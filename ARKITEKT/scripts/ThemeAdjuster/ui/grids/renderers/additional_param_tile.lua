-- @noindex
-- ThemeAdjuster/ui/grids/renderers/additional_param_tile.lua
-- Renders parameter tiles in Additional tab with controls and link mode selector

local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local Checkbox = require('rearkitekt.gui.widgets.primitives.checkbox')
local Spinner = require('rearkitekt.gui.widgets.primitives.spinner')
local ParameterLinkManager = require('ThemeAdjuster.core.parameter_link_manager')
local hexrgb = Colors.hexrgb

local M = {}

-- Tile dimensions
local TILE_HEIGHT = 60
local TILE_PADDING = 8
local CONTROL_WIDTH = 200

-- Throttle refresh calls during drag
local last_refresh_time = 0
local REFRESH_INTERVAL = 0.1  -- 100ms = 10 fps max

-- Template configuration state
M._template_config_open = M._template_config_open or {}  -- keyed by param_name
M._template_config_state = M._template_config_state or {}  -- editing state for open dialogs

-- Read/write parameter value from Reaper theme
local function get_param_value(param_index, param_type)
  if not param_index then return param_type == "bool" and 0 or 0.0 end

  local ok, name, desc, value = pcall(reaper.ThemeLayout_GetParameter, param_index)
  if not ok or value == nil then
    -- Default values based on type
    if param_type == "bool" then
      return 0
    elseif param_type == "int" or param_type == "enum" then
      return 0
    else -- float
      return 0.0
    end
  end
  return value
end

local function set_param_value(param_index, value)
  if not param_index then return end
  pcall(reaper.ThemeLayout_SetParameter, param_index, value, true)
end

-- Render a single parameter tile
function M.render(ctx, param, tab_color, shell_state, view)
  local param_name = param.name
  local param_index = param.index
  local param_type = param.type
  local metadata = view.custom_metadata[param_name] or {}

  -- Get current value from Reaper
  local current_value = get_param_value(param_index, param_type)

  -- Get link status
  local is_in_group = ParameterLinkManager.is_in_group(param_name)
  local link_mode = ParameterLinkManager.get_link_mode(param_name)
  local other_params = is_in_group and ParameterLinkManager.get_other_group_params(param_name) or {}

  -- Tile background
  local x1, y1 = ImGui.GetCursorScreenPos(ctx)
  local avail_w = ImGui.GetContentRegionAvail(ctx)
  local x2, y2 = x1 + avail_w, y1 + TILE_HEIGHT
  local dl = ImGui.GetWindowDrawList(ctx)

  -- Background with tab color tint
  local function dim_color(color, opacity)
    local r = (color >> 24) & 0xFF
    local g = (color >> 16) & 0xFF
    local b = (color >> 8) & 0xFF
    local a = math.floor(255 * opacity)
    return (r << 24) | (g << 16) | (b << 8) | a
  end

  local bg_color = dim_color(tab_color, 0.12)
  local border_color = dim_color(tab_color, 0.3)

  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, bg_color, 3)
  ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, border_color, 3, 0, 1)

  -- Start tile content
  ImGui.SetCursorScreenPos(ctx, x1 + TILE_PADDING, y1 + TILE_PADDING)

  -- TOP ROW: Parameter name + tooltip indicator
  ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
  local display_name = metadata.display_name and metadata.display_name ~= "" and metadata.display_name or param_name
  if #display_name > 35 then
    display_name = display_name:sub(1, 32) .. "..."
  end
  ImGui.Text(ctx, display_name)
  ImGui.PopFont(ctx)

  -- Tooltip with full details
  if ImGui.IsItemHovered(ctx) then
    local tooltip = "Parameter: " .. param_name
    tooltip = tooltip .. "\nType: " .. (param_type or "unknown")
    if metadata.description and metadata.description ~= "" then
      tooltip = tooltip .. "\n" .. metadata.description
    end
    if param.min and param.max then
      tooltip = tooltip .. string.format("\nRange: %.2f - %.2f", param.min, param.max)
    end
    ImGui.SetTooltip(ctx, tooltip)
  end

  -- Linked params indicator (same line, right side)
  if is_in_group and #other_params > 0 then
    ImGui.SameLine(ctx, avail_w - 250)
    local group_color = ParameterLinkManager.get_group_color(param_name) or hexrgb("#4AE290")
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, group_color)
    local linked_text = "Linked: " .. table.concat(other_params, ", ")
    if #linked_text > 30 then
      linked_text = linked_text:sub(1, 27) .. "..."
    end
    ImGui.Text(ctx, linked_text)
    ImGui.PopStyleColor(ctx)

    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, "Grouped with:\n" .. table.concat(other_params, "\n"))
    end
  end

  -- MIDDLE ROW: Control (slider/checkbox/spinner)
  ImGui.SetCursorScreenPos(ctx, x1 + TILE_PADDING, y1 + TILE_PADDING + 20)

  local value_changed = false
  local was_deactivated = false
  local new_value = current_value
  local control_id = "##" .. param_name

  -- Check if this parameter has a template configured
  local assignment = view:get_assignment_for_param(param.name)
  local template = assignment and assignment.template

  if template and template.type == "preset_spinner" and template.presets then
    -- Render preset spinner
    local preset_values = {}
    local preset_labels = {}
    for _, preset in ipairs(template.presets) do
      table.insert(preset_values, preset.value)
      table.insert(preset_labels, preset.label)
    end

    -- Find closest preset to current value
    local closest_idx = 1
    local min_diff = math.abs(current_value - preset_values[1])
    for i = 2, #preset_values do
      local diff = math.abs(current_value - preset_values[i])
      if diff < min_diff then
        min_diff = diff
        closest_idx = i
      end
    end

    local changed_spinner, new_idx = Spinner.draw(
      ctx,
      "##preset_spinner_" .. param.name,
      closest_idx,
      preset_labels,
      {w = CONTROL_WIDTH, h = 24}
    )

    if changed_spinner then
      new_value = preset_values[new_idx]
      value_changed = true
      was_deactivated = true  -- Spinner changes are immediate
    end

  elseif param_type == "bool" then
    -- Checkbox
    local checked = current_value ~= 0
    if Checkbox.draw_at_cursor(ctx, param_name, checked, nil, "param_" .. param_name) then
      new_value = checked and 0 or 1
      value_changed = true
      was_deactivated = true  -- Immediate
    end
  elseif param_type == "int" or param_type == "enum" then
    -- SliderInt with IsItemActive for continuous updates
    ImGui.SetNextItemWidth(ctx, CONTROL_WIDTH)
    local min_val = param.min or 0
    local max_val = param.max or 100
    local changed, val = ImGui.SliderInt(ctx, control_id, current_value, min_val, max_val)
    local is_active = ImGui.IsItemActive(ctx)

    if changed or is_active then
      new_value = val
      value_changed = true
    end

    if ImGui.IsItemDeactivated(ctx) then
      was_deactivated = true
    end
  else
    -- SliderDouble with IsItemActive (REAPER parameters are integers, so we round)
    ImGui.SetNextItemWidth(ctx, CONTROL_WIDTH)
    local min_val = param.min or 0.0
    local max_val = param.max or 1.0
    local changed, val = ImGui.SliderDouble(ctx, control_id, current_value, min_val, max_val, "%.0f")
    local is_active = ImGui.IsItemActive(ctx)

    if changed or is_active then
      new_value = math.floor(val + 0.5)  -- Round to integer for REAPER
      value_changed = true
    end

    if ImGui.IsItemDeactivated(ctx) then
      was_deactivated = true
    end
  end

  -- BOTTOM ROW: Link mode selector
  ImGui.SetCursorScreenPos(ctx, x1 + TILE_PADDING + CONTROL_WIDTH + 20, y1 + TILE_PADDING + 20)

  -- UNLINKED button
  local is_unlinked = link_mode == ParameterLinkManager.LINK_MODE.UNLINKED
  if is_unlinked then
    ImGui.PushStyleColor(ctx, ImGui.Col_Button, hexrgb("#555555"))
  end
  if ImGui.Button(ctx, "UNLINKED##" .. param_name, 80, 20) then
    ParameterLinkManager.set_link_mode(param_name, ParameterLinkManager.LINK_MODE.UNLINKED)
    view:save_assignments()
  end
  if is_unlinked then
    ImGui.PopStyleColor(ctx)
  end
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "No linking - parameter is independent")
  end

  ImGui.SameLine(ctx, 0, 4)

  -- LINK button
  local is_link = link_mode == ParameterLinkManager.LINK_MODE.LINK
  if is_link then
    ImGui.PushStyleColor(ctx, ImGui.Col_Button, hexrgb("#4A90E2"))
  end
  if ImGui.Button(ctx, "LINK##" .. param_name, 60, 20) then
    ParameterLinkManager.set_link_mode(param_name, ParameterLinkManager.LINK_MODE.LINK)
    view:save_assignments()
  end
  if is_link then
    ImGui.PopStyleColor(ctx)
  end
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "LINK mode - parameters move by same delta")
  end

  ImGui.SameLine(ctx, 0, 4)

  -- SYNC button
  local is_sync = link_mode == ParameterLinkManager.LINK_MODE.SYNC
  if is_sync then
    ImGui.PushStyleColor(ctx, ImGui.Col_Button, hexrgb("#4AE290"))
  end
  if ImGui.Button(ctx, "SYNC##" .. param_name, 60, 20) then
    ParameterLinkManager.set_link_mode(param_name, ParameterLinkManager.LINK_MODE.SYNC)
    view:save_assignments()
  end
  if is_sync then
    ImGui.PopStyleColor(ctx)
  end
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "SYNC mode - parameter mirrors exact value")
  end

  -- Handle value change and propagation (match library_tile.lua pattern)
  if value_changed then
    local old_value = current_value

    -- Apply to this parameter
    set_param_value(param_index, new_value)

    -- Propagate to linked parameters
    if is_in_group and link_mode ~= ParameterLinkManager.LINK_MODE.UNLINKED then
      local propagations = ParameterLinkManager.propagate_value_change(param_name, old_value, new_value, param)

      -- Apply propagated changes to other parameters
      for _, prop in ipairs(propagations) do
        -- Find the parameter definition for the linked param
        for _, p in ipairs(view.all_params) do
          if p.name == prop.param_name then
            local target_min = p.min or 0
            local target_max = p.max or 100
            local target_range = target_max - target_min
            local target_new_value

            if prop.mode == "sync" then
              -- SYNC: Set to same percentage position in target's range
              target_new_value = target_min + (prop.percent * target_range)
            elseif prop.mode == "link" then
              -- LINK: Use virtual value (can be negative), clamp for REAPER
              target_new_value = prop.virtual_value
            end

            -- Round to integer for REAPER
            target_new_value = math.floor(target_new_value + 0.5)

            -- Clamp to target's range
            local clamped_value = math.max(target_min, math.min(target_max, target_new_value))

            set_param_value(p.index, clamped_value)
            break
          end
        end
      end
    end

    -- Throttled refresh during drag, immediate on release
    local current_time = reaper.time_precise()
    local should_refresh = was_deactivated or ((current_time - last_refresh_time) >= REFRESH_INTERVAL)

    if should_refresh then
      pcall(reaper.ThemeLayout_RefreshAll)
      last_refresh_time = current_time
    end
  end

  -- Invisible button covering whole tile for right-click detection
  ImGui.SetCursorScreenPos(ctx, x1, y1)
  ImGui.InvisibleButton(ctx, "##tile_interact_" .. param_name, avail_w, TILE_HEIGHT)

  -- Right-click context menu
  if ImGui.BeginPopupContextItem(ctx, "tile_context_" .. param_name) then
    if ImGui.MenuItem(ctx, "Configure Template...") then
      M._template_config_open[param_name] = true
      -- Initialize config state if needed
      if not M._template_config_state[param_name] then
        M._template_config_state[param_name] = {
          template_type = "none",
          presets = {},
        }
      end
    end

    -- Show current template info
    local assignment = view:get_assignment_for_param(param_name)
    if assignment and assignment.template then
      if ImGui.MenuItem(ctx, "Remove Template") then
        assignment.template = nil
        view:save_assignments()
      end
    end

    ImGui.EndPopup(ctx)
  end

  -- Render template configuration dialog
  M.render_template_config_dialog(ctx, param_name, param, view)

  -- Move cursor to next tile position
  ImGui.SetCursorScreenPos(ctx, x1, y2 + 4)
  ImGui.Dummy(ctx, avail_w, 0)
end

-- Render template configuration dialog
function M.render_template_config_dialog(ctx, param_name, param, view)
  if not M._template_config_open[param_name] then
    return
  end

  local state = M._template_config_state[param_name]
  if not state then return end

  -- Center the modal on screen
  local viewport_w, viewport_h = ImGui.GetWindowViewport(ctx)
  local modal_w, modal_h = 500, 400

  ImGui.SetNextWindowPos(ctx, (viewport_w - modal_w) / 2, (viewport_h - modal_h) / 2, ImGui.Cond_Appearing)
  ImGui.SetNextWindowSize(ctx, modal_w, modal_h, ImGui.Cond_Appearing)

  local flags = ImGui.WindowFlags_NoCollapse | ImGui.WindowFlags_NoDocking
  local visible, open = ImGui.Begin(ctx, "Template Configuration: " .. param_name, true, flags)

  if visible then
    ImGui.Text(ctx, "Template Type:")
    ImGui.Separator(ctx)
    ImGui.Dummy(ctx, 0, 8)

    -- Template type selector
    if ImGui.RadioButton(ctx, "None (Default Control)", state.template_type == "none") then
      state.template_type = "none"
    end

    ImGui.Dummy(ctx, 0, 4)

    if ImGui.RadioButton(ctx, "Preset Spinner", state.template_type == "preset_spinner") then
      state.template_type = "preset_spinner"
      -- Initialize with some defaults if empty
      if #state.presets == 0 then
        state.presets = {
          {value = param.min or 0, label = "Off"},
          {value = ((param.max or 100) - (param.min or 0)) * 0.3 + (param.min or 0), label = "Low"},
          {value = ((param.max or 100) - (param.min or 0)) * 0.5 + (param.min or 0), label = "Medium"},
          {value = ((param.max or 100) - (param.min or 0)) * 0.7 + (param.min or 0), label = "High"},
        }
      end
    end

    ImGui.Dummy(ctx, 0, 12)

    -- Preset editor (only for preset_spinner)
    if state.template_type == "preset_spinner" then
      ImGui.Text(ctx, "Presets:")
      ImGui.Separator(ctx)
      ImGui.Dummy(ctx, 0, 8)

      -- Show existing presets
      for i, preset in ipairs(state.presets) do
        ImGui.PushID(ctx, i)

        ImGui.SetNextItemWidth(ctx, 100)
        local changed_val, new_val = ImGui.InputDouble(ctx, "##value", preset.value)
        if changed_val then
          preset.value = new_val
        end

        ImGui.SameLine(ctx, 0, 8)
        ImGui.SetNextItemWidth(ctx, 200)
        local changed_label, new_label = ImGui.InputText(ctx, "##label", preset.label)
        if changed_label then
          preset.label = new_label
        end

        ImGui.SameLine(ctx, 0, 8)
        if ImGui.Button(ctx, "Remove") then
          table.remove(state.presets, i)
        end

        ImGui.PopID(ctx)
      end

      ImGui.Dummy(ctx, 0, 8)
      if ImGui.Button(ctx, "Add Preset") then
        table.insert(state.presets, {value = param.min or 0, label = "New Preset"})
      end
    end

    -- Bottom buttons
    ImGui.Dummy(ctx, 0, 12)
    ImGui.Separator(ctx)
    ImGui.Dummy(ctx, 0, 8)

    if ImGui.Button(ctx, "Save", 100, 28) then
      -- Apply template to assignment
      local assignment = view:get_assignment_for_param(param_name)
      if assignment then
        if state.template_type == "none" then
          assignment.template = nil
        else
          assignment.template = {
            type = state.template_type,
            presets = state.template_type == "preset_spinner" and state.presets or nil,
          }
        end
        view:save_assignments()
      end
      M._template_config_open[param_name] = false
    end

    ImGui.SameLine(ctx, 0, 8)
    if ImGui.Button(ctx, "Cancel", 100, 28) then
      M._template_config_open[param_name] = false
    end

    ImGui.End(ctx)
  end

  if not open then
    M._template_config_open[param_name] = false
  end
end

return M

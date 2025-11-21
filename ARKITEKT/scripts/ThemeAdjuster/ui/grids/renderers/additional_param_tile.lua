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

-- Refresh throttling: Track last refresh time globally
local last_refresh_time = 0
local REFRESH_INTERVAL = 0.1  -- 100ms between refreshes (10 fps max)
local refresh_needed = false

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
  -- Always persist parameter (save=true) like original Theme Adjuster
  local ok = pcall(reaper.ThemeLayout_SetParameter, param_index, value, true)
  if ok then
    refresh_needed = true  -- Flag that refresh is needed
  end
  return ok
end

-- Call this at the end of render to do throttled refresh
local function do_throttled_refresh()
  if not refresh_needed then return end

  local current_time = reaper.time_precise()
  if (current_time - last_refresh_time) >= REFRESH_INTERVAL then
    pcall(reaper.ThemeLayout_RefreshAll)
    last_refresh_time = current_time
    refresh_needed = false
  end
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
  local item_deactivated = false
  local new_value = current_value
  local control_id = "##" .. param_name

  if param_type == "bool" then
    -- Checkbox
    local checked = current_value ~= 0
    if Checkbox.draw_at_cursor(ctx, param_name, checked, nil, "param_" .. param_name) then
      new_value = checked and 0 or 1
      value_changed = true
      item_deactivated = true  -- Checkbox is immediate
    end
  elseif param_type == "int" or param_type == "enum" then
    -- Spinner for integers
    ImGui.SetNextItemWidth(ctx, CONTROL_WIDTH)
    local min_val = param.min or 0
    local max_val = param.max or 100
    local changed, val = ImGui.DragInt(ctx, control_id, current_value, 1, min_val, max_val)
    if changed then
      new_value = val
      value_changed = true
    end
    -- Check if mouse was released
    if ImGui.IsItemDeactivated(ctx) then
      item_deactivated = true
    end
  else
    -- Drag control for floats (smoother than SliderDouble)
    ImGui.SetNextItemWidth(ctx, CONTROL_WIDTH)
    local min_val = param.min or 0.0
    local max_val = param.max or 1.0
    -- Calculate appropriate drag speed based on range (1% of range, minimum 0.01)
    local range = max_val - min_val
    local speed = math.max(range * 0.01, 0.01)
    local changed, val = ImGui.DragDouble(ctx, control_id, current_value, speed, min_val, max_val, "%.2f")
    if changed then
      new_value = val
      value_changed = true
    end
    -- Check if mouse was released
    if ImGui.IsItemDeactivated(ctx) then
      item_deactivated = true
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

  -- Handle value change and propagation
  if value_changed then
    -- Always set parameter value (persisted immediately, like original Theme Adjuster)
    set_param_value(param_index, new_value)

    -- Propagate to linked parameters
    if is_in_group and link_mode ~= ParameterLinkManager.LINK_MODE.UNLINKED then
      local propagations = ParameterLinkManager.propagate_value_change(param_name, current_value, new_value)

      -- Apply propagated changes to other parameters
      for _, prop in ipairs(propagations) do
        -- Find the parameter index for the linked param
        for _, p in ipairs(view.all_params) do
          if p.name == prop.param_name then
            set_param_value(p.index, prop.clamped_value)
            break
          end
        end
      end
    end
  end

  -- ALWAYS force refresh on mouse release - don't rely on flags that might get cleared
  if item_deactivated then
    pcall(reaper.ThemeLayout_RefreshAll)
    last_refresh_time = reaper.time_precise()
    refresh_needed = false
  else
    -- Only do throttled refresh if NOT deactivating (during active drag)
    do_throttled_refresh()
  end

  -- Move cursor to next tile position
  ImGui.SetCursorScreenPos(ctx, x1, y2 + 4)
  ImGui.Dummy(ctx, avail_w, 0)
end

return M

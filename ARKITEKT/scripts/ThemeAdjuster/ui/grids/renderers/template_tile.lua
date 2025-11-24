-- @noindex
-- ThemeAdjuster/ui/grids/renderers/template_tile.lua
-- Renders template tiles in the templates grid

local ImGui = require 'imgui' '0.10'
local Colors = require('arkitekt.core.colors')
local Visuals = require('ThemeAdjuster.ui.grids.renderers.tile_visuals')
local hexrgb = Colors.hexrgb

local M = {}

-- Animation state storage (persistent across frames)
M._anim = M._anim or {}

-- Template configuration state
M._template_config_open = M._template_config_open or {}
M._template_config_state = M._template_config_state or {}

function M.render(ctx, rect, item, state, view)
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local w = x2 - x1
  local h = y2 - y1
  local dl = ImGui.GetWindowDrawList(ctx)

  local template_id = item.id
  local template = view.templates[template_id]
  if not template then return end

  -- Animation state
  local key = "template_" .. template_id
  M._anim[key] = M._anim[key] or { hover = 0 }

  local hover_t = Visuals.lerp(M._anim[key].hover, state.hover and 1 or 0, 12.0 * 0.016)
  M._anim[key].hover = hover_t

  -- Color definitions
  local BG_BASE = hexrgb("#252530")
  local BG_HOVER = hexrgb("#2D2D3D")
  local BRD_BASE = hexrgb("#444455")
  local BRD_HOVER = hexrgb("#7788FF")
  local ANT_COLOR = hexrgb("#7788FF7F")

  -- Hover shadow effect
  if hover_t > 0.01 and not state.selected then
    Visuals.draw_hover_shadow(dl, x1, y1, x2, y2, hover_t, 3)
  end

  -- Background
  local bg_color = Visuals.color_lerp(BG_BASE, BG_HOVER, hover_t * 0.5)
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, bg_color, 3)

  -- Border / Selection
  if state.selected then
    Visuals.draw_marching_ants_rounded(dl, x1 + 0.5, y1 + 0.5, x2 - 0.5, y2 - 0.5, ANT_COLOR, 1, 3)
  else
    local border_color = Visuals.color_lerp(BRD_BASE, BRD_HOVER, hover_t)
    ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, border_color, 3, 0, 1)
  end

  -- Content
  ImGui.SetCursorScreenPos(ctx, x1 + 8, y1 + 4)
  ImGui.AlignTextToFramePadding(ctx)

  -- Template name
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#CCCCFF"))
  local display_name = template.name or "Unnamed Template"
  if #display_name > 30 then
    display_name = display_name:sub(1, 27) .. "..."
  end
  ImGui.Text(ctx, display_name)
  ImGui.PopStyleColor(ctx)

  -- Template type indicator
  ImGui.SameLine(ctx)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#8888AA"))
  local type_label = template.type == "preset_spinner" and "[Preset]" or
                     template.type == "compound_bool" and "[Compound]" or
                     "[Custom]"
  ImGui.Text(ctx, type_label)
  ImGui.PopStyleColor(ctx)

  -- Parameter list (second line)
  ImGui.SetCursorScreenPos(ctx, x1 + 8, y1 + 20)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#777788"))

  local param_names = {}
  for _, param_name in ipairs(template.params or {}) do
    table.insert(param_names, param_name)
  end

  local params_text = table.concat(param_names, ", ")
  if #params_text > 50 then
    params_text = params_text:sub(1, 47) .. "..."
  end
  ImGui.Text(ctx, params_text)
  ImGui.PopStyleColor(ctx)

  -- Tooltip
  if ImGui.IsItemHovered(ctx) then
    local tooltip = "Template: " .. (template.name or "Unnamed")
    tooltip = tooltip .. "\nType: " .. (template.type or "unknown")
    tooltip = tooltip .. "\nParameters: " .. table.concat(param_names, ", ")
    if template.type == "preset_spinner" and template.config and template.config.presets then
      tooltip = tooltip .. "\nPresets: " .. #template.config.presets
    end
    ImGui.SetTooltip(ctx, tooltip)
  end

  -- Invisible button for right-click
  ImGui.SetCursorScreenPos(ctx, x1, y1)
  ImGui.InvisibleButton(ctx, "##template_interact_" .. template_id, w, h)

  -- Right-click context menu
  if ImGui.BeginPopupContextItem(ctx, "template_context_" .. template_id) then
    if ImGui.MenuItem(ctx, "Configure...") then
      M._template_config_open[template_id] = true
      -- Load existing config and convert to new format if needed
      local presets = {}
      if template.config and template.config.presets then
        for _, preset in ipairs(template.config.presets) do
          local new_preset = {
            label = preset.label or "Unnamed",
            values = {}
          }

          -- Convert old single-value format to new multi-parameter format
          if preset.value then
            -- Old format: apply value to all parameters
            for _, param_name in ipairs(template.params or {}) do
              new_preset.values[param_name] = preset.value
            end
          else
            -- Already new format
            new_preset.values = preset.values or {}
          end

          table.insert(presets, new_preset)
        end
      end

      M._template_config_state[template_id] = {
        name = template.name or "",
        template_type = template.type or "preset_spinner",
        presets = presets,
        param_order = template.params or {},
      }
    end

    ImGui.Separator(ctx)

    if ImGui.MenuItem(ctx, "Delete") then
      view:delete_template(template_id)
    end

    ImGui.EndPopup(ctx)
  end
end

-- Render template configuration dialogs
function M.render_template_config_dialogs(ctx, view)
  for template_id, is_open in pairs(M._template_config_open) do
    if is_open then
      local state = M._template_config_state[template_id]
      if not state then
        M._template_config_open[template_id] = false
        goto continue
      end

      local template = view.templates[template_id]
      if not template then
        M._template_config_open[template_id] = false
        goto continue
      end

      -- Modal window
      local modal_w, modal_h = 600, 500
      ImGui.SetNextWindowSize(ctx, modal_w, modal_h, ImGui.Cond_Appearing)

      local flags = ImGui.WindowFlags_NoCollapse | ImGui.WindowFlags_NoDocking
      local visible, open = ImGui.Begin(ctx, "Template Configuration: " .. (state.name ~= "" and state.name or "Unnamed"), true, flags)

      if visible then
        -- Template name
        ImGui.Text(ctx, "Template Name:")
        ImGui.SetNextItemWidth(ctx, 300)
        local changed_name, new_name = ImGui.InputText(ctx, "##template_name", state.name)
        if changed_name then
          state.name = new_name
        end

        ImGui.Dummy(ctx, 0, 12)
        ImGui.Separator(ctx)
        ImGui.Dummy(ctx, 0, 8)

        -- Template type
        ImGui.Text(ctx, "Template Type:")
        ImGui.Dummy(ctx, 0, 4)

        -- Template type selection (always preset spinner)
        ImGui.Text(ctx, "Template Type: Preset Spinner")
        ImGui.Dummy(ctx, 0, 8)

        -- Preset configuration
        M.render_preset_config(ctx, state, view, template)

        -- Bottom buttons
        ImGui.Dummy(ctx, 0, 12)
        ImGui.Separator(ctx)
        ImGui.Dummy(ctx, 0, 8)

        if ImGui.Button(ctx, "Save", 100, 28) then
          -- Apply configuration
          template.name = state.name
          template.type = "preset_spinner"
          template.config = {
            presets = state.presets
          }
          view:save_templates()
          M._template_config_open[template_id] = false
        end

        ImGui.SameLine(ctx, 0, 8)
        if ImGui.Button(ctx, "Cancel", 100, 28) then
          M._template_config_open[template_id] = false
        end

        ImGui.End(ctx)
      end

      if not open then
        M._template_config_open[template_id] = false
      end

      ::continue::
    end
  end
end

-- Render preset spinner configuration with parameter columns
function M.render_preset_config(ctx, state, view, template)
  ImGui.Text(ctx, "Presets (each row = spinner enum):")
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 8)

  local param_order = state.param_order or {}
  local num_params = #param_order

  -- Calculate number of columns: # + Label + one per parameter
  local num_columns = 2 + num_params

  -- Table for presets
  local table_flags = ImGui.TableFlags_Borders |
                      ImGui.TableFlags_RowBg |
                      ImGui.TableFlags_ScrollY |
                      ImGui.TableFlags_ScrollX |
                      ImGui.TableFlags_SizingFixedFit

  if ImGui.BeginTable(ctx, "preset_table", num_columns, table_flags, 0, 250) then
    -- Setup columns
    ImGui.TableSetupColumn(ctx, "#", ImGui.TableColumnFlags_WidthFixed, 30)
    ImGui.TableSetupColumn(ctx, "Label", ImGui.TableColumnFlags_WidthFixed, 120)

    -- Add column for each parameter
    for _, param_name in ipairs(param_order) do
      -- Use full parameter name
      ImGui.TableSetupColumn(ctx, param_name, ImGui.TableColumnFlags_WidthFixed, 150)
    end

    ImGui.TableSetupScrollFreeze(ctx, 2, 1)  -- Freeze first 2 columns and header
    ImGui.TableHeadersRow(ctx)

    -- Render preset rows
    local to_remove = nil
    for i, preset in ipairs(state.presets) do
      ImGui.TableNextRow(ctx)
      ImGui.PushID(ctx, i)

      -- Column 0: Index with remove button
      ImGui.TableSetColumnIndex(ctx, 0)
      ImGui.AlignTextToFramePadding(ctx)
      ImGui.Text(ctx, tostring(i))
      if ImGui.IsItemHovered(ctx) then
        ImGui.SetTooltip(ctx, "Right-click to remove")
      end

      -- Right-click to remove
      if ImGui.BeginPopupContextItem(ctx, "preset_ctx_" .. i) then
        if ImGui.MenuItem(ctx, "Remove") then
          to_remove = i
        end
        ImGui.EndPopup(ctx)
      end

      -- Column 1: Label input
      ImGui.TableSetColumnIndex(ctx, 1)
      ImGui.SetNextItemWidth(ctx, -1)
      local changed_label, new_label = ImGui.InputText(ctx, "##label", preset.label or "")
      if changed_label then
        preset.label = new_label
      end

      -- Columns 2+: Parameter value controls
      for col_idx, param_name in ipairs(param_order) do
        ImGui.TableSetColumnIndex(ctx, 1 + col_idx)

        -- Get parameter info
        local param = view:get_param_by_name(param_name)
        if param then
          -- Initialize value if not set
          if preset.values[param_name] == nil then
            preset.values[param_name] = param.default or param.min or 0
          end

          -- Render control based on parameter type
          ImGui.SetNextItemWidth(ctx, -1)
          local changed = false
          local new_value = preset.values[param_name]

          if param.type == "toggle" then
            -- Checkbox for boolean
            local is_checked = (preset.values[param_name] ~= 0)
            local rv, new_checked = ImGui.Checkbox(ctx, "##" .. param_name, is_checked)
            if rv then
              changed = true
              new_value = new_checked and 1 or 0
            end

          elseif param.type == "spinner" then
            -- Combo box for enum
            local current_idx = math.floor(preset.values[param_name] - param.min + 1)
            local values = {}
            for v = param.min, param.max do
              table.insert(values, tostring(v))
            end

            local rv, new_idx = ImGui.Combo(ctx, "##" .. param_name, current_idx, table.concat(values, "\0") .. "\0")
            if rv then
              changed = true
              new_value = param.min + (new_idx - 1)
            end

          else
            -- InputDouble for int/float/slider
            local rv, new_val = ImGui.InputDouble(ctx, "##" .. param_name, preset.values[param_name])
            if rv then
              changed = true
              new_value = new_val
              -- Clamp to min/max
              if param.min and new_value < param.min then new_value = param.min end
              if param.max and new_value > param.max then new_value = param.max end
            end
          end

          if changed then
            preset.values[param_name] = new_value
          end
        end
      end

      ImGui.PopID(ctx)
    end

    -- Handle removal
    if to_remove then
      table.remove(state.presets, to_remove)
    end

    ImGui.EndTable(ctx)
  end

  ImGui.Dummy(ctx, 0, 8)
  if ImGui.Button(ctx, "Add Preset", 120, 0) then
    -- Create new preset with default values for all parameters
    local new_preset = {
      label = "New Preset",
      values = {}
    }

    for _, param_name in ipairs(param_order) do
      local param = view:get_param_by_name(param_name)
      if param then
        new_preset.values[param_name] = param.default or param.min or 0
      end
    end

    table.insert(state.presets, new_preset)
  end

  ImGui.SameLine(ctx)
  ImGui.TextDisabled(ctx, "(Right-click row # to remove)")
end

-- Removed compound boolean config - no longer needed

return M

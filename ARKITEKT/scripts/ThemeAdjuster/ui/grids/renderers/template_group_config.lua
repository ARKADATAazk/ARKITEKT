-- @noindex
-- ThemeAdjuster/ui/grids/renderers/template_group_config.lua
-- Configuration UI for template groups in the templates grid

local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

-- Configuration state storage
M._group_config_open = M._group_config_open or {}
M._group_config_state = M._group_config_state or {}

--- Opens the configuration dialog for a template group
--- @param group_id string - The group ID to configure
--- @param view table - The AdditionalView instance
function M.open_config(group_id, view)
  local group = nil
  for _, g in ipairs(view.template_groups) do
    if g.id == group_id then
      group = g
      break
    end
  end

  if not group then return end

  M._group_config_open[group_id] = true
  M._group_config_state[group_id] = {
    name = group.name or "",
    color = group.color or "#888888",
    -- Load first template's config as group defaults
    preset_config = M.load_group_preset_config(group, view),
  }
end

--- Loads the preset configuration from the group's templates
--- @param group table - The group data
--- @param view table - The AdditionalView instance
--- @return table - Preset configuration state
function M.load_group_preset_config(group, view)
  -- Check if all templates in the group have the same type and compatible presets
  local first_template_id = group.template_ids and group.template_ids[1]
  if not first_template_id then
    return {
      type = "preset_spinner",
      presets = {},
      unified = false,
    }
  end

  local first_template = view.templates[first_template_id]
  if not first_template or not first_template.config then
    return {
      type = "preset_spinner",
      presets = {},
      unified = false,
    }
  end

  -- Copy presets from first template
  local presets = {}
  if first_template.config.presets then
    for _, preset in ipairs(first_template.config.presets) do
      table.insert(presets, {
        value = preset.value,
        label = preset.label,
      })
    end
  end

  return {
    type = first_template.type or "preset_spinner",
    presets = presets,
    unified = true,
  }
end

--- Renders all open group configuration dialogs
--- @param ctx ImGui context
--- @param view table - The AdditionalView instance
function M.render_config_dialogs(ctx, view)
  for group_id, is_open in pairs(M._group_config_open) do
    if is_open then
      local state = M._group_config_state[group_id]
      if not state then
        M._group_config_open[group_id] = false
        goto continue
      end

      -- Find the group
      local group = nil
      for _, g in ipairs(view.template_groups) do
        if g.id == group_id then
          group = g
          break
        end
      end

      if not group then
        M._group_config_open[group_id] = false
        goto continue
      end

      -- Modal window
      local modal_w, modal_h = 650, 600
      ImGui.SetNextWindowSize(ctx, modal_w, modal_h, ImGui.Cond_Appearing)

      local flags = ImGui.WindowFlags_NoCollapse | ImGui.WindowFlags_NoDocking
      local visible, open = ImGui.Begin(ctx, "Group Configuration: " .. (state.name ~= "" and state.name or "Unnamed Group"), true, flags)

      if visible then
        -- Group name
        ImGui.Text(ctx, "Group Name:")
        ImGui.SetNextItemWidth(ctx, 300)
        local changed_name, new_name = ImGui.InputText(ctx, "##group_name", state.name)
        if changed_name then
          state.name = new_name
        end

        ImGui.Dummy(ctx, 0, 8)

        -- Group color picker
        ImGui.Text(ctx, "Group Color:")
        ImGui.SameLine(ctx)

        -- Convert hex to ImGui color format (0xRRGGBB)
        local color_int = M.hex_to_color_int(state.color)
        ImGui.SetNextItemWidth(ctx, 150)
        local changed_color, new_color_int = ImGui.ColorEdit3(ctx, "##group_color", color_int, ImGui.ColorEditFlags_NoInputs)
        if changed_color then
          state.color = M.color_int_to_hex(new_color_int)
        end

        ImGui.Dummy(ctx, 0, 12)
        ImGui.Separator(ctx)
        ImGui.Dummy(ctx, 0, 8)

        -- Template list in this group
        ImGui.Text(ctx, string.format("Templates in this group: %d", #(group.template_ids or {})))
        ImGui.Dummy(ctx, 0, 4)

        if ImGui.BeginChild(ctx, "group_templates_list", 0, 100) then
          for _, template_id in ipairs(group.template_ids or {}) do
            local template = view.templates[template_id]
            if template then
              local param_names = table.concat(template.params or {}, ", ")
              ImGui.BulletText(ctx, param_names)
            end
          end
          ImGui.EndChild(ctx)
        end

        ImGui.Dummy(ctx, 0, 12)
        ImGui.Separator(ctx)
        ImGui.Dummy(ctx, 0, 8)

        -- Unified preset configuration
        ImGui.Text(ctx, "Unified Preset Configuration:")
        ImGui.TextWrapped(ctx, "Configure presets for all templates in this group. Changes will be applied to all member templates.")
        ImGui.Dummy(ctx, 0, 8)

        -- Preset type selection
        if ImGui.RadioButton(ctx, "Preset Spinner", state.preset_config.type == "preset_spinner") then
          state.preset_config.type = "preset_spinner"
          -- Initialize default presets if empty
          if #state.preset_config.presets == 0 then
            M.initialize_default_presets(state, group, view)
          end
        end

        ImGui.SameLine(ctx, 0, 12)

        if ImGui.RadioButton(ctx, "Compound Boolean", state.preset_config.type == "compound_bool") then
          state.preset_config.type = "compound_bool"
        end

        ImGui.Dummy(ctx, 0, 8)

        -- Type-specific configuration
        if state.preset_config.type == "preset_spinner" then
          M.render_preset_config(ctx, state)
        elseif state.preset_config.type == "compound_bool" then
          ImGui.TextColored(ctx, hexrgb("#FFAA44"), "Compound boolean configuration coming soon...")
        end

        -- Bottom buttons
        ImGui.Dummy(ctx, 0, 12)
        ImGui.Separator(ctx)
        ImGui.Dummy(ctx, 0, 8)

        if ImGui.Button(ctx, "Apply to All Templates", 180, 28) then
          -- Apply configuration to the group and all its templates
          M.apply_group_config(group, state, view)
          M._group_config_open[group_id] = false
        end

        ImGui.SameLine(ctx, 0, 8)
        if ImGui.Button(ctx, "Cancel", 100, 28) then
          M._group_config_open[group_id] = false
        end

        ImGui.End(ctx)
      end

      if not open then
        M._group_config_open[group_id] = false
      end

      ::continue::
    end
  end
end

--- Render preset spinner configuration
function M.render_preset_config(ctx, state)
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 8)

  -- Scrollable region for presets
  if ImGui.BeginChild(ctx, "group_preset_list", 0, 180) then
    local to_remove = nil
    for i, preset in ipairs(state.preset_config.presets) do
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
        to_remove = i
      end

      ImGui.PopID(ctx)
    end

    if to_remove then
      table.remove(state.preset_config.presets, to_remove)
    end

    ImGui.EndChild(ctx)
  end

  ImGui.Dummy(ctx, 0, 8)
  if ImGui.Button(ctx, "Add Preset") then
    table.insert(state.preset_config.presets, {value = 0, label = "New Preset"})
  end
end

--- Initialize default presets for a group
function M.initialize_default_presets(state, group, view)
  -- Get the first template's parameter to determine range
  local first_template_id = group.template_ids and group.template_ids[1]
  if not first_template_id then return end

  local first_template = view.templates[first_template_id]
  if not first_template or not first_template.params or #first_template.params == 0 then
    return
  end

  local param_name = first_template.params[1]
  local param = view:get_param_by_name(param_name)
  if param then
    state.preset_config.presets = {
      {value = param.min or 0, label = "Off"},
      {value = ((param.max or 100) - (param.min or 0)) * 0.3 + (param.min or 0), label = "Low"},
      {value = ((param.max or 100) - (param.min or 0)) * 0.5 + (param.min or 0), label = "Medium"},
      {value = ((param.max or 100) - (param.min or 0)) * 0.7 + (param.min or 0), label = "High"},
    }
  end
end

--- Apply group configuration to all templates in the group
function M.apply_group_config(group, state, view)
  -- Update group properties
  group.name = state.name
  group.color = state.color

  -- Apply configuration to all templates in the group
  for _, template_id in ipairs(group.template_ids or {}) do
    local template = view.templates[template_id]
    if template then
      -- Update template type
      template.type = state.preset_config.type

      -- Update template config based on type
      if state.preset_config.type == "preset_spinner" then
        template.config = {
          presets = {}
        }
        -- Deep copy presets
        for _, preset in ipairs(state.preset_config.presets) do
          table.insert(template.config.presets, {
            value = preset.value,
            label = preset.label,
          })
        end
      elseif state.preset_config.type == "compound_bool" then
        template.config = {
          mappings = state.preset_config.compound_mappings or {}
        }
      end
    end
  end

  -- Save changes
  view:save_templates()
end

--- Convert hex color string to ImGui color integer (0xRRGGBB)
function M.hex_to_color_int(hex)
  hex = hex:gsub("#", "")
  return tonumber(hex, 16)
end

--- Convert ImGui color integer (0xRRGGBB) to hex color string
function M.color_int_to_hex(color_int)
  return string.format("#%06X", color_int & 0xFFFFFF)
end

return M

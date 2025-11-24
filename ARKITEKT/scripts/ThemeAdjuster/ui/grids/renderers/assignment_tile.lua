-- @noindex
-- ThemeAdjuster/ui/grids/renderers/assignment_tile.lua
-- Renders parameter tiles in assignment grids

local ImGui = require 'imgui' '0.10'
local Colors = require('arkitekt.core.colors')
local Visuals = require('ThemeAdjuster.ui.grids.renderers.tile_visuals')
local ParameterLinkManager = require('ThemeAdjuster.core.parameter_link_manager')
local hexrgb = Colors.hexrgb

local M = {}

-- Animation state storage (persistent across frames)
M._anim = M._anim or {}

-- Template configuration state
M._template_config_open = M._template_config_open or {}  -- keyed by param_name
M._template_config_state = M._template_config_state or {}  -- editing state for open dialogs

function M.render(ctx, rect, item, state, view, tab_id)
  -- Check if this is a group assignment
  if item.type == "group" then
    M.render_group(ctx, rect, item, state, view, tab_id)
    return
  end

  -- Otherwise render as parameter tile
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local w = x2 - x1
  local h = y2 - y1
  local dl = ImGui.GetWindowDrawList(ctx)

  local param_name = item.param_name
  local metadata = view.custom_metadata[param_name] or {}

  -- Animation state (smooth transitions)
  local key = "assign_" .. tab_id .. "_" .. param_name
  M._anim[key] = M._anim[key] or { hover = 0 }

  -- CORRECT: Grid passes state.hover and state.selected (not is_hovered/is_selected!)
  local hover_t = Visuals.lerp(M._anim[key].hover, state.hover and 1 or 0, 12.0 * 0.016)
  M._anim[key].hover = hover_t

  -- Get tab color
  local tab_color = view.tab_colors[tab_id] or hexrgb("#888888")

  -- Color definitions - use tab color for base with very low opacity
  local function dim_color(color, opacity)
    local r = (color >> 24) & 0xFF
    local g = (color >> 16) & 0xFF
    local b = (color >> 8) & 0xFF
    local a = math.floor(255 * opacity)
    return (r << 24) | (g << 16) | (b << 8) | a
  end

  local BG_BASE = dim_color(tab_color, 0.12)  -- 12% opacity of tab color
  local BG_HOVER = dim_color(tab_color, 0.18)  -- 18% opacity on hover
  local BRD_BASE = dim_color(tab_color, 0.3)  -- 30% opacity for border
  local BRD_HOVER = tab_color  -- Full tab color on hover
  local ANT_COLOR = dim_color(tab_color, 0.5)  -- 50% opacity for marching ants

  -- Hover shadow effect (only when not selected)
  if hover_t > 0.01 and not state.selected then
    Visuals.draw_hover_shadow(dl, x1, y1, x2, y2, hover_t, 3)
  end

  -- Background color (with smooth transitions)
  local bg_color = BG_BASE
  bg_color = Visuals.color_lerp(bg_color, BG_HOVER, hover_t * 0.5)

  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, bg_color, 3)

  -- Border / Selection
  if state.selected then
    -- Marching ants for selection
    Visuals.draw_marching_ants_rounded(dl, x1 + 0.5, y1 + 0.5, x2 - 0.5, y2 - 0.5, ANT_COLOR, 1, 3)
  else
    -- Normal border with hover highlight
    local border_color = Visuals.color_lerp(BRD_BASE, BRD_HOVER, hover_t)
    ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, border_color, 3, 0, 1)
  end

  -- Position cursor inside tile (moved 3 pixels up)
  ImGui.SetCursorScreenPos(ctx, x1 + 8, y1 + 1)

  ImGui.AlignTextToFramePadding(ctx)

  -- Display: [CUSTOM NAME] → [PARAM NAME] (when custom name exists)
  -- Otherwise: [PARAM NAME]

  -- Check link status for visual indicator
  local is_in_group = ParameterLinkManager.is_in_group(param_name)
  local link_prefix = ""
  local link_color = hexrgb("#FFFFFF")

  if is_in_group then
    local mode = ParameterLinkManager.get_link_mode(param_name)
    link_prefix = mode == ParameterLinkManager.LINK_MODE.LINK and "⇄ " or "⇉ "
    link_color = ParameterLinkManager.get_group_color(param_name) or hexrgb("#4AE290")
  end

  if metadata.display_name and metadata.display_name ~= "" then
    -- Link indicator
    if link_prefix ~= "" then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, link_color)
      ImGui.Text(ctx, link_prefix)
      ImGui.PopStyleColor(ctx)
      ImGui.SameLine(ctx, 0, 0)
    end

    -- Custom name on LEFT (bright color)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#CCCCCC"))
    local custom_name = metadata.display_name
    local max_len = link_prefix ~= "" and 26 or 30
    if #custom_name > max_len then
      custom_name = custom_name:sub(1, max_len - 3) .. "..."
    end
    ImGui.Text(ctx, custom_name)
    ImGui.PopStyleColor(ctx)

    -- Parameter name on RIGHT (muted)
    ImGui.SameLine(ctx, 0, 12)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#666666"))
    local display_name = param_name
    if #display_name > 25 then
      display_name = display_name:sub(1, 22) .. "..."
    end
    ImGui.Text(ctx, "(" .. display_name .. ")")
    ImGui.PopStyleColor(ctx)
  else
    -- Link indicator
    if link_prefix ~= "" then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, link_color)
      ImGui.Text(ctx, link_prefix)
      ImGui.PopStyleColor(ctx)
      ImGui.SameLine(ctx, 0, 0)
    end

    -- No custom name - just show parameter name (muted color)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#888888"))
    local display_name = param_name
    local max_len = link_prefix ~= "" and 21 or 25
    if #display_name > max_len then
      display_name = display_name:sub(1, max_len - 3) .. "..."
    end
    ImGui.Text(ctx, display_name)
    ImGui.PopStyleColor(ctx)

    -- Tooltip
    if ImGui.IsItemHovered(ctx) then
      local tooltip = "Parameter: " .. param_name
      if is_in_group then
        local other_params = ParameterLinkManager.get_other_group_params(param_name)
        local mode = ParameterLinkManager.get_link_mode(param_name)
        local mode_text = mode == ParameterLinkManager.LINK_MODE.LINK and "LINK" or "SYNC"
        if #other_params > 0 then
          tooltip = tooltip .. string.format("\nGrouped with: %s [%s]", table.concat(other_params, ", "), mode_text)
        else
          tooltip = tooltip .. string.format("\nIn group [%s]", mode_text)
        end
      end
      ImGui.SetTooltip(ctx, tooltip)
    end
  end

  -- Show order number for debugging (optional)
  if view.dev_mode and item.order then
    ImGui.SameLine(ctx)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#555555"))
    ImGui.Text(ctx, string.format("#%d", item.order))
    ImGui.PopStyleColor(ctx)
  end

  -- Invisible button covering whole tile for right-click detection
  ImGui.SetCursorScreenPos(ctx, x1, y1)
  ImGui.InvisibleButton(ctx, "##tile_interact_" .. param_name .. "_" .. tab_id, w, h)

  -- Right-click context menu
  if ImGui.BeginPopupContextItem(ctx, "tile_context_" .. param_name .. "_" .. tab_id) then
    if ImGui.MenuItem(ctx, "Configure Template...") then
      M._template_config_open[param_name] = true

      -- Initialize config state - load existing template or create new
      local assignment = view:get_assignment_for_param(param_name)
      if assignment and assignment.template then
        -- Load existing template
        M._template_config_state[param_name] = {
          template_type = assignment.template.type or "none",
          presets = assignment.template.presets or {},
        }
      else
        -- Create new config
        M._template_config_state[param_name] = {
          template_type = "none",
          presets = {},
        }
      end
    end

    -- Show current template info
    local assignment = view:get_assignment_for_param(param_name)
    if assignment and assignment.template then
      ImGui.Separator(ctx)
      ImGui.Text(ctx, "Current: " .. (assignment.template.type or "unknown"))

      if ImGui.MenuItem(ctx, "Remove Template") then
        assignment.template = nil
        view:save_assignments()
      end
    end

    ImGui.EndPopup(ctx)
  end
end

-- Render template configuration dialog (called from view's draw function)
function M.render_template_config_dialogs(ctx, view)
  -- Iterate through all open dialogs
  for param_name, is_open in pairs(M._template_config_open) do
    if is_open then
      local state = M._template_config_state[param_name]
      if not state then
        M._template_config_open[param_name] = false
        goto continue
      end

      -- Get parameter info
      local param = nil
      for _, p in ipairs(view.all_params) do
        if p.name == param_name then
          param = p
          break
        end
      end

      if not param then
        M._template_config_open[param_name] = false
        goto continue
      end

      -- Set modal size and let ImGui position it
      local modal_w, modal_h = 500, 400
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
          local to_remove = nil
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
              to_remove = i
            end

            ImGui.PopID(ctx)
          end

          if to_remove then
            table.remove(state.presets, to_remove)
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

      ::continue::
    end
  end
end

-- Render a group assignment (unified control for all templates in group)
function M.render_group(ctx, rect, item, state, view, tab_id)
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local w = x2 - x1
  local h = y2 - y1
  local dl = ImGui.GetWindowDrawList(ctx)

  local group_id = item.group_id

  -- Find the group
  local group = nil
  for _, g in ipairs(view.template_groups) do
    if g.id == group_id then
      group = g
      break
    end
  end

  if not group then
    -- Group not found, render error placeholder
    ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, hexrgb("#440000"), 3)
    ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, hexrgb("#880000"), 3, 0, 1)
    ImGui.SetCursorScreenPos(ctx, x1 + 8, y1 + 4)
    ImGui.Text(ctx, "Group not found: " .. group_id)
    return
  end

  -- Animation state
  local key = "assign_group_" .. tab_id .. "_" .. group_id
  M._anim[key] = M._anim[key] or { hover = 0 }
  local hover_t = Visuals.lerp(M._anim[key].hover, state.hover and 1 or 0, 12.0 * 0.016)
  M._anim[key].hover = hover_t

  -- Get tab color
  local tab_color = view.tab_colors[tab_id] or hexrgb("#888888")

  -- Parse group color
  local group_color = group.color
  if type(group_color) == "string" then
    group_color = hexrgb(group_color)
  end

  -- Color definitions
  local function dim_color(color, opacity)
    local r = (color >> 24) & 0xFF
    local g = (color >> 16) & 0xFF
    local b = (color >> 8) & 0xFF
    local a = math.floor(255 * opacity)
    return (r << 24) | (g << 16) | (b << 8) | a
  end

  local BG_BASE = dim_color(tab_color, 0.15)
  local BG_HOVER = dim_color(tab_color, 0.22)
  local BRD_BASE = dim_color(tab_color, 0.4)
  local BRD_HOVER = tab_color
  local ANT_COLOR = dim_color(tab_color, 0.5)

  -- Hover shadow
  if hover_t > 0.01 and not state.selected then
    Visuals.draw_hover_shadow(dl, x1, y1, x2, y2, hover_t, 3)
  end

  -- Background
  local bg_color = BG_BASE
  bg_color = Visuals.color_lerp(bg_color, BG_HOVER, hover_t * 0.5)
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, bg_color, 3)

  -- Border / Selection
  if state.selected then
    Visuals.draw_marching_ants_rounded(dl, x1 + 0.5, y1 + 0.5, x2 - 0.5, y2 - 0.5, ANT_COLOR, 1, 3)
  else
    local border_color = Visuals.color_lerp(BRD_BASE, BRD_HOVER, hover_t)
    ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, border_color, 3, 0, 1)
  end

  -- Color badge (left side)
  local badge_size = 4
  local badge_x = x1 + 8
  local badge_y = y1 + (h / 2) - (badge_size / 2)
  ImGui.DrawList_AddRectFilled(dl, badge_x, badge_y, badge_x + badge_size, badge_y + badge_size, group_color, 1)

  -- Group name
  ImGui.SetCursorScreenPos(ctx, x1 + 8 + badge_size + 6, y1 + 1)
  ImGui.AlignTextToFramePadding(ctx)

  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#CCCCCC"))
  local display_name = group.name or ("Group " .. group_id)
  if #display_name > 30 then
    display_name = display_name:sub(1, 27) .. "..."
  end
  ImGui.Text(ctx, display_name)
  ImGui.PopStyleColor(ctx)

  -- Member count
  ImGui.SameLine(ctx, 0, 8)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#666666"))
  local count = #(group.template_ids or {})
  ImGui.Text(ctx, string.format("(%d template%s)", count, count == 1 and "" or "s"))
  ImGui.PopStyleColor(ctx)

  -- Invisible button for interaction
  ImGui.SetCursorScreenPos(ctx, x1, y1)
  ImGui.InvisibleButton(ctx, "##group_tile_interact_" .. group_id .. "_" .. tab_id, w, h)

  -- Right-click context menu
  if ImGui.BeginPopupContextItem(ctx, "group_context_" .. group_id .. "_" .. tab_id) then
    if ImGui.MenuItem(ctx, "Configure Group...") then
      -- TODO: Open group configuration dialog
      -- M._group_config_open[group_id] = true
    end

    ImGui.Separator(ctx)

    if ImGui.MenuItem(ctx, "Rename Group...") then
      -- TODO: Rename dialog
    end

    if ImGui.MenuItem(ctx, "Change Color...") then
      -- TODO: Color picker
    end

    ImGui.Separator(ctx)

    if ImGui.MenuItem(ctx, "Remove from Tab") then
      view:unassign_group_from_tab(group_id, tab_id)
    end

    ImGui.EndPopup(ctx)
  end

  -- Tooltip
  if ImGui.IsItemHovered(ctx) then
    local tooltip = string.format("Group: %s\nContains %d template%s", group.name, count, count == 1 and "" or "s")

    -- List template names
    if count > 0 then
      tooltip = tooltip .. "\n\nTemplates:"
      for i, template_id in ipairs(group.template_ids) do
        local template = view.templates[template_id]
        if template then
          tooltip = tooltip .. "\n  • " .. template.name
        end
      end
    end

    ImGui.SetTooltip(ctx, tooltip)
  end
end

return M

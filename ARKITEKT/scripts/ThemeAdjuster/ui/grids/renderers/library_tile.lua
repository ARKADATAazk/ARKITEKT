-- @noindex
-- ThemeAdjuster/ui/grids/renderers/library_tile.lua
-- Renders parameter tiles in the library

local ImGui = require 'imgui' '0.10'
local Checkbox = require('rearkitekt.gui.widgets.primitives.checkbox')
local Spinner = require('rearkitekt.gui.widgets.primitives.spinner')
local Colors = require('rearkitekt.core.colors')
local Visuals = require('ThemeAdjuster.ui.grids.renderers.tile_visuals')
local ParameterLinkManager = require('ThemeAdjuster.core.parameter_link_manager')
local hexrgb = Colors.hexrgb

local M = {}

-- Animation state storage (persistent across frames)
M._anim = M._anim or {}

function M.render(ctx, rect, param, state, view)
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local w = x2 - x1
  local h = y2 - y1
  local dl = ImGui.GetWindowDrawList(ctx)

  -- Initialize metadata if needed
  if not view.custom_metadata[param.name] then
    view.custom_metadata[param.name] = {
      display_name = "",
      description = ""
    }
  end

  local metadata = view.custom_metadata[param.name]
  local assignment_count = view:get_assignment_count(param.name)

  -- Animation state (smooth transitions)
  local key = "lib_" .. param.index
  M._anim[key] = M._anim[key] or { hover = 0 }

  -- CORRECT: Grid passes state.hover and state.selected (not is_hovered/is_selected!)
  local hover_t = Visuals.lerp(M._anim[key].hover, state.hover and 1 or 0, 12.0 * 0.016)
  M._anim[key].hover = hover_t

  -- Color definitions
  local BG_BASE = hexrgb("#252525")
  local BG_ASSIGNED = hexrgb("#2A2A35")
  local BG_HOVER = hexrgb("#2D2D2D")
  local BRD_BASE = hexrgb("#333333")
  local BRD_HOVER = hexrgb("#5588FF")
  local ANT_COLOR = hexrgb("#5588FF7F")  -- 50% opacity for subtle effect

  -- Hover shadow effect (only when not selected)
  if hover_t > 0.01 and not state.selected then
    Visuals.draw_hover_shadow(dl, x1, y1, x2, y2, hover_t, 3)
  end

  -- Background color (with smooth transitions)
  local bg_color = (assignment_count > 0) and BG_ASSIGNED or BG_BASE
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

  -- Position cursor inside tile
  ImGui.SetCursorScreenPos(ctx, x1 + 4, y1 + 4)

  -- Layout: [NAME 200px] [CONTROL 120px] [NAME INPUT 140px] [DESC INPUT 140px] [BADGE]
  local name_w = 200  -- Increased from 140px to give more breathing room
  local control_w = 120
  local name_input_w = 140
  local desc_input_w = 140  -- Reduced from 180px to compensate
  local spacing = 8

  ImGui.AlignTextToFramePadding(ctx)

  -- 1. Parameter name (DRAGGABLE - truncated, with tooltip)
  local truncated_name = param.name
  if #param.name > 30 then  -- Increased from 20 to 30 characters
    truncated_name = param.name:sub(1, 27) .. "..."
  end

  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#CCCCCC"))
  ImGui.Text(ctx, truncated_name)
  ImGui.PopStyleColor(ctx)

  -- Tooltip with full technical info
  if ImGui.IsItemHovered(ctx) then
    local tooltip = string.format(
      "Parameter: %s\nType: %s\nRange: %.1f - %.1f\nDefault: %.1f\nCurrent: %.1f\n\nDrag to assign to tabs →",
      param.name,
      param.type,
      param.min,
      param.max,
      param.default,
      param.value
    )
    ImGui.SetTooltip(ctx, tooltip)
  end

  ImGui.SameLine(ctx, 0, spacing)

  -- 2. Live control (slider/spinner/checkbox)
  -- Calculate and store control rectangles BEFORE drawing (for exclusion zones)
  if not view.control_rects[param.index] then
    view.control_rects[param.index] = {}
  end
  local rects = view.control_rects[param.index]

  -- Get current cursor position to calculate control rect
  local ctrl_x, ctrl_y = ImGui.GetCursorScreenPos(ctx)
  local ctrl_h = 24  -- Standard control height
  rects[1] = {ctrl_x, ctrl_y, ctrl_x + control_w, ctrl_y + ctrl_h}

  ImGui.SetNextItemWidth(ctx, control_w)
  local changed = false
  local new_value = param.value

  if param.type == "toggle" then
    local is_checked = (param.value ~= 0)
    if Checkbox.draw_at_cursor(ctx, "", is_checked, nil, "lib_" .. param.index) then
      changed = true
      new_value = is_checked and 0 or 1
    end

  elseif param.type == "spinner" then
    local values = {}
    for i = param.min, param.max do
      table.insert(values, tostring(i))
    end

    local current_idx = math.floor(param.value - param.min + 1)
    current_idx = math.max(1, math.min(current_idx, #values))

    local changed_spinner, new_idx = Spinner.draw(
      ctx,
      "##lib_spinner_" .. param.index,
      current_idx,
      values,
      {w = control_w, h = 24}
    )

    if changed_spinner then
      changed = true
      new_value = param.min + (new_idx - 1)
    end

  elseif param.type == "slider" then
    local changed_slider, slider_value = ImGui.SliderDouble(
      ctx,
      "##lib_slider_" .. param.index,
      param.value,
      param.min,
      param.max,
      "%.1f"
    )

    if changed_slider then
      changed = true
      new_value = slider_value
    end
  end

  -- Apply parameter change
  if changed then
    local old_value = param.value

    -- Apply to this parameter
    pcall(reaper.ThemeLayout_SetParameter, param.index, new_value, true)
    param.value = new_value

    -- Propagate to linked parameters
    M.propagate_to_linked_params(param.name, old_value, new_value, param, view)

    -- Refresh all after propagation
    pcall(reaper.ThemeLayout_RefreshAll)
  end

  ImGui.SameLine(ctx, 0, spacing)

  -- 3. Name input
  -- Calculate rect before drawing
  local name_x, name_y = ImGui.GetCursorScreenPos(ctx)
  local input_h = 24
  rects[2] = {name_x, name_y, name_x + name_input_w, name_y + input_h}

  ImGui.SetNextItemWidth(ctx, name_input_w)
  local name_changed, new_name = ImGui.InputTextWithHint(ctx, "##name_" .. param.index,
    "Custom name...", metadata.display_name)
  if name_changed then
    metadata.display_name = new_name
    view:save_assignments()
  end

  ImGui.SameLine(ctx, 0, spacing)

  -- 4. Description input
  -- Calculate rect before drawing
  local desc_x, desc_y = ImGui.GetCursorScreenPos(ctx)
  rects[3] = {desc_x, desc_y, desc_x + desc_input_w, desc_y + input_h}

  ImGui.SetNextItemWidth(ctx, desc_input_w)
  local desc_changed, new_desc = ImGui.InputTextWithHint(ctx, "##desc_" .. param.index,
    "Description...", metadata.description)
  if desc_changed then
    metadata.description = new_desc
    view:save_assignments()
  end

  -- 5. Assignment badge (at the end)
  if assignment_count > 0 then
    ImGui.SameLine(ctx)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#88AAFF"))
    ImGui.Text(ctx, string.format("(%d)", assignment_count))
    ImGui.PopStyleColor(ctx)
  end
end

-- Propagate parameter changes to linked parameters
function M.propagate_to_linked_params(param_name, old_value, new_value, param, view)
  -- Get propagations from ParameterLinkManager
  local propagations = ParameterLinkManager.propagate_value_change(param_name, old_value, new_value, param)

  -- Apply each propagation
  for _, prop in ipairs(propagations) do
    local child_param_name = prop.param_name
    local child_new_value = prop.new_value

    -- Find the child parameter definition
    for _, child_param in ipairs(view.all_params) do
      if child_param.name == child_param_name then
        -- Clamp value to parameter limits for Reaper
        local clamped_value = math.max(child_param.min, math.min(child_param.max, child_new_value))

        -- Apply the change to Reaper
        pcall(reaper.ThemeLayout_SetParameter, child_param.index, clamped_value, true)

        -- Update local value
        child_param.value = clamped_value

        break
      end
    end
  end

  -- Save virtual values
  if #propagations > 0 then
    view:save_assignments()
  end
end

return M

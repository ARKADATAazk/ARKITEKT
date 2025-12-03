-- @noindex
-- panel/corner_buttons.lua
-- Corner button rendering with asymmetric rounding

local ImGui = require('arkitekt.core.imgui')
local Base = require('arkitekt.gui.widgets.base')
local CornerButton = require('arkitekt.gui.widgets.primitives.corner_button')
local ConfigUtil = require('arkitekt.core.merge')
local Rendering = require('arkitekt.gui.widgets.containers.panel.rendering')

local M = {}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

M.DEFAULTS = {
  outer_rounding = 8,
  inner_rounding = 3,
  offset_x = -1,
  offset_y = -1,
  border_thickness = 1,
  min_width_to_show = 150,
}

-- ============================================================================
-- INSTANCE MANAGEMENT (strong tables with access tracking for cleanup)
-- ============================================================================

local instances = Base.create_instance_registry()

local function create_corner_button_instance(id)
  return { hover_alpha = 0 }
end

local function get_instance(id)
  return Base.get_or_create_instance(instances, id, create_corner_button_instance, ctx)
end

-- ============================================================================
-- CORNER BUTTON POSITIONING
-- ============================================================================

local function get_button_positions(x, y, w, h, size, config)
  local border = config.border_thickness or M.DEFAULTS.border_thickness
  local offset_x = config.offset_x or M.DEFAULTS.offset_x
  local offset_y = config.offset_y or M.DEFAULTS.offset_y

  return {
    tl = { x = x + border + offset_x, y = y + border + offset_y },
    tr = { x = x + w - size - border - offset_x, y = y + border + offset_y },
    bl = { x = x + border + offset_x, y = y + h - size - border - offset_y },
    br = { x = x + w - size - border - offset_x, y = y + h - size - border - offset_y },
  }
end

-- ============================================================================
-- CORNER BUTTON RENDERING
-- ============================================================================

--- Draw all corner buttons as child windows (for proper z-order)
--- @param ctx userdata ImGui context
--- @param x number Panel X
--- @param y number Panel Y
--- @param w number Panel width
--- @param h number Panel height
--- @param config table Panel config
--- @param panel_id string Panel ID
function M.Draw(ctx, x, y, w, h, config, panel_id)
  local cb_config = config.corner_buttons
  if not cb_config then return end

  -- Responsive hiding
  local min_width = cb_config.min_width_to_show or M.DEFAULTS.min_width_to_show
  if w < min_width then return end

  local size = cb_config.size or 30
  local outer_rounding = config.rounding or M.DEFAULTS.outer_rounding
  local inner_rounding = cb_config.inner_rounding or M.DEFAULTS.inner_rounding

  -- Calculate positions
  local positions = get_button_positions(x, y, w, h, size, {
    border_thickness = M.DEFAULTS.border_thickness,
    offset_x = M.DEFAULTS.offset_x,
    offset_y = M.DEFAULTS.offset_y,
  })

  -- Setup clipping to panel bounds
  local dl = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_PushClipRect(dl, x, y, x + w, y + h, true)

  -- Track drawn buttons for edge border rendering
  local buttons_drawn = {}

  -- Helper: Create a corner button as a child window
  local function create_button_child(button_config, position_key)
    if not button_config then return end

    local pos = positions[position_key]
    local btn_x, btn_y = pos.x, pos.y

    buttons_drawn[#buttons_drawn + 1] = { x = btn_x, y = btn_y, w = size, h = size }

    -- Create child window for proper z-order (above grid content, below popups)
    ImGui.SetCursorScreenPos(ctx, btn_x, btn_y)

    local child_flags = ImGui.WindowFlags_NoScrollbar |
                       ImGui.WindowFlags_NoScrollWithMouse |
                       ImGui.WindowFlags_NoBackground

    local child_id = panel_id .. '_corner_' .. position_key
    if ImGui.BeginChild(ctx, child_id, size, size, ImGui.ChildFlags_None, child_flags) then
      local child_dl = ImGui.GetWindowDrawList(ctx)

      -- Merge button config
      local opts = ConfigUtil.merge_safe(button_config, {})
      opts.id = child_id
      opts.draw_list = child_dl
      opts.x = btn_x
      opts.y = btn_y
      opts.size = size
      opts.outer_rounding = outer_rounding
      opts.inner_rounding = inner_rounding
      opts.position = position_key

      CornerButton.Draw(ctx, opts)

      -- Inform ImGui of bounds
      ImGui.Dummy(ctx, size, size)
      ImGui.EndChild(ctx)
    end
  end

  -- Draw all corner buttons
  if cb_config.top_left then create_button_child(cb_config.top_left, 'tl') end
  if cb_config.top_right then create_button_child(cb_config.top_right, 'tr') end
  if cb_config.bottom_left then create_button_child(cb_config.bottom_left, 'bl') end
  if cb_config.bottom_right then create_button_child(cb_config.bottom_right, 'br') end

  -- Draw edge borders for buttons extending beyond panel
  local border_color = 0x000000FF
  for _, btn in ipairs(buttons_drawn) do
    if btn.x < x then
      ImGui.DrawList_AddLine(dl, x, btn.y, x, btn.y + btn.h, border_color, 1)
    end
    if btn.x + btn.w > x + w then
      ImGui.DrawList_AddLine(dl, x + w, btn.y, x + w, btn.y + btn.h, border_color, 1)
    end
    if btn.y < y then
      ImGui.DrawList_AddLine(dl, btn.x, y, btn.x + btn.w, y, border_color, 1)
    end
    if btn.y + btn.h > y + h then
      ImGui.DrawList_AddLine(dl, btn.x, y + h, btn.x + btn.w, y + h, border_color, 1)
    end
  end

  ImGui.DrawList_PopClipRect(dl)
end

return M

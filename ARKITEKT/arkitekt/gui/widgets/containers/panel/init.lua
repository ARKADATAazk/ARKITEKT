-- @noindex
-- Arkitekt/gui/widgets/panel/init.lua
-- Main panel API with header positioning and corner buttons support
-- Fixed: Push unique ID scope for entire panel

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Header = require('arkitekt.gui.widgets.containers.panel.header')
local Content = require('arkitekt.gui.widgets.containers.panel.content')
local Background = require('arkitekt.gui.widgets.containers.panel.background')
local TabAnimator = require('arkitekt.gui.widgets.containers.panel.tab_animator')
local Scrollbar = require('arkitekt.gui.widgets.primitives.scrollbar')
local Button = require('arkitekt.gui.widgets.primitives.button')
local CornerButton = require('arkitekt.gui.widgets.primitives.corner_button')
local PanelConfig = require('arkitekt.gui.widgets.containers.panel.defaults')
local ConfigUtil = require('arkitekt.core.config')

local M = {}
local DEFAULTS = PanelConfig.DEFAULTS

local panel_id_counter = 0

local function generate_unique_id(prefix)
  panel_id_counter = panel_id_counter + 1
  return string.format("%s_%d", prefix or "panel", panel_id_counter)
end

local Panel = {}
Panel.__index = Panel

function M.new(opts)
  opts = opts or {}
  
  local id = opts.id or generate_unique_id("panel")
  
  local panel = setmetatable({
    id = id,
    _panel_id = id,  -- CRITICAL: Required for header elements to detect panel context
    config = ConfigUtil.deepMerge(DEFAULTS, opts.config),
    
    width = opts.width,
    height = opts.height,
    
    had_scrollbar_last_frame = false,
    last_content_height = 0,
    scrollbar_size = 0,
    scrollbar = nil,
    actual_child_height = 0,
    child_width = 0,
    child_height = 0,
    child_x = 0,
    child_y = 0,
    
    tabs = {},
    active_tab_id = nil,
    
    _overflow_visible = false,
    _child_began_successfully = false,
    _id_scope_pushed = false,
    
    current_mode = nil,
    
    header_height = 0,
    visible_bounds = nil,
  }, Panel)
  
  if panel.config.scroll.custom_scrollbar then
    panel.scrollbar = Scrollbar.new({
      id = panel.id .. "_scrollbar",
      config = panel.config.scroll.scrollbar_config,
      on_scroll = function(scroll_pos)
      end,
    })
  end
  
  return panel
end

function Panel:get_effective_child_width(ctx, base_width)
  local anti_jitter = self.config.anti_jitter or DEFAULTS.anti_jitter
  
  if not anti_jitter.enabled or not anti_jitter.track_scrollbar then
    return base_width
  end
  
  if self.scrollbar_size == 0 then
    self.scrollbar_size = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ScrollbarSize) or 14
  end
  
  if self.had_scrollbar_last_frame then
    return base_width - self.scrollbar_size
  end
  
  return base_width
end

-- ============================================================================
-- CUSTOM CORNER ROUNDING (PATH-BASED WITH HIGH QUALITY)
-- ============================================================================

local function snap_pixel(v)
  return math.floor(v + 0.5)
end

local function draw_rounded_rect_path(dl, x1, y1, x2, y2, color, filled, rounding_tl, rounding_tr, rounding_br, rounding_bl, thickness)
  -- Snap to pixel boundaries
  x1 = snap_pixel(x1)
  y1 = snap_pixel(y1)
  x2 = snap_pixel(x2)
  y2 = snap_pixel(y2)
  
  -- For 1px strokes, offset by 0.5 for crisp rendering
  if not filled and thickness == 1 then
    x1 = x1 + 0.5
    y1 = y1 + 0.5
    x2 = x2 - 0.5
    y2 = y2 - 0.5
  end
  
  local w = x2 - x1
  local h = y2 - y1
  
  local max_rounding = math.min(w, h) * 0.5
  rounding_tl = math.min(rounding_tl or 0, max_rounding)
  rounding_tr = math.min(rounding_tr or 0, max_rounding)
  rounding_br = math.min(rounding_br or 0, max_rounding)
  rounding_bl = math.min(rounding_bl or 0, max_rounding)
  
  local function get_segments(r)
    if r <= 0 then return 0 end
    return math.max(4, math.floor(r * 0.6))
  end
  
  ImGui.DrawList_PathClear(dl)
  
  -- Top-left
  if rounding_tl > 0 then
    ImGui.DrawList_PathArcTo(dl, x1 + rounding_tl, y1 + rounding_tl, rounding_tl, 
                             math.pi, math.pi * 1.5, get_segments(rounding_tl))
  else
    ImGui.DrawList_PathLineTo(dl, x1, y1)
  end
  
  -- Top-right
  if rounding_tr > 0 then
    ImGui.DrawList_PathArcTo(dl, x2 - rounding_tr, y1 + rounding_tr, rounding_tr, 
                             math.pi * 1.5, math.pi * 2.0, get_segments(rounding_tr))
  else
    ImGui.DrawList_PathLineTo(dl, x2, y1)
  end
  
  -- Bottom-right
  if rounding_br > 0 then
    ImGui.DrawList_PathArcTo(dl, x2 - rounding_br, y2 - rounding_br, rounding_br, 
                             0, math.pi * 0.5, get_segments(rounding_br))
  else
    ImGui.DrawList_PathLineTo(dl, x2, y2)
  end
  
  -- Bottom-left
  if rounding_bl > 0 then
    ImGui.DrawList_PathArcTo(dl, x1 + rounding_bl, y2 - rounding_bl, rounding_bl, 
                             math.pi * 0.5, math.pi, get_segments(rounding_bl))
  else
    ImGui.DrawList_PathLineTo(dl, x1, y2)
  end
  
  if filled then
    ImGui.DrawList_PathFillConvex(dl, color)
  else
    ImGui.DrawList_PathStroke(dl, color, ImGui.DrawFlags_Closed, thickness or 1)
  end
end

local function draw_corner_button_shape(dl, x, y, size, bg_color, border_inner, border_outer, 
                                        outer_rounding, inner_rounding, position)
  -- Determine which corners get which rounding
  local rounding_tl, rounding_tr, rounding_br, rounding_bl = 0, 0, 0, 0
  
  if position == "tl" then
    rounding_tl = outer_rounding
    rounding_br = inner_rounding
  elseif position == "tr" then
    rounding_tr = outer_rounding
    rounding_bl = inner_rounding
  elseif position == "bl" then
    rounding_bl = outer_rounding
    rounding_tr = inner_rounding
  elseif position == "br" then
    rounding_br = outer_rounding
    rounding_tl = inner_rounding
  end
  
  -- Inner rounding (for background/borders)
  local inner_tl = math.max(0, rounding_tl - 2)
  local inner_tr = math.max(0, rounding_tr - 2)
  local inner_br = math.max(0, rounding_br - 2)
  local inner_bl = math.max(0, rounding_bl - 2)
  
  -- Background
  draw_rounded_rect_path(dl, x, y, x + size, y + size, bg_color, true,
                         inner_tl, inner_tr, inner_br, inner_bl)
  
  -- Inner border
  draw_rounded_rect_path(dl, x + 1, y + 1, x + size - 1, y + size - 1, border_inner, false,
                         inner_tl, inner_tr, inner_br, inner_bl, 1)
  
  -- Outer border
  draw_rounded_rect_path(dl, x, y, x + size, y + size, border_outer, false,
                         inner_tl, inner_tr, inner_br, inner_bl, 1)
end

-- ============================================================================
-- CORNER BUTTONS - CONFIGURATION
-- ============================================================================

local CORNER_BUTTON_CONFIG = {
  -- Rounding for corner touching panel edge (usually matches panel rounding)
  outer_corner_rounding = 8,  -- Adjust to match panel corner
  
  -- Rounding for opposite corner (pointing inward, usually circular)
  inner_corner_rounding_multiplier = 0.5,  -- Multiplied by button size (0.5 = circular)
  
  -- Position offset from panel edge (positive = outward)
  position_offset_x = -1,
  position_offset_y = -1,
}

-- ============================================================================
-- CORNER BUTTONS
-- ============================================================================

-- Corner button rounding configuration
local CORNER_BUTTON_OUTER_ROUNDING_OFFSET = 0  -- Adjust outer corner (0 = match panel, -2 = tighter fit)
local CORNER_BUTTON_INNER_ROUNDING_FACTOR = 0.5  -- Inner corner radius (0.5 = circular, lower = less round)

-- Instance storage for corner button animations
local corner_button_instances = {}

local function get_corner_button_instance(id)
  if not corner_button_instances[id] then
    corner_button_instances[id] = { hover_alpha = 0 }
  end
  return corner_button_instances[id]
end

-- Corner button rendering is delegated to controls.corner_button
-- (draw_corner_button_custom removed)

-- Draws corner buttons using the provided draw list
-- Called at the end of panel draw cycle to render above content but below modals
local function draw_corner_buttons_foreground(ctx, dl, x, y, w, h, config, panel_id, panel_rounding)
  if not config.corner_buttons then return end

  local cb = config.corner_buttons
  local size = cb.size or 30
  local border_thickness = 1

  -- Responsive: Hide corner buttons if panel is too narrow
  local min_width = cb.min_width_to_show or 150
  if w < min_width then
    return
  end

  -- Apply clipping to prevent corner buttons from overflowing panel bounds
  ImGui.DrawList_PushClipRect(dl, x, y, x + w, y + h, true)

  -- Get rounding from config
  local outer_rounding = config.rounding or CORNER_BUTTON_CONFIG.outer_corner_rounding
  -- Inner rounding is configurable separately
  local inner_rounding = cb.inner_rounding or 3

  -- Get position offsets
  local offset_x = CORNER_BUTTON_CONFIG.position_offset_x
  local offset_y = CORNER_BUTTON_CONFIG.position_offset_y

  -- Helper: Draw rounded rect path with asymmetric corners
  local function draw_rounded_rect_path(x1, y1, x2, y2, color, filled, rt, rr, rb, rl, thickness)
    local function snap_pixel(v)
      return math.floor(v + 0.5)
    end

    x1 = snap_pixel(x1)
    y1 = snap_pixel(y1)
    x2 = snap_pixel(x2)
    y2 = snap_pixel(y2)

    if not filled and thickness == 1 then
      x1 = x1 + 0.5
      y1 = y1 + 0.5
      x2 = x2 - 0.5
      y2 = y2 - 0.5
    end

    local w = x2 - x1
    local h = y2 - y1
    local max_r = math.min(w, h) * 0.5
    rt = math.min(rt or 0, max_r)
    rr = math.min(rr or 0, max_r)
    rb = math.min(rb or 0, max_r)
    rl = math.min(rl or 0, max_r)

    local function segs(r)
      if r <= 0 then return 0 end
      return math.max(4, math.floor(r * 0.6))
    end

    ImGui.DrawList_PathClear(dl)

    -- Top-left corner
    if rt > 0 then
      ImGui.DrawList_PathArcTo(dl, x1 + rt, y1 + rt, rt, math.pi, math.pi * 1.5, segs(rt))
    else
      ImGui.DrawList_PathLineTo(dl, x1, y1)
    end

    -- Top-right corner
    if rr > 0 then
      ImGui.DrawList_PathArcTo(dl, x2 - rr, y1 + rr, rr, math.pi * 1.5, math.pi * 2.0, segs(rr))
    else
      ImGui.DrawList_PathLineTo(dl, x2, y1)
    end

    -- Bottom-right corner
    if rb > 0 then
      ImGui.DrawList_PathArcTo(dl, x2 - rb, y2 - rb, rb, 0, math.pi * 0.5, segs(rb))
    else
      ImGui.DrawList_PathLineTo(dl, x2, y2)
    end

    -- Bottom-left corner
    if rl > 0 then
      ImGui.DrawList_PathArcTo(dl, x1 + rl, y2 - rl, rl, math.pi * 0.5, math.pi, segs(rl))
    else
      ImGui.DrawList_PathLineTo(dl, x1, y2)
    end

    if filled then
      ImGui.DrawList_PathFillConvex(dl, color)
    else
      ImGui.DrawList_PathStroke(dl, color, ImGui.DrawFlags_Closed, thickness or 1)
    end
  end

  -- Helper to draw a single corner button on foreground
  local function draw_button(position, button_config, btn_x, btn_y, unique_id)
    if not button_config then return end

    -- Draw visuals on foreground
    local Style = require('arkitekt.gui.style.defaults')
    local inst = get_corner_button_instance(unique_id)

    -- Apply style defaults
    local cfg = Style.apply_defaults(Style.BUTTON, button_config)

    local is_blocking = cfg.is_blocking or false
    local hovered = false
    local active = false

    if not is_blocking then
      hovered = ImGui.IsMouseHoveringRect(ctx, btn_x, btn_y, btn_x + size, btn_y + size)
      active = hovered and ImGui.IsMouseDown(ctx, 0)
    end

    local dt = ImGui.GetDeltaTime(ctx)
    local target = (hovered or active) and 1.0 or 0.0

    -- Reset hover alpha immediately when blocking (don't animate)
    if is_blocking then
      inst.hover_alpha = 0
    else
      inst.hover_alpha = inst.hover_alpha + (target - inst.hover_alpha) * 12.0 * dt
      inst.hover_alpha = math.max(0, math.min(1, inst.hover_alpha))
    end

    local bg = cfg.bg_color
    local border_inner = cfg.border_inner_color
    local text = cfg.text_color

    if active then
      bg = cfg.bg_active_color or bg
      border_inner = cfg.border_active_color or border_inner
      text = cfg.text_active_color or text
    elseif inst.hover_alpha > 0.01 then
      bg = Style.RENDER.lerp_color(cfg.bg_color, cfg.bg_hover_color or cfg.bg_color, inst.hover_alpha)
      border_inner = Style.RENDER.lerp_color(cfg.border_inner_color, cfg.border_hover_color or cfg.border_inner_color, inst.hover_alpha)
      text = Style.RENDER.lerp_color(cfg.text_color, cfg.text_hover_color or cfg.text_color, inst.hover_alpha)
    end

    -- Determine corner-specific rounding (asymmetric)
    local rtl, rtr, rbr, rbl = 0, 0, 0, 0
    if position == 'tl' then
      rtl = outer_rounding; rbr = inner_rounding
    elseif position == 'tr' then
      rtr = outer_rounding; rbl = inner_rounding
    elseif position == 'bl' then
      rbl = outer_rounding; rtr = inner_rounding
    elseif position == 'br' then
      rbr = outer_rounding; rtl = inner_rounding
    end

    local itl = math.max(0, rtl - 2)
    local itr = math.max(0, rtr - 2)
    local ibr = math.max(0, rbr - 2)
    local ibl = math.max(0, rbl - 2)

    -- Draw corner shape with proper asymmetric rounding using path-based drawing
    draw_rounded_rect_path(btn_x, btn_y, btn_x + size, btn_y + size, bg, true, itl, itr, ibr, ibl)
    draw_rounded_rect_path(btn_x + 1, btn_y + 1, btn_x + size - 1, btn_y + size - 1, border_inner, false, itl, itr, ibr, ibl, 1)
    draw_rounded_rect_path(btn_x, btn_y, btn_x + size, btn_y + size, cfg.border_outer_color, false, itl, itr, ibr, ibl, 1)

    -- Support custom_draw callback (for icons drawn with primitives)
    if cfg.custom_draw then
      cfg.custom_draw(ctx, dl, btn_x, btn_y, size, size, hovered, active, text)
    else
      -- Draw icon/label
      local label = cfg.icon or cfg.label or ''
      if label ~= '' then
        -- Push icon font if available (must be active during DrawList call)
        -- PushFont requires 3 parameters: ctx, font, size
        local use_icon_font = (cb.icon_font and cb.icon_font ~= 0 and cb.icon_font ~= nil and cb.icon_font_size)
        if use_icon_font then
          ImGui.PushFont(ctx, cb.icon_font, cb.icon_font_size)
        end

        -- Calculate size and position with active font
        local tw, th = ImGui.CalcTextSize(ctx, label)
        local tx = btn_x + (size - tw) * 0.5
        local ty = btn_y + (size - th) * 0.5

        -- Draw with currently active font (from font stack)
        ImGui.DrawList_AddText(dl, tx, ty, text, label)

        -- Pop icon font after drawing
        if use_icon_font then
          ImGui.PopFont(ctx)
        end
      end
    end

    -- Only allow interaction if not blocking
    if not is_blocking then
      -- Click detection (manual for foreground)
      if hovered and ImGui.IsMouseClicked(ctx, 0) and cfg.on_click then
        cfg.on_click()
      end

      if hovered and cfg.tooltip then
        ImGui.SetTooltip(ctx, cfg.tooltip)
      end
    end
  end

  -- Draw each corner button
  local buttons_drawn = {}

  if cb.top_left then
    local btn_x = x + border_thickness + offset_x
    local btn_y = y + border_thickness + offset_y
    draw_button('tl', cb.top_left, btn_x, btn_y, panel_id .. "_corner_tl")
    buttons_drawn[#buttons_drawn + 1] = {x = btn_x, y = btn_y, w = size, h = size}
  end

  if cb.top_right then
    local btn_x = x + w - size - border_thickness - offset_x
    local btn_y = y + border_thickness + offset_y
    draw_button('tr', cb.top_right, btn_x, btn_y, panel_id .. "_corner_tr")
    buttons_drawn[#buttons_drawn + 1] = {x = btn_x, y = btn_y, w = size, h = size}
  end

  if cb.bottom_left then
    local btn_x = x + border_thickness + offset_x
    local btn_y = y + h - size - border_thickness - offset_y
    draw_button('bl', cb.bottom_left, btn_x, btn_y, panel_id .. "_corner_bl")
    buttons_drawn[#buttons_drawn + 1] = {x = btn_x, y = btn_y, w = size, h = size}
  end

  if cb.bottom_right then
    local btn_x = x + w - size - border_thickness - offset_x
    local btn_y = y + h - size - border_thickness - offset_y
    draw_button('br', cb.bottom_right, btn_x, btn_y, panel_id .. "_corner_br")
    buttons_drawn[#buttons_drawn + 1] = {x = btn_x, y = btn_y, w = size, h = size}
  end

  -- Draw clip edge borders for any button that extends beyond panel bounds
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

local function draw_corner_buttons(ctx, dl, x, y, w, h, config, panel_id, panel_rounding)
  if not config.corner_buttons then return end

  local cb = config.corner_buttons
  local size = cb.size or 30
  local border_thickness = 1

  -- Responsive: Hide corner buttons if panel is too narrow
  -- Default minimum width: 2 buttons + margins (150px gives good spacing)
  local min_width = cb.min_width_to_show or 150
  if w < min_width then
    return
  end

  -- Get rounding from config
  local outer_rounding = config.rounding or CORNER_BUTTON_CONFIG.outer_corner_rounding
  -- Inner rounding is configurable separately
  local inner_rounding = cb.inner_rounding or 3

  -- Get position offsets
  local offset_x = CORNER_BUTTON_CONFIG.position_offset_x
  local offset_y = CORNER_BUTTON_CONFIG.position_offset_y

  -- Top-left
  if cb.top_left then
    local btn_x = x + border_thickness + offset_x
    local btn_y = y + border_thickness + offset_y
    CornerButton.draw(ctx, dl, btn_x, btn_y, size, cb.top_left, panel_id .. "_corner_tl", outer_rounding, inner_rounding, "tl")
  end

  -- Top-right
  if cb.top_right then
    local btn_x = x + w - size - border_thickness - offset_x
    local btn_y = y + border_thickness + offset_y
    CornerButton.draw(ctx, dl, btn_x, btn_y, size, cb.top_right, panel_id .. "_corner_tr", outer_rounding, inner_rounding, "tr")
  end

  -- Bottom-left
  if cb.bottom_left then
    local btn_x = x + border_thickness + offset_x
    local btn_y = y + h - size - border_thickness - offset_y
    CornerButton.draw(ctx, dl, btn_x, btn_y, size, cb.bottom_left, panel_id .. "_corner_bl", outer_rounding, inner_rounding, "bl")
  end

  -- Bottom-right
  if cb.bottom_right then
    local btn_x = x + w - size - border_thickness - offset_x
    local btn_y = y + h - size - border_thickness - offset_y
    CornerButton.draw(ctx, dl, btn_x, btn_y, size, cb.bottom_right, panel_id .. "_corner_br", outer_rounding, inner_rounding, "br")
  end
end

-- ============================================================================
-- SIDEBAR RENDERING
-- ============================================================================

local function draw_sidebar(ctx, dl, x, y, width, height, sidebar_cfg, panel_id, side)
  if not sidebar_cfg or not sidebar_cfg.enabled then return 0 end

  local elements = sidebar_cfg.elements or {}
  if #elements == 0 then return width end

  local btn_height = sidebar_cfg.button_size or 28
  local btn_width = math.floor(btn_height * 0.7)  -- 30% narrower
  local rounding = sidebar_cfg.rounding or 8  -- Larger default rounding

  -- Extra height for first/last buttons to accommodate rounding
  local corner_extension = rounding

  -- Calculate total buttons height with 1px overlap and corner extensions
  local total_btn_height = (#elements * btn_height) - (#elements - 1) + (corner_extension * 2)

  -- Calculate start Y based on valign (no padding)
  local start_y
  local valign = sidebar_cfg.valign or "center"
  if valign == "top" then
    start_y = y
  elseif valign == "bottom" then
    start_y = y + height - total_btn_height
  else -- center
    start_y = y + (height - total_btn_height) / 2
  end

  -- Position buttons at panel edge
  local btn_x
  if side == "left" then
    btn_x = x
  else -- right
    btn_x = x + width - btn_width
  end

  -- Draw each button
  for i, element in ipairs(elements) do
    local is_first = (i == 1)
    local is_last = (i == #elements)

    -- Calculate button position and size
    local btn_y = start_y + corner_extension + (i - 1) * (btn_height - 1)
    local current_btn_height = btn_height

    -- Extend first button upward for top rounding
    if is_first then
      btn_y = btn_y - corner_extension
      current_btn_height = current_btn_height + corner_extension
    end

    -- Extend last button downward for bottom rounding
    if is_last then
      current_btn_height = current_btn_height + corner_extension
    end

    local btn_id = panel_id .. "_sidebar_" .. side .. "_" .. (element.id or i)

    -- Round outer corners only (away from panel edge)
    -- Left sidebar: round right corners, Right sidebar: round left corners
    local corner_rounding
    if side == "left" then
      corner_rounding = {
        round_top_left = false,
        round_top_right = is_first,
        round_bottom_left = false,
        round_bottom_right = is_last,
        rounding = rounding,
      }
    else -- right
      corner_rounding = {
        round_top_left = is_first,
        round_top_right = false,
        round_bottom_left = is_last,
        round_bottom_right = false,
        rounding = rounding,
      }
    end

    -- Merge element config with defaults
    local btn_config = ConfigUtil.merge_safe(element.config or {}, PanelConfig.ELEMENT_STYLE.button)
    btn_config.id = btn_id
    btn_config.corner_rounding = corner_rounding

    -- Draw the button with panel context
    Button.draw(ctx, dl, btn_x, btn_y, btn_width, current_btn_height, btn_config, { _panel_id = panel_id })
  end

  return width
end

-- ============================================================================
-- MAIN RENDERING
-- ============================================================================

function Panel:begin_draw(ctx)
  -- Push unique ID scope for entire panel
  ImGui.PushID(ctx, self.id)
  self._id_scope_pushed = true

  local dt = ImGui.GetDeltaTime(ctx)
  self:update(dt)

  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)
  local w = self.width or avail_w
  local h = self.height or avail_h

  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)

  local x1, y1 = cursor_x, cursor_y
  local x2, y2 = x1 + w, y1 + h
  
  -- Draw panel background
  ImGui.DrawList_AddRectFilled(
    dl, x1, y1, x2, y2,
    self.config.bg_color,
    self.config.rounding
  )
  
  -- Header and footer configuration (dual toolbar support)
  local header_cfg = self.config.header or DEFAULTS.header
  local footer_cfg = self.config.footer

  local header_height = 0
  local footer_height = 0
  local content_y1 = y1
  local content_y2 = y2

  -- Draw header at top if enabled (unless explicitly positioned at bottom)
  if header_cfg.enabled then
    header_height = header_cfg.height or 30
    local header_position = header_cfg.position or "top"

    if header_position == "top" then
      Header.draw(ctx, dl, x1, y1, w, header_height, self, self.config, self.config.rounding)
      content_y1 = y1 + header_height
    elseif header_position == "bottom" then
      -- Header at bottom (when no footer exists)
      Header.draw(ctx, dl, x1, y2 - header_height, w, header_height, self, self.config, self.config.rounding)
      content_y2 = y2 - header_height
    end
  end

  -- Draw footer at bottom if enabled (always at bottom, independent of header)
  if footer_cfg and footer_cfg.enabled then
    footer_height = footer_cfg.height or 30
    -- Ensure footer has position="bottom" for proper corner rounding
    footer_cfg.position = "bottom"
    -- Temporarily swap footer into header position for rendering
    local saved_header = self.config.header
    self.config.header = footer_cfg
    Header.draw(ctx, dl, x1, y2 - footer_height, w, footer_height, self, self.config, self.config.rounding)
    self.config.header = saved_header
    content_y2 = content_y2 - footer_height
  end

  self.header_height = header_height
  self.footer_height = footer_height

  -- Draw background pattern (smart header detection: only draw under header if it's transparent)
  -- Apply clipping to respect rounded corners and border insets
  if self.config.background_pattern and self.config.background_pattern.enabled then
    local border_inset = self.config.border_thickness
    local pattern_x1 = x1 + border_inset
    local pattern_x2 = x2 - border_inset

    -- Check if header background is transparent (alpha < 0.1)
    local header_is_transparent = false
    if header_cfg.enabled and header_cfg.bg_color then
      local alpha = (header_cfg.bg_color & 0xFF) / 255.0
      header_is_transparent = alpha < 0.1
    end

    -- If header is transparent, draw pattern across full panel; otherwise skip header area
    local pattern_y1, pattern_y2
    if header_is_transparent then
      pattern_y1 = y1 + border_inset  -- Full panel top
      pattern_y2 = y2 - border_inset  -- Full panel bottom
    else
      pattern_y1 = content_y1 + border_inset  -- Below header
      pattern_y2 = content_y2 - border_inset  -- Content area only
    end

    -- Push clip rect with rounded corners to prevent bleeding
    local clip_rounding = math.max(0, self.config.rounding - border_inset)
    ImGui.DrawList_PushClipRect(dl, pattern_x1, pattern_y1, pattern_x2, pattern_y2, true)

    Background.draw(ctx, dl, pattern_x1, pattern_y1, pattern_x2, pattern_y2, self.config.background_pattern)

    ImGui.DrawList_PopClipRect(dl)
  end
  
  -- Draw panel border
  if self.config.border_thickness > 0 then
    ImGui.DrawList_AddRect(
      dl,
      x1, y1,
      x2, y2,
      self.config.border_color,
      self.config.rounding,
      0,
      self.config.border_thickness
    )
  end
  
  -- Draw header elements on top
  if header_cfg.enabled then
    local header_position = header_cfg.position or "top"
    if header_position == "top" then
      Header.draw_elements(ctx, dl, x1, y1, w, header_height, self, self.config)
    elseif header_position == "bottom" then
      Header.draw_elements(ctx, dl, x1, y2 - header_height, w, header_height, self, self.config)
    end
  end

  -- Draw footer elements if enabled
  if footer_cfg and footer_cfg.enabled then
    -- Temporarily swap footer into header position for rendering
    local saved_header = self.config.header
    self.config.header = footer_cfg
    Header.draw_elements(ctx, dl, x1, y2 - footer_height, w, footer_height, self, self.config)
    self.config.header = saved_header
  end

  -- Draw sidebars
  local left_sidebar_width = 0
  local right_sidebar_width = 0
  local sidebar_height = content_y2 - content_y1

  local left_sidebar_cfg = self.config.left_sidebar
  if left_sidebar_cfg and left_sidebar_cfg.enabled then
    left_sidebar_width = left_sidebar_cfg.width or 36
    draw_sidebar(ctx, dl, x1, content_y1, left_sidebar_width, sidebar_height, left_sidebar_cfg, self.id, "left")
  end

  local right_sidebar_cfg = self.config.right_sidebar
  if right_sidebar_cfg and right_sidebar_cfg.enabled then
    right_sidebar_width = right_sidebar_cfg.width or 36
    draw_sidebar(ctx, dl, x2 - right_sidebar_width, content_y1, right_sidebar_width, sidebar_height, right_sidebar_cfg, self.id, "right")
  end

  -- Store panel bounds for corner buttons (drawn later in end_draw to be on top)
  self._corner_button_bounds = {x1, y1, w, h}

  -- Calculate content area (accounting for sidebars)
  local border_inset = self.config.border_thickness
  local child_x = x1 + border_inset + left_sidebar_width
  local child_y = content_y1 + border_inset

  self.child_x = child_x
  self.child_y = child_y

  local scrollbar_width = 0
  if self.scrollbar then
    scrollbar_width = self.config.scroll.scrollbar_config.width
  end

  ImGui.SetCursorScreenPos(ctx, child_x, child_y)

  local child_w = w - (border_inset * 2) - scrollbar_width - left_sidebar_width - right_sidebar_width
  local child_h = (content_y2 - content_y1) - (border_inset * 2)
  
  if child_w < 1 then child_w = 1 end
  if child_h < 1 then child_h = 1 end
  
  self.child_width = child_w
  self.child_height = child_h
  self.actual_child_height = child_h
  
  local scroll_config = self.config.scroll
  if self.config.disable_window_drag then
    local flags = scroll_config.flags or 0
    if ImGui.WindowFlags_NoMove then
      flags = flags | ImGui.WindowFlags_NoMove
    end
    scroll_config = {
      flags = flags,
      bg_color = scroll_config.bg_color,
    }
  end

  -- Apply padding as window padding style (affects all content, not just first item)
  local padding = self.config.padding or 0
  if padding > 0 then
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, padding, padding)
  end

  -- Pass self (container) to begin_child for state tracking
  local success = Content.begin_child(ctx, self.id, child_w, child_h, scroll_config, self)

  -- Pop padding style immediately after BeginChild (it only affects window creation)
  if padding > 0 then
    ImGui.PopStyleVar(ctx)
  end

  if success then
    local win_x, win_y = ImGui.GetWindowPos(ctx)
    local win_w, win_h = ImGui.GetWindowSize(ctx)
    self.visible_bounds = {win_x, win_y, win_x + win_w, win_y + win_h}
  end

  return success
end

function Panel:end_draw(ctx)
  -- Only process if child began successfully
  if self._child_began_successfully then
    local content_height = ImGui.GetCursorPosY(ctx)
    local scroll_y = ImGui.GetScrollY(ctx)
    local scroll_max_y = ImGui.GetScrollMaxY(ctx)

    if self.scrollbar then
      self.scrollbar:set_content_height(content_height)
      self.scrollbar:set_visible_height(self.child_height)
      self.scrollbar:set_scroll_pos(scroll_y)

      if self.scrollbar.is_dragging then
        ImGui.SetScrollY(ctx, self.scrollbar:get_scroll_pos())
      end
    end

    Content.end_child(ctx, self)

    if self.scrollbar and self.scrollbar:is_scrollable() then
      local scrollbar_x = self.child_x + self.child_width - self.config.scroll.scrollbar_config.width
      local scrollbar_y = self.child_y

      self.scrollbar:draw(ctx, scrollbar_x, scrollbar_y, self.child_height)
    end
  end

  -- CRITICAL: Corner button z-order fix
  -- ImGui render order: parent drawlist < child windows < popups < foreground drawlist
  -- Problem: We need buttons between child (tiles) and popups (menus)
  -- Solution: Each corner button is its own child window created AFTER the grid child
  -- This ensures: grid child < button children < popup windows
  if self._corner_button_bounds then
    local header_cfg = self.config.header
    if not header_cfg.enabled or self.config.corner_buttons_always_visible then
      local x1, y1, w, h = table.unpack(self._corner_button_bounds)
      local cb = self.config.corner_buttons
      if cb then
        local size = cb.size or 30
      local border_thickness = 1
      local outer_rounding = self.config.rounding or CORNER_BUTTON_CONFIG.outer_corner_rounding
      -- Inner rounding is configurable separately
      local inner_rounding = cb.inner_rounding or 3
      local offset_x = CORNER_BUTTON_CONFIG.position_offset_x
      local offset_y = CORNER_BUTTON_CONFIG.position_offset_y
      local panel_id = self.id

      -- Apply clipping to prevent corner buttons from overflowing panel bounds
      local dl = ImGui.GetWindowDrawList(ctx)
      ImGui.DrawList_PushClipRect(dl, x1, y1, x1 + w, y1 + h, true)

      -- Track button positions for clip edge border detection
      local buttons_drawn = {}

      -- Create each corner button as its own child window
      -- These child windows are created AFTER the grid child, so they render on top
      -- But popups still render above these child windows

      local function create_corner_button_child(btn_config, btn_x, btn_y, position, suffix)
        if not btn_config then return end

        -- Track button position for clipping detection
        buttons_drawn[#buttons_drawn + 1] = {x = btn_x, y = btn_y, w = size, h = size}

        -- Position the child window at the button location
        ImGui.SetCursorScreenPos(ctx, btn_x, btn_y)

        -- Create transparent, clickable child window
        local child_flags = ImGui.WindowFlags_NoScrollbar |
                           ImGui.WindowFlags_NoScrollWithMouse |
                           ImGui.WindowFlags_NoBackground

        if ImGui.BeginChild(ctx, panel_id .. "_corner_" .. suffix, size, size, ImGui.ChildFlags_None, child_flags) then
          local dl = ImGui.GetWindowDrawList(ctx)
          -- Draw the corner button at its position
          CornerButton.draw(ctx, dl, btn_x, btn_y, size, btn_config, panel_id .. "_corner_" .. suffix, outer_rounding, inner_rounding, position)
          ImGui.EndChild(ctx)
        end
      end

      -- Create child windows for each corner button
      if cb.top_left then
        local btn_x = x1 + border_thickness + offset_x
        local btn_y = y1 + border_thickness + offset_y
        create_corner_button_child(cb.top_left, btn_x, btn_y, "tl", "tl")
      end

      if cb.top_right then
        local btn_x = x1 + w - size - border_thickness - offset_x
        local btn_y = y1 + border_thickness + offset_y
        create_corner_button_child(cb.top_right, btn_x, btn_y, "tr", "tr")
      end

      if cb.bottom_left then
        local btn_x = x1 + border_thickness + offset_x
        local btn_y = y1 + h - size - border_thickness - offset_y
        create_corner_button_child(cb.bottom_left, btn_x, btn_y, "bl", "bl")
      end

      if cb.bottom_right then
        local btn_x = x1 + w - size - border_thickness - offset_x
        local btn_y = y1 + h - size - border_thickness - offset_y
        create_corner_button_child(cb.bottom_right, btn_x, btn_y, "br", "br")
      end

      -- Draw clip edge borders for any button that extends beyond panel bounds
      local border_color = 0x000000FF
      for _, btn in ipairs(buttons_drawn) do
        if btn.x < x1 then
          ImGui.DrawList_AddLine(dl, x1, btn.y, x1, btn.y + btn.h, border_color, 1)
        end
        if btn.x + btn.w > x1 + w then
          ImGui.DrawList_AddLine(dl, x1 + w, btn.y, x1 + w, btn.y + btn.h, border_color, 1)
        end
        if btn.y < y1 then
          ImGui.DrawList_AddLine(dl, btn.x, y1, btn.x + btn.w, y1, border_color, 1)
        end
        if btn.y + btn.h > y1 + h then
          ImGui.DrawList_AddLine(dl, btn.x, y1 + h, btn.x + btn.w, y1 + h, border_color, 1)
        end
      end

      -- Pop clip rect after all corner buttons are drawn
      ImGui.DrawList_PopClipRect(dl)
      end
    end
  end

  -- Pop ID scope if it was pushed
  if self._id_scope_pushed then
    ImGui.PopID(ctx)
    self._id_scope_pushed = false
  end
end

function Panel:reset()
  self.had_scrollbar_last_frame = false
  self.last_content_height = 0
  
  if self.scrollbar then
    self.scrollbar:set_scroll_pos(0)
  end
end

function Panel:update(dt)
  if self.scrollbar then
    self.scrollbar:update(dt or 0.016)
  end
end

function Panel:get_id()
  return self.id
end

function Panel:debug_id_chain(ctx)
  reaper.ShowConsoleMsg(string.format(
    "[Panel ID Debug]\n" ..
    "  Panel ID: %s\n" ..
    "  Child Window ID: %s_scroll\n" ..
    "  Scrollbar ID: %s_scrollbar\n\n",
    self.id,
    self.id,
    self.id
  ))
end

function Panel:set_tabs(tabs, active_id)
  self.tabs = tabs or {}
  if active_id ~= nil then
    self.active_tab_id = active_id
  end
end

function Panel:get_tabs()
  return self.tabs or {}
end

function Panel:get_active_tab_id()
  return self.active_tab_id
end

function Panel:set_active_tab_id(id)
  self.active_tab_id = id
end

function Panel:is_overflow_visible()
  return self._overflow_visible or false
end

function Panel:show_overflow_modal()
  self._overflow_visible = true
end

function Panel:close_overflow_modal()
  self._overflow_visible = false
end

function Panel:get_search_text()
  if not self.config.header or not self.config.header.elements then
    return ""
  end
  
  for _, element in ipairs(self.config.header.elements) do
    if element.type == "search_field" then
      local element_state = self[element.id]
      if element_state and element_state.search_text then
        return element_state.search_text
      end
    end
  end
  
  return ""
end

function Panel:set_search_text(text)
  if not self.config.header or not self.config.header.elements then
    return
  end
  
  for _, element in ipairs(self.config.header.elements) do
    if element.type == "search_field" then
      if not self[element.id] then
        self[element.id] = {}
      end
      self[element.id].search_text = text or ""
      return
    end
  end
end

function Panel:get_sort_mode()
  if not self.config.header or not self.config.header.elements then
    return nil
  end
  
  for _, element in ipairs(self.config.header.elements) do
    if element.type == "dropdown_field" and element.id == "sort" then
      local element_state = self[element.id]
      if element_state and element_state.dropdown_value ~= nil then
        return element_state.dropdown_value
      end
    end
  end
  
  return nil
end

function Panel:set_sort_mode(mode)
  if not self.config.header or not self.config.header.elements then
    return
  end
  
  for _, element in ipairs(self.config.header.elements) do
    if element.type == "dropdown_field" and element.id == "sort" then
      if not self[element.id] then
        self[element.id] = {}
      end
      self[element.id].dropdown_value = mode
      return
    end
  end
end

function Panel:get_sort_direction()
  if not self.config.header or not self.config.header.elements then
    return "asc"
  end
  
  for _, element in ipairs(self.config.header.elements) do
    if element.type == "dropdown_field" and element.id == "sort" then
      local element_state = self[element.id]
      if element_state and element_state.dropdown_direction then
        return element_state.dropdown_direction
      end
    end
  end
  
  return "asc"
end

function Panel:set_sort_direction(direction)
  if not self.config.header or not self.config.header.elements then
    return
  end
  
  for _, element in ipairs(self.config.header.elements) do
    if element.type == "dropdown_field" and element.id == "sort" then
      if not self[element.id] then
        self[element.id] = {}
      end
      self[element.id].dropdown_direction = direction or "asc"
      return
    end
  end
end

function Panel:get_current_mode()
  return self.current_mode
end

function Panel:set_current_mode(mode)
  self.current_mode = mode
end

function M.draw(ctx, id, width, height, content_fn, config)
  config = config or DEFAULTS
  
  local panel = M.new({
    id = id,
    width = width,
    height = height,
    config = config,
  })
  
  if panel:begin_draw(ctx) then
    if content_fn then
      content_fn(ctx)
    end
  end
  panel:end_draw(ctx)
  
  return panel
end

return M

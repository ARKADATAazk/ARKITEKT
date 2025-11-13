-- @noindex
-- Region_Playlist/ui/transport_widgets.lua
-- Transport widgets for Region Playlist

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Button = require('rearkitekt.gui.widgets.controls.button')
local Tooltip = require('rearkitekt.gui.widgets.controls.tooltip')
local Colors = require('rearkitekt.core.colors')
local TileFXConfig = require('rearkitekt.gui.fx.tile_fx_config')
local TransportFX = require('rearkitekt.gui.widgets.transport.transport_fx')
local Chip = require('rearkitekt.gui.widgets.component.chip')
local hexrgb = Colors.hexrgb

local M = {}

-- ============================================================================
-- TRANSPORT DISPLAY LAYOUT CONFIG
-- Adjust these values to manually fine-tune the transport UI layout
-- All positions are in pixels, offsets can be positive (right/down) or negative (left/up)
-- ============================================================================
local TRANSPORT_LAYOUT_CONFIG = {
  -- Global Offset (affects entire transport content including progress bar)
  global_offset_y = -5,           -- Vertical offset for entire transport group (positive = down, negative = up)
  
  -- Spacing & Padding
  padding = 48,                   -- Horizontal padding from display edges (matches progress bar padding)
  padding_top = 8,                -- Top padding for content (separate from horizontal)
  spacing_horizontal = 12,        -- Horizontal spacing between elements
  spacing_progress = 8,           -- Vertical spacing between content row and progress bar
  
  -- Progress Bar
  progress_height = 3,            -- Height of progress bar
  progress_bottom_offset = 13,    -- Distance from bottom of display area (increased by 5 from 8 to 13)
  progress_padding_h = 48,        -- Horizontal padding for progress bar from edge of panel
  
  -- Single Row Layout: [Playlist] [Current Region] [TIME] [Next Region]
  -- Playlist (left side)
  playlist_chip_size = 8,         -- Chip indicator size (diameter)
  playlist_chip_offset_x = 0,     -- Additional X offset for chip
  playlist_chip_offset_y = 0,     -- Additional Y offset for chip
  playlist_name_offset_x = 12,    -- Distance from chip to playlist name text
  playlist_name_offset_y = 0,     -- Additional Y offset for playlist name
  
  -- Time Display (center)
  time_offset_x = 0,              -- Additional X offset for time (from center)
  time_offset_y = 0,              -- Additional Y offset for time
  
  -- Region Labels (around time)
  region_label_spacing = 4,       -- Spacing between region index and name
  current_region_offset_x = 0,    -- Additional X offset for current region
  current_region_offset_y = 0,    -- Additional Y offset for current region
  next_region_offset_x = 0,       -- Additional X offset for next region
  next_region_offset_y = 0,       -- Additional Y offset for next region
  
  -- Vertical Centering
  content_vertical_offset = 0,    -- Additional Y offset for content row (positive = down, negative = up)
}

-- ============================================================================
-- TRANSPORT ICONS
-- ============================================================================
local TransportIcons = {}

-- PLAY icon (Triangle - pixel-perfect alignment, 30% smaller vertically)
function TransportIcons.draw_play(dl, x, y, width, height, color)
  local icon_size = 14 * 0.7  -- 30% reduction vertically
  local cx = math.floor(x + width / 2 + 0.5)
  local cy = math.floor(y + height / 2 + 0.5)
  
  -- Ensure vertices are on whole pixels
  local x1 = math.floor(cx - icon_size / 3 + 0.5)
  local y1 = math.floor(cy - icon_size / 2 + 0.5)
  local x2 = math.floor(cx - icon_size / 3 + 0.5)
  local y2 = math.floor(cy + icon_size / 2 + 0.5)
  local x3 = math.floor(cx + icon_size / 2 + 0.5)
  local y3 = cy
  
  -- Draw with stroke for better antialiasing
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathLineTo(dl, x1, y1)
  ImGui.DrawList_PathLineTo(dl, x2, y2)
  ImGui.DrawList_PathLineTo(dl, x3, y3)
  ImGui.DrawList_PathFillConvex(dl, color)
  
  -- Add thin stroke for sharper edges
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathLineTo(dl, x1, y1)
  ImGui.DrawList_PathLineTo(dl, x2, y2)
  ImGui.DrawList_PathLineTo(dl, x3, y3)
  ImGui.DrawList_PathStroke(dl, color, ImGui.DrawFlags_Closed, 0.5)
end

-- STOP icon (Square - pixel-perfect alignment)
function TransportIcons.draw_stop(dl, x, y, width, height, color)
  local icon_size = 10
  local cx = math.floor(x + width / 2 + 0.5)
  local cy = math.floor(y + height / 2 + 0.5)
  
  -- Ensure all coordinates are on whole pixels
  local x1 = math.floor(cx - icon_size / 2 + 0.5)
  local y1 = math.floor(cy - icon_size / 2 + 0.5)
  local x2 = math.floor(cx + icon_size / 2 + 0.5)
  local y2 = math.floor(cy + icon_size / 2 + 0.5)
  
  -- Draw filled rectangle on whole pixels
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, color, 0)
  
  -- Add thin stroke for sharper edges
  ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, color, 0, 0, 0.5)
end

-- LOOP icon (Complex L-shape pattern)
function TransportIcons.draw_loop(dl, x, y, width, height, color)
  local cx = math.floor(x + width / 2 + 0.5)
  local cy = math.floor(y + height / 2 + 0.5)
  
  local line_width = 2
  local l_width = 6
  local l_height = 9
  local rect_width = 2
  local rect_height = 5
  local gap = 1
  
  local total_width = l_width + gap + rect_width + gap + rect_width + gap + l_width
  local start_x = math.floor(cx - total_width / 2 + 0.5)
  local start_y = math.floor(cy - l_height / 2 + 0.5)
  
  -- Offsets per request
  local left_L_dx = 3
  local rect1_dx, rect1_dy = -1, -4
  local rect2_dx, rect2_dy = 0, 4
  local right_L_dx = -4
  
  -- Left L-shape (moved right by 3px) - ensure whole pixels
  local left_x = math.floor(start_x + left_L_dx + 0.5)
  ImGui.DrawList_AddRectFilled(dl, left_x, start_y, left_x + line_width, start_y + l_height, color)
  ImGui.DrawList_AddRectFilled(dl, left_x, start_y + l_height - line_width, left_x + l_width, start_y + l_height, color)
  
  -- Two center rectangles (first square up 4px, left 1px; second square down 4px)
  local rect1_x = math.floor(start_x + l_width + gap + rect1_dx + 0.5)
  local rect1_y = math.floor(cy - rect_height / 2 + rect1_dy + 0.5)
  ImGui.DrawList_AddRectFilled(dl, rect1_x, rect1_y, rect1_x + rect_width, rect1_y + rect_height, color)
  
  local rect2_x = math.floor(start_x + l_width + gap + rect_width + gap + rect2_dx + 0.5)
  local rect2_y = math.floor(cy - rect_height / 2 + rect2_dy + 0.5)
  ImGui.DrawList_AddRectFilled(dl, rect2_x, rect2_y, rect2_x + rect_width, rect2_y + rect_height, color)
  
  -- Right L-shape (moved left by 4px) - ensure whole pixels
  local right_l_x = math.floor(rect2_x + rect_width + gap + right_L_dx + 0.5)
  ImGui.DrawList_AddRectFilled(dl, right_l_x + l_width - line_width, start_y, right_l_x + l_width, start_y + l_height, color)
  ImGui.DrawList_AddRectFilled(dl, right_l_x, start_y, right_l_x + l_width, start_y + line_width, color)
end

-- JUMP icon (Double Play Triangle - pixel-perfect alignment)
function TransportIcons.draw_jump(dl, x, y, width, height, color)
  local icon_size = 11
  local spacing = 3
  local cx = math.floor(x + width / 2 + 0.5)
  local cy = math.floor(y + height / 2 + 0.5)
  
  -- First triangle - ensure whole pixels
  local x1_1 = math.floor(cx - icon_size - spacing / 2 + 0.5)
  local y1_1 = math.floor(cy - icon_size / 2 + 0.5)
  local x1_2 = math.floor(cx - icon_size - spacing / 2 + 0.5)
  local y1_2 = math.floor(cy + icon_size / 2 + 0.5)
  local x1_3 = math.floor(cx - spacing / 2 + 0.5)
  local y1_3 = cy
  
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathLineTo(dl, x1_1, y1_1)
  ImGui.DrawList_PathLineTo(dl, x1_2, y1_2)
  ImGui.DrawList_PathLineTo(dl, x1_3, y1_3)
  ImGui.DrawList_PathFillConvex(dl, color)
  
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathLineTo(dl, x1_1, y1_1)
  ImGui.DrawList_PathLineTo(dl, x1_2, y1_2)
  ImGui.DrawList_PathLineTo(dl, x1_3, y1_3)
  ImGui.DrawList_PathStroke(dl, color, ImGui.DrawFlags_Closed, 0.5)
  
  -- Second triangle - ensure whole pixels
  local x2_1 = math.floor(cx + spacing / 2 + 0.5)
  local y2_1 = math.floor(cy - icon_size / 2 + 0.5)
  local x2_2 = math.floor(cx + spacing / 2 + 0.5)
  local y2_2 = math.floor(cy + icon_size / 2 + 0.5)
  local x2_3 = math.floor(cx + icon_size + spacing / 2 + 0.5)
  local y2_3 = cy
  
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathLineTo(dl, x2_1, y2_1)
  ImGui.DrawList_PathLineTo(dl, x2_2, y2_2)
  ImGui.DrawList_PathLineTo(dl, x2_3, y2_3)
  ImGui.DrawList_PathFillConvex(dl, color)
  
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathLineTo(dl, x2_1, y2_1)
  ImGui.DrawList_PathLineTo(dl, x2_2, y2_2)
  ImGui.DrawList_PathLineTo(dl, x2_3, y2_3)
  ImGui.DrawList_PathStroke(dl, color, ImGui.DrawFlags_Closed, 0.5)
end

-- ============================================================================
-- TRANSPORT BUTTON LAYOUT CONFIG
-- ============================================================================
local TRANSPORT_BUTTON_CONFIG = {
  -- Button dimensions (from left to right)
  play_width = 34,
  play_height = 23,
  stop_width = 34,
  stop_height = 23,
  loop_width = 34,
  loop_height = 23,
  jump_width = 46,
  jump_height = 23,
  measure_width = 75,
  measure_height = 23,
  override_width = 70,
  override_height = 23,
  follow_width = 110,
  follow_height = 23,
  
  -- Spacing
  button_spacing = -1,  -- Negative for border overlap
  
  -- Position offset from transport lower left
  start_offset_x = 8,
  start_offset_y = 8,  -- Distance from bottom
}

-- ============================================================================
-- VIEW MODE BUTTON (Layout Toggle)
-- ============================================================================

M.ViewModeButton = {}
M.ViewModeButton.__index = M.ViewModeButton

function M.ViewModeButton.new(config)
  return setmetatable({
    config = config or {},
    hover_alpha = 0,
  }, M.ViewModeButton)
end

function M.ViewModeButton:draw_icon(ctx, dl, x, y, mode)
  local color = self.config.icon_color or hexrgb("#AAAAAA")
  
  if mode == 'vertical' then
    -- Top bar: 20x3, 2px space, left 5x15, 2px space, right 13x15
    ImGui.DrawList_AddRectFilled(dl, x, y, x + 20, y + 3, color, 0)
    ImGui.DrawList_AddRectFilled(dl, x, y + 5, x + 5, y + 20, color, 0)
    ImGui.DrawList_AddRectFilled(dl, x + 7, y + 5, x + 20, y + 20, color, 0)
  else
    -- Top bar: 20x3, 2px space, middle 20x4, 2px space, bottom 20x9
    ImGui.DrawList_AddRectFilled(dl, x, y, x + 20, y + 3, color, 0)
    ImGui.DrawList_AddRectFilled(dl, x, y + 5, x + 20, y + 9, color, 0)
    ImGui.DrawList_AddRectFilled(dl, x, y + 11, x + 20, y + 20, color, 0)
  end
end

function M.ViewModeButton:draw(ctx, x, y, current_mode, on_click)
  local dl = ImGui.GetWindowDrawList(ctx)
  local cfg = self.config
  local btn_size = cfg.size or 32
  
  local mx, my = ImGui.GetMousePos(ctx)
  local is_hovered = mx >= x and mx < x + btn_size and my >= y and my < y + btn_size
  
  local target = is_hovered and 1.0 or 0.0
  local speed = cfg.animation_speed or 12.0
  local dt = ImGui.GetDeltaTime(ctx)
  self.hover_alpha = self.hover_alpha + (target - self.hover_alpha) * speed * dt
  self.hover_alpha = math.max(0, math.min(1, self.hover_alpha))
  
  local bg = self:lerp_color(cfg.bg_color or hexrgb("#252525"), cfg.bg_hover or hexrgb("#2A2A2A"), self.hover_alpha)
  local border_inner = self:lerp_color(cfg.border_inner or hexrgb("#404040"), cfg.border_hover or hexrgb("#505050"), self.hover_alpha)
  local border_outer = cfg.border_outer or hexrgb("#000000DD")
  
  local rounding = cfg.rounding or 4
  local inner_rounding = math.max(0, rounding - 2)
  
  -- Background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + btn_size, y + btn_size, bg, inner_rounding)
  
  -- Inner border
  ImGui.DrawList_AddRect(dl, x + 1, y + 1, x + btn_size - 1, y + btn_size - 1, border_inner, inner_rounding, 0, 1)
  
  -- Outer border
  ImGui.DrawList_AddRect(dl, x, y, x + btn_size, y + btn_size, border_outer, inner_rounding, 0, 1)
  
  local icon_x = math.floor(x + (btn_size - 20) / 2 + 0.5)
  local icon_y = math.floor(y + (btn_size - 20) / 2 + 0.5)
  self:draw_icon(ctx, dl, icon_x, icon_y, current_mode)
  
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, "##view_mode_toggle", btn_size, btn_size)
  
  if ImGui.IsItemClicked(ctx, 0) and on_click then
    on_click()
  end
  
  if ImGui.IsItemHovered(ctx) then
    local tooltip = current_mode == 'horizontal' and "Switch to List Mode" or "Switch to Timeline Mode"
    Tooltip.show(ctx, tooltip)
  end
  
  return btn_size
end

function M.ViewModeButton:lerp_color(a, b, t)
  local ar, ag, ab, aa = (a >> 24) & 0xFF, (a >> 16) & 0xFF, (a >> 8) & 0xFF, a & 0xFF
  local br, bg, bb, ba = (b >> 24) & 0xFF, (b >> 16) & 0xFF, (b >> 8) & 0xFF, b & 0xFF
  
  local r = math.floor(ar + (br - ar) * t)
  local g = math.floor(ag + (bg - ag) * t)
  local b = math.floor(ab + (bb - ab) * t)
  local a = math.floor(aa + (ba - aa) * t)
  
  return (r << 24) | (g << 16) | (b << 8) | a
end

-- ============================================================================
-- MODERN TRANSPORT DISPLAY WITH GRADIENT PROGRESS
-- ============================================================================

M.TransportDisplay = {}
M.TransportDisplay.__index = M.TransportDisplay

function M.TransportDisplay.new(config)
  return setmetatable({
    config = config or {},
  }, M.TransportDisplay)
end

-- Helper to ensure progress bar color has minimum brightness
local function ensure_minimum_brightness(color, min_luminance)
  min_luminance = min_luminance or 0.15
  
  local lum = Colors.luminance(color)
  if lum >= min_luminance then
    return color
  end
  
  -- Calculate brightness boost needed
  local boost_factor = min_luminance / math.max(lum, 0.01)
  return Colors.adjust_brightness(color, boost_factor)
end

function M.TransportDisplay:draw(ctx, x, y, width, height, bridge_state, current_region, next_region, playlist_data, region_colors, time_font)
  local dl = ImGui.GetWindowDrawList(ctx)
  local cfg = self.config
  local fx_config = TileFXConfig.get()
  
  -- Load layout config
  local LC = TRANSPORT_LAYOUT_CONFIG
  
  -- Apply global offset
  y = y + LC.global_offset_y
  
  -- ================================================
  -- PROGRESS BAR (at bottom of display area, above buttons)
  -- ================================================
  
  local progress = bridge_state.progress or 0
  local bar_x = x + LC.progress_padding_h
  local bar_y = y + height - LC.progress_height - LC.progress_bottom_offset
  local bar_w = width - LC.progress_padding_h * 2
  local bar_h = LC.progress_height
  
  -- Track background
  local track_color = cfg.track_color or hexrgb("#1D1D1D")
  ImGui.DrawList_AddRectFilled(dl, bar_x, bar_y, bar_x + bar_w, bar_y + bar_h, track_color, 1.5)
  
  -- Gradient fill with minimum brightness enforcement
  if progress > 0 and region_colors and region_colors.current then
    local fill_w = bar_w * progress
    
    -- Determine fill colors based on state
    local color_left, color_right
    if region_colors.next then
      -- Playing with next region: gradient from current to next
      color_left = ensure_minimum_brightness(region_colors.current, 0.15)
      color_right = ensure_minimum_brightness(region_colors.next, 0.15)
    else
      -- Last region: gradient to black
      color_left = ensure_minimum_brightness(region_colors.current, 0.15)
      color_right = hexrgb("#000000")
    end
    
    -- Use TransportFX to render gradient with border colors
    TransportFX.render_progress_gradient(dl, bar_x, bar_y, bar_x + fill_w, bar_y + bar_h, 
      color_left, color_right, 1.5)
  end
  
  -- ================================================
  -- SINGLE ROW CONTENT: [Playlist] [Current] [TIME] [Next]
  -- ================================================
  
  -- Calculate available space above progress bar
  local content_bottom = bar_y - LC.spacing_progress
  local content_top = y + (LC.padding_top or 8)  -- Use separate top padding
  
  -- Build time text first to get dimensions
  local time_text = "READY"
  local time_color = cfg.time_color or hexrgb("#CCCCCC")
  
  if bridge_state.is_playing then
    local time_remaining = bridge_state.time_remaining or 0
    local mins = math.floor(time_remaining / 60)
    local secs = time_remaining % 60
    
    if mins > 0 then
      time_text = string.format("%02d:%04.1f", mins, secs)
    else
      time_text = string.format("%04.1f", secs)
    end
    time_color = cfg.time_playing_color or hexrgb("#FFFFFF")
  end
  
  -- Get time dimensions with large font
  if time_font then
    ImGui.PushFont(ctx, time_font, 20)
  end
  local time_w, time_h = ImGui.CalcTextSize(ctx, time_text)
  if time_font then
    ImGui.PopFont(ctx)
  end
  
  local text_line_h = ImGui.CalcTextSize(ctx, "Tg")
  
  -- Single row uses the larger of text_line_h or time_h
  local row_height = math.max(text_line_h, time_h)
  
  -- Center the row vertically in available space
  local row_y = content_top + ((content_bottom - content_top) - row_height) / 2 + LC.content_vertical_offset
  
  -- Left: Playlist chip + name
  if playlist_data then
    local chip_x = x + LC.padding + LC.playlist_chip_offset_x
    local chip_y = row_y + row_height / 2 + LC.playlist_chip_offset_y
    
    Chip.draw(ctx, {
      style = Chip.STYLE.INDICATOR,
      color = playlist_data.color,
      draw_list = dl,
      x = chip_x,
      y = chip_y,
      radius = 4,
      is_selected = false,
      is_hovered = false,
      show_glow = false,
      alpha_factor = 1.0,
    })
    
    local playlist_name_x = x + LC.padding + LC.playlist_name_offset_x
    local playlist_name_y = row_y + (row_height - text_line_h) / 2 + LC.playlist_name_offset_y
    local playlist_name_color = hexrgb("#CCCCCC")
    ImGui.DrawList_AddText(dl, playlist_name_x, playlist_name_y, playlist_name_color, playlist_data.name)
  end
  
  -- Center: TIME (with large font)
  local center_x = x + width / 2
  
  if time_font then
    ImGui.PushFont(ctx, time_font, 20)
  end
  
  local time_x = center_x - time_w / 2 + LC.time_offset_x
  local time_y = row_y + (row_height - time_h) / 2 + LC.time_offset_y
  
  ImGui.DrawList_AddText(dl, time_x, time_y, time_color, time_text)
  
  if time_font then
    ImGui.PopFont(ctx)
  end
  
  -- Left of time: Current region
  if bridge_state.is_playing and current_region then
    local index_str = string.format("%d", current_region.rid)
    local name_str = current_region.name or "Unknown"
    
    local index_color = Colors.same_hue_variant(current_region.color, fx_config.index_saturation, fx_config.index_brightness, 0xFF)
    local name_color = hexrgb("#FFFFFF")
    
    local index_w = ImGui.CalcTextSize(ctx, index_str)
    local name_w = ImGui.CalcTextSize(ctx, name_str)
    
    local total_w = index_w + LC.region_label_spacing + name_w
    local current_x = time_x - total_w - LC.spacing_horizontal + LC.current_region_offset_x
    local current_y = row_y + (row_height - text_line_h) / 2 + LC.current_region_offset_y
    
    ImGui.DrawList_AddText(dl, current_x, current_y, index_color, index_str)
    ImGui.DrawList_AddText(dl, current_x + index_w + LC.region_label_spacing, current_y, name_color, name_str)
  end
  
  -- Right of time: Next region
  if bridge_state.is_playing and next_region then
    local index_str = string.format("%d", next_region.rid)
    local name_str = next_region.name or "Unknown"
    
    local index_color = Colors.same_hue_variant(next_region.color, fx_config.index_saturation, fx_config.index_brightness, 0xFF)
    local name_color = hexrgb("#FFFFFF")
    
    local index_w = ImGui.CalcTextSize(ctx, index_str)
    
    local next_x = time_x + time_w + LC.spacing_horizontal + LC.next_region_offset_x
    local next_y = row_y + (row_height - text_line_h) / 2 + LC.next_region_offset_y
    
    ImGui.DrawList_AddText(dl, next_x, next_y, index_color, index_str)
    ImGui.DrawList_AddText(dl, next_x + index_w + LC.region_label_spacing, next_y, name_color, name_str)
  end
end

-- ============================================================================
-- SIMPLE TOGGLE BUTTONS (Override + Loop)
-- ============================================================================

M.SimpleToggleButton = {}
M.SimpleToggleButton.__index = M.SimpleToggleButton

function M.SimpleToggleButton.new(id, label, width, height)
  return setmetatable({
    id = id,
    label = label,
    width = width or 80,
    height = height or 28,
    hover_alpha = 0,
    state = false,
  }, M.SimpleToggleButton)
end

function M.SimpleToggleButton:draw(ctx, x, y, state, on_click, color)
  local dl = ImGui.GetWindowDrawList(ctx)
  self.state = state
  
  local mx, my = ImGui.GetMousePos(ctx)
  local is_hovered = mx >= x and mx < x + self.width and my >= y and my < y + self.height
  
  local target = is_hovered and 1.0 or 0.0
  local dt = ImGui.GetDeltaTime(ctx)
  self.hover_alpha = self.hover_alpha + (target - self.hover_alpha) * 12.0 * dt
  self.hover_alpha = math.max(0, math.min(1, self.hover_alpha))
  
  local bg_off = hexrgb("#252525")
  local bg_off_hover = hexrgb("#2A2A2A")
  local bg_on = Colors.with_alpha(color or hexrgb("#4A9EFF"), 0x40)
  local bg_on_hover = Colors.with_alpha(color or hexrgb("#4A9EFF"), 0x50)
  
  local bg = state and (is_hovered and bg_on_hover or bg_on) or (is_hovered and bg_off_hover or bg_off)
  
  local border_color = state and (color or hexrgb("#4A9EFF")) or hexrgb("#404040")
  
  -- Background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + self.width, y + self.height, bg, 4)
  
  -- Border
  ImGui.DrawList_AddRect(dl, x, y, x + self.width, y + self.height, border_color, 4, 0, 1)
  
  -- Text
  local text_color = state and hexrgb("#FFFFFF") or hexrgb("#999999")
  local tw, th = ImGui.CalcTextSize(ctx, self.label)
  ImGui.DrawList_AddText(dl, x + (self.width - tw) / 2, y + (self.height - th) / 2, text_color, self.label)
  
  -- Interaction
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, self.id, self.width, self.height)
  
  if ImGui.IsItemClicked(ctx, 0) and on_click then
    on_click(not state)
  end
  
  return self.width
end

-- ============================================================================
-- JUMP CONTROLS (Compact)
-- ============================================================================

M.JumpControls = {}
M.JumpControls.__index = M.JumpControls

function M.JumpControls.new(config)
  return setmetatable({
    config = config or {},
    jump_button_id = "transport_jump_btn",
  }, M.JumpControls)
end

function M.JumpControls:draw(ctx, x, y, width, height, bridge_state, quantize_lookahead, on_jump, on_mode_change, on_lookahead_change)
  local dl = ImGui.GetWindowDrawList(ctx)
  local cfg = self.config
  
  local btn_w = 80
  local combo_w = 100
  local slider_label_w = 60
  local spacing = 8
  local slider_w = math.max(60, width - btn_w - combo_w - slider_label_w - spacing * 3)
  
  local current_x = x
  
  -- JUMP button
  local is_disabled = not bridge_state.is_playing
  
  if is_disabled then
    ImGui.BeginDisabled(ctx)
  end
  
  local button_config = {
    label = "JUMP",
    id = self.jump_button_id,
    width = btn_w,
    height = height,
    rounding = 4,
    on_click = on_jump,
    tooltip = "Jump to next quantize point",
  }
  
  Button.draw(ctx, dl, current_x, y, btn_w, height, button_config, self.jump_button_id)
  
  if is_disabled then
    ImGui.EndDisabled(ctx)
  end
  
  current_x = current_x + btn_w + spacing
  
  -- Mode combo
  ImGui.SetCursorScreenPos(ctx, current_x, y)
  ImGui.SetNextItemWidth(ctx, combo_w)
  
  local mode_options = {
    { value = "measure", label = "Measure" },
    { value = "4.0", label = "Bar" },
    { value = "1.0", label = "1/4" },
    { value = "0.5", label = "1/8" },
    { value = "0.25", label = "1/16" },
  }
  
  local current_mode = bridge_state.quantize_mode or "measure"
  local current_label = "Measure"
  for _, opt in ipairs(mode_options) do
    if opt.value == current_mode then
      current_label = opt.label
      break
    end
  end
  
  if ImGui.BeginCombo(ctx, "##jump_mode", current_label) then
    for _, opt in ipairs(mode_options) do
      local is_selected = opt.value == current_mode
      if ImGui.Selectable(ctx, opt.label, is_selected) and on_mode_change then
        on_mode_change(opt.value)
      end
      if is_selected then
        ImGui.SetItemDefaultFocus(ctx)
      end
    end
    ImGui.EndCombo(ctx)
  end
  
  current_x = current_x + combo_w + spacing
  
  -- Lookahead label + slider
  ImGui.SetCursorScreenPos(ctx, current_x, y + (height - ImGui.GetTextLineHeight(ctx)) / 2)
  ImGui.Text(ctx, "Lookahead:")
  
  current_x = current_x + slider_label_w + 4
  
  ImGui.SetCursorScreenPos(ctx, current_x, y + (height - 20) / 2)
  ImGui.SetNextItemWidth(ctx, slider_w)
  local changed, new_val = ImGui.SliderDouble(ctx, "##lookahead", quantize_lookahead * 1000, 200, 1000, "%.0fms")
  if changed and on_lookahead_change then
    on_lookahead_change(new_val / 1000)
  end
  
  if ImGui.IsItemHovered(ctx) then
    Tooltip.show(ctx, "Jump lookahead time (milliseconds)")
  end
end

-- ============================================================================
-- TRANSPORT BUTTON BAR (Using panel header layout system)
-- ============================================================================

M.TransportButtonBar = {}
M.TransportButtonBar.__index = M.TransportButtonBar

function M.TransportButtonBar.new()
  local HeaderLayout = require('rearkitekt.gui.widgets.panel.header.layout')
  
  return setmetatable({
    layout = HeaderLayout,
    state = {
      id = "transport_buttons",
    },
  }, M.TransportButtonBar)
end

function M.TransportButtonBar:draw(ctx, x, y, width, height, bridge_state, callbacks)
  local dl = ImGui.GetWindowDrawList(ctx)
  local cfg = TRANSPORT_BUTTON_CONFIG
  
  -- Position at bottom of transport area
  local footer_x = x + cfg.start_offset_x
  local footer_y = y + height - cfg.start_offset_y - cfg.play_height
  local footer_w = width - cfg.start_offset_x * 2
  local footer_h = cfg.play_height
  
  -- Build header elements config for footer layout
  local elements = {
    -- PLAY button (toggle)
    {
      type = "button",
      id = "play",
      width = cfg.play_width,
      config = {
        is_toggled = bridge_state.is_playing or false,
        custom_draw = function(ctx, dl, bx, by, bw, bh, is_hovered, is_active, text_color)
          TransportIcons.draw_play(dl, bx, by, bw, bh, text_color)
        end,
        tooltip = "Play/Pause",
        on_click = callbacks and callbacks.on_play or nil,
      },
    },
    -- STOP button
    {
      type = "button",
      id = "stop",
      width = cfg.stop_width,
      config = {
        custom_draw = function(ctx, dl, bx, by, bw, bh, is_hovered, is_active, text_color)
          TransportIcons.draw_stop(dl, bx, by, bw, bh, text_color)
        end,
        tooltip = "Stop",
        on_click = callbacks and callbacks.on_stop or nil,
      },
    },
    -- LOOP button (toggle)
    {
      type = "button",
      id = "loop",
      width = cfg.loop_width,
      config = {
        is_toggled = bridge_state.loop_enabled or false,
        custom_draw = function(ctx, dl, bx, by, bw, bh, is_hovered, is_active, text_color)
          TransportIcons.draw_loop(dl, bx, by, bw, bh, text_color)
        end,
        tooltip = "Loop",
        on_click = callbacks and callbacks.on_loop or nil,
      },
    },
    -- JUMP button
    {
      type = "button",
      id = "jump",
      width = cfg.jump_width,
      config = {
        custom_draw = function(ctx, dl, bx, by, bw, bh, is_hovered, is_active, text_color)
          TransportIcons.draw_jump(dl, bx, by, bw, bh, text_color)
        end,
        tooltip = "Jump Forward",
        on_click = callbacks and callbacks.on_jump or nil,
      },
    },
    -- SEPARATOR
    {
      type = "separator",
      id = "sep1",
      width = 4,
    },
    -- MEASURE dropdown
    {
      type = "button",  -- TODO: Change to dropdown when implemented
      id = "measure",
      width = cfg.measure_width,
      config = {
        label = "Measure",
        tooltip = "Grid/Quantize Mode",
      },
    },
    -- OVERRIDE button (toggle)
    {
      type = "button",
      id = "override",
      width = cfg.override_width,
      config = {
        label = "Override",
        is_toggled = bridge_state.override_enabled or false,
        tooltip = "Override Quantization",
        on_click = callbacks and callbacks.on_override or nil,
      },
    },
    -- FOLLOW VIEWPORT button (toggle)
    {
      type = "button",
      id = "follow",
      width = cfg.follow_width,
      config = {
        label = "Follow Viewport",
        is_toggled = bridge_state.follow_viewport or false,
        tooltip = "Follow Playhead in Viewport",
        on_click = callbacks and callbacks.on_follow or nil,
      },
    },
  }
  
  -- Use header layout system with bottom positioning
  local header_config = {
    elements = elements,
    rounding = 8,
    position = "bottom",  -- This makes it use top rounding only
    padding = { left = 0, right = 0 },
  }
  
  self.layout.draw(ctx, dl, footer_x, footer_y, footer_w, footer_h, self.state, header_config)
end

-- ============================================================================
-- EXPORTED ICON DRAWING FUNCTIONS
-- ============================================================================

M.draw_play_icon = TransportIcons.draw_play
M.draw_stop_icon = TransportIcons.draw_stop
M.draw_loop_icon = TransportIcons.draw_loop
M.draw_jump_icon = TransportIcons.draw_jump

return M
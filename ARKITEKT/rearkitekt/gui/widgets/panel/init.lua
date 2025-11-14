-- @noindex
-- ReArkitekt/gui/widgets/panel/init.lua
-- Main panel API with header positioning and corner buttons support
-- Fixed: Push unique ID scope for entire panel

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Header = require('rearkitekt.gui.widgets.panel.header')
local Content = require('rearkitekt.gui.widgets.panel.content')
local Background = require('rearkitekt.gui.widgets.panel.background')
local TabAnimator = require('rearkitekt.gui.widgets.panel.tab_animator')
local Scrollbar = require('rearkitekt.gui.widgets.controls.scrollbar')
local Button = require('rearkitekt.gui.widgets.controls.button')
local CornerButton = require('rearkitekt.gui.widgets.controls.corner_button')
local PanelConfig = require('rearkitekt.gui.widgets.panel.config')
local ConfigUtil = require('rearkitekt.core.config')

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
    config = ConfigUtil.deep_merge(DEFAULTS, opts.config),
    
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

local function draw_corner_buttons(ctx, dl, x, y, w, h, config, panel_id, panel_rounding)
  if not config.corner_buttons then return end
  
  local cb = config.corner_buttons
  local size = cb.size or 30
  local border_thickness = 1
  
  -- Get rounding from config
  local inner_rounding = size * CORNER_BUTTON_CONFIG.inner_corner_rounding_multiplier
  local outer_rounding = CORNER_BUTTON_CONFIG.outer_corner_rounding
  
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
  
  -- Header configuration
  local header_cfg = self.config.header or DEFAULTS.header
  local header_height = 0
  local header_position = "top"
  local content_y1 = y1
  local content_y2 = y2
  
  if header_cfg.enabled then
    header_height = header_cfg.height or 30
    header_position = header_cfg.position or "top"
    
    if header_position == "bottom" then
      -- Bottom header: draw at bottom, content above
      Header.draw(ctx, dl, x1, y2 - header_height, w, header_height, self, self.config, self.config.rounding)
      content_y1 = y1
      content_y2 = y2 - header_height
    else
      -- Top header: draw at top, content below
      Header.draw(ctx, dl, x1, y1, w, header_height, self, self.config, self.config.rounding)
      content_y1 = y1 + header_height
      content_y2 = y2
    end
  end
  
  self.header_height = header_height
  
  -- Draw background pattern across full panel area (including header for transparency)
  -- Apply clipping to respect rounded corners and border insets
  if self.config.background_pattern and self.config.background_pattern.enabled then
    local border_inset = self.config.border_thickness
    local pattern_x1 = x1 + border_inset
    local pattern_y1 = y1 + border_inset  -- Start from panel top, not content_y1
    local pattern_x2 = x2 - border_inset
    local pattern_y2 = y2 - border_inset  -- End at panel bottom, not content_y2

    -- Push clip rect with rounded corners to prevent bleeding
    local clip_rounding = math.max(0, self.config.rounding - border_inset)
    ImGui.DrawList_PushClipRect(dl, pattern_x1, pattern_y1, pattern_x2, pattern_y2, true)

    Background.draw(dl, pattern_x1, pattern_y1, pattern_x2, pattern_y2, self.config.background_pattern)

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
    if header_position == "bottom" then
      Header.draw_elements(ctx, dl, x1, y2 - header_height, w, header_height, self, self.config)
    else
      Header.draw_elements(ctx, dl, x1, y1, w, header_height, self, self.config)
    end
  end
  
  -- Draw corner buttons (if no header, or if explicitly enabled)
  if not header_cfg.enabled or self.config.corner_buttons_always_visible then
    draw_corner_buttons(ctx, dl, x1, y1, w, h, self.config, self.id, self.config.rounding)
  end
  
  -- Calculate content area
  local border_inset = self.config.border_thickness
  local child_x = x1 + border_inset
  local child_y = content_y1 + border_inset
  
  self.child_x = child_x
  self.child_y = child_y
  
  local scrollbar_width = 0
  if self.scrollbar then
    scrollbar_width = self.config.scroll.scrollbar_config.width
  end
  
  ImGui.SetCursorScreenPos(ctx, child_x, child_y)
  
  local child_w = w - (border_inset * 2) - scrollbar_width
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
  
  -- Pass self (container) to begin_child for state tracking
  local success = Content.begin_child(ctx, self.id, child_w, child_h, scroll_config, self)
  
  if success then
    local win_x, win_y = ImGui.GetWindowPos(ctx)
    local win_w, win_h = ImGui.GetWindowSize(ctx)
    self.visible_bounds = {win_x, win_y, win_x + win_w, win_y + win_h}
    
    if self.config.padding > 0 then
      local px = self.config.padding
      local py = self.config.padding
      if px > child_w - 1 then px = math.max(0, child_w - 1) end
      if py > child_h - 1 then py = math.max(0, child_h - 1) end
      if px < 0 then px = 0 end
      if py < 0 then py = 0 end
      ImGui.SetCursorPos(ctx, px, py)
    end
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

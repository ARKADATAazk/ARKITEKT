-- @noindex
-- panel/coordinator.lua
-- Main panel rendering coordinator - orchestrates all panel subsystems

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

-- Module dependencies
local Toolbar = require('arkitekt.gui.widgets.containers.panel.toolbar')
local Content = require('arkitekt.gui.widgets.containers.panel.content')
local Pattern = require('arkitekt.gui.draw.pattern')
local Rendering = require('arkitekt.gui.widgets.containers.panel.rendering')
local CornerButtons = require('arkitekt.gui.widgets.containers.panel.corner_buttons')
local Scrolling = require('arkitekt.gui.widgets.containers.panel.scrolling')
local State = require('arkitekt.gui.widgets.containers.panel.state')
local PanelConfig = require('arkitekt.gui.widgets.containers.panel.defaults')
local ConfigUtil = require('arkitekt.core.config')

local M = {}
local DEFAULTS = PanelConfig.DEFAULTS

-- ============================================================================
-- PANEL CLASS
-- ============================================================================

local panel_id_counter = 0

local function generate_unique_id(prefix)
  panel_id_counter = panel_id_counter + 1
  return string.format("%s_%d", prefix or "panel", panel_id_counter)
end

local Panel = {}
Panel.__index = Panel

--- Create new panel instance
--- @param opts table Panel options
--- @return table Panel instance
function M.new(opts)
  opts = opts or {}

  local id = opts.id or generate_unique_id("panel")

  local panel = setmetatable({
    id = id,
    _panel_id = id,
    config = ConfigUtil.deepMerge(DEFAULTS, opts.config or {}),

    -- Dimensions
    width = opts.width,
    height = opts.height,

    -- Scrolling state
    had_scrollbar_last_frame = false,
    scrollbar_size = 0,
    scrollbar = nil,

    -- Child window state
    child_width = 0,
    child_height = 0,
    child_x = 0,
    child_y = 0,
    actual_child_height = 0,
    visible_bounds = nil,
    _child_began_successfully = false,
    _id_scope_pushed = false,

    -- Tab state
    tabs = {},
    active_tab_id = nil,

    -- Mode state
    current_mode = nil,

    -- Overflow modal state
    _overflow_visible = false,

    -- Header/footer heights
    header_height = 0,
    footer_height = 0,

    -- Corner button bounds (for end_draw)
    _corner_button_bounds = nil,
  }, Panel)

  -- Initialize scrollbar if custom scrollbar enabled
  panel.scrollbar = Scrolling.create_scrollbar(id, panel.config)

  return panel
end

-- ============================================================================
-- PANEL RENDERING
-- ============================================================================

function Panel:begin_draw(ctx)
  -- Push unique ID scope
  ImGui.PushID(ctx, self.id)
  self._id_scope_pushed = true

  -- Update animations
  local dt = ImGui.GetDeltaTime(ctx)
  self:update(dt)

  -- Get dimensions
  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)
  local w = self.width or avail_w
  local h = self.height or avail_h

  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)

  local x1, y1 = cursor_x, cursor_y
  local x2, y2 = x1 + w, y1 + h

  -- Draw background
  Rendering.draw_background(dl, x1, y1, w, h, self.config.bg_color, self.config.rounding)

  -- ============================================================================
  -- TOOLBAR CALCULATION (Unified API)
  -- ============================================================================

  -- Calculate toolbar dimensions and content bounds
  local toolbar_sizes = {top = 0, bottom = 0, left = 0, right = 0}
  local content_y1 = y1
  local content_y2 = y2

  -- Top toolbar
  local top_cfg = Toolbar.get_toolbar_config(self.config, "top")
  if top_cfg then
    toolbar_sizes.top = top_cfg.height or 30
    content_y1 = y1 + toolbar_sizes.top
  end

  -- Bottom toolbar
  local bottom_cfg = Toolbar.get_toolbar_config(self.config, "bottom")
  if bottom_cfg then
    toolbar_sizes.bottom = bottom_cfg.height or 30
    content_y2 = y2 - toolbar_sizes.bottom
  end

  -- Left/right toolbars (vertical - calculated but don't affect content_y bounds)
  local left_cfg = Toolbar.get_toolbar_config(self.config, "left")
  if left_cfg then
    toolbar_sizes.left = left_cfg.width or 36
  end

  local right_cfg = Toolbar.get_toolbar_config(self.config, "right")
  if right_cfg then
    toolbar_sizes.right = right_cfg.width or 36
  end

  -- Store for state accessors (legacy compatibility)
  self.header_height = toolbar_sizes.top
  self.footer_height = toolbar_sizes.bottom

  -- ============================================================================
  -- DRAW HORIZONTAL TOOLBAR BACKGROUNDS
  -- ============================================================================

  -- Top toolbar background
  if top_cfg then
    Toolbar.draw_background(ctx, dl, x1, y1, w, toolbar_sizes.top, self, top_cfg, self.config.rounding, "top")
  end

  -- Bottom toolbar background
  if bottom_cfg then
    Toolbar.draw_background(ctx, dl, x1, y2 - toolbar_sizes.bottom, w, toolbar_sizes.bottom, self, bottom_cfg, self.config.rounding, "bottom")
  end

  -- ============================================================================
  -- DRAW PATTERN AND BORDER
  -- ============================================================================

  -- Draw background pattern (if enabled)
  if self.config.background_pattern and self.config.background_pattern.enabled then
    local border_inset = self.config.border_thickness
    local pattern_x1 = x1 + border_inset
    local pattern_x2 = x2 - border_inset

    -- Check if top toolbar is transparent
    local top_is_transparent = false
    if top_cfg and top_cfg.bg_color then
      local alpha = (top_cfg.bg_color & 0xFF) / 255.0
      top_is_transparent = alpha < 0.1
    end

    -- Adjust pattern area based on top toolbar transparency
    local pattern_y1, pattern_y2
    if top_is_transparent then
      pattern_y1 = y1 + border_inset
      pattern_y2 = y2 - border_inset
    else
      pattern_y1 = content_y1 + border_inset
      pattern_y2 = content_y2 - border_inset
    end

    local clip_rounding = math.max(0, self.config.rounding - border_inset)
    ImGui.DrawList_PushClipRect(dl, pattern_x1, pattern_y1, pattern_x2, pattern_y2, true)
    Pattern.draw(ctx, dl, pattern_x1, pattern_y1, pattern_x2, pattern_y2, self.config.background_pattern)
    ImGui.DrawList_PopClipRect(dl)
  end

  -- Draw border
  if self.config.border_thickness > 0 then
    Rendering.draw_border(dl, x1, y1, w, h, self.config.border_color, self.config.rounding, self.config.border_thickness)
  end

  -- ============================================================================
  -- DRAW TOOLBAR ELEMENTS
  -- ============================================================================

  -- Top toolbar elements
  if top_cfg then
    Toolbar.draw_elements(ctx, dl, x1, y1, w, toolbar_sizes.top, self, top_cfg, self.id, "top")
  end

  -- Bottom toolbar elements
  if bottom_cfg then
    Toolbar.draw_elements(ctx, dl, x1, y2 - toolbar_sizes.bottom, w, toolbar_sizes.bottom, self, bottom_cfg, self.id, "bottom")
  end

  -- ============================================================================
  -- DRAW VERTICAL TOOLBARS (LEFT/RIGHT)
  -- ============================================================================

  local sidebar_height = content_y2 - content_y1

  -- Left toolbar
  if left_cfg then
    Toolbar.draw_elements(ctx, dl, x1, content_y1, w, sidebar_height, self, left_cfg, self.id, "left")
  end

  -- Right toolbar
  if right_cfg then
    local right_x = x2 - toolbar_sizes.right
    Toolbar.draw_elements(ctx, dl, right_x, content_y1, w, sidebar_height, self, right_cfg, self.id, "right")
  end

  -- Store bounds for corner buttons (drawn in end_draw for z-order)
  self._corner_button_bounds = {x1, y1, w, h}

  -- ============================================================================
  -- CALCULATE CONTENT AREA
  -- ============================================================================

  local border_inset = self.config.border_thickness
  local scrollbar_width = Scrolling.get_scrollbar_width(self)

  self.child_x = x1 + border_inset + toolbar_sizes.left
  self.child_y = content_y1 + border_inset

  -- Note: toolbar_sizes.right NOT subtracted - scrollbar overlaps right toolbar (draws on top)
  local child_w = w - (border_inset * 2) - scrollbar_width - toolbar_sizes.left
  local child_h = (content_y2 - content_y1) - (border_inset * 2)

  if child_w < 1 then child_w = 1 end
  if child_h < 1 then child_h = 1 end

  self.child_width = child_w
  self.child_height = child_h
  self.actual_child_height = child_h

  ImGui.SetCursorScreenPos(ctx, self.child_x, self.child_y)

  -- Apply padding
  local padding = self.config.padding or 0
  if padding > 0 then
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, padding, padding)
  end

  -- Begin child window
  local success = Content.begin_child(ctx, self.id, child_w, child_h, self.config.scroll, self)

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
  -- Update scrollbar and end child window
  if self._child_began_successfully then
    Scrolling.update_scrollbar(ctx, self)
    Content.end_child(ctx, self)
    Scrolling.draw_scrollbar(ctx, self)
  end

  -- Draw corner buttons (z-order: above content, below popups)
  if self._corner_button_bounds then
    local top_toolbar = Toolbar.get_toolbar_config(self.config, "top")
    if not top_toolbar or self.config.corner_buttons_always_visible then
      local x1, y1, w, h = table.unpack(self._corner_button_bounds)
      CornerButtons.draw(ctx, x1, y1, w, h, self.config, self.id)
    end
  end

  -- Pop ID scope
  if self._id_scope_pushed then
    ImGui.PopID(ctx)
    self._id_scope_pushed = false
  end
end

-- ============================================================================
-- PANEL METHODS
-- ============================================================================

function Panel:reset()
  self.had_scrollbar_last_frame = false
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

-- State management methods (delegate to state module)
Panel.get_search_text = function(self) return State.get_search_text(self) end
Panel.set_search_text = function(self, text) State.set_search_text(self, text) end
Panel.get_sort_mode = function(self) return State.get_sort_mode(self) end
Panel.set_sort_mode = function(self, mode) State.set_sort_mode(self, mode) end
Panel.get_sort_direction = function(self) return State.get_sort_direction(self) end
Panel.set_sort_direction = function(self, direction) State.set_sort_direction(self, direction) end
Panel.set_tabs = function(self, tabs, active_id) State.set_tabs(self, tabs, active_id) end
Panel.get_tabs = function(self) return State.get_tabs(self) end
Panel.get_active_tab_id = function(self) return State.get_active_tab_id(self) end
Panel.set_active_tab_id = function(self, id) State.set_active_tab_id(self, id) end
Panel.get_current_mode = function(self) return State.get_current_mode(self) end
Panel.set_current_mode = function(self, mode) State.set_current_mode(self, mode) end
Panel.is_overflow_visible = function(self) return State.is_overflow_visible(self) end
Panel.show_overflow_modal = function(self) State.show_overflow_modal(self) end
Panel.close_overflow_modal = function(self) State.close_overflow_modal(self) end

-- ============================================================================
-- STANDALONE DRAW FUNCTION
-- ============================================================================

--- Draw a panel (stateless convenience function)
--- @param ctx userdata ImGui context
--- @param id string Panel ID
--- @param width number Panel width
--- @param height number Panel height
--- @param content_fn function Content render function
--- @param config table Panel config
--- @return table Panel instance
function M.draw(ctx, id, width, height, content_fn, config)
  local panel = M.new({
    id = id,
    width = width,
    height = height,
    config = config or DEFAULTS,
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

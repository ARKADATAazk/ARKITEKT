-- @noindex
-- ReArkitekt/gui/widgets/panel/init.lua
-- Main panel API with header positioning and corner buttons support

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Header = require('rearkitekt.gui.widgets.panel.header')
local Content = require('rearkitekt.gui.widgets.panel.content')
local Background = require('rearkitekt.gui.widgets.panel.background')
local TabAnimator = require('rearkitekt.gui.widgets.panel.tab_animator')
local Scrollbar = require('rearkitekt.gui.widgets.controls.scrollbar')
local Button = require('rearkitekt.gui.widgets.controls.button')
local Config = require('rearkitekt.gui.widgets.panel.config')

local M = {}
local DEFAULTS = Config.DEFAULTS

local panel_id_counter = 0

local function generate_unique_id(prefix)
  panel_id_counter = panel_id_counter + 1
  return string.format("%s_%d", prefix or "panel", panel_id_counter)
end

local function deep_merge(base, override)
  if not override then return base end
  if not base then return override end
  
  local result = {}
  
  for k, v in pairs(base) do
    result[k] = v
  end
  
  for k, v in pairs(override) do
    if type(v) == 'table' and type(result[k]) == 'table' then
      result[k] = deep_merge(result[k], v)
    else
      result[k] = v
    end
  end
  
  return result
end

local Panel = {}
Panel.__index = Panel

function M.new(opts)
  opts = opts or {}
  
  local id = opts.id or generate_unique_id("panel")
  
  local panel = setmetatable({
    id = id,
    config = deep_merge(DEFAULTS, opts.config),
    
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
-- CORNER BUTTONS
-- ============================================================================

local function draw_corner_button(ctx, dl, x, y, size, config, id, rounding)
  local btn_config = {
    label = config.label or config.icon or "",
    icon = config.icon,
    tooltip = config.tooltip,
    on_click = config.on_click,
    rounding = rounding,
    width = size,
    height = size,
  }
  
  -- Apply custom colors if provided
  if config.bg_color then btn_config.bg_color = config.bg_color end
  if config.bg_hover_color then btn_config.bg_hover_color = config.bg_hover_color end
  if config.text_color then btn_config.text_color = config.text_color end
  
  return Button.draw(ctx, dl, x, y, size, size, btn_config, id)
end

local function draw_corner_buttons(ctx, dl, x, y, w, h, config, panel_id, rounding)
  if not config.corner_buttons then return end
  
  local cb = config.corner_buttons
  local size = cb.size or 30
  local margin = cb.margin or 8
  
  -- Top-left
  if cb.top_left then
    draw_corner_button(ctx, dl, x + margin, y + margin, size, cb.top_left, panel_id .. "_corner_tl", rounding)
  end
  
  -- Top-right
  if cb.top_right then
    draw_corner_button(ctx, dl, x + w - size - margin, y + margin, size, cb.top_right, panel_id .. "_corner_tr", rounding)
  end
  
  -- Bottom-left
  if cb.bottom_left then
    draw_corner_button(ctx, dl, x + margin, y + h - size - margin, size, cb.bottom_left, panel_id .. "_corner_bl", rounding)
  end
  
  -- Bottom-right
  if cb.bottom_right then
    draw_corner_button(ctx, dl, x + w - size - margin, y + h - size - margin, size, cb.bottom_right, panel_id .. "_corner_br", rounding)
  end
end

-- ============================================================================
-- MAIN RENDERING
-- ============================================================================

function Panel:begin_draw(ctx)
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
  
  -- Draw background pattern in content area
  Background.draw(dl, x1, content_y1, x2, content_y2, self.config.background_pattern)
  
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
  
  local success = Content.begin_child(ctx, self.id, child_w, child_h, scroll_config)
  
  if success then
    local win_x, win_y = ImGui.GetWindowPos(ctx)
    local win_w, win_h = ImGui.GetWindowSize(ctx)
    self.visible_bounds = {win_x, win_y, win_x + win_w, win_y + win_h}
    
    if self.config.padding > 0 then
      ImGui.SetCursorPos(ctx, self.config.padding, self.config.padding)
    end
  end
  
  return success
end

function Panel:end_draw(ctx)
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

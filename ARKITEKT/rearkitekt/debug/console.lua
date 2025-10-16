-- @noindex
-- rearkitekt/debug/console.lua
-- Visual debug console widget

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Logger = require('rearkitekt.debug.logger')
local Panel = require('rearkitekt.gui.widgets.panel')
local Config = require('rearkitekt.gui.widgets.panel.config')

local M = {}

local function hexrgb(hex)
  if hex:sub(1, 1) == "#" then hex = hex:sub(2) end
  local h = tonumber(hex, 16)
  if not h then return 0xFFFFFFFF end
  return (#hex == 8) and h or ((h << 8) | 0xFF)
end

local COLORS = {
  teal = hexrgb("#41E0A3FF"),
  red = hexrgb("#E04141FF"),
  yellow = hexrgb("#E0B341FF"),
  grey_84 = hexrgb("#D6D6D6FF"),
  grey_60 = hexrgb("#999999FF"),
  grey_52 = hexrgb("#858585FF"),
  grey_40 = hexrgb("#666666FF"),
  grey_20 = hexrgb("#333333FF"),
  grey_18 = hexrgb("#2E2E2EFF"),
  grey_14 = hexrgb("#242424FF"),
  grey_10 = hexrgb("#1A1A1AFF"),
  grey_08 = hexrgb("#141414FF"),
}

local LEVEL_COLORS = {
  INFO = COLORS.teal,
  DEBUG = COLORS.grey_60,
  WARN = COLORS.yellow,
  ERROR = COLORS.red,
  PROFILE = COLORS.grey_52,
}

local LEVEL_ICONS = {
  INFO = "●",
  DEBUG = "○",
  WARN = "⚠",
  ERROR = "✕",
  PROFILE = "⏱",
}

function M.new(config)
  config = config or {}
  
  local console = {
    filter_category = "All",
    search_text = "",
    paused = false,
    
    last_frame_time = 0,
    fps = 60,
    frame_time_ms = 16.7,
    
    scroll_pos = 0,
    scroll_max = 0,
    user_scrolled_up = false,
    
    panel = nil,
  }
  
  local panel_config = {
    bg_color = hexrgb("#0D0D0DFF"),
    border_color = hexrgb("#000000DD"),
    border_thickness = 1,
    rounding = 8,
    padding = 8,
    
    scroll = {
      flags = 0,
      bg_color = 0x00000000,
    },
    
    background_pattern = {
      enabled = false,
    },
    
    header = {
      enabled = true,
      height = 30,
      -- Colors and rounding come from Panel defaults now
      
      elements = {
        {
          id = "clear_btn",
          type = "button",
          spacing_before = 0,
          config = {
            id = "clear",
            label = "Clear",
            width = 50,
            -- All colors come from Panel defaults
            on_click = function()
              Logger.clear()
            end,
          },
        },
        {
          id = "export_btn",
          type = "button",
          spacing_before = 0,
          config = {
            id = "export",
            label = "Export",
            width = 55,
            on_click = function()
              local entries = Logger.get_entries()
              local export_text = ""
              for _, entry in ipairs(entries) do
                local h = math.floor(entry.time / 3600) % 24
                local m = math.floor(entry.time / 60) % 60
                local s = entry.time % 60
                local time_str = string.format("%02d:%02d:%06.3f", h, m, s)
                export_text = export_text .. string.format("[%s] [%s] %s: %s\n",
                  time_str, entry.level, entry.category, entry.message)
              end
              reaper.CF_SetClipboard(export_text)
              Logger.info("CONSOLE", "Exported to clipboard")
            end,
          },
        },
        {
          id = "sep1",
          type = "separator",
          width = 12,
          spacing_before = 0,
        },
        {
          id = "filter",
          type = "dropdown_field",
          width = 90,
          spacing_before = 0,
          config = {
            options = {
              { value = "All", label = "All" },
              { value = "INFO", label = "INFO" },
              { value = "DEBUG", label = "DEBUG" },
              { value = "WARN", label = "WARN" },
              { value = "ERROR", label = "ERROR" },
              { value = "PROFILE", label = "PROFILE" },
            },
            on_change = function(value)
              console.filter_category = value
            end,
          },
        },
        {
          id = "search",
          type = "search_field",
          width = 180,
          spacing_before = 0,
          config = {
            placeholder = "Search...",
            on_change = function(text)
              console.search_text = text
            end,
          },
        },
        {
          id = "spacer",
          type = "separator",
          flex = 1,
          spacing_before = 0,
        },
        {
          id = "pause_btn",
          type = "button",
          spacing_before = 0,
          config = {
            id = "pause",
            label = "Pause",
            width = 52,
            on_click = function()
              console.paused = not console.paused
            end,
            custom_draw = function(ctx, dl, x, y, width, height, is_hovered, is_active, text_color)
              local label = console.paused and "Resume" or "Pause"
              local text_w = ImGui.CalcTextSize(ctx, label)
              local text_x = x + (width - text_w) * 0.5
              local text_y = y + (height - ImGui.GetTextLineHeight(ctx)) * 0.5
              
              local indicator_x = x + 8
              local indicator_y = y + height * 0.5
              local indicator_color = console.paused and COLORS.yellow or COLORS.teal
              ImGui.DrawList_AddCircleFilled(dl, indicator_x, indicator_y, 3, indicator_color)
              
              ImGui.DrawList_AddText(dl, text_x + 8, text_y, text_color, label)
            end,
          },
        },
      },
    },
  }
  
  console.panel = Panel.new({
    id = "debug_console_panel",
    config = panel_config,
  })
  
  local function format_time(timestamp)
    local h = math.floor(timestamp / 3600) % 24
    local m = math.floor(timestamp / 60) % 60
    local s = timestamp % 60
    return string.format("%02d:%02d:%06.3f", h, m, s)
  end
  
  local function draw_log_entries(ctx)
    local entries = Logger.get_entries()
    local dl = ImGui.GetWindowDrawList(ctx)
    
    for _, entry in ipairs(entries) do
      local show = true
      
      if console.filter_category ~= "All" and entry.level ~= console.filter_category then
        show = false
      end
      
      if console.search_text ~= "" then
        local search_lower = console.search_text:lower()
        local text = (entry.message .. entry.category):lower()
        if not text:find(search_lower, 1, true) then
          show = false
        end
      end
      
      if show then
        local color = LEVEL_COLORS[entry.level] or COLORS.grey_60
        local icon = LEVEL_ICONS[entry.level] or "○"
        
        local time_str = format_time(entry.time)
        local level_str = string.format("[%s%s]", icon, entry.level)
        local category_str = entry.category
        
        local sx, sy = ImGui.GetCursorScreenPos(ctx)
        local x = sx
        
        ImGui.DrawList_AddText(dl, x, sy, COLORS.grey_52, time_str)
        x = x + 90
        
        ImGui.DrawList_AddText(dl, x, sy, color, level_str)
        x = x + 65
        
        ImGui.DrawList_AddText(dl, x, sy, COLORS.grey_60, category_str)
        x = x + 80
        
        local msg_str = entry.message
        if entry.data then
          msg_str = msg_str .. " {...}"
        end
        
        ImGui.DrawList_AddText(dl, x, sy, COLORS.grey_84, msg_str)
        
        ImGui.Dummy(ctx, 0, 16)
      end
    end
  end
  
  local function draw_footer(ctx, w)
    local dl = ImGui.GetWindowDrawList(ctx)
    local sx, sy = ImGui.GetCursorScreenPos(ctx)
    
    local footer_h = 24
    local x1, y1 = sx, sy
    local x2, y2 = sx + w, sy + footer_h
    
    ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, COLORS.grey_18, 0, 0)
    ImGui.DrawList_AddLine(dl, x1, y1, x2, y1, hexrgb("#000000DD"), 1.0)
    
    local fps_str = string.format("FPS: %d", console.fps)
    local frame_str = string.format("Frame: %.1fms", console.frame_time_ms)
    local count_str = string.format("Logs: %d/%d", Logger.get_count(), Logger.get_max())
    
    local text_y = y1 + 4
    
    ImGui.DrawList_AddText(dl, x1 + 8, text_y, COLORS.grey_60, fps_str)
    ImGui.DrawList_AddText(dl, x1 + 80, text_y, COLORS.grey_60, frame_str)
    ImGui.DrawList_AddText(dl, x1 + 180, text_y, COLORS.grey_60, count_str)
    
    ImGui.Dummy(ctx, 0, footer_h)
  end
  
  function console:update()
    local current_time = reaper.time_precise()
    if self.last_frame_time > 0 then
      local delta = current_time - self.last_frame_time
      self.frame_time_ms = delta * 1000
      self.fps = math.floor(1.0 / delta + 0.5)
    end
    self.last_frame_time = current_time
  end
  
  function console:render(ctx)
    self:update()
    
    local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)
    local sx, sy = ImGui.GetCursorScreenPos(ctx)
    
    if self.panel:begin_draw(ctx) then
      local scroll_y = ImGui.GetScrollY(ctx)
      local scroll_max_y = ImGui.GetScrollMaxY(ctx)
      
      local was_at_bottom = (scroll_max_y == 0) or (scroll_y >= scroll_max_y - 5)
      
      if scroll_y < self.scroll_pos then
        self.user_scrolled_up = true
      elseif scroll_y >= scroll_max_y - 5 then
        self.user_scrolled_up = false
      end
      
      self.scroll_pos = scroll_y
      self.scroll_max = scroll_max_y
      
      draw_log_entries(ctx)
      
      if not self.paused and not self.user_scrolled_up and was_at_bottom then
        ImGui.SetScrollHereY(ctx, 1.0)
      end
    end
    self.panel:end_draw(ctx)
    
    local footer_y = sy + avail_h - 24
    ImGui.SetCursorScreenPos(ctx, sx, footer_y)
    draw_footer(ctx, avail_w)
  end
  
  return console
end

return M
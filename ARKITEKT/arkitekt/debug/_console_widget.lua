-- @noindex
-- arkitekt/debug/_console_widget.lua
-- Console widget implementation with ColoredTextView

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Logger = require('arkitekt.debug.logger')
local Panel = require('arkitekt.gui.widgets.containers.panel')
local Config = require('arkitekt.gui.widgets.containers.panel.defaults')
local ColoredTextView = require('arkitekt.gui.widgets.text.colored_text_view')
local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb


local M = {}

local function hexrgb(hex)
  if hex:sub(1, 1) == "#" then hex = hex:sub(2) end
  local h = tonumber(hex, 16)
  if not h then return hexrgb("#FFFFFF") end
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

-- ==========================================================================
-- CATEGORY COLOR SCHEME
-- ==========================================================================
-- Colors are organized by functional group for visual coherence:
--
-- BLUE FAMILY (Playback/Transport) - Audio and timing operations
--   #4682B4 Steel Blue   - TRANSPORT (play/stop/pause/seek)
--   #00CED1 Dark Cyan    - TRANSITIONS (region transitions)
--   #5F9EA0 Cadet Blue   - PLAYBACK (playback monitoring)
--   #6495ED Cornflower   - SEQUENCER (sequence building)
--   #7B68EE Med Slate    - QUANTIZE (beat quantization)
--
-- GOLD/AMBER FAMILY (State/Data) - Data flow and persistence
--   #DAA520 Goldenrod    - STATE (state management)
--   #CD853F Peru         - STORAGE (save/load operations)
--   #D2691E Chocolate    - BRIDGE (coordinator bridge)
--
-- PURPLE FAMILY (Domains) - Business logic domains
--   #9370DB Med Purple   - PLAYLIST (playlist domain)
--   #20B2AA Lt Sea Green - REGION (region domain)
--   #BA55D3 Med Orchid   - UI_PREFERENCES (UI prefs domain)
--   #DB7093 Pale Violet  - DEPENDENCY (dependency graph)
--
-- GREEN FAMILY (Actions/Control) - User actions
--   #41E0A3 Teal         - ENGINE (main engine)
--   #98FB98 Pale Green   - CONTROLLER (user commands)
--   #66CDAA Med Aqua     - COORDINATOR (tile coordinator)
--   #F5DEB3 Wheat        - UNDO (undo operations)
--
-- GREY FAMILY (System/UI) - Framework and UI
--   #D6D6D6 Light Grey   - GUI, SYSTEM (general UI/system)
--   #87CEEB Sky Blue     - WIDGET, EVENTS (widget events)
--   #999999 Med Grey     - CONSOLE (console messages)
--
-- SPECIAL
--   #00FF88 Bright Green - TEST (test results)
-- ==========================================================================

local CATEGORY_COLORS = {
  -- Playback/Transport (Blues)
  TRANSPORT   = hexrgb("#4682B4FF"),  -- Steel Blue
  TRANSITIONS = hexrgb("#00CED1FF"),  -- Dark Cyan
  PLAYBACK    = hexrgb("#5F9EA0FF"),  -- Cadet Blue
  SEQUENCER   = hexrgb("#6495EDFF"),  -- Cornflower Blue
  QUANTIZE    = hexrgb("#7B68EEFF"),  -- Medium Slate Blue

  -- State/Data (Golds)
  STATE   = hexrgb("#DAA520FF"),  -- Goldenrod
  STORAGE = hexrgb("#CD853FFF"),  -- Peru
  BRIDGE  = hexrgb("#D2691EFF"),  -- Chocolate

  -- Domains (Purples/Teals)
  PLAYLIST       = hexrgb("#9370DBFF"),  -- Medium Purple
  REGION         = hexrgb("#20B2AAFF"),  -- Light Sea Green
  UI_PREFERENCES = hexrgb("#BA55D3FF"),  -- Medium Orchid
  DEPENDENCY     = hexrgb("#DB7093FF"),  -- Pale Violet Red

  -- Actions/Control (Greens)
  ENGINE      = COLORS.teal,             -- #41E0A3
  CONTROLLER  = hexrgb("#98FB98FF"),     -- Pale Green
  COORDINATOR = hexrgb("#66CDAAFF"),     -- Medium Aquamarine
  UNDO        = hexrgb("#F5DEB3FF"),     -- Wheat

  -- System/UI (Greys)
  GUI     = COLORS.grey_84,
  SYSTEM  = COLORS.grey_84,
  WIDGET  = hexrgb("#87CEEBFF"),  -- Sky Blue
  EVENTS  = hexrgb("#87CEEBFF"),  -- Sky Blue
  CONSOLE = COLORS.grey_60,

  -- Special
  TEST = hexrgb("#00FF88FF"),  -- Bright Green
}

local LEVEL_COLORS = {
  INFO = COLORS.teal,
  DEBUG = COLORS.grey_60,
  WARN = COLORS.yellow,
  ERROR = COLORS.red,
  PROFILE = COLORS.grey_52,
}

local function get_entry_color(entry)
  if CATEGORY_COLORS[entry.category] then
    return CATEGORY_COLORS[entry.category]
  elseif LEVEL_COLORS[entry.level] then
    return LEVEL_COLORS[entry.level]
  else
    return COLORS.grey_60
  end
end

local function get_category_color(category)
  return CATEGORY_COLORS[category] or COLORS.grey_60
end

-- Format time ago string
local function format_time_ago(seconds)
  if seconds < 1 then
    return string.format("%.0fms", seconds * 1000)
  elseif seconds < 60 then
    return string.format("%.1fs", seconds)
  else
    return string.format("%.0fm", seconds / 60)
  end
end

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
    text_view = ColoredTextView.new(),
    last_entry_count = 0,
  }
  
  local panel_config = {
    bg_color = hexrgb("#0D0D0DFF"),
    border_color = hexrgb("#000000DD"),
    border_thickness = 1,
    rounding = 8,
    padding = 8,
    
    scroll = {
      flags = 0,
      bg_color = hexrgb("#00000000"),
    },
    
    background_pattern = {
      enabled = false,
    },
    
    header = {
      enabled = true,
      height = 30,
      
      elements = {
        {
          id = "clear_btn",
          type = "button",
          spacing_before = 0,
          config = {
            id = "clear",
            label = "Clear",
            width = 50,
            on_click = function()
              Logger.clear()
              console.text_view:set_lines({})
              console.last_entry_count = 0
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
          id = "copy_btn",
          type = "button",
          spacing_before = 0,
          config = {
            id = "copy",
            label = "Copy",
            width = 50,
            on_click = function()
              if console.text_view:copy() then
                Logger.info("CONSOLE", "Selection copied to clipboard")
              else
                Logger.warn("CONSOLE", "No selection to copy")
              end
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
          type = "combo",
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
              console:update_text_view()
            end,
          },
        },
        {
          id = "search",
          type = "inputtext",
          width = 180,
          spacing_before = 0,
          config = {
            preset = "search",
            placeholder = "Search...",
            on_change = function(text)
              console.search_text = text
              console:update_text_view()
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
        {
          id = "tests_btn",
          type = "button",
          spacing_before = 0,
          config = {
            id = "tests",
            label = "Tests",
            width = 48,
            on_click = function()
              local TestRunner = require('arkitekt.debug.test_runner')
              local apps = TestRunner.get_registered_apps()
              if #apps == 0 then
                Logger.warn("TEST", "No test suites registered")
              else
                TestRunner.run_all()
              end
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

  -- ============================================================================
  -- LIVE SLOTS RENDERING
  -- ============================================================================

  -- Render the live slots section
  -- Returns the height consumed by live slots
  function console:render_live_slots(ctx, avail_w)
    local live_slots = Logger.get_live_slots()
    local slot_count = Logger.get_live_count()

    if slot_count == 0 then
      return 0
    end

    local now = reaper.time_precise()
    local line_height = ImGui.GetTextLineHeightWithSpacing(ctx)
    local row_height = line_height + 2
    local header_height = 20
    local padding = 4

    -- Calculate height needed for expanded slots
    local total_height = header_height + padding
    local sorted_slots = {}
    for key, slot in pairs(live_slots) do
      sorted_slots[#sorted_slots + 1] = { key = key, slot = slot }
    end
    table.sort(sorted_slots, function(a, b)
      return a.slot.last_update > b.slot.last_update
    end)

    for _, entry in ipairs(sorted_slots) do
      total_height = total_height + row_height
      if entry.slot.expanded then
        local history_lines = math.min(#entry.slot.history, 8)
        total_height = total_height + (history_lines * line_height) + 4
      end
    end

    -- Draw live slots container
    ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#141414FF"))
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ChildRounding, 4)

    local child_flags = ImGui.WindowFlags_NoScrollbar
    if ImGui.BeginChild(ctx, "##LiveSlots", avail_w - 16, total_height, child_flags) then
      local dl = ImGui.GetWindowDrawList(ctx)
      local cx, cy = ImGui.GetCursorScreenPos(ctx)

      -- Header
      ImGui.TextColored(ctx, COLORS.grey_52, "LIVE")
      ImGui.SameLine(ctx)
      ImGui.TextDisabled(ctx, string.format("(%d)", slot_count))
      ImGui.SameLine(ctx, avail_w - 80)
      if ImGui.SmallButton(ctx, "Clear All##live") then
        Logger.clear_all_live()
      end

      ImGui.Separator(ctx)

      -- Render each slot
      for _, entry in ipairs(sorted_slots) do
        local slot = entry.slot
        local color = get_category_color(slot.category)
        local age = now - slot.last_update
        local stale = age > 5.0

        -- Fade color if stale
        local display_color = color
        if stale then
          display_color = (color & 0xFFFFFF00) | 0x60
        end

        -- Pulsing indicator for active slots
        if not stale then
          local pulse = math.abs(math.sin(now * 4)) * 0.3 + 0.7
          local indicator_color = (color & 0xFFFFFF00) | math.floor(pulse * 255)
          ImGui.TextColored(ctx, indicator_color, ">")
        else
          ImGui.TextColored(ctx, COLORS.grey_40, " ")
        end
        ImGui.SameLine(ctx)

        -- Category
        ImGui.TextColored(ctx, display_color, slot.category)
        ImGui.SameLine(ctx)

        -- Key (dimmed)
        ImGui.TextColored(ctx, COLORS.grey_40, ":" .. slot.key)
        ImGui.SameLine(ctx)

        -- Message
        ImGui.TextColored(ctx, display_color, slot.message)
        ImGui.SameLine(ctx)

        -- Update count and time
        local time_str = format_time_ago(age)
        ImGui.TextDisabled(ctx, string.format("(x%d, %s ago)", slot.update_count, time_str))

        -- Expand/collapse button
        ImGui.SameLine(ctx, avail_w - 50)
        local btn_label = slot.expanded and "[-]##" .. entry.key or "[+]##" .. entry.key
        if ImGui.SmallButton(ctx, btn_label) then
          slot.expanded = not slot.expanded
        end

        -- Expanded history
        if slot.expanded and #slot.history > 0 then
          ImGui.Indent(ctx, 24)
          local history_to_show = math.min(#slot.history, 8)
          for i = 1, history_to_show do
            local h = slot.history[i]
            local h_age = now - h.time
            ImGui.TextDisabled(ctx, string.format("-%s: %s", format_time_ago(h_age), h.message))
          end
          if #slot.history > 8 then
            ImGui.TextDisabled(ctx, string.format("... and %d more", #slot.history - 8))
          end
          ImGui.Unindent(ctx, 24)
        end
      end
    end
    ImGui.EndChild(ctx)
    ImGui.PopStyleVar(ctx)
    ImGui.PopStyleColor(ctx)

    ImGui.Spacing(ctx)

    return total_height + 8
  end

  -- ============================================================================
  -- LOG ENTRIES
  -- ============================================================================

  -- Convert log entries to colored text view format (without icons)
  function console:update_text_view()
    local entries = Logger.get_entries()
    local lines = {}
    
    for _, entry in ipairs(entries) do
      -- Apply filters
      local show = true
      if self.filter_category ~= "All" and entry.level ~= self.filter_category then
        show = false
      end
      if self.search_text ~= "" then
        local search_lower = self.search_text:lower()
        local text = (entry.message .. entry.category):lower()
        if not text:find(search_lower, 1, true) then
          show = false
        end
      end
      
      if show then
        local color = get_entry_color(entry)
        
        local msg_str = entry.message
        if entry.data then
          msg_str = msg_str .. " {...}"
        end
        
        -- Create line with colored segments (no icons)
        table.insert(lines, {
          segments = {
            {text = msg_str, color = color}
          }
        })
      end
    end
    
    self.text_view:set_lines(lines)
  end
  
  function console:update()
    local current_time = reaper.time_precise()
    if self.last_frame_time > 0 then
      local delta = current_time - self.last_frame_time
      self.frame_time_ms = delta * 1000
      self.fps = math.floor(1.0 / delta + 0.5)
    end
    self.last_frame_time = current_time
    
    -- Update text view if logs changed
    local current_count = Logger.get_count()
    if not self.paused and current_count ~= self.last_entry_count then
      self:update_text_view()
      self.last_entry_count = current_count
    end
  end
  
  local function draw_stats_overlay(ctx, w, h)
    local dl = ImGui.GetWindowDrawList(ctx)
    local sx, sy = ImGui.GetCursorScreenPos(ctx)

    -- Stats panel in top right
    local live_count = Logger.get_live_count()
    local stats_w = 200
    local stats_h = live_count > 0 and 78 or 60
    local padding = 12
    local stats_x = sx + w - stats_w - padding
    local stats_y = sy + padding

    -- Background with slight transparency
    local bg_color = hexrgb("#1A1A1AE6")
    local border_color = hexrgb("#333333FF")
    ImGui.DrawList_AddRectFilled(dl, stats_x, stats_y, stats_x + stats_w, stats_y + stats_h, bg_color, 6, 0)
    ImGui.DrawList_AddRect(dl, stats_x, stats_y, stats_x + stats_w, stats_y + stats_h, border_color, 6, 0, 1.0)

    -- FPS
    local fps_str = string.format("FPS: %d", console.fps)
    local fps_color = console.fps >= 60 and COLORS.teal or (console.fps >= 30 and COLORS.yellow or COLORS.red)
    ImGui.DrawList_AddText(dl, stats_x + 12, stats_y + 8, fps_color, fps_str)

    -- Frame time
    local frame_str = string.format("%.1fms", console.frame_time_ms)
    ImGui.DrawList_AddText(dl, stats_x + 100, stats_y + 8, COLORS.grey_60, frame_str)

    -- Log count
    local count_str = string.format("%d / %d logs", Logger.get_count(), Logger.get_max())
    ImGui.DrawList_AddText(dl, stats_x + 12, stats_y + 26, COLORS.grey_60, count_str)

    -- Live slots count (if any)
    if live_count > 0 then
      local live_str = string.format("%d live slots", live_count)
      ImGui.DrawList_AddText(dl, stats_x + 12, stats_y + 44, COLORS.teal, live_str)

      -- Prune stale hint
      ImGui.DrawList_AddText(dl, stats_x + 12, stats_y + 62, COLORS.grey_40, "stale after 10s")
    end
  end
  
  function console:render(ctx)
    self:update()

    local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)

    if self.panel:begin_draw(ctx) then
      -- Render live slots section first (if any)
      local live_height = self:render_live_slots(ctx, avail_w)

      -- Remaining height for log entries
      local log_height = avail_h - live_height
      if log_height > 50 then
        self.text_view:render(ctx, avail_w, log_height)
      end
    end
    self.panel:end_draw(ctx)

    -- Draw stats overlay in top right
    draw_stats_overlay(ctx, avail_w, avail_h)
  end
  
  -- Initialize with current logs
  console:update_text_view()
  
  return console
end

return M

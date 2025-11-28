-- @noindex
-- WalterBuilder/ui/panels/debug_console.lua
-- Debug console for logging conversion/loading operations

local ImGui = require 'imgui' '0.10'
local Ark = require('arkitekt')

local hexrgb = Ark.Colors.hexrgb

local M = {}

-- Singleton log storage
local logs = {}
local max_logs = 500

-- Log levels
M.LEVEL = {
  INFO = "info",
  SUCCESS = "success",
  WARN = "warn",
  ERROR = "error",
}

local level_colors = {
  info = "#AAAAAA",
  success = "#88CC88",
  warn = "#CCCC88",
  error = "#CC6666",
}

-- Add a log entry
function M.log(level, message, ...)
  local formatted = string.format(message, ...)
  local entry = {
    level = level or M.LEVEL.INFO,
    message = formatted,
    time = os.date("%H:%M:%S"),
  }
  logs[#logs + 1] = entry

  -- Trim old logs
  while #logs > max_logs do
    table.remove(logs, 1)
  end
end

-- Convenience functions
function M.info(message, ...)
  M.log(M.LEVEL.INFO, message, ...)
end

function M.success(message, ...)
  M.log(M.LEVEL.SUCCESS, message, ...)
end

function M.warn(message, ...)
  M.log(M.LEVEL.WARN, message, ...)
end

function M.error(message, ...)
  M.log(M.LEVEL.ERROR, message, ...)
end

-- Clear all logs
function M.clear()
  logs = {}
end

-- Get all logs as a string (for copying)
function M.get_all_text()
  local lines = {}
  for _, entry in ipairs(logs) do
    lines[#lines + 1] = string.format("[%s] [%s] %s", entry.time, entry.level:upper(), entry.message)
  end
  return table.concat(lines, "\n")
end

-- Get log count
function M.get_count()
  return #logs
end

-- Draw the console panel
function M.draw(ctx)
  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)

  -- Header with buttons
  if ImGui.Button(ctx, "Clear", 60, 0) then
    M.clear()
  end

  ImGui.SameLine(ctx)

  if ImGui.Button(ctx, "Copy All", 70, 0) then
    ImGui.SetClipboardText(ctx, M.get_all_text())
  end

  ImGui.SameLine(ctx)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#666666"))
  ImGui.Text(ctx, string.format("(%d entries)", #logs))
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 4)

  -- Log area
  local log_h = avail_h - 35
  ImGui.BeginChild(ctx, "debug_log_area", avail_w, log_h, 1)

  for _, entry in ipairs(logs) do
    local color = level_colors[entry.level] or "#AAAAAA"

    -- Time prefix
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#666666"))
    ImGui.Text(ctx, entry.time)
    ImGui.PopStyleColor(ctx)

    ImGui.SameLine(ctx)

    -- Level badge
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb(color))
    ImGui.Text(ctx, string.format("[%s]", entry.level:upper():sub(1, 4)))
    ImGui.PopStyleColor(ctx)

    ImGui.SameLine(ctx)

    -- Message
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#CCCCCC"))
    ImGui.TextWrapped(ctx, entry.message)
    ImGui.PopStyleColor(ctx)
  end

  -- Auto-scroll to bottom if near bottom
  if ImGui.GetScrollY(ctx) >= ImGui.GetScrollMaxY(ctx) - 20 then
    ImGui.SetScrollHereY(ctx, 1.0)
  end

  ImGui.EndChild(ctx)
end

return M

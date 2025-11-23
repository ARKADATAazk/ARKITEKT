-- @noindex
-- arkitekt/app/utils/monitor_detection.lua
-- Utility for detecting the correct monitor dimensions for REAPER
-- Uses JS API when available for accurate multi-monitor support

local M = {}

-- Check if JS API is available
local function check_js_api()
  return reaper.JS_Window_GetRect ~= nil
end

--- Get REAPER window dimensions using JS API or fallback to viewport
--- @param ctx ImGui_Context|nil Optional ImGui context for viewport fallback
--- @return number x X position of REAPER window
--- @return number y Y position of REAPER window
--- @return number w Width of REAPER window
--- @return number h Height of REAPER window
function M.get_reaper_window_bounds(ctx)
  local JS_API_available = check_js_api()

  if JS_API_available then
    local hwnd = reaper.GetMainHwnd()
    local retval, left, top_y, right, bottom = reaper.JS_Window_GetRect(hwnd)

    if retval then
      return left, top_y, right - left, bottom - top_y
    end
  end

  -- Fallback to viewport (may not work correctly on multi-monitor setups)
  if ctx then
    local ImGui = require 'imgui' '0.10'
    local viewport = ImGui.GetMainViewport(ctx)
    local x, y = ImGui.Viewport_GetPos(viewport)
    local w, h = ImGui.Viewport_GetSize(viewport)
    return x, y, w, h
  end

  -- Last resort: return 0,0 with screen dimensions
  -- This will position at top-left of main monitor
  return 0, 0, 1920, 1080
end

--- Get just the dimensions (width and height) without position
--- Useful when you only need size info for fullscreen windows
--- @param ctx ImGui_Context|nil Optional ImGui context for viewport fallback
--- @return number w Width of REAPER window
--- @return number h Height of REAPER window
function M.get_reaper_window_size(ctx)
  local _, _, w, h = M.get_reaper_window_bounds(ctx)
  return w, h
end

--- Check if JS API is available for accurate monitor detection
--- @return boolean true if JS API is available
function M.is_js_api_available()
  return check_js_api()
end

return M

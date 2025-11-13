-- @noindex
-- Region_Playlist/ui/status.lua
-- Status bar configuration

local StatusBar = require("rearkitekt.app.chrome.status_bar")
local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb


local M = {}

-- Status priority (highest priority wins):
-- 1. Errors (red)
-- 2. Warnings (yellow/orange)
-- 3. Info states (blue)
-- 4. Playing (green)
-- 5. Ready (teal)

local STATUS_COLORS = {
  ERROR = hexrgb("#E04141"),     -- Red
  WARNING = hexrgb("#E0B341"),  -- Yellow/Orange
  INFO = hexrgb("#4A9EFF"),     -- Blue
  PLAYING = hexrgb("#41E0A3"),  -- Green/Teal
  READY = hexrgb("#41E0A3"),    -- Green/Teal
  IDLE = hexrgb("#888888"),     -- Gray
}

local function get_app_status(State)
  return function()
    reaper.ShowConsoleMsg("[STATUS DEBUG] get_app_status function called\n")
    
    -- Ensure we always return something valid
    local ok, result = pcall(function()
      local bridge = State.get_bridge()
      local bridge_state = bridge:get_state()
    
    -- >>> STATUS DETECTION (BEGIN)
    local status_parts = {}
    local status_color = STATUS_COLORS.READY
    local priority = 5  -- Lower number = higher priority
    
    -- Check for undo/redo availability (info)
    if State.can_undo and State.can_undo() then
      table.insert(status_parts, "Undo Available")
      if priority > 3 then
        status_color = STATUS_COLORS.INFO
        priority = 3
      end
    end
    
    -- Check for active search filter (info)
    local search_filter = State.get_search_filter and State.get_search_filter() or ""
    if search_filter and search_filter ~= "" then
      table.insert(status_parts, string.format("Filter: '%s'", search_filter))
      if priority > 3 then
        status_color = STATUS_COLORS.INFO
        priority = 3
      end
    end
    
    -- Check for playback state (playing)
    if bridge_state.is_playing then
      local current_rid = bridge:get_current_rid()
      if current_rid then
        local region = State.get_region_by_rid(current_rid)
        if region then
          local progress = bridge:get_progress() or 0
          local time_remaining = bridge:get_time_remaining()
          local play_text = string.format("▶ %s [%d/%d] %.0f%%", 
            region.name, 
            bridge_state.playlist_pointer, 
            #bridge_state.playlist_order,
            progress * 100)
          if time_remaining then
            play_text = play_text .. string.format(" (%.1fs)", time_remaining)
          end
          table.insert(status_parts, 1, play_text)  -- Insert at front
          if priority > 4 then
            status_color = STATUS_COLORS.PLAYING
            priority = 4
          end
        end
      end
    end
    
    -- Build base info (always shown)
    local mode_text = State.get_layout_mode() == 'horizontal' and "Timeline" or "List"
    local quantize_text = bridge_state.quantize_mode or "none"
    if quantize_text ~= "none" then
      quantize_text = "Q:" .. quantize_text
    else
      quantize_text = "Q:Off"
    end
    
    -- Add playlist info
    local active_playlist = State.get_active_playlist and State.get_active_playlist()
    local playlist_info = ""
    if active_playlist then
      local region_count = active_playlist.order and #active_playlist.order or 0
      playlist_info = string.format("%s (%d)", active_playlist.name or "Untitled", region_count)
    end
    
    -- Build final status text
    local base_parts = {}
    if playlist_info ~= "" then
      table.insert(base_parts, playlist_info)
    end
    table.insert(base_parts, mode_text)
    table.insert(base_parts, quantize_text)
    
    -- Prepend dynamic status if any
    local final_parts = {}
    if #status_parts > 0 then
      for _, part in ipairs(status_parts) do
        table.insert(final_parts, part)
      end
    end
    for _, part in ipairs(base_parts) do
      table.insert(final_parts, part)
    end
    
      local info_text = table.concat(final_parts, "  •  ")
      
      -- Failsafe: ensure we never return empty text
      if not info_text or info_text == "" then
        info_text = "[Status Error]"
      end
      -- <<< STATUS DETECTION (END)
      
      return {
        color = status_color,
        text = info_text,
        buttons = nil,
        right_buttons = nil,
      }
    end)
    
    if ok then
      reaper.ShowConsoleMsg("[STATUS DEBUG] Returning text: " .. (result.text or "nil") .. "\n")
      return result
    else
      -- Error occurred, return diagnostic
      reaper.ShowConsoleMsg("[STATUS DEBUG] ERROR: " .. tostring(result) .. "\n")
      return {
        color = STATUS_COLORS.ERROR,
        text = "Status Error: " .. tostring(result),
        buttons = nil,
        right_buttons = nil,
      }
    end
  end
end

function M.create(State, Style)
  return StatusBar.new({
    height = 20,
    get_status = get_app_status(State),
    style = Style and { palette = Style.palette } or nil
  })
end

-- Export get_status_func for direct use by Shell
function M.get_status_func(State)
  return get_app_status(State)
end

return M
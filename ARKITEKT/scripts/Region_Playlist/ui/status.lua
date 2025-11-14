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
  PLAYING = hexrgb("#49ff70ff"),  -- Green/Teal
  READY = hexrgb("#54ff4eff"),    -- Green/Teal
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
    -- Show ONLY ONE status message at a time (highest priority wins)
    local status_message = nil
    local status_color = STATUS_COLORS.READY

    -- Track override state changes
    if State.check_override_state_change then
      State.check_override_state_change(bridge_state.transport_override)
    end

    -- Priority 1: Errors (RED)
    if State.get_circular_dependency_error and State.get_circular_dependency_error() then
      status_message = State.get_circular_dependency_error()
      status_color = STATUS_COLORS.ERROR
    end

    -- Priority 2: State change notifications (INFO) - temporary feedback
    if not status_message then
      if State.get_state_change_notification then
        local notification = State.get_state_change_notification()
        if notification then
          status_message = notification
          status_color = STATUS_COLORS.INFO
        end
      end
    end

    -- Priority 3: Warnings (ORANGE) - only if no errors/notifications
    if not status_message then
      local active_playlist = State.get_active_playlist and State.get_active_playlist()
      if active_playlist and active_playlist.order and #active_playlist.order == 0 and not bridge_state.is_playing then
        status_message = "Playlist is empty"
        status_color = STATUS_COLORS.WARNING
      end
    end

    -- Priority 4: Info (BLUE) - only if no errors/warnings/notifications
    if not status_message then
      local selection_info = State.get_selection_info and State.get_selection_info()
      if selection_info and (selection_info.region_count > 0 or selection_info.playlist_count > 0) then
        local parts = {}
        if selection_info.region_count > 0 then
          table.insert(parts, string.format("%d Region%s", selection_info.region_count, selection_info.region_count > 1 and "s" or ""))
        end
        if selection_info.playlist_count > 0 then
          table.insert(parts, string.format("%d Playlist%s", selection_info.playlist_count, selection_info.playlist_count > 1 and "s" or ""))
        end
        status_message = table.concat(parts, ", ") .. " selected"
        status_color = STATUS_COLORS.INFO
      else
        local search_filter = State.get_search_filter and State.get_search_filter() or ""
        if search_filter and search_filter ~= "" then
          status_message = string.format("Filter: '%s'", search_filter)
          status_color = STATUS_COLORS.INFO
        end
      end
    end

    -- Priority 5: Playback state (GREEN) - overrides info/warnings but not errors/notifications
    if bridge_state.is_playing then
      local current_rid = bridge:get_current_rid()
      if current_rid then
        local region = State.get_region_by_rid(current_rid)
        if region then
          local progress = bridge:get_progress() or 0
          local time_remaining = bridge:get_time_remaining()

          -- Enhanced playback info
          local play_parts = {}
          table.insert(play_parts, string.format("▶ %s", region.name))
          table.insert(play_parts, string.format("[%d/%d]", bridge_state.playlist_pointer, #bridge_state.playlist_order))

          -- Add loop info if looping
          if bridge_state.current_loop and bridge_state.total_loops and bridge_state.total_loops > 1 then
            table.insert(play_parts, string.format("Loop %d/%d", bridge_state.current_loop, bridge_state.total_loops))
          end

          -- Add progress percentage
          table.insert(play_parts, string.format("%.0f%%", progress * 100))

          -- Add time remaining
          if time_remaining then
            table.insert(play_parts, string.format("%.1fs left", time_remaining))
          end

          local play_text = table.concat(play_parts, "  ")

          -- Playing state takes precedence over everything except errors and notifications
          if status_color ~= STATUS_COLORS.ERROR and not (status_color == STATUS_COLORS.INFO and State.get_state_change_notification and State.get_state_change_notification()) then
            status_message = play_text
            status_color = STATUS_COLORS.PLAYING
          end
        end
      end
    end

    -- Build base info (always shown)
    -- Add playlist info
    local active_playlist = State.get_active_playlist and State.get_active_playlist()
    local playlist_info = ""
    if active_playlist then
      local region_count = active_playlist.order and #active_playlist.order or 0
      playlist_info = string.format("%s (%d)", active_playlist.name or "Untitled", region_count)
    end

    -- Build final status text
    local final_parts = {}

    -- Add dynamic status message if present
    if status_message then
      table.insert(final_parts, status_message)
    end

    -- Add base info (only playlist name and count)
    if playlist_info ~= "" then
      table.insert(final_parts, playlist_info)
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
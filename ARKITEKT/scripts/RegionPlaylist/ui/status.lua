-- @noindex
-- RegionPlaylist/ui/status.lua
-- Status bar configuration

local StatusBar = require("arkitekt.app.chrome.status_bar.widget")
local Constants = require('RegionPlaylist.defs.constants')

local M = {}

-- Status priority (highest priority wins):
-- 1. Errors (red)
-- 2. Warnings (yellow/orange)
-- 3. Info states (light grey)
-- 4. Playing (light grey)
-- 5. Ready (light grey)

local STATUS_COLORS = Constants.STATUS

local function get_app_status(State)
  return function()
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

    -- Priority 2: State change notifications - temporary feedback
    if not status_message then
      if State.get_state_change_notification then
        local notification = State.get_state_change_notification()
        if notification then
          status_message = notification
          -- JUMP messages get WARNING color (orange), others get INFO (blue)
          if notification:match("^Jump:") then
            status_color = STATUS_COLORS.WARNING
          else
            status_color = STATUS_COLORS.INFO
          end
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

          -- Enhanced playback info with playlist name
          local play_parts = {}

          -- Add playlist name
          local active_playlist = State.get_active_playlist and State.get_active_playlist()
          if active_playlist then
            table.insert(play_parts, string.format("Playing '%s'", active_playlist.name or "Untitled"))
          end

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

          -- Playing state takes precedence over info/warnings but not errors or notifications
          local has_notification = State.get_state_change_notification and State.get_state_change_notification()
          if status_color ~= STATUS_COLORS.ERROR and status_color ~= STATUS_COLORS.WARNING and not (status_color == STATUS_COLORS.INFO and has_notification) then
            status_message = play_text
            status_color = STATUS_COLORS.PLAYING
          end
        end
      end
    end

    -- Build final status text (no base info, message only)
    local info_text = status_message or ""
      -- <<< STATUS DETECTION (END)
      
      return {
        color = status_color,
        text = info_text,
        buttons = nil,
        right_buttons = nil,
      }
    end)
    
    if ok then
      return result
    else
      -- Error occurred, return diagnostic
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
-- @noindex
-- ItemPicker Toggle - Simple show/hide toggle
-- Works with ARK_ItemPicker_Daemon.lua for instant UI

local ext_state_section = "ARK_ItemPicker_Daemon"
local ext_state_running = "daemon_running"
local ext_state_visible = "ui_visible"
local ext_state_toggle = "toggle_request"

-- Check if daemon is running
local daemon_running = reaper.GetExtState(ext_state_section, ext_state_running) == "1"

if not daemon_running then
  reaper.MB(
    "ItemPicker Daemon is not running!\n\n" ..
    "Please start 'ARK_ItemPicker_Daemon.lua' first.\n" ..
    "The daemon keeps the UI preloaded for instant show/hide.",
    "ItemPicker Toggle",
    0
  )
  return
end

-- Send toggle signal to daemon
reaper.SetExtState(ext_state_section, ext_state_toggle, "1", false)

-- Update button state to match visibility
local ui_visible = reaper.GetExtState(ext_state_section, ext_state_visible) == "1"
local new_state = ui_visible and 0 or 1  -- Will be opposite after toggle

local _, _, sec, cmd = reaper.get_action_context()
reaper.SetToggleCommandState(sec, cmd, new_state)
reaper.RefreshToolbar2(sec, cmd)

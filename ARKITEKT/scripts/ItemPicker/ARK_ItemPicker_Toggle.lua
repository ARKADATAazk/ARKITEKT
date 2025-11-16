-- @noindex
-- ItemPicker Toggle - Simple show/hide toggle
-- Works with ARK_ItemPicker_Daemon_v2.lua for instant UI

local ext_section = "ARK_ItemPicker_Daemon"

-- Check if daemon is running
local daemon_running = reaper.GetExtState(ext_section, "running") == "1"

if not daemon_running then
  reaper.MB(
    "ItemPicker Daemon is not running!\n\n" ..
    "Please start 'ARK_ItemPicker_Daemon_v2.lua' first.\n" ..
    "The daemon keeps the UI preloaded for instant show/hide.",
    "ItemPicker Toggle",
    0
  )
  return
end

-- Send toggle signal to daemon
reaper.SetExtState(ext_section, "toggle_request", "1", false)

-- Update button state to match visibility
local ui_visible = reaper.GetExtState(ext_section, "ui_visible") == "1"
local new_state = ui_visible and 0 or 1  -- Will be opposite after toggle

local _, _, sec, cmd = reaper.get_action_context()
reaper.SetToggleCommandState(sec, cmd, new_state)
reaper.RefreshToolbar2(sec, cmd)

-- @noindex
-- arkitekt/reaper/project_monitor.lua
-- Monitor project changes, switches, and state changes
-- Extracted from RegionPlaylist for reuse across scripts

local M = {}
local Monitor = {}
Monitor.__index = Monitor

--- Create a new project monitor
--- @param opts? table Configuration options
---   - on_project_switch: function(old_proj, new_proj) Callback when project switches
---   - on_project_reload: function() Callback when project reloads (save as, load)
---   - on_state_change: function(change_count) Callback when project state changes
---   - check_state_changes: boolean Whether to monitor state changes (default: true)
--- @return table monitor The project monitor
function M.new(opts)
  opts = opts or {}

  local self = setmetatable({
    last_project_filename = M.get_current_project_filename(),
    last_project_ptr = M.get_current_project_ptr(),
    last_state_change_count = reaper.GetProjectStateChangeCount(0),

    on_project_switch = opts.on_project_switch,
    on_project_reload = opts.on_project_reload,
    on_state_change = opts.on_state_change,

    check_state_changes = opts.check_state_changes ~= false,
  }, Monitor)

  return self
end

--- Get current project filename (path + name)
--- @param proj? number Project number (default: 0)
--- @return string? filename Full project path or nil if unsaved
function M.get_current_project_filename(proj)
  proj = proj or 0
  local proj_path = reaper.GetProjectPath("", proj)
  local proj_name = reaper.GetProjectName(0, "", proj)

  if proj_path == "" or proj_name == "" then
    return nil
  end

  return proj_path .. "/" .. proj_name
end

--- Get current project pointer (for detecting tab switches)
--- @return userdata? project_ptr The project pointer or nil
function M.get_current_project_ptr()
  local proj, _ = reaper.EnumProjects(-1, "")
  return proj
end

--- Update the monitor and trigger callbacks if changes detected
--- Call this in your main update loop
--- @return boolean changed True if any change was detected
function Monitor:update()
  local changed = false
  local current_filename = M.get_current_project_filename()
  local current_ptr = M.get_current_project_ptr()

  -- Detect project switch (filename or pointer changed)
  local filename_changed = current_filename ~= self.last_project_filename
  local ptr_changed = current_ptr ~= self.last_project_ptr

  if filename_changed or ptr_changed then
    changed = true

    -- Determine type of change
    if ptr_changed and not filename_changed then
      -- Tab switch (same project, different tab)
      if self.on_project_switch then
        self.on_project_switch(self.last_project_ptr, current_ptr)
      end
    elseif filename_changed then
      -- Project reload (save as, load, etc.)
      if self.on_project_reload then
        self.on_project_reload()
      end
    end

    -- Update tracked state
    self.last_project_filename = current_filename
    self.last_project_ptr = current_ptr
    self.last_state_change_count = reaper.GetProjectStateChangeCount(0)
  end

  -- Check for state changes within same project
  if self.check_state_changes and not changed then
    local current_state = reaper.GetProjectStateChangeCount(0)
    if current_state ~= self.last_state_change_count then
      changed = true
      if self.on_state_change then
        self.on_state_change(current_state)
      end
      self.last_state_change_count = current_state
    end
  end

  return changed
end

--- Manually reset the monitor state (useful after handling a change)
function Monitor:reset()
  self.last_project_filename = M.get_current_project_filename()
  self.last_project_ptr = M.get_current_project_ptr()
  self.last_state_change_count = reaper.GetProjectStateChangeCount(0)
end

--- Get the last known project filename
--- @return string? filename The last project filename or nil
function Monitor:get_last_filename()
  return self.last_project_filename
end

--- Get the last known project pointer
--- @return userdata? ptr The last project pointer or nil
function Monitor:get_last_ptr()
  return self.last_project_ptr
end

--- Get the last known state change count
--- @return number count The last state change count
function Monitor:get_last_state_count()
  return self.last_state_change_count
end

--- Check if current project has unsaved changes
--- @return boolean has_unsaved True if project has unsaved changes
function Monitor:has_unsaved_changes()
  return reaper.IsProjectDirty(0) ~= 0
end

--- Get current project name (without path)
--- @return string name The project name (or "untitled.rpp" if unsaved)
function Monitor:get_project_name()
  local _, name = reaper.GetProjectName(0, "")
  return name or "untitled.rpp"
end

--- Check if current project is saved
--- @return boolean is_saved True if project is saved to disk
function Monitor:is_project_saved()
  return M.get_current_project_filename() ~= nil
end

return M

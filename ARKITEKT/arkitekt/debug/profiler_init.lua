-- @noindex
-- arkitekt/dev/profiler_init.lua
-- Reusable profiler initialization utility
-- Usage:
--   local ProfilerInit = require('arkitekt.dev.profiler_init')
--   local profiler_enabled = ProfilerInit.init()
--   
--   -- Load your modules
--   local State = require(...)
--   local GUI = require(...)
--   
--   -- Attach profiler to local scope
--   if profiler_enabled then ProfilerInit.attach_locals() end

local M = {}

M.profiler = nil
M.enabled = false

function M.init()
  if M.enabled then
    reaper.ShowConsoleMsg("[Profiler] Already initialized\n")
    return true
  end
  
  -- Check config flag
  local ok, Config = pcall(require, 'arkitekt.defs.app')
  if not ok or not Config or not Config.PROFILER_ENABLED then
    return false
  end
  
  -- Try to load profiler
  local profiler_path = reaper.GetResourcePath() .. '/Scripts/ReaTeam Scripts/Development/cfillion_Lua profiler.lua'
  local profiler_file = io.open(profiler_path, "r")
  
  if not profiler_file then
    reaper.ShowConsoleMsg("[Profiler] Not found at: " .. profiler_path .. "\n")
    reaper.ShowConsoleMsg("[Profiler] Install via: Extensions > ReaPack > Browse Packages > Search 'Lua profiler'\n")
    return false
  end
  
  profiler_file:close()
  M.profiler = dofile(profiler_path)
  
  -- CRITICAL: Override reaper.defer BEFORE any defer loops start
  reaper.defer = M.profiler.defer
  
  M.enabled = true
  reaper.ShowConsoleMsg("[Profiler] Loaded successfully\n")
  
  return true
end

function M.attach_locals(opts)
  if not M.enabled or not M.profiler then return end
  
  opts = opts or { recursive = true }
  M.profiler.attachToLocals(opts)
  reaper.ShowConsoleMsg("[Profiler] Attached to local scope\n")
end

function M.attach_world()
  if not M.enabled or not M.profiler then return end
  
  M.profiler.attachToWorld()
  reaper.ShowConsoleMsg("[Profiler] Attached to world scope (all globals)\n")
end

function M.attach_to(target, opts)
  if not M.enabled or not M.profiler then return end
  
  opts = opts or { recursive = true }
  M.profiler.attachTo(target, opts)
  reaper.ShowConsoleMsg("[Profiler] Attached to: " .. target .. "\n")
end

function M.launch_window()
  if not M.enabled or not M.profiler then return end
  
  -- Launch profiler window in separate defer loop
  reaper.defer(function()
    M.profiler.run()
  end)
  
  reaper.ShowConsoleMsg("[Profiler] Window launched\n")
  reaper.ShowConsoleMsg("[Profiler] IMPORTANT: Go to Acquisition menu > Select slot > Click START\n")
end

function M.get_profiler()
  return M.profiler
end

function M.is_enabled()
  return M.enabled
end

return M
-- @noindex
-- ARKITEKT Framework Loader
-- Simple one-line import for all ARKITEKT scripts
-- Usage: local Ark = dofile(reaper.GetResourcePath() .. '/Scripts/ARKITEKT/loader.lua')

local sep = package.config:sub(1,1)

-- ============================================================================
-- STRATEGY 1: Try fixed path first (fast, predictable, works 99% of cases)
-- ============================================================================
-- Standard installation: REAPER/Scripts/ARKITEKT/
local fixed_path = reaper.GetResourcePath() .. sep .. 'Scripts' .. sep .. 'ARKITEKT' .. sep .. 'arkitekt' .. sep .. 'init.lua'
local f = io.open(fixed_path, "r")
if f then
  f:close()
  return dofile(fixed_path)
end

-- ============================================================================
-- STRATEGY 2: Fall back to auto-discovery (for forks/custom locations)
-- ============================================================================
-- Walk up from the calling script to find ARKITEKT root
local script_path = debug.getinfo(1, "S").source:sub(2)
local arkitekt_root = script_path:match("(.-ARKITEKT[/\\])")

if not arkitekt_root then
  error("ARKITEKT loader: Could not find ARKITEKT root directory.\n" ..
        "Checked:\n" ..
        "  1. Fixed path: " .. fixed_path .. "\n" ..
        "  2. Auto-discovery from: " .. script_path)
end

-- Load and return the arkitekt namespace (with auto-bootstrap)
return dofile(arkitekt_root .. "arkitekt" .. sep .. "init.lua")

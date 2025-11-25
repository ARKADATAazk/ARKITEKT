-- @noindex
-- ARKITEKT Framework Loader
-- Simple one-line import for all ARKITEKT scripts
-- Usage: local ark = dofile(debug.getinfo(1,"S").source:sub(2):match("(.-ARKITEKT[/\\])") .. "loader.lua")

local script_path = debug.getinfo(1, "S").source:sub(2)
local arkitekt_root = script_path:match("(.-ARKITEKT[/\\])")

if not arkitekt_root then
  error("ARKITEKT loader: Could not find ARKITEKT root directory")
end

-- Load and return the arkitekt namespace (with auto-bootstrap)
return dofile(arkitekt_root .. "arkitekt/init.lua")

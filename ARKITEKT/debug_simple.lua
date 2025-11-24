-- Simple namespace test - no bullshit

local script_path = debug.getinfo(1, "S").source:match("@?(.*)[\\/]") or ""
local sep = package.config:sub(1,1)

-- Ensure trailing separator
if not script_path:match("[\\/]$") then
  script_path = script_path .. sep
end

package.path = script_path .. "?.lua;" .. script_path .. "?" .. sep .. "init.lua;" .. package.path
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path

reaper.ShowConsoleMsg("=== Simple Test ===\n")
reaper.ShowConsoleMsg("Before clear - package.loaded['arkitekt']: " .. tostring(package.loaded['arkitekt']) .. "\n")

package.loaded['arkitekt'] = nil

reaper.ShowConsoleMsg("After clear - package.loaded['arkitekt']: " .. tostring(package.loaded['arkitekt']) .. "\n\n")

-- Just load it directly
local ark = require('arkitekt')

reaper.ShowConsoleMsg("After require - package.loaded['arkitekt']: " .. tostring(package.loaded['arkitekt']) .. "\n")

reaper.ShowConsoleMsg("Type: " .. type(ark) .. "\n")

if type(ark) == "table" then
  reaper.ShowConsoleMsg("✓ Got table\n")

  -- Try accessing Colors
  local Colors = ark.Colors
  reaper.ShowConsoleMsg("Colors type: " .. type(Colors) .. "\n")

  if type(Colors) == "table" and Colors.hex_to_rgba then
    local r, g, b, a = Colors.hex_to_rgba("#FF0000")
    reaper.ShowConsoleMsg("✓ Colors.hex_to_rgba works: " .. r .. ", " .. g .. ", " .. b .. "\n")
  end
else
  reaper.ShowConsoleMsg("❌ Got: " .. tostring(ark) .. "\n")
end

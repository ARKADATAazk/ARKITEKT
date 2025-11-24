-- @description Debug ARKITEKT Namespace Circular Dependency
-- @version 1.0
-- Explicitly tests namespace loading to isolate stack overflow

-- Make sure we can see output
reaper.ShowConsoleMsg("=== ARKITEKT Namespace Debug ===\n")
reaper.ShowConsoleMsg("Starting tests...\n\n")

-- Test 1: Load namespace itself
reaper.ShowConsoleMsg("Test 1: Loading ark namespace...\n")
local success, result = pcall(function()
  return require('arkitekt')
end)

if not success then
  reaper.ShowConsoleMsg("❌ FAILED loading namespace:\n" .. tostring(result) .. "\n")
  return
end

local ark = result
reaper.ShowConsoleMsg("✓ Namespace loaded successfully\n\n")

-- Test 2: Access Colors (no dependencies on other namespace modules)
reaper.ShowConsoleMsg("Test 2: Loading ark.Colors...\n")
success, result = pcall(function()
  return ark.Colors
end)

if not success then
  reaper.ShowConsoleMsg("❌ FAILED loading Colors:\n" .. tostring(result) .. "\n")
  return
end
reaper.ShowConsoleMsg("✓ Colors loaded: " .. tostring(result) .. "\n\n")

-- Test 3: Access Style (requires Colors)
reaper.ShowConsoleMsg("Test 3: Loading ark.Style...\n")
success, result = pcall(function()
  return ark.Style
end)

if not success then
  reaper.ShowConsoleMsg("❌ FAILED loading Style:\n" .. tostring(result) .. "\n")
  return
end
reaper.ShowConsoleMsg("✓ Style loaded: " .. tostring(result) .. "\n\n")

-- Test 4: Access Button (requires Style, Colors, Base)
reaper.ShowConsoleMsg("Test 4: Loading ark.Button...\n")
success, result = pcall(function()
  return ark.Button
end)

if not success then
  reaper.ShowConsoleMsg("❌ FAILED loading Button:\n" .. tostring(result) .. "\n")
  return
end
reaper.ShowConsoleMsg("✓ Button loaded: " .. tostring(result) .. "\n\n")

-- Test 5: Access Panel (requires Button, CornerButton, Scrollbar)
reaper.ShowConsoleMsg("Test 5: Loading ark.Panel...\n")
success, result = pcall(function()
  return ark.Panel
end)

if not success then
  reaper.ShowConsoleMsg("❌ FAILED loading Panel:\n" .. tostring(result) .. "\n")
  return
end
reaper.ShowConsoleMsg("✓ Panel loaded: " .. tostring(result) .. "\n\n")

reaper.ShowConsoleMsg("=================================\n")
reaper.ShowConsoleMsg("✓ ALL TESTS PASSED!\n")
reaper.ShowConsoleMsg("No circular dependency detected.\n")
reaper.ShowConsoleMsg("=================================\n")

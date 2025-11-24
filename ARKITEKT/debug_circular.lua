-- Debug circular dependency in ark namespace
-- Run with: lua debug_circular.lua (or in REAPER console)

-- Simulate the package path setup
package.path = './?.lua;./?/init.lua;' .. package.path

print("Step 1: Loading ark namespace...")
local success, result = pcall(function()
  return require('arkitekt')
end)

if not success then
  print("ERROR loading namespace:", result)
  return
end

local ark = result
print("✓ Namespace loaded")

print("\nStep 2: Accessing ark.Colors...")
success, result = pcall(function()
  return ark.Colors
end)

if not success then
  print("ERROR loading Colors:", result)
  return
end
print("✓ Colors loaded")

print("\nStep 3: Accessing ark.Style...")
success, result = pcall(function()
  return ark.Style
end)

if not success then
  print("ERROR loading Style:", result)
  return
end
print("✓ Style loaded")

print("\nStep 4: Accessing ark.Button...")
success, result = pcall(function()
  return ark.Button
end)

if not success then
  print("ERROR loading Button:", result)
  return
end
print("✓ Button loaded")

print("\n✓ All tests passed - no circular dependency!")

-- Test: ARKITEKT Namespace
-- Validates that ark.* namespace works correctly

local function test_lazy_loading()
  print("Test 1: Lazy Loading")

  local ark = require('arkitekt')
  print("  ✓ Namespace loaded")

  -- Access Button for first time
  local button_module = ark.Button
  assert(button_module ~= nil, "Button module should load")
  print("  ✓ ark.Button loaded on first access")

  -- Access again (should be cached)
  local button_module2 = ark.Button
  assert(button_module == button_module2, "Button should be cached")
  print("  ✓ ark.Button cached on second access")

  print("  PASSED\n")
end

local function test_all_widgets()
  print("Test 2: All Widget Modules")

  local ark = require('arkitekt')
  local widgets = {
    'Badge', 'Button', 'Checkbox', 'CloseButton', 'Combo',
    'CornerButton', 'HueSlider', 'InputText', 'MarkdownField',
    'RadioButton', 'Scrollbar', 'Separator', 'Slider', 'Spinner'
  }

  for _, name in ipairs(widgets) do
    local module = ark[name]
    assert(module ~= nil, name .. " should load")
    assert(type(module) == "table", name .. " should be a table")
    print("  ✓ ark." .. name)
  end

  print("  PASSED\n")
end

local function test_containers()
  print("Test 3: Container Modules")

  local ark = require('arkitekt')
  local containers = {'Panel', 'TileGroup'}

  for _, name in ipairs(containers) do
    local module = ark[name]
    assert(module ~= nil, name .. " should load")
    assert(type(module) == "table", name .. " should be a table")
    print("  ✓ ark." .. name)
  end

  print("  PASSED\n")
end

local function test_utilities()
  print("Test 4: Utility Modules")

  local ark = require('arkitekt')
  local utils = {
    'Colors', 'Style', 'Draw', 'Easing', 'Math', 'UUID'
  }

  for _, name in ipairs(utils) do
    local module = ark[name]
    assert(module ~= nil, name .. " should load")
    assert(type(module) == "table", name .. " should be a table")
    print("  ✓ ark." .. name)
  end

  print("  PASSED\n")
end

local function test_invalid_module()
  print("Test 5: Invalid Module Error Handling")

  local ark = require('arkitekt')
  local success, err = pcall(function()
    local _ = ark.InvalidWidget
  end)

  assert(not success, "Should error on invalid widget")
  assert(err:match("not a valid widget"), "Error should mention 'not a valid widget'")
  print("  ✓ Proper error for ark.InvalidWidget")
  print("  PASSED\n")
end

local function test_colors_utility()
  print("Test 6: Colors Utility Functions")

  local ark = require('arkitekt')

  -- Test hex_to_rgba
  local r, g, b, a = ark.Colors.hex_to_rgba("#FF0000")
  assert(r == 1, "Red component should be 1")
  assert(g == 0, "Green component should be 0")
  assert(b == 0, "Blue component should be 0")
  print("  ✓ ark.Colors.hex_to_rgba works")

  -- Test hsv_to_rgb
  local color = ark.Colors.hsv_to_rgb(0, 1, 1)
  assert(type(color) == "table", "Should return table")
  print("  ✓ ark.Colors.hsv_to_rgb works")

  print("  PASSED\n")
end

local function test_easing_utility()
  print("Test 7: Easing Utility Functions")

  local ark = require('arkitekt')

  -- Test ease_out_cubic
  local result = ark.Easing.ease_out_cubic(0.5)
  assert(type(result) == "number", "Should return number")
  assert(result >= 0 and result <= 1, "Should be normalized")
  print("  ✓ ark.Easing.ease_out_cubic works")

  print("  PASSED\n")
end

-- Run all tests
print("==========================================")
print("ARKITEKT Namespace Tests")
print("==========================================\n")

local success, err = pcall(function()
  test_lazy_loading()
  test_all_widgets()
  test_containers()
  test_utilities()
  test_invalid_module()
  test_colors_utility()
  test_easing_utility()
end)

if success then
  print("==========================================")
  print("✓ ALL TESTS PASSED")
  print("==========================================")
else
  print("==========================================")
  print("✗ TEST FAILED:")
  print(err)
  print("==========================================")
end

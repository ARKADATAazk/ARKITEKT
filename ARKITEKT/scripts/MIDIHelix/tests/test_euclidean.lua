-- @noindex
-- MIDIHelix/tests/test_euclidean.lua
-- Unit tests for Euclidean rhythm generator

local Euclidean = require('scripts.MIDIHelix.domain.euclidean')

local function test_basic_patterns()
  print('Testing basic Euclidean patterns...')

  -- E(5,8) - Classic Euclidean pattern
  local p1 = Euclidean.generate(5, 8, 0)
  local expected1 = {1,0,1,0,1,0,1,1}
  assert(#p1 == 8, 'E(5,8) should have 8 steps')
  for i = 1, 8 do
    assert(p1[i] == expected1[i], string.format('E(5,8) step %d mismatch', i))
  end
  print('✓ E(5,8) = ' .. Euclidean.visualize(p1))

  -- E(3,8) - Tresillo pattern
  local p2 = Euclidean.generate(3, 8, 0)
  local expected2 = {1,0,0,1,0,0,1,0}
  assert(#p2 == 8, 'E(3,8) should have 8 steps')
  for i = 1, 8 do
    assert(p2[i] == expected2[i], string.format('E(3,8) step %d mismatch', i))
  end
  print('✓ E(3,8) = ' .. Euclidean.visualize(p2))

  -- E(4,12) - Common polyrhythm
  local p3 = Euclidean.generate(4, 12, 0)
  assert(#p3 == 12, 'E(4,12) should have 12 steps')
  print('✓ E(4,12) = ' .. Euclidean.visualize(p3))
end

local function test_edge_cases()
  print('\nTesting edge cases...')

  -- All pulses
  local p1 = Euclidean.generate(8, 8, 0)
  for i = 1, 8 do
    assert(p1[i] == 1, 'All pulses should be 1')
  end
  print('✓ E(8,8) = ' .. Euclidean.visualize(p1))

  -- No pulses
  local p2 = Euclidean.generate(0, 8, 0)
  for i = 1, 8 do
    assert(p2[i] == 0, 'No pulses should be 0')
  end
  print('✓ E(0,8) = ' .. Euclidean.visualize(p2))

  -- Single pulse
  local p3 = Euclidean.generate(1, 8, 0)
  assert(p3[1] == 1, 'First step should be pulse')
  print('✓ E(1,8) = ' .. Euclidean.visualize(p3))
end

local function test_rotation()
  print('\nTesting rotation...')

  local p1 = Euclidean.generate(5, 8, 0)
  local p2 = Euclidean.generate(5, 8, 2)

  print('✓ E(5,8,0) = ' .. Euclidean.visualize(p1))
  print('✓ E(5,8,2) = ' .. Euclidean.visualize(p2))

  -- Verify rotation wrapped correctly
  assert(#p2 == 8, 'Rotated pattern should have same length')
end

local function test_describe()
  print('\nTesting pattern description...')

  assert(Euclidean.describe(5, 8, 0) == 'E(5,8)', 'Description without rotation')
  assert(Euclidean.describe(5, 8, 2) == 'E(5,8,2)', 'Description with rotation')

  print('✓ Pattern descriptions working')
end

-- Run all tests
local function run_all_tests()
  print('=== Euclidean Generator Tests ===\n')

  local success, err = pcall(function()
    test_basic_patterns()
    test_edge_cases()
    test_rotation()
    test_describe()
  end)

  if success then
    print('\n=== All tests passed! ===')
  else
    print('\n=== Test failed: ' .. tostring(err) .. ' ===')
  end
end

run_all_tests()

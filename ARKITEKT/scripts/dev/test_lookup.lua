-- @noindex
-- Quick test script for bidirectional lookup functionality
-- Run with: lua test_lookup.lua (outside REAPER for quick validation)

-- Mock the arkitekt path setup
package.path = package.path .. ';../../?.lua;../../?/init.lua'

local Lookup = require('arkitekt.core.lookup')

print("=== Testing Lookup Module ===\n")

-- Test 1: build_reverse_lookup
print("Test 1: build_reverse_lookup")
local options = {
  { value = "4bar", label = "4 Bars" },
  { value = "2bar", label = "2 Bars" },
  { value = "measure", label = "1 Bar" },
}

local by_label = Lookup.build_reverse_lookup(options, "label", "value")
local by_value = Lookup.build_reverse_lookup(options, "value", "label")

assert(by_label["4 Bars"] == "4bar", "Label to value lookup failed")
assert(by_value["4bar"] == "4 Bars", "Value to label lookup failed")
print("✓ build_reverse_lookup works correctly\n")

-- Test 2: build_index
print("Test 2: build_index")
local index = Lookup.build_index(options, "value")
assert(index["4bar"].label == "4 Bars", "Index lookup failed")
assert(index["measure"].label == "1 Bar", "Index lookup failed")
print("✓ build_index works correctly\n")

-- Test 3: build_bidirectional
print("Test 3: build_bidirectional")
local forward, reverse = Lookup.build_bidirectional(options, "label", "value")
assert(forward["4 Bars"] == "4bar", "Forward lookup failed")
assert(reverse["4bar"] == "4 Bars", "Reverse lookup failed")
print("✓ build_bidirectional works correctly\n")

-- Test 4: build_reverse
print("Test 4: build_reverse")
local modes = {
  REGIONS = "regions",
  PLAYLISTS = "playlists",
  MIXED = "mixed",
}
local mode_reverse = Lookup.build_reverse(modes)
assert(mode_reverse["regions"] == "REGIONS", "Reverse lookup failed")
assert(mode_reverse["playlists"] == "PLAYLISTS", "Reverse lookup failed")
print("✓ build_reverse works correctly\n")

-- Test 5: Error handling
print("Test 5: Error handling")
local ok, err = pcall(function()
  Lookup.build_reverse_lookup(nil, "label", "value")
end)
assert(not ok and err:match("must be a table"), "Should error on nil array")
print("✓ Error handling works correctly\n")

print("=== All Tests Passed! ===")

-- Quick namespace test
print("Loading ark namespace...")
local ark = require('arkitekt')

print("Testing ark.Colors...")
local color = ark.Colors.hex_to_rgba("#FF0000")
print("✓ Colors work:", color[1], color[2], color[3])

print("Testing ark.Button...")
local Button = ark.Button
print("✓ Button loaded:", type(Button))

print("Testing ark.Panel...")
local Panel = ark.Panel
print("✓ Panel loaded:", type(Panel))

print("\n✓ All namespace tests passed!")

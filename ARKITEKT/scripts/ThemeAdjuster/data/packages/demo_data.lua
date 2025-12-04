-- @noindex
-- ThemeAdjuster/data/packages/demo_data.lua
-- Demo package data generator for testing and preview

local M = {}

-- Demo package names
local PACKAGE_NAMES = {
  'CleanLines', 'DarkBevel', 'FlatModern', 'GlassUI',
  'MinimalPro', 'NeonGlow', 'RetroWave', 'SoftGradient'
}

-- Available areas for assets
local AREAS = {'tcp', 'mcp', 'transport', 'global'}

-- Common asset types
local ASSET_TYPES = {
  'panel_bg', 'mute_on', 'mute_off', 'solo_on', 'solo_off',
  'recarm_on', 'recarm_off', 'fx_on', 'fx_off'
}

-- Generate demo packages for testing
function M.generate()
  local packages = {}

  for i, name in ipairs(PACKAGE_NAMES) do
    local keys = {}
    local assets = {}

    -- Generate random assets for this package
    local asset_count = math.random(15, 45)
    for j = 1, asset_count do
      local area = AREAS[math.random(1, #AREAS)]
      local asset = ASSET_TYPES[math.random(1, #ASSET_TYPES)]
      local key = area .. '_' .. asset

      if not assets[key] then
        keys[#keys + 1] = key
        assets[key] = {
          path = string.format('(mock)/%s/%s.png', name, key),
          is_strip = false,
        }
      end
    end

    table.sort(keys)

    packages[i] = {
      id = name,
      path = string.format('(mock)/Assembler/Packages/%s', name),
      assets = assets,
      keys_order = keys,
      meta = {
        name = name,
        version = '1.0.0',
        author = 'ARKADATA',
        description = string.format('%s theme package', name),
        tags = {'demo'},
        mosaic = {keys[1], keys[2], keys[3]},
        color = string.format('#%02X%02X%02X',
          math.random(100, 255),
          math.random(100, 255),
          math.random(100, 255)),
      },
    }
  end

  return packages
end

return M

local Colors = {
  tile_background = 0x1A1E24FF,
  tile_background_hover = 0x222932FF,
  tile_background_selected = 0x2D3A4AFF,
  text = 0xFFFFFFFF,
  secondary_text = 0xCCD3DBFF,
  badge_text = 0xFFFFFFFF,
  badge_bg = 0x14181CFF,
  repeat_muted_bg = 0x30363CFF,
  disabled_alpha = 0x66,
}

local Layout = {
  text_padding = { x = 8, y = 4 },
  badge_padding = { x = 6, y = 3 },
  badge_min_width = 24,
  badge_min_height = 16,
  badge_corner_radius = 4,
}

local ResponsiveThresholds = {
  text = 15,
  badge = 25,
  length = 35,
}

return {
  COLORS = Colors,
  LAYOUT = Layout,
  RESPONSIVE_THRESHOLDS = ResponsiveThresholds,
  TEXT_ELLIPSIS = '…',
}

-- @noindex
-- MIDIHelix/config/colors.lua
-- Tab color palette (Ex Machina style)

return {
  -- Tab accent colors
  TABS = {
    EUCLIDEAN  = 0xFF8C00FF,  -- Orange
    SEQUENCER  = 0xFFD700FF,  -- Yellow/Gold
    RANDOMIZER = 0x50C878FF,  -- Green
    MELODIC    = 0x00CED1FF,  -- Cyan/Teal
    RHYTHM     = 0xDA70D6FF,  -- Magenta/Orchid
    GENERATIVE = 0x9370DBFF,  -- Medium Purple
    OPTIONS    = 0x808080FF,  -- Grey
  },

  -- Common element colors
  SLIDER_FILL  = 0x4A90D9FF,  -- Blue (default slider fill)
  SLIDER_TRACK = 0x202020FF,  -- Dark track background
  SLIDER_BORDER = 0x404040FF, -- Track border

  -- UI colors
  BG_WINDOW    = 0x1A1A1AFF,  -- Window background
  BG_PANEL     = 0x252525FF,  -- Panel background
  BG_HEADER    = 0x2A2A2AFF,  -- Header bar
  BG_INPUT     = 0x181818FF,  -- Input field background

  -- Text colors
  TEXT_PRIMARY   = 0xE0E0E0FF,  -- Main text
  TEXT_SECONDARY = 0x909090FF,  -- Labels, hints
  TEXT_DISABLED  = 0x505050FF,  -- Disabled text

  -- Border colors
  BORDER_OUTER = 0x404040FF,
  BORDER_INNER = 0x303030FF,
  BORDER_FOCUS = 0x606060FF,

  -- State colors
  HOVER_TINT   = 0xFFFFFF20,  -- White overlay on hover
  ACTIVE_TINT  = 0x00000030,  -- Dark overlay on active
  DISABLED_TINT = 0x00000080, -- Dark overlay on disabled

  -- Specular/effect colors
  SPECULAR_WHITE = 0xFFFFFF40,
  SHADOW_BLACK   = 0x00000060,
}

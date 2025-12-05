-- @noindex
-- MIDIHelix/config/layout.lua
-- Ex Machina-style layout constants

return {
  -- Window
  WINDOW = {
    W = 900,
    H = 280,
    MIN_W = 700,
    MIN_H = 250,
  },

  -- Header bar
  HEADER = {
    X = 5,
    Y = 5,
    H = 22,
  },

  -- Left panel (controls, buttons)
  LEFT_PANEL = {
    X = 25,
    W = 110,
  },

  -- Dropdowns (Key, Octave, Scale)
  KEY_DROP = {
    X = 25,
    Y = 70,
    W = 50,
    H = 20,
  },
  OCT_DROP = {
    X = 80,
    Y = 70,
    W = 50,
    H = 20,
  },
  SCALE_DROP = {
    X = 25,
    Y = 120,
    W = 110,
    H = 20,
  },

  -- Action buttons (stacked vertically)
  BTN_PRIMARY = {
    X = 25,
    Y = 205,
    W = 110,
    H = 25,
  },
  BTN_SECONDARY = {
    X = 25,
    Y = 165,
    W = 110,
    H = 25,
  },

  -- Vertical sliders area
  SLIDERS = {
    X = 160,
    Y = 50,
    W = 30,
    H = 150,
    SPACING = 40,  -- Center to center
  },

  -- Options checkboxes (right side)
  OPTIONS = {
    X = 700,
    Y = 80,
    W = 150,
    H = 20,
    SPACING = 30,
  },

  -- Right panel (timing, velocity, etc.)
  RIGHT_PANEL = {
    X = 550,
    Y = 50,
    W = 180,
  },

  -- Tab bar (bottom)
  TAB_BAR = {
    Y_OFFSET = -25,  -- From bottom
    H = 20,
    BTN_W = 100,
    BTN_SPACING = 0,
  },

  -- Undo/Redo buttons
  UNDO_BTN = {
    X_OFFSET = -85,  -- From right edge
    W = 40,
    H = 20,
  },
  REDO_BTN = {
    X_OFFSET = -45,
    W = 40,
    H = 20,
  },

  -- Pattern visualization (Euclidean ring)
  PATTERN_VIS = {
    X = 420,
    Y = 60,
    SIZE = 120,
  },

  -- Preview panel (for transforms)
  PREVIEW = {
    X = 160,
    Y = 140,
    W = 500,
    H = 80,
  },

  -- Padding and spacing
  PADDING = 10,
  SPACING = 8,
  ROUNDING = 4,
}

-- @noindex
-- MIDIHelix/defs/defaults.lua
-- Default values and configuration

return {
  EUCLIDEAN = {
    PULSES = 5,
    STEPS = 8,
    ROTATION = 0,
    NOTE = 60,  -- Middle C
    VELOCITY = 96,
    GRID_DIVISION = 0.25,  -- 16th notes (1/4 beat)
    NOTE_LENGTH = 0.25,
  },

  WINDOW = {
    WIDTH = 400,
    HEIGHT = 300,
    TITLE = 'MIDI Helix - Euclidean Generator',
  },
}

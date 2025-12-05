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

  RANDOMIZER = {
    NOTE = 60,           -- Middle C (root)
    OCTAVE = 4,
    KEY = 1,             -- C (1-12 index)
    SCALE = 1,           -- Chromatic
    VELOCITY = 96,
    GRID_DIVISION = 0.25,
    NOTE_LENGTH = 0.25,
    NOTE_COUNT = 8,
    FIRST_IS_ROOT = true,
    OCTAVE_DOUBLE = false,
    OCTAVE_PROB = 3,     -- 0-10 probability
    ALL_NOTES = false,   -- false = selected only
    -- Default weights (all notes equal for Chromatic)
    DEFAULT_WEIGHT = 5,
  },

  SEQUENCER = {
    NOTE = 60,           -- Middle C (root)
    OCTAVE = 4,
    KEY = 1,             -- C (1-12 index)
    SCALE = 1,           -- Chromatic
    GRID = 2,            -- 1=1/16, 2=1/8, 3=1/4
    -- Note length weights (0-10 each)
    LENGTH_WEIGHTS = { 8, 4, 0, 2 },  -- 1/16, 1/8, 1/4, Rest
    -- Options
    GENERATE_ON_CHANGE = true,
    FIRST_NOTE_ALWAYS = true,
    ACCENT_ENABLED = true,
    LEGATO_ENABLED = false,
    RANDOMIZE_NOTES = true,
    -- Velocity
    NORMAL_VEL = 100,
    ACCENT_VEL = 127,
    ACCENT_PROB = 3,     -- 0-10
    LEGATO_PROB = 3,     -- 0-10
    LEGATO_OFFSET = -10, -- PPQ offset for non-legato
  },

  WINDOW = {
    WIDTH = 900,
    HEIGHT = 280,
    TITLE = 'MIDI Helix',
  },
}

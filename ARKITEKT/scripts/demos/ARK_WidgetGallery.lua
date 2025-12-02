-- @noindex
-- ARK_WidgetGallery.lua - Showcase of ARKITEKT experimental widgets
-- Visual gallery of all experimental audio and control widgets

-- ============================================================================
-- LOAD ARKITEKT FRAMEWORK
-- ============================================================================
local Ark = dofile(debug.getinfo(1,"S").source:sub(2):match("(.-ARKITEKT[/\\])") .. "arkitekt" .. package.config:sub(1,1) .. "init.lua")

-- ============================================================================
-- IMPORTS
-- ============================================================================
local Shell = require('arkitekt.app.shell')
local Colors = Ark.Colors

-- ============================================================================
-- STATE
-- ============================================================================
local state = {
  -- Knob values
  knob1 = 50,
  knob2 = 75,
  knob3 = 25,

  -- Fader values
  fader1 = 0,    -- dB
  fader2 = -6,

  -- XY Pad values
  xy_x = 0.5,
  xy_y = 0.5,

  -- VU Meter values (simulated)
  vu_peak = -6,
  vu_rms = -12,

  -- MediaItem selection
  media_selected = {false, true, false},

  -- Generate dummy waveform data
  peaks = nil,

  -- Generate dummy MIDI data
  midi_notes = nil,
}

-- Generate synthetic waveform data
local function generate_waveform(samples)
  local peaks = {}
  for i = 1, samples do
    local t = (i - 1) / samples
    local val = math.sin(t * math.pi * 8) * 0.8  -- Sine wave
    peaks[i] = val  -- Max peaks
  end
  for i = 1, samples do
    local t = (i - 1) / samples
    local val = math.sin(t * math.pi * 8) * 0.8
    peaks[samples + i] = -val  -- Min peaks (inverted)
  end
  return peaks
end

-- Generate synthetic MIDI notes
local function generate_midi_notes()
  local notes = {}
  for i = 1, 20 do
    local x1 = (i - 1) * 20
    local x2 = x1 + 15
    local y1 = 50 + math.random(-30, 30)
    local y2 = y1 + 4
    notes[i] = {x1 = x1, y1 = y1, x2 = x2, y2 = y2}
  end
  return notes
end

state.peaks = generate_waveform(200)
state.midi_notes = generate_midi_notes()

-- ============================================================================
-- GUI
-- ============================================================================
local function draw_section_header(ctx, title)
  Ark.ImGui.Separator(ctx)
  Ark.ImGui.Text(ctx, title)
  Ark.ImGui.Separator(ctx)
  Ark.ImGui.Spacing(ctx)
end

local function draw_gui(ctx)
  local ImGui = Ark.ImGui

  ImGui.Text(ctx, "ARKITEKT Experimental Widget Gallery")
  ImGui.Text(ctx, "All widgets are in experimental/ folder and APIs may change")
  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)

  -- ========================================================================
  -- KNOBS
  -- ========================================================================
  draw_section_header(ctx, "Knobs - Circular rotary controls")

  local knob1 = Ark.Knob(ctx, {
    label = "Volume",
    value = state.knob1,
    min = 0,
    max = 100,
    size = 60,
  })
  if knob1.changed then state.knob1 = knob1.value end

  ImGui.SameLine(ctx)

  local knob2 = Ark.Knob(ctx, {
    label = "Pan",
    value = state.knob2,
    min = -50,
    max = 50,
    default = 0,
    size = 60,
    color = Colors.hexrgb("#FF6633"),
  })
  if knob2.changed then state.knob2 = knob2.value end

  ImGui.SameLine(ctx)

  local knob3 = Ark.Knob(ctx, {
    label = "Cutoff",
    value = state.knob3,
    min = 0,
    max = 127,
    size = 60,
    color = Colors.hexrgb("#33CCFF"),
  })
  if knob3.changed then state.knob3 = knob3.value end

  ImGui.Spacing(ctx)

  -- ========================================================================
  -- FADERS
  -- ========================================================================
  draw_section_header(ctx, "Faders - Vertical dB sliders")

  local fader1 = Ark.Fader(ctx, {
    label = "Channel 1",
    value = state.fader1,
    min = -60,
    max = 12,
    width = 40,
    height = 150,
  })
  if fader1.changed then state.fader1 = fader1.value end

  ImGui.SameLine(ctx)

  local fader2 = Ark.Fader(ctx, {
    label = "Channel 2",
    value = state.fader2,
    min = -60,
    max = 12,
    width = 40,
    height = 150,
  })
  if fader2.changed then state.fader2 = fader2.value end

  ImGui.Spacing(ctx)

  -- ========================================================================
  -- VU METERS
  -- ========================================================================
  draw_section_header(ctx, "VU Meters - Peak/RMS level visualization")

  -- Animate the VU meters
  state.vu_peak = -20 + math.sin(reaper.time_precise() * 2) * 15
  state.vu_rms = state.vu_peak - 6

  Ark.VUMeter(ctx, {
    label = "L",
    peak = state.vu_peak,
    rms = state.vu_rms,
    min_db = -60,
    max_db = 0,
    width = 25,
    height = 150,
  })

  ImGui.SameLine(ctx)

  Ark.VUMeter(ctx, {
    label = "R",
    peak = state.vu_peak - 2,
    rms = state.vu_rms - 2,
    min_db = -60,
    max_db = 0,
    width = 25,
    height = 150,
  })

  ImGui.Spacing(ctx)

  -- ========================================================================
  -- XY PAD
  -- ========================================================================
  draw_section_header(ctx, "XY Pad - 2D control surface")

  local xy = Ark.XYPad(ctx, {
    label_x = "Rate",
    label_y = "Depth",
    value_x = state.xy_x,
    value_y = state.xy_y,
    min_x = 0,
    max_x = 10,
    min_y = 0,
    max_y = 1,
    size = 200,
    snap_to_grid = true,
    grid_divisions = 4,
  })
  if xy.changed then
    state.xy_x = xy.value_x
    state.xy_y = xy.value_y
  end

  ImGui.Spacing(ctx)

  -- ========================================================================
  -- WAVEFORM
  -- ========================================================================
  draw_section_header(ctx, "Waveform - Audio peak visualization")

  Ark.Waveform(ctx, {
    peaks = state.peaks,
    width = 400,
    height = 80,
    color = Colors.hexrgb("#33FF66"),
    is_filled = true,
    quality = 1.0,
  })

  ImGui.Spacing(ctx)

  -- ========================================================================
  -- MIDI PIANO ROLL
  -- ========================================================================
  draw_section_header(ctx, "MIDI Piano Roll - MIDI note visualization")

  Ark.MIDIPianoRoll(ctx, {
    notes = state.midi_notes,
    width = 400,
    height = 80,
    color = Colors.hexrgb("#FF9933"),
    cache_width = 400,
    cache_height = 200,
  })

  ImGui.Spacing(ctx)

  -- ========================================================================
  -- MEDIA ITEMS
  -- ========================================================================
  draw_section_header(ctx, "Media Items - Complete item tiles")

  -- Audio item
  local audio = Ark.MediaItem(ctx, {
    name = "Drums.wav",
    duration = 4.5,
    color = Colors.hexrgb("#FF6633"),
    peaks = state.peaks,
    is_selected = state.media_selected[1],
    width = 220,
    height = 100,
    pool_count = 2,
    on_click = function()
      state.media_selected[1] = not state.media_selected[1]
    end,
  })

  ImGui.SameLine(ctx)

  -- MIDI item
  local midi = Ark.MediaItem(ctx, {
    name = "Piano Melody",
    duration = 8.0,
    color = Colors.hexrgb("#33CCFF"),
    midi_notes = state.midi_notes,
    is_selected = state.media_selected[2],
    width = 220,
    height = 100,
    on_click = function()
      state.media_selected[2] = not state.media_selected[2]
    end,
  })

  ImGui.SameLine(ctx)

  -- Disabled audio item
  local disabled = Ark.MediaItem(ctx, {
    name = "Inactive.wav",
    duration = 2.3,
    color = Colors.hexrgb("#666666"),
    peaks = state.peaks,
    is_selected = state.media_selected[3],
    disabled = true,
    width = 220,
    height = 100,
  })

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Text(ctx, "Tip: Double-click knobs/faders to reset, click items to select")
end

-- ============================================================================
-- RUN APPLICATION
-- ============================================================================
Shell.run({
  title        = "Widget Gallery",
  version      = "v1.0.0",
  initial_pos  = { x = 100, y = 100 },
  initial_size = { w = 800, h = 900 },
  min_size     = { w = 700, h = 800 },
  icon_color   = Colors.hexrgb("#9966FF"),

  draw = function(ctx, shell_state)
    draw_gui(ctx)
  end,
})

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
local Shell = require('arkitekt.runtime.shell')
local Colors = Ark.Colors

-- ============================================================================
-- STATE
-- ============================================================================
local state = {
  -- Knob values
  knob1 = 50,
  knob2 = 75,
  knob3 = 25,

  -- Encoder values (endless rotation)
  encoder_angle = 0,
  encoder_value = 100,  -- Accumulated value

  -- Fader values
  fader1 = 0,    -- dB
  fader2 = -6,

  -- XY Pad values
  xy_x = 0.5,
  xy_y = 0.5,

  -- VU Meter values (simulated)
  vu_peak = -6,
  vu_rms = -12,

  -- Spectrum analyzer bins
  spectrum_bins = nil,

  -- Step sequencer pattern
  sequencer_pattern = nil,
  sequencer_step = 1,

  -- Transport state
  transport_state = 0,  -- Ark.Transport.STATE_STOPPED
  transport_loop = false,

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

-- Generate synthetic spectrum data (simulates FFT bins)
local function generate_spectrum_bins(num_bins)
  local bins = {}
  for i = 1, num_bins do
    -- Create a realistic spectrum shape with low-frequency emphasis
    local freq_normalized = (i - 1) / (num_bins - 1)

    -- Base spectrum with 1/f rolloff (pink noise characteristic)
    local base_level = -10 - (freq_normalized * 35)

    -- Add some peaks (harmonics)
    local peak1 = math.exp(-((freq_normalized - 0.15) ^ 2) / 0.01) * 15
    local peak2 = math.exp(-((freq_normalized - 0.35) ^ 2) / 0.008) * 12
    local peak3 = math.exp(-((freq_normalized - 0.55) ^ 2) / 0.012) * 8

    bins[i] = base_level + peak1 + peak2 + peak3 + math.random() * 2 - 1
  end
  return bins
end

-- Generate initial drum pattern
local function generate_drum_pattern()
  return {
    {1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0},  -- Kick
    {0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0},  -- Snare
    {1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0},  -- Closed HH
    {0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1},  -- Open HH
  }
end

state.peaks = generate_waveform(200)
state.midi_notes = generate_midi_notes()
state.spectrum_bins = generate_spectrum_bins(128)
state.sequencer_pattern = generate_drum_pattern()

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
  draw_section_header(ctx, "Knobs - Circular rotary controls (7 variants)")

  -- First row: tick, dot, wiper, wiper_only
  local knob1 = Ark.Knob(ctx, {
    label = "Tick",
    value = state.knob1,
    variant = "tick",
    min = 0,
    max = 100,
    size = 60,
  })
  if knob1.changed then state.knob1 = knob1.value end

  ImGui.SameLine(ctx)

  local knob2 = Ark.Knob(ctx, {
    label = "Dot",
    value = state.knob2,
    variant = "dot",
    min = 0,
    max = 100,
    size = 60,
  })
  if knob2.changed then state.knob2 = knob2.value end

  ImGui.SameLine(ctx)

  local knob3 = Ark.Knob(ctx, {
    label = "Wiper",
    value = state.knob3,
    variant = "wiper",
    min = 0,
    max = 100,
    size = 60,
  })
  if knob3.changed then state.knob3 = knob3.value end

  ImGui.SameLine(ctx)

  local knob4 = Ark.Knob(ctx, {
    label = "WiperOnly",
    value = state.knob1,
    variant = "wiper_only",
    min = 0,
    max = 100,
    size = 60,
    show_value = false,
  })
  if knob4.changed then state.knob1 = knob4.value end

  -- Second row: wiper_dot, stepped, space
  local knob5 = Ark.Knob(ctx, {
    label = "WiperDot",
    value = state.knob2,
    variant = "wiper_dot",
    min = 0,
    max = 100,
    size = 60,
  })
  if knob5.changed then state.knob2 = knob5.value end

  ImGui.SameLine(ctx)

  local knob6 = Ark.Knob(ctx, {
    label = "Stepped",
    value = state.knob3,
    variant = "stepped",
    steps = 10,
    min = 0,
    max = 100,
    size = 60,
  })
  if knob6.changed then state.knob3 = knob6.value end

  ImGui.SameLine(ctx)

  local knob7 = Ark.Knob(ctx, {
    label = "Space",
    value = state.knob1,
    variant = "space",
    min = 0,
    max = 100,
    size = 60,
  })
  if knob7.changed then state.knob1 = knob7.value end

  ImGui.Spacing(ctx)

  -- ========================================================================
  -- ENCODERS
  -- ========================================================================
  draw_section_header(ctx, "Encoders - Endless rotation (no bounds)")

  local encoder = Ark.Encoder(ctx, {
    label = "Value",
    angle = state.encoder_angle,
    sensitivity = 0.02,
  })

  if encoder.changed then
    state.encoder_angle = encoder.angle
    state.encoder_value = state.encoder_value + encoder.delta * 100
  end

  ImGui.SameLine(ctx)
  ImGui.Text(ctx, string.format("Accumulated: %.1f", state.encoder_value))

  ImGui.Spacing(ctx)

  -- ========================================================================
  -- TRANSPORT CONTROLS
  -- ========================================================================
  draw_section_header(ctx, "Transport - Play/Stop/Record controls")

  Ark.Transport(ctx, {
    buttons = {"rewind", "stop", "play", "record", "forward", "loop"},
    state = state.transport_state,
    is_loop_enabled = state.transport_loop,
    button_size = 36,
    on_play = function()
      state.transport_state = Ark.Transport.STATE_PLAYING
    end,
    on_stop = function()
      state.transport_state = Ark.Transport.STATE_STOPPED
    end,
    on_record = function()
      state.transport_state = Ark.Transport.STATE_RECORDING
    end,
    on_loop = function(enabled)
      state.transport_loop = enabled
    end,
    on_rewind = function()
      print("Rewind pressed")
    end,
    on_forward = function()
      print("Forward pressed")
    end,
  })

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
  -- SPECTRUM ANALYZER
  -- ========================================================================
  draw_section_header(ctx, "Spectrum Analyzer - Frequency domain visualization")

  -- Animate the spectrum (add some movement)
  local time = reaper.time_precise()
  local animated_bins = {}
  for i = 1, #state.spectrum_bins do
    local animation = math.sin(time * 1.5 + i * 0.05) * 3
    animated_bins[i] = state.spectrum_bins[i] + animation
  end

  Ark.SpectrumAnalyzer(ctx, {
    bins = animated_bins,
    width = 400,
    height = 120,
    min_db = -60,
    max_db = 0,
    sample_rate = 44100,
    is_logarithmic = true,
    is_gradient = true,
    show_grid = true,
  })

  ImGui.Spacing(ctx)

  -- ========================================================================
  -- STEP SEQUENCER
  -- ========================================================================
  draw_section_header(ctx, "Step Sequencer - Pattern editor for rhythm/drums")

  -- Animate playback position
  state.sequencer_step = (math.floor(reaper.time_precise() * 4) % 16) + 1

  local seq = Ark.StepSequencer(ctx, {
    pattern = state.sequencer_pattern,
    steps = 16,
    tracks = 4,
    current_step = state.sequencer_step,
    width = 450,
    height = 120,
    track_labels = {"Kick", "Snare", "Closed HH", "Open HH"},
    is_velocity_colors = false,
    on_change = function(track, step, velocity)
      -- Pattern is updated automatically
    end,
  })

  if seq.changed then
    state.sequencer_pattern = seq.pattern
  end

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
  -- PIANO
  -- ========================================================================
  draw_section_header(ctx, "Piano - Interactive keyboard")

  -- Horizontal piano (2 octaves)
  local piano_h = Ark.Piano(ctx, {
    orientation = "horizontal",
    start_note = 60,  -- Middle C
    num_octaves = 2,
    white_key_width = 18,
    white_key_height = 70,
    is_interactive = true,
    active_notes = {},
    on_note_press = function(note)
      print("Piano note pressed:", note)
    end,
  })

  ImGui.SameLine(ctx)
  ImGui.Dummy(ctx, 20, 1)  -- Spacing
  ImGui.SameLine(ctx)

  -- Vertical piano (1 octave, display-only with active notes)
  local c_major = {
    [60] = true,  -- C
    [62] = true,  -- D
    [64] = true,  -- E
    [65] = true,  -- F
    [67] = true,  -- G
    [69] = true,  -- A
    [71] = true,  -- B
  }

  Ark.Piano(ctx, {
    orientation = "vertical",
    start_note = 60,
    num_octaves = 1,
    white_key_width = 18,
    white_key_height = 70,
    is_interactive = false,  -- Display only
    active_notes = c_major,
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

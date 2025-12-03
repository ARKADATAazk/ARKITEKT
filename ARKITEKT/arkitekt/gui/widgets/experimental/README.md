# Experimental Widgets

**⚠️ Warning: APIs in this folder are unstable and may change.**

This folder contains prototype widgets that are being developed and tested. Use them at your own risk, as their APIs, behavior, and performance characteristics may change between versions.

## Current Experimental Widgets

### Encoder
**File**: `encoder.lua`
**Status**: Prototype
**Description**: Rotary encoder with endless rotation (no bounds) for relative adjustments.

**Features**:
- Endless rotation (no min/max bounds)
- Tracks relative delta changes, not absolute values
- Visual indicator shows rotation position
- Adjustable sensitivity
- Convenience constructors: `tempo()`, `fine()`, `coarse()`
- Custom value display support

**Usage**:
```lua
-- Basic encoder (returns delta on each frame)
local result = Ark.Encoder(ctx, {
  label = "Offset",
  angle = encoder_angle,      -- Visual rotation state (persisted)
  sensitivity = 0.01,
})

if result.changed then
  encoder_angle = result.angle  -- Update visual state
  value = value + result.delta   -- Apply delta to your value
end

-- Tempo encoder (shows BPM changes)
local tempo_result = Ark.Encoder.tempo(ctx, {
  angle = tempo_angle,
})
if tempo_result.changed then
  tempo_angle = tempo_result.angle
  bpm = bpm + tempo_result.delta * 100  -- Scale to BPM range
end

-- Fine/coarse adjustment
Ark.Encoder.fine(ctx, { angle = fine_angle })     -- Low sensitivity
Ark.Encoder.coarse(ctx, { angle = coarse_angle }) -- High sensitivity
```

**Known Issues**:
- No tick marks or detents for tactile feedback
- Visual wrapping is seamless (no indication of full rotation count)
- No shift/alt modifier for sensitivity adjustment
- Horizontal drag not supported (only vertical)

---

### Fader
**File**: `fader.lua`
**Status**: Prototype
**Description**: Vertical fader with logarithmic dB scaling, common in audio mixers.

**Features**:
- Logarithmic dB scale mapping
- Visual track with fill indicator
- Configurable dB range (-60 to +12 dB typical)
- Scale markings with dB values
- Convenience methods: `Fader.mixer()`, `Fader.master()`

**Usage**:
```lua
local result = Ark.Fader(ctx, {
  label = "Volume",
  value = 0,      -- dB
  min = -60,
  max = 12,
  width = 30,
  height = 200,
})
```

**Known Issues**:
- dB to linear conversion may need calibration
- Scale rendering performance could be improved

---

### VUMeter
**File**: `vu_meter.lua`
**Status**: Prototype
**Description**: Audio level meter showing peak and RMS with color gradients.

**Features**:
- Peak and RMS level visualization
- Color zones (green → yellow → orange → red)
- Peak hold indicator with decay
- Clipping indicator
- Optional dB scale markings

**Usage**:
```lua
Ark.VUMeter(ctx, {
  label = "L",
  peak = peak_db,    -- Current peak level (dB)
  rms = rms_db,      -- Current RMS level (dB)
  min_db = -60,
  max_db = 0,
  width = 20,
  height = 200,
})
```

**Known Issues**:
- Horizontal orientation not yet implemented
- Peak hold decay rate is fixed (needs to be configurable)
- Performance not tested with many instances

---

### SpectrumAnalyzer
**File**: `spectrum_analyzer.lua`
**Status**: Prototype
**Description**: FFT spectrum visualization for frequency domain analysis.

**Features**:
- Frequency domain visualization (FFT bins)
- Logarithmic or linear frequency spacing
- Color gradient zones (green → yellow → orange → red)
- Single color mode or gradient mode
- Configurable frequency range (20Hz - 20kHz default)
- dB scaling with configurable range
- Optional frequency grid lines
- Convenience constructors: `standard()`, `bass()`, `midrange()`

**Usage**:
```lua
-- Standard spectrum analyzer (20Hz - 20kHz)
Ark.SpectrumAnalyzer(ctx, {
  bins = fft_bins,       -- Array of dB values
  width = 400,
  height = 150,
  min_db = -60,
  max_db = 0,
  sample_rate = 44100,
  is_logarithmic = true,  -- Log frequency spacing
  is_gradient = true,     -- Color gradient
  show_grid = true,       -- Frequency markers
})

-- Bass analyzer (20Hz - 500Hz)
Ark.SpectrumAnalyzer.bass(ctx, {
  bins = fft_bins,
  width = 300,
  height = 100,
})

-- Single color mode
Ark.SpectrumAnalyzer(ctx, {
  bins = fft_bins,
  is_gradient = false,
  color = Colors.hexrgb("#33FF66"),
})
```

**Known Issues**:
- Requires pre-computed FFT bins (doesn't compute FFT from audio)
- Peak hold not implemented yet
- No frequency labels on grid lines
- Bar spacing may cause aliasing at low widths

---

### StepSequencer
**File**: `step_sequencer.lua`
**Status**: Prototype
**Description**: Step sequencer grid for pattern editing in rhythm editors and drum machines.

**Features**:
- Interactive grid (tracks × steps)
- Toggle cells on/off with left-click
- Velocity adjustment with right-click (cycles 33% → 66% → 100%)
- Velocity-based color visualization
- Current step highlighting for playback indicator
- Optional track labels and step numbers
- Convenience constructors: `standard()`, `mini()`, `extended()`

**Usage**:
```lua
-- Create pattern (2D array: pattern[track][step] = velocity)
local pattern = {
  {1, 0, 0, 0, 1, 0, 0, 0},  -- Track 1: kick
  {0, 0, 1, 0, 0, 0, 1, 0},  -- Track 2: snare
  {1, 1, 1, 1, 1, 1, 1, 1},  -- Track 3: hi-hat
}

local result = Ark.StepSequencer(ctx, {
  pattern = pattern,
  steps = 8,
  tracks = 3,
  current_step = playback_position,  -- Highlight current step
  width = 300,
  height = 150,
  is_velocity_colors = true,         -- Color by velocity
  on_change = function(track, step, velocity)
    print(string.format("Track %d, Step %d: %s", track, step, velocity))
  end,
})

if result.changed then
  pattern = result.pattern  -- Get updated pattern
end

-- Mini 8-step sequencer
Ark.StepSequencer.mini(ctx, { pattern = pattern })

-- Extended 32-step sequencer
Ark.StepSequencer.extended(ctx, { pattern = pattern })
```

**Known Issues**:
- No keyboard navigation (arrow keys, space to toggle)
- No drag-to-paint multiple cells
- No copy/paste support
- Velocity adjustment is discrete (3 levels), not continuous

---

### Transport
**File**: `transport.lua`
**Status**: Prototype
**Description**: Transport control buttons for play/stop/record/loop functionality.

**Features**:
- Standard transport buttons (play, stop, pause, record, loop, rewind, forward)
- Configurable button set (choose which buttons to display)
- State-aware button highlighting (playing = green, recording = red)
- Icon-based buttons with circular design
- Individual callbacks for each button action
- Convenience constructors: `standard()`, `full()`, `minimal()`

**Usage**:
```lua
-- Standard transport (play, stop, record)
local result = Ark.Transport(ctx, {
  state = transport_state,        -- STATE_STOPPED, STATE_PLAYING, STATE_RECORDING
  is_loop_enabled = loop_enabled,
  button_size = 32,
  on_play = function()
    transport_state = Ark.Transport.STATE_PLAYING
  end,
  on_stop = function()
    transport_state = Ark.Transport.STATE_STOPPED
  end,
  on_record = function()
    transport_state = Ark.Transport.STATE_RECORDING
  end,
  on_loop = function(enabled)
    loop_enabled = enabled
  end,
})

-- Custom button set
Ark.Transport(ctx, {
  buttons = {"rewind", "play", "stop", "forward"},
  state = state,
})

-- Full transport with all buttons
Ark.Transport.full(ctx, { state = state })

-- Minimal (play/stop only)
Ark.Transport.minimal(ctx, { state = state })
```

**Known Issues**:
- Loop icon is simplified (not a true circular arrow)
- No tooltips showing button functions
- No keyboard shortcuts (space for play/stop, etc.)
- Icons could be more polished

---

### XYPad
**File**: `xy_pad.lua`
**Status**: Prototype
**Description**: 2D control surface for manipulating two parameters simultaneously.

**Features**:
- Two-axis control (X/Y)
- Optional grid snapping
- Crosshair indicator
- Configurable value ranges for each axis
- Visual grid overlay

**Usage**:
```lua
local result = Ark.XYPad(ctx, {
  label_x = "Rate",
  label_y = "Depth",
  value_x = rate,
  value_y = depth,
  min_x = 0, max_x = 10,
  min_y = 0, max_y = 1,
  size = 200,
  snap_to_grid = true,
  grid_divisions = 4,
})

if result.changed then
  rate = result.value_x
  depth = result.value_y
end
```

**Known Issues**:
- Grid snapping feels quantized (needs smoothing)
- No keyboard navigation support

---

### Waveform
**File**: `audio/waveform.lua`
**Status**: Prototype
**Description**: Audio waveform visualization from peak data array.

**Features**:
- Displays audio waveform from peak data
- Filled or outline rendering modes
- Performance-optimized with polyline caching
- Automatic downsampling for target width
- Quality multiplier for resolution control

**Usage**:
```lua
Ark.Waveform(ctx, {
  peaks = peak_data,      -- Array of peak values [max1, max2, ..., min1, min2, ...]
  width = 400,
  height = 100,
  color = waveform_color,
  is_filled = true,       -- Filled polygons vs outline
  quality = 1.0,          -- Resolution multiplier
})
```

**Known Issues**:
- Requires pre-extracted peak data (doesn't extract from audio files)
- Cache grows unbounded (needs cleanup strategy)

---

### MIDIPianoRoll
**File**: `audio/midi_piano_roll.lua`
**Status**: Prototype
**Description**: MIDI piano roll visualization from note rectangle data.

**Features**:
- Displays MIDI notes as rectangles (piano roll view)
- LOD culling for performance (skips notes < 1px)
- Scales from cache resolution to display resolution
- Clip rect prevents overflow

**Usage**:
```lua
Ark.MIDIPianoRoll(ctx, {
  notes = midi_notes,     -- Array of note rectangles: {{x1, y1, x2, y2}, ...}
  width = 400,
  height = 200,
  color = note_color,
  cache_width = 400,      -- Width notes are normalized to
  cache_height = 200,     -- Height notes are normalized to
  is_culling_enabled = true,
})
```

**Known Issues**:
- Requires pre-extracted note data (doesn't parse MIDI files)
- No note coloring by velocity or channel
- No piano keyboard guide on left side

---

### Piano
**File**: `audio/piano.lua`
**Status**: Prototype
**Description**: Interactive piano keyboard for note input and visualization.

**Features**:
- Horizontal or vertical orientation
- Configurable octave range (start_note + num_octaves or end_note)
- Interactive mode (clickable keys) or display-only mode
- Active note highlighting (for showing which notes are playing)
- White and black keys with proper layout
- Hover states
- Returns pressed/released notes

**Usage**:
```lua
-- Interactive piano (input device)
local result = Ark.Piano(ctx, {
  orientation = "horizontal",
  start_note = 60,       -- Middle C
  num_octaves = 2,       -- 2 octaves
  white_key_width = 20,
  white_key_height = 80,
  is_interactive = true,
  active_notes = {[64] = true, [67] = true},  -- E and G highlighted
  on_note_press = function(note)
    print("Note pressed:", note)
  end,
})

-- Display-only piano (show scale/active notes)
Ark.Piano(ctx, {
  orientation = "vertical",
  start_note = 48,
  num_octaves = 3,
  is_interactive = false,  -- Display only
  active_notes = c_major_scale,
})
```

**Known Issues**:
- No scrollable mode yet (will clip if too many octaves)
- No keyboard input support (only mouse)
- Note release detection not implemented (would need state tracking)
- Black keys overlap white keys (z-order), may cause click precision issues

---

### MediaItem
**File**: `audio/media_item.lua`
**Status**: Prototype
**Description**: Complete media item tile with waveform/MIDI, header, and badges.

**Features**:
- Colored background (track/item color)
- Audio visualization (uses Waveform widget)
- MIDI visualization (uses MIDIPianoRoll widget)
- Auto-detects visualization type (peaks = audio, midi_notes = MIDI)
- Header with name/label
- Duration badge (minutes:seconds)
- Pool count badge (for pooled items)
- Selection border
- Disabled/muted state overlays
- Click/right-click/double-click callbacks

**Usage**:
```lua
-- Audio item
local result = Ark.MediaItem(ctx, {
  name = "Audio 01.wav",
  duration = 3.5,         -- seconds
  color = track_color,
  peaks = peak_data,      -- for audio
  is_selected = false,
  disabled = false,
  pool_count = 3,         -- optional
  width = 200,
  height = 80,
  on_click = function() ... end,
})

-- MIDI item
local result = Ark.MediaItem(ctx, {
  name = "MIDI Pattern",
  duration = 4.0,
  color = track_color,
  midi_notes = note_data, -- for MIDI
  is_selected = false,
  width = 200,
  height = 80,
})

if result.clicked then
  -- Handle click
end
```

**Known Issues**:
- No animation support (hover/selection transitions)
- Badges are always top-right (not configurable)
- No marching ants selection indicator yet
- No playback progress bar support

---

### Nodes
**File**: `nodes.lua`
**Status**: Prototype (rendering complete, interaction in progress)
**Description**: General-purpose node editor for visual programming and patching interfaces.

**Features**:
- Node rendering with title bars and pins (inputs/outputs)
- Bezier curve links between pins
- Grid background with pan/zoom support
- Clean data-driven API (nodes array + links array)
- Inspired by imnodes but using ARKITEKT conventions

**Usage**:
```lua
local nodes = {
  {
    id = "osc",
    label = "Oscillator",
    x = 50, y = 50,
    width = 140, height = 120,
    inputs = {
      {id = "freq", label = "Frequency", type = "float"},
    },
    outputs = {
      {id = "out", label = "Audio Out", type = "audio"},
    },
  },
  -- ... more nodes
}

local links = {
  {
    id = "link1",
    from_node = "osc",
    from_pin = "out",
    to_node = "filter",
    to_pin = "in",
  },
}

Ark.Nodes(ctx, {
  width = 800,
  height = 600,
  nodes = nodes,
  links = links,
  pan_x = state.pan_x,
  pan_y = state.pan_y,
  zoom = 1.0,
  show_grid = true,
})
```

**Known Issues**:
- Drag nodes not implemented yet
- Create/delete links not implemented yet
- Canvas pan/zoom interaction not implemented yet
- No minimap
- No multi-select
- See demo: `scripts/demos/ARK_NodeEditor.lua`

**Use Cases**:
- Audio patching interfaces
- Visual scripting tools
- State machine editors
- Data flow graphs

---

## Development Guidelines

When adding widgets to this folder:

1. **Mark as experimental** in file header
2. **Document known issues** in this README
3. **Follow ARKITEKT conventions** (Base utilities, opts tables, etc.)
4. **Include usage examples** in comments
5. **Note performance characteristics** if widget is complex

## Graduation Criteria

A widget moves from `experimental/` to `primitives/` when:

- [ ] API is stable (no breaking changes planned)
- [ ] Performance is verified (profiled in real apps)
- [ ] Edge cases are handled (disabled state, extreme values)
- [ ] Documentation is complete (cookbook entry)
- [ ] Used successfully in at least one production script

## Future Ideas

### ImGui Extensions Worth Considering

**ImGuiFileDialog** ([GitHub](https://github.com/aiekick/ImGuiFileDialog))
- Rich file browser with thumbnails, bookmarks, multi-select
- Could be useful for sample browsers, preset managers, media libraries
- Note: REAPER has native file dialogs (`reaper.GetUserFileNameForRead`), so priority is lower
- Best use case: Embedded file browser in custom UIs (not modal dialogs)

**ImPlot** ([GitHub](https://github.com/epezent/implot))
- Professional 2D plotting library
- Could enhance Waveform/Spectrum widgets with zoom, pan, axis labels, legends
- Would enable scientific-grade data visualization
- High value for analysis tools

**ImGuizmo** ([GitHub](https://github.com/CedricGuillemet/ImGuizmo))
- 3D gizmos and transformation widgets
- Lower priority for REAPER (mostly 2D workflows)

### Widget Ideas

**Already Implemented** ✅
- ~~Waveform Display~~ → `Waveform.lua`
- ~~Spectrum Analyzer~~ → `SpectrumAnalyzer.lua`
- ~~Piano Roll Grid~~ → `MIDIPianoRoll.lua`
- ~~Step Sequencer~~ → `StepSequencer.lua`
- ~~Transport Controls~~ → `Transport.lua`
- ~~Rotary Encoder~~ → `Encoder.lua`
- ~~Node Editor~~ → `Nodes.lua`

**Under Consideration**
- **Envelope Editor** - ADSR/multi-point envelope editor (complex interaction model)
- **Channel Strip** - Composite widget (can be built from Fader + Button + VUMeter)
- **Interactive Piano Roll** - Full MIDI editing (very complex, may not be worth it)
- **LED Indicator** - Simple on/off status light
- **7-Segment Display** - Retro numeric display for timecode/BPM
- **Minimap** - Thumbnail overview for canvas navigation

---

**Questions? Feedback?**
Report issues or suggest improvements in the main ARKITEKT repo.

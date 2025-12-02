# Experimental Widgets

**⚠️ Warning: APIs in this folder are unstable and may change.**

This folder contains prototype widgets that are being developed and tested. Use them at your own risk, as their APIs, behavior, and performance characteristics may change between versions.

## Current Experimental Widgets

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

## Future Candidates

Widgets being considered for experimental:

- **Waveform Display** - Zoomable audio waveform viewer
- **Spectrum Analyzer** - FFT visualization
- **Envelope Editor** - ADSR curve editor
- **Piano Roll Grid** - MIDI note grid
- **Step Sequencer** - Grid-based step programming
- **Channel Strip** - Composite widget (fader + pan + buttons)
- **Transport Controls** - Play/stop/record button group
- **Rotary Encoder** - Continuous rotation knob (no min/max)

---

**Questions? Feedback?**
Report issues or suggest improvements in the main ARKITEKT repo.

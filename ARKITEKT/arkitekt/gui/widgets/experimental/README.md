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

# MIDI Helix - Roadmap & UI Design

> Generative MIDI toolkit for REAPER. Inspired by MIDI Ex Machina, extended with melodic transforms.

---

## Visual Style Guide

### Tab Color System (Ex Machina Style)

Each tab has a **signature color** applied to:
- Tab button (active state)
- Header bar accent
- Action buttons
- Active radio/checkbox indicators

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  TAB COLOR PALETTE                                                           │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  GENERATORS (warm → cool)                                                    │
│  ┌─────────────┬─────────────┬─────────────┐                                │
│  │ RANDOMIZER  │  SEQUENCER  │  EUCLIDEAN  │                                │
│  │   GREEN     │   YELLOW    │   ORANGE    │                                │
│  │ 0x50C878FF  │ 0xFFD700FF  │ 0xFF8C00FF  │                                │
│  └─────────────┴─────────────┴─────────────┘                                │
│                                                                              │
│  TRANSFORMERS (cool tones)                                                   │
│  ┌─────────────┬─────────────┐                                              │
│  │   MELODIC   │   RHYTHM    │                                              │
│  │    CYAN     │   MAGENTA   │                                              │
│  │ 0x00CED1FF  │ 0xDA70D6FF  │                                              │
│  └─────────────┴─────────────┘                                              │
│                                                                              │
│  COMMON ELEMENTS                                                             │
│  ┌─────────────┬─────────────┬─────────────┐                                │
│  │   SLIDERS   │   LABELS    │   BORDERS   │                                │
│  │    BLUE     │   GREY      │  DARK GREY  │                                │
│  │ 0x4A90D9FF  │ 0x808080FF  │ 0x404040FF  │                                │
│  └─────────────┴─────────────┴─────────────┘                                │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### ARKITEKT Renderer Effects

Use `arkitekt/gui/renderers/tile/renderer.lua` for rich widget rendering:

```lua
-- Tile renderer config for buttons/sliders
local TILE_CONFIG = {
  -- Fill
  fill_opacity = 0.85,
  fill_saturation = 0.9,
  fill_brightness = 1.0,

  -- Gradient (top-to-bottom depth)
  gradient_intensity = 0.15,
  gradient_opacity = 0.4,

  -- Specular highlight (glossy top edge)
  specular_strength = 0.25,
  specular_coverage = 0.35,

  -- Inner shadow (depth)
  inner_shadow_strength = 0.3,

  -- Border
  border_opacity = 0.8,
  border_saturation = 0.7,
  border_brightness = 0.6,
  border_thickness = 1,

  -- Glow (selection/hover)
  glow_layers = 3,
  glow_strength = 0.6,

  -- Rounding
  rounding = 4,

  -- Hover boost
  hover_fill_boost = 0.1,
  hover_specular_boost = 0.3,
}
```

### Ex Machina Layout Reference

```
WINDOW: 900 x 280 px (default, scalable 70%-200%)

┌─────────────────────────────────────────────────────────────────────────────┐
│ [Zoom▼]  MIDI Ex Machina                                                    │  <- y=5, h=22
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─ LEFT PANEL (x=25) ─────────────────┐  ┌─ SLIDERS (x=160) ─────────────┐│
│  │                                      │  │                               ││
│  │  [Key▼][Oct▼]      y=70, h=20       │  │  ▓▓  ▓▓  ▓▓  ▓▓  ...  ▓▓     ││ <- y=50, h=150
│  │                                      │  │  ▓▓  ▓▓  ▓▓  ▓▓  ...  ▓▓     ││    w=30, spacing=40
│  │  [Scale▼]          y=120, h=20      │  │  ▓▓  ▓▓  ▓▓  ▓▓  ...  ▓▓     ││
│  │                                      │  │  ──  ──  ──  ──  ...  ──     ││ <- Labels y=210
│  │  [Shuffle]         y=165, h=25      │  │  C   D   E   F   ...  Oct     ││
│  │                                      │  │                               ││
│  │  [Randomize]       y=205, h=25      │  └───────────────────────────────┘│
│  │                                      │                                   │
│  └──────────────────────────────────────┘  ┌─ OPTIONS (x=700) ────────────┐│
│                                            │  ☐ All/Sel   y=80            ││
│                                            │  ☐ 1st=Root  y=110           ││
│                                            │  ☐ Oct x2    y=140           ││
│                                            └──────────────────────────────┘│
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│ [Randomiser] [Sequencer] [Euclidiser] [Options]              [Undo] [Redo] │ <- y=h-25, h=20
└─────────────────────────────────────────────────────────────────────────────┘
   x=5,w=100    x=105      x=205        x=305                  x=w-85  x=w-45
```

### Vertical Slider Widget Spec

```
VERTICAL SLIDER (Ex Machina style)
┌────────────────────────────────────────┐
│                                        │
│  Width:   30px                         │
│  Height:  150px                        │
│  Spacing: 40px (center to center)      │
│                                        │
│  ┌──────┐                              │
│  │      │  <- Track (dark, recessed)   │
│  │  ▓▓  │                              │
│  │  ▓▓  │  <- Fill (colored, from      │
│  │  ▓▓  │     bottom up based on val)  │
│  │  ▓▓  │                              │
│  │  ▓▓  │  <- Specular on fill top     │
│  │  ▓▓  │                              │
│  └──────┘                              │
│    C#      <- Label below              │
│                                        │
│  Rendering layers:                     │
│  1. Track background (0x202020FF)      │
│  2. Track border (0x404040FF)          │
│  3. Fill gradient (tab color)          │
│  4. Specular highlight (top 35%)       │
│  5. Inner shadow (top edge)            │
│  6. Value indicator line               │
│                                        │
└────────────────────────────────────────┘
```

### Button Rendering (with effects)

```lua
-- Action button with full effects
local function draw_action_button(ctx, dl, x, y, w, h, label, tab_color, is_hovered, is_active)
  local TileRenderer = require('arkitekt.gui.renderers.tile.renderer')

  local config = {
    rounding = 4,
    fill_opacity = is_active and 0.95 or (is_hovered and 0.9 or 0.85),
    fill_saturation = 0.85,
    fill_brightness = is_active and 1.1 or 1.0,
    gradient_intensity = 0.2,
    gradient_opacity = 0.5,
    specular_strength = is_hovered and 0.4 or 0.25,
    specular_coverage = 0.35,
    inner_shadow_strength = 0.25,
    border_opacity = 0.9,
    border_saturation = 0.6,
    border_brightness = 0.5,
    border_thickness = 1,
    glow_layers = is_hovered and 2 or 0,
    glow_strength = 0.4,
    hover_fill_boost = 0,
    hover_specular_boost = 0,
  }

  TileRenderer.render_complete_fast(ctx, dl, x, y, x + w, y + h, tab_color, config, false, 0, 0, 0)
end
```

---

## Vision

MIDI Helix is a **generative composition tool** with two core capabilities:

1. **Generators** - Create patterns from scratch (Euclidean, Sequencer, Randomizer)
2. **Transformers** - Modify existing MIDI (Inversion, Retrograde, Re-Rhythm, etc.)

The UI follows Ex Machina's proven tab-based paradigm while adding new transformation modules.

---

## UI Architecture

### Window Structure

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  MIDI Helix v0.2                                           [Undo] [Redo]   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─ COMMON CONTROLS ──────────────────────────────────────────────────────┐ │
│  │  Key [C ▼]  Octave [4 ▼]  Scale [Minor ▼]       Source: [Selection ▼] │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  ┌─ TAB CONTENT AREA ─────────────────────────────────────────────────────┐ │
│  │                                                                        │ │
│  │                    [ Active Tab Content Here ]                         │ │
│  │                                                                        │ │
│  │                                                                        │ │
│  │                                                                        │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  ┌─ STATUS BAR ───────────────────────────────────────────────────────────┐ │
│  │  ✓ Pattern generated: E(5,8,0) = [x.x.xx.x]                           │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│ [Euclidean] [Sequencer] [Randomizer] │ [Melodic] [Rhythm] │ [Options]      │
│ ─────────── GENERATORS ────────────── ──── TRANSFORMERS ──                  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Tab Organization

| Category | Tab | Purpose |
|----------|-----|---------|
| **Generators** | Euclidean | Bjorklund algorithm rhythm patterns |
| | Sequencer | Probability-based note length sequences |
| | Randomizer | Scale-weighted pitch randomization |
| **Transformers** | Melodic | Pitch transformations (invert, retrograde, transpose) |
| | Rhythm | Time transformations (augment, quantize, humanize) |
| **Settings** | Options | Preferences, MIDI output settings |

---

## Tab Layouts (Ex Machina Style)

### Layout Constants

```lua
-- MIDIHelix/config/layout.lua
return {
  -- Window
  WINDOW = { W = 900, H = 280 },

  -- Header bar
  HEADER = { X = 5, Y = 5, H = 22 },

  -- Left panel (controls, buttons)
  LEFT_PANEL = { X = 25, W = 110 },

  -- Dropdowns
  KEY_DROP   = { X = 25, Y = 70, W = 50, H = 20 },
  OCT_DROP   = { X = 80, Y = 70, W = 50, H = 20 },
  SCALE_DROP = { X = 25, Y = 120, W = 110, H = 20 },

  -- Action buttons (stacked)
  BTN_PRIMARY   = { X = 25, Y = 205, W = 110, H = 25 },
  BTN_SECONDARY = { X = 25, Y = 165, W = 110, H = 25 },

  -- Vertical sliders area
  SLIDERS = { X = 160, Y = 50, W = 30, H = 150, SPACING = 40 },

  -- Options checkboxes
  OPTIONS = { X = 700, Y = 80, W = 30, H = 30, SPACING = 30 },

  -- Tab bar (bottom)
  TAB_BAR = { Y_OFFSET = -25, H = 20, BTN_W = 100 },

  -- Undo/Redo
  UNDO_BTN = { X_OFFSET = -85, W = 40 },
  REDO_BTN = { X_OFFSET = -45, W = 40 },
}
```

### 1. Euclidean Tab (ORANGE = 0xFF8C00FF)

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ [100%▼]  MIDI Helix                                                                 │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│   ┌────────────┐     ▓▓▓▓   ▓▓▓▓   ▓▓▓▓                    ┌──────────────────┐   │
│   │ [Key▼]     │     ▓▓▓▓   ▓▓▓▓   ▓▓▓▓                    │ ☐ Generate       │   │
│   │ [Oct▼]     │     ▓▓▓▓   ▓▓▓▓   ▓▓▓▓                    │ ☑ Accent         │   │
│   └────────────┘     ▓▓▓▓   ▓▓▓▓   ▓▓▓▓      ●             │ ☐ Rnd Notes      │   │
│                      ▓▓▓▓   ▓▓▓▓   ▓▓▓▓    ·   ·           └──────────────────┘   │
│   ┌────────────┐     ▓▓▓▓   ▓▓▓▓   ▓▓▓▓   ●     ●                                 │
│   │ [Scale▼]   │     ▓▓▓▓   ▓▓▓▓   ▓▓▓▓    ·   ·          ┌──────────────────────┐│
│   └────────────┘     ▓▓▓▓   ▓▓▓▓   ▓▓▓▓      ●   ●        │ Grid   [1/16▼]      ││
│                      ▓▓▓▓   ▓▓▓▓   ▓▓▓▓    ·       ·      │ Length [1/16▼]      ││
│   ┌────────────┐     ▓▓▓▓   ▓▓▓▓   ▓▓▓▓      ●            │ Vel  ═══════●═══ 96 ││
│   │ [Generate] │     ────   ────   ────                    └──────────────────────┘│
│   └────────────┘     Puls  Steps  Rotat   E(5,8,0)                                 │
│                                                                                     │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ [Randomizer][Sequencer][Euclidean][Melodic][Rhythm][Options]         [Undo][Redo]  │
└─────────────────────────────────────────────────────────────────────────────────────┘
    GREEN      YELLOW     ORANGE    CYAN    MAGENTA  GREY
```

### 2. Sequencer Tab (YELLOW = 0xFFD700FF)

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ [100%▼]  MIDI Helix                                                                 │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│   ┌────────────┐     ▓▓▓▓   ▓▓▓▓   ▓▓▓▓   ▓▓▓▓      ▓▓▓▓   ▓▓▓▓   ┌─────────────┐ │
│   │ [Key▼]     │     ▓▓▓▓   ▓▓▓▓   ▓▓▓▓   ▓▓▓▓      ▓▓▓▓   ▓▓▓▓   │ ☑ Generate  │ │
│   │ [Oct▼]     │     ▓▓▓▓   ▓▓▓▓   ▓▓▓▓   ▓▓▓▓      ▓▓▓▓   ▓▓▓▓   │ ☑ 1st Note  │ │
│   └────────────┘     ▓▓▓▓   ▓▓▓▓   ▓▓▓▓   ▓▓▓▓      ▓▓▓▓   ▓▓▓▓   │ ☑ Accent    │ │
│   ○ 1/16             ▓▓▓▓   ▓▓▓▓   ▓▓▓▓   ▓▓▓▓      ▓▓▓▓   ▓▓▓▓   │ ☐ Legato    │ │
│   ● 1/8              ▓▓▓▓   ▓▓▓▓   ▓▓▓▓   ▓▓▓▓      ▓▓▓▓   ▓▓▓▓   │ ☐ Rnd Notes │ │
│   ○ 1/4              ▓▓▓▓   ▓▓▓▓   ▓▓▓▓   ▓▓▓▓      ▓▓▓▓   ▓▓▓▓   └─────────────┘ │
│   └─Grid─┘           ────   ────   ────   ────      ────   ────                    │
│   ┌────────────┐     1/16   1/8    1/4    Rest      Vel    Leg    [<<][ 0 ][>>]   │
│   │ [Scale▼]   │     └── Note Length Prob ──┘      └Acc%─┘ └%─┘    └─Shift──┘     │
│   └────────────┘                                                                   │
│   ┌────────────┐                                                                   │
│   │ [Generate] │                                                                   │
│   └────────────┘                                                                   │
│                                                                                     │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ [Randomizer][Sequencer][Euclidean][Melodic][Rhythm][Options]         [Undo][Redo]  │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 3. Randomizer Tab (GREEN = 0x50C878FF)

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ [100%▼]  MIDI Helix                                                                 │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│   ┌────────────┐     ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   │
│   │ [Key▼]     │     ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   │
│   │ [Oct▼]     │     ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   │
│   └────────────┘     ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   │
│                      ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   │
│   ┌────────────┐     ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   │
│   │ [Scale▼]   │     ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   │
│   └────────────┘     ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓▓   │
│                      ──   ──   ──   ──   ──   ──   ──   ──   ──   ──   ──   ──   │
│   ┌────────────┐     C    C#   D    D#   E    F    F#   G    G#   A    A#   B    │
│   │ [Shuffle ] │     └───────────────── Note Weight Sliders ───────────────────┘   │
│   └────────────┘                                                                   │
│   ┌────────────┐     ┌──────────────────────────────────────────────────────────┐ │
│   │[Randomize] │     │ ☐ All/Sel   ☑ 1st=Root   ☐ Oct x2           ▓▓▓▓  Oct  │ │
│   └────────────┘     └──────────────────────────────────────────────────────────┘ │
│                                                                                     │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ [Randomizer][Sequencer][Euclidean][Melodic][Rhythm][Options]         [Undo][Redo]  │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 4. Melodic Transform Tab (CYAN = 0x00CED1FF)

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ [100%▼]  MIDI Helix                                                                 │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│   ┌────────────┐     ┌─ TRANSFORM ────────────────────────────────────────────────┐│
│   │ [Key▼]     │     │ ● Invert  ○ Retro  ○ Retro-Inv  ○ Transpose  ○ Rotate    ││
│   │ [Oct▼]     │     └────────────────────────────────────────────────────────────┘│
│   └────────────┘                                                                   │
│                      ┌─ INVERSION PARAMS ─────────────────────────────────────────┐│
│   ┌────────────┐     │                                                            ││
│   │ [Scale▼]   │     │  Pivot [C4▼]     Mode: ○ Chromatic  ● Diatonic            ││
│   └────────────┘     │                                                            ││
│                      └────────────────────────────────────────────────────────────┘│
│   Source:            ┌─ PREVIEW ──────────────────────────────────────────────────┐│
│   ○ Selection        │  Original: C4 E4 G4 C5     ●       ●                       ││
│   ○ All Notes        │                                ●                           ││
│                      │  Inverted: C4 Ab3 F3 C3            ●   ●                   ││
│   ┌────────────┐     │                                        ●                   ││
│   │ [ Apply  ] │     └────────────────────────────────────────────────────────────┘│
│   └────────────┘                                                                   │
│                                                                                     │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ [Randomizer][Sequencer][Euclidean][Melodic][Rhythm][Options]         [Undo][Redo]  │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 5. Rhythm Transform Tab (MAGENTA = 0xDA70D6FF)

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ [100%▼]  MIDI Helix                                                                 │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│   ┌────────────┐     ┌─ TRANSFORM ────────────────────────────────────────────────┐│
│   │ [Key▼]     │     │ ● Aug/Dim  ○ Quantize  ○ Swing  ○ Humanize  ○ Re-Rhythm   ││
│   │ [Oct▼]     │     └────────────────────────────────────────────────────────────┘│
│   └────────────┘                                                                   │
│                      ┌─ AUGMENT/DIMINISH ─────────────────────────────────────────┐│
│   ┌────────────┐     │                                                            ││
│   │ [Scale▼]   │     │  Factor ════════════●════════════  x2.0 (double)          ││
│   └────────────┘     │          x0.25              x4.0                           ││
│                      │                                                            ││
│   Source:            │  ☑ Durations   ☑ Positions   ☐ Velocities                 ││
│   ○ Selection        └────────────────────────────────────────────────────────────┘│
│   ○ All Notes        ┌─ PREVIEW ──────────────────────────────────────────────────┐│
│                      │  Before: │▓▓│▓▓│  │▓▓▓▓│▓▓│  │▓▓│                         ││
│   ┌────────────┐     │  After:  │▓▓▓▓│▓▓▓▓│    │▓▓▓▓▓▓▓▓│▓▓▓▓│    │▓▓▓▓│        ││
│   │ [ Apply  ] │     └────────────────────────────────────────────────────────────┘│
│   └────────────┘                                                                   │
│                                                                                     │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ [Randomizer][Sequencer][Euclidean][Melodic][Rhythm][Options]         [Undo][Redo]  │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Transform Parameters Reference

### Melodic Transforms

| Transform | Parameters |
|-----------|------------|
| **Inversion** | Pivot note (C0-C8), Mode (Chromatic/Diatonic) |
| **Retrograde** | Preserve timing (on/off) |
| **Retro-Inversion** | Pivot note, Mode |
| **Transpose** | Interval (-12 to +12), Mode (Chromatic/Diatonic) |
| **Rotation** | Shift amount (-8 to +8), Direction |
| **Scale Quantize** | Scale, Root, Direction (Nearest/Up/Down) |
| **Octave Fold** | Target octave, Preserve intervals |

### Rhythm Transforms

| Transform | Parameters |
|-----------|------------|
| **Augment/Diminish** | Factor (0.25x to 4x), Affect (Durations/Positions/Velocities) |
| **Quantize** | Grid (1/4 to 1/32), Strength (0-100%), Mode |
| **Swing** | Amount (0-100%), Grid, Style preset |
| **Humanize** | Timing variance, Velocity variance, Length variance |
| **Re-Rhythm** | Source rhythm, Target pitches, Merge mode |
| **Time Shift** | Shift amount, Grid snap |

---

## Feature Matrix

| Feature | Phase 1 | Phase 2 | Phase 3 |
|---------|:-------:|:-------:|:-------:|
| **Generators** | | | |
| Euclidean | ✅ | ✅ | ✅ |
| Sequencer | | ✅ | ✅ |
| Randomizer | | ✅ | ✅ |
| **Melodic Transforms** | | | |
| Inversion | | ✅ | ✅ |
| Retrograde | | ✅ | ✅ |
| Retrograde Inversion | | ✅ | ✅ |
| Transpose | | ✅ | ✅ |
| Rotation | | | ✅ |
| Scale Quantize | | | ✅ |
| Octave Fold | | | ✅ |
| **Rhythm Transforms** | | | |
| Augment/Diminish | | ✅ | ✅ |
| Quantize | | | ✅ |
| Swing | | | ✅ |
| Humanize | | | ✅ |
| Re-Rhythm | | | ✅ |
| **Infrastructure** | | | |
| Common controls (key/scale) | | ✅ | ✅ |
| Preview system | | ✅ | ✅ |
| Undo/Redo | | ✅ | ✅ |
| Settings persistence | | | ✅ |
| Transform chaining | | | Future |

---

## Implementation Phases

### Phase 1: Foundation (Current)
- [x] Euclidean generator (basic)
- [x] MIDI output to REAPER
- [ ] Enhanced Euclidean UI (visualization)
- [ ] Tab infrastructure

### Phase 2: Core Transforms
- [ ] Tab-based navigation
- [ ] Common controls (key, scale, octave)
- [ ] Melodic tab with: Inversion, Retrograde, Transpose
- [ ] Rhythm tab with: Augment/Diminish
- [ ] Preview system (before/after)
- [ ] Sequencer generator
- [ ] Randomizer generator

### Phase 3: Extended Features
- [ ] Additional melodic transforms (Rotation, Scale Quantize, Octave Fold)
- [ ] Additional rhythm transforms (Quantize, Swing, Humanize, Re-Rhythm)
- [ ] Settings persistence
- [ ] Presets system

### Future: Advanced
- [ ] Transform chaining/pipeline
- [ ] MIDI input monitoring
- [ ] Pattern library/favorites
- [ ] Audio preview

---

## Domain Logic Modules

```
domain/
├── euclidean.lua        # Bjorklund algorithm (exists)
├── scales.lua           # Scale definitions, quantization
├── transforms/
│   ├── melodic.lua      # Inversion, retrograde, transpose, rotation
│   ├── rhythm.lua       # Augment, diminish, quantize, swing, humanize
│   └── utils.lua        # Common transform utilities
└── sequence.lua         # Probability-based sequence generation
```

---

## UI Module Structure

```
ui/
├── init.lua             # Main orchestrator (tab management)
├── common/
│   ├── controls.lua     # Key, scale, octave selectors
│   └── preview.lua      # Before/after visualization
├── views/
│   ├── euclidean.lua    # Euclidean generator view
│   ├── sequencer.lua    # Sequencer view
│   ├── randomizer.lua   # Randomizer view
│   ├── melodic.lua      # Melodic transforms view
│   ├── rhythm.lua       # Rhythm transforms view
│   └── options.lua      # Settings view
└── widgets/
    ├── pattern_ring.lua # Circular pattern visualization
    ├── piano_roll.lua   # Mini piano roll preview
    └── weight_sliders.lua # Vertical probability sliders
```

---

## Design Principles

1. **Tab-based, like Ex Machina** - Familiar paradigm, proven UX
2. **Generators vs Transformers** - Clear mental model
3. **Preview before commit** - Non-destructive workflow
4. **Scale-aware** - Diatonic options for musical results
5. **Progressive disclosure** - Simple defaults, advanced options available
6. **Visual feedback** - Pattern visualization, before/after comparisons

---

## Open Questions

- [ ] Should transforms be stackable (pipeline)?
- [ ] MIDI input monitoring for live transformation?
- [ ] Preset system for saving favorite transform settings?
- [ ] Integration with other ARKITEKT apps?

---

## References

- MIDI Ex Machina (RobU) - Original inspiration
- Music theory: Counterpoint, Serial composition, Bjorklund's algorithm
- DAW paradigms: Ableton, Bitwig, VCV Rack

---

*Last updated: 2024-12*

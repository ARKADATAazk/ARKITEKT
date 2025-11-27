# WALTER Builder - Development Progress

> **WALTER**: Window Arrangement Logic Template Engine for REAPER

This document tracks the development progress of the visual rtconfig editor/builder.

---

## Current Status: Expression Evaluation Working

**Date**: 2024-11-27

The expression evaluator now successfully parses and evaluates 80/80 computed expressions from complex rtconfig themes. Elements are positioned correctly on the canvas.

### Recent Updates

**2024-11-27 (Session 2)**
- Added **Customs section** in elements panel for theme-specific elements not in standard definitions
- Custom elements display with purple color for easy identification
- Improved **right-click UX**: direct toggle (no context menu)
- Right-click on category headers toggles all elements in that category
- Added `is_custom` flag to Element model for tracking non-standard elements

---

## Architecture Overview

```
WalterBuilder/
├── domain/                    # Core logic (pure, no UI)
│   ├── rtconfig_parser.lua    # Tokenizes rtconfig files into AST
│   ├── expression_eval.lua    # Evaluates WALTER expressions
│   ├── rtconfig_converter.lua # Converts AST to Element models
│   ├── element.lua            # Element model (id, coords, category)
│   ├── coordinate.lua         # Coordinate math and rect computation
│   └── simulator.lua          # Simulates layout at different sizes
├── ui/
│   ├── gui.lua                # Main UI orchestration
│   ├── canvas/
│   │   ├── preview_canvas.lua # Canvas rendering
│   │   ├── element_renderer.lua # Element drawing with attachments
│   │   └── track_renderer.lua # Track panel background
│   └── panels/
│       ├── rtconfig_panel.lua # File loading, context selection
│       ├── elements_panel.lua # Element list/tree
│       ├── properties_panel.lua # Selected element properties
│       └── debug_console.lua  # Logging output
├── infra/
│   └── settings.lua           # Persistent settings (JSON storage)
└── defs/
    └── colors.lua             # Color constants
```

---

## WALTER Coordinate System

### Basic Format
```
[x y w h ls ts rs bs]
```

| Field | Description |
|-------|-------------|
| x, y | Position (can be negative for right/bottom-relative) |
| w, h | Dimensions (can be negative for stretch-from-edge) |
| ls | Left attachment (0-1, how left edge moves with parent) |
| ts | Top attachment |
| rs | Right attachment |
| bs | Bottom attachment |

### Attachment Behaviors

| ls | rs | Behavior |
|----|----|----|
| 0 | 0 | Fixed position |
| 0 | 1 | Stretches right |
| 1 | 0 | Stretches left |
| 1 | 1 | Moves with parent (fixed size) |

### Negative Coordinate Patterns

**Pattern 1: Right-relative positioning (no attachments)**
```
set tcp.mute [-25 3 21 20]
```
- x=-25 with ls=0, rs=0 means "25px from right edge"
- Canvas interprets as: `x = parent_w + x = 300 + (-25) = 275`

**Pattern 2: Stretch from edge**
```
set tcp.meter [5 2 -27 -5]
```
- w=-27 means "stretch to 27px from right edge"
- h=-5 means "stretch to 5px from bottom edge"

---

## Expression Evaluation

### Supported Syntax

**Prefix notation (Polish notation)**
```
+ [10 20] [5 5]           → [15, 25]
* scale [300 100]         → [300, 100] (scale=1)
- [100 50] [10 10]        → [90, 40]
/ [100 50] [2 2]          → [50, 25]
```

**Conditionals**
```
?condition [true_val] [false_val]
!condition [true_val] [false_val]    (negated)
```

**Comparison conditionals**
```
scale==1 [value_if_true] [value_if_false]
h<100 [small_coords] [large_coords]
```

**Variable references**
```
meter_sec                  → variable value
meter_sec{2}               → array index (0-based in WALTER, 1-based in Lua)
tcp.mute{3}                → element coordinate index
```

**@position notation (sparse arrays)**
```
40@y                       → [0, 40]
-4@x                       → [-4]
1@rs                       → [0, 0, 0, 0, 0, 0, 1]
```

**Inside brackets**
```
[-4@x 21 20 0 0 1]         → [-4, 0, 21, 20, 0, 0, 1]
[meter_sec]                → entire array if meter_sec is array
[meter_sec{2}]             → single indexed value
```

### Expression Examples from Real Themes

**tcp.mute** (positioned relative to meter section):
```
+ + [meter_sec] [meter_sec{2}] ?is_solo_flipped * scale [-25 3 21 20] + [0 tcp_padding] * scale [-44 0 21 20]
```

**tcp.solo** (positioned relative to tcp.mute):
```
?is_solo_flipped + + scale==1 1@y 2@y tcp.mute [0 tcp.mute{3}] - + tcp.mute [tcp.mute{2}] scale==2 2@x 1@x
```

**tcp.phase** (conditional visibility based on height):
```
h<phaseHide_h{0} [0] + * scale [3 -24 16 20] [tcp.solo meter_sec{3}]
```

---

## Key Implementation Details

### 1. Variable Context Building

Variables are processed in order from the rtconfig. Each SET statement that doesn't contain a dot (`.`) is treated as a variable definition:

```lua
-- In rtconfig_converter.lua
if is_variable_definition(item.element) then
  process_variable_definition(item, eval_context)
end
```

Variables can be scalars or arrays, and are stored in the evaluation context for later expression resolution.

### 2. Bracket Parsing with @position

The `@position` notation inside brackets required special handling:

```lua
-- In expression_eval.lua parse_bracket()
local num_part, at_pos = token:match("^([%-%.%d]+)@([%w]+)$")
if num_part and at_pos then
  local pos_idx = POSITION_MAP[at_pos]
  while #values < pos_idx - 1 do
    values[#values + 1] = 0  -- Pad with zeros
  end
  values[pos_idx] = num_val
end
```

### 3. Scalar Broadcast (Multiplication Only)

When multiplying a scalar by an array, the scalar is broadcast:

```lua
-- Only for multiplication
if op == "*" then
  if #a == 1 and #b > 1 then
    return scale_array(b, a[1])
  end
end
```

This was incorrectly applied to all operators initially, causing bugs.

### 4. Negative Coordinate Handling

Elements with negative x/y but no attachments are treated as right/bottom-relative:

```lua
-- In coordinate.lua compute_rect()
if x < 0 and ls == 0 and rs == 0 then
  x = parent_w + x  -- Right-relative
end
if w < 0 and rs == 0 then
  w = parent_w - x + w  -- Stretch from edge
end
```

---

## Bugs Fixed

### 1. Ternary Operator Not Evaluating
**Symptom**: `tcp.solo` expression failed to evaluate
**Cause**: Comparison conditional check (`scale==1`) was dead code - identifier handling returned value before checking for comparison operator
**Fix**: Moved comparison detection before simple value return in identifier handler

### 2. Wrong Coordinates (Multiplied by 300)
**Symptom**: Coordinates like `(-7500, 900)` instead of `(-25, 3)`
**Cause**: `[meter_sec]` with array variable only returned first element wrapped in single-element array
**Fix**: Return full array when single-token bracket contains array variable

### 3. Addition Producing Multiplication Results
**Symptom**: `+ [20 0 280 90] [280]` produced wrong values
**Cause**: `scale_array` (scalar broadcast) was applied to ALL operators, not just `*`
**Fix**: Added `if op == "*"` check before scalar broadcast

### 4. @position Not Parsed in Brackets
**Symptom**: `[-4@x 21 20 0 0 1]` parsed as `[0, 21, 20, 0, 0, 1]`
**Cause**: Bracket parser didn't handle @position notation
**Fix**: Added @position parsing to `parse_bracket()` function

### 5. Elements on Wrong Side of Canvas
**Symptom**: Elements with negative x appeared on left edge
**Cause**: Negative coordinates weren't being interpreted as right-relative
**Fix**: Added negative coordinate handling in `compute_rect()`

---

## Current Limitations

### 1. Conditionally Hidden Elements
Many elements evaluate to `[0]` (hidden) based on default context values:
- `hide_pan_group=0` hides pan controls
- `hide_fx_group=0` hides FX controls
- Height thresholds hide elements when TCP is small

**Workaround**: Adjust DEFAULT_CONTEXT values or use "Force Visible" checkbox

### 2. Theme-Specific Variable Patterns
Some themes use unique variable naming/computation patterns that may not be captured by default context values.

### 3. Macro Expansion
Macros are parsed but not fully expanded - we extract SET statements from macro bodies directly.

---

## Default Context Values

```lua
DEFAULT_CONTEXT = {
  w = 300,            -- Parent width
  h = 90,             -- Parent height
  scale = 1.0,        -- DPI scale

  -- Common computed values
  tcp_padding = 7,
  meter_sec = 50,
  main_sec = 200,
  element_h = 20,

  -- Conditional flags (0 = show element)
  is_solo_flipped = 0,
  hide_mute_group = 0,
  hide_fx_group = 0,
  hide_pan_group = 0,

  -- Track state
  recarm = 0,
  track_selected = 1,
  folderstate = 0,
}
```

---

## Next Steps

### Short Term
- [ ] Add context variable controls in UI
- [ ] Show element tooltips with raw expression
- [ ] Improve element inspector with coordinate breakdown

### Medium Term
- [ ] Support editing element coordinates
- [ ] Live preview of coordinate changes
- [ ] Export modified rtconfig

### Long Term
- [ ] Full macro expansion
- [ ] Multiple theme comparison
- [ ] Layout validation/warnings

---

## Testing

Current test coverage:
- 80/80 computed expressions evaluate successfully
- 661 variables processed from test theme
- 43 visual elements loaded to canvas

Test theme: Complex production theme with TCP, MCP, and transport layouts.

---

## References

- REAPER rtconfig documentation: https://www.reaper.fm/sdk/walter/walter.php
- WALTER coordinate system explanation in `helpers/` folder
- ReaImGui demo for UI patterns

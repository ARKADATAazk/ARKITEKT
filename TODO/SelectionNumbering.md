# Selection Numbering (Global Module)

> **Status:** Proposed
> **Scope:** arkitekt/gui/widgets/ or arkitekt/gui/interaction/
> **Apps:** ItemPicker, potentially TemplateBrowser, any grid-based picker

---

## Concept

When multi-selecting items in a grid, display numbers on each tile showing selection order (1, 2, 3...). This order is preserved for batch operations like sequential insert.

## Features

### Core
- **Selection order tracking**: First selected = 1, second = 2, etc.
- **Visual number badge**: Small numbered badge on selected tiles
- **Order preservation**: Batch operations respect this order

### Advanced
- **Randomize order**: Shuffle the numbers (for creative variation)
- **Reverse order**: Quick reverse of selection order
- **Reorder by drag**: Drag numbers to reorder without re-selecting
- **Clear and restart**: Reset numbering from current hover position

## Visual Design

```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│ [1]         │  │ [3]         │  │             │
│   Item A    │  │   Item C    │  │   Item X    │
│             │  │             │  │ (not sel)   │
└─────────────┘  └─────────────┘  └─────────────┘
┌─────────────┐  ┌─────────────┐
│ [2]         │  │ [4]         │
│   Item B    │  │   Item D    │
└─────────────┘  └─────────────┘
```

Badge position: Top-left corner, small circular badge with number.

## API Sketch

```lua
-- In grid selection module
local Selection = require('arkitekt.gui.interaction.selection')

-- Selection now tracks order
selection:add(key)           -- Adds with next order number
selection:remove(key)        -- Removes, others keep their numbers
selection:get_order(key)     -- Returns order number (1-based) or nil
selection:ordered_keys()     -- Returns keys in selection order
selection:randomize_order()  -- Shuffle order numbers
selection:reverse_order()    -- Reverse order
```

## Use Cases

1. **Sequential insert**: Insert drums in order: kick, snare, hat, kick...
2. **Creative randomization**: Select items, randomize, insert for variation
3. **Layered sounds**: Stack items in specific order at same position
4. **Pattern building**: Build rhythmic patterns with precise ordering

## Implementation Notes

- Selection module already exists in arkitekt
- Need to extend with order tracking (simple array or order map)
- Badge rendering in tile renderer (check selection order, draw if present)
- Randomize could be a keyboard shortcut (R while items selected?)

## Open Questions

- Should randomization show animation of numbers shuffling?
- Persist order across filter changes? (probably not - gets confusing)
- Maximum number to display? (99? 999?)

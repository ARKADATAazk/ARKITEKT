# Grid Pinned Slots Feature

## Overview

Add support for "pinned" items at the start and/or end of a grid that:
- Render like regular tiles (same dimensions, same rect passed to render callback)
- Are visually part of the grid flow
- Cannot be reordered, selected, or sorted
- Are excluded from all item-based behaviors

## Use Cases

1. **Pinned Start** - "Result" tile showing combined output, summary tile, "All Items" option
2. **Pinned End** - "Add New..." button (like browser tab + button), "Load More" tile

## Proposed API

```lua
Ark.Grid(ctx, {
  id = 'my_grid',
  items = my_items,

  -- Optional: Pinned slot at start (index 0, before all items)
  pinned_start = {
    -- Receives same rect as regular items
    render = function(ctx, rect, state)
      -- state = { hover = bool }
      draw_my_pinned_tile(ctx, rect, state)
    end,

    -- Optional click handler
    on_click = function()
      open_result_modal()
    end,

    -- Optional: custom key for internal state (default: '__pinned_start')
    key = '__result',
  },

  -- Optional: Pinned slot at end (after all items)
  pinned_end = {
    render = function(ctx, rect, state)
      draw_add_button(ctx, rect, state)
    end,
    on_click = function()
      add_new_item()
    end,
    key = '__add_new',
  },

  -- Regular item config...
  render_item = function(ctx, rect, item, state) ... end,
  behaviors = { ... },
})
```

## Implementation Notes

### What pinned slots should receive:
- Same `rect` (x1, y1, x2, y2) as regular items
- Same tile dimensions (width from min_col_w, height from fixed_tile_h)
- `state.hover` for hover detection
- Participate in grid layout flow (take up a cell)

### What pinned slots should NOT do:
- Not included in `items` iteration
- Not passed to `key()` function
- Not included in selection state
- Not draggable / reorderable
- Not passed to any behaviors (delete, space, reorder, etc.)
- Not counted in grid statistics
- Not affected by sorting

### Internal handling:

```lua
-- In grid draw loop:
local total_cells = #items + (opts.pinned_start and 1 or 0) + (opts.pinned_end and 1 or 0)

-- Layout:
-- Cell 0: pinned_start (if exists)
-- Cells 1..N: regular items
-- Cell N+1: pinned_end (if exists)

-- Render pinned_start first
if opts.pinned_start then
  local rect = calculate_cell_rect(0, cols, ...)
  local hovered = is_rect_hovered(rect)
  opts.pinned_start.render(ctx, rect, { hover = hovered })

  if hovered and ImGui.IsMouseClicked(ctx, 0) then
    if opts.pinned_start.on_click then
      opts.pinned_start.on_click()
    end
  end
end

-- Then render regular items starting at cell offset
for i, item in ipairs(items) do
  local cell_index = i + (opts.pinned_start and 1 or 0)
  local rect = calculate_cell_rect(cell_index, cols, ...)
  -- ... normal item rendering
end

-- Render pinned_end last
if opts.pinned_end then
  local cell_index = #items + (opts.pinned_start and 1 or 0)
  local rect = calculate_cell_rect(cell_index, cols, ...)
  -- ... same pattern as pinned_start
end
```

### Drag/reorder handling:

```lua
-- In reorder logic:
-- Pinned slots create "dead zones" that items cannot be dropped into

-- If pinned_start exists:
--   Drop index 0 is invalid, minimum drop index is 1
-- If pinned_end exists:
--   Drop index > #items is invalid, maximum drop index is #items

-- Visual feedback:
--   When dragging near pinned slots, show "blocked" cursor or no drop indicator
```

## Edge Cases

1. **Empty grid with pinned slots** - Should still show pinned_start and/or pinned_end
2. **Single column** - Pinned slots should still work, just stacked vertically
3. **Responsive resize** - Pinned slots reflow with grid like any other cell
4. **Keyboard navigation** - Skip pinned slots when using arrow keys? Or allow focus but no action?

## Migration

Existing grids are unaffected - `pinned_start` and `pinned_end` are optional.

## Priority

Medium - Nice to have for cleaner UI patterns, but workarounds exist (render before/after grid).

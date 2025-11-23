# Media Grid Component

A reusable grid component for browsing and interacting with media items (audio/MIDI) in REAPER.

## Features

- **Waveform Visualization** - Display audio waveforms in tiles
- **MIDI Piano Roll** - Display MIDI notes in tiles
- **Multi-Select** - Ctrl+Click, Shift+Click, Marquee selection
- **Drag & Drop** - Multi-item drag with visual preview
- **Preview** - Spacebar to preview items
- **Disabled State** - Right-click to toggle, visual feedback
- **Cascade Animations** - Smooth tile spawn/destroy effects
- **TileFX Integration** - Gradients, specular, shadows, marching ants
- **Caching** - LRU cache for visualization performance
- **Async Jobs** - Non-blocking waveform/MIDI generation

## Architecture

```
media_grid/
├── init.lua              # Main module
├── renderers/
│   └── base.lua          # Base tile renderer utilities
└── README.md             # Documentation
```

## Components

### Base Renderer (`renderers/base.lua`)

Provides shared utilities for rendering media tiles:

- `calculate_cascade_factor(rect, overlay_alpha, config)` - Cascade animation
- `truncate_text(ctx, text, max_width)` - Text truncation with ellipsis
- `get_dark_waveform_color(base_color, config)` - Waveform color derivation
- `render_header_bar(...)` - Colored header bar
- `render_placeholder(...)` - Loading spinner
- `render_tile_text(...)` - Text with badge (e.g., "2/5")

## Usage Example

```lua
local MediaGrid = require('arkitekt.gui.widgets.media_grid')
local BaseRenderer = MediaGrid.renderers.base

-- In your tile renderer
function render_tile(ctx, rect, item_data, tile_state)
  local dl = ImGui.GetWindowDrawList(ctx)

  -- Use base renderer utilities
  local cascade_factor = BaseRenderer.calculate_cascade_factor(rect, overlay_alpha, config)

  BaseRenderer.render_header_bar(dl, x1, y1, x2, header_height, base_color, alpha, config)

  BaseRenderer.render_tile_text(ctx, dl, x1, y1, x2, header_height,
    item_name, index, total, base_color, text_alpha, config)

  -- Custom visualization
  if waveform then
    -- Render waveform
  end
end
```

## Configuration

The base renderer expects a configuration object with:

```lua
config = {
  TILE = {
    ROUNDING = 0,  -- Border radius
  },

  cascade = {
    stagger_delay = 0.03,  -- Delay between tile animations
  },

  header = {
    saturation_factor = 1.1,
    brightness_factor = 0.7,
    alpha = 0xDD,
    min_height = 22,
    text_shadow = hexrgb("#00000099"),
  },

  badge = {
    padding_x = 6,
    padding_y = 3,
    margin = 6,
    rounding = 4,
    bg = hexrgb("#14181C"),
    border_alpha = 0x33,
  },

  text = {
    primary_color = hexrgb("#FFFFFF"),
    padding_left = 6,
    margin_right = 6,
  },

  waveform = {
    saturation = 0.3,
    brightness = 0.15,
    line_alpha = 0.8,
  },

  responsive = {
    hide_text_below = 35,   -- Hide text at small heights
    hide_badge_below = 25,  -- Hide badge at small heights
  },
}
```

## Integration with Grid System

Works seamlessly with `arkitekt.gui.widgets.grid.core`:

```lua
local Grid = require('arkitekt.gui.widgets.grid.core')

local grid = Grid.new({
  id = "media_items",
  gap = 4,
  min_col_w = function() return 120 end,
  fixed_tile_h = 140,

  get_items = function()
    return media_items
  end,

  key = function(item) return item.key end,

  render_tile = function(ctx, rect, item, tile_state)
    -- Use BaseRenderer utilities
    -- Render waveform/MIDI
  end,
})

-- Grid behaviors
grid.behaviors = {
  drag_start = function(keys) end,
  right_click = function(key, selected) end,
  wheel_adjust = function(keys, delta) end,
  delete = function(keys) end,
  play = function(keys) end,
  on_select = function(keys) end,
}
```

## Used By

- **ItemPicker** (`scripts/ItemPicker/`) - Media item browser with waveforms/MIDI
- *Future scripts can use this component for media browsing*

## Pattern

This component follows the **reusable widget pattern** established by RegionPlaylist:

1. **Extraction** - Common functionality extracted to arkitekt
2. **Configuration** - Highly configurable through config objects
3. **Composition** - Compose with Grid, TileFX, animations
4. **Documentation** - Clear examples and usage patterns

## See Also

- `arkitekt.gui.widgets.grid.core` - Grid layout system
- `arkitekt.gui.fx.tile_fx` - Tile visual effects
- `arkitekt.gui.fx.marching_ants` - Selection animation
- `scripts/ItemPicker/` - Reference implementation

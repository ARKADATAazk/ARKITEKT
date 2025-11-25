# GUI Directory Reorganization Plan

**Status**: Planned
**Priority**: Medium
**Complexity**: Medium (many file moves + require updates)

## Problem

Current `gui/` structure has:
- Overlap between `fx/interactions/dnd.lua` and `systems/drag_drop.lua`
- Confusing `draw.lua` file alongside `draw/` folder
- Mixed concerns in `systems/` (layout + interaction + utilities)
- Unclear where new code should go

## Current Structure

```
gui/
├── draw.lua                          # Single file (primitives)
├── draw/
│   └── pattern.lua                   # Background patterns
├── fx/
│   ├── animation/
│   │   ├── easing.lua
│   │   ├── lifecycle.lua
│   │   └── tracks.lua
│   └── interactions/
│       ├── dnd.lua                   # OVERLAPS with systems/drag_drop.lua
│       └── marching_ants.lua
├── rendering/
│   ├── effects.lua
│   ├── shapes.lua
│   └── tile/
│       ├── animator.lua
│       ├── defaults.lua
│       └── renderer.lua
├── systems/
│   ├── drag_drop.lua                 # OVERLAPS with fx/interactions/dnd.lua
│   ├── height_stabilizer.lua
│   ├── mouse_util.lua
│   ├── reorder.lua
│   ├── responsive_grid.lua
│   └── selection.lua
├── utils/
│   └── interaction_blocking.lua
├── style/
│   └── ...
└── widgets/
    └── ...
```

## Target Structure (Option A: By Concern Type)

```
gui/
├── draw/                             # LOW-LEVEL DRAWING PRIMITIVES
│   ├── primitives.lua                # (was draw.lua)
│   ├── patterns.lua                  # (was draw/pattern.lua, pluralized)
│   ├── shapes.lua                    # (from rendering/)
│   └── effects.lua                   # (from rendering/)
│
├── animation/                        # ANIMATION SYSTEM
│   ├── easing.lua                    # (from fx/animation/)
│   ├── tracks.lua                    # (from fx/animation/)
│   ├── lifecycle.lua                 # (from fx/animation/)
│   └── tile_animator.lua             # (from rendering/tile/animator.lua)
│
├── interaction/                      # USER INTERACTION
│   ├── selection.lua                 # (from systems/)
│   ├── marching_ants.lua             # (from fx/interactions/)
│   ├── drag_drop.lua                 # MERGED from systems/ + fx/interactions/
│   ├── reorder.lua                   # (from systems/)
│   └── blocking.lua                  # (from utils/interaction_blocking.lua)
│
├── layout/                           # LAYOUT CALCULATIONS
│   ├── responsive.lua                # (from systems/responsive_grid.lua)
│   ├── height_stabilizer.lua         # (from systems/)
│   └── mouse_util.lua                # (from systems/)
│
├── renderers/                        # COMPONENT-SPECIFIC RENDERERS
│   └── tile/
│       ├── renderer.lua              # (from rendering/tile/)
│       └── defaults.lua              # (from rendering/tile/)
│
├── style/                            # (unchanged)
│   └── ...
│
└── widgets/                          # (unchanged)
    └── ...
```

## Migration Map

| Current Path | New Path | Action |
|--------------|----------|--------|
| `gui/draw.lua` | `gui/draw/primitives.lua` | Move + rename |
| `gui/draw/pattern.lua` | `gui/draw/patterns.lua` | Rename (pluralize) |
| `gui/rendering/shapes.lua` | `gui/draw/shapes.lua` | Move |
| `gui/rendering/effects.lua` | `gui/draw/effects.lua` | Move |
| `gui/fx/animation/easing.lua` | `gui/animation/easing.lua` | Move |
| `gui/fx/animation/tracks.lua` | `gui/animation/tracks.lua` | Move |
| `gui/fx/animation/lifecycle.lua` | `gui/animation/lifecycle.lua` | Move |
| `gui/rendering/tile/animator.lua` | `gui/animation/tile_animator.lua` | Move + rename |
| `gui/systems/selection.lua` | `gui/interaction/selection.lua` | Move |
| `gui/fx/interactions/marching_ants.lua` | `gui/interaction/marching_ants.lua` | Move |
| `gui/systems/drag_drop.lua` | `gui/interaction/drag_drop.lua` | **MERGE** |
| `gui/fx/interactions/dnd.lua` | (merged above) | **MERGE** |
| `gui/systems/reorder.lua` | `gui/interaction/reorder.lua` | Move |
| `gui/utils/interaction_blocking.lua` | `gui/interaction/blocking.lua` | Move + rename |
| `gui/systems/responsive_grid.lua` | `gui/layout/responsive.lua` | Move + rename |
| `gui/systems/height_stabilizer.lua` | `gui/layout/height_stabilizer.lua` | Move |
| `gui/systems/mouse_util.lua` | `gui/layout/mouse_util.lua` | Move |
| `gui/rendering/tile/renderer.lua` | `gui/renderers/tile/renderer.lua` | Move |
| `gui/rendering/tile/defaults.lua` | `gui/renderers/tile/defaults.lua` | Move |

## Folders to Delete (after moves)

- `gui/fx/` (empty)
- `gui/rendering/` (empty)
- `gui/systems/` (empty)
- `gui/utils/` (empty)

## Step-by-Step Instructions

### Phase 1: Create New Directory Structure

```bash
cd ARKITEKT/arkitekt/gui

mkdir -p animation
mkdir -p interaction
mkdir -p layout
mkdir -p renderers/tile
```

### Phase 2: Move Files

```bash
# draw/ folder
mv draw.lua draw/primitives.lua
mv draw/pattern.lua draw/patterns.lua
mv rendering/shapes.lua draw/
mv rendering/effects.lua draw/

# animation/ folder
mv fx/animation/easing.lua animation/
mv fx/animation/tracks.lua animation/
mv fx/animation/lifecycle.lua animation/
mv rendering/tile/animator.lua animation/tile_animator.lua

# interaction/ folder
mv systems/selection.lua interaction/
mv fx/interactions/marching_ants.lua interaction/
mv systems/reorder.lua interaction/
mv utils/interaction_blocking.lua interaction/blocking.lua
# NOTE: drag_drop.lua requires manual merge (see below)

# layout/ folder
mv systems/responsive_grid.lua layout/responsive.lua
mv systems/height_stabilizer.lua layout/
mv systems/mouse_util.lua layout/

# renderers/ folder
mv rendering/tile/renderer.lua renderers/tile/
mv rendering/tile/defaults.lua renderers/tile/
```

### Phase 3: Merge drag_drop Files

Compare and merge:
- `gui/systems/drag_drop.lua`
- `gui/fx/interactions/dnd.lua`

Into single file: `gui/interaction/drag_drop.lua`

### Phase 4: Update All Require Paths

Search and replace in all `.lua` files:

| Old Require | New Require |
|-------------|-------------|
| `arkitekt.gui.draw` | `arkitekt.gui.draw.primitives` |
| `arkitekt.gui.draw.pattern` | `arkitekt.gui.draw.patterns` |
| `arkitekt.gui.rendering.shapes` | `arkitekt.gui.draw.shapes` |
| `arkitekt.gui.rendering.effects` | `arkitekt.gui.draw.effects` |
| `arkitekt.gui.fx.animation.easing` | `arkitekt.gui.animation.easing` |
| `arkitekt.gui.fx.animation.tracks` | `arkitekt.gui.animation.tracks` |
| `arkitekt.gui.fx.animation.lifecycle` | `arkitekt.gui.animation.lifecycle` |
| `arkitekt.gui.rendering.tile.animator` | `arkitekt.gui.animation.tile_animator` |
| `arkitekt.gui.systems.selection` | `arkitekt.gui.interaction.selection` |
| `arkitekt.gui.fx.interactions.marching_ants` | `arkitekt.gui.interaction.marching_ants` |
| `arkitekt.gui.systems.drag_drop` | `arkitekt.gui.interaction.drag_drop` |
| `arkitekt.gui.fx.interactions.dnd` | `arkitekt.gui.interaction.drag_drop` |
| `arkitekt.gui.systems.reorder` | `arkitekt.gui.interaction.reorder` |
| `arkitekt.gui.utils.interaction_blocking` | `arkitekt.gui.interaction.blocking` |
| `arkitekt.gui.systems.responsive_grid` | `arkitekt.gui.layout.responsive` |
| `arkitekt.gui.systems.height_stabilizer` | `arkitekt.gui.layout.height_stabilizer` |
| `arkitekt.gui.systems.mouse_util` | `arkitekt.gui.layout.mouse_util` |
| `arkitekt.gui.rendering.tile.renderer` | `arkitekt.gui.renderers.tile.renderer` |
| `arkitekt.gui.rendering.tile.defaults` | `arkitekt.gui.renderers.tile.defaults` |

### Phase 5: Clean Up Empty Folders

```bash
rm -rf fx/
rm -rf rendering/
rm -rf systems/
rm -rf utils/
```

### Phase 6: Update Documentation

- Update `PROJECT_STRUCTURE.txt`
- Update `arkitekt_FLOW.md`
- Update `DEPENDENCIES.md`
- Update `index.xml` (ReaPack manifest)

## Special Attention: drag_drop Merge

The two drag_drop files need manual review:

**`systems/drag_drop.lua`**: Likely the main implementation
**`fx/interactions/dnd.lua`**: Likely visual indicators or older code

Review both files to determine:
1. Which is the canonical implementation?
2. Is one a subset of the other?
3. Can they be cleanly merged?

## Files NOT Moving

These stay where they are:
- `gui/style/` - theming, unchanged
- `gui/widgets/` - widget implementations, unchanged
- `scripts/RegionPlaylist/core/tile_utilities.lua` - domain-specific

## Benefits After Reorganization

1. **Clear mental model** - know instantly where code belongs
2. **No overlaps** - single source of truth for each concern
3. **Scalable** - easy to add new animation/interaction/layout code
4. **Better discoverability** - `animation/` is clearer than `fx/`

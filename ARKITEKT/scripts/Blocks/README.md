# Blocks

**Modular component platform for REAPER**

## Overview

Blocks is a dockable host for modular UI components that combine multiple scripts into a single unified interface. One defer loop hosts multiple "blocks" (components) that can run standalone or be composed together.

**Status:** Early prototype - testing component mode pattern

## Architecture

```
Blocks (host) - Single defer loop
│
├── Block A (Macro Controls) - No defer, just draws
├── Block B (Drum Rack) - No defer, just draws
├── Block C (Future component) - No defer, just draws
└── ...
```

Key concept: **Single defer loop hosts multiple components**

## Current Built-in Blocks

### Macro Controls
- **8 rotary knobs** with custom widget design
- Visual value display and arc indicators
- Learn mode for parameter assignment (mockup)
- Assignment labels showing mapped parameters
- Double-click to reset values
- Drag to adjust with visual feedback

### Drum Rack
- **16-pad grid** (4x4) with colored pads
- MIDI note assignment per pad
- Visual sample indicator
- Pad selection and interaction
- Right-click context menu
- Volume/pan controls for selected pad
- Kit save/load interface (mockup)

## Project Structure

```
scripts/Blocks/
├── ARK_Blocks.lua             # Entry point (host)
├── app/
│   └── state.lua              # State management
├── config/
│   └── defaults.lua           # Configuration constants
├── ui/
│   ├── init.lua               # Main UI with tabs
│   ├── views/
│   │   ├── macro_controls.lua # Macro controls block
│   │   └── drum_rack.lua      # Drum rack block
│   └── widgets/
│       └── knob.lua           # Custom rotary knob widget
└── README.md                  # This file
```

## Running

1. Load `ARK_Blocks.lua` in REAPER
2. Explore the different tabs
3. Interact with knobs and pads

## Component Mode Pattern (WIP)

The goal is to enable blocks to run either:
- **Standalone**: Block runs its own defer loop
- **Hosted**: Block returns a drawable handle, Blocks host calls draw()

```lua
-- Component detects hosting via global flag
local mode = _G.ARKITEKT_BLOCKS_HOST and "component" or "standalone"

-- In component mode, Shell.run() returns a drawable handle
-- In standalone mode, Shell.run() runs the defer loop
```

## Roadmap

### Phase 1: Component Mode
- [ ] Shell component mode detection
- [ ] Host loads components via dofile()
- [ ] Components return drawable handles
- [ ] Single defer loop test

### Phase 2: Block Discovery
- [ ] Scan blocks/ directory for components
- [ ] Dynamic loading/unloading
- [ ] Block picker UI

### Phase 3: Layout Management
- [ ] Vertical/horizontal splits
- [ ] Block resize handles
- [ ] Save/load layouts

### Phase 4: Real Block Implementations
- [ ] Macro Controls with REAPER FX integration
- [ ] Drum Rack with MIDI/sample integration
- [ ] Browser integration
- [ ] More community blocks

## Technical Notes

### Custom Widgets
The rotary knob widget demonstrates creating new widget types:
- Uses ImGui draw list for custom rendering
- Arc rendering with path stroke
- Mouse drag handling with sensitivity
- State persistence patterns

## Credits

**Built with:**
- ARKITEKT framework - UI widgets, theming, shell
- ReaImGui - ImGui binding for REAPER

## License

GPL-3.0 (consistent with ARKITEKT framework)

# Production Panel (Prototype v0.1)

**Unified workflow hub for REAPER production**

## Overview

Production Panel is a comprehensive production tool that brings Ableton Live-style workflow to REAPER with modern, polished UX. This prototype demonstrates the core concepts with mockup data.

**Status:** Early prototype - UI/UX demonstration with mock data

## Features (Current Prototype)

### ✅ Macro Controls
- **8 rotary knobs** with custom widget design
- Visual value display and arc indicators
- Learn mode for parameter assignment (mockup)
- Assignment labels showing mapped parameters
- Double-click to reset values
- Drag to adjust with visual feedback

### ✅ Drum Rack
- **16-pad grid** (4x4) with colored pads
- MIDI note assignment per pad
- Visual sample indicator
- Pad selection and interaction
- Right-click context menu
- Volume/pan controls for selected pad
- Kit save/load interface (mockup)

### ✅ Unified Interface
- **Tabbed layout** for easy navigation:
  - 🎛️ Macro Controls
  - 🥁 Drum Rack
  - 📁 Browser (placeholder)
  - ⚙️ Settings (placeholder)
- Clean, themed UI using ARKITEKT widgets
- Consistent color scheme and spacing

## What's New/Creative

### Custom Knob Widget
**New widget type** created for this prototype:
- Rotary control with arc visualization
- Value display centered in knob
- Customizable colors and sizing
- Smooth drag interaction
- Position indicator dot
- Located: `ui/widgets/knob.lua`

### Mock Data Approach
All data is currently mocked to focus on UI/UX:
- Macro assignments show example FX parameters
- Drum pads have example sample names and colors
- No actual REAPER API integration yet

## Project Structure

```
scripts/ProductionPanel/
├── ARK_ProductionPanel.lua    # Entry point
├── app/
│   └── state.lua              # State management
├── defs/
│   └── defaults.lua           # Configuration constants
├── ui/
│   ├── init.lua               # Main UI with tabs
│   ├── views/
│   │   ├── macro_controls.lua # Macro controls view
│   │   └── drum_rack.lua      # Drum rack view
│   └── widgets/
│       └── knob.lua           # Custom rotary knob widget
└── README.md                  # This file
```

## Running the Prototype

1. Load `ARK_ProductionPanel.lua` in REAPER
2. Explore the different tabs
3. Interact with knobs and pads
4. Test UI/UX patterns

## Next Steps (Implementation Roadmap)

### Phase 1: REAPER Integration
- [ ] FX container parameter access API
- [ ] Learn mode implementation (touch detection)
- [ ] Macro → parameter mapping system
- [ ] Save/load macro mappings with container

### Phase 2: Drum Rack Integration
- [ ] MIDI routing to pads
- [ ] Sample loading from file system
- [ ] Per-pad FX chain management
- [ ] Trigger samples on pad click
- [ ] Velocity sensitivity

### Phase 3: Browser Integration
- [ ] Integrate ItemPicker for sample browsing
- [ ] FX chain browser (TemplateBrowser patterns)
- [ ] Track template browser
- [ ] Drag-and-drop to pads/containers
- [ ] Waveform previews

### Phase 4: Advanced Features
- [ ] 16 macro mode (expanded layout)
- [ ] Parallel FX routing in containers
- [ ] Pattern sequencer for drums
- [ ] MIDI CC learning for macros
- [ ] Preset system for entire panel state

## Why This Approach?

### Problems Solved

**Existing tools (FX Devices, LBX Stripper):**
- ❌ Poor UX ("looks like shit")
- ❌ Abandoned or barely maintained
- ❌ Requires manual layout creation
- ❌ Scattered, inconsistent interfaces

**Production Panel:**
- ✅ Modern, polished UI
- ✅ Unified workflow hub
- ✅ Zero-config where possible
- ✅ Actively developed with ARKITEKT
- ✅ Clean separation of concerns

### Target Users

- **DAW switchers** who want Ableton-style workflow in REAPER
- **Producers** who need quick macro control without setup
- **Sound designers** who want integrated sample/FX management
- **Anyone** frustrated with REAPER's scattered FX control options

## Feedback Welcome

This is an early prototype focused on UI/UX validation. Testing:

1. **Visual design** - Does it look professional?
2. **Interaction patterns** - Do knobs/pads feel good?
3. **Layout/spacing** - Is information density right?
4. **Tab organization** - Logical grouping?

## Technical Notes

### Custom Widgets
The rotary knob widget demonstrates creating new widget types:
- Uses ImGui draw list for custom rendering
- Arc rendering with path stroke
- Mouse drag handling with sensitivity
- State persistence patterns

### Mock Data Pattern
```lua
-- Mock data allows UI iteration without API complexity
local mock_macros = {
  { name = "Cutoff", value = 0.65, assigned = "Filter - Cutoff" },
  { name = "Resonance", value = 0.42, assigned = "Filter - Q" },
  -- ...
}
```

Later replaced with:
```lua
-- Real data from REAPER FX containers
local macros = FXContainer.get_parameters()
```

## Credits

**Concept inspired by:**
- Ableton Live - Effect Rack & Drum Rack workflow
- BryanChi - FX Devices (proved demand for better FX control)
- LBX Stripper - Channel strip concepts
- Guillaume Tiger - Original request for macro controls

**Built with:**
- ARKITEKT framework - UI widgets, theming, shell
- ReaImGui - ImGui binding for REAPER

## License

GPL-3.0 (consistent with ARKITEKT framework)

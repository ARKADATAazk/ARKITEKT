# Drum Rack: Feature Roadmap

## Vision

A modern, performant drum rack for REAPER that combines:
- **MPL RS5K Manager's** power and REAPER integration
- **Suzuki ReaDrum Machine's** clean container approach
- **Sitala's** intuitive UX and visual clarity
- **ARKITEKT's** responsive grid and tile rendering

---

## Phase 0: Foundation (Current)
*UI Prototype - No REAPER Integration*

- [x] Basic pad grid using `Ark.Grid`
- [x] Pad renderer with TileFX styling
- [x] Mock data for 16 pads
- [x] Selection and hover states
- [x] Volume bar visualization
- [x] MIDI note badge display
- [ ] Context menu (load/clear sample)
- [ ] Pad color customization

---

## Phase 1: RS5K Backend Integration
*Connect UI to actual REAPER tracks/FX*

### 1.1 Track Structure Management
- [ ] Create parent "Drum Rack" track
- [ ] Create child track per pad
- [ ] Insert RS5K on each child
- [ ] Configure MIDI routing (parent → children)
- [ ] Set RS5K note filter per pad

### 1.2 State Synchronization
- [ ] Read existing drum rack structure on load
- [ ] Detect RS5K instances and their settings
- [ ] Map track → pad in UI
- [ ] Handle external changes (user edits in mixer)

### 1.3 Sample Loading
- [ ] Drag-drop from Media Explorer
- [ ] Drag-drop from ItemPicker integration
- [ ] Load sample into RS5K (`FILE0` parameter)
- [ ] Read sample name/path from RS5K
- [ ] Waveform thumbnail generation

### 1.4 Basic Controls
- [ ] Volume (track volume or RS5K gain)
- [ ] Pan (track pan)
- [ ] Pitch (RS5K pitch parameter)
- [ ] "Obey note-offs" toggle

---

## Phase 2: Essential Features
*Match MPL/ReaDrum feature parity*

### 2.1 Pad Operations
- [ ] Clear pad (remove sample, keep RS5K)
- [ ] Delete pad (remove child track)
- [ ] Duplicate pad (copy track + increment note)
- [ ] Swap pads (exchange samples/settings)
- [ ] Rename pad

### 2.2 Visual Improvements
- [ ] Show pitch shift in semitones on pad
- [ ] Multi-line sample names (no truncation)
- [ ] Waveform display on pad
- [ ] Custom pad colors
- [ ] Empty pad drop zone indicator

### 2.3 Quick Controls
- [ ] Attack/Release knobs
- [ ] Filter cutoff (if SK Filter present)
- [ ] Sample start/end
- [ ] Reverse toggle

### 2.4 Preview & Audition
- [ ] Click-to-preview (send MIDI note)
- [ ] Preview through RS5K (with FX)
- [ ] Preview direct (bypass FX)
- [ ] Stop all previews

---

## Phase 3: Advanced Features
*Differentiate from existing solutions*

### 3.1 Choke Groups
- [ ] Choke group assignment UI
- [ ] JSFX choke handler integration
- [ ] Visual indicator for choke relationships
- [ ] Preset choke groups (HH, cymbals)

### 3.2 Velocity Layers
- [ ] Add/remove velocity layers per pad
- [ ] Velocity range editor
- [ ] Visual layer indicator on pad
- [ ] Auto-distribute velocity ranges

### 3.3 Round Robin
- [ ] Add round robin samples
- [ ] Probability-based or sequential mode
- [ ] RR indicator on pad
- [ ] Test/cycle through RR samples

### 3.4 Per-Pad Delay (Groove)
- [ ] Sample delay offset (-50ms to +50ms)
- [ ] Groove template import
- [ ] Visual timing offset indicator
- [ ] Global swing amount

---

## Phase 4: Workflow Enhancements
*Power user features*

### 4.1 Kit Management
- [ ] Save kit as track template
- [ ] Load kit from template
- [ ] Kit browser with previews
- [ ] Export kit as folder (samples + template)

### 4.2 Explode to Tracks
- [ ] Ungroup to separate tracks (for mixing)
- [ ] Maintain routing to bus
- [ ] Option to keep or break parent folder

### 4.3 MIDI Learn / Controller Integration
- [ ] Learn pad triggers from MIDI input
- [ ] Configurable note range (C1-D#2, etc.)
- [ ] Match hardware controller layout
- [ ] Pad bank switching (for >16 pads)

### 4.4 Step Sequencer Integration
- [ ] Basic pattern grid
- [ ] Per-step velocity
- [ ] Pattern save/load
- [ ] Sync with REAPER transport

---

## Phase 5: Polish & Performance
*Production-ready quality*

### 5.1 Performance Optimization
- [ ] Lazy state reading (only visible pads)
- [ ] Batch REAPER API calls
- [ ] Minimal UI redraws
- [ ] Background sample scanning

### 5.2 UX Refinements
- [ ] Keyboard shortcuts (copy, paste, delete)
- [ ] Undo/redo support
- [ ] Multi-select pad operations
- [ ] Drag-reorder pads

### 5.3 Visual Polish
- [ ] Animated transitions
- [ ] Playing indicator (when note triggered)
- [ ] Velocity-based visual feedback
- [ ] Theme integration

---

## Non-Goals (Out of Scope)

- Full DAW-inside-DAW (not building Ableton in Lua)
- Complex synthesis (use dedicated synths)
- Time-stretching (use REAPER's native stretch)
- Slice-to-MIDI (separate tool)

---

## Success Metrics

1. **Performance**: No lag with 16 pads, <50ms response
2. **Stability**: No crashes, proper undo support
3. **Discoverability**: New users productive in <5 minutes
4. **Compatibility**: Works with REAPER 6.80+
5. **Integration**: Seamless with ItemPicker, existing workflows

---

## Dependencies

| Dependency | Required For | Status |
|------------|--------------|--------|
| ARKITEKT Ark.Grid | Pad layout | ✅ Available |
| ARKITEKT TileFX | Pad rendering | ✅ Available |
| ItemPicker | Sample browsing | ✅ Available |
| SWS Extension | Some track operations | ⚠️ Optional |
| REAPER 6.80+ | Basic functionality | Required |
| REAPER 7.0+ | FX Containers (optional) | Optional |

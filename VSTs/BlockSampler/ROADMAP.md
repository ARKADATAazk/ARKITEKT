# DrumBlocks + BlockSampler Roadmap

## Vision

**One kit. One track. One instrument. Ableton Drum Rack power in REAPER.**

```
┌─────────────────────────────────────────────────────────┐
│  DrumBlocks (ARKITEKT/Lua)                              │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Visual 16-pad grid (4 banks = 64, 8 banks = 128)│   │
│  │ Sample browser with hot-swap preview            │   │
│  │ Waveform display per pad                        │   │
│  │ Kit presets (save/load entire rack)             │   │
│  │ Per-pad FX routing via REAPER containers        │   │
│  └─────────────────────────────────────────────────┘   │
│                          │                              │
│                          ▼                              │
│  ┌─────────────────────────────────────────────────┐   │
│  │ BlockSampler VST3 (headless audio engine)       │   │
│  │ 128 pads × 4 velocity layers × 13 params each   │   │
│  │ Kill groups, output groups, ADSR, filter        │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

---

## Phase 1: BlockSampler VST (Foundation)

**Goal:** Working VST that DrumBlocks can control.

### 1.1 Core Audio Engine ✅ DONE
- [x] 128 pad sample slots
- [x] 4 velocity layers per pad
- [x] ADSR envelope per pad (juce::ADSR)
- [x] SVF filter per pad (juce::dsp::StateVariableTPTFilter)
- [x] Pitch/tune via playback speed
- [x] Pan per pad
- [x] Kill groups (8 groups)
- [x] One-shot / sustain mode
- [x] Reverse playback

### 1.2 Parameter System ✅ DONE
- [x] 13 params × 128 pads = 1664 automatable parameters
- [x] AudioProcessorValueTreeState for automation
- [x] Parameter IDs: `p{pad}_{param}` (e.g., `p0_volume`)

### 1.3 Output Routing ✅ DONE
- [x] Main stereo bus (all pads)
- [x] 16 group stereo buses
- [x] Output group param per pad

### 1.4 Sample Loading ✅ DONE
- [x] Named config param handler (`P{pad}_L{layer}_SAMPLE`)
- [x] State save/restore (sample paths in XML)
- [x] Chunk-based runtime sample loading via Commands node
- [ ] Async sample loading (don't block audio thread)

### 1.5 Sample Playback ✅ DONE
- [x] Sample start/end points (automatable, 0-1 normalized)
- [x] Round-robin playback (multiple samples per layer, cycles on trigger)
- [x] 15 params × 128 pads = 1920 automatable parameters

### 1.6 TODO: Build & Test
- [ ] Build on Windows (VST3)
- [ ] Build on macOS (VST3 + AU)
- [ ] Test in REAPER
- [ ] Test parameter automation from Lua

---

## Phase 2: DrumBlocks UI (ARKITEKT)

**Goal:** Visual interface that controls BlockSampler.

### 2.1 Pad Grid View
```
┌──────────────────────────────────────────┐
│ [Bank A] [Bank B] [Bank C] [Bank D]      │
│ ┌────┬────┬────┬────┬────┬────┬────┬────┐│
│ │ 01 │ 02 │ 03 │ 04 │ 05 │ 06 │ 07 │ 08 ││
│ │~~~~│~~~~│    │~~~~│    │    │~~~~│    ││ ← Waveform preview
│ ├────┼────┼────┼────┼────┼────┼────┼────┤│
│ │ 09 │ 10 │ 11 │ 12 │ 13 │ 14 │ 15 │ 16 ││
│ │~~~~│    │~~~~│    │    │~~~~│    │    ││
│ └────┴────┴────┴────┴────┴────┴────┴────┘│
└──────────────────────────────────────────┘
```

- [ ] 4×4 or 4×8 pad grid layout
- [ ] Bank switching (A/B/C/D for 64 pads, or 8 banks for 128)
- [ ] Visual velocity feedback on trigger
- [ ] Waveform mini-preview on each pad
- [ ] Drag-drop samples to pads
- [ ] Selected pad highlight

### 2.2 Sample Browser (Hot-Swap)
```
┌─────────────────────────────────────┐
│ 📁 Samples/Drums/Kicks              │
│ ├── kick_808.wav         [▶]       │ ← Preview button
│ ├── kick_acoustic.wav    [▶]       │
│ ├── kick_distorted.wav   [▶]       │
│ └── kick_sub.wav         [▶]       │
│                                     │
│ [Hot-Swap: ON]  Playing in context  │
└─────────────────────────────────────┘
```

- [ ] File browser with folder navigation
- [ ] Sample preview on hover/click (plays with current beat)
- [ ] Hot-swap mode: browse while playing, hear in context
- [ ] Drag from browser to pad
- [ ] Recent samples list
- [ ] Favorites system

### 2.3 Pad Editor Panel
```
┌─────────────────────────────────────┐
│ Pad 01: kick_808.wav                │
│ ┌─────────────────────────────────┐ │
│ │ [Waveform with start/end marks] │ │
│ └─────────────────────────────────┘ │
│                                     │
│ Volume [====----]  Pan [--==--]    │
│ Tune   [--==----]  -2st            │
│                                     │
│ ┌─ADSR─────────────────────────┐   │
│ │ A[=]  D[==]  S[====]  R[==]  │   │
│ └──────────────────────────────┘   │
│                                     │
│ Filter [==========--] 8.2kHz       │
│ Reso   [==----------]              │
│                                     │
│ Kill Group: [HiHats ▼]             │
│ Out Group:  [Kicks ▼]              │
│ [x] One-Shot  [ ] Reverse          │
└─────────────────────────────────────┘
```

- [ ] Waveform display with zoom
- [ ] Sample start/end markers (drag to set)
- [ ] All parameter knobs/sliders
- [ ] Kill group dropdown
- [ ] Output group dropdown
- [ ] Velocity layer tabs (Layer 1/2/3/4)

### 2.4 Kit Presets
```
┌─────────────────────────────────────┐
│ Kit: 808 Classic                    │
│ [Save] [Save As] [Load] [New]       │
│                                     │
│ Recent:                             │
│ • 808 Classic                       │
│ • Acoustic Kit                      │
│ • Lo-Fi Pack                        │
└─────────────────────────────────────┘
```

- [ ] Save kit (all pads, all layers, all params)
- [ ] Load kit (one-click restore)
- [ ] Kit browser with categories
- [ ] Recent kits list
- [ ] Kit format: JSON with relative sample paths

---

## Phase 3: Advanced Features

### 3.1 Per-Pad FX (via REAPER Containers)
```
DrumBlocks auto-creates:
├── BlockSampler (128 pads, 16 group outs)
├── Container: Kicks FX (receives Group 1)
│   ├── EQ (user adds)
│   └── Compressor (user adds)
├── Container: Snares FX (receives Group 2)
│   └── Transient Shaper
└── Main Out
```

- [ ] Auto-create container per output group
- [ ] Visual "Add FX" button per group
- [ ] Show FX chain inline in DrumBlocks UI

### 3.2 Velocity Layers UI
```
┌─────────────────────────────────────┐
│ Pad 01 Velocity Layers              │
│                                     │
│ Layer 4 (96-127): kick_hard.wav     │
│ Layer 3 (64-95):  kick_medium.wav   │
│ Layer 2 (32-63):  kick_soft.wav     │
│ Layer 1 (0-31):   kick_ghost.wav    │
│                                     │
│ [Auto-map folder] [Clear all]       │
└─────────────────────────────────────┘
```

- [ ] Drag samples to specific layers
- [ ] Auto-map folder (sort by name → layers)
- [ ] Adjust velocity thresholds
- [ ] Visual velocity range editor

### 3.3 Round-Robin ✅ DONE
- [x] Multiple samples per layer
- [x] Cycle through on each trigger
- [ ] Random mode option

### 3.4 Sample Analysis
- [ ] Auto-detect pitch (for tune suggestion)
- [ ] Auto-detect transient (for auto-trim)
- [ ] Waveform peak detection for display

### 3.5 Chain Extraction (Ableton-style)
- [ ] Drag pad to new track → creates track with:
  - MIDI item with pad's notes
  - New BlockSampler with just that pad
  - Or RS5K with sample

---

## Phase 4: Polish & Distribution

### 4.1 Performance
- [ ] Profile CPU usage with 128 pads
- [ ] Optimize parameter updates (batch)
- [ ] Lazy waveform rendering

### 4.2 Distribution
- [ ] BlockSampler VST3: GitHub releases
- [ ] DrumBlocks: ReaPack
- [ ] Auto-check for VST on first run
- [ ] One-click install link from DrumBlocks

### 4.3 Documentation
- [ ] User guide with screenshots
- [ ] Video tutorial
- [ ] Example kits

---

## Timeline (Estimated)

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| 1: BlockSampler VST | 1 week | Working headless VST3 |
| 2: DrumBlocks UI | 2-3 weeks | Full pad grid + browser |
| 3: Advanced Features | 2-3 weeks | Per-pad FX, layers, presets |
| 4: Polish | 1 week | Performance, docs, release |
| **Total** | **6-8 weeks** | **Complete drum rack** |

---

## Key Differentiators vs Competitors

| Feature | Sitala | RS5K Mgr | ReaDrum | DrumBlocks |
|---------|--------|----------|---------|------------|
| Pad Count | 16 | 128 | 64 | **128** |
| Hot-Swap | ✅ | ❌ | ❌ | **✅** |
| Velocity Layers | ❌ | ❌ | ❌ | **✅ (4)** |
| Kill Groups | ✅ | ❌ | ❌ | **✅** |
| Per-Pad FX | ❌ | ⚠️ | ✅ | **✅** |
| One Track | ✅ | ❌ | ✅ | **✅** |
| Kit Presets | ✅ | ✅ | ❌ | **✅** |
| Round-Robin | ❌ | ❌ | ❌ | **✅** |
| Sample Preview | ✅ | ❌ | ❌ | **✅** |
| REAPER Integration | VST only | Deep | Deep | **Deep** |
| Architecture | C++ | Globals | Globals | **ARKITEKT** |
| Price | $20 | Free | Free | **Free** |

---

## Success Metrics

1. **Workflow Speed**: Load kit and start playing in < 30 seconds
2. **Hot-Swap**: Change sample and hear result in < 1 second
3. **Stability**: Zero crashes in normal use
4. **CPU**: < 5% with 16 pads playing simultaneously
5. **Adoption**: Become go-to drum solution for REAPER users

# ArkDrums VST Sampler

Professional 16-pad drum sampler built with JUCE, designed for tight integration with REAPER via ARKITEKT's ProductionPanel Lua UI.

## Architecture

**Hybrid Design:**
- **VST Layer (C++ + JUCE):** High-performance audio engine, sample playback, MIDI processing
- **Lua Layer (ReaScript + ImGui):** Advanced UI in REAPER via ProductionPanel

**Why Hybrid?**
- VST handles audio/DSP (where performance matters)
- Lua provides rich REAPER integration (sample browser, preset management, visual feedback)
- Best of both worlds: Pro audio + rapid UI iteration

---

## Features

### Core (MVP - Week 1-3)
- [x] 16 pads, MIDI 36-51 (GM Drum Map)
- [x] WAV/AIFF sample loading per pad
- [x] Basic ADSR envelope
- [x] Volume, Pan, Tune per pad
- [x] Velocity response (linear)

### Advanced (Week 4-6)
- [ ] Velocity layers (2-4 samples per pad)
- [ ] Round-robin (multiple samples per velocity layer)
- [ ] Kill groups (hi-hat choking)
- [ ] One-shot / Loop modes
- [ ] Multi-out routing (16 stereo outs)

### DSP (Week 7-8)
- [ ] Per-pad low-pass filter (cutoff, resonance)
- [ ] Per-pad high-pass filter
- [ ] Time-stretching (preserve pitch)
- [ ] Pitch-shifting (preserve timing)

### Integration (Week 9-10)
- [ ] Lua UI control via REAPER API
- [ ] Preset system (XML)
- [ ] Kit import/export
- [ ] Sample browser integration

---

## Project Structure

```
ArkDrums/
├── Source/
│   ├── PluginProcessor.h/cpp    # JUCE plugin wrapper
│   ├── PluginEditor.h/cpp       # Minimal VST UI (or headless)
│   ├── Engine/
│   │   ├── Sampler.h/cpp        # Main sampler engine
│   │   ├── Pad.h/cpp            # Individual pad (samples, ADSR, settings)
│   │   ├── Voice.h/cpp          # Active voice (playing sample instance)
│   │   └── ADSR.h/cpp           # ADSR envelope generator
│   └── Utils/
│       ├── Constants.h          # Pad count, MIDI mapping, limits
│       └── MidiMapping.h        # MIDI note -> pad index conversion
└── ArkDrums.jucer               # JUCE project file
```

---

## MIDI Mapping

| Pads      | MIDI Notes | GM Drums                           |
|-----------|------------|------------------------------------|
| Pad 1-4   | 36-39      | Kick, Snare, Clap, Hat Closed      |
| Pad 5-8   | 40-43      | Tom Low, Tom Mid, Hat Open, Tom Hi |
| Pad 9-12  | 44-47      | Crash, Ride, Cymbal, Tom           |
| Pad 13-16 | 48-51      | User Assignable                    |

Velocity Layers:
- 0-42: Layer 1 (soft)
- 43-84: Layer 2 (medium)
- 85-127: Layer 3 (hard)

---

## Build Instructions

### Prerequisites
- JUCE 7.x (download from juce.com)
- CMake 3.15+ or Projucer
- C++17 compiler (MSVC 2019+, GCC 9+, Clang 10+)

### Build
```bash
# Option 1: Projucer (GUI)
# Open ArkDrums.jucer in Projucer, generate project, build in IDE

# Option 2: CMake (command-line)
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release

# VST3 output: build/ArkDrums_artefacts/Release/VST3/ArkDrums.vst3
```

### Install
**Windows:** Copy `.vst3` folder to `C:\Program Files\Common Files\VST3\`
**macOS:** Copy `.vst3` to `~/Library/Audio/Plug-Ins/VST3/`
**Linux:** Copy `.vst3` to `~/.vst3/`

---

## Integration with ARKITEKT ProductionPanel

The Lua UI in `scripts/ProductionPanel/` controls the VST via REAPER API:

```lua
-- Load ArkDrums on selected track
local track = reaper.GetSelectedTrack(0, 0)
local fx_idx = reaper.TrackFX_AddByName(track, "ArkDrums", false, -1)

-- Set pad volume (param 0 = Pad 1 Volume)
reaper.TrackFX_SetParam(track, fx_idx, 0, 0.8)

-- Load sample (param 16 = Pad 1 Sample Path, send as string)
-- Note: JUCE doesn't support string params, so we use a custom mechanism:
-- 1. Write sample path to temp file
-- 2. Set param 32 (Load Sample Trigger) to pad index
-- 3. VST reads temp file and loads sample
```

---

## Performance Goals

- **CPU (idle):** < 1% (16 empty pads)
- **CPU (16 voices):** < 5% @ 48kHz
- **Latency:** < 5ms (sample-accurate MIDI)
- **Memory:** < 100MB (16 pads × 4 layers × 2MB samples)

---

## Development Timeline

**Week 1 (Setup + Basic Playback):** JUCE project, WAV loader, MIDI trigger
**Week 2 (Core Features):** ADSR, velocity, per-pad controls
**Week 3 (Multi-Sample):** 16 pads, parameter system
**Weeks 4-6 (Advanced):** Velocity layers, round-robin, kill groups
**Weeks 7-8 (DSP):** Filters, pitch/time manipulation
**Weeks 9-10 (Integration):** Lua UI wiring, preset system

---

## License

GPL-3.0 (matches ARKITEKT framework)

---

## References

- JUCE Framework: https://juce.com/
- JUCE Sampler Tutorial: https://docs.juce.com/master/tutorial_simple_synth_noise.html
- REAPER FX API: https://www.reaper.fm/sdk/plugin/plugin.php

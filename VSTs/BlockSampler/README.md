# BlockSampler

Headless 128-pad drum sampler VST3 for REAPER, controlled by DrumBlocks (ARKITEKT).

## Features

- **128 pads** in one instance (full MIDI range)
- **4 velocity layers** per pad
- **Round-robin** playback (multiple samples per layer)
- **Sample start/end** points (non-destructive trim)
- **Kill groups** (hi-hat choke, 8 groups)
- **Output groups** (route pads to 16 stereo buses)
- **ADSR envelope** per pad
- **SVF filter** per pad (lowpass or highpass)
- **Peak normalization** per pad
- **Tune/pitch** per pad (-24 to +24 semitones)
- **One-shot / sustain** mode
- **Reverse playback**
- **Multi-out** (main + 16 group stereo outputs)
- **Headless** - DrumBlocks provides the UI
- **2176 automatable parameters** (17 per pad × 128)

## Build

### Prerequisites

- CMake 3.22+
- C++17 compiler (MSVC 2019+, Clang 10+, GCC 9+)
- JUCE 7.0.9 (auto-fetched by CMake)

### Build Commands

```bash
cd VSTs/BlockSampler
mkdir build && cd build
cmake ..
cmake --build . --config Release

# Output:
# Windows: build/BlockSampler_artefacts/Release/VST3/BlockSampler.vst3
# macOS:   build/BlockSampler_artefacts/Release/VST3/BlockSampler.vst3
# Linux:   build/BlockSampler_artefacts/Release/VST3/BlockSampler.vst3
```

### Install

Copy the `.vst3` folder to your VST3 path:
- **Windows**: `C:\Program Files\Common Files\VST3\`
- **macOS**: `/Library/Audio/Plug-Ins/VST3/`
- **Linux**: `~/.vst3/`

## Source Files

```
Source/
├── Parameters.h        # Constants, param definitions, layout factory
├── Pad.h               # Pad class declaration
├── Pad.cpp             # Pad implementation (playback, sample loading)
├── PluginProcessor.h   # VST3 processor declaration
└── PluginProcessor.cpp # VST3 processor implementation
```

## MIDI Mapping

| Note | Pad |
|------|-----|
| 0 (C-2) | 0 |
| 36 (C2) | 36 |
| 127 (G8) | 127 |

Full MIDI range: 128 notes = 128 pads.

## Parameters (17 per pad)

| Index | Name | Range | Default |
|-------|------|-------|---------|
| 0 | Volume | 0-1 | 0.8 |
| 1 | Pan | -1 to +1 | 0 |
| 2 | Tune | -24 to +24 st | 0 |
| 3 | Attack | 0-2000 ms | 0 |
| 4 | Decay | 0-2000 ms | 100 |
| 5 | Sustain | 0-1 | 1 |
| 6 | Release | 0-5000 ms | 200 |
| 7 | Filter Cutoff | 20-20000 Hz | 20000 |
| 8 | Filter Reso | 0-1 | 0 |
| 9 | Filter Type | 0=LP, 1=HP | 0 |
| 10 | Kill Group | 0-8 | 0 |
| 11 | Output Group | 0-16 | 0 |
| 12 | One-Shot | bool | true |
| 13 | Reverse | bool | false |
| 14 | Normalize | bool | false |
| 15 | Sample Start | 0-1 | 0 |
| 16 | Sample End | 0-1 | 1 |

**Parameter index formula**: `pad_index * 17 + param_index`

## Output Routing

| Bus | Name | Default Use |
|-----|------|-------------|
| 0 | Main | All pads (always) |
| 1 | Group 1 | Kicks |
| 2 | Group 2 | Snares |
| 3 | Group 3 | HiHats |
| 4 | Group 4 | Percussion |
| 5-16 | Group 5-16 | User-defined |

Pads route to Main + their assigned Output Group bus.

## DrumBlocks/Lua Integration

### Loading Samples

```lua
-- Sync load (blocks until complete - use for state restore)
Bridge.loadSample(track, fx, 0, 0, "/path/to/kick.wav")

-- Async load (returns immediately, loads in background thread)
Bridge.loadSampleAsync(track, fx, 0, 0, "/path/to/kick.wav")

-- Add round-robin sample (async)
Bridge.addRoundRobin(track, fx, 0, 0, "/path/to/kick_rr1.wav")
Bridge.addRoundRobin(track, fx, 0, 0, "/path/to/kick_rr2.wav")

-- Clear sample from pad 5, layer 1
Bridge.clearSample(track, fx, 5, 1)

-- Clear all samples from pad 10
Bridge.clearPad(track, fx, 10)
```

### Setting Parameters

```lua
local Bridge = require('DrumBlocks.domain.bridge')

-- Set volume on pad 0 to 80%
Bridge.setVolume(track, fx, 0, 0.8)

-- Set tune on pad 1 to -2 semitones
Bridge.setTune(track, fx, 1, -2)

-- Set output group on pad 0 to Group 1 (Kicks)
Bridge.setOutputGroup(track, fx, 0, 1)

-- Set sample start/end for pad 2 (trim first 10%, last 5%)
Bridge.setSampleRange(track, fx, 2, 0.1, 0.95)
```

### Direct Parameter Access

```lua
local PARAMS_PER_PAD = 15
local pad = 0
local VOLUME = 0

local param_idx = pad * PARAMS_PER_PAD + VOLUME
reaper.TrackFX_SetParam(track, fx, param_idx, 0.8)
```

## State Persistence

Sample paths are stored in the project state XML and reloaded on project open:

```xml
<BlockSamplerParams>
  <Samples>
    <Sample pad="0" layer="0" path="/path/to/kick.wav"/>
    <Sample pad="1" layer="0" path="/path/to/snare.wav"/>
  </Samples>
</BlockSamplerParams>
```

## Completed Features

- [x] 128 pads, 4 velocity layers
- [x] Sample start/end points
- [x] Round-robin playback
- [x] Kill groups (8)
- [x] Output groups (16)
- [x] ADSR per pad
- [x] SVF filter per pad (LP/HP)
- [x] Peak normalization per pad
- [x] State save/load with sample paths
- [x] Runtime sample loading via chunk commands
- [x] 2176 automatable parameters
- [x] Multi-out rendering to group buses

## TODO

- [x] Async sample loading (don't block audio thread)
- [ ] Random mode for round-robin

# BlockSampler

128-pad drum sampler VST3 for REAPER/DrumBlocks.

## Features

- **128 pads** in one instance (full MIDI range)
- **4 velocity layers** per pad
- **Kill groups** (hi-hat choke, 8 groups)
- **Output groups** (route pads to 16 group buses)
- **ADSR envelope** per pad
- **SVF filter** per pad (LP)
- **Tune/pitch** per pad
- **One-shot / sustain** mode
- **Reverse playback**
- **Multi-out** (main + 16 group stereo outputs)
- **Headless** - DrumBlocks is the UI
- **1664 automatable parameters** (13 per pad × 128)

## Build

```bash
# Prerequisites: CMake 3.22+, C++17 compiler

cd VSTs/BlockSampler
mkdir build && cd build
cmake ..
cmake --build . --config Release

# Output: build/BlockSampler_artefacts/Release/VST3/BlockSampler.vst3
```

## MIDI Mapping

| Note | Pad |
|------|-----|
| 0 (C-2) | 0 |
| 1 (C#-2) | 1 |
| ... | ... |
| 127 (G8) | 127 |

Full MIDI range: 128 pads = 128 MIDI notes.

## Parameters (per pad)

| Index | Name | Range |
|-------|------|-------|
| 0 | Volume | 0-1 |
| 1 | Pan | -1 to +1 |
| 2 | Tune | -24 to +24 st |
| 3 | Attack | 0-2000 ms |
| 4 | Decay | 0-2000 ms |
| 5 | Sustain | 0-1 |
| 6 | Release | 0-5000 ms |
| 7 | Filter Cutoff | 20-20000 Hz |
| 8 | Filter Reso | 0-1 |
| 9 | Kill Group | 0-8 |
| 10 | Output Group | 0-16 (0=main only) |
| 11 | One-Shot | 0/1 |
| 12 | Reverse | 0/1 |

Parameter index = `pad * 13 + param_index`

## Output Routing

| Bus | Name | Default Use |
|-----|------|-------------|
| 0 | Main | All pads (always) |
| 1 | Group 1 | Kicks |
| 2 | Group 2 | Snares |
| 3 | Group 3 | HiHats |
| 4 | Group 4 | Percussion |
| 5-16 | Group 5-16 | User-defined |

Pads route to Main + their assigned Output Group.

## Lua/DrumBlocks Integration

```lua
-- Load sample to pad 0, velocity layer 0
reaper.TrackFX_SetNamedConfigParm(track, fx, "P0_L0_SAMPLE", "/path/to/kick.wav")

-- Set volume on pad 0
local PARAMS_PER_PAD = 13
local param_idx = 0 * PARAMS_PER_PAD + 0  -- pad 0, volume
reaper.TrackFX_SetParam(track, fx, param_idx, 0.8)

-- Set output group on pad 0 to Group 1 (Kicks)
local OUTPUT_GROUP = 10
local param_idx = 0 * PARAMS_PER_PAD + OUTPUT_GROUP
reaper.TrackFX_SetParam(track, fx, param_idx, 1 / 16)  -- normalized
```

## TODO

- [ ] Sample path persistence in state
- [ ] Named config param handler for sample loading
- [ ] Multi-out rendering to group buses
- [ ] Round-robin support
- [ ] Sample start/end points
- [ ] Hot-swap preview mode (play sample on param change)

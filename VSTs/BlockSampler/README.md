# BlockSampler

16-pad drum sampler VST3 for REAPER/DrumBlocks.

## Features

- **16 pads** in one instance (vs RS5K's 1)
- **4 velocity layers** per pad
- **Kill groups** (hi-hat choke)
- **ADSR envelope** per pad
- **SVF filter** per pad (LP)
- **Tune/pitch** per pad
- **One-shot / sustain** mode
- **Reverse playback**
- **Multi-out** (main + 16 stereo outputs)
- **Headless** - DrumBlocks is the UI

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
| 36 (C1) | 0 |
| 37 (C#1) | 1 |
| ... | ... |
| 51 (D#2) | 15 |

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
| 10 | One-Shot | 0/1 |
| 11 | Reverse | 0/1 |

Parameter index = `pad * 12 + param_index`

## Lua/DrumBlocks Integration

```lua
-- Load sample
reaper.TrackFX_SetNamedConfigParm(track, fx, "P0_SAMPLE", "/path/to/kick.wav")

-- Set parameters
local param_idx = pad * 12 + 0  -- Volume
reaper.TrackFX_SetParam(track, fx, param_idx, 0.8)
```

## TODO

- [ ] Sample path persistence in state
- [ ] Named config param handler for sample loading
- [ ] Multi-out rendering (currently all to main)
- [ ] Round-robin support
- [ ] Sample start/end points

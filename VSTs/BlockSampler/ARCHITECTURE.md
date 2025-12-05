# BlockSampler Architecture Guide

> A layman's explanation of how the VST works and why we made certain choices.

## What is a VST?

A **VST** (Virtual Studio Technology) is a plugin format that lets software instruments and effects run inside a DAW (like REAPER). Think of it like a "mini-program" that lives inside your music software.

```
REAPER (host)
  └── BlockSampler.vst3 (our plugin)
        └── DrumBlocks (Lua UI that controls it)
```

**Why "headless"?** BlockSampler has no built-in GUI. Instead, DrumBlocks (your Lua/ImGui app) controls it remotely. This keeps the C++ code simple and lets you iterate on the UI in Lua without recompiling.

---

## The Build System (CMake)

### What is CMake?

CMake is a "build system generator" - it creates the actual build files for your platform:
- Windows: generates Visual Studio project
- macOS: generates Xcode project
- Linux: generates Makefiles

```
CMakeLists.txt (recipe)
       │
       ▼
    cmake ..
       │
       ▼
  Makefile / .vcxproj / .xcodeproj (platform-specific)
       │
       ▼
  cmake --build .
       │
       ▼
  BlockSampler.vst3 (final plugin)
```

### Key Parts of CMakeLists.txt

```cmake
# "Go download JUCE from GitHub"
FetchContent_Declare(JUCE ...)
FetchContent_MakeAvailable(JUCE)

# "Build a plugin called BlockSampler"
juce_add_plugin(BlockSampler
    FORMATS VST3 AU CLAP Standalone  # What formats to build
    IS_SYNTH TRUE                     # It makes sound (not just effects)
    NEEDS_MIDI_INPUT TRUE             # It responds to MIDI notes
)

# "These are the source files"
target_sources(BlockSampler PRIVATE
    Source/PluginProcessor.cpp
    Source/Pad.cpp
)

# "Link these JUCE modules"
target_link_libraries(BlockSampler PRIVATE
    juce::juce_audio_formats   # Read WAV/MP3/FLAC files
    juce::juce_dsp             # Filters, envelopes
    # ...
)
```

### Why JUCE?

**JUCE** is a C++ framework specifically for audio software. We chose it because:

| Feature | What it does for us |
|---------|---------------------|
| `AudioFormatManager` | Reads WAV, MP3, FLAC, AIFF without writing file parsers |
| `ADSR` | Ready-made envelope (Attack/Decay/Sustain/Release) |
| `StateVariableTPTFilter` | High-quality lowpass/highpass filter |
| `ThreadPool` | Background loading without freezing audio |
| `ValueTree` | Easy state save/load (project recall) |
| Cross-platform | Same code builds on Win/Mac/Linux |

**The tradeoff:** JUCE plugins are ~5MB (vs ~200KB for minimal frameworks). But it saved weeks of development time.

---

## Source Code Explained

### File Structure

```
Source/
├── Parameters.h        # "What knobs does this plugin have?"
├── Pad.h / Pad.cpp     # "One drum pad" - sample playback logic
└── PluginProcessor.h/cpp  # "The brain" - MIDI, routing, state
```

### Parameters.h - The Knobs

This file defines every controllable parameter. Think of it as the "spec sheet."

```cpp
// We have 128 pads, each with 18 parameters
constexpr int NUM_PADS = 128;
constexpr int PARAMS_PER_PAD = 18;  // volume, pan, tune, etc.

// Total: 128 × 18 = 2304 parameters (!)
// This is why DAW automation works - each knob has an ID
```

**Parameter list per pad:**
| # | Name | Range | What it does |
|---|------|-------|--------------|
| 0 | Volume | 0-1 | How loud |
| 1 | Pan | -1 to +1 | Left/right position |
| 2 | Tune | -24 to +24 | Pitch shift in semitones |
| 3-6 | ADSR | various | Envelope shape |
| 7-9 | Filter | Hz, resonance, type | Tone shaping |
| 10 | Kill Group | 0-8 | "Choke" other pads (hi-hat behavior) |
| 11 | Output Group | 0-16 | Route to separate mixer channel |
| 12 | One-Shot | bool | Play full sample vs. hold-to-play |
| 13 | Reverse | bool | Play backwards |
| 14 | Normalize | bool | Auto-level matching |
| 15-16 | Start/End | 0-1 | Trim points |
| 17 | RR Mode | 0-1 | Round-robin: sequential vs. random |

### Pad.cpp - The Sample Player

Each pad is like a tiny sampler. Here's what happens when you hit a note:

```
MIDI Note On (velocity 100)
       │
       ▼
┌─────────────────────────────────────────────────┐
│ 1. Select velocity layer (soft/medium/hard)    │
│ 2. Advance round-robin (pick next sample)      │
│ 3. Calculate start/end points                   │
│ 4. Trigger ADSR envelope                        │
└─────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────┐
│ For each audio sample:                          │
│   - Read from buffer (with pitch interpolation) │
│   - Apply volume × velocity × envelope          │
│   - Apply pan (stereo positioning)              │
│   - Run through filter (if enabled)             │
└─────────────────────────────────────────────────┘
       │
       ▼
  Audio output
```

**Key concepts:**

1. **Velocity Layers** (4 per pad)
   - Different samples for soft vs. hard hits
   - Velocity 1-31 → Layer 0, 32-63 → Layer 1, etc.

2. **Round-Robin**
   - Multiple samples that cycle to avoid "machine gun" effect
   - Sequential: 1→2→3→1→2→3...
   - Random: picks randomly (but avoids immediate repeats)

3. **Pitch Shifting**
   - Uses linear interpolation between samples
   - `pitchRatio = 2^(semitones/12)` - same math as real instruments

4. **Kill Groups**
   - When pad triggers, stops all other pads in same group
   - Classic use: open hi-hat chokes closed hi-hat

### PluginProcessor.cpp - The Brain

This is the main class that REAPER talks to:

```
REAPER                          BlockSampler
   │                                 │
   ├── "Here's MIDI" ──────────────► handleMidiEvent()
   │                                 │
   ├── "Give me 512 samples" ──────► processBlock()
   │                                 │
   ├── "Save your state" ──────────► getStateInformation()
   │                                 │
   ├── "Load this state" ──────────► setStateInformation()
   │                                 │
   └── "Set P0_L0_SAMPLE=/kick.wav"─► handleNamedConfigParam()
       (from DrumBlocks Lua)
```

**Key methods:**

```cpp
// Called 44100÷512 ≈ 86 times per second (at 44.1kHz, 512 buffer)
void processBlock(AudioBuffer& buffer, MidiBuffer& midi)
{
    // 1. Clear output
    buffer.clear();

    // 2. Handle any MIDI events (note on/off)
    for (auto msg : midi)
        handleMidiEvent(msg);

    // 3. Render each playing pad
    for (int i = 0; i < 128; i++)
    {
        if (pads[i].isPlaying)
        {
            pads[i].renderNextBlock(512);

            // Mix into main output
            buffer.addFrom(pads[i].getOutput());

            // Also mix into group bus if assigned
            if (pads[i].outputGroup > 0)
                groupBus[pads[i].outputGroup].addFrom(...);
        }
    }
}
```

---

## How DrumBlocks Talks to BlockSampler

### Loading Samples

DrumBlocks can't directly call C++ functions. Instead, it uses REAPER's parameter system:

```lua
-- In DrumBlocks (Lua)
reaper.TrackFX_SetNamedConfigParm(track, fx, "P0_L0_SAMPLE", "/path/to/kick.wav")
```

The VST receives this as a "named config param" and loads the sample:

```cpp
// In PluginProcessor.cpp
bool handleNamedConfigParam(const String& name, const String& value)
{
    // Parse "P0_L0_SAMPLE" → pad=0, layer=0
    if (name.endsWith("_SAMPLE"))
    {
        loadSampleToPad(padIndex, layerIndex, value);
        return true;
    }
}
```

### Setting Parameters

```lua
-- Set volume on pad 0 to 80%
local param_index = 0 * 18 + 0  -- pad 0, param 0 (volume)
reaper.TrackFX_SetParam(track, fx, param_index, 0.8)
```

### Multi-Output Routing

BlockSampler has 17 stereo outputs:
- Bus 0: Main (all pads)
- Bus 1-16: Group buses (optional routing)

In REAPER, you enable extra outputs via track routing. Each pad can send to Main + one Group simultaneously.

---

## Thread Safety

Audio code has strict rules because it runs in a **real-time thread**:

| OK in audio thread | NOT OK in audio thread |
|--------------------|------------------------|
| Math operations | File I/O |
| Reading from buffers | Memory allocation |
| Parameter reads | Locking mutexes (blocking) |

**Our solution for sample loading:**

```
DrumBlocks: "Load /kick.wav to pad 0"
                    │
                    ▼
            ┌───────────────┐
            │  ThreadPool   │ ◄── Background thread
            │  (2 workers)  │
            └───────┬───────┘
                    │ Load file, decode audio
                    ▼
            ┌───────────────┐
            │ completedLoads│ ◄── Queue (mutex-protected)
            │    (queue)    │
            └───────┬───────┘
                    │
                    ▼
            ┌───────────────┐
            │ Timer (50ms)  │ ◄── Main thread checks queue
            │ applies loads │
            └───────────────┘
```

The audio thread never waits for file I/O - samples appear "magically" when ready.

---

## Build Requirements

### Minimum Versions

| Platform | Requirement |
|----------|-------------|
| Windows | Visual Studio 2019+ |
| macOS | Xcode 12.4+ (macOS 10.15+) |
| Linux | GCC 9+ or Clang 6+ |
| All | CMake 3.22+, C++17 |

### Build Commands

```bash
cd VSTs/BlockSampler
mkdir build && cd build
cmake ..
cmake --build . --config Release

# Output locations:
# Windows: build/BlockSampler_artefacts/Release/VST3/BlockSampler.vst3
# macOS:   build/BlockSampler_artefacts/Release/VST3/BlockSampler.vst3
#          build/BlockSampler_artefacts/Release/AU/BlockSampler.component
#          build/BlockSampler_artefacts/Release/CLAP/BlockSampler.clap
# Linux:   build/BlockSampler_artefacts/Release/VST3/BlockSampler.vst3
#          build/BlockSampler_artefacts/Release/CLAP/BlockSampler.clap
```

### Install Locations

| Format | Windows | macOS | Linux |
|--------|---------|-------|-------|
| VST3 | `C:\Program Files\Common Files\VST3\` | `/Library/Audio/Plug-Ins/VST3/` | `~/.vst3/` |
| AU | - | `/Library/Audio/Plug-Ins/Components/` | - |
| CLAP | `C:\Program Files\Common Files\CLAP\` | `/Library/Audio/Plug-Ins/CLAP/` | `~/.clap/` |

---

## Why These Choices?

### Why C++ for the VST?

- **Performance**: Audio runs at 44100+ samples/second, needs raw speed
- **Low latency**: Can't have garbage collection pauses
- **Industry standard**: All pro audio plugins are C/C++

### Why Lua/ImGui for the UI?

- **Fast iteration**: Change UI without recompiling C++
- **Your expertise**: You know Lua/ARKITEKT well
- **Decoupled**: UI can evolve independently of audio engine

### Why 128 Pads?

- Full MIDI range (notes 0-127)
- 8 banks × 16 pads = familiar drum machine layout
- Room to grow (multi-kit setups)

### Why CLAP Support?

- Open source, no licensing fees
- Better parameter handling than VST3
- Growing DAW support (REAPER, Bitwig, FL Studio)
- Future-proofing

---

## Glossary

| Term | Meaning |
|------|---------|
| **DAW** | Digital Audio Workstation (REAPER, Ableton, etc.) |
| **Buffer** | Chunk of audio samples processed at once (e.g., 512 samples) |
| **Sample Rate** | How many samples per second (44100 Hz = CD quality) |
| **MIDI** | Protocol for note on/off, velocity, etc. |
| **VST3** | Steinberg's plugin format (most compatible) |
| **AU** | Apple's Audio Unit format (macOS only) |
| **CLAP** | New open-source plugin format |
| **ADSR** | Attack-Decay-Sustain-Release envelope |
| **Kill Group** | Pads that stop each other (hi-hat choke) |
| **Round-Robin** | Cycling through multiple samples to sound natural |
| **Velocity Layer** | Different sample for soft vs. hard hits |

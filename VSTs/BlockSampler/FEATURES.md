# BlockSampler vs RS5K Feature Comparison

## What RS5K Does (That We Need)

| Feature | RS5K | BlockSampler |
|---------|------|--------------|
| Sample playback | ✅ | ✅ |
| ADSR envelope | ✅ Basic | ✅ Per-pad |
| Filter (LP/HP/BP) | ✅ Basic | ✅ SVF per-pad |
| Pitch/tune | ✅ Via speed | ✅ Via speed (same) |
| Volume/Pan | ✅ | ✅ Per-pad |
| Note range | ✅ | ✅ Fixed: 36-51 (pads 0-15) |
| Velocity sensitivity | ✅ | ✅ + layers |
| Obey note-off | ✅ | ✅ Optional per-pad |

## What RS5K Lacks (That We Add)

| Feature | RS5K | BlockSampler |
|---------|------|--------------|
| Multiple pads per instance | ❌ (need 16 instances) | ✅ 16 pads |
| Velocity layers | ❌ | ✅ 4 layers per pad |
| Round-robin | ❌ | ✅ Per layer |
| Kill groups (hi-hat choke) | ❌ | ✅ 8 groups |
| Multi-out routing | ❌ (1 stereo) | ✅ 16 stereo outs |
| Sample start/end | ⚠️ Basic | ✅ Per-pad |
| One-shot mode | ⚠️ Clunky | ✅ Per-pad toggle |
| Reverse playback | ❌ | ✅ Per-pad |
| Parameter exposure for Lua | ❌ | ✅ Full control |

## What We Skip (Not Worth Complexity)

| Feature | Why Skip |
|---------|----------|
| Time-stretching | Complex, CPU heavy, rarely needed for drums |
| Pitch-independent | Same - drums don't need it |
| Loop modes | One-shot is 99% of drum use |
| Complex modulation | DrumBlocks handles this via automation |
| Built-in FX (reverb, delay) | Use REAPER FX chain instead |

## Parameter Layout (160 total)

```
Per-Pad Parameters (10 × 16 pads = 160):
  0: Volume        (0.0 - 1.0)
  1: Pan           (-1.0 - 1.0)
  2: Tune          (-24 - +24 semitones)
  3: Attack        (0 - 2000 ms)
  4: Decay         (0 - 2000 ms)
  5: Sustain       (0.0 - 1.0)
  6: Release       (0 - 5000 ms)
  7: Filter Cutoff (20 - 20000 Hz, log scale)
  8: Filter Reso   (0.0 - 1.0)
  9: Kill Group    (0-8, 0 = none)
```

## Named Config Parameters (Strings)

```
P0_SAMPLE  = "/path/to/kick.wav"
P0_SAMPLE1 = "/path/to/kick_soft.wav"   (velocity layer 1)
P0_SAMPLE2 = "/path/to/kick_medium.wav" (velocity layer 2)
P0_SAMPLE3 = "/path/to/kick_hard.wav"   (velocity layer 3)
...
P15_SAMPLE = "/path/to/crash.wav"
```

## MIDI Mapping

```
Note 36 (C1)  → Pad 0  (Kick)
Note 37 (C#1) → Pad 1  (Snare)
Note 38 (D1)  → Pad 2  (Closed HH)
...
Note 51 (D#2) → Pad 15
```

## Multi-Out Configuration

```
Bus 0:  Main Stereo (mix of all pads)
Bus 1:  Pad 0 stereo
Bus 2:  Pad 1 stereo
...
Bus 16: Pad 15 stereo
```

## Kill Group Logic

```cpp
// When pad triggers:
if (pad.killGroup > 0) {
    for (auto& other : pads) {
        if (&other != &pad && other.killGroup == pad.killGroup) {
            other.stopImmediately();  // Or fast release
        }
    }
}

// Typical use:
// Pad 2 (Closed HH) → Kill Group 1
// Pad 3 (Open HH)   → Kill Group 1
// Closed stops Open, Open stops Closed
```

## Velocity Layer Selection

```cpp
// 4 layers with configurable thresholds
// Default: 0-31, 32-63, 64-95, 96-127
int selectLayer(int velocity) {
    if (velocity < 32) return 0;
    if (velocity < 64) return 1;
    if (velocity < 96) return 2;
    return 3;
}
```

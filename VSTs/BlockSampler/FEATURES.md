# BlockSampler Feature Comparison

## vs Sitala (Free Drum Sampler)

| Feature | Sitala | BlockSampler | Winner |
|---------|--------|--------------|--------|
| Pads | 16 | 128 | **BlockSampler** |
| Velocity layers | ❌ | ✅ 4 per pad + crossfade | **BlockSampler** |
| Round-robin | ❌ | ✅ 16 per layer | **BlockSampler** |
| Choke/kill groups | ✅ 16 | ✅ 8 | Sitala (more groups) |
| Multi-out routing | ✅ 16 stereo | ✅ 16 stereo | Tie |
| ADSR envelope | ✅ | ✅ | Tie |
| Filter | ✅ Tone knob | ✅ SVF LP/HP + reso | **BlockSampler** |
| **Pitch envelope** | ❌ | ✅ Full ADSR | **BlockSampler** |
| **Loop modes** | ❌ | ✅ OneShot/Loop/PingPong | **BlockSampler** |
| Sample start/end | ✅ | ✅ | Tie |
| Reverse playback | ❌ | ✅ | **BlockSampler** |
| Peak normalization | ❌ | ✅ | **BlockSampler** |
| Built-in effects | ✅ (tone, bitcrush) | ❌ (use DAW FX) | Sitala |
| GUI | ✅ Nice | ❌ Headless | Sitala |
| Drag & drop | ✅ | ❌ (Lua/chunk) | Sitala |
| Parameter automation | ✅ ~80 | ✅ 2816 | **BlockSampler** |
| Price | Free | Free | Tie |

**Summary:** BlockSampler wins on audio features (pitch envelope, velocity layers, round-robin), Sitala wins on usability (GUI, drag & drop).

---

## vs Ableton Drum Rack

| Feature | Drum Rack | BlockSampler | Winner |
|---------|-----------|--------------|--------|
| Pads | 128 | 128 | Tie |
| Velocity layers | ✅ (via Simpler) | ✅ 4 built-in + crossfade | **BlockSampler** |
| Round-robin | ✅ (manual setup) | ✅ 16 per layer | **BlockSampler** (easier) |
| Choke groups | ✅ 16 | ✅ 8 | Drum Rack |
| Multi-out routing | ✅ Unlimited | ✅ 16 stereo | Drum Rack |
| ADSR envelope | ✅ Full | ✅ Full | Tie |
| Filter | ✅ Multi-mode | ✅ SVF LP/HP | Drum Rack |
| **Pitch envelope** | ✅ (via Simpler) | ✅ Dedicated | Tie |
| **Loop modes** | ✅ Full | ✅ 3 modes | Drum Rack (more options) |
| Warp/time-stretch | ✅ | ❌ | Drum Rack |
| Slice to pads | ✅ | ❌ | Drum Rack |
| Macro controls | ✅ 8 | ❌ (use Lua) | Drum Rack |
| Per-pad FX chains | ✅ Full | ❌ (use DAW) | Drum Rack |
| Parameter automation | ✅ | ✅ 2816 params | Tie |
| Scripting/API | ❌ | ✅ Full Lua | **BlockSampler** |
| DAW integration | Ableton only | REAPER | Depends |
| Price | $$$$ (Suite) | Free | **BlockSampler** |

**Summary:** Drum Rack has more features overall, but BlockSampler is free and has superior scripting/automation for REAPER workflows.

---

## BlockSampler Unique Strengths

1. **2816 Automatable Parameters**
   - Every parameter on every pad exposed to DAW automation
   - Full Lua API for scripted control

2. **808-Style Pitch Envelope**
   - Dedicated A-D-S envelope for pitch modulation
   - Fast `pow2` approximation for CPU efficiency
   - Classic kick "boing" in 4 parameters

3. **Velocity Layer Crossfade**
   - Smooth blending between adjacent velocity layers
   - Configurable blend zone width (0-100%)
   - Eliminates harsh transitions in multi-layer samples

4. **Deep Round-Robin**
   - 16 samples per velocity layer
   - Sequential or random mode
   - No manual routing needed

5. **Thread-Safe Async Loading**
   - Background sample loading
   - Lock-free command queue
   - No audio dropouts during kit changes

6. **REAPER/Lua Integration**
   - Full named config param support
   - Kit save/load via scripts
   - 808 presets built into bridge

---

## Current Parameter Count

```
Per-Pad Parameters: 23
  0:  Volume           (0-1)
  1:  Pan              (-1 to +1)
  2:  Tune             (-24 to +24 semitones)
  3:  Attack           (0-2000 ms)
  4:  Decay            (0-2000 ms)
  5:  Sustain          (0-1)
  6:  Release          (0-5000 ms)
  7:  Filter Cutoff    (20-20000 Hz)
  8:  Filter Reso      (0-1)
  9:  Filter Type      (0=LP, 1=HP)
  10: Kill Group       (0-8)
  11: Output Group     (0-16)
  12: Loop Mode        (0=OneShot, 1=Loop, 2=PingPong)
  13: Reverse          (bool)
  14: Normalize        (bool)
  15: Sample Start     (0-1)
  16: Sample End       (0-1)
  17: Round Robin Mode (0=seq, 1=random)
  18: Pitch Env Amount (-24 to +24 semitones)
  19: Pitch Env Attack (0-100 ms)
  20: Pitch Env Decay  (0-2000 ms)
  21: Pitch Env Sustain(0-1)
  22: Vel Crossfade    (0-1, 0=hard switch, 1=full blend)

Total: 23 × 128 pads = 2,944 parameters
```

---

## What We Still Skip

| Feature | Why |
|---------|-----|
| Time-stretching | CPU heavy, drums don't need it |
| Granular/wavetable | Out of scope for drum sampler |
| Built-in FX | Use REAPER FX chain (more flexible) |
| Slice detection | DrumBlocks can handle via Lua |
| GUI | Headless by design (DrumBlocks provides UI) |

---

## 808 Preset Quick Reference

```lua
-- Classic 808 kick
Bridge.applyPreset(track, fx, pad, Bridge.Presets.Kick808)
-- pitch_env_amount = -12, decay = 80ms

-- Deep sub kick
Bridge.applyPreset(track, fx, pad, Bridge.Presets.SubKick808)
-- pitch_env_amount = -24, decay = 150ms

-- Punchy kick
Bridge.applyPreset(track, fx, pad, Bridge.Presets.PunchyKick808)
-- pitch_env_amount = -8, decay = 30ms
```

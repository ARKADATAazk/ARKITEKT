# BlockSampler - Future Feature Ideas

Potential enhancements to consider. Not committed to implementing - just captured for reference.

## High Priority

### Fade In/Out
- Prevents clicks on loop points and sample cuts
- Parameters: `fadeIn` (ms), `fadeOut` (ms)
- Simple linear fade or configurable curve
- Essential if loop mode is used heavily

### Voice Limit Per Pad
- Prevent CPU spikes on rapid triggers (e.g., drum rolls)
- Parameter: `maxVoices` (1-16, default 8?)
- Voice stealing: kill oldest or quietest
- Could also have global limit across all pads

## Medium Priority

### Pitch Envelope
- Pitch decay over time (classic 808 kick sound)
- Parameters: `pitchEnvAmount` (semitones), `pitchEnvDecay` (ms)
- Start at pitch + amount, decay to base pitch
- Very popular for electronic drums

### Filter Envelope
- Filter cutoff modulation over time
- Parameters: `filterEnvAmount`, `filterEnvDecay` (ms)
- One-shot decay envelope, triggered with note
- Adds movement and expression

## Low Priority

### Velocity-to-Filter Modulation
- Harder hits open the filter more
- Parameter: `velToFilter` (-100% to +100%)
- Simple multiply against velocity

### Humanization / Jitter
- Sample offset randomization (subtle timing variation)
- Pitch randomization (slight detuning)
- Pan randomization (stereo field variation)
- Parameters: `offsetJitter`, `pitchJitter`, `panJitter`

### Oversampling
- Better quality pitch shifting at extreme values
- 2x or 4x oversampling option
- Trade-off: higher CPU usage

## Deferred to REAPER FX Chain

Some features might be better handled externally:

- **Saturation/soft clipping** - Use JS or VST saturation plugin
- **Compression** - Per-group or master compression in REAPER
- **EQ** - ReaEQ on output groups
- **Reverb/delay sends** - REAPER routing
- **Sidechain** - REAPER's native sidechain routing

## Design Philosophy

Keep the VST focused on:
1. Sample playback engine (done well)
2. Per-pad parameters that need sample-accurate timing
3. Features that benefit from tight integration

Defer to REAPER for:
1. Effects processing
2. Complex modulation
3. Mixing/routing beyond basic groups

---

*Last updated: 2024-12*

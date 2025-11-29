# MIDI Helix (ARKITEKT Edition)

**Euclidean rhythm generator for REAPER's MIDI Editor**

## About

This is a reimplementation of the Euclidean generator from RobU's excellent [MIDI Ex Machina](https://github.com/RobU23/ReaScripts), built on the ARKITEKT framework.

**Inspiration:** RobU's original MIDI Ex Machina (GPL-3.0)
**Status:** Prototype - Euclidean generator only (v0.1)

## What is a Euclidean Rhythm?

Euclidean rhythms distribute pulses (hits) as evenly as possible across a given number of steps using the Bjorklund algorithm. These patterns appear naturally in music worldwide:

- **E(5,8)** = `x.x.x.xx` - Common in rock/funk
- **E(3,8)** = `x..x..x.` - Tresillo (Latin music)
- **E(4,12)** = `x..x..x..x..` - Common polyrhythm

## Features

- ✅ Bjorklund algorithm implementation
- ✅ Adjustable pulses, steps, and rotation
- ✅ Real-time visual pattern preview
- ✅ Safe MIDI writing (prevents Ghost/Pooled item hangs)
- ✅ Grid-based timing control
- ✅ Note pitch and velocity control

## Usage

1. Open REAPER's MIDI editor
2. Run `ARK_MIDIHelix.lua`
3. Adjust sliders to create your pattern
4. Click "Generate Pattern" to insert notes

### Controls

**Pattern:**
- **Pulses** - Number of hits in the pattern (0-32)
- **Steps** - Total number of steps (1-32)
- **Rotation** - Rotate pattern left/right (0-31)

**MIDI Output:**
- **Note** - MIDI note number (0-127)
- **Velocity** - Note velocity (1-127)

**Timing:**
- **Grid Division** - Time between steps (0.0625 = 64th notes, 0.25 = 16ths, 1.0 = quarter notes)
- **Note Length** - Duration of each note

## Known Limitations

- Pattern starts from cursor position
- Monophonic output only (one note at a time)
- No pattern library/presets yet

## Future Plans

This is a **prototype** to test the concept. Planned additions:

- Note randomizer module
- Sequencer module
- Pattern presets/library
- Settings persistence
- Polyphonic support

## Credits

**Original concept:** [RobU](https://github.com/RobU23) - MIDI Ex Machina
**ARKITEKT implementation:** Built with the [ARKITEKT framework](https://github.com/ARKADATAazk/ARKITEKT-Toolkit)

## License

GPL-3.0 (same as original MIDI Ex Machina)

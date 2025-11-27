# MIDI Generator (MIDI Ex Machina++)

> **Status:** Proposed
> **Priority:** High
> **Inspiration:** [RobU's MIDI Ex Machina](https://github.com/RobU23/ReaScripts), X-Raym randomization scripts
> **Goal:** Build enhanced MIDI generator, extract reusable algorithms to arkitekt/core/

---

## Overview

A next-generation MIDI pattern generator that extends RobU's MIDI Ex Machina with additional features, while extracting core algorithms into reusable arkitekt modules for use across apps (ItemPicker, TemplateBrowser, etc.).

---

## Existing Features (RobU's MIDI Ex Machina)

- [x] Euclidean rhythm generator (Bjorklund algorithm)
- [x] Random sequence generation
- [x] Scale-aware note generation
- [x] Note probability per step
- [x] Basic velocity randomization

---

## New Features

### Rhythm Generation

| Feature | Description |
|---------|-------------|
| **Polyrhythm support** | Multiple Euclidean patterns with different lengths (3 over 4, 5 over 8, etc.) |
| **Polymetric patterns** | Different time signatures running simultaneously |
| **Rhythm presets** | Common patterns: straight, swing, shuffle, triplet, dotted |
| **Pattern chaining** | Link multiple patterns into longer sequences |
| **Accent patterns** | Separate Euclidean layer for accents/ghost notes |

### Melody Generation

| Feature | Description |
|---------|-------------|
| **Chord progression templates** | I-IV-V-I, ii-V-I, etc. with voicing options |
| **Melodic contour** | Control shape: rising, falling, arch, wave |
| **Interval constraints** | Limit jumps (e.g., max 5th, prefer steps) |
| **Motif development** | Repeat/vary a short phrase |
| **Bass line generator** | Root, fifth, walking patterns |

### Humanization (X-Raym inspired)

| Feature | Description |
|---------|-------------|
| **Normal distribution** | Gaussian randomization (not uniform) for natural feel |
| **Timing humanize** | Micro-timing shifts with configurable range |
| **Velocity curves** | Natural dynamics, accent patterns |
| **Reproducible seeds** | Save/recall specific random states |
| **Groove templates** | MPC swing, live drummer feel, etc. |

### Interface

| Feature | Description |
|---------|-------------|
| **Live preview** | MIDI output while adjusting parameters |
| **Visual pattern display** | Piano roll preview in UI |
| **A/B comparison** | Compare two generations side by side |
| **Undo history** | Step back through generations |
| **Preset system** | Save/load full configurations |

---

## Reusable Algorithms (arkitekt/core/)

Extract these to share with ItemPicker and other apps:

### arkitekt/core/random/

```lua
-- distributions.lua
M.uniform(min, max)              -- Standard random
M.normal(mean, stddev)           -- Gaussian distribution
M.weighted(values, weights)      -- Weighted selection
M.probability(chance)            -- Returns true/false

-- seed.lua
M.create_seed()                  -- Generate new seed
M.set_seed(seed)                 -- Set for reproducibility
M.get_seed()                     -- Get current seed

-- shuffle.lua
M.fisher_yates(array)            -- In-place shuffle
M.rotate(array, n)               -- Rotate by n positions
M.swap_pairs(array)              -- Swap adjacent pairs
M.partial_shuffle(array, pct)    -- Shuffle only pct% of items
```

### arkitekt/core/patterns/

```lua
-- euclidean.lua
M.generate(steps, pulses, rotation)  -- Bjorklund algorithm
M.to_binary(pattern)                 -- Pattern to 0/1 array
M.to_indices(pattern)                -- Pattern to hit indices

-- probability.lua
M.apply(pattern, probabilities)      -- Per-step probability
M.gradient(length, start_p, end_p)   -- Probability ramp

-- sequence.lua
M.reverse(pattern)
M.invert(pattern)
M.retrograde(pattern)                -- Reverse + invert
M.augment(pattern, factor)           -- Time stretch
M.diminish(pattern, factor)          -- Time compress
```

### arkitekt/core/music/

```lua
-- scales.lua
M.SCALES = { major, minor, dorian, ... }
M.get_notes(root, scale)
M.nearest_in_scale(note, root, scale)

-- chords.lua
M.CHORDS = { maj, min, dim, aug, ... }
M.build_chord(root, chord_type, inversion)
M.voice_lead(from_chord, to_chord)
```

---

## Integration with ItemPicker

Once core algorithms exist, ItemPicker can use:

```lua
local shuffle = require('arkitekt.core.random.shuffle')
local distributions = require('arkitekt.core.random.distributions')

-- Shuffle selection order with normal distribution bias
function M.randomize_selection_order(keys)
  shuffle.fisher_yates(keys)
  return keys
end

-- Add timing variation to sequential insert
function M.humanize_insert_timing(base_time, range_ms)
  local offset = distributions.normal(0, range_ms / 3)
  return base_time + offset
end
```

---

## UI Mockup

```
┌─────────────────────────────────────────────────────────┐
│ MIDI Generator                                    [X]   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  RHYTHM ─────────────────────────────────────────────   │
│  Steps: [16▼]  Pulses: [5 ▼]  Rotation: [0  ▼]         │
│  [●○○●○○●○○●○○●○○○]                                     │
│                                                         │
│  Polyrhythm: [Off▼]   Accent: [Euclidean▼]             │
│                                                         │
│  MELODY ─────────────────────────────────────────────   │
│  Root: [C▼]  Scale: [Minor▼]  Octave: [3-5▼]           │
│  Contour: [Arch▼]  Max Interval: [5th▼]                │
│                                                         │
│  HUMANIZE ───────────────────────────────────────────   │
│  Timing:   [▬▬▬▬▬▬▬░░░] 35%                            │
│  Velocity: [▬▬▬▬░░░░░░] 20%                            │
│  [●] Normal distribution   Seed: [Auto▼] [🎲]          │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ ▁▃▅▇▅▃▁  ▁▃▅▇▅▃▁  (preview)                     │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  [▶ Preview]  [Generate]  [A/B]     [Presets▼] [Save]  │
└─────────────────────────────────────────────────────────┘
```

---

## Implementation Phases

### Phase 1: Core Algorithms
- [ ] Extract Euclidean to arkitekt/core/patterns/euclidean.lua
- [ ] Create arkitekt/core/random/ module
- [ ] Create arkitekt/core/music/scales.lua
- [ ] Unit tests for all algorithms

### Phase 2: Basic Generator
- [ ] Port RobU's core functionality
- [ ] Add ReaImGui interface
- [ ] Integrate arkitekt patterns
- [ ] Basic preset system

### Phase 3: Enhanced Features
- [ ] Polyrhythm support
- [ ] Humanization with normal distribution
- [ ] Chord progression templates
- [ ] Live MIDI preview

### Phase 4: Polish
- [ ] Visual pattern display
- [ ] A/B comparison
- [ ] Groove templates
- [ ] Documentation

### Phase 5: Integration
- [ ] ItemPicker uses shuffle/humanize
- [ ] TemplateBrowser pattern presets
- [ ] Shared preset format

---

## Related

- [SelectionNumbering.md](./SelectionNumbering.md) - Uses shuffle algorithms
- [ItemPickerFeatures.md](./ItemPickerFeatures.md) - Uses humanization for insert timing
- [RobU's MIDI Ex Machina](https://github.com/RobU23/ReaScripts)
- [X-Raym Randomization Scripts](https://www.extremraym.com/en/reaper-randomisation-takes/)

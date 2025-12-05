# Drum Rack: Architecture Decision Document

## Context

We're building a drum rack component for Blocks that integrates with REAPER's audio engine. This document captures research findings and architectural decisions.

## Research Summary

### Existing Solutions Analyzed

| Solution | Pros | Cons |
|----------|------|------|
| **MPL RS5K Manager** | Powerful, velocity layers, step sequencer, mature | Performance issues (laggy UI), complex routing, some bugs |
| **Suzuki ReaDrum Machine** | Clean container-based, REAPER 7 features, active development | Many dependencies, complex setup, generates undo points |
| **Sitala** | Simple UI, multi-out auto-config, free | External plugin, limited features, no REAPER integration |
| **Speedrum** | Lightweight, good presets | External plugin, less polished |

### Common Pain Points (from forum research)

1. **Performance**: Script-based UI tanks the DAW with many instances
2. **Routing Complexity**: Multi-out setup is confusing for beginners
3. **Missing Visual Feedback**: Knob values, sample names truncated, pitch not shown
4. **No Per-Pad Delay**: Critical for groove/swing timing
5. **Choke Groups**: Require workarounds with JSFX
6. **Velocity Layers**: Setup is complex (multiple RS5K instances per note)
7. **Round Robin**: Requires probability-based workarounds
8. **Note Range**: Fixed ranges don't match hardware controllers

### Highly Requested Features

- [ ] Sample delay per pad (groove timing)
- [ ] Double-click to open RS5K settings
- [ ] Cell/pad duplication with note increment
- [ ] Visible pitch shift values (semitones)
- [ ] Custom color schemes per pad
- [ ] Global note-off toggle
- [ ] Choke groups (hi-hat, cymbal)
- [ ] Velocity layer support
- [ ] Round robin support
- [ ] Explode to tracks for mixing
- [ ] Configurable note range (match controller)

---

## Key Decisions

### Decision 1: Backend Architecture

**Question**: What REAPER mechanism should power the drum rack?

**Options**:

| Option | Description | Trade-offs |
|--------|-------------|------------|
| **A) RS5K per child track** | Each pad = child track with RS5K | Best mixer integration, flexible routing, more tracks |
| **B) RS5K in FX containers** | All RS5K in containers on one track | Cleaner track list, REAPER 7+ only, harder multi-out |
| **C) Custom JSFX sampler** | Build our own sampler | Full control, huge effort, reinventing wheel |
| **D) External VST (Sitala)** | Rely on third-party plugin | Easy, but external dependency, limited API |

**Decision**: **Option A - RS5K per child track** (with smart UX to hide complexity)

**Rationale**:
- Best compatibility (works with REAPER 6+)
- Natural multi-out (each track = separate channel)
- Mixer integration (volume, pan, FX per pad)
- Full RS5K API access for all parameters
- Can add FX chains per pad easily
- **Per-pad automation lanes** - critical for mixing/arrangement workflows
- **Global FX on parent track** - bus processing for the whole kit

**Why not FX Containers?**

After research (Ableton/Bitwig forums, REAPER forums), we found:
- Users complaining about "track clutter" were really asking for **better UX**, not containers
- Container automation = all params on one track = nightmare to navigate with 16 pads
- Ableton's "Extract Chains" **loses automation** - we'd have the same problem
- Track clutter is **solvable with UI** (folder collapse, visibility toggles)
- Automation hell is **not solvable** - it's an architectural limit

**The insight**: Tracks are the right foundation. Hide the complexity with good UX.

**Hybrid approach**: Nothing prevents using FX Containers *within* pad tracks for:
- Velocity layers (Container with multiple RS5Ks)
- Parallel processing (Container with parallel routing)
- Complex per-pad FX chains

---

### Decision 2: State Management

**Question**: Where does the drum rack state live?

**Options**:

| Option | Description |
|--------|-------------|
| **A) Script state only** | State in Lua, sync to REAPER on changes |
| **B) REAPER as source of truth** | Read state from tracks/FX, UI reflects reality |
| **C) Hybrid** | Script state for UI, periodically sync with REAPER |

**Decision**: **Option B - REAPER as source of truth**

**Rationale**:
- No state sync bugs
- Works if user manually edits RS5K
- Survives script restart
- Undo/redo works naturally
- Use `TrackFX_GetNamedConfigurationValue` to read RS5K state

---

### Decision 3: Track Structure

**Question**: How should tracks be organized?

**Proposed Structure**:
```
📁 [DrumRack] My Kit (Parent - receives MIDI, applies Global FX)
│   └── 🎛️ Global FX Chain: Bus Comp → Tape Sat → Limiter
│
├── 🥁 Kick (Note 36) [RS5K → Transient → EQ]      ← Per-pad FX
├── 🥁 Snare (Note 38) [RS5K → Comp → Gate]        ← Per-pad FX
├── 🥁 HH Closed (Note 42) [RS5K]                   ← Minimal
├── 🥁 HH Open (Note 46) [RS5K → Container[Layers]] ← Advanced
└── ... (up to 16/32/128 pads)
```

**Signal Flow**:
```
[MIDI In] → [Parent Track] → routes MIDI to children
                ↓
[Pad Tracks] → each filters to its note, processes audio
                ↓
[Parent Track] ← receives summed audio (folder behavior)
                ↓
[Global FX] → Master/Hardware Out
```

**MIDI Routing**:
- Parent track receives all MIDI, armed for input
- Each child has RS5K filtering to its note
- Children receive MIDI from parent

**Audio Routing**:
- Each child outputs to parent (default folder behavior)
- Parent applies global FX to the sum
- OR direct hardware out for multi-out mixing

**Visibility Strategy** (solving "track clutter"):
- Folder **auto-collapsed** on creation
- User sees single "[DrumRack] Kit" in TCP
- **DrumRack UI** is the primary interaction point
- "Expand for Mixing" reveals children in MCP
- Per-pad visibility toggles (TCP/MCP independent)

---

### Decision 4: UI Approach

**Question**: How should the UI integrate with the backend?

**Decision**: Decouple UI from backend operations

```
┌─────────────────────────────────────────┐
│  Blocks Drum Rack UI (Ark.Grid)         │
│  - Visual pad grid                       │
│  - Drag-drop from ItemPicker            │
│  - Knob controls for quick edits        │
└──────────────────┬──────────────────────┘
                   │ Actions
                   ▼
┌─────────────────────────────────────────┐
│  Drum Rack Backend (rs5k_manager.lua)   │
│  - Create/delete pads (tracks + RS5K)   │
│  - Load samples                          │
│  - Read/write RS5K parameters           │
│  - Handle choke groups                   │
└──────────────────┬──────────────────────┘
                   │ REAPER API
                   ▼
┌─────────────────────────────────────────┐
│  REAPER (tracks, FX, RS5K instances)    │
└─────────────────────────────────────────┘
```

---

### Decision 4b: Visibility & UX Tools

**Question**: How do we solve "track clutter" while keeping track-based architecture?

**Core Principle**: Tracks are the foundation, but DrumRack UI hides the complexity.

**Visibility Tools**:

| Tool | Action | Use Case |
|------|--------|----------|
| **Collapse Kit** | Folder collapse in TCP | Default view, tidy session |
| **Expand for Mixing** | Show children in MCP | Per-pad mixing session |
| **Show in TCP** | Per-pad toggle | Focus on specific pads |
| **Show in MCP** | Per-pad toggle | Mixer-only visibility |
| **Focus Automation** | Opens pad's envelope lane | Quick automation access |
| **Hide All** | Remove from TCP/MCP | Maximum cleanliness |

**Right-Click Pad Menu**:
```
├── Edit Pad FX Chain...     → Opens REAPER FX window
├── Edit Global FX...        → Opens parent track FX
├── ─────────────────
├── Show in Mixer            ✓
├── Show in Arrange
├── Show Automation      ►   [Volume] [Pan] [RS5K Params...]
├── ─────────────────
├── Duplicate Pad
├── Clear Pad
└── Delete Pad Track
```

**Kit-Level Controls**:
```
┌─────────────────────────────────────────────┐
│ 🥁 Drum Rack: "808 Kit"        [≡] [⚙️]    │
├─────────────────────────────────────────────┤
│ 👁️ View: [Compact] [Mixer] [Arrange] [All] │
│ 🎛️ Global FX: [Edit...] [Bypass]            │
│ 📁 Kit: [Save...] [Load...] [New]           │
└─────────────────────────────────────────────┘
```

**User Personas Served**:
- **Beatmaker**: Compact view, just sees DrumRack UI, no track clutter
- **Mixer**: Mixer view, per-pad faders visible in MCP
- **Arranger**: Arrange view, per-pad tracks for automation
- **Power user**: All view, full access to everything

---

### Decision 5: Choke Groups

**Question**: How to implement choke groups (e.g., open hi-hat silences closed hi-hat)?

**Options**:

| Option | Description |
|--------|-------------|
| **A) JSFX choke handler** | MIDI filter that sends note-off to choke targets |
| **B) RS5K "Obey note-offs" + script** | Script sends note-off before trigger |
| **C) Dedicated choke track** | Separate track with choke logic |

**Decision**: **Option A - JSFX choke handler** (like MPL)

**Rationale**:
- Proven approach
- Low latency (runs in audio thread)
- Configurable choke groups
- No script overhead during playback

---

### Decision 6: Velocity Layers

**Question**: How to support multiple samples per note (velocity layers)?

**Decision**: Multiple RS5K instances per pad track

```
📁 Snare (Note 38)
├── RS5K (vel 0-50) - soft.wav
├── RS5K (vel 51-100) - medium.wav
└── RS5K (vel 101-127) - hard.wav
```

- Use RS5K params 17-18 (min/max velocity)
- UI shows layer count badge
- "Add Layer" action in context menu

---

## Open Questions

1. **Round Robin**: Use probability-based approach or custom JSFX?
2. **Sample Preview**: Direct preview or through RS5K instance?
3. **Kit Persistence**: Save as REAPER track template or custom format?
4. **Max Pads**: 16 (classic) or 128 (full MIDI range)?
5. **Controller Integration**: MIDI learn for pad triggers?

---

## Competitive Analysis (Extended)

### Grading Summary

| Aspect | RS5K Manager (MPL) | ReaDrum Machine | Our Target |
|--------|-------------------|-----------------|------------|
| **Overall** | C+ (73/100) | C (70/100) | A- (90+) |
| **Architecture** | D+ (60) - Heavy globals | C- (65) - Modular but globals | A (95) - ARKITEKT patterns |
| **Performance** | D - Laggy knobs, slow loading | C - Undo point spam | A - Per-frame caching |
| **UX** | C - Complex, hidden values | C+ - Cleaner but limited | A - Visual, intuitive |
| **Reliability** | C - Many reported bugs | B- - Fewer issues | A - Robust error handling |

### Specific Bugs to Avoid

**From RS5K Manager:**
- ❌ Clicking M button + scrolling crashes script
- ❌ Double-clicking Freq/Gain/Drive → nil value error
- ❌ Drag-drop second sample → arithmetic on nil
- ❌ Laggy knobs (jumps between values, no fine control)
- ❌ Release knob range doesn't reach 100%
- ❌ Docking position not remembered

**From ReaDrum Machine:**
- ❌ Generates undo points on playback (can't prevent)
- ❌ Parallel FX volume summing confuses users
- ❌ 6+ dependencies required
- ❌ Only 4x4 grid, no layout options

### What Users Actually Say

> "RS5K is krusty and in need of TLC"
> "Leaves a lot to be desired"
> "Actually feels like Reaper has a real native drum sampler" (what they WANT)
> "Clone of Ableton drum racks" (the dream)

### Key Architectural Anti-Patterns to Avoid

```lua
-- ❌ MPL Pattern (BAD)
DATA = { upd = true, scheduler = {}, ... }  -- Massive global
EXT = { viewport_posX = 10, ... }           -- Another global
UI = { font = 'Arial', ... }                -- And another
ctx  -- Global ImGui context

-- ❌ ReaDrum Pattern (BETTER but still globals)
TRACK = nil
SELECTED = {}
Pad = {}

-- ✅ ARKITEKT Pattern (IDEAL)
local M = {}
local State = require('drumrack.state')
function M.new(opts) return { ... } end
return M
```

---

## References

- [MPL RS5K Manager Forum Thread](https://forum.cockos.com/showthread.php?t=207971)
- [ReaDrum Machine Forum Thread](https://forum.cockos.com/showthread.php?t=284566)
- [RS5K Velocity & Round Robin Tutorial](https://reaper.blog/2018/11/rs5k-velocity-round-robin/)
- [Drum Racks in REAPER (ReaperTips)](https://www.reapertips.com/post/drum-racks-in-reaper)

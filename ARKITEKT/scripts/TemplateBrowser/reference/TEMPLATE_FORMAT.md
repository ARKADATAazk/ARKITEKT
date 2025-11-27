# REAPER Track Template Format (.RTrackTemplate)

## Overview

Track templates are RPP (REAPER Project) chunk format files containing one or more `<TRACK>` blocks.
They define track configurations including name, color, routing, and FX chains.

## Track Structure

```
<TRACK
  NAME "Track Name"
  PEAKCOL 21403218        # Track color (decimal)
  ISBUS 1 1               # Folder structure (see below)
  TRACKID {GUID}          # Unique identifier
  ...settings...
  <FXCHAIN
    <VST "VSTi: Plugin" file.dll 0 "">
    <JS path/script.jsfx "">
  >
>
```

## Key Fields

### Track Metadata
| Field | Type | Description |
|-------|------|-------------|
| `NAME` | string | Display name (quoted) |
| `PEAKCOL` | integer | Track color as decimal COLORREF |
| `TRACKID` | GUID | Unique identifier `{xxxxxxxx-xxxx-...}` |
| `ISBUS` | `X Y` | Folder structure control |

### ISBUS (Folder Structure)

The `ISBUS X Y` field controls folder hierarchy:

| Pattern | Meaning |
|---------|---------|
| `ISBUS 1 1` | Folder track (opens folder, depth +1) |
| `ISBUS 0 0` | Regular track (no depth change) |
| `ISBUS 1 -1` | Last child (closes 1 folder) |
| `ISBUS 2 -2` | Last child (closes 2 folders) |
| `ISBUS N -N` | Last child (closes N folders) |

**Parsing algorithm:**
```lua
local depth = 0
local tracks = {}

for each <TRACK> block:
  local name = parse NAME
  local isbus_x, isbus_y = parse ISBUS (default 0, 0)

  -- Track's display depth
  local track_depth = depth

  -- Folder opening happens AFTER we record this track's depth
  if isbus_y > 0 then
    track.is_folder = true
    depth = depth + isbus_y
  elseif isbus_y < 0 then
    -- Closing happens, but track is still AT current depth
    -- Apply close AFTER recording
  end

  track.depth = track_depth
  tracks[#tracks + 1] = track

  -- Apply folder closing after recording track
  if isbus_y < 0 then
    depth = depth + isbus_y  -- Y is negative
  end
```

### FX Chain Patterns

| Pattern | Type | Example |
|---------|------|---------|
| `<VST "VST: Name"` | VST2 effect | `<VST "VST: ReaEQ"` |
| `<VST "VSTi: Name"` | VST2 instrument | `<VST "VSTi: Kontakt"` |
| `<VST "VST3: Name"` | VST3 plugin | `<VST "VST3: Pro-Q 3"` |
| `<JS path/file.jsfx` | JSFX script | `<JS utility/volume.jsfx` |
| `<CLAP "CLAPi: Name"` | CLAP plugin | `<CLAP "CLAPi: Surge XT"` |
| `<AU "AU: Name"` | AudioUnit | `<AU "AU: AUSampler"` |
| `PRESETNAME "name"` | FX preset | `PRESETNAME "CSS Violins"` |

---

## Example Templates

### Flat Template (5 tracks, no folders)
```
Strings Ensemble:
├ VI-M: ST-VN2 (Kontakt, Reaticulate)
├ VI-M: ST-VN1 (Kontakt, Reaticulate)
├ VI-M: ST-VA (Kontakt, Reaticulate)
├ VI-M: ST-VC (Kontakt, Reaticulate)
└ VI-M: ST-B (Kontakt, Reaticulate)

All tracks: ISBUS 0 0
Total: 5T, 15 FX
```

### Nested Folders Template (6 tracks, 2 folders)
```
▼ ADADAD (ISBUS 1 1)
  ▼ 235 (ISBUS 1 1)
    ├ ED (ISBUS 0 0)
    ├ OLO (ISBUS 0 0)
    └ AD (ISBUS 2 -2) ← closes both folders
ZDZ (ISBUS 0 0)

Total: 6T
```

---

## Display Model

### Tile Badge
- **Track count**: `6T` (total tracks including folders)
- **FX count**: `15 FX` (total unique FX)

### Stacked Visual
- Multi-track templates (>1 track): show 3-4 offset layers
- Same visual regardless of folder structure

### Hover Preview (indented hierarchy)
```
▼ ADADAD
  ▼ 235
    ├ ED
    ├ OLO
    └ AD
ZDZ
```

---

## Lua Data Model

```lua
-- Parsed template structure
local template = {
  path = "/path/to/template.RTrackTemplate",
  name = "Template Name",  -- from filename

  -- Parsed content
  track_count = 6,
  tracks = {
    { name = "ADADAD", depth = 0, is_folder = true, fx = {} },
    { name = "235", depth = 1, is_folder = true, fx = {} },
    { name = "ED", depth = 2, is_folder = false, fx = {"Kontakt"} },
    { name = "OLO", depth = 2, is_folder = false, fx = {"Kontakt"} },
    { name = "AD", depth = 2, is_folder = false, fx = {"Kontakt"} },
    { name = "ZDZ", depth = 0, is_folder = false, fx = {} },
  },

  -- Aggregated for display
  fx = {"Kontakt"},  -- unique FX list (flat)
  fx_count = 3,      -- total FX instances
}
```

---

## Parsing Functions

### Count Tracks (simple)
```lua
function count_tracks(filepath)
  local count = 0
  for line in io.lines(filepath) do
    if line:match("^<TRACK") then
      count = count + 1
    end
  end
  return count
end
```

### Parse Track Tree (with hierarchy)
```lua
function parse_track_tree(filepath)
  local tracks = {}
  local depth = 0
  local current_track = nil

  for line in io.lines(filepath) do
    if line:match("^<TRACK") then
      current_track = { name = nil, depth = depth, is_folder = false, fx = {} }
      tracks[#tracks + 1] = current_track
    elseif current_track then
      -- Parse NAME
      local name = line:match('^%s*NAME%s+"([^"]+)"')
      if name then current_track.name = name end

      -- Parse ISBUS
      local isbus_x, isbus_y = line:match('^%s*ISBUS%s+(%d+)%s+(%-?%d+)')
      if isbus_y then
        isbus_y = tonumber(isbus_y)
        if isbus_y > 0 then
          current_track.is_folder = true
          depth = depth + isbus_y
        elseif isbus_y < 0 then
          depth = depth + isbus_y
        end
      end

      -- Parse FX (existing parser logic)
      local fx_name = extract_fx_name(line)
      if fx_name then
        current_track.fx[#current_track.fx + 1] = fx_name
      end
    end

    -- Track block ends
    if line:match("^>") and current_track then
      current_track = nil
    end
  end

  return tracks
end
```

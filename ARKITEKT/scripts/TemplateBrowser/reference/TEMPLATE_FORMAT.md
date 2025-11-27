# REAPER Track Template Format (.RTrackTemplate)

## Overview

Track templates are RPP (REAPER Project) chunk format files containing one or more `<TRACK>` blocks.

## Structure

```
<TRACK
  NAME "Track Name"
  PEAKCOL 21403218        # Track color (decimal COLORREF)
  ...track settings...
  <FXCHAIN
    ...fx chain settings...
    <VST "VST: PluginName" plugin.dll 0 "" ...>
      ...base64 encoded state...
    >
    <JS path/to/script.jsfx ""
      ...script parameters...
    >
  >
>
<TRACK
  ...next track...
>
```

## Key Fields for TemplateBrowser

### Track Level
| Field | Description | Example |
|-------|-------------|---------|
| `NAME` | Track display name | `"VI-M: ST-VN1"` |
| `PEAKCOL` | Track color as decimal | `21403218` |
| `TRACKID` | Unique GUID | `{9F7535ED-3EFA-...}` |
| `ISBUS` | Folder track indicator | `0 0` (not folder) |

### FX Chain
| Pattern | Type | Example |
|---------|------|---------|
| `<VST "VST: Name"` | VST2 plugin | `<VST "VST: ReaControlMIDI"` |
| `<VST "VSTi: Name"` | VST2 instrument | `<VST "VSTi: Kontakt (Native Instruments)"` |
| `<VST "VST3: Name"` | VST3 plugin | `<VST "VST3: Pro-Q 3"` |
| `<JS path/file.jsfx` | JSFX script | `<JS Reaticulate/jsfx/Reaticulate.jsfx` |
| `<CLAP "CLAPi: Name"` | CLAP plugin | `<CLAP "CLAPi: Surge XT"` |
| `<AU "AU: Name"` | AudioUnit (macOS) | `<AU "AU: AUSampler"` |
| `PRESETNAME` | FX preset name | `PRESETNAME "CSS 1st Violins"` |

## Parsing Strategy

### Track Count
```lua
local track_count = 0
for line in file:lines() do
  if line:match("^<TRACK") then
    track_count = track_count + 1
  end
end
```

### Track Names (for hover preview)
```lua
local tracks = {}
for line in file:lines() do
  local name = line:match('^%s*NAME%s+"([^"]+)"')
  if name then
    tracks[#tracks + 1] = name
  end
end
```

### FX Per Track
Need to track which `<TRACK>` block we're in:
```lua
local current_track = nil
local tracks = {}

for line in file:lines() do
  if line:match("^<TRACK") then
    current_track = { name = nil, fx = {} }
    tracks[#tracks + 1] = current_track
  elseif current_track then
    local name = line:match('^%s*NAME%s+"([^"]+)"')
    if name then
      current_track.name = name
    end
    -- Parse FX within current track's FXCHAIN
    local fx_name = extract_fx_name(line)
    if fx_name then
      current_track.fx[#current_track.fx + 1] = fx_name
    end
  end
end
```

## Example Analysis

**File**: `example_strings_template.RTrackTemplate`

| Track | Name | Color | FX |
|-------|------|-------|-----|
| 1 | VI-M: ST-VN2 | 21403218 | ReaControlMIDI, Reaticulate, Kontakt |
| 2 | VI-M: ST-VN1 | 21403218 | ReaControlMIDI, Reaticulate, Kontakt |
| 3 | VI-M: ST-VA | 30112323 | ReaControlMIDI, Reaticulate, Kontakt |
| 4 | VI-M: ST-VC | 31683967 | ReaControlMIDI, Reaticulate, Kontakt |
| 5 | VI-M: ST-B | 21909988 | ReaControlMIDI, Reaticulate, Kontakt |

**Summary**: 5 tracks, 15 total FX (3 per track), all using Kontakt

## Display Recommendations

- **Track Badge**: `5T` - total track count (simple, includes folders)
- **FX Badge**: `15 FX` or show primary plugin
- **Stacked Visual**: Max 3-4 offset layers for multi-track templates (regardless of folder structure)
- **Hover Preview** (with indentation for folders):
  ```
  ▼ Strings
    ├ VI-M: ST-VN2 (3 FX)
    ├ VI-M: ST-VN1 (3 FX)
    ├ VI-M: ST-VA (3 FX)
    ├ VI-M: ST-VC (3 FX)
    └ VI-M: ST-B (3 FX)
  ```

## Folder Track Format

Folder tracks use `ISBUS` field:
```
ISBUS 1 1    # Folder start
ISBUS 0 0    # Regular track (child)
ISBUS 1 -1   # Last child (closes folder)
ISBUS 2 -1   # Closes nested folder (depth 2)
```

Parsing hierarchy requires tracking depth as you iterate through tracks.

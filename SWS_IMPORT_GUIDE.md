# SWS Region Playlist Import Guide

## Overview

The ARK Region Playlist system can import playlists from the SWS Region Playlist extension. This document explains how the conversion works and the technical details behind the import process.

---

## Storage Comparison

### SWS Storage (C++ Extension)
- **Location**: Custom tags directly in `.RPP` project file
- **Format**: Plain text with custom parser
- **Method**: `project_config_extension_t` API

```
<S&M_RGN_PLAYLIST "Playlist Name" 1
123 2
456 1
789 -1
>
```

### ARK Storage (Lua ExtState)
- **Location**: `<PROJEXTSTATE>` section in `.RPP` project file
- **Format**: JSON (managed by REAPER API)
- **Method**: `reaper.SetProjExtState()` / `reaper.GetProjExtState()`

```json
{
  "id": "Main",
  "name": "Main",
  "items": [
    {"type": "region", "rid": 5, "reps": 2, "enabled": true, "key": "item_5_..."},
    {"type": "region", "rid": 7, "reps": 1, "enabled": true, "key": "item_7_..."}
  ],
  "chip_color": 4289655552
}
```

---

## Data Structure Comparison

| Field | SWS | ARK | Conversion |
|-------|-----|-----|------------|
| **Playlist Name** | `"Name"` in header | `name` string | Direct copy |
| **Active Flag** | `0` or `1` after name | Saved separately in ExtState | Used to set `active_playlist` |
| **Region ID** | Internal `m_rgnId` (int) | Region number `rid` (int) | **Complex conversion** ⚠️ |
| **Loop Count** | `m_cnt` (positive/negative/zero) | `reps` (positive only) | See loop conversion below |
| **Item Type** | N/A (regions only) | `"region"` or `"playlist"` | Always `"region"` |
| **Enabled State** | N/A | `enabled` (bool) | Always `true` |
| **Item Key** | N/A | `key` (string) | Generated unique ID |
| **Chip Color** | N/A | `chip_color` (rgba int) | Generated random color |

---

## Critical Conversion: Region ID Mapping

### The Problem

SWS stores **internal REAPER marker/region IDs** (`markrgnindexnumber`), which are:
- Assigned by REAPER when marker/region is created
- **NOT sequential** (e.g., could be 5, 12, 27, 103...)
- **NOT the display number** shown in REAPER UI

ARK stores **region numbers** (1-based sequential display numbers):
- Region 1, Region 2, Region 3, etc.
- What users see in the UI
- What `GoToRegion()` expects

### The Solution

```lua
function get_region_number_from_sws_id(sws_rgn_id)
  -- 1. Enumerate all project markers/regions
  local idx = 0
  while idx < reaper.CountProjectMarkers(0) do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber = 
      reaper.EnumProjectMarkers(idx)
    
    if retval > 0 and isrgn then
      -- 2. Find the one with matching internal ID
      if markrgnindexnumber == sws_rgn_id then
        -- 3. Count how many regions came before it
        local region_num = 0
        for i = 0, idx do
          local ret, is_rgn = reaper.EnumProjectMarkers(i)
          if ret > 0 and is_rgn then
            region_num = region_num + 1
          end
        end
        return region_num  -- This is the display number!
      end
    end
    idx = idx + 1
  end
  
  return nil  -- Region not found (deleted)
end
```

### Example Mapping

Project state:
```
Marker 1      (internal ID: 5)
Region 1      (internal ID: 12)  ← Display number = 1
Marker 2      (internal ID: 19)
Region 2      (internal ID: 27)  ← Display number = 2
Region 3      (internal ID: 103) ← Display number = 3
```

SWS stores: `12`, `27`, `103`  
ARK needs: `1`, `2`, `3`

---

## Loop Count Conversion

### SWS Loop Count Values

| SWS Value | Meaning | ARK Conversion |
|-----------|---------|----------------|
| `cnt > 0` | Play N times | `reps = cnt` (direct copy) |
| `cnt < 0` | Infinite loop ∞ | `reps = 999` (pseudo-infinite) |
| `cnt = 0` | Invalid/skip | Item skipped |

### Why 999 Instead of -1?

ARK uses positive integers for loop counts. While we could use `-1` to indicate infinity, using `999` is:
- More compatible with existing ARK logic
- Effectively infinite for practical purposes
- Clearer in the UI (shows "999" instead of special infinity symbol)
- Easier to modify if user wants to change it

The importer **reports** how many infinite loops were converted, so users are aware.

---

## Import Process Flow

```
┌─────────────────────────────────────┐
│ 1. Read Project File (.RPP)        │
│    - Get project path from REAPER   │
│    - Open file and read all lines   │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│ 2. Parse SWS Sections               │
│    - Find <S&M_RGN_PLAYLIST tags    │
│    - Extract playlist name & active │
│    - Parse item lines (ID + count)  │
│    - Continue until '>' end tag     │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│ 3. Convert Each Playlist            │
│    For each SWS playlist:           │
│    ├─ Create ARK playlist structure │
│    ├─ Generate random chip color    │
│    └─ For each item:                │
│        ├─ Convert region ID → num   │
│        ├─ Convert loop count        │
│        ├─ Generate unique key       │
│        └─ Create ARK item object    │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│ 4. Generate Report                  │
│    - Count successful conversions   │
│    - Count skipped items            │
│    - Track infinite loops           │
│    - Note active playlist           │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│ 5. Backup Current State (Optional)  │
│    - Save existing ARK playlists to │
│      ExtState backup key            │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│ 6. Save to Project                  │
│    Mode: Replace or Merge           │
│    ├─ Replace: Overwrite all        │
│    └─ Merge: Append to existing     │
│    - Save via RegionState.save()    │
│    - Set active playlist            │
└─────────────────────────────────────┘
```

---

## Error Handling & Edge Cases

### 1. **Project Not Saved**
```lua
if proj_path == "" or proj_name == "" then
  return nil, "No project file found (project not saved)"
end
```
**User Action**: Save project first

### 2. **No SWS Playlists Found**
```lua
if #sws_playlists == 0 then
  return false, nil, "No SWS Region Playlists found in project"
end
```
**User Action**: Nothing to import

### 3. **Region Deleted**
```lua
local region_num = get_region_number_from_sws_id(sws_item.sws_rgn_id)
if not region_num then
  -- Skip this item
  report.skipped_items = report.skipped_items + 1
end
```
**Result**: Item skipped, counted in report

### 4. **Invalid Loop Count**
```lua
if reps == 0 then
  -- Skip invalid item
  report.skipped_items = report.skipped_items + 1
  goto continue
end
```
**Result**: Item skipped

### 5. **Empty Playlist After Conversion**
```lua
if #ark_playlist.items == 0 then
  -- Don't add this playlist
  -- All regions were deleted or invalid
end
```
**Result**: Playlist not created

---

## Import Modes

### Replace Mode (Default)
```lua
SWSImporter.execute_import(false, true)
```
- **Deletes** all existing ARK playlists
- **Replaces** with imported SWS playlists
- **Use when**: Fresh start, SWS is source of truth

### Merge Mode
```lua
SWSImporter.execute_import(true, true)
```
- **Keeps** existing ARK playlists
- **Appends** imported SWS playlists
- **Use when**: Want both ARK and SWS playlists

---

## Import Report Format

```
SWS Playlists Found: 3
ARK Playlists Created: 3

Total Items: 15
Converted: 13
Skipped: 2 (regions not found)
Infinite loops converted to 999 reps: 1

Per Playlist:
  1. "Main": 5/5 items
  2. "Intro/Outro": 4/5 items  ← 1 item skipped
  3. "Verses": 4/5 items       ← 1 item skipped
```

---

## API Reference

### Main Functions

#### `M.has_sws_playlists()`
Quick check if project contains SWS playlists.

**Returns**: `boolean`

**Example**:
```lua
if SWSImporter.has_sws_playlists() then
  -- Show import button
end
```

#### `M.execute_import(merge_mode, backup)`
Execute complete import process.

**Parameters**:
- `merge_mode` (boolean): `false` = replace, `true` = merge. Default: `false`
- `backup` (boolean): Create backup before import. Default: `true`

**Returns**: `success (bool), report (table), error_msg (string)`

**Example**:
```lua
local success, report, err = SWSImporter.execute_import(false, true)
if success then
  print(SWSImporter.format_report(report))
else
  print("Error:", err)
end
```

#### `M.format_report(report)`
Format import report as human-readable string.

**Parameters**:
- `report` (table): Report from `execute_import()`

**Returns**: `string`

---

## Implementation Notes

### Why Parse RPP File Directly?

1. **SWS data not accessible via REAPER API**
   - No ExtState key to read
   - Custom C++ serialization format

2. **RPP file is plain text**
   - Easy to parse with Lua pattern matching
   - Reliable and fast

3. **Alternative would require SWS API**
   - Would add dependency on SWS
   - Users might not have SWS installed
   - This way works even after SWS uninstalled

### Thread Safety

Import reads file **synchronously** in main thread:
- No async I/O needed (RPP files are small)
- No risk of file changes during read
- REAPER doesn't support background file I/O

### Memory Considerations

For typical projects (< 100 regions, < 10 playlists):
- RPP file: ~1-10 MB
- Parsed lines: ~100-1000 strings
- Converted data: < 100 KB

**No memory concerns** for normal usage.

---

## Limitations & Known Issues

### 1. **Nested Playlists Not Supported**
SWS doesn't support nested playlists, so this isn't an issue.
ARK's nested playlist feature is a superset.

### 2. **Infinite Loops → 999 Reps**
Users who relied on true infinite loops need to know this.
Workaround: Manually edit to larger value if needed.

### 3. **Colors Not Preserved**
SWS uses grayscale region colors.
ARK generates random vibrant colors for visual distinction.

### 4. **No Undo for Import**
Import operation creates ExtState backup but doesn't create REAPER undo point.
Workaround: Backup is automatic, can restore manually if needed.

### 5. **Project Must Be Saved**
Can't import from unsaved projects (no file to read).
This is a REAPER limitation, not importer limitation.

---

## Testing Checklist

- [ ] Import with no SWS playlists (should fail gracefully)
- [ ] Import with deleted regions (should skip and report)
- [ ] Import with infinite loops (should convert to 999)
- [ ] Import with multiple playlists (should preserve all)
- [ ] Import with active playlist marked (should set active)
- [ ] Replace mode (should clear existing)
- [ ] Merge mode (should append)
- [ ] Backup creation (should create before import)
- [ ] Unsaved project (should show error)

---

## Future Enhancements

### Potential Improvements

1. **Import from external RPP file**
   ```lua
   M.import_from_file(filepath, merge_mode)
   ```
   Useful for importing playlists from other projects.

2. **Export to SWS format**
   ```lua
   M.export_to_sws_format(ark_playlists)
   ```
   For users who want to go back to SWS.

3. **Preview before import**
   ```lua
   local preview = M.preview_import()
   -- Show UI with what will be imported
   ```

4. **Selective import**
   ```lua
   M.import_specific_playlists({1, 3, 5})
   ```
   Choose which SWS playlists to import.

5. **Conflict resolution**
   Ask user what to do when ARK playlist names match SWS names.

---

## Conclusion

The SWS importer provides a **one-way upgrade path** from SWS Region Playlist to ARK Region Playlist. The conversion is:

✅ **Safe** - Automatic backup before import  
✅ **Smart** - Handles deleted regions gracefully  
✅ **Accurate** - Correct region ID mapping  
✅ **Transparent** - Detailed reporting  
✅ **Flexible** - Replace or merge modes  

ARK's feature set is a **superset** of SWS (nested playlists, enable/disable, playlist items), so users only gain functionality, never lose it.

# ItemPicker Performance Optimization

This document records the performance optimization journey for the ItemPicker grid rendering system. Starting from ~360ms per frame down to ~50-60ms (roughly 6x improvement).

## Context

ItemPicker displays grids of audio and MIDI items with:
- Animated tiles (hover, selection, mute/disable states)
- Waveform visualization for audio items
- Piano roll visualization for MIDI items
- Text labels with truncation
- Cycle badges (N/M indicators)
- Region tags, duration text, favorite stars

With 500+ items in compact mode, FPS was dropping to ~20fps.

---

## Phase 1: Profiling Infrastructure

Added inline profilers to both renderers to identify bottlenecks:

**audio.lua / midi.lua:**
```lua
local _profile = {
  animator = 0, color = 0, draw_base = 0, wave = 0,
  header = 0, ants = 0, text_badges = 0, count = 0, last_report = 0,
}

-- Timing markers throughout render function
local t0 = reaper.time_precise()
-- ... animator code ...
local t1 = reaper.time_precise()
-- ... etc ...

-- Report every second
if t7 - _profile.last_report > 1.0 then
  reaper.ShowConsoleMsg(string.format(
    "[PROFILE] %d tiles | anim:%.0fms | color:%.0fms | ...",
    _profile.count, _profile.animator * 1000, ...
  ))
end
```

**Initial findings (~360ms total):**
- Animator: ~95ms
- Text/badges: ~200ms
- Waveform/MIDI: ~50ms (spikes to 200ms+ during resize)

---

## Phase 2: Animator Optimization

### Problem
TileAnimator was calling `track()` and `get()` separately for each animation track, even when tiles were idle (not animating).

### Solution 1: Combined track_get() method

**arkitekt/gui/animation/tile_animator.lua:**
```lua
-- OPTIMIZATION: Combined track + get in one call (reduces lookups from 2 to 1 per track)
function TileAnimator:track_get(tile_id, track_name, target, speed)
  speed = speed or self.default_speed
  local tile_tracks = self.tracks[tile_id]
  if not tile_tracks then
    tile_tracks = {}
    self.tracks[tile_id] = tile_tracks
  end
  local t = tile_tracks[track_name]
  if not t then
    t = Track.new(target, speed)
    tile_tracks[track_name] = t
    return target  -- New track starts at target
  else
    if t.target ~= target then
      t.target = target
      self.active_tiles[tile_id] = true
    end
    if t.speed ~= speed then
      t.speed = speed
    end
    return t.current
  end
end
```

### Solution 2: Settled tile state cache

Skip animator entirely when tile state is unchanged AND all animations have reached their targets.

**audio.lua / midi.lua:**
```lua
local _tile_state_cache = {}
-- Key: tile_key, Value: { hover, disabled, muted, compact, hover_f, enabled_f, muted_f, compact_f, settled }

-- In render:
local cached = _tile_state_cache[key]
if cached and cached.settled
   and cached.hover == is_hover
   and cached.disabled == is_disabled
   and cached.muted == is_muted
   and cached.compact == is_small_tile then
  -- Use cached values directly - skip animator entirely
  hover_factor = cached.hover_f
  enabled_factor = cached.enabled_f
  -- ...
else
  -- Use animator and update cache
  hover_factor = animator:track_get(key, 'hover', is_hover and 1.0 or 0.0, speed)
  -- ...

  -- Check if settled (all animations at target)
  local settled = (hover_factor == hover_target) and (enabled_factor == enabled_target) and ...

  _tile_state_cache[key] = { ..., settled = settled }
end
```

**Result:** Animator time reduced from ~95ms to ~35-50ms (~50% improvement)

---

## Phase 3: Animation Throttling for Resize

### Problem
During window/tile resize, waveform and MIDI thumbnails were regenerated continuously, causing massive spikes (200-300ms).

### Solution
Skip job queue processing entirely while grid tiles are animating. Thumbnails generated during resize would be wrong size anyway.

**arkitekt/gui/animation/tracks.lua:**
```lua
-- Added to RectTrack
function RectTrack:is_animating()
  for id, r in pairs(self.rects) do
    if not r.settled then
      return true
    end
  end
  return false
end
```

**arkitekt/gui/widgets/containers/grid/core.lua:**
```lua
-- Added to grid result
return {
  -- ...
  is_animating = grid.rect_track:is_animating(),
  -- ...
}
```

**scripts/ItemPicker/ui/grids/coordinator.lua:**
```lua
function Coordinator:is_animating()
  local audio_result = self.audio_grid_result_ref and self.audio_grid_result_ref.current
  local midi_result = self.midi_grid_result_ref and self.midi_grid_result_ref.current
  return (audio_result and audio_result.is_animating) or (midi_result and midi_result.is_animating)
end
```

**scripts/ItemPicker/ui/init.lua:**
```lua
local is_animating = self.coordinator and self.coordinator:is_animating()

if is_animating then
  -- Skip job processing while tiles are animating
  self.state.job_queue.max_per_frame = 0
elseif self.state.is_loading then
  self.state.job_queue.max_per_frame = 20
else
  self.state.job_queue.max_per_frame = 5
end
```

**Result:** Eliminated 200-300ms spikes during resize. Thumbnails regenerate once animation settles.

---

## Phase 4: MIDI Visualization LOD

### Problem
MIDI visualization draws each note as a separate `DrawList_AddRectFilled` call. Items with many notes = thousands of draw calls.

### Solution
Level of Detail (LOD) - skip notes smaller than 1 pixel in either dimension.

**scripts/ItemPicker/ui/visualization.lua:**
```lua
local MIDI_MIN_NOTE_WIDTH = 1.0
local MIDI_MIN_NOTE_HEIGHT = 1.0

function M.DisplayMidiItemTransparent(ctx, thumbnail, color, draw_list)
  -- ...

  -- LOD: Calculate minimum note size thresholds in cache coordinates
  local min_width_cache = MIDI_MIN_NOTE_WIDTH / scale_x
  local min_height_cache = MIDI_MIN_NOTE_HEIGHT / scale_y

  for i = 1, num_notes do
    local note = thumbnail[i]

    -- LOD: Skip notes that are too small to see
    local note_w = note.x2 - note.x1
    local note_h = note.y2 - note.y1
    if note_w >= min_width_cache and note_h >= min_height_cache then
      -- Draw note
      DrawList_AddRectFilled(draw_list, note_x1, note_y1, note_x2, note_y2, col_note)
    end
  end
end
```

**Result:** MIDI rendering reduced from ~108ms to ~16-70ms depending on tile size (small tiles skip more notes).

---

## Phase 5: Text Rendering Inlining

### Problem
Text rendering was the biggest remaining cost (~40-60ms). Each tile was doing:
- `Ark.Colors.with_alpha()` - 3 table lookups + function call
- `Ark.Draw.text()` - 3 table lookups + function call + 2x snap calls
- Multiple `ImGui.*` calls with table lookups

### Solution
Localize functions at module level and inline hot-path operations.

**scripts/ItemPicker/ui/grids/renderers/base.lua:**
```lua
-- PERF: Localize frequently used functions to avoid table lookups in hot paths
local DrawList_AddText = ImGui.DrawList_AddText
local DrawList_AddRectFilled = ImGui.DrawList_AddRectFilled
local DrawList_AddRect = ImGui.DrawList_AddRect
local SetCursorScreenPos = ImGui.SetCursorScreenPos
local InvisibleButton = ImGui.InvisibleButton
local IsItemClicked = ImGui.IsItemClicked
local floor = math.floor

-- PERF: Inline pixel snapping (avoids function call overhead)
local function snap(x)
  return (x + 0.5) // 1
end

-- PERF: Inline with_alpha (avoids Ark.Colors.with_alpha function call)
local function with_alpha(color, alpha)
  return (color & 0xFFFFFF00) | (alpha & 0xFF)
end

-- In render_tile_text:
-- Before: Ark.Draw.text(dl, text_x, text_y, Ark.Colors.with_alpha(color, alpha), text)
-- After:
DrawList_AddText(dl, snap(text_x), snap(text_y), with_alpha(final_text_color, text_alpha), truncated_name or "")
```

### Why inlining helps in Lua

Each `.` access is a hash table lookup:
- `Ark.Colors.with_alpha` = 3 lookups (Ark in globals, Colors in Ark, with_alpha in Colors)
- Multiply by 5000 tiles = 15,000+ table lookups eliminated

Local variables in Lua are register-like - much faster than globals or table accesses.

**Result:** Text rendering reduced from ~40-60ms to ~18-26ms (~50% improvement)

---

## Phase 6: Truncated Text Caching

### Already implemented
Text truncation uses binary search and caches results by item key + width.

**base.lua:**
```lua
local width_key = ((available_width + 1) // 2) * 2  -- Round to 2px to reduce cache misses

if truncated_text_cache and item_key then
  local cached = truncated_text_cache[item_key]
  if cached and cached.name == item_name and cached.width == width_key then
    truncated_name = cached.truncated  -- Cache hit
  else
    truncated_name = M.truncate_text(ctx, item_name, available_width)
    truncated_text_cache[item_key] = { name = item_name, width = width_key, truncated = truncated_name }
  end
end
```

---

## Final Results

**Important:** All times below are **cumulative per second** (not per frame). The profiler accumulated render times over 1 second and reported totals. With REAPER's defer loop at ~32fps:
- Per-frame time = reported time ÷ 32
- Tile count = visible tiles × 32 frames

### Before optimization (~500 visible tiles):
- Total: ~360ms/sec cumulative (~11ms/frame)
- Animator: ~95ms/sec
- Text: ~200ms/sec
- Wave/MIDI: ~50ms/sec (spikes to 300ms during resize)
- Actual FPS impact: ~11ms/frame leaves plenty of headroom

### After optimization (~500 visible tiles):
- Total: ~50-60ms/sec cumulative (~1.5-2ms/frame)
- Animator: ~11-14ms/sec
- Text: ~18-26ms/sec
- Wave/MIDI: ~0-1ms/sec (cached), ~20-30ms/sec (regenerating)
- Actual FPS impact: ~2ms/frame = negligible

### Improvement: ~6x faster (360ms → 60ms cumulative)

---

## Key Principles Applied

1. **Profile first** - Identify actual bottlenecks before optimizing
2. **Skip work when possible** - Settled tile detection, animation throttling
3. **LOD for visual content** - Skip sub-pixel details
4. **Cache expensive operations** - Text truncation, waveform polylines
5. **Localize hot-path functions** - Eliminate table lookups in Lua
6. **Inline small operations** - with_alpha, snap, etc.

---

## Files Modified

- `arkitekt/gui/animation/tile_animator.lua` - Added track_get()
- `arkitekt/gui/animation/tracks.lua` - Added RectTrack:is_animating()
- `arkitekt/gui/widgets/containers/grid/core.lua` - Exposed is_animating in result
- `scripts/ItemPicker/ui/grids/coordinator.lua` - Added is_animating() method
- `scripts/ItemPicker/ui/grids/renderers/base.lua` - Inlined functions, localized ImGui calls
- `scripts/ItemPicker/ui/grids/renderers/audio.lua` - Settled tile cache, profiler
- `scripts/ItemPicker/ui/grids/renderers/midi.lua` - Settled tile cache, profiler
- `scripts/ItemPicker/ui/visualization.lua` - MIDI LOD
- `scripts/ItemPicker/ui/init.lua` - Animation-based job throttling

---

## Phase 7: Per-Frame Config Caching

### Problem
Text rendering was still doing per-tile config lookups despite function localization. Profiling with granular timing revealed:

```
RTT: cfg:30ms | pos:23ms | trunc:3ms | text:10ms | badge:0ms
```

The `cfg` time was **30ms** - accessing `config.TILE_RENDER.responsive.hide_text_below`, etc. for each tile.

### Solution
Cache config values once per frame in `begin_frame()`, access cached locals during render.

**scripts/ItemPicker/ui/grids/renderers/base.lua:**
```lua
-- PERF: Per-frame config cache (set once per frame via begin_frame)
local _frame_config = {
  tile_render = nil,
  hide_text_below = nil,
  hide_badge_below = nil,
  header_min_height = nil,
  text_padding_left = nil,
  text_padding_top = nil,
  text_margin_right = nil,
  text_primary_color = nil,
  badge_cycle = nil,
}

function M.cache_config(config)
  local tile_render = config.TILE_RENDER
  _frame_config.tile_render = tile_render
  _frame_config.hide_text_below = tile_render.responsive.hide_text_below - tile_render.header.min_height
  _frame_config.hide_badge_below = tile_render.responsive.hide_badge_below - tile_render.header.min_height
  _frame_config.header_min_height = tile_render.header.min_height
  _frame_config.text_padding_left = tile_render.text.padding_left
  _frame_config.text_padding_top = tile_render.text.padding_top
  _frame_config.text_margin_right = tile_render.text.margin_right
  _frame_config.text_primary_color = tile_render.text.primary_color
  _frame_config.badge_cycle = tile_render.badge.cycle
end

-- In render_tile_text: access _frame_config instead of config.TILE_RENDER.*
```

**scripts/ItemPicker/ui/grids/renderers/audio.lua:**
```lua
function M.begin_frame(ctx, config)
  -- ... palette cache ...
  if config then
    BaseRenderer.cache_config(config)
  end
end
```

### Why this matters in Lua

Each dot access is a table lookup:
- `config.TILE_RENDER.responsive.hide_text_below` = 4 lookups
- For 10,000 tiles × 8 config accesses × 4 lookups = **320,000 table lookups**

After caching:
- `_frame_config.hide_text_below` = 1 lookup
- 10,000 tiles × 8 accesses = **80,000 lookups** (4x reduction)

### Result

**Before (with profiling overhead):**
- TEXT section: ~36-44ms (audio), ~50ms+ (MIDI)
- Config lookups: ~30ms alone

**After (profiling stripped):**
- TEXT section: **18-22ms** (audio), **32-37ms** (MIDI)
- ~50% reduction in TEXT time

**Overall frame times:**
- Audio: ~100-110ms → **84-96ms** (~15% improvement)
- MIDI: ~150-160ms → **117-145ms** (~10-15% improvement)

---

## Phase 7b: Post-Render Badge Click Handling

### Problem
Each tile with a cycle badge created an `InvisibleButton` for click detection. With 5000+ tiles, that's 5000+ widget calls.

### Solution
Store badge rectangles during render, do single hit-test after grid render completes.

**scripts/ItemPicker/ui/grids/factories/audio.lua:**
```lua
-- Store badge rects during render
local badge_rects = {}

-- In tile render callback:
badge_rects[item.uuid] = { badge_x, badge_y, badge_x + badge_w, badge_y + badge_h }

-- Post-render hit test:
local function handle_badge_click(ctx)
  local left_click = ImGui.IsMouseClicked(ctx, 0)
  local right_click = ImGui.IsMouseClicked(ctx, 1)
  if not left_click and not right_click then return false end

  local mx, my = ImGui.GetMousePos(ctx)
  for uuid, rect in pairs(badge_rects) do
    if mx >= rect[1] and mx <= rect[3] and my >= rect[2] and my <= rect[4] then
      -- Handle click
    end
  end
end
```

**scripts/ItemPicker/ui/grids/coordinator.lua:**
```lua
-- Call after grid render:
if self.audio_badge_click_handler then
  self.audio_badge_click_handler(ctx)
end
```

### Result
Eliminated per-tile InvisibleButton overhead. Impact depends on how many tiles have cycle badges.

---

## Phase 8: Comprehensive Per-Frame Config Caching

### Problem
Cfillion's Lua profiler revealed a critical bottleneck we hadn't measured with inline timing:

```
[PROFILER] CONFIG.TILE_RENDER.__index: 47% of execution time
[PROFILER] Ark.Colors.rgb_to_hsl: 15%
[PROFILER] rgba_to_components: 3%
```

The `__index` metatable overhead was consuming nearly half of all execution time. Every access to `config.TILE_RENDER.responsive.hide_text_below` triggered multiple metatable lookups - not just table indexing, but actual Lua `__index` metamethod calls.

With ~10,000 tiles × ~50 config accesses per tile × ~5 metatable operations per access = **2.5 million metatable calls per frame**.

### Solution
Expand per-frame config caching to cover ALL `config.TILE_RENDER.*` accesses across all renderer functions.

**scripts/ItemPicker/ui/grids/renderers/base.lua:**
```lua
-- PERF: Per-frame config cache (set once per frame via begin_frame)
-- This eliminates the 47% overhead from config.TILE_RENDER.__index metatable calls
-- Declared early so all functions can access it
local _frame_config = {}

-- Module-level accessor for audio.lua/midi.lua
M.cfg = _frame_config

function M.cache_config(config)
  local tr = config.TILE_RENDER
  local c = _frame_config

  -- Cascade animation
  c.cascade_scale_from = tr.cascade.scale_from
  c.cascade_y_offset = tr.cascade.y_offset
  c.cascade_scale_power = tr.cascade.scale_power

  -- Waveform
  c.waveform_saturation = tr.waveform.saturation
  c.waveform_brightness = tr.waveform.brightness
  c.waveform_line_alpha = tr.waveform.line_alpha

  -- Header bar
  c.header_saturation_factor = tr.header.saturation_factor
  c.header_brightness_factor = tr.header.brightness_factor
  c.header_alpha = tr.header.alpha
  c.header_text_shadow = tr.header.text_shadow
  c.header_min_height = tr.header.min_height

  -- ... 60+ more cached values covering ALL config accesses ...

  -- Store the original config for rare code paths (like cascade animation)
  c.config = config
end
```

**scripts/ItemPicker/ui/grids/renderers/audio.lua:**
```lua
function M.render(ctx, dl, rect, item_data, tile_state, config, animator, ...)
  -- PERF: Use cached config values (eliminates __index metatable overhead)
  local cfg = BaseRenderer.cfg

  -- Before: config.TILE_RENDER.cascade.scale_from
  -- After:  cfg.cascade_scale_from
  local scale_from = cfg.cascade_scale_from
  local y_offset = cfg.cascade_y_offset
  -- ...
end
```

### Why This Is Different From Phase 7

Phase 7 cached ~8 values for `render_tile_text`. This phase expanded caching to **60+ values** covering every `TILE_RENDER` access across:
- `calculate_cascade_factor`
- `get_dark_waveform_color`
- `render_header_bar`
- `apply_state_effects`
- `get_cached_tile_color`
- `compute_tile_color_fast`
- `compute_tile_color`
- `calculate_combined_alpha`
- `get_text_color`
- `render_tile_text`
- And all per-tile code in audio.lua/midi.lua

### Critical Implementation Detail

The `_frame_config` table MUST be declared at the top of the module, before any functions that use it:

```lua
-- @noindex
local ImGui = require('arkitekt.platform.imgui')
-- ... other imports ...

local M = {}

-- IMPORTANT: Declare before functions that access it
local _frame_config = {}

-- Functions can now safely access _frame_config
function M.some_function()
  local value = _frame_config.some_value
end
```

If declared after functions, Lua captures a `nil` reference at parse time, causing runtime errors.

### Result

**Cfillion Profiler Before:**
```
CONFIG.TILE_RENDER.__index: 47%
```

**Cfillion Profiler After:**
```
CONFIG.TILE_RENDER.__index: 23%
```

**Cumulative Times (per second, ~500 visible tiles × 32 frames = ~16,000 tile renders/sec):**
- Audio grid: ~100ms/sec → **42-50ms/sec** (55% faster)
- MIDI grid: ~150ms/sec → **43-50ms/sec** (70% faster)

**Combined: ~250ms/sec → ~90-100ms/sec (60% improvement)**

**Per-frame (÷32):**
- Before: ~7.8ms/frame combined
- After: ~3ms/frame combined

The remaining 23% `__index` overhead comes from:
1. The initial `cache_config()` call each frame (necessary)
2. Other non-tile config accesses
3. TILE_RENDER accesses we haven't cached yet (diminishing returns)

At ~45ms/sec cumulative for ~500 tiles (~1.4ms/frame), we've reached the performance floor for pure Lua rendering.

---

## Lessons Learned

1. **Profiling has overhead** - Granular timing (time_precise per operation) adds measurable cost. Strip profiling after identifying bottlenecks.

2. **Table lookups are expensive** - In Lua, `a.b.c.d` is 4 hash lookups. Per-frame caching of frequently accessed config is essential.

3. **Metatable `__index` is even more expensive** - Config tables with metatables trigger `__index` calls on every access. With thousands of tiles, this dominates execution time (47% in our case). Cache all config values once per frame.

4. **Per-tile widgets are costly** - InvisibleButton per tile adds up. Post-render hit testing is cheaper when you only need click detection.

5. **Measure after stripping** - Don't trust numbers with profiling enabled. The optimization may be working but masked by measurement overhead.

6. **Use external profilers for overall view** - Inline timing shows where time is spent within your code, but external profilers (like Cfillion's Lua profiler) reveal hidden costs like metatable overhead that inline timing misses.

7. **Cache at the right frequency** - Per-tile caching is wasteful when values don't change per-tile. Per-frame caching (once at frame start, used thousands of times) provides the best balance.

---

## Phase 9: Duration, Settings, and Header Caching

### Problem
Additional profiling revealed more per-tile bottlenecks:

```
[MIDI] badge:25ms (dur:18ms!)
[MIDI] rgn:22-23ms
[AUDIO] badge:11ms
```

Duration badges were calling `reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')` per tile per frame. Region chips were calling `CalcTextSize` and color computations per chip. Settings lookups (`state.settings.show_duration`) happened ~40,000+ times per frame.

### Solution 1: Duration Caching in Factories

Cache duration when building item data, not when rendering:

**scripts/ItemPicker/ui/grids/factories/midi.lua:**
```lua
-- PERF: Cache duration to avoid GetMediaItemInfo_Value calls in renderer
local duration = (item and reaper.ValidatePtr2(0, item, 'MediaItem*'))
                 and reaper.GetMediaItemInfo_Value(item, 'D_LENGTH') or 0

filtered[#filtered + 1] = {
  -- ... existing fields ...
  duration = duration,  -- Cached duration for renderer
}
```

**Result:** Duration badge: 18ms → 3.4ms (80% reduction)

### Solution 2: Region Text/Color Caching

Cache region chip calculations per unique region name/color:

**scripts/ItemPicker/ui/grids/renderers/midi.lua:**
```lua
local _cached = {
  region_text = {},    -- region_name -> {text_w, text_h}
  region_colors = {},  -- region_color -> adjusted_color
}

-- In region chip rendering:
local cached_text = _cached.region_text[region_name]
if cached_text then
  text_w, text_h = cached_text[1], cached_text[2]
else
  text_w, text_h = CalcTextSize(ctx, region_name)
  _cached.region_text[region_name] = {text_w, text_h}
end
```

**Result:** Region chips: 23ms → 7ms (70% reduction)

### Solution 3: Settings Caching

Cache `state.settings.*` values once per frame like config:

**scripts/ItemPicker/ui/grids/renderers/base.lua:**
```lua
local _settings_cache = {}

function M.cache_settings(state)
  local s = state.settings or {}
  _settings_cache.show_disabled_items = s.show_disabled_items
  _settings_cache.show_duration = s.show_duration
  _settings_cache.show_region_tags = s.show_region_tags
  _settings_cache.waveform_quality = s.waveform_quality or 0.2
  _settings_cache.waveform_filled = s.waveform_filled
  _settings_cache.show_visualization_in_small_tiles = s.show_visualization_in_small_tiles
end

M.settings = _settings_cache
```

**Renderers:**
```lua
function M.begin_frame(ctx, config, state)
  BaseRenderer.cache_config(config)
  BaseRenderer.cache_settings(state)  -- NEW
end

-- In render: use settings.show_duration instead of state.settings.show_duration
local settings = BaseRenderer.settings
if settings.show_duration and ... then
```

**Result:** Eliminated ~40,000+ table lookups per frame.

### Solution 4: Header Color Caching

Cache HSV color conversions for header rendering:

**scripts/ItemPicker/ui/grids/renderers/base.lua:**
```lua
local _header_color_cache = {}
local _header_color_cache_key = nil

local function get_cached_header_color(base_color, is_small_tile, palette)
  local cached = _header_color_cache[base_color]
  if cached then
    return is_small_tile and cached.small or cached.normal
  end

  -- Compute both normal and small tile variants
  local r, g, b = ImGui.ColorConvertU32ToDouble4(base_color)
  local h, s, v = ImGui.ColorConvertRGBtoHSV(r, g, b)

  -- Normal mode
  local nr, ng, nb = ImGui.ColorConvertHSVtoRGB(h, s * sat_factor, v * bright_factor)
  -- Small tile mode
  local sr, sg, sb = ImGui.ColorConvertHSVtoRGB(h, s * small_sat, v * small_bright)

  _header_color_cache[base_color] = {
    normal = {nr, ng, nb},
    small = {sr, sg, sb}
  }
  return is_small_tile and {sr, sg, sb} or {nr, ng, nb}
end
```

**Result:** Header rendering: 10-11ms → 7ms (30% reduction)

### Combined Results

| Component | Before | After | Improvement |
|-----------|--------|-------|-------------|
| Duration badge | 18ms | 3.4ms | 80% |
| Region chips | 23ms | 7ms | 70% |
| Header | 10-11ms | 7ms | 30% |
| Settings lookups | ~40k/frame | cached | ~95% |

---

## ArkContext vs Manual Optimization

### What is ArkContext?

`arkitekt/core/context.lua` provides a per-frame context object that:
- Caches draw_list, time, mouse_pos, delta_time per frame
- Provides `actx:cache(key, fn)` for per-frame memoization
- Avoids the overhead of `parse_opts`, table allocations, and `merge_config`

### When to Use Each Approach

| Scenario | Approach | Reason |
|----------|----------|--------|
| Normal widgets | ArkContext | Automatic optimization, clean code |
| Moderate hot paths | Badge positional mode | Zero allocation, still uses module |
| Extreme hot paths (5000+ calls) | Direct inlining | Maximum performance |

### Optimization Levels

```
Level 0: Naive widget calls
         Ark.Badge.Icon(ctx, { x=x, y=y, ... })
         → parse_opts, table allocs, merge_config
         → SLOW (baseline)

Level 1: ArkContext-powered widgets
         Same API, but widget internally uses cached context
         → ~5-6x faster (automatic)

Level 2: Positional mode
         Badge.Icon(dl, x, y, icon_char, icon_w, icon_h, size, cfg)
         → Zero allocation, pre-computed cfg
         → ~6-7x faster

Level 3: Direct inlining (what ItemPicker renderers do)
         DrawList_AddRectFilled(dl, x, y, ...)
         → No function call overhead, duplicated code
         → ~7-10x faster
```

### ItemPicker Renderer Architecture

The renderers use Level 2-3 optimizations because:
1. They render 5000+ tiles per second (extreme hot path)
2. They bypass Ark widgets entirely for maximum speed
3. Manual caching (`BaseRenderer.cfg`, `_cached` tables) is faster than generic `actx:cache()`

For 90% of ARKITEKT code, ArkContext (Level 1) provides automatic optimization without manual work. Only go to Level 2-3 for extreme hot paths like tile rendering.

### Badge Positional Mode

Both `Badge.Text` and `Badge.Icon` support positional mode for hot paths:

```lua
-- Opts mode (flexible, allocates):
Badge.Text(ctx, { x=x, y=y, text=text, ... })
Badge.Icon(ctx, { x=x, y=y, icon='★', ... })

-- Positional mode (fast, zero allocation):
Badge.Text(dl, x, y, text, text_w, text_h, cfg)
Badge.Icon(dl, x, y, icon_char, icon_w, icon_h, size, cfg)

-- cfg must have pre-computed: bg_color, border, text_color/icon_color, rounding
```

This provides a middle ground: uses the Badge module (maintainable) but avoids allocation overhead (fast).

---

## Summary: Total Optimization Impact

| Phase | Focus | Improvement |
|-------|-------|-------------|
| 1 | Profiling infrastructure | Baseline measurement |
| 2 | Animator optimization | 50% animator time |
| 3 | Resize throttling | Eliminated 200-300ms spikes |
| 4 | MIDI LOD | ~60% MIDI rendering |
| 5 | Text inlining | 50% text rendering |
| 6 | Text truncation caching | Already implemented |
| 7 | Per-frame config caching | 50% overall |
| 7b | Badge click post-render | Eliminated per-tile widgets |
| 8 | Comprehensive config cache | 60% overall |
| 9 | Duration/settings/header cache | 30-80% per component |

**Total: ~360ms → ~45-50ms cumulative (7-8x improvement)**

At this point, the remaining time is actual ImGui DrawList operations - the irreducible cost of drawing pixels.

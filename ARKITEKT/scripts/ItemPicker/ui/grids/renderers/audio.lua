-- @noindex
-- ItemPicker/ui/tiles/renderers/audio.lua
-- Audio tile renderer with waveform visualization

local ImGui = require('arkitekt.core.imgui')
local Ark = require('arkitekt')
local Duration = require('arkitekt.core.duration')
local MarchingAnts = require('arkitekt.gui.interaction.marching_ants')
local BaseRenderer = require('ItemPicker.ui.grids.renderers.base')
local Shapes = require('arkitekt.gui.draw.shapes')
local TileFX = require('arkitekt.gui.renderers.tile.renderer')
local Palette = require('ItemPicker.config.palette')

local M = {}

-- =============================================================================
-- PROFILER (toggle via M.profile_enabled or settings panel)
-- =============================================================================
M.profile_enabled = false
local _profile = {
  animator = 0, color = 0, draw_base = 0, wave = 0,
  header = 0, ants = 0, text = 0, badges = 0, regions = 0,
  count = 0, last_report = 0,
}
local time_precise = reaper.time_precise
local format = string.format

local function profile_report()
  if not M.profile_enabled then return end
  local now = time_precise()
  if now - _profile.last_report > 1.0 then
    local cnt = _profile.count
    if cnt > 0 then
      reaper.ShowConsoleMsg(format(
        '[AUDIO] %d tiles | anim:%.1fms | color:%.1fms | base:%.1fms | wave:%.1fms | hdr:%.1fms | ants:%.1fms | txt:%.1fms | badge:%.1fms | rgn:%.1fms\n',
        cnt,
        _profile.animator * 1000,
        _profile.color * 1000,
        _profile.draw_base * 1000,
        _profile.wave * 1000,
        _profile.header * 1000,
        _profile.ants * 1000,
        _profile.text * 1000,
        _profile.badges * 1000,
        _profile.regions * 1000
      ))
    end
    _profile.animator = 0
    _profile.color = 0
    _profile.draw_base = 0
    _profile.wave = 0
    _profile.header = 0
    _profile.ants = 0
    _profile.text = 0
    _profile.badges = 0
    _profile.regions = 0
    _profile.count = 0
    _profile.last_report = now
  end
end

-- =============================================================================

-- PERF: Localize frequently used functions
local min = math.min
local max = math.max
local tostring = tostring
local DrawList_AddRectFilled = ImGui.DrawList_AddRectFilled
local DrawList_AddRect = ImGui.DrawList_AddRect
local DrawList_AddText = ImGui.DrawList_AddText
local CalcTextSize = ImGui.CalcTextSize
local Colors_WithAlpha = Ark.Colors.WithAlpha
local Colors_Opacity = Ark.Colors.Opacity
-- PERF: Localize REAPER API for hot paths
local GetMediaItemInfo_Value = reaper.GetMediaItemInfo_Value
local Colors_AdjustBrightness = Ark.Colors.AdjustBrightness
local Colors_luminance = Ark.Colors.Luminance
local Colors_SameHueVariant = Ark.Colors.SameHueVariant
local Colors_RgbaToComponents = Ark.Colors.RgbaToComponents
local Colors_ComponentsToRgba = Ark.Colors.ComponentsToRgba

-- PERF: Inline color functions for hot paths (avoids function call overhead)
local function with_alpha(color, alpha)
  return (color & 0xFFFFFF00) | (alpha & 0xFF)
end

local function adjust_brightness(color, factor)
  local r = (color >> 24) & 0xFF
  local g = (color >> 16) & 0xFF
  local b = (color >> 8) & 0xFF
  local a = color & 0xFF
  r = min(255, max(0, (r * factor) // 1))
  g = min(255, max(0, (g * factor) // 1))
  b = min(255, max(0, (b * factor) // 1))
  return (r << 24) | (g << 16) | (b << 8) | a
end

local function float_to_alpha(opacity)
  return (max(0, min(1, opacity)) * 255 + 0.5) // 1
end

-- PERF: Cache constant values computed once
local _cached = {
  text_height = nil,     -- Cached per-frame (ctx dependent)
  text_height_ctx = nil, -- Track which ctx we cached for
  duration_text = {},    -- uuid -> {text, width, height}
  palette = nil,         -- Cached palette (refreshed once per frame)
  palette_frame = -1,    -- Frame counter for palette cache
  -- PERF: Pool badge cache (limited set of values)
  pool_badges = {},      -- pool_count -> {text, width, height}
  -- PERF: Cycle badge cache (limited set: index/total combos)
  cycle_badges = {},     -- (index * 10000 + total) -> {text, width, height}
  -- PERF: Region chip caches
  region_text = {},      -- region_name -> {text_w, text_h}
  region_colors = {},    -- region_color -> adjusted_color (ensure_min_lightness result)
}

-- PERF: Call once per frame before rendering tiles (avoids per-tile overhead)
function M.begin_frame(ctx, config, state)
  local frame_count = ImGui.GetFrameCount(ctx)
  if _cached.palette_frame ~= frame_count then
    _cached.palette = Palette.get()
    _cached.palette_frame = frame_count
  end
  -- PERF: Cache config values for render_tile_text (eliminates ~30ms of config lookups)
  if config then
    BaseRenderer.cache_config(config)
  end
  -- PERF: Cache state.settings values (eliminates ~40k+ table lookups per frame)
  if state then
    BaseRenderer.cache_settings(state)
  end
end

-- PERF: Per-tile state cache to skip animator when state is unchanged and settled
-- Key: tile_key, Value: { hover, disabled, muted, compact, hover_f, enabled_f, muted_f, compact_f, settled }
local _tile_state_cache = {}

-- PERF: Truncated text cache - avoids re-truncating every frame
-- Key: tile_key, Value: { name, width, truncated }
local _truncated_text_cache = {}

-- Clear all caches (call when data reloads to prevent stale values)
function M.clear_caches()
  _tile_state_cache = {}
  _truncated_text_cache = {}
  _cached.duration_text = {}
  _cached.cycle_badges = {}
  _cached.pool_badges = {}
  _cached.region_colors = {}
end

function M.render(ctx, dl, rect, item_data, tile_state, config, animator, visualization, state, badge_rects, disable_animator)
  -- PROFILER: Start timing
  local t0, t1, t2, t3, t4, t5, t6, t7, t8
  if M.profile_enabled then t0 = time_precise() end

  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local tile_w, tile_h = x2 - x1, y2 - y1
  local center_x, center_y = (x1 + x2) / 2, (y1 + y2) / 2

  -- PERF: Use cached config values (eliminates __index metatable overhead)
  local cfg = BaseRenderer.cfg

  local overlay_alpha = state.overlay_alpha or 1.0
  -- PERF: Inline cascade_factor for common case (overlay_alpha = 1.0)
  local cascade_factor = overlay_alpha >= 0.999 and 1.0 or BaseRenderer.calculate_cascade_factor(rect, overlay_alpha, config)

  -- Early spawn animation (when tiles appear before overlay fade completes)
  local spawn_factor = 1.0
  if item_data._spawned_at then
    local time_since_spawn = time_precise() - item_data._spawned_at
    local spawn_duration = 0.4  -- 400ms spawn animation
    if time_since_spawn < spawn_duration then
      -- Ease out quart: smooth deceleration
      local t = time_since_spawn / spawn_duration
      local inv = 1 - t
      spawn_factor = 1 - inv * inv * inv * inv
    end
  end

  -- Combine cascade and spawn factors
  local combined_factor = cascade_factor * spawn_factor
  if combined_factor < 0.001 then return end

  -- Apply combined animation transform
  local scale = cfg.cascade_scale_from + (1.0 - cfg.cascade_scale_from) * combined_factor
  local y_offset = cfg.cascade_y_offset * (1.0 - combined_factor)

  local scaled_w = tile_w * scale
  local scaled_h = tile_h * scale
  local scaled_x1 = center_x - scaled_w / 2
  local scaled_y1 = center_y - scaled_h / 2 + y_offset
  local scaled_x2 = center_x + scaled_w / 2
  local scaled_y2 = center_y + scaled_h / 2 + y_offset

  -- Check if we're in small tile mode (need this early for animations)
  local is_small_tile = scaled_h < cfg.small_tile_height

  -- Track animations
  local is_disabled = state.disabled and state.disabled.audio and state.disabled.audio[item_data.filename]
  local is_muted = (item_data.track_muted or item_data.item_muted) and true or false
  local is_hover = tile_state.hover and true or false

  local hover_factor, enabled_factor, muted_factor, compact_factor
  local key = item_data.key

  if animator and key then
    -- PERF: Check if we can skip animator entirely (state unchanged + settled)
    local cached = _tile_state_cache[key]
    if cached and cached.settled
       and cached.hover == is_hover
       and cached.disabled == is_disabled
       and cached.muted == is_muted
       and cached.compact == is_small_tile then
      -- State unchanged and animations settled - use cached values directly
      hover_factor = cached.hover_f
      enabled_factor = cached.enabled_f
      muted_factor = cached.muted_f
      compact_factor = cached.compact_f
    else
      -- State changed or not settled - use animator
      hover_factor = animator:track_get(key, 'hover', is_hover and 1.0 or 0.0, cfg.animation_speed_hover)
      enabled_factor = animator:track_get(key, 'enabled', is_disabled and 0.0 or 1.0, cfg.disabled_fade_speed)
      muted_factor = animator:track_get(key, 'muted', is_muted and 1.0 or 0.0, cfg.muted_fade_speed)
      compact_factor = animator:track_get(key, 'compact_mode', is_small_tile and 1.0 or 0.0, cfg.animation_speed_header_transition)

      -- Check if all animations are now settled (at target values)
      local hover_target = is_hover and 1.0 or 0.0
      local enabled_target = is_disabled and 0.0 or 1.0
      local muted_target = is_muted and 1.0 or 0.0
      local compact_target = is_small_tile and 1.0 or 0.0

      local settled = (hover_factor == hover_target)
                  and (enabled_factor == enabled_target)
                  and (muted_factor == muted_target)
                  and (compact_factor == compact_target)

      -- Update cache (clear color cache when state changes)
      _tile_state_cache[key] = {
        hover = is_hover,
        disabled = is_disabled,
        muted = is_muted,
        compact = is_small_tile,
        hover_f = hover_factor,
        enabled_f = enabled_factor,
        muted_f = muted_factor,
        compact_f = compact_factor,
        settled = settled,
        -- Color cache (invalidated when state changes)
        render_color = nil,
        combined_alpha = nil,
      }
    end
  else
    hover_factor = is_hover and 1.0 or 0.0
    enabled_factor = is_disabled and 0.0 or 1.0
    muted_factor = is_muted and 1.0 or 0.0
    compact_factor = is_small_tile and 1.0 or 0.0
  end

  -- PROFILER: After animator
  if M.profile_enabled then t1 = time_precise() end

  -- Track playback progress (PERF: only track if preview system is active)
  local playback_progress, playback_fade = 0, 0
  if state.is_previewing then
    local is_playing_this = state.is_previewing(item_data.item)
    if is_playing_this then
      playback_progress = state.get_preview_progress and state.get_preview_progress() or 0
      -- Store progress for fade out
      if animator and item_data.key then
        animator:track(item_data.key, 'last_progress', playback_progress, 999)  -- Instant update
        -- Time-based fade: fade in when playing, fade out at 100% or when stopped
        local target_fade = (playback_progress > 0 and playback_progress < 1.0) and 1.0 or 0.0
        local current_fade = animator:get(item_data.key, 'progress_fade') or 0
        -- Fast fade in (8.0), fade out in 1 second (1.0)
        local fade_speed = (target_fade > current_fade) and 8.0 or 1.0
        animator:track(item_data.key, 'progress_fade', target_fade, fade_speed)
        playback_fade = animator:get(item_data.key, 'progress_fade')
      else
        playback_fade = 1.0
      end
    elseif animator and item_data.key then
      -- PERF: Only check fade if we have a stored progress (avoid unnecessary animator calls)
      local last_progress = animator:get(item_data.key, 'last_progress')
      if last_progress and last_progress > 0 then
        playback_progress = last_progress
        animator:track(item_data.key, 'progress_fade', 0.0, 1.0)  -- 1 second fade out
        playback_fade = animator:get(item_data.key, 'progress_fade')
      end
    end
  end

  -- PERF: Use cached palette (call M.begin_frame before rendering tiles)
  local palette = _cached.palette
  local base_color = item_data.color or palette.default_tile_color or 0xFF555555

  -- Calculate selection pulse (0 if not selected, 0-1 oscillating if selected)
  local selection_pulse = BaseRenderer.get_selection_pulse(tile_state.selected)

  -- PERF: Use cached color for settled tiles (skips all color computations)
  -- Only cache when cascade is 1.0 (fully visible) to avoid float comparison issues
  -- Don't cache selected tiles since they pulse every frame
  local render_color, combined_alpha
  local cached_state = _tile_state_cache[key]
  local can_use_cache = cached_state and cached_state.settled
                        and cached_state.render_color
                        and cached_state.base_color == base_color
                        and not tile_state.selected  -- Don't cache selected (pulsing) tiles
                        and combined_factor >= 0.999  -- Only cache fully visible tiles (incl. spawn anim)

  if can_use_cache then
    -- Use cached colors
    render_color = cached_state.render_color
    combined_alpha = cached_state.combined_alpha
  else
    -- Compute colors (pass selection_pulse instead of boolean)
    -- Use combined_factor (cascade * spawn) for alpha calculation
    render_color, combined_alpha = BaseRenderer.compute_tile_color(
      base_color, is_small_tile, hover_factor, muted_factor, enabled_factor,
      selection_pulse, combined_factor, config, palette
    )
    -- Cache if settled, fully visible, and not selected
    if cached_state and cached_state.settled and combined_factor >= 0.999 and not tile_state.selected then
      cached_state.render_color = render_color
      cached_state.combined_alpha = combined_alpha
      cached_state.base_color = base_color
    end
  end

  -- Capture animation color for disable animation (without alpha)
  local animation_color = with_alpha(render_color, 0xFF)

  -- PERF: Clamp to 0-255 to prevent overflow (256 & 0xFF = 0, making text invisible)
  local text_alpha = min(255, max(0, (0xFF * combined_alpha) // 1))
  local text_color = BaseRenderer.get_text_color(muted_factor, config)

  -- PROFILER: After color computation
  if M.profile_enabled then t2 = time_precise() end

  -- Calculate header height with animated transition
  local normal_header_height = max(
    cfg.header_min_height,
    scaled_h * cfg.header_height_ratio
  )
  local full_tile_height = scaled_h

  -- Interpolate between normal and full based on compact_factor
  -- compact_factor: 0.0 = normal mode, 1.0 = compact mode
  local header_height = normal_header_height + (full_tile_height - normal_header_height) * compact_factor

  -- Calculate header fade (fade out when going to compact, fade in when going to normal)
  -- In compact mode (compact_factor = 1.0), header alpha should be 0
  -- In normal mode (compact_factor = 0.0), header alpha should be normal
  local header_alpha_factor = 1.0 - compact_factor

  -- Trigger disable animation if item is being disabled when show_disabled_items = false
  -- PERF: Use cached settings (BaseRenderer.settings) instead of per-tile state.settings lookup
  local settings = BaseRenderer.settings
  if disable_animator and item_data.key and is_disabled and not settings.show_disabled_items then
    if not disable_animator:is_disabling(item_data.key) then
      -- Use animation_color (actual tile appearance before alpha) for matching color
      disable_animator:disable(item_data.key, {scaled_x1, scaled_y1, scaled_x2, scaled_y2}, animation_color)
    end
  end

  -- Render base tile fill with rounding
  -- PERF: Use cached cfg.tile_rounding instead of config.TILE.ROUNDING
  DrawList_AddRectFilled(dl, scaled_x1, scaled_y1, scaled_x2, scaled_y2, render_color, cfg.tile_rounding)

  -- Render dark backdrop for disabled items (skip if show_disabled_items = false, animation handles it)
  if enabled_factor < 0.999 and settings.show_disabled_items then
    local backdrop_alpha = cfg.disabled_backdrop_alpha * (1.0 - enabled_factor) * cascade_factor
    local backdrop_color = with_alpha(cfg.disabled_backdrop_color, backdrop_alpha // 1)
    DrawList_AddRectFilled(dl, scaled_x1, scaled_y1, scaled_x2, scaled_y2, backdrop_color, cfg.tile_rounding)
  end

  -- PROFILER: After base draw
  if M.profile_enabled then t3 = time_precise() end

  -- Render waveform BEFORE header so header can overlay with transparency
  -- (show even when disabled, just with toned down color)
  if item_data.item and combined_factor > 0.2 then
    -- Skip waveform rendering entirely in small tile mode
    if is_small_tile then
      goto skip_waveform
    end

    -- Normal mode: render in content area below header
    local content_y1 = scaled_y1 + header_height
    local content_h = scaled_y2 - content_y1

    local content_w = scaled_w

    ImGui.SetCursorScreenPos(ctx, scaled_x1, content_y1)
    ImGui.Dummy(ctx, content_w, content_h)

    local dark_color = BaseRenderer.get_dark_waveform_color(base_color, config, palette)
    local waveform_alpha = combined_alpha * cfg.waveform_line_alpha
    dark_color = with_alpha(dark_color, float_to_alpha(waveform_alpha))

    -- Skip all waveform rendering if skip_visualizations is enabled (fast mode)
    if not state.skip_visualizations then
      -- Check runtime cache for waveform
      local waveform = state.runtime_cache and state.runtime_cache.waveforms[item_data.uuid]
      if waveform then
        if visualization.DisplayWaveformTransparent then
          -- Apply waveform quality multiplier to reduce resolution (better performance with many items)
          -- PERF: Use cached settings instead of per-tile state.settings lookup
          local target_width = (content_w * settings.waveform_quality) // 1
          visualization.DisplayWaveformTransparent(ctx, waveform, dark_color, dl, target_width, item_data.uuid, state.runtime_cache)
        end
      else
        -- Show placeholder with spinner and queue waveform generation
        BaseRenderer.render_placeholder(dl, scaled_x1, content_y1, scaled_x2, scaled_y2, render_color, combined_alpha)

        -- Queue waveform job
        if state.job_queue and state.job_queue.add_waveform_job then
          state.job_queue.add_waveform_job(item_data.item, item_data.uuid)
        end
      end
    end
  end

  ::skip_waveform::

  -- PROFILER: After waveform
  if M.profile_enabled then t4 = time_precise() end

  -- Render playback progress bar (after visualization, before header)
  if playback_progress > 0 and playback_fade > 0 then
    TileFX.render_playback_progress(dl, scaled_x1, scaled_y1, scaled_x2, scaled_y2, base_color, playback_progress, playback_fade, config.TILE.ROUNDING)
  end

  -- Render header with animated fade and size transition
  -- Apply header_alpha_factor for transition fade (fades out when going to compact, fades in when going to normal)
  local header_alpha = combined_alpha * header_alpha_factor
  if is_small_tile and header_alpha_factor < 0.1 then
    -- When mostly faded out in compact mode, apply small tile header alpha
    header_alpha = combined_alpha * cfg.small_tile_header_alpha
  end
  BaseRenderer.render_header_bar(dl, scaled_x1, scaled_y1, scaled_x2, header_height,
    render_color, header_alpha, config, is_small_tile, palette)

  -- PROFILER: After header
  if M.profile_enabled then t5 = time_precise() end

  -- Render marching ants for selection
  if tile_state.selected and combined_factor > 0.5 then
    -- Use palette values if available for theme-reactive ants
    local ants_sat = palette.ants_saturation or cfg.selection_border_saturation
    local ants_bright = palette.ants_brightness or cfg.selection_border_brightness
    local ant_color = Colors_SameHueVariant(
      base_color,
      ants_sat,
      ants_bright,
      (cfg.selection_ants_alpha * combined_alpha) // 1
    )

    -- Mix with white to make marching ants lighter but still tinted
    local white_mix = 0.65  -- Mix 65% white - whiter, less colored
    local r, g, b, a = Colors_RgbaToComponents(ant_color)
    r = r + (255 - r) * white_mix
    g = g + (255 - g) * white_mix
    b = b + (255 - b) * white_mix
    ant_color = Colors_ComponentsToRgba(r // 1, g // 1, b // 1, a)

    local inset = cfg.selection_ants_inset
    local selection_count = state.audio_selection_count or 1
    MarchingAnts.Draw(
      dl,
      scaled_x1 + inset, scaled_y1 + inset, scaled_x2 - inset, scaled_y2 - inset,
      ant_color,
      cfg.selection_ants_thickness,
      0,  -- No rounding for marching ants (performance: skips arc calculations)
      cfg.selection_ants_dash,
      cfg.selection_ants_gap,
      cfg.selection_ants_speed,
      selection_count  -- Performance: LOD based on selection size
    )
  end

  -- PROFILER: After marching ants
  if M.profile_enabled then t6 = time_precise() end

  -- Check if item is favorited
  local is_favorite = state.favorites and state.favorites.audio and state.favorites.audio[item_data.filename]

  -- Get favorite color from palette (theme-reactive)
  local favorite_color = palette.favorite_star or 0xFFE87CFF
  local display_text_color = is_favorite and favorite_color or text_color

  -- PERF: Cache text height per context (doesn't change within a frame)
  if _cached.text_height_ctx ~= ctx then
    local _, h = CalcTextSize(ctx, '1')
    _cached.text_height = h
    _cached.text_height_ctx = ctx
  end
  local text_h = _cached.text_height

  -- Calculate star badge space - match cycle badge height dynamically
  local star_badge_size = text_h + (cfg.badge_cycle_padding_y * 2)  -- Match cycle badge calculation

  -- Calculate extra text margin to reserve space for favorite and pool badges (text truncation only)
  -- This doesn't affect cycle badge position, only text truncation
  local extra_text_margin = 0
  if is_favorite then
    extra_text_margin = star_badge_size + cfg.badge_favorite_spacing
  end

  -- Add pool badge space if needed
  if item_data.pool_count and item_data.pool_count > 1 and combined_factor > 0.5 then
    -- PERF: Use cached pool badge dimensions
    local pool_count = item_data.pool_count
    local cached_pool = _cached.pool_badges and _cached.pool_badges[pool_count]
    local pool_w
    if cached_pool then
      pool_w = cached_pool[2]
    else
      local pool_text = '×' .. tostring(pool_count)
      pool_w = CalcTextSize(ctx, pool_text)
    end
    local pool_badge_w = pool_w + cfg.badge_pool_padding_x * 2
    extra_text_margin = extra_text_margin + pool_badge_w + cfg.badge_pool_spacing
  end

  -- Check if this tile is being renamed
  local is_renaming = state.rename_active and state.rename_uuid == item_data.uuid and state.rename_is_audio

  -- Populate rename text if it's empty (happens when moving to next item in batch)
  if is_renaming and (not state.rename_text or state.rename_text == '') then
    state.rename_text = item_data.name
  end

  -- Calculate text reveal animation (fade-up effect when metadata loads)
  local text_reveal_factor = 1.0
  local text_y_offset = 0
  if item_data._metadata_loaded_at then
    local time_since_load = time_precise() - item_data._metadata_loaded_at
    local reveal_duration = 0.25  -- 250ms animation
    if time_since_load < reveal_duration then
      -- Ease out quad: fast start, slow finish
      local t = time_since_load / reveal_duration
      text_reveal_factor = t * (2 - t)  -- ease out quad
      text_y_offset = (1 - text_reveal_factor) * 6  -- Start 6px below, move up
    end
  end

  -- Apply text reveal to alpha
  local animated_text_alpha = min(255, (text_alpha * text_reveal_factor) // 1)

  -- Render text and badge (with reduced width if star is present)
  if combined_factor > 0.3 then
    if is_renaming then
      -- Render inline rename input
      local input_x = scaled_x1 + 8
      local input_y = scaled_y1 + 4
      local input_w = (scaled_x2 - extra_text_margin) - input_x - 4
      local input_h = header_height - 8

      ImGui.SetCursorScreenPos(ctx, input_x, input_y)
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, 2, 2)
      ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, palette.rename_input_bg or 0x1A1A1AFF)
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, palette.rename_input_text or 0xFFFFFFFF)
      ImGui.SetNextItemWidth(ctx, input_w)

      -- Auto-focus on first frame
      if not state.rename_focused then
        ImGui.SetKeyboardFocusHere(ctx)
        state.rename_focused = true
        state.rename_focus_frame = true  -- Mark this as the focus frame
      end

      local changed, new_text = ImGui.InputText(ctx, '##rename', state.rename_text, ImGui.InputTextFlags_EnterReturnsTrue)

      -- Update rename text in real-time (even if not committed with Enter)
      if not changed then
        state.rename_text = new_text
      end

      if changed then
        -- Get fresh item data from lookup
        local lookup_data = state.audio_item_lookup[item_data.uuid]
        if not lookup_data then
          lookup_data = item_data
        end

        local item = lookup_data.item or lookup_data[1]

        -- Validate item pointer
        if not item or not reaper.ValidatePtr2(0, item, 'MediaItem*') then
          state.rename_active = false
          state.rename_uuid = nil
          state.rename_focused = false
          state.rename_queue = nil
          state.rename_queue_index = 0
          state.rename_focus_frame = false
          ImGui.PopStyleColor(ctx, 2)
          ImGui.PopStyleVar(ctx)
          return
        end

        -- Apply rename to the item
        reaper.Undo_BeginBlock()
        local take = reaper.GetActiveTake(item)
        if take then
          reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', new_text, true)

          -- Update the name in the lookup immediately so tile reflects change
          if state.audio_item_lookup[item_data.uuid] then
            if type(state.audio_item_lookup[item_data.uuid]) == 'table' then
              state.audio_item_lookup[item_data.uuid][2] = new_text
            end
          end

          -- Also update in the samples array
          if state.samples then
            for filename, items_array in pairs(state.samples) do
              for _, entry in ipairs(items_array) do
                if entry.uuid == item_data.uuid then
                  entry[2] = new_text
                  break
                end
              end
            end
          end

          -- Update the current item_data name for immediate display
          item_data.name = new_text

          reaper.UpdateArrange()
        end
        reaper.Undo_EndBlock('Rename item take', -1)

        -- Check if there are more items in the batch rename queue
        if state.rename_queue and state.rename_queue_index < #state.rename_queue then
          -- Move to next item in queue
          state.rename_queue_index = state.rename_queue_index + 1
          local next_uuid = state.rename_queue[state.rename_queue_index]

          -- Find the next item to rename
          -- This will be picked up on next frame, need to get item name
          -- For now, set to empty and let the next frame's double_click logic populate it
          state.rename_uuid = next_uuid
          state.rename_focused = false
          state.rename_text = ''  -- Will be populated by factory on next frame
          state.rename_focus_frame = false
        else
          -- No more items in queue, end rename session
          state.rename_active = false
          state.rename_uuid = nil
          state.rename_focused = false
          state.rename_queue = nil
          state.rename_queue_index = 0
          state.rename_focus_frame = false
        end
      end

      -- Cancel on Escape or focus loss (but NOT on the frame we just set focus)
      if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
        -- Cancel entire rename session on Escape
        state.rename_active = false
        state.rename_uuid = nil
        state.rename_focused = false
        state.rename_queue = nil
        state.rename_queue_index = 0
        state.rename_focus_frame = false
      elseif state.rename_focused and not ImGui.IsItemActive(ctx) and not state.rename_focus_frame then
        -- Only cancel on focus loss if not in batch mode AND not on focus frame
        if not state.rename_queue or #state.rename_queue <= 1 then
          state.rename_active = false
          state.rename_uuid = nil
          state.rename_focused = false
          state.rename_focus_frame = false
        end
      end

      -- Clear focus frame flag after first frame
      if state.rename_focus_frame then
        state.rename_focus_frame = false
      end

      ImGui.PopStyleColor(ctx, 2)
      ImGui.PopStyleVar(ctx)
    else
      -- Normal text rendering
      -- PERF: Badge click handling moved to coordinator (single hit-test vs per-tile InvisibleButton)
      -- Pass full x2 (cycle badge position stays fixed), use extra_text_margin for text truncation only
      -- PERF: Pass truncated text cache for cross-frame caching
      -- Pass animated alpha and y_offset for text reveal effect
      BaseRenderer.render_tile_text(ctx, dl, scaled_x1, scaled_y1, scaled_x2, header_height,
        item_data.name, item_data.index, item_data.total, render_color, animated_text_alpha, config,
        item_data.uuid, badge_rects, nil, extra_text_margin, display_text_color, _truncated_text_cache, text_y_offset)
    end
  end

  -- PROFILER: After text
  if M.profile_enabled then t7 = time_precise() end

  -- PERF: Pre-compute cycle badge dimensions once (reused for star and pool positioning)
  local cycle_badge_w, cycle_text
  local has_cycle = item_data.total and item_data.total > 1
  if has_cycle then
    local idx = item_data.index or 1
    local cache_key = idx * 10000 + item_data.total
    local cached = _cached.cycle_badges[cache_key]
    if cached then
      cycle_text, cycle_badge_w = cached[1], cached[2] + cfg.badge_cycle_padding_x * 2
    else
      cycle_text = format('%d/%d', idx, item_data.total)
      local w = CalcTextSize(ctx, cycle_text)
      _cached.cycle_badges[cache_key] = {cycle_text, w}
      cycle_badge_w = w + cfg.badge_cycle_padding_x * 2
    end
  end

  -- Render favorite star badge (vertically centered in header, to the left of cycle badge)
  if combined_factor > 0.5 and is_favorite then
    local star_x
    -- Position favorite to the left of cycle badge (if it exists)
    if has_cycle then
      local cycle_x = scaled_x2 - cycle_badge_w - cfg.badge_cycle_margin
      -- Position favorite to the left of cycle badge
      star_x = cycle_x - star_badge_size - cfg.badge_favorite_spacing
    else
      -- No cycle badge, position at right edge
      star_x = scaled_x2 - star_badge_size - cfg.badge_favorite_margin
    end

    local star_y = scaled_y1 + (header_height - star_badge_size) / 2
    local icon_size = cfg.badge_favorite_icon_size or state.icon_font_size
    Shapes.draw_favorite_star(ctx, dl, star_x, star_y, star_badge_size, combined_alpha, is_favorite,
      state.icon_font, icon_size, favorite_color, cfg.badge_favorite)
  end

  -- Render region tags (bottom left, only on larger tiles)
  -- Only show region chips if show_region_tags is enabled (regions are already processed if enable_region_processing is true)
  -- PERF: Use cached config values (cfg.region_*) instead of config.REGION_TAGS lookups
  -- PERF: Use cached settings instead of per-tile state.settings lookup
  if settings.show_region_tags and item_data.regions and #item_data.regions > 0 and
     not is_small_tile and scaled_h >= cfg.region_min_tile_height and
     combined_factor > 0.5 then

    local chip_cfg = cfg.region_chip
    local chip_x = scaled_x1 + chip_cfg.margin_left
    local chip_y = scaled_y2 - chip_cfg.height - chip_cfg.margin_bottom

    -- Calculate available width for chips (accounting for duration if enabled)
    local max_chip_x = scaled_x2 - chip_cfg.margin_left
    local show_duration_for_chips = settings.show_duration
    if show_duration_for_chips == nil then show_duration_for_chips = true end
    -- PERF: Use cached duration from item_data
    local chip_duration = item_data.duration or 0
    if show_duration_for_chips and compact_factor < 0.5 and chip_duration > 0 then
      -- PERF: Use cached duration text width if available
      local dur_cache = _cached.duration_text[item_data.uuid]
      if dur_cache then
        max_chip_x = max_chip_x - dur_cache[2] - cfg.duration_text_margin_x - chip_cfg.margin_x
      else
        -- Conservative estimate (duration text not yet cached)
        max_chip_x = max_chip_x - 50 - cfg.duration_text_margin_x - chip_cfg.margin_x
      end
    end

    -- Limit number of chips displayed
    local num_chips = min(#item_data.regions, cfg.region_max_chips)
    local chip_h = chip_cfg.height
    local chip_pad_x = chip_cfg.padding_x
    local chip_pad_x2 = chip_pad_x * 2

    for i = 1, num_chips do
      local region = item_data.regions[i]
      local region_name = region.name or region  -- Support both {name, color} and plain string
      local region_color = region.color or palette.region_chip_default or 0x4A5A6AFF

      -- PERF: Cache region text dimensions (region names repeat across tiles)
      local cached_text = _cached.region_text[region_name]
      local text_w, text_h
      if cached_text then
        text_w, text_h = cached_text[1], cached_text[2]
      else
        text_w, text_h = CalcTextSize(ctx, region_name)
        _cached.region_text[region_name] = {text_w, text_h}
      end
      local chip_w = text_w + chip_pad_x2

      -- Check available space for this chip
      local available_width = max_chip_x - chip_x
      if available_width < chip_pad_x2 + 10 then
        break  -- Not enough space for even a minimal chip
      end

      -- Truncate text if needed to fit (simplified: just truncate at fixed ratio, skip binary search)
      local display_name = region_name
      if chip_w > available_width then
        -- PERF: Simple truncation instead of binary search (good enough, much faster)
        local max_chars = (#region_name * (available_width - chip_pad_x2 - 20) / chip_w) // 1
        if max_chars >= 3 then
          display_name = region_name:sub(1, max_chars) .. '...'
          -- Re-measure truncated text (still cached if same truncation)
          local truncated_cache_key = region_name .. '_' .. max_chars
          local cached_trunc = _cached.region_text[truncated_cache_key]
          if cached_trunc then
            text_w, text_h = cached_trunc[1], cached_trunc[2]
          else
            text_w, text_h = CalcTextSize(ctx, display_name)
            _cached.region_text[truncated_cache_key] = {text_w, text_h}
          end
          chip_w = text_w + chip_pad_x2
        else
          break  -- Can't fit even a minimal truncation
        end
      end

      -- Chip background (dark grey)
      local bg_alpha = (chip_cfg.alpha * combined_alpha) // 1
      local bg_color = (chip_cfg.bg_color & 0xFFFFFF00) | bg_alpha
      DrawList_AddRectFilled(dl, chip_x, chip_y, chip_x + chip_w, chip_y + chip_h, bg_color, chip_cfg.rounding)

      -- PERF: Cache ensure_min_lightness result (region colors repeat)
      local chip_text_color = _cached.region_colors[region_color]
      if not chip_text_color then
        chip_text_color = BaseRenderer.ensure_min_lightness(region_color, chip_cfg.text_min_lightness)
        _cached.region_colors[region_color] = chip_text_color
      end
      local text_alpha_val = float_to_alpha(combined_alpha)
      chip_text_color = (chip_text_color & 0xFFFFFF00) | text_alpha_val
      local chip_text_x = chip_x + chip_pad_x
      local chip_text_y = chip_y + (chip_h - text_h) / 2
      DrawList_AddText(dl, chip_text_x, chip_text_y, chip_text_color, display_name)

      -- Move to next chip position
      chip_x = chip_x + chip_w + chip_cfg.margin_x
    end
  end

  -- Render pool count badge in header (left of favorite/cycle badge) if more than 1 instance
  local should_show_pool_count = item_data.pool_count and item_data.pool_count > 1 and combined_factor > 0.5
  if should_show_pool_count then
    -- PERF: Cache pool badge dimensions (limited set of values)
    local pool_count = item_data.pool_count
    local pool_text, badge_text_w, badge_text_h
    local cached_pool = _cached.pool_badges and _cached.pool_badges[pool_count]
    if cached_pool then
      pool_text, badge_text_w, badge_text_h = cached_pool[1], cached_pool[2], cached_pool[3]
    else
      pool_text = '×' .. tostring(pool_count)
      badge_text_w, badge_text_h = CalcTextSize(ctx, pool_text)
      _cached.pool_badges = _cached.pool_badges or {}
      _cached.pool_badges[pool_count] = {pool_text, badge_text_w, badge_text_h}
    end

    local badge_w = badge_text_w + cfg.badge_pool_padding_x * 2
    local badge_h = badge_text_h + cfg.badge_pool_padding_y * 2

    -- Position left of favorite/cycle badge
    local badge_x = scaled_x2 - badge_w - cfg.badge_pool_margin

    -- Adjust position if favorite is visible
    if is_favorite then
      local star_badge_size_adj = badge_text_h + (cfg.badge_cycle_padding_y * 2)
      badge_x = badge_x - star_badge_size_adj - cfg.badge_favorite_spacing
    end

    -- Adjust position if cycle badge is visible (use pre-computed dimensions)
    if has_cycle then
      badge_x = badge_x - cycle_badge_w - cfg.badge_cycle_margin
    end

    local badge_y = scaled_y1 + (header_height - badge_h) / 2

    -- Badge background
    local badge_bg_alpha = ((cfg.badge_pool_bg & 0xFF) * combined_alpha) // 1
    local badge_bg = (cfg.badge_pool_bg & 0xFFFFFF00) | badge_bg_alpha
    DrawList_AddRectFilled(dl, badge_x, badge_y, badge_x + badge_w, badge_y + badge_h, badge_bg, cfg.badge_pool_rounding)

    -- Border using darker tile color (PERF: inline functions)
    local border_color = with_alpha(adjust_brightness(render_color, cfg.badge_pool_border_darken), cfg.badge_pool_border_alpha)
    DrawList_AddRect(dl, badge_x, badge_y, badge_x + badge_w, badge_y + badge_h, border_color, cfg.badge_pool_rounding, 0, 0.5)

    -- Pool count text (match cycle badge brightness) (PERF: inline functions)
    local pool_text_color = with_alpha(palette.pool_badge_text or 0xFFFFFFDD, float_to_alpha(combined_alpha))
    DrawList_AddText(dl, badge_x + cfg.badge_pool_padding_x, badge_y + cfg.badge_pool_padding_y, pool_text_color, pool_text)
  end

  -- Render duration text at bottom right (plain text, no badge - matches Region Playlist style)
  -- Don't render on compact tiles or if show_duration is disabled
  -- PERF: Use cached settings instead of per-tile state.settings lookup
  local show_duration = settings.show_duration
  if show_duration == nil then show_duration = true end
  -- PERF: Use cached duration from item_data (avoids GetMediaItemInfo_Value per frame)
  local duration = item_data.duration or 0
  if show_duration and combined_factor > 0.3 and compact_factor < 0.5 and duration > 0 then
      -- PERF: Cache duration text and dimensions by UUID (consistent with region chips)
      local dur_cache = _cached.duration_text[item_data.uuid]
      local duration_text, dur_text_w, dur_text_h

      if dur_cache then
        duration_text, dur_text_w, dur_text_h = dur_cache[1], dur_cache[2], dur_cache[3]
      else
        duration_text = Duration.format_hms(duration)
        dur_text_w, dur_text_h = CalcTextSize(ctx, duration_text)
        _cached.duration_text[item_data.uuid] = {duration_text, dur_text_w, dur_text_h}
      end

      local dur_x = scaled_x2 - dur_text_w - cfg.duration_text_margin_x
      local dur_y = scaled_y2 - dur_text_h - cfg.duration_text_margin_y

      -- PERF: Use cached dur_text_color for settled tiles (avoids luminance + SameHueVariant per frame)
      local dur_text_color
      if can_use_cache and cached_state.dur_text_color then
        dur_text_color = cached_state.dur_text_color
      else
        -- Adaptive color: dark grey with subtle tile coloring for most tiles, light only for very dark
        local luminance = Colors_luminance(render_color)
        if luminance < cfg.duration_text_dark_tile_threshold then
          -- Very dark tile only: use light text
          dur_text_color = Colors_SameHueVariant(render_color, cfg.duration_text_light_saturation, cfg.duration_text_light_value, float_to_alpha(combined_alpha))
        else
          -- All other tiles: dark grey with subtle tile color
          dur_text_color = Colors_SameHueVariant(render_color, cfg.duration_text_dark_saturation, cfg.duration_text_dark_value, float_to_alpha(combined_alpha))
        end
        -- Cache if settled
        if cached_state and cached_state.settled and cascade_factor >= 0.999 and not tile_state.selected then
          cached_state.dur_text_color = dur_text_color
        end
      end

      -- Draw duration text (PERF: use localized DrawList function)
      DrawList_AddText(dl, dur_x, dur_y, dur_text_color, duration_text)
  end

  -- PROFILER: Accumulate and report
  if M.profile_enabled then
    t8 = time_precise()
    _profile.animator = _profile.animator + (t1 - t0)
    _profile.color = _profile.color + (t2 - t1)
    _profile.draw_base = _profile.draw_base + (t3 - t2)
    _profile.wave = _profile.wave + (t4 - t3)
    _profile.header = _profile.header + (t5 - t4)
    _profile.ants = _profile.ants + (t6 - t5)
    _profile.text = _profile.text + (t7 - t6)
    _profile.badges = _profile.badges + (t8 - t7)
    _profile.count = _profile.count + 1
    profile_report()
  end
end

return M

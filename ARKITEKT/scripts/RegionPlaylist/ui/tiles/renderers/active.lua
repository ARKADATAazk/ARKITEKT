-- @noindex
-- RegionPlaylist/ui/tiles/renderers/active.lua
-- MODIFIED: Lowered responsive threshold for text.

local ImGui = require('arkitekt.core.imgui')
local Ark = require('arkitekt')

local TileFXConfig = require('arkitekt.gui.renderers.tile.defaults')
local BaseRenderer = require('RegionPlaylist.ui.tiles.renderers.base')
local State = require('RegionPlaylist.app.state')
local Layout = require('RegionPlaylist.config.layout')

-- Performance: Localize math functions for hot path (30% faster in loops)
local max = math.max
local time_precise = reaper.time_precise

-- Performance: Localize ImGui/Ark functions
local CalcTextSize = ImGui.CalcTextSize
local DrawList_AddRectFilled = ImGui.DrawList_AddRectFilled
local DrawList_AddRect = ImGui.DrawList_AddRect
local SetCursorScreenPos = ImGui.SetCursorScreenPos
local InvisibleButton = ImGui.InvisibleButton
local IsItemClicked = ImGui.IsItemClicked
local Colors_WithAlpha = Ark.Colors.WithAlpha
local Colors_Desaturate = Ark.Colors.Desaturate
local Colors_AdjustBrightness = Ark.Colors.AdjustBrightness
local Colors_Luminance = Ark.Colors.Luminance
local Draw_Text = Ark.Draw.Text

local M = {}

-- ============================================================================
-- PROFILING (set to true to enable, check REAPER console for output)
-- ============================================================================
local PROFILE_ENABLED = false
local _profile = {
  animator = 0,
  color = 0,
  fx_config = 0,
  playback = 0,
  base_tile = 0,
  text = 0,
  badge = 0,
  length = 0,
  count = 0,
  last_report = 0,
}

local function profile_report()
  if not PROFILE_ENABLED then return end
  local now = time_precise()
  if now - _profile.last_report > 1.0 then
    reaper.ShowConsoleMsg(string.format(
      '[ACTIVE] %d tiles | anim:%.1fms | color:%.1fms | fx:%.1fms | playback:%.1fms | base:%.1fms | text:%.1fms | badge:%.1fms | len:%.1fms\n',
      _profile.count,
      _profile.animator * 1000,
      _profile.color * 1000,
      _profile.fx_config * 1000,
      _profile.playback * 1000,
      _profile.base_tile * 1000,
      _profile.text * 1000,
      _profile.badge * 1000,
      _profile.length * 1000
    ))
    -- Reset
    _profile.animator = 0
    _profile.color = 0
    _profile.fx_config = 0
    _profile.playback = 0
    _profile.base_tile = 0
    _profile.text = 0
    _profile.badge = 0
    _profile.length = 0
    _profile.count = 0
    _profile.last_report = now
  end
end
-- Use layout config for consistent values
local TA = Layout.TILE_ACTIVE

M.CONFIG = {
  -- Grid layout
  tile_width = 110,
  gap = 12,
  -- Appearance
  bg_base = 0x1A1A1AFF,
  badge_rounding = TA.badge_rounding,
  badge_padding_x = TA.badge_padding_x,
  badge_padding_y = TA.badge_padding_y,
  badge_margin = TA.badge_margin,
  badge_bg = 0x14181CFF,
  badge_border_alpha = 0x33,
  disabled = { desaturate = 0.8, brightness = 0.4, min_alpha = 0x33, fade_speed = 20.0, min_lightness = 0.28 },
  responsive = { hide_length_below = TA.hide_length_below, hide_badge_below = TA.hide_badge_below, hide_text_below = TA.hide_text_below },
  playlist_tile = { base_color = 0x3A3A3AFF },
  text_margin_right = TA.text_margin_right,
  badge_nudge_x = TA.badge_nudge_x,
  badge_nudge_y = TA.badge_nudge_y,
  badge_text_nudge_x = TA.badge_text_nudge_x,
  badge_text_nudge_y = TA.badge_text_nudge_y,
  -- Spawn animation
  spawn = { enabled = true, duration = 0.25, scale_start = 0.8 },
  -- Overlap warning badge (RED - nested regions)
  overlap = {
    icon = '⚠',
    badge_size = 18,
    badge_bg = 0x4A2020FF,
    badge_border = 0xFF4444FF,
    icon_color = 0xFFBB33FF,
  },
  -- Beyond project end warning badge (YELLOW/ORANGE)
  beyond = {
    icon = '⚠',
    badge_size = 18,
    badge_bg = 0x3A3010FF,
    badge_border = 0xFFAA22FF,
    icon_color = 0xFFDD44FF,
  },
  -- Skip badge (BLUE - scheduled transition will skip this tile)
  skip = {
    icon = '→',
    badge_bg = 0x1A2A3AFF,
    badge_border = 0x4488CCFF,
    icon_color = 0x66AAFFFF,
    desaturate = 0.7,
    brightness = 0.5,
  },
}

local function clamp_min_lightness(color, min_l)
  local lum = Colors_Luminance(color)
  if lum < (min_l or 0) then
    local factor = (min_l + 0.001) / max(lum, 0.001)
    return Colors_AdjustBrightness(color, factor)
  end
  return color
end

--- Render active tile (region or playlist)
--- @param opts table Render options
--- @param opts.ctx ImGui_Context ImGui context
--- @param opts.rect table {x1, y1, x2, y2} Tile bounds
--- @param opts.item table Item data {type, key, rid?, playlist_id?, enabled?, ...}
--- @param opts.state table Tile state {hover, pressed, selected}
--- @param opts.get_region_by_rid function Function(rid) -> region
--- @param opts.animator table TileAnimator instance
--- @param opts.on_repeat_cycle function Callback(key, current_loop, total_reps)
--- @param opts.hover_config table Animation config {animation_speed_hover}
--- @param opts.tile_height number Tile height in pixels
--- @param opts.border_thickness number Border thickness
--- @param opts.bridge table CoordinatorBridge instance
--- @param opts.get_playlist_by_id function Function(id) -> playlist
--- @param opts.grid table Grid instance
function M.render(opts)
  if opts.item.type == 'playlist' then
    M.render_playlist(opts)
  else
    M.render_region(opts)
  end
end

--- Render region tile
--- @param opts table Render options (same as M.render)
function M.render_region(opts)
  local t0 = PROFILE_ENABLED and time_precise() or 0

  local ctx = opts.ctx
  local rect = opts.rect
  local item = opts.item
  local state = opts.state
  local get_region_by_rid = opts.get_region_by_rid
  local animator = opts.animator
  local on_repeat_cycle = opts.on_repeat_cycle
  local hover_config = opts.hover_config
  local tile_height = opts.tile_height
  local border_thickness = opts.border_thickness
  local bridge = opts.bridge
  local grid = opts.grid
  local dl = ImGui.GetWindowDrawList(ctx)
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local region = get_region_by_rid(item.rid)
  if not region then return end

  local is_enabled = item.enabled ~= false

  -- Check if this item is being skipped due to scheduled transition
  local is_skipped = false
  if bridge then
    local skipped_keys = bridge:get_skipped_keys()
    is_skipped = skipped_keys and skipped_keys[item.key] or false
  end

  animator:track(item.key, 'hover', state.hover and 1.0 or 0.0, hover_config and hover_config.animation_speed_hover or Layout.ANIMATION.hover_speed)
  animator:track(item.key, 'enabled', is_enabled and 1.0 or 0.0, M.CONFIG.disabled.fade_speed)
  animator:track(item.key, 'skipped', is_skipped and 1.0 or 0.0, M.CONFIG.disabled.fade_speed)
  local hover_factor = animator:get(item.key, 'hover')
  local enabled_factor = animator:get(item.key, 'enabled')
  local skip_factor = animator:get(item.key, 'skipped')

  local t1 = PROFILE_ENABLED and time_precise() or 0

  local base_color = region.color or M.CONFIG.bg_base
  -- Apply disabled styling
  if enabled_factor < 1.0 then
    base_color = Colors_Desaturate(base_color, M.CONFIG.disabled.desaturate * (1.0 - enabled_factor))
    base_color = Colors_AdjustBrightness(base_color, 1.0 - (1.0 - M.CONFIG.disabled.brightness) * (1.0 - enabled_factor))
    base_color = clamp_min_lightness(base_color, M.CONFIG.disabled.min_lightness or 0.28)
  end
  -- Apply skip styling (blue-tinted dim)
  if skip_factor > 0 then
    base_color = Colors_Desaturate(base_color, M.CONFIG.skip.desaturate * skip_factor)
    base_color = Colors_AdjustBrightness(base_color, 1.0 - (1.0 - M.CONFIG.skip.brightness) * skip_factor)
    base_color = clamp_min_lightness(base_color, M.CONFIG.disabled.min_lightness or 0.28)
  end

  local t2 = PROFILE_ENABLED and time_precise() or 0

  local fx_config = TileFXConfig.get()
  fx_config.border_thickness = border_thickness or 1.0

  local t3 = PROFILE_ENABLED and time_precise() or 0

  local playback_progress, playback_fade = 0, 0
  if bridge and bridge:get_state().is_playing then
    local current_key = bridge:get_current_item_key()
    if current_key == item.key then
      playback_progress = bridge:get_progress() or 0
      -- Store progress for fade out
      animator:track(item.key, 'last_progress', playback_progress, 999)  -- Instant update
      -- Time-based fade: fade in when playing, fade out at 100% or when stopped
      local target_fade = (playback_progress > 0 and playback_progress < 1.0) and 1.0 or 0.0
      local current_fade = animator:get(item.key, 'progress_fade') or 0
      -- Fade speeds from layout config
      local fade_speed = (target_fade > current_fade) and Layout.ANIMATION.fade_in_speed or Layout.ANIMATION.fade_out_speed
      animator:track(item.key, 'progress_fade', target_fade, fade_speed)
      playback_fade = animator:get(item.key, 'progress_fade')
    else
      -- Not currently playing this item, fade out at last known progress
      playback_progress = animator:get(item.key, 'last_progress') or 0
      animator:track(item.key, 'progress_fade', 0.0, Layout.ANIMATION.fade_out_speed)
      playback_fade = animator:get(item.key, 'progress_fade')
    end
  else
    -- Playback stopped, fade out at last known progress
    playback_progress = animator:get(item.key, 'last_progress') or 0
    animator:track(item.key, 'progress_fade', 0.0, Layout.ANIMATION.fade_out_speed)
    playback_fade = animator:get(item.key, 'progress_fade')
  end
  
  local t4 = PROFILE_ENABLED and time_precise() or 0

  BaseRenderer.draw_base_tile(ctx, dl, rect, base_color, fx_config, state, hover_factor, playback_progress, playback_fade)
  if state.selected and fx_config.ants_enabled then BaseRenderer.draw_marching_ants(dl, rect, base_color, fx_config) end

  local t5 = PROFILE_ENABLED and time_precise() or 0

  local actual_height = tile_height or (y2 - y1)
  local show_text = actual_height >= M.CONFIG.responsive.hide_text_below
  local show_badge = actual_height >= M.CONFIG.responsive.hide_badge_below
  local show_length = actual_height >= M.CONFIG.responsive.hide_length_below
  -- Compute text alpha accounting for both disabled and skip states
  local combined_factor = enabled_factor * (1.0 - skip_factor * 0.5)  -- Skip dims to 50%
  local text_alpha = (0xFF * combined_factor + M.CONFIG.disabled.min_alpha * (1.0 - combined_factor))//1

  -- Check for region warnings early (needed for right_elements calculation)
  -- Priority: Overlap (red) > Beyond project end (yellow)
  local has_overlap = State.has_region_overlap and State.has_region_overlap(item.rid)
  local is_beyond = not has_overlap and State.is_region_beyond_project_end and State.is_region_beyond_project_end(item.rid)
  local has_warning = has_overlap or is_beyond

  local right_elements = {}

  -- Pre-compute badge dimensions once (used for text bounds and badge rendering)
  local badge_text, bw, bh
  if show_badge then
    local reps = item.reps or 1
    badge_text = (reps == 0) and '∞' or ('×' .. reps)
    bw, bh = CalcTextSize(ctx, badge_text)
    bw, bh = bw * BaseRenderer.CONFIG.badge_font_scale, bh * BaseRenderer.CONFIG.badge_font_scale
    right_elements[#right_elements + 1] = BaseRenderer.create_element(
      true,
      bw + (M.CONFIG.badge_padding_x * 2),
      M.CONFIG.badge_margin
    )
  end

  -- Add warning badge to right_elements if needed (will be drawn left of reps badge)
  local warning_cfg = has_overlap and M.CONFIG.overlap or M.CONFIG.beyond
  if has_warning and show_badge then
    right_elements[#right_elements + 1] = BaseRenderer.create_element(
      true,
      warning_cfg.badge_size,
      4  -- Small gap between warning and reps badge
    )
  end

  -- Add skip badge to right_elements if item is being skipped
  if is_skipped and show_badge then
    local skip_icon_w = CalcTextSize(ctx, M.CONFIG.skip.icon) * BaseRenderer.CONFIG.badge_font_scale
    right_elements[#right_elements + 1] = BaseRenderer.create_element(
      true,
      skip_icon_w + M.CONFIG.badge_padding_x * 2,
      4  -- Small gap
    )
  end

  if show_text then
    local right_bound_x = BaseRenderer.calculate_text_right_bound(ctx, x2, M.CONFIG.text_margin_right, right_elements)
    local text_pos = BaseRenderer.calculate_text_position(ctx, rect, actual_height)
    BaseRenderer.draw_region_text(ctx, dl, text_pos, region, base_color, text_alpha, right_bound_x, grid, rect, item.key)
  end

  local t6 = PROFILE_ENABLED and time_precise() or 0

  -- Track reps badge position for overlap badge positioning
  local reps_badge_x, reps_badge_y, reps_badge_height = x2, y1, 0
  if show_badge then
    -- badge_text, bw, bh already computed above
    local badge_height = bh + M.CONFIG.badge_padding_y * 2
    local badge_x = x2 - bw - M.CONFIG.badge_padding_x * 2 - M.CONFIG.badge_margin
    local badge_y = BaseRenderer.calculate_badge_position(ctx, rect, badge_height, actual_height)
    local badge_x2, badge_y2 = badge_x + bw + M.CONFIG.badge_padding_x * 2, badge_y + bh + M.CONFIG.badge_padding_y * 2
    local badge_bg = (M.CONFIG.badge_bg & 0xFFFFFF00) | ((((M.CONFIG.badge_bg & 0xFF) * enabled_factor) + (M.CONFIG.disabled.min_alpha * (1.0 - enabled_factor)))//1)

    DrawList_AddRectFilled(dl, badge_x, badge_y, badge_x2, badge_y2, badge_bg, M.CONFIG.badge_rounding)
    DrawList_AddRect(dl, badge_x, badge_y, badge_x2, badge_y2, Colors_WithAlpha(base_color, M.CONFIG.badge_border_alpha), M.CONFIG.badge_rounding, 0, 0.5)
    Draw_Text(dl, badge_x + M.CONFIG.badge_padding_x + M.CONFIG.badge_text_nudge_x, badge_y + M.CONFIG.badge_padding_y + M.CONFIG.badge_text_nudge_y, Colors_WithAlpha(0xFFFFFFDD, text_alpha), badge_text)

    SetCursorScreenPos(ctx, badge_x, badge_y)
    InvisibleButton(ctx, '##badge_' .. item.key, badge_x2 - badge_x, badge_y2 - badge_y)
    if IsItemClicked(ctx, 0) and on_repeat_cycle then on_repeat_cycle(item.key) end

    -- Track for overlap badge alignment
    reps_badge_x = badge_x
    reps_badge_y = badge_y
    reps_badge_height = badge_height
  end

  local t7 = PROFILE_ENABLED and time_precise() or 0

  if show_length then BaseRenderer.draw_length_display(ctx, dl, rect, region, base_color, text_alpha) end

  local t8 = PROFILE_ENABLED and time_precise() or 0

  -- Track leftmost badge position for stacking badges
  local next_badge_x = reps_badge_x

  -- Draw warning badge (right side, left of reps badge, matching size)
  if has_warning and show_badge then
    -- Use same sizing as reps badge (text height + padding), but square
    local icon_w, icon_h = CalcTextSize(ctx, warning_cfg.icon)
    icon_w, icon_h = icon_w * BaseRenderer.CONFIG.badge_font_scale, icon_h * BaseRenderer.CONFIG.badge_font_scale
    local badge_w = icon_w + M.CONFIG.badge_padding_x * 2
    local badge_h = icon_h + M.CONFIG.badge_padding_y * 2
    local badge_x = next_badge_x - badge_w - 4  -- 4px gap from previous badge
    local badge_y = reps_badge_y  -- Same Y position as reps badge
    local badge_x2 = badge_x + badge_w
    local badge_y2 = badge_y + badge_h

    -- Draw badge background (same style as reps badge)
    local badge_bg = (warning_cfg.badge_bg & 0xFFFFFF00) | ((((warning_cfg.badge_bg & 0xFF) * enabled_factor) + (M.CONFIG.disabled.min_alpha * (1.0 - enabled_factor)))//1)
    DrawList_AddRectFilled(dl, badge_x, badge_y, badge_x2, badge_y2, badge_bg, M.CONFIG.badge_rounding)
    DrawList_AddRect(dl, badge_x, badge_y, badge_x2, badge_y2, warning_cfg.badge_border, M.CONFIG.badge_rounding, 0, 0.5)

    -- Draw warning icon centered
    local icon_x = badge_x + M.CONFIG.badge_padding_x + M.CONFIG.badge_text_nudge_x
    local icon_y = badge_y + M.CONFIG.badge_padding_y + M.CONFIG.badge_text_nudge_y
    Draw_Text(dl, icon_x, icon_y, warning_cfg.icon_color, warning_cfg.icon)

    -- Tooltip
    SetCursorScreenPos(ctx, badge_x, badge_y)
    InvisibleButton(ctx, item.key .. '_warning_tooltip', badge_w, badge_h)
    if ImGui.IsItemHovered(ctx) then
      if has_overlap then
        local nested_rids = State.get_nested_regions(item.rid)
        local nested_count = nested_rids and #nested_rids or 0
        ImGui.SetTooltip(ctx, string.format('Contains %d nested region%s', nested_count, nested_count ~= 1 and 's' or ''))
      else
        ImGui.SetTooltip(ctx, 'Region starts beyond project end')
      end
    end

    next_badge_x = badge_x  -- Update for next badge
  end

  -- Draw skip badge (blue, left of other badges) when tile is being skipped
  if skip_factor > 0 and show_badge then
    local skip_cfg = M.CONFIG.skip
    local icon_w, icon_h = CalcTextSize(ctx, skip_cfg.icon)
    icon_w, icon_h = icon_w * BaseRenderer.CONFIG.badge_font_scale, icon_h * BaseRenderer.CONFIG.badge_font_scale
    local badge_w = icon_w + M.CONFIG.badge_padding_x * 2
    local badge_h = icon_h + M.CONFIG.badge_padding_y * 2
    local badge_x = next_badge_x - badge_w - 4  -- 4px gap from previous badge
    local badge_y = reps_badge_y
    local badge_x2 = badge_x + badge_w
    local badge_y2 = badge_y + badge_h

    -- Fade badge alpha with skip_factor for smooth transition
    local skip_alpha = ((skip_cfg.badge_bg & 0xFF) * skip_factor)//1
    local badge_bg = (skip_cfg.badge_bg & 0xFFFFFF00) | skip_alpha
    local border_alpha = ((skip_cfg.badge_border & 0xFF) * skip_factor)//1
    local border_color = (skip_cfg.badge_border & 0xFFFFFF00) | border_alpha
    local icon_alpha = ((skip_cfg.icon_color & 0xFF) * skip_factor)//1
    local icon_color = (skip_cfg.icon_color & 0xFFFFFF00) | icon_alpha

    DrawList_AddRectFilled(dl, badge_x, badge_y, badge_x2, badge_y2, badge_bg, M.CONFIG.badge_rounding)
    DrawList_AddRect(dl, badge_x, badge_y, badge_x2, badge_y2, border_color, M.CONFIG.badge_rounding, 0, 0.5)

    -- Draw skip icon
    local icon_x = badge_x + M.CONFIG.badge_padding_x + M.CONFIG.badge_text_nudge_x
    local icon_y = badge_y + M.CONFIG.badge_padding_y + M.CONFIG.badge_text_nudge_y
    Draw_Text(dl, icon_x, icon_y, icon_color, skip_cfg.icon)

    -- Tooltip
    SetCursorScreenPos(ctx, badge_x, badge_y)
    InvisibleButton(ctx, item.key .. '_skip_tooltip', badge_w, badge_h)
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, 'Will be skipped (scheduled transition)')
    end
  end

  -- Profiling accumulation
  if PROFILE_ENABLED then
    local t9 = time_precise()
    _profile.animator = _profile.animator + (t1 - t0)
    _profile.color = _profile.color + (t2 - t1)
    _profile.fx_config = _profile.fx_config + (t3 - t2)
    _profile.playback = _profile.playback + (t4 - t3)
    _profile.base_tile = _profile.base_tile + (t5 - t4)
    _profile.text = _profile.text + (t6 - t5)
    _profile.badge = _profile.badge + (t7 - t6)
    _profile.length = _profile.length + (t8 - t7) + (t9 - t8)  -- Include overlap badge time
    _profile.count = _profile.count + 1
    profile_report()
  end
end

--- Render playlist tile
--- @param opts table Render options (same as M.render)
function M.render_playlist(opts)
  local ctx = opts.ctx
  local rect = opts.rect
  local item = opts.item
  local state = opts.state
  local animator = opts.animator
  local on_repeat_cycle = opts.on_repeat_cycle
  local hover_config = opts.hover_config
  local tile_height = opts.tile_height
  local border_thickness = opts.border_thickness
  local get_playlist_by_id = opts.get_playlist_by_id
  local bridge = opts.bridge
  local grid = opts.grid

  local dl = ImGui.GetWindowDrawList(ctx)
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local playlist = get_playlist_by_id and get_playlist_by_id(item.playlist_id) or {}
  
  -- Use cached duration from playlist if available, otherwise calculate
  -- Note: Duration should ideally be cached on playlist when items change
  local total_duration = playlist.cached_duration or 0
  if total_duration == 0 and playlist.items then
    -- Fallback: calculate duration (consider caching this in data layer)
    for _, pl_item in ipairs(playlist.items) do
      local item_type = pl_item.type or 'region'
      local rid = pl_item.rid

      if item_type == 'region' and rid then
        local region = State.get_region_by_rid(rid)
        if region then
          local duration = (region['end'] or 0) - (region.start or 0)
          local repeats = pl_item.reps or 1
          total_duration = total_duration + (duration * repeats)
        end
      end
    end
  end
  
  local playlist_data = {
    name = playlist.name or item.playlist_name or 'Unknown Playlist',
    item_count = playlist.items and #playlist.items or item.playlist_item_count or 0,
    chip_color = playlist.chip_color or item.chip_color or 0xFF5733FF,
    total_duration = total_duration
  }

  local is_enabled = item.enabled ~= false
  animator:track(item.key, 'hover', state.hover and is_enabled and 1.0 or 0.0, hover_config and hover_config.animation_speed_hover or Layout.ANIMATION.hover_speed)
  animator:track(item.key, 'enabled', is_enabled and 1.0 or 0.0, M.CONFIG.disabled.fade_speed)
  local hover_factor = animator:get(item.key, 'hover')
  local enabled_factor = animator:get(item.key, 'enabled')

  local base_color = M.CONFIG.playlist_tile.base_color
  local chip_color = playlist_data.chip_color

  -- Apply disabled state to both base and chip color
  if enabled_factor < 1.0 then
    base_color = Colors_Desaturate(base_color, M.CONFIG.disabled.desaturate * (1.0 - enabled_factor))
    base_color = Colors_AdjustBrightness(base_color, 1.0 - (1.0 - M.CONFIG.disabled.brightness) * (1.0 - enabled_factor))
    chip_color = Colors_Desaturate(chip_color, M.CONFIG.disabled.desaturate * (1.0 - enabled_factor))
    chip_color = Colors_AdjustBrightness(chip_color, 1.0 - (1.0 - M.CONFIG.disabled.brightness) * (1.0 - enabled_factor))
    local minL = M.CONFIG.disabled.min_lightness or 0.28
    base_color = clamp_min_lightness(base_color, minL)
    chip_color = clamp_min_lightness(chip_color, minL)
  end
  
  -- Update playlist_data with adjusted chip color
  playlist_data.chip_color = chip_color

  local fx_config = TileFXConfig.get()
  fx_config.border_thickness = border_thickness or 1.0

  -- Check if this playlist is currently playing (includes nested playlists)
  local playback_progress, playback_fade = 0, 0
  if bridge and bridge:get_state().is_playing then
    -- Use is_playlist_active to support deep nesting - all parent playlists show progress
    if bridge:is_playlist_active(item.key) then
      playback_progress = bridge:get_playlist_progress(item.key) or 0
      -- Store progress for fade out
      animator:track(item.key, 'last_progress', playback_progress, 999)  -- Instant update
      -- Time-based fade: fade in when playing, fade out at 100% or when stopped
      local target_fade = (playback_progress > 0 and playback_progress < 1.0) and 1.0 or 0.0
      local current_fade = animator:get(item.key, 'progress_fade') or 0
      -- Fade speeds from layout config
      local fade_speed = (target_fade > current_fade) and Layout.ANIMATION.fade_in_speed or Layout.ANIMATION.fade_out_speed
      animator:track(item.key, 'progress_fade', target_fade, fade_speed)
      playback_fade = animator:get(item.key, 'progress_fade')
    else
      -- Not currently playing this playlist, fade out at last known progress
      playback_progress = animator:get(item.key, 'last_progress') or 0
      animator:track(item.key, 'progress_fade', 0.0, Layout.ANIMATION.fade_out_speed)
      playback_fade = animator:get(item.key, 'progress_fade')
    end
  else
    -- Playback stopped, fade out at last known progress
    playback_progress = animator:get(item.key, 'last_progress') or 0
    animator:track(item.key, 'progress_fade', 0.0, Layout.ANIMATION.fade_out_speed)
    playback_fade = animator:get(item.key, 'progress_fade')
  end

  -- Draw base tile with chip color for border and playback progress
  BaseRenderer.draw_base_tile(ctx, dl, rect, base_color, fx_config, state, hover_factor, playback_progress, playback_fade, playlist_data.chip_color)
  
  if state.selected and fx_config.ants_enabled then BaseRenderer.draw_marching_ants(dl, rect, playlist_data.chip_color, fx_config) end

  local actual_height = tile_height or (y2 - y1)
  local show_text = actual_height >= M.CONFIG.responsive.hide_text_below
  local show_badge = actual_height >= M.CONFIG.responsive.hide_badge_below
  local show_length = actual_height >= M.CONFIG.responsive.hide_length_below
  local text_alpha = (0xFF * enabled_factor + M.CONFIG.disabled.min_alpha * (1.0 - enabled_factor))//1

  local right_elements = {}

  -- Pre-compute badge dimensions once (used for text bounds and badge rendering)
  local badge_text, bw, bh
  if show_badge then
    local reps = item.reps or 1
    badge_text = (reps == 0) and ('∞ [' .. playlist_data.item_count .. ']') or ('×' .. reps .. ' [' .. playlist_data.item_count .. ']')
    bw, bh = CalcTextSize(ctx, badge_text)
    bw, bh = bw * BaseRenderer.CONFIG.badge_font_scale, bh * BaseRenderer.CONFIG.badge_font_scale
    right_elements[#right_elements + 1] = BaseRenderer.create_element(
      true,
      bw + (M.CONFIG.badge_padding_x * 2),
      M.CONFIG.badge_margin
    )
  end

  if show_text then
    local right_bound_x = BaseRenderer.calculate_text_right_bound(ctx, x2, M.CONFIG.text_margin_right, right_elements)
    local text_pos = BaseRenderer.calculate_text_position(ctx, rect, actual_height)
    BaseRenderer.draw_playlist_text(ctx, dl, text_pos, playlist_data, state, text_alpha, right_bound_x, nil, actual_height, rect, grid, base_color, item.key)
  end

  if show_badge then
    -- badge_text, bw, bh already computed above
    local badge_height = bh + M.CONFIG.badge_padding_y * 2
    local badge_x = x2 - bw - M.CONFIG.badge_padding_x * 2 - M.CONFIG.badge_margin
    local badge_y = BaseRenderer.calculate_badge_position(ctx, rect, badge_height, actual_height)
    local badge_x2, badge_y2 = badge_x + bw + M.CONFIG.badge_padding_x * 2, badge_y + bh + M.CONFIG.badge_padding_y * 2
    local badge_bg = (M.CONFIG.badge_bg & 0xFFFFFF00) | ((((M.CONFIG.badge_bg & 0xFF) * enabled_factor) + (M.CONFIG.disabled.min_alpha * (1.0 - enabled_factor)))//1)

    DrawList_AddRectFilled(dl, badge_x, badge_y, badge_x2, badge_y2, badge_bg, M.CONFIG.badge_rounding)
    DrawList_AddRect(dl, badge_x, badge_y, badge_x2, badge_y2, Colors_WithAlpha(playlist_data.chip_color, M.CONFIG.badge_border_alpha), M.CONFIG.badge_rounding, 0, 0.5)
    Draw_Text(dl, badge_x + M.CONFIG.badge_padding_x + M.CONFIG.badge_text_nudge_x, badge_y + M.CONFIG.badge_padding_y + M.CONFIG.badge_text_nudge_y, Colors_WithAlpha(0xFFFFFFDD, text_alpha), badge_text)

    SetCursorScreenPos(ctx, badge_x, badge_y)
    InvisibleButton(ctx, '##badge_' .. item.key, badge_x2 - badge_x, badge_y2 - badge_y)
    if IsItemClicked(ctx, 0) and on_repeat_cycle then on_repeat_cycle(item.key) end
    
    -- Enhanced tooltip with playback info
    if ImGui.IsItemHovered(ctx) then
      local reps_text = (reps == 0) and '∞' or tostring(reps)
      local tooltip = string.format('Playlist • %d items • ×%s repeats', playlist_data.item_count, reps_text)
      
      if bridge and bridge:get_state().is_playing then
        local current_playlist_key = bridge:get_current_playlist_key()
        if current_playlist_key == item.key then
          local time_remaining = bridge:get_playlist_time_remaining(item.key)
          if time_remaining then
            local mins = (time_remaining / 60)//1
            local secs = (time_remaining % 60)//1
            tooltip = tooltip .. string.format('\n▶ Playing • %d:%02d remaining', mins, secs)
          end
        end
      end
      
      ImGui.SetTooltip(ctx, tooltip)
    end
  end
  
  -- Draw playlist duration in bottom right (like regions)
  if show_length then
    BaseRenderer.draw_playlist_length_display(ctx, dl, rect, playlist_data, base_color, text_alpha)
  end
end

return M
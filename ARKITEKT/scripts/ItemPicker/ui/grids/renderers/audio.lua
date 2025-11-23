-- @noindex
-- ItemPicker/ui/tiles/renderers/audio.lua
-- Audio tile renderer with waveform visualization

local ImGui = require 'imgui' '0.10'
local Colors = require('arkitekt.core.colors')
local Draw = require('arkitekt.gui.draw')
local MarchingAnts = require('arkitekt.gui.fx.interactions.marching_ants')
local BaseRenderer = require('ItemPicker.ui.grids.renderers.base')
local Shapes = require('arkitekt.gui.rendering.shapes')
local TileFX = require('arkitekt.gui.rendering.tile.renderer')

local M = {}

function M.render(ctx, dl, rect, item_data, tile_state, config, animator, visualization, state, badge_rects)
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local tile_w, tile_h = x2 - x1, y2 - y1
  local center_x, center_y = (x1 + x2) / 2, (y1 + y2) / 2

  local overlay_alpha = state.overlay_alpha or 1.0
  local cascade_factor = BaseRenderer.calculate_cascade_factor(rect, overlay_alpha, config)

  if cascade_factor < 0.001 then return end

  -- Apply cascade animation transform
  local scale = config.TILE_RENDER.cascade.scale_from + (1.0 - config.TILE_RENDER.cascade.scale_from) * cascade_factor
  local y_offset = config.TILE_RENDER.cascade.y_offset * (1.0 - cascade_factor)

  local scaled_w = tile_w * scale
  local scaled_h = tile_h * scale
  local scaled_x1 = center_x - scaled_w / 2
  local scaled_y1 = center_y - scaled_h / 2 + y_offset
  local scaled_x2 = center_x + scaled_w / 2
  local scaled_y2 = center_y + scaled_h / 2 + y_offset

  -- Check if we're in small tile mode (need this early for animations)
  local is_small_tile = scaled_h < config.TILE_RENDER.responsive.small_tile_height

  -- Track animations
  local is_disabled = state.disabled and state.disabled.audio and state.disabled.audio[item_data.filename]
  local is_muted = (item_data.track_muted or item_data.item_muted) and true or false

  if animator and item_data.key then
    animator:track(item_data.key, 'hover', tile_state.hover and 1.0 or 0.0, config.TILE_RENDER.animation_speed_hover)
    animator:track(item_data.key, 'enabled', is_disabled and 0.0 or 1.0, config.TILE_RENDER.disabled.fade_speed)
    animator:track(item_data.key, 'muted', is_muted and 1.0 or 0.0, config.TILE_RENDER.muted.fade_speed)
    -- Track compact mode for header transition (1.0 = compact/small, 0.0 = normal)
    animator:track(item_data.key, 'compact_mode', is_small_tile and 1.0 or 0.0, config.TILE_RENDER.animation_speed_header_transition)
  end

  local hover_factor = animator and animator:get(item_data.key, 'hover') or (tile_state.hover and 1.0 or 0.0)
  local enabled_factor = animator and animator:get(item_data.key, 'enabled') or (is_disabled and 0.0 or 1.0)
  local muted_factor = animator and animator:get(item_data.key, 'muted') or (is_muted and 1.0 or 0.0)
  local compact_factor = animator and animator:get(item_data.key, 'compact_mode') or (is_small_tile and 1.0 or 0.0)

  -- Track playback progress
  local playback_progress, playback_fade = 0, 0
  if state.is_previewing and state.is_previewing(item_data.item) then
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
  else
    -- Not currently playing this item, fade out at last known progress
    if animator and item_data.key then
      playback_progress = animator:get(item_data.key, 'last_progress') or 0
      animator:track(item_data.key, 'progress_fade', 0.0, 1.0)  -- 1 second fade out
      playback_fade = animator:get(item_data.key, 'progress_fade')
    end
  end

  -- Get base color from item
  local base_color = item_data.color or 0xFF555555

  -- Apply muted and disabled state effects
  local render_color = BaseRenderer.apply_state_effects(base_color, muted_factor, enabled_factor, config)

  -- Apply base tile fill adjustments (use compact mode values for small tiles)
  local sat_factor = is_small_tile and config.TILE_RENDER.base_fill.compact_saturation_factor or config.TILE_RENDER.base_fill.saturation_factor
  local bright_factor = is_small_tile and config.TILE_RENDER.base_fill.compact_brightness_factor or config.TILE_RENDER.base_fill.brightness_factor
  render_color = Colors.desaturate(render_color, 1.0 - sat_factor)
  render_color = Colors.adjust_brightness(render_color, bright_factor)

  -- ABSOLUTE MINIMUM LUMINANCE - NO BLACK TILES ALLOWED
  -- Enforce AFTER base_fill adjustments (which can make tiles very dark)
  -- but BEFORE hover effect (so all tiles meet minimum, not just hovered ones)
  -- Use HSL to set minimum lightness (works even for pure black colors)
  local min_lightness = config.TILE_RENDER.min_lightness
  local r, g, b, a = Colors.rgba_to_components(render_color)
  local h, s, l = Colors.rgb_to_hsl(render_color)
  if l < min_lightness then
    -- Set minimum lightness while preserving hue and saturation
    l = min_lightness
    local r_new, g_new, b_new = Colors.hsl_to_rgb(h, s, l)
    render_color = Colors.components_to_rgba(r_new, g_new, b_new, a)
  end

  -- Apply hover effect (brightness boost)
  if hover_factor > 0.001 then
    local hover_boost = config.TILE_RENDER.hover.brightness_boost * hover_factor
    render_color = Colors.adjust_brightness(render_color, 1.0 + hover_boost)
  end

  -- Calculate combined alpha with state effects
  local base_alpha = (render_color & 0xFF) / 255
  local combined_alpha, final_alpha = BaseRenderer.calculate_combined_alpha(cascade_factor, enabled_factor, muted_factor, base_alpha, config)
  render_color = Colors.with_alpha(render_color, math.floor(final_alpha * 255))

  local text_alpha = math.floor(0xFF * combined_alpha)
  local text_color = BaseRenderer.get_text_color(muted_factor, config)

  -- Calculate header height with animated transition
  local normal_header_height = math.max(
    config.TILE_RENDER.header.min_height,
    scaled_h * config.TILE_RENDER.header.height_ratio
  )
  local full_tile_height = scaled_h

  -- Interpolate between normal and full based on compact_factor
  -- compact_factor: 0.0 = normal mode, 1.0 = compact mode
  local header_height = normal_header_height + (full_tile_height - normal_header_height) * compact_factor

  -- Calculate header fade (fade out when going to compact, fade in when going to normal)
  -- In compact mode (compact_factor = 1.0), header alpha should be 0
  -- In normal mode (compact_factor = 0.0), header alpha should be normal
  local header_alpha_factor = 1.0 - compact_factor

  -- Render base tile fill with rounding
  ImGui.DrawList_AddRectFilled(dl, scaled_x1, scaled_y1, scaled_x2, scaled_y2, render_color, config.TILE.ROUNDING)

  -- Render dark backdrop for disabled items
  if enabled_factor < 0.999 then
    local backdrop_alpha = config.TILE_RENDER.disabled.backdrop_alpha * (1.0 - enabled_factor) * cascade_factor
    local backdrop_color = Colors.with_alpha(config.TILE_RENDER.disabled.backdrop_color, math.floor(backdrop_alpha))
    ImGui.DrawList_AddRectFilled(dl, scaled_x1, scaled_y1, scaled_x2, scaled_y2, backdrop_color, config.TILE.ROUNDING)
  end

  -- Render waveform BEFORE header so header can overlay with transparency
  -- (show even when disabled, just with toned down color)
  if item_data.item and cascade_factor > 0.2 then
    -- In small tile mode with visualization disabled, skip entirely for performance
    local show_viz_in_small = is_small_tile and (state.settings.show_visualization_in_small_tiles ~= false)
    if is_small_tile and not show_viz_in_small then
      -- Skip waveform rendering in small tile mode when visualization is disabled
      goto skip_waveform
    end

    local content_y1, content_h

    if show_viz_in_small then
      -- Render visualization over entire tile (header will overlay with transparency)
      content_y1 = scaled_y1
      content_h = scaled_h
    else
      -- Normal mode: render in content area below header
      content_y1 = scaled_y1 + header_height
      content_h = scaled_y2 - content_y1
    end

    local content_w = scaled_w

    ImGui.SetCursorScreenPos(ctx, scaled_x1, content_y1)
    ImGui.Dummy(ctx, content_w, content_h)

    local dark_color = BaseRenderer.get_dark_waveform_color(base_color, config)
    local waveform_alpha = combined_alpha * config.TILE_RENDER.waveform.line_alpha

    -- In small tile mode, apply very low opacity for subtle visualization
    if show_viz_in_small then
      waveform_alpha = waveform_alpha * config.TILE_RENDER.small_tile.visualization_alpha
    end

    dark_color = Colors.with_alpha(dark_color, math.floor(waveform_alpha * 255))

    -- Skip all waveform rendering if skip_visualizations is enabled (fast mode)
    if not state.skip_visualizations then
      -- Check runtime cache for waveform
      local waveform = state.runtime_cache and state.runtime_cache.waveforms[item_data.uuid]
      if waveform then
        if visualization.DisplayWaveformTransparent then
          -- Apply waveform quality multiplier to reduce resolution (better performance with many items)
          local quality = state.settings.waveform_quality or 1.0
          local target_width = math.floor(content_w * quality)
          local use_filled = state.settings.waveform_filled
          if use_filled == nil then use_filled = true end
          local show_zero_line = state.settings.waveform_zero_line or false
          visualization.DisplayWaveformTransparent(ctx, waveform, dark_color, dl, target_width, item_data.uuid, state.runtime_cache, use_filled, show_zero_line)
        end
      else
        -- Show placeholder and queue waveform generation
        BaseRenderer.render_placeholder(dl, scaled_x1, content_y1, scaled_x2, scaled_y2, render_color, combined_alpha)

        -- Queue waveform job
        if state.job_queue and state.job_queue.add_waveform_job then
          state.job_queue.add_waveform_job(item_data.item, item_data.uuid)
        end
      end
    end
  end

  ::skip_waveform::

  -- Render playback progress bar (after visualization, before header)
  if playback_progress > 0 and playback_fade > 0 then
    TileFX.render_playback_progress(dl, scaled_x1, scaled_y1, scaled_x2, scaled_y2, base_color, playback_progress, playback_fade, config.TILE.ROUNDING)
  end

  -- Render header with animated fade and size transition
  -- Apply header_alpha_factor for transition fade (fades out when going to compact, fades in when going to normal)
  local header_alpha = combined_alpha * header_alpha_factor
  if is_small_tile and header_alpha_factor < 0.1 then
    -- When mostly faded out in compact mode, apply small tile header alpha
    header_alpha = combined_alpha * config.TILE_RENDER.small_tile.header_alpha
  end
  BaseRenderer.render_header_bar(dl, scaled_x1, scaled_y1, scaled_x2, header_height,
    render_color, header_alpha, config, is_small_tile)

  -- Render marching ants for selection
  if tile_state.selected and cascade_factor > 0.5 then
    local selection_config = config.TILE_RENDER.selection
    local ant_color = Colors.same_hue_variant(
      base_color,
      selection_config.border_saturation,
      selection_config.border_brightness,
      math.floor(selection_config.ants_alpha * combined_alpha)
    )

    local inset = selection_config.ants_inset
    MarchingAnts.draw(
      dl,
      scaled_x1 + inset, scaled_y1 + inset, scaled_x2 - inset, scaled_y2 - inset,
      ant_color,
      selection_config.ants_thickness,
      config.TILE.ROUNDING,
      selection_config.ants_dash,
      selection_config.ants_gap,
      selection_config.ants_speed
    )
  end

  -- Check if item is favorited
  local is_favorite = state.favorites and state.favorites.audio and state.favorites.audio[item_data.filename]

  -- Calculate star badge space - match cycle badge height dynamically
  local fav_cfg = config.TILE_RENDER.badges.favorite
  local _, text_h = ImGui.CalcTextSize(ctx, "1")  -- Get text height to match cycle badge
  local star_badge_size = text_h + (config.TILE_RENDER.badges.cycle.padding_y * 2)  -- Match cycle badge calculation

  -- Calculate extra text margin to reserve space for favorite and pool badges (text truncation only)
  -- This doesn't affect cycle badge position, only text truncation
  local extra_text_margin = 0
  if is_favorite then
    extra_text_margin = star_badge_size + (fav_cfg.spacing or 4)
  end

  -- Add pool badge space if needed
  if item_data.pool_count and item_data.pool_count > 1 and cascade_factor > 0.5 then
    local pool_cfg = config.TILE_RENDER.badges.pool
    local pool_text = "×" .. tostring(item_data.pool_count)
    local pool_w, _ = ImGui.CalcTextSize(ctx, pool_text)
    local pool_badge_w = pool_w + pool_cfg.padding_x * 2
    extra_text_margin = extra_text_margin + pool_badge_w + (pool_cfg.spacing or 4)
  end

  -- Check if this tile is being renamed
  local is_renaming = state.rename_active and state.rename_uuid == item_data.uuid and state.rename_is_audio

  -- Populate rename text if it's empty (happens when moving to next item in batch)
  if is_renaming and (not state.rename_text or state.rename_text == "") then
    state.rename_text = item_data.name
  end

  -- Render text and badge (with reduced width if star is present)
  if cascade_factor > 0.3 then
    if is_renaming then
      -- Render inline rename input
      local input_x = scaled_x1 + 8
      local input_y = scaled_y1 + 4
      local input_w = (scaled_x2 - extra_text_margin) - input_x - 4
      local input_h = header_height - 8

      ImGui.SetCursorScreenPos(ctx, input_x, input_y)
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, 2, 2)
      ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, Colors.hexrgb("#1A1A1A"))
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, Colors.hexrgb("#FFFFFF"))
      ImGui.SetNextItemWidth(ctx, input_w)

      -- Auto-focus on first frame
      if not state.rename_focused then
        ImGui.SetKeyboardFocusHere(ctx)
        state.rename_focused = true
        state.rename_focus_frame = true  -- Mark this as the focus frame
      end

      local changed, new_text = ImGui.InputText(ctx, "##rename", state.rename_text, ImGui.InputTextFlags_EnterReturnsTrue)

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
        if not item or not reaper.ValidatePtr2(0, item, "MediaItem*") then
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
          reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", new_text, true)

          -- Update the name in the lookup immediately so tile reflects change
          if state.audio_item_lookup[item_data.uuid] then
            if type(state.audio_item_lookup[item_data.uuid]) == "table" then
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
        reaper.Undo_EndBlock("Rename item take", -1)

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
          state.rename_text = ""  -- Will be populated by factory on next frame
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
      -- Badge click callback to cycle through items
      -- Left-click: delta=1 (next), Right-click: delta=-1 (previous)
      local on_badge_click = function(delta)
        if item_data.total and item_data.total > 1 then
          state.cycle_audio_item(item_data.filename, delta)
          -- Force cache invalidation to update display (same as wheel_adjust)
          state.runtime_cache.audio_filter_hash = nil
        end
      end

      -- Pass full x2 (cycle badge position stays fixed), use extra_text_margin for text truncation only
      BaseRenderer.render_tile_text(ctx, dl, scaled_x1, scaled_y1, scaled_x2, header_height,
        item_data.name, item_data.index, item_data.total, render_color, text_alpha, config,
        item_data.uuid, badge_rects, on_badge_click, extra_text_margin, text_color)
    end
  end

  -- Render favorite star badge (vertically centered in header, to the left of cycle badge)
  if cascade_factor > 0.5 and is_favorite then
    local star_x
    -- Position favorite to the left of cycle badge (if it exists)
    if item_data.total and item_data.total > 1 then
      -- Calculate where cycle badge will be positioned
      local cycle_cfg = config.TILE_RENDER.badges.cycle
      local cycle_text = string.format("%d/%d", item_data.index or 1, item_data.total)
      local cycle_w, _ = ImGui.CalcTextSize(ctx, cycle_text)
      local cycle_badge_w = cycle_w + cycle_cfg.padding_x * 2
      local cycle_x = scaled_x2 - cycle_badge_w - cycle_cfg.margin
      -- Position favorite to the left of cycle badge
      star_x = cycle_x - star_badge_size - (fav_cfg.spacing or 4)
    else
      -- No cycle badge, position at right edge
      star_x = scaled_x2 - star_badge_size - fav_cfg.margin
    end

    local star_y = scaled_y1 + (header_height - star_badge_size) / 2
    local icon_size = fav_cfg.icon_size or state.icon_font_size
    Shapes.draw_favorite_star(ctx, dl, star_x, star_y, star_badge_size, combined_alpha, is_favorite,
      state.icon_font, icon_size, render_color, fav_cfg)
  end

  -- Render region tags (bottom left, only on larger tiles)
  -- Only show region chips if show_region_tags is enabled (regions are already processed if enable_region_processing is true)
  local show_region_tags = state.settings and state.settings.show_region_tags
  if show_region_tags and item_data.regions and #item_data.regions > 0 and
     not is_small_tile and scaled_h >= config.REGION_TAGS.min_tile_height and
     cascade_factor > 0.5 then

    local chip_cfg = config.REGION_TAGS.chip
    local chip_x = scaled_x1 + chip_cfg.margin_left
    local chip_y = scaled_y2 - chip_cfg.height - chip_cfg.margin_bottom

    -- Limit number of chips displayed
    local max_chips = config.REGION_TAGS.max_chips_per_tile
    local num_chips = math.min(#item_data.regions, max_chips)

    for i = 1, num_chips do
      local region = item_data.regions[i]
      local region_name = region.name or region  -- Support both {name, color} and plain string
      local region_color = region.color or 0x4A5A6AFF  -- Default gray if no color

      local text_w, text_h = ImGui.CalcTextSize(ctx, region_name)
      local chip_w = text_w + chip_cfg.padding_x * 2
      local chip_h = chip_cfg.height

      -- Check if chip fits within tile width
      if chip_x + chip_w > scaled_x2 - chip_cfg.margin_left then
        break  -- Stop rendering if we run out of space
      end

      -- Chip background (dark grey)
      local bg_alpha = math.floor(chip_cfg.alpha * combined_alpha)
      local bg_color = (chip_cfg.bg_color & 0xFFFFFF00) | bg_alpha
      ImGui.DrawList_AddRectFilled(dl, chip_x, chip_y, chip_x + chip_w, chip_y + chip_h, bg_color, chip_cfg.rounding)

      -- Chip text (region color with minimum lightness for readability)
      local text_color = BaseRenderer.ensure_min_lightness(region_color, chip_cfg.text_min_lightness)
      local text_alpha_val = math.floor(combined_alpha * 255)
      text_color = (text_color & 0xFFFFFF00) | text_alpha_val
      local text_x = chip_x + chip_cfg.padding_x
      local text_y = chip_y + (chip_h - text_h) / 2
      ImGui.DrawList_AddText(dl, text_x, text_y, text_color, region_name)

      -- Move to next chip position
      chip_x = chip_x + chip_w + chip_cfg.margin_x
    end
  end

  -- Render pool count badge in header (left of favorite/cycle badge) if more than 1 instance
  local should_show_pool_count = item_data.pool_count and item_data.pool_count > 1 and cascade_factor > 0.5
  if should_show_pool_count then
    local pool_cfg = config.TILE_RENDER.badges.pool
    local pool_text = "×" .. tostring(item_data.pool_count)
    local text_w, text_h = ImGui.CalcTextSize(ctx, pool_text)
    local badge_w = text_w + pool_cfg.padding_x * 2
    local badge_h = text_h + pool_cfg.padding_y * 2

    -- Position left of favorite/cycle badge
    local badge_x = scaled_x2 - badge_w - pool_cfg.margin

    -- Adjust position if favorite is visible
    if is_favorite then
      local fav_cfg = config.TILE_RENDER.badges.favorite
      local star_badge_size = text_h + (config.TILE_RENDER.badges.cycle.padding_y * 2)
      badge_x = badge_x - star_badge_size - (fav_cfg.spacing or 4)
    end

    -- Adjust position if cycle badge is visible
    if item_data.total and item_data.total > 1 then
      local cycle_badge_text = string.format("%d/%d", item_data.index or 1, item_data.total)
      local cycle_w, _ = ImGui.CalcTextSize(ctx, cycle_badge_text)
      local cycle_cfg = config.TILE_RENDER.badges.cycle
      local cycle_badge_w = cycle_w + cycle_cfg.padding_x * 2
      badge_x = badge_x - cycle_badge_w - cycle_cfg.margin
    end

    local badge_y = scaled_y1 + (header_height - badge_h) / 2

    -- Badge background
    local badge_bg_alpha = math.floor((pool_cfg.bg & 0xFF) * combined_alpha)
    local badge_bg = (pool_cfg.bg & 0xFFFFFF00) | badge_bg_alpha
    ImGui.DrawList_AddRectFilled(dl, badge_x, badge_y, badge_x + badge_w, badge_y + badge_h, badge_bg, pool_cfg.rounding)

    -- Border using darker tile color
    local border_color = Colors.adjust_brightness(render_color, pool_cfg.border_darken)
    border_color = Colors.with_alpha(border_color, pool_cfg.border_alpha)
    ImGui.DrawList_AddRect(dl, badge_x, badge_y, badge_x + badge_w, badge_y + badge_h, border_color, pool_cfg.rounding, 0, 0.5)

    -- Pool count text (match cycle badge brightness)
    local text_color = Colors.hexrgb("#FFFFFFDD")
    text_color = Colors.with_alpha(text_color, math.floor(combined_alpha * 255))
    ImGui.DrawList_AddText(dl, badge_x + pool_cfg.padding_x, badge_y + pool_cfg.padding_y, text_color, pool_text)
  end

  -- Render duration text at bottom right (plain text, no badge - matches Region Playlist style)
  -- Don't render on compact tiles or if show_duration is disabled
  local show_duration = state.settings.show_duration
  if show_duration == nil then show_duration = true end
  if show_duration and cascade_factor > 0.3 and compact_factor < 0.5 and item_data.item then
    local duration = reaper.GetMediaItemInfo_Value(item_data.item, "D_LENGTH")
    if duration > 0 then
      -- Format duration as time (mm:ss or hh:mm:ss)
      local duration_text
      if duration >= 3600 then
        local hours = math.floor(duration / 3600)
        local minutes = math.floor((duration % 3600) / 60)
        local seconds = math.floor(duration % 60)
        duration_text = string.format("%d:%02d:%02d", hours, minutes, seconds)
      else
        local minutes = math.floor(duration / 60)
        local seconds = math.floor(duration % 60)
        duration_text = string.format("%d:%02d", minutes, seconds)
      end

      -- Calculate text dimensions and position (right-aligned at bottom-right)
      local text_w, text_h = ImGui.CalcTextSize(ctx, duration_text)

      local dt_cfg = config.TILE_RENDER.duration_text
      local text_x = scaled_x2 - text_w - dt_cfg.margin_x
      local text_y = scaled_y2 - text_h - dt_cfg.margin_y

      -- Adaptive color: dark grey with subtle tile coloring for most tiles, light only for very dark
      local luminance = Colors.luminance(render_color)
      local text_color
      if luminance < dt_cfg.dark_tile_threshold then
        -- Very dark tile only: use light text
        text_color = Colors.same_hue_variant(render_color, dt_cfg.light_saturation, dt_cfg.light_value, math.floor(combined_alpha * 255))
      else
        -- All other tiles: dark grey with subtle tile color
        text_color = Colors.same_hue_variant(render_color, dt_cfg.dark_saturation, dt_cfg.dark_value, math.floor(combined_alpha * 255))
      end

      -- Draw duration text
      Draw.text(dl, text_x, text_y, text_color, duration_text)
    end
  end
end

return M

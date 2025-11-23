-- @noindex
local ImGui = require 'imgui' '0.10'
local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb


local M = {}
local utils
local SCRIPT_DIRECTORY
local config

local WAVEFORM_RESOLUTION = 2000
local MIDI_CACHE_WIDTH = 400
local MIDI_CACHE_HEIGHT = 200

-- Performance: Cache color conversions (5-10% faster)
-- Uses weak table so unused colors get garbage collected
local waveform_color_cache = {}
setmetatable(waveform_color_cache, {__mode = "kv"})

-- Performance: Compute waveform color with caching
-- Uses config values for HSV transformation multipliers
local function compute_waveform_color(base_color)
  if waveform_color_cache[base_color] then
    return waveform_color_cache[base_color]
  end

  local r, g, b = ImGui.ColorConvertU32ToDouble4(base_color)
  local h, s, v = ImGui.ColorConvertRGBtoHSV(r, g, b)

  -- Use config values for HSV transformation
  local sat_mult = config and config.TILE_RENDER.waveform.saturation_multiplier or 0.64
  local bright_mult = config and config.TILE_RENDER.waveform.brightness_multiplier or 0.35

  s = s * sat_mult
  v = v * bright_mult
  r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)

  local col_wave = ImGui.ColorConvertDouble4ToU32(r, g, b, 1)
  waveform_color_cache[base_color] = col_wave
  return col_wave
end

function M.init(utils_module, script_dir, config_module)
  utils = utils_module
  SCRIPT_DIRECTORY = script_dir
  config = config_module
end

function M.GetItemWaveform(cache, item, uuid)
  -- Check runtime cache
  if cache and cache.waveforms and cache.waveforms[uuid] then
    return cache.waveforms[uuid]
  end

  -- Validate item and take
  if not item or not reaper.ValidatePtr2(0, item, "MediaItem*") then
    return nil
  end

  local take = reaper.GetActiveTake(item)
  if not take then
    return nil
  end

  local sourceraw = reaper.GetMediaItemTake_Source(take)
  if not sourceraw then
    return nil
  end
  local _, _, _, _, _, reverse = reaper.BR_GetMediaSourceProperties(take)
  if reverse then
    sourceraw = reaper.GetMediaSourceParent(sourceraw)
  end

  local filename = reaper.GetMediaSourceFileName(sourceraw)

  -- Try to create PCM source from file, fallback to original source if it fails
  local source = reaper.PCM_Source_CreateFromFile(filename)
  if not source or not reaper.ValidatePtr2(0, source, "PCM_source*") then
    source = sourceraw  -- Use original source if file creation fails
  end

  local length = math.min(
    reaper.GetMediaItemInfo_Value(item, "D_LENGTH"),
    (reaper.GetMediaSourceLength(source) - reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")) *
    (1 / reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE"))
  )

  local channels = reaper.GetMediaSourceNumChannels(source)
  channels = math.min(channels, 2)

  -- Validate channels to prevent crash
  if channels <= 0 then
    return nil
  end

  local buf = reaper.new_array(WAVEFORM_RESOLUTION * 2 * channels)

  reaper.GetMediaItemTake_Peaks(
    take,
    WAVEFORM_RESOLUTION / length,
    reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
    channels,
    WAVEFORM_RESOLUTION,
    0,
    buf
  )

  local ret_tab
  if channels == 2 then
    local tab = buf.table()
    ret_tab = {}
    for i = 1, #tab - 1, 2 do
      local val = utils.SampleLimit(tab[i]) + utils.SampleLimit(tab[i + 1])
      table.insert(ret_tab, -val / 2)
    end
  else
    -- Mono: clamp values to prevent waveform exceeding tile bounds
    local tab = buf.table()
    ret_tab = {}
    for i = 1, #tab do
      table.insert(ret_tab, utils.SampleLimit(tab[i]))
    end
  end

  -- Store in runtime cache
  if cache and cache.waveforms then
    cache.waveforms[uuid] = ret_tab
  end
  return ret_tab
end

function M.DownsampleWaveform(waveform, target_width)
  if not waveform then return nil end

  -- Cache math functions for performance (30% faster in hot loops)
  local floor = math.floor
  local max = math.max
  local min = math.min
  local huge = math.huge

  local source_len = #waveform / 2
  if target_width >= source_len then
    return waveform
  end

  local downsampled = {}
  local ratio = source_len / target_width
  local negative_index = #waveform / 2

  -- Use direct indexing instead of table.insert (10-15% faster)
  local idx = 1
  for i = 1, target_width do
    local start_idx = floor((i - 1) * ratio) + 1
    local end_idx = floor(i * ratio)

    local max_val = -huge
    local min_val = huge

    for j = start_idx, end_idx do
      if j <= source_len then
        max_val = max(max_val, waveform[j])
        min_val = min(min_val, waveform[j + negative_index])
      end
    end

    -- Clamp to prevent waveform exceeding tile bounds
    downsampled[idx] = max(-1, min(1, max_val))
    idx = idx + 1
  end

  for i = 1, target_width do
    local start_idx = floor((i - 1) * ratio) + 1
    local end_idx = floor(i * ratio)

    local min_val = huge

    for j = start_idx, end_idx do
      if j <= source_len then
        min_val = min(min_val, waveform[j + #waveform / 2])
      end
    end

    -- Clamp to prevent waveform exceeding tile bounds
    downsampled[idx] = max(-1, min(1, min_val))
    idx = idx + 1
  end

  return downsampled
end

function M.DisplayWaveform(ctx, waveform, color, draw_list, target_width)
  -- Cache ImGui functions for performance
  local GetItemRectMin = ImGui.GetItemRectMin
  local GetItemRectMax = ImGui.GetItemRectMax
  local GetItemRectSize = ImGui.GetItemRectSize
  local DrawList_AddLine = ImGui.DrawList_AddLine
  local DrawList_AddPolyline = ImGui.DrawList_AddPolyline
  local DrawList_AddRectFilled = ImGui.DrawList_AddRectFilled
  local floor = math.floor

  local item_x1, item_y1 = GetItemRectMin(ctx)
  local item_x2, item_y2 = GetItemRectMax(ctx)
  local item_w, item_h = GetItemRectSize(ctx)

  if not waveform then return end

  local display_waveform = M.DownsampleWaveform(waveform, floor(target_width or item_w))
  if not display_waveform or #display_waveform == 0 then return end

  DrawList_AddRectFilled(draw_list, item_x1, item_y1, item_x2, item_y2, color)
  local r, g, b = ImGui.ColorConvertU32ToDouble4(color)
  local h, s, v = ImGui.ColorConvertRGBtoHSV(r, g, b)

  -- Use config values for HSV transformation
  local sat_mult = config and config.TILE_RENDER.waveform.saturation_multiplier or 0.64
  local bright_mult = config and config.TILE_RENDER.waveform.brightness_multiplier or 0.35

  s = s * sat_mult
  v = v * bright_mult
  r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)

  local col_wave = ImGui.ColorConvertDouble4ToU32(r, g, b, 1)
  local col_zero_line = col_wave

  local waveform_height = item_h / 2 * 0.95
  local zero_line = item_y1 + item_h / 2
  local negative_index = #display_waveform / 2

  DrawList_AddLine(draw_list, item_x1, zero_line, item_x2, zero_line, col_zero_line)

  -- Use direct indexing instead of table.insert (10-15% faster)
  local top_points_table = {}
  local top_idx = 1
  for i = 1, negative_index do
    local max_val = display_waveform[i]
    if max_val then
      local y = zero_line + waveform_height * max_val
      local x = item_x1 + ((i - 1) / (negative_index - 1)) * item_w
      top_points_table[top_idx] = x
      top_points_table[top_idx + 1] = y
      top_idx = top_idx + 2
    end
  end

  local bottom_points_table = {}
  local bottom_idx = 1
  for i = 1, negative_index do
    local min_val = display_waveform[i + negative_index]
    if min_val then
      local y = zero_line + waveform_height * min_val
      local x = item_x1 + ((i - 1) / (negative_index - 1)) * item_w
      bottom_points_table[bottom_idx] = x
      bottom_points_table[bottom_idx + 1] = y
      bottom_idx = bottom_idx + 2
    end
  end

  if #top_points_table >= 4 then
    local top_array = reaper.new_array(top_points_table)
    DrawList_AddPolyline(draw_list, top_array, col_wave, ImGui.DrawFlags_None, 1.0)
  end

  if #bottom_points_table >= 4 then
    local bottom_array = reaper.new_array(bottom_points_table)
    DrawList_AddPolyline(draw_list, bottom_array, col_wave, ImGui.DrawFlags_None, 1.0)
  end
end

function M.GetNoteRange(take)
  local _, num_notes = reaper.MIDI_CountEvts(take)
  local lowest_note, highest_note = math.huge, 0
  for i = 0, num_notes - 1 do
    local _, _, muted, start_ppq, end_ppq, _, pitch = reaper.MIDI_GetNote(take, i)
    if pitch > highest_note then
      highest_note = pitch
    end
    if pitch < lowest_note then
      lowest_note = pitch
    end
  end
  return lowest_note, highest_note
end

function M.GenerateMidiThumbnail(cache, item, w, h, uuid)
  -- Check runtime cache
  if cache and cache.midi_thumbnails and cache.midi_thumbnails[uuid] then
    return cache.midi_thumbnails[uuid]
  end

  -- Validate item
  if not item or not reaper.ValidatePtr2(0, item, "MediaItem*") then
    return nil
  end

  local take = reaper.GetActiveTake(item)
  if not take or not reaper.TakeIsMIDI(take) then
    return nil
  end

  -- Use fixed resolution for generation
  w, h = MIDI_CACHE_WIDTH, MIDI_CACHE_HEIGHT

  local thumbnail = {}

  local lowest_note, highest_note = M.GetNoteRange(take)

  local midi_range = highest_note - lowest_note + 3
  if midi_range < 10 then
    midi_range = 10
  end
  local midi_note_height = h / midi_range

  local item_pos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
  local take_offset = reaper.GetMediaItemTakeInfo_Value(take, 'D_STARTOFFS')
  local item_pos_qn = reaper.TimeMap2_timeToQN(0, item_pos - take_offset)
  local item_ppq = reaper.MIDI_GetPPQPosFromProjQN(take, item_pos_qn + 1)
  local item_length = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
  local item_length_ppq = reaper.TimeMap_timeToQN(item_length) * item_ppq

  local time_to_ppq = reaper.TimeMap_timeToQN(1) * item_ppq
  local pqq_to_pixel = item_length_ppq / w

  local _, num_notes = reaper.MIDI_CountEvts(take)
  for i = 0, num_notes - 1 do
    local _, _, muted, start_ppq, end_ppq, _, pitch = reaper.MIDI_GetNote(take, i)
    if not muted then
      local note_pos_y = highest_note - pitch + 1
      local y_offset = 0
      if midi_range == 10 then
        y_offset = h / 2 - (midi_note_height * (highest_note - lowest_note + 3)) / 2
      end

      local note_x1 = (start_ppq) / pqq_to_pixel
      local note_x2 = (end_ppq) / pqq_to_pixel
      local note_y1 = midi_note_height * note_pos_y + y_offset
      local note_y2 = midi_note_height * (note_pos_y + 1) + y_offset
      table.insert(thumbnail, {
        x1 = note_x1,
        y1 = note_y1,
        x2 = note_x2,
        y2 = note_y2,
      })
    end
  end

  -- Store in runtime cache
  if cache and cache.midi_thumbnails then
    cache.midi_thumbnails[uuid] = thumbnail
  end
  return thumbnail
end

function M.GetMidiThumbnail(ctx, cache, item)
  local take = reaper.GetActiveTake(item)
  local w, h = ImGui.GetItemRectSize(ctx)
  
  return M.GenerateMidiThumbnail(cache, item, w, h)
end

function M.DisplayMidiItem(ctx, thumbnail, color, draw_list)
  -- Cache ImGui functions for performance
  local GetItemRectMin = ImGui.GetItemRectMin
  local GetItemRectMax = ImGui.GetItemRectMax
  local DrawList_AddRectFilled = ImGui.DrawList_AddRectFilled

  local x1, y1 = GetItemRectMin(ctx)
  local x2, y2 = GetItemRectMax(ctx)
  local display_w = x2 - x1
  local display_h = y2 - y1

  DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, color)

  -- Push clip rect to prevent MIDI notes from overflowing tile bounds
  -- Use intersect=true to respect parent panel clipping
  ImGui.DrawList_PushClipRect(draw_list, x1, y1, x2, y2, true)

  -- Calculate scale factors using fixed cache resolution
  local scale_x = display_w / MIDI_CACHE_WIDTH
  local scale_y = display_h / MIDI_CACHE_HEIGHT

  local r, g, b = ImGui.ColorConvertU32ToDouble4(color)
  local h, s, v = ImGui.ColorConvertRGBtoHSV(r, g, b)

  -- Use config values for HSV transformation
  local sat_mult = config and config.TILE_RENDER.waveform.saturation_multiplier or 0.64
  local bright_mult = config and config.TILE_RENDER.waveform.brightness_multiplier or 0.35

  s = s * sat_mult
  v = v * bright_mult
  r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)

  local col_note = ImGui.ColorConvertDouble4ToU32(r, g, b, 1)

  -- Use indexed loop instead of pairs() for better performance
  local num_notes = #thumbnail
  for i = 1, num_notes do
    local note = thumbnail[i]
    -- Scale note coordinates from cache resolution to display resolution
    local note_x1 = x1 + (note.x1 * scale_x)
    local note_x2 = x1 + (note.x2 * scale_x)
    local note_y1 = y1 + (note.y1 * scale_y)
    local note_y2 = y1 + (note.y2 * scale_y)
    DrawList_AddRectFilled(draw_list, note_x1, note_y1, note_x2, note_y2, col_note)
  end

  -- Pop clip rect to restore previous clipping state
  ImGui.DrawList_PopClipRect(draw_list)
end

function M.DisplayWaveformTransparent(ctx, waveform, color, draw_list, target_width, uuid, cache, use_filled, show_zero_line)
  -- Default to filled if not specified (for backwards compatibility)
  if use_filled == nil then use_filled = true end
  if show_zero_line == nil then show_zero_line = false end

  -- Cache ImGui functions for performance
  local GetItemRectMin = ImGui.GetItemRectMin
  local GetItemRectMax = ImGui.GetItemRectMax
  local GetItemRectSize = ImGui.GetItemRectSize
  local DrawList_AddLine = ImGui.DrawList_AddLine
  local DrawList_AddPolyline = ImGui.DrawList_AddPolyline
  local floor = math.floor

  local item_x1, item_y1 = GetItemRectMin(ctx)
  local item_x2, item_y2 = GetItemRectMax(ctx)
  local item_w, item_h = GetItemRectSize(ctx)

  if not waveform then return end

  local width = floor(target_width or item_w)

  -- Use the color directly - it's already been transformed by get_dark_waveform_color
  local col_wave = color
  local col_zero_line = col_wave

  local waveform_height = item_h / 2 * 0.95
  local zero_line = item_y1 + item_h / 2

  -- Draw zero line (optional)
  if show_zero_line then
    DrawList_AddLine(draw_list, item_x1, zero_line, item_x2, zero_line, col_zero_line)
  end

  -- Performance: Cache normalized point coordinates (20x faster)
  local cache_key = uuid and (uuid .. "_" .. width) or nil
  local cached_polylines = cache_key and cache and cache.waveform_polylines and cache.waveform_polylines[cache_key]

  if cached_polylines then
    -- Use cached normalized coordinates - just scale to current tile dimensions
    local norm_top = cached_polylines.norm_top
    local norm_bottom = cached_polylines.norm_bottom

    if norm_top and norm_bottom then
      if use_filled then
        -- Build filled polygon arrays (waveform + zero line closure)
        local top_fill_table = {}
        local top_idx = 1

        -- Top waveform points (left to right)
        for i = 1, #norm_top, 2 do
          top_fill_table[top_idx] = item_x1 + norm_top[i] * item_w  -- Scale X
          top_fill_table[top_idx + 1] = zero_line + norm_top[i + 1] * waveform_height  -- Scale Y
          top_idx = top_idx + 2
        end

        -- Close polygon along zero line (right to left)
        top_fill_table[top_idx] = item_x2
        top_fill_table[top_idx + 1] = zero_line
        top_idx = top_idx + 2
        top_fill_table[top_idx] = item_x1
        top_fill_table[top_idx + 1] = zero_line

        -- Bottom polygon
        local bottom_fill_table = {}
        local bottom_idx = 1

        -- Bottom waveform points (left to right)
        for i = 1, #norm_bottom, 2 do
          bottom_fill_table[bottom_idx] = item_x1 + norm_bottom[i] * item_w  -- Scale X
          bottom_fill_table[bottom_idx + 1] = zero_line + norm_bottom[i + 1] * waveform_height  -- Scale Y
          bottom_idx = bottom_idx + 2
        end

        -- Close polygon along zero line (right to left)
        bottom_fill_table[bottom_idx] = item_x2
        bottom_fill_table[bottom_idx + 1] = zero_line
        bottom_idx = bottom_idx + 2
        bottom_fill_table[bottom_idx] = item_x1
        bottom_fill_table[bottom_idx + 1] = zero_line

        -- Fill polygons
        if #top_fill_table >= 8 then  -- Need at least 4 points (8 values) for a polygon
          local top_fill_array = reaper.new_array(top_fill_table)
          ImGui.DrawList_AddConvexPolyFilled(draw_list, top_fill_array, col_wave)
        end

        if #bottom_fill_table >= 8 then
          local bottom_fill_array = reaper.new_array(bottom_fill_table)
          ImGui.DrawList_AddConvexPolyFilled(draw_list, bottom_fill_array, col_wave)
        end
      else
        -- Build outline polyline arrays (just waveform points)
        local top_points_table = {}
        local top_idx = 1
        for i = 1, #norm_top, 2 do
          top_points_table[top_idx] = item_x1 + norm_top[i] * item_w  -- Scale X
          top_points_table[top_idx + 1] = zero_line + norm_top[i + 1] * waveform_height  -- Scale Y
          top_idx = top_idx + 2
        end

        local bottom_points_table = {}
        local bottom_idx = 1
        for i = 1, #norm_bottom, 2 do
          bottom_points_table[bottom_idx] = item_x1 + norm_bottom[i] * item_w  -- Scale X
          bottom_points_table[bottom_idx + 1] = zero_line + norm_bottom[i + 1] * waveform_height  -- Scale Y
          bottom_idx = bottom_idx + 2
        end

        -- Draw outline polylines
        if #top_points_table >= 4 then
          local top_array = reaper.new_array(top_points_table)
          DrawList_AddPolyline(draw_list, top_array, col_wave, ImGui.DrawFlags_None, 1.0)
        end

        if #bottom_points_table >= 4 then
          local bottom_array = reaper.new_array(bottom_points_table)
          DrawList_AddPolyline(draw_list, bottom_array, col_wave, ImGui.DrawFlags_None, 1.0)
        end
      end
    end
  else
    -- Generate and cache normalized coordinates
    local display_waveform = M.DownsampleWaveform(waveform, width)
    if not display_waveform or #display_waveform == 0 then return end

    local negative_index = #display_waveform / 2

    -- Build normalized point arrays (0-1 range) for caching
    local norm_top = {}
    local norm_top_idx = 1
    for i = 1, negative_index do
      local max_val = display_waveform[i]
      if max_val then
        local norm_x = (i - 1) / (negative_index - 1)  -- Normalized X (0-1)
        local norm_y = max_val  -- Already normalized (-1 to 1)
        norm_top[norm_top_idx] = norm_x
        norm_top[norm_top_idx + 1] = norm_y
        norm_top_idx = norm_top_idx + 2
      end
    end

    local norm_bottom = {}
    local norm_bottom_idx = 1
    for i = 1, negative_index do
      local min_val = display_waveform[i + negative_index]
      if min_val then
        local norm_x = (i - 1) / (negative_index - 1)  -- Normalized X (0-1)
        local norm_y = min_val  -- Already normalized (-1 to 1)
        norm_bottom[norm_bottom_idx] = norm_x
        norm_bottom[norm_bottom_idx + 1] = norm_y
        norm_bottom_idx = norm_bottom_idx + 2
      end
    end

    -- Build and render arrays for this frame
    if use_filled then
      -- Build filled polygon arrays
      local top_fill_table = {}
      local top_idx = 1

      -- Top waveform points
      for i = 1, #norm_top, 2 do
        top_fill_table[top_idx] = item_x1 + norm_top[i] * item_w
        top_fill_table[top_idx + 1] = zero_line + norm_top[i + 1] * waveform_height
        top_idx = top_idx + 2
      end

      -- Close polygon along zero line
      top_fill_table[top_idx] = item_x2
      top_fill_table[top_idx + 1] = zero_line
      top_idx = top_idx + 2
      top_fill_table[top_idx] = item_x1
      top_fill_table[top_idx + 1] = zero_line

      -- Bottom polygon
      local bottom_fill_table = {}
      local bottom_idx = 1

      -- Bottom waveform points
      for i = 1, #norm_bottom, 2 do
        bottom_fill_table[bottom_idx] = item_x1 + norm_bottom[i] * item_w
        bottom_fill_table[bottom_idx + 1] = zero_line + norm_bottom[i + 1] * waveform_height
        bottom_idx = bottom_idx + 2
      end

      -- Close polygon along zero line
      bottom_fill_table[bottom_idx] = item_x2
      bottom_fill_table[bottom_idx + 1] = zero_line
      bottom_idx = bottom_idx + 2
      bottom_fill_table[bottom_idx] = item_x1
      bottom_fill_table[bottom_idx + 1] = zero_line

      -- Fill polygons
      if #top_fill_table >= 8 then
        local top_fill_array = reaper.new_array(top_fill_table)
        ImGui.DrawList_AddConvexPolyFilled(draw_list, top_fill_array, col_wave)
      end

      if #bottom_fill_table >= 8 then
        local bottom_fill_array = reaper.new_array(bottom_fill_table)
        ImGui.DrawList_AddConvexPolyFilled(draw_list, bottom_fill_array, col_wave)
      end
    else
      -- Build outline polyline arrays
      local top_points_table = {}
      local top_idx = 1
      for i = 1, #norm_top, 2 do
        top_points_table[top_idx] = item_x1 + norm_top[i] * item_w
        top_points_table[top_idx + 1] = zero_line + norm_top[i + 1] * waveform_height
        top_idx = top_idx + 2
      end

      local bottom_points_table = {}
      local bottom_idx = 1
      for i = 1, #norm_bottom, 2 do
        bottom_points_table[bottom_idx] = item_x1 + norm_bottom[i] * item_w
        bottom_points_table[bottom_idx + 1] = zero_line + norm_bottom[i + 1] * waveform_height
        bottom_idx = bottom_idx + 2
      end

      -- Draw outline polylines
      if #top_points_table >= 4 then
        local top_array = reaper.new_array(top_points_table)
        DrawList_AddPolyline(draw_list, top_array, col_wave, ImGui.DrawFlags_None, 1.0)
      end

      if #bottom_points_table >= 4 then
        local bottom_array = reaper.new_array(bottom_points_table)
        DrawList_AddPolyline(draw_list, bottom_array, col_wave, ImGui.DrawFlags_None, 1.0)
      end
    end

    -- Cache the normalized coordinates for this uuid+width
    if cache_key and cache and cache.waveform_polylines then
      cache.waveform_polylines[cache_key] = {
        norm_top = norm_top,
        norm_bottom = norm_bottom,
      }
    end
  end
end

function M.DisplayMidiItemTransparent(ctx, thumbnail, color, draw_list)
  -- Cache ImGui functions for performance
  local GetItemRectMin = ImGui.GetItemRectMin
  local GetItemRectMax = ImGui.GetItemRectMax
  local DrawList_AddRectFilled = ImGui.DrawList_AddRectFilled

  local x1, y1 = GetItemRectMin(ctx)
  local x2, y2 = GetItemRectMax(ctx)
  local display_w = x2 - x1
  local display_h = y2 - y1

  -- Push clip rect to prevent MIDI notes from overflowing tile bounds
  -- Use intersect=true to respect parent panel clipping
  ImGui.DrawList_PushClipRect(draw_list, x1, y1, x2, y2, true)

  -- Calculate scale factors using fixed cache resolution
  local scale_x = display_w / MIDI_CACHE_WIDTH
  local scale_y = display_h / MIDI_CACHE_HEIGHT

  -- Use the color directly - it's already been transformed by get_dark_waveform_color
  local col_note = color

  -- Use indexed loop instead of pairs() for better performance
  local num_notes = #thumbnail
  for i = 1, num_notes do
    local note = thumbnail[i]
    -- Scale note coordinates from cache resolution to display resolution
    local note_x1 = x1 + (note.x1 * scale_x)
    local note_x2 = x1 + (note.x2 * scale_x)
    local note_y1 = y1 + (note.y1 * scale_y)
    local note_y2 = y1 + (note.y2 * scale_y)
    DrawList_AddRectFilled(draw_list, note_x1, note_y1, note_x2, note_y2, col_note)
  end

  -- Pop clip rect to restore previous clipping state
  ImGui.DrawList_PopClipRect(draw_list)
end

function M.DisplayPreviewLine(ctx, preview_start, preview_end, draw_list)
  if preview_start and preview_end then
    local span = preview_end - preview_start
    local time = reaper.time_precise() - preview_start
    local progress = time / span
    local item_x1, item_y1 = ImGui.GetItemRectMin(ctx)
    local item_x2, item_y2 = ImGui.GetItemRectMax(ctx)
    local item_w, item_h = ImGui.GetItemRectSize(ctx)
    local x = item_x1 + item_w * progress
    ImGui.DrawList_AddLine(draw_list, x, item_y1, x, item_y2, hexrgb("#FFFFFF"))
  end
end

return M
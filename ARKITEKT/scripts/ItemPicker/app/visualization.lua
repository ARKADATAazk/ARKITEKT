-- @noindex
local ImGui = require 'imgui' '0.10'

local M = {}
local utils
local SCRIPT_DIRECTORY
local cache_manager

local WAVEFORM_RESOLUTION = 2000

function M.init(utils_module, script_dir, cache_mgr)
  utils = utils_module
  SCRIPT_DIRECTORY = script_dir
  cache_manager = cache_mgr
end

function M.GetItemWaveform(cache, item)
  local cached_data = cache_manager.get_waveform_data(cache, item)
  if cached_data then
    return cached_data
  end

  local take = reaper.GetActiveTake(item)
  local sourceraw = reaper.GetMediaItemTake_Source(take)
  local _, _, _, _, _, reverse = reaper.BR_GetMediaSourceProperties(take)
  if reverse then
    sourceraw = reaper.GetMediaSourceParent(sourceraw)
  end

  local filename = reaper.GetMediaSourceFileName(sourceraw)
  local source = reaper.PCM_Source_CreateFromFile(filename)

  local length = math.min(
    reaper.GetMediaItemInfo_Value(item, "D_LENGTH"),
    (reaper.GetMediaSourceLength(source) - reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")) *
    (1 / reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE"))
  )

  local channels = reaper.GetMediaSourceNumChannels(source)
  channels = math.min(channels, 2)

  local buf = reaper.new_array(WAVEFORM_RESOLUTION * 2 * channels)

  reaper.GetMediaItemTake_Peaks(take, WAVEFORM_RESOLUTION / length, reaper.GetMediaItemInfo_Value(item, "D_POSITION"), channels,
    WAVEFORM_RESOLUTION, 0, buf)

  local ret_tab
  if channels == 2 then
    local tab = buf.table()
    ret_tab = {}
    for i = 1, #tab - 1, 2 do
      local val = utils.SampleLimit(tab[i]) + utils.SampleLimit(tab[i + 1])
      table.insert(ret_tab, -val / 2)
    end
  else
    ret_tab = buf.table()
  end
  
  cache_manager.set_waveform_data(cache, item, ret_tab)
  return ret_tab
end

function M.DownsampleWaveform(waveform, target_width)
  if not waveform then return nil end
  
  local source_len = #waveform / 2
  if target_width >= source_len then
    return waveform
  end
  
  local downsampled = {}
  local ratio = source_len / target_width
  local negative_index = #waveform / 2
  
  for i = 1, target_width do
    local start_idx = math.floor((i - 1) * ratio) + 1
    local end_idx = math.floor(i * ratio)
    
    local max_val = -math.huge
    local min_val = math.huge
    
    for j = start_idx, end_idx do
      if j <= source_len then
        max_val = math.max(max_val, waveform[j])
        min_val = math.min(min_val, waveform[j + negative_index])
      end
    end
    
    table.insert(downsampled, max_val)
  end
  
  for i = 1, target_width do
    local start_idx = math.floor((i - 1) * ratio) + 1
    local end_idx = math.floor(i * ratio)
    
    local min_val = math.huge
    
    for j = start_idx, end_idx do
      if j <= source_len then
        min_val = math.min(min_val, waveform[j + #waveform / 2])
      end
    end
    
    table.insert(downsampled, min_val)
  end
  
  return downsampled
end

function M.DisplayWaveform(ctx, waveform, color, draw_list, target_width)
  local item_x1, item_y1 = ImGui.GetItemRectMin(ctx)
  local item_x2, item_y2 = ImGui.GetItemRectMax(ctx)
  local item_w, item_h = ImGui.GetItemRectSize(ctx)

  if not waveform then return end
  
  local display_waveform = M.DownsampleWaveform(waveform, math.floor(target_width or item_w))

  ImGui.DrawList_AddRectFilled(draw_list, item_x1, item_y1, item_x2, item_y2, color)
  local r, g, b = ImGui.ColorConvertU32ToDouble4(color)
  local h, s, v = ImGui.ColorConvertRGBtoHSV(r, g, b)
  s = s * 0.64
  v = v * 0.35
  r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)

  local col_wave = ImGui.ColorConvertDouble4ToU32(r, g, b, 1)
  local col_zero_line = ImGui.ColorConvertDouble4ToU32(r, g, b, 0.4)

  local waveform_height = item_h / 2 * 0.95
  local zero_line = item_y1 + item_h / 2
  ImGui.DrawList_AddLine(draw_list, item_x1, zero_line, item_x2, zero_line, col_zero_line)
  local negative_index = #display_waveform / 2

  for i = 1, negative_index - 1 do
    local max = zero_line + waveform_height * display_waveform[i]
    local min = zero_line + waveform_height * display_waveform[i + negative_index]
    local max_next = zero_line + waveform_height * display_waveform[i + 1]
    local min_next = zero_line + waveform_height * display_waveform[i + 1 + negative_index]
    local pos_x = item_x1 + (i / negative_index) * item_w

    ImGui.DrawList_AddLine(draw_list, pos_x, max, pos_x, min, col_wave)
    if i < negative_index - 1 then
      local next_x = item_x1 + ((i + 1) / negative_index) * item_w
      ImGui.DrawList_AddLine(draw_list, pos_x, max, next_x, max_next, col_wave)
      ImGui.DrawList_AddLine(draw_list, pos_x, min, next_x, min_next, col_wave)
    end
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

function M.GetMidiThumbnail(ctx, cache, item)
  local take = reaper.GetActiveTake(item)
  local w, h = ImGui.GetItemRectSize(ctx)
  
  local cached_thumbnail = cache_manager.get_midi_thumbnail(cache, item, w, h)
  if cached_thumbnail then
    return cached_thumbnail
  end

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
  
  cache_manager.set_midi_thumbnail(cache, item, w, h, thumbnail)
  return thumbnail
end

function M.DisplayMidiItem(ctx, thumbnail, color, draw_list)
  local x1, y1 = ImGui.GetItemRectMin(ctx)
  local x2, y2 = ImGui.GetItemRectMax(ctx)
  ImGui.DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, color)

  local r, g, b = ImGui.ColorConvertU32ToDouble4(color)
  local h, s, v = ImGui.ColorConvertRGBtoHSV(r, g, b)
  s = s * 0.64
  v = v * 0.35
  r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)

  local col_note = ImGui.ColorConvertDouble4ToU32(r, g, b, 1)

  for key, note in pairs(thumbnail) do
    local note_x1 = x1 + note.x1
    local note_x2 = x1 + note.x2
    local note_y1 = y1 + note.y1
    local note_y2 = y1 + note.y2
    ImGui.DrawList_AddRectFilled(draw_list, note_x1, note_y1, note_x2, note_y2, col_note)
  end
end

function M.DisplayWaveformTransparent(ctx, waveform, color, draw_list, target_width)
  local item_x1, item_y1 = ImGui.GetItemRectMin(ctx)
  local item_x2, item_y2 = ImGui.GetItemRectMax(ctx)
  local item_w, item_h = ImGui.GetItemRectSize(ctx)

  if not waveform then return end
  
  local display_waveform = M.DownsampleWaveform(waveform, math.floor(target_width or item_w))
  
  local r, g, b = ImGui.ColorConvertU32ToDouble4(color)
  local h, s, v = ImGui.ColorConvertRGBtoHSV(r, g, b)
  s = s * 0.64
  v = v * 0.35
  r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)

  local col_wave = ImGui.ColorConvertDouble4ToU32(r, g, b, 1)
  local col_zero_line = ImGui.ColorConvertDouble4ToU32(r, g, b, 0.4)

  local waveform_height = item_h / 2 * 0.95
  local zero_line = item_y1 + item_h / 2
  ImGui.DrawList_AddLine(draw_list, item_x1, zero_line, item_x2, zero_line, col_zero_line)
  local negative_index = #display_waveform / 2

  for i = 1, negative_index - 1 do
    local max = zero_line + waveform_height * display_waveform[i]
    local min = zero_line + waveform_height * display_waveform[i + negative_index]
    local max_next = zero_line + waveform_height * display_waveform[i + 1]
    local min_next = zero_line + waveform_height * display_waveform[i + 1 + negative_index]
    local pos_x = item_x1 + (i / negative_index) * item_w

    ImGui.DrawList_AddLine(draw_list, pos_x, max, pos_x, min, col_wave)
    if i < negative_index - 1 then
      local next_x = item_x1 + ((i + 1) / negative_index) * item_w
      ImGui.DrawList_AddLine(draw_list, pos_x, max, next_x, max_next, col_wave)
      ImGui.DrawList_AddLine(draw_list, pos_x, min, next_x, min_next, col_wave)
    end
  end
end

function M.DisplayMidiItemTransparent(ctx, thumbnail, color, draw_list)
  local x1, y1 = ImGui.GetItemRectMin(ctx)
  local x2, y2 = ImGui.GetItemRectMax(ctx)

  local r, g, b = ImGui.ColorConvertU32ToDouble4(color)
  local h, s, v = ImGui.ColorConvertRGBtoHSV(r, g, b)
  s = s * 0.64
  v = v * 0.35
  r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)

  local col_note = ImGui.ColorConvertDouble4ToU32(r, g, b, 1)

  for key, note in pairs(thumbnail) do
    local note_x1 = x1 + note.x1
    local note_x2 = x1 + note.x2
    local note_y1 = y1 + note.y1
    local note_y2 = y1 + note.y2
    ImGui.DrawList_AddRectFilled(draw_list, note_x1, note_y1, note_x2, note_y2, col_note)
  end
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
    ImGui.DrawList_AddLine(draw_list, x, item_y1, x, item_y2, 0xFFFFFFFF)
  end
end

return M
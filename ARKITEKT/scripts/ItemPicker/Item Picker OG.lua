-- @noindex
local _, script_filename, _, _, _, _, _ = reaper.get_action_context()
SCRIPT_DIRECTORY = script_filename:match('(.*)[%\\/]') .. "\\"

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local imgui = require 'imgui' '0.9.2'

SCRIPT_TITLE = "Item Picker"

local profiler = dofile(reaper.GetResourcePath() ..
    '/Scripts/ReaTeam Scripts/Development/cfillion_Lua profiler.lua')
reaper.defer = profiler.defer

-- package.path = SCRIPT_DIRECTORY .. '/?.lua'
-- require "Pickle"
-- require "Utils"

dofile(reaper.GetResourcePath() .. "/UserPlugins/ultraschall_api.lua")
local ultraschall = ultraschall

if not imgui.CreateContext then
    reaper.MB("Missing dependency: ReaImGui extension.\nDownload it via Reapack ReaTeam extension repository.", "Error",
        0)
    return false
end

reaimgui_shim_file_path = reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua'
if reaper.file_exists(reaimgui_shim_file_path) then
    dofile(reaimgui_shim_file_path)('0.8.6')
end

-- Set ToolBar Button State
local function SetButtonState(set)
    local is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
    reaper.SetToggleCommandState(sec, cmd, set or 0)
    reaper.RefreshToolbar2(sec, cmd)
end


  ----------------------------------------------
  -- Pickle.lua
  -- A table serialization utility for lua
  -- Steve Dekorte, http://www.dekorte.com, Apr 2000
  -- Freeware
  ----------------------------------------------
  
  function Pickle(t)
    return PickleTable:clone():pickle_(t)
  end
  
  PickleTable = {
    clone = function(t)
      local nt = {}; for i, v in pairs(t) do nt[i] = v end
      return nt
    end
  }
  
  function PickleTable:pickle_(root)
    if type(root) ~= "table" then
      error("can only pickle tables, not " .. type(root) .. "s")
    end
    self._tableToRef = {}
    self._refToTable = {}
    local savecount = 0
    self:ref_(root)
    local s = ""
  
    while table.getn(self._refToTable) > savecount do
      savecount = savecount + 1
      local t = self._refToTable[savecount]
      s = s .. "{\n"
      for i, v in pairs(t) do
        s = string.format("%s[%s]=%s,\n", s, self:value_(i), self:value_(v))
      end
      s = s .. "},\n"
    end
  
    return string.format("{%s}", s)
  end
  
  function PickleTable:value_(v)
    local vtype = type(v)
    if vtype == "string" then
      return string.format("%q", v)
    elseif vtype == "number" then
      return v
    elseif vtype == "boolean" then
      return tostring(v)
    elseif vtype == "table" then
      return "{" .. self:ref_(v) .. "}"
    else --error("pickle a "..type(v).." is not supported")
    end
  end
  
  function PickleTable:ref_(t)
    local ref = self._tableToRef[t]
    if not ref then
      if t == self then error("can't pickle the pickle class") end
      table.insert(self._refToTable, t)
      ref = table.getn(self._refToTable)
      self._tableToRef[t] = ref
    end
    return ref
  end
  
  ----------------------------------------------
  -- unpickle
  ----------------------------------------------
  
  function Unpickle(s)
    if type(s) ~= "string" then
      error("can't unpickle a " .. type(s) .. ", only strings")
    end
    local gentables = load("return " .. s)
    local tables = gentables()
  
    for tnum = 1, table.getn(tables) do
      local t = tables[tnum]
      local tcopy = {}; for i, v in pairs(t) do tcopy[i] = v end
      for i, v in pairs(tcopy) do
        local ni, nv
        if type(i) == "table" then ni = tables[i[1]] else ni = i end
        if type(v) == "table" then nv = tables[v[1]] else nv = v end
        t[i] = nil
        t[ni] = nv
      end
    end
    return tables[1]
  end

----------------------------------------------------------------------
-- OTHER --
----------------------------------------------------------------------

local settings = {
    play_item_through_track = false,
    show_muted_tracks = false,
    show_muted_items = false,
    focus_keyboard_on_init = true,
}

local state = {
    item_waveforms = {},
    waveform_bitmaps = {},
    midi_thumbnails = {},
    box_current_sample = {},
    box_current_item = {},
    scroll_y = {},
    previewing = 0,
    time_since_last_bitmap_draw = 0,
}

local function Exit()
    SetButtonState()
    reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_STOPPREVIEW"), 0) -- Xenakios/SWS: Preview selected media item through track
    reaper.SetProjExtState(0, "ItemPicker", "settings", Pickle(settings))
end

local rv, pickled_settings = reaper.GetProjExtState(0, "ItemPicker", "settings")
if rv == 1 then
    settings = Unpickle(pickled_settings)
end

function table.getn(tab)
    local i = 0
    for _ in pairs(tab) do
        i = i + 1
    end
    return i
end

local function GetAllTracks()
    local tracks = {}
    for i = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, i)
        table.insert(tracks, track)
    end
    return tracks
end

local function GetTrackID(track)
    return reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
end

local function GetItemInTrack(track)
    local items = {}
    for i = 0, reaper.CountTrackMediaItems(track) - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        table.insert(items, item)
    end
    return items
end

local function RGBvalues(RGB)
    local R = RGB & 255
    local G = (RGB >> 8) & 255
    local B = (RGB >> 16) & 255
    local R = R / 255
    local G = G / 255
    local B = B / 255
    return R, G, B
end


local function TrackIsFrozen(track)
    local chunk = state.track_chunks[GetTrackID(track)]
    return chunk:find("<FREEZE")
end

local function IsParentFrozen(track)
    getParentTrack = reaper.GetParentTrack
    local parentTrack = getParentTrack(track)
    while parentTrack do
        if TrackIsFrozen(track) then
            return true
        end
        parentTrack = getParentTrack(parentTrack)
    end
end

local function IsParentMuted(track)
    getParentTrack = reaper.GetParentTrack
    local function isTrackMuted(track) return reaper.GetMediaTrackInfo_Value(track, "B_MUTE") > 0 end

    local parentTrack = getParentTrack(track)
    while parentTrack do
        if isTrackMuted(parentTrack) then
            return true
        end
        parentTrack = getParentTrack(parentTrack)
    end
end

local function RemoveKeyFromChunk(chunk_string, key) -- CHATGPT Thank You
    -- Pattern to match the key and everything until the next newline, non-greedy
    local pattern = key .. "[^\n]*\n?"

    -- Replace all occurrences of the pattern with an empty string
    local modified_chunk = string.gsub(chunk_string, pattern, "")

    return modified_chunk
end


local function GetAllTrackStateChunks()
    local all_tracks = GetAllTracks()
    local chunks = {}
    for key, track in pairs(all_tracks) do
        local _, chunk = reaper.GetTrackStateChunk(track, "")
        table.insert(chunks, chunk)
    end
    return chunks
end

local function GetAllCleanedItemChunks()
    local item_chunks = {}
    for i = 0, reaper.CountMediaItems(0) - 1 do
        local item = reaper.GetMediaItem(0, i)
        local _, chunk = reaper.GetItemStateChunk(item, "")
        chunk = RemoveKeyFromChunk(chunk, "POSITION")
        chunk = RemoveKeyFromChunk(chunk, "IGUID")
        chunk = RemoveKeyFromChunk(chunk, "IID")
        chunk = RemoveKeyFromChunk(chunk, "GUID")
        local track_id = GetTrackID(reaper.GetMediaItemTrack(item))
        local item_id = reaper.GetMediaItemInfo_Value(item, "IP_ITEMNUMBER")
        item_chunks[track_id .. " " .. item_id] = chunk
    end
    return item_chunks
end


local function ItemChunkID(item)
    local track = reaper.GetMediaItemTrack(item)
    local track_id = GetTrackID(track)
    local item_id = reaper.GetMediaItemInfo_Value(item, "IP_ITEMNUMBER")
    return track_id .. " " .. item_id
end

local function GetProjectSamples()
    local all_tracks = GetAllTracks()
    -- {filename1 = {1 = MediaItem, 2 = MediaItem...}, filename2 = {1 = MediaItem, 2 = MediaItem...}....}
    local samples = {}
    local sample_indexes = {}
    for key, track in pairs(all_tracks) do
        if reaper.GetMediaTrackInfo_Value(track, "B_SHOWINTCP") == 0 or IsParentFrozen(track) == true then
            goto next_track
        end
        if not settings.show_muted_tracks and (reaper.GetMediaTrackInfo_Value(track, "B_MUTE") == 1 or IsParentMuted(track)) then
            goto next_track
        end
        local track_items = GetItemInTrack(track)
        for key, item in pairs(track_items) do
            if not settings.show_muted_items and reaper.GetMediaItemInfo_Value(item, "B_MUTE") == 1 then
                goto next_item
            end
            local take = reaper.GetActiveTake(item)
            if not reaper.TakeIsMIDI(take) then
                local source = reaper.GetMediaItemTake_Source(take)
                local _, _, _, _, _, reverse = reaper.BR_GetMediaSourceProperties(take)
                if reverse then
                    source = reaper.GetMediaSourceParent(source)
                end
                local filename = reaper.GetMediaSourceFileName(source)
                if not filename then
                    goto next_item
                end
                if not samples[filename] then
                    table.insert(sample_indexes, filename)
                    samples[filename] = {}
                end
                for key, _item in pairs(samples[filename]) do
                    if state.item_chunks[ItemChunkID(item)] == state.item_chunks[ItemChunkID(_item[1])] then
                        goto next_item
                    end
                end
                local item_name = (filename:match("[^/\\]+$") or ""):match("(.+)%..+$") or
                    filename:match("[^/\\]+$")
                table.insert(samples[filename], { item, item_name })
            end
            ::next_item::
        end
        ::next_track::
    end
    return samples, sample_indexes
end

local function GetProjectMidiTracks()
    local all_tracks = GetAllTracks()

    -- {1 = {1 = MediaItem, 2 = MediaItem....} , 2 = {1 = MediaItem, 2 = MediaItem....} ....}
    local midi_tracks = {}
    for key, track in pairs(all_tracks) do
        if reaper.GetMediaTrackInfo_Value(track, "B_SHOWINTCP") == 0 or IsParentFrozen(track) == true then
            goto next_track
        end
        if not settings.show_muted_tracks and (reaper.GetMediaTrackInfo_Value(track, "B_MUTE") == 1 or IsParentMuted(track)) then
            goto next_track
        end
        local track_items = GetItemInTrack(track)
        local track_midi = {}
        for key, item in pairs(track_items) do
            if not settings.show_muted_items and reaper.GetMediaItemInfo_Value(item, "B_MUTE") == 1 then
                goto next_item
            end
            local take = reaper.GetActiveTake(item)
            if reaper.TakeIsMIDI(take) then
                local _, num_notes = reaper.MIDI_CountEvts(take)
                if num_notes == 0 then
                    goto next_item
                end
                local _, midi = reaper.MIDI_GetAllEvts(take)
                for key, _item in pairs(track_midi) do
                    local _, _midi = reaper.MIDI_GetAllEvts(reaper.GetActiveTake(_item))
                    if midi == _midi then
                        goto next_item
                    end
                end
                table.insert(track_midi, item)
            end
            ::next_item::
        end
        if #track_midi > 0 then
            table.insert(midi_tracks, track_midi)
        end
        ::next_track::
    end

    return midi_tracks
end


local function Color(r, g, b, a)
    return imgui.ColorConvertDouble4ToU32(r, g, b, a)
end

local function SampleLimit(spl)
    return math.max(-1, math.min(spl, 1))
end

local function GetItemWaveform(item, width)
    local take = reaper.GetActiveTake(item)
    local sourceraw = reaper.GetMediaItemTake_Source(take)
    local _, _, _, _, _, reverse = reaper.BR_GetMediaSourceProperties(take)
    if reverse then
        sourceraw = reaper.GetMediaSourceParent(sourceraw)
    end

    local filename = reaper.GetMediaSourceFileName(sourceraw)
    -- reaper.ShowConsoleMsg(filename .. "\n")

    local source = reaper.PCM_Source_CreateFromFile(filename)


    local length = math.min(
        reaper.GetMediaItemInfo_Value(item, "D_LENGTH"),
        (reaper.GetMediaSourceLength(source) - reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")) *
        (1 / reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE"))
    )

    local channels = reaper.GetMediaSourceNumChannels(source)
    channels = math.min(channels, 2)

    local buf = reaper.new_array(width * 2 * channels)

    reaper.GetMediaItemTake_Peaks(take, width / length, reaper.GetMediaItemInfo_Value(item, "D_POSITION"), channels,
        width, 0, buf)

    local ret_tab
    if channels == 2 then
        local tab = buf.table()
        ret_tab = {}
        for i = 1, #tab - 1, 2 do
            local val = SampleLimit(tab[i]) + SampleLimit(tab[i + 1])
            table.insert(ret_tab, -val / 2)
        end
    else
        ret_tab = buf.table()
    end
    return ret_tab
end

local function CreateWaveformBitmap(item, width, height, color)
    local filepath = SCRIPT_DIRECTORY .. "cached_bitmap"
    local peaks = GetItemWaveform(item, width)
    local bitmap = reaper.JS_LICE_CreateBitmap(true, math.floor(width), math.floor(height))

    local r, g, b = imgui.ColorConvertU32ToDouble4(color)
    local h, s, v = imgui.ColorConvertRGBtoHSV(r, g, b)
    s = s * 0.64
    v = v * 0.35
    r, g, b = imgui.ColorConvertHSVtoRGB(h, s, v)

    local zero_line = height / 2
    local waveform_height = height / 2 * 0.95
    local col_wave = imgui.ColorConvertDouble4ToU32(1, r, g, b)
    local col_zero_line = imgui.ColorConvertDouble4ToU32(0.4, r, g, b)
    local negative_index = #peaks / 2

    reaper.JS_LICE_Line(bitmap, 0, zero_line, #peaks, zero_line, col_zero_line, 1, "", false)

    for i = 1, #peaks / 2 - 1 do
        local max = zero_line + waveform_height * peaks[i]
        local min = zero_line + waveform_height * peaks[i + negative_index]
        local max_next = zero_line + waveform_height * peaks[i + 1]
        local min_next = zero_line + waveform_height * peaks[i + 1 + negative_index]
        local pos_x = i

        reaper.JS_LICE_Line(bitmap, pos_x, max, pos_x, min, col_wave, 1, "", false)
        reaper.JS_LICE_Line(bitmap, pos_x, max, pos_x + 1, max_next, col_wave, 1, "", true)
        reaper.JS_LICE_Line(bitmap, pos_x, min, pos_x + 1, min_next, col_wave, 1, "", true)
    end

    local image = imgui.CreateImageFromLICE(bitmap)
    imgui.Attach(ctx, image)
    state.time_since_last_bitmap_draw = imgui.GetTime(ctx)
    return image
end

local function DisplayWaveform(waveform, color)
    local item_x1, item_y1 = imgui.GetItemRectMin(ctx)
    local item_x2, item_y2 = imgui.GetItemRectMax(ctx)
    local item_w, item_h = imgui.GetItemRectSize(ctx)

    imgui.DrawList_AddRectFilled(state.draw_list, item_x1, item_y1, item_x2, item_y2, color)
    local r, g, b = imgui.ColorConvertU32ToDouble4(color)
    local h, s, v = imgui.ColorConvertRGBtoHSV(r, g, b)
    s = s * 0.64
    v = v * 0.35
    r, g, b = imgui.ColorConvertHSVtoRGB(h, s, v)

    local col_wave = imgui.ColorConvertDouble4ToU32(r, g, b, 1)
    local col_zero_line = imgui.ColorConvertDouble4ToU32(r, g, b, 0.4)

    local waveform_height = item_h / 2 * 0.95
    local zero_line = item_y1 + item_h / 2
    imgui.DrawList_AddLine(state.draw_list, item_x1, zero_line, item_x2, zero_line, col_zero_line)
    local negative_index = #waveform / 2

    for i = 1, #waveform / 2 - 1 do
        local max = zero_line + waveform_height * waveform[i]
        local min = zero_line + waveform_height * waveform[i + negative_index]
        local max_next = zero_line + waveform_height * waveform[i + 1]
        local min_next = zero_line + waveform_height * waveform[i + 1 + negative_index]
        local pos_x = item_x1 + i

        imgui.DrawList_AddLine(state.draw_list, pos_x, max, pos_x, min, col_wave)
        imgui.DrawList_AddLine(state.draw_list, pos_x, max, pos_x + 1, max_next, col_wave)
        imgui.DrawList_AddLine(state.draw_list, pos_x, min, pos_x + 1, min_next, col_wave)
    end
end

local function GetNoteRange(take)
    local _, num_notes              = reaper.MIDI_CountEvts(take)
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

local function GetMidiThumbnail(item)
    local thumbnail                 = {}
    local take                      = reaper.GetActiveTake(item)
    local w, h                      = imgui.GetItemRectSize(ctx)

    local lowest_note, highest_note = GetNoteRange(take)

    local midi_range                = highest_note - lowest_note + 3
    if midi_range < 10 then
        midi_range = 10
    end
    local midi_note_height = h / midi_range

    local item_pos         = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    local take_offset      = reaper.GetMediaItemTakeInfo_Value(take, 'D_STARTOFFS')
    local item_pos_qn      = reaper.TimeMap2_timeToQN(0, item_pos - take_offset)
    local item_ppq         = reaper.MIDI_GetPPQPosFromProjQN(take, item_pos_qn + 1)
    local item_length      = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
    local item_length_ppq  = reaper.TimeMap_timeToQN(item_length) * item_ppq

    local time_to_ppq      = reaper.TimeMap_timeToQN(1) * item_ppq
    local pqq_to_pixel     = item_length_ppq / w

    local _, num_notes     = reaper.MIDI_CountEvts(take)
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
    return thumbnail
end

local function DisplayMidiItem(thumbnail, color)
    local x1, y1 = imgui.GetItemRectMin(ctx)
    local x2, y2 = imgui.GetItemRectMax(ctx)
    imgui.DrawList_AddRectFilled(state.draw_list, x1, y1, x2, y2, color)

    local r, g, b = imgui.ColorConvertU32ToDouble4(color)
    local h, s, v = imgui.ColorConvertRGBtoHSV(r, g, b)
    s = s * 0.64
    v = v * 0.35
    r, g, b = imgui.ColorConvertHSVtoRGB(h, s, v)

    local col_note = imgui.ColorConvertDouble4ToU32(r, g, b, 1)

    for key, note in pairs(thumbnail) do
        local note_x1 = x1 + note.x1
        local note_x2 = x1 + note.x2
        local note_y1 = y1 + note.y1
        local note_y2 = y1 + note.y2
        imgui.DrawList_AddRectFilled(state.draw_list, note_x1, note_y1, note_x2, note_y2, col_note)
    end
end

local function DisplayPreviewLine()
    if state.preview_start and state.preview_end then
        local span = state.preview_end - state.preview_start
        local time = reaper.time_precise() - state.preview_start
        local progress = time / span
        local item_x1, item_y1 = imgui.GetItemRectMin(ctx)
        local item_x2, item_y2 = imgui.GetItemRectMax(ctx)
        local item_w, item_h = imgui.GetItemRectSize(ctx)
        local x = item_x1 + item_w * progress
        imgui.DrawList_AddLine(state.draw_list, x, item_y1, x, item_y2, 0xFFFFFFFF)
    end
end

local function ContentTable(content_table, name, num_boxes, box_w, box_h, table_x, table_y, table_w, table_h)
    imgui.SetCursorScreenPos(ctx, table_x, table_y)
    local name_w, name_h = imgui.CalcTextSize(ctx, name)
    imgui.DrawList_AddText(state.draw_list, table_x + table_w / 2 - name_w / 2, table_y - name_h, 0xFFFFFFFF, name)
    local scroll_size = imgui.GetStyleVar(ctx, imgui.StyleVar_ScrollbarSize)
    if not state.scroll_y[name] then
        state.scroll_y[name] = 0
    end

    if table_h > SCREEN_H * 0.7 then
        local text = "(Shift + Scroll)"
        local text_w, text_h = imgui.CalcTextSize(ctx, text)
        imgui.DrawList_AddText(state.draw_list, table_x + table_w - text_w, table_y + SCREEN_H * 0.7, 0xFFFFFFFF, text)
    end


    imgui.SetNextWindowScroll(ctx, 0, state.scroll_y[name])
    if imgui.BeginChild(ctx, "Child" .. table_x, table_w + scroll_size, SCREEN_H * 0.7, 0, imgui.WindowFlags_NoScrollWithMouse) then
        if imgui.IsKeyDown(ctx, imgui.Key_LeftShift) and imgui.GetMouseWheel(ctx) ~= 0 and imgui.IsMouseHoveringRect(ctx, table_x, table_y, table_x + table_w + scroll_size, table_y + table_h) then
            state.scroll_y[name] = math.min(imgui.GetScrollMaxY(ctx),
                math.max(0, state.scroll_y[name] - imgui.GetMouseWheel(ctx) * 100))
        end
        if imgui.BeginTable(ctx, "Table" .. table_x, num_boxes, 0, 0, 0) then
            box_w = box_w - imgui.GetStyleVar(ctx, imgui.StyleVar_CellPadding)
            for content_key, content in ipairs(content_table) do
                content_key = content_key + table_x
                if not state.box_current_item[content_key] then
                    state.box_current_item[content_key] = 1
                end


                local filepath
                local box_name
                local item
                local track
                if type(content) == "string" then -- TODO: this is so stupid
                    filepath = content
                    content = state.samples[content]
                    if state.box_current_item[content_key] > #content then
                        state.box_current_item[content_key] = 1
                    end
                    box_name = content[state.box_current_item[content_key]][2]
                    item = content[state.box_current_item[content_key]][1]
                    track = reaper.GetMediaItemTrack(item)
                else
                    item = content[state.box_current_item[content_key]]
                    track = reaper.GetMediaItemTrack(item)
                    _, box_name = reaper.GetTrackName(track)
                end


                if settings.search_string ~= 0 then
                    if not box_name:lower():find(settings.search_string:lower()) then
                        goto next
                    end
                end

                local take = reaper.GetActiveTake(item)

                local track_muted = reaper.GetMediaTrackInfo_Value(track, "B_MUTE") == 1 or IsParentMuted(track) == true

                local item_muted = reaper.GetMediaItemInfo_Value(item, "B_MUTE") == 1

                local track_color = reaper.GetMediaTrackInfo_Value(reaper.GetMediaItemTrack(item), "I_CUSTOMCOLOR")
                local r, g, b = 85 / 256, 91 / 256, 91 / 256
                if track_color ~= 16576 and track_color > 0 then
                    r, g, b = RGBvalues(track_color)
                end

                track_color = Color(r, g, b, 1)

                imgui.TableNextColumn(ctx)

                imgui.PushStyleVar(ctx, imgui.StyleVar_ItemSpacing, 0, 0)
                local text_height_spacing = imgui.GetTextLineHeightWithSpacing(ctx)
                local text_height = imgui.GetTextLineHeight(ctx)

                imgui.Dummy(ctx, box_w, text_height_spacing)

                local box_x1, box_y1 = imgui.GetItemRectMin(ctx)

                if imgui.InvisibleButton(ctx, content_key, box_w, box_h - text_height_spacing) and not track_muted then
                    reaper.SelectAllMediaItems(0, false)
                    reaper.SetMediaItemSelected(item, true)
                    if reaper.TakeIsMIDI(take) then
                        local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                        reaper.SetEditCurPos(item_pos, false, false)
                        reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_PREVIEWTRACK"), 0) -- Xenakios/SWS: Preview selected media item through track
                    else
                        if settings.play_item_through_track then
                            reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_PREVIEWTRACK"), 0)    -- Xenakios/SWS: Preview selected media item through track
                        else
                            reaper.Main_OnCommand(reaper.NamedCommandLookup("_XENAKIOS_ITEMASPCM1"), 0) -- Xenakios/SWS: Preview selected media item
                        end
                    end

                    state.preview_start = reaper.time_precise() + reaper.GetOutputLatency()
                    local length = math.min(
                        reaper.GetMediaItemInfo_Value(item, "D_LENGTH"),
                        (reaper.GetMediaSourceLength(reaper.GetMediaItemTake_Source(take)) - reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")) *
                        (1 / reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE"))
                    )
                    state.preview_end = state.preview_start + length + reaper.GetOutputLatency()
                    state.previewing = state.box_current_item[content_key] .. content_key
                end
                imgui.PopStyleVar(ctx, 1)

                local box_x2, box_y2 = imgui.GetItemRectMax(ctx)
                if imgui.IsRectVisibleEx(ctx, box_x1, box_y1, box_x2, box_y2) then
                    imgui.DrawList_AddRectFilled(state.draw_list, box_x1, box_y1, box_x1 + box_w,
                        box_y1 + text_height_spacing,
                        track_color, 2)
                    imgui.DrawList_AddRectFilled(state.draw_list, box_x1, box_y1, box_x1 + box_w,
                        box_y1 + text_height_spacing,
                        0x00000050, 2)

                    imgui.DrawList_AddRectFilled(state.draw_list, box_x1, box_y1 + text_height,
                        box_x2, box_y2, track_color)

                    if reaper.TakeIsMIDI(take) then
                        imgui.DrawList_AddText(state.draw_list, box_x1, box_y1, 0xFFFFFFFF, box_name)

                        if not state.midi_thumbnails[state.box_current_item[content_key] .. content_key] then
                            state.midi_thumbnails[state.box_current_item[content_key] .. content_key] = GetMidiThumbnail(
                                item)
                        end
                        DisplayMidiItem(state.midi_thumbnails[state.box_current_item[content_key] .. content_key],
                            track_color)
                    else
                        box_name = box_name
                        imgui.DrawList_AddText(state.draw_list, box_x1, box_y1, 0xFFFFFFFF, box_name)

                        if not state.waveform_bitmaps[state.box_current_item[content_key] .. content_key] and imgui.GetTime(ctx) - state.time_since_last_bitmap_draw > 1 / 60 then
                            -- state.item_waveforms[state.box_current_item[content_key] .. content_key] = GetItemWaveform(item,
                            --     box_w)
                            state.waveform_bitmaps[state.box_current_item[content_key] .. content_key] =
                                CreateWaveformBitmap(
                                    item, box_w, box_h, track_color)
                        end
                        -- DisplayWaveform(state.item_waveforms[state.box_current_item[content_key] .. content_key],
                        --     track_color)
                        if state.waveform_bitmaps[state.box_current_item[content_key] .. content_key] then
                            imgui.DrawList_AddImage(state.draw_list,
                                state.waveform_bitmaps[state.box_current_item[content_key] .. content_key], box_x1,
                                box_y1 + text_height_spacing,
                                box_x2, box_y2)
                        end
                    end

                    if #content > 1 then
                        local item_num_string = string.format("%.0f", state.box_current_item[content_key]) ..
                            "/" .. #content .. " "
                        imgui.DrawList_AddText(state.draw_list, box_x2 - imgui.CalcTextSize(ctx, item_num_string),
                            box_y1 + text_height_spacing, 0xFFFFFFFF, item_num_string)
                    end

                    if state.previewing == state.box_current_item[content_key] .. content_key then
                        DisplayPreviewLine()
                    end

                    if track_muted then
                        imgui.DrawList_AddRectFilled(state.draw_list, box_x1, box_y1, box_x2, box_y2, 0x00000090, 2)
                        local str_w, str_h = imgui.CalcTextSize(ctx, "Track Muted")
                        imgui.DrawList_AddText(state.draw_list, box_x1 + (box_x2 - box_x1) / 2 - str_w / 2,
                            box_y1 + (box_y2 - box_y1) / 2 - str_h / 2, 0xFF000090, "Track Muted")
                    elseif item_muted then
                        imgui.DrawList_AddRectFilled(state.draw_list, box_x1, box_y1, box_x2, box_y2, 0x00000090, 2)
                        local str_w, str_h = imgui.CalcTextSize(ctx, "Item Muted")
                        imgui.DrawList_AddText(state.draw_list, box_x1 + (box_x2 - box_x1) / 2 - str_w / 2,
                            box_y1 + (box_y2 - box_y1) / 2 - str_h / 2, 0xFF000090, "Item Muted")
                    end

                    if imgui.BeginDragDropSource(ctx, imgui.DragDropFlags_SourceNoPreviewTooltip) then
                        state.item_to_add = item
                        state.item_to_add_width = math.max(imgui.CalcTextSize(ctx, " " .. box_name), box_w)
                        state.item_to_add_height = box_h
                        state.item_to_add_color = track_color
                        state.item_to_add_visual_index = state.box_current_item[content_key] .. content_key
                        state.item_to_add_name = box_name
                        state.drag_bounds = { box_x1, box_y1, box_x2, box_y2 }
                        imgui.EndDragDropSource(ctx)
                    end

                    if imgui.IsMouseHoveringRect(ctx, box_x1, box_y1, box_x2, box_y2) then
                        imgui.DrawList_AddRectFilled(state.draw_list, box_x1, box_y1, box_x2, box_y2, 0xFFFFFF30, 2)

                        if imgui.GetMouseWheel(ctx) ~= 0 then
                            state.box_current_item[content_key] = math.max(
                                math.min(state.box_current_item[content_key] + imgui.GetMouseWheel(ctx), #content), 1)
                        end
                    end
                end


                ::next::
            end
            imgui.EndTable(ctx)
        end
        -- state.scroll_y[name] = imgui.GetScrollY(ctx)
        imgui.EndChild(ctx)
    end
end

local function InsertItemAtMousePos(item)
    local take = reaper.GetActiveTake(item)
    local source = reaper.GetMediaItemTake_Source(take)
    local mouse_x, mouse_y = reaper.GetMousePosition()
    local track, str = reaper.GetThingFromPoint(mouse_x, mouse_y)
    if track or state.out_of_bounds then
        if state.out_of_bounds then
            reaper.InsertTrackAtIndex(reaper.CountTracks(0), false)
            track = reaper.GetTrack(0, reaper.CountTracks(0) - 1)
            state.out_of_bounds = nil
        end
        reaper.BR_GetMouseCursorContext()
        local mouse_position_in_arrange = reaper.BR_GetMouseCursorContext_Position()

        -- Is snapping on?
        if reaper.GetToggleCommandState(1157) then
            mouse_position_in_arrange = reaper.SnapToGrid(0, mouse_position_in_arrange)
        end
        reaper.SelectAllMediaItems(0, false)
        reaper.SetMediaItemSelected(item, true)
        reaper.ApplyNudge(0, 1, 5, 1, mouse_position_in_arrange, false, 1)
        reaper.MoveMediaItemToTrack(reaper.GetSelectedMediaItem(0, 0), track)
    end
end

----------------------------------------------------------------------
-- RUN --
----------------------------------------------------------------------
local function MainWindow()
    --------------------
    -- YOUR CODE HERE --
    --------------------


    local window_flags = imgui.WindowFlags_NoCollapse | imgui.WindowFlags_NoTitleBar | imgui.WindowFlags_NoResize |
        imgui.WindowFlags_NoMove | imgui.WindowFlags_NoScrollbar | imgui.WindowFlags_NoScrollWithMouse

    local imgui_visible, imgui_open = imgui.Begin(ctx, SCRIPT_TITLE, true, window_flags)

    if imgui.Checkbox(ctx, "Play Item Through Track (will add delay to preview playback)", settings.play_item_through_track) then
        if not settings.play_item_through_track then
            settings.play_item_through_track = true
        else
            settings.play_item_through_track = false
        end
    end
    if imgui.Checkbox(ctx, "Show Muted Tracks", settings.show_muted_tracks) then
        state.samples, state.sample_indexes, state.midi_tracks, state.waveform_bitmaps = nil, nil, nil, {}

        if not settings.show_muted_tracks then
            settings.show_muted_tracks = true
        else
            settings.show_muted_tracks = false
        end
    end

    if imgui.Checkbox(ctx, "Show Muted Items", settings.show_muted_items) then
        state.samples, state.sample_indexes, state.midi_tracks, state.waveform_bitmaps = nil, nil, nil, {}
        if not settings.show_muted_items then
            settings.show_muted_items = true
        else
            settings.show_muted_items = false
        end
    end

    if not state.samples then
        state.samples, state.sample_indexes = GetProjectSamples()
        state.midi_tracks = GetProjectMidiTracks()
    end
    imgui.PushFont(ctx, big_font)
    local search_text_w, search_text_h = imgui.CalcTextSize(ctx, "Search:")
    imgui.DrawList_AddText(state.draw_list, SCREEN_W / 2 - search_text_w / 2, SCREEN_H * 0.1 - search_text_h, 0xFFFFFFFF,
        "Search:")

    imgui.SetCursorScreenPos(ctx, SCREEN_W / 2 - SCREEN_W / 5 / 2, SCREEN_H * 0.1)
    imgui.PushItemWidth(ctx, SCREEN_W / 5)
    if not state.initialized and settings.focus_keyboard_on_init then
        imgui.SetKeyboardFocusHere(ctx)
        state.initialized = true
    end
    _, settings.search_string = imgui.InputText(ctx, "##Search", settings.search_string)
    imgui.PopFont(ctx)

    local num_items_width = 5
    local box_w = SCREEN_W * 0.075

    if state.drag_bounds then
        local x1, y1, x2, y2 = state.drag_bounds[1], state.drag_bounds[2], state.drag_bounds[3], state.drag_bounds[4]
        if not imgui.IsMouseHoveringRect(ctx, x1, y1, x2, y2) then
            state.dragging = true
        end
        if not imgui.IsMouseDragging(ctx, 0) then
            state.drag_bounds = nil
        end
    end

    if #state.midi_tracks > 0 then
        local num_midi_boxes_x = math.min(#state.midi_tracks, num_items_width)
        local num_midi_boxes_y = #state.midi_tracks // num_items_width + 1


        local midi_box_h = SCREEN_H / 10
        -- if num_midi_boxes_y > 8 then
        --     midi_box_h = screen_h / (10 + num_midi_boxes_y - 8) -
        --         imgui.GetStyleVar(ctx, imgui.StyleVar_CellPadding) * num_midi_boxes_y / (num_midi_boxes_y - 1)
        -- end

        local midi_table_w = box_w * num_midi_boxes_x
        local midi_table_h = midi_box_h * num_midi_boxes_y + 4 * num_midi_boxes_y

        local midi_table_x = SCREEN_W * 0.25 - midi_table_w /2 
        local midi_table_y = math.max(SCREEN_H * 0.5 - midi_table_h / 2, SCREEN_H * 0.2)


        ContentTable(state.midi_tracks, "Midi Tracks", num_midi_boxes_x, box_w, midi_box_h, midi_table_x, midi_table_y,
            midi_table_w,
            midi_table_h)
    end

    if table.getn(state.samples) > 0 then
        local num_sample_boxes_x = math.min(table.getn(state.samples), num_items_width)
        local num_sample_boxes_y = table.getn(state.samples) // num_items_width + 1
        local sample_box_h = SCREEN_H / 10
        -- if num_sample_boxes_y > 8 then
        --     sample_box_h = screen_h / (10 + num_sample_boxes_y - 8) -
        --         imgui.GetStyleVar(ctx, imgui.StyleVar_CellPadding) * num_sample_boxes_y / (num_sample_boxes_y - 1)
        -- end

        local sample_table_w = box_w * num_sample_boxes_x
        local sample_table_h = sample_box_h * num_sample_boxes_y + 4 * num_sample_boxes_y


        local sample_table_x = SCREEN_W * 0.75 - sample_table_w/2
        local sample_table_y = math.max(SCREEN_H * 0.5 - sample_table_h / 2, SCREEN_H * 0.2)
        ContentTable(state.sample_indexes, "Audio Sources", num_sample_boxes_x, box_w, sample_box_h, sample_table_x,
            sample_table_y, sample_table_w,
            sample_table_h)
    end

    imgui.End(ctx)
end

local function DragDropLogic()
    -- Mouse Release: insert item
    local mouse_key = reaper.JS_Mouse_GetState(-1)
    local left_mouse_key = mouse_key & 1 == 1
    if not left_mouse_key then
        InsertItemAtMousePos(state.item_to_add)
        state.exit = true
        state.dragging = nil
    end

    local arrange_window = reaper.JS_Window_Find("trackview", true)
    local rv, w_x1, w_y1, w_x2, w_y2 = reaper.JS_Window_GetRect(arrange_window)
    local w_width, w_height = w_x2 - w_x1, w_y2 - w_y1

    imgui.SetNextWindowPos(ctx, w_x1, w_y1)
    imgui.SetNextWindowSize(ctx, w_width, w_height - 17)

    imgui.PushStyleVar(ctx, imgui.StyleVar_WindowBorderSize, 0)

    local _, _ = imgui.Begin(ctx, "drag_target_window", false,
        imgui.WindowFlags_NoCollapse | imgui.WindowFlags_NoInputs | imgui.WindowFlags_NoTitleBar |
        imgui.WindowFlags_NoFocusOnAppearing | imgui.WindowFlags_NoBackground)

    local arrange_zoom_level = reaper.GetHZoomLevel()

    if state.dragging then
        local mouse_x, mouse_y = reaper.GetMousePosition()

        local m_window, m_segment, m_details = reaper.BR_GetMouseCursorContext()
        local track, str = reaper.GetThingFromPoint(mouse_x, mouse_y)
        local last_track
        for i = reaper.CountTracks(0) - 1, 0, -1 do
            local track = reaper.GetTrack(0, i)
            if reaper.IsTrackVisible(track, false) then
                last_track = track
                break
            end
        end
        local track_height
        local track_y

        -- Is snapping on?
        if reaper.GetToggleCommandState(1157) then
            local mouse_position_in_arrange = reaper.BR_GetMouseCursorContext_Position()
            local snapped_position = reaper.SnapToGrid(0, mouse_position_in_arrange)
            local snap_factor = snapped_position - mouse_position_in_arrange
            snap_factor = snap_factor * arrange_zoom_level
            mouse_x = mouse_x + snap_factor
        end

        local rect_x1
        local rect_y1
        local rect_x2
        local rect_y2

        local item_length = reaper.GetMediaSourceLength(reaper.GetMediaItemTake_Source(reaper.GetActiveTake(state
            .item_to_add)))
        if track and (str == "arrange" or str:find('envelope')) then
            track_height = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")
            track_y = reaper.GetMediaTrackInfo_Value(track, "I_TCPY")

            rect_x1 = mouse_x
            rect_y1 = w_y1 + track_y
            rect_x2 = mouse_x + item_length * arrange_zoom_level
            rect_y2 = rect_y1 + track_height

            state.out_of_bounds = nil
        elseif m_window == "arrange" and m_segment == "empty" then
            track_height = reaper.GetMediaTrackInfo_Value(last_track, "I_WNDH")
            track_y = reaper.GetMediaTrackInfo_Value(last_track, "I_TCPY")

            rect_x1 = mouse_x
            rect_y1 = w_y1 + track_y + track_height
            rect_x2 = mouse_x + item_length * arrange_zoom_level
            rect_y2 = w_y1 + track_y + track_height + 17

            state.out_of_bounds = true
        else
            state.out_of_bounds = nil
        end

        if rect_x1 then
            imgui.DrawList_AddRectFilled(state.draw_list, rect_x1, rect_y1, rect_x2, rect_y2,
                Color(177 / 256, 180 / 256, 180 /
                    256, 1))

            -- Insert Item Box
            local line_color = Color(16 / 256, 133 / 256, 130 / 256, 1)

            -- Vertical lines
            imgui.DrawList_AddLine(state.draw_list, rect_x1, w_y1, rect_x1, w_y2, line_color)
            imgui.DrawList_AddLine(state.draw_list, rect_x2, w_y1, rect_x2, w_y2, line_color)

            -- Horizontal Lines
            imgui.DrawList_AddLine(state.draw_list, w_x1, rect_y1, w_x2, rect_y1, line_color)
            imgui.DrawList_AddLine(state.draw_list, w_x1, rect_y2, w_x2, rect_y2, line_color)
        end
    end



    imgui.PopStyleVar(ctx, 1)
    imgui.End(ctx)
end

local function DraggingThumbnailWindow()
    local mouse_x, mouse_y = reaper.GetMousePosition()
    imgui.SetNextWindowPos(ctx, mouse_x, mouse_y)

    if imgui.Begin(ctx, "MouseFollower", false, imgui.WindowFlags_NoInputs | imgui.WindowFlags_TopMost | imgui.WindowFlags_NoTitleBar | imgui.WindowFlags_NoBackground | imgui.WindowFlags_AlwaysAutoResize) then
        imgui.PushFont(ctx, mini_font)
        local cursor_x, cursor_y = imgui.GetItemRectMin(ctx)
        local x1, y1 = cursor_x + imgui.StyleVar_ChildBorderSize, cursor_y + imgui.StyleVar_ChildBorderSize
        imgui.DrawList_AddRectFilled(state.draw_list, x1 - 8, y1 - 8, x1 + state.item_to_add_width + 8,
            y1 + state.item_to_add_height + 8, 0x00000050)

        imgui.DrawList_AddRectFilled(state.draw_list, x1, y1, x1 + state.item_to_add_width,
            y1 + imgui.GetTextLineHeightWithSpacing(ctx), state.item_to_add_color)
        imgui.DrawList_AddRectFilled(state.draw_list, x1, y1, x1 + state.item_to_add_width,
            y1 + imgui.GetTextLineHeightWithSpacing(ctx), Color(0, 0, 0, 0.3))
        imgui.Text(ctx, " " .. state.item_to_add_name)
        imgui.Dummy(ctx, state.item_to_add_width, state.item_to_add_height - imgui.GetTextLineHeightWithSpacing(ctx))
        if reaper.TakeIsMIDI(reaper.GetActiveTake(state.item_to_add)) then
            DisplayMidiItem(state.midi_thumbnails[state.item_to_add_visual_index],
                state.item_to_add_color)
        else
            if not state.drag_waveform then
                state.drag_waveform = GetItemWaveform(state.item_to_add, state.item_to_add_width)
            end
            DisplayWaveform(state.drag_waveform, state.item_to_add_color)
        end
        imgui.PopFont(ctx)
        imgui.End(ctx)
    end
end

local function Run()
    if set_dock_id then
        imgui.SetNextWindowDockID(ctx, set_dock_id)
        set_dock_id = nil
    end

    -- state.time_since_last_bitmap_draw = 0

    _, _, SCREEN_W, SCREEN_H = reaper.my_getViewport(0, 0, 0, 0, 0, 0, 0, 0, true)
    imgui.SetNextWindowPos(ctx, 0, 0)
    imgui.SetNextWindowSize(ctx, SCREEN_W, SCREEN_H)

    imgui.PushFont(ctx, mini_font)
    reaper.PreventUIRefresh(1)
    if not state.dragging then
        MainWindow()
    else
        DragDropLogic()
        DraggingThumbnailWindow()
    end
    reaper.PreventUIRefresh(-1)
    imgui.PopFont(ctx)


    -- imgui.ShowMetricsWindow(ctx, true)
    --------------------


    if not state.exit and not imgui.IsKeyPressed(ctx, imgui.Key_Escape) and not EXIT then
        reaper.defer(Run)
    end
end -- END DEFER

----------------------------------------------------------------------
-- RUN --
----------------------------------------------------------------------

local function Init()
    SetButtonState(1)
    reaper.atexit(Exit)

    ctx = imgui.CreateContext(SCRIPT_TITLE)

    mini_font = imgui.CreateFont('verdana', 14)
    small_font = imgui.CreateFont('verdana', 16)
    medium_font = imgui.CreateFont('verdana', 20)
    big_font = imgui.CreateFont('verdana', 24)
    imgui.Attach(ctx, mini_font)
    imgui.Attach(ctx, small_font)
    imgui.Attach(ctx, medium_font)
    imgui.Attach(ctx, big_font)

    state.draw_list = imgui.GetWindowDrawList(ctx)

    state.track_chunks = GetAllTrackStateChunks()
    state.item_chunks = GetAllCleanedItemChunks()

    reaper.defer(Run)
end

Init()
-- profiler.auto_start = 30
-- profiler.attachToWorld() -- after all functions have been defined
-- profiler.run()

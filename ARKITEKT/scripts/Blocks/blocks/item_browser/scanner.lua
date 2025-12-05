-- @noindex
-- Blocks/blocks/item_browser/scanner.lua
-- Scans REAPER project for audio and MIDI items
-- Includes favorite status from shared ItemPicker storage

local M = {}

local Storage = require('scripts.Blocks.blocks.item_browser.storage')

-- Cache for REAPER API lookups
local GetTrack = reaper.GetTrack
local GetTrackNumMediaItems = reaper.GetTrackNumMediaItems
local GetTrackMediaItem = reaper.GetTrackMediaItem
local GetActiveTake = reaper.GetActiveTake
local TakeIsMIDI = reaper.TakeIsMIDI
local GetTakeName = reaper.GetTakeName
local GetMediaItemTake_Source = reaper.GetMediaItemTake_Source
local GetMediaSourceFileName = reaper.GetMediaSourceFileName
local GetTrackColor = reaper.GetTrackColor
local GetSetMediaTrackInfo_String = reaper.GetSetMediaTrackInfo_String
local CountTracks = reaper.CountTracks

---Convert REAPER color (native) to ImGui color (RGBA)
---@param reaper_color number REAPER native color
---@return number ImGui RGBA color
local function reaper_to_imgui_color(reaper_color)
  if reaper_color == 0 then
    return 0x606060FF  -- Default gray
  end
  -- REAPER color format varies by platform, use ColorFromNative
  local r, g, b = reaper.ColorFromNative(reaper_color)
  return (r << 24) | (g << 16) | (b << 8) | 0xFF
end

---Get track name
---@param track userdata MediaTrack
---@return string
local function get_track_name(track)
  local _, name = GetSetMediaTrackInfo_String(track, 'P_NAME', '', false)
  if name == '' then
    local track_num = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
    return 'Track ' .. math.floor(track_num)
  end
  return name
end

---Get filename without path
---@param filepath string Full file path
---@return string Filename only
local function get_filename(filepath)
  return filepath:match('[/\\]([^/\\]+)$') or filepath
end

---Scan project for audio and MIDI items
---@param state table Component state to populate
function M.scan(state)
  local audio_items = {}
  local midi_items = {}
  local audio_seen = {}  -- Dedupe by filename
  local midi_seen = {}   -- Dedupe by track_guid + name

  -- Load current favorites for marking items
  local favorites = Storage.load_favorites()

  local num_tracks = CountTracks(0)

  for t = 0, num_tracks - 1 do
    local track = GetTrack(0, t)
    if track then
      local track_color = GetTrackColor(track)
      local track_name = get_track_name(track)
      local track_guid = reaper.GetTrackGUID(track)
      local color = reaper_to_imgui_color(track_color)

      local num_items = GetTrackNumMediaItems(track)
      for i = 0, num_items - 1 do
        local item = GetTrackMediaItem(track, i)
        if item then
          local take = GetActiveTake(item)
          if take then
            local take_name = GetTakeName(take)
            local is_midi = TakeIsMIDI(take)

            if is_midi then
              -- MIDI item - use take_name as key (matches ItemPicker)
              local item_name = take_name ~= '' and take_name or 'Untitled MIDI'
              if not midi_seen[item_name] then
                midi_seen[item_name] = true

                -- Check favorite status (MIDI uses item_name, matching ItemPicker)
                local is_favorite = favorites.midi and favorites.midi[item_name] == true

                table.insert(midi_items, {
                  key = item_name,  -- Key by item_name for favorites lookup
                  name = item_name,
                  track_name = track_name,
                  track_guid = track_guid,
                  color = color,
                  item = item,
                  take = take,
                  is_favorite = is_favorite,
                })
              end
            else
              -- Audio item
              local source = GetMediaItemTake_Source(take)
              if source then
                local filename = GetMediaSourceFileName(source)
                if filename and filename ~= '' then
                  if not audio_seen[filename] then
                    audio_seen[filename] = true

                    -- Check favorite status (Audio uses filename)
                    local is_favorite = favorites.audio and favorites.audio[filename] == true

                    table.insert(audio_items, {
                      key = filename,
                      name = take_name ~= '' and take_name or get_filename(filename),
                      filename = filename,
                      track_name = track_name,
                      track_guid = track_guid,
                      color = color,
                      item = item,
                      take = take,
                      is_favorite = is_favorite,
                    })
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  -- Sort by name
  table.sort(audio_items, function(a, b) return a.name:lower() < b.name:lower() end)
  table.sort(midi_items, function(a, b) return a.name:lower() < b.name:lower() end)

  state.audio_items = audio_items
  state.midi_items = midi_items
end

return M

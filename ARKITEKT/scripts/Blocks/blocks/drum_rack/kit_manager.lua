-- @noindex
-- Blocks/blocks/drum_rack/kit_manager.lua
-- Kit save/load functionality for DrumRack

local M = {}

-- Dependencies
local json = require('arkitekt.core.json')

-- Kit file extension
M.KIT_EXTENSION = '.drumkit'

---Get default kit directory (next to script)
---@return string path
local function get_kit_directory()
  local source = debug.getinfo(1, 'S').source:sub(2)
  local dir = source:match('(.*[/\\])')
  return dir .. 'kits'
end

---Ensure kit directory exists
local function ensure_kit_directory()
  local dir = get_kit_directory()
  -- Use reaper.RecursiveCreateDirectory if available
  if reaper.RecursiveCreateDirectory then
    reaper.RecursiveCreateDirectory(dir, 0)
  end
  return dir
end

---Serialize pad data for saving
---@param pad table Pad state
---@return table serialized
local function serialize_pad(pad)
  return {
    index = pad.index,
    name = pad.name,
    note = pad.note,
    color = pad.color,
    has_sample = pad.has_sample,
    source_path = pad.source_path,
    volume = pad.volume,
    pan = pad.pan,
    pitch = pad.pitch,
    delay = pad.delay,
    attack = pad.attack,
    decay = pad.decay,
    sustain = pad.sustain,
    env_release = pad.env_release,
    obey_noteoff = pad.obey_noteoff,
    choke_group = pad.choke_group,
  }
end

---Save kit to file
---@param pads table Array of pad states
---@param name string Kit name
---@param filepath string? Optional full path (otherwise uses default directory)
---@return boolean success
---@return string? error
function M.save_kit(pads, name, filepath)
  if not pads or #pads == 0 then
    return false, 'No pads to save'
  end

  -- Build kit data
  local kit = {
    version = 1,
    name = name,
    created = os.date('%Y-%m-%d %H:%M:%S'),
    pad_count = #pads,
    pads = {},
  }

  for _, pad in ipairs(pads) do
    if pad.has_sample then
      table.insert(kit.pads, serialize_pad(pad))
    end
  end

  -- Determine file path
  if not filepath then
    local dir = ensure_kit_directory()
    local safe_name = name:gsub('[^%w%s%-_]', ''):gsub('%s+', '_')
    filepath = dir .. '/' .. safe_name .. M.KIT_EXTENSION
  end

  -- Serialize to JSON
  local ok, json_str = pcall(json.encode, kit)
  if not ok then
    return false, 'JSON encoding failed: ' .. tostring(json_str)
  end

  -- Write file
  local file, err = io.open(filepath, 'w')
  if not file then
    return false, 'Could not open file: ' .. tostring(err)
  end

  file:write(json_str)
  file:close()

  reaper.ShowConsoleMsg('[DrumRack] Saved kit: ' .. filepath .. '\n')
  return true
end

---Load kit from file
---@param filepath string Path to kit file
---@return table? kit Kit data
---@return string? error
function M.load_kit(filepath)
  local file, err = io.open(filepath, 'r')
  if not file then
    return nil, 'Could not open file: ' .. tostring(err)
  end

  local content = file:read('*all')
  file:close()

  local ok, kit = pcall(json.decode, content)
  if not ok then
    return nil, 'JSON decoding failed: ' .. tostring(kit)
  end

  if not kit or not kit.pads then
    return nil, 'Invalid kit format'
  end

  reaper.ShowConsoleMsg('[DrumRack] Loaded kit: ' .. (kit.name or 'Unknown') .. '\n')
  return kit
end

---List available kits in default directory
---@return table kits Array of {name, path}
function M.list_kits()
  local dir = get_kit_directory()
  local kits = {}

  -- Use reaper.EnumerateFiles
  local i = 0
  while true do
    local filename = reaper.EnumerateFiles(dir, i)
    if not filename then break end

    if filename:match(M.KIT_EXTENSION .. '$') then
      local name = filename:gsub(M.KIT_EXTENSION .. '$', ''):gsub('_', ' ')
      table.insert(kits, {
        name = name,
        path = dir .. '/' .. filename,
      })
    end

    i = i + 1
  end

  return kits
end

---Apply loaded kit to pads
---@param kit table Loaded kit data
---@param pads table Array of pad states
---@param rs5k_manager table RS5K manager module
---@param parent_track MediaTrack Parent drum rack track
---@return number loaded_count Number of pads loaded
function M.apply_kit(kit, pads, rs5k_manager, parent_track)
  if not kit or not kit.pads then return 0 end

  local loaded = 0

  for _, kit_pad in ipairs(kit.pads) do
    local pad = pads[kit_pad.index]
    if pad then
      -- Create track if needed
      if not pad.track or not reaper.ValidatePtr2(0, pad.track, 'MediaTrack*') then
        pad.track = rs5k_manager.create_pad_track(parent_track, pad.index, kit_pad.note or pad.note, kit_pad.name)
      end

      if pad.track then
        local fx_idx = rs5k_manager.find_rs5k(pad.track)
        if fx_idx >= 0 then
          pad.fx_idx = fx_idx

          -- Load sample
          if kit_pad.source_path and kit_pad.source_path ~= '' then
            -- Check if file exists
            local file = io.open(kit_pad.source_path, 'r')
            if file then
              file:close()
              rs5k_manager.load_sample(pad.track, fx_idx, kit_pad.source_path)
              pad.has_sample = true
              pad.source_path = kit_pad.source_path
            else
              reaper.ShowConsoleMsg('[DrumRack] Warning: Sample not found: ' .. kit_pad.source_path .. '\n')
              pad.has_sample = false
            end
          end

          -- Apply settings
          pad.name = kit_pad.name or ''
          pad.note = kit_pad.note or pad.note
          pad.color = kit_pad.color or pad.color
          pad.volume = kit_pad.volume or 1.0
          pad.pan = kit_pad.pan or 0
          pad.pitch = kit_pad.pitch or 0
          pad.delay = kit_pad.delay or 0
          pad.attack = kit_pad.attack or 0.01
          pad.decay = kit_pad.decay or 0.1
          pad.sustain = kit_pad.sustain or 1.0
          pad.env_release = kit_pad.env_release or 0.1
          pad.obey_noteoff = kit_pad.obey_noteoff ~= false

          -- Apply to RS5K/track
          rs5k_manager.set_param(pad.track, fx_idx, rs5k_manager.PARAMS.VOLUME, pad.volume)
          rs5k_manager.set_track_pan(pad.track, pad.pan)
          rs5k_manager.set_pitch(pad.track, fx_idx, pad.pitch)
          rs5k_manager.set_track_delay(pad.track, pad.delay)
          rs5k_manager.set_param(pad.track, fx_idx, rs5k_manager.PARAMS.ATTACK, pad.attack)
          rs5k_manager.set_param(pad.track, fx_idx, rs5k_manager.PARAMS.DECAY, pad.decay)
          rs5k_manager.set_param(pad.track, fx_idx, rs5k_manager.PARAMS.SUSTAIN, pad.sustain)
          rs5k_manager.set_param(pad.track, fx_idx, rs5k_manager.PARAMS.RELEASE, pad.env_release)
          rs5k_manager.set_param(pad.track, fx_idx, rs5k_manager.PARAMS.OBEY_NOTE_OFF, pad.obey_noteoff and 1 or 0)
          rs5k_manager.set_track_color(pad.track, pad.color)

          loaded = loaded + 1
        end
      end
    end
  end

  return loaded
end

return M

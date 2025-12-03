-- @noindex
-- TemplateBrowser/domain/template/track_parser.lua
-- Parse track names and hierarchy from REAPER track template files

local Logger = require('arkitekt.debug.logger')

local M = {}

-- Convert REAPER COLORREF (decimal BGR) to ImGui RGBA (0xRRGGBBAA)
-- PEAKCOL is stored as decimal: 0x00BBGGRR
local function colorref_to_rgba(colorref)
  if not colorref or colorref == 0 then return nil end
  local r = colorref % 256
  local g = math.floor(colorref / 256) % 256
  local b = math.floor(colorref / 65536) % 256
  return (r * 0x1000000) + (g * 0x10000) + (b * 0x100) + 0xFF
end

-- Parse a track template file and extract track names with hierarchy
-- Returns array of track entries: { name = string, depth = number, is_folder = boolean, color = number|nil }
function M.parse_track_tree(filepath)
  local file = io.open(filepath, "r")
  if not file then
    return nil
  end

  local tracks = {}
  local current_depth = 0
  local in_track = false
  local current_track = nil
  local track_depth = 0

  -- Wrap parsing in pcall to handle malformed files gracefully
  local ok, err = pcall(function()
    for line in file:lines() do
      -- Detect start of a TRACK block
      if line:match("^%s*<TRACK") then
        in_track = true
        track_depth = track_depth + 1
        current_track = {
          name = nil,
          depth = current_depth,
          is_folder = false,
          color = nil,
        }
      elseif in_track then
        -- Parse NAME within track
        local name = line:match('^%s*NAME%s+"([^"]*)"')
        if name and current_track then
          current_track.name = name
        end

        -- Parse PEAKCOL (track color as decimal COLORREF)
        local peakcol = line:match('^%s*PEAKCOL%s+(%d+)')
        if peakcol and current_track then
          current_track.color = colorref_to_rgba(tonumber(peakcol))
        end

        -- Parse ISBUS to detect folder tracks
        -- ISBUS format: ISBUS <bus_mode> <folder_depth>
        -- bus_mode: 0=normal, 1=folder parent, 2=last child in folder
        local bus_mode, folder_compact = line:match('^%s*ISBUS%s+(%d+)%s+(%d+)')
        if bus_mode and current_track then
          bus_mode = tonumber(bus_mode)
          folder_compact = tonumber(folder_compact)

          if bus_mode == 1 then
            -- This is a folder parent track
            current_track.is_folder = true
          elseif bus_mode == 2 and folder_compact then
            -- This is the last track in a folder, depth decreases after
            -- folder_compact tells us how many folder levels to close
          end
        end

        -- Detect nested elements (increase depth counter for proper parsing)
        if line:match("^%s*<[A-Z]") and not line:match("^%s*<TRACK") then
          track_depth = track_depth + 1
        end

        -- Detect end of block
        if line:match("^%s*>%s*$") then
          track_depth = track_depth - 1
          if track_depth == 0 then
            -- End of TRACK block
            in_track = false
            if current_track then
              -- Default name if not specified
              if not current_track.name or current_track.name == "" then
                current_track.name = "Track " .. (#tracks + 1)
              end
              tracks[#tracks + 1] = current_track

              -- Adjust depth for next track based on folder status
              if current_track.is_folder then
                current_depth = current_depth + 1
              end
            end
            current_track = nil
          end
        end

        -- Handle BUSCOMP which closes folder levels
        -- BUSCOMP <mode> <depth_adjustment>
        local buscomp_mode, depth_adj = line:match('^%s*BUSCOMP%s+(%d+)%s+(%d+)')
        if depth_adj then
          depth_adj = tonumber(depth_adj)
          if depth_adj and depth_adj > 0 then
            -- This track closes folder levels - adjust for NEXT track
            -- The adjustment happens after we add this track
          end
        end
      end
    end
  end)

  file:close()

  if not ok then
    Logger.warn("TRACKPARSER", "Failed to parse tracks from %s: %s", filepath, tostring(err))
    return nil
  end

  -- Post-process to fix depth based on ISBUS/BUSCOMP relationships
  -- Simplified approach: use ISBUS 1 for folder start, ISBUS 2 for folder end
  local fixed_tracks = {}
  local depth_stack = { 0 }  -- Stack of folder depths

  for _, track in ipairs(tracks) do
    local current_depth_level = depth_stack[#depth_stack] or 0
    fixed_tracks[#fixed_tracks + 1] = {
      name = track.name,
      depth = current_depth_level,
      is_folder = track.is_folder,
      color = track.color,
    }
    if track.is_folder then
      -- Push new depth for children
      depth_stack[#depth_stack + 1] = current_depth_level + 1
    end
  end

  return fixed_tracks
end

-- Quick count of tracks (for performance when full parse not needed)
function M.count_tracks(filepath)
  local file = io.open(filepath, "r")
  if not file then return 1 end

  local count = 0
  for line in file:lines() do
    if line:match("^%s*<TRACK") then
      count = count + 1
    end
  end

  file:close()
  return count > 0 and count or 1
end

return M

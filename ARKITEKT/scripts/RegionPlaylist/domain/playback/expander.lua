-- @noindex
-- RegionPlaylist/domain/playback/sequence_expander.lua
-- Expands nested playlists into a flat playback sequence with ancestry tracking
--
-- Each sequence entry includes an 'ancestry' array that records the full path
-- from the root playlist to this entry. This enables correct progress display
-- for arbitrarily nested playlists without key collisions.

local Logger = require('arkitekt.debug.logger')

local SequenceExpander = {}

local function normalize_loops(value)
  local reps = tonumber(value) or 1
  if reps < 1 then
    return 1
  end
  return reps // 1
end

-- Deep copy ancestry array and optionally append a new entry
local function copy_ancestry(ancestry, new_entry)
  local copy = {}
  for i, entry in ipairs(ancestry) do
    copy[i] = entry  -- Entries are immutable {key, rep} tables
  end
  if new_entry then
    copy[#copy + 1] = new_entry
  end
  return copy
end

local function expand_items(sequence, playlist, get_playlist_by_id, context, ancestry)
  if not playlist or not playlist.items then
    return
  end

  for _, item in ipairs(playlist.items) do
    if item and item.enabled ~= false then
      if item.type == 'playlist' and item.playlist_id then
        local nested_id = item.playlist_id
        local reps = normalize_loops(item.reps)

        if context.stack[nested_id] then
          context.cycle_detected = true
        else
          local nested_playlist = get_playlist_by_id and get_playlist_by_id(nested_id)
          if nested_playlist then
            context.stack[nested_id] = true

            for rep = 1, reps do
              -- Create ancestry entry for this playlist occurrence
              local playlist_ancestry = copy_ancestry(ancestry, {
                key = item.key,
                rep = rep,
                total_reps = reps,
                playlist_id = nested_id,
              })

              -- Recursively expand with updated ancestry
              expand_items(sequence, nested_playlist, get_playlist_by_id, context, playlist_ancestry)
            end

            context.stack[nested_id] = nil
          end
        end
      elseif item.type == 'region' and item.rid then
        local reps = normalize_loops(item.reps)
        local key = item.key

        for loop_index = 1, reps do
          sequence[#sequence + 1] = {
            rid = item.rid,
            item_key = key,
            loop = loop_index,
            total_loops = reps,
            ancestry = ancestry,  -- Reference to current ancestry (immutable at this point)
          }
        end
      end
    end
  end
end

function SequenceExpander.expand_playlist(playlist, get_playlist_by_id)
  local sequence = {}
  local context = {
    stack = {},
    cycle_detected = false,
  }

  if playlist then
    context.stack[playlist.id] = true
    expand_items(sequence, playlist, get_playlist_by_id, context, {})
    context.stack[playlist.id] = nil
  end

  return sequence
end

-- Check if an ancestry chain contains a specific playlist item key
function SequenceExpander.ancestry_contains(ancestry, item_key)
  if not ancestry then return false end
  for _, entry in ipairs(ancestry) do
    if entry.key == item_key then
      return true
    end
  end
  return false
end

-- Get the ancestry entry for a specific playlist item key
function SequenceExpander.get_ancestry_entry(ancestry, item_key)
  if not ancestry then return nil end
  for _, entry in ipairs(ancestry) do
    if entry.key == item_key then
      return entry
    end
  end
  return nil
end

function SequenceExpander.debug_print_sequence(sequence, get_region_by_rid)
  Logger.info('SEQUENCER', '=== PLAYBACK SEQUENCE ===')
  for index, entry in ipairs(sequence or {}) do
    local region_name = '(unknown)'
    if get_region_by_rid then
      local region = get_region_by_rid(entry.rid)
      if region and region.name and region.name ~= '' then
        region_name = string.format("'%s'", region.name)
      end
    end

    local ancestry_str = ''
    if entry.ancestry and #entry.ancestry > 0 then
      local parts = {}
      for _, a in ipairs(entry.ancestry) do
        local key_str = a.key and a.key:sub(1, 8) or '?'
        parts[#parts + 1] = string.format('%s[%d/%d]', key_str, a.rep or 0, a.total_reps or 0)
      end
      ancestry_str = ' via ' .. table.concat(parts, '>')
    end

    Logger.info('SEQUENCER', '[%d] rid=%s %s (loop %d/%d) key=%s%s',
      index,
      tostring(entry.rid or 'nil'),
      region_name,
      entry.loop or 1,
      entry.total_loops or 1,
      tostring(entry.item_key or ''),
      ancestry_str
    )
  end

  Logger.info('SEQUENCER', '=== TOTAL: %d entries ===', #(sequence or {}))
end

return SequenceExpander

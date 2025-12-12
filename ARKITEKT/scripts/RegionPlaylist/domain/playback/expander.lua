-- @noindex
-- RegionPlaylist/domain/playback/sequence_expander.lua
-- Expands nested playlists into a flat playback sequence with ancestry tracking
--
-- Each sequence entry includes an 'ancestry' array that records the full path
-- from the root playlist to this entry. This enables correct progress display
-- for arbitrarily nested playlists without key collisions.

local Logger = require('arkitekt.debug.logger')

local SequenceExpander = {}

-- Returns: reps (number), is_infinite (boolean)
-- reps = 0 means infinite loop (displayed as ∞ in UI)
-- reps < 0 is treated as 1 (invalid)
local function normalize_loops(value)
  local reps = tonumber(value) or 1
  if reps == 0 then
    return 0, true  -- Infinite
  elseif reps < 1 then
    return 1, false  -- Invalid -> default to 1
  end
  return reps // 1, false
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
        local reps, is_infinite = normalize_loops(item.reps)

        if context.stack[nested_id] then
          context.cycle_detected = true
        else
          local nested_playlist = get_playlist_by_id and get_playlist_by_id(nested_id)
          if nested_playlist then
            context.stack[nested_id] = true

            -- For infinite playlists, expand once with is_infinite flag
            local loop_count = is_infinite and 1 or reps
            for rep = 1, loop_count do
              -- Create ancestry entry for this playlist occurrence
              local playlist_ancestry = copy_ancestry(ancestry, {
                key = item.key,
                rep = rep,
                total_reps = is_infinite and 0 or reps,  -- 0 indicates infinite
                playlist_id = nested_id,
                is_infinite = is_infinite,
              })

              -- Recursively expand with updated ancestry
              expand_items(sequence, nested_playlist, get_playlist_by_id, context, playlist_ancestry)
            end

            context.stack[nested_id] = nil
          end
        end
      elseif item.type == 'region' and item.rid then
        local reps, is_infinite = normalize_loops(item.reps)
        local key = item.key

        -- For infinite regions, add single entry with is_infinite flag
        local loop_count = is_infinite and 1 or reps
        for loop_index = 1, loop_count do
          sequence[#sequence + 1] = {
            rid = item.rid,
            item_key = key,
            loop = loop_index,
            total_loops = is_infinite and 0 or reps,  -- 0 indicates infinite
            is_infinite = is_infinite,
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

    local loop_str = entry.is_infinite and '∞' or string.format('%d/%d', entry.loop or 1, entry.total_loops or 1)
    Logger.info('SEQUENCER', '[%d] rid=%s %s (loop %s) key=%s%s',
      index,
      tostring(entry.rid or 'nil'),
      region_name,
      loop_str,
      tostring(entry.item_key or ''),
      ancestry_str
    )
  end

  Logger.info('SEQUENCER', '=== TOTAL: %d entries ===', #(sequence or {}))
end

return SequenceExpander

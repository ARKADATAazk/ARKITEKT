-- @noindex
-- Region_Playlist/app/sequence_expander.lua
-- Expands nested playlists into a flat playback sequence with loop metadata

local SequenceExpander = {}

local function normalize_loops(value)
  local reps = tonumber(value) or 1
  if reps < 1 then
    return 1
  end
  return math.floor(reps)
end

local function expand_items(sequence, playlist, get_playlist_by_id, context)
  if not playlist or not playlist.items then
    return
  end

  for _, item in ipairs(playlist.items) do
    if item and item.enabled ~= false then
      if item.type == "playlist" and item.playlist_id then
        local nested_id = item.playlist_id
        local reps = normalize_loops(item.reps)

        if context.stack[nested_id] then
          context.cycle_detected = true
        else
          local nested_playlist = get_playlist_by_id and get_playlist_by_id(nested_id)
          if nested_playlist then
            context.stack[nested_id] = true
            local nested_sequence = {}
            expand_items(nested_sequence, nested_playlist, get_playlist_by_id, context)
            context.stack[nested_id] = nil

            for _ = 1, reps do
              for _, nested_entry in ipairs(nested_sequence) do
                sequence[#sequence + 1] = {
                  rid = nested_entry.rid,
                  item_key = nested_entry.item_key,
                  loop = nested_entry.loop,
                  total_loops = nested_entry.total_loops,
                }
              end
            end
          end
        end
      elseif item.type == "region" and item.rid then
        local reps = normalize_loops(item.reps)
        local key = item.key or ("region_" .. tostring(item.rid))

        for loop_index = 1, reps do
          sequence[#sequence + 1] = {
            rid = item.rid,
            item_key = key,
            loop = loop_index,
            total_loops = reps,
          }
        end
      end
    end
  end
end

function SequenceExpander.expand_playlist(playlist, get_playlist_by_id)
  local sequence = {}
  local context = { stack = {}, cycle_detected = false }

  if playlist then
    context.stack[playlist.id] = true
    expand_items(sequence, playlist, get_playlist_by_id, context)
    context.stack[playlist.id] = nil
  end

  return sequence
end

function SequenceExpander.debug_print_sequence(sequence, get_region_by_rid)
  reaper.ShowConsoleMsg("=== PLAYBACK SEQUENCE ===\n")
  for index, entry in ipairs(sequence or {}) do
    local region_name = "(unknown)"
    if get_region_by_rid then
      local region = get_region_by_rid(entry.rid)
      if region and region.name and region.name ~= "" then
        region_name = string.format("'%s'", region.name)
      end
    end

    reaper.ShowConsoleMsg(string.format(
      "[%d] rid=%s %s (loop %d/%d) key=%s\n",
      index,
      tostring(entry.rid or "nil"),
      region_name,
      entry.loop or 1,
      entry.total_loops or 1,
      tostring(entry.item_key or "")
    ))
  end

  reaper.ShowConsoleMsg(string.format("=== TOTAL: %d entries ===\n", #(sequence or {})))
end

return SequenceExpander

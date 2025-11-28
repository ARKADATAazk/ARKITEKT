-- @noindex
-- ItemPicker/domain/filters/track.lua
-- Pure track filtering logic (no UI dependencies)

local M = {}

-- Build track hierarchy from project
-- Returns array of track nodes with parent/children relationships
function M.build_track_tree()
  local tracks = {}
  local track_count = reaper.CountTracks(0)

  -- First pass: collect all tracks with metadata
  local all_tracks = {}
  for i = 0, track_count - 1 do
    local track = reaper.GetTrack(0, i)
    if not track then goto continue end

    local guid = reaper.GetTrackGUID(track)
    local _, name = reaper.GetTrackName(track)
    local color = reaper.GetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR")
    local depth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
    local folder_depth = reaper.GetTrackDepth(track)

    all_tracks[i + 1] = {
      track = track,
      guid = guid,
      name = name or ("Track " .. (i + 1)),
      color = color,
      index = i + 1,
      depth = folder_depth,
      folder_depth = depth,  -- 1 = folder start, 0 = normal, -1/-2 = folder end
      children = {},
      is_folder = depth == 1,
      parent = nil,
    }

    ::continue::
  end

  -- Second pass: build tree structure with parent references
  local root = { children = {}, guid = nil }
  local stack = { root }

  for i, track_data in ipairs(all_tracks) do
    local parent = stack[#stack]
    track_data.parent = parent.guid and parent or nil
    parent.children[#parent.children + 1] = track_data

    if track_data.folder_depth == 1 then
      stack[#stack + 1] = track_data
    elseif track_data.folder_depth < 0 then
      for j = 1, -track_data.folder_depth do
        if #stack > 1 then
          table.remove(stack)
        end
      end
    end
  end

  return root.children
end

-- Check if a track is effectively selected (itself and all ancestors enabled)
function M.is_effectively_selected(track, whitelist)
  local self_selected = whitelist[track.guid]
  if self_selected == nil then self_selected = true end
  if not self_selected then return false end

  local ancestor = track.parent
  while ancestor do
    local ancestor_selected = whitelist[ancestor.guid]
    if ancestor_selected == nil then ancestor_selected = true end
    if not ancestor_selected then return false end
    ancestor = ancestor.parent
  end

  return true
end

-- Check if any parent is disabled (for visual dimming)
function M.is_parent_disabled(track, whitelist)
  local ancestor = track.parent
  while ancestor do
    local ancestor_selected = whitelist[ancestor.guid]
    if ancestor_selected == nil then ancestor_selected = true end
    if not ancestor_selected then return true end
    ancestor = ancestor.parent
  end
  return false
end

-- Build full track path string (e.g., "Folder > Subfolder > Track")
function M.get_track_path(track)
  local path_parts = {}
  local current = track
  while current do
    table.insert(path_parts, 1, current.name)
    current = current.parent
  end
  return table.concat(path_parts, " > ")
end

-- Calculate total height needed for track tree display
function M.calculate_tree_height(tracks, expanded_state, tile_height, margin_y, depth)
  depth = depth or 0
  tile_height = tile_height or 18
  margin_y = margin_y or 1
  local height = 0

  for _, track in ipairs(tracks) do
    height = height + tile_height + margin_y

    local has_children = track.children and #track.children > 0
    local is_expanded = expanded_state and expanded_state[track.guid]
    if is_expanded == nil then is_expanded = true end

    if has_children and is_expanded then
      height = height + M.calculate_tree_height(track.children, expanded_state, tile_height, margin_y, depth + 1)
    end
  end

  return height
end

-- Calculate maximum depth of the track tree
function M.calculate_max_depth(tracks, current_depth)
  current_depth = current_depth or 0
  local max_depth = current_depth

  for _, track in ipairs(tracks) do
    if track.children and #track.children > 0 then
      local child_depth = M.calculate_max_depth(track.children, current_depth + 1)
      if child_depth > max_depth then
        max_depth = child_depth
      end
    end
  end

  return max_depth
end

-- Set expansion state based on depth level
function M.set_expansion_level(tracks, expanded_state, target_level, current_depth)
  current_depth = current_depth or 0

  for _, track in ipairs(tracks) do
    if track.children and #track.children > 0 then
      expanded_state[track.guid] = current_depth < target_level
      M.set_expansion_level(track.children, expanded_state, target_level, current_depth + 1)
    end
  end
end

-- Initialize whitelist with all tracks selected
function M.init_whitelist(tracks, whitelist)
  whitelist = whitelist or {}
  for _, track in ipairs(tracks) do
    whitelist[track.guid] = true
    if track.children then
      M.init_whitelist(track.children, whitelist)
    end
  end
  return whitelist
end

-- Count total and selected tracks
function M.count_tracks(tracks, whitelist)
  local total = 0
  local selected = 0

  local function count(track_list)
    for _, track in ipairs(track_list) do
      total = total + 1
      if whitelist[track.guid] then
        selected = selected + 1
      end
      if track.children then
        count(track.children)
      end
    end
  end

  count(tracks)
  return total, selected
end

-- Select/deselect all tracks recursively
function M.set_all_tracks(tracks, whitelist, value)
  for _, track in ipairs(tracks) do
    whitelist[track.guid] = value
    if track.children then
      M.set_all_tracks(track.children, whitelist, value)
    end
  end
end

return M

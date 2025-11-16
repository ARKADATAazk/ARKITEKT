-- @noindex
-- TemplateBrowser/domain/scanner.lua
-- Scans REAPER's track template directory with UUID tracking

local M = {}
local Persistence = require('TemplateBrowser.domain.persistence')
local FXQueue = require('TemplateBrowser.domain.fx_queue')

-- Get REAPER's default track template path
local function get_template_path()
  local resource_path = reaper.GetResourcePath()
  local sep = package.config:sub(1,1)
  return resource_path .. sep .. "TrackTemplates" .. sep
end

-- Recursively scan directory for .RTrackTemplate files
local function scan_directory(path, relative_path, metadata)
  relative_path = relative_path or ""

  local templates = {}
  local folders = {}

  local sep = package.config:sub(1,1)
  local idx = 0

  while true do
    local file = reaper.EnumerateFiles(path, idx)
    if not file then break end

    -- Check if it's a track template
    if file:match("%.RTrackTemplate$") then
      local template_name = file:gsub("%.RTrackTemplate$", "")
      local full_path = path .. file
      local relative_folder = relative_path

      -- Skip FX parsing during initial scan - will be parsed in background
      local fx_list = {}

      -- Try to find existing template in metadata by name+path
      local existing = Persistence.find_template(metadata, nil, template_name, relative_path)

      local uuid
      if existing then
        uuid = existing.uuid
        -- Update metadata
        existing.name = template_name
        existing.path = relative_path
        existing.last_seen = os.time()
        -- Preserve existing FX list from metadata (will be updated by queue)
        fx_list = existing.fx or {}
      else
        -- Create new UUID and metadata entry
        uuid = Persistence.generate_uuid()
        metadata.templates[uuid] = {
          uuid = uuid,
          name = template_name,
          path = relative_path,
          tags = {},
          notes = "",
          fx = {},  -- Empty initially, will be populated by background parser
          created = os.time(),
          last_seen = os.time()
        }
        reaper.ShowConsoleMsg("New template UUID: " .. template_name .. " -> " .. uuid .. "\n")
      end

      table.insert(templates, {
        uuid = uuid,
        name = template_name,
        file = file,
        path = full_path,
        relative_path = relative_path,
        folder = relative_path ~= "" and relative_path or "Root",
        fx = fx_list,  -- Will be populated by background parser
      })
    end

    idx = idx + 1
  end

  -- Scan subdirectories
  idx = 0
  while true do
    local subdir = reaper.EnumerateSubdirectories(path, idx)
    if not subdir then break end

    local new_relative = relative_path ~= "" and (relative_path .. sep .. subdir) or subdir
    local sub_path = path .. subdir .. sep

    -- Try to find existing folder in metadata
    local existing_folder = Persistence.find_folder(metadata, nil, subdir, new_relative)

    local folder_uuid
    if existing_folder then
      folder_uuid = existing_folder.uuid
      existing_folder.name = subdir
      existing_folder.path = new_relative
      existing_folder.last_seen = os.time()
    else
      -- Create new UUID and metadata entry
      folder_uuid = Persistence.generate_uuid()
      metadata.folders[folder_uuid] = {
        uuid = folder_uuid,
        name = subdir,
        path = new_relative,
        tags = {},
        created = os.time(),
        last_seen = os.time()
      }
      reaper.ShowConsoleMsg("New folder UUID: " .. subdir .. " -> " .. folder_uuid .. "\n")
    end

    -- Recursively scan subdirectory
    local sub_templates, sub_folders = scan_directory(sub_path, new_relative, metadata)

    -- Add folder to list
    table.insert(folders, {
      uuid = folder_uuid,
      name = subdir,
      path = new_relative,
      full_path = sub_path,
      parent = relative_path,
    })

    -- Merge templates
    for _, tmpl in ipairs(sub_templates) do
      table.insert(templates, tmpl)
    end

    -- Merge folders
    for _, fld in ipairs(sub_folders) do
      table.insert(folders, fld)
    end

    idx = idx + 1
  end

  return templates, folders
end

-- Build folder tree structure
local function build_folder_tree(folders)
  local tree = {
    name = "Root",
    path = "",
    children = {},
    is_root = true,
  }

  -- Sort folders by path depth
  table.sort(folders, function(a, b)
    local a_depth = select(2, a.path:gsub("/", "")) + select(2, a.path:gsub("\\", ""))
    local b_depth = select(2, b.path:gsub("/", "")) + select(2, b.path:gsub("\\", ""))
    return a_depth < b_depth
  end)

  local path_to_node = {[""] = tree}

  for _, folder in ipairs(folders) do
    local parent_node = path_to_node[folder.parent] or tree
    local node = {
      uuid = folder.uuid,
      name = folder.name,
      path = folder.path,
      full_path = folder.full_path,
      children = {},
      parent = parent_node,
    }
    table.insert(parent_node.children, node)
    path_to_node[folder.path] = node
  end

  return tree
end

-- Main scan function
function M.scan_templates(state)
  local template_path = get_template_path()

  reaper.ShowConsoleMsg("=== TemplateBrowser: Scanning templates ===\n")
  reaper.ShowConsoleMsg("Template path: " .. template_path .. "\n")

  -- Load metadata
  local metadata = Persistence.load_metadata()
  state.metadata = metadata

  -- Scan with UUID tracking (FX parsing is deferred to background queue)
  local templates, folders = scan_directory(template_path, "", metadata)

  state.templates = templates
  state.filtered_templates = templates
  state.folders = build_folder_tree(folders)

  -- Save updated metadata
  Persistence.save_metadata(metadata)

  reaper.ShowConsoleMsg(string.format("Found %d templates in %d folders\n", #templates, #folders))

  -- Start background FX parsing
  FXQueue.add_to_queue(state, templates)
end

-- Filter templates by folder and search
function M.filter_templates(state)
  local filtered = {}

  -- Count active FX filters
  local fx_filter_count = 0
  for _ in pairs(state.filter_fx) do
    fx_filter_count = fx_filter_count + 1
  end

  reaper.ShowConsoleMsg(string.format("Filtering: selected_folder='%s', search='%s', fx_filters=%d\n",
    state.selected_folder or "nil", state.search_query, fx_filter_count))

  for _, tmpl in ipairs(state.templates) do
    local matches = true

    -- Filter by folder
    if state.selected_folder and state.selected_folder ~= "" then
      -- Exact match on relative_path
      if tmpl.relative_path ~= state.selected_folder then
        matches = false
      end
    end

    -- Filter by search query
    if matches and state.search_query ~= "" then
      local query_lower = state.search_query:lower()
      if not tmpl.name:lower():match(query_lower) then
        matches = false
      end
    end

    -- Filter by FX (template must have ALL selected FX)
    if matches and fx_filter_count > 0 then
      if not tmpl.fx then
        matches = false
      else
        for fx_name in pairs(state.filter_fx) do
          local has_fx = false
          for _, template_fx in ipairs(tmpl.fx) do
            if template_fx == fx_name then
              has_fx = true
              break
            end
          end
          if not has_fx then
            matches = false
            break
          end
        end
      end
    end

    if matches then
      table.insert(filtered, tmpl)
    end
  end

  reaper.ShowConsoleMsg(string.format("Filtered: %d -> %d templates\n", #state.templates, #filtered))
  state.filtered_templates = filtered
end

return M

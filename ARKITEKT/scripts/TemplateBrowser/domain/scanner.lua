-- @noindex
-- TemplateBrowser/domain/scanner.lua
-- Scans REAPER's track template directory

local M = {}

-- Get REAPER's default track template path
local function get_template_path()
  local resource_path = reaper.GetResourcePath()
  local sep = package.config:sub(1,1)
  return resource_path .. sep .. "TrackTemplates" .. sep
end

-- Recursively scan directory for .RTrackTemplate files
local function scan_directory(path, relative_path)
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
      table.insert(templates, {
        name = template_name,
        file = file,
        path = path .. file,
        relative_path = relative_path,
        folder = relative_path ~= "" and relative_path or "Root",
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

    -- Recursively scan subdirectory
    local sub_templates, sub_folders = scan_directory(sub_path, new_relative)

    -- Add folder to list
    table.insert(folders, {
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

  local templates, folders = scan_directory(template_path, "")

  state.templates = templates
  state.filtered_templates = templates
  state.folders = build_folder_tree(folders)

  reaper.ShowConsoleMsg(string.format("Found %d templates in %d folders\n", #templates, #folders))
end

-- Filter templates by folder and search
function M.filter_templates(state)
  local filtered = {}

  for _, tmpl in ipairs(state.templates) do
    local matches = true

    -- Filter by folder
    if state.selected_folder and state.selected_folder ~= "" then
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

    if matches then
      table.insert(filtered, tmpl)
    end
  end

  state.filtered_templates = filtered
end

return M

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

      -- Get file size for change detection
      local file_handle, err = io.open(full_path, "r")
      local file_size = nil
      if file_handle then
        file_size = file_handle:seek("end")  -- Returns position at end = file size
        file_handle:close()
      else
        reaper.ShowConsoleMsg("WARNING: Cannot open file for size check: " .. full_path .. "\n")
        if err then
          reaper.ShowConsoleMsg("ERROR: " .. tostring(err) .. "\n")
        end
      end

      -- Try to find existing template in metadata by name+path
      local existing = Persistence.find_template(metadata, nil, template_name, relative_path)

      local uuid
      local fx_list = {}
      local needs_fx_parse = false

      if existing then
        uuid = existing.uuid
        -- Update metadata
        existing.name = template_name
        existing.path = relative_path
        existing.last_seen = os.time()

        -- Check if file has changed by comparing size
        local size_changed = false
        if file_size and existing.file_size then
          size_changed = (existing.file_size ~= file_size)
        elseif file_size and not existing.file_size then
          -- We have size now but didn't before - old metadata without file_size
          size_changed = true  -- Re-parse to get FX with new system
          reaper.ShowConsoleMsg("FX: Old metadata (no file_size): " .. template_name .. "\n")
        elseif not file_size and existing.file_size then
          -- Had size before but can't read now - something wrong
          reaper.ShowConsoleMsg("WARNING: Could not read file size for: " .. template_name .. "\n")
          size_changed = false  -- Don't re-parse due to read error
        end

        -- Only re-parse if fx field is missing (nil), not if it's an empty array
        local missing_fx = (existing.fx == nil)

        if size_changed then
          reaper.ShowConsoleMsg("FX: File changed (size): " .. template_name .. " (" .. tostring(existing.file_size) .. " -> " .. tostring(file_size) .. ")\n")
          needs_fx_parse = true
          fx_list = {}
        elseif missing_fx then
          reaper.ShowConsoleMsg("FX: Missing FX data: " .. template_name .. "\n")
          needs_fx_parse = true
          fx_list = {}
        else
          -- File unchanged - use cached FX
          fx_list = existing.fx or {}
        end

        -- Update file size in metadata
        if file_size then
          existing.file_size = file_size
        end
      else
        -- Create new UUID and metadata entry
        uuid = Persistence.generate_uuid()

        local new_metadata = {
          uuid = uuid,
          name = template_name,
          path = relative_path,
          tags = {},
          notes = "",
          fx = {},
          created = os.time(),
          last_seen = os.time(),
          usage_count = 0,
          last_used = nil,
          chip_color = nil  -- Color chip for template (can be set via context menu)
        }

        -- Only set file_size if we successfully read it
        if file_size then
          new_metadata.file_size = file_size
        end

        metadata.templates[uuid] = new_metadata
        needs_fx_parse = true
        reaper.ShowConsoleMsg("New template UUID: " .. template_name .. " -> " .. uuid .. "\n")
      end

      table.insert(templates, {
        uuid = uuid,
        name = template_name,
        file = file,
        path = full_path,
        relative_path = relative_path,
        folder = relative_path ~= "" and relative_path or "Root",
        fx = fx_list,
        needs_fx_parse = needs_fx_parse,  -- Flag for queue
      })
    end

    idx = idx + 1
  end

  -- Scan subdirectories
  idx = 0
  while true do
    local subdir = reaper.EnumerateSubdirectories(path, idx)
    if not subdir then break end

    -- Skip .archive folder (it's managed separately)
    if subdir ~= ".archive" then
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

      -- Get folder color from metadata if available
      local folder_color = nil
      if metadata.folders[folder_uuid] and metadata.folders[folder_uuid].color then
        folder_color = metadata.folders[folder_uuid].color
      end

      -- Add folder to list
      table.insert(folders, {
        uuid = folder_uuid,
        name = subdir,
        path = new_relative,
        full_path = sub_path,
        parent = relative_path,
        color = folder_color,
      })

      -- Merge templates
      for _, tmpl in ipairs(sub_templates) do
        table.insert(templates, tmpl)
      end

      -- Merge folders
      for _, fld in ipairs(sub_folders) do
        table.insert(folders, fld)
      end
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
      color = folder.color,  -- Pass color from metadata to tree node
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

  -- Debug: Check if metadata loaded
  local template_count = 0
  if metadata and metadata.templates then
    for _ in pairs(metadata.templates) do
      template_count = template_count + 1
    end
  end
  local sep = package.config:sub(1,1)
  Persistence.log("=== Scanning Templates ===")
  Persistence.log("Path separator: '" .. sep .. "' (ASCII: " .. string.byte(sep) .. ")")
  Persistence.log("Loaded metadata with " .. template_count .. " templates")

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

  -- Count active tag filters
  local tag_filter_count = 0
  for _ in pairs(state.filter_tags) do
    tag_filter_count = tag_filter_count + 1
  end

  for _, tmpl in ipairs(state.templates) do
    local matches = true

    -- Filter by folder (supports multi-select and includes subfolders)
    if state.selected_folder and state.selected_folder ~= "" then
      -- Build list of selected folders (support both single and multi-select)
      local selected_folders = {}

      -- Check if we have multi-selection
      if state.selected_folders and next(state.selected_folders) then
        -- Multi-select: use all selected folders
        for folder_path, _ in pairs(state.selected_folders) do
          table.insert(selected_folders, folder_path)
        end
      else
        -- Single select: use state.selected_folder
        table.insert(selected_folders, state.selected_folder)
      end

      -- Check if template matches any of the selected folders (including subfolders)
      local found_in_folder = false

      for _, folder_path in ipairs(selected_folders) do
        -- Check if this is a virtual folder
        local is_virtual_folder = state.metadata and state.metadata.virtual_folders and state.metadata.virtual_folders[folder_path]

        if is_virtual_folder then
          -- Special case: __VIRTUAL_ROOT__ means show all templates from all virtual folders
          if folder_path == "__VIRTUAL_ROOT__" then
            -- Check if template exists in ANY virtual folder
            for _, vfolder in pairs(state.metadata.virtual_folders) do
              if vfolder.template_refs then
                for _, ref_uuid in ipairs(vfolder.template_refs) do
                  if ref_uuid == tmpl.uuid then
                    found_in_folder = true
                    break
                  end
                end
              end
              if found_in_folder then break end
            end
            if found_in_folder then break end
          else
            -- Virtual folder: check if template UUID is in template_refs (recursive check)
            local function check_virtual_folder_recursive(vfolder_id)
              local vfolder = state.metadata.virtual_folders[vfolder_id]
              if not vfolder then return false end

              -- Check direct references
              if vfolder.template_refs then
                for _, ref_uuid in ipairs(vfolder.template_refs) do
                  if ref_uuid == tmpl.uuid then
                    return true
                  end
                end
              end

              -- Check child virtual folders
              for _, child_vfolder in pairs(state.metadata.virtual_folders) do
                if child_vfolder.parent_id == vfolder_id then
                  if check_virtual_folder_recursive(child_vfolder.id) then
                    return true
                  end
                end
              end

              return false
            end

            if check_virtual_folder_recursive(folder_path) then
              found_in_folder = true
              break
            end
          end
        else
          -- Physical folder: check if template is in this folder or any subfolder
          -- Special case: __ROOT__ means show all physical templates
          if folder_path == "__ROOT__" or folder_path == "" then
            found_in_folder = true
            break
          end

          -- Check exact match OR if template path starts with folder path + separator
          local tmpl_path = tmpl.relative_path or ""
          local sep = package.config:sub(1,1)

          if tmpl_path == folder_path then
            -- Exact match: template is directly in this folder
            found_in_folder = true
            break
          elseif tmpl_path:find("^" .. folder_path:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1") .. sep) then
            -- Template is in a subfolder
            found_in_folder = true
            break
          end
        end
      end

      if not found_in_folder then
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

    -- Filter by tags (template must have ALL selected tags)
    if matches and tag_filter_count > 0 then
      local tmpl_metadata = state.metadata and state.metadata.templates[tmpl.uuid]
      if not tmpl_metadata or not tmpl_metadata.tags then
        matches = false
      else
        for tag_name in pairs(state.filter_tags) do
          local has_tag = false
          for _, template_tag in ipairs(tmpl_metadata.tags) do
            if template_tag == tag_name then
              has_tag = true
              break
            end
          end
          if not has_tag then
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

  -- Sort filtered templates based on sort mode
  if state.sort_mode == "alphabetical" then
    table.sort(filtered, function(a, b)
      return a.name:lower() < b.name:lower()
    end)
  elseif state.sort_mode == "usage" then
    table.sort(filtered, function(a, b)
      local a_usage = (state.metadata and state.metadata.templates[a.uuid] and state.metadata.templates[a.uuid].usage_count) or 0
      local b_usage = (state.metadata and state.metadata.templates[b.uuid] and state.metadata.templates[b.uuid].usage_count) or 0
      if a_usage == b_usage then
        -- Tie-breaker: alphabetical
        return a.name:lower() < b.name:lower()
      end
      return a_usage > b_usage  -- Most used first
    end)
  elseif state.sort_mode == "insertion" then
    table.sort(filtered, function(a, b)
      local a_created = (state.metadata and state.metadata.templates[a.uuid] and state.metadata.templates[a.uuid].created) or 0
      local b_created = (state.metadata and state.metadata.templates[b.uuid] and state.metadata.templates[b.uuid].created) or 0
      if a_created == b_created then
        -- Tie-breaker: alphabetical
        return a.name:lower() < b.name:lower()
      end
      return a_created > b_created  -- Most recent first
    end)
  elseif state.sort_mode == "color" then
    -- Sort by color: colored templates first (grouped by color), then uncolored (alphabetical)
    table.sort(filtered, function(a, b)
      local a_metadata = state.metadata and state.metadata.templates[a.uuid]
      local b_metadata = state.metadata and state.metadata.templates[b.uuid]
      local a_color = a_metadata and a_metadata.chip_color
      local b_color = b_metadata and b_metadata.chip_color

      -- If both have colors, sort by color value (groups similar colors)
      if a_color and b_color then
        if a_color == b_color then
          -- Same color: alphabetical
          return a.name:lower() < b.name:lower()
        end
        return a_color < b_color
      end

      -- Colored templates come before uncolored
      if a_color and not b_color then
        return true
      end
      if not a_color and b_color then
        return false
      end

      -- Both uncolored: alphabetical
      return a.name:lower() < b.name:lower()
    end)
  end

  state.filtered_templates = filtered
end

return M

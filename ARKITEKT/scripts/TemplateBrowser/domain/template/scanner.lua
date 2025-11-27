-- @noindex
-- TemplateBrowser/domain/template/scanner.lua
-- Scans REAPER's track template directory with UUID tracking

local M = {}
local Logger = require('arkitekt.debug.logger')
local Persistence = require('TemplateBrowser.data.storage')
local FXQueue = require('TemplateBrowser.domain.fx.queue')

-- Scan state for incremental scanning
local scan_state = {
  active = false,
  files_to_scan = {},
  files_scanned = 0,
  total_files = 0,
  metadata = nil,
  templates = {},
  folders = {},
}

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
        Logger.warn("SCANNER", "Cannot open file for size check: %s", full_path)
        if err then
          Logger.error("SCANNER", "%s", tostring(err))
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
          Logger.debug("SCANNER", "FX: Old metadata (no file_size): %s", template_name)
        elseif not file_size and existing.file_size then
          -- Had size before but can't read now - something wrong
          Logger.warn("SCANNER", "Could not read file size for: %s", template_name)
          size_changed = false  -- Don't re-parse due to read error
        end

        -- Only re-parse if fx field is missing (nil), not if it's an empty array
        local missing_fx = (existing.fx == nil)

        if size_changed then
          Logger.debug("SCANNER", "FX: File changed (size): %s (%s -> %s)", template_name, tostring(existing.file_size), tostring(file_size))
          needs_fx_parse = true
          fx_list = {}
        elseif missing_fx then
          Logger.debug("SCANNER", "FX: Missing FX data: %s", template_name)
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
        Logger.debug("SCANNER", "New template UUID: %s -> %s", template_name, uuid)
      end

      templates[#templates + 1] = {
        uuid = uuid,
        name = template_name,
        file = file,
        path = full_path,
        relative_path = relative_path,
        folder = relative_path ~= "" and relative_path or "Root",
        fx = fx_list,
        needs_fx_parse = needs_fx_parse,  -- Flag for queue
      }
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
        Logger.debug("SCANNER", "New folder UUID: %s -> %s", subdir, folder_uuid)
      end

      -- Recursively scan subdirectory
      local sub_templates, sub_folders = scan_directory(sub_path, new_relative, metadata)

      -- Get folder color from metadata if available
      local folder_color = nil
      if metadata.folders[folder_uuid] and metadata.folders[folder_uuid].color then
        folder_color = metadata.folders[folder_uuid].color
      end

      -- Add folder to list
      folders[#folders + 1] = {
        uuid = folder_uuid,
        name = subdir,
        path = new_relative,
        full_path = sub_path,
        parent = relative_path,
        color = folder_color,
      }

      -- Merge templates
      for _, tmpl in ipairs(sub_templates) do
        templates[#templates + 1] = tmpl
      end

      -- Merge folders
      for _, fld in ipairs(sub_folders) do
        folders[#folders + 1] = fld
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
    parent_node.children[#parent_node.children + 1] = node
    path_to_node[folder.path] = node
  end

  return tree
end

-- Main scan function
function M.scan_templates(state)
  local template_path = get_template_path()

  Logger.info("SCANNER", "=== Scanning templates ===")
  Logger.info("SCANNER", "Template path: %s", template_path)

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

  Logger.info("SCANNER", "Found %d templates in %d folders", #templates, #folders)

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

  -- Pre-compute selected folders list ONCE before template loop (optimization)
  local selected_folders = {}
  local escaped_folder_paths = {}  -- Pre-escaped paths for regex matching
  local sep = package.config:sub(1,1)

  if state.selected_folder and state.selected_folder ~= "" then
    -- Check if we have multi-selection
    if state.selected_folders and next(state.selected_folders) then
      -- Multi-select: use all selected folders
      for folder_path, _ in pairs(state.selected_folders) do
        selected_folders[#selected_folders + 1] = folder_path
        -- Pre-escape special regex characters for path matching
        escaped_folder_paths[folder_path] = folder_path:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
      end
    else
      -- Single select: use state.selected_folder
      selected_folders[#selected_folders + 1] = state.selected_folder
      escaped_folder_paths[state.selected_folder] = state.selected_folder:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    end
  end

  local has_folder_filter = #selected_folders > 0

  for _, tmpl in ipairs(state.templates) do
    local matches = true

    -- Filter by folder (supports multi-select and includes subfolders)
    if has_folder_filter then

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

          if tmpl_path == folder_path then
            -- Exact match: template is directly in this folder
            found_in_folder = true
            break
          elseif tmpl_path:find("^" .. escaped_folder_paths[folder_path] .. sep) then
            -- Template is in a subfolder (using pre-escaped path for performance)
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
      filtered[#filtered + 1] = tmpl
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

-- Initialize incremental scanning
function M.scan_init(state)
  local template_path = get_template_path()

  Logger.info("SCANNER", "=== Starting incremental scan ===")
  Logger.info("SCANNER", "Template path: %s", template_path)

  -- Load metadata
  local metadata = Persistence.load_metadata()
  state.metadata = metadata

  -- Build list of all files to scan
  local files_to_scan = {}
  local folders = {}

  local function enumerate_all(path, relative_path)
    relative_path = relative_path or ""
    local sep = package.config:sub(1,1)

    -- Enumerate files
    local idx = 0
    while true do
      local file = reaper.EnumerateFiles(path, idx)
      if not file then break end

      if file:match("%.RTrackTemplate$") then
        files_to_scan[#files_to_scan + 1] = {
          path = path,
          file = file,
          relative_path = relative_path,
        }
      end
      idx = idx + 1
    end

    -- Enumerate subdirectories
    idx = 0
    while true do
      local subdir = reaper.EnumerateSubdirectories(path, idx)
      if not subdir then break end

      if subdir ~= ".archive" then
        local new_relative = relative_path ~= "" and (relative_path .. sep .. subdir) or subdir
        local sub_path = path .. subdir .. sep

        -- Add folder info
        folders[#folders + 1] = {
          name = subdir,
          path = new_relative,
          full_path = sub_path,
          parent = relative_path,
        }

        -- Recursively enumerate
        enumerate_all(sub_path, new_relative)
      end

      idx = idx + 1
    end
  end

  enumerate_all(template_path, "")

  -- Store scan state
  scan_state.active = true
  scan_state.files_to_scan = files_to_scan
  scan_state.files_scanned = 0
  scan_state.total_files = #files_to_scan
  scan_state.metadata = metadata
  scan_state.templates = {}
  scan_state.folders = folders

  Logger.info("SCANNER", "Found %d templates to scan", #files_to_scan)
end

-- Scan a batch of templates (call this each frame)
-- Returns true when complete
function M.scan_batch(state, batch_size)
  if not scan_state.active then
    return true
  end

  batch_size = batch_size or 50  -- Default: 50 files per frame

  local start_idx = scan_state.files_scanned + 1
  local end_idx = math.min(start_idx + batch_size - 1, scan_state.total_files)

  -- Scan batch
  for i = start_idx, end_idx do
    local file_info = scan_state.files_to_scan[i]
    local path = file_info.path
    local file = file_info.file
    local relative_path = file_info.relative_path

    local template_name = file:gsub("%.RTrackTemplate$", "")
    local full_path = path .. file

    -- Get file size for change detection
    local file_handle, err = io.open(full_path, "r")
    local file_size = nil
    if file_handle then
      file_size = file_handle:seek("end")
      file_handle:close()
    end

    -- Try to find existing template in metadata
    local existing = Persistence.find_template(scan_state.metadata, nil, template_name, relative_path)

    local uuid
    local fx_list = {}
    local needs_fx_parse = false

    if existing then
      uuid = existing.uuid
      existing.name = template_name
      existing.path = relative_path
      existing.last_seen = os.time()

      -- Check if file has changed
      local size_changed = false
      if file_size and existing.file_size then
        size_changed = (existing.file_size ~= file_size)
      elseif file_size and not existing.file_size then
        size_changed = true
      end

      local missing_fx = (existing.fx == nil)

      if size_changed then
        needs_fx_parse = true
        fx_list = {}
      elseif missing_fx then
        needs_fx_parse = true
        fx_list = {}
      else
        fx_list = existing.fx or {}
      end

      if file_size then
        existing.file_size = file_size
      end
    else
      -- Create new UUID
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
        chip_color = nil,
      }

      if file_size then
        new_metadata.file_size = file_size
      end

      scan_state.metadata.templates[uuid] = new_metadata
      needs_fx_parse = true
    end

    scan_state.templates[#scan_state.templates + 1] = {
      uuid = uuid,
      name = template_name,
      file = file,
      path = full_path,
      relative_path = relative_path,
      folder = relative_path ~= "" and relative_path or "Root",
      fx = fx_list,
      needs_fx_parse = needs_fx_parse,
    }
  end

  scan_state.files_scanned = end_idx

  -- Update progress
  state.scan_progress = scan_state.files_scanned / scan_state.total_files

  -- Check if complete
  if scan_state.files_scanned >= scan_state.total_files then
    -- Process folders and build tree
    local folders_with_uuids = {}
    for _, folder in ipairs(scan_state.folders) do
      local existing_folder = Persistence.find_folder(scan_state.metadata, nil, folder.name, folder.path)

      local folder_uuid
      if existing_folder then
        folder_uuid = existing_folder.uuid
        existing_folder.name = folder.name
        existing_folder.path = folder.path
        existing_folder.last_seen = os.time()
      else
        folder_uuid = Persistence.generate_uuid()
        scan_state.metadata.folders[folder_uuid] = {
          uuid = folder_uuid,
          name = folder.name,
          path = folder.path,
          tags = {},
          created = os.time(),
          last_seen = os.time()
        }
      end

      folders_with_uuids[#folders_with_uuids + 1] = {
        uuid = folder_uuid,
        name = folder.name,
        path = folder.path,
        full_path = folder.full_path,
        parent = folder.parent,
        color = scan_state.metadata.folders[folder_uuid] and scan_state.metadata.folders[folder_uuid].color,
      }
    end

    -- Finalize
    state.templates = scan_state.templates
    state.filtered_templates = scan_state.templates
    state.folders = build_folder_tree(folders_with_uuids)

    -- Save metadata
    Persistence.save_metadata(scan_state.metadata)

    Logger.info("SCANNER", "Scan complete: %d templates in %d folders",
      #scan_state.templates, #folders_with_uuids)

    -- Start background FX parsing
    FXQueue.add_to_queue(state, scan_state.templates)

    -- Reset scan state
    scan_state.active = false
    scan_state.files_to_scan = {}
    scan_state.files_scanned = 0
    scan_state.total_files = 0
    scan_state.metadata = nil
    scan_state.templates = {}
    scan_state.folders = {}

    return true
  end

  return false
end

return M

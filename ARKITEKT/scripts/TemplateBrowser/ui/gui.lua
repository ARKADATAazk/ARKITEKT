-- @noindex
-- TemplateBrowser/ui/gui.lua
-- Main GUI with three-panel layout

local ImGui = require 'imgui' '0.10'
local TemplateOps = require('TemplateBrowser.domain.template_ops')
local FileOps = require('TemplateBrowser.domain.file_ops')
local Tags = require('TemplateBrowser.domain.tags')
local Separator = require('TemplateBrowser.ui.separator')
local FXQueue = require('TemplateBrowser.domain.fx_queue')
local Chip = require('rearkitekt.gui.widgets.data.chip')
local Colors = require('rearkitekt.core.colors')
local TileAnim = require('rearkitekt.gui.rendering.tile.animator')
local TemplateGridFactory = require('TemplateBrowser.ui.tiles.template_grid_factory')
local TilesContainer = require('rearkitekt.gui.widgets.containers.panel')
local TemplateContainerConfig = require('TemplateBrowser.ui.template_container_config')
local Tabs = require('rearkitekt.gui.widgets.navigation.tabs')
local Button = require('rearkitekt.gui.widgets.primitives.button')
local Fields = require('rearkitekt.gui.widgets.primitives.fields')
local MarkdownField = require('rearkitekt.gui.widgets.primitives.markdown_field')
local TreeView = require('rearkitekt.gui.widgets.navigation.tree_view')
local Shortcuts = require('TemplateBrowser.core.shortcuts')
local Tooltips = require('TemplateBrowser.core.tooltips')

local M = {}
local GUI = {}
GUI.__index = GUI

-- Color preset palette for template chips
local PRESET_COLORS = {
  Colors.hexrgb("#FF0000"), -- Red
  Colors.hexrgb("#FF6000"), -- Red-Orange
  Colors.hexrgb("#FF9900"), -- Orange
  Colors.hexrgb("#FFCC00"), -- Yellow-Orange
  Colors.hexrgb("#FFFF00"), -- Yellow
  Colors.hexrgb("#CCFF00"), -- Yellow-Green
  Colors.hexrgb("#66FF00"), -- Lime
  Colors.hexrgb("#00FF00"), -- Green
  Colors.hexrgb("#00FF66"), -- Green-Cyan
  Colors.hexrgb("#00FFCC"), -- Cyan-Green
  Colors.hexrgb("#00FFFF"), -- Cyan
  Colors.hexrgb("#00CCFF"), -- Cyan-Blue
  Colors.hexrgb("#0066FF"), -- Blue
  Colors.hexrgb("#0000FF"), -- Deep Blue
  Colors.hexrgb("#6600FF"), -- Blue-Purple
  Colors.hexrgb("#CC00FF"), -- Purple
}

-- ImGui compatibility for BeginChild
-- ChildFlags_Border might not exist in all versions, so use hardcoded values
-- ChildFlags_None = 0, ChildFlags_Border = 1
local function BeginChildCompat(ctx, id, w, h, want_border, window_flags)
  local child_flags = want_border and 1 or 0
  return ImGui.BeginChild(ctx, id, w, h, child_flags, window_flags or 0)
end

function M.new(config, state, scanner)
  local self = setmetatable({
    config = config,
    state = state,
    scanner = scanner,
    initialized = false,
    separator1 = Separator.new("sep1"),
    separator2 = Separator.new("sep2"),
    template_animator = TileAnim.new(16.0),  -- Animation speed
    template_grid = nil,  -- Initialized in initialize_once
    template_container = nil,  -- Initialized in initialize_once
  }, GUI)

  return self
end

function GUI:initialize_once(ctx)
  if self.initialized then return end
  self.ctx = ctx

  -- Create template grid
  self.template_grid = TemplateGridFactory.create(
    function() return self.state.filtered_templates end,
    self.state.metadata,
    self.template_animator,
    function() return self.state.tile_width end,  -- get_tile_width
    -- on_select
    function(selected_keys)
      -- Update selected template from grid selection
      if selected_keys and #selected_keys > 0 then
        local key = selected_keys[1]
        local uuid = key:match("template_(.+)")  -- Keep as string!

        for _, tmpl in ipairs(self.state.filtered_templates) do
          if tmpl.uuid == uuid then
            self.state.selected_template = tmpl
            break
          end
        end
      else
        self.state.selected_template = nil
      end
    end,
    -- on_double_click (receives template object from factory)
    function(template)
      if template then
        -- Check if Ctrl is held for rename, otherwise apply template
        local ctrl_down = ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl)
        if ctrl_down then
          -- Start rename
          self.state.renaming_item = template
          self.state.renaming_type = "template"
          self.state.rename_buffer = template.name
        else
          -- Apply template to track
          TemplateOps.apply_to_selected_track(template.path, template.uuid, self.state)
        end
      end
    end,
    -- on_right_click (receives template and selected_keys from factory)
    function(template, selected_keys)
      if template then
        -- Set context menu template for color picker
        self.state.context_menu_template = template
      end
    end,
    -- on_star_click (receives template object from factory)
    function(template)
      if template then
        local Persistence = require('TemplateBrowser.domain.persistence')
        local favorites_id = "__FAVORITES__"

        -- Get favorites folder
        local favorites = self.state.metadata.virtual_folders[favorites_id]
        if not favorites then
          -- This should not happen due to initialization, but handle gracefully
          self.state.set_status("Favorites folder not found", "error")
          return
        end

        -- Check if template is already favorited
        local is_favorited = false
        local favorite_index = nil
        for idx, ref_uuid in ipairs(favorites.template_refs) do
          if ref_uuid == template.uuid then
            is_favorited = true
            favorite_index = idx
            break
          end
        end

        -- Toggle favorite status
        if is_favorited then
          -- Remove from favorites
          table.remove(favorites.template_refs, favorite_index)
          self.state.set_status("Removed from Favorites: " .. template.name, "success")
        else
          -- Add to favorites
          table.insert(favorites.template_refs, template.uuid)
          self.state.set_status("Added to Favorites: " .. template.name, "success")
        end

        -- Save metadata
        Persistence.save_metadata(self.state.metadata)

        -- If currently viewing Favorites folder, refresh the filter
        if self.state.selected_folder == favorites_id then
          local Scanner = require('TemplateBrowser.domain.scanner')
          Scanner.filter_templates(self.state)
        end
      end
    end
  )

  -- Create template container with header controls
  local container_config = TemplateContainerConfig.create({
    get_template_count = function()
      return #self.state.filtered_templates
    end,
    get_search_query = function()
      return self.state.search_query
    end,
    on_search_changed = function(new_query)
      self.state.search_query = new_query
      local Scanner = require('TemplateBrowser.domain.scanner')
      Scanner.filter_templates(self.state)
    end,
    get_sort_mode = function()
      return self.state.sort_mode
    end,
    on_sort_changed = function(new_mode)
      self.state.sort_mode = new_mode
      local Scanner = require('TemplateBrowser.domain.scanner')
      Scanner.filter_templates(self.state)
    end,
    get_filter_items = function()
      local items = {}

      -- Add active tag filters
      if self.state.metadata and self.state.metadata.tags then
        for tag_name, _ in pairs(self.state.filter_tags) do
          local tag_data = self.state.metadata.tags[tag_name]
          if tag_data then
            table.insert(items, {
              id = "tag:" .. tag_name,
              label = tag_name,
              color = tag_data.color,
            })
          end
        end
      end

      -- Add active FX filters
      for fx_name, _ in pairs(self.state.filter_fx) do
        table.insert(items, {
          id = "fx:" .. fx_name,
          label = fx_name,
          color = 0x888888,  -- Gray for FX
        })
      end

      return items
    end,
    on_filter_remove = function(filter_id)
      -- Parse filter ID to determine type
      local filter_type, filter_name = filter_id:match("^(%w+):(.+)$")

      if filter_type == "tag" then
        -- Remove tag filter
        self.state.filter_tags[filter_name] = nil
      elseif filter_type == "fx" then
        -- Remove FX filter
        self.state.filter_fx[filter_name] = nil
      end

      -- Re-filter templates
      local Scanner = require('TemplateBrowser.domain.scanner')
      Scanner.filter_templates(self.state)
    end,
  })

  self.template_container = TilesContainer.new({
    id = "templates_container",
    config = container_config,
  })

  self.initialized = true
end

-- Convert folder tree to TreeView format with colors from metadata
local function prepare_tree_nodes(node, metadata, all_templates)
  if not node then return {} end

  -- Convert physical folder node
  local function convert_physical_node(n)
    local tree_node = {
      id = n.path,
      name = n.name,
      path = n.path,
      full_path = n.full_path,
      children = {},
      is_virtual = false,
    }

    -- Add color from metadata if available
    if metadata and metadata.folders and metadata.folders[n.uuid] then
      tree_node.color = metadata.folders[n.uuid].color
    end

    -- Convert children recursively
    if n.children then
      for _, child in ipairs(n.children) do
        table.insert(tree_node.children, convert_physical_node(child))
      end
    end

    return tree_node
  end

  -- Build tree from virtual folders
  local function build_virtual_tree(parent_id)
    local virtual_children = {}

    if not metadata or not metadata.virtual_folders then
      return virtual_children
    end

    for _, vfolder in pairs(metadata.virtual_folders) do
      if vfolder.parent_id == parent_id then
        local vnode = {
          id = vfolder.id,
          name = vfolder.name,
          path = vfolder.id,  -- Use ID as path for virtual folders
          is_virtual = true,
          template_refs = vfolder.template_refs or {},
          color = vfolder.color,
          children = build_virtual_tree(vfolder.id),  -- Recursively add virtual children
        }
        table.insert(virtual_children, vnode)
      end
    end

    return virtual_children
  end

  local root_nodes = {}

  -- Add Physical Root node
  local template_path = reaper.GetResourcePath() .. package.config:sub(1,1) .. "TrackTemplates"
  local physical_root = {
    id = "__ROOT__",  -- Unique ID for ImGui (must not be empty)
    name = "Physical Root",
    path = "",  -- Relative path is empty (represents TrackTemplates root)
    full_path = template_path,
    children = {},
    is_root = true,  -- Flag to identify root node
    is_virtual = false,
  }

  -- Add all physical folders as children of Physical Root
  if node.children then
    for _, child in ipairs(node.children) do
      table.insert(physical_root.children, convert_physical_node(child))
    end
  end

  table.insert(root_nodes, physical_root)

  -- Add Virtual Root node (separate from physical)
  local virtual_root = {
    id = "__VIRTUAL_ROOT__",
    name = "Virtual Root",
    path = "__VIRTUAL_ROOT__",
    children = build_virtual_tree("__VIRTUAL_ROOT__"),  -- All virtual folders go here
    is_root = true,
    is_virtual = true,
  }

  table.insert(root_nodes, virtual_root)

  return root_nodes
end

-- Helper functions removed - now using Chip component directly

-- Draw folder tree using TreeView widget
local function draw_folder_tree(ctx, state, config)
  -- Prepare tree nodes from state.folders
  local tree_nodes = prepare_tree_nodes(state.folders, state.metadata, state.templates)

  if #tree_nodes == 0 then
    return
  end

  -- Ensure ROOT nodes are open by default
  if state.folder_open_state["__ROOT__"] == nil then
    state.folder_open_state["__ROOT__"] = true
  end
  if state.folder_open_state["__VIRTUAL_ROOT__"] == nil then
    state.folder_open_state["__VIRTUAL_ROOT__"] = true
  end

  -- Map state variables to TreeView format
  local tree_state = {
    open_nodes = state.folder_open_state,  -- TreeView uses open_nodes
    selected_nodes = state.selected_folders,  -- Multi-select mode
    last_clicked_node = state.last_clicked_folder,  -- Last clicked for shift-range selection
    renaming_node = state.renaming_folder_path or nil,  -- Track renaming by path
    rename_buffer = state.rename_buffer or "",
  }

  -- Draw tree with callbacks
  TreeView.draw(ctx, tree_nodes, tree_state, {
    enable_rename = true,
    show_colors = true,
    enable_drag_drop = true,  -- Enable folder drag-and-drop
    enable_multi_select = true,  -- Enable multi-select with Ctrl/Shift
    context_menu_id = "folder_context_menu",  -- Enable context menu

    -- Check if node can be renamed (prevent renaming system folders)
    can_rename = function(node)
      if node.is_virtual then
        local vfolder = state.metadata.virtual_folders and state.metadata.virtual_folders[node.id]
        if vfolder and vfolder.is_system then
          return false  -- System folders cannot be renamed
        end
      end
      return true  -- All other nodes can be renamed
    end,

    -- Selection callback
    on_select = function(node, selected_nodes)
      -- Update state with selected folders
      state.selected_folders = selected_nodes

      -- For backward compatibility, set selected_folder to the clicked node
      state.selected_folder = node.path

      local Scanner = require('TemplateBrowser.domain.scanner')
      Scanner.filter_templates(state)
    end,

    -- Folder drop callback (supports multi-drag)
    on_drop_folder = function(dragged_node_id, target_node)
      -- Find the source node
      local function find_node_by_id(nodes, id)
        for _, n in ipairs(nodes) do
          if n.id == id then return n end
          if n.children then
            local found = find_node_by_id(n.children, id)
            if found then return found end
          end
        end
        return nil
      end

      -- Check if target is a descendant of source
      local function is_descendant(parent_node, potential_child_id)
        if not parent_node.children then return false end
        for _, child in ipairs(parent_node.children) do
          if child.id == potential_child_id then return true end
          if is_descendant(child, potential_child_id) then return true end
        end
        return false
      end

      -- Check if payload contains multiple IDs (newline-separated)
      local dragged_ids = {}
      if dragged_node_id:find("\n") then
        -- Multi-drag: split by newline
        for id in dragged_node_id:gmatch("[^\n]+") do
          table.insert(dragged_ids, id)
        end
      else
        -- Single drag
        table.insert(dragged_ids, dragged_node_id)
      end

      -- Validate all folders before moving any
      local folders_to_move = {}
      for _, id in ipairs(dragged_ids) do
        local source_node = find_node_by_id(tree_nodes, id)
        if not source_node or not target_node then
          state.set_status("Error: Cannot find source or target folder", "error")
          return
        end

        -- Don't allow dropping onto self
        if source_node.id == target_node.id then
          state.set_status("Cannot move folder into itself", "error")
          return
        end

        -- Don't allow dropping into own descendants (circular reference)
        if is_descendant(source_node, target_node.id) then
          state.set_status("Cannot move folder into its own subfolder", "error")
          return
        end

        table.insert(folders_to_move, source_node)
      end

      -- Prepare move operations for all folders
      local move_operations = {}
      local target_full_path = target_node.full_path
      local target_name = target_node.name
      local target_normalized = target_full_path:gsub("[/\\]+$", "")

      for _, source_node in ipairs(folders_to_move) do
        local source_full_path = source_node.full_path
        local source_name = source_node.name
        local source_normalized = source_full_path:gsub("[/\\]+$", "")

        -- Extract old parent directory
        local old_parent = source_normalized:match("^(.+)[/\\][^/\\]+$")
        if not old_parent then
          state.set_status("Cannot determine parent folder for: " .. source_name, "error")
          return
        end

        table.insert(move_operations, {
          source_normalized = source_normalized,
          source_name = source_name,
          old_parent = old_parent,
          new_path = nil  -- Will be set after move
        })
      end

      -- Execute all moves
      local all_success = true
      for _, op in ipairs(move_operations) do
        local success, new_path = FileOps.move_folder(op.source_normalized, target_normalized)
        if success then
          op.new_path = new_path
        else
          all_success = false
          state.set_status("Failed to move folder: " .. op.source_name, "error")
          break
        end
      end

      if all_success then
        -- Create batch undo operation
        local description = #folders_to_move > 1
          and ("Move " .. #folders_to_move .. " folders -> " .. target_name)
          or ("Move folder: " .. move_operations[1].source_name .. " -> " .. target_name)

        state.undo_manager:push({
          description = description,
          undo_fn = function()
            local undo_success = true
            -- Undo in reverse order
            for i = #move_operations, 1, -1 do
              local op = move_operations[i]
              if not FileOps.move_folder(op.new_path, op.old_parent) then
                undo_success = false
                break
              end
            end
            if undo_success then
              local Scanner = require('TemplateBrowser.domain.scanner')
              Scanner.scan_templates(state)
            end
            return undo_success
          end,
          redo_fn = function()
            local redo_success = true
            for _, op in ipairs(move_operations) do
              local sep = package.config:sub(1,1)
              local original_source = op.old_parent .. sep .. op.source_name
              local success, new_path = FileOps.move_folder(original_source, target_normalized)
              if success then
                op.new_path = new_path
              else
                redo_success = false
                break
              end
            end
            if redo_success then
              local Scanner = require('TemplateBrowser.domain.scanner')
              Scanner.scan_templates(state)
            end
            return redo_success
          end
        })

        -- Rescan templates
        local Scanner = require('TemplateBrowser.domain.scanner')
        Scanner.scan_templates(state)

        -- Success message
        local count = #folders_to_move
        if count > 1 then
          state.set_status("Successfully moved " .. count .. " folders to " .. target_name, "success")
        else
          state.set_status("Successfully moved " .. folders_to_move[1].name .. " to " .. target_name, "success")
        end
      end
    end,

    -- Template drop callback (supports multi-drag)
    on_drop_template = function(template_payload, target_node)
      if not target_node then return end

      -- Parse payload (can be single UUID or newline-separated UUIDs)
      local uuids = {}
      if template_payload:find("\n") then
        -- Multi-template drag
        for uuid in template_payload:gmatch("[^\n]+") do
          table.insert(uuids, uuid)
        end
      else
        -- Single template
        table.insert(uuids, template_payload)
      end

      if #uuids == 0 then return end

      -- Handle virtual folder (add references, don't move files)
      if target_node.is_virtual then
        local Persistence = require('TemplateBrowser.domain.persistence')

        -- Get the virtual folder from metadata
        local vfolder = state.metadata.virtual_folders[target_node.id]
        if not vfolder then
          state.set_status("Virtual folder not found", "error")
          return
        end

        -- Ensure template_refs exists
        if not vfolder.template_refs then
          vfolder.template_refs = {}
        end

        -- Add new UUIDs (avoid duplicates)
        local added_count = 0
        for _, uuid in ipairs(uuids) do
          -- Check if already exists
          local already_exists = false
          for _, existing_uuid in ipairs(vfolder.template_refs) do
            if existing_uuid == uuid then
              already_exists = true
              break
            end
          end

          if not already_exists then
            table.insert(vfolder.template_refs, uuid)
            added_count = added_count + 1
          end
        end

        -- Save metadata
        Persistence.save_metadata(state.metadata)

        -- Success message
        if added_count > 0 then
          if #uuids > 1 then
            state.set_status("Added " .. added_count .. " of " .. #uuids .. " templates to " .. target_node.name, "success")
          else
            state.set_status("Added template to " .. target_node.name, "success")
          end
        else
          if #uuids > 1 then
            state.set_status("Templates already in " .. target_node.name, "info")
          else
            state.set_status("Template already in " .. target_node.name, "info")
          end
        end

        return
      end

      -- Handle physical folder (move files)
      local templates_to_move = {}
      for _, uuid in ipairs(uuids) do
        for _, tmpl in ipairs(state.templates) do
          if tmpl.uuid == uuid then
            table.insert(templates_to_move, tmpl)
            break
          end
        end
      end

      if #templates_to_move == 0 then return end

      -- Check for conflicts (only for physical folders)
      local has_conflict = false
      if not target_node.is_virtual then
        for _, tmpl in ipairs(templates_to_move) do
          local conflict_exists = FileOps.check_template_conflict(tmpl.name, target_node.full_path)
          if conflict_exists then
            has_conflict = true
            break
          end
        end
      end

      -- If conflict detected, set up pending conflict and show modal
      if has_conflict then
        state.conflict_pending = {
          templates = templates_to_move,
          target_folder = target_node,
          operation = "move"
        }
        return  -- Wait for user decision in modal (processed in main draw loop)
      end

      -- Move all templates (no conflict or virtual folder - virtual folders can have duplicates)
      local success_count = 0
      local total_count = #templates_to_move

      for _, tmpl in ipairs(templates_to_move) do
        local success, new_path, conflict_detected = FileOps.move_template(tmpl.path, target_node.full_path, nil)
        if success then
          success_count = success_count + 1
        else
          state.set_status("Failed to move template: " .. tmpl.name, "error")
        end
      end

      -- Rescan if any succeeded
      if success_count > 0 then
        local Scanner = require('TemplateBrowser.domain.scanner')
        Scanner.scan_templates(state)

        -- Success message
        if total_count > 1 then
          state.set_status("Moved " .. success_count .. " of " .. total_count .. " templates to " .. target_node.name, "success")
        else
          state.set_status("Moved " .. templates_to_move[1].name .. " to " .. target_node.name, "success")
        end
      end
    end,

    -- Right-click callback (sets state for context menu)
    on_right_click = function(node)
      state.context_menu_node = node
    end,

    -- Context menu renderer (called inline by TreeView)
    render_context_menu = function(ctx_inner, node)
      local ContextMenu = require('rearkitekt.gui.widgets.overlays.context_menu')
      local Colors = require('rearkitekt.core.colors')

      if ContextMenu.begin(ctx_inner, "folder_context_menu") then
        -- Predefined color palette
        local color_options = {
          { name = "None", color = nil },
          { name = "Red", color = Colors.hexrgb("#FF6B6BFF") },
          { name = "Orange", color = Colors.hexrgb("#FFA500FF") },
          { name = "Yellow", color = Colors.hexrgb("#FFD93DFF") },
          { name = "Green", color = Colors.hexrgb("#6BCF7FFF") },
          { name = "Blue", color = Colors.hexrgb("#4A9EFFFF") },
          { name = "Purple", color = Colors.hexrgb("#B57FFFFF") },
          { name = "Pink", color = Colors.hexrgb("#FF69B4FF") },
        }

        for _, color_opt in ipairs(color_options) do
          if ContextMenu.item(ctx_inner, color_opt.name) then
            local Persistence = require('TemplateBrowser.domain.persistence')

            if node.is_virtual then
              -- Update virtual folder color
              if state.metadata.virtual_folders and state.metadata.virtual_folders[node.id] then
                state.metadata.virtual_folders[node.id].color = color_opt.color
                Persistence.save_metadata(state.metadata)

                -- No need to rescan, just update UI
                local Scanner = require('TemplateBrowser.domain.scanner')
                Scanner.scan_templates(state)
              end
            else
              -- Update physical folder color in metadata
              if not state.metadata.folders then
                state.metadata.folders = {}
              end

              -- Find or create folder metadata entry
              local folder_uuid = nil
              for uuid, folder in pairs(state.metadata.folders) do
                if folder.path == node.path then
                  folder_uuid = uuid
                  break
                end
              end

              if not folder_uuid then
                -- Create new metadata entry
                folder_uuid = reaper.genGuid("")
                state.metadata.folders[folder_uuid] = {
                  path = node.path,
                  name = node.name,
                }
              end

              -- Set color
              state.metadata.folders[folder_uuid].color = color_opt.color

              -- Save metadata
              Persistence.save_metadata(state.metadata)

              -- Rescan to update UI
              local Scanner = require('TemplateBrowser.domain.scanner')
              Scanner.scan_templates(state)
            end

            ImGui.CloseCurrentPopup(ctx_inner)
          end
        end

        -- Add separator and delete option for virtual folders (except system folders)
        if node.is_virtual then
          local vfolder = state.metadata.virtual_folders and state.metadata.virtual_folders[node.id]
          local is_system_folder = vfolder and vfolder.is_system

          if not is_system_folder then
            ContextMenu.separator(ctx_inner)

            if ContextMenu.item(ctx_inner, "Delete Virtual Folder") then
              local Persistence = require('TemplateBrowser.domain.persistence')

              -- Remove from metadata
              if state.metadata.virtual_folders and state.metadata.virtual_folders[node.id] then
                state.metadata.virtual_folders[node.id] = nil
                Persistence.save_metadata(state.metadata)

                -- Clear selection if this folder was selected
                if state.selected_folder == node.id then
                  state.selected_folder = ""
                  state.selected_folders = {}
                end

                -- Refresh UI (no need to rescan templates, just rebuild tree)
                local Scanner = require('TemplateBrowser.domain.scanner')
                Scanner.filter_templates(state)

                state.set_status("Deleted virtual folder: " .. node.name, "success")
              end

              ImGui.CloseCurrentPopup(ctx_inner)
            end
          end
        end

        ContextMenu.end_menu(ctx_inner)
      end
    end,

    -- Rename callback
    on_rename = function(node, new_name)
      if new_name ~= "" and new_name ~= node.name then
        local Persistence = require('TemplateBrowser.domain.persistence')

        -- Handle virtual folder rename (metadata only, no file operations)
        if node.is_virtual then
          if state.metadata.virtual_folders and state.metadata.virtual_folders[node.id] then
            -- Prevent renaming system folders
            local vfolder = state.metadata.virtual_folders[node.id]
            if vfolder.is_system then
              state.set_status("Cannot rename system folder: " .. node.name, "error")
              return false
            end

            state.metadata.virtual_folders[node.id].name = new_name
            Persistence.save_metadata(state.metadata)
            state.set_status("Renamed virtual folder to: " .. new_name, "success")
          end
          return
        end

        -- Handle physical folder rename (file operations + metadata update)
        local old_path = node.full_path
        local old_relative_path = node.path  -- e.g., "OldFolder" or "Parent/OldFolder"

        local success, new_path = FileOps.rename_folder(old_path, new_name)
        if success then
          -- Calculate new relative path
          local parent_path = old_relative_path:match("^(.+)[/\\][^/\\]+$")
          local new_relative_path = parent_path and (parent_path .. "/" .. new_name) or new_name

          -- Update metadata paths for this folder and all templates in it
          -- Update folder metadata
          if state.metadata and state.metadata.folders then
            for uuid, folder in pairs(state.metadata.folders) do
              if folder.path == old_relative_path then
                folder.name = new_name
                folder.path = new_relative_path
              elseif folder.path:find("^" .. old_relative_path:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1") .. "[/\\]") then
                -- Update subfolders
                folder.path = folder.path:gsub("^" .. old_relative_path:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"), new_relative_path)
              end
            end
          end

          -- Update template metadata paths (without re-parsing!)
          if state.metadata and state.metadata.templates then
            for uuid, tmpl in pairs(state.metadata.templates) do
              local tmpl_path = tmpl.folder or ""
              if tmpl_path == old_relative_path then
                tmpl.folder = new_relative_path
              elseif tmpl_path:find("^" .. old_relative_path:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1") .. "[/\\]") then
                tmpl.folder = tmpl_path:gsub("^" .. old_relative_path:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"), new_relative_path)
              end
            end
          end

          -- Save updated metadata
          Persistence.save_metadata(state.metadata)

          -- Create undo operation
          state.undo_manager:push({
            description = "Rename folder: " .. node.name .. " -> " .. new_name,
            undo_fn = function()
              local undo_success = FileOps.rename_folder(new_path, node.name)
              if undo_success then
                local Scanner = require('TemplateBrowser.domain.scanner')
                Scanner.scan_templates(state)
              end
              return undo_success
            end,
            redo_fn = function()
              local redo_success = FileOps.rename_folder(old_path, new_name)
              if redo_success then
                local Scanner = require('TemplateBrowser.domain.scanner')
                Scanner.scan_templates(state)
              end
              return redo_success
            end
          })

          -- Light rescan: just rebuild folder tree and template list from updated metadata
          local Scanner = require('TemplateBrowser.domain.scanner')
          Scanner.scan_templates(state)
        end
      end
    end,
  })

  -- Sync TreeView state back to Template Browser state
  state.selected_folders = tree_state.selected_nodes
  state.last_clicked_folder = tree_state.last_clicked_node
  state.renaming_folder_path = tree_state.renaming_node
  state.rename_buffer = tree_state.rename_buffer
end

-- Tags list for bottom of directory tab (with filtering)
local function draw_tags_mini_list(ctx, state, config, width, height)
  BeginChildCompat(ctx, "DirectoryTags", width, height, true)

  -- Header with "+" button
  local button_w = 24
  local tag_header_height = 28

  ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.header_bg)
  ImGui.Text(ctx, "Tags")
  ImGui.SameLine(ctx, width - button_w - 8)

  if Button.draw_at_cursor(ctx, { label = "+", width = button_w, height = 24 }, "createtag_dir") then
    -- Create new tag - prompt for name
    local tag_num = 1
    local new_tag_name = "Tag " .. tag_num

    -- Find unique name
    if state.metadata and state.metadata.tags then
      while state.metadata.tags[new_tag_name] do
        tag_num = tag_num + 1
        new_tag_name = "Tag " .. tag_num
      end
    end

    -- Create tag with random color
    local r = math.random(50, 255) / 255.0
    local g = math.random(50, 255) / 255.0
    local b = math.random(50, 255) / 255.0
    local color = (math.floor(r * 255) << 16) | (math.floor(g * 255) << 8) | math.floor(b * 255)

    Tags.create_tag(state.metadata, new_tag_name, color)

    -- Save metadata
    local Persistence = require('TemplateBrowser.domain.persistence')
    Persistence.save_metadata(state.metadata)
  end

  ImGui.PopStyleColor(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Calculate remaining height for tags list
  local tags_list_height = height - tag_header_height - 10  -- Account for header + separator/spacing

  -- List all tags with filtering (scrollable)
  BeginChildCompat(ctx, "DirectoryTagsList", 0, tags_list_height, false)

  if state.metadata and state.metadata.tags then
    for tag_name, tag_data in pairs(state.metadata.tags) do
      ImGui.PushID(ctx, tag_name)

      local is_selected = state.filter_tags[tag_name] or false

      -- Draw tag using Chip component (PILL style)
      local clicked, chip_w, chip_h = Chip.draw(ctx, {
        style = Chip.STYLE.PILL,
        label = tag_name,
        color = tag_data.color,
        height = 24,
        is_selected = is_selected,
        interactive = true,
      })

      if clicked then
        -- Toggle tag filter
        if is_selected then
          state.filter_tags[tag_name] = nil
        else
          state.filter_tags[tag_name] = true
        end

        -- Re-filter templates
        local Scanner = require('TemplateBrowser.domain.scanner')
        Scanner.filter_templates(state)
      end

      ImGui.PopID(ctx)
    end
  else
    ImGui.TextDisabled(ctx, "No tags yet")
  end

  ImGui.EndChild(ctx)
  ImGui.EndChild(ctx)
end

-- Draw directory content (folder tree + tags at bottom)
local function draw_directory_content(ctx, state, config, width, height)
  -- Split into folder tree (top 70%) and tags (bottom 30%)
  local folder_section_height = height * 0.7
  local tags_section_height = height * 0.3 - 4

  -- === FOLDER SECTION ===
  -- Header with folder creation buttons
  local button_w = 24
  local button_spacing = 4
  local header_height = 28

  ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.header_bg)
  ImGui.Text(ctx, "Explorer")
  ImGui.SameLine(ctx, width - (button_w * 2 + button_spacing) - config.PANEL_PADDING * 2)

  -- Physical folder button
  if Button.draw_at_cursor(ctx, { label = "+", width = button_w, height = 24 }, "folder_physical") then
    -- Create new folder inside selected folder (or root if nothing selected)
    local template_path = reaper.GetResourcePath() .. package.config:sub(1,1) .. "TrackTemplates"
    local parent_path = template_path
    local parent_relative_path = ""

    -- Determine parent folder from selection
    if state.selected_folders and next(state.selected_folders) then
      -- Get first selected folder as parent
      for folder_path, _ in pairs(state.selected_folders) do
        -- Handle ROOT node: "__ROOT__" ID maps to "" path
        if folder_path == "__ROOT__" then
          parent_relative_path = ""
          parent_path = template_path
        else
          parent_relative_path = folder_path
          parent_path = template_path .. package.config:sub(1,1) .. folder_path
        end
        break  -- Use first selected
      end
    elseif state.selected_folder and state.selected_folder ~= "" and state.selected_folder ~= "__ROOT__" then
      parent_relative_path = state.selected_folder
      parent_path = template_path .. package.config:sub(1,1) .. state.selected_folder
    end

    local folder_num = 1
    local new_folder_name = "New Folder"

    -- Find unique name by checking existing folders in the scanned folder tree
    local function folder_exists_in_parent(parent_rel_path, name)
      -- Navigate to parent folder in the tree
      local function find_children_at_path(node, path)
        if not path or path == "" then
          -- Root level
          return node.children or {}
        end

        -- Navigate to the target path
        local parts = {}
        for part in path:gmatch("[^"..package.config:sub(1,1).."]+") do
          table.insert(parts, part)
        end

        local current = node
        for _, part in ipairs(parts) do
          if not current.children then return {} end
          local found = false
          for _, child in ipairs(current.children) do
            if child.name == part then
              current = child
              found = true
              break
            end
          end
          if not found then return {} end
        end

        return current.children or {}
      end

      local siblings = find_children_at_path(state.folders or {}, parent_rel_path)
      for _, sibling in ipairs(siblings) do
        if sibling.name == name then
          return true
        end
      end
      return false
    end

    while folder_exists_in_parent(parent_relative_path, new_folder_name) do
      folder_num = folder_num + 1
      new_folder_name = "New Folder " .. folder_num
    end

    local success, new_path = FileOps.create_folder(parent_path, new_folder_name)
    if success then
      local Scanner = require('TemplateBrowser.domain.scanner')
      Scanner.scan_templates(state)

      -- Select the newly created folder
      local sep = package.config:sub(1,1)
      local new_relative_path = parent_relative_path
      if new_relative_path ~= "" then
        new_relative_path = new_relative_path .. sep .. new_folder_name
      else
        new_relative_path = new_folder_name
      end

      -- Select the new folder
      state.selected_folders = {}
      state.selected_folders[new_relative_path] = true
      state.selected_folder = new_relative_path
      state.last_clicked_folder = new_relative_path

      -- Open parent folder to show the new folder
      if parent_relative_path ~= "" then
        state.folder_open_state[parent_relative_path] = true
      end
      state.folder_open_state["__ROOT__"] = true  -- Open ROOT

      -- Show status message
      state.set_status("Created folder: " .. new_folder_name, "success")
    else
      state.set_status("Failed to create folder", "error")
    end
  end

  -- Virtual folder button
  ImGui.SameLine(ctx, 0, button_spacing)
  if Button.draw_at_cursor(ctx, { label = "V", width = button_w, height = 24 }, "folder_virtual") then
    -- Create new virtual folder
    local Persistence = require('TemplateBrowser.domain.persistence')

    -- Determine parent folder from selection (only virtual folders/root)
    local parent_id = "__VIRTUAL_ROOT__"  -- Default to virtual root
    if state.selected_folders and next(state.selected_folders) then
      for folder_id, _ in pairs(state.selected_folders) do
        -- Only use as parent if it's a virtual folder
        local is_virtual = state.metadata.virtual_folders and state.metadata.virtual_folders[folder_id]
        if is_virtual or folder_id == "__VIRTUAL_ROOT__" then
          parent_id = folder_id
          break  -- Use first selected virtual folder
        end
      end
    elseif state.selected_folder then
      local is_virtual = state.metadata.virtual_folders and state.metadata.virtual_folders[state.selected_folder]
      if is_virtual or state.selected_folder == "__VIRTUAL_ROOT__" then
        parent_id = state.selected_folder
      end
    end

    -- Find unique name for the virtual folder
    local folder_num = 1
    local new_folder_name = "New Virtual Folder"

    local function virtual_folder_name_exists(name)
      if not state.metadata or not state.metadata.virtual_folders then
        return false
      end

      -- Check if any virtual folder with same parent has this name
      for _, vfolder in pairs(state.metadata.virtual_folders) do
        if vfolder.parent_id == parent_id and vfolder.name == name then
          return true
        end
      end
      return false
    end

    while virtual_folder_name_exists(new_folder_name) do
      folder_num = folder_num + 1
      new_folder_name = "New Virtual Folder " .. folder_num
    end

    -- Create the virtual folder in metadata
    local new_id = Persistence.generate_uuid()
    if not state.metadata.virtual_folders then
      state.metadata.virtual_folders = {}
    end

    state.metadata.virtual_folders[new_id] = {
      id = new_id,
      name = new_folder_name,
      parent_id = parent_id,
      template_refs = {},
      created = os.time()
    }

    -- Save metadata
    Persistence.save_metadata(state.metadata)

    -- Select the newly created virtual folder
    state.selected_folders = {}
    state.selected_folders[new_id] = true
    state.selected_folder = new_id
    state.last_clicked_folder = new_id

    -- Open parent folder to show the new virtual folder
    if parent_id ~= "__VIRTUAL_ROOT__" then
      state.folder_open_state[parent_id] = true
    end
    state.folder_open_state["__VIRTUAL_ROOT__"] = true  -- Open Virtual Root

    state.set_status("Created virtual folder: " .. new_folder_name, "success")
  end

  ImGui.PopStyleColor(ctx)

  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- "All Templates" option
  local is_all_selected = (state.selected_folder == nil or state.selected_folder == "")
  if is_all_selected then
    ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.selected_bg)
  end

  if ImGui.Selectable(ctx, "All Templates", is_all_selected) then
    state.selected_folder = ""
    local Scanner = require('TemplateBrowser.domain.scanner')
    Scanner.filter_templates(state)
  end

  if is_all_selected then
    ImGui.PopStyleColor(ctx)
  end

  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Calculate remaining height for folder tree (scrollable)
  -- Account for: header (28) + separator/spacing (10) + All Templates (24) + separator/spacing (10)
  local used_height = header_height + 10 + 24 + 10
  local tree_height = folder_section_height - used_height

  -- Folder tree in scrollable child
  BeginChildCompat(ctx, "FolderTreeScroll", 0, tree_height, false)
  draw_folder_tree(ctx, state, config)
  ImGui.EndChild(ctx)

  ImGui.Spacing(ctx)

  -- === TAGS SECTION ===
  draw_tags_mini_list(ctx, state, config, width, tags_section_height)
end

-- Draw VSTS content (list of all FX with filtering)
local function draw_vsts_content(ctx, state, config, width, height)
  -- Get all FX from templates
  local FXParser = require('TemplateBrowser.domain.fx_parser')
  local all_fx = FXParser.get_all_fx(state.templates)

  -- Header with VST count and Force Reparse button
  ImGui.Text(ctx, string.format("%d VST%s found", #all_fx, #all_fx == 1 and "" or "s"))

  ImGui.SameLine(ctx, width - 120 - config.PANEL_PADDING * 2)

  -- Force Reparse button (two-click confirmation)
  local button_label = "Force Reparse All"
  local button_config = { label = button_label, width = 120, height = 24 }

  if state.reparse_armed then
    button_label = "CONFIRM REPARSE?"
    button_config = {
      label = button_label,
      width = 120,
      height = 24,
      bg_color = Colors.hexrgb("#CC3333")
    }
  end

  if Button.draw_at_cursor(ctx, button_config, "force_reparse") then
    if state.reparse_armed then
      -- Second click - execute reparse
      reaper.ShowConsoleMsg("Force reparsing all templates...\n")

      -- Clear file_size from all templates in metadata to force re-parse
      if state.metadata and state.metadata.templates then
        for uuid, tmpl in pairs(state.metadata.templates) do
          tmpl.file_size = nil
        end
      end

      -- Save metadata and trigger rescan
      local Persistence = require('TemplateBrowser.domain.persistence')
      Persistence.save_metadata(state.metadata)

      -- Trigger rescan which will re-parse everything
      local Scanner = require('TemplateBrowser.domain.scanner')
      Scanner.scan_templates(state)

      state.reparse_armed = false
    else
      -- First click - arm the button
      state.reparse_armed = true
    end
  end

  -- Auto-disarm after hovering away
  if state.reparse_armed and not ImGui.IsItemHovered(ctx) then
    state.reparse_armed = false
  end

  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  BeginChildCompat(ctx, "VSTsList", width - config.PANEL_PADDING * 2, height - 60, false)

  for _, fx_name in ipairs(all_fx) do
    ImGui.PushID(ctx, fx_name)

    local is_selected = state.filter_fx[fx_name] or false

    -- Draw VST using Chip component (DOT style, blue like in template tiles)
    local vst_color = Colors.hexrgb("#4A9EFF")
    local clicked, chip_w, chip_h = Chip.draw(ctx, {
      style = Chip.STYLE.DOT,
      label = fx_name,
      color = vst_color,
      height = 28,
      dot_size = 8,
      dot_spacing = 10,
      is_selected = is_selected,
      interactive = true,
    })

    if clicked then
      -- Toggle FX filter
      if is_selected then
        state.filter_fx[fx_name] = nil
      else
        state.filter_fx[fx_name] = true
      end

      -- Re-filter templates
      local Scanner = require('TemplateBrowser.domain.scanner')
      Scanner.filter_templates(state)
    end

    ImGui.PopID(ctx)
  end

  ImGui.EndChild(ctx)
end

-- Draw TAGS content (full tag management)
local function draw_tags_content(ctx, state, config, width, height)
  -- Header with "+" button
  local header_text = "Tags"
  local button_w = 24

  ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.header_bg)
  ImGui.Text(ctx, header_text)
  ImGui.SameLine(ctx, width - button_w - config.PANEL_PADDING * 2)

  if Button.draw_at_cursor(ctx, { label = "+", width = button_w, height = 24 }, "createtag") then
    -- Create new tag - prompt for name
    local tag_num = 1
    local new_tag_name = "Tag " .. tag_num

    -- Find unique name
    if state.metadata and state.metadata.tags then
      while state.metadata.tags[new_tag_name] do
        tag_num = tag_num + 1
        new_tag_name = "Tag " .. tag_num
      end
    end

    -- Create tag with random color
    local r = math.random(50, 255) / 255.0
    local g = math.random(50, 255) / 255.0
    local b = math.random(50, 255) / 255.0
    local color = (math.floor(r * 255) << 16) | (math.floor(g * 255) << 8) | math.floor(b * 255)

    Tags.create_tag(state.metadata, new_tag_name, color)

    -- Save metadata
    local Persistence = require('TemplateBrowser.domain.persistence')
    Persistence.save_metadata(state.metadata)
  end

  ImGui.PopStyleColor(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- List all tags
  BeginChildCompat(ctx, "TagsList", width - config.PANEL_PADDING * 2, height - 30, false)

  if state.metadata and state.metadata.tags then
    for tag_name, tag_data in pairs(state.metadata.tags) do
      local is_renaming = (state.renaming_item == tag_name and state.renaming_type == "tag")

      ImGui.PushID(ctx, tag_name)

      if is_renaming then
        -- Rename mode
        -- Initialize field with current name
        if Fields.get_text("tag_rename_" .. tag_name) == "" then
          Fields.set_text("tag_rename_" .. tag_name, state.rename_buffer)
        end

        local changed, new_name = Fields.draw_at_cursor(ctx, {
          width = -1,
          height = 20,
          text = state.rename_buffer,
        }, "tag_rename_" .. tag_name)

        if changed then
          state.rename_buffer = new_name
        end

        -- Commit on Enter or deactivate
        if ImGui.IsItemDeactivatedAfterEdit(ctx) or ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
          if state.rename_buffer ~= "" and state.rename_buffer ~= tag_name then
            -- Rename tag
            Tags.rename_tag(state.metadata, tag_name, state.rename_buffer)
            local Persistence = require('TemplateBrowser.domain.persistence')
            Persistence.save_metadata(state.metadata)
          end
          state.renaming_item = nil
          state.renaming_type = nil
          state.rename_buffer = ""
        end

        -- Cancel on Escape
        if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
          state.renaming_item = nil
          state.renaming_type = nil
          state.rename_buffer = ""
        end
      else
        -- Normal display - draw tag using Chip component (PILL style)
        local clicked, chip_w, chip_h = Chip.draw(ctx, {
          style = Chip.STYLE.PILL,
          label = tag_name,
          color = tag_data.color,
          height = 24,
          is_selected = false,
          interactive = true,
        })

        -- Double-click to rename
        if ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
          state.renaming_item = tag_name
          state.renaming_type = "tag"
          state.rename_buffer = tag_name
        end
      end

      ImGui.PopID(ctx)
    end
  else
    ImGui.TextDisabled(ctx, "No tags yet")
  end

  ImGui.EndChild(ctx)
end

-- Draw tabbed left panel (DIRECTORY / VSTS / TAGS)
local function draw_left_panel(ctx, state, config, width, height)
  BeginChildCompat(ctx, "LeftPanel", width, height, true)

  -- Count active filters for badges
  local fx_filter_count = 0
  for _ in pairs(state.filter_fx) do
    fx_filter_count = fx_filter_count + 1
  end

  local tag_filter_count = 0
  for _ in pairs(state.filter_tags) do
    tag_filter_count = tag_filter_count + 1
  end

  -- Draw tabs using rearkitekt Tabs widget
  local tabs_def = {
    { id = "directory", label = "DIRECTORY" },
    { id = "vsts", label = "VSTS" },
    { id = "tags", label = "TAGS" },
  }

  local clicked_tab = Tabs.draw_at_cursor(ctx, tabs_def, state.left_panel_tab, {
    height = 24,
    available_width = width,
    bg_color = config.COLORS.header_bg,
    active_color = config.COLORS.selected_bg,
    text_color = config.COLORS.text,
  })

  if clicked_tab then
    state.left_panel_tab = clicked_tab
  end
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Draw content based on active tab
  local content_height = height - 35  -- Account for tab bar

  if state.left_panel_tab == "directory" then
    draw_directory_content(ctx, state, config, width, content_height)
  elseif state.left_panel_tab == "vsts" then
    draw_vsts_content(ctx, state, config, width, content_height)
  elseif state.left_panel_tab == "tags" then
    draw_tags_content(ctx, state, config, width, content_height)
  end

  ImGui.EndChild(ctx)
end

-- Get recent templates (up to max_count)
local function get_recent_templates(state, max_count)
  max_count = max_count or 10

  local recent = {}

  -- Collect templates with last_used timestamp
  for _, tmpl in ipairs(state.templates) do
    local metadata = state.metadata and state.metadata.templates[tmpl.uuid]
    if metadata and metadata.last_used then
      table.insert(recent, {
        template = tmpl,
        last_used = metadata.last_used,
      })
    end
  end

  -- Sort by last_used (most recent first)
  table.sort(recent, function(a, b)
    return a.last_used > b.last_used
  end)

  -- Extract just the templates
  local result = {}
  for i = 1, math.min(max_count, #recent) do
    table.insert(result, recent[i].template)
  end

  return result
end

-- Draw recent templates horizontal row
local function draw_recent_templates(ctx, gui, width, available_height)
  local state = gui.state
  local recent_templates = get_recent_templates(state, 10)

  if #recent_templates == 0 then
    return 0  -- No height consumed
  end

  local section_height = 120  -- Height for recent templates section
  local tile_height = 80
  local tile_width = 140
  local tile_gap = 8
  local header_height = 24
  local padding = 8

  -- Draw section header
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, Colors.hexrgb("#B3B3B3"))
  ImGui.Text(ctx, "Recent Templates")
  ImGui.PopStyleColor(ctx)
  ImGui.Spacing(ctx)

  -- Scroll area for horizontal tiles
  local scroll_height = tile_height + padding * 2
  BeginChildCompat(ctx, "RecentTemplatesScroll", width, scroll_height, false, ImGui.WindowFlags_HorizontalScrollbar)

  -- Draw tiles horizontally
  local TemplateTile = require('TemplateBrowser.ui.tiles.template_tile')

  for idx, tmpl in ipairs(recent_templates) do
    local x1, y1 = ImGui.GetCursorScreenPos(ctx)
    local x2 = x1 + tile_width
    local y2 = y1 + tile_height

    -- Create tile state for rendering
    local tile_state = {
      hover = false,
      selected = state.selected_template and state.selected_template.uuid == tmpl.uuid,
      star_clicked = false,
    }

    -- Check hover
    local mx, my = ImGui.GetMousePos(ctx)
    tile_state.hover = mx >= x1 and mx <= x2 and my >= y1 and my <= y2

    -- Render tile
    TemplateTile.render(ctx, {x1, y1, x2, y2}, tmpl, tile_state, state.metadata, gui.template_animator)

    -- Handle tile click
    if tile_state.hover and ImGui.IsMouseClicked(ctx, 0) and not tile_state.star_clicked then
      state.selected_template = tmpl
    end

    -- Handle star click
    if tile_state.star_clicked then
      local Persistence = require('TemplateBrowser.domain.persistence')
      local favorites_id = "__FAVORITES__"
      local favorites = state.metadata.virtual_folders[favorites_id]

      if favorites then
        -- Toggle favorite
        local is_favorited = false
        local favorite_index = nil
        for i, ref_uuid in ipairs(favorites.template_refs) do
          if ref_uuid == tmpl.uuid then
            is_favorited = true
            favorite_index = i
            break
          end
        end

        if is_favorited then
          table.remove(favorites.template_refs, favorite_index)
          state.set_status("Removed from Favorites: " .. tmpl.name, "success")
        else
          table.insert(favorites.template_refs, tmpl.uuid)
          state.set_status("Added to Favorites: " .. tmpl.name, "success")
        end

        Persistence.save_metadata(state.metadata)
      end
    end

    -- Handle double-click
    if tile_state.hover and ImGui.IsMouseDoubleClicked(ctx, 0) then
      TemplateOps.apply_to_selected_track(tmpl.path, tmpl.uuid, state)
    end

    -- Move cursor for next tile
    ImGui.SetCursorScreenPos(ctx, x2 + tile_gap, y1)
  end

  -- Add dummy to consume the space used by horizontally positioned tiles
  -- This prevents SetCursorPos error when EndChild is called
  if #recent_templates > 0 then
    local total_width = (#recent_templates * tile_width) + ((#recent_templates - 1) * tile_gap)
    ImGui.Dummy(ctx, total_width, tile_height)
  end

  ImGui.EndChild(ctx)

  -- Separator after recent templates
  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  return section_height
end

-- Draw template list panel (middle)
-- Draw template panel using TilesContainer
local function draw_template_panel(ctx, gui, width, height)
  local state = gui.state

  -- Begin outer container
  BeginChildCompat(ctx, "TemplatePanel", width, height, true)

  -- Draw recent templates section
  local recent_height = draw_recent_templates(ctx, gui, width - 16, height)  -- Account for padding

  -- Calculate remaining height for main grid
  local grid_height = height - recent_height - 32  -- Account for container padding

  -- Set container dimensions for main grid
  gui.template_container.width = width - 16
  gui.template_container.height = grid_height

  -- Begin panel drawing
  if gui.template_container:begin_draw(ctx) then
    -- Draw template grid
    gui.template_grid:draw(ctx)

    -- End panel drawing
    gui.template_container:end_draw(ctx)
  end

  ImGui.EndChild(ctx)
end

-- Draw template context menu (color picker)
local function draw_template_context_menu(ctx, state)
  -- Context menu with color picker (MUST be outside BeginChild for popups to work)
  if state.context_menu_template then
    ImGui.OpenPopup(ctx, "template_color_picker")
  end

  if ImGui.BeginPopup(ctx, "template_color_picker") then
    local tmpl = state.context_menu_template
    if tmpl then
      ImGui.Text(ctx, "Set Template Color")
      ImGui.Separator(ctx)
      ImGui.Spacing(ctx)

      -- Get template metadata
      local tmpl_metadata = state.metadata and state.metadata.templates[tmpl.uuid]
      local current_color = tmpl_metadata and tmpl_metadata.chip_color or nil

      -- Draw 4x4 color grid
      local grid_cols = 4
      local chip_size = 20
      local chip_radius = chip_size / 2

      for idx, color in ipairs(PRESET_COLORS) do
        local col_idx = (idx - 1) % grid_cols

        if col_idx > 0 then
          ImGui.SameLine(ctx)
        end

        -- Position for color button
        local start_x, start_y = ImGui.GetCursorScreenPos(ctx)

        -- Clickable area
        if ImGui.InvisibleButton(ctx, "##color_" .. idx, chip_size, chip_size) then
          -- Set color
          if tmpl_metadata then
            tmpl_metadata.chip_color = color
            local Persistence = require('TemplateBrowser.domain.persistence')
            Persistence.save_metadata(state.metadata)
          end
          state.context_menu_template = nil
          ImGui.CloseCurrentPopup(ctx)
        end

        local is_hovered = ImGui.IsItemHovered(ctx)
        local is_this_color = (current_color == color)

        -- Draw chip
        local chip_x = start_x + chip_radius
        local chip_y = start_y + chip_radius
        Chip.draw(ctx, {
          style = Chip.STYLE.INDICATOR,
          x = chip_x,
          y = chip_y,
          radius = chip_radius - 2,
          color = color,
          is_selected = is_this_color,
          is_hovered = is_hovered,
          show_glow = is_this_color or is_hovered,
          glow_layers = is_this_color and 6 or 3,
        })
      end

      ImGui.Spacing(ctx)
      ImGui.Separator(ctx)
      ImGui.Spacing(ctx)

      -- Remove color button
      if Button.draw_at_cursor(ctx, { label = "Remove Color", width = -1, height = 24 }, "remove_color") then
        if tmpl_metadata then
          tmpl_metadata.chip_color = nil
          local Persistence = require('TemplateBrowser.domain.persistence')
          Persistence.save_metadata(state.metadata)
        end
        state.context_menu_template = nil
        ImGui.CloseCurrentPopup(ctx)
      end

      -- Add "Remove from Virtual Folder" button if viewing a virtual folder
      if state.selected_folder and state.selected_folder ~= "" and state.metadata then
        local vfolder = state.metadata.virtual_folders and state.metadata.virtual_folders[state.selected_folder]
        if vfolder and tmpl then
          ImGui.Spacing(ctx)
          ImGui.Separator(ctx)
          ImGui.Spacing(ctx)

          if Button.draw_at_cursor(ctx, { label = "Remove from " .. vfolder.name, width = -1, height = 24 }, "remove_from_vfolder") then
            local Persistence = require('TemplateBrowser.domain.persistence')

            -- Remove template UUID from virtual folder's template_refs
            if vfolder.template_refs then
              for i, ref_uuid in ipairs(vfolder.template_refs) do
                if ref_uuid == tmpl.uuid then
                  table.remove(vfolder.template_refs, i)
                  break
                end
              end
            end

            -- Save metadata
            Persistence.save_metadata(state.metadata)

            -- Refresh filtered templates
            local Scanner = require('TemplateBrowser.domain.scanner')
            Scanner.filter_templates(state)

            state.set_status("Removed " .. tmpl.name .. " from " .. vfolder.name, "success")
            state.context_menu_template = nil
            ImGui.CloseCurrentPopup(ctx)
          end
        end
      end
    end

    ImGui.EndPopup(ctx)
  end
end

-- Draw template rename modal
local function draw_template_rename_modal(ctx, state)
  -- Rename modal popup (for F2 or Ctrl+double-click)
  if state.renaming_item and state.renaming_type == "template" then
    ImGui.OpenPopup(ctx, "Rename Template")
  end

  if ImGui.BeginPopupModal(ctx, "Rename Template", nil, ImGui.WindowFlags_AlwaysAutoResize) then
    local tmpl = state.renaming_item

    ImGui.Text(ctx, "Current name: " .. (tmpl and tmpl.name or ""))
    ImGui.Spacing(ctx)

    -- Initialize field with current name
    if Fields.get_text("template_rename_modal") == "" then
      Fields.set_text("template_rename_modal", state.rename_buffer)
    end

    local changed, new_name = Fields.draw_at_cursor(ctx, {
      width = 300,
      height = 24,
      text = state.rename_buffer,
    }, "template_rename_modal")

    if changed then
      state.rename_buffer = new_name
    end

    -- Auto-focus input on first frame
    if ImGui.IsWindowAppearing(ctx) then
      ImGui.SetKeyboardFocusHere(ctx, -1)
    end

    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    -- Buttons
    local ok_clicked = Button.draw_at_cursor(ctx, { label = "OK", width = 140, height = 24 }, "rename_ok")
    if ok_clicked or ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
      if state.rename_buffer ~= "" and state.rename_buffer ~= tmpl.name then
        local old_path = tmpl.path
        local success, new_path = FileOps.rename_template(tmpl.path, state.rename_buffer)
        if success then
          -- Create undo operation
          state.undo_manager:push({
            description = "Rename template: " .. tmpl.name .. " -> " .. state.rename_buffer,
            undo_fn = function()
              local undo_success = FileOps.rename_template(new_path, tmpl.name)
              if undo_success then
                local Scanner = require('TemplateBrowser.domain.scanner')
                Scanner.scan_templates(state)
              end
              return undo_success
            end,
            redo_fn = function()
              local redo_success = FileOps.rename_template(old_path, state.rename_buffer)
              if redo_success then
                local Scanner = require('TemplateBrowser.domain.scanner')
                Scanner.scan_templates(state)
              end
              return redo_success
            end
          })

          local Scanner = require('TemplateBrowser.domain.scanner')
          Scanner.scan_templates(state)
        end
      end
      state.renaming_item = nil
      state.renaming_type = nil
      state.rename_buffer = ""
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.SameLine(ctx)
    local cancel_clicked = Button.draw_at_cursor(ctx, { label = "Cancel", width = 140, height = 24 }, "rename_cancel")
    if cancel_clicked or ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
      state.renaming_item = nil
      state.renaming_type = nil
      state.rename_buffer = ""
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.EndPopup(ctx)
  end
end

-- Draw conflict resolution modal
local function draw_conflict_resolution_modal(ctx, state)
  -- Show conflict modal when conflict is pending
  if state.conflict_pending then
    ImGui.OpenPopup(ctx, "File Conflict")
  end

  if ImGui.BeginPopupModal(ctx, "File Conflict", nil, ImGui.WindowFlags_AlwaysAutoResize) then
    local conflict = state.conflict_pending

    if conflict then
      ImGui.Text(ctx, "A file with the same name already exists in the target folder.")
      ImGui.Spacing(ctx)

      -- Show conflict details
      if #conflict.templates == 1 then
        ImGui.Text(ctx, string.format("File: %s", conflict.templates[1].name))
      else
        ImGui.Text(ctx, string.format("Files: %d templates", #conflict.templates))
      end

      ImGui.Text(ctx, string.format("Target: %s", conflict.target_folder.name or "Root"))

      ImGui.Spacing(ctx)
      ImGui.Separator(ctx)
      ImGui.Spacing(ctx)

      ImGui.Text(ctx, "What would you like to do?")
      ImGui.Spacing(ctx)

      -- Overwrite button
      local overwrite_clicked = Button.draw_at_cursor(ctx, {
        label = "Overwrite (Archives existing)",
        width = 250,
        height = 32
      }, "conflict_overwrite")

      if overwrite_clicked then
        state.conflict_resolution = "overwrite"
        ImGui.CloseCurrentPopup(ctx)
      end

      ImGui.Spacing(ctx)

      -- Keep Both button
      local keep_both_clicked = Button.draw_at_cursor(ctx, {
        label = "Keep Both (Rename new)",
        width = 250,
        height = 32
      }, "conflict_keep_both")

      if keep_both_clicked then
        state.conflict_resolution = "keep_both"
        ImGui.CloseCurrentPopup(ctx)
      end

      ImGui.Spacing(ctx)

      -- Cancel button
      local cancel_clicked = Button.draw_at_cursor(ctx, {
        label = "Cancel",
        width = 250,
        height = 32
      }, "conflict_cancel")

      if cancel_clicked or ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
        state.conflict_resolution = "cancel"
        state.conflict_pending = nil  -- Clear pending conflict
        ImGui.CloseCurrentPopup(ctx)
      end
    end

    ImGui.EndPopup(ctx)
  end
end

-- Draw info & tag assignment panel (right)
local function draw_info_panel(ctx, state, config, width, height)
  -- Outer border container (non-scrollable)
  BeginChildCompat(ctx, "InfoPanel", width, height, true)

  -- Header (stays at top)
  ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.header_bg)
  ImGui.SeparatorText(ctx, "Info & Tags")
  ImGui.PopStyleColor(ctx)

  ImGui.Spacing(ctx)

  -- Scrollable content region
  local header_height = 30  -- SeparatorText + spacing
  local content_height = height - header_height

  BeginChildCompat(ctx, "InfoPanelContent", 0, content_height, false)

  if state.selected_template then
    local tmpl = state.selected_template
    local tmpl_metadata = state.metadata and state.metadata.templates[tmpl.uuid]

    -- Template info
    ImGui.Text(ctx, "Name:")
    ImGui.Indent(ctx, 10)
    ImGui.TextWrapped(ctx, tmpl.name)
    ImGui.Unindent(ctx, 10)

    ImGui.Spacing(ctx)
    ImGui.Text(ctx, "Location:")
    ImGui.Indent(ctx, 10)
    ImGui.TextWrapped(ctx, tmpl.folder)
    ImGui.Unindent(ctx, 10)

    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    -- Actions
    if Button.draw_at_cursor(ctx, { label = "Apply to Selected Track", width = -1, height = 28 }, "apply_template") then
      reaper.ShowConsoleMsg("Applying template: " .. tmpl.name .. "\n")
      TemplateOps.apply_to_selected_track(tmpl.path, tmpl.uuid, state)
    end
    Tooltips.show(ctx, ImGui, "template_apply")

    ImGui.Dummy(ctx, 0, 4)

    if Button.draw_at_cursor(ctx, { label = "Insert as New Track", width = -1, height = 28 }, "insert_template") then
      reaper.ShowConsoleMsg("Inserting template as new track: " .. tmpl.name .. "\n")
      TemplateOps.insert_as_new_track(tmpl.path, tmpl.uuid, state)
    end
    Tooltips.show(ctx, ImGui, "template_insert")

    ImGui.Dummy(ctx, 0, 4)

    if Button.draw_at_cursor(ctx, { label = "Rename (F2)", width = -1, height = 28 }, "rename_template") then
      state.renaming_item = tmpl
      state.renaming_type = "template"
      state.rename_buffer = tmpl.name
    end
    Tooltips.show(ctx, ImGui, "template_rename")

    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    -- Notes (Markdown field with view/edit modes)
    ImGui.Text(ctx, "Notes:")
    Tooltips.show(ctx, ImGui, "notes_field")
    ImGui.Spacing(ctx)

    local notes = (tmpl_metadata and tmpl_metadata.notes) or ""

    -- Initialize markdown field with current notes
    local notes_field_id = "template_notes_" .. tmpl.uuid
    if MarkdownField.get_text(notes_field_id) ~= notes and not MarkdownField.is_editing(notes_field_id) then
      MarkdownField.set_text(notes_field_id, notes)
    end

    local notes_changed, new_notes = MarkdownField.draw_at_cursor(ctx, {
      width = -1,
      height = 200,  -- Taller for better markdown viewing
      text = notes,
      placeholder = "Double-click to add notes...\n\nSupports Markdown:\n• **bold** and *italic*\n• # Headers\n• - Lists\n• [links](url)",
    }, notes_field_id)

    if notes_changed then
      Tags.set_template_notes(state.metadata, tmpl.uuid, new_notes)
      local Persistence = require('TemplateBrowser.domain.persistence')
      Persistence.save_metadata(state.metadata)
    end

    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    -- Tag Assignment
    ImGui.Text(ctx, "Tags:")
    ImGui.Spacing(ctx)

    if state.metadata and state.metadata.tags then
      local has_tags = false
      for tag_name, tag_data in pairs(state.metadata.tags) do
        has_tags = true
        ImGui.PushID(ctx, tag_name)

        -- Check if this tag is assigned
        local is_assigned = false
        if tmpl_metadata and tmpl_metadata.tags then
          for _, assigned_tag in ipairs(tmpl_metadata.tags) do
            if assigned_tag == tag_name then
              is_assigned = true
              break
            end
          end
        end

        -- Draw tag using Chip component (PILL style)
        local clicked, chip_w, chip_h = Chip.draw(ctx, {
          style = Chip.STYLE.PILL,
          label = tag_name,
          color = tag_data.color,
          height = 24,
          is_selected = is_assigned,
          interactive = true,
        })

        if clicked then
          -- Toggle tag assignment
          if is_assigned then
            Tags.remove_tag_from_template(state.metadata, tmpl.uuid, tag_name)
          else
            Tags.add_tag_to_template(state.metadata, tmpl.uuid, tag_name)
          end
          local Persistence = require('TemplateBrowser.domain.persistence')
          Persistence.save_metadata(state.metadata)
        end

        ImGui.PopID(ctx)
      end

      if not has_tags then
        ImGui.TextDisabled(ctx, "No tags available")
        ImGui.TextDisabled(ctx, "Create tags in the Tags panel")
      end
    else
      ImGui.TextDisabled(ctx, "No tags available")
    end

  else
    ImGui.TextDisabled(ctx, "Select a template to view details")
  end

  ImGui.EndChild(ctx)  -- End InfoPanelContent
  ImGui.EndChild(ctx)  -- End InfoPanel
end

function GUI:draw(ctx, shell_state)
  self:initialize_once(ctx)

  -- Process background FX parsing queue (5 templates per frame)
  FXQueue.process_batch(self.state, 5)

  -- Process conflict resolution if user made a choice
  if self.state.conflict_resolution and self.state.conflict_pending then
    local conflict = self.state.conflict_pending
    local resolution = self.state.conflict_resolution

    if resolution ~= "cancel" and conflict.operation == "move" then
      local success_count = 0
      local total_count = #conflict.templates
      local target_node = conflict.target_folder

      for _, tmpl in ipairs(conflict.templates) do
        local success, new_path, conflict_detected = FileOps.move_template(tmpl.path, target_node.full_path, resolution)
        if success then
          success_count = success_count + 1
        else
          self.state.set_status("Failed to move template: " .. tmpl.name, "error")
        end
      end

      -- Rescan if any succeeded
      if success_count > 0 then
        local Scanner = require('TemplateBrowser.domain.scanner')
        Scanner.scan_templates(self.state)

        -- Success message
        if total_count > 1 then
          self.state.set_status("Moved " .. success_count .. " of " .. total_count .. " templates to " .. target_node.name, "success")
        else
          self.state.set_status("Moved " .. conflict.templates[1].name .. " to " .. target_node.name, "success")
        end
      end
    end

    -- Clear conflict state
    self.state.conflict_pending = nil
    self.state.conflict_resolution = nil
  end

  -- Handle keyboard shortcuts (but not while editing markdown)
  local is_editing_markdown = false
  if self.state.selected_template then
    local notes_field_id = "template_notes_" .. self.state.selected_template.uuid
    is_editing_markdown = MarkdownField.is_editing(notes_field_id)
  end

  local action = Shortcuts.check_shortcuts(ctx)
  if action and not is_editing_markdown then
    if action == "undo" then
      self.state.undo_manager:undo()
    elseif action == "redo" then
      self.state.undo_manager:redo()
    elseif action == "rename_template" then
      if self.state.selected_template then
        self.state.renaming_item = self.state.selected_template
        self.state.renaming_type = "template"
        self.state.rename_buffer = self.state.selected_template.name
      end
    elseif action == "archive_template" then
      if self.state.selected_template then
        local success, archive_path = FileOps.delete_template(self.state.selected_template.path)
        if success then
          self.state.set_status("Archived: " .. self.state.selected_template.name, "success")
          -- Rescan templates
          local Scanner = require('TemplateBrowser.domain.scanner')
          Scanner.scan_templates(self.state)
          self.state.selected_template = nil
        else
          self.state.set_status("Failed to archive template", "error")
        end
      end
    elseif action == "apply_template" then
      if self.state.selected_template then
        TemplateOps.apply_to_selected_track(self.state.selected_template.path, self.state.selected_template.uuid, self.state)
      end
    elseif action == "insert_template" then
      if self.state.selected_template then
        TemplateOps.insert_as_new_track(self.state.selected_template.path, self.state.selected_template.uuid, self.state)
      end
    elseif action == "focus_search" then
      -- Focus search box (will be handled by container)
      self.state.focus_search = true
    elseif action == "navigate_left" or action == "navigate_right" or
           action == "navigate_up" or action == "navigate_down" then
      -- Grid navigation (will be handled by grid widget)
      self.state.grid_navigation = action
    end
  end

  -- Get overlay alpha for animations
  local is_overlay_mode = shell_state.is_overlay_mode == true
  local overlay = shell_state.overlay

  local overlay_alpha = 1.0
  if is_overlay_mode and overlay and overlay.alpha then
    overlay_alpha = overlay.alpha:value()
  end
  self.state.overlay_alpha = overlay_alpha

  -- Get screen dimensions
  local SCREEN_W, SCREEN_H
  if is_overlay_mode and shell_state.overlay_state then
    SCREEN_W = shell_state.overlay_state.width
    SCREEN_H = shell_state.overlay_state.height
  else
    local viewport = ImGui.GetMainViewport(ctx)
    SCREEN_W, SCREEN_H = ImGui.Viewport_GetSize(viewport)
  end

  -- Title (moved up by 15 pixels)
  local title_y_offset = -15
  ImGui.PushFont(ctx, shell_state.fonts.title, shell_state.fonts.title_size)
  local title = "Template Browser"
  local title_w = ImGui.CalcTextSize(ctx, title)
  local title_y = ImGui.GetCursorPosY(ctx) + title_y_offset
  ImGui.SetCursorPos(ctx, (SCREEN_W - title_w) * 0.5, title_y)
  ImGui.Text(ctx, title)
  ImGui.PopFont(ctx)

  -- FX parsing progress indicator
  if not FXQueue.is_complete(self.state) then
    local status = FXQueue.get_status(self.state)
    local progress = FXQueue.get_progress(self.state)

    local status_y = title_y + 25
    local status_w = ImGui.CalcTextSize(ctx, status)

    ImGui.SetCursorPos(ctx, (SCREEN_W - status_w) * 0.5, status_y)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, Colors.hexrgb("#B3B3B3"))
    ImGui.Text(ctx, status)
    ImGui.PopStyleColor(ctx)

    -- Small progress bar
    local bar_width = 200
    local bar_height = 3
    ImGui.SetCursorPos(ctx, (SCREEN_W - bar_width) * 0.5, status_y + 18)
    ImGui.PushStyleColor(ctx, ImGui.Col_PlotHistogram, self.config.COLORS.selected_bg)
    ImGui.ProgressBar(ctx, progress, bar_width, bar_height, "")
    ImGui.PopStyleColor(ctx)
  end

  -- Adjust spacing after title
  ImGui.SetCursorPosY(ctx, title_y + 30)

  -- Padding
  local padding_left = 14
  local padding_right = 14
  local padding_bottom = 14
  local status_bar_height = 24  -- Reserve space for status bar

  local cursor_y = ImGui.GetCursorPosY(ctx)
  local content_width = SCREEN_W - padding_left - padding_right
  local panel_height = SCREEN_H - cursor_y - padding_bottom - status_bar_height

  -- Get window's screen position for coordinate conversion
  -- The cursor is currently at (0, cursor_y) in window coords
  local cursor_screen_x, cursor_screen_y = ImGui.GetCursorScreenPos(ctx)
  -- Window's top-left corner in screen coords
  local window_screen_x = cursor_screen_x
  local window_screen_y = cursor_screen_y - cursor_y

  -- Draggable separator configuration
  local separator_thickness = 8
  local min_panel_width = 150

  -- Calculate positions based on ratios within content area (window-relative)
  local sep1_x_local = padding_left + (content_width * self.state.separator1_ratio)
  local sep2_x_local = padding_left + (content_width * self.state.separator2_ratio)

  -- Convert to screen coordinates for separator
  local sep1_x_screen = window_screen_x + sep1_x_local
  local sep2_x_screen = window_screen_x + sep2_x_local
  local content_y_screen = window_screen_y + cursor_y

  -- Handle separator 1 dragging
  local sep1_action, sep1_new_x_screen = self.separator1:draw_vertical(ctx, sep1_x_screen, content_y_screen, 0, panel_height, separator_thickness)
  if sep1_action == "drag" then
    -- Convert back to window coordinates
    local sep1_new_x = sep1_new_x_screen - window_screen_x
    -- Clamp to valid range within content area
    local min_x = padding_left + min_panel_width
    local max_x = SCREEN_W - padding_right - min_panel_width * 2 - separator_thickness * 2
    sep1_new_x = math.max(min_x, math.min(sep1_new_x, max_x))
    self.state.separator1_ratio = (sep1_new_x - padding_left) / content_width
    sep1_x_local = sep1_new_x
    sep1_x_screen = window_screen_x + sep1_x_local
  elseif sep1_action == "reset" then
    self.state.separator1_ratio = self.config.FOLDERS_PANEL_WIDTH_RATIO
    sep1_x_local = padding_left + (content_width * self.state.separator1_ratio)
    sep1_x_screen = window_screen_x + sep1_x_local
  end

  -- Handle separator 2 dragging
  local sep2_action, sep2_new_x_screen = self.separator2:draw_vertical(ctx, sep2_x_screen, content_y_screen, 0, panel_height, separator_thickness)
  if sep2_action == "drag" then
    -- Convert back to window coordinates
    local sep2_new_x = sep2_new_x_screen - window_screen_x
    -- Clamp to valid range
    local min_x = sep1_x_local + separator_thickness + min_panel_width
    local max_x = SCREEN_W - padding_right - min_panel_width
    sep2_new_x = math.max(min_x, math.min(sep2_new_x, max_x))
    self.state.separator2_ratio = (sep2_new_x - padding_left) / content_width
    sep2_x_local = sep2_new_x
    sep2_x_screen = window_screen_x + sep2_x_local
  elseif sep2_action == "reset" then
    self.state.separator2_ratio = self.state.separator1_ratio + self.config.TEMPLATES_PANEL_WIDTH_RATIO
    sep2_x_local = padding_left + (content_width * self.state.separator2_ratio)
    sep2_x_screen = window_screen_x + sep2_x_local
  end

  -- Calculate panel widths (accounting for separator thickness)
  local left_column_width = sep1_x_local - padding_left - separator_thickness / 2
  local template_width = sep2_x_local - sep1_x_local - separator_thickness
  local info_width = SCREEN_W - padding_right - sep2_x_local - separator_thickness / 2

  -- Draw panels with padding
  -- Left column: Tabbed panel (DIRECTORY / VSTS / TAGS)
  ImGui.SetCursorPos(ctx, padding_left, cursor_y)
  draw_left_panel(ctx, self.state, self.config, left_column_width, panel_height)

  -- Middle panel: Templates
  ImGui.SetCursorPos(ctx, sep1_x_local + separator_thickness / 2, cursor_y)
  draw_template_panel(ctx, self, template_width, panel_height)

  -- Right panel: Info & Tag Assignment
  ImGui.SetCursorPos(ctx, sep2_x_local + separator_thickness / 2, cursor_y)
  draw_info_panel(ctx, self.state, self.config, info_width, panel_height)

  -- Template context menu and rename modal (must be drawn outside panels)
  draw_template_context_menu(ctx, self.state)
  draw_template_rename_modal(ctx, self.state)
  draw_conflict_resolution_modal(ctx, self.state)

  -- Status bar at the bottom
  local StatusBar = require('TemplateBrowser.ui.status_bar')
  local status_bar_y = SCREEN_H - padding_bottom - status_bar_height
  ImGui.SetCursorPos(ctx, padding_left, status_bar_y)
  StatusBar.draw(ctx, self.state, content_width, status_bar_height)

  -- Handle exit
  if self.state.exit or ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
    if is_overlay_mode then
      if overlay and overlay.close then
        overlay:close()
      end
    else
      if shell_state.window and shell_state.window.request_close then
        shell_state.window:request_close()
      end
    end
  end
end

return M

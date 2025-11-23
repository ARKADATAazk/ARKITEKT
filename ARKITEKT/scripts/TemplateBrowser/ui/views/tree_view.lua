-- @noindex
-- TemplateBrowser/ui/views/tree_view.lua
-- Template Browser TreeView module for folder tree rendering
-- Handles Physical and Virtual folder trees

local TreeView = require('arkitekt.gui.widgets.navigation.tree_view')

local M = {}

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

  -- Build archive tree from .archive folder
  local function build_archive_tree()
    local archive_children = {}
    local FileOps = require('TemplateBrowser.domain.file_ops')
    local archive_path = FileOps.get_archive_path()
    local sep = package.config:sub(1,1)

    -- Recursively scan archive directory for both folders and files
    local function scan_archive_dir(path, relative_path)
      local nodes = {}

      -- Scan subdirectories
      local idx = 0
      while true do
        local subdir = reaper.EnumerateSubdirectories(path, idx)
        if not subdir then break end

        local sub_relative = relative_path ~= "" and (relative_path .. sep .. subdir) or subdir
        local sub_path = path .. subdir .. sep
        local sub_full_path = sub_path:sub(1, -2)  -- Remove trailing separator

        local folder_node = {
          id = "__ARCHIVE__" .. sep .. sub_relative,
          name = subdir,
          path = sub_relative,
          full_path = sub_full_path,
          children = scan_archive_dir(sub_path, sub_relative),
          is_archive = true,
          is_folder = true,
        }

        table.insert(nodes, folder_node)
        idx = idx + 1
      end

      -- Scan files in this directory
      idx = 0
      while true do
        local file = reaper.EnumerateFiles(path, idx)
        if not file then break end

        local file_relative = relative_path ~= "" and (relative_path .. sep .. file) or file
        local file_full_path = path .. file

        local file_node = {
          id = "__ARCHIVE_FILE__" .. sep .. file_relative,
          name = file,
          path = file_relative,
          full_path = file_full_path,
          children = {},  -- Files have no children
          is_archive = true,
          is_file = true,
        }

        table.insert(nodes, file_node)
        idx = idx + 1
      end

      return nodes
    end

    -- Check if archive directory exists by trying to enumerate it
    local test_idx = 0
    local test_subdir = reaper.EnumerateSubdirectories(archive_path .. sep, test_idx)
    local test_file = reaper.EnumerateFiles(archive_path .. sep, 0)

    -- If we can enumerate (even if empty), directory exists
    if test_subdir ~= nil or test_file ~= nil or reaper.file_exists(archive_path .. sep .. "dummy") == false then
      archive_children = scan_archive_dir(archive_path .. sep, "")
    end

    return archive_children
  end

  local root_nodes = {}

  -- Add Physical Root node
  local template_path = reaper.GetResourcePath() .. package.config:sub(1,1) .. "TrackTemplates"
  local physical_root = {
    id = "__ROOT__",  -- Unique ID for ImGui (must not be empty)
    name = "Physical Directory",
    path = "",  -- Relative path is empty (represents TrackTemplates root)
    full_path = template_path,
    children = {},
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
    name = "Virtual Directory",
    path = "__VIRTUAL_ROOT__",
    children = build_virtual_tree("__VIRTUAL_ROOT__"),  -- All virtual folders go here
    is_virtual = true,
  }

  table.insert(root_nodes, virtual_root)

  -- Add Archive Root node
  local archive_root = {
    id = "__ARCHIVE_ROOT__",
    name = "Archive",
    path = "__ARCHIVE_ROOT__",
    children = build_archive_tree(),
    is_archive = true,
  }

  table.insert(root_nodes, archive_root)

  return root_nodes
end

-- Draw physical folder tree only
function M.draw_physical_tree(ctx, state, config)
  -- Prepare tree nodes from state.folders
  local all_nodes = prepare_tree_nodes(state.folders, state.metadata, state.templates)

  -- Get physical root node and extract its children (start one level down)
  local physical_nodes = {}
  for _, node in ipairs(all_nodes) do
    if node.id == "__ROOT__" then
      -- Use children of root directly, not the root itself
      physical_nodes = node.children or {}
      break
    end
  end

  if #physical_nodes == 0 then
    return
  end

  -- Ensure ROOT node is open by default (for state consistency)
  if state.folder_open_state["__ROOT__"] == nil then
    state.folder_open_state["__ROOT__"] = true
  end

  -- Map state variables to TreeView format
  local tree_state = {
    open_nodes = state.folder_open_state,
    selected_nodes = state.selected_folders,
    last_clicked_node = state.last_clicked_folder,
    renaming_node = state.renaming_folder_path or nil,
    rename_buffer = state.rename_buffer or "",
  }

  -- Draw tree with callbacks
  TreeView.draw(ctx, physical_nodes, tree_state, {
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
      local FileOps = require('TemplateBrowser.domain.file_ops')

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

      local FileOps = require('TemplateBrowser.domain.file_ops')

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
      local ContextMenu = require('arkitekt.gui.widgets.overlays.context_menu')
      local Colors = require('arkitekt.core.colors')
      local ColorDefs = require('arkitekt.defs.colors')

      if ContextMenu.begin(ctx_inner, "folder_context_menu") then
        -- Build color options from centralized palette
        local color_options = {{ name = "None", color = nil }}
        for _, palette_color in ipairs(ColorDefs.PALETTE) do
          table.insert(color_options, {
            name = palette_color.name,
            color = Colors.hexrgb(palette_color.hex)
          })
        end

        for _, color_opt in ipairs(color_options) do
          if ContextMenu.item(ctx_inner, color_opt.name) then
            local Persistence = require('TemplateBrowser.domain.persistence')
            local ImGui = require('imgui') '0.10'

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
              local ImGui = require('imgui') '0.10'

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
        local FileOps = require('TemplateBrowser.domain.file_ops')

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

    -- Delete callback (Delete key)
    on_delete = function(node)
      -- Don't allow deleting root nodes or virtual folders (only physical)
      if node.id == "__ROOT__" or node.id == "__VIRTUAL_ROOT__" or node.is_virtual then
        return
      end

      local FileOps = require('TemplateBrowser.domain.file_ops')
      local Scanner = require('TemplateBrowser.domain.scanner')

      -- Count templates in folder and subfolders
      local template_count = 0
      for _, tmpl in ipairs(state.templates) do
        local sep = package.config:sub(1,1)
        local tmpl_path = tmpl.relative_path or ""
        if tmpl_path == node.path or tmpl_path:find("^" .. node.path:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1") .. sep) then
          template_count = template_count + 1
        end
      end

      local success, archive_path

      if template_count == 0 then
        -- Empty folder: attempt to delete directly (will only work if truly empty)
        success = os.remove(node.full_path)
        if success then
          state.set_status("Deleted empty folder: " .. node.name, "success")
        else
          -- Folder might have subdirectories - try archiving instead
          success, archive_path = FileOps.delete_folder(node.full_path)
          if success then
            state.set_status(string.format("Folder has subdirectories, archived to %s", archive_path), "success")
          else
            state.set_status("Failed to delete folder: " .. node.name, "error")
            return
          end
        end
      else
        -- Folder with templates: archive with structure
        success, archive_path = FileOps.delete_folder(node.full_path)
        if success then
          state.set_status(string.format("Deleted folder with %d template%s, archived to %s",
            template_count,
            template_count == 1 and "" or "s",
            archive_path), "success")
        else
          state.set_status("Failed to archive folder: " .. node.name, "error")
          return
        end
      end

      -- Create undo operation
      if success then
        state.undo_manager:push({
          description = "Delete folder: " .. node.name,
          undo_fn = function()
            if archive_path then
              -- Restore from archive
              local restore_success = os.rename(archive_path, node.full_path)
              if restore_success then
                Scanner.scan_templates(state)
              end
              return restore_success
            else
              -- Cannot restore simple deletion
              return false
            end
          end,
          redo_fn = function()
            if template_count == 0 then
              local redo_success = os.remove(node.full_path)
              if not redo_success then
                redo_success, archive_path = FileOps.delete_folder(node.full_path)
              end
              if redo_success then
                Scanner.scan_templates(state)
              end
              return redo_success
            else
              local redo_success, redo_archive = FileOps.delete_folder(node.full_path)
              if redo_success then
                archive_path = redo_archive
                Scanner.scan_templates(state)
              end
              return redo_success
            end
          end
        })

        -- Clear selection and rescan
        state.selected_folder = ""
        state.selected_folders = {}
        Scanner.scan_templates(state)
      end
    end,
  })

  -- Sync TreeView state back to Template Browser state
  state.selected_folders = tree_state.selected_nodes
  state.last_clicked_folder = tree_state.last_clicked_node
  state.renaming_folder_path = tree_state.renaming_node
  state.rename_buffer = tree_state.rename_buffer
end

-- Draw virtual folder tree only
function M.draw_virtual_tree(ctx, state, config)
  -- Prepare tree nodes from state.folders
  local all_nodes = prepare_tree_nodes(state.folders, state.metadata, state.templates)

  -- Get virtual root node and extract its children (start one level down)
  local virtual_nodes = {}
  for _, node in ipairs(all_nodes) do
    if node.id == "__VIRTUAL_ROOT__" then
      -- Use children of root directly, not the root itself
      virtual_nodes = node.children or {}
      break
    end
  end

  if #virtual_nodes == 0 then
    return
  end

  -- Ensure VIRTUAL_ROOT node is open by default (for state consistency)
  if state.folder_open_state["__VIRTUAL_ROOT__"] == nil then
    state.folder_open_state["__VIRTUAL_ROOT__"] = true
  end

  -- Map state variables to TreeView format (same as physical tree)
  local tree_state = {
    open_nodes = state.folder_open_state,
    selected_nodes = state.selected_folders,
    last_clicked_node = state.last_clicked_folder,
    renaming_node = state.renaming_folder_path or nil,
    rename_buffer = state.rename_buffer or "",
  }

  -- Draw tree with same callbacks as physical tree (they handle both types)
  TreeView.draw(ctx, virtual_nodes, tree_state, {
    enable_rename = true,
    show_colors = true,
    enable_drag_drop = true,
    enable_multi_select = true,
    context_menu_id = "folder_context_menu",

    can_rename = function(node)
      if node.is_virtual then
        local vfolder = state.metadata.virtual_folders and state.metadata.virtual_folders[node.id]
        if vfolder and vfolder.is_system then
          return false
        end
      end
      return true
    end,

    on_select = function(node, selected_nodes)
      state.selected_folders = selected_nodes
      state.selected_folder = node.path
      local Scanner = require('TemplateBrowser.domain.scanner')
      Scanner.filter_templates(state)
    end,

    on_drop_folder = function(dragged_node_id, target_node)
      -- Virtual tree doesn't support folder moves (only template drops)
      -- Physical folders can't be moved to virtual and vice versa
    end,

    on_drop_template = function(template_payload, target_node)
      if not target_node then return end
      local FileOps = require('TemplateBrowser.domain.file_ops')

      -- Parse payload
      local uuids = {}
      if template_payload:find("\n") then
        for uuid in template_payload:gmatch("[^\n]+") do
          table.insert(uuids, uuid)
        end
      else
        table.insert(uuids, template_payload)
      end

      if #uuids == 0 then return end

      -- Only handle virtual folder drops (add references)
      if target_node.is_virtual then
        local Persistence = require('TemplateBrowser.domain.persistence')
        local vfolder = state.metadata.virtual_folders[target_node.id]
        if not vfolder then
          state.set_status("Virtual folder not found", "error")
          return
        end

        if not vfolder.template_refs then
          vfolder.template_refs = {}
        end

        local added_count = 0
        for _, uuid in ipairs(uuids) do
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

        Persistence.save_metadata(state.metadata)

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
      end
    end,

    on_right_click = function(node)
      state.context_menu_node = node
    end,

    render_context_menu = function(ctx_inner, node)
      local ContextMenu = require('arkitekt.gui.widgets.overlays.context_menu')
      local Colors = require('arkitekt.core.colors')
      local ColorDefs = require('arkitekt.defs.colors')

      if ContextMenu.begin(ctx_inner, "folder_context_menu") then
        -- Build color options from centralized palette
        local color_options = {{ name = "None", color = nil }}
        for _, palette_color in ipairs(ColorDefs.PALETTE) do
          table.insert(color_options, {
            name = palette_color.name,
            color = Colors.hexrgb(palette_color.hex)
          })
        end

        for _, color_opt in ipairs(color_options) do
          if ContextMenu.item(ctx_inner, color_opt.name) then
            local Persistence = require('TemplateBrowser.domain.persistence')
            local ImGui = require('imgui') '0.10'

            if node.is_virtual then
              if state.metadata.virtual_folders and state.metadata.virtual_folders[node.id] then
                state.metadata.virtual_folders[node.id].color = color_opt.color
                Persistence.save_metadata(state.metadata)
                local Scanner = require('TemplateBrowser.domain.scanner')
                Scanner.scan_templates(state)
              end
            end

            ImGui.CloseCurrentPopup(ctx_inner)
          end
        end

        if node.is_virtual then
          local vfolder = state.metadata.virtual_folders and state.metadata.virtual_folders[node.id]
          local is_system_folder = vfolder and vfolder.is_system

          if not is_system_folder then
            ContextMenu.separator(ctx_inner)

            if ContextMenu.item(ctx_inner, "Delete Virtual Folder") then
              local Persistence = require('TemplateBrowser.domain.persistence')
              local ImGui = require('imgui') '0.10'

              if state.metadata.virtual_folders and state.metadata.virtual_folders[node.id] then
                state.metadata.virtual_folders[node.id] = nil
                Persistence.save_metadata(state.metadata)

                if state.selected_folder == node.id then
                  state.selected_folder = ""
                  state.selected_folders = {}
                end

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

    on_rename = function(node, new_name)
      if new_name ~= "" and new_name ~= node.name then
        local Persistence = require('TemplateBrowser.domain.persistence')

        if node.is_virtual then
          if state.metadata.virtual_folders and state.metadata.virtual_folders[node.id] then
            local vfolder = state.metadata.virtual_folders[node.id]
            if vfolder.is_system then
              state.set_status("Cannot rename system folder: " .. node.name, "error")
              return false
            end

            state.metadata.virtual_folders[node.id].name = new_name
            Persistence.save_metadata(state.metadata)
            state.set_status("Renamed virtual folder to: " .. new_name, "success")
          end
        end
      end
    end,

    -- Delete callback (Delete key) - virtual folders use context menu delete
    on_delete = function(node)
      -- Virtual folders are deleted via context menu, not Delete key
      -- This is intentionally empty for virtual tree
    end,
  })

  -- Sync TreeView state back to Template Browser state
  state.selected_folders = tree_state.selected_nodes
  state.last_clicked_folder = tree_state.last_clicked_node
  state.renaming_folder_path = tree_state.renaming_node
  state.rename_buffer = tree_state.rename_buffer
end

-- Draw archive folder tree only
function M.draw_archive_tree(ctx, state, config)
  -- Prepare tree nodes from state.folders
  local all_nodes = prepare_tree_nodes(state.folders, state.metadata, state.templates)

  -- Get archive root node and extract its children (start one level down)
  local archive_nodes = {}
  for _, node in ipairs(all_nodes) do
    if node.id == "__ARCHIVE_ROOT__" then
      -- Use children of root directly, not the root itself
      archive_nodes = node.children or {}
      break
    end
  end

  if #archive_nodes == 0 then
    return
  end

  -- Ensure ARCHIVE_ROOT node is open by default (for state consistency)
  if state.folder_open_state["__ARCHIVE_ROOT__"] == nil then
    state.folder_open_state["__ARCHIVE_ROOT__"] = true
  end

  -- Map state variables to TreeView format
  local tree_state = {
    open_nodes = state.folder_open_state,
    selected_nodes = state.selected_folders,
    last_clicked_node = state.last_clicked_folder,
    renaming_node = nil,  -- Archive folders cannot be renamed
    rename_buffer = "",
  }

  -- Draw tree with minimal callbacks (archive is read-only)
  TreeView.draw(ctx, archive_nodes, tree_state, {
    enable_rename = false,  -- No renaming in archive
    show_colors = false,  -- No colors for archive
    enable_drag_drop = false,  -- No drag-drop in archive
    enable_multi_select = true,
    context_menu_id = nil,  -- No context menu for archive

    on_select = function(node, selected_nodes)
      -- Archive folders don't filter templates
      -- Just update selection state
      state.selected_folders = selected_nodes
      state.last_clicked_folder = node.path
    end,

    -- No delete for archive folders
    on_delete = function(node)
      -- Archive folders cannot be deleted via Delete key
    end,
  })

  -- Sync TreeView state back to Template Browser state
  state.selected_folders = tree_state.selected_nodes
  state.last_clicked_folder = tree_state.last_clicked_node
end

-- Legacy function that draws both trees (kept for compatibility)
function M.draw_folder_tree(ctx, state, config)
  M.draw_physical_tree(ctx, state, config)
end

return M

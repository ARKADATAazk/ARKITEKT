-- @noindex
-- TemplateBrowser/ui/views/tree_view.lua
-- Template Browser TreeView module using new Ark.Tree widget
-- Handles Physical, Virtual, Inbox, and Archive folder trees

local Logger = require('arkitekt.debug.logger')
local Ark = require('arkitekt')
local PathValidation = require('arkitekt.core.path_validation')
local ImGui = require('arkitekt.core.imgui')
local FileOps = require('TemplateBrowser.data.file_ops')
local Scanner = require('TemplateBrowser.domain.template.scanner')
local Persistence = require('TemplateBrowser.data.storage')
local ContextMenu = require('arkitekt.gui.widgets.overlays.context_menu')
local Colors = require('arkitekt.core.colors')
local ColorDefs = require('arkitekt.config.colors')
local Constants = require('TemplateBrowser.config.constants')

local M = {}

-- ============================================================================
-- NODE PREPARATION (same as before)
-- ============================================================================

-- Convert folder tree to Tree widget format with colors from metadata
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
      icon_type = 'folder',  -- Always show folder icon
    }

    -- Add color from metadata if available
    if metadata and metadata.folders and metadata.folders[n.uuid] then
      tree_node.color = metadata.folders[n.uuid].color
    end

    -- Convert children recursively
    if n.children then
      for _, child in ipairs(n.children) do
        tree_node.children[#tree_node.children + 1] = convert_physical_node(child)
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
          path = vfolder.id,
          is_virtual = true,
          template_refs = vfolder.template_refs or {},
          color = vfolder.color,
          children = build_virtual_tree(vfolder.id),
        }
        virtual_children[#virtual_children + 1] = vnode
      end
    end

    return virtual_children
  end

  -- Build archive tree from _Archive folder
  local function build_archive_tree()
    local archive_children = {}
    local archive_path = FileOps.get_archive_path()
    local sep = package.config:sub(1,1)

    local function scan_archive_dir(path, relative_path)
      local nodes = {}

      local idx = 0
      while true do
        local subdir = reaper.EnumerateSubdirectories(path, idx)
        if not subdir then break end

        local sub_relative = relative_path ~= '' and (relative_path .. sep .. subdir) or subdir
        local sub_path = path .. subdir .. sep
        local sub_full_path = sub_path:sub(1, -2)

        local folder_node = {
          id = '__ARCHIVE__' .. sep .. sub_relative,
          name = subdir,
          path = sub_relative,
          full_path = sub_full_path,
          children = scan_archive_dir(sub_path, sub_relative),
          is_archive = true,
          is_folder = true,
          icon_type = 'folder',  -- Archive folder icon
        }

        nodes[#nodes + 1] = folder_node
        idx = idx + 1
      end

      idx = 0
      while true do
        local file = reaper.EnumerateFiles(path, idx)
        if not file then break end

        local file_relative = relative_path ~= '' and (relative_path .. sep .. file) or file
        local file_full_path = path .. file

        local file_node = {
          id = '__ARCHIVE_FILE__' .. sep .. file_relative,
          name = file,
          path = file_relative,
          full_path = file_full_path,
          children = {},
          is_archive = true,
          is_file = true,
        }

        nodes[#nodes + 1] = file_node
        idx = idx + 1
      end

      return nodes
    end

    local test_idx = 0
    local test_subdir = reaper.EnumerateSubdirectories(archive_path .. sep, test_idx)
    local test_file = reaper.EnumerateFiles(archive_path .. sep, 0)

    if test_subdir ~= nil or test_file ~= nil or reaper.file_exists(archive_path .. sep .. 'dummy') == false then
      archive_children = scan_archive_dir(archive_path .. sep, '')
    end

    return archive_children
  end

  -- Build inbox tree from _Inbox folder
  local function build_inbox_tree()
    local inbox_children = {}

    if all_templates then
      for _, tmpl in ipairs(all_templates) do
        if tmpl.relative_path == Constants.FOLDERS.INBOX then
          local template_node = {
            id = '__INBOX_TMPL__' .. tmpl.uuid,
            name = tmpl.name,
            path = tmpl.path,
            full_path = tmpl.path,
            uuid = tmpl.uuid,
            children = {},
            is_inbox = true,
            is_template = true,
          }
          inbox_children[#inbox_children + 1] = template_node
        end
      end
    end

    table.sort(inbox_children, function(a, b) return a.name:lower() < b.name:lower() end)

    return inbox_children
  end

  local root_nodes = {}

  -- Physical Root
  local template_path = reaper.GetResourcePath() .. package.config:sub(1,1) .. 'TrackTemplates'
  local physical_root = {
    id = '__ROOT__',
    name = 'Physical Directory',
    path = '',
    full_path = template_path,
    children = {},
    is_virtual = false,
  }

  if node.children then
    for _, child in ipairs(node.children) do
      if child.name ~= Constants.FOLDERS.INBOX and child.name ~= Constants.FOLDERS.ARCHIVE then
        local converted = convert_physical_node(child)
        physical_root.children[#physical_root.children + 1] = converted
      end
    end
  end

  root_nodes[#root_nodes + 1] = physical_root

  -- Virtual Root
  local virtual_root = {
    id = '__VIRTUAL_ROOT__',
    name = 'Virtual Directory',
    path = '__VIRTUAL_ROOT__',
    children = build_virtual_tree('__VIRTUAL_ROOT__'),
    is_virtual = true,
  }

  root_nodes[#root_nodes + 1] = virtual_root

  -- Inbox Root
  local inbox_children = build_inbox_tree()
  local inbox_root = {
    id = '__INBOX_ROOT__',
    name = 'Inbox',
    path = '__INBOX_ROOT__',
    children = inbox_children,
    is_inbox = true,
    template_count = #inbox_children,
  }

  root_nodes[#root_nodes + 1] = inbox_root

  -- Archive Root
  local archive_root = {
    id = '__ARCHIVE_ROOT__',
    name = 'Archive',
    path = '__ARCHIVE_ROOT__',
    children = build_archive_tree(),
    is_archive = true,
  }

  root_nodes[#root_nodes + 1] = archive_root

  return root_nodes
end

-- ============================================================================
-- HELPER: Find node by ID in tree
-- ============================================================================

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

-- ============================================================================
-- PHYSICAL FOLDER TREE
-- ============================================================================

function M.draw_physical_tree(ctx, state, config, height)
  local all_nodes = prepare_tree_nodes(state.folders, state.metadata, state.templates)

  -- Get physical root children
  local physical_nodes = {}
  for _, node in ipairs(all_nodes) do
    if node.id == '__ROOT__' then
      physical_nodes = node.children or {}
      break
    end
  end

  if #physical_nodes == 0 then
    return
  end

  -- Ensure ROOT is open by default
  if state.folder_open_state['__ROOT__'] == nil then
    state.folder_open_state['__ROOT__'] = true
  end

  -- Draw tree using new Ark.Tree widget
  local result = Ark.Tree(ctx, {
    id = 'physical_tree',
    nodes = physical_nodes,
    width = ImGui.GetContentRegionAvail(ctx),
    height = height or 200,
    draggable = true,
    renameable = true,
    multi_select = true,

    can_rename = function(node)
      if node.is_virtual then
        local vfolder = state.metadata.virtual_folders and state.metadata.virtual_folders[node.id]
        if vfolder and vfolder.is_system then
          return false
        end
      end
      return true
    end,

    on_select = function(id)
      state.selected_folder = id
      state.selected_folders = { [id] = true }
      Scanner.filter_templates(state)
    end,

    on_right_click = function(id, selected_ids)
      local node = find_node_by_id(physical_nodes, id)
      if node then
        state.context_menu_node = node
      end
    end,

    on_rename = function(id, new_name)
      local node = find_node_by_id(physical_nodes, id)
      if not node then return end

      if new_name ~= '' and new_name ~= node.name then
        if node.is_virtual then
          if state.metadata.virtual_folders and state.metadata.virtual_folders[node.id] then
            local vfolder = state.metadata.virtual_folders[node.id]
            if vfolder.is_system then
              state.set_status('Cannot rename system folder: ' .. node.name, 'error')
              return
            end

            state.metadata.virtual_folders[node.id].name = new_name
            Persistence.save_metadata(state.metadata)
            state.set_status('Renamed virtual folder to: ' .. new_name, 'success')
          end
          return
        end

        local old_path = node.full_path
        local old_relative_path = node.path

        local success, new_path = FileOps.rename_folder(old_path, new_name)
        if success then
          local parent_path = old_relative_path:match('^(.+)[/\\][^/\\]+$')
          local new_relative_path = parent_path and (parent_path .. '/' .. new_name) or new_name

          if state.metadata and state.metadata.folders then
            for uuid, folder in pairs(state.metadata.folders) do
              if folder.path == old_relative_path then
                folder.name = new_name
                folder.path = new_relative_path
              elseif folder.path:find('^' .. old_relative_path:gsub('([%(%)%.%%%+%-%*%?%[%]%^%$])', '%%%1') .. '[/\\]') then
                folder.path = folder.path:gsub('^' .. old_relative_path:gsub('([%(%)%.%%%+%-%*%?%[%]%^%$])', '%%%1'), new_relative_path)
              end
            end
          end

          if state.metadata and state.metadata.templates then
            for uuid, tmpl in pairs(state.metadata.templates) do
              local tmpl_path = tmpl.folder or ''
              if tmpl_path == old_relative_path then
                tmpl.folder = new_relative_path
              elseif tmpl_path:find('^' .. old_relative_path:gsub('([%(%)%.%%%+%-%*%?%[%]%^%$])', '%%%1') .. '[/\\]') then
                tmpl.folder = tmpl_path:gsub('^' .. old_relative_path:gsub('([%(%)%.%%%+%-%*%?%[%]%^%$])', '%%%1'), new_relative_path)
              end
            end
          end

          Persistence.save_metadata(state.metadata)

          state.undo_manager:push({
            description = 'Rename folder: ' .. node.name .. ' -> ' .. new_name,
            undo_fn = function()
              local undo_success = FileOps.rename_folder(new_path, node.name)
              if undo_success then
                Scanner.scan_templates(state)
              end
              return undo_success
            end,
            redo_fn = function()
              local redo_success = FileOps.rename_folder(old_path, new_name)
              if redo_success then
                Scanner.scan_templates(state)
              end
              return redo_success
            end
          })

          Scanner.scan_templates(state)
        end
      end
    end,

    on_drop = function(info)
      -- Internal folder drag-drop
      if not info.target_id then return end

      local target_node = find_node_by_id(physical_nodes, info.target_id)
      if not target_node then return end

      local function is_descendant(parent_node, potential_child_id)
        if not parent_node.children then return false end
        for _, child in ipairs(parent_node.children) do
          if child.id == potential_child_id then return true end
          if is_descendant(child, potential_child_id) then return true end
        end
        return false
      end

      local folders_to_move = {}
      for _, source_id in ipairs(info.source_ids) do
        local source_node = find_node_by_id(physical_nodes, source_id)
        if not source_node then
          state.set_status('Error: Cannot find source folder', 'error')
          return
        end

        if source_node.id == target_node.id then
          state.set_status('Cannot move folder into itself', 'error')
          return
        end

        if is_descendant(source_node, target_node.id) then
          state.set_status('Cannot move folder into its own subfolder', 'error')
          return
        end

        folders_to_move[#folders_to_move + 1] = source_node
      end

      local move_operations = {}
      local target_full_path = target_node.full_path
      local target_name = target_node.name
      local target_normalized = target_full_path:gsub('[/\\]+$', '')

      for _, source_node in ipairs(folders_to_move) do
        local source_full_path = source_node.full_path
        local source_name = source_node.name
        local source_normalized = source_full_path:gsub('[/\\]+$', '')

        local old_parent = source_normalized:match('^(.+)[/\\][^/\\]+$')
        if not old_parent then
          state.set_status('Cannot determine parent folder for: ' .. source_name, 'error')
          return
        end

        move_operations[#move_operations + 1] = {
          source_normalized = source_normalized,
          source_name = source_name,
          old_parent = old_parent,
          new_path = nil
        }
      end

      local all_success = true
      for _, op in ipairs(move_operations) do
        local success, new_path = FileOps.move_folder(op.source_normalized, target_normalized)
        if success then
          op.new_path = new_path
        else
          all_success = false
          state.set_status('Failed to move folder: ' .. op.source_name, 'error')
          break
        end
      end

      if all_success then
        local description = #folders_to_move > 1
          and ('Move ' .. #folders_to_move .. ' folders -> ' .. target_name)
          or ('Move folder: ' .. move_operations[1].source_name .. ' -> ' .. target_name)

        state.undo_manager:push({
          description = description,
          undo_fn = function()
            local undo_success = true
            for i = #move_operations, 1, -1 do
              local op = move_operations[i]
              if not FileOps.move_folder(op.new_path, op.old_parent) then
                undo_success = false
                break
              end
            end
            if undo_success then
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
              Scanner.scan_templates(state)
            end
            return redo_success
          end
        })

        Scanner.scan_templates(state)

        local count = #folders_to_move
        if count > 1 then
          state.set_status('Successfully moved ' .. count .. ' folders to ' .. target_name, 'success')
        else
          state.set_status('Successfully moved ' .. folders_to_move[1].name .. ' to ' .. target_name, 'success')
        end
      end
    end,

    on_delete = function(ids)
      for _, node_id in ipairs(ids) do
        local node = find_node_by_id(physical_nodes, node_id)
        if not node then return end

        if node.id == '__ROOT__' or node.id == '__VIRTUAL_ROOT__' or node.is_virtual then
          return
        end

        local template_count = 0
        for _, tmpl in ipairs(state.templates) do
          local sep = package.config:sub(1,1)
          local tmpl_path = tmpl.relative_path or ''
          if tmpl_path == node.path or tmpl_path:find('^' .. node.path:gsub('([%(%)%.%%%+%-%*%?%[%]%^%$])', '%%%1') .. sep) then
            template_count = template_count + 1
          end
        end

        local success, archive_path

        if template_count == 0 then
          local path_ok, path_err = PathValidation.is_safe_path(node.full_path)
          if not path_ok then
            state.set_status('Invalid path: ' .. (path_err or 'unknown'), 'error')
            return
          end
          success = os.remove(node.full_path)
          if success then
            state.set_status('Deleted empty folder: ' .. node.name, 'success')
          else
            success, archive_path = FileOps.delete_folder(node.full_path)
            if success then
              state.set_status(string.format('Folder has subdirectories, archived to %s', archive_path), 'success')
            else
              state.set_status('Failed to delete folder: ' .. node.name, 'error')
              return
            end
          end
        else
          success, archive_path = FileOps.delete_folder(node.full_path)
          if success then
            state.set_status(string.format('Deleted folder with %d template%s, archived to %s',
              template_count,
              template_count == 1 and '' or 's',
              archive_path), 'success')
          else
            state.set_status('Failed to archive folder: ' .. node.name, 'error')
            return
          end
        end

        if success then
          state.undo_manager:push({
            description = 'Delete folder: ' .. node.name,
            undo_fn = function()
              if archive_path then
                local src_ok = PathValidation.is_safe_path(archive_path)
                local dst_ok = PathValidation.is_safe_path(node.full_path)
                if not src_ok or not dst_ok then
                  return false
                end
                local restore_success = os.rename(archive_path, node.full_path)
                if restore_success then
                  Scanner.scan_templates(state)
                end
                return restore_success
              else
                return false
              end
            end,
            redo_fn = function()
              if template_count == 0 then
                local path_ok = PathValidation.is_safe_path(node.full_path)
                if not path_ok then
                  return false
                end
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

          state.selected_folder = ''
          state.selected_folders = {}
          Scanner.scan_templates(state)
        end
      end
    end,
  })

  -- Sync selection back to state
  if result.selection_changed then
    state.selected_folders = {}
    for _, id in ipairs(result.selected_ids) do
      state.selected_folders[id] = true
    end
    state.last_clicked_folder = result.clicked_id
  end

  -- Handle context menu for right-click
  if result.right_clicked_id and state.context_menu_node then
    local node = state.context_menu_node
    if ContextMenu.begin(ctx, 'folder_context_menu') then
      local color_options = {{ name = 'None', color = nil }}
      for _, palette_color in ipairs(ColorDefs.PALETTE) do
        color_options[#color_options + 1] = {
          name = palette_color.name,
          color = palette_color.hex
        }
      end

      for _, color_opt in ipairs(color_options) do
        if ContextMenu.item(ctx, color_opt.name) then
          if node.is_virtual then
            if state.metadata.virtual_folders and state.metadata.virtual_folders[node.id] then
              state.metadata.virtual_folders[node.id].color = color_opt.color
              Persistence.save_metadata(state.metadata)
              Scanner.scan_templates(state)
            end
          else
            if not state.metadata.folders then
              state.metadata.folders = {}
            end

            local folder_uuid = nil
            for uuid, folder in pairs(state.metadata.folders) do
              if folder.path == node.path then
                folder_uuid = uuid
                break
              end
            end

            if not folder_uuid then
              folder_uuid = reaper.genGuid('')
              state.metadata.folders[folder_uuid] = {
                path = node.path,
                name = node.name,
              }
            end

            state.metadata.folders[folder_uuid].color = color_opt.color
            Persistence.save_metadata(state.metadata)
            Scanner.scan_templates(state)
          end

          ImGui.CloseCurrentPopup(ctx)
        end
      end

      if node.is_virtual then
        local vfolder = state.metadata.virtual_folders and state.metadata.virtual_folders[node.id]
        local is_system_folder = vfolder and vfolder.is_system

        if not is_system_folder then
          ContextMenu.separator(ctx)

          if ContextMenu.item(ctx, 'Delete Virtual Folder') then
            if state.metadata.virtual_folders and state.metadata.virtual_folders[node.id] then
              state.metadata.virtual_folders[node.id] = nil
              Persistence.save_metadata(state.metadata)

              if state.selected_folder == node.id then
                state.selected_folder = ''
                state.selected_folders = {}
              end

              Scanner.filter_templates(state)
              state.set_status('Deleted virtual folder: ' .. node.name, 'success')
            end

            ImGui.CloseCurrentPopup(ctx)
          end
        end
      end

      ContextMenu.end_menu(ctx)
    end
  end
end

-- ============================================================================
-- VIRTUAL FOLDER TREE
-- ============================================================================

function M.draw_virtual_tree(ctx, state, config, height)
  local all_nodes = prepare_tree_nodes(state.folders, state.metadata, state.templates)

  local virtual_nodes = {}
  for _, node in ipairs(all_nodes) do
    if node.id == '__VIRTUAL_ROOT__' then
      virtual_nodes = node.children or {}
      break
    end
  end

  if #virtual_nodes == 0 then
    return
  end

  if state.folder_open_state['__VIRTUAL_ROOT__'] == nil then
    state.folder_open_state['__VIRTUAL_ROOT__'] = true
  end

  local result = Ark.Tree(ctx, {
    id = 'virtual_tree',
    nodes = virtual_nodes,
    width = ImGui.GetContentRegionAvail(ctx),
    height = height or 200,
    draggable = false,  -- Virtual folders don't support folder-to-folder drag
    renameable = true,
    multi_select = true,

    can_rename = function(node)
      if node.is_virtual then
        local vfolder = state.metadata.virtual_folders and state.metadata.virtual_folders[node.id]
        if vfolder and vfolder.is_system then
          return false
        end
      end
      return true
    end,

    on_select = function(id)
      state.selected_folder = id
      state.selected_folders = { [id] = true }
      Scanner.filter_templates(state)
    end,

    on_right_click = function(id, selected_ids)
      local node = find_node_by_id(virtual_nodes, id)
      if node then
        state.context_menu_node = node
      end
    end,

    on_rename = function(id, new_name)
      local node = find_node_by_id(virtual_nodes, id)
      if not node then return end

      if new_name ~= '' and new_name ~= node.name then
        if node.is_virtual then
          if state.metadata.virtual_folders and state.metadata.virtual_folders[node.id] then
            local vfolder = state.metadata.virtual_folders[node.id]
            if vfolder.is_system then
              state.set_status('Cannot rename system folder: ' .. node.name, 'error')
              return
            end

            state.metadata.virtual_folders[node.id].name = new_name
            Persistence.save_metadata(state.metadata)
            state.set_status('Renamed virtual folder to: ' .. new_name, 'success')
          end
        end
      end
    end,

    on_delete = function(ids)
      -- Virtual folders are deleted via context menu
    end,
  })

  -- Sync selection
  if result.selection_changed then
    state.selected_folders = {}
    for _, id in ipairs(result.selected_ids) do
      state.selected_folders[id] = true
    end
    state.last_clicked_folder = result.clicked_id
  end

  -- Handle context menu
  if result.right_clicked_id and state.context_menu_node then
    local node = state.context_menu_node
    if ContextMenu.begin(ctx, 'virtual_context_menu') then
      local color_options = {{ name = 'None', color = nil }}
      for _, palette_color in ipairs(ColorDefs.PALETTE) do
        color_options[#color_options + 1] = {
          name = palette_color.name,
          color = palette_color.hex
        }
      end

      for _, color_opt in ipairs(color_options) do
        if ContextMenu.item(ctx, color_opt.name) then
          if node.is_virtual then
            if state.metadata.virtual_folders and state.metadata.virtual_folders[node.id] then
              state.metadata.virtual_folders[node.id].color = color_opt.color
              Persistence.save_metadata(state.metadata)
              Scanner.scan_templates(state)
            end
          end

          ImGui.CloseCurrentPopup(ctx)
        end
      end

      if node.is_virtual then
        local vfolder = state.metadata.virtual_folders and state.metadata.virtual_folders[node.id]
        local is_system_folder = vfolder and vfolder.is_system

        if not is_system_folder then
          ContextMenu.separator(ctx)

          if ContextMenu.item(ctx, 'Delete Virtual Folder') then
            if state.metadata.virtual_folders and state.metadata.virtual_folders[node.id] then
              state.metadata.virtual_folders[node.id] = nil
              Persistence.save_metadata(state.metadata)

              if state.selected_folder == node.id then
                state.selected_folder = ''
                state.selected_folders = {}
              end

              Scanner.filter_templates(state)
              state.set_status('Deleted virtual folder: ' .. node.name, 'success')
            end

            ImGui.CloseCurrentPopup(ctx)
          end
        end
      end

      ContextMenu.end_menu(ctx)
    end
  end
end

-- ============================================================================
-- INBOX TREE
-- ============================================================================

function M.draw_inbox_tree(ctx, state, config, height)
  local all_nodes = prepare_tree_nodes(state.folders, state.metadata, state.templates)

  local inbox_nodes = {}
  local inbox_count = 0
  for _, node in ipairs(all_nodes) do
    if node.id == '__INBOX_ROOT__' then
      inbox_nodes = node.children or {}
      inbox_count = node.template_count or #inbox_nodes
      break
    end
  end

  if state.folder_open_state['__INBOX_ROOT__'] == nil then
    state.folder_open_state['__INBOX_ROOT__'] = true
  end

  local result = Ark.Tree(ctx, {
    id = 'inbox_tree',
    nodes = inbox_nodes,
    width = ImGui.GetContentRegionAvail(ctx),
    height = height or 200,
    draggable = true,  -- Allow dragging templates out of inbox
    renameable = false,
    multi_select = true,

    on_select = function(id)
      local node = find_node_by_id(inbox_nodes, id)
      if node and node.is_template and node.uuid then
        for _, tmpl in ipairs(state.templates) do
          if tmpl.uuid == node.uuid then
            state.selected_template = tmpl
            break
          end
        end
      end
      state.selected_folders = { [id] = true }
      state.last_clicked_folder = id
    end,

    on_delete = function(ids)
      -- Inbox templates can't be deleted via Delete key in tree
    end,
  })

  if result.selection_changed then
    state.selected_folders = {}
    for _, id in ipairs(result.selected_ids) do
      state.selected_folders[id] = true
    end
    state.last_clicked_folder = result.clicked_id
  end

  return inbox_count
end

-- ============================================================================
-- ARCHIVE TREE
-- ============================================================================

function M.draw_archive_tree(ctx, state, config, height)
  local all_nodes = prepare_tree_nodes(state.folders, state.metadata, state.templates)

  local archive_nodes = {}
  for _, node in ipairs(all_nodes) do
    if node.id == '__ARCHIVE_ROOT__' then
      archive_nodes = node.children or {}
      break
    end
  end

  if #archive_nodes == 0 then
    return
  end

  if state.folder_open_state['__ARCHIVE_ROOT__'] == nil then
    state.folder_open_state['__ARCHIVE_ROOT__'] = true
  end

  local result = Ark.Tree(ctx, {
    id = 'archive_tree',
    nodes = archive_nodes,
    width = ImGui.GetContentRegionAvail(ctx),
    height = height or 200,
    draggable = false,
    renameable = false,
    multi_select = true,

    on_select = function(id)
      state.selected_folders = { [id] = true }
      state.last_clicked_folder = id
    end,

    on_delete = function(ids)
      -- Archive folders cannot be deleted
    end,
  })

  if result.selection_changed then
    state.selected_folders = {}
    for _, id in ipairs(result.selected_ids) do
      state.selected_folders[id] = true
    end
    state.last_clicked_folder = result.clicked_id
  end
end

-- ============================================================================
-- LEGACY COMPATIBILITY
-- ============================================================================

function M.draw_folder_tree(ctx, state, config)
  M.draw_physical_tree(ctx, state, config)
end

return M

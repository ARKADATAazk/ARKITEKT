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
local TreeView = require('rearkitekt.gui.widgets.navigation.tree_view')

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

  local function convert_node(n)
    local tree_node = {
      id = n.path,
      name = n.name,
      path = n.path,
      full_path = n.full_path,
      children = {},
    }

    -- Add color from metadata if available
    if metadata and metadata.folders and metadata.folders[n.uuid] then
      tree_node.color = metadata.folders[n.uuid].color
    end

    -- Convert children recursively
    if n.children then
      for _, child in ipairs(n.children) do
        table.insert(tree_node.children, convert_node(child))
      end
    end

    return tree_node
  end

  local root_nodes = {}
  if node.children then
    for _, child in ipairs(node.children) do
      table.insert(root_nodes, convert_node(child))
    end
  end

  return root_nodes
end

-- Draw folder tree using TreeView widget
local function draw_folder_tree(ctx, state, config)
  -- Prepare tree nodes from state.folders
  local tree_nodes = prepare_tree_nodes(state.folders, state.metadata, state.templates)

  if #tree_nodes == 0 then
    return
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

    -- Template drop callback
    on_drop_template = function(template_uuid, target_node)
      -- Find template by UUID
      local template = nil
      for _, tmpl in ipairs(state.templates) do
        if tmpl.uuid == template_uuid then
          template = tmpl
          break
        end
      end

      if not template or not target_node then return end

      -- Move template to target folder
      local success = FileOps.move_template(template.path, target_node.full_path)
      if success then
        -- Rescan templates
        local Scanner = require('TemplateBrowser.domain.scanner')
        Scanner.scan_templates(state)
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
            -- Update folder color in metadata
            local Persistence = require('TemplateBrowser.domain.persistence')

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

            ImGui.CloseCurrentPopup(ctx_inner)
          end
        end

        ContextMenu.end_menu(ctx_inner)
      end
    end,

    -- Rename callback
    on_rename = function(node, new_name)
      if new_name ~= "" and new_name ~= node.name then
        local old_path = node.full_path
        local old_relative_path = node.path  -- e.g., "OldFolder" or "Parent/OldFolder"

        local success, new_path = FileOps.rename_folder(old_path, new_name)
        if success then
          -- Calculate new relative path
          local parent_path = old_relative_path:match("^(.+)[/\\][^/\\]+$")
          local new_relative_path = parent_path and (parent_path .. "/" .. new_name) or new_name

          -- Update metadata paths for this folder and all templates in it
          local Persistence = require('TemplateBrowser.domain.persistence')

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
  ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.header_bg)
  ImGui.Text(ctx, "Tags")
  ImGui.SameLine(ctx, width - button_w - config.PANEL_PADDING * 2)

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

  -- List all tags with filtering
  BeginChildCompat(ctx, "DirectoryTagsList", 0, 0, false)

  if state.metadata and state.metadata.tags then
    for tag_name, tag_data in pairs(state.metadata.tags) do
      ImGui.PushID(ctx, tag_name)

      local is_selected = state.filter_tags[tag_name] or false

      if is_selected then
        ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.selected_bg)
      end

      -- Color swatch
      ImGui.ColorButton(ctx, "##color", tag_data.color, 0, 16, 16)
      ImGui.SameLine(ctx)

      -- Tag name as selectable
      if ImGui.Selectable(ctx, tag_name, is_selected) then
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

      if is_selected then
        ImGui.PopStyleColor(ctx)
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
  local folder_height = height * 0.7
  local tags_height = height * 0.3 - 8

  -- Folder tree section
  BeginChildCompat(ctx, "DirectoryFolders", width - config.PANEL_PADDING * 2, folder_height, false)

  -- Header with "+" button
  local button_w = 24
  ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.header_bg)
  ImGui.Text(ctx, "Explorer")
  ImGui.SameLine(ctx, width - button_w - config.PANEL_PADDING * 3)

  if Button.draw_at_cursor(ctx, { label = "+", width = button_w, height = 24 }, "folder") then
    -- Create new folder
    local template_path = reaper.GetResourcePath() .. package.config:sub(1,1) .. "TrackTemplates"
    local folder_num = 1
    local new_folder_name = "New Folder"

    -- Find unique name by checking existing folders in the tree
    local function folder_exists_in_tree(node, name)
      if not node then return false end
      if node.children then
        for _, child in ipairs(node.children) do
          if child.name == name and child.path == name then
            return true
          end
          if folder_exists_in_tree(child, name) then
            return true
          end
        end
      end
      return false
    end

    while folder_exists_in_tree(state.folders, new_folder_name) do
      folder_num = folder_num + 1
      new_folder_name = "New Folder " .. folder_num
    end

    local success, new_path = FileOps.create_folder(template_path, new_folder_name)
    if success then
      local Scanner = require('TemplateBrowser.domain.scanner')
      Scanner.scan_templates(state)
    end
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

  -- Folder tree
  draw_folder_tree(ctx, state, config)

  ImGui.EndChild(ctx)

  ImGui.Spacing(ctx)

  -- Tags section at bottom
  draw_tags_mini_list(ctx, state, config, width - config.PANEL_PADDING * 2, tags_height)
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

    if is_selected then
      ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.selected_bg)
    end

    if ImGui.Selectable(ctx, fx_name, is_selected) then
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

    if is_selected then
      ImGui.PopStyleColor(ctx)
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
        -- Normal display
        -- Color swatch
        ImGui.ColorButton(ctx, "##color", tag_data.color, 0, 16, 16)
        ImGui.SameLine(ctx)

        -- Tag name
        ImGui.Text(ctx, tag_name)

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
    { id = "vsts", label = "VSTS", badge = fx_filter_count > 0 and fx_filter_count or nil },
    { id = "tags", label = "TAGS", badge = tag_filter_count > 0 and tag_filter_count or nil },
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

-- Draw template list panel (middle)
-- Draw template panel using TilesContainer
local function draw_template_panel(ctx, gui, width, height)
  local state = gui.state

  -- Set container dimensions
  gui.template_container.width = width
  gui.template_container.height = height

  -- Begin panel drawing
  if not gui.template_container:begin_draw(ctx) then
    return
  end

  -- Draw template grid
  gui.template_grid:draw(ctx)

  -- End panel drawing
  gui.template_container:end_draw(ctx)
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

-- Draw info & tag assignment panel (right)
local function draw_info_panel(ctx, state, config, width, height)
  BeginChildCompat(ctx, "InfoPanel", width, height, true)

  -- Header
  ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.header_bg)
  ImGui.SeparatorText(ctx, "Info & Tags")
  ImGui.PopStyleColor(ctx)

  ImGui.Spacing(ctx)

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
    if Button.draw_at_cursor(ctx, { label = "Apply to Selected Track", width = -1, height = 32 }, "apply_template") then
      reaper.ShowConsoleMsg("Applying template: " .. tmpl.name .. "\n")
      TemplateOps.apply_to_selected_track(tmpl.path, tmpl.uuid, state)
    end

    if Button.draw_at_cursor(ctx, { label = "Insert as New Track", width = -1, height = 32 }, "insert_template") then
      reaper.ShowConsoleMsg("Inserting template as new track: " .. tmpl.name .. "\n")
      TemplateOps.insert_as_new_track(tmpl.path, tmpl.uuid, state)
    end

    if Button.draw_at_cursor(ctx, { label = "Rename (F2)", width = -1, height = 32 }, "rename_template") then
      state.renaming_item = tmpl
      state.renaming_type = "template"
      state.rename_buffer = tmpl.name
    end

    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    -- Notes
    ImGui.Text(ctx, "Notes:")
    ImGui.Spacing(ctx)

    local notes = (tmpl_metadata and tmpl_metadata.notes) or ""

    -- Initialize field with current notes
    local notes_field_id = "template_notes_" .. tmpl.uuid
    if Fields.get_text(notes_field_id) ~= notes then
      Fields.set_text(notes_field_id, notes)
    end

    local notes_changed, new_notes = Fields.draw_at_cursor(ctx, {
      width = -1,
      height = 80,
      text = notes,
      multiline = true,
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

        -- Color swatch with opacity based on assignment
        local alpha = is_assigned and 0xFF or 0x4D  -- Full opacity or 30%
        local button_color = Colors.with_alpha(tag_data.color, alpha)

        if ImGui.ColorButton(ctx, "##color", button_color, 0, 20, 20) then
          -- Toggle tag assignment
          if is_assigned then
            Tags.remove_tag_from_template(state.metadata, tmpl.uuid, tag_name)
          else
            Tags.add_tag_to_template(state.metadata, tmpl.uuid, tag_name)
          end
          local Persistence = require('TemplateBrowser.domain.persistence')
          Persistence.save_metadata(state.metadata)
        end

        ImGui.SameLine(ctx)

        -- Tag name with opacity
        if not is_assigned then
          ImGui.PushStyleColor(ctx, ImGui.Col_Text, Colors.hexrgb("#808080"))
        end
        ImGui.Text(ctx, tag_name)
        if not is_assigned then
          ImGui.PopStyleColor(ctx)
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

  ImGui.EndChild(ctx)
end

function GUI:draw(ctx, shell_state)
  self:initialize_once(ctx)

  -- Process background FX parsing queue (5 templates per frame)
  FXQueue.process_batch(self.state, 5)

  -- Handle undo/redo
  if ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl) and ImGui.IsKeyPressed(ctx, ImGui.Key_Z) then
    if ImGui.IsKeyDown(ctx, ImGui.Mod_Shift) then
      self.state.undo_manager:redo()
    else
      self.state.undo_manager:undo()
    end
  end

  -- F2 to rename selected template or folder
  if ImGui.IsKeyPressed(ctx, ImGui.Key_F2) then
    if self.state.selected_template then
      self.state.renaming_item = self.state.selected_template
      self.state.renaming_type = "template"
      self.state.rename_buffer = self.state.selected_template.name
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

-- @noindex
-- TemplateBrowser/ui/gui.lua
-- Main GUI with three-panel layout

local ImGui = require 'imgui' '0.10'
local TemplateOps = require('TemplateBrowser.domain.template_ops')
local FileOps = require('TemplateBrowser.domain.file_ops')
local Tags = require('TemplateBrowser.domain.tags')
local Separator = require('TemplateBrowser.ui.separator')

local M = {}
local GUI = {}
GUI.__index = GUI

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
  }, GUI)

  return self
end

function GUI:initialize_once(ctx)
  if self.initialized then return end
  self.ctx = ctx
  self.initialized = true
end

-- Draw folder tree recursively
local _folder_counter = 0
local function draw_folder_node(ctx, node, state, config)
  _folder_counter = _folder_counter + 1
  local node_id = _folder_counter

  local is_selected = (state.selected_folder == node.path)
  local has_children = #node.children > 0
  local is_renaming = (state.renaming_item == node and state.renaming_type == "folder")

  -- Check if folder should be open (from state or default)
  local is_open = state.folder_open_state[node.path]
  if is_open == nil then is_open = false end

  ImGui.PushID(ctx, node_id)

  -- If renaming, show input instead of tree node
  if is_renaming then
    ImGui.SetNextItemWidth(ctx, -1)
    local changed, new_name = ImGui.InputText(ctx, "##rename", state.rename_buffer)

    if changed then
      state.rename_buffer = new_name
    end

    -- Auto-focus on first frame
    if ImGui.IsWindowAppearing(ctx) then
      ImGui.SetKeyboardFocusHere(ctx, 0)
    end

    -- Commit on Enter or deactivate
    if ImGui.IsItemDeactivatedAfterEdit(ctx) or ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
      if state.rename_buffer ~= "" and state.rename_buffer ~= node.name then
        -- Perform rename
        local old_path = node.full_path
        local success, new_path = FileOps.rename_folder(old_path, state.rename_buffer)
        if success then
          -- Create undo operation
          state.undo_manager:push({
            description = "Rename folder: " .. node.name .. " -> " .. state.rename_buffer,
            undo_fn = function()
              local undo_success = FileOps.rename_folder(new_path, node.name)
              if undo_success then
                local Scanner = require('TemplateBrowser.domain.scanner')
                Scanner.scan_templates(state)
              end
              return undo_success
            end,
            redo_fn = function()
              local redo_success = FileOps.rename_folder(old_path, state.rename_buffer)
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
        end
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
    -- Normal tree node display
    local flags = ImGui.TreeNodeFlags_SpanAvailWidth

    if is_selected then
      flags = flags | ImGui.TreeNodeFlags_Selected
    end

    if not has_children then
      flags = flags | ImGui.TreeNodeFlags_Leaf
    end

    -- Set open state
    if is_open then
      ImGui.SetNextItemOpen(ctx, true)
    end

    local node_open = ImGui.TreeNode(ctx, node.name, flags)

    -- Handle clicks
    if ImGui.IsItemClicked(ctx) and not ImGui.IsItemToggledOpen(ctx) then
      -- Single click: select folder and filter
      state.selected_folder = node.path
      local Scanner = require('TemplateBrowser.domain.scanner')
      Scanner.filter_templates(state)
    end

    -- Track open state
    state.folder_open_state[node.path] = node_open

    -- Double-click to rename
    if ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
      state.renaming_item = node
      state.renaming_type = "folder"
      state.rename_buffer = node.name
    end

    -- Drag source (folder drag)
    if ImGui.BeginDragDropSource(ctx) then
      ImGui.SetDragDropPayload(ctx, "FOLDER", node.full_path)
      ImGui.Text(ctx, "Move: " .. node.name)
      ImGui.EndDragDropSource(ctx)
    end

    -- Drop target (drop template or folder here)
    if ImGui.BeginDragDropTarget(ctx) then
      local payload, data = ImGui.AcceptDragDropPayload(ctx, "TEMPLATE")
      if payload then
        -- Move template to this folder
        local old_path = data
        local success, new_path = FileOps.move_template(data, node.full_path)
        if success then
          -- Create undo operation
          local tmpl_filename = old_path:match("[^/\\]+$")
          state.undo_manager:push({
            description = "Move template: " .. tmpl_filename,
            undo_fn = function()
              local old_dir = old_path:match("^(.*)[/\\]")
              local undo_success = FileOps.move_template(new_path, old_dir)
              if undo_success then
                local Scanner = require('TemplateBrowser.domain.scanner')
                Scanner.scan_templates(state)
              end
              return undo_success
            end,
            redo_fn = function()
              local redo_success = FileOps.move_template(old_path, node.full_path)
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

      local folder_payload, folder_data = ImGui.AcceptDragDropPayload(ctx, "FOLDER")
      if folder_payload and folder_data ~= node.full_path then
        -- Move folder into this folder
        local old_path = folder_data
        local success, new_path = FileOps.move_folder(folder_data, node.full_path)
        if success then
          -- Create undo operation
          local folder_name = old_path:match("[^/\\]+$")
          state.undo_manager:push({
            description = "Move folder: " .. folder_name,
            undo_fn = function()
              local old_parent = old_path:match("^(.*)[/\\]")
              local undo_success = FileOps.move_folder(new_path, old_parent)
              if undo_success then
                local Scanner = require('TemplateBrowser.domain.scanner')
                Scanner.scan_templates(state)
              end
              return undo_success
            end,
            redo_fn = function()
              local redo_success = FileOps.move_folder(old_path, node.full_path)
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

      ImGui.EndDragDropTarget(ctx)
    end

    -- Draw children if open
    if node_open then
      for _, child in ipairs(node.children) do
        draw_folder_node(ctx, child, state, config)
      end
      ImGui.TreePop(ctx)
    end
  end

  ImGui.PopID(ctx)
end

-- Draw tabbed left panel (DIRECTORY / VSTS / TAGS)
local function draw_left_panel(ctx, state, config, width, height)
  BeginChildCompat(ctx, "LeftPanel", width, height, true)

  -- Tab bar
  ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.header_bg)

  local tab_width = width / 3
  local tab_flags = 0

  -- DIRECTORY tab
  if state.left_panel_tab == "directory" then
    ImGui.PushStyleColor(ctx, ImGui.Col_Button, config.COLORS.selected_bg)
  end
  if ImGui.Button(ctx, "DIRECTORY", tab_width - 2, 24) then
    state.left_panel_tab = "directory"
  end
  if state.left_panel_tab == "directory" then
    ImGui.PopStyleColor(ctx)
  end

  ImGui.SameLine(ctx)

  -- VSTS tab
  if state.left_panel_tab == "vsts" then
    ImGui.PushStyleColor(ctx, ImGui.Col_Button, config.COLORS.selected_bg)
  end
  if ImGui.Button(ctx, "VSTS", tab_width - 2, 24) then
    state.left_panel_tab = "vsts"
  end
  if state.left_panel_tab == "vsts" then
    ImGui.PopStyleColor(ctx)
  end

  ImGui.SameLine(ctx)

  -- TAGS tab
  if state.left_panel_tab == "tags" then
    ImGui.PushStyleColor(ctx, ImGui.Col_Button, config.COLORS.selected_bg)
  end
  if ImGui.Button(ctx, "TAGS", tab_width - 2, 24) then
    state.left_panel_tab = "tags"
  end
  if state.left_panel_tab == "tags" then
    ImGui.PopStyleColor(ctx)
  end

  ImGui.PopStyleColor(ctx)
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

  if ImGui.Button(ctx, "+##folder", button_w, 0) then
    -- Create new folder
    local template_path = reaper.GetResourcePath() .. package.config:sub(1,1) .. "TrackTemplates"
    local folder_num = 1
    local new_folder_name = "New Folder"

    -- Find unique name
    while true do
      local test_path = template_path .. package.config:sub(1,1) .. new_folder_name
      if not reaper.file_exists(test_path) then
        break
      end
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
  if state.folders and state.folders.children then
    _folder_counter = 0  -- Reset counter each frame
    for _, child in ipairs(state.folders.children) do
      draw_folder_node(ctx, child, state, config)
    end
  end

  ImGui.EndChild(ctx)

  ImGui.Spacing(ctx)

  -- Tags section at bottom
  draw_tags_mini_list(ctx, state, config, width - config.PANEL_PADDING * 2, tags_height)
end

-- Mini tags list for bottom of directory tab
local function draw_tags_mini_list(ctx, state, config, width, height)
  BeginChildCompat(ctx, "DirectoryTags", width, height, true)

  ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.header_bg)
  ImGui.Text(ctx, "Tags")
  ImGui.PopStyleColor(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Show tag count
  local tag_count = 0
  if state.metadata and state.metadata.tags then
    for _ in pairs(state.metadata.tags) do
      tag_count = tag_count + 1
    end
  end

  ImGui.TextDisabled(ctx, string.format("%d tag%s (see TAGS tab)", tag_count, tag_count == 1 and "" or "s"))

  ImGui.EndChild(ctx)
end

-- Draw VSTS content (list of all FX with filtering)
local function draw_vsts_content(ctx, state, config, width, height)
  -- Get all FX from templates
  local FXParser = require('TemplateBrowser.domain.fx_parser')
  local all_fx = FXParser.get_all_fx(state.templates)

  ImGui.Text(ctx, string.format("%d VST%s found", #all_fx, #all_fx == 1 and "" or "s"))
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  BeginChildCompat(ctx, "VSTsList", width - config.PANEL_PADDING * 2, height - 30, false)

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

  if ImGui.Button(ctx, "+##createtag", button_w, 0) then
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
        ImGui.SetNextItemWidth(ctx, -1)
        local changed, new_name = ImGui.InputText(ctx, "##rename_tag", state.rename_buffer)

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
        local r = ((tag_data.color >> 16) & 0xFF) / 255.0
        local g = ((tag_data.color >> 8) & 0xFF) / 255.0
        local b = (tag_data.color & 0xFF) / 255.0

        ImGui.ColorButton(ctx, "##color", ImGui.ColorConvertDouble4ToU32(r, g, b, 1.0), 0, 16, 16)
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

-- DEPRECATED: Old folder panel function (kept for reference, will be removed)
local function draw_folder_panel_old(ctx, state, config, width, height)
  BeginChildCompat(ctx, "FolderPanel", width, height, true)

  -- Header with "+" button
  local header_text_w = ImGui.CalcTextSize(ctx, "Explorer")
  local button_w = 24

  ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.header_bg)
  ImGui.Text(ctx, "Explorer")
  ImGui.SameLine(ctx, width - button_w - config.PANEL_PADDING)

  if ImGui.Button(ctx, "+", button_w, 0) then
    -- Create new folder
    local template_path = reaper.GetResourcePath() .. package.config:sub(1,1) .. "TrackTemplates"
    local folder_num = 1
    local new_folder_name = "New Folder"

    -- Find unique name
    while true do
      local test_path = template_path .. package.config:sub(1,1) .. new_folder_name
      if not reaper.file_exists(test_path) then
        break
      end
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
  if state.folders and state.folders.children then
    _folder_counter = 0  -- Reset counter each frame
    for _, child in ipairs(state.folders.children) do
      draw_folder_node(ctx, child, state, config)
    end
  end

  ImGui.EndChild(ctx)
end

-- Draw template list panel (middle)
local function draw_template_panel(ctx, state, config, width, height)
  BeginChildCompat(ctx, "TemplatePanel", width, height, true)

  -- Header with search
  ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.header_bg)
  ImGui.SeparatorText(ctx, "Templates")
  ImGui.PopStyleColor(ctx)

  ImGui.Spacing(ctx)

  -- Search box
  ImGui.SetNextItemWidth(ctx, -1)
  local changed, new_query = ImGui.InputTextWithHint(ctx, "##search", "Search templates...", state.search_query)
  if changed then
    state.search_query = new_query
    local Scanner = require('TemplateBrowser.domain.scanner')
    Scanner.filter_templates(state)
  end

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Template count
  local count = #state.filtered_templates
  ImGui.Text(ctx, string.format("%d template%s", count, count == 1 and "" or "s"))
  ImGui.Separator(ctx)

  -- Template list
  BeginChildCompat(ctx, "TemplateList", 0, 0, false)

  for i, tmpl in ipairs(state.filtered_templates) do
    local is_selected = (state.selected_template == tmpl)
    local is_renaming = (state.renaming_item == tmpl and state.renaming_type == "template")

    ImGui.PushID(ctx, i)

    if is_renaming then
      -- Rename mode
      ImGui.SetNextItemWidth(ctx, -1)
      local changed_rename, new_name = ImGui.InputText(ctx, "##rename_tmpl", state.rename_buffer)

      if changed_rename then
        state.rename_buffer = new_name
      end

      -- Commit on Enter or deactivate
      if ImGui.IsItemDeactivatedAfterEdit(ctx) or ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
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
      end

      -- Cancel on Escape
      if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
        state.renaming_item = nil
        state.renaming_type = nil
        state.rename_buffer = ""
      end
    else
      -- Normal display
      if is_selected then
        ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.selected_bg)
      end

      local label = tmpl.name
      if tmpl.relative_path ~= "" then
        label = label .. "  [" .. tmpl.folder .. "]"
      end

      if ImGui.Selectable(ctx, label, is_selected, nil, 0, config.TEMPLATE_ITEM_HEIGHT) then
        state.selected_template = tmpl
      end

      -- Double-click: apply or rename (Ctrl = rename, normal = apply)
      if ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
        local ctrl_down = ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl)
        if ctrl_down then
          -- Rename
          state.renaming_item = tmpl
          state.renaming_type = "template"
          state.rename_buffer = tmpl.name
        else
          -- Apply
          TemplateOps.apply_to_selected_track(tmpl.path)
        end
      end

      -- Drag source
      if ImGui.BeginDragDropSource(ctx) then
        ImGui.SetDragDropPayload(ctx, "TEMPLATE", tmpl.path)
        ImGui.Text(ctx, tmpl.name)
        ImGui.EndDragDropSource(ctx)
      end

      if is_selected then
        ImGui.PopStyleColor(ctx)
      end

      -- Show FX under template name
      if tmpl.fx and #tmpl.fx > 0 then
        ImGui.Indent(ctx, 10)
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, ImGui.ColorConvertDouble4ToU32(0.6, 0.6, 0.6, 1.0))

        -- Show unique FX (deduplicated)
        local fx_str = table.concat(tmpl.fx, ", ")
        if #fx_str > 60 then
          fx_str = fx_str:sub(1, 57) .. "..."
        end
        ImGui.TextWrapped(ctx, fx_str)

        ImGui.PopStyleColor(ctx)
        ImGui.Unindent(ctx, 10)
        ImGui.Spacing(ctx)
      end
    end

    ImGui.PopID(ctx)
  end

  ImGui.EndChild(ctx)
  ImGui.EndChild(ctx)
end

-- Draw tags list panel (left-bottom)
local function draw_tags_list_panel(ctx, state, config, width, height)
  BeginChildCompat(ctx, "TagsListPanel", width, height, true)

  -- Header with "+" button
  local header_text = "Tags"
  local header_text_w = ImGui.CalcTextSize(ctx, header_text)
  local button_w = 24

  ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.header_bg)
  ImGui.Text(ctx, header_text)
  ImGui.SameLine(ctx, width - button_w - config.PANEL_PADDING)

  if ImGui.Button(ctx, "+##createtag", button_w, 0) then
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
  if state.metadata and state.metadata.tags then
    for tag_name, tag_data in pairs(state.metadata.tags) do
      local is_renaming = (state.renaming_item == tag_name and state.renaming_type == "tag")

      ImGui.PushID(ctx, tag_name)

      if is_renaming then
        -- Rename mode
        ImGui.SetNextItemWidth(ctx, -1)
        local changed, new_name = ImGui.InputText(ctx, "##rename_tag", state.rename_buffer)

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
        local r = ((tag_data.color >> 16) & 0xFF) / 255.0
        local g = ((tag_data.color >> 8) & 0xFF) / 255.0
        local b = (tag_data.color & 0xFF) / 255.0

        ImGui.ColorButton(ctx, "##color", ImGui.ColorConvertDouble4ToU32(r, g, b, 1.0), 0, 16, 16)
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
    if ImGui.Button(ctx, "Apply to Selected Track", -1, 32) then
      reaper.ShowConsoleMsg("Applying template: " .. tmpl.name .. "\n")
      TemplateOps.apply_to_selected_track(tmpl.path)
    end

    if ImGui.Button(ctx, "Insert as New Track", -1, 32) then
      reaper.ShowConsoleMsg("Inserting template as new track: " .. tmpl.name .. "\n")
      TemplateOps.insert_as_new_track(tmpl.path)
    end

    if ImGui.Button(ctx, "Rename (F2)", -1, 32) then
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
    ImGui.SetNextItemWidth(ctx, -1)
    local notes_changed, new_notes = ImGui.InputTextMultiline(ctx, "##notes", notes, -1, 80)
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
        local r = ((tag_data.color >> 16) & 0xFF) / 255.0
        local g = ((tag_data.color >> 8) & 0xFF) / 255.0
        local b = (tag_data.color & 0xFF) / 255.0
        local alpha = is_assigned and 1.0 or 0.3

        if ImGui.ColorButton(ctx, "##color", ImGui.ColorConvertDouble4ToU32(r, g, b, alpha), 0, 20, 20) then
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
          ImGui.PushStyleColor(ctx, ImGui.Col_Text, ImGui.ColorConvertDouble4ToU32(0.5, 0.5, 0.5, 1.0))
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

  -- Adjust spacing after title
  ImGui.SetCursorPosY(ctx, title_y + 30)

  -- Padding
  local padding_left = 14
  local padding_right = 14
  local padding_bottom = 14

  local cursor_y = ImGui.GetCursorPosY(ctx)
  local content_width = SCREEN_W - padding_left - padding_right
  local panel_height = SCREEN_H - cursor_y - padding_bottom

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
  draw_template_panel(ctx, self.state, self.config, template_width, panel_height)

  -- Right panel: Info & Tag Assignment
  ImGui.SetCursorPos(ctx, sep2_x_local + separator_thickness / 2, cursor_y)
  draw_info_panel(ctx, self.state, self.config, info_width, panel_height)

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

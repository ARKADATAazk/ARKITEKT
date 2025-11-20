-- @noindex
-- TemplateBrowser/ui/views/left_panel_view.lua
-- Left tabbed panel view: Directory / VSTs / Tags

local ImGui = require 'imgui' '0.10'
local Tags = require('TemplateBrowser.domain.tags')
local Button = require('rearkitekt.gui.widgets.primitives.button')
local Fields = require('rearkitekt.gui.widgets.primitives.fields')
local Chip = require('rearkitekt.gui.widgets.data.chip')
local Colors = require('rearkitekt.core.colors')
local Tabs = require('rearkitekt.gui.widgets.navigation.tabs')
local FileOps = require('TemplateBrowser.domain.file_ops')
local TreeViewModule = require('TemplateBrowser.ui.views.tree_view')

local M = {}

-- ImGui compatibility for BeginChild
local function BeginChildCompat(ctx, id, w, h, want_border, window_flags)
  local child_flags = want_border and 1 or 0
  return ImGui.BeginChild(ctx, id, w, h, child_flags, window_flags or 0)
end

-- Tags list for bottom of directory tab (with filtering)
local function draw_tags_mini_list(ctx, state, config, width, height)
  if not BeginChildCompat(ctx, "DirectoryTags", width, height, true) then
    return
  end

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
  if BeginChildCompat(ctx, "DirectoryTagsList", 0, tags_list_height, false) then
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

    ImGui.EndChild(ctx)  -- End DirectoryTagsList
  end

  ImGui.EndChild(ctx)  -- End DirectoryTags
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
  if BeginChildCompat(ctx, "FolderTreeScroll", 0, tree_height, false) then
    TreeViewModule.draw_folder_tree(ctx, state, config)
    ImGui.EndChild(ctx)
  end

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

  if BeginChildCompat(ctx, "VSTsList", width - config.PANEL_PADDING * 2, height - 60, false) then
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
  if BeginChildCompat(ctx, "TagsList", width - config.PANEL_PADDING * 2, height - 30, false) then
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
end

-- Draw tabbed left panel (DIRECTORY / VSTS / TAGS)
local function draw_left_panel(ctx, state, config, width, height)
  if not BeginChildCompat(ctx, "LeftPanel", width, height, true) then
    return
  end

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

-- Export the main draw function
M.draw_left_panel = draw_left_panel

return M

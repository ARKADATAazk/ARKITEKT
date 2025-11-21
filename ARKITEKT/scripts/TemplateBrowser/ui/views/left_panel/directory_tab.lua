-- @noindex
-- TemplateBrowser/ui/views/left_panel/directory_tab.lua
-- Directory tab: Folder tree + folder creation + tags mini-list

local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local Tags = require('TemplateBrowser.domain.tags')
local Button = require('rearkitekt.gui.widgets.primitives.button')
local Chip = require('rearkitekt.gui.widgets.data.chip')
local FileOps = require('TemplateBrowser.domain.file_ops')
local TreeViewModule = require('TemplateBrowser.ui.views.tree_view')
local Helpers = require('TemplateBrowser.ui.views.helpers')
local UI = require('TemplateBrowser.ui.ui_constants')

local M = {}

-- Tags list for bottom of directory tab (with filtering)
local function draw_tags_mini_list(ctx, state, config, width, height)
  if not Helpers.begin_child_compat(ctx, "DirectoryTags", width, height, true) then
    return
  end

  -- Header with "+" button
  ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.header_bg)

  -- Position button at the right
  local button_x = width - UI.BUTTON.WIDTH_SMALL - 8
  ImGui.SetCursorPosX(ctx, button_x)

  if Button.draw_at_cursor(ctx, {
    label = "+",
    width = UI.BUTTON.WIDTH_SMALL,
    height = UI.BUTTON.HEIGHT_DEFAULT
  }, "createtag_dir") then
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
  local tags_list_height = height - UI.HEADER.DEFAULT - UI.PADDING.SEPARATOR_SPACING

  -- List all tags with filtering (scrollable)
  if Helpers.begin_child_compat(ctx, "DirectoryTagsList", 0, tags_list_height, false) then
    if state.metadata and state.metadata.tags then
      for tag_name, tag_data in pairs(state.metadata.tags) do
        ImGui.PushID(ctx, tag_name)

        local is_selected = state.filter_tags[tag_name] or false

        -- Draw tag using Chip component (ACTION style)
        local clicked, chip_w, chip_h = Chip.draw(ctx, {
          style = Chip.STYLE.ACTION,
          label = tag_name,
          bg_color = tag_data.color,
          text_color = Colors.auto_text_color(tag_data.color),
          height = UI.CHIP.HEIGHT_DEFAULT,
          padding_h = 8,
          rounding = 2,
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
function M.draw(ctx, state, config, width, height, gui)
  -- Split into folder tree (top 70%) and tags (bottom 30%)
  local folder_section_height = height * 0.7
  local tags_section_height = height * 0.3 - UI.PADDING.SMALL

  -- === FOLDER SECTION ===
  -- Header with folder creation buttons
  ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.header_bg)

  -- Position buttons at the top right
  local button_x = width - (UI.BUTTON.WIDTH_SMALL * 2 + UI.BUTTON.SPACING) - config.PANEL_PADDING * 2
  ImGui.SetCursorPosX(ctx, button_x)

  -- Physical folder button
  if Button.draw_at_cursor(ctx, {
    label = "+",
    width = UI.BUTTON.WIDTH_SMALL,
    height = UI.BUTTON.HEIGHT_DEFAULT
  }, "folder_physical") then
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
  ImGui.SameLine(ctx, 0, UI.BUTTON.SPACING)
  if Button.draw_at_cursor(ctx, {
    label = "V",
    width = UI.BUTTON.WIDTH_SMALL,
    height = UI.BUTTON.HEIGHT_DEFAULT
  }, "folder_virtual") then
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

  -- Calculate remaining height for folder trees
  -- Account for: header (28) + separator/spacing (10) + All Templates (24) + separator/spacing (10)
  local used_height = UI.HEADER.DEFAULT + UI.PADDING.SEPARATOR_SPACING + 24 + UI.PADDING.SEPARATOR_SPACING
  local total_tree_height = folder_section_height - used_height

  -- Initialize section heights from state (default to 33% each)
  local separator_thickness = 8
  local min_section_height = 80

  state.physical_section_height = state.physical_section_height or math.floor(total_tree_height * 0.40)
  state.virtual_section_height = state.virtual_section_height or math.floor(total_tree_height * 0.30)

  -- Clamp values
  state.physical_section_height = math.max(min_section_height, math.min(state.physical_section_height,
    total_tree_height - min_section_height * 2 - separator_thickness * 2))
  state.virtual_section_height = math.max(min_section_height, math.min(state.virtual_section_height,
    total_tree_height - state.physical_section_height - min_section_height - separator_thickness * 2))

  local archive_section_height = total_tree_height - state.physical_section_height - state.virtual_section_height - separator_thickness * 2

  local current_y = ImGui.GetCursorPosY(ctx)
  local content_x = ImGui.GetCursorPosX(ctx)

  -- === PHYSICAL DIRECTORY SECTION ===
  ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.header_bg)
  ImGui.PushStyleColor(ctx, ImGui.Col_HeaderHovered, config.COLORS.header_hover or config.COLORS.header_bg)
  ImGui.PushStyleColor(ctx, ImGui.Col_HeaderActive, config.COLORS.header_active or config.COLORS.header_bg)

  local physical_open = ImGui.CollapsingHeader(ctx, "Physical Directory", nil, ImGui.TreeNodeFlags_DefaultOpen)

  ImGui.PopStyleColor(ctx, 3)

  if physical_open then
    local header_height = 20  -- Approximate header height
    local scroll_height = state.physical_section_height - header_height
    if Helpers.begin_child_compat(ctx, "PhysicalTreeScroll", 0, scroll_height, false) then
      TreeViewModule.draw_physical_tree(ctx, state, config)
      ImGui.EndChild(ctx)
    end
  end

  -- DRAGGABLE SEPARATOR 1 (between Physical and Virtual)
  local sep1_y = ImGui.GetCursorScreenPos(ctx)
  local sep_action1, sep_value1 = gui.dir_separator1:draw_horizontal(
    ctx,
    content_x,
    sep1_y + separator_thickness / 2,
    width,
    0,
    separator_thickness
  )

  if sep_action1 == "drag" then
    local delta = (sep_value1 - (sep1_y + separator_thickness / 2))
    state.physical_section_height = math.max(min_section_height,
      math.min(state.physical_section_height + delta,
        total_tree_height - min_section_height * 2 - separator_thickness * 2))
  end

  ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) + separator_thickness)

  -- === VIRTUAL DIRECTORY SECTION ===
  ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.header_bg)
  ImGui.PushStyleColor(ctx, ImGui.Col_HeaderHovered, config.COLORS.header_hover or config.COLORS.header_bg)
  ImGui.PushStyleColor(ctx, ImGui.Col_HeaderActive, config.COLORS.header_active or config.COLORS.header_bg)

  local virtual_open = ImGui.CollapsingHeader(ctx, "Virtual Directory", nil, ImGui.TreeNodeFlags_DefaultOpen)

  ImGui.PopStyleColor(ctx, 3)

  if virtual_open then
    local header_height = 20
    local scroll_height = state.virtual_section_height - header_height
    if Helpers.begin_child_compat(ctx, "VirtualTreeScroll", 0, scroll_height, false) then
      TreeViewModule.draw_virtual_tree(ctx, state, config)
      ImGui.EndChild(ctx)
    end
  end

  -- DRAGGABLE SEPARATOR 2 (between Virtual and Archive)
  local sep2_y = ImGui.GetCursorScreenPos(ctx)
  local sep_action2, sep_value2 = gui.dir_separator2:draw_horizontal(
    ctx,
    content_x,
    sep2_y + separator_thickness / 2,
    width,
    0,
    separator_thickness
  )

  if sep_action2 == "drag" then
    local delta = (sep_value2 - (sep2_y + separator_thickness / 2))
    state.virtual_section_height = math.max(min_section_height,
      math.min(state.virtual_section_height + delta,
        total_tree_height - state.physical_section_height - min_section_height - separator_thickness * 2))
  end

  ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) + separator_thickness)

  -- === ARCHIVE SECTION ===
  ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.header_bg)
  ImGui.PushStyleColor(ctx, ImGui.Col_HeaderHovered, config.COLORS.header_hover or config.COLORS.header_bg)
  ImGui.PushStyleColor(ctx, ImGui.Col_HeaderActive, config.COLORS.header_active or config.COLORS.header_bg)

  local archive_open = ImGui.CollapsingHeader(ctx, "Archive", nil, ImGui.TreeNodeFlags_DefaultOpen)

  ImGui.PopStyleColor(ctx, 3)

  if archive_open then
    local header_height = 20
    local scroll_height = archive_section_height - header_height
    if Helpers.begin_child_compat(ctx, "ArchiveTreeScroll", 0, scroll_height, false) then
      TreeViewModule.draw_archive_tree(ctx, state, config)
      ImGui.EndChild(ctx)
    end
  end

  ImGui.Spacing(ctx)

  -- === TAGS SECTION ===
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, config.COLORS.text_dim or config.COLORS.text)
  ImGui.Text(ctx, "TAGS")
  ImGui.PopStyleColor(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  draw_tags_mini_list(ctx, state, config, width, tags_section_height)
end

return M

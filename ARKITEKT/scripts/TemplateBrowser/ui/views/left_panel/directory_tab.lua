-- @noindex
-- TemplateBrowser/ui/views/left_panel/directory_tab.lua
-- Directory tab: Folder tree + folder creation + tags mini-list

local ImGui = require 'imgui' '0.10'
local Colors = require('arkitekt.core.colors')
local Tags = require('TemplateBrowser.domain.tags')
local Button = require('arkitekt.gui.widgets.primitives.button')
local Chip = require('arkitekt.gui.widgets.data.chip')
local FileOps = require('TemplateBrowser.domain.file_ops')
local TreeViewModule = require('TemplateBrowser.ui.views.tree_view')
local Helpers = require('TemplateBrowser.ui.views.helpers')
local UI = require('TemplateBrowser.ui.ui_constants')

local M = {}

-- Custom collapsible header with minimal design (bold text, no fill, no borders)
local function draw_custom_collapsible_header(ctx, label, is_open, width, config)
  local header_height = 24
  local padding = 4

  -- Get position
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)

  -- Invisible button for interaction
  ImGui.InvisibleButton(ctx, "##header_" .. label, width, header_height)
  local clicked = ImGui.IsItemClicked(ctx)
  local hovered = ImGui.IsItemHovered(ctx)

  -- Very subtle hover background (optional - can be removed for pure minimal)
  if hovered then
    local hover_color = Colors.hexrgba(config.COLORS.header_hover or config.COLORS.header_bg, 0.3) -- 30% alpha
    ImGui.DrawList_AddRectFilled(dl, x, y, x + width, y + header_height, hover_color, 0)
  end

  -- Draw chevron icon (left-aligned)
  local chevron = is_open and "▼" or "▶"
  local chevron_x = x + padding
  local chevron_y = y + (header_height - ImGui.GetTextLineHeight(ctx)) / 2

  ImGui.DrawList_AddText(dl, chevron_x, chevron_y, config.COLORS.text, chevron)

  -- Calculate chevron width for text offset
  local chevron_width = ImGui.CalcTextSize(ctx, chevron)

  -- Draw label text (bold) - we'll use regular font but with slight offset for "bold" effect
  local text_x = chevron_x + chevron_width + padding * 2
  local text_y = chevron_y

  -- Draw text with slight shadow for bold effect
  ImGui.DrawList_AddText(dl, text_x + 0.5, text_y + 0.5, Colors.hexrgba(config.COLORS.text, 0.5), label)
  ImGui.DrawList_AddText(dl, text_x, text_y, config.COLORS.text, label)

  return clicked
end

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

-- Draw directory content (folder trees only - tags moved to convenience panel)
function M.draw(ctx, state, config, width, height, gui)
  -- Use full height for directory trees
  local folder_section_height = height

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

  -- Initialize section heights from state (3 sections: Physical, Virtual, Archive)
  local separator_height = 3  -- Thin 3-pixel separator line
  local min_section_height = 80
  local header_height = 24  -- Custom collapsible header height

  -- Initialize stored section height ratios if not set
  state.physical_section_height = state.physical_section_height or math.floor(total_tree_height * 0.40)
  state.virtual_section_height = state.virtual_section_height or math.floor(total_tree_height * 0.30)

  -- Track section open states (initialize if not set)
  state.physical_section_open = state.physical_section_open == nil and true or state.physical_section_open
  state.virtual_section_open = state.virtual_section_open == nil and true or state.virtual_section_open
  state.archive_section_open = state.archive_section_open == nil and true or state.archive_section_open

  -- Count open sections and calculate available height
  local open_sections = {}
  if state.physical_section_open then table.insert(open_sections, "physical") end
  if state.virtual_section_open then table.insert(open_sections, "virtual") end
  if state.archive_section_open then table.insert(open_sections, "archive") end

  local num_open = #open_sections
  local num_closed = 3 - num_open
  local num_separators = math.max(0, num_open - 1)  -- Separators only between open sections

  -- Calculate available height for open sections
  local closed_headers_height = num_closed * header_height
  local separators_total_height = num_separators * separator_height
  local available_height = total_tree_height - closed_headers_height - separators_total_height

  -- Distribute available height among open sections based on their stored ratios
  local physical_actual_height, virtual_actual_height, archive_actual_height

  if num_open == 0 then
    -- All collapsed
    physical_actual_height = header_height
    virtual_actual_height = header_height
    archive_actual_height = header_height
  elseif num_open == 1 then
    -- One open - takes all available height
    physical_actual_height = state.physical_section_open and available_height or header_height
    virtual_actual_height = state.virtual_section_open and available_height or header_height
    archive_actual_height = state.archive_section_open and available_height or header_height
  elseif num_open == 2 then
    -- Two open - distribute based on ratios
    if state.physical_section_open and state.virtual_section_open then
      local total_ratio = state.physical_section_height + state.virtual_section_height
      physical_actual_height = math.floor(available_height * (state.physical_section_height / total_ratio))
      virtual_actual_height = available_height - physical_actual_height
      archive_actual_height = header_height
    elseif state.physical_section_open and state.archive_section_open then
      local archive_stored = total_tree_height - state.physical_section_height - state.virtual_section_height - separator_height * 2
      local total_ratio = state.physical_section_height + archive_stored
      physical_actual_height = math.floor(available_height * (state.physical_section_height / total_ratio))
      archive_actual_height = available_height - physical_actual_height
      virtual_actual_height = header_height
    else  -- virtual and archive open
      local archive_stored = total_tree_height - state.physical_section_height - state.virtual_section_height - separator_height * 2
      local total_ratio = state.virtual_section_height + archive_stored
      virtual_actual_height = math.floor(available_height * (state.virtual_section_height / total_ratio))
      archive_actual_height = available_height - virtual_actual_height
      physical_actual_height = header_height
    end
  else
    -- All three open - use normal distribution
    state.physical_section_height = math.max(min_section_height, math.min(state.physical_section_height,
      total_tree_height - min_section_height * 2 - separator_height * 2))
    state.virtual_section_height = math.max(min_section_height, math.min(state.virtual_section_height,
      total_tree_height - state.physical_section_height - min_section_height - separator_height * 2))

    physical_actual_height = state.physical_section_height
    virtual_actual_height = state.virtual_section_height
    archive_actual_height = total_tree_height - state.physical_section_height - state.virtual_section_height - separator_height * 2
  end

  -- Initialize hover tracking and drag state for separators
  state.sep1_hover_time = state.sep1_hover_time or 0
  state.sep2_hover_time = state.sep2_hover_time or 0
  state.sep1_drag_start_height = state.sep1_drag_start_height or nil
  state.sep2_drag_start_height = state.sep2_drag_start_height or nil
  local hover_threshold = 1.0  -- 1 second

  -- Helper function to draw thin separator line above header
  local function draw_thin_separator(ctx, dl, x, y, width, is_hovered, hover_time)
    local line_color = Colors.hexrgb("#333333")  -- Default dark

    -- If hovered for more than 1 second, highlight light grey
    if is_hovered and hover_time >= hover_threshold then
      line_color = Colors.hexrgb("#666666")  -- Light grey highlight
    end

    -- Draw thin horizontal line
    ImGui.DrawList_AddLine(dl, x, y, x + width, y, line_color, separator_height)
  end

  local dl = ImGui.GetWindowDrawList(ctx)

  -- === PHYSICAL DIRECTORY SECTION (no separator above first section) ===
  local physical_clicked = draw_custom_collapsible_header(ctx, "Physical Directory", state.physical_section_open, width, config)

  -- Update open state on click
  if physical_clicked then
    state.physical_section_open = not state.physical_section_open
  end
  local physical_open = state.physical_section_open

  if physical_open then
    local scroll_height = physical_actual_height - header_height
    if scroll_height > 10 and Helpers.begin_child_compat(ctx, "PhysicalTreeScroll", 0, scroll_height, false) then
      TreeViewModule.draw_physical_tree(ctx, state, config)
      ImGui.EndChild(ctx)
    end
  end

  -- === SEPARATOR 1 (before Virtual Directory) - only if physical is open ===
  if physical_open then
    local sep1_x, sep1_y = ImGui.GetCursorScreenPos(ctx)
    local mx, my = ImGui.GetMousePos(ctx)
    local sep1_hovered = mx >= sep1_x and mx < sep1_x + width and
                         my >= sep1_y and my < sep1_y + separator_height + 4

    -- Track hover time
    if sep1_hovered then
      state.sep1_hover_time = state.sep1_hover_time + (1/60)  -- Approximate frame time
    else
      state.sep1_hover_time = 0
    end

    -- Draw separator line
    draw_thin_separator(ctx, dl, sep1_x, sep1_y + separator_height / 2, width, sep1_hovered, state.sep1_hover_time)

    -- Invisible button for drag interaction (only if virtual is also open)
    ImGui.SetCursorScreenPos(ctx, sep1_x, sep1_y - 2)
    ImGui.InvisibleButton(ctx, "##sep1", width, separator_height + 4)

    if ImGui.IsItemHovered(ctx) then
      ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeNS)
    end

    -- Handle drag with proper initial height tracking (only when both sections open)
    if num_open >= 2 and ImGui.IsItemActive(ctx) then
      if not state.sep1_drag_start_height then
        state.sep1_drag_start_height = state.physical_section_height
      end
      local _, delta_y = ImGui.GetMouseDragDelta(ctx, 0, 0)
      state.physical_section_height = state.sep1_drag_start_height + delta_y
      state.physical_section_height = math.max(min_section_height,
        math.min(state.physical_section_height,
          total_tree_height - min_section_height * 2 - separator_height * 2))
    else
      state.sep1_drag_start_height = nil
    end

    ImGui.SetCursorScreenPos(ctx, sep1_x, sep1_y + separator_height)
  end

  -- === VIRTUAL DIRECTORY SECTION ===
  local virtual_clicked = draw_custom_collapsible_header(ctx, "Virtual Directory", state.virtual_section_open, width, config)

  -- Update open state on click
  if virtual_clicked then
    state.virtual_section_open = not state.virtual_section_open
  end
  local virtual_open = state.virtual_section_open

  if virtual_open then
    local scroll_height = virtual_actual_height - header_height
    if scroll_height > 10 and Helpers.begin_child_compat(ctx, "VirtualTreeScroll", 0, scroll_height, false) then
      TreeViewModule.draw_virtual_tree(ctx, state, config)
      ImGui.EndChild(ctx)
    end
  end

  -- === SEPARATOR 2 (before Archive) - only if virtual is open ===
  if virtual_open then
    local sep2_x, sep2_y = ImGui.GetCursorScreenPos(ctx)
    local mx, my = ImGui.GetMousePos(ctx)
    local sep2_hovered = mx >= sep2_x and mx < sep2_x + width and
                         my >= sep2_y and my < sep2_y + separator_height + 4

    -- Track hover time
    if sep2_hovered then
      state.sep2_hover_time = state.sep2_hover_time + (1/60)
    else
      state.sep2_hover_time = 0
    end

    -- Draw separator line
    draw_thin_separator(ctx, dl, sep2_x, sep2_y + separator_height / 2, width, sep2_hovered, state.sep2_hover_time)

    -- Invisible button for drag interaction
    ImGui.SetCursorScreenPos(ctx, sep2_x, sep2_y - 2)
    ImGui.InvisibleButton(ctx, "##sep2", width, separator_height + 4)

    if ImGui.IsItemHovered(ctx) then
      ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeNS)
    end

    -- Handle drag with proper initial height tracking (only when multiple sections open)
    if num_open >= 2 and ImGui.IsItemActive(ctx) then
      if not state.sep2_drag_start_height then
        state.sep2_drag_start_height = state.virtual_section_height
      end
      local _, delta_y = ImGui.GetMouseDragDelta(ctx, 0, 0)
      state.virtual_section_height = state.sep2_drag_start_height + delta_y
      state.virtual_section_height = math.max(min_section_height,
        math.min(state.virtual_section_height,
          total_tree_height - state.physical_section_height - min_section_height - separator_height * 2))
    else
      state.sep2_drag_start_height = nil
    end

    ImGui.SetCursorScreenPos(ctx, sep2_x, sep2_y + separator_height)
  end

  -- === ARCHIVE SECTION ===
  local archive_clicked = draw_custom_collapsible_header(ctx, "Archive", state.archive_section_open, width, config)

  -- Update open state on click
  if archive_clicked then
    state.archive_section_open = not state.archive_section_open
  end
  local archive_open = state.archive_section_open

  if archive_open then
    local scroll_height = archive_actual_height - header_height
    if scroll_height > 10 and Helpers.begin_child_compat(ctx, "ArchiveTreeScroll", 0, scroll_height, false) then
      TreeViewModule.draw_archive_tree(ctx, state, config)
      ImGui.EndChild(ctx)
    end
  end
end

return M

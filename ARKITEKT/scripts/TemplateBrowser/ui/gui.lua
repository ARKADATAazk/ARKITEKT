-- @noindex
-- TemplateBrowser/ui/gui.lua
-- Main GUI with three-panel layout

local ImGui = require 'imgui' '0.10'
local TemplateOps = require('TemplateBrowser.domain.template_ops')

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
  }, GUI)

  return self
end

function GUI:initialize_once(ctx)
  if self.initialized then return end
  self.ctx = ctx
  self.initialized = true
end

-- Draw folder tree recursively
local function draw_folder_node(ctx, node, state, config)
  local is_selected = (state.selected_folder == node.path)
  local has_children = #node.children > 0

  -- Build unique label: "FolderName##unique_id"
  -- Sanitize path for use as ID (replace ALL non-alphanumeric chars)
  local safe_id = (node.path ~= "" and node.path or "root"):gsub("[^%w]", "_")
  local label = node.name .. "##folder_" .. safe_id

  -- Set up flags
  local flags = ImGui.TreeNodeFlags_OpenOnArrow
    | ImGui.TreeNodeFlags_OpenOnDoubleClick
    | ImGui.TreeNodeFlags_SpanAvailWidth

  if is_selected then
    flags = flags | ImGui.TreeNodeFlags_Selected
  end

  if not has_children then
    flags = flags | ImGui.TreeNodeFlags_Leaf
  end

  -- Draw the tree node: TreeNodeEx(ctx, label, flags)
  local node_open = ImGui.TreeNodeEx(ctx, label, flags)

  -- Check for click
  if ImGui.IsItemClicked(ctx) then
    state.selected_folder = node.path
    local Scanner = require('TemplateBrowser.domain.scanner')
    Scanner.filter_templates(state)
  end

  -- Draw children and always pop if opened
  if node_open then
    for _, child in ipairs(node.children) do
      draw_folder_node(ctx, child, state, config)
    end
    ImGui.TreePop(ctx)
  end
end

-- Draw folder panel (left)
local function draw_folder_panel(ctx, state, config, width, height)
  BeginChildCompat(ctx, "FolderPanel", width, height, true)

  -- Header
  ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.header_bg)
  ImGui.SeparatorText(ctx, "Folders")
  ImGui.PopStyleColor(ctx)

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

    if is_selected then
      ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.selected_bg)
    end

    local label = tmpl.name
    if tmpl.relative_path ~= "" then
      label = label .. "  [" .. tmpl.folder .. "]"
    end

    if ImGui.Selectable(ctx, label .. "##" .. i, is_selected, nil, 0, config.TEMPLATE_ITEM_HEIGHT) then
      state.selected_template = tmpl
    end

    -- Double-click to apply
    if ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
      -- TODO: Apply template
      reaper.ShowConsoleMsg("Apply template: " .. tmpl.name .. "\n")
    end

    if is_selected then
      ImGui.PopStyleColor(ctx)
    end
  end

  ImGui.EndChild(ctx)
  ImGui.EndChild(ctx)
end

-- Draw tags/info panel (right)
local function draw_tags_panel(ctx, state, config, width, height)
  BeginChildCompat(ctx, "TagsPanel", width, height, true)

  -- Header
  ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.header_bg)
  ImGui.SeparatorText(ctx, "Info & Tags")
  ImGui.PopStyleColor(ctx)

  ImGui.Spacing(ctx)

  if state.selected_template then
    local tmpl = state.selected_template

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

    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    -- Tags (placeholder)
    ImGui.Text(ctx, "Tags:")
    ImGui.Spacing(ctx)
    ImGui.TextDisabled(ctx, "Tag system coming soon...")

  else
    ImGui.TextDisabled(ctx, "Select a template to view details")
  end

  ImGui.EndChild(ctx)
end

function GUI:draw(ctx, shell_state)
  self:initialize_once(ctx)

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

  -- Calculate panel widths
  local total_width = SCREEN_W - (self.config.PANEL_SPACING * 4)
  local folder_width = total_width * self.config.FOLDERS_PANEL_WIDTH_RATIO
  local template_width = total_width * self.config.TEMPLATES_PANEL_WIDTH_RATIO
  local tags_width = total_width * self.config.TAGS_PANEL_WIDTH_RATIO
  local panel_height = SCREEN_H - (self.config.PANEL_SPACING * 2)

  -- Title
  ImGui.PushFont(ctx, shell_state.fonts.title, shell_state.fonts.title_size)
  local title = "Template Browser"
  local title_w = ImGui.CalcTextSize(ctx, title)
  ImGui.SetCursorPosX(ctx, (SCREEN_W - title_w) * 0.5)
  ImGui.Text(ctx, title)
  ImGui.PopFont(ctx)

  ImGui.Spacing(ctx)
  ImGui.Spacing(ctx)

  -- Three-panel layout
  local cursor_y = ImGui.GetCursorPosY(ctx)

  -- Left panel: Folders
  ImGui.SetCursorPos(ctx, self.config.PANEL_SPACING, cursor_y)
  draw_folder_panel(ctx, self.state, self.config, folder_width, panel_height)

  -- Middle panel: Templates
  ImGui.SameLine(ctx, 0, self.config.PANEL_SPACING)
  draw_template_panel(ctx, self.state, self.config, template_width, panel_height)

  -- Right panel: Tags/Info
  ImGui.SameLine(ctx, 0, self.config.PANEL_SPACING)
  draw_tags_panel(ctx, self.state, self.config, tags_width, panel_height)

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

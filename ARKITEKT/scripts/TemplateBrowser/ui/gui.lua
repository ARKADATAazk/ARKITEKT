-- @noindex
-- TemplateBrowser/ui/gui.lua
-- Main GUI with three-panel layout

local ImGui = require 'imgui' '0.10'

local M = {}
local GUI = {}
GUI.__index = GUI

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
local function draw_folder_node(ctx, node, state, config, level)
  level = level or 0
  local clicked = false

  -- Indentation
  if level > 0 then
    ImGui.Indent(ctx, 16)
  end

  -- Folder item
  local is_selected = (state.selected_folder == node.path)
  local flags = ImGui.TreeNodeFlags_OpenOnArrow
    | ImGui.TreeNodeFlags_OpenOnDoubleClick
    | ImGui.TreeNodeFlags_SpanAvailWidth

  if is_selected then
    flags = flags | ImGui.TreeNodeFlags_Selected
  end

  if #node.children == 0 then
    flags = flags | ImGui.TreeNodeFlags_Leaf | ImGui.TreeNodeFlags_NoTreePushOnOpen
  end

  local node_open = ImGui.TreeNodeEx(ctx, node.name .. "##" .. node.path, flags)

  if ImGui.IsItemClicked(ctx) then
    state.selected_folder = node.path
    local Scanner = require('TemplateBrowser.domain.scanner')
    Scanner.filter_templates(state)
    clicked = true
  end

  -- Draw children
  if node_open and #node.children > 0 then
    for _, child in ipairs(node.children) do
      draw_folder_node(ctx, child, state, config, level + 1)
    end
    ImGui.TreePop(ctx)
  end

  if level > 0 then
    ImGui.Unindent(ctx, 16)
  end

  return clicked
end

-- Draw folder panel (left)
local function draw_folder_panel(ctx, state, config, width, height)
  ImGui.BeginChild(ctx, "FolderPanel", width, height, ImGui.ChildFlags_Border)

  -- Header
  ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.header_bg)
  ImGui.SeparatorText(ctx, "Folders")
  ImGui.PopStyleColor(ctx)

  ImGui.Spacing()

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
  ImGui.Spacing()

  -- Folder tree
  if state.folders and state.folders.children then
    for _, child in ipairs(state.folders.children) do
      draw_folder_node(ctx, child, state, config, 0)
    end
  end

  ImGui.EndChild(ctx)
end

-- Draw template list panel (middle)
local function draw_template_panel(ctx, state, config, width, height)
  ImGui.BeginChild(ctx, "TemplatePanel", width, height, ImGui.ChildFlags_Border)

  -- Header with search
  ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.header_bg)
  ImGui.SeparatorText(ctx, "Templates")
  ImGui.PopStyleColor(ctx)

  ImGui.Spacing()

  -- Search box
  ImGui.SetNextItemWidth(ctx, -1)
  local changed, new_query = ImGui.InputTextWithHint(ctx, "##search", "Search templates...", state.search_query)
  if changed then
    state.search_query = new_query
    local Scanner = require('TemplateBrowser.domain.scanner')
    Scanner.filter_templates(state)
  end

  ImGui.Spacing()
  ImGui.Separator(ctx)
  ImGui.Spacing()

  -- Template count
  local count = #state.filtered_templates
  ImGui.Text(ctx, string.format("%d template%s", count, count == 1 and "" or "s"))
  ImGui.Separator(ctx)

  -- Template list
  ImGui.BeginChild(ctx, "TemplateList", 0, 0)

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
  ImGui.BeginChild(ctx, "TagsPanel", width, height, ImGui.ChildFlags_Border)

  -- Header
  ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.header_bg)
  ImGui.SeparatorText(ctx, "Info & Tags")
  ImGui.PopStyleColor(ctx)

  ImGui.Spacing()

  if state.selected_template then
    local tmpl = state.selected_template

    -- Template info
    ImGui.Text(ctx, "Name:")
    ImGui.Indent(ctx, 10)
    ImGui.TextWrapped(ctx, tmpl.name)
    ImGui.Unindent(ctx, 10)

    ImGui.Spacing()
    ImGui.Text(ctx, "Location:")
    ImGui.Indent(ctx, 10)
    ImGui.TextWrapped(ctx, tmpl.folder)
    ImGui.Unindent(ctx, 10)

    ImGui.Spacing()
    ImGui.Separator(ctx)
    ImGui.Spacing()

    -- Actions
    if ImGui.Button(ctx, "Apply to Selected Track", -1, 32) then
      -- TODO: Apply template to selected track
      reaper.ShowConsoleMsg("Apply template to selected track: " .. tmpl.name .. "\n")
    end

    if ImGui.Button(ctx, "Insert as New Track", -1, 32) then
      -- TODO: Insert template as new track
      reaper.ShowConsoleMsg("Insert template as new track: " .. tmpl.name .. "\n")
    end

    ImGui.Spacing()
    ImGui.Separator(ctx)
    ImGui.Spacing()

    -- Tags (placeholder)
    ImGui.Text(ctx, "Tags:")
    ImGui.Spacing()
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

  ImGui.Spacing()
  ImGui.Spacing()

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

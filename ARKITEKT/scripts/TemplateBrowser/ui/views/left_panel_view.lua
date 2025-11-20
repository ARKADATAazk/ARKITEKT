-- @noindex
-- TemplateBrowser/ui/views/left_panel_view.lua
-- Left tabbed panel: Directory / VSTs / Tags

local ImGui = require 'imgui' '0.10'
local TreeView = require('rearkitekt.gui.widgets.navigation.tree_view')
local Tabs = require('rearkitekt.gui.widgets.navigation.tabs')
local Button = require('rearkitekt.gui.widgets.primitives.button')
local Chip = require('rearkitekt.gui.widgets.data.chip')
local Tags = require('TemplateBrowser.domain.tags')
local FileOps = require('TemplateBrowser.domain.file_ops')
local Colors = require('rearkitekt.core.colors')

local M = {}
local LeftPanelView = {}
LeftPanelView.__index = LeftPanelView

function M.new(config, state)
  local self = setmetatable({
    config = config,
    state = state,
  }, LeftPanelView)

  return self
end

-- ImGui compatibility for BeginChild
local function BeginChildCompat(ctx, id, w, h, want_border, window_flags)
  local child_flags = want_border and 1 or 0
  return ImGui.BeginChild(ctx, id, w, h, child_flags, window_flags or 0)
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
          path = vfolder.id,
          is_virtual = true,
          template_refs = vfolder.template_refs or {},
          color = vfolder.color,
          children = build_virtual_tree(vfolder.id),
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
    id = "__ROOT__",
    name = "Physical Root",
    path = "",
    full_path = template_path,
    children = {},
    is_root = true,
    is_virtual = false,
  }

  -- Add all physical folders as children of Physical Root
  if node.children then
    for _, child in ipairs(node.children) do
      table.insert(physical_root.children, convert_physical_node(child))
    end
  end

  table.insert(root_nodes, physical_root)

  -- Add Virtual Root node
  local virtual_root = {
    id = "__VIRTUAL_ROOT__",
    name = "Virtual Root",
    path = "__VIRTUAL_ROOT__",
    children = build_virtual_tree("__VIRTUAL_ROOT__"),
    is_root = true,
    is_virtual = true,
  }

  table.insert(root_nodes, virtual_root)

  return root_nodes
end

-- NOTE: This is a simplified extraction. The full implementation would need
-- to extract all the TreeView callbacks (on_drop_folder, on_drop_template, etc.)
-- For now, referencing the full implementation in the original gui.lua

function LeftPanelView:draw(ctx, width, height)
  BeginChildCompat(ctx, "LeftPanel", width, height, true)

  -- Count active filters for badges
  local fx_filter_count = 0
  for _ in pairs(self.state.filter_fx) do
    fx_filter_count = fx_filter_count + 1
  end

  local tag_filter_count = 0
  for _ in pairs(self.state.filter_tags) do
    tag_filter_count = tag_filter_count + 1
  end

  -- Draw tabs
  local tabs_def = {
    { id = "directory", label = "DIRECTORY" },
    { id = "vsts", label = "VSTS" },
    { id = "tags", label = "TAGS" },
  }

  local clicked_tab = Tabs.draw_at_cursor(ctx, tabs_def, self.state.left_panel_tab, {
    height = 24,
    available_width = width,
    bg_color = self.config.COLORS.header_bg,
    active_color = self.config.COLORS.selected_bg,
    text_color = self.config.COLORS.text,
  })

  if clicked_tab then
    self.state.left_panel_tab = clicked_tab
  end

  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Draw content based on active tab
  local content_height = height - 35

  if self.state.left_panel_tab == "directory" then
    self:draw_directory_content(ctx, width, content_height)
  elseif self.state.left_panel_tab == "vsts" then
    self:draw_vsts_content(ctx, width, content_height)
  elseif self.state.left_panel_tab == "tags" then
    self:draw_tags_content(ctx, width, content_height)
  end

  ImGui.EndChild(ctx)
end

function LeftPanelView:draw_directory_content(ctx, width, height)
  -- TODO: Extract full directory content rendering
  -- For now, display placeholder
  ImGui.Text(ctx, "Directory view (to be extracted)")
end

function LeftPanelView:draw_vsts_content(ctx, width, height)
  -- TODO: Extract full VSTs content rendering
  ImGui.Text(ctx, "VSTs view (to be extracted)")
end

function LeftPanelView:draw_tags_content(ctx, width, height)
  -- TODO: Extract full tags content rendering
  ImGui.Text(ctx, "Tags view (to be extracted)")
end

return M

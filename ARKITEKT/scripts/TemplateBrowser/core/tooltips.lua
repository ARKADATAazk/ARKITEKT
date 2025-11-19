-- @noindex
-- TemplateBrowser/core/tooltips.lua
-- Tooltip configuration and utilities

local M = {}

-- Tooltip strings storage
M.TOOLTIPS = {
  -- Template actions
  template_apply = "Apply template to selected track\nShortcut: Enter",
  template_insert = "Insert template as new track\nShortcut: Shift+Enter",
  template_rename = "Rename template\nShortcut: F2",
  template_archive = "Archive template (safe deletion)\nShortcut: Delete",
  template_star = "Add to Favorites",
  template_unstar = "Remove from Favorites",

  -- Folder actions
  folder_create_physical = "Create physical folder (filesystem)",
  folder_create_virtual = "Create virtual folder (metadata only)",
  folder_rename = "Rename folder\nDouble-click to rename",
  folder_color = "Set folder color",
  folder_delete_virtual = "Delete virtual folder (templates not affected)",

  -- Search and filter
  search_box = "Search templates by name\nShortcut: Ctrl+F",
  sort_alphabetical = "Sort alphabetically",
  sort_usage = "Sort by usage count (most used first)",
  sort_insertion = "Sort by insertion date (newest first)",
  sort_color = "Sort by color (colored first)",
  filter_clear = "Clear all active filters",

  -- Tags
  tag_create = "Create new tag",
  tag_rename = "Double-click to rename tag",
  tag_assign = "Click to assign/unassign tag",
  tag_filter = "Click to filter by this tag",

  -- VSTs
  vst_filter = "Click to filter templates with this VST",
  vst_reparse = "Force re-scan all templates for VSTs\nClick twice to confirm",

  -- Virtual folders
  virtual_folder_info = "Virtual folder - templates can be in multiple virtual folders",
  favorites_folder = "Favorites folder - click star on templates to add here",

  -- Archive
  archive_folder = "Archive folder - safely stores deleted files",

  -- Notes
  notes_field = "Template notes - use for descriptions, credits, etc.",

  -- Status bar
  status_message = "Status messages appear here",
}

-- Tooltip configuration
M.CONFIG = {
  delay = 0.5,        -- Delay in seconds before showing tooltip
  wrap_width = 300,   -- Maximum width for tooltip text wrapping
  bg_color = 0x1E1E1EFF,  -- Dark background
  border_color = 0x4A4A4AFF,  -- Medium border
  text_color = 0xFFFFFFFF,  -- White text
  padding = 8,        -- Internal padding
}

-- Show a tooltip if mouse is hovering
-- Returns: true if tooltip was shown
function M.show(ctx, ImGui, tooltip_id, custom_text)
  if not tooltip_id then return false end

  -- Get tooltip text (custom or from storage)
  local text = custom_text or M.TOOLTIPS[tooltip_id]
  if not text then return false end

  -- Show tooltip if item is hovered
  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_DelayNormal) then
    ImGui.BeginTooltip(ctx)
    ImGui.PushTextWrapPos(ctx, M.CONFIG.wrap_width)
    ImGui.Text(ctx, text)
    ImGui.PopTextWrapPos(ctx)
    ImGui.EndTooltip(ctx)
    return true
  end

  return false
end

-- Show tooltip for a template with detailed information
function M.show_template_info(ctx, ImGui, template, metadata)
  if not template then return false end

  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_DelayNormal) then
    local tmpl_meta = metadata and metadata.templates[template.uuid]

    ImGui.BeginTooltip(ctx)
    ImGui.PushTextWrapPos(ctx, M.CONFIG.wrap_width)

    -- Template name
    ImGui.Text(ctx, template.name)
    ImGui.Separator(ctx)

    -- Location
    if template.folder and template.folder ~= "Root" then
      ImGui.Text(ctx, "Location: " .. template.folder)
    end

    -- VSTs
    if template.fx and #template.fx > 0 then
      ImGui.Text(ctx, string.format("VSTs: %d", #template.fx))
      if #template.fx <= 5 then
        ImGui.Indent(ctx, 10)
        for _, fx_name in ipairs(template.fx) do
          ImGui.BulletText(ctx, fx_name)
        end
        ImGui.Unindent(ctx, 10)
      else
        ImGui.Text(ctx, "  " .. table.concat(template.fx, ", ", 1, 3) .. string.format("... +%d more", #template.fx - 3))
      end
    end

    -- Tags
    if tmpl_meta and tmpl_meta.tags and #tmpl_meta.tags > 0 then
      ImGui.Text(ctx, "Tags: " .. table.concat(tmpl_meta.tags, ", "))
    end

    -- Usage stats
    if tmpl_meta then
      if tmpl_meta.usage_count and tmpl_meta.usage_count > 0 then
        ImGui.Text(ctx, string.format("Used: %d times", tmpl_meta.usage_count))
      end

      if tmpl_meta.last_used then
        local last_used_date = os.date("%Y-%m-%d %H:%M", tmpl_meta.last_used)
        ImGui.Text(ctx, "Last used: " .. last_used_date)
      end

      if tmpl_meta.created then
        local created_date = os.date("%Y-%m-%d", tmpl_meta.created)
        ImGui.Text(ctx, "Added: " .. created_date)
      end
    end

    -- Notes preview
    if tmpl_meta and tmpl_meta.notes and tmpl_meta.notes ~= "" then
      ImGui.Separator(ctx)
      local preview = tmpl_meta.notes
      if #preview > 100 then
        preview = preview:sub(1, 100) .. "..."
      end
      ImGui.TextWrapped(ctx, preview)
    end

    ImGui.PopTextWrapPos(ctx)
    ImGui.EndTooltip(ctx)
    return true
  end

  return false
end

-- Show tooltip for a folder with information
function M.show_folder_info(ctx, ImGui, folder_node, templates_count)
  if not folder_node then return false end

  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_DelayNormal) then
    ImGui.BeginTooltip(ctx)
    ImGui.PushTextWrapPos(ctx, M.CONFIG.wrap_width)

    ImGui.Text(ctx, folder_node.name)
    ImGui.Separator(ctx)

    if folder_node.is_virtual then
      ImGui.Text(ctx, "Type: Virtual Folder")
      if folder_node.template_refs then
        ImGui.Text(ctx, string.format("Templates: %d", #folder_node.template_refs))
      end
    else
      ImGui.Text(ctx, "Type: Physical Folder")
      if templates_count then
        ImGui.Text(ctx, string.format("Templates: %d", templates_count))
      end
    end

    if folder_node.path and folder_node.path ~= "" then
      ImGui.Text(ctx, "Path: " .. folder_node.path)
    end

    ImGui.PopTextWrapPos(ctx)
    ImGui.EndTooltip(ctx)
    return true
  end

  return false
end

-- Show a simple text tooltip
function M.show_text(ctx, ImGui, text)
  if not text then return false end

  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_DelayNormal) then
    ImGui.BeginTooltip(ctx)
    ImGui.PushTextWrapPos(ctx, M.CONFIG.wrap_width)
    ImGui.Text(ctx, text)
    ImGui.PopTextWrapPos(ctx)
    ImGui.EndTooltip(ctx)
    return true
  end

  return false
end

return M

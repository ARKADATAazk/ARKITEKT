-- @noindex
-- TemplateBrowser/ui/tooltips.lua
-- Tooltip configuration and utilities

local Strings = require('TemplateBrowser.defs.strings')
local Defaults = require('TemplateBrowser.defs.defaults')
local TrackParser = require('TemplateBrowser.domain.template.track_parser')

local M = {}

-- Re-export from defs for backward compatibility
M.TOOLTIPS = Strings.TOOLTIPS
M.CONFIG = Defaults.TOOLTIP

-- Track tree cache (in-memory, keyed by template path)
local track_tree_cache = {}

-- Clear track tree cache (call when templates are rescanned)
function M.clear_track_cache()
  track_tree_cache = {}
end

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

    -- Track tree (lazy-loaded and cached)
    local track_count = template.track_count or 1
    if track_count > 0 then
      -- Get or parse track tree
      local track_tree = track_tree_cache[template.path]
      if track_tree == nil then
        -- Parse on first hover (nil means not yet parsed)
        track_tree = TrackParser.parse_track_tree(template.path) or false
        track_tree_cache[template.path] = track_tree
      end

      if track_tree and #track_tree > 0 then
        ImGui.Text(ctx, string.format("Tracks: %d", #track_tree))
        -- Show track tree with indentation (limit to 8 tracks for tooltip)
        local max_display = 8
        for i, track in ipairs(track_tree) do
          if i > max_display then
            ImGui.TextDisabled(ctx, string.format("  ... +%d more", #track_tree - max_display))
            break
          end
          -- Indent based on depth, add folder icon for folder tracks
          local indent = string.rep("  ", track.depth)
          local icon = track.is_folder and "▸ " or "• "
          ImGui.TextDisabled(ctx, indent .. icon .. track.name)
        end
      elseif track_count > 1 then
        -- Fallback if parsing failed but we know there are multiple tracks
        ImGui.Text(ctx, string.format("Tracks: %d", track_count))
      end
    end

    -- Location
    if template.folder and template.folder ~= "Root" and template.folder ~= "" then
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

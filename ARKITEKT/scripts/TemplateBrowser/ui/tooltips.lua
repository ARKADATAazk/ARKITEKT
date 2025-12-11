-- @noindex
-- TemplateBrowser/ui/tooltips.lua
-- Tooltip configuration and utilities

local Strings = require('TemplateBrowser.config.strings')
local Constants = require('TemplateBrowser.config.constants')
local Stats = require('TemplateBrowser.domain.template.stats')

local M = {}

M.TOOLTIPS = Strings.TOOLTIPS
M.CONFIG = Constants.TOOLTIP

-- Tooltip color scheme
local COLORS = {
  header = 0xFFFFFFFF,      -- White for section headers (Tracks:, VSTs:)
  track_default = 0xCCDDFFFF, -- Light blue for tracks without color
  vst = 0xE0A0FFFF,         -- Purple/magenta for VSTs
  tag = 0xA0FFD0FF,         -- Mint/teal for tags
  location = 0xB0B0B0FF,    -- Grey for location
  stats = 0x909090FF,       -- Dimmed for stats/dates
  notes = 0xA0A0A0FF,       -- Grey for notes
}

-- Lighten a color for text (blend toward white)
local function lighten_color(color, amount)
  if not color then return nil end
  amount = amount or 0.4
  local r = math.floor(color / 0x1000000) % 256
  local g = math.floor(color / 0x10000) % 256
  local b = math.floor(color / 0x100) % 256
  local a = color % 256
  r = math.floor(r + (255 - r) * amount)
  g = math.floor(g + (255 - g) * amount)
  b = math.floor(b + (255 - b) * amount)
  return r * 0x1000000 + g * 0x10000 + b * 0x100 + a
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

-- Cached indent strings to avoid repeated concatenation
local INDENT_CACHE = { [0] = '' }
for i = 1, 10 do INDENT_CACHE[i] = INDENT_CACHE[i-1] .. '  ' end

-- Show tooltip for a template with detailed information
function M.show_template_info(ctx, ImGui, template, metadata)
  if not template then return false end

  -- Use DelayShort for faster tooltip appearance
  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_DelayShort) then
    local tmpl_meta = metadata and metadata.templates[template.uuid]

    ImGui.BeginTooltip(ctx)
    ImGui.PushTextWrapPos(ctx, M.CONFIG.wrap_width)

    -- Template name
    ImGui.Text(ctx, template.name)
    ImGui.Separator(ctx)

    -- Track tree (from cached data - no file I/O on hover)
    local tracks = template.tracks or (tmpl_meta and tmpl_meta.tracks)
    local track_count = template.track_count or (tracks and #tracks) or 1

    if tracks and #tracks > 0 then
      local num_tracks = #tracks
      ImGui.TextColored(ctx, COLORS.header, 'Tracks: ' .. num_tracks)
      local max_display = 8
      local dl = ImGui.GetWindowDrawList(ctx)
      local text_height = ImGui.GetTextLineHeight(ctx)
      local swatch_size = text_height - 4

      -- Pre-compute "is_last" flags in single pass
      local is_last_at_depth = {}
      for i = num_tracks, 1, -1 do
        local d = tracks[i].depth
        if not is_last_at_depth[d] then
          is_last_at_depth[d] = i
        end
      end

      for i, track in ipairs(tracks) do
        if i > max_display then
          ImGui.TextColored(ctx, COLORS.stats, '  ... +' .. (num_tracks - max_display) .. ' more')
          break
        end

        local depth = track.depth
        local indent = INDENT_CACHE[depth] or INDENT_CACHE[10]
        local tree_char = depth > 0 and (is_last_at_depth[depth] == i and '└ ' or '├ ') or ''
        local folder_icon = track.is_folder and '▼ ' or ''
        local text_color = track.color and lighten_color(track.color, 0.3) or COLORS.track_default

        -- Draw color swatch inline if track has color
        if track.color then
          local cx, cy = ImGui.GetCursorScreenPos(ctx)
          ImGui.DrawList_AddRectFilled(dl, cx + 2, cy + 2, cx + 2 + swatch_size, cy + 2 + swatch_size, track.color)
          ImGui.Dummy(ctx, swatch_size + 6, 1)
          ImGui.SameLine(ctx)
          ImGui.TextColored(ctx, text_color, indent .. tree_char .. folder_icon .. track.name)
        else
          ImGui.TextColored(ctx, text_color, '  ' .. indent .. tree_char .. folder_icon .. track.name)
        end
      end
    elseif track_count > 1 then
      -- Fallback to just showing count if no track tree cached yet
      ImGui.TextColored(ctx, COLORS.header, string.format('Tracks: %d', track_count))
    end

    -- Location
    if template.folder and template.folder ~= 'Root' and template.folder ~= '' then
      ImGui.TextColored(ctx, COLORS.location, 'Location: ' .. template.folder)
    end

    -- VSTs
    if template.fx and #template.fx > 0 then
      ImGui.TextColored(ctx, COLORS.header, string.format('VSTs: %d', #template.fx))
      if #template.fx <= 5 then
        ImGui.Indent(ctx, 10)
        for _, fx_name in ipairs(template.fx) do
          ImGui.TextColored(ctx, COLORS.vst, '• ' .. fx_name)
        end
        ImGui.Unindent(ctx, 10)
      else
        ImGui.TextColored(ctx, COLORS.vst, '  ' .. table.concat(template.fx, ', ', 1, 3) .. string.format('... +%d more', #template.fx - 3))
      end
    end

    -- Tags
    if tmpl_meta and tmpl_meta.tags and #tmpl_meta.tags > 0 then
      ImGui.TextColored(ctx, COLORS.header, 'Tags: ')
      ImGui.SameLine(ctx)
      ImGui.TextColored(ctx, COLORS.tag, table.concat(tmpl_meta.tags, ', '))
    end

    -- Usage stats (enhanced with time-based analysis)
    if tmpl_meta then
      local usage_history = tmpl_meta.usage_history
      if usage_history and #usage_history > 0 then
        -- Use stats module for rich summary
        local stats = Stats.calculate_stats(usage_history)
        local summary = Stats.format_summary(stats)
        ImGui.TextColored(ctx, COLORS.stats, 'Usage: ' .. summary)
      elseif tmpl_meta.usage_count and tmpl_meta.usage_count > 0 then
        -- Fallback for old data without history
        ImGui.TextColored(ctx, COLORS.stats, string.format('Used: %d times', tmpl_meta.usage_count))
      end

      if tmpl_meta.last_used then
        local last_used_date = os.date('%Y-%m-%d %H:%M', tmpl_meta.last_used)
        ImGui.TextColored(ctx, COLORS.stats, 'Last used: ' .. last_used_date)
      end

      if tmpl_meta.created then
        local created_date = os.date('%Y-%m-%d', tmpl_meta.created)
        ImGui.TextColored(ctx, COLORS.stats, 'Added: ' .. created_date)
      end
    end

    -- Notes preview
    if tmpl_meta and tmpl_meta.notes and tmpl_meta.notes ~= '' then
      ImGui.Separator(ctx)
      local preview = tmpl_meta.notes
      if #preview > 100 then
        preview = preview:sub(1, 100) .. '...'
      end
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, COLORS.notes)
      ImGui.TextWrapped(ctx, preview)
      ImGui.PopStyleColor(ctx)
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
      ImGui.Text(ctx, 'Type: Virtual Folder')
      if folder_node.template_refs then
        ImGui.Text(ctx, string.format('Templates: %d', #folder_node.template_refs))
      end
    else
      ImGui.Text(ctx, 'Type: Physical Folder')
      if templates_count then
        ImGui.Text(ctx, string.format('Templates: %d', templates_count))
      end
    end

    if folder_node.path and folder_node.path ~= '' then
      ImGui.Text(ctx, 'Path: ' .. folder_node.path)
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

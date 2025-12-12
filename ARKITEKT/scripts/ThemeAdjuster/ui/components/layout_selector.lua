-- @noindex
-- ThemeAdjuster/ui/components/layout_selector.lua
-- Reusable layout selector component (A/B/C, size buttons, default layout)

local ImGui = require('arkitekt.core.imgui')
local Ark = require('arkitekt')
local ThemeParams = require('ThemeAdjuster.domain.theme.params')

local M = {}

-- Draw the layout selector section
-- @param ctx ImGui context
-- @param opts table {
--   panel: string - 'tcp' or 'mcp'
--   active_layout: string - Current layout ('A', 'B', 'C')
--   default_layout: string - Default layout for new tracks
--   id_prefix: string - ID prefix for buttons (e.g., 'tcp', 'mcp')
--   tooltip_strings: table - Strings table with set_default_layout tooltip
--   on_layout_change: function(layout) - Callback when layout changes
--   on_set_default: function(layout) - Callback when default is set
-- }
function M.draw(ctx, opts)
  local panel = opts.panel
  local active_layout = opts.active_layout
  local default_layout = opts.default_layout
  local id_prefix = opts.id_prefix or panel
  local tooltip_strings = opts.tooltip_strings or {}
  local on_layout_change = opts.on_layout_change
  local on_set_default = opts.on_set_default

  -- Active Layout
  ImGui.AlignTextToFramePadding(ctx)
  ImGui.Text(ctx, 'Active Layout')
  ImGui.SameLine(ctx, 120)

  for _, layout in ipairs({'A', 'B', 'C'}) do
    local is_active = (active_layout == layout)
    if Ark.Button(ctx, {
      id = id_prefix .. '_layout_' .. layout,
      label = layout,
      width = 50,
      height = 24,
      is_toggled = is_active,
      preset_name = 'BUTTON_TOGGLE_WHITE',
      on_click = function()
        if on_layout_change then
          on_layout_change(layout)
        end
      end
    }).clicked then
    end
    ImGui.SameLine(ctx, 0, 6)
  end
  ImGui.NewLine(ctx)

  ImGui.Dummy(ctx, 0, 4)

  -- Apply Size
  ImGui.AlignTextToFramePadding(ctx)
  ImGui.Text(ctx, 'Apply Size')
  ImGui.SameLine(ctx, 120)

  for _, size in ipairs({'100%', '150%', '200%'}) do
    if Ark.Button(ctx, {
      id = id_prefix .. '_size_' .. size,
      label = size,
      width = 70,
      height = 24,
      on_click = function()
        local scale = (size == '100%') and '' or (size .. '_')
        ThemeParams.apply_layout_to_tracks(panel, active_layout, scale)
      end
    }).clicked then
    end
    ImGui.SameLine(ctx, 0, 6)
  end
  ImGui.NewLine(ctx)

  ImGui.Dummy(ctx, 0, 4)

  -- Set Default Layout button
  local is_default = (default_layout == active_layout)

  ImGui.AlignTextToFramePadding(ctx)
  if is_default then
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x00FF88FF)
    ImGui.Text(ctx, 'Default Layout')
    ImGui.PopStyleColor(ctx)
  else
    ImGui.Text(ctx, 'Default Layout')
  end
  ImGui.SameLine(ctx, 120)

  if Ark.Button(ctx, {
    id = id_prefix .. '_set_default',
    label = is_default and ('✓ ' .. active_layout .. ' is Default') or ('Set ' .. active_layout .. ' as Default'),
    width = 200,
    height = 24,
    is_toggled = is_default,
    preset_name = is_default and 'BUTTON_TOGGLE_WHITE' or nil,
    on_click = function()
      if not is_default and on_set_default then
        on_set_default(active_layout)
      end
    end
  }).clicked then
  end

  -- Tooltip
  if ImGui.IsItemHovered(ctx) and tooltip_strings.set_default_layout then
    ImGui.SetTooltip(ctx, string.format(tooltip_strings.set_default_layout, active_layout))
  end

  ImGui.NewLine(ctx)
end

return M

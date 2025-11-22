-- @noindex
-- rearkitekt/gui/widgets/menus/color_picker_menu.lua
-- Reusable color picker for context menus

local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.defs.colors')
local ColorUtils = require('rearkitekt.core.colors')

local M = {}

-- Default configuration
local DEFAULTS = {
  chip_size = 20,
  chip_spacing = 4,
  chip_rounding = 3,
  columns = 4,
  show_labels = false,
  show_none_option = true,
  none_label = "None",
}

-- =============================================================================
-- MAIN RENDER FUNCTION
-- =============================================================================

--- Render a color picker grid in a context menu
-- @param ctx ImGui context
-- @param opts Options table:
--   - on_select: function(color_hex, color_name) - called when color is selected
--   - current_color: string - hex of currently selected color (optional)
--   - palette: table - custom palette (optional, defaults to Colors.PALETTE)
--   - chip_size: number - size of color chips (optional)
--   - columns: number - number of columns (optional)
--   - show_labels: boolean - show color names (optional)
--   - show_none_option: boolean - show "None" option to clear color (optional)
-- @return boolean - true if a color was selected
function M.render(ctx, opts)
  opts = opts or {}
  local palette = opts.palette or Colors.PALETTE
  local chip_size = opts.chip_size or DEFAULTS.chip_size
  local chip_spacing = opts.chip_spacing or DEFAULTS.chip_spacing
  local chip_rounding = opts.chip_rounding or DEFAULTS.chip_rounding
  local columns = opts.columns or DEFAULTS.columns
  local show_labels = opts.show_labels == nil and DEFAULTS.show_labels or opts.show_labels
  local show_none = opts.show_none_option == nil and DEFAULTS.show_none_option or opts.show_none_option

  local selected = false

  -- "None" option to clear color
  if show_none then
    if ImGui.MenuItem(ctx, opts.none_label or DEFAULTS.none_label) then
      if opts.on_select then
        opts.on_select(nil, nil)
      end
      selected = true
    end
    ImGui.Separator(ctx)
  end

  -- Render color chips in grid
  local col = 0
  for i, color in ipairs(palette) do
    local hex = color.hex
    local name = color.name

    -- Convert hex to ImGui color
    local r, g, b, a = ColorUtils.hex_to_rgba(hex)
    local color_u32 = ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1.0)

    -- Check if this is the current color
    local is_current = opts.current_color and opts.current_color:upper() == hex:upper()

    -- Push ID for unique button
    ImGui.PushID(ctx, i)

    -- Draw colored button
    if is_current then
      -- Highlight current selection
      ImGui.PushStyleColor(ctx, ImGui.Col_Border, 0xFFFFFFFF)
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameBorderSize, 2)
    end

    ImGui.PushStyleColor(ctx, ImGui.Col_Button, color_u32)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, color_u32)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, color_u32)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameRounding, chip_rounding)

    local label = show_labels and name or "##color"
    if ImGui.Button(ctx, label, chip_size, chip_size) then
      if opts.on_select then
        opts.on_select(hex, name)
      end
      selected = true
    end

    -- Tooltip with color name
    if ImGui.IsItemHovered(ctx) then
      ImGui.BeginTooltip(ctx)
      ImGui.Text(ctx, name)
      ImGui.EndTooltip(ctx)
    end

    ImGui.PopStyleVar(ctx)  -- FrameRounding
    ImGui.PopStyleColor(ctx, 3)  -- Button colors

    if is_current then
      ImGui.PopStyleVar(ctx)  -- FrameBorderSize
      ImGui.PopStyleColor(ctx)  -- Border
    end

    ImGui.PopID(ctx)

    -- Grid layout
    col = col + 1
    if col < columns and i < #palette then
      ImGui.SameLine(ctx, 0, chip_spacing)
    else
      col = 0
    end
  end

  return selected
end

-- =============================================================================
-- SUBMENU HELPER
-- =============================================================================

--- Render a color picker as a submenu
-- @param ctx ImGui context
-- @param label string - menu label (e.g., "Assign Color")
-- @param opts Options table (same as render)
-- @return boolean - true if a color was selected
function M.submenu(ctx, label, opts)
  local selected = false

  if ImGui.BeginMenu(ctx, label) then
    selected = M.render(ctx, opts)
    ImGui.EndMenu(ctx)
  end

  return selected
end

return M

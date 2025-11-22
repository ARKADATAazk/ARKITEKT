-- @noindex
-- rearkitekt/gui/widgets/menus/color_picker_menu.lua
-- Reusable color picker for context menus with Chip rendering

local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.defs.colors')
local ColorUtils = require('rearkitekt.core.colors')
local Chip = require('rearkitekt.gui.widgets.data.chip')
local Draw = require('rearkitekt.gui.draw')

local hexrgb = ColorUtils.hexrgb

-- Remix icon for paint fill (selection indicator)
local ICON_PAINT_FILL = "\xEE\xBF\x82"  -- U+EFC2

local M = {}

-- Default configuration
local DEFAULTS = {
  chip_size = 17,           -- Size for square chips
  chip_radius = 7,          -- Radius for circle chips (legacy)
  columns = 7,              -- 7 columns for 28 colors (4 rows)
  show_none_option = true,
  none_label = "Remove Color",
  shape = Chip.SHAPE.SQUARE, -- Default to square like Wwise
}

-- =============================================================================
-- MAIN RENDER FUNCTION
-- =============================================================================

--- Render a color picker grid in a context menu using Chip components
-- @param ctx ImGui context
-- @param opts Options table:
--   - on_select: function(color_int, color_hex, color_name) - called when color is selected
--   - current_color: number - integer color value of currently selected color (optional)
--   - palette: table - custom palette (optional, defaults to Colors.PALETTE)
--   - shape: Chip.SHAPE - SQUARE (default) or CIRCLE
--   - chip_size: number - size for square chips (default 17)
--   - chip_radius: number - radius for circle chips (default 7)
--   - columns: number - number of columns (default 7 for 28 colors)
--   - show_none_option: boolean - show "Remove Color" option (optional)
--   - none_label: string - label for none option (optional)
--   - icon_font: font - remix icon font for selection indicator (optional)
-- @return boolean - true if a color was selected
function M.render(ctx, opts)
  opts = opts or {}
  local palette = opts.palette or Colors.PALETTE
  local chip_size = opts.chip_size or DEFAULTS.chip_size
  local chip_radius = opts.chip_radius or DEFAULTS.chip_radius
  local columns = opts.columns or DEFAULTS.columns
  local shape = opts.shape or DEFAULTS.shape
  local show_none = opts.show_none_option == nil and DEFAULTS.show_none_option or opts.show_none_option
  local none_label = opts.none_label or DEFAULTS.none_label

  local selected = false
  local dl = ImGui.GetWindowDrawList(ctx)

  -- Use size or radius based on shape
  local is_square = shape == Chip.SHAPE.SQUARE
  local effective_size = is_square and chip_size or (chip_radius * 2)

  -- Calculate minimum width needed for grid
  local chip_gap = 3  -- Gap between chips
  local item_padding_x = 12
  local min_grid_width = (columns * effective_size) + ((columns - 1) * chip_gap) + (item_padding_x * 2)

  -- Force minimum width with a dummy
  ImGui.Dummy(ctx, min_grid_width, 1)

  -- Draw separator line at top
  ImGui.Dummy(ctx, 1, 4)
  local sep_x1, sep_y1 = ImGui.GetCursorScreenPos(ctx)
  local sep_w = ImGui.GetContentRegionAvail(ctx)
  ImGui.DrawList_AddLine(dl, sep_x1 + 8, sep_y1, sep_x1 + sep_w - 8, sep_y1, hexrgb("#505050FF"), 1)
  ImGui.Dummy(ctx, 1, 12)

  -- Calculate grid layout
  local menu_width = ImGui.GetContentRegionAvail(ctx)
  local menu_start_x, menu_start_y = ImGui.GetCursorScreenPos(ctx)

  -- Grid spacing based on chip size + gap
  local chip_spacing = effective_size + chip_gap

  -- Calculate actual grid width and center it
  local actual_grid_width = (columns * effective_size) + ((columns - 1) * chip_gap)
  local grid_offset_x = (menu_width - actual_grid_width) * 0.5

  -- Convert palette to integer colors
  local preset_colors = {}
  for i, color in ipairs(palette) do
    preset_colors[i] = hexrgb(color.hex)
  end

  -- Draw color chips
  for i, color in ipairs(preset_colors) do
    local col_idx = (i - 1) % columns
    local row_idx = math.floor((i - 1) / columns)

    local chip_cx = menu_start_x + grid_offset_x + col_idx * chip_spacing
    local chip_cy = menu_start_y + row_idx * chip_spacing
    local hit_size = effective_size + 4

    -- Check if this is the current color
    local is_selected = (opts.current_color and opts.current_color == color)

    -- Make it clickable
    local hit_x = chip_cx - hit_size * 0.5
    local hit_y = chip_cy - hit_size * 0.5
    ImGui.SetCursorScreenPos(ctx, hit_x, hit_y)
    if ImGui.InvisibleButton(ctx, "##color_" .. i, hit_size, hit_size) then
      if opts.on_select then
        local color_hex = palette[i].hex
        local color_name = palette[i].name
        opts.on_select(color, color_hex, color_name)
      end
      selected = true
    end
    local is_hovered = ImGui.IsItemHovered(ctx)

    -- Create darker border using HSL (reduce lightness for true darker shade)
    local h, s, l = ColorUtils.rgb_to_hsl(color)
    local darker_l = l * 0.5  -- 50% of original lightness
    local br, bg, bb = ColorUtils.hsl_to_rgb(h, s, darker_l)
    local border_col = ColorUtils.components_to_rgba(br, bg, bb, 255)

    -- Draw chip (no glow - using icon for selection)
    Chip.draw(ctx, {
      style = Chip.STYLE.INDICATOR,
      shape = shape,
      color = color,
      draw_list = dl,
      x = chip_cx,
      y = chip_cy,
      -- For squares
      size = chip_size,
      rounding = 1,  -- Slight rounding for Wwise look
      -- For circles (legacy)
      radius = chip_radius,
      is_selected = false,  -- Don't use chip's selection state
      is_hovered = is_hovered,
      show_glow = false,  -- No glow - using icon instead
      shadow = false,  -- No shadow for cleaner Wwise look
      border = true,   -- Always show border
      border_color = border_col,
      border_thickness = 1.0,
    })

    -- Draw paint-fill icon for selected color
    if is_selected and opts.icon_font then
      ImGui.PushFont(ctx, opts.icon_font)
      local icon_color = hexrgb("#000000FF")  -- Black icon
      local text_w, text_h = ImGui.CalcTextSize(ctx, ICON_PAINT_FILL)
      local icon_x = chip_cx - text_w * 0.5
      local icon_y = chip_cy - text_h * 0.5
      Draw.text(dl, icon_x, icon_y, icon_color, ICON_PAINT_FILL)
      ImGui.PopFont(ctx)
    end
  end

  -- Calculate grid height and move cursor past it
  local grid_rows = math.ceil(#preset_colors / columns)
  local grid_height = (grid_rows - 1) * chip_spacing + effective_size
  ImGui.SetCursorScreenPos(ctx, menu_start_x, menu_start_y + grid_height + 8)

  -- Draw separator before "Remove Color" button
  ImGui.Dummy(ctx, 1, 4)
  local sep_x2, sep_y2 = ImGui.GetCursorScreenPos(ctx)
  local sep_w2 = ImGui.GetContentRegionAvail(ctx)
  ImGui.DrawList_AddLine(dl, sep_x2 + 8, sep_y2, sep_x2 + sep_w2 - 8, sep_y2, hexrgb("#505050FF"), 1)
  ImGui.Dummy(ctx, 1, 6)

  -- "Remove Color" button
  if show_none then
    local button_text = opts.current_color and none_label or "No Color"
    local button_width = ImGui.GetContentRegionAvail(ctx)

    ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + 8)
    if ImGui.Button(ctx, button_text, button_width - 16, 28) then
      if opts.on_select then
        opts.on_select(nil, nil, nil)
      end
      selected = true
    end
    ImGui.Dummy(ctx, 1, 4)
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

-- @noindex
-- Arkitekt/gui/widgets/controls/context_menu.lua
-- Enhanced context menu widget with icons, shortcuts, and ImGui-compatible API
--
-- Features over vanilla ImGui:
-- - Drop shadow for visual depth
-- - Icons in menu items (using icon fonts)
-- - Keyboard shortcut display (right-aligned)
-- - Disabled items with optional tooltips
-- - Labeled separators
-- - Theme integration
-- - checkbox_item/radiobutton_item variants
--
-- Usage (ImGui-compatible API):
--   if ContextMenu.BeginPopup(ctx, "my_menu") then
--     if ContextMenu.MenuItem(ctx, "Copy", "Ctrl+C") then
--       -- Handle copy
--     end
--     if ContextMenu.MenuItem(ctx, "Paste", "Ctrl+V", false, can_paste) then
--       -- Handle paste (disabled if can_paste is false)
--     end
--     ContextMenu.Separator(ctx, "Recent Files")  -- Labeled separator
--     if ContextMenu.BeginMenu(ctx, "More Options") then
--       if ContextMenu.MenuItem(ctx, "Option 1") then end
--       ContextMenu.EndMenu(ctx)
--     end
--     ContextMenu.EndPopup(ctx)
--   end
--
-- With icons:
--   if ContextMenu.MenuItem(ctx, "Save", "Ctrl+S", false, true, {
--     icon = "\u{e0c7}",  -- Font Awesome icon
--     icon_font = my_icon_font
--   }) then
--     -- Handle save
--   end

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Colors = require('arkitekt.core.colors')
local Theme = require('arkitekt.core.theme')

local M = {}
local hexrgb = Colors.hexrgb

-- Get dynamic defaults from Theme.COLORS
local function get_defaults()
  local C = Theme.COLORS
  return {
    bg_color = C.BG_BASE,
    border_color = C.BORDER_OUTER,
    item_bg_color = C.BG_TRANSPARENT,
    item_hover_color = C.BG_HOVER,
    item_active_color = C.BG_ACTIVE,
    item_text_color = C.TEXT_NORMAL,
    item_text_hover_color = C.TEXT_BRIGHT,
    item_disabled_color = C.TEXT_DIMMED,
    separator_color = C.BORDER_OUTER,
    checkbox_accent = C.ACCENT_PRIMARY,
    rounding = 2,
    padding = 8,
    item_height = 26,
    item_padding_x = 12,
    border_thickness = 1,
  }
end

-- Legacy static DEFAULTS for backward compatibility
local DEFAULTS = get_defaults()

function M.begin(ctx, id, config)
  config = config or {}
  local defaults = get_defaults()  -- Get fresh colors from Theme.COLORS

  local bg_color = config.bg_color or defaults.bg_color
  local border_color = config.border_color or defaults.border_color
  local rounding = config.rounding or defaults.rounding
  local padding = config.padding or defaults.padding
  local border_thickness = config.border_thickness or defaults.border_thickness
  local min_width = config.min_width or 180  -- Minimum width for better appearance

  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, padding, padding)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding, rounding)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_PopupRounding, rounding)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowBorderSize, border_thickness)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowMinSize, min_width, 0)

  ImGui.PushStyleColor(ctx, ImGui.Col_PopupBg, bg_color)
  ImGui.PushStyleColor(ctx, ImGui.Col_Border, border_color)

  local popup_open = ImGui.BeginPopup(ctx, id)

  if not popup_open then
    ImGui.PopStyleColor(ctx, 2)
    ImGui.PopStyleVar(ctx, 5)
  else
    -- Draw optimized multi-layer shadow/glow effect
    -- Use window draw list with expanded clip rect for shadow
    local wx, wy = ImGui.GetWindowPos(ctx)
    local ww, wh = ImGui.GetWindowSize(ctx)
    local dl = ImGui.GetWindowDrawList(ctx)

    -- Base black color
    local black = hexrgb("#000000")

    -- Shadow parameters
    local shadow_offset_x = 2
    local shadow_offset_y = 3

    -- Expand clip rect to allow drawing shadow outside window bounds
    local spread_max = 10
    ImGui.DrawList_PushClipRect(dl,
      wx - spread_max,
      wy - spread_max,
      wx + ww + spread_max * 2,
      wy + wh + spread_max * 2,
      false  -- Don't intersect with current clip
    )

    -- Multi-layer shadow for smooth blur (draw outer to inner)
    -- Increased opacities for better visibility

    -- Outer glow (largest, most transparent)
    local spread_1 = 8
    ImGui.DrawList_AddRectFilled(
      dl,
      wx + shadow_offset_x - spread_1,
      wy + shadow_offset_y - spread_1,
      wx + ww + shadow_offset_x + spread_1,
      wy + wh + shadow_offset_y + spread_1,
      Colors.with_opacity(black, 0.15),
      rounding + spread_1
    )

    -- Middle layer
    local spread_2 = 5
    ImGui.DrawList_AddRectFilled(
      dl,
      wx + shadow_offset_x - spread_2,
      wy + shadow_offset_y - spread_2,
      wx + ww + shadow_offset_x + spread_2,
      wy + wh + shadow_offset_y + spread_2,
      Colors.with_opacity(black, 0.20),
      rounding + spread_2
    )

    -- Inner shadow (smallest, most opaque)
    local spread_3 = 2
    ImGui.DrawList_AddRectFilled(
      dl,
      wx + shadow_offset_x - spread_3,
      wy + shadow_offset_y - spread_3,
      wx + ww + shadow_offset_x + spread_3,
      wy + wh + shadow_offset_y + spread_3,
      Colors.with_opacity(black, 0.25),
      rounding + spread_3
    )

    -- Restore clip rect
    ImGui.DrawList_PopClipRect(dl)
  end

  return popup_open
end

function M.end_menu(ctx)
  ImGui.EndPopup(ctx)
  ImGui.PopStyleColor(ctx, 2)
  ImGui.PopStyleVar(ctx, 5)
end

--- Enhanced menu item with icons, shortcuts, and disabled state
--- @param ctx userdata ImGui context
--- @param label string Item label
--- @param shortcut string|nil Keyboard shortcut text (e.g., "Ctrl+C")
--- @param selected boolean|nil If true, shows a checkmark
--- @param enabled boolean|nil If false, item is grayed out (default: true)
--- @param config table|nil Optional config: icon, icon_font, tooltip
--- @return boolean True if clicked
function M.MenuItem(ctx, label, shortcut, selected, enabled, config)
  config = config or {}
  local defaults = get_defaults()

  -- Handle optional parameters (match ImGui signature)
  if type(shortcut) == "table" then
    config = shortcut
    shortcut = config.shortcut
    selected = config.selected
    enabled = config.enabled
  end

  enabled = (enabled == nil) and true or enabled
  selected = selected or false
  shortcut = shortcut or config.shortcut

  local item_height = config.item_height or defaults.item_height
  local item_padding_x = config.item_padding_x or defaults.item_padding_x
  local item_hover_color = config.item_hover_color or defaults.item_hover_color
  local item_text_color = enabled and (config.item_text_color or defaults.item_text_color) or defaults.item_disabled_color
  local item_text_hover_color = enabled and (config.item_text_hover_color or defaults.item_text_hover_color) or defaults.item_disabled_color

  local icon = config.icon
  local icon_font = config.icon_font
  local tooltip = config.tooltip

  local dl = ImGui.GetWindowDrawList(ctx)
  local item_x, item_y = ImGui.GetCursorScreenPos(ctx)
  local avail_w = ImGui.GetContentRegionAvail(ctx)

  -- Calculate layout
  local icon_width = 0
  local icon_spacing = 0
  if icon then
    if icon_font then
      ImGui.PushFont(ctx, icon_font)
    end
    icon_width = ImGui.CalcTextSize(ctx, icon)
    if icon_font then
      ImGui.PopFont(ctx)
    end
    icon_spacing = 8
  end

  -- Calculate checkmark width (for selected items)
  local check_width = 0
  local check_spacing = 0
  if selected then
    check_width = 12
    check_spacing = 6
  end

  local text_w, text_h = ImGui.CalcTextSize(ctx, label)

  -- Calculate shortcut width
  local shortcut_w = 0
  local shortcut_spacing = 0
  if shortcut and shortcut ~= "" then
    shortcut_w = ImGui.CalcTextSize(ctx, shortcut)
    shortcut_spacing = 24  -- Spacing between label and shortcut
  end

  local item_w = math.max(avail_w, check_width + check_spacing + icon_width + icon_spacing + text_w + shortcut_spacing + shortcut_w + item_padding_x * 2)

  local item_hovered = enabled and ImGui.IsMouseHoveringRect(ctx, item_x, item_y, item_x + item_w, item_y + item_height)

  -- Draw hover background
  if item_hovered then
    ImGui.DrawList_AddRectFilled(dl, item_x, item_y, item_x + item_w, item_y + item_height, item_hover_color, 2)
  end

  local text_color = item_hovered and item_text_hover_color or item_text_color
  local current_x = item_x + item_padding_x

  -- Draw checkmark if selected
  if selected then
    local check_y = item_y + (item_height - check_width) * 0.5
    local check_color = text_color

    -- Draw checkmark using lines
    local cx = current_x + 2
    local cy = check_y + check_width * 0.5
    local mx = cx + check_width * 0.3
    local my = cy + check_width * 0.3
    local ex = cx + check_width - 2
    local ey = cy - check_width * 0.4

    ImGui.DrawList_AddLine(dl, cx, cy, mx, my, check_color, 2)
    ImGui.DrawList_AddLine(dl, mx, my, ex, ey, check_color, 2)

    current_x = current_x + check_width + check_spacing
  end

  -- Draw icon if provided
  if icon then
    if icon_font then
      ImGui.PushFont(ctx, icon_font)
    end
    local icon_y = item_y + (item_height - text_h) * 0.5
    ImGui.DrawList_AddText(dl, current_x, icon_y, text_color, icon)
    if icon_font then
      ImGui.PopFont(ctx)
    end
    current_x = current_x + icon_width + icon_spacing
  end

  -- Draw label
  local text_y = item_y + (item_height - text_h) * 0.5
  ImGui.DrawList_AddText(dl, current_x, text_y, text_color, label)

  -- Draw shortcut (right-aligned, dimmed)
  if shortcut and shortcut ~= "" then
    local shortcut_color = Colors.with_opacity(text_color, enabled and 0.6 or 0.4)
    local shortcut_x = item_x + item_w - shortcut_w - item_padding_x
    ImGui.DrawList_AddText(dl, shortcut_x, text_y, shortcut_color, shortcut)
  end

  -- Invisible button for interaction
  ImGui.InvisibleButton(ctx, label .. "_menuitem", item_w, item_height)

  -- Show tooltip on hover if disabled
  if tooltip and item_hovered and not enabled then
    ImGui.SetTooltip(ctx, tooltip)
  end

  return enabled and ImGui.IsItemClicked(ctx, 0) or false
end

-- Legacy API (backward compatibility)
function M.item(ctx, label, config)
  config = config or {}
  return M.MenuItem(ctx, label, config.shortcut, config.selected, config.enabled, config)
end

function M.checkbox_item(ctx, label, checked, config)
  config = config or {}
  local defaults = get_defaults()  -- Get fresh colors from Theme.COLORS

  local item_height = config.item_height or defaults.item_height
  local item_padding_x = config.item_padding_x or defaults.item_padding_x
  local item_hover_color = config.item_hover_color or defaults.item_hover_color
  local item_text_color = config.item_text_color or defaults.item_text_color
  local item_text_hover_color = config.item_text_hover_color or defaults.item_text_hover_color

  local dl = ImGui.GetWindowDrawList(ctx)
  local item_x, item_y = ImGui.GetCursorScreenPos(ctx)
  local avail_w = ImGui.GetContentRegionAvail(ctx)

  local checkbox_size = 16  -- Slightly larger for better visibility
  local checkbox_padding = 8
  local text_w, text_h = ImGui.CalcTextSize(ctx, label)
  local item_w = math.max(avail_w, text_w + item_padding_x * 2 + checkbox_size + checkbox_padding)

  local item_hovered = ImGui.IsMouseHoveringRect(ctx, item_x, item_y, item_x + item_w, item_y + item_height)

  if item_hovered then
    ImGui.DrawList_AddRectFilled(dl, item_x, item_y, item_x + item_w, item_y + item_height, item_hover_color, 2)
  end

  -- Draw checkbox with improved styling matching checkbox primitive
  local checkbox_x = item_x + item_padding_x
  local checkbox_y = item_y + (item_height - checkbox_size) * 0.5

  -- Use theme colors for better consistency
  local C = Theme.COLORS
  local checkbox_bg = checked and C.BG_HOVER or C.BG_BASE
  local checkbox_border_inner = checked and C.BORDER_HOVER or C.BORDER_INNER
  local checkbox_border_outer = C.BORDER_OUTER

  -- Draw background with rounded corners
  ImGui.DrawList_AddRectFilled(dl, checkbox_x + 1, checkbox_y + 1,
    checkbox_x + checkbox_size - 1, checkbox_y + checkbox_size - 1, checkbox_bg, 1)

  -- Draw double border for depth (matches checkbox primitive)
  ImGui.DrawList_AddRect(dl, checkbox_x + 1, checkbox_y + 1,
    checkbox_x + checkbox_size - 1, checkbox_y + checkbox_size - 1, checkbox_border_inner, 1, 0, 1)
  ImGui.DrawList_AddRect(dl, checkbox_x, checkbox_y,
    checkbox_x + checkbox_size, checkbox_y + checkbox_size, checkbox_border_outer, 1, 0, 1)

  -- Draw checkmark if checked (improved design from checkbox primitive)
  if checked then
    local check_color = C.TEXT_DIMMED
    local padding = checkbox_size * 0.25
    local check_size = checkbox_size - padding * 2

    local cx = checkbox_x + padding
    local cy = checkbox_y + checkbox_size * 0.5
    local mx = cx + check_size * 0.3
    local my = cy + check_size * 0.3
    local ex = cx + check_size
    local ey = cy - check_size * 0.4

    -- Smooth checkmark with proper thickness
    ImGui.DrawList_AddLine(dl, cx, cy, mx, my, check_color, 2)
    ImGui.DrawList_AddLine(dl, mx, my, ex, ey, check_color, 2)
  end

  -- Draw label text
  local text_color = item_hovered and item_text_hover_color or item_text_color
  local text_x = checkbox_x + checkbox_size + checkbox_padding
  local text_y = item_y + (item_height - text_h) * 0.5

  ImGui.DrawList_AddText(dl, text_x, text_y, text_color, label)

  ImGui.InvisibleButton(ctx, label .. "_checkbox_item", item_w, item_height)

  return ImGui.IsItemClicked(ctx, 0)
end

function M.radiobutton_item(ctx, label, selected, config)
  config = config or {}
  local defaults = get_defaults()  -- Get fresh colors from Theme.COLORS

  local item_height = config.item_height or defaults.item_height
  local item_padding_x = config.item_padding_x or defaults.item_padding_x
  local item_hover_color = config.item_hover_color or defaults.item_hover_color
  local item_text_color = config.item_text_color or defaults.item_text_color
  local item_text_hover_color = config.item_text_hover_color or defaults.item_text_hover_color

  local dl = ImGui.GetWindowDrawList(ctx)
  local item_x, item_y = ImGui.GetCursorScreenPos(ctx)
  local avail_w = ImGui.GetContentRegionAvail(ctx)

  local radio_size = 16  -- Outer circle diameter
  local radio_padding = 8
  local text_w, text_h = ImGui.CalcTextSize(ctx, label)
  local item_w = math.max(avail_w, text_w + item_padding_x * 2 + radio_size + radio_padding)

  local item_hovered = ImGui.IsMouseHoveringRect(ctx, item_x, item_y, item_x + item_w, item_y + item_height)

  if item_hovered then
    ImGui.DrawList_AddRectFilled(dl, item_x, item_y, item_x + item_w, item_y + item_height, item_hover_color, 2)
  end

  -- Draw radio button with improved styling matching radio button primitive
  local radio_x = item_x + item_padding_x
  local radio_y = item_y + (item_height - radio_size) * 0.5
  local center_x = radio_x + radio_size / 2
  local center_y = radio_y + radio_size / 2

  -- Use theme colors for better consistency
  local C = Theme.COLORS
  local outer_radius = radio_size / 2
  local inner_radius = (radio_size - 4) / 2
  local selected_radius = (radio_size - 8) / 2

  local bg_color = selected and C.BG_HOVER or C.BG_BASE
  local inner_color = C.BG_BASE
  local border_inner = selected and C.BORDER_HOVER or C.BORDER_INNER
  local border_outer = C.BORDER_OUTER

  -- Draw outer circle
  ImGui.DrawList_AddCircleFilled(dl, center_x, center_y, outer_radius, bg_color)
  ImGui.DrawList_AddCircle(dl, center_x, center_y, outer_radius - 1, border_inner, 0, 1.0)
  ImGui.DrawList_AddCircle(dl, center_x, center_y, outer_radius, border_outer, 0, 1.0)

  -- Draw inner circle
  ImGui.DrawList_AddCircleFilled(dl, center_x, center_y, inner_radius, inner_color)
  ImGui.DrawList_AddCircle(dl, center_x, center_y, inner_radius, border_outer, 0, 1.0)

  -- Draw selected indicator (filled circle)
  if selected then
    local selected_color = C.TEXT_DIMMED
    ImGui.DrawList_AddCircleFilled(dl, center_x, center_y, selected_radius, selected_color)
  end

  -- Draw label text
  local text_color = item_hovered and item_text_hover_color or item_text_color
  local text_x = radio_x + radio_size + radio_padding
  local text_y = item_y + (item_height - text_h) * 0.5

  ImGui.DrawList_AddText(dl, text_x, text_y, text_color, label)

  ImGui.InvisibleButton(ctx, label .. "_radiobutton_item", item_w, item_height)

  return ImGui.IsItemClicked(ctx, 0)
end

--- Separator with optional label (like "--- Recent Files ---")
--- @param ctx userdata ImGui context
--- @param label string|nil Optional label text
--- @param config table|nil Optional config
function M.Separator(ctx, label, config)
  config = config or {}

  -- Handle label passed as config
  if type(label) == "table" then
    config = label
    label = config.label
  end

  local defaults = get_defaults()
  local separator_color = config.separator_color or defaults.separator_color
  local label_color = config.label_color or defaults.item_disabled_color

  ImGui.Dummy(ctx, 1, 4)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local avail_w = ImGui.GetContentRegionAvail(ctx)

  local dl = ImGui.GetWindowDrawList(ctx)

  if label and label ~= "" then
    -- Separator with label (like VSCode section headers)
    local label_w, label_h = ImGui.CalcTextSize(ctx, label)
    local inset = 8
    local label_x = x + inset
    local label_y = y

    -- Draw label
    ImGui.DrawList_AddText(dl, label_x, label_y, label_color, label)

    -- Draw line after label
    local line_start_x = label_x + label_w + 8
    if line_start_x < x + avail_w - inset then
      ImGui.DrawList_AddLine(dl, line_start_x, y + label_h / 2, x + avail_w - inset, y + label_h / 2, separator_color, 1)
    end

    ImGui.Dummy(ctx, 1, label_h + 2)
  else
    -- Standard separator with inset from edges
    ImGui.DrawList_AddLine(dl, x + 8, y, x + avail_w - 8, y, separator_color, 1)
    ImGui.Dummy(ctx, 1, 6)
  end
end

-- Legacy API (backward compatibility)
function M.separator(ctx, config)
  return M.Separator(ctx, nil, config)
end

--- Submenu support (ImGui-compatible API)
--- @param ctx userdata ImGui context
--- @param label string Submenu label
--- @param enabled boolean|nil If false, submenu is grayed out (default: true)
--- @param config table|nil Optional config
--- @return boolean True if submenu is open
function M.BeginMenu(ctx, label, enabled, config)
  config = config or {}

  -- Handle enabled passed as config
  if type(enabled) == "table" then
    config = enabled
    enabled = config.enabled
  end

  enabled = (enabled == nil) and true or enabled

  local defaults = get_defaults()

  local item_height = config.item_height or defaults.item_height
  local item_padding_x = config.item_padding_x or defaults.item_padding_x
  local item_hover_color = config.item_hover_color or defaults.item_hover_color
  local item_text_color = enabled and (config.item_text_color or defaults.item_text_color) or defaults.item_disabled_color
  local item_text_hover_color = enabled and (config.item_text_hover_color or defaults.item_text_hover_color) or defaults.item_disabled_color

  local dl = ImGui.GetWindowDrawList(ctx)
  local item_x, item_y = ImGui.GetCursorScreenPos(ctx)
  local avail_w = ImGui.GetContentRegionAvail(ctx)

  local text_w, text_h = ImGui.CalcTextSize(ctx, label)
  local arrow_size = 6  -- Triangle size
  local arrow_space = arrow_size + 4
  local item_w = math.max(avail_w, text_w + arrow_space + item_padding_x * 3)

  local item_hovered = enabled and ImGui.IsMouseHoveringRect(ctx, item_x, item_y, item_x + item_w, item_y + item_height)

  if item_hovered then
    ImGui.DrawList_AddRectFilled(dl, item_x, item_y, item_x + item_w, item_y + item_height, item_hover_color, 2)
  end

  local text_color = item_hovered and item_text_hover_color or item_text_color
  local text_x = item_x + item_padding_x
  local text_y = item_y + (item_height - text_h) * 0.5

  ImGui.DrawList_AddText(dl, text_x, text_y, text_color, label)

  -- Draw triangle arrow (pointing right)
  local arrow_x = item_x + item_w - item_padding_x - arrow_size
  local arrow_y = item_y + item_height * 0.5
  ImGui.DrawList_AddTriangleFilled(dl,
    arrow_x, arrow_y - arrow_size * 0.6,           -- Top vertex
    arrow_x, arrow_y + arrow_size * 0.6,           -- Bottom vertex
    arrow_x + arrow_size, arrow_y,                 -- Right vertex (pointing right)
    text_color)

  ImGui.InvisibleButton(ctx, label .. "_submenu", item_w, item_height)

  -- Only open submenu if enabled
  if not enabled then
    return false
  end

  -- Open submenu on hover and position it at the right edge of the parent menu
  if item_hovered then
    -- Calculate position: right edge of parent menu, aligned with this item
    local parent_window_x, parent_window_y = ImGui.GetWindowPos(ctx)
    local parent_window_w, _ = ImGui.GetWindowSize(ctx)
    local submenu_x = parent_window_x + parent_window_w - 2  -- Slight overlap for seamless appearance
    local submenu_y = item_y - defaults.padding  -- Align with item, accounting for padding

    ImGui.SetNextWindowPos(ctx, submenu_x, submenu_y, ImGui.Cond_Always)
    ImGui.OpenPopup(ctx, label .. "_submenu_popup")
  end

  -- Style for submenu popup
  local bg_color = config.bg_color or defaults.bg_color
  local border_color = config.border_color or defaults.border_color
  local rounding = config.rounding or defaults.rounding
  local padding = config.padding or defaults.padding

  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, padding, padding)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding, rounding)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_PopupRounding, rounding)
  ImGui.PushStyleColor(ctx, ImGui.Col_PopupBg, bg_color)
  ImGui.PushStyleColor(ctx, ImGui.Col_Border, border_color)

  local submenu_open = ImGui.BeginPopup(ctx, label .. "_submenu_popup")

  if not submenu_open then
    ImGui.PopStyleColor(ctx, 2)
    ImGui.PopStyleVar(ctx, 3)
  end

  return submenu_open
end

function M.EndMenu(ctx)
  ImGui.EndPopup(ctx)
  ImGui.PopStyleColor(ctx, 2)
  ImGui.PopStyleVar(ctx, 3)
end

-- ============================================================================
-- ImGui-COMPATIBLE ALIASES (for users coming from vanilla ImGui)
-- ============================================================================

-- Popup aliases
M.BeginPopup = M.begin  -- Same as begin(), just renamed
M.EndPopup = M.end_menu -- Same as end_menu(), just renamed

-- Legacy aliases (backward compatibility)
M.begin_menu = M.BeginMenu
M.end_submenu = M.EndMenu

return M
-- @noindex
-- Arkitekt/gui/style/imgui.lua
-- ImGui theme overrides and base styling
-- Reads colors dynamically from Style.COLORS for unified theming

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Colors = require('arkitekt.core.colors')

local M = {}
local hexrgb = Colors.hexrgb
local style_color_stack = {}

-- Static colors that don't change with theme
local STATIC = {
  transparent = hexrgb("#00000000"),
  black = hexrgb("#000000FF"),
  white = hexrgb("#FFFFFFFF"),
}

function M.with_alpha(col, a)
  return (col & 0xFFFFFF00) | (a & 0xFF)
end

-- Lazy-load Style to avoid circular dependency
local Style
local function get_style()
  if not Style then
    Style = require('arkitekt.gui.style')
  end
  return Style
end

function M.PushMyStyle(ctx, opts)
  opts = opts or {}
  local push_window_bg = (opts.window_bg ~= false)
  local push_modal_dim_bg = (opts.modal_dim_bg ~= false)

  -- Get current theme colors
  local S = get_style()
  local C = S.COLORS

  local color_pushes = 0
  local function push_color(...)
    ImGui.PushStyleColor(ctx, ...)
    color_pushes = color_pushes + 1
  end

  local A = M.with_alpha

  -- Style vars (geometry - unchanged by theme)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, 1)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_DisabledAlpha, 0)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 8, 8)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding, 0)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowBorderSize, 1)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowMinSize, 32, 32)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowTitleAlign, 0, 0.5)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ChildRounding, 0)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ChildBorderSize, 1)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_PopupRounding, 0)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_PopupBorderSize, 1)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, 4, 1)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameRounding, 0)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameBorderSize, 1)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 8, 4)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemInnerSpacing, 4, 4)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_IndentSpacing, 22)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_CellPadding, 4, 2)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ScrollbarSize, 12)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ScrollbarRounding, 4)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_GrabMinSize, 30)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_GrabRounding, 0)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_TabRounding, 0)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_TabBorderSize, 1)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_TabBarBorderSize, 1)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_TableAngledHeadersAngle, 0.401426)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ButtonTextAlign, 0.5, 0.51)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_SelectableTextAlign, 0, 0)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_SeparatorTextBorderSize, 3)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_SeparatorTextAlign, 0, 0.5)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_SeparatorTextPadding, 20, 3)

  -- Text colors
  push_color(ImGui.Col_Text, C.TEXT_NORMAL)
  push_color(ImGui.Col_TextDisabled, C.TEXT_DIMMED)

  -- Window backgrounds
  if push_window_bg then
    push_color(ImGui.Col_WindowBg, opts.window_bg_color or C.BG_PANEL)
  end
  push_color(ImGui.Col_ChildBg, STATIC.transparent)
  push_color(ImGui.Col_PopupBg, A(C.BG_PANEL, 0xF0))

  -- Borders
  push_color(ImGui.Col_Border, C.BORDER_OUTER)
  push_color(ImGui.Col_BorderShadow, STATIC.transparent)

  -- Frame (input fields, etc.)
  push_color(ImGui.Col_FrameBg, A(C.BG_BASE, 0x8A))
  push_color(ImGui.Col_FrameBgHovered, A(C.BG_HOVER, 0x99))
  push_color(ImGui.Col_FrameBgActive, A(C.BG_ACTIVE, 0xAB))

  -- Title bar (stays dark - chrome element)
  push_color(ImGui.Col_TitleBg, hexrgb("#0F0F0FFF"))
  push_color(ImGui.Col_TitleBgActive, hexrgb("#141414FF"))
  push_color(ImGui.Col_TitleBgCollapsed, hexrgb("#00000082"))

  -- Menu bar
  push_color(ImGui.Col_MenuBarBg, C.BG_PANEL)

  -- Scrollbar
  push_color(ImGui.Col_ScrollbarBg, STATIC.transparent)
  push_color(ImGui.Col_ScrollbarGrab, C.BG_HOVER)
  push_color(ImGui.Col_ScrollbarGrabHovered, C.BG_ACTIVE)
  push_color(ImGui.Col_ScrollbarGrabActive, C.BORDER_HOVER)

  -- Widgets
  push_color(ImGui.Col_CheckMark, C.TEXT_DIMMED)
  push_color(ImGui.Col_SliderGrab, C.BG_HOVER)
  push_color(ImGui.Col_SliderGrabActive, C.BG_ACTIVE)

  -- Buttons
  push_color(ImGui.Col_Button, A(C.BG_BASE, 0x66))
  push_color(ImGui.Col_ButtonHovered, C.BG_HOVER)
  push_color(ImGui.Col_ButtonActive, C.BG_ACTIVE)

  -- Headers (collapsing headers, tree nodes)
  push_color(ImGui.Col_Header, A(C.BG_BASE, 0x4F))
  push_color(ImGui.Col_HeaderHovered, C.BG_HOVER)
  push_color(ImGui.Col_HeaderActive, C.BG_ACTIVE)

  -- Separators
  push_color(ImGui.Col_Separator, STATIC.transparent)
  push_color(ImGui.Col_SeparatorHovered, STATIC.transparent)
  push_color(ImGui.Col_SeparatorActive, STATIC.transparent)

  -- Resize grip
  push_color(ImGui.Col_ResizeGrip, C.BG_HOVER)
  push_color(ImGui.Col_ResizeGripHovered, C.BG_ACTIVE)
  push_color(ImGui.Col_ResizeGripActive, C.BORDER_HOVER)

  -- Tabs
  push_color(ImGui.Col_Tab, A(C.BG_PANEL, 0xDC))
  push_color(ImGui.Col_TabHovered, C.ACCENT_PRIMARY)

  -- Docking
  push_color(ImGui.Col_DockingPreview, A(C.ACCENT_PRIMARY, 0xB3))
  push_color(ImGui.Col_DockingEmptyBg, C.BG_HOVER)

  -- Plots
  push_color(ImGui.Col_PlotLines, C.TEXT_NORMAL)
  push_color(ImGui.Col_PlotLinesHovered, C.ACCENT_WARNING or C.TEXT_BRIGHT)
  push_color(ImGui.Col_PlotHistogram, C.ACCENT_WARNING or C.TEXT_BRIGHT)
  push_color(ImGui.Col_PlotHistogramHovered, C.ACCENT_WARNING or C.TEXT_BRIGHT)

  -- Tables
  push_color(ImGui.Col_TableHeaderBg, C.BG_PANEL)
  push_color(ImGui.Col_TableBorderStrong, C.BORDER_OUTER)
  push_color(ImGui.Col_TableBorderLight, C.BORDER_INNER)
  push_color(ImGui.Col_TableRowBg, A(C.BG_BASE, 0x0A))
  push_color(ImGui.Col_TableRowBgAlt, A(C.BG_HOVER, 0x0F))

  -- Selection
  push_color(ImGui.Col_TextSelectedBg, A(C.BG_ACTIVE, 0x66))

  -- Drag and drop
  push_color(ImGui.Col_DragDropTarget, A(C.TEXT_NORMAL, 0xE6))

  -- Navigation
  push_color(ImGui.Col_NavWindowingHighlight, A(C.TEXT_NORMAL, 0xB3))
  push_color(ImGui.Col_NavWindowingDimBg, A(C.TEXT_DIMMED, 0x33))

  -- Modal dim
  if push_modal_dim_bg then
    push_color(ImGui.Col_ModalWindowDimBg, A(C.TEXT_DIMMED, 0x59))
  end

  table.insert(style_color_stack, color_pushes)
end

function M.PopMyStyle(ctx)
  local color_pushes = table.remove(style_color_stack) or 0
  if color_pushes > 0 then
    ImGui.PopStyleColor(ctx, color_pushes)
  end
  ImGui.PopStyleVar(ctx, 31)
end

-- Expose palette for backward compatibility (some scripts might use M.palette)
-- Chrome elements (titlebar, statusbar) use these and should stay dark
M.palette = setmetatable({}, {
  __index = function(_, key)
    local S = get_style()
    -- Dark greys stay hardcoded for chrome elements (titlebar, statusbar)
    local hardcoded = {
      white = hexrgb("#FFFFFFFF"),
      black = hexrgb("#000000FF"),
      grey_05 = hexrgb("#0D0D0DFF"),
      grey_06 = hexrgb("#0F0F0FFF"),
      grey_07 = hexrgb("#121212FF"),
      grey_08 = hexrgb("#141414FF"),  -- statusbar bg
      grey_09 = hexrgb("#171717FF"),
      grey_10 = hexrgb("#1A1A1AFF"),
      grey_14 = hexrgb("#242424FF"),  -- titlebar bg
      grey_18 = hexrgb("#2E2E2EFF"),
      grey_20 = hexrgb("#333333FF"),
      border_strong = hexrgb("#000000FF"),
      border_soft = hexrgb("#000000DD"),
      -- Semantic mappings for lighter greys that can theme
      grey_52 = S.COLORS.TEXT_DIMMED,
      grey_60 = S.COLORS.TEXT_NORMAL,
      grey_c0 = S.COLORS.TEXT_NORMAL,
      teal = S.COLORS.ACCENT_PRIMARY,
      yellow = S.COLORS.ACCENT_WARNING,
      red = S.COLORS.ACCENT_DANGER,
    }
    return hardcoded[key] or S.COLORS.BG_BASE
  end
})

return M

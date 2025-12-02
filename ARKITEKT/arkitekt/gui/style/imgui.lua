-- @noindex
-- Arkitekt/gui/style/imgui.lua
-- ImGui theme overrides and base styling
-- Reads colors dynamically from Theme.COLORS for unified theming

local ImGui = require('arkitekt.platform.imgui')
local Colors = require('arkitekt.core.colors')

local M = {}
local hexrgb = Colors.hexrgb
local style_color_stack = {}

-- Static colors that don't change with theme
local STATIC = {
  transparent = hexrgb('#00000000'),
  black = hexrgb('#000000FF'),
  white = hexrgb('#FFFFFFFF'),
}

function M.with_alpha(col, a)
  return (col & 0xFFFFFF00) | (a & 0xFF)
end

-- Lazy-load Theme to avoid circular dependency
local Theme
local function get_theme()
  if not Theme then
    Theme = require('arkitekt.core.theme')
  end
  return Theme
end

function M.PushMyStyle(ctx, opts)
  opts = opts or {}
  local push_window_bg = (opts.window_bg ~= false)
  local push_modal_dim_bg = (opts.modal_dim_bg ~= false)

  -- Get current theme colors
  local T = get_theme()
  local C = T.COLORS

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
    push_color(ImGui.Col_WindowBg, opts.window_bg_color or C.BG_BASE)
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

  -- Title bar (uses chrome color - significantly darker than content)
  push_color(ImGui.Col_TitleBg, C.BG_CHROME)
  push_color(ImGui.Col_TitleBgActive, C.BG_CHROME)
  push_color(ImGui.Col_TitleBgCollapsed, A(C.BG_CHROME, 0x82))

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

  style_color_stack[#style_color_stack + 1] = color_pushes
end

function M.PopMyStyle(ctx)
  local color_pushes = table.remove(style_color_stack) or 0
  if color_pushes > 0 then
    ImGui.PopStyleColor(ctx, color_pushes)
  end
  ImGui.PopStyleVar(ctx, 31)
end

-- Expose palette for backward compatibility (some scripts might use M.palette)
-- Maps old grey names to themed colors
M.palette = setmetatable({}, {
  __index = function(_, key)
    local T = get_theme()
    local Colors = require('arkitekt.core.colors')
    -- Map palette names to themed colors
    -- Chrome elements (grey_05-08) use BG_CHROME (significantly darker than content)
    local mapping = {
      white = hexrgb('#FFFFFFFF'),
      black = hexrgb('#000000FF'),
      -- Very dark greys map to chrome colors (titlebar/statusbar)
      grey_05 = Colors.adjust_lightness(T.COLORS.BG_CHROME, -0.02),
      grey_06 = Colors.adjust_lightness(T.COLORS.BG_CHROME, -0.01),
      grey_07 = T.COLORS.BG_CHROME,
      grey_08 = T.COLORS.BG_CHROME,  -- statusbar bg
      -- Lighter greys map to content/panel colors
      grey_09 = T.COLORS.BG_PANEL,
      grey_10 = T.COLORS.BG_PANEL,
      grey_14 = T.COLORS.BG_BASE,   -- content bg
      grey_18 = T.COLORS.BG_HOVER,
      grey_20 = T.COLORS.BG_ACTIVE,
      grey_52 = T.COLORS.TEXT_DIMMED,
      grey_60 = T.COLORS.TEXT_NORMAL,
      grey_66 = T.COLORS.TEXT_DIMMED,
      grey_c0 = T.COLORS.TEXT_NORMAL,
      border_strong = T.COLORS.BORDER_OUTER,
      border_soft = T.COLORS.BORDER_INNER,
      teal = T.COLORS.ACCENT_PRIMARY,
      yellow = T.COLORS.ACCENT_WARNING,
      red = T.COLORS.ACCENT_DANGER,
    }
    return mapping[key] or T.COLORS.BG_BASE
  end
})

return M

-- @noindex
-- Demo: Theme Manager
-- Test the new dynamic theme system with algorithmic palette generation

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local ark = require('arkitekt')
local ThemeManager = require('arkitekt.core.theme_manager')
local Style = require('arkitekt.gui.style')
local Colors = require('arkitekt.core.colors')

-- ============================================================================
-- STATE
-- ============================================================================

local state = {
  current_theme = "dark",
  live_sync_enabled = false,
  show_color_values = false,
}

local live_sync_fn = nil

-- ============================================================================
-- UI
-- ============================================================================

local function draw_theme_selector(ctx)
  ImGui.Text(ctx, "Theme Presets:")
  ImGui.Spacing(ctx)

  local themes = ThemeManager.get_theme_names()

  for _, theme_name in ipairs(themes) do
    local is_current = (theme_name == state.current_theme)

    if ark.Button.draw(ctx, {
      label = theme_name,
      width = 120,
      preset_name = is_current and "BUTTON_TOGGLE_WHITE" or nil,
      is_toggled = is_current,
    }).clicked then
      ThemeManager.apply_theme(theme_name)
      state.current_theme = theme_name
    end

    ImGui.SameLine(ctx)
  end

  ImGui.NewLine(ctx)
end

local function draw_reaper_sync(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
  ImGui.Text(ctx, "REAPER Integration:")
  ImGui.Spacing(ctx)

  -- Manual sync button
  if ark.Button.draw(ctx, {
    label = "Sync with REAPER Theme",
    width = 180,
  }).clicked then
    if ThemeManager.sync_with_reaper() then
      state.current_theme = "REAPER"
    end
  end

  ImGui.SameLine(ctx)

  -- Live sync toggle
  local live_sync_result = ark.Button.draw(ctx, {
    label = "Live Sync",
    width = 100,
    preset_name = "BUTTON_TOGGLE_TEAL",
    is_toggled = state.live_sync_enabled,
  })

  if live_sync_result.clicked then
    state.live_sync_enabled = not state.live_sync_enabled
    if state.live_sync_enabled then
      live_sync_fn = ThemeManager.create_live_sync(1.0)  -- Check every second
    else
      live_sync_fn = nil
    end
  end

  if state.live_sync_enabled then
    ImGui.SameLine(ctx)
    ImGui.TextColored(ctx, 0x4CAF50FF, "(Active)")
  end
end

local function draw_color_preview(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  if ark.Button.draw(ctx, {
    label = state.show_color_values and "Hide Color Values" or "Show Color Values",
    width = 160,
  }).clicked then
    state.show_color_values = not state.show_color_values
  end

  if not state.show_color_values then
    return
  end

  ImGui.Spacing(ctx)
  ImGui.Text(ctx, "Current Color Palette:")
  ImGui.Spacing(ctx)

  local colors = {
    {"BG_BASE", "Background"},
    {"BG_HOVER", "Background Hover"},
    {"BG_ACTIVE", "Background Active"},
    {"BORDER_OUTER", "Border Outer"},
    {"BORDER_INNER", "Border Inner"},
    {"TEXT_NORMAL", "Text Normal"},
    {"TEXT_DIMMED", "Text Dimmed"},
    {"ACCENT_PRIMARY", "Accent Primary"},
    {"ACCENT_TEAL_BRIGHT", "Accent Bright"},
  }

  for _, pair in ipairs(colors) do
    local key, label = pair[1], pair[2]
    local color = Style.COLORS[key]

    if color then
      -- Draw color swatch
      local dl = ImGui.GetWindowDrawList(ctx)
      local x, y = ImGui.GetCursorScreenPos(ctx)
      ImGui.DrawList_AddRectFilled(dl, x, y, x + 30, y + 20, color)
      ImGui.DrawList_AddRect(dl, x, y, x + 30, y + 20, 0xFFFFFFFF)
      ImGui.Dummy(ctx, 30, 20)

      -- Draw label and hex value
      ImGui.SameLine(ctx)
      local r, g, b, a = Colors.rgba_to_components(color)
      ImGui.Text(ctx, string.format("%s: #%02X%02X%02X%02X", label, r, g, b, a))
    end
  end
end

local function draw_custom_theme(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
  ImGui.Text(ctx, "Custom Theme Generator:")
  ImGui.Spacing(ctx)
  ImGui.Text(ctx, "Pick a color to generate an entire theme from it")
  ImGui.Spacing(ctx)

  -- TODO: Add color picker when we implement it
  -- For now, just show some example colors to click
  local example_colors = {
    {Colors.hexrgb("#FF6B6BFF"), "Coral Red"},
    {Colors.hexrgb("#4ECDC4FF"), "Turquoise"},
    {Colors.hexrgb("#95E1D3FF"), "Mint"},
    {Colors.hexrgb("#F38181FF"), "Pink"},
    {Colors.hexrgb("#AA96DAFF"), "Purple"},
    {Colors.hexrgb("#FCBAD3FF"), "Rose"},
  }

  for _, pair in ipairs(example_colors) do
    local color, name = pair[1], pair[2]

    -- Draw color button
    local dl = ImGui.GetWindowDrawList(ctx)
    local x, y = ImGui.GetCursorScreenPos(ctx)

    local is_hovered = ImGui.IsMouseHoveringRect(ctx, x, y, x + 100, y + 30)
    local bg_color = is_hovered and Colors.adjust_brightness(color, 1.2) or color

    ImGui.DrawList_AddRectFilled(dl, x, y, x + 100, y + 30, bg_color, 2)
    ImGui.DrawList_AddRect(dl, x, y, x + 100, y + 30, 0x000000FF, 2, 0, 2)

    -- Text
    ImGui.SetCursorScreenPos(ctx, x + 5, y + 8)
    local text_color = Colors.auto_text_color(color)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, text_color)
    ImGui.Text(ctx, name)
    ImGui.PopStyleColor(ctx)

    -- Handle click
    if is_hovered and ImGui.IsMouseClicked(ctx, 0) then
      ThemeManager.generate_and_apply(color)
      state.current_theme = "Custom: " .. name
    end

    ImGui.Dummy(ctx, 100, 30)
    ImGui.SameLine(ctx)
  end

  ImGui.NewLine(ctx)
end

-- ============================================================================
-- MAIN
-- ============================================================================

local ctx = ImGui.CreateContext('Theme Manager Demo')
local open = true

local function main()
  -- Live sync check
  if live_sync_fn then
    live_sync_fn()
  end

  -- Main window
  ImGui.SetNextWindowSize(ctx, 800, 600, ImGui.Cond_FirstUseEver)

  local visible, window_open = ImGui.Begin(ctx, 'Theme Manager Demo', true)
  if not visible then
    ImGui.End(ctx)
    return window_open
  end

  ImGui.Text(ctx, "Dynamic Theme System with Algorithmic Palette Generation")
  ImGui.Text(ctx, "Generate entire UI themes from 1-3 base colors!")
  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Current theme indicator
  ImGui.Text(ctx, "Current Theme: " .. state.current_theme)
  ImGui.Spacing(ctx)

  -- Theme selector
  draw_theme_selector(ctx)

  -- REAPER sync
  draw_reaper_sync(ctx)

  -- Custom theme generator
  draw_custom_theme(ctx)

  -- Color preview
  draw_color_preview(ctx)

  ImGui.End(ctx)

  return window_open
end

local function loop()
  local window_open = main()
  if window_open then
    reaper.defer(loop)
  else
    ImGui.DestroyContext(ctx)
  end
end

reaper.defer(loop)

-- @noindex
-- Demo: Colored Button Presets (Algorithmic Hue Variations)
-- Showcase the new create_colored_button_preset system

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Style = require('arkitekt.gui.style')
local Colors = require('arkitekt.core.colors')
local ThemeManager = require('arkitekt.core.theme_manager')

-- ============================================================================
-- STATE
-- ============================================================================

local state = {
  current_hue = 0.0,  -- Red
  current_sat = 0.65,
  current_light = 0.48,
  preview_button_text = "Click Me",
}

-- ============================================================================
-- BUTTON RENDERER (Manual - shows the preset works)
-- ============================================================================

local function draw_colored_button(ctx, x, y, width, height, preset, label)
  local dl = ImGui.GetWindowDrawList(ctx)

  -- Check interaction
  local is_hovered = ImGui.IsMouseHoveringRect(ctx, x, y, x + width, y + height)
  local is_active = is_hovered and ImGui.IsMouseDown(ctx, 0)

  -- Get state color
  local bg_color = preset.bg_color
  if is_active then
    bg_color = preset.bg_active_color
  elseif is_hovered then
    bg_color = preset.bg_hover_color
  end

  local border_inner = is_hovered and preset.border_hover_color or preset.border_inner_color
  local border_outer = preset.border_outer_color
  local text_color = preset.text_color

  -- Draw button
  ImGui.DrawList_AddRectFilled(dl, x, y, x + width, y + height, bg_color)
  ImGui.DrawList_AddRect(dl, x + 1, y + 1, x + width - 1, y + height - 1, border_inner, 0, 0, 1)
  ImGui.DrawList_AddRect(dl, x, y, x + width, y + height, border_outer, 0, 0, 1)

  -- Draw text
  local text_w, text_h = ImGui.CalcTextSize(ctx, label)
  local text_x = x + (width - text_w) / 2
  local text_y = y + (height - text_h) / 2
  ImGui.DrawList_AddText(dl, text_x, text_y, text_color, label)

  -- Advance cursor
  ImGui.SetCursorScreenPos(ctx, x, y + height + 5)

  return is_hovered and ImGui.IsMouseReleased(ctx, 0)
end

-- ============================================================================
-- UI
-- ============================================================================

local ctx = ImGui.CreateContext('Colored Button Presets Demo')

local function draw_hue_slider(ctx)
  ImGui.Text(ctx, "Hue Control (Color Wheel Position):")
  ImGui.SetNextItemWidth(ctx, 400)

  local changed, new_hue = ImGui.SliderDouble(ctx, "##hue", state.current_hue, 0.0, 1.0, "%.3f")
  if changed then
    state.current_hue = new_hue
  end

  -- Show color names at key positions
  ImGui.SameLine(ctx)
  local hue_deg = state.current_hue * 360
  local color_name = ""
  if hue_deg < 30 or hue_deg >= 330 then
    color_name = "Red"
  elseif hue_deg < 90 then
    color_name = "Yellow"
  elseif hue_deg < 150 then
    color_name = "Green"
  elseif hue_deg < 210 then
    color_name = "Cyan"
  elseif hue_deg < 270 then
    color_name = "Blue"
  else
    color_name = "Magenta"
  end
  ImGui.Text(ctx, string.format("%s (%.0f°)", color_name, hue_deg))

  -- Saturation & Lightness
  ImGui.SetNextItemWidth(ctx, 200)
  local s_changed, new_sat = ImGui.SliderDouble(ctx, "Saturation", state.current_sat, 0.0, 1.0, "%.2f")
  if s_changed then
    state.current_sat = new_sat
  end

  ImGui.SameLine(ctx)
  ImGui.SetNextItemWidth(ctx, 200)
  local l_changed, new_light = ImGui.SliderDouble(ctx, "Lightness", state.current_light, 0.0, 1.0, "%.2f")
  if l_changed then
    state.current_light = new_light
  end
end

local function draw_custom_preview(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
  ImGui.Text(ctx, "Custom Color Preview:")
  ImGui.Spacing(ctx)

  draw_hue_slider(ctx)
  ImGui.Spacing(ctx)

  -- Generate preset from current HSL
  local preset = Style.create_colored_button_preset(state.current_hue, state.current_sat, state.current_light)

  -- Draw preview button
  local x, y = ImGui.GetCursorScreenPos(ctx)
  draw_colored_button(ctx, x, y, 150, 35, preset, state.preview_button_text)

  ImGui.Spacing(ctx)

  -- Show generated colors
  ImGui.Text(ctx, "Generated Colors:")
  local dl = ImGui.GetWindowDrawList(ctx)

  local color_info = {
    {"Base", preset.bg_color},
    {"Hover", preset.bg_hover_color},
    {"Active", preset.bg_active_color},
    {"Border Out", preset.border_outer_color},
    {"Border In", preset.border_inner_color},
  }

  for i, info in ipairs(color_info) do
    local label, color = info[1], info[2]
    local cx, cy = ImGui.GetCursorScreenPos(ctx)

    -- Color swatch
    ImGui.DrawList_AddRectFilled(dl, cx, cy, cx + 40, cy + 20, color)
    ImGui.DrawList_AddRect(dl, cx, cy, cx + 40, cy + 20, 0xFFFFFFFF)
    ImGui.Dummy(ctx, 40, 20)

    ImGui.SameLine(ctx)
    local r, g, b, a = Colors.rgba_to_components(color)
    ImGui.Text(ctx, string.format("%s: #%02X%02X%02X", label, r, g, b))
  end
end

local function draw_semantic_presets(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
  ImGui.Text(ctx, "Semantic Colored Buttons (Fixed Hues):")
  ImGui.Spacing(ctx)

  local presets = {
    {"BUTTON_DANGER", "Delete", 0xFF5350FF},
    {"BUTTON_SUCCESS", "Save", 0x4CAF50FF},
    {"BUTTON_WARNING", "Warning", 0xFFA726FF},
    {"BUTTON_INFO", "Info", 0x4A9EFFFF},
    {"BUTTON_PRIMARY", "Primary", 0x41E0A3FF},
  }

  local x, y = ImGui.GetCursorScreenPos(ctx)

  for i, preset_info in ipairs(presets) do
    local name, label, indicator_color = preset_info[1], preset_info[2], preset_info[3]
    local preset = Style.DYNAMIC_PRESETS[name]

    -- Draw indicator dot
    local dl = ImGui.GetWindowDrawList(ctx)
    ImGui.DrawList_AddCircleFilled(dl, x - 12, y + 17, 5, indicator_color)

    -- Draw button
    if draw_colored_button(ctx, x, y, 120, 30, preset, label) then
      reaper.ShowConsoleMsg(string.format("Clicked: %s\n", name))
    end

    y = y + 35
    ImGui.SetCursorScreenPos(ctx, x, y)
  end

  ImGui.Dummy(ctx, 1, 1)
end

local function draw_color_theory_sets(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
  ImGui.Text(ctx, "Color Theory Sets (Algorithmic Generation):")
  ImGui.Spacing(ctx)

  -- Analogous colors
  ImGui.Text(ctx, "Analogous (±30°):")
  local analogous = Style.create_analogous_button_set(state.current_hue)
  local x, y = ImGui.GetCursorScreenPos(ctx)

  draw_colored_button(ctx, x, y, 80, 28, analogous.left, "-30°")
  draw_colored_button(ctx, x + 85, y, 80, 28, analogous.main, "Base")
  draw_colored_button(ctx, x + 170, y, 80, 28, analogous.right, "+30°")

  ImGui.Dummy(ctx, 1, 35)
  ImGui.Spacing(ctx)

  -- Complementary
  ImGui.Text(ctx, "Complementary (±180°):")
  x, y = ImGui.GetCursorScreenPos(ctx)
  local base_preset = Style.create_colored_button_preset(state.current_hue, 0.70, 0.50)
  local complement = Style.create_complementary_button(state.current_hue)

  draw_colored_button(ctx, x, y, 100, 28, base_preset, "Base")
  draw_colored_button(ctx, x + 105, y, 100, 28, complement, "Opposite")

  ImGui.Dummy(ctx, 1, 35)
  ImGui.Spacing(ctx)

  -- Triadic
  ImGui.Text(ctx, "Triadic (120° apart):")
  x, y = ImGui.GetCursorScreenPos(ctx)
  local triadic = Style.create_triadic_button_set(state.current_hue)

  for i, preset in ipairs(triadic) do
    draw_colored_button(ctx, x + (i - 1) * 85, y, 80, 28, preset, string.format("%d°", (i - 1) * 120))
  end

  ImGui.Dummy(ctx, 1, 35)
end

local function draw_saturation_lightness_variants(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
  ImGui.Text(ctx, "Saturation & Lightness Variants:")
  ImGui.Spacing(ctx)

  -- Saturation variants
  ImGui.Text(ctx, "Saturation Variants (same lightness, different saturation):")
  local sat_variants = Style.create_saturation_variants(state.current_hue, state.current_light)
  local x, y = ImGui.GetCursorScreenPos(ctx)

  draw_colored_button(ctx, x, y, 90, 28, sat_variants.muted, "Muted (30%)")
  draw_colored_button(ctx, x + 95, y, 90, 28, sat_variants.normal, "Normal (65%)")
  draw_colored_button(ctx, x + 190, y, 90, 28, sat_variants.vivid, "Vivid (85%)")

  ImGui.Dummy(ctx, 1, 35)
  ImGui.Spacing(ctx)

  -- Lightness variants
  ImGui.Text(ctx, "Lightness Variants (same saturation, different lightness):")
  local light_variants = Style.create_lightness_variants(state.current_hue, state.current_sat)
  x, y = ImGui.GetCursorScreenPos(ctx)

  draw_colored_button(ctx, x, y, 90, 28, light_variants.dark, "Dark (35%)")
  draw_colored_button(ctx, x + 95, y, 90, 28, light_variants.normal, "Normal (48%)")
  draw_colored_button(ctx, x + 190, y, 90, 28, light_variants.light, "Light (62%)")

  ImGui.Dummy(ctx, 1, 35)
  ImGui.Spacing(ctx)

  -- Monochromatic set
  ImGui.Text(ctx, "Monochromatic Palette (same hue, varying sat/light):")
  local mono = Style.create_monochromatic_set(state.current_hue)
  x, y = ImGui.GetCursorScreenPos(ctx)

  local mono_buttons = {
    {"bold", "Bold"},
    {"primary", "Primary"},
    {"secondary", "Secondary"},
    {"subtle", "Subtle"},
    {"accent", "Accent"},
  }

  for i, btn in ipairs(mono_buttons) do
    local key, label = btn[1], btn[2]
    draw_colored_button(ctx, x, y, 100, 28, mono[key], label)
    y = y + 33
    ImGui.SetCursorScreenPos(ctx, x, y)
  end

  ImGui.Dummy(ctx, 1, 5)
end

local function draw_theme_integration(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
  ImGui.Text(ctx, "Theme Integration:")
  ImGui.Spacing(ctx)

  ImGui.TextWrapped(ctx, "The BUTTON_PRIMARY preset uses the theme's accent hue. Change themes to see it adapt:")
  ImGui.Spacing(ctx)

  local themes = {"dark", "light", "midnight", "pro_tools"}
  for _, theme in ipairs(themes) do
    if ImGui.Button(ctx, theme, 100, 25) then
      ThemeManager.apply_theme(theme)
      -- Regenerate PRIMARY to use new theme accent
      Style.DYNAMIC_PRESETS.BUTTON_PRIMARY = Style.create_colored_button_preset(nil, 0.70, 0.50)
    end
    ImGui.SameLine(ctx)
  end
  ImGui.NewLine(ctx)

  ImGui.Spacing(ctx)
  local primary = Style.DYNAMIC_PRESETS.BUTTON_PRIMARY
  local x, y = ImGui.GetCursorScreenPos(ctx)
  draw_colored_button(ctx, x, y, 150, 32, primary, "Theme Primary")
  ImGui.Dummy(ctx, 1, 35)
end

local function main()
  ImGui.SetNextWindowSize(ctx, 900, 800, ImGui.Cond_FirstUseEver)

  local visible, window_open = ImGui.Begin(ctx, 'Colored Button Presets Demo', true)
  if not visible then
    ImGui.End(ctx)
    return window_open
  end

  ImGui.Text(ctx, "Algorithmic Colored Buttons from Hue Variations")
  ImGui.TextWrapped(ctx, "All buttons maintain consistent saturation/lightness relationships, differing only in hue. This ensures visual harmony and allows adaptation to theme changes.")
  ImGui.Spacing(ctx)

  -- Custom preview
  draw_custom_preview(ctx)

  -- Semantic presets
  draw_semantic_presets(ctx)

  -- Color theory sets
  draw_color_theory_sets(ctx)

  -- Saturation/lightness variants
  draw_saturation_lightness_variants(ctx)

  -- Theme integration
  draw_theme_integration(ctx)

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

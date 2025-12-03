-- @noindex
-- Demo: Dynamic Config Builders
-- Test the new dynamic config system without modifying widgets

local ImGui = require('arkitekt.core.imgui')
local Style = require('arkitekt.gui.style')
local ThemeManager = require('arkitekt.theme.manager')
local Colors = require('arkitekt.core.colors')

-- ============================================================================
-- TEST: Dynamic Config vs Static Config
-- ============================================================================

local state = {
  current_theme = 'dark',
  test_results = {},
}

local function run_test()
  state.test_results = {}

  -- Test 1: Build config from current theme
  local config1 = Style.build_button_config()
  local bg1 = config1.bg_color
  state.test_results[#state.test_results + 1] = {
    test = 'Initial button bg',
    value = string.format('0x%08X', bg1),
    passed = true,
  }

  -- Test 2: Change theme
  ThemeManager.apply_theme('light')

  -- Test 3: Build config again (should have new colors)
  local config2 = Style.build_button_config()
  local bg2 = config2.bg_color

  state.test_results[#state.test_results + 1] = {
    test = 'After theme change',
    value = string.format('0x%08X', bg2),
    passed = (bg1 ~= bg2),  -- Should be different!
  }

  -- Test 4: Apply dynamic preset
  local config3 = Style.build_button_config()
  Style.apply_dynamic_preset(config3, 'BUTTON_TOGGLE_TEAL')

  state.test_results[#state.test_results + 1] = {
    test = 'Preset applied (TEAL',
    value = string.format('bg_on = 0x%08X', config3.bg_on_color or 0),
    passed = (config3.bg_on_color ~= nil),
  })

  -- Test 5: Verify preset uses M.COLORS
  local teal_before = Style.COLORS.ACCENT_TEAL
  local config4 = Style.build_button_config()
  Style.apply_dynamic_preset(config4, 'BUTTON_TOGGLE_TEAL')
  local preset_color = config4.bg_on_color

  state.test_results[#state.test_results + 1] = {
    test = 'Preset references M.COLORS',
    value = string.format('ACCENT_TEAL = 0x%08X', teal_before),
    passed = (preset_color == teal_before),
  }

  -- Test 6: Change M.COLORS directly and rebuild
  Style.COLORS.ACCENT_TEAL = Colors.Hexrgb('#FF0000FF')  -- Red
  local config5 = Style.build_button_config()
  Style.apply_dynamic_preset(config5, 'BUTTON_TOGGLE_TEAL')

  state.test_results[#state.test_results + 1] = {
    test = 'Preset adapts to M.COLORS change',
    value = string.format('New color = 0x%08X', config5.bg_on_color or 0),
    passed = (config5.bg_on_color == Colors.Hexrgb('#FF0000FF')),
  }

  -- Restore original theme
  ThemeManager.apply_theme('dark')
end

-- ============================================================================
-- UI
-- ============================================================================

local ctx = ImGui.CreateContext('Dynamic Config Demo')

local function draw_color_swatch(ctx, color, size)
  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.DrawList_AddRectFilled(dl, x, y, x + size, y + size, color)
  ImGui.DrawList_AddRect(dl, x, y, x + size, y + size, 0xFFFFFFFF)
  ImGui.Dummy(ctx, size, size)
end

local function main()
  ImGui.SetNextWindowSize(ctx, 700, 500, ImGui.Cond_FirstUseEver)

  local visible, window_open = ImGui.Begin(ctx, 'Dynamic Config Test', true)
  if not visible then
    ImGui.End(ctx)
    return window_open
  end

  ImGui.Text(ctx, 'Testing Dynamic Config Builders (Option 3)')
  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Run test button
  if ImGui.Button(ctx, 'Run Tests', 150, 30) then
    run_test()
  end

  ImGui.Spacing(ctx)

  -- Show test results
  if #state.test_results > 0 then
    ImGui.Text(ctx, 'Test Results:')
    ImGui.Spacing(ctx)

    for i, result in ipairs(state.test_results) do
      local status_color = result.passed and 0x4CAF50FF or 0xEF5350FF
      local status_text = result.passed and '[PASS]' or '[FAIL]'

      ImGui.TextColored(ctx, status_color, status_text)
      ImGui.SameLine(ctx)
      ImGui.Text(ctx, result.test)

      ImGui.Text(ctx, '  → ' .. result.value)
      ImGui.Spacing(ctx)
    end
  end

  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Live color display
  ImGui.Text(ctx, 'Current Theme Colors (M.COLORS):')
  ImGui.Spacing(ctx)

  local colors_to_show = {
    {'BG_BASE', 'Background'},
    {'BG_HOVER', 'Hover'},
    {'TEXT_NORMAL', 'Text'},
    {'ACCENT_TEAL', 'Teal Accent'},
    {'ACCENT_WHITE', 'White Accent'},
  }

  for _, pair in ipairs(colors_to_show) do
    local key, label = pair[1], pair[2]
    local color = Style.COLORS[key]

    if color then
      draw_color_swatch(ctx, color, 20)
      ImGui.SameLine(ctx)

      local r, g, b, a = Colors.RgbaToComponents(color)
      ImGui.Text(ctx, string.format('%s: #%02X%02X%02X', label, r, g, b))
    end
  end

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Manual theme switcher
  ImGui.Text(ctx, 'Change Theme:')
  ImGui.Spacing(ctx)

  local themes = {'dark', 'light', 'midnight', 'pro_tools'}
  for _, theme in ipairs(themes) do
    if ImGui.Button(ctx, theme, 100, 25) then
      ThemeManager.apply_theme(theme)
      state.current_theme = theme
    end
    ImGui.SameLine(ctx)
  end
  ImGui.NewLine(ctx)

  ImGui.Text(ctx, 'Current: ' .. state.current_theme)
  ImGui.Spacing(ctx)

  -- Instructions
  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
  ImGui.TextWrapped(ctx, "This demo shows that the new dynamic config builders work correctly. When you switch themes, the config builders read the NEW colors from M.COLORS. Click 'Run Tests' to verify the system works as expected.")

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

-- Run initial test
run_test()

reaper.defer(loop)

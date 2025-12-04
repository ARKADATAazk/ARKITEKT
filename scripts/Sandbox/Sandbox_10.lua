-- @noindex
-- ARKITEKT vs ImGui Performance Benchmark

-- Bootstrap ARKITEKT
local sep = package.config:sub(1,1)
local src = debug.getinfo(1, 'S').source:sub(2)
local path = src:match('(.*'..sep..')')
local ark_path
while path and #path > 3 do
  local init = path .. 'ARKITEKT' .. sep .. 'arkitekt' .. sep .. 'init.lua'
  local f = io.open(init, 'r')
  if f then
    f:close()
    ark_path = init
    break
  end
  path = path:match('(.*'..sep..')[^'..sep..']-'..sep..'$')
end

if not ark_path then
  reaper.MB('ARKITEKT framework not found!', 'FATAL ERROR', 0)
  return
end

local Ark = dofile(ark_path)
local ImGui = Ark.ImGui
local Shell = require('arkitekt.runtime.shell')

local WIDGET_COUNT = 1000
local results = {
  -- Button tests
  imgui_button = {},
  ark_button = {},
  ark_button_rounded = {},
  ark_button_raw = {},
  minimal_button = {},

  -- Other widget tests
  ark_checkbox = {},
  ark_slider = {},
  imgui_slider = {},
}

-- ============================================================================
-- BUTTON BENCHMARKS
-- ============================================================================

local function benchmark_imgui_button(ctx)
  local start = reaper.time_precise()
  for i = 1, WIDGET_COUNT do
    ImGui.PushID(ctx, i)
    if ImGui.Button(ctx, 'Button') then end
    ImGui.PopID(ctx)
    if i % 20 == 0 then ImGui.NewLine(ctx) end
  end
  local elapsed = reaper.time_precise() - start
  table.insert(results.imgui_button, elapsed)
end

-- Manual vertex count observation (from ImGui Metrics/Debugger):
-- Ark button (1000): ~75,000 vertices (~75 per button)
-- ImGui button (1000): ~3,778 vertices (~3.8 per button, mostly text)
local function benchmark_ark_button(ctx)
  local start = reaper.time_precise()
  for i = 1, WIDGET_COUNT do
    Ark.PushID(ctx, i)
    if Ark.Button(ctx, 'Button') then end
    Ark.PopID(ctx)
    if i % 20 == 0 then ImGui.NewLine(ctx) end
  end
  local elapsed = reaper.time_precise() - start
  table.insert(results.ark_button, elapsed)
end

local function benchmark_ark_button_rounded(ctx)
  local start = reaper.time_precise()
  for i = 1, WIDGET_COUNT do
    Ark.PushID(ctx, i)
    if Ark.Button(ctx, { label = 'Button', rounding = 4 }).clicked then end
    Ark.PopID(ctx)
    if i % 20 == 0 then ImGui.NewLine(ctx) end
  end
  local elapsed = reaper.time_precise() - start
  table.insert(results.ark_button_rounded, elapsed)
end

local Button = require('arkitekt.gui.widgets.primitives.button')
local function benchmark_ark_button_raw(ctx)
  local start = reaper.time_precise()
  for i = 1, WIDGET_COUNT do
    Ark.PushID(ctx, i)
    local opts = { label = 'Button' }
    Button.draw(ctx, opts)
    Ark.PopID(ctx)
    if i % 20 == 0 then ImGui.NewLine(ctx) end
  end
  local elapsed = reaper.time_precise() - start
  table.insert(results.ark_button_raw, elapsed)
end

local function benchmark_minimal_button(ctx)
  local start = reaper.time_precise()
  for i = 1, WIDGET_COUNT do
    ImGui.PushID(ctx, i)
    local x, y = ImGui.GetCursorScreenPos(ctx)
    ImGui.InvisibleButton(ctx, '##btn', 50, 24)
    local dl = ImGui.GetWindowDrawList(ctx)
    -- Single rect + text (like ImGui does internally)
    ImGui.DrawList_AddRectFilled(dl, x, y, x + 50, y + 24, 0xFF333333, 0)
    ImGui.DrawList_AddText(dl, x + 10, y + 5, 0xFFFFFFFF, 'Button')
    ImGui.PopID(ctx)
    if i % 20 == 0 then ImGui.NewLine(ctx) end
  end
  local elapsed = reaper.time_precise() - start
  table.insert(results.minimal_button, elapsed)
end

-- ============================================================================
-- OTHER WIDGET BENCHMARKS
-- ============================================================================

local Checkbox = require('arkitekt.gui.widgets.primitives.checkbox')
local function benchmark_ark_checkbox(ctx)
  local start = reaper.time_precise()
  for i = 1, WIDGET_COUNT do
    Ark.PushID(ctx, i)
    Checkbox.draw(ctx, { label = 'Check', value = false })
    Ark.PopID(ctx)
    if i % 20 == 0 then ImGui.NewLine(ctx) end
  end
  local elapsed = reaper.time_precise() - start
  table.insert(results.ark_checkbox, elapsed)
end

-- Manual vertex count observation (from ImGui Metrics/Debugger):
-- Ark slider (1000): ~30,000 vertices (~30 per slider)
-- ImGui slider (1000): ~3,000 vertices (~3 per slider)
local Slider = require('arkitekt.gui.widgets.primitives.slider')
local slider_value = 0.5
local function benchmark_ark_slider(ctx)
  local start = reaper.time_precise()
  for i = 1, WIDGET_COUNT do
    Ark.PushID(ctx, i)
    Slider.draw(ctx, { value = slider_value, min = 0, max = 1, width = 100 })
    Ark.PopID(ctx)
    if i % 20 == 0 then ImGui.NewLine(ctx) end
  end
  local elapsed = reaper.time_precise() - start
  table.insert(results.ark_slider, elapsed)
end

local function benchmark_imgui_slider(ctx)
  local start = reaper.time_precise()
  for i = 1, WIDGET_COUNT do
    ImGui.PushID(ctx, i)
    local _, val = ImGui.SliderDouble(ctx, '##slider', slider_value, 0, 1)
    ImGui.PopID(ctx)
    if i % 20 == 0 then ImGui.NewLine(ctx) end
  end
  local elapsed = reaper.time_precise() - start
  table.insert(results.imgui_slider, elapsed)
end

local function average(t)
  if #t == 0 then return 0 end
  local sum = 0
  for _, v in ipairs(t) do sum = sum + v end
  return sum / #t
end

local mode = 'imgui_button'

Shell.run({
  title = 'ARKITEKT Benchmark',
  initial_size = { w = 1000, h = 700 },

  draw = function(ctx, shell_state)
    -- BUTTON TESTS
    ImGui.Text(ctx, 'BUTTON TESTS:')
    if Ark.Button(ctx, 'ImGui Button') then
      mode = 'imgui_button'
      results.imgui_button = {}
    end
    ImGui.SameLine(ctx)
    if Ark.Button(ctx, 'Ark Button') then
      mode = 'ark_button'
      results.ark_button = {}
    end
    ImGui.SameLine(ctx)
    if Ark.Button(ctx, 'Ark Rounded') then
      mode = 'ark_button_rounded'
      results.ark_button_rounded = {}
    end
    ImGui.SameLine(ctx)
    if Ark.Button(ctx, 'Ark Raw') then
      mode = 'ark_button_raw'
      results.ark_button_raw = {}
    end
    ImGui.SameLine(ctx)
    if Ark.Button(ctx, 'Minimal') then
      mode = 'minimal_button'
      results.minimal_button = {}
    end

    -- OTHER WIDGET TESTS
    ImGui.Text(ctx, 'OTHER WIDGETS:')
    if Ark.Button(ctx, 'Checkbox') then
      mode = 'ark_checkbox'
      results.ark_checkbox = {}
    end
    ImGui.SameLine(ctx)
    if Ark.Button(ctx, 'Ark Slider') then
      mode = 'ark_slider'
      results.ark_slider = {}
    end
    ImGui.SameLine(ctx)
    if Ark.Button(ctx, 'ImGui Slider') then
      mode = 'imgui_slider'
      results.imgui_slider = {}
    end
    ImGui.SameLine(ctx)
    if Ark.Button(ctx, 'Clear All') then
      for k in pairs(results) do
        results[k] = {}
      end
    end

    ImGui.Separator(ctx)

    -- RESULTS
    ImGui.Text(ctx, string.format('Widget count: %d', WIDGET_COUNT))
    ImGui.Dummy(ctx, 0, 4)

    -- Button results
    ImGui.Text(ctx, 'BUTTON RESULTS:')
    ImGui.Text(ctx, string.format('  ImGui:         %.4f ms (%d)', average(results.imgui_button) * 1000, #results.imgui_button))
    ImGui.Text(ctx, string.format('  Ark:           %.4f ms (%d) - ~75 vtx/btn', average(results.ark_button) * 1000, #results.ark_button))
    ImGui.Text(ctx, string.format('  Ark Rounded:   %.4f ms (%d)', average(results.ark_button_rounded) * 1000, #results.ark_button_rounded))
    ImGui.Text(ctx, string.format('  Ark Raw:       %.4f ms (%d)', average(results.ark_button_raw) * 1000, #results.ark_button_raw))
    ImGui.Text(ctx, string.format('  Minimal:       %.4f ms (%d) - ~4 vtx/btn', average(results.minimal_button) * 1000, #results.minimal_button))

    if #results.imgui_button > 0 and #results.ark_button > 0 then
      local ratio = average(results.ark_button) / average(results.imgui_button)
      ImGui.Text(ctx, string.format('  → Ark is %.2fx slower than ImGui', ratio))
      ImGui.Text(ctx, '  → Ark has ~20x more vertices (75 vs ~4 per button)')
      ImGui.Text(ctx, '  → Overhead from dual borders + anti-aliasing')
    end

    if #results.ark_button > 0 and #results.ark_button_rounded > 0 then
      local diff = (average(results.ark_button_rounded) - average(results.ark_button)) * 1000
      ImGui.Text(ctx, string.format('  → Rounding adds %.4f ms', diff))
    end

    ImGui.Dummy(ctx, 0, 4)

    -- Other widget results
    ImGui.Text(ctx, 'OTHER WIDGET RESULTS:')
    ImGui.Text(ctx, string.format('  Checkbox:      %.4f ms (%d)', average(results.ark_checkbox) * 1000, #results.ark_checkbox))
    ImGui.Text(ctx, string.format('  Ark Slider:    %.4f ms (%d) - ~30 vtx/slider', average(results.ark_slider) * 1000, #results.ark_slider))
    ImGui.Text(ctx, string.format('  ImGui Slider:  %.4f ms (%d) - ~3 vtx/slider', average(results.imgui_slider) * 1000, #results.imgui_slider))

    if #results.imgui_slider > 0 and #results.ark_slider > 0 then
      local ratio = average(results.ark_slider) / average(results.imgui_slider)
      ImGui.Text(ctx, string.format('  → Ark Slider is %.2fx slower', ratio))
      ImGui.Text(ctx, '  → Ark has ~10x more vertices (30 vs 3 per slider)')
      ImGui.Text(ctx, '  → Overhead from borders, shadows, and anti-aliasing')
    end

    ImGui.Separator(ctx)

    -- Run benchmark in scrolling child
    if ImGui.BeginChild(ctx, '##widgets') then
      if mode == 'imgui_button' then
        benchmark_imgui_button(ctx)
      elseif mode == 'ark_button' then
        benchmark_ark_button(ctx)
      elseif mode == 'ark_button_rounded' then
        benchmark_ark_button_rounded(ctx)
      elseif mode == 'ark_button_raw' then
        benchmark_ark_button_raw(ctx)
      elseif mode == 'minimal_button' then
        benchmark_minimal_button(ctx)
      elseif mode == 'ark_checkbox' then
        benchmark_ark_checkbox(ctx)
      elseif mode == 'ark_slider' then
        benchmark_ark_slider(ctx)
      elseif mode == 'imgui_slider' then
        benchmark_imgui_slider(ctx)
      end
    end
    ImGui.EndChild(ctx)
  end,
})

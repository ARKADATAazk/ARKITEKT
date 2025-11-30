-- @noindex
-- ARKITEKT vs ImGui Performance Benchmark

-- Bootstrap ARKITEKT
local sep = package.config:sub(1,1)
local src = debug.getinfo(1, "S").source:sub(2)
local path = src:match("(.*"..sep..")")
local ark_path
while path and #path > 3 do
  local init = path .. "ARKITEKT" .. sep .. "arkitekt" .. sep .. "init.lua"
  local f = io.open(init, "r")
  if f then
    f:close()
    ark_path = init
    break
  end
  path = path:match("(.*"..sep..")[^"..sep.."]-"..sep.."$")
end

if not ark_path then
  reaper.MB("ARKITEKT framework not found!", "FATAL ERROR", 0)
  return
end

local Ark = dofile(ark_path)
local ImGui = Ark.ImGui
local Shell = require('arkitekt.app.shell')

local BUTTON_COUNT = 1000
local results = {
  imgui = {},
  ark = {},
  ark_raw = {},  -- Direct render test
  minimal = {},  -- Minimal DrawList test
}
local profiling = {
  setup = 0,
  render = 0,
  other = 0,
}

local function benchmark_imgui(ctx)
  local start = reaper.time_precise()

  for i = 1, BUTTON_COUNT do
    ImGui.PushID(ctx, i)
    if ImGui.Button(ctx, "Button") then end
    ImGui.PopID(ctx)
    if i % 20 == 0 then ImGui.NewLine(ctx) end
  end

  local elapsed = reaper.time_precise() - start
  table.insert(results.imgui, elapsed)
end

local function benchmark_ark(ctx)
  local start = reaper.time_precise()

  for i = 1, BUTTON_COUNT do
    Ark.PushID(ctx, i)
    if Ark.Button(ctx, "Button") then end  -- Use new positional API
    Ark.PopID(ctx)
    if i % 20 == 0 then ImGui.NewLine(ctx) end
  end

  local elapsed = reaper.time_precise() - start
  table.insert(results.ark, elapsed)
end

-- Test just the raw rendering part (bypass all the setup)
local Button = require('arkitekt.gui.widgets.primitives.button')
local function benchmark_ark_raw(ctx)
  local start = reaper.time_precise()

  for i = 1, BUTTON_COUNT do
    Ark.PushID(ctx, i)

    -- Call draw directly with pre-made opts (bypass __call wrapper)
    local opts = { label = "Button" }
    Button.draw(ctx, opts)

    Ark.PopID(ctx)
    if i % 20 == 0 then ImGui.NewLine(ctx) end
  end

  local elapsed = reaper.time_precise() - start
  table.insert(results.ark_raw, elapsed)
end

-- Test MINIMAL button (just InvisibleButton + text, no DrawList)
local function benchmark_minimal(ctx)
  local start = reaper.time_precise()

  for i = 1, BUTTON_COUNT do
    ImGui.PushID(ctx, i)

    -- Absolute minimal button simulation
    local x, y = ImGui.GetCursorScreenPos(ctx)
    ImGui.InvisibleButton(ctx, "##btn", 50, 24)
    local dl = ImGui.GetWindowDrawList(ctx)
    ImGui.DrawList_AddText(dl, x + 10, y + 5, 0xFFFFFFFF, "Button")

    ImGui.PopID(ctx)
    if i % 20 == 0 then ImGui.NewLine(ctx) end
  end

  local elapsed = reaper.time_precise() - start
  table.insert(results.minimal, elapsed)
end

local function average(t)
  if #t == 0 then return 0 end
  local sum = 0
  for _, v in ipairs(t) do sum = sum + v end
  return sum / #t
end

local mode = "imgui"  -- Toggle between tests

Shell.run({
  title = "ARKITEKT Benchmark",
  initial_size = { w = 900, h = 600 },

  draw = function(ctx, shell_state)
    -- Controls
    if Ark.Button(ctx, "Test ImGui") then
      mode = "imgui"
      results.imgui = {}
    end
    ImGui.SameLine(ctx)
    if Ark.Button(ctx, "Test ARKITEKT") then
      mode = "ark"
      results.ark = {}
    end
    ImGui.SameLine(ctx)
    if Ark.Button(ctx, "Test Raw") then
      mode = "raw"
      results.ark_raw = {}
    end
    ImGui.SameLine(ctx)
    if Ark.Button(ctx, "Test Minimal") then
      mode = "minimal"
      results.minimal = {}
    end
    ImGui.SameLine(ctx)
    if Ark.Button(ctx, "Clear Results") then
      results.imgui = {}
      results.ark = {}
      results.ark_raw = {}
      results.minimal = {}
    end

    -- Results
    ImGui.Text(ctx, string.format("Button count: %d", BUTTON_COUNT))
    ImGui.Text(ctx, string.format("ImGui avg:    %.4f ms (%d samples)", average(results.imgui) * 1000, #results.imgui))
    ImGui.Text(ctx, string.format("ARKITEKT avg: %.4f ms (%d samples)", average(results.ark) * 1000, #results.ark))
    ImGui.Text(ctx, string.format("Raw draw avg: %.4f ms (%d samples)", average(results.ark_raw) * 1000, #results.ark_raw))
    ImGui.Text(ctx, string.format("Minimal avg:  %.4f ms (%d samples)", average(results.minimal) * 1000, #results.minimal))

    if #results.imgui > 0 and #results.ark > 0 then
      local ratio = average(results.ark) / average(results.imgui)
      ImGui.Text(ctx, string.format("ARKITEKT is %.2fx slower than ImGui", ratio))
    end

    if #results.imgui > 0 and #results.minimal > 0 then
      local ratio = average(results.minimal) / average(results.imgui)
      ImGui.Text(ctx, string.format("Minimal is %.2fx slower than ImGui", ratio))
    end

    if #results.ark > 0 and #results.minimal > 0 then
      local overhead = average(results.ark) - average(results.minimal)
      local overhead_pct = (overhead / average(results.ark)) * 100
      ImGui.Text(ctx, string.format("Config+Theme overhead: %.4f ms (%.1f%%)", overhead * 1000, overhead_pct))
    end

    ImGui.Separator(ctx)

    -- Run benchmark in scrolling child
    if ImGui.BeginChild(ctx, "##buttons") then
      if mode == "imgui" then
        benchmark_imgui(ctx)
      elseif mode == "raw" then
        benchmark_ark_raw(ctx)
      elseif mode == "minimal" then
        benchmark_minimal(ctx)
      else
        benchmark_ark(ctx)
      end
    end
    ImGui.EndChild(ctx)
  end,
})

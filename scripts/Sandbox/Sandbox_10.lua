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

local function average(t)
  if #t == 0 then return 0 end
  local sum = 0
  for _, v in ipairs(t) do sum = sum + v end
  return sum / #t
end

local mode = "imgui"  -- Toggle between tests

Shell.run({
  title = "ARKITEKT Benchmark",
  initial_size = { w = 800, h = 600 },

  draw = function(ctx, shell_state)
    -- Controls
    if ImGui.Button(ctx, "Test ImGui") then
      mode = "imgui"
      results.imgui = {}
    end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Test ARKITEKT") then
      mode = "ark"
      results.ark = {}
    end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Clear Results") then
      results.imgui = {}
      results.ark = {}
    end

    -- Results
    ImGui.Text(ctx, string.format("Button count: %d", BUTTON_COUNT))
    ImGui.Text(ctx, string.format("ImGui avg: %.4f ms (%d samples)", average(results.imgui) * 1000, #results.imgui))
    ImGui.Text(ctx, string.format("ARKITEKT avg: %.4f ms (%d samples)", average(results.ark) * 1000, #results.ark))

    if #results.imgui > 0 and #results.ark > 0 then
      local ratio = average(results.ark) / average(results.imgui)
      ImGui.Text(ctx, string.format("ARKITEKT is %.2fx slower", ratio))
    end

    ImGui.Separator(ctx)

    -- Run benchmark in scrolling child
    if ImGui.BeginChild(ctx, "##buttons", -1, -1, ImGui.ChildFlags_Border) then
      if mode == "imgui" then
        benchmark_imgui(ctx)
      else
        benchmark_ark(ctx)
      end
    end
    ImGui.EndChild(ctx)
  end,
})

-- @noindex
-- Test script for Hybrid ID System (Decision 20)
-- Demonstrates PushID/PopID stack + explicit ID field

-- Load ARKITEKT
local ARK
do
  local sep = package.config:sub(1,1)
  local src = debug.getinfo(1, "S").source:sub(2)
  local path = src:match("(.*"..sep..")")
  while path and #path > 3 do
    local init = path .. "arkitekt" .. sep .. "app" .. sep .. "init" .. sep .. "init.lua"
    local f = io.open(init, "r")
    if f then
      f:close()
      ARK = dofile(init).bootstrap()
      break
    end
    path = path:match("(.*"..sep..")[^"..sep.."]-"..sep.."$")
  end
  if not ARK then
    reaper.MB("ARKITEKT framework not found!", "FATAL ERROR", 0)
    return
  end
end

local Ark = ARK.Ark
local Shell = ARK.Shell
local ctx = ARK.ctx

-- Test data
local tracks = {
  { name = "Track 1", items = {{label = "Item A"}, {label = "Item B"}} },
  { name = "Track 2", items = {{label = "Item C"}, {label = "Item D"}} },
  { name = "Track 3", items = {{label = "Item E"}, {label = "Item F"}} },
}

local function draw_ui()
  -- === EXAMPLE 1: Simple case (no stack, no ID) ===
  Ark.ImGui.SeparatorText(ctx, "Example 1: Simple Case (Auto ID from label)")
  Ark.Button(ctx, "Save")  -- ID = "Save" (auto from label)
  Ark.ImGui.SameLine(ctx)
  Ark.Button(ctx, "Load")  -- ID = "Load" (auto from label)

  -- === EXAMPLE 2: Multiple widgets with explicit ID ===
  Ark.ImGui.SeparatorText(ctx, "Example 2: Explicit IDs")
  Ark.Grid(ctx, { id = "active_grid", items = tracks[1].items })
  Ark.Grid(ctx, { id = "pool_grid", items = tracks[2].items })

  -- === EXAMPLE 3: Loop with PushID stack (ImGui way!) ===
  Ark.ImGui.SeparatorText(ctx, "Example 3: Loop with PushID Stack")
  for i, track in ipairs(tracks) do
    Ark.PushID(ctx, i)
      Ark.ImGui.Text(ctx, track.name)
      Ark.ImGui.SameLine(ctx)
      Ark.Button(ctx, "M")  -- ID = "1/M", "2/M", "3/M"
      Ark.ImGui.SameLine(ctx)
      Ark.Button(ctx, "S")  -- ID = "1/S", "2/S", "3/S"
      Ark.Grid(ctx, { items = track.items })  -- ID = "1/grid", "2/grid", "3/grid"
    Ark.PopID(ctx)
  end

  -- === EXAMPLE 4: Explicit ID overrides stack ===
  Ark.ImGui.SeparatorText(ctx, "Example 4: Explicit ID Overrides Stack")
  Ark.PushID(ctx, "section")
    Ark.Button(ctx, "Auto")  -- ID = "section/Auto" (uses stack)
    Ark.ImGui.SameLine(ctx)
    Ark.Button(ctx, { id = "fixed", label = "Override" })  -- ID = "fixed" (ignores stack)
  Ark.PopID(ctx)

  -- === EXAMPLE 5: Nested stacks ===
  Ark.ImGui.SeparatorText(ctx, "Example 5: Nested Stacks")
  Ark.PushID(ctx, "outer")
    Ark.Button(ctx, "A")  -- ID = "outer/A"
    Ark.PushID(ctx, "inner")
      Ark.Button(ctx, "B")  -- ID = "outer/inner/B"
    Ark.PopID(ctx)
    Ark.Button(ctx, "C")  -- ID = "outer/C"
  Ark.PopID(ctx)
end

-- Run the app
Shell.run({
  script_name = "Hybrid ID System Test",
  ctx = ctx,
  draw = draw_ui,
})

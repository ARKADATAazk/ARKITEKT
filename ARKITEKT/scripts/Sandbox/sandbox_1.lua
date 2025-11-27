-- @noindex
-- ARKITEKT/scripts/Sandbox/sandbox_1.lua
-- Hatched Fill Effects Demo

-- ============================================================================
-- BOOTSTRAP ARKITEKT FRAMEWORK
-- ============================================================================
local ark
do
  local sep = package.config:sub(1,1)
  local src = debug.getinfo(1, "S").source:sub(2)
  local path = src:match("(.*"..sep..")")
  while path and #path > 3 do
    local bootstrap = path .. "arkitekt" .. sep .. "app" .. sep .. "bootstrap.lua"
    local f = io.open(bootstrap, "r")
    if f then
      f:close()
      package.path = path .. "?.lua;" .. path .. "?" .. sep .. "init.lua;" .. package.path
      package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
      ark = require('arkitekt')
      break
    end
    path = path:match("(.*"..sep..")[^"..sep.."]-"..sep.."$")
  end
  if not ark then
    reaper.MB("ARKITEKT framework not found!", "FATAL ERROR", 0)
    return
  end
end

local Shell = require('arkitekt.app.shell')
local HatchedFill = require('arkitekt.gui.widgets.effects.hatched_fill')

local ImGui = ark.ImGui
local hexrgb = ark.Colors.hexrgb

-- Demo state
local demo_state = {
  spacing = 8,
  thickness = 1,
  overflow = 25,
  glow_layers = 4,
  animate_speed = 40,
  show_background = true,
}

Shell.run({
  title = "Hatched Fill Effects Demo",
  version = "v0.1.0",
  version_color = hexrgb("#888888FF"),
  initial_pos = { x = 100, y = 100 },
  initial_size = { w = 900, h = 700 },
  min_size = { w = 600, h = 400 },

  draw = function(ctx, shell_state)
    local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)

    -- Controls
    ImGui.Text(ctx, "Controls:")
    ImGui.SameLine(ctx, 100)
    local _, spacing = ImGui.SliderInt(ctx, "Spacing##ctrl", demo_state.spacing, 2, 20)
    demo_state.spacing = spacing

    ImGui.SameLine(ctx, 300)
    local _, thickness = ImGui.SliderDouble(ctx, "Thickness##ctrl", demo_state.thickness, 0.5, 4)
    demo_state.thickness = thickness

    ImGui.SameLine(ctx, 520)
    local _, overflow = ImGui.SliderInt(ctx, "Overflow##ctrl", demo_state.overflow, 5, 50)
    demo_state.overflow = overflow

    local _, glow_layers = ImGui.SliderInt(ctx, "Glow Layers##ctrl", demo_state.glow_layers, 1, 8)
    demo_state.glow_layers = glow_layers

    ImGui.SameLine(ctx, 200)
    local _, animate_speed = ImGui.SliderInt(ctx, "Animation Speed##ctrl", demo_state.animate_speed, 0, 100)
    demo_state.animate_speed = animate_speed

    ImGui.SameLine(ctx, 450)
    local _, show_bg = ImGui.Checkbox(ctx, "Show Background", demo_state.show_background)
    demo_state.show_background = show_bg

    ImGui.Separator(ctx)
    ImGui.Dummy(ctx, 0, 10)

    local dl = ImGui.GetWindowDrawList(ctx)
    local win_x, win_y = ImGui.GetCursorScreenPos(ctx)

    -- Row 1: Basic directions
    ImGui.Text(ctx, "Basic Directions (with clip rect):")
    ImGui.Dummy(ctx, 0, 5)

    local row1_y = select(2, ImGui.GetCursorScreenPos(ctx))
    local box_w, box_h = 150, 100
    local gap = 20

    -- Forward diagonal
    local x1 = win_x + 10
    if demo_state.show_background then
      ImGui.DrawList_AddRectFilled(dl, x1, row1_y, x1 + box_w, row1_y + box_h, hexrgb("#1a1a1aFF"), 4)
    end
    HatchedFill.draw(ctx, {
      x = x1, y = row1_y, w = box_w, h = box_h,
      direction = HatchedFill.DIRECTION.FORWARD,
      color = hexrgb("#4488FFAA"),
      spacing = demo_state.spacing,
      thickness = demo_state.thickness,
      animate_speed = demo_state.animate_speed,
      draw_list = dl,
    })
    ImGui.DrawList_AddRect(dl, x1, row1_y, x1 + box_w, row1_y + box_h, hexrgb("#4488FF"), 4)
    ImGui.DrawList_AddText(dl, x1 + 5, row1_y + box_h - 18, hexrgb("#FFFFFFCC"), "FORWARD")

    -- Backward diagonal
    local x2 = x1 + box_w + gap
    if demo_state.show_background then
      ImGui.DrawList_AddRectFilled(dl, x2, row1_y, x2 + box_w, row1_y + box_h, hexrgb("#1a1a1aFF"), 4)
    end
    HatchedFill.draw(ctx, {
      x = x2, y = row1_y, w = box_w, h = box_h,
      direction = HatchedFill.DIRECTION.BACKWARD,
      color = hexrgb("#FF8844AA"),
      spacing = demo_state.spacing,
      thickness = demo_state.thickness,
      animate_speed = demo_state.animate_speed,
      draw_list = dl,
    })
    ImGui.DrawList_AddRect(dl, x2, row1_y, x2 + box_w, row1_y + box_h, hexrgb("#FF8844"), 4)
    ImGui.DrawList_AddText(dl, x2 + 5, row1_y + box_h - 18, hexrgb("#FFFFFFCC"), "BACKWARD")

    -- Cross-hatch (both)
    local x3 = x2 + box_w + gap
    if demo_state.show_background then
      ImGui.DrawList_AddRectFilled(dl, x3, row1_y, x3 + box_w, row1_y + box_h, hexrgb("#1a1a1aFF"), 4)
    end
    HatchedFill.draw(ctx, {
      x = x3, y = row1_y, w = box_w, h = box_h,
      direction = HatchedFill.DIRECTION.BOTH,
      color = hexrgb("#44FF88AA"),
      spacing = demo_state.spacing,
      thickness = demo_state.thickness,
      draw_list = dl,
    })
    ImGui.DrawList_AddRect(dl, x3, row1_y, x3 + box_w, row1_y + box_h, hexrgb("#44FF88"), 4)
    ImGui.DrawList_AddText(dl, x3 + 5, row1_y + box_h - 18, hexrgb("#FFFFFFCC"), "BOTH (cross)")

    -- Horizontal lines
    local x4 = x3 + box_w + gap
    if demo_state.show_background then
      ImGui.DrawList_AddRectFilled(dl, x4, row1_y, x4 + box_w, row1_y + box_h, hexrgb("#1a1a1aFF"), 4)
    end
    HatchedFill.draw(ctx, {
      x = x4, y = row1_y, w = box_w, h = box_h,
      direction = HatchedFill.DIRECTION.HORIZONTAL,
      color = hexrgb("#FF44AAAA"),
      spacing = demo_state.spacing,
      thickness = demo_state.thickness,
      draw_list = dl,
    })
    ImGui.DrawList_AddRect(dl, x4, row1_y, x4 + box_w, row1_y + box_h, hexrgb("#FF44AA"), 4)
    ImGui.DrawList_AddText(dl, x4 + 5, row1_y + box_h - 18, hexrgb("#FFFFFFCC"), "HORIZONTAL")

    -- Vertical lines
    local x5 = x4 + box_w + gap
    if demo_state.show_background then
      ImGui.DrawList_AddRectFilled(dl, x5, row1_y, x5 + box_w, row1_y + box_h, hexrgb("#1a1a1aFF"), 4)
    end
    HatchedFill.draw(ctx, {
      x = x5, y = row1_y, w = box_w, h = box_h,
      direction = HatchedFill.DIRECTION.VERTICAL,
      color = hexrgb("#AAFF44AA"),
      spacing = demo_state.spacing,
      thickness = demo_state.thickness,
      draw_list = dl,
    })
    ImGui.DrawList_AddRect(dl, x5, row1_y, x5 + box_w, row1_y + box_h, hexrgb("#AAFF44"), 4)
    ImGui.DrawList_AddText(dl, x5 + 5, row1_y + box_h - 18, hexrgb("#FFFFFFCC"), "VERTICAL")

    ImGui.Dummy(ctx, 0, box_h + 20)

    -- Row 2: Glitch effects (the original bug turned into art)
    ImGui.Text(ctx, "Glitch Effects (the original bug - curved exponential patterns):")
    ImGui.Dummy(ctx, 0, 5)

    local row2_y = select(2, ImGui.GetCursorScreenPos(ctx))
    local glitch_w, glitch_h = 180, 120

    -- Glitch effect (original bug)
    x1 = win_x + 30
    HatchedFill.draw_glitch(ctx, {
      x = x1, y = row2_y, w = glitch_w, h = glitch_h,
      color = hexrgb("#FF5555CC"),
      spacing = demo_state.spacing,
      thickness = demo_state.thickness,
      intensity = 1.0 + (demo_state.overflow / 50),
      layers = demo_state.glow_layers,
      show_box = true,
      draw_list = dl,
    })
    ImGui.DrawList_AddText(dl, x1 + 5, row2_y + glitch_h + 5, hexrgb("#FFFFFFAA"), "GLITCH (original bug)")

    -- Curved effect (exponential)
    x2 = x1 + glitch_w + gap + 40
    HatchedFill.draw_curved(ctx, {
      x = x2, y = row2_y, w = glitch_w, h = glitch_h,
      color = hexrgb("#55FF55CC"),
      spacing = demo_state.spacing,
      thickness = demo_state.thickness,
      curve_factor = 1.0 + (demo_state.overflow / 20),
      layers = demo_state.glow_layers,
      direction = "both",
      draw_list = dl,
    })
    ImGui.DrawList_AddRect(dl, x2, row2_y, x2 + glitch_w, row2_y + glitch_h, hexrgb("#55FF5580"), 0, 0, 1)
    ImGui.DrawList_AddText(dl, x2 + 5, row2_y + glitch_h + 5, hexrgb("#FFFFFFAA"), "CURVED (exponential)")

    -- Curved forward only
    x3 = x2 + glitch_w + gap + 40
    HatchedFill.draw_curved(ctx, {
      x = x3, y = row2_y, w = glitch_w, h = glitch_h,
      color = hexrgb("#5555FFCC"),
      spacing = demo_state.spacing,
      thickness = demo_state.thickness,
      curve_factor = 2.5,
      layers = demo_state.glow_layers,
      direction = "forward",
      draw_list = dl,
    })
    ImGui.DrawList_AddRect(dl, x3, row2_y, x3 + glitch_w, row2_y + glitch_h, hexrgb("#5555FF80"), 0, 0, 1)
    ImGui.DrawList_AddText(dl, x3 + 5, row2_y + glitch_h + 5, hexrgb("#FFFFFFAA"), "CURVED (forward)")

    ImGui.Dummy(ctx, 0, glitch_h + 40)

    -- Row 3: Marching ants
    ImGui.Text(ctx, "Marching Ants (animated dashed border):")
    ImGui.Dummy(ctx, 0, 5)

    local row3_y = select(2, ImGui.GetCursorScreenPos(ctx))

    x1 = win_x + 10
    if demo_state.show_background then
      ImGui.DrawList_AddRectFilled(dl, x1, row3_y, x1 + box_w * 2, row3_y + box_h, hexrgb("#1a1a1aFF"), 4)
    end
    HatchedFill.draw_marching_ants(ctx, {
      x = x1, y = row3_y, w = box_w * 2, h = box_h,
      color = hexrgb("#FFFFFFCC"),
      dash_length = 6,
      gap_length = 4,
      thickness = 2,
      speed = demo_state.animate_speed,
      draw_list = dl,
    })
    ImGui.DrawList_AddText(dl, x1 + 10, row3_y + 10, hexrgb("#FFFFFFAA"), "Selection indicator style")

    x2 = x1 + box_w * 2 + gap + 20
    if demo_state.show_background then
      ImGui.DrawList_AddRectFilled(dl, x2, row3_y, x2 + box_w * 2, row3_y + box_h, hexrgb("#2a2a3aFF"), 4)
    end
    HatchedFill.draw_marching_ants(ctx, {
      x = x2, y = row3_y, w = box_w * 2, h = box_h,
      color = hexrgb("#FFAA44FF"),
      dash_length = 10,
      gap_length = 6,
      thickness = 1,
      speed = demo_state.animate_speed * 0.5,
      draw_list = dl,
    })
    ImGui.DrawList_AddText(dl, x2 + 10, row3_y + 10, hexrgb("#FFAA44AA"), "Slow variant")

    ImGui.Dummy(ctx, 0, box_h + 20)

    -- Row 4: Combined usage
    ImGui.Text(ctx, "Combined Usage Examples:")
    ImGui.Dummy(ctx, 0, 5)

    local row4_y = select(2, ImGui.GetCursorScreenPos(ctx))

    -- Progress bar style
    x1 = win_x + 10
    local progress = (math.sin(ImGui.GetTime(ctx)) + 1) * 0.5  -- 0 to 1
    local progress_w = box_w * 2
    local fill_w = progress_w * progress

    ImGui.DrawList_AddRectFilled(dl, x1, row4_y, x1 + progress_w, row4_y + 30, hexrgb("#222222FF"), 4)
    if fill_w > 4 then
      ImGui.DrawList_AddRectFilled(dl, x1, row4_y, x1 + fill_w, row4_y + 30, hexrgb("#335533FF"), 4)
      HatchedFill.draw(ctx, {
        x = x1 + 2, y = row4_y + 2, w = fill_w - 4, h = 26,
        direction = HatchedFill.DIRECTION.FORWARD,
        color = hexrgb("#55FF5560"),
        spacing = 6,
        thickness = 1,
        animate_speed = 60,
        draw_list = dl,
      })
    end
    ImGui.DrawList_AddRect(dl, x1, row4_y, x1 + progress_w, row4_y + 30, hexrgb("#55FF5580"), 4)
    ImGui.DrawList_AddText(dl, x1 + progress_w / 2 - 30, row4_y + 7, hexrgb("#FFFFFFCC"),
      string.format("Progress: %.0f%%", progress * 100))

    -- Danger zone
    x2 = x1 + progress_w + gap + 20
    ImGui.DrawList_AddRectFilled(dl, x2, row4_y, x2 + box_w, row4_y + 50, hexrgb("#331111FF"), 4)
    HatchedFill.draw(ctx, {
      x = x2, y = row4_y, w = box_w, h = 50,
      direction = HatchedFill.DIRECTION.FORWARD,
      color = hexrgb("#FF333380"),
      spacing = 10,
      thickness = 2,
      draw_list = dl,
    })
    ImGui.DrawList_AddRect(dl, x2, row4_y, x2 + box_w, row4_y + 50, hexrgb("#FF3333"), 4)
    ImGui.DrawList_AddText(dl, x2 + 20, row4_y + 16, hexrgb("#FF6666FF"), "DANGER ZONE")
  end,
})

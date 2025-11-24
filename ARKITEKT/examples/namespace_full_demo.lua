-- ARKITEKT Namespace Full Demo
-- Demonstrates ark.* syntax for widgets AND utilities

local ImGui = require('reaper_imgui')
local ark = require('arkitekt')

-- ONE import gives access to EVERYTHING:
-- ark.Button, ark.Checkbox, ark.Panel (widgets)
-- ark.Colors, ark.Style, ark.Draw, ark.Math (utilities)

local ctx = ImGui.CreateContext('ARKITEKT Full Demo')

local state = {
  checked = false,
  hue = 0.5,
  slider_value = 0.5,
}

local function loop()
  local visible, open = ImGui.Begin(ctx, 'Namespace Full Demo', true)
  if visible then
    -- Section 1: Primitives
    ImGui.SeparatorText(ctx, "Primitives (ark.Widget.draw)")

    if ark.Button.draw(ctx, {
      label = "Animated Button",
      width = 200,
      style = {
        bg = ark.Colors.hex_to_rgba("#3B82F6"),
        hover_bg = ark.Colors.hex_to_rgba("#2563EB"),
      }
    }) then
      reaper.ShowMessageBox("Using ark.Colors utility!", "Demo", 0)
    end

    ImGui.Spacing(ctx)

    state.checked = ark.Checkbox.draw(ctx, {
      label = "Toggle Feature",
      checked = state.checked
    })

    ImGui.Spacing(ctx)

    -- Using ark.Colors for dynamic theming
    local hue_color = ark.Colors.hsv_to_rgb(state.hue, 0.7, 0.9)
    ImGui.PushStyleColor(ctx, ImGui.Col_SliderGrab, ImGui.ColorConvertDouble4ToU32(hue_color))
    ImGui.PushStyleColor(ctx, ImGui.Col_SliderGrabActive, ImGui.ColorConvertDouble4ToU32(hue_color))

    _, state.hue = ImGui.SliderDouble(ctx, "Hue", state.hue, 0, 1)

    ImGui.PopStyleColor(ctx, 2)

    -- Section 2: Utilities
    ImGui.Spacing(ctx)
    ImGui.SeparatorText(ctx, "Utilities (ark.Colors, ark.Math, etc.)")

    ImGui.Text(ctx, string.format("ark.Colors.hsv_to_rgb(%.2f, 0.7, 0.9)", state.hue))
    ImGui.Text(ctx, string.format("  → R:%.2f G:%.2f B:%.2f A:%.2f", table.unpack(hue_color)))

    ImGui.Spacing(ctx)

    -- Demonstrate easing
    local eased = ark.Easing.ease_out_cubic(state.slider_value)
    ImGui.Text(ctx, string.format("ark.Easing.ease_out_cubic(%.2f) = %.2f", state.slider_value, eased))

    _, state.slider_value = ImGui.SliderDouble(ctx, "Easing Input", state.slider_value, 0, 1)

    -- Visual representation of easing
    local draw_list = ImGui.GetWindowDrawList(ctx)
    local x, y = ImGui.GetCursorScreenPos(ctx)
    local graph_w, graph_h = 200, 100

    -- Background
    ImGui.DrawList_AddRectFilled(draw_list, x, y, x + graph_w, y + graph_h,
                                 ImGui.ColorConvertDouble4ToU32(0.1, 0.1, 0.1, 1))

    -- Easing curve
    for i = 0, graph_w - 1 do
      local t = i / graph_w
      local ease_t = ark.Easing.ease_out_cubic(t)
      local x1 = x + i
      local y1 = y + graph_h - (ease_t * graph_h)
      ImGui.DrawList_AddCircleFilled(draw_list, x1, y1, 1,
                                     ImGui.ColorConvertDouble4ToU32(table.unpack(hue_color)))
    end

    -- Current position marker
    local marker_x = x + (state.slider_value * graph_w)
    local marker_y = y + graph_h - (eased * graph_h)
    ImGui.DrawList_AddCircleFilled(draw_list, marker_x, marker_y, 4,
                                   ImGui.ColorConvertDouble4ToU32(1, 1, 1, 1))

    ImGui.Dummy(ctx, graph_w, graph_h)

    -- Section 3: Summary
    ImGui.Spacing(ctx)
    ImGui.SeparatorText(ctx, "Summary")
    ImGui.TextWrapped(ctx,
      "The ark.* namespace provides:\n" ..
      "• 14 Primitives (Button, Checkbox, Slider, etc.)\n" ..
      "• 2 Containers (Panel, TileGroup)\n" ..
      "• 6 Utilities (Colors, Style, Draw, Easing, Math, UUID)\n\n" ..
      "All loaded lazily - only what you use is loaded!\n" ..
      "Just like ImGui.*, but for ARKITEKT."
    )

    ImGui.End(ctx)
  end

  if open then
    reaper.defer(loop)
  else
    ImGui.DestroyContext(ctx)
  end
end

reaper.defer(loop)

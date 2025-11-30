-- @noindex
-- Test script for SlidingZone callable pattern
-- Tests both old API (on_draw) and new API (draw) for backward compatibility

-- Bootstrap ARKITEKT
local script_path = debug.getinfo(1, 'S').source:match("@?(.*[\\/])") or ""
local arkitekt_path = script_path:match("(.+ARKITEKT[\\/])") or script_path:match("(.+arkitekt[\\/])")
if not arkitekt_path then
  reaper.ShowConsoleMsg("Error: Could not find ARKITEKT directory\n")
  return
end
package.path = arkitekt_path .. "?.lua;" .. package.path
local Ark = require('arkitekt')

local ctx = Ark.ImGui.CreateContext('SlidingZone Callable Test')
local ImGui = Ark.ImGui

local test_state = {
  mode = "new",  -- "new" or "old"
}

local function loop()
  local visible, open = ImGui.Begin(ctx, 'SlidingZone Callable Pattern Test', true)
  if visible then
    local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)
    local win_x, win_y = ImGui.GetWindowPos(ctx)
    local win_w, win_h = ImGui.GetWindowSize(ctx)

    -- Mode selector
    ImGui.Text(ctx, "API Test Mode:")
    ImGui.SameLine(ctx)
    if ImGui.RadioButton(ctx, "New (draw callback)", test_state.mode == "new") then
      test_state.mode = "new"
    end
    ImGui.SameLine(ctx)
    if ImGui.RadioButton(ctx, "Old (on_draw callback)", test_state.mode == "old") then
      test_state.mode = "old"
    end

    ImGui.Separator(ctx)

    -- Content area
    local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
    local content_bounds = {
      x = cursor_x,
      y = cursor_y,
      w = avail_w,
      h = avail_h - 50
    }

    -- Draw background
    local dl = ImGui.GetWindowDrawList(ctx)
    ImGui.DrawList_AddRectFilled(dl,
      content_bounds.x, content_bounds.y,
      content_bounds.x + content_bounds.w, content_bounds.y + content_bounds.h,
      0x202020FF)

    -- Test NEW callable pattern: Ark.SlidingZone(ctx, opts)
    if test_state.mode == "new" then
      local result = Ark.SlidingZone(ctx, {
        id = "test_zone_new",
        edge = "right",
        bounds = content_bounds,
        size = 200,
        trigger = "hover",
        bg_color = 0x304050FF,
        rounding = 8,
        window_bounds = { x = win_x, y = win_y, w = win_w, h = win_h },

        -- NEW API: draw callback (no state param)
        draw = function(ctx, dl, bounds, visibility)
          -- Draw content
          ImGui.DrawList_AddText(dl,
            bounds.x + 10, bounds.y + 10,
            0xFFFFFFFF,
            string.format("NEW API (draw)\nVisibility: %.2f", visibility))

          -- Test that we can call widgets
          ImGui.SetCursorScreenPos(ctx, bounds.x + 10, bounds.y + 50)
          if Ark.Button(ctx, "Test Button").clicked then
            reaper.ShowConsoleMsg("Button clicked in NEW API!\n")
          end
        end,
      })

      -- Show result
      ImGui.SetCursorScreenPos(ctx, cursor_x + 10, cursor_y + content_bounds.h - 30)
      ImGui.Text(ctx, string.format("Result: expanded=%s, visibility=%.2f",
        tostring(result.expanded), result.visibility))

    -- Test OLD API for backward compatibility: on_draw
    else
      local result = Ark.SlidingZone(ctx, {
        id = "test_zone_old",
        edge = "right",
        bounds = content_bounds,
        size = 200,
        trigger = "hover",
        bg_color = 0x503040FF,
        rounding = 8,
        window_bounds = { x = win_x, y = win_y, w = win_w, h = win_h },

        -- OLD API: on_draw callback (with state param) - BACKWARD COMPAT
        on_draw = function(ctx, dl, bounds, visibility, state)
          -- Draw content
          ImGui.DrawList_AddText(dl,
            bounds.x + 10, bounds.y + 10,
            0xFFFFFFFF,
            string.format("OLD API (on_draw)\nVisibility: %.2f\nState available: %s",
              visibility, tostring(state ~= nil)))

          -- Test that we can call widgets
          ImGui.SetCursorScreenPos(ctx, bounds.x + 10, bounds.y + 70)
          if Ark.Button(ctx, "Test Button").clicked then
            reaper.ShowConsoleMsg("Button clicked in OLD API!\n")
          end
        end,
      })

      -- Show result
      ImGui.SetCursorScreenPos(ctx, cursor_x + 10, cursor_y + content_bounds.h - 30)
      ImGui.Text(ctx, string.format("Result: expanded=%s, visibility=%.2f",
        tostring(result.expanded), result.visibility))
    end

    ImGui.End(ctx)
  end

  if open then
    reaper.defer(loop)
  else
    ImGui.DestroyContext(ctx)
  end
end

reaper.defer(loop)

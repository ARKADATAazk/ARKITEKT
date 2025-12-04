-- @noindex
-- ARKITEKT/scripts/Sandbox/sandbox_1.lua
-- Hatched Fill Effects Demo

-- ============================================================================
-- LOAD ARKITEKT FRAMEWORK
-- ============================================================================
local Ark = dofile(debug.getinfo(1,'S').source:sub(2):match('(.-ARKITEKT[/\\])') .. 'arkitekt' .. package.config:sub(1,1) .. 'init.lua')

local Shell = require('arkitekt.runtime.shell')
local HatchedFill = require('arkitekt.gui.widgets.effects.hatched_fill')

local ImGui = Ark.ImGui
-- Demo state
local demo_state = {
  active_tab = 1,
  spacing = 6,
  thickness = 1,
  intensity = 1.5,
  layers = 4,
  corner = 'bottom_right',
}

-- Tab definitions
local TABS = {
  { name = 'Corner Radial', id = 1 },
  { name = 'Basic Patterns', id = 2 },
  { name = 'Glitch Effects', id = 3 },
}

Shell.run({
  title = 'Hatched Fill Effects Demo',
  version = 'v0.1.0',
  version_color = 0x888888FF,
  initial_pos = { x = 100, y = 100 },
  initial_size = { w = 900, h = 700 },
  min_size = { w = 600, h = 400 },

  draw = function(ctx, shell_state)
    local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)
    local dl = ImGui.GetWindowDrawList(ctx)

    -- Tab bar
    if ImGui.BeginTabBar(ctx, '##effects_tabs') then
      for _, tab in ipairs(TABS) do
        if ImGui.BeginTabItem(ctx, tab.name) then
          demo_state.active_tab = tab.id
          ImGui.EndTabItem(ctx)
        end
      end
      ImGui.EndTabBar(ctx)
    end

    ImGui.Dummy(ctx, 0, 5)

    -- ========================================================================
    -- TAB 1: Corner Radial (the original WALTER bug effect)
    -- ========================================================================
    if demo_state.active_tab == 1 then
      -- Controls
      ImGui.Text(ctx, 'Corner:')
      ImGui.SameLine(ctx)
      if ImGui.RadioButton(ctx, 'Bottom-Right', demo_state.corner == 'bottom_right') then
        demo_state.corner = 'bottom_right'
      end
      ImGui.SameLine(ctx)
      if ImGui.RadioButton(ctx, 'Bottom-Left', demo_state.corner == 'bottom_left') then
        demo_state.corner = 'bottom_left'
      end
      ImGui.SameLine(ctx)
      if ImGui.RadioButton(ctx, 'Top-Right', demo_state.corner == 'top_right') then
        demo_state.corner = 'top_right'
      end
      ImGui.SameLine(ctx)
      if ImGui.RadioButton(ctx, 'Top-Left', demo_state.corner == 'top_left') then
        demo_state.corner = 'top_left'
      end

      local _, spacing = ImGui.SliderInt(ctx, 'Spacing##corner', demo_state.spacing, 2, 20)
      demo_state.spacing = spacing

      ImGui.SameLine(ctx, 250)
      local _, intensity = ImGui.SliderDouble(ctx, 'Intensity##corner', demo_state.intensity, 0.5, 3.0)
      demo_state.intensity = intensity

      ImGui.SameLine(ctx, 500)
      local _, layers = ImGui.SliderInt(ctx, 'Layers##corner', demo_state.layers, 1, 8)
      demo_state.layers = layers

      ImGui.Separator(ctx)
      ImGui.Dummy(ctx, 0, 10)

      -- Large panel with corner radial effect
      local panel_w = avail_w - 20
      local panel_h = avail_h - 120
      local panel_x, panel_y = ImGui.GetCursorScreenPos(ctx)

      -- Panel background
      ImGui.DrawList_AddRectFilled(dl, panel_x, panel_y, panel_x + panel_w, panel_y + panel_h, 0x1A1A2AFF, 8)

      -- Draw the corner radial effect
      HatchedFill.draw_corner_radial(ctx, {
        x = panel_x, y = panel_y, w = panel_w, h = panel_h,
        color = 0x8844FFCC,
        spacing = demo_state.spacing,
        thickness = demo_state.thickness,
        corner = demo_state.corner,
        layers = demo_state.layers,
        intensity = demo_state.intensity,
        draw_list = dl,
      })

      -- Panel border
      ImGui.DrawList_AddRect(dl, panel_x, panel_y, panel_x + panel_w, panel_y + panel_h, 0x8844FF80, 8, 0, 2)

      -- Label
      ImGui.DrawList_AddText(dl, panel_x + 15, panel_y + 15, 0xFFFFFFCC, 'Corner Radial Effect (like WALTER Builder)')
      ImGui.DrawList_AddText(dl, panel_x + 15, panel_y + 35, 0xFFFFFF88,
        string.format('Corner: %s | Spacing: %d | Layers: %d | Intensity: %.1f',
          demo_state.corner, demo_state.spacing, demo_state.layers, demo_state.intensity))

      ImGui.Dummy(ctx, panel_w, panel_h)

    -- ========================================================================
    -- TAB 2: Basic Patterns
    -- ========================================================================
    elseif demo_state.active_tab == 2 then
      local _, spacing = ImGui.SliderInt(ctx, 'Spacing##basic', demo_state.spacing, 2, 20)
      demo_state.spacing = spacing

      ImGui.SameLine(ctx, 250)
      local _, thickness = ImGui.SliderDouble(ctx, 'Thickness##basic', demo_state.thickness, 0.5, 4)
      demo_state.thickness = thickness

      ImGui.Separator(ctx)
      ImGui.Dummy(ctx, 0, 10)

      local win_x, win_y = ImGui.GetCursorScreenPos(ctx)
      local box_w, box_h = 150, 100
      local gap = 20

      -- Row of basic directions
      local patterns = {
        { dir = HatchedFill.DIRECTION.FORWARD, color = '#4488FFAA', label = 'FORWARD' },
        { dir = HatchedFill.DIRECTION.BACKWARD, color = '#FF8844AA', label = 'BACKWARD' },
        { dir = HatchedFill.DIRECTION.BOTH, color = '#44FF88AA', label = 'BOTH' },
        { dir = HatchedFill.DIRECTION.HORIZONTAL, color = '#FF44AAAA', label = 'HORIZONTAL' },
        { dir = HatchedFill.DIRECTION.VERTICAL, color = '#AAFF44AA', label = 'VERTICAL' },
      }

      for i, pat in ipairs(patterns) do
        local px = win_x + (i - 1) * (box_w + gap)
        ImGui.DrawList_AddRectFilled(dl, px, win_y, px + box_w, win_y + box_h, 0x1A1A1AFF, 4)
        HatchedFill.Draw(ctx, {
          x = px, y = win_y, w = box_w, h = box_h,
          direction = pat.dir,
          color = hex(pat.color),
          spacing = demo_state.spacing,
          thickness = demo_state.thickness,
          draw_list = dl,
        })
        ImGui.DrawList_AddRect(dl, px, win_y, px + box_w, win_y + box_h, hex(pat.color:gsub('AA$', 'FF')), 4)
        ImGui.DrawList_AddText(dl, px + 5, win_y + box_h - 18, 0xFFFFFFCC, pat.label)
      end

      ImGui.Dummy(ctx, 0, box_h + 30)

      -- Marching ants row
      ImGui.Text(ctx, 'Marching Ants (animated borders):')
      ImGui.Dummy(ctx, 0, 5)
      local row2_x, row2_y = ImGui.GetCursorScreenPos(ctx)

      ImGui.DrawList_AddRectFilled(dl, row2_x, row2_y, row2_x + 300, row2_y + 80, 0x1A1A2AFF, 4)
      HatchedFill.draw_marching_ants(ctx, {
        x = row2_x, y = row2_y, w = 300, h = 80,
        color = 0xFFFFFFCC,
        dash_length = 6,
        gap_length = 4,
        thickness = 2,
        speed = 40,
        draw_list = dl,
      })
      ImGui.DrawList_AddText(dl, row2_x + 10, row2_y + 30, 0xFFFFFFAA, 'Selection indicator style')

      ImGui.DrawList_AddRectFilled(dl, row2_x + 320, row2_y, row2_x + 620, row2_y + 80, 0x2A1A1AFF, 4)
      HatchedFill.draw_marching_ants(ctx, {
        x = row2_x + 320, y = row2_y, w = 300, h = 80,
        color = 0xFF6644FF,
        dash_length = 10,
        gap_length = 6,
        thickness = 1,
        speed = 20,
        draw_list = dl,
      })
      ImGui.DrawList_AddText(dl, row2_x + 330, row2_y + 30, 0xFF8866AA, 'Slower variant')

      ImGui.Dummy(ctx, 0, 100)

    -- ========================================================================
    -- TAB 3: Glitch Effects
    -- ========================================================================
    elseif demo_state.active_tab == 3 then
      local _, spacing = ImGui.SliderInt(ctx, 'Spacing##glitch', demo_state.spacing, 2, 20)
      demo_state.spacing = spacing

      ImGui.SameLine(ctx, 250)
      local _, intensity = ImGui.SliderDouble(ctx, 'Intensity##glitch', demo_state.intensity, 0.5, 3.0)
      demo_state.intensity = intensity

      ImGui.SameLine(ctx, 500)
      local _, layers = ImGui.SliderInt(ctx, 'Layers##glitch', demo_state.layers, 1, 8)
      demo_state.layers = layers

      ImGui.Separator(ctx)
      ImGui.Dummy(ctx, 0, 10)

      local win_x, win_y = ImGui.GetCursorScreenPos(ctx)
      local glitch_w, glitch_h = 250, 180

      -- Glitch effect (original bug)
      HatchedFill.draw_glitch(ctx, {
        x = win_x, y = win_y, w = glitch_w, h = glitch_h,
        color = 0xFF5555CC,
        spacing = demo_state.spacing,
        thickness = demo_state.thickness,
        intensity = demo_state.intensity,
        layers = demo_state.layers,
        show_box = true,
        draw_list = dl,
      })
      ImGui.DrawList_AddText(dl, win_x + 5, win_y + glitch_h + 5, 0xFFFFFFAA, 'GLITCH (original bug math)')

      -- Curved effect
      local x2 = win_x + glitch_w + 40
      HatchedFill.draw_curved(ctx, {
        x = x2, y = win_y, w = glitch_w, h = glitch_h,
        color = 0x55FF55CC,
        spacing = demo_state.spacing,
        thickness = demo_state.thickness,
        curve_factor = demo_state.intensity,
        layers = demo_state.layers,
        direction = 'both',
        draw_list = dl,
      })
      ImGui.DrawList_AddRect(dl, x2, win_y, x2 + glitch_w, win_y + glitch_h, 0x55FF5560, 0, 0, 1)
      ImGui.DrawList_AddText(dl, x2 + 5, win_y + glitch_h + 5, 0xFFFFFFAA, 'CURVED (exponential)')

      -- Corner radial preview
      local x3 = x2 + glitch_w + 40
      HatchedFill.draw_corner_radial(ctx, {
        x = x3, y = win_y, w = glitch_w, h = glitch_h,
        color = 0x5555FFCC,
        spacing = demo_state.spacing,
        thickness = demo_state.thickness,
        corner = 'bottom_right',
        layers = demo_state.layers,
        intensity = demo_state.intensity,
        draw_list = dl,
      })
      ImGui.DrawList_AddRect(dl, x3, win_y, x3 + glitch_w, win_y + glitch_h, 0x5555FF60, 0, 0, 1)
      ImGui.DrawList_AddText(dl, x3 + 5, win_y + glitch_h + 5, 0xFFFFFFAA, 'CORNER RADIAL')

      ImGui.Dummy(ctx, 0, glitch_h + 40)
    end
  end,
})

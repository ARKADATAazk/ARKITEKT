-- @noindex
-- ProductionPanel/ui/init.lua
-- Main UI orchestrator with tabbed interface

local M = {}

-- DEPENDENCIES
local Ark = require('arkitekt')
local MacroControls = require('scripts.ProductionPanel.ui.views.macro_controls')
local DrumRack = require('scripts.ProductionPanel.ui.views.drum_rack')
local ImGui = Ark.ImGui
local Colors = Ark.Colors
local Theme = require('arkitekt.theme')

-- STATE
local state = {
  current_tab = 1, -- 1 = Macros, 2 = Drum Rack, 3 = Browser (future)
  initialized = false,
}

---Initialize UI
function M.init()
  if state.initialized then return end

  MacroControls.init()
  DrumRack.init()

  state.initialized = true
end

---Draw tabbed interface
---@param ctx userdata ImGui context
---@param shell_state table Shell state
function M.Draw(ctx, shell_state)
  if not state.initialized then
    M.init()
  end

  -- Tab bar
  local tab_flags = ImGui.TabBarFlags_None

  if ImGui.BeginTabBar(ctx, 'production_panel_tabs', tab_flags) then

    -- Macro Controls Tab
    if ImGui.BeginTabItem(ctx, '🎛️ Macro Controls') then
      state.current_tab = 1
      ImGui.Spacing(ctx)
      MacroControls.Draw(ctx)
      ImGui.EndTabItem(ctx)
    end

    -- Drum Rack Tab
    if ImGui.BeginTabItem(ctx, '🥁 Drum Rack') then
      state.current_tab = 2
      ImGui.Spacing(ctx)
      DrumRack.Draw(ctx)
      ImGui.EndTabItem(ctx)
    end

    -- Sample Browser Tab (placeholder)
    if ImGui.BeginTabItem(ctx, '📁 Browser') then
      state.current_tab = 3
      ImGui.Spacing(ctx)

      ImGui.Text(ctx, 'Sample & FX Chain Browser')
      ImGui.Spacing(ctx)
      ImGui.Separator(ctx)
      ImGui.Spacing(ctx)

      ImGui.PushStyleColor(ctx, ImGui.Col_Text, Theme.COLORS.TEXT_DARK)
      ImGui.TextWrapped(ctx, '📝 Mockup: This will integrate ItemPicker for samples, TemplateBrowser patterns for FX chains, and track template management.')
      ImGui.Spacing(ctx)
      ImGui.Spacing(ctx)
      ImGui.TextWrapped(ctx, 'Future features:')
      ImGui.BulletText(ctx, 'Visual sample browser with waveform previews')
      ImGui.BulletText(ctx, 'FX chain library with tags and search')
      ImGui.BulletText(ctx, 'Track template browser')
      ImGui.BulletText(ctx, 'Drag-and-drop to pads/containers')
      ImGui.PopStyleColor(ctx)

      ImGui.EndTabItem(ctx)
    end

    -- Settings Tab (placeholder)
    if ImGui.BeginTabItem(ctx, '⚙️ Settings') then
      state.current_tab = 4
      ImGui.Spacing(ctx)

      ImGui.Text(ctx, 'Production Panel Settings')
      ImGui.Spacing(ctx)
      ImGui.Separator(ctx)
      ImGui.Spacing(ctx)

      ImGui.PushStyleColor(ctx, ImGui.Col_Text, Theme.COLORS.TEXT_DARK)
      ImGui.TextWrapped(ctx, '📝 Mockup: Settings for MIDI routing, default behaviors, UI preferences, etc.')
      ImGui.Spacing(ctx)
      ImGui.Spacing(ctx)
      ImGui.TextWrapped(ctx, 'Planned settings:')
      ImGui.BulletText(ctx, 'MIDI input channel selection')
      ImGui.BulletText(ctx, 'Default macro count (4, 8, or 16)')
      ImGui.BulletText(ctx, 'Knob sensitivity and behavior')
      ImGui.BulletText(ctx, 'Auto-save preferences')
      ImGui.BulletText(ctx, 'Color themes')
      ImGui.PopStyleColor(ctx)

      ImGui.EndTabItem(ctx)
    end

    ImGui.EndTabBar(ctx)
  end
end

return M

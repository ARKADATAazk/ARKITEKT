-- @noindex
-- ARKITEKT/scripts/demos/controls_test.lua
-- Refactored Controls Test - Standalone vs Panel Usage

local script_path = debug.getinfo(1, "S").source:match("@?(.*)[\\/]") or ""
local root_path = script_path:match("(.*)[\\/][^\\/]+[\\/]?$") or script_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
if not root_path:match("[\\/]$") then root_path = root_path .. "/" end

local arkitekt_path = root_path .. "ARKITEKT/"
package.path = arkitekt_path .. "?.lua;" .. arkitekt_path .. "?/init.lua;" .. package.path
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path

-- Import system
local Shell = require('arkitekt.app.runtime.shell')
local Arkit = require('arkitekt.arkit')

-- Import refactored base controls
local Button = require('arkitekt.gui.widgets.primitives.button')
local SearchInput = require('arkitekt.gui.widgets.inputs.search_input')
local Dropdown = require('arkitekt.gui.widgets.inputs.dropdown')

-- Import panel system
local Panel = require('arkitekt.gui.widgets.containers.panel')

local ImGui = Arkit.ImGui
local hexrgb = Arkit.hexrgb

local StyleOK, Style = pcall(require, 'arkitekt.gui.style.imgui_defaults')
local Colors = require('arkitekt.core.colors')

-- ============================================================================
-- STATE
-- ============================================================================

local state = {
  -- Standalone controls
  standalone = {
    button_clicks = 0,
    search_text = "",
    dropdown_value = "red",
    dropdown_direction = "asc",
  },
  
  -- Panel controls
  panel_instance = nil,
  panel_button_clicks = 0,
  
  -- UI
  show_tooltips = true,
  show_panel = true,
  frame_count = 0,
}

-- ============================================================================
-- PANEL CONFIGURATION
-- ============================================================================

local function create_test_panel()
  local panel_config = {
    bg_color = hexrgb("#1A1A1AFF"),
    border_color = hexrgb("#000000DD"),
    border_thickness = 1,
    rounding = 8,
    padding = 16,
    
    header = {
      enabled = true,
      height = 30,
      bg_color = hexrgb("#1E1E1EFF"),
      border_color = hexrgb("#00000066"),
      rounding = 8,
      
      padding = {
        left = 0,
        right = 0,
      },
      
      elements = {
        {
          id = "panel_button",
          type = "button",
          spacing_before = 0,
          config = {
            label = "Panel Button",
            tooltip = state.show_tooltips and "This button is in a panel header" or nil,
            on_click = function()
              state.panel_button_clicks = state.panel_button_clicks + 1
              reaper.ShowConsoleMsg(string.format("[PANEL] Button clicked! (Total: %d)\n", state.panel_button_clicks))
            end,
          }
        },
        {
          id = "panel_search",
          type = "search_field",
          width = 200,
          spacing_before = 8,
          config = {
            placeholder = "Search in panel...",
            tooltip = state.show_tooltips and "Panel-integrated search field with corner rounding" or nil,
            on_change = function(text)
              reaper.ShowConsoleMsg(string.format("[PANEL] Search changed: '%s'\n", text))
            end,
          }
        },
        {
          id = "panel_dropdown",
          type = "dropdown_field",
          width = 140,
          spacing_before = 8,
          config = {
            options = {
              { label = "Grid View", value = "grid" },
              { label = "List View", value = "list" },
              { label = "Tree View", value = "tree" },
              { label = "Timeline", value = "timeline" },
            },
            tooltip = state.show_tooltips and "Select a view mode (right-click to change sort)" or nil,
            enable_mousewheel = true,
            on_change = function(value)
              reaper.ShowConsoleMsg(string.format("[PANEL] Dropdown changed: %s\n", value))
            end,
            on_direction_change = function(direction)
              reaper.ShowConsoleMsg(string.format("[PANEL] Sort direction: %s\n", direction))
            end,
          }
        },
      },
    },
  }
  
  return Panel.new({
    id = "controls_test_panel",
    config = panel_config,
  })
end

-- ============================================================================
-- STANDALONE CONTROLS SECTION
-- ============================================================================

local function draw_standalone_section(ctx)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#FFD700FF"))
  ImGui.Text(ctx, "═══ STANDALONE CONTROLS ═══")
  ImGui.PopStyleColor(ctx, 1)
  
  ImGui.Spacing(ctx)
  ImGui.Text(ctx, "These controls are rendered directly, without a panel:")
  ImGui.Spacing(ctx)
  
  local dl = ImGui.GetWindowDrawList(ctx)
  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  
  -- Button Test
  ImGui.Text(ctx, "Button:")
  ImGui.SameLine(ctx, 0, 8)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#888888FF"))
  ImGui.Text(ctx, "(with custom rounding)")
  ImGui.PopStyleColor(ctx, 1)
  
  cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  
  Button.draw(ctx, dl, cursor_x, cursor_y, 150, 30, {
    label = "Click Me!",
    rounding = 6,
    tooltip = state.show_tooltips and "Standalone button with 6px rounding" or nil,
    on_click = function()
      state.standalone.button_clicks = state.standalone.button_clicks + 1
      reaper.ShowConsoleMsg(string.format("[STANDALONE] Button clicked! (Total: %d)\n", state.standalone.button_clicks))
    end,
  }, "standalone_button")
  
  ImGui.SetCursorScreenPos(ctx, cursor_x + 160, cursor_y + 5)
  ImGui.Text(ctx, string.format("Clicks: %d", state.standalone.button_clicks))
  
  ImGui.SetCursorScreenPos(ctx, cursor_x, cursor_y + 40)
  
  -- Search Input Test
  ImGui.Text(ctx, "Search Input:")
  ImGui.SameLine(ctx, 0, 8)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#888888FF"))
  ImGui.Text(ctx, "(with fade animation)")
  ImGui.PopStyleColor(ctx, 1)
  
  cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  
  SearchInput.draw(ctx, dl, cursor_x, cursor_y, 300, 30, {
    placeholder = "Type to search...",
    rounding = 6,
    tooltip = state.show_tooltips and "Standalone search with opacity fade on focus" or nil,
    fade_speed = 8.0,
    on_change = function(text)
      state.standalone.search_text = text
      if text ~= "" then
        reaper.ShowConsoleMsg(string.format("[STANDALONE] Search: '%s'\n", text))
      end
    end,
  }, "standalone_search")
  
  ImGui.SetCursorScreenPos(ctx, cursor_x, cursor_y + 40)
  
  if state.standalone.search_text ~= "" then
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#4A9EFFFF"))
    ImGui.Text(ctx, string.format("Current search: '%s'", state.standalone.search_text))
    ImGui.PopStyleColor(ctx, 1)
    ImGui.Spacing(ctx)
  end
  
  -- Dropdown Test
  ImGui.Text(ctx, "Dropdown:")
  ImGui.SameLine(ctx, 0, 8)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#888888FF"))
  ImGui.Text(ctx, "(with mousewheel support)")
  ImGui.PopStyleColor(ctx, 1)
  
  cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  
  Dropdown.draw(ctx, dl, cursor_x, cursor_y, 180, 30, {
    id = "standalone_dropdown",
    options = {
      { label = "🔴 Red", value = "red" },
      { label = "🟢 Green", value = "green" },
      { label = "🔵 Blue", value = "blue" },
      { label = "🟡 Yellow", value = "yellow" },
      { label = "🟣 Purple", value = "purple" },
    },
    rounding = 6,
    tooltip = state.show_tooltips and "Scroll with mousewheel, right-click to toggle sort" or nil,
    enable_mousewheel = true,
    on_change = function(value)
      state.standalone.dropdown_value = value
      reaper.ShowConsoleMsg(string.format("[STANDALONE] Dropdown: %s\n", value))
    end,
    on_direction_change = function(direction)
      state.standalone.dropdown_direction = direction
      reaper.ShowConsoleMsg(string.format("[STANDALONE] Sort direction: %s\n", direction))
    end,
  }, "standalone_dropdown")
  
  ImGui.SetCursorScreenPos(ctx, cursor_x + 190, cursor_y + 5)
  
  local color_map = {
    red = hexrgb("#FF6B6BFF"),
    green = hexrgb("#4CAF50FF"),
    blue = hexrgb("#4A9EFFFF"),
    yellow = hexrgb("#FFD700FF"),
    purple = hexrgb("#B968C7FF"),
  }
  
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, color_map[state.standalone.dropdown_value] or hexrgb("#FFFFFF"))
  ImGui.Text(ctx, string.format("Selected: %s (%s)", state.standalone.dropdown_value, state.standalone.dropdown_direction))
  ImGui.PopStyleColor(ctx, 1)
  
  ImGui.SetCursorScreenPos(ctx, cursor_x, cursor_y + 50)
end

-- ============================================================================
-- PANEL SECTION
-- ============================================================================

local function draw_panel_section(ctx)
  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
  
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#FFD700FF"))
  ImGui.Text(ctx, "═══ PANEL-INTEGRATED CONTROLS ═══")
  ImGui.PopStyleColor(ctx, 1)
  
  ImGui.Spacing(ctx)
  ImGui.Text(ctx, "Same controls, but rendered inside a panel header:")
  ImGui.Spacing(ctx)
  
  if not state.panel_instance then
    state.panel_instance = create_test_panel()
  end
  
  -- Update panel header config for tooltip toggle
  if state.panel_instance.config.header.elements then
    for _, element in ipairs(state.panel_instance.config.header.elements) do
      if element.config then
        if state.show_tooltips then
          if element.id == "panel_button" then
            element.config.tooltip = "This button is in a panel header"
          elseif element.id == "panel_search" then
            element.config.tooltip = "Panel-integrated search field with corner rounding"
          elseif element.id == "panel_dropdown" then
            element.config.tooltip = "Select a view mode (right-click to change sort)"
          end
        else
          element.config.tooltip = nil
        end
      end
    end
  end
  
  if state.panel_instance:begin_draw(ctx) then
    ImGui.Spacing(ctx)
    ImGui.Text(ctx, "📦 Panel Content Area")
    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)
    
    ImGui.Text(ctx, "Notice the differences:")
    ImGui.BulletText(ctx, "Corner rounding matches the panel style")
    ImGui.BulletText(ctx, "Components share panel state automatically")
    ImGui.BulletText(ctx, "No adapter files needed - same components!")
    ImGui.BulletText(ctx, "Context detection happens automatically")
    ImGui.Spacing(ctx)
    
    ImGui.Text(ctx, string.format("Panel button clicks: %d", state.panel_button_clicks))
    
    -- Show panel state
    if state.panel_instance.panel_search and state.panel_instance.panel_search.search_text ~= "" then
      ImGui.Spacing(ctx)
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#4A9EFFFF"))
      ImGui.Text(ctx, string.format("Panel search: '%s'", state.panel_instance.panel_search.search_text))
      ImGui.PopStyleColor(ctx, 1)
    end
    
    if state.panel_instance.panel_dropdown and state.panel_instance.panel_dropdown.dropdown_value then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#4CAF50FF"))
      ImGui.Text(ctx, string.format("Panel dropdown: %s", state.panel_instance.panel_dropdown.dropdown_value))
      ImGui.PopStyleColor(ctx, 1)
    end
  end
  state.panel_instance:end_draw(ctx)
end

-- ============================================================================
-- CONTROLS SECTION
-- ============================================================================

local function draw_controls(ctx)
  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
  
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#FFD700FF"))
  ImGui.Text(ctx, "═══ TEST CONTROLS ═══")
  ImGui.PopStyleColor(ctx, 1)
  
  ImGui.Spacing(ctx)
  
  if ImGui.Button(ctx, state.show_tooltips and "Disable Tooltips" or "Enable Tooltips", 180, 26) then
    state.show_tooltips = not state.show_tooltips
    reaper.ShowConsoleMsg(string.format("[TEST] Tooltips %s\n", state.show_tooltips and "enabled" or "disabled"))
  end
  
  ImGui.SameLine(ctx, 0, 8)
  
  if ImGui.Button(ctx, "Reset Counters", 180, 26) then
    state.standalone.button_clicks = 0
    state.panel_button_clicks = 0
    reaper.ShowConsoleMsg("[TEST] Counters reset\n")
  end
  
  ImGui.SameLine(ctx, 0, 8)
  
  if ImGui.Button(ctx, "Clear Console", 180, 26) then
    reaper.ClearConsole()
    reaper.ShowConsoleMsg("[TEST] Console cleared\n")
  end
  
  ImGui.Spacing(ctx)
  ImGui.Text(ctx, string.format("Frame: %d", state.frame_count))
end

-- ============================================================================
-- MAIN DRAW
-- ============================================================================

local function draw(ctx, shell_state)
  state.frame_count = state.frame_count + 1
  
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 20, 20)
  
  -- Header
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#41E0A3FF"))
  ImGui.Text(ctx, "🎨 REFACTORED CONTROLS TEST")
  ImGui.PopStyleColor(ctx, 1)
  
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#888888FF"))
  ImGui.Text(ctx, "Testing base components in standalone and panel contexts")
  ImGui.PopStyleColor(ctx, 1)
  
  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
  
  -- Sections
  draw_standalone_section(ctx)
  draw_panel_section(ctx)
  draw_controls(ctx)
  
  ImGui.PopStyleVar(ctx, 1)
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

reaper.ShowConsoleMsg("\n")
reaper.ShowConsoleMsg("═══════════════════════════════════════\n")
reaper.ShowConsoleMsg("  REFACTORED CONTROLS TEST\n")
reaper.ShowConsoleMsg("═══════════════════════════════════════\n")
reaper.ShowConsoleMsg("Testing base components:\n")
reaper.ShowConsoleMsg("  • Button (standalone + panel)\n")
reaper.ShowConsoleMsg("  • SearchInput (standalone + panel)\n")
reaper.ShowConsoleMsg("  • Dropdown (standalone + panel)\n")
reaper.ShowConsoleMsg("\n")
reaper.ShowConsoleMsg("Key features:\n")
reaper.ShowConsoleMsg("  ✓ Context detection\n")
reaper.ShowConsoleMsg("  ✓ No adapter files\n")
reaper.ShowConsoleMsg("  ✓ Unified styling\n")
reaper.ShowConsoleMsg("  ✓ Backward compatible\n")
reaper.ShowConsoleMsg("═══════════════════════════════════════\n\n")

Shell.run({
  title = "Controls Test",
  version = "v2.0.0",
  version_color = hexrgb("#888888FF"),
  style = StyleOK and Style or nil,
  initial_pos = { x = 100, y = 100 },
  initial_size = { w = 900, h = 750 },
  min_size = { w = 800, h = 600 },
  icon_color = hexrgb("#41E0A3FF"),
  icon_size = 18,
  
  draw = draw,
})

-- @noindex
-- Arkitekt Controls Test
-- Tests all refactored base components in both standalone and panel contexts

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local ark = require('arkitekt')

-- Import system
local Shell = require('arkitekt.app.runtime.shell')

-- Import base controls
-- Import panel system
local Config = require('arkitekt.gui.widgets.containers.panel.defaults')
local hexrgb = ark.Colors.hexrgb


-- ============================================================================
-- TEST STATE
-- ============================================================================

local test_state = {
  -- Standalone component test values
  search_text = "",
  dropdown_value = "option1",
  
  -- Panel instance
  panel = nil,
}

-- ============================================================================
-- PANEL CONFIGURATION
-- ============================================================================

local function create_test_panel()
  local panel_config = {
    bg_color = hexrgb("#1A1A1A"),
    border_color = hexrgb("#000000DD"),
    border_thickness = 1,
    rounding = 8,
    padding = 16,
    
    header = {
      enabled = true,
      height = 30,
      bg_color = hexrgb("#1E1E1E"),
      border_color = hexrgb("#00000066"),
      rounding = 8,
      
      padding = {
        left = 0,
        right = 0,
      },
      
      elements = {
        {
          id = "test_button",
          type = "button",
          spacing_before = 0,
          config = {
            label = "Panel Button",
            on_click = function()
              reaper.ShowConsoleMsg("Panel button clicked!\n")
            end,
          }
        },
        {
          id = "test_search",
          type = "inputtext",
          width = 200,
          spacing_before = 8,
          config = {
            placeholder = "Search in panel...",
            tooltip = "This is a search field in a panel header",
            on_change = function(text)
              reaper.ShowConsoleMsg("Panel search: " .. text .. "\n")
            end,
          }
        },
        {
          id = "test_dropdown",
          type = "combo",
          width = 120,
          spacing_before = 8,
          config = {
            options = {
              { label = "Option 1", value = "opt1" },
              { label = "Option 2", value = "opt2" },
              { label = "Option 3", value = "opt3" },
            },
            tooltip = "Select an option",
            on_change = function(value)
              reaper.ShowConsoleMsg("Panel dropdown: " .. value .. "\n")
            end,
          }
        },
      },
    },

    -- Sidebar test - vertical buttons on left
    left_sidebar = {
      enabled = true,
      width = 40,
      bg_color = hexrgb("#1E1E1E"),
      valign = "center",
      button_size = 30,
      button_spacing = 4,
      rounding = 4,
      elements = {
        {
          id = "sidebar_add",
          config = {
            label = "+",
            tooltip = "Add item",
            on_click = function()
              reaper.ShowConsoleMsg("Sidebar Add clicked!\n")
            end,
          },
        },
        {
          id = "sidebar_remove",
          config = {
            label = "-",
            tooltip = "Remove item",
            on_click = function()
              reaper.ShowConsoleMsg("Sidebar Remove clicked!\n")
            end,
          },
        },
        {
          id = "sidebar_settings",
          config = {
            label = "⚙",
            tooltip = "Settings",
            on_click = function()
              reaper.ShowConsoleMsg("Sidebar Settings clicked!\n")
            end,
          },
        },
      },
    },

    -- Right sidebar test
    right_sidebar = {
      enabled = true,
      width = 40,
      bg_color = hexrgb("#1E1E1E"),
      valign = "top",
      button_size = 30,
      button_spacing = 4,
      rounding = 4,
      elements = {
        {
          id = "sidebar_up",
          config = {
            label = "▲",
            tooltip = "Move up",
            on_click = function()
              reaper.ShowConsoleMsg("Sidebar Up clicked!\n")
            end,
          },
        },
        {
          id = "sidebar_down",
          config = {
            label = "▼",
            tooltip = "Move down",
            on_click = function()
              reaper.ShowConsoleMsg("Sidebar Down clicked!\n")
            end,
          },
        },
      },
    },
  }

  return ark.Panel.new({
    id = "controls_test_panel",
    config = panel_config,
  })
end

-- ============================================================================
-- STANDALONE COMPONENTS TEST
-- ============================================================================

local function draw_standalone_test(ctx)
  ImGui.Text(ctx, "=== STANDALONE COMPONENTS TEST ===")
  ImGui.Spacing(ctx)
  
  local dl = ImGui.GetWindowDrawList(ctx)
  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  
  -- Button Test
  ImGui.Text(ctx, "Button (standalone):")
  cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  
  local button_result = ark.Button.draw(ctx, {
    id = "standalone_button",
    draw_list = dl,
    x = cursor_x,
    y = cursor_y,
    width = 120,
    height = 30,
    label = "Click Me",
    rounding = 4,
    on_click = function()
      reaper.ShowConsoleMsg("Standalone button clicked!\n")
    end,
    tooltip = "This is a standalone button"
  })
  
  ImGui.SetCursorScreenPos(ctx, cursor_x, cursor_y + 40)
  
  -- Search Input Test
  ImGui.Text(ctx, "Search Input (standalone):")
  cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  
  local search_result = ark.InputText.search(ctx, {
    id = "standalone_search",
    draw_list = dl,
    x = cursor_x,
    y = cursor_y,
    width = 250,
    height = 30,
    placeholder = "Type to search...",
    rounding = 4,
    tooltip = "This is a standalone search field",
    on_change = function(text)
      test_state.search_text = text
      reaper.ShowConsoleMsg("Standalone search: " .. text .. "\n")
    end,
  })
  
  ImGui.SetCursorScreenPos(ctx, cursor_x, cursor_y + 40)
  
  if test_state.search_text ~= "" then
    ImGui.Text(ctx, "Search text: " .. test_state.search_text)
  end
  
  ImGui.Spacing(ctx)
  
  -- Dropdown Test
  ImGui.Text(ctx, "Dropdown (standalone):")
  cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  
  local dropdown_result = ark.Combo.draw(ctx, {
    id = "standalone_dropdown",
    draw_list = dl,
    x = cursor_x,
    y = cursor_y,
    width = 150,
    height = 30,
    options = {
      { label = "Red", value = "red" },
      { label = "Green", value = "green" },
      { label = "Blue", value = "blue" },
    },
    rounding = 4,
    tooltip = "Select a color",
    enable_mousewheel = true,
    on_change = function(value)
      test_state.dropdown_value = value
      reaper.ShowConsoleMsg("Standalone dropdown: " .. value .. "\n")
    end,
  })
  
  ImGui.SetCursorScreenPos(ctx, cursor_x, cursor_y + 40)
  
  ImGui.Text(ctx, "Selected: " .. (test_state.dropdown_value or "none"))
  
  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
end

-- ============================================================================
-- PANEL TEST
-- ============================================================================

local function draw_panel_test(ctx)
  if not test_state.panel then
    test_state.panel = create_test_panel()
  end
  
  ImGui.Text(ctx, "=== PANEL COMPONENTS TEST ===")
  ImGui.Spacing(ctx)
  ImGui.Text(ctx, "Components below are in a panel header:")
  ImGui.Spacing(ctx)
  
  -- Draw panel
  if test_state.panel:begin_draw(ctx) then
    ImGui.Text(ctx, "Panel content area")
    ImGui.Spacing(ctx)
    ImGui.Text(ctx, "The header above contains the same components,")
    ImGui.Text(ctx, "but they're rendered through the panel system.")
    ImGui.Spacing(ctx)
    ImGui.Text(ctx, "Notice:")
    ImGui.BulletText(ctx, "Corner rounding matches the panel")
    ImGui.BulletText(ctx, "Context detection works automatically")
    ImGui.BulletText(ctx, "No adapter files needed!")
  end
  test_state.panel:end_draw(ctx)
end

-- ============================================================================
-- MAIN LOOP
-- ============================================================================

local function frame(ctx)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 20, 20)
  
  draw_standalone_test(ctx)
  draw_panel_test(ctx)
  
  ImGui.PopStyleVar(ctx, 1)
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

Shell.run({
  title = "Controls Test - Standalone vs Panel",
  width = 800,
  height = 700,
  resizable = true,
  frame = frame,
})

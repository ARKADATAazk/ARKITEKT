-- @noindex
-- ARKITEKT/scripts/demos/panel_features_test.lua
-- Test all new panel features: alignment, bottom headers, corner buttons
-- Fixed: ID isolation and better layout

local script_path = debug.getinfo(1, "S").source:match("@?(.*)[\\/]") or ""
local root_path = script_path:match("(.*)[\\/][^\\/]+[\\/]?$") or script_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
if not root_path:match("[\\/]$") then root_path = root_path .. "/" end

local arkitekt_path = root_path .. "ARKITEKT/"
package.path = arkitekt_path .. "?.lua;" .. arkitekt_path .. "?/init.lua;" .. package.path
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path

local Shell = require('arkitekt.app.runtime.shell')
local Arkit = require('arkitekt.arkit')
local Panel = require('arkitekt.gui.widgets.containers.panel')

local ImGui = Arkit.ImGui
local hexrgb = Arkit.hexrgb

local StyleOK, Style = pcall(require, 'arkitekt.gui.style.imgui_defaults')

-- ============================================================================
-- STATE
-- ============================================================================

local state = {
  panels = {},
  corner_button_clicks = 0,
  frame_count = 0,
}

-- ============================================================================
-- PANEL 1: LEFT/RIGHT ALIGNMENT WITH SEPARATOR
-- ============================================================================

local function create_alignment_panel()
  return Panel.new({
    id = "alignment_panel",
    width = 850,
    height = 180,
    config = {
      bg_color = hexrgb("#1A1A1AFF"),
      border_color = hexrgb("#000000DD"),
      border_thickness = 1,
      rounding = 8,
      padding = 16,
      
      header = {
        enabled = true,
        height = 30,
        position = "top",
        bg_color = hexrgb("#1E1E1EFF"),
        border_color = hexrgb("#00000066"),
        rounding = 8,
        
        elements = {
          -- Left-aligned elements
          {
            id = "title",
            type = "button",
            align = "left",
            spacing_before = 0,
            config = {
              label = "📂 Left Side",
              tooltip = "This button is left-aligned",
              on_click = function()
                reaper.ShowConsoleMsg("[LEFT] Title clicked\n")
              end,
            }
          },
          {
            id = "search",
            type = "search_field",
            align = "left",
            width = 200,
            spacing_before = 8,
            config = {
              placeholder = "Search left...",
              tooltip = "Left-aligned search",
            }
          },
          
          -- Separator (creates visual break and rounds corners)
          {
            id = "sep1",
            type = "separator",
            align = "left",
            width = 16,
            spacing_before = 8,
            config = {
              show_line = true,
              line_color = hexrgb("#40404080"),
            }
          },
          
          {
            id = "middle",
            type = "button",
            align = "left",
            spacing_before = 8,
            config = {
              label = "Middle",
              tooltip = "After separator - has rounded corners",
            }
          },
          
          -- Right-aligned elements
          {
            id = "filter",
            type = "dropdown_field",
            align = "right",
            width = 120,
            spacing_before = 8,
            config = {
              options = {
                { label = "All Items", value = "all" },
                { label = "Active", value = "active" },
                { label = "Archived", value = "archived" },
              },
              tooltip = "Right-aligned dropdown",
              on_change = function(value)
                reaper.ShowConsoleMsg("[RIGHT] Filter: " .. value .. "\n")
              end,
            }
          },
          {
            id = "settings",
            type = "button",
            align = "right",
            spacing_before = 8,
            config = {
              label = "⚙",
              tooltip = "Settings (right-aligned)",
              on_click = function()
                reaper.ShowConsoleMsg("[RIGHT] Settings clicked\n")
              end,
            }
          },
        },
      },
    },
  })
end

-- ============================================================================
-- PANEL 2: BOTTOM HEADER
-- ============================================================================

local function create_bottom_header_panel()
  return Panel.new({
    id = "bottom_panel",
    width = 850,
    height = 150,
    config = {
      bg_color = hexrgb("#1A1A1AFF"),
      border_color = hexrgb("#000000DD"),
      border_thickness = 1,
      rounding = 8,
      padding = 16,
      
      header = {
        enabled = true,
        height = 30,
        position = "bottom", -- Header at bottom!
        bg_color = hexrgb("#1E1E1EFF"),
        border_color = hexrgb("#00000066"),
        rounding = 8,
        
        elements = {
          {
            id = "status",
            type = "button",
            align = "left",
            config = {
              label = "📊 Status: Ready",
              tooltip = "Status indicator in bottom header",
            }
          },
          {
            id = "counter",
            type = "button",
            align = "right",
            config = {
              label = string.format("Frame: %d", state.frame_count),
              tooltip = "Frame counter",
            }
          },
        },
      },
    },
  })
end

-- ============================================================================
-- PANEL 3: CORNER BUTTONS (NO HEADER)
-- ============================================================================

local function create_corner_buttons_panel()
  return Panel.new({
    id = "corner_panel",
    width = 850,
    height = 200,
    config = {
      bg_color = hexrgb("#1A1A1AFF"),
      border_color = hexrgb("#000000DD"),
      border_thickness = 1,
      rounding = 8,
      padding = 16,
      
      -- No header!
      header = {
        enabled = false,
      },
      
      -- But has corner buttons
      corner_buttons = {
        size = 32,
        margin = 12,
        
        top_left = {
          icon = "📌",
          tooltip = "Pin panel",
          on_click = function()
            reaper.ShowConsoleMsg("[CORNER] Top-left clicked\n")
          end,
        },
        
        top_right = {
          icon = "✕",
          tooltip = "Close panel",
          on_click = function()
            reaper.ShowConsoleMsg("[CORNER] Top-right clicked\n")
          end,
        },
        
        bottom_left = {
          icon = "+",
          tooltip = "Add new item",
          on_click = function()
            state.corner_button_clicks = state.corner_button_clicks + 1
            reaper.ShowConsoleMsg(string.format("[CORNER] Bottom-left clicked! (Total: %d)\n", state.corner_button_clicks))
          end,
        },
        
        bottom_right = {
          icon = "⚙",
          tooltip = "Settings",
          on_click = function()
            reaper.ShowConsoleMsg("[CORNER] Bottom-right clicked\n")
          end,
        },
      },
    },
  })
end

-- ============================================================================
-- PANEL 4: BOTH HEADER AND CORNER BUTTONS
-- ============================================================================

local function create_hybrid_panel()
  return Panel.new({
    id = "hybrid_panel",
    width = 850,
    height = 150,
    config = {
      bg_color = hexrgb("#1A1A1AFF"),
      border_color = hexrgb("#000000DD"),
      border_thickness = 1,
      rounding = 8,
      padding = 16,
      
      header = {
        enabled = true,
        height = 30,
        position = "top",
        bg_color = hexrgb("#1E1E1EFF"),
        border_color = hexrgb("#00000066"),
        rounding = 8,
        
        elements = {
          {
            id = "title",
            type = "button",
            config = {
              label = "🎨 Hybrid Panel",
            }
          },
        },
      },
      
      corner_buttons = {
        size = 28,
        margin = 10,
        bottom_left = {
          icon = "💡",
          tooltip = "Help",
          on_click = function()
            reaper.ShowConsoleMsg("[HYBRID] Help clicked\n")
          end,
        },
      },
      
      corner_buttons_always_visible = true, -- Show even with header
    },
  })
end

-- ============================================================================
-- PANEL 5: SIDEBARS
-- ============================================================================

local function create_sidebar_panel()
  return Panel.new({
    id = "sidebar_panel",
    width = 850,
    height = 200,
    config = {
      bg_color = hexrgb("#1A1A1AFF"),
      border_color = hexrgb("#000000DD"),
      border_thickness = 1,
      rounding = 8,
      padding = 16,

      header = {
        enabled = true,
        height = 30,
        position = "top",
        bg_color = hexrgb("#1E1E1EFF"),
        border_color = hexrgb("#00000066"),
        rounding = 8,

        elements = {
          {
            id = "title",
            type = "button",
            config = {
              label = "📐 Sidebar Demo",
            }
          },
        },
      },

      -- Left sidebar (centered)
      left_sidebar = {
        enabled = true,
        width = 40,
        bg_color = hexrgb("#1E1E1EFF"),
        border_color = hexrgb("#00000066"),
        valign = "center",
        padding = { top = 4, bottom = 4 },
        button_size = 28,
        button_spacing = 4,
        elements = {
          {
            id = "nav_home",
            icon = "🏠",
            tooltip = "Home",
            on_click = function()
              reaper.ShowConsoleMsg("[LEFT SIDEBAR] Home clicked\n")
            end,
          },
          {
            id = "nav_search",
            icon = "🔍",
            tooltip = "Search",
            on_click = function()
              reaper.ShowConsoleMsg("[LEFT SIDEBAR] Search clicked\n")
            end,
          },
          {
            id = "nav_settings",
            icon = "⚙",
            tooltip = "Settings",
            on_click = function()
              reaper.ShowConsoleMsg("[LEFT SIDEBAR] Settings clicked\n")
            end,
          },
        },
      },

      -- Right sidebar (top-aligned)
      right_sidebar = {
        enabled = true,
        width = 40,
        bg_color = hexrgb("#1E1E1EFF"),
        border_color = hexrgb("#00000066"),
        valign = "top",
        padding = { top = 4, bottom = 4 },
        button_size = 28,
        button_spacing = 4,
        elements = {
          {
            id = "action_add",
            icon = "+",
            tooltip = "Add item",
            on_click = function()
              reaper.ShowConsoleMsg("[RIGHT SIDEBAR] Add clicked\n")
            end,
          },
          {
            id = "action_remove",
            icon = "−",
            tooltip = "Remove item",
            on_click = function()
              reaper.ShowConsoleMsg("[RIGHT SIDEBAR] Remove clicked\n")
            end,
          },
        },
      },
    },
  })
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local function init()
  state.panels.alignment = create_alignment_panel()
  state.panels.bottom = create_bottom_header_panel()
  state.panels.corner = create_corner_buttons_panel()
  state.panels.hybrid = create_hybrid_panel()
  state.panels.sidebar = create_sidebar_panel()
end

init()

-- ============================================================================
-- MAIN DRAW
-- ============================================================================

local function draw(ctx, shell_state)
  state.frame_count = state.frame_count + 1
  
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 20, 20)
  
  -- Header
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#41E0A3FF"))
  ImGui.Text(ctx, "🎨 PANEL FEATURES TEST")
  ImGui.PopStyleColor(ctx, 1)
  
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#888888FF"))
  ImGui.Text(ctx, "Testing new panel capabilities")
  ImGui.PopStyleColor(ctx, 1)
  
  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
  
  -- Panel 1: Left/Right Alignment
  ImGui.PushID(ctx, "panel1")
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#FFD700FF"))
  ImGui.Text(ctx, "1. LEFT/RIGHT ALIGNMENT + SEPARATOR")
  ImGui.PopStyleColor(ctx, 1)
  ImGui.Text(ctx, "Elements can be aligned left or right. Separator creates visual break.")
  ImGui.Spacing(ctx)
  
  if state.panels.alignment:begin_draw(ctx) then
    ImGui.Text(ctx, "✓ Left-aligned: Title, Search, Middle button")
    ImGui.Text(ctx, "✓ Right-aligned: Filter dropdown, Settings")
    ImGui.Text(ctx, "✓ Separator between left and middle creates rounded corners")
    ImGui.Spacing(ctx)
    ImGui.Text(ctx, "Notice how elements adjacent to separator get corner rounding!")
  end
  state.panels.alignment:end_draw(ctx)
  ImGui.PopID(ctx)
  
  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
  
  -- Panel 2: Bottom Header
  ImGui.PushID(ctx, "panel2")
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#FFD700FF"))
  ImGui.Text(ctx, "2. BOTTOM HEADER")
  ImGui.PopStyleColor(ctx, 1)
  ImGui.Text(ctx, "Header can be positioned at top or bottom of panel.")
  ImGui.Spacing(ctx)
  
  if state.panels.bottom:begin_draw(ctx) then
    ImGui.Text(ctx, "✓ Header positioned at bottom")
    ImGui.Text(ctx, "✓ Corner rounding adjusts automatically")
    ImGui.Text(ctx, "✓ Content area is above the header")
    ImGui.Spacing(ctx)
    ImGui.Text(ctx, "Useful for status bars, action toolbars, footers!")
  end
  state.panels.bottom:end_draw(ctx)
  ImGui.PopID(ctx)
  
  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
  
  -- Panel 3: Corner Buttons
  ImGui.PushID(ctx, "panel3")
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#FFD700FF"))
  ImGui.Text(ctx, "3. CORNER BUTTONS (NO HEADER)")
  ImGui.PopStyleColor(ctx, 1)
  ImGui.Text(ctx, "Floating buttons in panel corners without header.")
  ImGui.Spacing(ctx)
  
  if state.panels.corner:begin_draw(ctx) then
    ImGui.Text(ctx, "✓ Top-left: Pin button")
    ImGui.Text(ctx, "✓ Top-right: Close button")
    ImGui.Text(ctx, "✓ Bottom-left: Add button")
    ImGui.Text(ctx, "✓ Bottom-right: Settings button")
    ImGui.Spacing(ctx)
    ImGui.Text(ctx, string.format("Bottom-left clicks: %d", state.corner_button_clicks))
    ImGui.Spacing(ctx)
    ImGui.Text(ctx, "Hover over corners to see the buttons!")
  end
  state.panels.corner:end_draw(ctx)
  ImGui.PopID(ctx)
  
  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
  
  -- Panel 4: Hybrid
  ImGui.PushID(ctx, "panel4")
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#FFD700FF"))
  ImGui.Text(ctx, "4. HEADER + CORNER BUTTONS")
  ImGui.PopStyleColor(ctx, 1)
  ImGui.Text(ctx, "Corner buttons can coexist with headers.")
  ImGui.Spacing(ctx)
  
  if state.panels.hybrid:begin_draw(ctx) then
    ImGui.Text(ctx, "✓ Has both header and corner buttons")
    ImGui.Text(ctx, "✓ Set corner_buttons_always_visible = true")
    ImGui.Text(ctx, "✓ Useful for quick actions without cluttering header")
    ImGui.Spacing(ctx)
    ImGui.Text(ctx, "Look for the 💡 button in the bottom-left corner!")
  end
  state.panels.hybrid:end_draw(ctx)
  ImGui.PopID(ctx)

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Panel 5: Sidebars
  ImGui.PushID(ctx, "panel5")
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#FFD700FF"))
  ImGui.Text(ctx, "5. SIDEBARS")
  ImGui.PopStyleColor(ctx, 1)
  ImGui.Text(ctx, "Vertical button bars on left/right sides of panel.")
  ImGui.Spacing(ctx)

  if state.panels.sidebar:begin_draw(ctx) then
    ImGui.Text(ctx, "✓ Left sidebar: 3 buttons, centered vertically")
    ImGui.Text(ctx, "✓ Right sidebar: 2 buttons, top-aligned")
    ImGui.Text(ctx, "✓ valign options: \"top\", \"center\", \"bottom\"")
    ImGui.Spacing(ctx)
    ImGui.Text(ctx, "Great for navigation, toolbars, or quick actions!")
  end
  state.panels.sidebar:end_draw(ctx)
  ImGui.PopID(ctx)

  ImGui.PopStyleVar(ctx, 1)
end

-- ============================================================================
-- STARTUP
-- ============================================================================

reaper.ShowConsoleMsg("\n")
reaper.ShowConsoleMsg("═══════════════════════════════════════\n")
reaper.ShowConsoleMsg("  PANEL FEATURES TEST\n")
reaper.ShowConsoleMsg("═══════════════════════════════════════\n")
reaper.ShowConsoleMsg("New features:\n")
reaper.ShowConsoleMsg("  ✓ Left/Right alignment in headers\n")
reaper.ShowConsoleMsg("  ✓ Bottom header positioning\n")
reaper.ShowConsoleMsg("  ✓ Corner buttons (no header needed)\n")
reaper.ShowConsoleMsg("  ✓ Separator corner rounding\n")
reaper.ShowConsoleMsg("  ✓ Hybrid panels (header + corners)\n")
reaper.ShowConsoleMsg("  ✓ Sidebars (vertical button bars)\n")
reaper.ShowConsoleMsg("═══════════════════════════════════════\n\n")

Shell.run({
  title = "Panel Features Test",
  version = "v3.0.0",
  version_color = hexrgb("#888888FF"),
  style = StyleOK and Style or nil,
  initial_pos = { x = 100, y = 100 },
  initial_size = { w = 900, h = 1150 },
  min_size = { w = 900, h = 900 },
  icon_color = hexrgb("#41E0A3FF"),
  icon_size = 18,

  draw = draw,
})

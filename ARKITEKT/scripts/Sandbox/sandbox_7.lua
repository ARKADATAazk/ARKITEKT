-- @noindex
-- Test overlay toolbar system with regular toolbars

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path

-- Get script directory and navigate to ARKITEKT root
local script_path = debug.getinfo(1, "S").source:match("@?(.*[\\/])") or ""
local arkitekt_root = script_path .. "../../"  -- From scripts/Sandbox/ to ARKITEKT/

-- Add arkitekt to package path (points to parent of arkitekt/ folder)
package.path = package.path .. ';' .. arkitekt_root .. '?.lua'
package.path = package.path .. ';' .. arkitekt_root .. '?/init.lua'

local ImGui = require 'imgui' '0.10'
local Panel = require('arkitekt.gui.widgets.containers.panel')

-- ============================================================================
-- STATE
-- ============================================================================

local ctx
local panel
local window_open = true

-- ============================================================================
-- PANEL CONFIG
-- ============================================================================

local panel_config = {
  bg_color = 0x1E1E1EFF,
  border_color = 0x3C3C3CFF,
  border_thickness = 1,
  rounding = 8,
  padding = 10,

  -- Regular top toolbar
  header = {
    enabled = true,
    height = 30,
    position = "top",
    bg_color = 0x2D2D2DFF,
    border_color = 0x3C3C3CFF,
    elements = {
      {
        type = "button",
        id = "btn1",
        label = "Regular Top 1",
        config = {
          width = 100,
        }
      },
      {
        type = "button",
        id = "btn2",
        label = "Regular Top 2",
        config = {
          width = 100,
        }
      }
    }
  },

  -- Regular left toolbar (vertical buttons)
  left_sidebar = {
    enabled = true,
    width = 36,
    elements = {
      {
        id = "left1",
        label = "L1",
        config = {}
      },
      {
        id = "left2",
        label = "L2",
        config = {}
      }
    }
  },

  -- Overlay toolbar (left side, button trigger)
  overlay_toolbars = {
    left = {
      enabled = true,
      width = 200,
      extend_from_edge = true,  -- Start from panel edge, not regular toolbar edge
      auto_hide = {
        enabled = true,
        trigger = "button",  -- BUTTON TRIGGER: Click to expand/collapse
        visible_amount = 0.15,  -- 15% visible when hidden
        animation_speed = 0.2,
      },
      -- NO bg_color = overlay is transparent by default (floats above content)
      elements = {
        {
          id = "overlay1",
          label = "Overlay 1",
          config = {}
        },
        {
          id = "overlay2",
          label = "Overlay 2",
          config = {}
        },
        {
          id = "overlay3",
          label = "Overlay 3",
          config = {}
        }
      }
    },

    -- Overlay toolbar on right (always visible, with background)
    right = {
      enabled = true,
      width = 150,
      extend_from_edge = true,  -- Start from panel edge
      auto_hide = {
        enabled = true,
        trigger = "always_visible",
        visible_amount = 1.0,
        animation_speed = 0.15,
      },
      bg_color = 0x2A2A2A99,  -- Optional: semi-transparent background (if you want it)
      elements = {
        {
          id = "overlay_r1",
          label = "R1",
          config = {}
        },
        {
          id = "overlay_r2",
          label = "R2",
          config = {}
        }
      }
    }
  },

  -- Background pattern
  background_pattern = {
    enabled = true,
    primary = {
      type = 'dots',
      spacing = 20,
      dot_size = 2,
      color = 0x404040FF,
    }
  }
}

-- ============================================================================
-- INIT
-- ============================================================================

local function init()
  ctx = ImGui.CreateContext('Overlay Toolbar Test - Sandbox 7')

  -- Create panel with config
  panel = Panel.new({
    id = "test_panel",
    width = 800,
    height = 600,
    config = panel_config
  })

  reaper.ShowConsoleMsg("\n=== Overlay Toolbar Test Started ===\n")
  reaper.ShowConsoleMsg("Left overlay: BUTTON trigger - click arrow to expand/collapse\n")
  reaper.ShowConsoleMsg("Right overlay: Always visible, with background\n\n")
end

-- ============================================================================
-- RENDER
-- ============================================================================

local function render()
  ImGui.SetNextWindowSize(ctx, 850, 650, ImGui.Cond_FirstUseEver)

  local visible, open = ImGui.Begin(ctx, 'Overlay Toolbar Test - Sandbox 7', true)
  window_open = open

  if visible then
    if panel:begin_draw(ctx) then
      -- Content area
      ImGui.Text(ctx, "Overlay Toolbar System Test")
      ImGui.Separator(ctx)
      ImGui.Dummy(ctx, 0, 10)

      ImGui.Text(ctx, "Regular Toolbars:")
      ImGui.BulletText(ctx, "Top toolbar: Static, has background")
      ImGui.BulletText(ctx, "Left toolbar: Static vertical buttons")
      ImGui.Dummy(ctx, 0, 10)

      ImGui.Text(ctx, "Overlay Toolbars:")
      ImGui.BulletText(ctx, "Left: BUTTON trigger, transparent, at panel edge")
      ImGui.BulletText(ctx, "Right: Always visible, semi-transparent background")
      ImGui.Dummy(ctx, 0, 10)

      ImGui.Text(ctx, "Configuration:")
      ImGui.BulletText(ctx, "trigger = 'button' -> click arrow to toggle")
      ImGui.BulletText(ctx, "trigger = 'hover' -> auto-expand on mouse over")
      ImGui.BulletText(ctx, "trigger = 'always_visible' -> always shown")
      ImGui.BulletText(ctx, "extend_from_edge = true -> overlay at panel edge")
      ImGui.BulletText(ctx, "bg_color = nil -> transparent overlay (default)")
      ImGui.Dummy(ctx, 0, 20)

      ImGui.TextColored(ctx, 0x00FF00FF, "Instructions:")
      ImGui.BulletText(ctx, "Click the '>' arrow button at LEFT to expand overlay")
      ImGui.BulletText(ctx, "Overlay buttons float ABOVE content (no background)")
      ImGui.BulletText(ctx, "Scroll down to see scrollbar z-order")
      ImGui.Dummy(ctx, 0, 10)

      -- Add some content to test scrolling
      for i = 1, 30 do
        ImGui.Text(ctx, string.format("Content line %d - Testing scrollbar overlap", i))
      end
    end
    panel:end_draw(ctx)

    ImGui.End(ctx)
  end
end

-- ============================================================================
-- MAIN LOOP
-- ============================================================================

local function loop()
  render()

  if window_open then
    reaper.defer(loop)
  else
    ImGui.DestroyContext(ctx)
    reaper.ShowConsoleMsg("\n=== Overlay Toolbar Test Closed ===\n")
  end
end

-- ============================================================================
-- START
-- ============================================================================

init()
reaper.defer(loop)

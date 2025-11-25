-- @noindex
-- Test overlay toolbar system with regular toolbars

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

-- Add arkitekt to path
package.path = package.path .. ';' .. reaper.GetResourcePath() .. '/Scripts/ARKITEKT/?.lua'
package.path = package.path .. ';' .. reaper.GetResourcePath() .. '/Scripts/ARKITEKT/ARKITEKT/?.lua'

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

  -- Overlay toolbar (left side, auto-hide on hover)
  overlay_toolbars = {
    left = {
      enabled = true,
      width = 200,
      auto_hide = {
        enabled = true,
        trigger = "hover",
        visible_amount = 0.15,  -- 15% visible when hidden
        animation_speed = 0.2,
      },
      bg_color = 0x252525CC,  -- Semi-transparent background
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

    -- Overlay toolbar on right (always visible)
    right = {
      enabled = true,
      width = 150,
      auto_hide = {
        enabled = true,
        trigger = "always_visible",
        visible_amount = 1.0,
        animation_speed = 0.15,
      },
      bg_color = 0x2A2A2AEE,
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
  ctx = ImGui.CreateContext('Overlay Toolbar Test')

  -- Create panel with config
  panel = Panel.new({
    id = "test_panel",
    width = 800,
    height = 600,
    config = panel_config
  })

  reaper.ShowConsoleMsg("Overlay Toolbar Test Started\n")
  reaper.ShowConsoleMsg("Left overlay: Hover to show (15% visible when hidden)\n")
  reaper.ShowConsoleMsg("Right overlay: Always visible\n")
end

-- ============================================================================
-- RENDER
-- ============================================================================

local function render()
  ImGui.SetNextWindowSize(ctx, 850, 650, ImGui.Cond_FirstUseEver)

  local visible, open = ImGui.Begin(ctx, 'Overlay Toolbar Test', true)
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
      ImGui.BulletText(ctx, "Left overlay: Hover to expand (15% visible)")
      ImGui.BulletText(ctx, "Right overlay: Always fully visible")
      ImGui.Dummy(ctx, 0, 10)

      ImGui.Text(ctx, "Z-Order (bottom to top):")
      ImGui.BulletText(ctx, "1. Panel background + regular toolbars")
      ImGui.BulletText(ctx, "2. Content area (this text)")
      ImGui.BulletText(ctx, "3. Overlay toolbars (animated)")
      ImGui.BulletText(ctx, "4. Scrollbar (if present)")
      ImGui.Dummy(ctx, 0, 20)

      -- Add some content to test scrolling
      for i = 1, 30 do
        ImGui.Text(ctx, string.format("Content line %d", i))
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
  end
end

-- ============================================================================
-- START
-- ============================================================================

init()
reaper.defer(loop)

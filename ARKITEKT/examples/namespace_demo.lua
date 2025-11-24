-- ARKITEKT Namespace Demo
-- Shows the new ImGui-style ark.* syntax

local ImGui = require('reaper_imgui')
local ark = require('arkitekt')

-- Compare old vs new syntax:

-- OLD (explicit requires - still works!)
-- local Button = require('arkitekt.gui.widgets.primitives.button')
-- local Checkbox = require('arkitekt.gui.widgets.primitives.checkbox')
-- local Panel = require('arkitekt.gui.widgets.containers.panel')

-- NEW (ImGui-style namespace - cleaner!)
-- Just require once, access everything via ark.*

local ctx = ImGui.CreateContext('ARKITEKT Namespace Demo')

local state = {
  checked = false,
  text = "Hello ARKITEKT",
  combo_value = 1,
  combo_items = "Option 1\31Option 2\31Option 3",
}

local function loop()
  local visible, open = ImGui.Begin(ctx, 'Namespace Demo', true)
  if visible then
    ImGui.Text(ctx, "Using ark.* namespace (like ImGui.*):")
    ImGui.Separator(ctx)

    -- Primitives via namespace
    if ark.Button.draw(ctx, {label = "Click Me!", width = 200}) then
      reaper.ShowMessageBox("Button clicked!", "Event", 0)
    end

    ImGui.Spacing(ctx)

    state.checked = ark.Checkbox.draw(ctx, {
      label = "Enable Feature",
      checked = state.checked
    })

    ImGui.Spacing(ctx)

    state.text = ark.InputText.draw(ctx, {
      label = "Input",
      value = state.text,
      width = 200
    })

    ImGui.Spacing(ctx)

    state.combo_value = ark.Combo.draw(ctx, {
      label = "Select",
      current_item = state.combo_value,
      items = state.combo_items,
      width = 200
    })

    ImGui.Separator(ctx)
    ImGui.Text(ctx, "Containers also available:")

    -- Container via namespace
    ark.Panel.draw(ctx, {
      id = "demo_panel",
      title = "Sample Panel",
      width = 300,
      height = 200,
      x = 50,
      y = 150,
      body = function(panel_ctx)
        ImGui.Text(panel_ctx, "Panel content via ark.Panel!")
        ark.Separator.draw(panel_ctx, {})
        ImGui.Text(panel_ctx, "Clean syntax, just like ImGui.*")
      end
    })

    ImGui.End(ctx)
  end

  if open then
    reaper.defer(loop)
  else
    ImGui.DestroyContext(ctx)
  end
end

reaper.defer(loop)

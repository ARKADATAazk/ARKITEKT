-- @noindex
-- ProductionPanel/ui/views/macro_controls.lua
-- Macro controls view with 8 assignable knobs

local M = {}

-- DEPENDENCIES
local Knob = require('scripts.ProductionPanel.ui.widgets.knob')
local Defaults = require('scripts.ProductionPanel.defs.defaults')
local ImGui = require('imgui')('0.10')
local Colors = require('arkitekt.core.colors')
local Theme = require('arkitekt.core.theme')

-- MOCK DATA (for prototype)
local mock_macros = {
  { name = "Cutoff", value = 0.65, assigned = "Filter - Cutoff" },
  { name = "Resonance", value = 0.42, assigned = "Filter - Q" },
  { name = "Attack", value = 0.15, assigned = "Env - Attack" },
  { name = "Release", value = 0.58, assigned = "Env - Release" },
  { name = "Mix", value = 0.50, assigned = "Reverb - Mix" },
  { name = "Time", value = 0.73, assigned = "Delay - Time" },
  { name = "Feedback", value = 0.38, assigned = "Delay - Feedback" },
  { name = "Drive", value = 0.80, assigned = "Distortion - Drive" },
}

-- STATE
local state = {
  macros = {},
  learn_mode = false,
  selected_macro = nil,
}

---Initialize the macro controls view
function M.init()
  -- Initialize with mock data
  for i = 1, Defaults.MACROS.COUNT do
    state.macros[i] = {
      name = mock_macros[i].name,
      value = mock_macros[i].value,
      min = Defaults.MACROS.MIN_VALUE,
      max = Defaults.MACROS.MAX_VALUE,
      assigned = mock_macros[i].assigned,
    }
  end
end

---Draw macro controls view
---@param ctx userdata ImGui context
function M.draw(ctx)
  if #state.macros == 0 then
    M.init()
  end

  local knob_size = Defaults.UI.KNOB_SIZE
  local spacing = Defaults.UI.KNOB_SPACING
  local padding = Defaults.UI.SECTION_PADDING

  -- Header
  ImGui.PushFont(ctx, "font_title" or 0)
  ImGui.Text(ctx, "Macro Controls")
  ImGui.PopFont(ctx)

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Learn mode toggle
  local button_color = state.learn_mode and Colors.hexrgb("#D94A4A") or Theme.COLORS.BUTTON_BG or Colors.hexrgb("#383C45")
  ImGui.PushStyleColor(ctx, ImGui.Col_Button, button_color)
  if ImGui.Button(ctx, state.learn_mode and "● LEARN MODE ACTIVE" or "Learn", 150, 28) then
    state.learn_mode = not state.learn_mode
    if not state.learn_mode then
      state.selected_macro = nil
    end
  end
  ImGui.PopStyleColor(ctx)

  if state.learn_mode then
    ImGui.SameLine(ctx)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, Colors.hexrgb("#D94A4A"))
    ImGui.Text(ctx, "Click a macro knob, then touch a parameter to assign")
    ImGui.PopStyleColor(ctx)
  end

  ImGui.Spacing(ctx)
  ImGui.Spacing(ctx)

  -- Macro knobs grid (2 rows of 4)
  local start_x, start_y = ImGui.GetCursorScreenPos(ctx)
  local knobs_per_row = 4
  local total_width = (knob_size * knobs_per_row) + (spacing * (knobs_per_row - 1))

  for i, macro in ipairs(state.macros) do
    local row = math.floor((i - 1) / knobs_per_row)
    local col = (i - 1) % knobs_per_row

    local x = start_x + col * (knob_size + spacing)
    local y = start_y + row * (knob_size + 60) -- 60 = knob + label + assignment

    ImGui.SetCursorScreenPos(ctx, x, y)

    -- Highlight if selected in learn mode
    local is_selected = state.learn_mode and state.selected_macro == i
    local knob_color = is_selected and Colors.hexrgb("#D94A4A") or nil

    -- Draw knob
    local result = Knob.draw(ctx, {
      id = "macro_" .. i,
      label = macro.name,
      value = macro.value,
      min = macro.min,
      max = macro.max,
      size = knob_size,
      value_color = knob_color,
      tooltip = macro.assigned and ("Assigned: " .. macro.assigned) or "No assignment",
    })

    -- Handle knob interaction
    if result.changed then
      state.macros[i].value = result.value
      -- TODO: Send value to assigned parameter
    end

    -- Click to select in learn mode
    if state.learn_mode and result.hovered and ImGui.IsMouseClicked(ctx, 0) then
      state.selected_macro = i
    end

    -- Assignment label below knob
    ImGui.SetCursorScreenPos(ctx, x, y + knob_size + 24)
    local assign_text = macro.assigned or "Not assigned"
    local assign_color = macro.assigned and Colors.hexrgb("#A0A0A0") or Colors.hexrgb("#606060")

    -- Truncate if too long
    local max_chars = 12
    if #assign_text > max_chars then
      assign_text = assign_text:sub(1, max_chars) .. "..."
    end

    local text_w = ImGui.CalcTextSize(ctx, assign_text)
    ImGui.SetCursorScreenPos(ctx, x + (knob_size - text_w) / 2, y + knob_size + 24)

    ImGui.PushStyleColor(ctx, ImGui.Col_Text, assign_color)
    ImGui.Text(ctx, assign_text)
    ImGui.PopStyleColor(ctx)
  end

  -- Advance cursor past knobs
  ImGui.SetCursorScreenPos(ctx, start_x, start_y + (2 * (knob_size + 60)) + padding)

  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Assignment panel (mockup)
  ImGui.Text(ctx, "Active FX Container: None")
  ImGui.Spacing(ctx)

  ImGui.PushStyleColor(ctx, ImGui.Col_Text, Colors.hexrgb("#808080"))
  ImGui.Text(ctx, "📝 Mockup: Select an FX container to enable macro assignment")
  ImGui.PopStyleColor(ctx)
end

---Get current macro values
---@return table Array of macro values
function M.get_macro_values()
  local values = {}
  for i, macro in ipairs(state.macros) do
    values[i] = macro.value
  end
  return values
end

---Set macro value
---@param index number Macro index (1-8)
---@param value number New value
function M.set_macro_value(index, value)
  if state.macros[index] then
    state.macros[index].value = math.max(0, math.min(1, value))
  end
end

return M

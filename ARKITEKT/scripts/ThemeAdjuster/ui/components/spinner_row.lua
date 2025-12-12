-- @noindex
-- ThemeAdjuster/ui/components/spinner_row.lua
-- Reusable spinner row component for parameter views

local ImGui = require('arkitekt.core.imgui')
local Ark = require('arkitekt')

local M = {}

-- Draw a spinner row with right-aligned label
-- @param ctx ImGui context
-- @param opts table {
--   label: string - Display label
--   id: string - Spinner ID
--   value: number - Current index (1-based)
--   options: table - Array of option strings/values
--   label_width: number - Width for label column (default 100)
--   spinner_width: number - Width for spinner (required)
--   label_color: number - Label text color (default 0xAAAAAAFF)
-- }
-- @return changed: boolean, new_value: number
function M.draw(ctx, opts)
  local label = opts.label
  local id = opts.id
  local value = opts.value
  local options = opts.options
  local label_width = opts.label_width or 100
  local spinner_width = opts.spinner_width
  local label_color = opts.label_color or 0xAAAAAAFF

  -- Label (right-aligned in label column)
  local label_text_w = ImGui.CalcTextSize(ctx, label)
  ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + label_width - label_text_w)
  ImGui.AlignTextToFramePadding(ctx)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, label_color)
  ImGui.Text(ctx, label)
  ImGui.PopStyleColor(ctx)

  -- Spinner (fixed position, fixed width)
  ImGui.SameLine(ctx, 0, 8)
  local spinner_result = Ark.Spinner(ctx, {
    id = id,
    value = value,
    options = options,
    width = spinner_width,
    height = 24,
  })

  ImGui.Dummy(ctx, 0, 2)

  return spinner_result.changed, spinner_result.value
end

-- Create a spinner row factory for a specific column layout
-- @param ctx ImGui context
-- @param col_width: number - Column width
-- @param label_width: number - Label width (default 100)
-- @return function(label, id, value, options) -> changed, new_value
function M.create_factory(ctx, col_width, label_width)
  label_width = label_width or 100
  local spinner_width = col_width - label_width - 16

  return function(label, id, value, options)
    return M.draw(ctx, {
      label = label,
      id = id,
      value = value,
      options = options,
      label_width = label_width,
      spinner_width = spinner_width,
    })
  end
end

return M

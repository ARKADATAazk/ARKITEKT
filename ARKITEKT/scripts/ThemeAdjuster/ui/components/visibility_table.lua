-- @noindex
-- ThemeAdjuster/ui/components/visibility_table.lua
-- Reusable visibility flags table component

local ImGui = require('arkitekt.core.imgui')

local M = {}

-- Draw a visibility flags table
-- @param ctx ImGui context
-- @param opts table {
--   id: string - Table ID
--   elements: table[] - Array of {id: string, label: string}
--   columns: table[] - Array of {bit: number, label: string}
--   visibility: table - Map of element_id -> current_value (bitflags)
--   tooltip_strings: table - Map of element_id -> tooltip string
--   width: number - Table width
--   height: number - Table height (default 300)
--   element_col_width: number - First column width (default 130)
--   flag_col_width: number - Flag column width (default 85)
--   on_toggle: function(element_id, bit) - Callback when flag is toggled
-- }
function M.draw(ctx, opts)
  local id = opts.id
  local elements = opts.elements
  local columns = opts.columns
  local visibility = opts.visibility
  local tooltip_strings = opts.tooltip_strings or {}
  local width = opts.width
  local height = opts.height or 300
  local element_col_width = opts.element_col_width or 130
  local flag_col_width = opts.flag_col_width or 85
  local on_toggle = opts.on_toggle

  local col_count = 1 + #columns

  ImGui.PushStyleVar(ctx, ImGui.StyleVar_CellPadding, 6, 4)

  local table_flags = ImGui.TableFlags_Borders | ImGui.TableFlags_RowBg | ImGui.TableFlags_ScrollY
  if ImGui.BeginTable(ctx, id, col_count, table_flags, width, height) then
    -- Setup columns
    ImGui.TableSetupColumn(ctx, 'Element', ImGui.TableColumnFlags_WidthFixed, element_col_width)
    for _, col in ipairs(columns) do
      ImGui.TableSetupColumn(ctx, col.label, ImGui.TableColumnFlags_WidthFixed, flag_col_width)
    end
    ImGui.TableSetupScrollFreeze(ctx, 0, 1)
    ImGui.TableHeadersRow(ctx)

    -- Rows
    for _, elem in ipairs(elements) do
      ImGui.TableNextRow(ctx)

      -- Element name
      ImGui.TableSetColumnIndex(ctx, 0)
      ImGui.AlignTextToFramePadding(ctx)
      ImGui.Text(ctx, elem.label)

      -- Checkboxes for each condition
      for col_idx, col in ipairs(columns) do
        ImGui.TableSetColumnIndex(ctx, col_idx)

        local current_value = visibility[elem.id] or 0
        local is_checked = (current_value & col.bit) ~= 0

        ImGui.PushID(ctx, elem.id .. '_' .. col.bit)
        if ImGui.Checkbox(ctx, '##check', is_checked) then
          if on_toggle then
            on_toggle(elem.id, col.bit)
          end
        end
        if ImGui.IsItemHovered(ctx) then
          local tooltip = tooltip_strings[elem.id] or ('Toggle ' .. elem.label)
          ImGui.SetTooltip(ctx, tooltip)
        end
        ImGui.PopID(ctx)
      end
    end

    ImGui.EndTable(ctx)
  end

  ImGui.PopStyleVar(ctx)
end

return M

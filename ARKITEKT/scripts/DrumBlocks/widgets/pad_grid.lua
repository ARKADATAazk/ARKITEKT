-- @noindex
-- DrumBlocks/widgets/pad_grid.lua
-- 4x4 pad grid widget

local Ark = require('arkitekt')
local ImGui = Ark.ImGui

local M = {}

local PAD_SIZE = 80
local PAD_SPACING = 4
local GRID_COLS = 4
local GRID_ROWS = 4

local COLORS = {
  pad_empty = 0x333333FF,
  pad_loaded = 0x444466FF,
  pad_selected = 0x6666AAFF,
  pad_hover = 0x555577FF,
  pad_playing = 0x66AA66FF,
  pad_border = 0x666666FF,
  text = 0xFFFFFFFF,
  text_dim = 0x999999FF,
}

function M.draw(ctx, state, opts)
  opts = opts or {}
  local pad_size = opts.pad_size or PAD_SIZE
  local spacing = opts.spacing or PAD_SPACING

  local start_x, start_y = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)

  local selected_pad = state.getSelectedPad()
  local current_bank = state.getCurrentBank()

  for row = 0, GRID_ROWS - 1 do
    for col = 0, GRID_COLS - 1 do
      local pad_index = state.getPadIndexForGrid(row, col)
      local pad_data = state.getPadData(pad_index)

      local x = start_x + col * (pad_size + spacing)
      local y = start_y + row * (pad_size + spacing)

      -- Determine pad color
      local bg_color = COLORS.pad_empty
      if state.hasSample(pad_index) then
        bg_color = COLORS.pad_loaded
      end
      if pad_index == selected_pad then
        bg_color = COLORS.pad_selected
      end

      -- Invisible button for interaction
      ImGui.SetCursorScreenPos(ctx, x, y)
      local clicked = ImGui.InvisibleButton(ctx, '##pad_' .. pad_index, pad_size, pad_size)
      local hovered = ImGui.IsItemHovered(ctx)

      if hovered then
        bg_color = COLORS.pad_hover
        if pad_index == selected_pad then
          bg_color = COLORS.pad_selected
        end
      end

      -- Handle click
      if clicked then
        state.setSelectedPad(pad_index)
      end

      -- Handle drag-drop target
      if ImGui.BeginDragDropTarget(ctx) then
        local payload, _ = ImGui.AcceptDragDropPayload(ctx, 'FILES')
        if payload then
          -- payload contains the file path
          state.setPadSample(pad_index, 0, payload)
        end
        ImGui.EndDragDropTarget(ctx)
      end

      -- Draw pad background
      ImGui.DrawList_AddRectFilled(dl, x, y, x + pad_size, y + pad_size, bg_color, 4)
      ImGui.DrawList_AddRect(dl, x, y, x + pad_size, y + pad_size, COLORS.pad_border, 4)

      -- Draw pad number
      local pad_num = string.format('%d', (pad_index % 16) + 1)
      ImGui.DrawList_AddText(dl, x + 4, y + 2, COLORS.text_dim, pad_num)

      -- Draw sample name if loaded
      if pad_data.name then
        local name = pad_data.name
        if #name > 10 then
          name = name:sub(1, 9) .. '..'
        end
        local text_x = x + pad_size / 2 - ImGui.CalcTextSize(ctx, name) / 2
        local text_y = y + pad_size - 18
        ImGui.DrawList_AddText(dl, text_x, text_y, COLORS.text, name)
      end

      -- Draw velocity indicator (placeholder for when playing)
      -- TODO: Track last trigger time and velocity for visual feedback
    end
  end

  -- Reserve space for the grid
  local total_w = GRID_COLS * (pad_size + spacing) - spacing
  local total_h = GRID_ROWS * (pad_size + spacing) - spacing
  ImGui.Dummy(ctx, total_w, total_h)

  return {
    width = total_w,
    height = total_h,
  }
end

return M

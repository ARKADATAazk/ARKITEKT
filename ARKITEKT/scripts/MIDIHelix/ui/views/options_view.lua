-- @noindex
-- MIDIHelix/ui/views/options_view.lua
-- Settings and preferences view

local M = {}

-- Dependencies (set during init)
local Ark = nil
local ImGui = nil

-- State
local state = {
  initialized = false,
}

--- Initialize the Options view
--- @param ark_instance table Ark instance
function M.init(ark_instance)
  if state.initialized then return end
  Ark = ark_instance
  ImGui = Ark.ImGui
  state.initialized = true
end

--- Draw the Options view
--- @param ctx userdata ImGui context
--- @param opts table { x, y, w, h, tab_color }
function M.Draw(ctx, opts)
  if not state.initialized then return end

  opts = opts or {}
  local base_x = opts.x or 0
  local base_y = opts.y or 0
  local win_w = opts.w or 900
  local win_h = opts.h or 200
  local tab_color = opts.tab_color or 0x808080FF

  -- Placeholder content
  local cx = base_x + win_w / 2
  local cy = base_y + win_h / 2 - 20

  ImGui.SetCursorScreenPos(ctx, cx - 60, cy)
  ImGui.TextColored(ctx, tab_color, 'Options')

  ImGui.SetCursorScreenPos(ctx, cx - 130, cy + 25)
  ImGui.TextColored(ctx, 0x808080FF, 'Preferences and MIDI settings')

  ImGui.SetCursorScreenPos(ctx, cx - 80, cy + 50)
  ImGui.TextColored(ctx, 0x606060FF, '[ Coming Soon ]')
end

function M.get_state()
  return {}
end

function M.set_state(new_state)
end

return M

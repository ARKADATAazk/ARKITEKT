-- @noindex
-- MIDIHelix/ui/components/header.lua
-- Header bar with title and zoom control

local M = {}

-- Dependencies (set during init)
local Ark = nil
local ImGui = nil

-- ============================================================================
-- STATE
-- ============================================================================

local state = {
  initialized = false,
}

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Initialize the header component
--- @param ark_instance table Ark instance
function M.init(ark_instance)
  if state.initialized then return end
  Ark = ark_instance
  ImGui = Ark.ImGui
  state.initialized = true
end

--- Draw the header bar
--- @param ctx userdata ImGui context
--- @param opts table { x, y, width, height, title, tab_color, rounding, zoom_level }
function M.Draw(ctx, opts)
  if not state.initialized then return end

  local x = opts.x or 5
  local y = opts.y or 5
  local width = opts.width or 400
  local height = opts.height or 22
  local title = opts.title or 'MIDI Helix'
  local tab_color = opts.tab_color or 0xFF8C00FF
  local rounding = opts.rounding or 4
  local zoom_level = opts.zoom_level or 100

  local dl = ImGui.GetWindowDrawList(ctx)

  -- Header background with tab accent color
  ImGui.DrawList_AddRectFilled(dl, x, y, x + width, y + height, tab_color, rounding)

  -- Zoom dropdown area (left side)
  local zoom_w = 40
  ImGui.DrawList_AddRectFilled(dl, x, y, x + zoom_w, y + height, 0x00000030, rounding)

  local zoom_text = tostring(zoom_level) .. '%'
  local zoom_tw = ImGui.CalcTextSize(ctx, zoom_text)
  ImGui.DrawList_AddText(dl, x + (zoom_w - zoom_tw) / 2, y + 4, 0xFFFFFFFF, zoom_text)

  -- Title text
  local title_x = x + zoom_w + 10
  local title_y = y + 4
  ImGui.DrawList_AddText(dl, title_x, title_y, 0x202020FF, title)
end

return M

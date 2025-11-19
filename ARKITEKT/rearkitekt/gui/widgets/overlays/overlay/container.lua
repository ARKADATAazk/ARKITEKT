-- @noindex
-- ReArkitekt/gui/widgets/overlay/container.lua
-- Reusable dark container pattern for non-blocking modals

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

-- Default container styling - simple squares with 1px black border
local DEFAULTS = {
  width = 0.6,           -- Percentage of bounds width
  height = 0.7,          -- Percentage of bounds height
  rounding = 0,          -- Square corners (no rounding)
  bg_color = hexrgb("#101010"),  -- Darker background
  bg_opacity = 1.0,
  border_color = hexrgb("#000000"),  -- Black border
  border_opacity = 1.0,
  border_thickness = 1,  -- 1 pixel border
  padding = 12,          -- Subtle internal padding
}

-- Render a dark container with content
-- Usage in overlay render callback:
--   Container.render(ctx, alpha, bounds, function(ctx, content_w, content_h)
--     -- Your content here
--   end, { width = 0.5, height = 0.6 })
function M.render(ctx, alpha, bounds, content_fn, opts)
  opts = opts or {}

  -- Merge with defaults
  local config = {}
  for k, v in pairs(DEFAULTS) do
    config[k] = opts[k] ~= nil and opts[k] or v
  end

  -- Calculate container dimensions
  local w = math.floor(bounds.w * config.width)
  local h = math.floor(bounds.h * config.height)
  local x = math.floor(bounds.x + (bounds.w - w) * 0.5)
  local y = math.floor(bounds.y + (bounds.h - h) * 0.5)
  local r = config.rounding

  -- Create child window for container (renders above scrim)
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 0, 0)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding, r)

  -- Dark background color for child
  local bg_color = Colors.with_alpha(config.bg_color, math.floor(255 * config.bg_opacity * alpha))
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, bg_color)

  local child_flags = ImGui.ChildFlags_None or 0
  local window_flags = ImGui.WindowFlags_NoScrollbar
  ImGui.BeginChild(ctx, '##modal_container', w, h, child_flags, window_flags)

  -- Draw simple 1px black border
  local dl = ImGui.GetWindowDrawList(ctx)
  local border_color = Colors.with_alpha(config.border_color, math.floor(255 * config.border_opacity * alpha))
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, border_color, r, 0, config.border_thickness)

  ImGui.PopStyleColor(ctx, 1)
  ImGui.PopStyleVar(ctx, 2)

  -- Render content with padding
  local padding = config.padding
  local content_w = w - padding * 2
  local content_h = h - padding * 2

  ImGui.SetCursorPos(ctx, padding, padding)

  if content_fn then
    content_fn(ctx, content_w, content_h, w, h, alpha, padding)
  end

  ImGui.EndChild(ctx)
end

return M

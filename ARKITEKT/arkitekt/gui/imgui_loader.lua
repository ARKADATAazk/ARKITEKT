-- @noindex
-- arkitekt/gui/imgui_loader.lua
-- Centralized ImGui initialization
-- Eliminates the need to repeat package.path setup in every widget file

local M = {}

-- Cached ImGui module
local _ImGui = nil

-- Initialize ImGui path and return the module
-- This function is idempotent - safe to call multiple times
function M.get()
  if _ImGui then
    return _ImGui
  end

  -- Add ImGui to package path if not already present
  local imgui_path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
  if not package.path:find(imgui_path, 1, true) then
    package.path = imgui_path .. ';' .. package.path
  end

  -- Load and cache ImGui
  _ImGui = require 'imgui' '0.10'

  return _ImGui
end

-- Shorthand alias for get()
M.ImGui = setmetatable({}, {
  __index = function(_, key)
    return M.get()[key]
  end,
  __call = function(_, ...)
    return M.get()(...)
  end
})

return M

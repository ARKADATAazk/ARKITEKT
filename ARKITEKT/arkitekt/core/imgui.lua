-- @noindex
-- ImGui centralized loader
-- Manages ImGui version in one place
-- Usage in library modules: local ImGui = require('arkitekt.core.imgui')

-- Set up ImGui builtin path (required for ReaImGui extension)
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path

return require('imgui')('0.10')

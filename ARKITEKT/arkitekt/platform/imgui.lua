-- @noindex
-- ImGui centralized loader
-- Manages ImGui version in one place
-- Usage in library modules: local ImGui = require('arkitekt.platform.imgui':gsub('core', 'platform'))

return require('imgui')('0.10')

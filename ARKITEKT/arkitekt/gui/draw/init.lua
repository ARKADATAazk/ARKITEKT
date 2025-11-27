-- @noindex
-- arkitekt/gui/draw/init.lua
-- Convenience loader for draw.primitives (backwards compatibility)
--
-- This allows both of these to work:
--   require('arkitekt.gui.draw')            -- Returns primitives (shorthand)
--   require('arkitekt.gui.draw.primitives') -- Explicit (preferred)
--
-- For other draw modules, use explicit paths:
--   require('arkitekt.gui.draw.shapes')
--   require('arkitekt.gui.draw.effects')
--   require('arkitekt.gui.draw.patterns')

return require('arkitekt.gui.draw.primitives')

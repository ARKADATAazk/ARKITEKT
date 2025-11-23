-- @noindex
-- arkitekt/gui/widgets/media_grid/init.lua
-- Media grid component for browsing audio/MIDI items with visualization
--
-- A reusable grid component for displaying media items with:
-- - Waveform visualization for audio
-- - MIDI piano roll for MIDI items
-- - Multi-select support
-- - Drag & drop
-- - Preview functionality
-- - Disabled state management
-- - Cascade animations
-- - TileFX integration
--
-- Used by: ItemPicker, and other media browsing tools
--
-- Example usage:
--[[
  local MediaGrid = require('arkitekt.gui.widgets.media.media_grid')
  local AudioGridFactory = require('arkitekt.gui.widgets.media.media_grid.factories.audio')

  -- Create audio grid
  local grid = AudioGridFactory.create(ctx, {
    config = config,
    state = state,
    visualization = visualization,
    cache_mgr = cache_mgr,
    animator = animator,
  })

  -- Render
  grid:render(ctx, avail_w, avail_h)
]]

local M = {}

-- Re-export base renderer
M.renderers = {}
M.renderers.base = require('arkitekt.gui.widgets.media.media_grid.renderers.base')

-- Module metadata
M._VERSION = '1.0.0'
M._DESCRIPTION = 'Reusable media grid component for audio/MIDI browsing'
M._AUTHOR = 'ARKITEKT'

return M

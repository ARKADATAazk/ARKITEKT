-- @noindex
-- ItemPicker module loader
-- @migrated 2024-11-27 - Updated to use new architecture
--
-- This file provides backward-compatible aliases to the new structure.
-- New code should use require('ItemPicker.app.init') directly.

-- Load the new bootstrap
local App = require('ItemPicker.app.init')

local M = {}

-- ============================================================================
-- APP LAYER (new location)
-- ============================================================================
M.app = App

-- ============================================================================
-- DOMAIN LAYER (new location)
-- ============================================================================
M.domain = {
  items = App.items,
  preview = App.preview,
  pool = App.pool,
}

-- ============================================================================
-- DATA LAYER (new location)
-- ============================================================================
M.data = App.data

-- ============================================================================
-- UI LAYER (new location)
-- ============================================================================
M.ui = {
  main_window = App.ui,
  visualization = App.visualization,
}

-- ============================================================================
-- BACKWARD-COMPATIBLE ALIASES
-- @deprecated These aliases are for backward compatibility only.
-- New code should use the new paths (app/, domain/, data/, ui/).
-- ============================================================================

-- core/ aliases (deprecated)
M.core = {
  config = App.config,
  app_state = App.state,
  controller = App.items,
}

-- services/ aliases (deprecated)
M.services = {
  visualization = App.visualization,
  utils = require('ItemPicker.services.utils'),
  pool_utils = App.pool,
}

return M

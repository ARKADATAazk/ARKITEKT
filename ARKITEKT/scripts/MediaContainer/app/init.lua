-- @noindex
--- MediaContainer Application Bootstrap
-- @module MediaContainer.app.init
--
-- Central dependency injection point for MediaContainer.
-- Loads and wires together all layers: app, domain, data, ui.
--
-- @usage
--   local App = require('MediaContainer.app.init')
--   App.state.initialize(settings)
--   local gui = App.ui.new({ state = App.state, config = App.config, settings = settings })

local M = {}

-- ============================================================================
-- APP LAYER (Configuration and State)
-- ============================================================================

--- Application configuration
-- Constants and defaults for UI and behavior
M.config = require('MediaContainer.config.constants')

--- Application state
-- Container registry, clipboard, project tracking
M.state = require('MediaContainer.app.state')

-- ============================================================================
-- DOMAIN LAYER (Business Logic)
-- ============================================================================

--- Container domain
-- CRUD operations for containers (create, copy, paste, sync, delete)
M.container = require('MediaContainer.domain.container')

-- ============================================================================
-- DATA LAYER (Infrastructure / I/O)
-- ============================================================================

M.data = {
  --- Persistence
  -- Container storage via Project ExtState
  persistence = require('MediaContainer.data.persistence'),
}

-- ============================================================================
-- UI LAYER (Presentation)
-- ============================================================================

--- Main GUI orchestrator
M.ui = require('MediaContainer.ui.init')

return M

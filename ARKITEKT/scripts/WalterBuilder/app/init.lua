-- @noindex
--- WalterBuilder Application Bootstrap
-- @module WalterBuilder.app.init
--
-- Central dependency injection point for WalterBuilder.
-- Loads and wires together all layers: app, domain, data, ui.
--
-- @usage
--   local App = require('WalterBuilder.app.init')
--   App.state.initialize(settings)
--   local gui = App.ui.create(App.state, App.config, settings)

local M = {}

-- ============================================================================
-- APP LAYER (Configuration and State)
-- ============================================================================

--- Application state
-- Centralized state management for elements, tracks, selection
M.state = require('WalterBuilder.app.state')

--- Application controller
-- Business logic controller with undo/redo support
M.controller = require('WalterBuilder.app.controller')

-- ============================================================================
-- DOMAIN LAYER (Business Logic)
-- ============================================================================

--- Element domain
-- Element model for WALTER layout elements
M.element = require('WalterBuilder.domain.element')

--- Coordinate domain
-- Coordinate math and rect computation
M.coordinate = require('WalterBuilder.domain.coordinate')

--- Expression evaluator
-- Evaluates WALTER expressions (Polish notation)
M.expression = require('WalterBuilder.domain.expression_eval')

--- rtconfig parser
-- Tokenizes rtconfig files into AST
M.parser = require('WalterBuilder.domain.rtconfig_parser')

--- rtconfig converter
-- Converts AST to Element models
M.converter = require('WalterBuilder.domain.rtconfig_converter')

--- Serializer
-- Element to rtconfig text conversion
M.serializer = require('WalterBuilder.domain.serializer')

--- Simulator
-- Simulates layout at different sizes
M.simulator = require('WalterBuilder.domain.simulator')

-- ============================================================================
-- DATA LAYER (Infrastructure / I/O)
-- ============================================================================

M.data = {
  --- Settings storage
  -- WalterBuilder-specific settings persistence
  settings = require('WalterBuilder.data.settings'),
}

-- ============================================================================
-- UI LAYER (Presentation)
-- ============================================================================

--- Main GUI orchestrator
M.ui = require('WalterBuilder.ui.init')

-- ============================================================================
-- DEFINITIONS (Constants)
-- ============================================================================

--- Constants and configuration
M.defs = {
  constants = require('WalterBuilder.config.constants'),
  colors = require('WalterBuilder.config.colors'),
  tcp_elements = require('WalterBuilder.config.tcp_elements'),
  track_defaults = require('WalterBuilder.config.track_defaults'),
  scalars = require('WalterBuilder.config.scalars'),
}

return M

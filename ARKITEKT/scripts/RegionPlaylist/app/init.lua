-- @noindex
--- RegionPlaylist Application Bootstrap
-- @module RegionPlaylist.app.init
-- @created 2025-12-01
--
-- Central dependency injection point for RegionPlaylist.
-- Loads and wires together all layers: app, domain, data, ui.
--
-- @usage
--   local App = require('RegionPlaylist.app.init')
--   App.state.initialize(settings)
--   local gui = App.ui.create(App.state, App.config, settings)

local M = {}

-- ============================================================================
-- APP LAYER (Configuration and State)
-- ============================================================================

--- Application configuration
-- Factory functions for dynamic configs (transport, containers, tiles)
M.config = require('RegionPlaylist.app.config')

--- Application state
-- Centralized state management using domain composition pattern
M.state = require('RegionPlaylist.app.state')

-- ============================================================================
-- DOMAIN LAYER (Business Logic)
-- ============================================================================

--- Playlist domain
-- CRUD operations for playlists (create, delete, add/remove items, reorder)
M.playlist = require('RegionPlaylist.domain.playlist')

--- Region domain
-- Region cache and pool ordering (scan project, filter, custom order)
M.region = require('RegionPlaylist.domain.region')

--- Dependency domain
-- Circular reference detection for nested playlists
M.dependency = require('RegionPlaylist.domain.dependency')

--- Playback engine
-- State machine for playlist/region playback with quantization
M.playback = {
  controller = require('RegionPlaylist.domain.playback.controller'),
  state = require('RegionPlaylist.domain.playback.state'),
  transport = require('RegionPlaylist.domain.playback.transport'),
  transitions = require('RegionPlaylist.domain.playback.transitions'),
  quantize = require('RegionPlaylist.domain.playback.quantize'),
  loop = require('RegionPlaylist.domain.playback.loop'),
  expander = require('RegionPlaylist.domain.playback.expander'),
}

-- ============================================================================
-- DATA LAYER (Infrastructure / I/O)
-- ============================================================================

M.data = {
  --- Coordinator bridge
  -- Coordination layer between UI and playback engine with lazy sequence expansion
  bridge = require('RegionPlaylist.data.bridge'),

  --- Settings storage
  -- Persistence using file-based JSON storage
  storage = require('RegionPlaylist.data.storage'),

  --- SWS import
  -- Import playlists from SWS Snapshots extension
  sws_import = require('RegionPlaylist.data.sws_import'),

  --- Undo manager
  -- REAPER undo point management for playlist operations
  undo = require('RegionPlaylist.data.undo'),
}

-- ============================================================================
-- UI LAYER (Presentation)
-- ============================================================================

--- Main GUI orchestrator
M.ui = require('RegionPlaylist.ui.init')

--- Status bar configuration
M.status = require('RegionPlaylist.ui.status')

-- ============================================================================
-- DEFINITIONS (Constants)
-- ============================================================================

--- Constants
-- Animation timings, button configs, quantize modes
M.defs = {
  constants = require('RegionPlaylist.config.constants'),
  defaults = require('RegionPlaylist.config.defaults'),
  strings = require('RegionPlaylist.config.strings'),
}

return M

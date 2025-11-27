-- @noindex
--- ItemPicker Application Bootstrap
-- @module ItemPicker.app.init
-- @migrated 2024-11-27 (new file)
--
-- Central dependency injection point for ItemPicker.
-- Loads and wires together all layers: app, domain, data, ui.
--
-- @usage
--   local App = require('ItemPicker.app.init')
--   App.state.initialize(App.config)

local M = {}

-- ============================================================================
-- APP LAYER (Configuration and State)
-- ============================================================================

--- Application configuration
-- Re-exports constants from defs/
M.config = require("ItemPicker.app.config")

--- Application state
-- Centralized state management (single source of truth)
M.state = require("ItemPicker.app.state")

-- ============================================================================
-- DOMAIN LAYER (Business Logic)
-- ============================================================================

--- Item service
-- Business logic controller for item operations
M.items = require("ItemPicker.domain.items.service")

--- Preview manager
-- Handles audio/MIDI preview playback
M.preview = require("ItemPicker.domain.preview.manager")

--- Filters
-- Filtering logic for items, tracks, pools, regions
M.filters = {
  items = require("ItemPicker.domain.filters.items"),
  track = require("ItemPicker.domain.filters.track"),
  pool = require("ItemPicker.domain.filters.pool"),
  region = require("ItemPicker.domain.filters.region"),
}

-- ============================================================================
-- DATA LAYER (Infrastructure / I/O)
-- ============================================================================

M.data = {
  --- Settings storage
  -- Persistence using REAPER project extended state
  storage = require("ItemPicker.data.storage"),

  --- Disk cache
  -- Project-scoped disk cache with LRU eviction
  cache = require("ItemPicker.data.cache"),

  --- Job queue
  -- Async job processing for waveform/thumbnail generation
  job_queue = require("ItemPicker.data.job_queue"),

  --- REAPER API wrapper
  -- Abstraction over REAPER's item/track API
  reaper_api = require("ItemPicker.data.reaper_api"),

  --- Incremental loader
  -- Processes items in small batches per frame
  loader = require("ItemPicker.data.loader"),
}

-- ============================================================================
-- UI LAYER (Presentation)
-- ============================================================================

--- Main window / GUI orchestrator
M.ui = require("ItemPicker.ui.main_window")

--- Visualization
-- Waveform and MIDI thumbnail generation
M.visualization = require("ItemPicker.ui.visualization")

return M

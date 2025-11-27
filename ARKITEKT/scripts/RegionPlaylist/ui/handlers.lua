-- @noindex
-- RegionPlaylist/ui/handlers.lua
-- Centralized event handlers for UI updates
--
-- This module contains handlers that respond to app events and update UI state.
-- Migrated from inline callbacks in gui.lua (Phase 2: event-driven architecture)
--
-- Usage:
--   local Handlers = require("RegionPlaylist.ui.handlers")
--   Handlers.setup(app_state, gui_context)

local Logger = require("arkitekt.debug.logger")

local M = {}

-- =============================================================================
-- HANDLER CONTEXT
-- =============================================================================

local ctx = {
  app_state = nil,
  gui = nil,
  unsubscribers = {},
}

-- =============================================================================
-- PLAYBACK HANDLERS
-- =============================================================================

local function on_playback_started(data)
  if not ctx.gui then return end
  Logger.debug("HANDLERS", "Playback started: rid=%s, pointer=%s",
    tostring(data.rid), tostring(data.pointer))
end

local function on_playback_stopped(data)
  if not ctx.gui then return end
  Logger.debug("HANDLERS", "Playback stopped")
end

local function on_playback_paused(data)
  if not ctx.gui then return end
  Logger.debug("HANDLERS", "Playback paused at position %.2fs",
    data.position or -1)
end

local function on_playback_resumed(data)
  if not ctx.gui then return end
  Logger.debug("HANDLERS", "Playback resumed")
end

local function on_repeat_cycle(data)
  if not ctx.gui then return end
  Logger.debug("HANDLERS", "Repeat cycle: key=%s, loop=%d/%d",
    tostring(data.key), data.current_loop or 1, data.total_loops or 1)

  -- Update animation state if needed
  if ctx.app_state and ctx.app_state.animation then
    ctx.app_state.animation:queue_select(data.key)
  end
end

-- =============================================================================
-- STATE HANDLERS
-- =============================================================================

local function on_state_restored(data)
  if not ctx.gui then return end
  Logger.debug("HANDLERS", "State restored")

  -- Clear any pending animations and refresh UI
  if ctx.app_state then
    ctx.app_state.clear_pending()
  end
end

local function on_state_saved(data)
  Logger.debug("HANDLERS", "State saved")
end

-- =============================================================================
-- SETUP
-- =============================================================================

--- Set up event handlers
--- @param app_state table The app_state module
--- @param gui table Optional GUI context for UI updates
function M.setup(app_state, gui)
  -- Clean up any existing subscriptions
  M.cleanup()

  ctx.app_state = app_state
  ctx.gui = gui

  if not app_state or not app_state.events then
    Logger.warn("HANDLERS", "Cannot setup handlers: no event bus available")
    return
  end

  local events = app_state.events
  local EVENTS = app_state.EVENTS

  -- Subscribe to playback events
  ctx.unsubscribers[#ctx.unsubscribers + 1] = events:on(EVENTS.PLAYBACK_STARTED, on_playback_started)
  ctx.unsubscribers[#ctx.unsubscribers + 1] = events:on(EVENTS.PLAYBACK_STOPPED, on_playback_stopped)
  ctx.unsubscribers[#ctx.unsubscribers + 1] = events:on(EVENTS.PLAYBACK_PAUSED, on_playback_paused)
  ctx.unsubscribers[#ctx.unsubscribers + 1] = events:on(EVENTS.PLAYBACK_RESUMED, on_playback_resumed)
  ctx.unsubscribers[#ctx.unsubscribers + 1] = events:on(EVENTS.PLAYBACK_REPEAT_CYCLE, on_repeat_cycle)

  -- Subscribe to state events
  ctx.unsubscribers[#ctx.unsubscribers + 1] = events:on(EVENTS.STATE_RESTORED, on_state_restored)
  ctx.unsubscribers[#ctx.unsubscribers + 1] = events:on(EVENTS.STATE_SAVED, on_state_saved)

  Logger.info("HANDLERS", "Event handlers registered (%d subscriptions)", #ctx.unsubscribers)
end

--- Clean up event handlers
function M.cleanup()
  for _, unsubscribe in ipairs(ctx.unsubscribers) do
    if type(unsubscribe) == "function" then
      unsubscribe()
    end
  end
  ctx.unsubscribers = {}
  ctx.app_state = nil
  ctx.gui = nil
end

--- Get handler context (for debugging)
function M.get_context()
  return ctx
end

return M

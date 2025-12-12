-- @noindex
-- MIDIHelix/ui/init.lua
-- Main UI orchestrator (RegionPlaylist-inspired clean architecture)

local M = {}

-- Dependencies
local Layout = require('scripts.MIDIHelix.config.layout')
local TabColors = require('scripts.MIDIHelix.config.colors')

-- Components
local TabBar = require('scripts.MIDIHelix.ui.components.tab_bar')
local Header = require('scripts.MIDIHelix.ui.components.header')

-- Views
local EuclideanView = require('scripts.MIDIHelix.ui.views.euclidean_view')
local RandomizerView = require('scripts.MIDIHelix.ui.views.randomizer_view')
local SequencerView = require('scripts.MIDIHelix.ui.views.sequencer_view')
local MelodicView = require('scripts.MIDIHelix.ui.views.melodic_view')
local RhythmView = require('scripts.MIDIHelix.ui.views.rhythm_view')
local GenerativeView = require('scripts.MIDIHelix.ui.views.generative_view')
local OptionsView = require('scripts.MIDIHelix.ui.views.options_view')

-- Will be set during init
local Ark = nil
local ImGui = nil

-- ============================================================================
-- TAB CONFIGURATION
-- ============================================================================

local TABS = {
  { id = 'euclidean',  label = 'Euclidean',  color = TabColors.TABS.EUCLIDEAN,  enabled = true, view = EuclideanView },
  { id = 'sequencer',  label = 'Sequencer',  color = TabColors.TABS.SEQUENCER,  enabled = true, view = SequencerView },
  { id = 'randomizer', label = 'Randomizer', color = TabColors.TABS.RANDOMIZER, enabled = true, view = RandomizerView },
  { id = 'melodic',    label = 'Melodic',    color = TabColors.TABS.MELODIC,    enabled = true, view = MelodicView },
  { id = 'rhythm',     label = 'Rhythm',     color = TabColors.TABS.RHYTHM,     enabled = true, view = RhythmView },
  { id = 'generative', label = 'Generative', color = TabColors.TABS.GENERATIVE, enabled = true, view = GenerativeView },
  { id = 'options',    label = 'Options',    color = TabColors.TABS.OPTIONS,    enabled = true, view = OptionsView },
}

-- ============================================================================
-- STATE
-- ============================================================================

local state = {
  initialized = false,
  current_tab = 1,  -- Start on Euclidean (first tab)
  zoom_level = 100,
}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local function init_views(ark_instance)
  for _, tab in ipairs(TABS) do
    if tab.view and tab.view.init then
      tab.view.init(ark_instance)
    end
  end
end

-- ============================================================================
-- DRAWING
-- ============================================================================

local function draw_content(ctx, content_x, content_y, content_w, content_h)
  local tab = TABS[state.current_tab]
  if not tab or not tab.view then return end

  tab.view.Draw(ctx, {
    x = content_x,
    y = content_y,
    w = content_w,
    h = content_h,
    tab_color = tab.color,
  })
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Initialize the UI
--- @param ark_instance table The Ark instance
function M.init(ark_instance)
  if state.initialized then return end

  Ark = ark_instance
  ImGui = Ark.ImGui

  -- Initialize components
  TabBar.init(Ark)
  Header.init(Ark)

  -- Initialize all views
  init_views(Ark)

  state.initialized = true
end

--- Draw the main UI
--- @param ctx userdata ImGui context
function M.Draw(ctx)
  if not state.initialized then
    M.init(require('arkitekt'))
  end

  -- Get window geometry
  local win_x, win_y = ImGui.GetWindowPos(ctx)
  local win_w, win_h = ImGui.GetWindowSize(ctx)

  -- Layout calculations
  local header_h = Layout.HEADER.H
  local tab_bar_h = Layout.TAB_BAR.H
  local padding = Layout.PADDING

  -- Content area (between header and tab bar)
  local content_x = win_x
  local content_y = win_y + header_h + padding
  local content_w = win_w
  local content_h = win_h - header_h - tab_bar_h - padding * 3

  -- Tab bar position (bottom)
  local tab_bar_y = win_y + win_h - tab_bar_h - padding

  -- Get current tab info
  local current_tab = TABS[state.current_tab]
  local tab_color = current_tab and current_tab.color or 0xFF8C00FF

  -- Draw header
  Header.Draw(ctx, {
    x = win_x + Layout.HEADER.X,
    y = win_y + Layout.HEADER.Y,
    width = win_w - Layout.HEADER.X * 2,
    height = header_h,
    title = 'MIDI Helix',
    tab_color = tab_color,
    rounding = Layout.ROUNDING,
    zoom_level = state.zoom_level,
  })

  -- Draw content area
  draw_content(ctx, content_x, content_y, content_w, content_h)

  -- Draw tab bar
  TabBar.Draw(ctx, {
    tabs = TABS,
    current_tab = state.current_tab,
    x = win_x,
    y = tab_bar_y,
    width = win_w,
    rounding = Layout.ROUNDING,
    on_tab_change = function(index, tab)
      state.current_tab = index
    end,
    on_undo = function()
      -- TODO: Implement undo
    end,
    on_redo = function()
      -- TODO: Implement redo
    end,
  })
end

--- Get current tab info
--- @return table Current tab { id, label, color }
function M.get_current_tab()
  return TABS[state.current_tab]
end

--- Set current tab by id
--- @param tab_id string Tab identifier
function M.set_tab(tab_id)
  for i, tab in ipairs(TABS) do
    if tab.id == tab_id and tab.enabled then
      state.current_tab = i
      return true
    end
  end
  return false
end

--- Get all tab states (for persistence)
--- @return table States keyed by tab id
function M.get_all_states()
  local states = {}
  for _, tab in ipairs(TABS) do
    if tab.view and tab.view.get_state then
      states[tab.id] = tab.view.get_state()
    end
  end
  states._current_tab = state.current_tab
  states._zoom_level = state.zoom_level
  return states
end

--- Restore all tab states (for persistence)
--- @param states table States keyed by tab id
function M.set_all_states(states)
  if not states then return end
  for _, tab in ipairs(TABS) do
    if tab.view and tab.view.set_state and states[tab.id] then
      tab.view.set_state(states[tab.id])
    end
  end
  if states._current_tab then
    state.current_tab = states._current_tab
  end
  if states._zoom_level then
    state.zoom_level = states._zoom_level
  end
end

return M

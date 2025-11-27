-- @noindex
-- WalterBuilder/app/state.lua
-- Application state management

local Element = require('WalterBuilder.domain.element')
local TCPElements = require('WalterBuilder.defs.tcp_elements')
local TrackDefaults = require('WalterBuilder.defs.track_defaults')

local M = {}

-- State storage
local state = {
  settings = nil,

  -- Layout elements
  elements = {},

  -- Track list for visualization
  tracks = {},

  -- Selection
  selected_element = nil,
  selected_track = nil,

  -- Canvas state
  parent_w = 300,
  parent_h = 90,

  -- UI state
  show_grid = true,
  show_attachments = true,
  show_tracks = true,  -- Show track list visualization

  -- Context (tcp, mcp, etc.)
  context = "tcp",
}

-- Initialize state
function M.initialize(settings)
  state.settings = settings

  if settings then
    state.parent_w = settings:get('parent_w', 300)
    state.parent_h = settings:get('parent_h', 90)
    state.show_grid = settings:get('show_grid', true)
    state.show_attachments = settings:get('show_attachments', true)
    state.context = settings:get('context', "tcp")

    -- Load saved elements
    local saved_elements = settings:get('elements', nil)
    if saved_elements then
      M.load_elements(saved_elements)
    end
  end
end

-- Save state
function M.save()
  if not state.settings then return end

  state.settings:set('parent_w', state.parent_w)
  state.settings:set('parent_h', state.parent_h)
  state.settings:set('show_grid', state.show_grid)
  state.settings:set('show_attachments', state.show_attachments)
  state.settings:set('context', state.context)

  -- Save elements
  local element_data = {}
  for _, elem in ipairs(state.elements) do
    element_data[#element_data + 1] = {
      id = elem.id,
      name = elem.name,
      category = elem.category,
      visible = elem.visible,
      coords = {
        x = elem.coords.x,
        y = elem.coords.y,
        w = elem.coords.w,
        h = elem.coords.h,
        ls = elem.coords.ls,
        ts = elem.coords.ts,
        rs = elem.coords.rs,
        bs = elem.coords.bs,
      },
    }
  end
  state.settings:set('elements', element_data)
end

-- Load elements from saved data
function M.load_elements(data)
  state.elements = {}
  for _, elem_data in ipairs(data) do
    local elem = Element.new({
      id = elem_data.id,
      name = elem_data.name,
      category = elem_data.category,
      visible = elem_data.visible,
      coords = elem_data.coords,
    })
    state.elements[#state.elements + 1] = elem
  end
end

-- Get all elements
function M.get_elements()
  return state.elements
end

-- Get element by ID
function M.get_element(id)
  for _, elem in ipairs(state.elements) do
    if elem.id == id then
      return elem
    end
  end
  return nil
end

-- Add element from definition
function M.add_element(def)
  -- Check if already exists
  if M.get_element(def.id) then
    return nil  -- Already in layout
  end

  local elem = Element.new({
    id = def.id,
    name = def.name,
    category = def.category,
    description = def.description,
    is_size = def.is_size,
    is_margin = def.is_margin,
    coords = def.coords,
  })

  state.elements[#state.elements + 1] = elem
  M.save()
  return elem
end

-- Remove element
function M.remove_element(element)
  for i, elem in ipairs(state.elements) do
    if elem == element or elem.id == element.id then
      table.remove(state.elements, i)
      if state.selected_element == elem then
        state.selected_element = nil
      end
      M.save()
      return true
    end
  end
  return false
end

-- Clear all elements
function M.clear_elements()
  state.elements = {}
  state.selected_element = nil
  M.save()
end

-- Get element IDs (for palette active state)
function M.get_element_ids()
  local ids = {}
  for _, elem in ipairs(state.elements) do
    ids[#ids + 1] = elem.id
  end
  return ids
end

-- Selection
function M.get_selected()
  return state.selected_element
end

function M.set_selected(element)
  state.selected_element = element
end

function M.clear_selection()
  state.selected_element = nil
end

-- Canvas size
function M.get_parent_size()
  return state.parent_w, state.parent_h
end

function M.set_parent_size(w, h)
  state.parent_w = w
  state.parent_h = h
  M.save()
end

-- Display options
function M.get_show_grid()
  return state.show_grid
end

function M.set_show_grid(value)
  state.show_grid = value
  M.save()
end

function M.get_show_attachments()
  return state.show_attachments
end

function M.set_show_attachments(value)
  state.show_attachments = value
  M.save()
end

-- Context
function M.get_context()
  return state.context
end

function M.set_context(context)
  state.context = context
  M.save()
end

-- Load default TCP layout
function M.load_tcp_defaults()
  M.clear_elements()

  -- Add some common TCP elements with reasonable defaults
  local defaults = {
    "tcp.size",
    "tcp.mute",
    "tcp.solo",
    "tcp.recarm",
    "tcp.volume",
    "tcp.pan",
    "tcp.label",
    "tcp.meter",
  }

  for _, id in ipairs(defaults) do
    local def = TCPElements.get_definition(id)
    if def then
      M.add_element(def)
    end
  end
end

-- Notify element changed (for re-rendering)
function M.element_changed(element)
  M.save()
end

-- ============================================
-- TRACK MANAGEMENT
-- ============================================

-- Get all tracks
function M.get_tracks()
  return state.tracks
end

-- Add a track
function M.add_track(opts)
  local track = TrackDefaults.new_track(opts)
  state.tracks[#state.tracks + 1] = track
  return track
end

-- Remove a track
function M.remove_track(track)
  for i, t in ipairs(state.tracks) do
    if t == track or t.id == track.id then
      table.remove(state.tracks, i)
      if state.selected_track == t then
        state.selected_track = nil
      end
      return true
    end
  end
  return false
end

-- Clear all tracks
function M.clear_tracks()
  state.tracks = {}
  state.selected_track = nil
end

-- Load default tracks for demonstration
function M.load_default_tracks()
  state.tracks = TrackDefaults.get_default_tracks()
end

-- Get selected track
function M.get_selected_track()
  return state.selected_track
end

-- Set selected track
function M.set_selected_track(track)
  state.selected_track = track
end

-- Get show tracks option
function M.get_show_tracks()
  return state.show_tracks
end

-- Set show tracks option
function M.set_show_tracks(value)
  state.show_tracks = value
end

-- Calculate total height of all tracks
function M.get_total_tracks_height()
  local total = 0
  for _, track in ipairs(state.tracks) do
    if track.visible then
      total = total + track.height
    end
  end
  return total
end

-- Get track at Y position (for hit testing)
function M.get_track_at_y(y)
  local current_y = 0
  for _, track in ipairs(state.tracks) do
    if track.visible then
      if y >= current_y and y < current_y + track.height then
        return track, current_y
      end
      current_y = current_y + track.height
    end
  end
  return nil, 0
end

return M

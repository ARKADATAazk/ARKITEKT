-- @noindex
-- RegionPlaylist/tests/domain_tests.lua
-- Tests for domain modules

local TestRunner = require('arkitekt.debug.test_runner')
local assert = TestRunner.assert

-- Mock constants for testing (matches defs/constants.lua)
local MOCK_CONSTANTS = {
  LAYOUT_MODES = {
    HORIZONTAL = 'horizontal',
    VERTICAL = 'vertical',
  },
  POOL_MODES = {
    REGIONS = 'regions',
    PLAYLISTS = 'playlists',
    MIXED = 'mixed',
  },
  SORT_DIRECTIONS = {
    ASC = 'asc',
    DESC = 'desc',
  },
}

-- Mock settings for testing
local function create_mock_settings()
  local store = {}
  return {
    get = function(_, key) return store[key] end,
    set = function(_, key, value) store[key] = value end,
    _store = store,
  }
end

-- ============================================================================
-- REGION DOMAIN TESTS
-- ============================================================================

local region_tests = {}

function region_tests.test_new_creates_empty_domain()
  local Region = require('RegionPlaylist.domain.region')
  local domain = Region.new()

  assert.not_nil(domain, 'Domain should be created')
  assert.is_type(domain.region_index, 'table', 'region_index should be table')
  assert.is_type(domain.pool_order, 'table', 'pool_order should be table')
  assert.equals(0, domain:count(), 'New domain should have 0 regions')
end

function region_tests.test_refresh_from_bridge()
  local Region = require('RegionPlaylist.domain.region')
  local domain = Region.new()

  local mock_regions = {
    { rid = 1, name = 'Intro', color = 0xFF0000 },
    { rid = 2, name = 'Verse', color = 0x00FF00 },
    { rid = 3, name = 'Chorus', color = 0x0000FF },
  }

  domain:refresh_from_bridge(mock_regions)

  assert.equals(3, domain:count(), 'Should have 3 regions')
  assert.table_length(domain:get_pool_order(), 3, 'Pool order should have 3 entries')
end

function region_tests.test_get_region_by_rid()
  local Region = require('RegionPlaylist.domain.region')
  local domain = Region.new()

  local mock_regions = {
    { rid = 10, name = 'Test Region', color = 0xFF0000 },
  }
  domain:refresh_from_bridge(mock_regions)

  local region = domain:get_region_by_rid(10)
  assert.not_nil(region, 'Should find region by rid')
  assert.equals('Test Region', region.name, 'Region name should match')

  local missing = domain:get_region_by_rid(999)
  assert.is_nil(missing, 'Non-existent region should return nil')
end

function region_tests.test_set_pool_order()
  local Region = require('RegionPlaylist.domain.region')
  local domain = Region.new()

  local mock_regions = {
    { rid = 1, name = 'A' },
    { rid = 2, name = 'B' },
    { rid = 3, name = 'C' },
  }
  domain:refresh_from_bridge(mock_regions)

  -- Reorder: C, A, B
  domain:set_pool_order({ 3, 1, 2 })

  local order = domain:get_pool_order()
  assert.equals(3, order[1], 'First should be RID 3')
  assert.equals(1, order[2], 'Second should be RID 1')
  assert.equals(2, order[3], 'Third should be RID 2')
end

-- ============================================================================
-- PLAYLIST DOMAIN TESTS
-- ============================================================================

local playlist_tests = {}

function playlist_tests.test_new_creates_empty_domain()
  local Playlist = require('RegionPlaylist.domain.playlist')
  local domain = Playlist.new()

  assert.not_nil(domain, 'Domain should be created')
  assert.equals(0, domain:count(), 'New domain should have 0 playlists')
  assert.is_nil(domain:get_active_id(), 'Active playlist should be nil')
end

function playlist_tests.test_load_playlists()
  local Playlist = require('RegionPlaylist.domain.playlist')
  local domain = Playlist.new()

  local mock_playlists = {
    { id = 'uuid-1', name = 'Playlist A', items = {} },
    { id = 'uuid-2', name = 'Playlist B', items = {} },
  }

  domain:load_playlists(mock_playlists)

  assert.equals(2, domain:count(), 'Should have 2 playlists')
end

function playlist_tests.test_get_by_id()
  local Playlist = require('RegionPlaylist.domain.playlist')
  local domain = Playlist.new()

  local mock_playlists = {
    { id = 'uuid-1', name = 'Playlist A', items = {} },
    { id = 'uuid-2', name = 'Playlist B', items = {} },
  }
  domain:load_playlists(mock_playlists)

  local pl = domain:get_by_id('uuid-1')
  assert.not_nil(pl, 'Should find playlist by ID')
  assert.equals('Playlist A', pl.name, 'Playlist name should match')

  local missing = domain:get_by_id('nonexistent')
  assert.is_nil(missing, 'Non-existent playlist should return nil')
end

function playlist_tests.test_set_and_get_active()
  local Playlist = require('RegionPlaylist.domain.playlist')
  local domain = Playlist.new()

  local mock_playlists = {
    { id = 'uuid-1', name = 'Playlist A', items = {} },
    { id = 'uuid-2', name = 'Playlist B', items = {} },
  }
  domain:load_playlists(mock_playlists)

  domain:set_active('uuid-2')
  assert.equals('uuid-2', domain:get_active_id(), 'Active ID should be uuid-2')

  local active = domain:get_active()
  assert.not_nil(active, 'Should get active playlist object')
  assert.equals('Playlist B', active.name, 'Active playlist should be B')
end

function playlist_tests.test_get_active_fallback()
  local Playlist = require('RegionPlaylist.domain.playlist')
  local domain = Playlist.new()

  local mock_playlists = {
    { id = 'uuid-1', name = 'Playlist A', items = {} },
  }
  domain:load_playlists(mock_playlists)

  -- No active set, should fallback to first
  local active = domain:get_active()
  assert.not_nil(active, 'Should fallback to first playlist')
  assert.equals('uuid-1', active.id, 'Fallback should be first playlist')
end

function playlist_tests.test_move_to_front()
  local Playlist = require('RegionPlaylist.domain.playlist')
  local domain = Playlist.new()

  local mock_playlists = {
    { id = 'uuid-1', name = 'A', items = {} },
    { id = 'uuid-2', name = 'B', items = {} },
    { id = 'uuid-3', name = 'C', items = {} },
  }
  domain:load_playlists(mock_playlists)

  domain:move_to_front('uuid-3')

  local all = domain:get_all()
  assert.equals('uuid-3', all[1].id, 'C should now be first')
  assert.equals('uuid-1', all[2].id, 'A should be second')
  assert.equals('uuid-2', all[3].id, 'B should be third')
end

function playlist_tests.test_reorder_by_ids()
  local Playlist = require('RegionPlaylist.domain.playlist')
  local domain = Playlist.new()

  local mock_playlists = {
    { id = 'uuid-1', name = 'A', items = {} },
    { id = 'uuid-2', name = 'B', items = {} },
    { id = 'uuid-3', name = 'C', items = {} },
  }
  domain:load_playlists(mock_playlists)

  domain:reorder_by_ids({ 'uuid-2', 'uuid-3', 'uuid-1' })

  local all = domain:get_all()
  assert.equals('uuid-2', all[1].id, 'B should be first')
  assert.equals('uuid-3', all[2].id, 'C should be second')
  assert.equals('uuid-1', all[3].id, 'A should be third')
end

function playlist_tests.test_count_contents()
  local Playlist = require('RegionPlaylist.domain.playlist')
  local domain = Playlist.new()

  local mock_playlists = {
    {
      id = 'uuid-1',
      name = 'Mixed Playlist',
      items = {
        { type = 'region', rid = 1 },
        { type = 'region', rid = 2 },
        { type = 'playlist', playlist_id = 'uuid-other' },
        { type = 'region', rid = 3 },
      }
    },
  }
  domain:load_playlists(mock_playlists)

  local region_count, playlist_count = domain:count_contents('uuid-1')
  assert.equals(3, region_count, 'Should count 3 regions')
  assert.equals(1, playlist_count, 'Should count 1 nested playlist')
end

function playlist_tests.test_get_tabs()
  local Playlist = require('RegionPlaylist.domain.playlist')
  local domain = Playlist.new()

  local mock_playlists = {
    { id = 'uuid-1', name = 'Tab A', chip_color = 0xFF0000, items = {} },
    { id = 'uuid-2', name = 'Tab B', chip_color = 0x00FF00, items = {} },
  }
  domain:load_playlists(mock_playlists)

  local tabs = domain:get_tabs()
  assert.table_length(tabs, 2, 'Should have 2 tabs')
  assert.equals('Tab A', tabs[1].label, 'First tab label should match')
  assert.equals(0xFF0000, tabs[1].chip_color, 'First tab color should match')
end

-- ============================================================================
-- UI PREFERENCES DOMAIN TESTS
-- ============================================================================

local ui_pref_tests = {}

function ui_pref_tests.test_new_creates_domain_with_defaults()
  local UIPref = require('RegionPlaylist.ui.state.preferences')
  local domain = UIPref.new(MOCK_CONSTANTS, nil)

  assert.not_nil(domain, 'Domain should be created')
  assert.equals('', domain:get_search_filter(), 'Search should be empty')
  assert.equals('horizontal', domain:get_layout_mode(), 'Default layout is horizontal')
  assert.equals('regions', domain:get_pool_mode(), 'Default pool mode is regions')
  assert.equals('asc', domain:get_sort_direction(), 'Default sort direction is asc')
end

function ui_pref_tests.test_search_filter()
  local UIPref = require('RegionPlaylist.ui.state.preferences')
  local domain = UIPref.new(MOCK_CONSTANTS, nil)

  domain:set_search_filter('test query')
  assert.equals('test query', domain:get_search_filter(), 'Search filter should be set')

  domain:set_search_filter('')
  assert.equals('', domain:get_search_filter(), 'Search filter should be cleared')
end

function ui_pref_tests.test_sort_mode()
  local UIPref = require('RegionPlaylist.ui.state.preferences')
  local domain = UIPref.new(MOCK_CONSTANTS, nil)

  domain:set_sort_mode('name')
  assert.equals('name', domain:get_sort_mode(), 'Sort mode should be name')

  domain:set_sort_mode(nil)
  assert.is_nil(domain:get_sort_mode(), 'Sort mode can be nil')
end

function ui_pref_tests.test_sort_direction_validation()
  local UIPref = require('RegionPlaylist.ui.state.preferences')
  local domain = UIPref.new(MOCK_CONSTANTS, nil)

  domain:set_sort_direction('desc')
  assert.equals('desc', domain:get_sort_direction(), 'Sort direction should be desc')

  domain:set_sort_direction('asc')
  assert.equals('asc', domain:get_sort_direction(), 'Sort direction should be asc')

  -- Test invalid direction throws
  assert.throws(function()
    domain:set_sort_direction('invalid')
  end, 'Invalid sort_direction', 'Should throw on invalid sort direction')
end

function ui_pref_tests.test_layout_mode_validation()
  local UIPref = require('RegionPlaylist.ui.state.preferences')
  local domain = UIPref.new(MOCK_CONSTANTS, nil)

  domain:set_layout_mode('vertical')
  assert.equals('vertical', domain:get_layout_mode(), 'Layout should be vertical')

  assert.throws(function()
    domain:set_layout_mode('diagonal')
  end, 'Invalid layout_mode', 'Should throw on invalid layout mode')
end

function ui_pref_tests.test_pool_mode_validation()
  local UIPref = require('RegionPlaylist.ui.state.preferences')
  local domain = UIPref.new(MOCK_CONSTANTS, nil)

  domain:set_pool_mode('playlists')
  assert.equals('playlists', domain:get_pool_mode(), 'Pool mode should be playlists')

  domain:set_pool_mode('mixed')
  assert.equals('mixed', domain:get_pool_mode(), 'Pool mode should be mixed')

  assert.throws(function()
    domain:set_pool_mode('invalid')
  end, 'Invalid pool_mode', 'Should throw on invalid pool mode')
end

function ui_pref_tests.test_save_load_settings()
  local UIPref = require('RegionPlaylist.ui.state.preferences')
  local settings = create_mock_settings()
  local domain = UIPref.new(MOCK_CONSTANTS, settings)

  -- Set various preferences
  domain:set_search_filter('my search')
  domain:set_sort_mode('color')
  domain:set_sort_direction('desc')
  domain:set_layout_mode('vertical')
  domain:set_pool_mode('mixed')

  -- Save to settings
  domain:save_to_settings()

  -- Create new domain and load
  local domain2 = UIPref.new(MOCK_CONSTANTS, settings)
  domain2:load_from_settings()

  assert.equals('my search', domain2:get_search_filter(), 'Search should persist')
  assert.equals('color', domain2:get_sort_mode(), 'Sort mode should persist')
  assert.equals('desc', domain2:get_sort_direction(), 'Sort direction should persist')
  assert.equals('vertical', domain2:get_layout_mode(), 'Layout should persist')
  assert.equals('mixed', domain2:get_pool_mode(), 'Pool mode should persist')
end

function ui_pref_tests.test_separator_positions()
  local UIPref = require('RegionPlaylist.ui.state.preferences')
  local domain = UIPref.new(MOCK_CONSTANTS, nil)

  assert.is_nil(domain:get_separator_position_horizontal(), 'Initial horizontal separator is nil')
  assert.is_nil(domain:get_separator_position_vertical(), 'Initial vertical separator is nil')

  domain:set_separator_position_horizontal(200)
  domain:set_separator_position_vertical(300)

  assert.equals(200, domain:get_separator_position_horizontal(), 'Horizontal separator should be 200')
  assert.equals(300, domain:get_separator_position_vertical(), 'Vertical separator should be 300')
end

-- ============================================================================
-- DEPENDENCY DOMAIN TESTS
-- ============================================================================

local dependency_tests = {}

function dependency_tests.test_new_creates_empty_domain()
  local Dependency = require('RegionPlaylist.domain.dependency')
  local domain = Dependency.new()

  assert.not_nil(domain, 'Domain should be created')
  assert.truthy(domain.dirty, 'New domain should be dirty')
end

function dependency_tests.test_rebuild_simple()
  local Dependency = require('RegionPlaylist.domain.dependency')
  local domain = Dependency.new()

  local mock_playlists = {
    { id = 'pl-1', items = {} },
    { id = 'pl-2', items = {} },
  }

  domain:rebuild(mock_playlists)

  assert.falsy(domain.dirty, 'Domain should not be dirty after rebuild')
  assert.not_nil(domain.graph['pl-1'], 'Should have graph entry for pl-1')
  assert.not_nil(domain.graph['pl-2'], 'Should have graph entry for pl-2')
end

function dependency_tests.test_is_draggable_to_self()
  local Dependency = require('RegionPlaylist.domain.dependency')
  local domain = Dependency.new()

  local mock_playlists = {
    { id = 'pl-1', items = {} },
  }
  domain:rebuild(mock_playlists)

  local can_drag = domain:is_draggable_to('pl-1', 'pl-1')
  assert.falsy(can_drag, 'Cannot drag playlist to itself')
end

function dependency_tests.test_is_draggable_to_independent()
  local Dependency = require('RegionPlaylist.domain.dependency')
  local domain = Dependency.new()

  local mock_playlists = {
    { id = 'pl-1', items = {} },
    { id = 'pl-2', items = {} },
  }
  domain:rebuild(mock_playlists)

  local can_drag = domain:is_draggable_to('pl-1', 'pl-2')
  assert.truthy(can_drag, 'Can drag independent playlist to another')
end

function dependency_tests.test_circular_reference_direct()
  local Dependency = require('RegionPlaylist.domain.dependency')
  local domain = Dependency.new()

  -- pl-1 contains pl-2
  local mock_playlists = {
    {
      id = 'pl-1',
      items = {
        { type = 'playlist', playlist_id = 'pl-2' }
      }
    },
    { id = 'pl-2', items = {} },
  }
  domain:rebuild(mock_playlists)

  -- Trying to add pl-1 to pl-2 would create a cycle
  local has_cycle, path = domain:detect_circular_reference('pl-2', 'pl-1')
  assert.truthy(has_cycle, 'Should detect circular reference')
  assert.not_nil(path, 'Should provide cycle path')
end

function dependency_tests.test_circular_reference_self()
  local Dependency = require('RegionPlaylist.domain.dependency')
  local domain = Dependency.new()

  local mock_playlists = {
    { id = 'pl-1', items = {} },
  }
  domain:rebuild(mock_playlists)

  local has_cycle, path = domain:detect_circular_reference('pl-1', 'pl-1')
  assert.truthy(has_cycle, 'Adding playlist to itself is circular')
end

function dependency_tests.test_circular_reference_transitive()
  local Dependency = require('RegionPlaylist.domain.dependency')
  local domain = Dependency.new()

  -- pl-1 -> pl-2 -> pl-3 chain
  local mock_playlists = {
    {
      id = 'pl-1',
      items = {
        { type = 'playlist', playlist_id = 'pl-2' }
      }
    },
    {
      id = 'pl-2',
      items = {
        { type = 'playlist', playlist_id = 'pl-3' }
      }
    },
    { id = 'pl-3', items = {} },
  }
  domain:rebuild(mock_playlists)

  -- Trying to add pl-1 to pl-3 would create: pl-1 -> pl-2 -> pl-3 -> pl-1
  local has_cycle = domain:detect_circular_reference('pl-3', 'pl-1')
  assert.truthy(has_cycle, 'Should detect transitive circular reference')
end

function dependency_tests.test_no_circular_reference()
  local Dependency = require('RegionPlaylist.domain.dependency')
  local domain = Dependency.new()

  -- pl-1 -> pl-2 chain
  local mock_playlists = {
    {
      id = 'pl-1',
      items = {
        { type = 'playlist', playlist_id = 'pl-2' }
      }
    },
    { id = 'pl-2', items = {} },
    { id = 'pl-3', items = {} },
  }
  domain:rebuild(mock_playlists)

  -- Adding pl-3 to pl-2 is fine (no cycle)
  local has_cycle = domain:detect_circular_reference('pl-2', 'pl-3')
  assert.falsy(has_cycle, 'Should not detect cycle for valid addition')
end

function dependency_tests.test_mark_dirty()
  local Dependency = require('RegionPlaylist.domain.dependency')
  local domain = Dependency.new()

  local mock_playlists = {
    { id = 'pl-1', items = {} },
  }
  domain:rebuild(mock_playlists)
  assert.falsy(domain.dirty, 'Should not be dirty after rebuild')

  domain:mark_dirty()
  assert.truthy(domain.dirty, 'Should be dirty after mark_dirty')
end

function dependency_tests.test_ensure_fresh()
  local Dependency = require('RegionPlaylist.domain.dependency')
  local domain = Dependency.new()

  local mock_playlists = {
    { id = 'pl-1', items = {} },
  }

  -- Domain starts dirty
  assert.truthy(domain.dirty, 'Should start dirty')

  domain:ensure_fresh(mock_playlists)
  assert.falsy(domain.dirty, 'Should not be dirty after ensure_fresh')

  -- Calling again should not rebuild
  domain:ensure_fresh(mock_playlists)
  assert.falsy(domain.dirty, 'Should remain clean')
end

-- ============================================================================
-- REGISTER TEST SUITES
-- ============================================================================

TestRunner.register('RegionPlaylist.domain.region', region_tests)
TestRunner.register('RegionPlaylist.domain.playlist', playlist_tests)
TestRunner.register('RegionPlaylist.ui.state.preferences', ui_pref_tests)
TestRunner.register('RegionPlaylist.domain.dependency', dependency_tests)

return {
  region = region_tests,
  playlist = playlist_tests,
  ui_preferences = ui_pref_tests,
  dependency = dependency_tests,
}

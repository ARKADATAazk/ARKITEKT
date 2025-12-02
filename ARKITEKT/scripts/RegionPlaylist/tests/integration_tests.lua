-- @noindex
-- RegionPlaylist/tests/integration_tests.lua
-- Integration tests that run within REAPER with real data

local TestRunner = require('arkitekt.debug.test_runner')
local Logger = require('arkitekt.debug.logger')
local assert = TestRunner.assert

-- ============================================================================
-- INTEGRATION TEST UTILITIES
-- ============================================================================

local function get_region_count()
  local count = 0
  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  return num_regions
end

local function has_regions()
  return get_region_count() > 0
end

local function skip_if_no_regions(test_fn)
  return function()
    if not has_regions() then
      Logger.warn('TEST', 'SKIPPED - No regions in project')
      return
    end
    test_fn()
  end
end

-- ============================================================================
-- ENGINE STATE INTEGRATION TESTS
-- ============================================================================

local engine_tests = {}

function engine_tests.test_engine_state_scans_regions()
  local EngineState = require('RegionPlaylist.domain.playback.state')
  local state = EngineState.new({ proj = 0 })

  local region_count = 0
  for _ in pairs(state.region_cache) do
    region_count = region_count + 1
  end

  Logger.info('TEST', 'Engine scanned %d regions from project', region_count)
  assert.is_type(state.region_cache, 'table', 'region_cache should be table')
  assert.equals(get_region_count(), region_count, 'Should match actual region count')
end

engine_tests.test_engine_state_detects_changes = skip_if_no_regions(function()
  local EngineState = require('RegionPlaylist.domain.playback.state')
  local state = EngineState.new({ proj = 0 })

  -- Initial state - no changes
  local changed = state:check_for_changes()
  assert.falsy(changed, 'No changes immediately after creation')
end)

-- ============================================================================
-- PERSISTENCE INTEGRATION TESTS
-- ============================================================================

local storage_tests = {}

function storage_tests.test_save_and_load_playlists()
  local Persistence = require('RegionPlaylist.data.storage')
  local Ark = require('arkitekt')

  -- Create test playlist
  local test_playlist = {
    {
      id = 'test-' .. Ark.UUID.generate(),
      name = 'Integration Test Playlist',
      items = {},
      chip_color = Persistence.generate_chip_color(),
    }
  }

  -- Save
  Persistence.save_playlists(test_playlist, 0)

  -- Load and verify
  local loaded = Persistence.load_playlists(0)
  assert.not_nil(loaded, 'Should load playlists')
  assert.truthy(#loaded >= 1, 'Should have at least 1 playlist')

  -- Find our test playlist
  local found = false
  for _, pl in ipairs(loaded) do
    if pl.name == 'Integration Test Playlist' then
      found = true
      break
    end
  end
  assert.truthy(found, 'Should find our test playlist')
end

function storage_tests.test_save_and_load_settings()
  local Persistence = require('RegionPlaylist.data.storage')

  local test_settings = {
    quantize_mode = 'beat',
    shuffle_enabled = true,
    test_key = 'test_value_' .. math.random(1000),
  }

  Persistence.save_settings(test_settings, 0)
  local loaded = Persistence.load_settings(0)

  assert.not_nil(loaded, 'Should load settings')
  assert.equals(test_settings.quantize_mode, loaded.quantize_mode, 'quantize_mode should match')
  assert.equals(test_settings.shuffle_enabled, loaded.shuffle_enabled, 'shuffle_enabled should match')
  assert.equals(test_settings.test_key, loaded.test_key, 'test_key should match')
end

function storage_tests.test_active_playlist_persistence()
  local Persistence = require('RegionPlaylist.data.storage')

  local test_id = 'test-active-' .. math.random(1000)
  Persistence.save_active_playlist(test_id, 0)

  local loaded = Persistence.load_active_playlist(0)
  assert.equals(test_id, loaded, 'Active playlist ID should persist')
end

-- ============================================================================
-- SEQUENCE EXPANDER INTEGRATION TESTS
-- ============================================================================

local expander_tests = {}

function expander_tests.test_expand_empty_playlist()
  local SequenceExpander = require('RegionPlaylist.domain.playback.expander')

  local empty_playlist = { id = 'empty', name = 'Empty', items = {} }
  local sequence, map = SequenceExpander.expand_playlist(empty_playlist, function() return nil end)

  assert.is_type(sequence, 'table', 'Should return table')
  assert.table_length(sequence, 0, 'Empty playlist should produce empty sequence')
end

expander_tests.test_expand_playlist_with_regions = skip_if_no_regions(function()
  local SequenceExpander = require('RegionPlaylist.domain.playback.expander')
  local Ark = require('arkitekt')

  -- Get first region RID
  local _, _, num_regions = reaper.CountProjectMarkers(0)
  if num_regions == 0 then return end

  local first_rid = nil
  local idx = 0
  while true do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(idx)
    if retval == 0 then break end
    if isrgn then
      first_rid = markrgnindexnumber
      break
    end
    idx = idx + 1
  end

  if not first_rid then return end

  local playlist = {
    id = 'test',
    name = 'Test',
    items = {
      { type = 'region', rid = first_rid, reps = 2, key = Ark.UUID.generate() }
    }
  }

  local sequence, map = SequenceExpander.expand_playlist(playlist, function() return nil end)

  assert.truthy(#sequence >= 2, 'Should expand reps into sequence entries')
  Logger.info('TEST', 'Expanded playlist to %d sequence entries', #sequence)
end)

-- ============================================================================
-- TRANSPORT INTEGRATION TESTS (Safe - don't actually play)
-- ============================================================================

local transport_tests = {}

function transport_tests.test_transport_creation()
  local Transport = require('RegionPlaylist.domain.playback.transport')
  local EngineState = require('RegionPlaylist.domain.playback.state')

  local state = EngineState.new({ proj = 0 })
  local transport = Transport.new({
    proj = 0,
    state = state,
  })

  assert.not_nil(transport, 'Transport should be created')
  assert.falsy(transport.is_playing, 'Should not be playing initially')
  assert.falsy(transport.is_paused, 'Should not be paused initially')
end

function transport_tests.test_transport_settings()
  local Transport = require('RegionPlaylist.domain.playback.transport')
  local EngineState = require('RegionPlaylist.domain.playback.state')

  local state = EngineState.new({ proj = 0 })
  local transport = Transport.new({
    proj = 0,
    state = state,
    loop_playlist = true,
    shuffle_enabled = true,
  })

  assert.truthy(transport:get_loop_playlist(), 'loop_playlist should be enabled')
  assert.truthy(transport:get_shuffle_enabled(), 'shuffle should be enabled')

  transport:set_loop_playlist(false)
  assert.falsy(transport:get_loop_playlist(), 'loop_playlist should be disabled')
end

-- ============================================================================
-- REGISTER TEST SUITES
-- ============================================================================

TestRunner.register('RegionPlaylist.integration.engine', engine_tests)
TestRunner.register('RegionPlaylist.integration.storage', storage_tests)
TestRunner.register('RegionPlaylist.integration.expander', expander_tests)
TestRunner.register('RegionPlaylist.integration.transport', transport_tests)

return {
  engine = engine_tests,
  storage = storage_tests,
  expander = expander_tests,
  transport = transport_tests,
}

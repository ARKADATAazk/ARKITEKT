-- @noindex
-- arkitekt/debug/test_runner.lua
-- Simple test framework with Logger integration

local Logger = require('arkitekt.debug.logger')

local M = {}

-- Registry of test suites by app name
local test_suites = {}

-- Results storage
local results = {
  total = 0,
  passed = 0,
  failed = 0,
  skipped = 0,
  last_run = nil,
  details = {},
}

--- Register a test suite for an app
--- @param app_name string Name of the app (e.g., 'RegionPlaylist')
--- @param suite table Table of test_name -> test_function pairs
function M.register(app_name, suite)
  test_suites[app_name] = suite
  Logger.info('TEST', 'Registered test suite: %s (%d tests)', app_name, M.count_tests(suite))
end

--- Add tests to an existing suite
--- @param app_name string Name of the app
--- @param tests table Additional tests to add
function M.add_tests(app_name, tests)
  if not test_suites[app_name] then
    test_suites[app_name] = {}
  end
  for name, fn in pairs(tests) do
    test_suites[app_name][name] = fn
  end
end

--- Count tests in a suite
--- @param suite table Test suite table
--- @return number count Number of tests
function M.count_tests(suite)
  local count = 0
  for _ in pairs(suite) do
    count = count + 1
  end
  return count
end

--- Run a single test with error handling
--- @param app_name string App name for logging
--- @param test_name string Test name
--- @param test_fn function Test function
--- @return boolean success True if test passed
--- @return string|nil error Error message if failed
local function run_single_test(app_name, test_name, test_fn)
  local start_time = reaper.time_precise()
  local ok, err = pcall(test_fn)
  local duration = (reaper.time_precise() - start_time) * 1000

  if ok then
    Logger.info('TEST', '✓ %s.%s PASSED (%.2fms)', app_name, test_name, duration)
    return true, nil
  else
    Logger.error('TEST', '✗ %s.%s FAILED: %s', app_name, test_name, tostring(err))
    return false, tostring(err)
  end
end

--- Run all tests for a specific app
--- @param app_name string Name of the app
--- @return table results {total, passed, failed, details}
function M.run(app_name)
  local suite = test_suites[app_name]
  if not suite then
    Logger.warn('TEST', 'No test suite found for: %s', app_name)
    return { total = 0, passed = 0, failed = 0, details = {} }
  end

  local run_results = {
    total = 0,
    passed = 0,
    failed = 0,
    details = {},
  }

  Logger.info('TEST', '═══════════════════════════════════════')
  Logger.info('TEST', 'Running test suite: %s', app_name)
  Logger.info('TEST', '═══════════════════════════════════════')

  -- Sort test names for consistent ordering
  local test_names = {}
  for name in pairs(suite) do
    test_names[#test_names + 1] = name
  end
  table.sort(test_names)

  local start_time = reaper.time_precise()

  for _, test_name in ipairs(test_names) do
    local test_fn = suite[test_name]
    run_results.total = run_results.total + 1

    local success, err = run_single_test(app_name, test_name, test_fn)

    if success then
      run_results.passed = run_results.passed + 1
    else
      run_results.failed = run_results.failed + 1
    end

    run_results.details[test_name] = {
      passed = success,
      error = err,
    }
  end

  local total_duration = (reaper.time_precise() - start_time) * 1000

  Logger.info('TEST', '───────────────────────────────────────')
  Logger.info('TEST', 'Results: %d/%d passed (%.2fms)',
    run_results.passed, run_results.total, total_duration)

  if run_results.failed > 0 then
    Logger.warn('TEST', '%d tests failed', run_results.failed)
  end

  Logger.info('TEST', '═══════════════════════════════════════')

  -- Store in global results
  results = run_results
  results.last_run = reaper.time_precise()

  return run_results
end

--- Run all registered test suites
--- @return table results Combined results from all suites
function M.run_all()
  local combined = {
    total = 0,
    passed = 0,
    failed = 0,
    details = {},
  }

  Logger.info('TEST', '╔═══════════════════════════════════════╗')
  Logger.info('TEST', '║     RUNNING ALL TEST SUITES           ║')
  Logger.info('TEST', '╚═══════════════════════════════════════╝')

  for app_name, _ in pairs(test_suites) do
    local suite_results = M.run(app_name)
    combined.total = combined.total + suite_results.total
    combined.passed = combined.passed + suite_results.passed
    combined.failed = combined.failed + suite_results.failed
    combined.details[app_name] = suite_results.details
  end

  Logger.info('TEST', '╔═══════════════════════════════════════╗')
  Logger.info('TEST', '║     ALL SUITES COMPLETE               ║')
  Logger.info('TEST', '║     Total: %d/%d passed               ║', combined.passed, combined.total)
  Logger.info('TEST', '╚═══════════════════════════════════════╝')

  return combined
end

--- Get list of registered app names
--- @return table apps Array of app names
function M.get_registered_apps()
  local apps = {}
  for app_name in pairs(test_suites) do
    apps[#apps + 1] = app_name
  end
  table.sort(apps)
  return apps
end

--- Get last run results
--- @return table results Last run results
function M.get_results()
  return results
end

--- Clear all registered test suites
function M.clear()
  test_suites = {}
  results = {
    total = 0,
    passed = 0,
    failed = 0,
    skipped = 0,
    last_run = nil,
    details = {},
  }
end

-- ============================================
-- Assertion helpers for tests
-- ============================================

M.assert = {}

--- Assert that a value is truthy
function M.assert.truthy(value, message)
  if not value then
    error(message or string.format('Expected truthy, got %s', tostring(value)))
  end
end

--- Assert that a value is falsy
function M.assert.falsy(value, message)
  if value then
    error(message or string.format('Expected falsy, got %s', tostring(value)))
  end
end

--- Assert equality
function M.assert.equals(expected, actual, message)
  if expected ~= actual then
    error(message or string.format('Expected %s, got %s', tostring(expected), tostring(actual)))
  end
end

--- Assert not equal
function M.assert.not_equals(expected, actual, message)
  if expected == actual then
    error(message or string.format('Expected not %s', tostring(expected)))
  end
end

--- Assert nil
function M.assert.is_nil(value, message)
  if value ~= nil then
    error(message or string.format('Expected nil, got %s', tostring(value)))
  end
end

--- Assert not nil
function M.assert.not_nil(value, message)
  if value == nil then
    error(message or 'Expected non-nil value')
  end
end

--- Assert type
function M.assert.is_type(value, expected_type, message)
  local actual_type = type(value)
  if actual_type ~= expected_type then
    error(message or string.format('Expected type %s, got %s', expected_type, actual_type))
  end
end

--- Assert table contains key
function M.assert.has_key(tbl, key, message)
  if tbl[key] == nil then
    error(message or string.format('Table missing key: %s', tostring(key)))
  end
end

--- Assert table length
function M.assert.table_length(tbl, expected_length, message)
  local actual_length = #tbl
  if actual_length ~= expected_length then
    error(message or string.format('Expected table length %d, got %d', expected_length, actual_length))
  end
end

--- Assert function throws error
function M.assert.throws(fn, expected_pattern, message)
  local ok, err = pcall(fn)
  if ok then
    error(message or 'Expected function to throw error')
  end
  if expected_pattern and not string.find(tostring(err), expected_pattern) then
    error(message or string.format("Error '%s' did not match pattern '%s'", tostring(err), expected_pattern))
  end
end

--- Assert value is in range
function M.assert.in_range(value, min, max, message)
  if value < min or value > max then
    error(message or string.format('Expected %s to be in range [%s, %s]', tostring(value), tostring(min), tostring(max)))
  end
end

return M

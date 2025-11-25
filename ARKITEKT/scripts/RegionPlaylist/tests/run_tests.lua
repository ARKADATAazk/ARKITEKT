-- @noindex
-- RegionPlaylist/tests/run_tests.lua
-- Entry point for running RegionPlaylist tests

local TestRunner = require('arkitekt.debug.test_runner')

-- Load all test suites
require('scripts.RegionPlaylist.tests.domain_tests')

local M = {}

--- Run all RegionPlaylist tests
--- @return table results Test results
function M.run_all()
  local results = {}

  -- Run each registered suite
  results.region = TestRunner.run("RegionPlaylist.domains.region")
  results.playlist = TestRunner.run("RegionPlaylist.domains.playlist")
  results.ui_preferences = TestRunner.run("RegionPlaylist.domains.ui_preferences")
  results.dependency = TestRunner.run("RegionPlaylist.domains.dependency")

  -- Calculate totals
  local total = 0
  local passed = 0
  local failed = 0

  for _, suite_result in pairs(results) do
    total = total + suite_result.total
    passed = passed + suite_result.passed
    failed = failed + suite_result.failed
  end

  results.summary = {
    total = total,
    passed = passed,
    failed = failed,
  }

  return results
end

--- Run tests for a specific domain
--- @param domain_name string Domain name (region, playlist, ui_preferences, dependency)
--- @return table results Test results for that domain
function M.run_domain(domain_name)
  local suite_name = "RegionPlaylist.domains." .. domain_name
  return TestRunner.run(suite_name)
end

return M

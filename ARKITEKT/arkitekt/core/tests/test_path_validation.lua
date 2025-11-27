-- @noindex
-- arkitekt/core/tests/test_path_validation.lua
-- Security test suite for path validation
--
-- This test suite validates that path_validation.lua properly prevents:
-- - Path traversal attacks
-- - Command injection
-- - Malicious filenames
-- - Other security vulnerabilities

local PathValidation = require('arkitekt.core.path_validation')

local M = {}

-- Test result tracking
local tests_run = 0
local tests_passed = 0
local tests_failed = 0
local failures = {}

-- Helper to run a single test
local function test(name, fn)
  tests_run = tests_run + 1
  local ok, err = pcall(fn)
  if ok then
    tests_passed = tests_passed + 1
    print(string.format("✓ %s", name))
  else
    tests_failed = tests_failed + 1
    table.insert(failures, {name = name, error = tostring(err)})
    print(string.format("✗ %s: %s", name, tostring(err)))
  end
end

-- Assertion helpers
local function assert_true(condition, msg)
  if not condition then
    error(msg or "Expected true, got false")
  end
end

local function assert_false(condition, msg)
  if condition then
    error(msg or "Expected false, got true")
  end
end

local function assert_equal(actual, expected, msg)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", msg or "Assertion failed", tostring(expected), tostring(actual)))
  end
end

-- ============================================================================
-- TEST SUITE: is_safe_path()
-- ============================================================================

function M.test_safe_paths()
  print("\n=== Testing is_safe_path() ===\n")

  test("Valid absolute path (Unix)", function()
    local ok, err = PathValidation.is_safe_path("/home/user/documents/file.txt")
    assert_true(ok, "Valid Unix path should pass")
  end)

  test("Valid absolute path (Windows)", function()
    local ok, err = PathValidation.is_safe_path("C:\\Users\\Name\\Documents\\file.txt")
    assert_true(ok, "Valid Windows path should pass")
  end)

  test("Valid relative path", function()
    local ok, err = PathValidation.is_safe_path("folder/subfolder/file.txt")
    assert_true(ok, "Valid relative path should pass")
  end)

  test("Valid path with spaces", function()
    local ok, err = PathValidation.is_safe_path("My Documents/My File.txt")
    assert_true(ok, "Path with spaces should pass")
  end)

  test("Valid path with dashes and underscores", function()
    local ok, err = PathValidation.is_safe_path("my-folder/my_file.txt")
    assert_true(ok, "Path with dashes and underscores should pass")
  end)

  test("Valid path with parentheses", function()
    local ok, err = PathValidation.is_safe_path("folder(1)/file(copy).txt")
    assert_true(ok, "Path with parentheses should pass")
  end)
end

function M.test_path_traversal_attacks()
  print("\n=== Testing Path Traversal Prevention ===\n")

  test("Block simple parent directory (..)", function()
    local ok, err = PathValidation.is_safe_path("../etc/passwd")
    assert_false(ok, "Path with .. should be blocked")
  end)

  test("Block complex path traversal", function()
    local ok, err = PathValidation.is_safe_path("/var/www/../../etc/shadow")
    assert_false(ok, "Complex traversal should be blocked")
  end)

  test("Block Windows path traversal", function()
    local ok, err = PathValidation.is_safe_path("..\\..\\Windows\\System32")
    assert_false(ok, "Windows traversal should be blocked")
  end)

  test("Block hidden traversal in middle", function()
    local ok, err = PathValidation.is_safe_path("/home/user/../root/secrets")
    assert_false(ok, "Hidden traversal should be blocked")
  end)
end

function M.test_command_injection()
  print("\n=== Testing Command Injection Prevention ===\n")

  test("Block semicolon command separator", function()
    local ok, err = PathValidation.is_safe_path("file.txt; rm -rf /")
    assert_false(ok, "Semicolon should be blocked")
  end)

  test("Block pipe character", function()
    local ok, err = PathValidation.is_safe_path("file.txt | cat /etc/passwd")
    assert_false(ok, "Pipe should be blocked")
  end)

  test("Block backticks", function()
    local ok, err = PathValidation.is_safe_path("file`whoami`.txt")
    assert_false(ok, "Backticks should be blocked")
  end)

  test("Block dollar sign (variable expansion)", function()
    local ok, err = PathValidation.is_safe_path("$HOME/file.txt")
    assert_false(ok, "Dollar sign should be blocked")
  end)

  test("Block ampersand (background execution)", function()
    local ok, err = PathValidation.is_safe_path("file.txt & curl evil.com")
    assert_false(ok, "Ampersand should be blocked")
  end)

  test("Block single quotes", function()
    local ok, err = PathValidation.is_safe_path("file'; DROP TABLE users--")
    assert_false(ok, "Single quote should be blocked")
  end)

  test("Block double quotes", function()
    local ok, err = PathValidation.is_safe_path('file"test')
    assert_false(ok, "Double quote should be blocked")
  end)

  test("Block angle brackets (redirection)", function()
    local ok, err = PathValidation.is_safe_path("file.txt > /dev/null")
    assert_false(ok, "Angle brackets should be blocked")
  end)
end

function M.test_empty_and_nil()
  print("\n=== Testing Empty and Nil Paths ===\n")

  test("Block nil path", function()
    local ok, err = PathValidation.is_safe_path(nil)
    assert_false(ok, "Nil path should be blocked")
  end)

  test("Block empty string", function()
    local ok, err = PathValidation.is_safe_path("")
    assert_false(ok, "Empty path should be blocked")
  end)
end

-- ============================================================================
-- TEST SUITE: is_safe_filename()
-- ============================================================================

function M.test_safe_filenames()
  print("\n=== Testing is_safe_filename() ===\n")

  test("Valid simple filename", function()
    local ok, err = PathValidation.is_safe_filename("document.txt")
    assert_true(ok, "Simple filename should pass")
  end)

  test("Valid filename with spaces", function()
    local ok, err = PathValidation.is_safe_filename("My Document.txt")
    assert_true(ok, "Filename with spaces should pass")
  end)

  test("Valid filename with numbers", function()
    local ok, err = PathValidation.is_safe_filename("file_2024_01.txt")
    assert_true(ok, "Filename with numbers should pass")
  end)

  test("Valid filename with parentheses", function()
    local ok, err = PathValidation.is_safe_filename("file(1).txt")
    assert_true(ok, "Filename with parentheses should pass")
  end)

  test("Block filename with path separator (slash)", function()
    local ok, err = PathValidation.is_safe_filename("folder/file.txt")
    assert_false(ok, "Filename with slash should be blocked")
  end)

  test("Block filename with path separator (backslash)", function()
    local ok, err = PathValidation.is_safe_filename("folder\\file.txt")
    assert_false(ok, "Filename with backslash should be blocked")
  end)

  test("Block filename with ..", function()
    local ok, err = PathValidation.is_safe_filename("..file.txt")
    assert_false(ok, "Filename with .. should be blocked")
  end)

  test("Block hidden file (starts with dot)", function()
    local ok, err = PathValidation.is_safe_filename(".hidden")
    assert_false(ok, "Hidden files should be blocked")
  end)
end

-- ============================================================================
-- TEST SUITE: sanitize_filename()
-- ============================================================================

function M.test_sanitize_filename()
  print("\n=== Testing sanitize_filename() ===\n")

  test("Remove path separators", function()
    local result = PathValidation.sanitize_filename("folder/file.txt")
    assert_equal(result, "folder_file.txt", "Slashes should be replaced with underscore")
  end)

  test("Remove shell metacharacters", function()
    local result = PathValidation.sanitize_filename("file;rm -rf.txt")
    assert_equal(result, "filerm -rf.txt", "Semicolons should be removed")
  end)

  test("Remove quotes", function()
    local result = PathValidation.sanitize_filename('file"test".txt')
    assert_equal(result, "filetest.txt", "Quotes should be removed")
  end)

  test("Replace directory traversal", function()
    local result = PathValidation.sanitize_filename("..secret")
    assert_equal(result, "__secret", ".. should be replaced")
  end)

  test("Trim leading and trailing dots/spaces", function()
    local result = PathValidation.sanitize_filename("  .file.txt.  ")
    assert_equal(result, "file.txt", "Leading/trailing dots and spaces should be trimmed")
  end)

  test("Handle empty result", function()
    local result = PathValidation.sanitize_filename(";;;")
    assert_equal(result, "unnamed", "Empty result should default to 'unnamed'")
  end)
end

-- ============================================================================
-- TEST SUITE: check_suspicious_patterns()
-- ============================================================================

function M.test_suspicious_patterns()
  print("\n=== Testing check_suspicious_patterns() ===\n")

  test("Detect null byte", function()
    local suspicious, reason = PathValidation.check_suspicious_patterns("file\0.txt")
    assert_true(suspicious, "Null byte should be detected")
  end)

  test("Detect excessive separators", function()
    local suspicious, reason = PathValidation.check_suspicious_patterns("folder///file.txt")
    assert_true(suspicious, "Excessive separators should be detected")
  end)

  test("Detect percent encoding", function()
    local suspicious, reason = PathValidation.check_suspicious_patterns("file%20name.txt")
    assert_true(suspicious, "Percent encoding should be detected")
  end)

  test("Normal path is not suspicious", function()
    local suspicious, reason = PathValidation.check_suspicious_patterns("/home/user/file.txt")
    assert_false(suspicious, "Normal path should not be suspicious")
  end)
end

-- ============================================================================
-- TEST SUITE: validate_and_normalize()
-- ============================================================================

function M.test_validate_and_normalize()
  print("\n=== Testing validate_and_normalize() ===\n")

  test("Normalize valid path", function()
    local ok, result = PathValidation.validate_and_normalize("folder/subfolder/file.txt")
    assert_true(ok, "Valid path should normalize successfully")
  end)

  test("Reject invalid path", function()
    local ok, err = PathValidation.validate_and_normalize("../etc/passwd")
    assert_false(ok, "Invalid path should be rejected")
  end)

  test("Allow empty with option", function()
    local ok, result = PathValidation.validate_and_normalize("", {allow_empty = true})
    assert_true(ok, "Empty should be allowed with option")
    assert_equal(result, "", "Result should be empty string")
  end)

  test("Reject empty without option", function()
    local ok, err = PathValidation.validate_and_normalize("")
    assert_false(ok, "Empty should be rejected without option")
  end)
end

-- ============================================================================
-- RUN ALL TESTS
-- ============================================================================

function M.run_all()
  print("\n" .. string.rep("=", 70))
  print("ARKITEKT Path Validation Security Test Suite")
  print(string.rep("=", 70))

  M.test_safe_paths()
  M.test_path_traversal_attacks()
  M.test_command_injection()
  M.test_empty_and_nil()
  M.test_safe_filenames()
  M.test_sanitize_filename()
  M.test_suspicious_patterns()
  M.test_validate_and_normalize()

  print("\n" .. string.rep("=", 70))
  print(string.format("RESULTS: %d tests run, %d passed, %d failed",
    tests_run, tests_passed, tests_failed))
  print(string.rep("=", 70))

  if tests_failed > 0 then
    print("\nFAILURES:")
    for i, failure in ipairs(failures) do
      print(string.format("%d. %s", i, failure.name))
      print(string.format("   %s", failure.error))
    end
  else
    print("\n✓ ALL TESTS PASSED!")
  end

  print("")

  return tests_failed == 0
end

-- Auto-run tests if executed directly
if not ... then
  M.run_all()
end

return M

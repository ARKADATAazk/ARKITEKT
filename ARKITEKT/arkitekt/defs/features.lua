-- @noindex
-- arkitekt/defs/features.lua
-- Centralized feature flags for framework and scripts
-- Single source of truth for toggleable features, experiments, and platform-specific behavior

local M = {}

-- ============================================================================
-- FRAMEWORK FEATURES
-- ============================================================================

-- Profiler: Performance profiling window
-- When enabled, shows frame timing and performance metrics
M.PROFILER_ENABLED = false

-- Theme synchronization: Auto-sync with REAPER theme changes
M.THEME_SYNC_ENABLED = true

-- ============================================================================
-- EXPERIMENTAL FEATURES
-- ============================================================================

-- Experimental widgets: Enable unstable/WIP widgets
M.EXPERIMENTAL_WIDGETS = false

-- Advanced logging: Verbose debug logging for development
M.VERBOSE_LOGGING = false

-- ============================================================================
-- PLATFORM-SPECIFIC FLAGS
-- ============================================================================

-- Detect OS at module load time (safe - no side effects)
local os_string = reaper.GetOS()

-- macOS-specific workarounds and behavior adjustments
M.IS_OSX = os_string:match("OSX") ~= nil

-- Windows-specific features (e.g., console output)
M.IS_WINDOWS = os_string:match("Win") ~= nil

-- Linux-specific features
M.IS_LINUX = not M.IS_OSX and not M.IS_WINDOWS

-- ============================================================================
-- DEPRECATION FLAGS
-- ============================================================================
-- Flags for backwards compatibility - remove before 1.0

-- Support for legacy configuration file formats
-- TODO: Remove in 1.0 after migration period
M.LEGACY_CONFIG_SUPPORT = true

-- Support for old theme format (pre theme_manager refactor)
-- TODO: Remove in 1.0
M.LEGACY_THEME_SUPPORT = true

-- ============================================================================
-- NOTES
-- ============================================================================
-- Feature flags philosophy:
-- - Use for experimental features, platform-specific behavior, or deprecation tracking
-- - NOT for app-specific settings (those belong in app/defs/)
-- - NOT for user preferences (those belong in Settings system)
-- - Keep this file flat and easy to scan
-- - Document removal timeline for deprecation flags

return M

-- @noindex
-- arkitekt/defs/features.lua
-- Centralized feature flags for framework
-- Single source of truth for toggleable features

local M = {}

-- ============================================================================
-- FRAMEWORK FEATURES
-- ============================================================================

-- Profiler: Performance profiling window
-- When enabled, shows frame timing and performance metrics
M.PROFILER_ENABLED = false

-- ============================================================================
-- NOTES
-- ============================================================================
-- Feature flags philosophy:
-- - Use for experimental features or framework-wide toggles
-- - NOT for app-specific settings (those belong in app/defs/)
-- - NOT for user preferences (those belong in Settings system)
-- - Only add flags that are actually checked in code
-- - Remove flags that become permanent features

return M

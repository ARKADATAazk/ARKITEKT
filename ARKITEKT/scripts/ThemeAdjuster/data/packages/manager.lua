-- @noindex
-- ThemeAdjuster/data/packages/manager.lua
-- Package management facade - re-exports from scanner, resolver, applier

local Scanner = require('ThemeAdjuster.data.packages.scanner')
local Resolver = require('ThemeAdjuster.data.packages.resolver')
local Applier = require('ThemeAdjuster.data.packages.applier')

local M = {}

-- ============================================================================
-- SCANNER (scanning, filtering)
-- ============================================================================

M.scan_packages = Scanner.scan_packages
M.filter_packages = Scanner.filter_packages

-- ============================================================================
-- RESOLVER (conflict detection, resolution, shadowing)
-- ============================================================================

M.detect_conflicts = Resolver.detect_conflicts
M.resolve_packages = Resolver.resolve_packages
M.detect_shadowed_keys = Resolver.detect_shadowed_keys

-- ============================================================================
-- APPLIER (apply, backup, revert, ZIP support, state persistence)
-- ============================================================================

-- Folder theme apply/revert
M.apply_to_theme = Applier.apply_to_theme
M.revert_last_apply = Applier.revert_last_apply
M.clear_backups = Applier.clear_backups
M.get_backup_status = Applier.get_backup_status

-- ZIP theme support
M.check_reassembled_exists = Applier.check_reassembled_exists
M.apply_to_zip_theme = Applier.apply_to_zip_theme
M.load_zip_theme = Applier.load_zip_theme

-- Reassembled folder output
M.apply_to_reassembled_folder = Applier.apply_to_reassembled_folder
M.get_reassembled_info = Applier.get_reassembled_info
M.get_default_reassembled_path = Applier.get_default_reassembled_path

-- State persistence
M.get_state_path = Applier.get_state_path
M.save_state = Applier.save_state
M.load_state = Applier.load_state
M.delete_state = Applier.delete_state

return M

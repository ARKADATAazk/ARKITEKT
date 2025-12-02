-- @noindex
-- RegionPlaylist/app/config.lua
-- Pure re-exports of constants from defs/
--
-- For factory functions (get_active_container_config, get_pool_container_config, etc.),
-- see app/config_factory.lua

local Constants = require('RegionPlaylist.defs.constants')
local Defaults = require('RegionPlaylist.defs.defaults')

local M = {}

-- Constants re-exports
M.ANIMATION = Constants.ANIMATION
M.ACCENT = Constants.ACCENT
M.DIM = Constants.DIM
M.SEPARATOR = Constants.SEPARATOR
M.TRANSPORT_BUTTONS = Constants.TRANSPORT_BUTTONS
M.TRANSPORT_LAYOUT = Constants.TRANSPORT_LAYOUT
M.REMIX_ICONS = Constants.REMIX_ICONS

-- Quantize config (mixed from defaults + constants)
M.QUANTIZE = {
  default_mode = Defaults.QUANTIZE.default_mode,
  default_lookahead = Defaults.QUANTIZE.default_lookahead,
  min_lookahead = Defaults.QUANTIZE.min_lookahead,
  max_lookahead = Defaults.QUANTIZE.max_lookahead,
  options = Constants.QUANTIZE_OPTIONS,
}

-- Transport defaults re-export
M.TRANSPORT = Defaults.TRANSPORT

return M

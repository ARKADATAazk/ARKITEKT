-- @noindex
-- ItemPicker module loader

local M = {}

-- Module exports
M.core = {}
M.core.config = require('ItemPicker.core.config')
M.core.app_state = require('ItemPicker.core.app_state')
M.core.controller = require('ItemPicker.core.controller')

M.domain = {}
M.domain.visualization = require('ItemPicker.domain.visualization')
M.domain.cache_manager = require('ItemPicker.domain.cache_manager')
M.domain.reaper_interface = require('ItemPicker.domain.reaper_interface')
M.domain.job_queue = require('ItemPicker.domain.job_queue')
M.domain.utils = require('ItemPicker.domain.utils')
M.domain.disabled_items = require('ItemPicker.domain.disabled_items')

M.ui = {}
M.ui.gui = require('ItemPicker.ui.gui')

M.storage = {}
M.storage.persistence = require('ItemPicker.storage.persistence')

return M

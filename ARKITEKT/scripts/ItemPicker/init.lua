-- @noindex
-- ItemPicker module loader

local M = {}

-- Core modules
M.core = {}
M.core.config = require('ItemPicker.core.config')
M.core.app_state = require('ItemPicker.core.app_state')
M.core.controller = require('ItemPicker.core.controller')

-- Data layer
M.data = {}
M.data.persistence = require('ItemPicker.data.persistence')
M.data.reaper_api = require('ItemPicker.data.reaper_api')
M.data.disk_cache = require('ItemPicker.data.disk_cache')
M.data.job_queue = require('ItemPicker.data.job_queue')
M.data.loaders = {}
M.data.loaders.incremental_loader = require('ItemPicker.data.loaders.incremental_loader')

-- Services
M.services = {}
M.services.visualization = require('ItemPicker.services.visualization')
M.services.utils = require('ItemPicker.services.utils')

-- UI modules
M.ui = {}
M.ui.main_window = require('ItemPicker.ui.main_window')

return M

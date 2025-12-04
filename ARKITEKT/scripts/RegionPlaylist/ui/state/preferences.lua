-- @noindex
-- RegionPlaylist/ui/state/ui_preferences.lua
-- Manages UI preferences (search, sort, layout, pool mode, separators)

local Logger = require('arkitekt.debug.logger')

local M = {}

-- Set to true for verbose domain logging
local DEBUG_DOMAIN = false

--- Create a new UI preferences domain
--- @param constants table Constants table with LAYOUT_MODES, POOL_MODES, SORT_DIRECTIONS
--- @param settings table Settings instance for persistence
--- @return table domain The UI preferences domain instance
function M.new(constants, settings)
  local domain = {
    search_filter = '',
    sort_mode = nil,
    sort_direction = constants.SORT_DIRECTIONS.ASC,
    layout_mode = constants.LAYOUT_MODES.HORIZONTAL,
    pool_mode = constants.POOL_MODES.REGIONS,
    separator_position_horizontal = nil,
    separator_position_vertical = nil,
    settings = settings,
    constants = constants,
  }

  if DEBUG_DOMAIN then
    Logger.debug('UI_PREFERENCES', 'Domain initialized')
  end

  --- Load preferences from settings
  function domain:load_from_settings()
    if not self.settings then
      if DEBUG_DOMAIN then
        Logger.debug('UI_PREFERENCES', 'No settings instance, using defaults')
      end
      return
    end

    self.search_filter = self.settings:get('pool_search') or ''
    self.sort_mode = self.settings:get('pool_sort')
    self.sort_direction = self.settings:get('pool_sort_direction') or 'asc'
    self.layout_mode = self.settings:get('layout_mode') or 'horizontal'
    self.pool_mode = self.settings:get('pool_mode') or 'regions'

    if DEBUG_DOMAIN then
      Logger.debug('UI_PREFERENCES', "Loaded: search='%s', sort=%s:%s, layout=%s, pool=%s",
        self.search_filter,
        tostring(self.sort_mode),
        self.sort_direction,
        self.layout_mode,
        self.pool_mode
      )
    end
  end

  --- Save preferences to settings
  function domain:save_to_settings()
    if not self.settings then return end

    self.settings:set('pool_search', self.search_filter)
    self.settings:set('pool_sort', self.sort_mode)
    self.settings:set('pool_sort_direction', self.sort_direction)
    self.settings:set('layout_mode', self.layout_mode)
    self.settings:set('pool_mode', self.pool_mode)

    if DEBUG_DOMAIN then
      Logger.debug('UI_PREFERENCES', "Saved: search='%s', sort=%s:%s, layout=%s, pool=%s",
        self.search_filter,
        tostring(self.sort_mode),
        self.sort_direction,
        self.layout_mode,
        self.pool_mode
      )
    end
  end

  -- Search filter accessors
  function domain:get_search_filter()
    return self.search_filter
  end

  function domain:set_search_filter(text)
    self.search_filter = text
    if DEBUG_DOMAIN then
      Logger.debug('UI_PREFERENCES', "Search filter: '%s'", text)
    end
  end

  -- Sort mode accessors
  function domain:get_sort_mode()
    return self.sort_mode
  end

  function domain:set_sort_mode(mode)
    self.sort_mode = mode
    if DEBUG_DOMAIN then
      Logger.debug('UI_PREFERENCES', 'Sort mode: %s', tostring(mode))
    end
  end

  -- Sort direction accessors
  function domain:get_sort_direction()
    return self.sort_direction
  end

  function domain:set_sort_direction(direction)
    -- Validate sort direction
    if direction ~= self.constants.SORT_DIRECTIONS.ASC and
       direction ~= self.constants.SORT_DIRECTIONS.DESC then
      error(string.format("Invalid sort_direction: %s (expected 'asc' or 'desc')", tostring(direction)))
    end
    self.sort_direction = direction
    if DEBUG_DOMAIN then
      Logger.debug('UI_PREFERENCES', 'Sort direction: %s', direction)
    end
  end

  -- Layout mode accessors
  function domain:get_layout_mode()
    return self.layout_mode
  end

  function domain:set_layout_mode(mode)
    -- Validate layout mode
    if mode ~= self.constants.LAYOUT_MODES.HORIZONTAL and
       mode ~= self.constants.LAYOUT_MODES.VERTICAL then
      error(string.format("Invalid layout_mode: %s (expected 'horizontal' or 'vertical')", tostring(mode)))
    end
    self.layout_mode = mode
    if DEBUG_DOMAIN then
      Logger.debug('UI_PREFERENCES', 'Layout mode: %s', mode)
    end
  end

  -- Pool mode accessors
  function domain:get_pool_mode()
    return self.pool_mode
  end

  function domain:set_pool_mode(mode)
    -- Validate pool mode
    if mode ~= self.constants.POOL_MODES.REGIONS and
       mode ~= self.constants.POOL_MODES.PLAYLISTS and
       mode ~= self.constants.POOL_MODES.MIXED then
      error(string.format("Invalid pool_mode: %s (expected 'regions', 'playlists', or 'mixed')", tostring(mode)))
    end
    self.pool_mode = mode
    if DEBUG_DOMAIN then
      Logger.debug('UI_PREFERENCES', 'Pool mode: %s', mode)
    end
  end

  -- Separator position accessors
  function domain:get_separator_position_horizontal()
    return self.separator_position_horizontal
  end

  function domain:set_separator_position_horizontal(pos)
    self.separator_position_horizontal = pos
  end

  function domain:get_separator_position_vertical()
    return self.separator_position_vertical
  end

  function domain:set_separator_position_vertical(pos)
    self.separator_position_vertical = pos
  end

  return domain
end

return M

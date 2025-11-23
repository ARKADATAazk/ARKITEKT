-- @noindex
-- RegionPlaylist/core/config.lua
-- Config builders using defs (factory functions for dynamic configs)

local Colors = require('arkitekt.core.colors')
local TransportIcons = require('RegionPlaylist.ui.views.transport.transport_icons')
local Constants = require('RegionPlaylist.defs.constants')
local Defaults = require('RegionPlaylist.defs.defaults')
local Strings = require('RegionPlaylist.defs.strings')

local M = {}
local hexrgb = Colors.hexrgb

-- Re-export constants for backward compatibility during migration
M.ANIMATION = Constants.ANIMATION
M.ACCENT = Constants.ACCENT
M.DIM = Constants.DIM
M.SEPARATOR = Constants.SEPARATOR
M.TRANSPORT_BUTTONS = Constants.TRANSPORT_BUTTONS
M.TRANSPORT_LAYOUT = Constants.TRANSPORT_LAYOUT
M.REMIX_ICONS = Constants.REMIX_ICONS
M.QUANTIZE = {
  default_mode = Defaults.QUANTIZE.default_mode,
  default_lookahead = Defaults.QUANTIZE.default_lookahead,
  min_lookahead = Defaults.QUANTIZE.min_lookahead,
  max_lookahead = Defaults.QUANTIZE.max_lookahead,
  options = Constants.QUANTIZE_OPTIONS,
}

-- Function to create viewmode corner button config (needs state module reference)
local function create_viewmode_button(state_module)
  return {
    custom_draw = function(ctx, dl, x, y, width, height, is_hovered, is_active, color)
      local current_mode = state_module.get_layout_mode()
      if current_mode == 'horizontal' then
        TransportIcons.draw_timeline(dl, x, y, width, height, color)
      else
        TransportIcons.draw_list(dl, x, y, width, height, color)
      end
    end,
    tooltip_fn = function()
      local current_mode = state_module.get_layout_mode()
      return current_mode == 'horizontal' and Strings.VIEW_MODES.switch_to_list or Strings.VIEW_MODES.switch_to_timeline
    end,
    on_click = function()
      local new_mode = (state_module.get_layout_mode() == 'horizontal') and 'vertical' or 'horizontal'
      state_module.set_layout_mode(new_mode)
      state_module.persist_ui_prefs()
    end,
  }
end

-- Transport dimensions and styling
M.TRANSPORT = {
  height = Defaults.TRANSPORT.height,
  padding = Defaults.TRANSPORT.padding,
  spacing = Defaults.TRANSPORT.spacing,
  panel_bg_color = Defaults.TRANSPORT.panel_bg_color,

  corner_buttons = {
    size = Defaults.TRANSPORT.corner_buttons.size,
    margin = Defaults.TRANSPORT.corner_buttons.margin,
    inner_rounding = Defaults.TRANSPORT.corner_buttons.inner_rounding,
    bottom_left = nil,  -- Set via set_viewmode_button()
    bottom_right = {
      custom_draw = function(ctx, dl, x, y, width, height, is_hovered, is_active, color)
        TransportIcons.draw_tool(dl, x, y, width, height, color)
      end,
      tooltip = Strings.TRANSPORT.settings,
      on_click = function()
        reaper.ShowConsoleMsg("Settings button clicked (coming soon)\n")
      end,
    },
  },

  display = Defaults.TRANSPORT.display,
  fx = Defaults.TRANSPORT.fx,
  background_pattern = Defaults.TRANSPORT.background_pattern,
  jump = Defaults.TRANSPORT.jump,
}

-- Active container: tabs only
function M.get_active_container_config(callbacks)
  local tab_config = {
    spacing = Defaults.CONTAINER.active.tab.spacing,
    min_width = Defaults.CONTAINER.active.tab.min_width,
    max_width = Defaults.CONTAINER.active.tab.max_width,
    padding_x = Defaults.CONTAINER.active.tab.padding_x,
    chip_radius = Defaults.CONTAINER.active.tab.chip_radius,
  }

  for key, value in pairs(callbacks or {}) do
    if type(key) == "string" and key:match("^on_") and type(value) == "function" then
      tab_config[key] = value
    end
  end

  return {
    header = {
      enabled = true,
      height = Defaults.CONTAINER.active.header_height,
      elements = {
        {
          id = "tabs",
          type = "tab_strip",
          flex = 1,
          spacing_before = 0,
          config = tab_config,
        },
      },
    },
    corner_buttons = {
      size = Defaults.CONTAINER.active.corner_button_size,
      margin = Defaults.CONTAINER.active.corner_button_margin,
      inner_rounding = Defaults.CONTAINER.active.corner_button_inner_rounding,
      bottom_left = {
        custom_draw = function(ctx, dl, x, y, width, height, is_hovered, is_active, color)
          TransportIcons.draw_bolt(dl, x, y, width, height, color)
        end,
        tooltip = Strings.POOL.actions_tooltip,
        on_click = callbacks.on_actions_button_click,
      },
    },
    corner_buttons_always_visible = true,
  }
end

-- Pool container: mode toggle, search, sort
function M.get_pool_container_config(callbacks)
  return {
    header = {
      enabled = true,
      height = Defaults.CONTAINER.pool.header_height,
      elements = {
        {
          id = "mode_toggle",
          type = "button",
          width = Defaults.CONTAINER.pool.mode_toggle_width,
          spacing_before = 0,
          config = {
            label = Strings.POOL.mode_toggle_label,
            on_click = callbacks.on_mode_toggle,
            on_right_click = callbacks.on_mode_toggle_right,
          },
        },
        {
          id = "spacer1",
          type = "separator",
          flex = 1,
          spacing_before = 0,
          config = { show_line = false },
        },
        {
          id = "search",
          type = "search_field",
          width = Defaults.CONTAINER.pool.search_width,
          spacing_before = 0,
          config = {
            placeholder = Strings.POOL.search_placeholder,
            on_change = callbacks.on_search_changed,
          },
        },
        {
          id = "sort",
          type = "dropdown_field",
          width = Defaults.CONTAINER.pool.sort_width,
          spacing_before = 0,
          config = {
            tooltip = Strings.POOL.sort_tooltip,
            tooltip_delay = 0.5,
            enable_sort = true,
            options = {
              { value = nil, label = Strings.POOL.sort_options.no_sort },
              { value = "color", label = Strings.POOL.sort_options.color },
              { value = "index", label = Strings.POOL.sort_options.index },
              { value = "alpha", label = Strings.POOL.sort_options.alpha },
              { value = "length", label = Strings.POOL.sort_options.length },
            },
            enable_mousewheel = true,
            on_change = callbacks.on_sort_changed,
            on_direction_change = callbacks.on_sort_direction_changed,
          },
        },
      },
    },
    corner_buttons = {
      size = Defaults.CONTAINER.pool.corner_button_size,
      margin = Defaults.CONTAINER.pool.corner_button_margin,
      inner_rounding = Defaults.CONTAINER.pool.corner_button_inner_rounding,
      bottom_left = {
        custom_draw = function(ctx, dl, x, y, width, height, is_hovered, is_active, color)
          TransportIcons.draw_bolt(dl, x, y, width, height, color)
        end,
        tooltip = Strings.POOL.actions_tooltip,
        on_click = function()
          if callbacks.on_actions_click then
            callbacks.on_actions_click()
          end
        end,
      },
    },
    corner_buttons_always_visible = true,
  }
end

-- Region tiles structural config
function M.get_region_tiles_config(layout_mode)
  local tiles = Defaults.REGION_TILES
  return {
    layout_mode = layout_mode or 'horizontal',

    tile_config = tiles.tile,
    container = tiles.container,
    responsive_config = tiles.responsive,

    hover_config = {
      animation_speed_hover = tiles.hover.animation_speed,
      hover_brightness_factor = tiles.hover.brightness_factor,
      hover_border_lerp = tiles.hover.border_lerp,
      base_fill_desaturation = tiles.hover.base_fill_desaturation,
      base_fill_brightness = tiles.hover.base_fill_brightness,
      base_fill_alpha = tiles.hover.base_fill_alpha,
    },

    dim_config = tiles.dim,
    drop_config = tiles.drop,
    ghost_config = tiles.ghost,
    wheel_config = tiles.wheel,
  }
end

-- Helper to set viewmode button dynamically
function M.set_viewmode_button(state_module)
  M.TRANSPORT.corner_buttons.bottom_left = create_viewmode_button(state_module)
end

return M

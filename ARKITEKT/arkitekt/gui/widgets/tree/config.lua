-- @noindex
-- arkitekt/gui/widgets/tree/config.lua
-- Shared configuration defaults for Tree and TreeTable widgets

local M = {}

-- ============================================================================
-- DEFAULT CONFIGURATION
-- ============================================================================

M.DEFAULTS = {
  -- Dimensions
  item_height = 17,
  indent_width = 22,
  arrow_size = 5,
  arrow_margin = 6,
  icon_width = 13,
  icon_margin = 4,
  header_height = 22,  -- TreeTable only

  -- Padding
  padding_left = 4,
  padding_top = 4,
  padding_right = 4,
  padding_bottom = 4,
  item_padding_left = 2,
  item_padding_right = 4,

  -- Visual features
  show_tree_lines = true,
  tree_line_style = 'dotted',  -- 'solid' or 'dotted'
  tree_line_thickness = 1,
  tree_line_dot_spacing = 2,
  show_alternating_bg = false,
  virtual_scroll = true,

  -- Colors (RRGGBBAA)
  colors = {
    bg = 0x1A1A1AFF,
    bg_hover = 0x2E2E2EFF,
    bg_selected = 0x393939FF,
    bg_selected_hover = 0x3E3E3EFF,
    bg_alternate = 0x1C1C1CFF,
    bg_disabled = 0x0F0F0FFF,

    text_normal = 0xCCCCCCFF,
    text_hover = 0xFFFFFFFF,
    text_disabled = 0x666666FF,

    arrow = 0xB0B0B0FF,
    icon = 0x888888FF,
    icon_open = 0x9A9A9AFF,

    tree_line = 0x505050FF,
    border = 0x000000DD,
    focus_ring = 0x6A9EFFAA,

    -- TreeTable header
    header_bg = 0x2A2A2AFF,
    header_text = 0xDDDDDDFF,
    header_border = 0x404040FF,
    resize_handle = 0x606060FF,

    -- Drag & drop
    drop_indicator = 0x4A9EFFFF,
    drag_overlay = 0xFFFFFF18,
    drag_border = 0xFFFFFF40,
  },

  -- Drag & drop
  drag_threshold = 5,  -- pixels before drag starts
  auto_scroll_zone = 40,  -- pixels from edge to trigger scroll
  auto_scroll_speed = 8,  -- pixels per frame

  -- Type-to-search
  type_search_timeout = 1.0,  -- seconds before clearing buffer

  -- State cleanup
  stale_threshold = 30.0,  -- seconds before state cleanup
  cleanup_interval = 60.0,
}

-- ============================================================================
-- CONFIGURATION MERGER
-- ============================================================================

--- Merge user options with defaults
--- @param opts table|nil User options
--- @return table Merged configuration
function M.resolve(opts)
  opts = opts or {}
  local cfg = {}

  -- Copy defaults
  for k, v in pairs(M.DEFAULTS) do
    if type(v) == 'table' then
      cfg[k] = {}
      for k2, v2 in pairs(v) do
        cfg[k][k2] = v2
      end
    else
      cfg[k] = v
    end
  end

  -- Override with user options (shallow merge for non-table values)
  for k, v in pairs(opts) do
    if k ~= 'colors' then
      cfg[k] = v
    end
  end

  -- Merge colors separately
  if opts.colors then
    for k, v in pairs(opts.colors) do
      cfg.colors[k] = v
    end
  end

  return cfg
end

return M

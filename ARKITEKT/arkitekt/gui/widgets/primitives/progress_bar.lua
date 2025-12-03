-- @noindex
-- arkitekt/gui/widgets/primitives/progress_bar.lua
-- Progress bar widget with theming support
-- Uses unified opts-based API

local ImGui = require('arkitekt.core.imgui')
local Theme = require('arkitekt.core.theme')
local Colors = require('arkitekt.core.colors')
local Base = require('arkitekt.gui.widgets.base')

local M = {}

-- ============================================================================
-- DEFAULTS
-- ============================================================================

local DEFAULTS = {
  -- Identity
  id = 'progress_bar',

  -- Position (nil = use cursor)
  x = nil,
  y = nil,

  -- Size
  width = 200,
  height = 4,

  -- State
  progress = 0.0,      -- 0.0 to 1.0

  -- Style
  rounding = 0,

  -- Colors (nil = use Theme defaults)
  bg_color = nil,              -- nil = Theme.COLORS.BG_BASE
  progress_color = nil,        -- nil = Theme.COLORS.ACCENT_PRIMARY
  border_color = nil,          -- nil = Theme.COLORS.BORDER_INNER

  -- Text overlay
  show_text = false,           -- Show percentage text
  text_format = '%d%%',        -- Format string for text (receives progress * 100)
  text_color = nil,            -- nil = Theme.COLORS.TEXT_NORMAL

  -- Cursor control
  advance = 'vertical',

  -- Draw list
  draw_list = nil,
}

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Draw a progress bar widget
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result { width, height, progress }
function M.Draw(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)

  -- Get position and draw list
  local x, y = Base.get_position(ctx, opts)
  local dl = Base.get_draw_list(ctx, opts)

  -- Get parameters
  local width = opts.width or 200
  local height = opts.height or 4
  local progress = math.max(0, math.min(1, opts.progress or 0))
  local rounding = opts.rounding or 0

  -- Get colors
  local bg_color = opts.bg_color or Theme.COLORS.BG_BASE
  local progress_color = opts.progress_color or Theme.COLORS.ACCENT_PRIMARY
  local border_color = opts.border_color or Theme.COLORS.BORDER_INNER
  local text_color = opts.text_color or Theme.COLORS.TEXT_NORMAL

  -- Round positions
  x = (x + 0.5) // 1
  y = (y + 0.5) // 1
  local x2 = (x + width + 0.5) // 1
  local y2 = (y + height + 0.5) // 1

  -- Draw background
  ImGui.DrawList_AddRectFilled(dl, x, y, x2, y2, bg_color, rounding)

  -- Draw progress fill
  if progress > 0 then
    local progress_width = (width * progress + 0.5) // 1
    ImGui.DrawList_AddRectFilled(dl, x, y, x + progress_width, y2, progress_color, rounding)
  end

  -- Draw border
  if border_color then
    ImGui.DrawList_AddRect(dl, x, y, x2, y2, border_color, rounding, 0, 1)
  end

  -- Draw text overlay if enabled
  if opts.show_text then
    local text = string.format(opts.text_format or '%d%%', progress * 100)
    local text_width, text_height = ImGui.CalcTextSize(ctx, text)
    local text_x = (x + (width - text_width) / 2 + 0.5) // 1
    local text_y = (y + (height - text_height) / 2 + 0.5) // 1

    -- Only draw text if there's enough vertical space
    if height >= text_height then
      ImGui.DrawList_AddText(dl, text_x, text_y, text_color, text)
    end
  end

  -- Advance cursor
  Base.advance_cursor(ctx, x, y, width, height, opts.advance)

  -- Return standardized result
  return Base.create_result({
    width = width,
    height = height,
    progress = progress,
  })
end


-- ============================================================================
-- MODULE EXPORT (Callable)
-- ============================================================================

-- Make module callable
return setmetatable(M, {
  __call = function(_, ctx, opts)
    return M.Draw(ctx, opts)
  end
})

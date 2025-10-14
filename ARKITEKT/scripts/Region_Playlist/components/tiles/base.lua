local Config = require('Region_Playlist.components.tiles.config')

local M = {}

local bit = bit32
local Colors = Config.COLORS or {}
local Layout = Config.LAYOUT or {}
local Thresholds = Config.RESPONSIVE_THRESHOLDS or {}
local Ellipsis = Config.TEXT_ELLIPSIS or '...'

local function apply_alpha(color, alpha)
  if not alpha then
    return color
  end

  if bit and color then
    local rgb = bit.band(color, 0x00FFFFFF)
    return bit.bor(bit.lshift(alpha, 24), rgb)
  end

  return color
end

local function normalize_rect(rect)
  if not rect then
    return nil
  end

  if rect.x then
    local w = rect.w or rect.width or 0
    local h = rect.h or rect.height or 0
    return rect.x, rect.y, rect.x + w, rect.y + h
  end

  return rect[1], rect[2], rect[3], rect[4]
end

local function resolve_background_color(base_color, state)
  local color = base_color or Colors.tile_background

  if state then
    if state.selected and Colors.tile_background_selected then
      color = Colors.tile_background_selected
    elseif state.hovered and Colors.tile_background_hover then
      color = Colors.tile_background_hover
    end

    if state.disabled and Colors.disabled_alpha then
      color = apply_alpha(color, Colors.disabled_alpha)
    end
  end

  return color
end

local function measure_text(ctx, text)
  if not ctx or not text then
    return nil
  end

  if ctx.CalcTextSize then
    local a, b = ctx:CalcTextSize(text)
    if type(a) == 'number' and type(b) == 'number' then
      return a, b
    elseif type(a) == 'table' then
      return a.x or a[1], a.y or a[2]
    end
  end

  if ctx.CalcTextSizeX then
    local width = ctx:CalcTextSizeX(text)
    return width, nil
  end

  if ctx.CalcTextSize2 and type(ctx.CalcTextSize2) == 'function' then
    local size = ctx:CalcTextSize2(text)
    if type(size) == 'table' then
      return size.x or size[1], size.y or size[2]
    end
  end

  return nil
end

function M.draw_tile_background(dl, rect, color, state)
  local x1, y1, x2, y2 = normalize_rect(rect)
  if not x1 or not y1 or not x2 or not y2 then
    return {
      rect = nil,
      color = nil,
      commands = {},
    }
  end

  local fill = resolve_background_color(color, state)
  local commands = {}
  if dl then
    commands[1] = {
      target = dl,
      method = 'AddRectFilled',
      args = { x1, y1, x2, y2, fill },
    }
  end

  return {
    color = fill,
    rect = { x1 = x1, y1 = y1, x2 = x2, y2 = y2 },
    commands = commands,
  }
end

local function truncate_text_to_width(ctx, text, max_width)
  if not text or not max_width then
    return text, false
  end

  local width = measure_text(ctx, text)
  if not width or width <= max_width then
    return text, false
  end

  local truncated = text
  for i = #text - 1, 1, -1 do
    truncated = text:sub(1, i) .. Ellipsis
    local w = measure_text(ctx, truncated)
    if not w or w <= max_width then
      return truncated, true
    end
  end

  return Ellipsis, true
end

function M.draw_text_with_truncation(ctx, dl, text, bounds)
  if not text or text == '' then
    return {
      rendered_text = '',
      truncated = false,
      commands = {},
    }
  end

  local x1, y1, x2, y2 = normalize_rect(bounds)
  if not x1 or not y1 or not x2 or not y2 then
    return {
      rendered_text = text,
      truncated = false,
      commands = {},
    }
  end

  local pad_x = (Layout.text_padding and Layout.text_padding.x) or 0
  local pad_y = (Layout.text_padding and Layout.text_padding.y) or 0
  local max_width = math.max(0, (x2 - x1) - (pad_x * 2))
  local display_text, truncated = truncate_text_to_width(ctx, text, max_width)
  local text_color = Colors.text or 0xFFFFFFFF
  local commands = {}
  if dl then
    commands[1] = {
      target = dl,
      method = 'AddText',
      args = { x1 + pad_x, y1 + pad_y, text_color, display_text },
    }
  end

  return {
    rendered_text = display_text,
    truncated = truncated,
    commands = commands,
  }
end

function M.draw_repeat_badge(ctx, dl, rect, reps, enabled)
  if not rect or not reps or reps <= 1 then
    return {
      visible = false,
      commands = {},
    }
  end

  local x1, y1, x2, y2 = normalize_rect(rect)
  if not x1 or not y1 or not x2 or not y2 then
    return {
      visible = false,
      commands = {},
    }
  end

  local pad = Layout.badge_padding or {}
  local pad_x = pad.x or 0
  local pad_y = pad.y or 0
  local badge_height = math.max((Layout.badge_min_height or 0), (y2 - y1) - 2 * pad_y)
  local badge_width = math.max(Layout.badge_min_width or badge_height, badge_height)

  local badge_x2 = x2 - pad_x
  local badge_x1 = badge_x2 - badge_width
  local badge_y1 = y1 + pad_y
  local badge_y2 = badge_y1 + badge_height

  local bg_color = Colors.badge_bg
  if not enabled and Colors.repeat_muted_bg then
    bg_color = Colors.repeat_muted_bg
  elseif not enabled and Colors.disabled_alpha then
    bg_color = apply_alpha(bg_color, Colors.disabled_alpha)
  end

  local text_color = Colors.badge_text or Colors.text or 0xFFFFFFFF
  local label = string.format('x%d', reps)
  local text_width = measure_text(ctx, label)
  local text_x = badge_x1 + math.max(pad_x, 0)
  if text_width and badge_width > text_width then
    text_x = badge_x1 + (badge_width - text_width) * 0.5
  end
  local text_y = badge_y1 + math.max(pad_y, 0)
  local rounding = Layout.badge_corner_radius or 0
  local commands = {}
  if dl then
    local rect_args = { badge_x1, badge_y1, badge_x2, badge_y2, bg_color }
    if rounding > 0 then
      rect_args[#rect_args + 1] = rounding
    end
    commands[1] = {
      target = dl,
      method = 'AddRectFilled',
      args = rect_args,
    }
    commands[2] = {
      target = dl,
      method = 'AddText',
      args = { text_x, text_y, text_color, label },
    }
  end

  return {
    visible = true,
    rect = { x1 = badge_x1, y1 = badge_y1, x2 = badge_x2, y2 = badge_y2 },
    label = label,
    commands = commands,
  }
end

function M.calculate_responsive_elements(tile_height)
  local height = tonumber(tile_height) or 0
  return {
    show_text = height >= (Thresholds.text or 0),
    show_badge = height >= (Thresholds.badge or 0),
    show_length = height >= (Thresholds.length or 0),
  }
end

return M

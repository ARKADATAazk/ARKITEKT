local Base = require('Region_Playlist.components.tiles.base')
local Config = require('Region_Playlist.components.tiles.config')

local Colors = Config.COLORS or {}
local Layout = Config.LAYOUT or {}

local M = {}

M.DEFAULTS = {
  badge_margin = 6,
  text_margin_right = 6,
}

local function append_commands(into, chunk)
  if not chunk or not chunk.commands then
    return
  end

  for i = 1, #chunk.commands do
    into[#into + 1] = chunk.commands[i]
  end
end

local function ensure_rect(rect, fallback)
  if rect and rect.x1 then
    return rect
  end

  fallback = fallback or {}
  local x1 = fallback.x1 or fallback[1] or fallback.x or 0
  local y1 = fallback.y1 or fallback[2] or fallback.y or 0
  local x2 = fallback.x2 or fallback[3]
  local y2 = fallback.y2 or fallback[4]

  if not x2 and fallback.w then
    x2 = x1 + fallback.w
  elseif not x2 then
    x2 = x1
  end

  if not y2 and fallback.h then
    y2 = y1 + fallback.h
  elseif not y2 then
    y2 = y1
  end

  return { x1 = x1, y1 = y1, x2 = x2, y2 = y2 }
end

local function compute_text_bounds(tile_rect, badge_rect, margin)
  local bounds = {
    tile_rect.x1,
    tile_rect.y1,
    tile_rect.x2 - (margin or 0),
    tile_rect.y2,
  }

  if badge_rect then
    bounds[3] = math.min(bounds[3], badge_rect.x1 - (margin or 0))
  end

  if bounds[3] <= bounds[1] then
    bounds[3] = tile_rect.x2
  end

  return bounds
end

local function region_label(region, overrides)
  if overrides and overrides.label then
    return overrides.label
  end

  local rid = region and region.rid
  local name = region and region.name

  if rid and name then
    return string.format('%s %s', tostring(rid), name)
  elseif name then
    return name
  elseif rid then
    return tostring(rid)
  end

  return '—'
end

local function gather(tile)
  local result = {
    commands = {},
    background = tile.background,
    text = tile.text,
    badge = tile.badge,
    responsive = tile.responsive,
    length = tile.length,
    tile_height = tile.tile_height,
    disabled = tile.disabled,
    overlay = tile.overlay,
  }

  append_commands(result.commands, tile.background)
  append_commands(result.commands, tile.text)
  append_commands(result.commands, tile.badge)

  return result
end

function M.render_region(ctx, dl, rect, region, opts)
  opts = opts or {}

  local base_color = opts.base_color or (region and region.color) or Colors.tile_background
  local background = Base.draw_tile_background(dl, rect, base_color, opts.state)
  local tile_rect = ensure_rect(background.rect, rect)
  local tile_height = opts.tile_height or math.max(0, (tile_rect.y2 or 0) - (tile_rect.y1 or 0))
  local responsive = Base.calculate_responsive_elements(tile_height)

  local text = nil
  if responsive.show_text then
    local bounds = compute_text_bounds(tile_rect, nil, opts.text_margin_right or M.DEFAULTS.text_margin_right)
    text = Base.draw_text_with_truncation(ctx, dl, region_label(region, opts), bounds)
  end

  local length = nil
  if responsive.show_length then
    length = opts.length_text or (region and region.length_text)
  end

  return gather({
    background = background,
    text = text,
    badge = { visible = false, commands = {} },
    responsive = responsive,
    length = length,
    tile_height = tile_height,
    disabled = opts.state and opts.state.disabled or false,
  })
end

function M.render_playlist(ctx, dl, rect, playlist, opts)
  opts = opts or {}

  local is_disabled = opts.disabled or (playlist and playlist.is_disabled)
  local state = opts.state or {}
  if is_disabled then
    state = {}
    for k, v in pairs(opts.state or {}) do
      state[k] = v
    end
    state.disabled = true
  end

  local base_color = opts.base_color or Colors.tile_background
  local background = Base.draw_tile_background(dl, rect, base_color, state)
  local tile_rect = ensure_rect(background.rect, rect)
  local tile_height = opts.tile_height or math.max(0, (tile_rect.y2 or 0) - (tile_rect.y1 or 0))
  local responsive = Base.calculate_responsive_elements(tile_height)

  local name = playlist and playlist.name or opts.label or 'Playlist'
  local text = nil
  if responsive.show_text then
    local bounds = compute_text_bounds(tile_rect, nil, opts.text_margin_right or M.DEFAULTS.text_margin_right)
    text = Base.draw_text_with_truncation(ctx, dl, name, bounds)
    if text and text.commands and text.commands[1] then
      local color = opts.text_color or (playlist and playlist.text_color) or Colors.secondary_text or Colors.text
      text.commands[1].args[3] = color
    end
  end

  local badge = { visible = false, commands = {} }
  local item_count = (playlist and playlist.items and #playlist.items) or opts.item_count
  if responsive.show_badge and item_count and item_count > 0 then
    local badge_rect = {
      tile_rect.x1,
      tile_rect.y1,
      tile_rect.x2 - (opts.badge_margin or M.DEFAULTS.badge_margin),
      tile_rect.y2,
    }
    badge = Base.draw_repeat_badge(ctx, dl, badge_rect, item_count, not is_disabled)
    if badge.commands and badge.commands[2] then
      badge.commands[2].args[4] = string.format('[%d]', item_count)
      badge.label = badge.commands[2].args[4]
      if opts.badge_color then
        badge.commands[2].args[3] = opts.badge_color
      end
    end
  end

  local overlay = nil
  if is_disabled then
    overlay = {
      color = opts.disabled_overlay_color or Colors.tile_background,
      opacity = opts.disabled_overlay_opacity or 0.5,
    }
  end

  local length = nil
  if responsive.show_length then
    length = opts.length_text or (playlist and playlist.length_text)
  end

  return gather({
    background = background,
    text = text,
    badge = badge,
    responsive = responsive,
    length = length,
    tile_height = tile_height,
    disabled = is_disabled,
    overlay = overlay,
  })
end

return M

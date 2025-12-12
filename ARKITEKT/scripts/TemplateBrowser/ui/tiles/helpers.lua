-- @noindex
-- TemplateBrowser/ui/tiles/helpers.lua
-- Shared helper functions for tile renderers

local ImGui = require('arkitekt.core.imgui')
local Constants = require('TemplateBrowser.config.constants')

local M = {}

-- Truncate text to fit width with ellipsis
function M.truncate_text(ctx, text, max_width)
  if not text or max_width <= 0 then return '' end

  local text_width = ImGui.CalcTextSize(ctx, text)
  if text_width <= max_width then return text end

  local ellipsis = '...'
  local ellipsis_width = ImGui.CalcTextSize(ctx, ellipsis)
  local available_width = max_width - ellipsis_width

  for i = #text, 1, -1 do
    local truncated = text:sub(1, i)
    if ImGui.CalcTextSize(ctx, truncated) <= available_width then
      return truncated .. ellipsis
    end
  end

  return ellipsis
end

-- Check if template is favorited
function M.is_favorited(template_uuid, metadata)
  if not metadata or not metadata.virtual_folders then
    return false
  end

  local favorites = metadata.virtual_folders['__FAVORITES__']
  if not favorites or not favorites.template_refs then
    return false
  end

  for _, ref_uuid in ipairs(favorites.template_refs) do
    if ref_uuid == template_uuid then
      return true
    end
  end

  return false
end

-- Strip parenthetical content from VST name for display
-- e.g., 'Kontakt (Native Instruments)' -> 'Kontakt'
function M.strip_parentheses(name)
  if not name then return '' end
  local stripped = name:gsub('%s*%b()', ''):gsub('^%s+', ''):gsub('%s+$', '')
  -- Return original if stripping would leave nothing
  return stripped ~= '' and stripped or name
end

-- Check if VST name is in the tile blacklist
function M.is_blacklisted(name)
  if not name then return false end
  local blacklist = Constants.VST and Constants.VST.tile_blacklist or {}
  for _, blocked in ipairs(blacklist) do
    if name:find(blocked, 1, true) then
      return true
    end
  end
  return false
end

-- Get first non-blacklisted VST from fx list
function M.get_display_vst(fx_list)
  if not fx_list or #fx_list == 0 then return nil end
  for _, fx_name in ipairs(fx_list) do
    if not M.is_blacklisted(fx_name) then
      return fx_name
    end
  end
  return nil  -- All VSTs are blacklisted
end

-- Calculate heat color for track count badge
-- 1 track: light yellow, up to 10: yellow→orange→red, 10-20: darkening red, 20+: dark red
function M.get_track_count_color(track_count)
  local r, g, b

  if track_count <= 1 then
    -- Light yellow for single track
    r, g, b = 255, 245, 157  -- #FFF59D
  elseif track_count <= 10 then
    -- Gradient: light yellow (1) → orange (5) → red (10)
    local t = (track_count - 1) / 9  -- 0 to 1 over range 1-10

    if t <= 0.5 then
      -- Yellow to orange (first half)
      local t2 = t * 2  -- 0 to 1
      r = 255
      g = math.floor(245 - (245 - 152) * t2)  -- 245 → 152
      b = math.floor(157 - 157 * t2)          -- 157 → 0
    else
      -- Orange to red (second half)
      local t2 = (t - 0.5) * 2  -- 0 to 1
      r = 255
      g = math.floor(152 - 152 * t2)  -- 152 → 0
      b = 0
    end
  elseif track_count <= 20 then
    -- Darkening red: red (10) → dark red (20)
    local t = (track_count - 10) / 10  -- 0 to 1 over range 10-20
    r = math.floor(255 - 100 * t)  -- 255 → 155
    g = 0
    b = 0
  else
    -- 20+: same dark red
    r, g, b = 155, 0, 0
  end

  return ((r & 0xFF) << 24) | ((g & 0xFF) << 16) | ((b & 0xFF) << 8) | 0xFF
end

return M

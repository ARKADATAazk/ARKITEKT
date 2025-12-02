-- @noindex
-- TemplateBrowser/ui/tiles/helpers.lua
-- Shared helper functions for tile renderers

local ImGui = require('arkitekt.platform.imgui')
local Defaults = require('TemplateBrowser.defs.defaults')

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
  local blacklist = Defaults.VST and Defaults.VST.tile_blacklist or {}
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

return M

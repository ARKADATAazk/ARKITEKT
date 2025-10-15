local JSON = require('rearkitekt.core.json')

local M = {}

function M.get_default()
  return {
    ui = { layout_mode = 'horizontal' },
    playback = { quantize_mode = 'none' },
  }
end

function M.save(settings, proj)
  local serialized = JSON.encode(settings)
  reaper.SetProjExtState(proj, 'ReArkitekt_RegionPlaylist', 'settings', serialized)
end

function M.load(proj)
  local ok, serialized = reaper.GetProjExtState(proj, 'ReArkitekt_RegionPlaylist', 'settings')
  if ok ~= 1 or (serialized or '') == '' then return M.get_default() end
  return JSON.decode(serialized)
end

return M

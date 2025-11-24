-- @noindex
-- MediaContainer/storage/persistence.lua
-- Container state persistence via Project ExtState

local JSON = require('arkitekt.core.json')
local UUID = require('arkitekt.core.uuid')

local M = {}

local EXT_STATE_SECTION = "ARK_MEDIACONTAINER"
local KEY_CONTAINERS = "containers"
local KEY_CLIPBOARD = "clipboard"

function M.save_containers(containers, proj)
  proj = proj or 0
  local json_str = JSON.encode(containers)
  reaper.SetProjExtState(proj, EXT_STATE_SECTION, KEY_CONTAINERS, json_str)
end

function M.load_containers(proj)
  proj = proj or 0
  local ok, json_str = reaper.GetProjExtState(proj, EXT_STATE_SECTION, KEY_CONTAINERS)
  if ok ~= 1 or not json_str or json_str == "" then
    return {}
  end

  local success, containers = pcall(JSON.decode, json_str)
  if not success then
    return {}
  end

  return containers or {}
end

function M.save_clipboard(container_id, proj)
  proj = proj or 0
  reaper.SetProjExtState(proj, EXT_STATE_SECTION, KEY_CLIPBOARD, container_id or "")
end

function M.load_clipboard(proj)
  proj = proj or 0
  local ok, container_id = reaper.GetProjExtState(proj, EXT_STATE_SECTION, KEY_CLIPBOARD)
  if ok ~= 1 or not container_id or container_id == "" then
    return nil
  end
  return container_id
end

function M.clear_all(proj)
  proj = proj or 0
  reaper.SetProjExtState(proj, EXT_STATE_SECTION, KEY_CONTAINERS, "")
  reaper.SetProjExtState(proj, EXT_STATE_SECTION, KEY_CLIPBOARD, "")
end

return M

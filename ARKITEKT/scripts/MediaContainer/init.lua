-- @noindex
-- MediaContainer/init.lua
-- Main initialization and deferred loop for media container sync

local State = require("MediaContainer.core.app_state")
local Container = require("MediaContainer.core.container")
local Overlay = require("MediaContainer.ui.overlay")

local M = {}

-- Polling interval (ms)
local POLL_INTERVAL = 100
local last_poll_time = 0

-- Initialize the container system
function M.initialize()
  State.initialize()
end

-- Main update loop - call this from deferred
function M.update(ctx, draw_list)
  -- Check for project changes
  local project_changed = State.update()
  if project_changed then
    return
  end

  -- Throttle polling
  local current_time = reaper.time_precise() * 1000
  if current_time - last_poll_time < POLL_INTERVAL then
    -- Still draw overlay even if not polling
    if ctx and draw_list then
      Overlay.draw_containers(ctx, draw_list, State)
    end
    return
  end
  last_poll_time = current_time

  -- Detect and sync changes
  local changes = Container.detect_changes()
  if #changes > 0 then
    Container.sync_changes(changes)

    -- Update container bounds after sync
    for _, container in ipairs(State.get_all_containers()) do
      Container.update_container_bounds(container)
    end
    State.persist()
  end

  -- Draw overlay
  if ctx and draw_list then
    Overlay.draw_containers(ctx, draw_list, State)
  end
end

-- Create container from selection
function M.create_container()
  local container = Container.create_from_selection()
  if container then
    reaper.ShowConsoleMsg(string.format("[MediaContainer] Created container '%s' with %d items\n",
      container.name, #container.items))
  end
  return container
end

-- Copy container to clipboard
function M.copy_container()
  return Container.copy_container()
end

-- Paste container at cursor
function M.paste_container()
  return Container.paste_container()
end

-- Delete container
function M.delete_container(container_id)
  Container.delete_container(container_id)
end

-- Get all containers
function M.get_containers()
  return State.get_all_containers()
end

-- Select all items in a container
function M.select_container(container_id)
  local container = State.get_container_by_id(container_id)
  if not container then return end

  reaper.SelectAllMediaItems(0, false)  -- Deselect all

  for _, item_ref in ipairs(container.items) do
    local item = State.find_item_by_guid(item_ref.guid)
    if item then
      reaper.SetMediaItemSelected(item, true)
    end
  end

  reaper.UpdateArrange()
end

-- Accessors
M.State = State
M.Container = Container
M.Overlay = Overlay

return M

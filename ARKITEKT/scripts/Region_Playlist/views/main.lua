local M = {}
M.__index = M

local function build_dependencies(arg1, coordinator, events, extras)
  if type(arg1) == 'table' and coordinator == nil and events == nil then
    return arg1
  end
  local bundle = {}
  if type(extras) == 'table' then
    for k, v in pairs(extras) do
      bundle[k] = v
    end
  end
  bundle.state = arg1
  bundle.coordinator = coordinator
  bundle.events = events; if not bundle.gui and bundle.app_state and bundle.config then local GUI = require('Region_Playlist.app.gui'); bundle.gui = GUI.create(bundle.app_state, bundle.config, bundle.settings) end
  return bundle
end

function M.new(arg1, coordinator, events, extras)
  local deps = build_dependencies(arg1, coordinator, events, extras)
  return setmetatable({
    deps = deps or {},
    _transport = nil,
    _active = nil,
    _pool = nil,
    _status = nil,
  }, M)
end

local function get_transport(view)
  if not view._transport then
    local Transport = require('Region_Playlist.views.transport_bar')
    view._transport = Transport.new(view.deps)
  end
  return view._transport
end

local function get_active(view)
  if not view._active then
    local Active = require('Region_Playlist.views.active_panel')
    view._active = Active.new(view.deps)
  end
  return view._active
end

local function get_pool(view)
  if not view._pool then
    local Pool = require('Region_Playlist.views.pool_panel')
    view._pool = Pool.new(view.deps)
  end
  return view._pool
end

local function get_status(view)
  if not view._status then
    local Status = require('Region_Playlist.views.status_bar')
    view._status = Status.new(view.deps)
  end
  return view._status
end

function M:draw(ctx, window)
  local gui = self.deps and self.deps.gui
  if not gui then return end

  local transport = get_transport(self)
  local active = get_active(self)
  local pool = get_pool(self)

  local original_transport = gui.draw_transport_section
  local original_active = gui.region_tiles and gui.region_tiles.draw_active
  local original_pool = gui.region_tiles and gui.region_tiles.draw_pool

  self.deps.original_transport = original_transport
  self.deps.original_active = original_active
  self.deps.original_pool = original_pool

  if original_transport then
    gui.draw_transport_section = function(self_obj, ctx2)
      return transport:draw(ctx2, function()
        return original_transport(self_obj, ctx2)
      end)
    end
  end

  if gui.region_tiles and original_active then
    gui.region_tiles.draw_active = function(rt, ctx2, playlist, size)
      return active:draw(ctx2, {
        playlist = playlist,
        size = size,
        render = function()
          return original_active(rt, ctx2, playlist, size)
        end,
      })
    end
  end

  if gui.region_tiles and original_pool then
    gui.region_tiles.draw_pool = function(rt, ctx2, data, size)
      return pool:draw(ctx2, {
        data = data,
        size = size,
        render = function()
          return original_pool(rt, ctx2, data, size)
        end,
      })
    end
  end

  gui:draw(ctx, window)

  if original_transport then gui.draw_transport_section = original_transport end
  if gui.region_tiles then
    if original_active then gui.region_tiles.draw_active = original_active end
    if original_pool then gui.region_tiles.draw_pool = original_pool end
  end

  get_status(self):draw(ctx)
end

return M

-- @noindex
-- ReArkitekt/demo.lua

-- Auto-injected package path setup for relocated script
local script_path = debug.getinfo(1, "S").source:match("@?(.*)[\\/]") or ""
local root_path = script_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
if not root_path:match("[\\/]$") then root_path = root_path .. "/" end
package.path = root_path .. "?.lua;" .. root_path .. "?/init.lua;" .. package.path

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local function dirname(p) return p:match("^(.*)[/\\]") end
local function join(a,b) local s=package.config:sub(1,1); return (a:sub(-1)==s) and (a..b) or (a..s..b) end
local function addpath(p) if p and p~="" and not package.path:find(p,1,true) then package.path = p .. ";" .. package.path end end

local SRC   = debug.getinfo(1,"S").source:sub(2)
local HERE  = dirname(SRC) or "."
local PARENT= dirname(HERE or ".") or "."
addpath(join(PARENT,"?.lua")); addpath(join(PARENT,"?/init.lua"))
addpath(join(HERE,  "?.lua")); addpath(join(HERE,  "?/init.lua"))
addpath(join(HERE,  "ReArkitekt/?.lua"))
addpath(join(HERE,  "ReArkitekt/?/init.lua"))
addpath(join(HERE,  "ReArkitekt/?/?.lua"))

local Shell          = require("arkitekt.app.shell")
local PackageGrid    = require("arkitekt.gui.widgets.package_tiles.grid")
local Micromanage    = require("arkitekt.gui.widgets.package_tiles.micromanage")
local TilesContainer = require("arkitekt.gui.widgets.panel")
local SelRect        = require("arkitekt.gui.widgets.selection_rectangle")

local SettingsOK, Settings = pcall(require, "arkitekt.core.settings")
local StyleOK,    Style    = pcall(require, "arkitekt.gui.style")

local settings = nil
if SettingsOK and type(Settings.new)=="function" then
  local ok, inst = pcall(Settings.new, join(HERE,"cache"), "demo_packages.json")
  if ok then settings = inst end
end

local pkg = {
  tile = 220,
  search = "",
  order = {},
  active = {},
  index = {},
  filters = { TCP = true, MCP = true, Transport = true, Global = true },
  excl = {},
  pins = {},
}

local mock_data = {
  { id="TCP_Modern_Light", name="Modern Light Theme", type="TCP", assets=15, 
    keys={"tcp_background.png", "tcp_button.png", "tcp_slider.png", "tcp_knob.png", "tcp_meter.png"} },
  
  { id="TCP_Dark_Minimal", name="Dark Minimal", type="TCP", assets=22, 
    keys={"tcp_background.png", "tcp_knob.png", "tcp_vu.png", "tcp_button.png", "tcp_fader.png"} },
  
  { id="MCP_Pro_Blue", name="Pro Blue Mixer", type="MCP", assets=18, 
    keys={"mcp_strip.png", "mcp_fader.png", "mcp_pan.png", "mcp_solo.png", "mcp_mute.png"} },
  
  { id="Transport_Classic", name="Classic Transport", type="Transport", assets=12, 
    keys={"transport_play.png", "transport_stop.png", "transport_record.png", "transport_pause.png"} },
  
  { id="TCP_Colorful", name="Colorful TCP", type="TCP", assets=25, 
    keys={"tcp_background.png", "tcp_label.png", "tcp_meter.png", "tcp_knob.png", "tcp_slider.png"} },
  
  { id="MCP_Compact", name="Compact Mixer", type="MCP", assets=14, 
    keys={"mcp_strip.png", "mcp_solo.png", "mcp_mute.png", "mcp_fader.png", "mcp_volume.png"} },
  
  { id="Global_Icons", name="Icon Pack", type="Global", assets=45, 
    keys={"icon_save.png", "icon_load.png", "icon_export.png", "icon_settings.png"} },
  
  { id="TCP_Vintage", name="Vintage Look", type="TCP", assets=19, 
    keys={"tcp_warm.png", "tcp_analog.png", "tcp_tape.png", "tcp_background.png", "tcp_slider.png"} },
  
  { id="MCP_Studio", name="Studio Mixer", type="MCP", assets=21, 
    keys={"mcp_strip.png", "mcp_fader.png", "mcp_pan.png", "mcp_eq.png", "mcp_insert.png"} },
  
  { id="Transport_Modern", name="Modern Transport", type="Transport", assets=16, 
    keys={"transport_play.png", "transport_stop.png", "transport_record.png", "transport_loop.png"} },
}

for i, data in ipairs(mock_data) do
  local P = {
    id = data.id,
    path = "mock://packages/" .. data.id,
    meta = {
      name = data.name,
      type = data.type,
      mosaic = data.keys,
    },
    keys_order = data.keys,
    assets = {},
  }
  
  for _, key in ipairs(data.keys) do
    P.assets[key] = { file = key, provider = data.id }
  end
  
  pkg.index[i] = P
  pkg.order[i] = data.id
  pkg.active[data.id] = (i % 3 ~= 0)
end

function pkg:visible()
  local result = {}
  for _, P in ipairs(self.index) do
    local matches_search = (self.search == "" or P.id:lower():find(self.search:lower(), 1, true) or 
                           (P.meta.name and P.meta.name:lower():find(self.search:lower(), 1, true)))
    local matches_filter = self.filters[P.meta.type] == true
    
    if matches_search and matches_filter then
      result[#result + 1] = P
    end
  end
  
  table.sort(result, function(a, b)
    local idx_a, idx_b = 999, 999
    for i, id in ipairs(self.order) do
      if id == a.id then idx_a = i end
      if id == b.id then idx_b = i end
    end
    return idx_a < idx_b
  end)
  
  return result
end

function pkg:toggle(id)
  self.active[id] = not self.active[id]
  if settings then
    settings:set('pkg_active', self.active)
  end
end

function pkg:conflicts(detailed)
  local conflicts = {}
  local asset_providers = {}
  
  for _, P in ipairs(self.index) do
    if self.active[P.id] then
      for key, _ in pairs(P.assets or {}) do
        if not asset_providers[key] then
          asset_providers[key] = {}
        end
        table.insert(asset_providers[key], P.id)
      end
    end
  end
  
  for key, providers in pairs(asset_providers) do
    if #providers > 1 then
      for _, pkg_id in ipairs(providers) do
        conflicts[pkg_id] = (conflicts[pkg_id] or 0) + 1
      end
    end
  end
  
  return conflicts
end

function pkg:remove(id)
  for i, P in ipairs(self.index) do
    if P.id == id then
      table.remove(self.index, i)
      break
    end
  end
  
  for i, order_id in ipairs(self.order) do
    if order_id == id then
      table.remove(self.order, i)
      break
    end
  end
  
  self.active[id] = nil
end

function pkg:scan()
end

local theme = {
  color_from_key = function(key)
    local hash = 0
    for i = 1, #key do
      hash = ((hash * 31) + string.byte(key, i)) % 0xFFFFFF
    end
    local r = (hash >> 16) & 0xFF
    local g = (hash >> 8) & 0xFF
    local b = hash & 0xFF
    return (r << 24) | (g << 16) | (b << 8) | 0xFF
  end
}

local sel_rect = SelRect.new()
local grid = PackageGrid.create(pkg, settings, theme)

local container = TilesContainer.new({
  id = "packages_container",
  width = nil,
  height = nil,
  sel_rect = sel_rect,
  
  on_rect_select = function(x1, y1, x2, y2, mode)
    grid:apply_rect_selection({x1, y1, x2, y2}, mode)
  end,
  
  on_click_empty = function()
    grid:clear_selection()
  end,
})

local function get_app_status()
  local conflicts = pkg:conflicts(true)
  local total_conflicts = 0
  for _, count in pairs(conflicts) do
    total_conflicts = total_conflicts + count
  end
  
  if total_conflicts > 0 then
    return {
      color = 0xFFA500FF,
      text = string.format("CONFLICTS: %d", total_conflicts),
    }
  end
  
  return {
    color = 0x41E0A3FF,
    text = "READY",
  }
end

local function draw_packages(ctx)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, 6, 3)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameRounding, 4)

  ImGui.SetNextItemWidth(ctx, 200)
  local ch_s, new_q = ImGui.InputText(ctx, 'Search', pkg.search or '')
  if ch_s then 
    pkg.search = new_q
    if settings then settings:set('pkg_search', pkg.search) end
  end

  ImGui.SameLine(ctx)
  
  ImGui.SetNextItemWidth(ctx, 140)
  local ch_t, new_tile = ImGui.SliderInt(ctx, '##TileSize', pkg.tile, 160, 420)
  if ch_t then 
    pkg.tile = new_tile
    if settings then settings:set('pkg_tilesize', pkg.tile) end
  end
  ImGui.SameLine(ctx)
  ImGui.Text(ctx, 'Size')

  ImGui.SameLine(ctx)
  
  local c1, v1 = ImGui.Checkbox(ctx, 'TCP', pkg.filters.TCP)
  if c1 then pkg.filters.TCP = v1 end
  ImGui.SameLine(ctx)
  
  local c2, v2 = ImGui.Checkbox(ctx, 'MCP', pkg.filters.MCP)
  if c2 then pkg.filters.MCP = v2 end
  ImGui.SameLine(ctx)
  
  local c3, v3 = ImGui.Checkbox(ctx, 'Transport', pkg.filters.Transport)
  if c3 then pkg.filters.Transport = v3 end
  ImGui.SameLine(ctx)
  
  local c4, v4 = ImGui.Checkbox(ctx, 'Global', pkg.filters.Global)
  if c4 then pkg.filters.Global = v4 end

  ImGui.PopStyleVar(ctx, 2)
  
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 1, 8)

  if container:begin_draw(ctx) then
    grid:draw(ctx)
  end
  container:end_draw(ctx)
  
  Micromanage.draw_window(ctx, pkg, settings)
end

local function draw_settings(ctx)
  ImGui.Text(ctx, "Settings")
  ImGui.Separator(ctx)
  ImGui.TextWrapped(ctx, "This demo showcases the colorblocks grid widget with:")
  ImGui.BulletText(ctx, "Multi-select with Ctrl/Shift")
  ImGui.BulletText(ctx, "Drag & drop reordering")
  ImGui.BulletText(ctx, "Selection rectangle across entire container")
  ImGui.BulletText(ctx, "Animated layout transitions")
  ImGui.BulletText(ctx, "Marching ants selection borders")
  ImGui.BulletText(ctx, "Right-click to toggle package state")
  ImGui.BulletText(ctx, "Double-click to open micro-manage")
  ImGui.BulletText(ctx, "Content padding managed by window system")
  ImGui.BulletText(ctx, "Conflict detection and priority resolution")
  ImGui.Dummy(ctx, 1, 20)
  ImGui.Text(ctx, string.format("Current packages visible: %d", #pkg:visible()))
  ImGui.Text(ctx, string.format("Current selection count: %d", grid:get_selected_count()))
  
  local conflicts = pkg:conflicts(true)
  local total_conflicts = 0
  for _, count in pairs(conflicts) do
    total_conflicts = total_conflicts + count
  end
  ImGui.Text(ctx, string.format("Total asset conflicts: %d", total_conflicts))
end

local function draw_about(ctx)
  ImGui.Text(ctx, "About Package Grid Demo")
  ImGui.Separator(ctx)
  ImGui.TextWrapped(ctx, "This demo uses the modular colorblocks widget system:")
  ImGui.Dummy(ctx, 1, 10)
  ImGui.BulletText(ctx, "colorblocks.lua - Reusable grid widget")
  ImGui.BulletText(ctx, "package_tiles/grid.lua - Package grid logic")
  ImGui.BulletText(ctx, "package_tiles/renderer.lua - Tile rendering")
  ImGui.BulletText(ctx, "package_tiles/micromanage.lua - Asset management")
  ImGui.BulletText(ctx, "tiles_container.lua - Visual container with scrolling")
  ImGui.BulletText(ctx, "selection_rectangle.lua - Standalone selection widget")
  ImGui.BulletText(ctx, "window.lua - Window with content padding")
  ImGui.BulletText(ctx, "menutabs.lua - Tab navigation")
  ImGui.BulletText(ctx, "Fully decoupled rendering and interaction")
  ImGui.Dummy(ctx, 1, 20)
  ImGui.TextWrapped(ctx, "The grid widget provides selection, drag-drop, and layout systems that can be reused for any grid-based UI.")
  ImGui.Dummy(ctx, 1, 20)
  ImGui.TextWrapped(ctx, "Content padding is now centralized in the window system, eliminating duplication across tab functions.")
  ImGui.Dummy(ctx, 1, 20)
  ImGui.TextWrapped(ctx, "Tabs are now proper window chrome, rendered between titlebar and content with no gap.")
  ImGui.Dummy(ctx, 1, 20)
  ImGui.TextWrapped(ctx, "Conflicts are auto-resolved by overwrite priority (#1 overwrites #2, etc). Orange badges show conflict counts.")
end

local function draw(ctx, state)
  local active_tab = state.window:get_active_tab()
  
  if     active_tab == "PACKAGES" then draw_packages(ctx)
  elseif active_tab == "SETTINGS" then draw_settings(ctx)
  elseif active_tab == "ABOUT"    then draw_about(ctx)
  end
end

Shell.run({
  title        = "ReArkitekt - Package Grid Demo",
  draw         = draw,
  settings     = settings,
  style        = StyleOK and Style or nil,
  initial_pos  = { x = 120, y = 120 },
  initial_size = { w = 900, h = 600 },
  min_size     = { w = 600, h = 400 },
  get_status_func = get_app_status,
  content_padding = 12,
  tabs = {
    items = {
      { id="PACKAGES", label="Packages" },
      { id="SETTINGS", label="Settings" },
      { id="ABOUT",    label="About" },
    },
    active = "PACKAGES",
  },
})
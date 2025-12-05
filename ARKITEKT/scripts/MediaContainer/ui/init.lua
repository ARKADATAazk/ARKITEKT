-- @noindex
-- MediaContainer/ui/init.lua
-- Main GUI orchestrator
--
-- Coordinates between the overlay (arrange view visualization),
-- the control panel (buttons and container list), and the domain layer.

local ImGui = require('arkitekt.core.imgui')
local Colors = require('arkitekt.core.colors')
local Constants = require('MediaContainer.config.constants')
local Overlay = require('MediaContainer.ui.overlay')
local Container = require('MediaContainer.domain.container')
local Logger = require('arkitekt.debug.logger')

local M = {}
local GUI = {}
GUI.__index = GUI

-- =============================================================================
-- FACTORY
-- =============================================================================

--- Create a new GUI instance
--- @param opts table Options table
--- @param opts.state table Application state module
--- @param opts.config table Configuration constants (optional, uses defaults)
--- @param opts.settings table Settings instance for persistence (optional)
--- @return table gui GUI instance
function M.new(opts)
  opts = opts or {}

  local self = setmetatable({
    State = opts.state,
    Config = opts.config or Constants,
    settings = opts.settings,
    last_poll_time = 0,
  }, GUI)

  Logger.debug('UI', 'GUI created')

  return self
end

-- =============================================================================
-- UPDATE LOOP
-- =============================================================================

function GUI:update(ctx, draw_list)
  -- Check for project changes via state's project monitor
  self.State.Update()

  local cfg = self.Config

  -- Throttle polling for sync detection
  local current_time = reaper.time_precise() * 1000
  if current_time - self.last_poll_time >= cfg.POLL_INTERVAL then
    self.last_poll_time = current_time

    -- Detect and sync changes
    local changes = Container.detect_changes()
    if #changes > 0 then
      Logger.debug('UI', 'Detected %d changes, syncing', #changes)
      Container.sync_changes(changes)

      -- Update container bounds after sync
      for _, container in ipairs(self.State.get_all_containers()) do
        Container.update_container_bounds(container)
      end
      self.State.persist()
    end
  end

  -- Draw overlay on arrange view
  if ctx and draw_list then
    Overlay.draw_containers(ctx, draw_list, self.State)
  end
end

-- =============================================================================
-- MAIN DRAW
-- =============================================================================

function GUI:draw(ctx, shell_state)
  local draw_list = ImGui.GetBackgroundDrawList(ctx)
  local cfg = self.Config

  -- Update state and sync
  self:update(ctx, draw_list)

  local containers = self.State.get_all_containers()

  -- Action buttons row
  if ImGui.Button(ctx, 'Create', cfg.BUTTON_WIDTH, 0) then
    local container = Container.create_from_selection()
    if container then
      Logger.info('UI', 'Created container: %s', container.name)
    end
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, 'Copy', cfg.BUTTON_WIDTH, 0) then
    Container.copy_container()
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, 'Paste', cfg.BUTTON_WIDTH, 0) then
    local container = Container.paste_container()
    if container then
      Logger.info('UI', 'Pasted container: %s', container.name)
    end
  end

  ImGui.Separator(ctx)

  -- Container count and list
  ImGui.Text(ctx, string.format('Containers: %d', #containers))

  if #containers > 0 then
    self:draw_container_list(ctx, containers)

    ImGui.Separator(ctx)

    -- Delete all button
    ImGui.PushStyleColor(ctx, ImGui.Col_Button, cfg.COLORS.delete_button)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, cfg.COLORS.delete_button_hover)
    if ImGui.Button(ctx, 'Delete All', -1, 0) then
      Logger.warn('UI', 'Deleting all %d containers', #containers)
      self.State.containers = {}
      self.State.container_lookup = {}
      self.State.persist()
    end
    ImGui.PopStyleColor(ctx, 2)
  else
    ImGui.TextDisabled(ctx, 'No containers yet')
    ImGui.TextDisabled(ctx, 'Select items and click Create')
  end

  ImGui.Separator(ctx)
  ImGui.TextDisabled(ctx, 'Sync: Active')
end

-- =============================================================================
-- CONTAINER LIST
-- =============================================================================

function GUI:draw_container_list(ctx, containers)
  local cfg = self.Config

  if not ImGui.BeginChild(ctx, 'ContainerList', 0, cfg.CONTAINER_LIST_HEIGHT) then
    return
  end

  for i, container in ipairs(containers) do
    local linked_text = container.master_id and ' [linked]' or ' [master]'
    local label = string.format('%s%s (%d items)', container.name, linked_text, #container.items)

    -- Color indicator
    local r, g, b, a = Colors.RgbaToComponents(container.color or cfg.COLORS.default_container)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, ImGui.ColorConvertDouble4ToU32(r/255, g/255, b/255, 1))
    ImGui.Bullet(ctx)
    ImGui.PopStyleColor(ctx, 1)
    ImGui.SameLine(ctx)

    -- Selectable item - click to select items in Reaper
    if ImGui.Selectable(ctx, label, false) then
      self:select_container(container.id)
    end

    -- Context menu for individual container
    if ImGui.BeginPopupContextItem(ctx) then
      if ImGui.MenuItem(ctx, 'Delete') then
        Logger.info('UI', 'Deleting container: %s', container.name)
        Container.delete_container(container.id)
      end
      ImGui.EndPopup(ctx)
    end
  end

  ImGui.EndChild(ctx)
end

-- =============================================================================
-- ACTIONS
-- =============================================================================

function GUI:select_container(container_id)
  local container = self.State.get_container_by_id(container_id)
  if not container then return end

  Logger.debug('UI', 'Selecting container: %s', container.name)

  reaper.SelectAllMediaItems(0, false)  -- Deselect all

  local selected_count = 0
  for _, item_ref in ipairs(container.items) do
    local item = self.State.find_item_by_guid(item_ref.guid)
    if item then
      reaper.SetMediaItemSelected(item, true)
      selected_count = selected_count + 1
    end
  end

  Logger.debug('UI', 'Selected %d/%d items', selected_count, #container.items)
  reaper.UpdateArrange()
end

return M

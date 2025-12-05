-- @noindex
-- DrumBlocks/app/gui.lua
-- Main GUI for DrumBlocks

local Ark = require('arkitekt')
local ImGui = Ark.ImGui
local PadGrid = require('DrumBlocks.widgets.pad_grid')
local Bridge = require('DrumBlocks.domain.bridge')

local M = {}
M.__index = M

function M.create(state, settings)
  local self = setmetatable({}, M)
  self.state = state
  self.settings = settings
  return self
end

function M:draw(ctx)
  local state = self.state

  -- Check if track changed
  local current_track = reaper.GetSelectedTrack(0, 0)
  if current_track ~= state.getTrack() then
    state.refreshTrack()
  end

  -- Main layout: Sidebar | Pad Grid | Pad Editor
  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)

  -- ========================================================================
  -- TOP BAR
  -- ========================================================================
  self:drawTopBar(ctx)
  ImGui.Separator(ctx)

  -- ========================================================================
  -- MAIN CONTENT
  -- ========================================================================
  if ImGui.BeginChild(ctx, '##main_content', 0, 0) then
    -- Left panel: Browser (collapsible)
    local browser_width = 200

    if ImGui.BeginChild(ctx, '##browser_panel', browser_width, 0, ImGui.ChildFlags_Border) then
      self:drawBrowser(ctx)
    end
    ImGui.EndChild(ctx)

    ImGui.SameLine(ctx)

    -- Center: Pad Grid
    if ImGui.BeginChild(ctx, '##pad_panel', 380, 0) then
      self:drawPadSection(ctx)
    end
    ImGui.EndChild(ctx)

    ImGui.SameLine(ctx)

    -- Right: Pad Editor
    if ImGui.BeginChild(ctx, '##editor_panel', 0, 0, ImGui.ChildFlags_Border) then
      self:drawPadEditor(ctx)
    end
    ImGui.EndChild(ctx)
  end
  ImGui.EndChild(ctx)
end

-- ============================================================================
-- TOP BAR
-- ============================================================================

function M:drawTopBar(ctx)
  local state = self.state

  -- Kit name
  ImGui.Text(ctx, 'Kit:')
  ImGui.SameLine(ctx)
  ImGui.SetNextItemWidth(ctx, 150)
  local changed, new_name = ImGui.InputText(ctx, '##kit_name', state.getKitName())
  if changed then
    state.setKitName(new_name)
  end

  ImGui.SameLine(ctx)

  -- Kit buttons
  if Ark.Button(ctx, 'New') then
    state.newKit()
  end
  ImGui.SameLine(ctx)
  if Ark.Button(ctx, 'Save') then
    self:saveKit()
  end
  ImGui.SameLine(ctx)
  if Ark.Button(ctx, 'Load') then
    self:loadKit()
  end

  ImGui.SameLine(ctx)
  ImGui.Dummy(ctx, 20, 0)
  ImGui.SameLine(ctx)

  -- BlockSampler status
  if state.hasBlockSampler() then
    ImGui.TextColored(ctx, 0x88FF88FF, 'BlockSampler: Connected')
  else
    ImGui.TextColored(ctx, 0xFF8888FF, 'BlockSampler: Not Found')
    ImGui.SameLine(ctx)
    if Ark.Button(ctx, 'Insert') then
      state.insertBlockSampler()
    end
  end

  ImGui.SameLine(ctx)
  ImGui.Dummy(ctx, 20, 0)
  ImGui.SameLine(ctx)

  -- Hot-swap toggle
  local hot_swap = state.isHotSwapEnabled()
  if ImGui.Checkbox(ctx, 'Hot-Swap', hot_swap) then
    state.setHotSwapEnabled(not hot_swap)
  end
end

-- ============================================================================
-- BROWSER PANEL
-- ============================================================================

function M:drawBrowser(ctx)
  local state = self.state

  ImGui.Text(ctx, 'Sample Browser')
  ImGui.Separator(ctx)

  -- Path navigation
  if Ark.Button(ctx, '^ Up') then
    state.navigateBrowserUp()
  end
  ImGui.SameLine(ctx)

  local path = state.getBrowserPath() or ''
  local display_path = path:match('([^/\\]+)$') or path
  ImGui.Text(ctx, display_path)

  ImGui.Separator(ctx)

  -- File list
  if ImGui.BeginChild(ctx, '##file_list') then
    local files = state.getBrowserFiles()

    -- Folders first (TODO)

    -- Files
    for i, file in ipairs(files) do
      local is_selected = false
      if ImGui.Selectable(ctx, file.name, is_selected) then
        -- Click to load
        local selected_pad = state.getSelectedPad()
        if selected_pad then
          state.setPadSample(selected_pad, 0, file.path)
        end
      end

      -- Hot-swap on hover
      if ImGui.IsItemHovered(ctx) and state.isHotSwapEnabled() then
        local selected_pad = state.getSelectedPad()
        if selected_pad then
          state.previewSample(file.path)
        end
      end

      -- Drag source
      if ImGui.BeginDragDropSource(ctx) then
        ImGui.SetDragDropPayload(ctx, 'FILES', file.path)
        ImGui.Text(ctx, file.name)
        ImGui.EndDragDropSource(ctx)
      end
    end
  end
  ImGui.EndChild(ctx)
end

-- ============================================================================
-- PAD SECTION
-- ============================================================================

function M:drawPadSection(ctx)
  local state = self.state

  -- Bank selector
  ImGui.Text(ctx, 'Bank:')
  ImGui.SameLine(ctx)

  local current_bank = state.getCurrentBank()
  for bank = 0, state.NUM_BANKS - 1 do
    if bank > 0 then ImGui.SameLine(ctx) end
    local label = string.format('%s', string.char(65 + bank))  -- A, B, C, D...
    local is_current = (bank == current_bank)

    if is_current then
      ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0x6666AAFF)
    end

    if Ark.Button(ctx, label, 24) then
      state.setCurrentBank(bank)
    end

    if is_current then
      ImGui.PopStyleColor(ctx)
    end
  end

  ImGui.Separator(ctx)

  -- Pad grid
  PadGrid.draw(ctx, state)

  -- Selected pad info
  local selected = state.getSelectedPad()
  if selected then
    ImGui.Separator(ctx)
    local pad_data = state.getPadData(selected)
    local name = pad_data.name or '(empty)'
    ImGui.Text(ctx, string.format('Selected: Pad %d - %s', selected + 1, name))
  end
end

-- ============================================================================
-- PAD EDITOR
-- ============================================================================

function M:drawPadEditor(ctx)
  local state = self.state
  local selected = state.getSelectedPad()

  ImGui.Text(ctx, 'Pad Editor')
  ImGui.Separator(ctx)

  if not selected then
    ImGui.TextDisabled(ctx, 'Select a pad to edit')
    return
  end

  local pad = state.getPadData(selected)

  -- Sample info
  ImGui.Text(ctx, 'Sample:')
  ImGui.SameLine(ctx)
  ImGui.Text(ctx, pad.name or '(none)')

  if pad.name then
    ImGui.SameLine(ctx)
    if Ark.Button(ctx, 'Clear') then
      state.setPadSample(selected, 0, '')
    end
  end

  ImGui.Separator(ctx)

  -- Volume
  ImGui.Text(ctx, 'Volume')
  ImGui.SetNextItemWidth(ctx, -1)
  local vol_changed, vol = ImGui.SliderDouble(ctx, '##volume', pad.volume, 0, 1, '%.2f')
  if vol_changed then
    state.setPadVolume(selected, vol)
  end

  -- Pan
  ImGui.Text(ctx, 'Pan')
  ImGui.SetNextItemWidth(ctx, -1)
  local pan_changed, pan = ImGui.SliderDouble(ctx, '##pan', pad.pan, -1, 1, '%.2f')
  if pan_changed then
    state.setPadPan(selected, pan)
  end

  -- Tune
  ImGui.Text(ctx, 'Tune (st)')
  ImGui.SetNextItemWidth(ctx, -1)
  local tune_changed, tune = ImGui.SliderDouble(ctx, '##tune', pad.tune, -24, 24, '%.0f')
  if tune_changed then
    state.setPadTune(selected, tune)
  end

  ImGui.Separator(ctx)

  -- Kill Group
  ImGui.Text(ctx, 'Kill Group')
  ImGui.SetNextItemWidth(ctx, -1)
  local kill_items = 'None\0001\0002\0003\0004\0005\0006\0007\0008\000'
  local kill_changed, kill = ImGui.Combo(ctx, '##killgroup', pad.kill_group, kill_items)
  if kill_changed then
    state.setPadKillGroup(selected, kill)
  end

  -- Output Group
  ImGui.Text(ctx, 'Output Group')
  ImGui.SetNextItemWidth(ctx, -1)
  local out_items = 'Main Only\000Group 1 - Kicks\000Group 2 - Snares\000Group 3 - HiHats\000Group 4 - Perc\000'
  for i = 5, 16 do
    out_items = out_items .. 'Group ' .. i .. '\000'
  end
  local out_changed, out = ImGui.Combo(ctx, '##outgroup', pad.output_group, out_items)
  if out_changed then
    state.setPadOutputGroup(selected, out)
  end

  ImGui.Separator(ctx)

  -- One-shot toggle
  local oneshot_changed, oneshot = ImGui.Checkbox(ctx, 'One-Shot', pad.one_shot)
  if oneshot_changed then
    -- TODO: state.setPadOneShot(selected, oneshot)
  end

  -- Reverse toggle
  local reverse_changed, reverse = ImGui.Checkbox(ctx, 'Reverse', pad.reverse)
  if reverse_changed then
    -- TODO: state.setPadReverse(selected, reverse)
  end

  ImGui.Separator(ctx)

  -- Trigger button for testing
  if Ark.Button(ctx, 'Trigger Pad', -1) then
    Bridge.triggerPad(selected, 100)
  end
end

-- ============================================================================
-- KIT SAVE/LOAD
-- ============================================================================

function M:saveKit()
  local state = self.state
  local kit = state.getKitData()

  -- Get save path
  local retval, path = reaper.JS_Dialog_BrowseForSaveFile(
    'Save Kit',
    reaper.GetResourcePath() .. '/Data',
    state.getKitName() .. '.json',
    'JSON Files (*.json)\0*.json\0All Files (*.*)\0*.*\0'
  )

  if retval == 1 and path then
    local JSON = require('arkitekt.core.json')
    local json_str = JSON.encode(kit)

    local f = io.open(path, 'w')
    if f then
      f:write(json_str)
      f:close()
    end
  end
end

function M:loadKit()
  local state = self.state

  local retval, path = reaper.JS_Dialog_BrowseForOpenFiles(
    'Load Kit',
    reaper.GetResourcePath() .. '/Data',
    '',
    'JSON Files (*.json)\0*.json\0All Files (*.*)\0*.*\0',
    false
  )

  if retval == 1 and path then
    local f = io.open(path, 'r')
    if f then
      local json_str = f:read('*a')
      f:close()

      local JSON = require('arkitekt.core.json')
      local kit = JSON.decode(json_str)
      if kit then
        state.loadKitData(kit)
      end
    end
  end
end

return M

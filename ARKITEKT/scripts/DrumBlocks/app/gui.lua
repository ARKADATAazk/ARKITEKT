-- @noindex
-- DrumBlocks/app/gui.lua
-- Main GUI for DrumBlocks

local Ark = require('arkitekt')
local ImGui = Ark.ImGui
local Colors = Ark.Colors
local Panel = require('arkitekt.gui.widgets.containers.panel')
local Card = require('arkitekt.gui.widgets.containers.card')
local PadGrid = require('DrumBlocks.widgets.pad_grid')
local WaveformDisplay = require('DrumBlocks.widgets.waveform_display')
local WaveformSlicer = require('DrumBlocks.widgets.waveform_slicer')
local VelocityPanel = require('DrumBlocks.widgets.velocity_panel')
local WaveformCache = require('DrumBlocks.domain.waveform_cache')
local TransientDetector = require('DrumBlocks.domain.transient_detector')
local Bridge = require('DrumBlocks.domain.bridge')

-- Envelope type state
local current_env_type = WaveformDisplay.ENV_VOLUME

-- Editor tab state
local EDITOR_TAB_WAVEFORM = 'waveform'
local EDITOR_TAB_SLICER = 'slicer'
local current_editor_tab = EDITOR_TAB_WAVEFORM

-- Toolbar state
local toolbar_state = {
  io_mode = false,    -- Show output bus on badge instead of MIDI note
  fold_mode = false,  -- Hide empty pads
  choke_mode = false, -- Show choke/kill group on pads
  vel_mode = false,   -- Show velocity layer panel
}

local M = {}
M.__index = M

function M.create(state, settings)
  local self = setmetatable({}, M)
  self.state = state
  self.settings = settings

  -- Create pad editor panel with dotted background
  self.pad_editor_panel = Panel.new({
    id = 'pad_editor_panel',
    config = {
      padding = 8,
      rounding = 6,
      border_thickness = 1,
      background_pattern = {
        enabled = true,
        primary = {
          type = 'dot',
          spacing = 24,
          dot_size = 1.5,
        },
        secondary = {
          enabled = false,
        },
      },
    },
  })

  return self
end

function M:draw(ctx)
  local state = self.state

  -- Check if track changed
  local current_track = reaper.GetSelectedTrack(0, 0)
  if current_track ~= state.getTrack() then
    state.refreshTrack()
  end

  -- Process queued waveform extractions (one per frame to avoid UI freeze)
  state.processWaveformQueue()

  -- ========================================================================
  -- TOP BAR
  -- ========================================================================
  self:drawTopBar(ctx)
  ImGui.Separator(ctx)

  -- ========================================================================
  -- MAIN CONTENT (Two columns: Pad Grid | Pad Editor)
  -- ========================================================================
  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)

  -- If no VST, show message instead of content
  if not state.hasDrumBlocks() then
    -- Center the message in available space
    local msg = 'No DrumBlocks VST detected'
    local msg2 = 'Select a track with DrumBlocks or click "Insert" above'
    local text_w, text_h = ImGui.CalcTextSize(ctx, msg)
    local text_w2 = ImGui.CalcTextSize(ctx, msg2)

    ImGui.Dummy(ctx, 0, avail_h / 2 - 30)
    ImGui.SetCursorPosX(ctx, (avail_w - text_w) / 2)
    ImGui.TextColored(ctx, 0xAAAAAAFF, msg)
    ImGui.SetCursorPosX(ctx, (avail_w - text_w2) / 2)
    ImGui.TextColored(ctx, 0x888888FF, msg2)
    return
  end

  -- Left: Pad Grid section (fixed width)
  -- toolbar(20) + gap(4) + bank(55) + gap(4) + grid(390) = 473
  local grid_panel_width = 473

  -- No scrolling on parent - only the grid child scrolls in fold mode
  local pad_panel_flags = ImGui.WindowFlags_NoScrollbar + ImGui.WindowFlags_NoScrollWithMouse

  -- Remove padding so child windows get exact dimensions
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 0, 0)
  if ImGui.BeginChild(ctx, '##pad_panel', grid_panel_width, 0, pad_panel_flags) then
    self:drawPadSection(ctx)
  end
  ImGui.EndChild(ctx)
  ImGui.PopStyleVar(ctx)

  ImGui.SameLine(ctx)

  -- Right: Pad Editor (takes remaining space)
  self:drawPadEditor(ctx)
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

  -- DrumBlocks VST status
  if state.hasDrumBlocks() then
    ImGui.TextColored(ctx, 0x88FF88FF, 'DrumBlocks: Connected')
  else
    ImGui.TextColored(ctx, 0xFF8888FF, 'DrumBlocks: Not Found')
    ImGui.SameLine(ctx)
    if Ark.Button(ctx, 'Insert') then
      state.insertDrumBlocks()
    end
  end
end

-- ============================================================================
-- PAD SECTION
-- ============================================================================

-- Draw vertical toolbar with toggle buttons (like Ableton Drum Rack)
-- Returns width, height
local function drawToolbar(ctx, total_height)
  local dl = ImGui.GetWindowDrawList(ctx)
  local start_x, start_y = ImGui.GetCursorScreenPos(ctx)

  local btn_size = 20
  local btn_gap = 4
  local rounding = 3

  -- Colors
  local col_bg = 0x252525FF
  local col_hover = 0x3A3A3AFF
  local col_active = 0x555555FF      -- Grayscale (no blue tint)
  local col_text = 0xAAAAAAFF
  local col_text_active = 0xFFFFFFFF

  local buttons = {
    { id = 'io', label = 'IO', tooltip = 'Show output bus on pads', state_key = 'io_mode' },
    { id = 'fold', label = 'F', tooltip = 'Fold: hide empty pads', state_key = 'fold_mode' },
    { id = 'choke', label = 'C', tooltip = 'Show choke groups', state_key = 'choke_mode' },
    { id = 'vel', label = 'V', tooltip = 'Velocity layers panel', state_key = 'vel_mode' },
  }

  for i, btn in ipairs(buttons) do
    local btn_y = start_y + (i - 1) * (btn_size + btn_gap)
    local is_active = toolbar_state[btn.state_key]

    -- Draw button background
    local bg_color = is_active and col_active or col_bg
    ImGui.DrawList_AddRectFilled(dl, start_x, btn_y, start_x + btn_size, btn_y + btn_size, bg_color, rounding)

    -- Draw label
    local text_w = ImGui.CalcTextSize(ctx, btn.label)
    local text_x = start_x + (btn_size - text_w) / 2
    local text_y = btn_y + (btn_size - ImGui.GetTextLineHeight(ctx)) / 2
    local text_color = is_active and col_text_active or col_text
    ImGui.DrawList_AddText(dl, text_x, text_y, text_color, btn.label)

    -- Invisible button for interaction
    ImGui.SetCursorScreenPos(ctx, start_x, btn_y)
    if ImGui.InvisibleButton(ctx, '##toolbar_' .. btn.id, btn_size, btn_size) then
      toolbar_state[btn.state_key] = not toolbar_state[btn.state_key]
    end

    -- Hover effect
    if ImGui.IsItemHovered(ctx) then
      if not is_active then
        ImGui.DrawList_AddRectFilled(dl, start_x, btn_y, start_x + btn_size, btn_y + btn_size, col_hover, rounding)
        ImGui.DrawList_AddText(dl, text_x, text_y, col_text, btn.label)
      end
      ImGui.BeginTooltip(ctx)
      ImGui.Text(ctx, btn.tooltip)
      ImGui.EndTooltip(ctx)
    end
  end

  -- Reserve space
  local total_w = btn_size
  local actual_h = #buttons * btn_size + (#buttons - 1) * btn_gap
  ImGui.SetCursorScreenPos(ctx, start_x, start_y)
  ImGui.Dummy(ctx, total_w, actual_h)

  return total_w, actual_h
end

-- MIDI note name conversion
local NOTE_NAMES = { 'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B' }
local function midi_to_note_name(midi_note)
  local note_idx = midi_note % 12
  local octave = math.floor(midi_note / 12) - 1
  return NOTE_NAMES[note_idx + 1] .. octave
end

-- Persistent state for bank selector drag
local bank_drag_active = false
local bank_drop_target = nil  -- Bank index where pad drag might drop

-- Draw bank overview: 8 mini 4x4 grids in vertical column (like Ableton Drum Rack)
-- total_height: target height to match (from pad grid)
local function drawBankOverview(ctx, state, total_height)
  local current_bank = state.getCurrentBank()
  local dl = ImGui.GetWindowDrawList(ctx)
  local start_x, start_y = ImGui.GetCursorScreenPos(ctx)

  -- Track bank selector drag state
  local mouse_down = ImGui.IsMouseDown(ctx, 0)
  if not mouse_down then
    bank_drag_active = false
  end

  -- Reset bank drop target each frame (will be set if mouse is over a bank)
  bank_drop_target = nil

  -- Position adjustments
  local left_pad = 3    -- Padding from left edge (for current bank border)
  local top_offset = 5  -- Move down from top
  local bot_offset = -2 -- Trim from bottom
  start_x = start_x + left_pad
  start_y = start_y + top_offset
  total_height = total_height - top_offset + bot_offset  -- Adjust available height

  -- Calculate bank gap first (fixed proportion)
  local bank_gap = 4

  -- Calculate bank_size to exactly fit total_height
  -- total_height = 8 * bank_size + 7 * bank_gap
  -- bank_size = (total_height - 7 * bank_gap) / 8
  local bank_size = math.floor((total_height - 7 * bank_gap) / 8)
  bank_size = math.max(16, bank_size)

  -- Cell size within bank (4x4 grid with 1px gaps)
  local gap = 1
  local cell = math.floor((bank_size - gap * 3) / 4)
  cell = math.max(3, cell)

  -- Recalculate actual bank_size with integer cell sizes
  bank_size = cell * 4 + gap * 3

  -- Recalculate bank_gap to distribute remaining space evenly
  local used_by_banks = bank_size * 8
  local remaining = total_height - used_by_banks
  bank_gap = math.floor(remaining / 7)
  bank_gap = math.max(2, bank_gap)

  -- Calculate actual height and vertical offset to center within target
  local actual_h = bank_size * 8 + bank_gap * 7
  local v_offset = math.floor((total_height - actual_h) / 2)
  start_y = start_y + v_offset

  -- Colors
  local col_empty = 0x2A2A2AFF
  local col_loaded = 0x4A4A4AFF          -- Grayscale (no blue tint)
  local col_selected_empty = 0x3A3A3AFF  -- Pure gray
  local col_selected_loaded = 0x606060FF -- Gray (no blue tint)
  local col_current_border = 0xAAAAAAFF  -- Light gray (no blue tint)

  -- Solo indicator color (golden yellow)
  local col_solo = 0xFFCC44FF

  -- Draw 8 banks in vertical column
  for bank = 0, 7 do
    local bank_x = start_x
    local bank_y = start_y + bank * (bank_size + bank_gap)

    local is_current = (bank == current_bank)

    -- Check if any pad in this bank is soloed
    local bank_has_solo = false
    local bank_start = bank * 16
    for i = 0, 15 do
      local pad_data = state.getPadData(bank_start + i)
      if pad_data and pad_data.soloed then
        bank_has_solo = true
        break
      end
    end

    -- Draw 4x4 mini grid for this bank
    for row = 0, 3 do
      for col = 0, 3 do
        local pad_idx = bank_start + row * 4 + col
        local has_sample = state.hasSample(pad_idx)
        local pad_color = state.getPadColor(pad_idx)

        local cx = bank_x + col * (cell + gap)
        local cy = bank_y + row * (cell + gap)

        -- Choose color based on state
        local color
        if pad_color then
          -- Use custom pad color with proper derivation (like TileFX)
          if is_current then
            -- Current bank: more saturated and bright
            color = Colors.SameHueVariant(pad_color, 0.8, 0.7, 0xFF)
          else
            -- Other banks: desaturated and darker
            color = Colors.SameHueVariant(pad_color, 0.4, 0.4, 0xCC)
          end
        elseif is_current then
          color = has_sample and col_selected_loaded or col_selected_empty
        else
          color = has_sample and col_loaded or col_empty
        end

        ImGui.DrawList_AddRectFilled(dl, cx, cy, cx + cell, cy + cell, color, 1)
      end
    end

    -- Solo indicator: small dot in top-right corner
    if bank_has_solo then
      local dot_r = 3
      local dot_x = bank_x + bank_size - dot_r - 1
      local dot_y = bank_y + dot_r + 1
      ImGui.DrawList_AddCircleFilled(dl, dot_x, dot_y, dot_r, col_solo)
    end

    -- Border around current bank
    if is_current then
      ImGui.DrawList_AddRect(dl,
        bank_x - 2, bank_y - 2,
        bank_x + bank_size + 2, bank_y + bank_size + 2,
        col_current_border, 2, 0, 2)
    end

    -- Invisible button for interaction (select on mouse DOWN, not release)
    ImGui.SetCursorScreenPos(ctx, bank_x, bank_y)
    ImGui.InvisibleButton(ctx, '##bank_' .. bank, bank_size, bank_size)

    local item_hovered = ImGui.IsItemHovered(ctx)

    -- Check mouse position directly (for drag-over detection)
    local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
    local mouse_in_bank = mouse_x >= bank_x and mouse_x <= bank_x + bank_size and
                          mouse_y >= bank_y and mouse_y <= bank_y + bank_size

    -- Start bank drag on mouse down
    if item_hovered and ImGui.IsMouseClicked(ctx, 0) then
      bank_drag_active = true
      state.setCurrentBank(bank)
    end

    -- While bank drag is active, select bank under cursor
    if bank_drag_active and mouse_in_bank then
      state.setCurrentBank(bank)
    end

    -- When dragging a pad and mouse is over a bank, select it and track as drop target
    if mouse_in_bank and PadGrid.isInternalDragActive() then
      state.setCurrentBank(bank)
      bank_drop_target = bank
    end

    -- Mousewheel to cycle banks when hovering
    if item_hovered then
      local wheel = ImGui.GetMouseWheel(ctx)
      if wheel ~= 0 then
        local new_bank = (current_bank - wheel) % 8  -- Scroll up = previous bank
        if new_bank < 0 then new_bank = new_bank + 8 end
        state.setCurrentBank(new_bank)
      end
    end

    -- Tooltip on hover (but not during any drag)
    if item_hovered and not PadGrid.isInternalDragActive() and not bank_drag_active then
      ImGui.BeginTooltip(ctx)
      local first = bank * 16
      local last = first + 15
      ImGui.Text(ctx, string.format('Bank %d: %s - %s', bank, midi_to_note_name(first), midi_to_note_name(last)))
      ImGui.EndTooltip(ctx)
    end
  end

  -- Handle pad drop on bank selector (when mouse released over a bank)
  local mouse_released = ImGui.IsMouseReleased(ctx, 0)
  if mouse_released and bank_drop_target ~= nil then
    local sources = PadGrid.getDragSources()
    local has_pad_target = PadGrid.hasDragTarget()

    -- Only handle if drag was active and pad_grid won't handle it (no pad target)
    if sources and #sources > 0 and not has_pad_target then
      local target_bank_start = bank_drop_target * 16
      local mods = ImGui.GetKeyMods(ctx)
      local is_copy = (mods & ImGui.Mod_Ctrl) ~= 0

      -- Find first empty slots in target bank (need as many as sources)
      local empty_slots = {}
      for i = 0, 15 do
        local pad_idx = target_bank_start + i
        if not state.hasSample(pad_idx) then
          empty_slots[#empty_slots + 1] = pad_idx
          if #empty_slots >= #sources then break end
        end
      end

      if #empty_slots >= #sources then
        -- Move/copy pads to empty slots
        for i, src in ipairs(sources) do
          local dest = empty_slots[i]
          if is_copy then
            state.copyPad(src, dest)
          else
            state.swapPads(src, dest)
          end
        end
        state.setSelectedPad(empty_slots[1])
        -- Show toast
        local action = is_copy and 'Copied' or 'Moved'
        local msg = #sources == 1
          and string.format('%s pad to Bank %d', action, bank_drop_target)
          or string.format('%s %d pads to Bank %d', action, #sources, bank_drop_target)
        PadGrid.showToast(msg)
      else
        -- Not enough room
        local msg = #sources == 1
          and 'Bank is full - no empty slots'
          or string.format('Bank needs %d empty slots, only %d available', #sources, #empty_slots)
        PadGrid.showToast(msg)
      end

      -- Clear drag state since we handled it
      PadGrid.clearDragState()
    end
  end

  -- Reserve space for the widget (include left padding + right margin for border)
  -- Restore original positions/sizes for layout reservation
  local original_height = total_height + top_offset - bot_offset
  local total_w = left_pad + bank_size + 2  -- Reduced right margin
  ImGui.SetCursorScreenPos(ctx, start_x - left_pad, start_y - v_offset - top_offset)
  ImGui.Dummy(ctx, total_w, original_height)

  return total_w, original_height
end

-- Draw a custom styled container for the pad grid
local function drawGridContainer(ctx, x, y, w, h, is_fold_mode)
  local dl = ImGui.GetWindowDrawList(ctx)

  -- Simple dark background with subtle border
  local bg = 0x0F0F0FFF
  local border = 0x252525FF
  local rounding = 4

  -- Background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, bg, rounding)

  -- Border
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, border, rounding, 0, 1)

  -- Fold mode indicator - subtle colored border
  if is_fold_mode then
    ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, 0x44AACC44, rounding, 0, 1)
  end
end

function M:drawPadSection(ctx)
  local state = self.state
  local current_bank = state.getCurrentBank()
  local first_pad = current_bank * 16
  local last_pad = first_pad + 15

  -- All sizes are FIXED - no responsiveness
  local PAD_SIZE = 90
  local PAD_SPACING = 6

  -- Grid dimensions from layout.lua:
  -- Width = cols * tile_w + (cols + 1) * gap = 4*90 + 5*6 = 390
  -- Height = rows * (tile_h + gap) + gap = 4*(90+6) + 6 = 390
  -- Note: GetContentRegionAvail inside child window may be slightly smaller
  -- due to ImGui window frame/padding, so we add a small buffer
  local grid_w = 4 * PAD_SIZE + 5 * PAD_SPACING  -- 4*90 + 5*6 = 390
  local grid_h = grid_w  -- Square grid

  -- Get available height for the section
  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)

  -- Main content row: Toolbar | Bank selector | Pad grid
  -- Toolbar and bank selector are fixed, grid scrolls in fold mode

  ImGui.BeginGroup(ctx)

  -- Toolbar (vertical buttons) - fixed position
  drawToolbar(ctx, grid_h)

  ImGui.EndGroup(ctx)

  ImGui.SameLine(ctx, 0, 4)

  ImGui.BeginGroup(ctx)

  -- Bank overview (vertical column) - fixed position
  drawBankOverview(ctx, state, grid_h)

  ImGui.EndGroup(ctx)

  ImGui.SameLine(ctx, 0, 4)

  -- Container size matches grid exactly
  local container_w = grid_w
  local container_h = grid_h

  -- Get position for custom container
  local container_x, container_y = ImGui.GetCursorScreenPos(ctx)

  -- Draw custom styled container (background only, grid draws on top)
  drawGridContainer(ctx, container_x, container_y, container_w, container_h, toolbar_state.fold_mode)

  -- Child window flags: no background, and control scrollbars based on mode
  local child_flags = ImGui.WindowFlags_NoBackground
  if not toolbar_state.fold_mode then
    -- Normal mode: disable scrollbars completely (no space reservation)
    child_flags = child_flags + ImGui.WindowFlags_NoScrollbar + ImGui.WindowFlags_NoScrollWithMouse
  end

  -- Remove padding/borders so content region matches child window size exactly
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 0, 0)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, 0, 0)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ChildBorderSize, 0)

  if ImGui.BeginChild(ctx, '##grid_scroll', container_w, container_h, child_flags) then
    -- DEBUG: Uncomment to verify content region size
    -- local inner_w, inner_h = ImGui.GetContentRegionAvail(ctx)
    -- reaper.ShowConsoleMsg(string.format('Grid child: avail=%.0fx%.0f, expected=%.0fx%.0f\n', inner_w, inner_h, container_w, container_h))

    local grid_result = PadGrid.draw(ctx, state, {
      pad_size = PAD_SIZE,
      spacing = PAD_SPACING,
      io_mode = toolbar_state.io_mode,
      fold_mode = toolbar_state.fold_mode,
      choke_mode = toolbar_state.choke_mode,
    })

    -- Store selected indices for multi-pad editing
    self._selected_indices = grid_result and grid_result.selected_indices or {}
  end
  ImGui.EndChild(ctx)
  ImGui.PopStyleVar(ctx, 3)  -- Pop all 3 style vars

  -- Selected pad info (footer)
  local selected = state.getSelectedPad()
  if selected then
    ImGui.Separator(ctx)
    local pad_data = state.getPadData(selected)
    local name = pad_data.name or '(empty)'
    local note_name = midi_to_note_name(selected)
    ImGui.Text(ctx, string.format('Pad %d (%s): %s', selected, note_name, name))
  end
end

-- ============================================================================
-- PAD EDITOR
-- ============================================================================

function M:drawPadEditor(ctx)
  local state = self.state
  local selected = state.getSelectedPad()

  -- Get multi-selection (from grid result)
  local selected_indices = self._selected_indices or {}
  local multi_count = #selected_indices

  -- Set panel dimensions from available space
  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)
  self.pad_editor_panel.width = avail_w
  self.pad_editor_panel.height = avail_h

  -- Draw panel with dotted background
  if not self.pad_editor_panel:begin_draw(ctx) then
    self.pad_editor_panel:end_draw(ctx)
    return
  end

  if not selected then
    ImGui.TextDisabled(ctx, 'Select a pad to edit')
    self.pad_editor_panel:end_draw(ctx)
    return
  end

  -- Multi-selection indicator
  if multi_count > 1 then
    ImGui.TextColored(ctx, 0x88CCFFFF, string.format('%d pads selected (bulk edit)', multi_count))
    ImGui.Separator(ctx)
  end

  -- Helper to apply change to all selected pads
  local function applyToSelected(setter_func)
    if multi_count > 1 then
      for _, idx in ipairs(selected_indices) do
        setter_func(idx)
      end
    else
      setter_func(selected)
    end
  end

  local pad = state.getPadData(selected)
  local has_sample = state.hasSample(selected)

  -- ========================================================================
  -- VELOCITY PANEL (show when V button is active or pad has multi-layer samples)
  -- ========================================================================

  local vel_panel_state = state.getVelocityPanelState()
  local show_vel_panel = toolbar_state.vel_mode or state.hasMultiLayerSamples(selected)

  if show_vel_panel then
    local panel_w = ImGui.GetContentRegionAvail(ctx)
    VelocityPanel.draw(ctx, {
      pad_data = pad,
      pad_index = selected,
      width = panel_w,
      height = 200,
      visible_columns = vel_panel_state.visible_columns or 4,
      get_peaks = function(layer)
        return state.getPadPeaks(selected, layer, 'mini')
      end,
      on_sample_drop = function(layer, path)
        state.setPadSample(selected, layer, path)
      end,
      on_rr_drop = function(layer, path)
        state.addRoundRobinSample(selected, layer, path)
      end,
      on_range_change = function(layer, rr_idx, vel_min, vel_max)
        -- TODO: Send velocity range to VST when custom boundaries are supported
      end,
    })
    ImGui.Spacing(ctx)
  end

  -- ========================================================================
  -- TAB SELECTOR: EDITOR | SLICER
  -- ========================================================================

  local avail_w = ImGui.GetContentRegionAvail(ctx)

  -- Tab colors
  local tab_bg = 0x1A1A1AFF
  local tab_bg_hover = 0x2A2A2AFF
  local tab_bg_active = 0x333333FF
  local tab_text = 0x888888FF
  local tab_text_active = 0xFFFFFFFF
  local tab_accent = 0xDDCC44FF  -- Yellow for slicer

  -- Draw tab bar
  local tab_height = 24
  local tab_width = 80

  ImGui.BeginGroup(ctx)

  -- EDITOR tab
  local editor_active = current_editor_tab == EDITOR_TAB_WAVEFORM
  local editor_hovered = false

  ImGui.PushStyleColor(ctx, ImGui.Col_Button, editor_active and tab_bg_active or tab_bg)
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, tab_bg_hover)
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, tab_bg_active)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, editor_active and tab_text_active or tab_text)

  if ImGui.Button(ctx, 'EDITOR', tab_width, tab_height) then
    current_editor_tab = EDITOR_TAB_WAVEFORM
  end
  editor_hovered = ImGui.IsItemHovered(ctx)

  ImGui.PopStyleColor(ctx, 4)

  ImGui.SameLine(ctx, 0, 0)

  -- SLICER tab
  local slicer_active = current_editor_tab == EDITOR_TAB_SLICER

  ImGui.PushStyleColor(ctx, ImGui.Col_Button, slicer_active and tab_bg_active or tab_bg)
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, tab_bg_hover)
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, tab_bg_active)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, slicer_active and tab_accent or tab_text)

  if ImGui.Button(ctx, 'SLICER', tab_width, tab_height) then
    current_editor_tab = EDITOR_TAB_SLICER
  end

  ImGui.PopStyleColor(ctx, 4)

  ImGui.EndGroup(ctx)

  ImGui.Spacing(ctx)

  -- ========================================================================
  -- SHARED: Sample duration and peaks (needed by both tabs)
  -- ========================================================================

  local waveform_id = 'pad_waveform_' .. selected

  -- Get sample duration first - needed for visible_duration calculation
  local sample_duration = 1.0
  if state.hasDrumBlocks() then
    local dur = Bridge.getSampleDuration(state.getTrack(), state.getFxIndex(), selected, 0)
    if dur and dur > 0 then
      sample_duration = dur
    end
  end
  -- Fallback: get duration from waveform cache (uses REAPER's PCM_Source API)
  if sample_duration <= 1.0 then
    local cache_dur = WaveformCache.getPadDuration(selected, 0)
    if cache_dur and cache_dur > 0 then
      sample_duration = cache_dur
    end
  end

  -- Calculate visible duration for tier selection
  local view_start, view_end = WaveformDisplay.getViewRange(waveform_id)
  local visible_duration = sample_duration * (view_end - view_start)
  -- Use duration-based peak resolution
  local peaks = state.getPadPeaksForEditor(selected, 0, visible_duration)

  -- Waveform color inherits from pad color or default grayscale
  local waveform_color = 0xAAAAAAEE  -- Default grayscale
  local pad_color = state.getPadColor(selected)
  if pad_color then
    -- Use pad color directly, slightly brightened for visibility
    waveform_color = Colors.Lighten(pad_color, 0.2)
  end

  -- Get sample name from pad or derive from file path
  local sample_name = pad.name
  if not sample_name and pad.samples and pad.samples[0] then
    -- Extract filename from path
    sample_name = pad.samples[0]:match('[^/\\]+$') or pad.samples[0]
    -- Remove extension
    sample_name = sample_name:match('(.+)%.[^.]+$') or sample_name
  end

  -- ========================================================================
  -- EDITOR TAB: Waveform Display with Envelope
  -- ========================================================================

  if current_editor_tab == EDITOR_TAB_WAVEFORM then
    -- Get or create envelope for current type
    local envelope_key = current_env_type .. '_envelope'
    local envelope = pad[envelope_key] or WaveformDisplay.getDefaultEnvelope(current_env_type)

    -- Volume envelope is always needed for waveform shaping (even when viewing other envelopes)
    local volume_envelope = pad.volume_envelope or WaveformDisplay.getDefaultEnvelope(WaveformDisplay.ENV_VOLUME)

    -- Get playback progress for this pad (for cursor display)
    local playback_progress = state.getPadPlayProgress(selected)

    local waveform_result = WaveformDisplay.draw(ctx, {
      id = waveform_id,  -- Same ID for all envelope types to share zoom state
      peaks = peaks,
      width = avail_w,
      height = 120,
      volume = pad.volume or 0.8,
      sample_duration = sample_duration,
      env_type = current_env_type,
      show_handles = true,
      waveform_color = waveform_color,
      envelope = envelope,
      volume_envelope = volume_envelope,  -- Always shapes the waveform
      sample_name = sample_name,
      start_point = pad.start_point or 0,
      end_point = pad.end_point or 1,
      playback_mode = pad.playback_mode or WaveformDisplay.PLAY_ONESHOT,
      reverse = pad.reverse or false,
      note_off_mode = pad.note_off_mode or WaveformDisplay.NOTEOFF_IGNORE,
      playback_progress = playback_progress,  -- For playback cursor
      on_envelope_change = function(new_envelope)
        -- Update state (deep copy to avoid reference issues)
        local copy = {}
        for i, pt in ipairs(new_envelope) do
          copy[i] = { x = pt.x, y = pt.y }
        end
        pad[envelope_key] = copy

        -- TODO: Send envelope to VST when supported
      end,
      on_start_end_change = function(start_pt, end_pt)
        -- Update state
        pad.start_point = start_pt
        pad.end_point = end_pt

        -- Send to VST
        if state.hasDrumBlocks() then
          Bridge.setSampleStart(state.getTrack(), state.getFxIndex(), selected, start_pt)
          Bridge.setSampleEnd(state.getTrack(), state.getFxIndex(), selected, end_pt)
        end
      end,
      on_env_type_change = function(new_type)
        current_env_type = new_type
      end,
      on_playback_mode_change = function(new_mode)
        pad.playback_mode = new_mode
        -- Send to VST when supported
        if state.hasDrumBlocks() then
          Bridge.setPlaybackMode(state.getTrack(), state.getFxIndex(), selected, new_mode)
        end
      end,
      on_note_off_mode_change = function(new_mode)
        pad.note_off_mode = new_mode
        -- Send to VST
        if state.hasDrumBlocks() then
          -- Convert waveform display mode to bridge constant
          local mode_map = {
            [WaveformDisplay.NOTEOFF_IGNORE] = Bridge.NoteOffMode.Ignore,
            [WaveformDisplay.NOTEOFF_RELEASE] = Bridge.NoteOffMode.Release,
            [WaveformDisplay.NOTEOFF_CUT] = Bridge.NoteOffMode.Cut,
          }
          Bridge.setNoteOffMode(state.getTrack(), state.getFxIndex(), selected, mode_map[new_mode] or 0)
        end
      end,
      on_reverse_change = function(new_reverse)
        pad.reverse = new_reverse
        -- Send to VST
        if state.hasDrumBlocks() then
          Bridge.setReverse(state.getTrack(), state.getFxIndex(), selected, new_reverse)
        end
      end,
    })
  end

  -- ========================================================================
  -- SLICER TAB: Waveform Slicer
  -- ========================================================================

  if current_editor_tab == EDITOR_TAB_SLICER then
    -- Try to detect BPM from filename
    local detected_bpm = nil
    if pad.samples and pad.samples[0] then
      detected_bpm = TransientDetector.parse_bpm_from_filename(pad.samples[0])
    end

    local slicer_result = WaveformSlicer.draw(ctx, {
      id = 'pad_slicer_' .. selected,
      peaks = peaks,
      width = avail_w,
      height = 140,
      sample_duration = sample_duration,
      sample_name = sample_name,
      waveform_color = waveform_color,
      bpm = detected_bpm or pad.detected_bpm or 120,
      on_distribute = function(slices_to_distribute)
        -- Distribute slices to consecutive pads starting from next available
        local current_bank = state.getCurrentBank()
        local bank_start = current_bank * 16

        -- Find first empty pad in current bank after selected
        local target_idx = selected + 1
        local distributed_count = 0

        for _, slice_data in ipairs(slices_to_distribute) do
          -- Find next empty pad
          while target_idx < bank_start + 16 and state.hasSample(target_idx) do
            target_idx = target_idx + 1
          end

          -- If we ran out of pads in this bank, stop
          if target_idx >= bank_start + 16 then
            break
          end

          -- Copy sample path and set start/end to slice boundaries
          local source_path = pad.samples and pad.samples[0]
          if source_path then
            state.setPadSample(target_idx, 0, source_path)
            local target_pad = state.getPadData(target_idx)
            target_pad.start_point = slice_data.start
            target_pad.end_point = slice_data.stop

            -- Send to VST
            if state.hasDrumBlocks() then
              Bridge.setSampleStart(state.getTrack(), state.getFxIndex(), target_idx, slice_data.start)
              Bridge.setSampleEnd(state.getTrack(), state.getFxIndex(), target_idx, slice_data.stop)
            end

            distributed_count = distributed_count + 1
          end

          target_idx = target_idx + 1
        end

        -- Show feedback
        if distributed_count > 0 then
          PadGrid.showToast(string.format('Distributed %d slices', distributed_count))
        end
      end,
      on_bpm_change = function(new_bpm)
        pad.detected_bpm = new_bpm
      end,
    })

    -- Handle drag-drop from slicer to pad grid
    if slicer_result.drag_payload then
      -- Store for pad grid to pick up
      self._slicer_drag_payload = slicer_result.drag_payload
      self._slicer_source_pad = selected
    else
      self._slicer_drag_payload = nil
    end
  end

  ImGui.Spacing(ctx)

  -- ========================================================================
  -- KNOB SHARED CONFIG (used by multiple sections below)
  -- ========================================================================

  local knob_size = 36
  local knob_spacing = 12

  -- Knob colors
  local knob_bg = 0x151515FF
  local knob_track = 0x333333FF


  -- ========================================================================
  -- LEVEL CONTROLS (Knobs row)
  -- ========================================================================

  local vol_color = 0x44DDDDFF    -- Teal for volume
  local pan_color = 0xFF8833FF    -- Orange for pan
  local tune_color = 0xAA66FFFF   -- Purple for tune
  local filter_color = 0x44AAFFFF -- Blue for filter
  local penv_color = 0xAA66FFFF   -- Purple for pitch env
  local sat_color = 0xFF4444FF    -- Red for saturation
  local trans_color = 0xFFDD44FF  -- Yellow for transient

  -- Format functions
  -- Volume: 0-2 linear (allows +6dB boost), default 1.0 = 0dB
  local function format_volume_db(v)
    if v <= 0 then return '-inf' end
    local db = 20 * math.log(v) / math.log(10)
    if db <= -60 then return '-inf' end
    if db >= 0 then
      return string.format('+%.1fdB', db)
    else
      return string.format('%.1fdB', db)
    end
  end

  local function format_pan(v)
    if math.abs(v) < 0.01 then return 'C' end
    local pct = math.abs(v) * 100
    if v < 0 then
      return string.format('%d%%L', math.floor(pct + 0.5))
    else
      return string.format('%d%%R', math.floor(pct + 0.5))
    end
  end

  local function format_tune(v)
    return string.format('%+.0fst', v)
  end

  -- Get start position for the row
  local row_x, row_y = ImGui.GetCursorScreenPos(ctx)

  -- Volume knob (0-2 linear = -inf to +6dB, default 1.0 = 0dB)
  Ark.Knob(ctx, {
    id = 'vol_knob',
    label = 'Vol',
    value = pad.volume or 1.0,
    min = 0,
    max = 2,
    default = 1.0,
    size = knob_size,
    x = row_x,
    y = row_y,
    variant = 'serum',
    format_func = format_volume_db,
    show_value = false,
    bg_color = knob_bg,
    track_color = knob_track,
    value_color = vol_color,
    label_color = vol_color,
    label_uppercase = true,
    on_change = function(v)
      applyToSelected(function(idx) state.setPadVolume(idx, v) end)
    end,
  })

  -- Pan knob
  Ark.Knob(ctx, {
    id = 'pan_knob',
    label = 'Pan',
    value = pad.pan or 0,
    min = -1,
    max = 1,
    default = 0,
    size = knob_size,
    x = row_x + knob_size + knob_spacing,
    y = row_y,
    variant = 'serum',
    format_func = format_pan,
    show_value = false,
    bg_color = knob_bg,
    track_color = knob_track,
    value_color = pan_color,
    line_color = pan_color,
    label_color = pan_color,
    label_uppercase = true,
    on_change = function(v)
      applyToSelected(function(idx) state.setPadPan(idx, v) end)
    end,
  })

  -- Tune knob
  Ark.Knob(ctx, {
    id = 'tune_knob',
    label = 'Tune',
    value = pad.tune or 0,
    min = -24,
    max = 24,
    default = 0,
    size = knob_size,
    x = row_x + (knob_size + knob_spacing) * 2,
    y = row_y,
    variant = 'serum',
    format_func = format_tune,
    show_value = false,
    bg_color = knob_bg,
    track_color = knob_track,
    value_color = tune_color,
    line_color = tune_color,
    label_color = tune_color,
    label_uppercase = true,
    on_change = function(v)
      applyToSelected(function(idx) state.setPadTune(idx, v) end)
    end,
  })

  -- Move cursor down after knob row (knob + label)

  ImGui.Separator(ctx)

  -- ========================================================================
  -- CARD LAYOUT: Two rows of horizontally aligned cards
  -- Row 1: Filter | Pitch Envelope
  -- Row 2: Saturation | Transient
  -- ========================================================================

  local card_avail_w = ImGui.GetContentRegionAvail(ctx)
  local card_gap = 8
  local card_width = (card_avail_w - card_gap) / 2
  local card_height = 100  -- Fixed height for uniform cards

  -- ========================================================================
  -- ROW 1: FILTER | PITCH ENVELOPE
  -- ========================================================================

  local row1_x, row1_y = ImGui.GetCursorScreenPos(ctx)

  -- FILTER CARD (left)
  if Card.Begin(ctx, { id = 'filter_card', title = 'FILTER', accent_color = filter_color, width = card_width, min_height = card_height }) then
    local filter_x, filter_y = ImGui.GetCursorScreenPos(ctx)

  -- Cutoff: power curve 20Hz-20kHz (less aggressive than pure exponential)
  -- Power of 3 gives good balance: 50% knob ≈ 2.5kHz
  local cutoff_power = 3
  local function cutoff_to_hz(t)
    return 20 + 19980 * (t ^ cutoff_power)
  end
  local function hz_to_cutoff(hz)
    hz = math.max(20, math.min(20000, hz))
    return ((hz - 20) / 19980) ^ (1 / cutoff_power)
  end
  local function format_cutoff(t)
    local hz = cutoff_to_hz(t)
    if hz >= 1000 then
      return string.format('%.1fk', hz / 1000)
    else
      return string.format('%.0f', hz)
    end
  end

  -- Resonance: 0.00 to 1.00 (like FabFilter Volcano)
  local function format_reso(v)
    return string.format('%.2f', v)
  end

  -- Cutoff knob (exponential via normalized value)
  local cutoff_hz = pad.filter_cutoff or 20000
  local cutoff_norm = hz_to_cutoff(cutoff_hz)
  local cutoff_result = Ark.Knob(ctx, {
    id = 'cutoff_knob',
    label = 'Cutoff',
    value = cutoff_norm,
    min = 0,
    max = 1,
    default = 1,  -- 20kHz
    size = knob_size,
    x = filter_x,
    y = filter_y,
    variant = 'serum',
    format_func = format_cutoff,
    show_value = false,
    bg_color = knob_bg,
    track_color = knob_track,
    value_color = filter_color,
    label_color = filter_color,
    label_uppercase = true,
    on_change = function(v)
      local new_hz = cutoff_to_hz(v)
      applyToSelected(function(idx)
        local p = state.getPadData(idx)
        p.filter_cutoff = new_hz
        if state.hasDrumBlocks() then
          Bridge.setFilterCutoff(state.getTrack(), state.getFxIndex(), idx, new_hz)
        end
      end)
    end,
  })

  -- Resonance knob
  local reso = pad.filter_reso or 0
  Ark.Knob(ctx, {
    id = 'reso_knob',
    label = 'Reso',
    value = reso,
    min = 0,
    max = 1,
    default = 0,
    size = knob_size,
    x = filter_x + knob_size + knob_spacing,
    y = filter_y,
    variant = 'serum',
    format_func = format_reso,
    show_value = false,
    bg_color = knob_bg,
    track_color = knob_track,
    value_color = filter_color,
    label_color = filter_color,
    label_uppercase = true,
    on_change = function(v)
      applyToSelected(function(idx)
        local p = state.getPadData(idx)
        p.filter_reso = v
        if state.hasDrumBlocks() then
          Bridge.setFilterReso(state.getTrack(), state.getFxIndex(), idx, v)
        end
      end)
    end,
  })

  -- Move cursor down after knob row (knob + label)
  ImGui.SetCursorScreenPos(ctx, filter_x, filter_y + knob_size + 18)

  -- Filter Type dropdown
  ImGui.Text(ctx, 'Type')
  ImGui.SameLine(ctx)
  ImGui.SetNextItemWidth(ctx, 100)
  local filter_type = pad.filter_type or 0
  local ft_changed, new_ft = ImGui.Combo(ctx, '##filter_type', filter_type, 'Lowpass\000Highpass\000Bandpass\000')
  if ft_changed then
    applyToSelected(function(idx)
      local p = state.getPadData(idx)
      p.filter_type = new_ft
      if state.hasDrumBlocks() then
        Bridge.setFilterType(state.getTrack(), state.getFxIndex(), idx, new_ft)
      end
    end)
  end
  end
  Card.End(ctx)

  -- PITCH ENVELOPE CARD (right side of row 1)
  ImGui.SetCursorScreenPos(ctx, row1_x + card_width + card_gap, row1_y)
  if Card.Begin(ctx, { id = 'penv_card', title = 'PITCH ENV', accent_color = penv_color, width = card_width, min_height = card_height }) then
    local penv_x, penv_y = ImGui.GetCursorScreenPos(ctx)

  local function format_penv_amt(v)
    return string.format('%+.0fst', v)
  end

  local function format_ms(v)
    if v >= 1000 then
      return string.format('%.1fs', v / 1000)
    else
      return string.format('%.0fms', v)
    end
  end

  -- Pitch Env Amount knob
  Ark.Knob(ctx, {
    id = 'penv_amt_knob',
    label = 'Amt',
    value = pad.pitch_env_amount or 0,
    min = -24,
    max = 24,
    default = 0,
    size = knob_size,
    x = penv_x,
    y = penv_y,
    variant = 'serum',
    format_func = format_penv_amt,
    show_value = false,
    bg_color = knob_bg,
    track_color = knob_track,
    value_color = penv_color,
    line_color = penv_color,
    label_color = penv_color,
    label_uppercase = true,
    on_change = function(v)
      applyToSelected(function(idx)
        local p = state.getPadData(idx)
        p.pitch_env_amount = v
        if state.hasDrumBlocks() then
          Bridge.setPitchEnvAmount(state.getTrack(), state.getFxIndex(), idx, v)
        end
      end)
    end,
  })

  -- Pitch Env Attack knob
  Ark.Knob(ctx, {
    id = 'penv_atk_knob',
    label = 'A',
    value = pad.pitch_env_attack or 0,
    min = 0,
    max = 100,
    default = 0,
    size = knob_size,
    x = penv_x + knob_size + knob_spacing,
    y = penv_y,
    variant = 'serum',
    format_func = format_ms,
    show_value = false,
    bg_color = knob_bg,
    track_color = knob_track,
    value_color = penv_color,
    label_color = penv_color,
    label_uppercase = true,
    on_change = function(v)
      applyToSelected(function(idx)
        local p = state.getPadData(idx)
        p.pitch_env_attack = v
        if state.hasDrumBlocks() then
          Bridge.setPitchEnvAttack(state.getTrack(), state.getFxIndex(), idx, v)
        end
      end)
    end,
  })

  -- Pitch Env Decay knob
  Ark.Knob(ctx, {
    id = 'penv_dec_knob',
    label = 'D',
    value = pad.pitch_env_decay or 100,
    min = 0,
    max = 2000,
    default = 100,
    size = knob_size,
    x = penv_x + (knob_size + knob_spacing) * 2,
    y = penv_y,
    variant = 'serum',
    format_func = format_ms,
    show_value = false,
    bg_color = knob_bg,
    track_color = knob_track,
    value_color = penv_color,
    label_color = penv_color,
    label_uppercase = true,
    on_change = function(v)
      applyToSelected(function(idx)
        local p = state.getPadData(idx)
        p.pitch_env_decay = v
        if state.hasDrumBlocks() then
          Bridge.setPitchEnvDecay(state.getTrack(), state.getFxIndex(), idx, v)
        end
      end)
    end,
  })

  -- Pitch Env Sustain knob
  Ark.Knob(ctx, {
    id = 'penv_sus_knob',
    label = 'S',
    value = pad.pitch_env_sustain or 0,
    min = 0,
    max = 1,
    default = 0,
    size = knob_size,
    x = penv_x + (knob_size + knob_spacing) * 3,
    y = penv_y,
    variant = 'serum',
    format_func = function(v) return string.format('%.0f%%', v * 100) end,
    show_value = false,
    bg_color = knob_bg,
    track_color = knob_track,
    value_color = penv_color,
    label_color = penv_color,
    label_uppercase = true,
    on_change = function(v)
      applyToSelected(function(idx)
        local p = state.getPadData(idx)
        p.pitch_env_sustain = v
        if state.hasDrumBlocks() then
          Bridge.setPitchEnvSustain(state.getTrack(), state.getFxIndex(), idx, v)
        end
      end)
    end,
  })

  -- Move cursor down after knob row (knob + label)
  ImGui.SetCursorScreenPos(ctx, penv_x, penv_y + knob_size + 18)
  end
  Card.End(ctx)

  -- ========================================================================
  -- ROW 2: SATURATION | TRANSIENT
  -- ========================================================================

  -- Move to row 2 (below the taller of the two row 1 cards)
  local row2_x, row2_y = ImGui.GetCursorScreenPos(ctx)
  row2_y = row2_y + 4  -- Small gap between rows

  -- SATURATION CARD (left)
  ImGui.SetCursorScreenPos(ctx, row2_x, row2_y)
  if Card.Begin(ctx, { id = 'sat_card', title = 'SATURATION', accent_color = sat_color, width = card_width, min_height = card_height }) then
    ImGui.SetNextItemWidth(ctx, 80)
    local sat_type = pad.saturation_type or 0
    local sat_changed, new_sat = ImGui.Combo(ctx, '##sat_type', sat_type, 'Soft\000Hard\000Tube\000Tape\000Fold\000Crush\000')
  if sat_changed then
    applyToSelected(function(idx)
      local p = state.getPadData(idx)
      p.saturation_type = new_sat
      if state.hasDrumBlocks() then
        Bridge.setSaturationType(state.getTrack(), state.getFxIndex(), idx, new_sat)
      end
    end)
  end
  ImGui.Spacing(ctx)

  local sat_x, sat_y = ImGui.GetCursorScreenPos(ctx)

  -- Saturation Drive knob
  Ark.Knob(ctx, {
    id = 'sat_drive_knob',
    label = 'Drive',
    value = pad.saturation_drive or 0,
    min = 0,
    max = 1,
    default = 0,
    size = knob_size,
    x = sat_x,
    y = sat_y,
    variant = 'serum',
    format_func = function(v) return string.format('%.0f%%', v * 100) end,
    show_value = false,
    bg_color = knob_bg,
    track_color = knob_track,
    value_color = sat_color,
    label_color = sat_color,
    label_uppercase = true,
    on_change = function(v)
      applyToSelected(function(idx)
        local p = state.getPadData(idx)
        p.saturation_drive = v
        if state.hasDrumBlocks() then
          Bridge.setSaturationDrive(state.getTrack(), state.getFxIndex(), idx, v)
        end
      end)
    end,
  })

  -- Saturation Mix knob
  Ark.Knob(ctx, {
    id = 'sat_mix_knob',
    label = 'Mix',
    value = pad.saturation_mix or 1,
    min = 0,
    max = 1,
    default = 1,
    size = knob_size,
    x = sat_x + knob_size + knob_spacing,
    y = sat_y,
    variant = 'serum',
    format_func = function(v) return string.format('%.0f%%', v * 100) end,
    show_value = false,
    bg_color = knob_bg,
    track_color = knob_track,
    value_color = sat_color,
    label_color = sat_color,
    label_uppercase = true,
    on_change = function(v)
      applyToSelected(function(idx)
        local p = state.getPadData(idx)
        p.saturation_mix = v
        if state.hasDrumBlocks() then
          Bridge.setSaturationMix(state.getTrack(), state.getFxIndex(), idx, v)
        end
      end)
    end,
  })

  -- Move cursor down after knob row (knob + label)
  ImGui.SetCursorScreenPos(ctx, sat_x, sat_y + knob_size + 18)
  end
  Card.End(ctx)

  -- TRANSIENT CARD (right side of row 2)
  ImGui.SetCursorScreenPos(ctx, row2_x + card_width + card_gap, row2_y)
  if Card.Begin(ctx, { id = 'trans_card', title = 'TRANSIENT', accent_color = trans_color, width = card_width, min_height = card_height }) then
    local trans_x, trans_y = ImGui.GetCursorScreenPos(ctx)

  -- Transient Attack knob
  Ark.Knob(ctx, {
    id = 'trans_atk_knob',
    label = 'Attack',
    value = pad.transient_attack or 0,
    min = -1,
    max = 1,
    default = 0,
    size = knob_size,
    x = trans_x,
    y = trans_y,
    variant = 'serum',
    format_func = function(v) return string.format('%+.0f%%', v * 100) end,
    show_value = false,
    bg_color = knob_bg,
    track_color = knob_track,
    value_color = trans_color,
    line_color = trans_color,
    label_color = trans_color,
    label_uppercase = true,
    on_change = function(v)
      applyToSelected(function(idx)
        local p = state.getPadData(idx)
        p.transient_attack = v
        if state.hasDrumBlocks() then
          Bridge.setTransientAttack(state.getTrack(), state.getFxIndex(), idx, v)
        end
      end)
    end,
  })

  -- Transient Sustain knob
  Ark.Knob(ctx, {
    id = 'trans_sus_knob',
    label = 'Sustain',
    value = pad.transient_sustain or 0,
    min = -1,
    max = 1,
    default = 0,
    size = knob_size,
    x = trans_x + knob_size + knob_spacing,
    y = trans_y,
    variant = 'serum',
    format_func = function(v) return string.format('%+.0f%%', v * 100) end,
    show_value = false,
    bg_color = knob_bg,
    track_color = knob_track,
    value_color = trans_color,
    line_color = trans_color,
    label_color = trans_color,
    label_uppercase = true,
    on_change = function(v)
      applyToSelected(function(idx)
        local p = state.getPadData(idx)
        p.transient_sustain = v
        if state.hasDrumBlocks() then
          Bridge.setTransientSustain(state.getTrack(), state.getFxIndex(), idx, v)
        end
      end)
    end,
  })

  -- Move cursor down after knob row (knob + label)
  ImGui.SetCursorScreenPos(ctx, trans_x, trans_y + knob_size + 18)
  end
  Card.End(ctx)

  -- Ensure cursor is below both row 2 cards
  local final_y = row2_y + card_height + 8
  ImGui.SetCursorScreenPos(ctx, row2_x, final_y)

  -- ========================================================================
  -- TIME-STRETCH (via REAPER glue - fast, cached)
  -- ========================================================================

  ImGui.Text(ctx, 'Time Stretch')
  ImGui.Spacing(ctx)

  -- Get current stretch state
  local stretch_ratio = pad.stretch_ratio or 1.0
  local pitch_preserve = pad.pitch_preserve ~= false  -- Default true
  local pitch_mode = pad.pitch_mode or Bridge.PitchMode.ElastiquePro
  local has_sample = pad.samples and pad.samples[0] and pad.samples[0] ~= ''

  -- Track pending stretch value per pad
  self._stretch_pending = self._stretch_pending or {}
  local pending = self._stretch_pending[selected]
  local display_ratio = pending and pending.ratio or stretch_ratio
  local display_pct = display_ratio * 100

  -- Convert ratio to semitones: semitones = 12 * log2(ratio)
  -- 200% = +12st (octave down, slower), 50% = -12st (octave up, faster)
  -- This way both sliders move in same direction (right = longer/slower)
  local log2 = function(x) return math.log(x) / math.log(2) end
  local display_semitones = 12 * log2(display_ratio)

  -- Helper to update pending with new ratio
  local function updatePendingRatio(new_ratio)
    self._stretch_pending[selected] = {
      ratio = new_ratio,
      pitch_preserve = pending and pending.pitch_preserve or pitch_preserve,
      pitch_mode = pending and pending.pitch_mode or pitch_mode,
    }
    pending = self._stretch_pending[selected]
  end

  -- Stretch slider (as percentage: 100% = normal)
  ImGui.SetNextItemWidth(ctx, 70)

  Ark.BeginDisabled(ctx, not has_sample)
  local stretch_changed, new_stretch_pct = ImGui.SliderDouble(ctx, '##stretch_pct', display_pct, 25, 400, '%.0f%%')
  if stretch_changed then
    updatePendingRatio(new_stretch_pct / 100)
  end
  Ark.EndDisabled(ctx)

  if ImGui.IsItemHovered(ctx) then
    ImGui.BeginTooltip(ctx)
    ImGui.Text(ctx, 'Stretch ratio (duration)')
    ImGui.Text(ctx, '100% = normal, 200% = 2x longer')
    ImGui.EndTooltip(ctx)
  end

  ImGui.SameLine(ctx)
  ImGui.TextDisabled(ctx, '=')
  ImGui.SameLine(ctx)

  -- Semitones input (linked to stretch %)
  -- Range: -24 to +24 semitones (matches 25% to 400% stretch)
  -- Shift+drag snaps to whole semitones
  local shift_held = ImGui.IsKeyDown(ctx, ImGui.Mod_Shift)
  local snap_semitones = shift_held and math.floor(display_semitones + 0.5) or display_semitones

  ImGui.SetNextItemWidth(ctx, 70)
  Ark.BeginDisabled(ctx, not has_sample)
  local semi_changed, new_semitones = ImGui.SliderDouble(ctx, '##stretch_semi', snap_semitones, -24, 24, shift_held and '%.0f st' or '%.1f st')
  if semi_changed then
    -- Snap to whole semitones if shift held
    if shift_held then
      new_semitones = math.floor(new_semitones + 0.5)
    end
    -- Convert semitones back to ratio: ratio = 2^(semitones/12)
    local new_ratio = 2 ^ (new_semitones / 12)
    -- Clamp to valid range
    new_ratio = math.max(0.25, math.min(4.0, new_ratio))
    updatePendingRatio(new_ratio)
  end
  Ark.EndDisabled(ctx)

  if ImGui.IsItemHovered(ctx) then
    ImGui.BeginTooltip(ctx)
    ImGui.Text(ctx, 'Pitch shift (without preserve pitch)')
    ImGui.Text(ctx, '+12 = octave down (slower)')
    ImGui.Text(ctx, '-12 = octave up (faster)')
    ImGui.Spacing(ctx)
    ImGui.TextDisabled(ctx, 'Shift+drag to snap to semitones')
    ImGui.EndTooltip(ctx)
  end

  ImGui.SameLine(ctx)

  -- Algorithm dropdown
  local display_mode = pending and pending.pitch_mode or pitch_mode
  local mode_idx = 0
  local mode_names = {}
  for i, m in ipairs(Bridge.PitchModeList) do
    mode_names[i] = m.name
    if m.value == display_mode then
      mode_idx = i - 1  -- 0-indexed
    end
  end
  local mode_combo_str = table.concat(mode_names, '\0') .. '\0'

  ImGui.SetNextItemWidth(ctx, 130)
  Ark.BeginDisabled(ctx, not has_sample)
  local mode_changed, new_mode_idx = ImGui.Combo(ctx, '##stretch_algo', mode_idx, mode_combo_str)
  if mode_changed then
    local new_mode = Bridge.PitchModeList[new_mode_idx + 1].value
    if pending then
      pending.pitch_mode = new_mode
    else
      self._stretch_pending[selected] = {
        ratio = stretch_ratio,
        pitch_preserve = pitch_preserve,
        pitch_mode = new_mode,
      }
      pending = self._stretch_pending[selected]
    end
  end
  Ark.EndDisabled(ctx)

  ImGui.SameLine(ctx)

  -- Preserve pitch checkbox
  local display_pitch = pending and pending.pitch_preserve or pitch_preserve
  Ark.BeginDisabled(ctx, not has_sample)
  local pitch_changed, new_pitch = ImGui.Checkbox(ctx, 'Preserve Pitch', display_pitch)
  if pitch_changed then
    if pending then
      pending.pitch_preserve = new_pitch
    else
      pad.pitch_preserve = new_pitch
    end
  end
  Ark.EndDisabled(ctx)

  -- Second row: Apply and Reset buttons
  local has_pending = pending and (
    math.abs(pending.ratio - stretch_ratio) > 0.01 or
    pending.pitch_mode ~= pitch_mode or
    pending.pitch_preserve ~= pitch_preserve
  )

  Ark.BeginDisabled(ctx, not has_sample or not has_pending)
  if Ark.Button(ctx, 'Apply Stretch', 90) then
    state.setPadStretch(selected, pending.ratio, pending.pitch_preserve, pending.pitch_mode)
    self._stretch_pending[selected] = nil
  end
  Ark.EndDisabled(ctx)

  -- Reset button (only show if currently stretched)
  if math.abs(stretch_ratio - 1.0) > 0.01 then
    ImGui.SameLine(ctx)
    if Ark.Button(ctx, 'Reset', 50) then
      state.setPadStretch(selected, 1.0, pitch_preserve, pitch_mode)
      self._stretch_pending[selected] = nil
    end
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

  -- Output (1-16 stereo)
  ImGui.Text(ctx, 'Output')
  ImGui.SetNextItemWidth(ctx, -1)
  local out_items = ''
  for i = 1, 16 do
    out_items = out_items .. i .. '\000'
  end
  local out_changed, out = ImGui.Combo(ctx, '##outgroup', pad.output_group or 0, out_items)
  if out_changed then
    state.setPadOutputGroup(selected, out)
  end

  ImGui.Separator(ctx)

  -- Reverse playback option (playback mode is controlled via waveform buttons)
  local reverse = pad.reverse or false
  local reverse_changed, new_reverse = ImGui.Checkbox(ctx, 'Reverse', reverse)
  if reverse_changed then
    pad.reverse = new_reverse
    if state.hasDrumBlocks() then
      Bridge.setReverse(state.getTrack(), state.getFxIndex(), selected, new_reverse)
    end
  end

  ImGui.Separator(ctx)

  -- Trigger button for testing
  if Ark.Button(ctx, 'Trigger Pad', -1) then
    if state.hasDrumBlocks() then
      Bridge.previewPad(state.getTrack(), state.getFxIndex(), selected, 100)
    end
  end

  -- End panel
  self.pad_editor_panel:end_draw(ctx)
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

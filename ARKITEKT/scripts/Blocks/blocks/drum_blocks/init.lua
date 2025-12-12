-- @noindex
-- Blocks/blocks/drum_blocks/init.lua
-- DrumBlocks component - 128-pad drum sampler using DrumBlocks VST
-- Works standalone OR as a Blocks component with ItemPicker integration

local Shell = require('arkitekt.runtime.shell')

-- Setup package.path to find DrumBlocks and ItemPicker modules
local function setup_paths()
  local source = debug.getinfo(1, 'S').source:sub(2)
  local scripts_path = source:match('(.-scripts[/\\])')
  if scripts_path and not package.path:find(scripts_path, 1, true) then
    local sep = package.config:sub(1, 1)
    package.path = scripts_path .. '?.lua;' .. scripts_path .. '?' .. sep .. 'init.lua;' .. package.path
  end
end
setup_paths()

-- Lazy-loaded dependencies
local Ark, ImGui
local Bridge
local ADSRWidget
local ItemPickerState  -- For cross-block drag detection

-- Component state
local state = {
  initialized = false,
  track = nil,
  fx_index = nil,
  current_bank = 0,
  selected_pad = nil,
  pads = {},  -- [pad_index] = { name, volume, pan, tune, ... }
  grid_panel = nil,

  -- Drag-drop tracking (for ItemPicker integration)
  drop_target_pad = nil,
  last_drop_target_pad = nil,
  was_mouse_down = false,
  was_dragging = false,
  cached_item_data = nil,
  cached_uuid = nil,

  -- Context menu
  context_pad = nil,
  open_context_menu = false,
}

-- Constants
local NUM_PADS = 128
local PADS_PER_BANK = 16
local NUM_BANKS = 8
local GRID_COLS = 4
local GRID_ROWS = 4
local PAD_SIZE = 70
local PAD_SPACING = 5

local COLORS = {
  pad_empty = 0x2A2A2AFF,
  pad_loaded = 0x3A3A5AFF,
  pad_selected = 0x5A5A8AFF,
  pad_hover = 0x4A4A6AFF,
  pad_drop_target = 0x6A8A6AFF,
  pad_border = 0x555555FF,
  pad_border_selected = 0x8888CCFF,
  text = 0xFFFFFFFF,
  text_dim = 0x888888FF,
  velocity_bar = 0x88AA88FF,
  velocity_bg = 0x00000066,
}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local function ensure_deps()
  if Ark then return end

  Ark = require('arkitekt')
  ImGui = Ark.ImGui
  Bridge = require('DrumBlocks.domain.bridge')
  ADSRWidget = require('DrumBlocks.widgets.adsr')

  -- Try to load ItemPickerState for cross-block drag-drop
  local ok, ip_state = pcall(require, 'ItemPicker.app.state')
  if ok then
    ItemPickerState = ip_state
  end
end

local function create_empty_pad()
  return {
    samples = {},
    name = nil,
    volume = 0.8,
    pan = 0,
    tune = 0,
    attack = 0,
    decay = 100,
    sustain = 1,
    release = 200,
    filter_cutoff = 20000,
    filter_reso = 0,
    kill_group = 0,
    output_group = 0,
    one_shot = true,
    reverse = false,
  }
end

local function init_state()
  if state.initialized then return end

  for i = 0, NUM_PADS - 1 do
    state.pads[i] = create_empty_pad()
  end

  state.initialized = true
end

-- ============================================================================
-- TRACK MANAGEMENT
-- ============================================================================

local function refresh_track()
  state.track = reaper.GetSelectedTrack(0, 0)
  if state.track then
    state.fx_index = Bridge.findDrumBlocks(state.track)
  else
    state.fx_index = nil
  end
end

local function has_drum_blocks()
  return state.track ~= nil and state.fx_index ~= nil
end

local function insert_drum_blocks()
  if not state.track then
    state.track = reaper.GetSelectedTrack(0, 0)
  end
  if state.track then
    state.fx_index = Bridge.insertDrumBlocks(state.track)
    return state.fx_index ~= nil
  end
  return false
end

-- ============================================================================
-- PAD HELPERS
-- ============================================================================

local function get_pad_index_for_grid(row, col)
  return state.current_bank * PADS_PER_BANK + row * GRID_COLS + col
end

local function has_sample(pad_index)
  local pad = state.pads[pad_index]
  return pad and pad.name ~= nil
end

local function set_pad_sample(pad_index, layer, file_path)
  local pad = state.pads[pad_index]
  if not pad then
    pad = create_empty_pad()
    state.pads[pad_index] = pad
  end

  pad.samples[layer] = file_path

  if file_path and file_path ~= '' then
    local name = file_path:match('([^/\\]+)$')
    name = name:match('(.+)%.[^.]+$') or name
    pad.name = name
  else
    pad.name = nil
  end

  if has_drum_blocks() then
    Bridge.loadSample(state.track, state.fx_index, pad_index, layer, file_path or '')
  end
end

-- ============================================================================
-- ITEMPICKER INTEGRATION
-- ============================================================================

local function is_itempicker_dragging_audio()
  if not ItemPickerState then return false end
  return ItemPickerState.dragging == true and ItemPickerState.dragging_is_audio == true
end

local function get_dragged_sample()
  if not ItemPickerState or not ItemPickerState.dragging_keys then
    return nil, nil
  end

  local uuid = ItemPickerState.dragging_keys[1]
  if not uuid then return nil, nil end

  local item_data = ItemPickerState.audio_item_lookup and ItemPickerState.audio_item_lookup[uuid]
  return item_data, uuid
end

local function get_source_path(media_item)
  if not media_item or not reaper.ValidatePtr2(0, media_item, 'MediaItem*') then
    return nil
  end

  local take = reaper.GetActiveTake(media_item)
  if not take then return nil end

  local source = reaper.GetMediaItemTake_Source(take)

  if reaper.BR_GetMediaSourceProperties then
    local _, _, _, _, _, reverse = reaper.BR_GetMediaSourceProperties(take)
    if reverse and source then
      local parent = reaper.GetMediaSourceParent(source)
      if parent then source = parent end
    end
  end

  if source then
    return reaper.GetMediaSourceFileName(source) or ''
  end

  return nil
end

-- ============================================================================
-- PAD RENDERING
-- ============================================================================

local function draw_pad(ctx, dl, x, y, size, pad_index, pad, is_selected, is_hovered, is_drop_target)
  local rounding = 5

  local bg_color = COLORS.pad_empty
  if pad.name then bg_color = COLORS.pad_loaded end
  if is_hovered then bg_color = COLORS.pad_hover end
  if is_selected then bg_color = COLORS.pad_selected end
  if is_drop_target then bg_color = COLORS.pad_drop_target end

  -- Shadow
  if pad.name then
    ImGui.DrawList_AddRectFilled(dl, x + 2, y + 2, x + size + 2, y + size + 2, 0x00000044, rounding)
  end

  -- Background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + size, y + size, bg_color, rounding)

  -- Velocity bar
  if pad.name then
    local bar_h = 3
    local bar_y = y + size - bar_h - 3
    local bar_w = (size - 6) * (pad.volume or 0.8)
    ImGui.DrawList_AddRectFilled(dl, x + 3, bar_y, x + size - 3, bar_y + bar_h, COLORS.velocity_bg, 2)
    ImGui.DrawList_AddRectFilled(dl, x + 3, bar_y, x + 3 + bar_w, bar_y + bar_h, COLORS.velocity_bar, 2)
  end

  -- Border
  local border_color = is_selected and COLORS.pad_border_selected or COLORS.pad_border
  ImGui.DrawList_AddRect(dl, x, y, x + size, y + size, border_color, rounding, 0, is_selected and 2 or 1)

  -- Pad number
  local pad_num = string.format('%d', (pad_index % 16) + 1)
  ImGui.DrawList_AddText(dl, x + 4, y + 2, COLORS.text_dim, pad_num)

  -- Note badge
  local note = 36 + (pad_index % 128)
  local note_text = tostring(note)
  local note_w = ImGui.CalcTextSize(ctx, note_text)
  ImGui.DrawList_AddRectFilled(dl, x + size - note_w - 8, y + 2, x + size - 2, y + 14, 0x00000066, 3)
  ImGui.DrawList_AddText(dl, x + size - note_w - 6, y + 2, COLORS.text_dim, note_text)

  -- Sample name
  if pad.name then
    local name = pad.name
    if #name > 10 then name = name:sub(1, 9) .. '..' end
    local text_w = ImGui.CalcTextSize(ctx, name)
    local text_x = x + (size - text_w) / 2
    ImGui.DrawList_AddText(dl, text_x + 1, y + size - 16, 0x000000AA, name)
    ImGui.DrawList_AddText(dl, text_x, y + size - 17, COLORS.text, name)
  end
end

-- ============================================================================
-- CONTEXT MENU
-- ============================================================================

local function draw_context_menu(ctx, pad_index)
  if not ImGui.BeginPopup(ctx, 'drumblocks_pad_menu') then return end

  local pad = state.pads[pad_index]
  local has_samp = has_sample(pad_index)

  if ImGui.MenuItem(ctx, 'Preview', nil, false, has_samp and has_drum_blocks()) then
    Bridge.previewPad(state.track, state.fx_index, pad_index, 100)
  end

  ImGui.Separator(ctx)

  if ImGui.MenuItem(ctx, 'Load Sample...') then
    local retval, filename = reaper.GetUserFileNameForRead('', 'Load Sample', 'wav;mp3;ogg;flac;aif;aiff')
    if retval and filename ~= '' then
      set_pad_sample(pad_index, 0, filename)
    end
  end

  if ImGui.MenuItem(ctx, 'Clear Sample', nil, false, has_samp) then
    set_pad_sample(pad_index, 0, '')
  end

  ImGui.Separator(ctx)

  -- Kill group
  if ImGui.BeginMenu(ctx, 'Kill Group') then
    local current_kg = pad.kill_group or 0
    if ImGui.MenuItem(ctx, 'None', nil, current_kg == 0) then
      pad.kill_group = 0
      if has_drum_blocks() then Bridge.setKillGroup(state.track, state.fx_index, pad_index, 0) end
    end
    ImGui.Separator(ctx)
    for g = 1, 8 do
      if ImGui.MenuItem(ctx, 'Group ' .. g, nil, current_kg == g) then
        pad.kill_group = g
        if has_drum_blocks() then Bridge.setKillGroup(state.track, state.fx_index, pad_index, g) end
      end
    end
    ImGui.EndMenu(ctx)
  end

  -- 808 Presets
  if ImGui.BeginMenu(ctx, '808 Presets', has_samp and has_drum_blocks()) then
    local presets = {
      { 'Kick 808', Bridge.Presets.Kick808 },
      { 'Sub Kick 808', Bridge.Presets.SubKick808 },
      { 'Snare 808', Bridge.Presets.Snare808 },
      { 'HiHat 808', Bridge.Presets.HiHat808 },
      { 'Clap 808', Bridge.Presets.Clap808 },
    }
    for _, p in ipairs(presets) do
      if ImGui.MenuItem(ctx, p[1]) then
        Bridge.applyPreset(state.track, state.fx_index, pad_index, p[2])
      end
    end
    ImGui.EndMenu(ctx)
  end

  ImGui.EndPopup(ctx)
end

-- ============================================================================
-- MAIN DRAW
-- ============================================================================

local function draw_content(ctx)
  ensure_deps()
  init_state()

  -- Check track
  local current_track = reaper.GetSelectedTrack(0, 0)
  if current_track ~= state.track then
    refresh_track()
  end

  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)

  -- Header
  if has_drum_blocks() then
    ImGui.TextColored(ctx, 0x88FF88FF, 'DrumBlocks VST: Connected')
  else
    ImGui.TextColored(ctx, 0xFF8888FF, 'DrumBlocks VST: Not Found')
    ImGui.SameLine(ctx)
    if Ark.Button(ctx, 'Insert') then
      insert_drum_blocks()
    end
  end

  -- Bank selector
  ImGui.SameLine(ctx)
  ImGui.Dummy(ctx, 20, 0)
  ImGui.SameLine(ctx)
  ImGui.Text(ctx, 'Bank:')
  ImGui.SameLine(ctx)

  for bank = 0, NUM_BANKS - 1 do
    if bank > 0 then ImGui.SameLine(ctx) end
    local label = string.char(65 + bank)
    local is_current = (bank == state.current_bank)
    if is_current then ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0x6666AAFF) end
    if Ark.Button(ctx, label, 22) then state.current_bank = bank end
    if is_current then ImGui.PopStyleColor(ctx) end
  end

  ImGui.Separator(ctx)

  -- Track drag state
  local dragging = is_itempicker_dragging_audio()
  local mouse_down = ImGui.IsMouseDown(ctx, 0)
  local just_dropped = state.was_dragging and state.was_mouse_down and not mouse_down

  if dragging and mouse_down then
    state.last_drop_target_pad = state.drop_target_pad
    state.cached_item_data, state.cached_uuid = get_dragged_sample()
  end

  state.was_mouse_down = mouse_down
  state.was_dragging = dragging
  state.drop_target_pad = nil

  -- Pad grid
  local grid_w = GRID_COLS * (PAD_SIZE + PAD_SPACING) - PAD_SPACING
  local grid_h = GRID_ROWS * (PAD_SIZE + PAD_SPACING) - PAD_SPACING

  local start_x, start_y = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)

  for row = 0, GRID_ROWS - 1 do
    for col = 0, GRID_COLS - 1 do
      local pad_index = get_pad_index_for_grid(row, col)
      local pad = state.pads[pad_index] or create_empty_pad()

      local x = start_x + col * (PAD_SIZE + PAD_SPACING)
      local y = start_y + row * (PAD_SIZE + PAD_SPACING)

      ImGui.SetCursorScreenPos(ctx, x, y)
      local clicked = ImGui.InvisibleButton(ctx, '##pad_' .. pad_index, PAD_SIZE, PAD_SIZE)
      local hovered = ImGui.IsItemHovered(ctx)
      local right_clicked = ImGui.IsItemClicked(ctx, 1)

      local is_drop_target = dragging and hovered
      if is_drop_target then state.drop_target_pad = pad_index end

      draw_pad(ctx, dl, x, y, PAD_SIZE, pad_index, pad, pad_index == state.selected_pad, hovered, is_drop_target)

      if clicked then
        state.selected_pad = pad_index
        if has_sample(pad_index) and has_drum_blocks() then
          Bridge.previewPad(state.track, state.fx_index, pad_index, 100)
        end
      end

      if right_clicked then
        state.context_pad = pad_index
        state.open_context_menu = true
      end
    end
  end

  -- Handle ItemPicker drop
  if just_dropped and state.last_drop_target_pad and state.cached_item_data then
    local source_path = get_source_path(state.cached_item_data[1])
    if source_path and source_path ~= '' then
      set_pad_sample(state.last_drop_target_pad, 0, source_path)
      local pad = state.pads[state.last_drop_target_pad]
      if pad then pad.uuid = state.cached_uuid end
    end
    state.last_drop_target_pad = nil
    state.cached_item_data = nil
    state.cached_uuid = nil
  end

  -- Context menu
  if state.open_context_menu then
    ImGui.OpenPopup(ctx, 'drumblocks_pad_menu')
    state.open_context_menu = false
  end
  if state.context_pad then
    draw_context_menu(ctx, state.context_pad)
  end

  -- Reserve grid space
  ImGui.SetCursorScreenPos(ctx, start_x, start_y)
  ImGui.Dummy(ctx, grid_w, grid_h)

  -- Selected pad info
  if state.selected_pad then
    ImGui.Separator(ctx)
    local pad = state.pads[state.selected_pad]
    local name = pad and pad.name or '(empty)'
    ImGui.Text(ctx, string.format('Pad %d: %s', (state.selected_pad % 16) + 1, name))
  end

  ImGui.Spacing(ctx)
  ImGui.TextDisabled(ctx, 'Drag audio from Browser tab to load samples')
end

-- ============================================================================
-- ENTRY POINT
-- ============================================================================

return Shell.run({
  title = 'DrumBlocks',
  version = 'v0.1.0',
  initial_size = { w = 400, h = 420 },
  min_size = { w = 320, h = 350 },

  draw = function(ctx, shell_state)
    draw_content(ctx)
  end,

  on_close = function()
    state.initialized = false
    state.pads = {}
    state.selected_pad = nil
    state.grid_panel = nil
    state.drop_target_pad = nil
    state.last_drop_target_pad = nil
    state.cached_item_data = nil
    state.cached_uuid = nil
  end,
})

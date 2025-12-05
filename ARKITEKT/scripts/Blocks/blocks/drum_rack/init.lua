-- @noindex
-- Blocks/blocks/drum_rack/init.lua
-- Drum rack component using Ark.Grid for responsive pad layout

local Shell = require('arkitekt.runtime.shell')

-- Setup package.path to find ItemPicker modules (for cross-block drag-drop)
local function setup_itempicker_paths()
  local source = debug.getinfo(1, 'S').source:sub(2)
  local scripts_path = source:match('(.-scripts[/\\])')
  if scripts_path and not package.path:find(scripts_path, 1, true) then
    local sep = package.config:sub(1, 1)
    package.path = scripts_path .. '?.lua;' .. scripts_path .. '?' .. sep .. 'init.lua;' .. package.path
  end
end
setup_itempicker_paths()

-- Lazy-loaded dependencies
local Ark, ImGui
local PadRenderer
local TileAnimator
local ItemPickerState  -- For cross-block drag detection
local Visualization  -- For waveform rendering
local RS5KManager  -- For REAPER track/FX operations
local ADSRWidget  -- For envelope display
local KitManager  -- For kit save/load

-- Configuration
local CONFIG = {
  pad_count = 16,
  cols = 4,
  gap = 8,
  min_pad_size = 70,
  fixed_pad_size = 80,
  base_note = 36,  -- C1 = 36, can change for different controllers
}

-- Common base note presets
local NOTE_PRESETS = {
  { name = 'C1 (36) - GM Drums', note = 36 },
  { name = 'C2 (48) - Kontakt', note = 48 },
  { name = 'C3 (60) - Middle C', note = 60 },
  { name = 'C0 (24) - Low', note = 24 },
}

-- Component state
local state = {
  pads = {},
  selected_pad = nil,
  initialized = false,
  grid_panel = nil,  -- Ark.Panel for grid container
  drop_target_pad = nil,  -- Pad being hovered during drag (for drop handling)
  last_drop_target_pad = nil,  -- Pad that was hovered last frame (for drop detection)
  was_mouse_down = false,  -- Track if mouse was down last frame (for drop detection)
  was_dragging_from_itempicker = false,  -- Track if dragging last frame (ItemPicker clears state on release)
  cached_item_data = nil,  -- Cached item data during drag
  cached_uuid = nil,  -- Cached UUID during drag
  parent_track = nil,  -- Parent drum rack track
  rs5k_initialized = false,  -- Whether RS5K structure exists
  context_pad = nil,  -- Pad for context menu
  open_context_menu = false,  -- Flag to open context menu
}

-- Mock pad data
local MOCK_PADS = {
  { name = 'Kick', note = 36, color = 0xD94A4AFF, has_sample = true, volume = 0.9 },
  { name = 'Snare', note = 38, color = 0xD9884AFF, has_sample = true, volume = 0.85 },
  { name = 'Clap', note = 39, color = 0xD9C84AFF, has_sample = true, volume = 0.75 },
  { name = 'HH Closed', note = 42, color = 0x88D94AFF, has_sample = true, volume = 0.6 },
  { name = 'Tom Low', note = 43, color = 0x4AD988FF, has_sample = false, volume = 1.0 },
  { name = 'HH Open', note = 46, color = 0x4AD9D9FF, has_sample = true, volume = 0.7 },
  { name = 'Tom Mid', note = 47, color = 0x4A88D9FF, has_sample = false, volume = 1.0 },
  { name = 'Tom High', note = 48, color = 0x884AD9FF, has_sample = false, volume = 1.0 },
  { name = 'Crash', note = 49, color = 0xD94AD9FF, has_sample = true, volume = 0.8 },
  { name = 'Ride', note = 51, color = 0xD94A88FF, has_sample = false, volume = 1.0 },
  { name = '', note = 52, color = 0x505050FF, has_sample = false, volume = 1.0 },
  { name = '', note = 53, color = 0x505050FF, has_sample = false, volume = 1.0 },
  { name = '', note = 54, color = 0x505050FF, has_sample = false, volume = 1.0 },
  { name = '', note = 55, color = 0x505050FF, has_sample = false, volume = 1.0 },
  { name = '', note = 56, color = 0x505050FF, has_sample = false, volume = 1.0 },
  { name = '', note = 57, color = 0x505050FF, has_sample = false, volume = 1.0 },
}

---Initialize pad data (scans existing RS5K structure or uses defaults)
local function init_pads()
  if state.initialized then return end

  -- Ensure RS5KManager is loaded
  if not RS5KManager then
    RS5KManager = require('scripts.Blocks.blocks.drum_rack.rs5k_manager')
  end

  -- Try to scan for existing drum rack structure
  local existing_rack = RS5KManager.scan_existing_rack()

  -- Build a lookup of existing pads by note number
  local existing_by_note = {}
  if existing_rack then
    state.parent_track = existing_rack.parent
    state.rs5k_initialized = true
    for _, pad_info in ipairs(existing_rack.pads) do
      existing_by_note[pad_info.note] = pad_info
    end
    reaper.ShowConsoleMsg(string.format('[DrumRack] Found existing rack with %d pads\n', #existing_rack.pads))
  end

  -- Initialize all pads (use existing data or defaults)
  for i = 1, CONFIG.pad_count do
    local default_note = CONFIG.base_note + (i - 1)  -- Default: C1 (36) for pad 1
    local mock = MOCK_PADS[i] or { name = '', note = default_note, color = 0x505050FF, has_sample = false, volume = 1.0 }

    -- Check if we have an existing RS5K pad for this note
    local existing = existing_by_note[mock.note]

    if existing then
      -- Use data from existing RS5K track
      local sample_name = existing.sample_path and existing.sample_path:match('[^/\\]+$') or ''
      sample_name = sample_name:gsub('%.[^.]+$', '')  -- Remove extension

      -- Get track color (falls back to default gray if not set)
      local track_color = RS5KManager.get_track_color(existing.track)

      state.pads[i] = {
        key = 'pad_' .. i,
        index = i,
        name = existing.name ~= '' and existing.name or sample_name,
        note = existing.note,
        color = track_color,
        has_sample = existing.sample_path ~= nil and existing.sample_path ~= '',
        volume = RS5KManager.get_param(existing.track, existing.fx_idx, RS5KManager.PARAMS.VOLUME) or 1.0,
        pan = RS5KManager.get_track_pan(existing.track) or 0,
        pitch = RS5KManager.get_pitch(existing.track, existing.fx_idx) or 0,
        attack = RS5KManager.get_param(existing.track, existing.fx_idx, RS5KManager.PARAMS.ATTACK) or 0.01,
        decay = RS5KManager.get_param(existing.track, existing.fx_idx, RS5KManager.PARAMS.DECAY) or 0.1,
        sustain = RS5KManager.get_param(existing.track, existing.fx_idx, RS5KManager.PARAMS.SUSTAIN) or 1.0,
        env_release = RS5KManager.get_param(existing.track, existing.fx_idx, RS5KManager.PARAMS.RELEASE) or 0.1,
        delay = RS5KManager.get_track_delay(existing.track) or 0,
        obey_noteoff = (RS5KManager.get_param(existing.track, existing.fx_idx, RS5KManager.PARAMS.OBEY_NOTE_OFF) or 1) > 0.5,
        source_path = existing.sample_path,
        track = existing.track,
        fx_idx = existing.fx_idx,
      }
    else
      -- Use mock/default data
      state.pads[i] = {
        key = 'pad_' .. i,
        index = i,
        name = mock.name,
        note = mock.note,
        color = mock.color,
        has_sample = mock.has_sample,
        volume = mock.volume,
        pan = 0.5,
      }
    end
  end

  state.initialized = true
end

---Ensure dependencies are loaded
local function ensure_deps()
  if not Ark then
    Ark = require('arkitekt')
    ImGui = Ark.ImGui
    PadRenderer = require('scripts.Blocks.blocks.drum_rack.renderer')
    TileAnimator = require('arkitekt.gui.animation.tile_animator')
    RS5KManager = require('scripts.Blocks.blocks.drum_rack.rs5k_manager')

    -- Try to load ItemPickerState for cross-block drag-drop
    local ok, ip_state = pcall(require, 'ItemPicker.app.state')
    if ok then
      ItemPickerState = ip_state
      reaper.ShowConsoleMsg('[DrumRack] ItemPickerState loaded successfully\n')
    else
      reaper.ShowConsoleMsg('[DrumRack] Failed to load ItemPickerState: ' .. tostring(ip_state) .. '\n')
    end

    -- Try to load Visualization for waveform rendering
    local ok2, ip_vis = pcall(require, 'ItemPicker.ui.visualization')
    if ok2 then
      Visualization = ip_vis
    end

    -- Load ADSR widget
    ADSRWidget = require('scripts.Blocks.ui.widgets.adsr')

    -- Load Kit manager
    KitManager = require('scripts.Blocks.blocks.drum_rack.kit_manager')
  end
end

---Check if ItemPicker is currently dragging audio
---@return boolean
local function is_itempicker_dragging_audio()
  if not ItemPickerState then
    return false
  end
  -- Check if dragging (dragging is true when active, nil when not)
  return ItemPickerState.dragging == true
    and ItemPickerState.dragging_is_audio == true
end

---Get the dragged sample data from ItemPicker
---@return table|nil item_data, string|nil uuid
local function get_dragged_sample()
  if not ItemPickerState or not ItemPickerState.dragging_keys then
    return nil, nil
  end

  local uuid = ItemPickerState.dragging_keys[1]
  if not uuid then return nil, nil end

  local item_data = ItemPickerState.audio_item_lookup and ItemPickerState.audio_item_lookup[uuid]
  return item_data, uuid
end

---Ensure RS5K parent track exists
---@return boolean success
local function ensure_rs5k_structure()
  reaper.ShowConsoleMsg('[DrumRack DEBUG] ensure_rs5k_structure called\n')

  if state.rs5k_initialized and state.parent_track then
    -- Validate parent still exists
    if reaper.ValidatePtr2(0, state.parent_track, 'MediaTrack*') then
      reaper.ShowConsoleMsg('[DrumRack DEBUG] Parent track already exists and valid\n')
      return true
    end
    reaper.ShowConsoleMsg('[DrumRack DEBUG] Parent track invalid, recreating\n')
  end

  -- Find or create parent track
  reaper.ShowConsoleMsg('[DrumRack DEBUG] Calling RS5KManager.find_or_create_parent\n')
  local parent, created = RS5KManager.find_or_create_parent('Drum Rack')
  reaper.ShowConsoleMsg(string.format('[DrumRack DEBUG] Result: parent=%s, created=%s\n', tostring(parent), tostring(created)))

  if parent then
    state.parent_track = parent
    state.rs5k_initialized = true
    if created then
      reaper.ShowConsoleMsg('[DrumRack] Created drum rack track structure\n')
    else
      reaper.ShowConsoleMsg('[DrumRack] Found existing drum rack track\n')
    end
    return true
  end

  reaper.ShowConsoleMsg('[DrumRack DEBUG] Failed to create parent track!\n')
  return false
end

---Load a sample into a pad (updates UI state AND creates RS5K)
---@param pad table The pad to load into
---@param item_data table ItemPicker item data
---@param uuid string|nil ItemPicker item UUID (for waveform lookup)
local function load_sample_to_pad(pad, item_data, uuid)
  reaper.ShowConsoleMsg('[DrumRack DEBUG] load_sample_to_pad called\n')
  reaper.ShowConsoleMsg(string.format('[DrumRack DEBUG] pad=%s, item_data=%s, uuid=%s\n',
    tostring(pad), tostring(item_data), tostring(uuid)))

  if not pad or not item_data then
    reaper.ShowConsoleMsg('[DrumRack DEBUG] Early return: pad or item_data is nil\n')
    return
  end

  -- Extract sample info
  -- item_data structure: [1]=MediaItem, [2]=name, uuid, track_color, etc.
  local name = item_data.name or item_data[2] or 'Sample'
  local color = item_data.color or 0x4A88D9FF

  -- Get source path from MediaItem (not stored in item_data directly)
  local source_path = ''
  local media_item = item_data[1]
  if media_item and reaper.ValidatePtr2(0, media_item, 'MediaItem*') then
    local take = reaper.GetActiveTake(media_item)
    if take then
      local source = reaper.GetMediaItemTake_Source(take)
      -- Handle reversed items (requires SWS extension)
      if reaper.BR_GetMediaSourceProperties then
        local _, _, _, _, _, reverse = reaper.BR_GetMediaSourceProperties(take)
        if reverse and source then
          local parent = reaper.GetMediaSourceParent(source)
          if parent then source = parent end
        end
      end
      if source then
        source_path = reaper.GetMediaSourceFileName(source) or ''
      end
    end
  end

  reaper.ShowConsoleMsg(string.format('[DrumRack DEBUG] name=%s, source_path=%s\n', name, source_path))

  -- Update pad UI state
  pad.name = name
  pad.color = color
  pad.has_sample = true
  pad.source_path = source_path
  pad.uuid = uuid  -- Store UUID for waveform lookup
  pad.volume = 1.0

  -- Create RS5K track and load sample
  reaper.ShowConsoleMsg(string.format('[DrumRack DEBUG] RS5KManager=%s, source_path empty=%s\n',
    tostring(RS5KManager), tostring(source_path == '')))

  if RS5KManager and source_path ~= '' then
    if ensure_rs5k_structure() then
      -- Create pad track if it doesn't exist
      if not pad.track or not reaper.ValidatePtr2(0, pad.track, 'MediaTrack*') then
        pad.track = RS5KManager.create_pad_track(state.parent_track, pad.index, pad.note, name)
      end

      if pad.track then
        local fx_idx = RS5KManager.find_rs5k(pad.track)
        if fx_idx >= 0 then
          pad.fx_idx = fx_idx
          local success = RS5KManager.load_sample(pad.track, fx_idx, source_path)
          if success then
            reaper.ShowConsoleMsg(string.format(
              '[DrumRack] Loaded "%s" into RS5K on Pad %d (Note %d)\n',
              name, pad.index, pad.note
            ))
          else
            reaper.ShowConsoleMsg(string.format(
              '[DrumRack] Failed to load sample into RS5K: %s\n', source_path
            ))
          end
        end
      end
    end
  else
    -- No source path, just UI update
    reaper.ShowConsoleMsg(string.format(
      '[DrumRack] Loaded "%s" to Pad %d (Note %d) [UI only - no source path]\n',
      name, pad.index, pad.note
    ))
  end
end

-- Grid animator (created once)
local animator = nil

---Get grid items
local function get_items()
  return state.pads
end

---Draw the component content
---@param ctx userdata ImGui context
local function draw_content(ctx)
  ensure_deps()
  init_pads()

  -- Create animator if needed
  if not animator then
    animator = TileAnimator.new()
  end

  -- Update animator
  local dt = ImGui.GetDeltaTime(ctx)
  animator:update(dt)

  -- Header
  ImGui.Text(ctx, 'Drum Rack')
  ImGui.SameLine(ctx)
  ImGui.TextDisabled(ctx, '(' .. CONFIG.pad_count .. ' pads)')

  -- Visibility controls (right-aligned)
  if state.parent_track and reaper.ValidatePtr2(0, state.parent_track, 'MediaTrack*') then
    local avail_w = ImGui.GetContentRegionAvail(ctx)
    ImGui.SameLine(ctx, avail_w - 150)

    -- Collapse/Expand toggle
    local is_collapsed = RS5KManager.is_folder_collapsed(state.parent_track)
    if ImGui.SmallButton(ctx, is_collapsed and 'Expand' or 'Collapse') then
      RS5KManager.toggle_folder_collapsed(state.parent_track)
    end

    ImGui.SameLine(ctx)

    -- Mixer visibility toggle
    if ImGui.SmallButton(ctx, 'Mixer') then
      ImGui.OpenPopup(ctx, 'visibility_menu')
    end

    ImGui.SameLine(ctx)

    -- Kit save/load
    if ImGui.SmallButton(ctx, 'Kit') then
      ImGui.OpenPopup(ctx, 'kit_menu')
    end

    -- Kit popup menu
    if ImGui.BeginPopup(ctx, 'kit_menu') then
      if ImGui.MenuItem(ctx, 'Save Kit...') then
        local retval, name = reaper.GetUserInputs('Save Drum Kit', 1, 'Kit Name:', 'My Kit')
        if retval and name ~= '' then
          local success, err = KitManager.save_kit(state.pads, name)
          if not success then
            reaper.ShowMessageBox('Failed to save kit: ' .. (err or 'Unknown error'), 'Error', 0)
          end
        end
      end

      if ImGui.MenuItem(ctx, 'Load Kit...') then
        local retval, filepath = reaper.GetUserFileNameForRead('', 'Load Drum Kit', 'drumkit')
        if retval and filepath ~= '' then
          local kit, err = KitManager.load_kit(filepath)
          if kit then
            if ensure_rs5k_structure() then
              local loaded = KitManager.apply_kit(kit, state.pads, RS5KManager, state.parent_track)
              reaper.ShowConsoleMsg(string.format('[DrumRack] Loaded %d pads from kit\n', loaded))
            end
          else
            reaper.ShowMessageBox('Failed to load kit: ' .. (err or 'Unknown error'), 'Error', 0)
          end
        end
      end

      ImGui.Separator(ctx)

      -- List available kits
      local kits = KitManager.list_kits()
      if #kits > 0 then
        if ImGui.BeginMenu(ctx, 'Recent Kits') then
          for _, kit_info in ipairs(kits) do
            if ImGui.MenuItem(ctx, kit_info.name) then
              local kit, err = KitManager.load_kit(kit_info.path)
              if kit then
                if ensure_rs5k_structure() then
                  KitManager.apply_kit(kit, state.pads, RS5KManager, state.parent_track)
                end
              end
            end
          end
          ImGui.EndMenu(ctx)
        end
      end

      ImGui.Separator(ctx)

      -- Note range configuration
      if ImGui.BeginMenu(ctx, 'Note Range') then
        ImGui.TextDisabled(ctx, string.format('Current: %d-%d', CONFIG.base_note, CONFIG.base_note + CONFIG.pad_count - 1))
        ImGui.Separator(ctx)

        for _, preset in ipairs(NOTE_PRESETS) do
          if ImGui.MenuItem(ctx, preset.name, nil, CONFIG.base_note == preset.note) then
            -- Update base note (requires re-init to take effect on new pads)
            CONFIG.base_note = preset.note
            -- Update existing pads' note assignments
            for i, pad in ipairs(state.pads) do
              local new_note = CONFIG.base_note + (i - 1)
              if pad.track and pad.fx_idx and pad.note ~= new_note then
                -- Update RS5K note filter
                RS5KManager.set_rs5k_note_range(pad.track, pad.fx_idx, new_note, new_note)
                pad.note = new_note
              end
            end
          end
        end

        ImGui.EndMenu(ctx)
      end

      ImGui.EndPopup(ctx)
    end

    -- Visibility popup menu
    if ImGui.BeginPopup(ctx, 'visibility_menu') then
      if ImGui.MenuItem(ctx, 'Show All in Mixer') then
        RS5KManager.show_all_in_mixer(state.parent_track)
      end
      if ImGui.MenuItem(ctx, 'Hide All from Mixer') then
        RS5KManager.hide_all_from_mixer(state.parent_track)
      end
      ImGui.Separator(ctx)
      if ImGui.MenuItem(ctx, 'Show All in Arrange') then
        RS5KManager.show_all_in_arrange(state.parent_track)
      end
      if ImGui.MenuItem(ctx, 'Hide All from Arrange') then
        RS5KManager.hide_all_from_arrange(state.parent_track)
      end
      ImGui.Separator(ctx)
      if ImGui.MenuItem(ctx, 'Collapse Folder', nil, is_collapsed) then
        RS5KManager.set_folder_collapsed(state.parent_track, true)
      end
      if ImGui.MenuItem(ctx, 'Expand Folder', nil, not is_collapsed) then
        RS5KManager.set_folder_collapsed(state.parent_track, false)
      end
      ImGui.EndPopup(ctx)
    end
  end

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Check for ItemPicker drag and handle drop on release
  local dragging_from_itempicker = is_itempicker_dragging_audio()
  local mouse_down = ImGui.IsMouseDown(ctx, 0)

  -- Track mouse state for drop detection
  -- Drop = WAS dragging (last frame) + mouse WAS down (last frame) + mouse is now up
  -- We use was_dragging because ItemPicker clears drag state on same frame as mouse release
  local just_dropped = state.was_dragging_from_itempicker and state.was_mouse_down and not mouse_down

  -- Cache dragged sample data and drop target during drag (for use on drop)
  if dragging_from_itempicker and mouse_down then
    state.last_drop_target_pad = state.drop_target_pad
    -- Cache the sample data while it's still available
    state.cached_item_data, state.cached_uuid = get_dragged_sample()
  end

  -- Update states for next frame
  state.was_mouse_down = mouse_down
  state.was_dragging_from_itempicker = dragging_from_itempicker

  -- Clear drop target at start of frame (will be set during render if hovering)
  state.drop_target_pad = nil

  -- Calculate available space for grid
  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)
  local grid_h = avail_h - 60  -- Reserve space for footer controls

  -- Grid result (declared outside child scope)
  local result = nil

  -- Create panel if needed (prevents window dragging during item drag)
  if not state.grid_panel then
    state.grid_panel = Ark.Panel.new({
      id = 'drum_rack_grid_panel',
      config = {
        background = { enabled = false },
        header = { enabled = false },
        scrollbar = { enabled = false },
      },
    })
  end

  -- Set panel dimensions and draw
  state.grid_panel.width = avail_w
  state.grid_panel.height = grid_h

  if state.grid_panel:begin_draw(ctx) then
    result = Ark.Grid(ctx, {
    id = 'drum_rack_grid',
    gap = CONFIG.gap,
    min_col_w = CONFIG.min_pad_size,
    fixed_tile_h = CONFIG.fixed_pad_size,

    -- Enable external drops from ItemPicker
    accept_external_drops = true,
    external_drag_check = is_itempicker_dragging_audio,

    get_items = get_items,

    key = function(pad)
      return pad.key
    end,

    render_item = function(render_ctx, rect, pad, tile_state)
      -- Highlight pad when dragging over it
      local is_drop_target = dragging_from_itempicker and tile_state.hover

      -- Get runtime cache for waveform lookup
      local runtime_cache = ItemPickerState and ItemPickerState.runtime_cache

      -- Compute layer count for display (if track exists)
      if pad.track and RS5KManager then
        local layers = RS5KManager.get_velocity_layers(pad.track)
        pad.layer_count = #layers
      end

      PadRenderer.render(render_ctx, rect, pad, tile_state, animator, is_drop_target, Visualization, runtime_cache)

      -- Track hovered pad for drop handling
      if is_drop_target then
        state.drop_target_pad = pad
      end
    end,

    behaviors = {
      on_select = function(grid, selected_keys)
        if #selected_keys > 0 then
          -- Find pad by key
          for _, pad in ipairs(state.pads) do
            if pad.key == selected_keys[1] then
              state.selected_pad = pad.index
              break
            end
          end
        else
          state.selected_pad = nil
        end
      end,

      -- Click triggers sample preview
      ['click:left'] = function(grid, key)
        for _, pad in ipairs(state.pads) do
          if pad.key == key and pad.has_sample and pad.track then
            -- Trigger sample via MIDI note
            RS5KManager.preview_note(pad.track, pad.note, 100, 0.5)
          end
        end
      end,

      -- Double-click opens RS5K
      ['dblclick:left'] = function(grid, key)
        for _, pad in ipairs(state.pads) do
          if pad.key == key and pad.track and pad.fx_idx then
            RS5KManager.show_fx_window(pad.track, pad.fx_idx)
          end
        end
      end,

      -- Right-click context menu
      ['click:right'] = function(grid, key, selected_keys)
        reaper.ShowConsoleMsg('[DrumRack] Right-click on key: ' .. tostring(key) .. '\n')
        for _, pad in ipairs(state.pads) do
          if pad.key == key then
            state.context_pad = pad
            state.open_context_menu = true  -- Flag to open popup outside grid
            break
          end
        end
      end,
    },
  })

  end
  state.grid_panel:end_draw(ctx)

  -- Handle drop from ItemPicker (mouse released while dragging over a pad)
  if just_dropped then
    reaper.ShowConsoleMsg('[DrumRack DEBUG] Mouse released while dragging!\n')
    reaper.ShowConsoleMsg(string.format('[DrumRack DEBUG] last_drop_target_pad=%s\n',
      state.last_drop_target_pad and (state.last_drop_target_pad.name or state.last_drop_target_pad.key) or 'nil'))

    -- Use the last known drop target pad and cached sample data
    if state.last_drop_target_pad and state.cached_item_data then
      load_sample_to_pad(state.last_drop_target_pad, state.cached_item_data, state.cached_uuid)
    elseif not state.last_drop_target_pad then
      reaper.ShowConsoleMsg('[DrumRack DEBUG] No drop target pad!\n')
    else
      reaper.ShowConsoleMsg('[DrumRack DEBUG] No cached item data!\n')
    end

    -- Clear cached data after drop
    state.last_drop_target_pad = nil
    state.cached_item_data = nil
    state.cached_uuid = nil
  end

  -- Open context menu if flagged (must be outside grid/panel scope)
  if state.open_context_menu then
    ImGui.OpenPopup(ctx, 'pad_context_menu')
    state.open_context_menu = false
  end

  -- Context menu (must be outside panel)
  if ImGui.BeginPopup(ctx, 'pad_context_menu') then
    local pad = state.context_pad
    if pad then
      -- Preview
      if ImGui.MenuItem(ctx, 'Preview', nil, false, pad.has_sample and pad.track ~= nil) then
        RS5KManager.preview_note(pad.track, pad.note, 100, 0.5)
      end

      ImGui.Separator(ctx)

      -- Sample operations
      if ImGui.MenuItem(ctx, 'Load Sample...') then
        -- Open file browser for sample selection
        local retval, filename = reaper.GetUserFileNameForRead('', 'Load Sample', 'wav;mp3;ogg;flac;aif;aiff')
        if retval and filename ~= '' then
          if ensure_rs5k_structure() then
            -- Create pad track if needed
            if not pad.track or not reaper.ValidatePtr2(0, pad.track, 'MediaTrack*') then
              pad.track = RS5KManager.create_pad_track(state.parent_track, pad.index, pad.note, pad.name)
            end
            if pad.track then
              local fx_idx = RS5KManager.find_rs5k(pad.track)
              if fx_idx >= 0 then
                pad.fx_idx = fx_idx
                if RS5KManager.load_sample(pad.track, fx_idx, filename) then
                  pad.has_sample = true
                  pad.source_path = filename
                  pad.name = filename:match('[^/\\]+$'):gsub('%.[^.]+$', '')
                end
              end
            end
          end
        end
      end

      if ImGui.MenuItem(ctx, 'Clear Sample', nil, false, pad.has_sample) then
        -- Clear sample from RS5K but keep track
        if pad.track and pad.fx_idx then
          RS5KManager.clear_sample(pad.track, pad.fx_idx)
        end
        pad.has_sample = false
        pad.name = ''
        pad.source_path = nil
        pad.uuid = nil
      end

      ImGui.Separator(ctx)

      -- Color picker submenu
      if ImGui.BeginMenu(ctx, 'Pad Color') then
        local colors = {
          { name = 'Red',      color = 0xD94A4AFF },
          { name = 'Orange',   color = 0xD9884AFF },
          { name = 'Yellow',   color = 0xD9C84AFF },
          { name = 'Green',    color = 0x88D94AFF },
          { name = 'Teal',     color = 0x4AD9D9FF },
          { name = 'Blue',     color = 0x4A88D9FF },
          { name = 'Purple',   color = 0x884AD9FF },
          { name = 'Pink',     color = 0xD94AD9FF },
          { name = 'Gray',     color = 0x808080FF },
        }

        for _, c in ipairs(colors) do
          -- Draw color swatch
          local r = (c.color >> 24) & 0xFF
          local g = (c.color >> 16) & 0xFF
          local b = (c.color >> 8) & 0xFF
          ImGui.PushStyleColor(ctx, ImGui.Col_Text, c.color)
          if ImGui.MenuItem(ctx, '■ ' .. c.name, nil, pad.color == c.color) then
            pad.color = c.color
            if pad.track then
              RS5KManager.set_track_color(pad.track, c.color)
            end
          end
          ImGui.PopStyleColor(ctx)
        end

        ImGui.EndMenu(ctx)
      end

      ImGui.Separator(ctx)

      -- FX operations
      if ImGui.MenuItem(ctx, 'Edit RS5K...', nil, false, pad.track ~= nil and pad.fx_idx ~= nil) then
        RS5KManager.show_fx_window(pad.track, pad.fx_idx)
      end

      if ImGui.MenuItem(ctx, 'Edit FX Chain...', nil, false, pad.track ~= nil) then
        RS5KManager.show_fx_window(pad.track)
      end

      ImGui.Separator(ctx)

      -- Visibility submenu
      if ImGui.BeginMenu(ctx, 'Visibility', pad.track ~= nil) then
        local in_tcp = RS5KManager.is_visible_in_tcp(pad.track)
        local in_mcp = RS5KManager.is_visible_in_mcp(pad.track)

        if ImGui.MenuItem(ctx, 'Show in Arrange', nil, in_tcp) then
          RS5KManager.set_visible_in_tcp(pad.track, not in_tcp)
        end
        if ImGui.MenuItem(ctx, 'Show in Mixer', nil, in_mcp) then
          RS5KManager.set_visible_in_mcp(pad.track, not in_mcp)
        end

        ImGui.EndMenu(ctx)
      end

      -- Choke group submenu
      if ImGui.BeginMenu(ctx, 'Choke Group', state.parent_track ~= nil) then
        -- Check current choke group assignment
        local current_group = nil
        if state.parent_track then
          for g = 1, 4 do
            local notes = RS5KManager.get_choke_group(state.parent_track, g)
            if notes then
              for _, n in ipairs(notes) do
                if n == pad.note then
                  current_group = g
                  break
                end
              end
            end
            if current_group then break end
          end
        end

        -- None option
        if ImGui.MenuItem(ctx, 'None', nil, current_group == nil) then
          if current_group and state.parent_track then
            RS5KManager.remove_note_from_choke_group(state.parent_track, current_group, pad.note)
          end
        end

        ImGui.Separator(ctx)

        -- Group 1-4 options
        local group_names = { 'Group 1 (Hi-Hats)', 'Group 2 (Crashes)', 'Group 3', 'Group 4' }
        for g = 1, 4 do
          if ImGui.MenuItem(ctx, group_names[g], nil, current_group == g) then
            if state.parent_track then
              -- Ensure choke JSFX exists
              RS5KManager.add_choke_fx(state.parent_track)
              -- Remove from old group if any
              if current_group and current_group ~= g then
                RS5KManager.remove_note_from_choke_group(state.parent_track, current_group, pad.note)
              end
              -- Add to new group
              RS5KManager.add_note_to_choke_group(state.parent_track, g, pad.note)
            end
          end
        end

        ImGui.EndMenu(ctx)
      end

      -- Velocity Layers submenu
      if ImGui.BeginMenu(ctx, 'Velocity Layers', pad.track ~= nil) then
        local layers = RS5KManager.get_velocity_layers(pad.track)
        local layer_count = #layers

        -- Show current layers
        ImGui.TextDisabled(ctx, string.format('%d layer(s)', layer_count))
        ImGui.Separator(ctx)

        -- List existing layers
        for i, layer in ipairs(layers) do
          local sample_name = layer.sample_path and layer.sample_path:match('[^/\\]+$') or 'Empty'
          if sample_name then sample_name = sample_name:gsub('%.[^.]+$', '') end
          local label = string.format('L%d: %d-%d vel (%s)', i, layer.vel_min, layer.vel_max, sample_name or 'Empty')

          if ImGui.BeginMenu(ctx, label) then
            -- Load sample for this layer
            if ImGui.MenuItem(ctx, 'Load Sample...') then
              local retval, filepath = reaper.GetUserFileNameForRead('', 'Load Sample', 'wav;mp3;ogg;flac')
              if retval and filepath ~= '' then
                RS5KManager.load_sample(pad.track, layer.fx_idx, filepath)
              end
            end

            -- Edit velocity range
            if ImGui.MenuItem(ctx, 'Edit RS5K...') then
              RS5KManager.show_fx_window(pad.track, layer.fx_idx)
            end

            -- Remove layer (if more than 1)
            if layer_count > 1 then
              ImGui.Separator(ctx)
              if ImGui.MenuItem(ctx, 'Remove Layer') then
                RS5KManager.remove_velocity_layer(pad.track, layer.fx_idx)
              end
            end

            ImGui.EndMenu(ctx)
          end
        end

        ImGui.Separator(ctx)

        -- Add layer
        if ImGui.MenuItem(ctx, 'Add Velocity Layer') then
          -- Open file picker
          local retval, filepath = reaper.GetUserFileNameForRead('', 'Load Sample for Layer', 'wav;mp3;ogg;flac')
          if retval and filepath ~= '' then
            RS5KManager.add_velocity_layer(pad.track, 0, 127, filepath)
            RS5KManager.auto_distribute_velocity(pad.track)
          end
        end

        -- Auto-distribute
        if layer_count > 1 then
          if ImGui.MenuItem(ctx, 'Auto-Distribute Velocity') then
            RS5KManager.auto_distribute_velocity(pad.track)
          end
        end

        ImGui.EndMenu(ctx)
      end

      ImGui.Separator(ctx)

      -- Duplication
      if ImGui.MenuItem(ctx, 'Duplicate to Next Pad', nil, false, pad.has_sample and pad.index < CONFIG.pad_count) then
        local next_pad = state.pads[pad.index + 1]
        if next_pad and pad.source_path then
          -- Create track for next pad if needed
          if ensure_rs5k_structure() then
            if not next_pad.track or not reaper.ValidatePtr2(0, next_pad.track, 'MediaTrack*') then
              next_pad.track = RS5KManager.create_pad_track(state.parent_track, next_pad.index, next_pad.note, pad.name)
            end
            if next_pad.track then
              local fx_idx = RS5KManager.find_rs5k(next_pad.track)
              if fx_idx >= 0 then
                next_pad.fx_idx = fx_idx
                RS5KManager.load_sample(next_pad.track, fx_idx, pad.source_path)
                -- Copy settings
                next_pad.has_sample = true
                next_pad.name = pad.name
                next_pad.source_path = pad.source_path
                next_pad.volume = pad.volume
                next_pad.pan = pad.pan
                next_pad.pitch = (pad.pitch or 0) + 12  -- Pitch up one octave
                next_pad.attack = pad.attack
                next_pad.decay = pad.decay
                next_pad.sustain = pad.sustain
                next_pad.env_release = pad.env_release
                -- Apply pitch offset
                RS5KManager.set_pitch(next_pad.track, fx_idx, next_pad.pitch)
              end
            end
          end
        end
      end

      ImGui.Separator(ctx)

      -- Destructive operations
      if ImGui.MenuItem(ctx, 'Delete Pad Track', nil, false, pad.track ~= nil) then
        if RS5KManager.delete_pad_track(pad.track) then
          pad.track = nil
          pad.fx_idx = nil
          pad.has_sample = false
          pad.name = ''
          pad.source_path = nil
          pad.color = 0x505050FF
        end
      end
    end
    ImGui.EndPopup(ctx)
  end

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Selected pad info
  if state.selected_pad then
    local pad = state.pads[state.selected_pad]
    if pad then
      ImGui.Text(ctx, string.format('Selected: Pad %d - %s (Note %d)',
        state.selected_pad, pad.name ~= '' and pad.name or 'Empty', pad.note))

      if pad.has_sample then
        ImGui.Spacing(ctx)

        -- Volume slider (RS5K volume is 0-2, where 1 = 0dB)
        ImGui.Text(ctx, 'Volume:')
        ImGui.SameLine(ctx)
        ImGui.SetNextItemWidth(ctx, 120)
        local vol_display = pad.volume * 100  -- Convert to percentage for display
        local changed, new_vol_pct = ImGui.SliderDouble(ctx, '##volume', vol_display, 0.0, 200.0, '%.0f%%')
        if changed then
          pad.volume = new_vol_pct / 100
          -- Update RS5K if track exists
          if pad.track and pad.fx_idx and RS5KManager then
            RS5KManager.set_param(pad.track, pad.fx_idx, RS5KManager.PARAMS.VOLUME, pad.volume)
          end
        end

        -- Pan slider (track pan is -1 to +1)
        ImGui.SameLine(ctx)
        ImGui.Text(ctx, 'Pan:')
        ImGui.SameLine(ctx)
        ImGui.SetNextItemWidth(ctx, 120)
        local pan_display = pad.pan * 100  -- -100 to +100
        local changed_pan, new_pan_pct = ImGui.SliderDouble(ctx, '##pan', pan_display, -100.0, 100.0, '%.0f')
        if changed_pan then
          pad.pan = new_pan_pct / 100
          -- Update track pan if track exists
          if pad.track and RS5KManager then
            RS5KManager.set_track_pan(pad.track, pad.pan)
          end
        end

        -- Pitch slider (RS5K pitch is -96 to +96 semitones)
        ImGui.SameLine(ctx)
        ImGui.Text(ctx, 'Pitch:')
        ImGui.SameLine(ctx)
        ImGui.SetNextItemWidth(ctx, 80)
        local pitch = pad.pitch or 0
        local changed_pitch, new_pitch = ImGui.SliderDouble(ctx, '##pitch', pitch, -24.0, 24.0, '%.0f st')
        if changed_pitch then
          pad.pitch = new_pitch
          -- Update RS5K pitch if track exists
          if pad.track and pad.fx_idx and RS5KManager then
            RS5KManager.set_pitch(pad.track, pad.fx_idx, pad.pitch)
          end
        end

        -- Second row: Delay and Note-Off
        -- Delay slider (track playback offset for groove/timing)
        ImGui.Text(ctx, 'Delay:')
        ImGui.SameLine(ctx)
        ImGui.SetNextItemWidth(ctx, 100)
        pad.delay = pad.delay or 0
        local changed_delay, new_delay = ImGui.SliderDouble(ctx, '##delay', pad.delay, -50.0, 50.0, '%.1f ms')
        if changed_delay then
          pad.delay = new_delay
          if pad.track and RS5KManager then
            RS5KManager.set_track_delay(pad.track, pad.delay)
          end
        end

        -- Note-off toggle (obey note-offs)
        ImGui.SameLine(ctx)
        pad.obey_noteoff = pad.obey_noteoff == nil and true or pad.obey_noteoff
        local changed_noteoff, new_noteoff = ImGui.Checkbox(ctx, 'Note-Off', pad.obey_noteoff)
        if changed_noteoff then
          pad.obey_noteoff = new_noteoff
          if pad.track and pad.fx_idx and RS5KManager then
            RS5KManager.set_param(pad.track, pad.fx_idx, RS5KManager.PARAMS.OBEY_NOTE_OFF, new_noteoff and 1 or 0)
          end
        end

        -- ADSR Envelope (full ADSR for RS5K)
        ImGui.Spacing(ctx)
        ImGui.Text(ctx, 'Envelope:')
        ImGui.SameLine(ctx)

        -- Initialize envelope values if not set
        pad.attack = pad.attack or 0.01
        pad.decay = pad.decay or 0.1
        pad.sustain = pad.sustain or 1.0
        pad.env_release = pad.env_release or 0.1  -- 'release' conflicts with Lua, use env_release

        local env_result = ADSRWidget.Draw(ctx, {
          id = 'pad_envelope_' .. pad.index,
          width = 220,
          height = 90,
          attack = pad.attack,
          decay = pad.decay,
          sustain = pad.sustain,
          release = pad.env_release,
        })

        if env_result.changed then
          pad.attack = env_result.attack
          pad.decay = env_result.decay
          pad.sustain = env_result.sustain
          pad.env_release = env_result.release

          -- Update RS5K envelope if track exists
          if pad.track and pad.fx_idx and RS5KManager then
            RS5KManager.set_param(pad.track, pad.fx_idx, RS5KManager.PARAMS.ATTACK, pad.attack)
            RS5KManager.set_param(pad.track, pad.fx_idx, RS5KManager.PARAMS.DECAY, pad.decay)
            RS5KManager.set_param(pad.track, pad.fx_idx, RS5KManager.PARAMS.SUSTAIN, pad.sustain)
            RS5KManager.set_param(pad.track, pad.fx_idx, RS5KManager.PARAMS.RELEASE, pad.env_release)
          end
        end
      end
    end
  else
    ImGui.TextDisabled(ctx, 'Click a pad to select')
  end
end

-- Entry point: Shell handles standalone vs hosted mode
return Shell.run({
  title = 'Drum Rack',
  version = 'v0.1.0',
  initial_size = { w = 450, h = 580 },
  min_size = { w = 300, h = 400 },

  draw = function(ctx, shell_state)
    draw_content(ctx)
  end,

  on_close = function()
    -- Stop any playing preview notes
    if RS5KManager then
      RS5KManager.stop_all_previews()
    end

    state.initialized = false
    state.pads = {}
    state.selected_pad = nil
    state.grid_panel = nil
    state.parent_track = nil
    state.rs5k_initialized = false
    state.drop_target_pad = nil
    state.last_drop_target_pad = nil
    state.was_mouse_down = false
    state.was_dragging_from_itempicker = false
    state.cached_item_data = nil
    state.cached_uuid = nil
    animator = nil
  end,
})

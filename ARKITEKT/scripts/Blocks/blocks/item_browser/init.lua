-- @noindex
-- Blocks/blocks/item_browser/init.lua
-- Mini ItemPicker - uses ItemPicker's actual grid, state, and renderers
-- A lightweight block component that embeds ItemPicker's grids with tabs

local Shell = require('arkitekt.runtime.shell')

-- Setup package.path to find ItemPicker modules
local function setup_itempicker_paths()
  local source = debug.getinfo(1,'S').source:sub(2)
  -- Find the scripts/ directory (contains both Blocks and ItemPicker)
  local scripts_path = source:match('(.-scripts[/\\])')
  if scripts_path and not package.path:find(scripts_path, 1, true) then
    local sep = package.config:sub(1,1)
    package.path = scripts_path .. '?.lua;' .. scripts_path .. '?' .. sep .. 'init.lua;' .. package.path
  end
end
setup_itempicker_paths()

-- Lazy-loaded dependencies
local Ark, ImGui
local ItemPickerState, Coordinator, Config, ItemsService, Visualization
local ReaperInterface, Utils, JobQueue
local initialized = false
local coordinator = nil
local loading_triggered = false
local debug_info = nil  -- Store module load failures for debug display
local job_queue = nil  -- For waveform/MIDI thumbnail generation

-- Component state
local state = {
  current_tab = 'audio',  -- 'audio' or 'midi'
  audio_panel = nil,  -- Ark.Panel for audio grid
  midi_panel = nil,   -- Ark.Panel for midi grid
}

---Check if ItemPicker modules are available and initialize
---@param ctx userdata ImGui context
---@return boolean success, boolean is_loading
local function ensure_itempicker(ctx)
  -- Try to load ItemPicker modules (only once)
  if not ItemPickerState then
    local ok1, ip_state = pcall(require, 'ItemPicker.app.state')
    local ok2, ip_coord = pcall(require, 'ItemPicker.ui.grids.coordinator')
    local ok3, ip_config = pcall(require, 'ItemPicker.config.constants')
    local ok4, ip_vis = pcall(require, 'ItemPicker.ui.visualization')
    local ok5, ip_service = pcall(require, 'ItemPicker.domain.items.service')
    local ok6, ip_reaper = pcall(require, 'ItemPicker.data.reaper_api')
    local ok7, ip_utils = pcall(require, 'ItemPicker.domain.items.utils')
    local ok8, ip_jobqueue = pcall(require, 'ItemPicker.data.job_queue')

    if not (ok1 and ok2 and ok3 and ok5 and ok6 and ok7 and ok8) then
      -- Store failed module info for debug display
      debug_info = {
        state = ok1 and 'ok' or tostring(ip_state),
        coord = ok2 and 'ok' or tostring(ip_coord),
        config = ok3 and 'ok' or tostring(ip_config),
        service = ok5 and 'ok' or tostring(ip_service),
        reaper = ok6 and 'ok' or tostring(ip_reaper),
        utils = ok7 and 'ok' or tostring(ip_utils),
        jobqueue = ok8 and 'ok' or tostring(ip_jobqueue),
      }
      return false, false
    end

    ItemPickerState = ip_state
    Config = ip_config
    Coordinator = ip_coord
    ItemsService = ip_service
    Visualization = ok4 and ip_vis or {}
    ReaperInterface = ip_reaper
    Utils = ip_utils
    JobQueue = ip_jobqueue

    -- Initialize visualization module (required for waveform/MIDI generation)
    if ok4 and ip_vis.init then
      ip_vis.init(ip_utils, nil, ip_config)
    end

    -- Create job queue for waveform/MIDI thumbnail generation
    if not job_queue then
      job_queue = ip_jobqueue.new(5)  -- Process 5 jobs per frame
      ItemPickerState.job_queue = job_queue
    end

    -- Initialize ItemPicker state if not already done
    if not ItemPickerState.config then
      ItemPickerState.initialize(Config)
    end

    -- Initialize ItemsService (MUST be called before start_incremental_loading)
    ItemsService.init(ReaperInterface, Utils)
  end

  -- Check if we need to trigger loading
  local has_items = ItemPickerState.sample_indexes and #ItemPickerState.sample_indexes > 0
  local has_midi = ItemPickerState.midi_indexes and #ItemPickerState.midi_indexes > 0

  if not has_items and not has_midi and not ItemPickerState.is_loading and not loading_triggered then
    -- Trigger item collection
    ItemsService.start_incremental_loading(ItemPickerState, 100, true)  -- fast mode
    loading_triggered = true
  end

  -- Process loading batch if loading
  if ItemPickerState.is_loading then
    ItemsService.process_loading_batch(ItemPickerState)
    return false, true  -- Not ready, still loading
  end

  -- Create coordinator if we have items and don't have one yet
  if not coordinator and (has_items or has_midi) then
    coordinator = Coordinator.new(ctx, Config, ItemPickerState, Visualization)
    ItemPickerState.coordinator = coordinator
    initialized = true

    -- Enable virtualization for embedded grids (better performance with many items)
    if coordinator.audio_grid_opts then
      coordinator.audio_grid_opts.virtual = true
    end
    if coordinator.midi_grid_opts then
      coordinator.midi_grid_opts.virtual = true
    end
  end

  return coordinator ~= nil, false
end

---Draw fallback UI when ItemPicker not available
---@param ctx userdata ImGui context
local function draw_fallback(ctx)
  if not Ark then
    Ark = require('arkitekt')
    ImGui = Ark.ImGui
  end

  ImGui.TextWrapped(ctx, 'ItemPicker modules failed to load.')
  ImGui.Spacing(ctx)

  -- Show debug info if available
  if debug_info then
    ImGui.TextDisabled(ctx, 'Module status:')
    for name, status in pairs(debug_info) do
      local color = status == 'ok' and 0x88FF88FF or 0xFF8888FF
      ImGui.TextColored(ctx, color, string.format('  %s: %s', name, status))
    end
    ImGui.Spacing(ctx)
  end

  if Ark.Button(ctx, 'Retry') then
    initialized = false
    coordinator = nil
    debug_info = nil
    loading_triggered = false
    job_queue = nil
    -- Clear cached module refs to force re-require
    ItemPickerState = nil
    Coordinator = nil
    Config = nil
    ItemsService = nil
    Visualization = nil
    ReaperInterface = nil
    Utils = nil
    JobQueue = nil
  end
end

---Draw loading indicator
---@param ctx userdata ImGui context
local function draw_loading(ctx)
  if not Ark then
    Ark = require('arkitekt')
    ImGui = Ark.ImGui
  end

  local progress = ItemPickerState and ItemPickerState.loading_progress or 0
  ImGui.Text(ctx, 'Scanning project items...')
  ImGui.ProgressBar(ctx, progress, -1, 20)

  local item_count = 0
  if ItemPickerState and ItemPickerState.incremental_loader then
    item_count = ItemPickerState.incremental_loader.current_index or 0
  end
  ImGui.TextDisabled(ctx, string.format('Processed: %d items', item_count))
end

---Draw the component content
---@param ctx userdata ImGui context
local function draw_content(ctx)
  if not Ark then
    Ark = require('arkitekt')
    ImGui = Ark.ImGui
  end

  -- Try to initialize ItemPicker integration
  local ready, is_loading = ensure_itempicker(ctx)

  if is_loading then
    draw_loading(ctx)
    return
  end

  if not ready then
    draw_fallback(ctx)
    return
  end

  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)

  -- Handle tile resize shortcuts (Ctrl+wheel = height, Alt+wheel = width)
  coordinator:handle_tile_size_shortcuts(ctx)

  -- Update animations
  local dt = ImGui.GetDeltaTime(ctx)
  coordinator:update_animations(dt)

  -- Process waveform/MIDI thumbnail jobs (generates visualizations progressively)
  if job_queue and ItemPickerState.runtime_cache and Visualization and JobQueue then
    JobQueue.process_jobs(job_queue, Visualization, ItemPickerState.runtime_cache, ctx)
  end

  -- Tab bar
  if ImGui.BeginTabBar(ctx, 'item_browser_tabs') then

    -- Audio tab
    local audio_count = ItemPickerState.sample_indexes and #ItemPickerState.sample_indexes or 0
    local audio_label = 'Audio (' .. audio_count .. ')'
    if ImGui.BeginTabItem(ctx, audio_label) then
      state.current_tab = 'audio'

      local tab_h = avail_h - ImGui.GetCursorPosY(ctx) - 4

      -- Create audio panel if needed (prevents window dragging during item drag)
      if not state.audio_panel then
        state.audio_panel = Ark.Panel.new({
          id = 'audio_grid_panel',
          config = {
            background = { enabled = false },
            header = { enabled = false },
            scrollbar = { enabled = false },
          },
        })
      end

      state.audio_panel.width = avail_w
      state.audio_panel.height = tab_h

      if state.audio_panel:begin_draw(ctx) then
        coordinator:render_audio_grid(ctx, avail_w, tab_h, 0)
      end
      state.audio_panel:end_draw(ctx)

      ImGui.EndTabItem(ctx)
    end

    -- MIDI tab
    local midi_count = ItemPickerState.midi_indexes and #ItemPickerState.midi_indexes or 0
    local midi_label = 'MIDI (' .. midi_count .. ')'
    if ImGui.BeginTabItem(ctx, midi_label) then
      state.current_tab = 'midi'

      local tab_h = avail_h - ImGui.GetCursorPosY(ctx) - 4

      -- Create midi panel if needed (prevents window dragging during item drag)
      if not state.midi_panel then
        state.midi_panel = Ark.Panel.new({
          id = 'midi_grid_panel',
          config = {
            background = { enabled = false },
            header = { enabled = false },
            scrollbar = { enabled = false },
          },
        })
      end

      state.midi_panel.width = avail_w
      state.midi_panel.height = tab_h

      if state.midi_panel:begin_draw(ctx) then
        coordinator:render_midi_grid(ctx, avail_w, tab_h, 0)
      end
      state.midi_panel:end_draw(ctx)

      ImGui.EndTabItem(ctx)
    end

    ImGui.EndTabBar(ctx)
  end

  -- Render disable animations (items fading out)
  coordinator:render_disable_animations(ctx)
end

-- Entry point: Shell handles standalone vs hosted mode
return Shell.run({
  title = 'Item Browser',
  version = 'v0.2.0',
  initial_size = { w = 500, h = 400 },
  min_size = { w = 300, h = 200 },

  draw = function(ctx, shell_state)
    draw_content(ctx)
  end,

  on_close = function()
    initialized = false
    coordinator = nil
    loading_triggered = false
    job_queue = nil
    state.audio_panel = nil
    state.midi_panel = nil
  end,
})

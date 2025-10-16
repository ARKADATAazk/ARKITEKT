local M = {}
local imgui
local ctx
local utils
local grid_adapter
local reaper_interface
local config
local shortcuts
local disabled_items

function M.init(imgui_module, imgui_ctx, utils_module, grid_adapter_module, reaper_interface_module, config_module, shortcuts_module, disabled_items_module)
  imgui = imgui_module
  ctx = imgui_ctx
  utils = utils_module
  grid_adapter = grid_adapter_module
  reaper_interface = reaper_interface_module
  config = config_module
  shortcuts = shortcuts_module
  disabled_items = disabled_items_module
  
  if not disabled_items then error("disabled_items module required") end
end

function M.MainWindow(state, settings, big_font, SCRIPT_TITLE, SCREEN_W, SCREEN_H)
  local window_flags = imgui.WindowFlags_NoCollapse | imgui.WindowFlags_NoTitleBar | imgui.WindowFlags_NoResize |
      imgui.WindowFlags_NoMove | imgui.WindowFlags_NoScrollbar | imgui.WindowFlags_NoScrollWithMouse

  local imgui_visible, imgui_open = imgui.Begin(ctx, SCRIPT_TITLE, true, window_flags)

  if imgui.Checkbox(ctx, "Play Item Through Track (will add delay to preview playback)", settings.play_item_through_track) then
    settings.play_item_through_track = not settings.play_item_through_track
  end
  
  if imgui.Checkbox(ctx, "Show Muted Tracks", settings.show_muted_tracks) then
    state.samples, state.sample_indexes, state.midi_tracks = nil, nil, nil
    settings.show_muted_tracks = not settings.show_muted_tracks
  end

  if imgui.Checkbox(ctx, "Show Muted Items", settings.show_muted_items) then
    state.samples, state.sample_indexes, state.midi_tracks = nil, nil, nil
    settings.show_muted_items = not settings.show_muted_items
  end
  
  imgui.SameLine(ctx)
  if imgui.Checkbox(ctx, "Show Disabled Items", settings.show_disabled_items) then
    settings.show_disabled_items = not settings.show_disabled_items
  end
  
  if state.disabled then
    local audio_disabled, midi_disabled = disabled_items.get_disabled_count(state.disabled)
    if audio_disabled > 0 or midi_disabled > 0 then
      imgui.SameLine(ctx)
      imgui.Text(ctx, string.format("(%d audio, %d midi disabled)", audio_disabled, midi_disabled))
      
      imgui.SameLine(ctx)
      if imgui.SmallButton(ctx, "Clear All Disabled") then
        disabled_items.clear_all(state.disabled)
      end
    end
  end

  local focus_search = shortcuts.handle_search_shortcuts(settings)
  
  shortcuts.handle_tile_size_shortcuts(state)
  
  if not state.samples then
    state.samples, state.sample_indexes = reaper_interface.GetProjectSamples(settings, state)
    state.midi_tracks = reaper_interface.GetProjectMidiTracks(settings, state)
    
    state.midi_grid = grid_adapter.create_midi_grid(state, settings)
    state.audio_grid = grid_adapter.create_audio_grid(state, settings)
  end
  
  imgui.PushFont(ctx, big_font)
  local search_text_w, search_text_h = imgui.CalcTextSize(ctx, "Search:")
  imgui.DrawList_AddText(state.draw_list, SCREEN_W / 2 - search_text_w / 2, SCREEN_H * config.LAYOUT.CONTENT_START_Y - search_text_h, 0xFFFFFFFF, "Search:")

  imgui.SetCursorScreenPos(ctx, SCREEN_W / 2 - (SCREEN_W * config.LAYOUT.SEARCH_WIDTH_RATIO) / 2, SCREEN_H * config.LAYOUT.CONTENT_START_Y)
  imgui.PushItemWidth(ctx, SCREEN_W * config.LAYOUT.SEARCH_WIDTH_RATIO)
  if (not state.initialized and settings.focus_keyboard_on_init) or focus_search then
    imgui.SetKeyboardFocusHere(ctx)
    state.initialized = true
  end
  _, settings.search_string = imgui.InputText(ctx, "##Search", settings.search_string)
  imgui.PopFont(ctx)

  local content_start_y = SCREEN_H * config.LAYOUT.CONTENT_START_Y
  local content_height = SCREEN_H * config.LAYOUT.CONTENT_HEIGHT
  
  if state.midi_grid then
    imgui.SetCursorScreenPos(ctx, config.LAYOUT.PADDING, content_start_y)
    imgui.PushFont(ctx, big_font)
    imgui.Text(ctx, "MIDI Tracks")
    imgui.PopFont(ctx)
    
    local midi_height = content_height * config.LAYOUT.MIDI_SECTION_RATIO
    imgui.SetCursorScreenPos(ctx, config.LAYOUT.PADDING, content_start_y + config.LAYOUT.HEADER_HEIGHT)
    if imgui.BeginChild(ctx, "midi_container", SCREEN_W - (config.LAYOUT.PADDING * 2), midi_height, 0, imgui.WindowFlags_NoScrollbar | imgui.WindowFlags_NoScrollWithMouse) then
      state.midi_grid:draw(ctx)
      imgui.EndChild(ctx)
    end
  end
  
  if state.audio_grid then
    local audio_start_y = content_start_y + (content_height * config.LAYOUT.MIDI_SECTION_RATIO) + config.LAYOUT.SECTION_SPACING
    imgui.SetCursorScreenPos(ctx, config.LAYOUT.PADDING, audio_start_y)
    imgui.PushFont(ctx, big_font)
    imgui.Text(ctx, "Audio Sources")
    imgui.PopFont(ctx)
    
    local audio_height = content_height * config.LAYOUT.AUDIO_SECTION_RATIO
    imgui.SetCursorScreenPos(ctx, config.LAYOUT.PADDING, audio_start_y + config.LAYOUT.HEADER_HEIGHT)
    if imgui.BeginChild(ctx, "audio_container", SCREEN_W - (config.LAYOUT.PADDING * 2), audio_height, 0, imgui.WindowFlags_NoScrollbar | imgui.WindowFlags_NoScrollWithMouse) then
      state.audio_grid:draw(ctx)
      imgui.EndChild(ctx)
    end
  end

  imgui.End(ctx)
end

return M
-- @noindex
local ImGui = require 'imgui' '0.10'

local M = {}
local utils
local grid_adapter
local reaper_interface
local config
local shortcuts
local disabled_items

function M.init(utils_module, grid_adapter_module, reaper_interface_module, config_module, shortcuts_module, disabled_items_module)
  utils = utils_module
  grid_adapter = grid_adapter_module
  reaper_interface = reaper_interface_module
  config = config_module
  shortcuts = shortcuts_module
  disabled_items = disabled_items_module
  
  if not disabled_items then error("disabled_items module required") end
end

function M.MainWindow(ctx, state, settings, big_font, SCRIPT_TITLE, SCREEN_W, SCREEN_H)
  local window_flags = ImGui.WindowFlags_NoCollapse | ImGui.WindowFlags_NoTitleBar | ImGui.WindowFlags_NoResize |
      ImGui.WindowFlags_NoMove | ImGui.WindowFlags_NoScrollbar | ImGui.WindowFlags_NoScrollWithMouse

  local imgui_visible, imgui_open = ImGui.Begin(ctx, SCRIPT_TITLE, true, window_flags)

  if ImGui.Checkbox(ctx, "Play Item Through Track (will add delay to preview playback)", settings.play_item_through_track) then
    settings.play_item_through_track = not settings.play_item_through_track
  end
  
  if ImGui.Checkbox(ctx, "Show Muted Tracks", settings.show_muted_tracks) then
    state.samples, state.sample_indexes, state.midi_tracks = nil, nil, nil
    settings.show_muted_tracks = not settings.show_muted_tracks
  end

  if ImGui.Checkbox(ctx, "Show Muted Items", settings.show_muted_items) then
    state.samples, state.sample_indexes, state.midi_tracks = nil, nil, nil
    settings.show_muted_items = not settings.show_muted_items
  end
  
  ImGui.SameLine(ctx)
  if ImGui.Checkbox(ctx, "Show Disabled Items", settings.show_disabled_items) then
    settings.show_disabled_items = not settings.show_disabled_items
  end
  
  if state.disabled then
    local audio_disabled, midi_disabled = disabled_items.get_disabled_count(state.disabled)
    if audio_disabled > 0 or midi_disabled > 0 then
      ImGui.SameLine(ctx)
      ImGui.Text(ctx, string.format("(%d audio, %d midi disabled)", audio_disabled, midi_disabled))
      
      ImGui.SameLine(ctx)
      if ImGui.SmallButton(ctx, "Clear All Disabled") then
        disabled_items.clear_all(state.disabled)
      end
    end
  end

  local focus_search = shortcuts.handle_search_shortcuts(ctx, settings)
  
  shortcuts.handle_tile_size_shortcuts(ctx, state)
  
  if not state.samples then
    state.samples, state.sample_indexes = reaper_interface.GetProjectSamples(settings, state)
    state.midi_tracks = reaper_interface.GetProjectMidiTracks(settings, state)
    
    state.midi_grid = grid_adapter.create_midi_grid(ctx, state, settings)
    state.audio_grid = grid_adapter.create_audio_grid(ctx, state, settings)
  end
  
  ImGui.PushFont(ctx, big_font, 14)
  local search_text_w, search_text_h = ImGui.CalcTextSize(ctx, "Search:")
  ImGui.DrawList_AddText(state.draw_list, SCREEN_W / 2 - search_text_w / 2, SCREEN_H * config.LAYOUT.CONTENT_START_Y - search_text_h, 0xFFFFFFFF, "Search:")

  ImGui.SetCursorScreenPos(ctx, SCREEN_W / 2 - (SCREEN_W * config.LAYOUT.SEARCH_WIDTH_RATIO) / 2, SCREEN_H * config.LAYOUT.CONTENT_START_Y)
  ImGui.PushItemWidth(ctx, SCREEN_W * config.LAYOUT.SEARCH_WIDTH_RATIO)
  if (not state.initialized and settings.focus_keyboard_on_init) or focus_search then
    ImGui.SetKeyboardFocusHere(ctx)
    state.initialized = true
  end
  _, settings.search_string = ImGui.InputText(ctx, "##Search", settings.search_string)
  ImGui.PopFont(ctx)

  local content_start_y = SCREEN_H * config.LAYOUT.CONTENT_START_Y
  local content_height = SCREEN_H * config.LAYOUT.CONTENT_HEIGHT
  
  if state.midi_grid then
    ImGui.SetCursorScreenPos(ctx, config.LAYOUT.PADDING, content_start_y)
    ImGui.PushFont(ctx, big_font, 14)
    ImGui.Text(ctx, "MIDI Tracks")
    ImGui.PopFont(ctx)
    
    local midi_height = content_height * config.LAYOUT.MIDI_SECTION_RATIO
    ImGui.SetCursorScreenPos(ctx, config.LAYOUT.PADDING, content_start_y + config.LAYOUT.HEADER_HEIGHT)
    if ImGui.BeginChild(ctx, "midi_container", SCREEN_W - (config.LAYOUT.PADDING * 2), midi_height, 0, ImGui.WindowFlags_NoScrollbar | ImGui.WindowFlags_NoScrollWithMouse) then
      state.midi_grid:draw(ctx)
      ImGui.EndChild(ctx)
    end
  end
  
  if state.audio_grid then
    local audio_start_y = content_start_y + (content_height * config.LAYOUT.MIDI_SECTION_RATIO) + config.LAYOUT.SECTION_SPACING
    ImGui.SetCursorScreenPos(ctx, config.LAYOUT.PADDING, audio_start_y)
    ImGui.PushFont(ctx, big_font, 15)
    ImGui.Text(ctx, "Audio Sources")
    ImGui.PopFont(ctx)
    
    local audio_height = content_height * config.LAYOUT.AUDIO_SECTION_RATIO
    ImGui.SetCursorScreenPos(ctx, config.LAYOUT.PADDING, audio_start_y + config.LAYOUT.HEADER_HEIGHT)
    if ImGui.BeginChild(ctx, "audio_container", SCREEN_W - (config.LAYOUT.PADDING * 2), audio_height, 0, ImGui.WindowFlags_NoScrollbar | ImGui.WindowFlags_NoScrollWithMouse) then
      state.audio_grid:draw(ctx)
      ImGui.EndChild(ctx)
    end
  end

  ImGui.End(ctx)
end

return M
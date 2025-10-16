# ITEMPICKER FLOW
Generated: 2025-10-16 01:20:52

## Overview
- **Folders**: 1
- **Files**: 15
- **Total Lines**: 2,118
- **Code Lines**: 1,756
- **Exports**: 76
- **Classes**: 3

## Folder Organization

### ARKITEKT/scripts/ItemPicker
- Files: 15
- Lines: 1,756
- Exports: 76

## Module API

### `ARKITEKT/scripts/ItemPicker/ARK_ItemPicker.lua` (161 lines)
**Exports**:
  - `table.getn(tab)`
**Private**: 4 helpers
**Requires**: `rearkitekt.gui.widgets.grid.core`

### `ARKITEKT/scripts/ItemPicker/app/cache_manager.lua` (134 lines)
**Modules**: `M, entries`
**Classes**: `M`
**Exports**:
  - `M.new(max_entries)` → Instance
  - `M.get_item_signature(item)`
  - `M.cleanup_old_entries(cache_table, access_times, max_entries)`
  - `M.get_waveform_data(cache, item)`
  - `M.set_waveform_data(cache, item, data)`
  - `M.get_midi_thumbnail(cache, item, width, height)`
  - `M.set_midi_thumbnail(cache, item, width, height, data)`
  - `M.invalidate_item(cache, item)`
  - `M.get_stats(cache)`

### `ARKITEKT/scripts/ItemPicker/app/config.lua` (59 lines)
**Modules**: `M`
**Exports**:
  - `M.validate()`

### `ARKITEKT/scripts/ItemPicker/app/disabled_items.lua` (62 lines)
**Modules**: `M`
**Classes**: `M`
**Exports**:
  - `M.new()` → Instance
  - `M.is_disabled_audio(disabled, filename)`
  - `M.is_disabled_midi(disabled, track_idx)`
  - `M.toggle_audio(disabled, filename)`
  - `M.toggle_midi(disabled, track_idx)`
  - `M.clear_audio(disabled)`
  - `M.clear_midi(disabled)`
  - `M.clear_all(disabled)`
  - `M.get_disabled_count(disabled)`

### `ARKITEKT/scripts/ItemPicker/app/drag_drop.lua` (148 lines)
**Modules**: `M`
**Exports**:
  - `M.init(imgui_module, imgui_ctx, visualization_module)`
  - `M.DragDropLogic(state, mini_font)`
  - `M.DraggingThumbnailWindow(state, mini_font)`

### `ARKITEKT/scripts/ItemPicker/app/grid_adapter.lua` (342 lines)
**Modules**: `M, filtered, filtered`
**Exports**:
  - `M.init(imgui_module, imgui_ctx, Grid_module, visualization_module, cache_manager_module, config_module, shortcuts_module, tile_rendering_module, disabled_items_module)`
  - `M.create_audio_grid(state, settings)` → Instance
  - `M.create_midi_grid(state, settings)` → Instance
**Private**: 6 helpers

### `ARKITEKT/scripts/ItemPicker/app/job_queue.lua` (66 lines)
**Modules**: `M`
**Classes**: `M`
**Exports**:
  - `M.new(max_per_frame)` → Instance
  - `M.add_bitmap_job(job_queue, item, width, height, color, cache_key)`
  - `M.process_jobs(job_queue, cache, visualization, imgui_ctx)`
  - `M.get_queue_length(job_queue)`
  - `M.clear(job_queue)`
  - `M.has_job(job_queue, cache_key)`

### `ARKITEKT/scripts/ItemPicker/app/main_ui.lua` (120 lines)
**Modules**: `M`
**Exports**:
  - `M.init(imgui_module, imgui_ctx, utils_module, grid_adapter_module, reaper_interface_module, config_module, shortcuts_module, disabled_items_module)`
  - `M.MainWindow(state, settings, big_font, SCRIPT_TITLE, SCREEN_W, SCREEN_H)`

### `ARKITEKT/scripts/ItemPicker/app/pickle.lua` (85 lines)
**Modules**: `M, nt, tcopy`
**Exports**:
  - `M.Pickle(t)`
  - `M.Unpickle(s)`

### `ARKITEKT/scripts/ItemPicker/app/reaper_interface.lua` (220 lines)
**Modules**: `M, tracks, items, chunks, item_chunks, samples, sample_indexes, midi_tracks, track_midi`
**Exports**:
  - `M.init(utils_module)`
  - `M.GetAllTracks()`
  - `M.GetTrackID(track)`
  - `M.GetItemInTrack(track)`
  - `M.TrackIsFrozen(track, track_chunks)`
  - `M.IsParentFrozen(track, track_chunks)`
  - `M.IsParentMuted(track)`
  - `M.GetAllTrackStateChunks()`
  - `M.GetAllCleanedItemChunks()`
  - `M.ItemChunkID(item)`
  - `M.GetProjectSamples(settings, state)`
  - `M.GetProjectMidiTracks(settings, state)`
  - `M.InsertItemAtMousePos(item, state)`

### `ARKITEKT/scripts/ItemPicker/app/shortcuts.lua` (92 lines)
**Modules**: `M`
**Exports**:
  - `M.init(imgui_module, imgui_ctx, config_module)`
  - `M.handle_tile_size_shortcuts(state)`
  - `M.handle_search_shortcuts(settings)`
  - `M.get_tile_width(state)`
  - `M.get_tile_height(state)`

### `ARKITEKT/scripts/ItemPicker/app/tile_rendering.lua` (125 lines)
**Modules**: `M`
**Exports**:
  - `M.init(imgui_module, imgui_ctx, config_module)`
  - `M.hsv_to_rgb(h, s, v)`
  - `M.rgb_to_hsv(r, g, b)`
  - `M.derive_border_color(base_color)`
  - `M.derive_fill_color(base_color, hover_factor)`
  - `M.render_tile_background(dl, x1, y1, x2, y2, base_color, is_hovered, is_disabled)`
  - `M.render_tile_header(dl, x1, y1, x2, text_h, base_color, text, count_text)`

### `ARKITEKT/scripts/ItemPicker/app/ui_content.lua` (212 lines)
**Modules**: `M`
**Exports**:
  - `M.init(imgui_module, imgui_ctx, utils_module, visualization_module, reaper_interface_module)`
  - `M.ContentTable(content_table, name, num_boxes, box_w, box_h, table_x, table_y, table_w, table_h, state, settings, SCREEN_H)`

### `ARKITEKT/scripts/ItemPicker/app/utils.lua` (35 lines)
**Modules**: `M`
**Exports**:
  - `M.getn(tab)`
  - `M.RGBvalues(RGB)`
  - `M.Color(imgui, r, g, b, a)`
  - `M.SampleLimit(spl)`
  - `M.RemoveKeyFromChunk(chunk_string, key)`

### `ARKITEKT/scripts/ItemPicker/app/visualization.lua` (257 lines)
**Modules**: `M, downsampled, thumbnail`
**Exports**:
  - `M.init(utils_module, imgui_module, imgui_ctx, script_dir, cache_mgr)`
  - `M.GetItemWaveform(cache, item)`
  - `M.DownsampleWaveform(waveform, target_width)`
  - `M.DisplayWaveform(waveform, color, draw_list, target_width)`
  - `M.GetNoteRange(take)`
  - `M.GetMidiThumbnail(cache, item)`
  - `M.DisplayMidiItem(thumbnail, color, draw_list)`
  - `M.DisplayPreviewLine(preview_start, preview_end, draw_list)`

## Internal Dependencies

No internal dependencies within this feature

## External Dependencies

**`ARKITEKT/rearkitekt/gui/widgets/grid/core.lua`** (used by 1 files)
  ← `ARKITEKT/scripts/ItemPicker/ARK_ItemPicker.lua`

local M = {}
local imgui
local ctx
local utils
local visualization
local reaper_interface

function M.init(imgui_module, imgui_ctx, utils_module, visualization_module, reaper_interface_module)
  imgui = imgui_module
  ctx = imgui_ctx
  utils = utils_module
  visualization = visualization_module
  reaper_interface = reaper_interface_module
end

function M.ContentTable(content_table, name, num_boxes, box_w, box_h, table_x, table_y, table_w, table_h, state, settings, SCREEN_H)
  local cache_mgr = state.cache_manager
  local job_q = state.job_queue_module
  
  if not cache_mgr then
    reaper.ShowConsoleMsg("ERROR: state.cache_manager is nil in ContentTable!\n")
    return
  end
  
  imgui.SetCursorScreenPos(ctx, table_x, table_y)
  local name_w, name_h = imgui.CalcTextSize(ctx, name)
  imgui.DrawList_AddText(state.draw_list, table_x + table_w / 2 - name_w / 2, table_y - name_h, 0xFFFFFFFF, name)
  local scroll_size = imgui.GetStyleVar(ctx, imgui.StyleVar_ScrollbarSize)
  if not state.scroll_y[name] then
    state.scroll_y[name] = 0
  end

  if table_h > SCREEN_H * 0.7 then
    local text = "(Shift + Scroll)"
    local text_w, text_h = imgui.CalcTextSize(ctx, text)
    imgui.DrawList_AddText(state.draw_list, table_x + table_w - text_w, table_y + SCREEN_H * 0.7, 0xFFFFFFFF, text)
  end

  imgui.SetNextWindowScroll(ctx, 0, state.scroll_y[name])
  if imgui.BeginChild(ctx, "Child" .. table_x, table_w + scroll_size, SCREEN_H * 0.7, 0, imgui.WindowFlags_NoScrollWithMouse) then
    if imgui.IsKeyDown(ctx, imgui.Key_LeftShift) and imgui.GetMouseWheel(ctx) ~= 0 and imgui.IsMouseHoveringRect(ctx, table_x, table_y, table_x + table_w + scroll_size, table_y + table_h) then
      state.scroll_y[name] = math.min(imgui.GetScrollMaxY(ctx),
        math.max(0, state.scroll_y[name] - imgui.GetMouseWheel(ctx) * 100))
    end
    if imgui.BeginTable(ctx, "Table" .. table_x, num_boxes, 0, 0, 0) then
      box_w = box_w - imgui.GetStyleVar(ctx, imgui.StyleVar_CellPadding)
      for content_key, content in ipairs(content_table) do
        content_key = content_key + table_x
        if not state.box_current_item[content_key] then
          state.box_current_item[content_key] = 1
        end

        local filepath
        local box_name
        local item
        local track
        if type(content) == "string" then
          filepath = content
          content = state.samples[content]
          if state.box_current_item[content_key] > #content then
            state.box_current_item[content_key] = 1
          end
          box_name = content[state.box_current_item[content_key]][2]
          item = content[state.box_current_item[content_key]][1]
          track = reaper.GetMediaItemTrack(item)
        else
          item = content[state.box_current_item[content_key]]
          track = reaper.GetMediaItemTrack(item)
          _, box_name = reaper.GetTrackName(track)
        end

        if settings.search_string ~= 0 then
          if not box_name:lower():find(settings.search_string:lower()) then
            goto next
          end
        end

        local take = reaper.GetActiveTake(item)
        local track_muted = reaper.GetMediaTrackInfo_Value(track, "B_MUTE") == 1 or reaper_interface.IsParentMuted(track) == true
        local item_muted = reaper.GetMediaItemInfo_Value(item, "B_MUTE") == 1
        local track_color = reaper.GetMediaTrackInfo_Value(reaper.GetMediaItemTrack(item), "I_CUSTOMCOLOR")
        local r, g, b = 85 / 256, 91 / 256, 91 / 256
        if track_color ~= 16576 and track_color > 0 then
          r, g, b = utils.RGBvalues(track_color)
        end

        track_color = imgui.ColorConvertDouble4ToU32(r, g, b, 1)

        imgui.TableNextColumn(ctx)
        imgui.PushStyleVar(ctx, imgui.StyleVar_ItemSpacing, 0, 0)
        local text_height_spacing = imgui.GetTextLineHeightWithSpacing(ctx)
        local text_height = imgui.GetTextLineHeight(ctx)

        imgui.Dummy(ctx, box_w, text_height_spacing)
        local box_x1, box_y1 = imgui.GetItemRectMin(ctx)

        if imgui.InvisibleButton(ctx, content_key, box_w, box_h - text_height_spacing) and not track_muted then
          reaper.SelectAllMediaItems(0, false)
          reaper.SetMediaItemSelected(item, true)
          if reaper.TakeIsMIDI(take) then
            local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            reaper.SetEditCurPos(item_pos, false, false)
            reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_PREVIEWTRACK"), 0)
          else
            if settings.play_item_through_track then
              reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_PREVIEWTRACK"), 0)
            else
              reaper.Main_OnCommand(reaper.NamedCommandLookup("_XENAKIOS_ITEMASPCM1"), 0)
            end
          end

          state.preview_start = reaper.time_precise() + reaper.GetOutputLatency()
          local length = math.min(
            reaper.GetMediaItemInfo_Value(item, "D_LENGTH"),
            (reaper.GetMediaSourceLength(reaper.GetMediaItemTake_Source(take)) - reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")) *
            (1 / reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE"))
          )
          state.preview_end = state.preview_start + length + reaper.GetOutputLatency()
          state.previewing = state.box_current_item[content_key] .. content_key
        end
        imgui.PopStyleVar(ctx, 1)

        local box_x2, box_y2 = imgui.GetItemRectMax(ctx)
        if imgui.IsRectVisibleEx(ctx, box_x1, box_y1, box_x2, box_y2) then
          imgui.DrawList_AddRectFilled(state.draw_list, box_x1, box_y1, box_x1 + box_w,
            box_y1 + text_height_spacing, track_color, 2)
          imgui.DrawList_AddRectFilled(state.draw_list, box_x1, box_y1, box_x1 + box_w,
            box_y1 + text_height_spacing, 0x00000050, 2)
          imgui.DrawList_AddRectFilled(state.draw_list, box_x1, box_y1 + text_height,
            box_x2, box_y2, track_color)

          if reaper.TakeIsMIDI(take) then
            imgui.DrawList_AddText(state.draw_list, box_x1, box_y1, 0xFFFFFFFF, box_name)

            local thumbnail = cache_mgr.get_midi_thumbnail(state.cache, item, box_x2 - box_x1, box_y2 - box_y1)
            if not thumbnail then
              thumbnail = visualization.GetMidiThumbnail(state.cache, item)
            end
            if thumbnail then
              visualization.DisplayMidiItem(thumbnail, track_color, state.draw_list)
            end
          else
            imgui.DrawList_AddText(state.draw_list, box_x1, box_y1, 0xFFFFFFFF, box_name)

            local bitmap = cache_mgr.get_bitmap(state.cache, item, box_w, box_h, track_color)
            if bitmap then
              imgui.DrawList_AddImage(state.draw_list, bitmap, box_x1,
                box_y1 + text_height_spacing, box_x2, box_y2)
            elseif not job_q.has_job(state.job_queue, state.box_current_item[content_key] .. content_key) then
              job_q.add_bitmap_job(
                state.job_queue,
                item,
                box_w,
                box_h,
                track_color,
                state.box_current_item[content_key] .. content_key
              )
            end
          end

          if #content > 1 then
            local item_num_string = string.format("%.0f", state.box_current_item[content_key]) .. "/" .. #content .. " "
            imgui.DrawList_AddText(state.draw_list, box_x2 - imgui.CalcTextSize(ctx, item_num_string),
              box_y1 + text_height_spacing, 0xFFFFFFFF, item_num_string)
          end

          if state.previewing == state.box_current_item[content_key] .. content_key then
            visualization.DisplayPreviewLine(state.preview_start, state.preview_end, state.draw_list)
          end

          if track_muted then
            imgui.DrawList_AddRectFilled(state.draw_list, box_x1, box_y1, box_x2, box_y2, 0x00000090, 2)
            local str_w, str_h = imgui.CalcTextSize(ctx, "Track Muted")
            imgui.DrawList_AddText(state.draw_list, box_x1 + (box_x2 - box_x1) / 2 - str_w / 2,
              box_y1 + (box_y2 - box_y1) / 2 - str_h / 2, 0xFF000090, "Track Muted")
          elseif item_muted then
            imgui.DrawList_AddRectFilled(state.draw_list, box_x1, box_y1, box_x2, box_y2, 0x00000090, 2)
            local str_w, str_h = imgui.CalcTextSize(ctx, "Item Muted")
            imgui.DrawList_AddText(state.draw_list, box_x1 + (box_x2 - box_x1) / 2 - str_w / 2,
              box_y1 + (box_y2 - box_y1) / 2 - str_h / 2, 0xFF000090, "Item Muted")
          end

          if imgui.BeginDragDropSource(ctx, imgui.DragDropFlags_SourceNoPreviewTooltip) then
            state.item_to_add = item
            state.item_to_add_width = math.max(imgui.CalcTextSize(ctx, " " .. box_name), box_w)
            state.item_to_add_height = box_h
            state.item_to_add_color = track_color
            state.item_to_add_visual_index = state.box_current_item[content_key] .. content_key
            state.item_to_add_name = box_name
            state.drag_bounds = { box_x1, box_y1, box_x2, box_y2 }
            imgui.EndDragDropSource(ctx)
          end

          if imgui.IsMouseHoveringRect(ctx, box_x1, box_y1, box_x2, box_y2) then
            imgui.DrawList_AddRectFilled(state.draw_list, box_x1, box_y1, box_x2, box_y2, 0xFFFFFF30, 2)

            if imgui.GetMouseWheel(ctx) ~= 0 then
              state.box_current_item[content_key] = math.max(
                math.min(state.box_current_item[content_key] + imgui.GetMouseWheel(ctx), #content), 1)
            end
          end
        end

        ::next::
      end
      imgui.EndTable(ctx)
    end
    imgui.EndChild(ctx)
  end
end

return M
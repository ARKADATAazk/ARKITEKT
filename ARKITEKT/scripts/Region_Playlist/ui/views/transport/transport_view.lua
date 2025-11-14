-- @noindex
-- Region_Playlist/ui/views/transport/transport_view.lua
-- Transport section view orchestrator

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local TransportContainer = require('Region_Playlist.ui.views.transport.transport_container')
local TransportIcons = require('Region_Playlist.ui.views.transport.transport_icons')
local ButtonWidgets = require('Region_Playlist.ui.views.transport.button_widgets')
local DisplayWidget = require('Region_Playlist.ui.views.transport.display_widget')
local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

local TransportView = {}
TransportView.__index = TransportView

function M.new(config, state_module)
  local self = setmetatable({
    config = config,
    state = state_module,
    container = nil,
    view_mode_button = ButtonWidgets.ViewModeButton_new(config.view_mode),
    transport_display = DisplayWidget.new(config.display),
  }, TransportView)
  
  self.container = TransportContainer.new({
    id = "region_playlist_transport",
    height = config.height,
    button_height = 30,
    header_elements = {},
    config = {
      fx = config.fx,
      background_pattern = config.background_pattern,
      panel_bg_color = config.panel_bg_color,
    },
  })
  
  return self
end

function TransportView:get_region_colors()
  local bridge = self.state.get_bridge()
  if not bridge then return {} end
  
  local bridge_state = bridge:get_state()
  if not bridge_state.is_playing then
    return {}
  end
  
  local current_rid = bridge:get_current_rid()
  if not current_rid then
    return {}
  end
  
  local current_region = self.state.get_region_by_rid(current_rid)
  local current_color = current_region and current_region.color or nil
  
  local sequence = bridge:get_sequence()
  if not sequence or #sequence == 0 then
    return { current = current_color }
  end
  
  local current_idx = bridge:get_state().playlist_pointer
  if not current_idx or current_idx < 1 then
    return { current = current_color }
  end
  
  local next_rid = nil
  for i = current_idx + 1, #sequence do
    local entry = sequence[i]
    if entry and entry.rid and entry.rid ~= current_rid then
      next_rid = entry.rid
      break
    end
  end
  
  if not next_rid then
    return { current = current_color }
  end
  
  local next_region = self.state.get_region_by_rid(next_rid)
  local next_color = next_region and next_region.color or nil
  
  return { current = current_color, next = next_color }
end

function TransportView:build_header_elements(bridge_state)
  bridge_state = bridge_state or {}
  
  return {
    {
      type = "button",
      id = "transport_play",
      align = "center",
      width = 34,
      config = {
        is_toggled = bridge_state.is_playing or false,
        preset_name = "BUTTON_TOGGLE_ACCENT",
        custom_draw = function(ctx, dl, bx, by, bw, bh, is_hovered, is_active, text_color)
          TransportIcons.draw_play(dl, bx, by, bw, bh, text_color)
        end,
        tooltip = "Play/Pause",
        on_click = function()
          local bridge = self.state.get_bridge()
          local is_playing = bridge:get_state().is_playing
          if is_playing then
            bridge:stop()
          else
            bridge:play()
          end
        end,
      },
    },
    {
      type = "button",
      id = "transport_stop",
      align = "center",
      width = 34,
      config = {
        custom_draw = function(ctx, dl, bx, by, bw, bh, is_hovered, is_active, text_color)
          TransportIcons.draw_stop(dl, bx, by, bw, bh, text_color)
        end,
        tooltip = "Stop",
        on_click = function()
          self.state.get_bridge():stop()
        end,
      },
    },
    {
      type = "button",
      id = "transport_loop",
      align = "center",
      width = 34,
      config = {
        is_toggled = bridge_state.loop_enabled or false,
        preset_name = "BUTTON_TOGGLE_ACCENT",
        custom_draw = function(ctx, dl, bx, by, bw, bh, is_hovered, is_active, text_color)
          TransportIcons.draw_loop(dl, bx, by, bw, bh, text_color)
        end,
        tooltip = "Loop",
        on_click = function()
          local bridge = self.state.get_bridge()
          local current_state = bridge:get_loop_playlist()
          bridge:set_loop_playlist(not current_state)
        end,
      },
    },
    {
      type = "button",
      id = "transport_jump",
      align = "center",
      width = 46,
      config = {
        custom_draw = function(ctx, dl, bx, by, bw, bh, is_hovered, is_active, text_color)
          TransportIcons.draw_jump(dl, bx, by, bw, bh, text_color)
        end,
        tooltip = "Jump Forward",
        on_click = function()
          local bridge = self.state.get_bridge()
          local success = bridge:jump_to_next_quantized(self.config.quantize_lookahead)

          if success and self.state.set_state_change_notification then
            local bridge_state = bridge:get_state()
            local quantize_mode = bridge_state.quantize_mode or "none"

            -- Get next region info
            if bridge_state.playlist_order and bridge_state.playlist_pointer then
              local next_idx = bridge_state.playlist_pointer + 1
              if next_idx <= #bridge_state.playlist_order then
                local next_rid = bridge_state.playlist_order[next_idx]
                local next_region = self.state.get_region_by_rid and self.state.get_region_by_rid(next_rid)

                if next_region then
                  local msg = string.format("Jump: Next → '%s' (Quantize: %s)", next_region.name, quantize_mode)
                  self.state.set_state_change_notification(msg)
                end
              end
            end
          end
        end,
      },
    },
    {
      type = "dropdown_field",
      id = "transport_measure",
      align = "center",
      width = 85,
      config = {
        tooltip = "Grid/Quantize Mode",
        current_value = bridge_state.quantize_mode,
        options = {
          { value = "4bar", label = "4 Bars" },
          { value = "2bar", label = "2 Bars" },
          { value = "measure", label = "1 Bar" },
          { value = "beat", label = "Beat" },
          { value = 1, label = "1/1" },
          { value = 0.5, label = "1/2" },
          { value = 0.25, label = "1/4" },
          { value = 0.125, label = "1/8" },
          { value = 0.0625, label = "1/16" },
          { value = 0.03125, label = "1/32" },
        },
        enable_mousewheel = true,
        on_change = function(new_value)
          self.state.get_bridge():set_quantize_mode(new_value)
        end,
        -- >>> FOOTER: LOOKAHEAD SLIDER (BEGIN)
        footer_content = function(footer_ctx)
          local ctx = footer_ctx.ctx
          local dl = footer_ctx.dl
          local width = footer_ctx.width
          local padding = footer_ctx.padding
          
          -- Label
          local label = "Jump Lookahead"
          local label_x, label_y = ImGui.GetCursorScreenPos(ctx)
          local label_color = Colors.hexrgb("#CCCCCCFF")
          ImGui.DrawList_AddText(dl, label_x + padding, label_y, label_color, label)
          ImGui.Dummy(ctx, width, 18)
          
          -- Slider
          local slider_x, slider_y = ImGui.GetCursorScreenPos(ctx)
          ImGui.SetCursorScreenPos(ctx, slider_x + padding, slider_y)
          ImGui.SetNextItemWidth(ctx, width - padding * 2)
          
          local lookahead_ms = self.config.quantize_lookahead * 1000
          local changed, new_val = ImGui.SliderDouble(ctx, "##quantize_lookahead", lookahead_ms, 200, 1000, "%.0fms")
          
          if changed then
            self.config.quantize_lookahead = new_val / 1000
            -- Persist to settings
            if self.state.settings then
              self.state.settings:set('quantize_lookahead', self.config.quantize_lookahead)
            end
          end
          
          ImGui.Dummy(ctx, width, 4)
        end,
        -- <<< FOOTER: LOOKAHEAD SLIDER (END)
      },
    },
    {
      type = "button",
      id = "transport_override",
      align = "center",
      width = 70,
      config = {
        label = "Override",
        is_toggled = bridge_state.override_enabled or false,
        preset_name = "BUTTON_TOGGLE_ACCENT",
        tooltip = "Override Quantization",
        on_click = function()
          local bridge = self.state.get_bridge()
          local engine = bridge.engine
          if engine then
            local current_state = engine:get_transport_override()
            engine:set_transport_override(not current_state)
          end
        end,
      },
    },
    {
      type = "button",
      id = "transport_follow",
      align = "center",
      width = 110,
      config = {
        label = "Follow Viewport",
        is_toggled = bridge_state.follow_viewport or false,
        preset_name = "BUTTON_TOGGLE_ACCENT",
        tooltip = "Follow Playhead in Viewport",
        on_click = function()
          reaper.ShowConsoleMsg("Follow Viewport toggle not yet implemented\n")
        end,
      },
    },
  }
end

function TransportView:draw(ctx, shell_state)
  local bridge = self.state.get_bridge()
  local engine = bridge.engine
  local bridge_state = {
    is_playing = bridge:get_state().is_playing,
    time_remaining = bridge:get_time_remaining(),
    progress = bridge:get_progress() or 0,
    quantize_mode = bridge:get_state().quantize_mode,
    loop_enabled = bridge:get_loop_playlist(),
    override_enabled = engine and engine:get_transport_override() or false,
    follow_viewport = false,
  }
  
  self.container:set_header_elements(self:build_header_elements(bridge_state))
  
  local spacing = self.config.spacing
  local transport_height = self.config.height
  
  local transport_start_x, transport_start_y = ImGui.GetCursorScreenPos(ctx)
  
  local region_colors = self:get_region_colors()
  local content_w, content_h = self.container:begin_draw(ctx, region_colors)
  
  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  
  local active_playlist = self.state.get_active_playlist()
  local playlist_data = active_playlist and {
    name = active_playlist.name,
    color = active_playlist.chip_color or hexrgb("#888888"),
  } or nil
  
  local current_region = nil
  local next_region = nil
  
  if bridge then
    local current_rid = bridge:get_current_rid()
    if current_rid then
      current_region = self.state.get_region_by_rid(current_rid)
      
      local sequence = bridge:get_sequence()
      if sequence and #sequence > 0 then
        local current_idx = bridge:get_state().playlist_pointer
        if current_idx and current_idx >= 1 then
          for i = current_idx + 1, #sequence do
            local entry = sequence[i]
            if entry and entry.rid and entry.rid ~= current_rid then
              next_region = self.state.get_region_by_rid(entry.rid)
              break
            end
          end
        end
      end
    end
  end
  
  local display_x = cursor_x
  local display_w = content_w
  local display_y = cursor_y
  local display_h = content_h
  
  local time_font = shell_state and shell_state.fonts and shell_state.fonts.time_display or nil
  self.transport_display:draw(ctx, display_x, display_y, display_w, display_h, 
    bridge_state, current_region, next_region, playlist_data, region_colors, time_font)
  
  self.container:end_draw(ctx)
  
  local view_mode_size = self.config.view_mode.size
  local view_x = transport_start_x + 8
  local view_y = transport_start_y + (transport_height - view_mode_size) / 2
  
  self.view_mode_button:draw(ctx, view_x, view_y, self.state.get_layout_mode(), function()
    local new_mode = (self.state.get_layout_mode() == 'horizontal') and 'vertical' or 'horizontal'
    self.state.set_layout_mode(new_mode)
    self.state.persist_ui_prefs()
  end, true)
  
  ImGui.SetCursorScreenPos(ctx, transport_start_x, transport_start_y + transport_height)
end

return M

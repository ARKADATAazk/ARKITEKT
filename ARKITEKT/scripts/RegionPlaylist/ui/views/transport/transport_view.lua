-- @noindex
-- RegionPlaylist/ui/views/transport/transport_view.lua
-- Transport section view orchestrator

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local TransportContainer = require('RegionPlaylist.ui.views.transport.transport_container')
local TransportIcons = require('RegionPlaylist.ui.views.transport.transport_icons')
local ButtonWidgets = require('RegionPlaylist.ui.views.transport.button_widgets')
local DisplayWidget = require('RegionPlaylist.ui.views.transport.display_widget')
local CoreConfig = require('RegionPlaylist.core.config')
local Strings = require('RegionPlaylist.defs.strings')
local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

local TransportView = {}
TransportView.__index = TransportView

function M.new(config, state_module)
  local self = setmetatable({
    config = config,
    state = state_module,
    container = nil,
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
      corner_buttons = config.corner_buttons,
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

-- >>> MODULAR BUTTON BUILDERS (BEGIN)
-- These functions build individual button elements using config as single source of truth

function TransportView:build_play_button(bridge_state)
  return {
    type = "button",
    id = "transport_play",
    align = "center",
    width = CoreConfig.TRANSPORT_BUTTONS.play.width,
    config = {
      is_toggled = bridge_state.is_playing or false,
      preset_name = "BUTTON_TOGGLE_WHITE",
      custom_draw = function(ctx, dl, bx, by, bw, bh, is_hovered, is_active, text_color)
        TransportIcons.draw_play(dl, bx, by, bw, bh, text_color)
      end,
      tooltip = Strings.TRANSPORT.play,
      on_click = function()
        local bridge = self.state.get_bridge()
        local is_playing = bridge:get_state().is_playing
        if is_playing then
          bridge:stop()
          if self.container then
            self.container:cancel_jump_flash()
          end
        else
          bridge:play()
        end
      end,
    },
  }
end

function TransportView:build_stop_button()
  return {
    type = "button",
    id = "transport_stop",
    align = "center",
    width = CoreConfig.TRANSPORT_BUTTONS.stop.width,
    config = {
      custom_draw = function(ctx, dl, bx, by, bw, bh, is_hovered, is_active, text_color)
        TransportIcons.draw_stop(dl, bx, by, bw, bh, text_color)
      end,
      tooltip = Strings.TRANSPORT.stop,
      on_click = function()
        self.state.get_bridge():stop()
        if self.container then
          self.container:cancel_jump_flash()
        end
      end,
    },
  }
end

function TransportView:build_pause_button(bridge_state)
  -- Get paused state from bridge
  local bridge = self.state.get_bridge()
  local is_paused = bridge and bridge.engine and bridge.engine.transport.is_paused or false

  return {
    type = "button",
    id = "transport_pause",
    align = "center",
    width = CoreConfig.TRANSPORT_BUTTONS.pause.width,
    config = {
      is_toggled = is_paused,
      preset_name = "BUTTON_TOGGLE_WHITE",
      custom_draw = function(ctx, dl, bx, by, bw, bh, is_hovered, is_active, text_color)
        TransportIcons.draw_pause(dl, bx, by, bw, bh, text_color)
      end,
      tooltip = Strings.TRANSPORT.pause,
      on_click = function()
        local bridge = self.state.get_bridge()
        -- If already paused, resume by calling play instead
        if bridge and bridge.engine and bridge.engine.transport.is_paused then
          bridge:play()
        else
          bridge:pause()
        end
      end,
    },
  }
end

function TransportView:build_loop_button(bridge_state)
  return {
    type = "button",
    id = "transport_loop",
    align = "center",
    width = CoreConfig.TRANSPORT_BUTTONS.loop.width,
    config = {
      is_toggled = bridge_state.loop_enabled or false,
      preset_name = "BUTTON_TOGGLE_WHITE",
      custom_draw = function(ctx, dl, bx, by, bw, bh, is_hovered, is_active, text_color)
        TransportIcons.draw_loop(dl, bx, by, bw, bh, text_color)
      end,
      tooltip = Strings.TRANSPORT.loop,
      on_click = function()
        local bridge = self.state.get_bridge()
        local current_state = bridge:get_loop_playlist()
        bridge:set_loop_playlist(not current_state)
      end,
    },
  }
end

function TransportView:build_jump_button(bridge_state)
  return {
    type = "button",
    id = "transport_jump",
    align = "center",
    width = CoreConfig.TRANSPORT_BUTTONS.jump.width,
    config = {
      custom_draw = function(ctx, dl, bx, by, bw, bh, is_hovered, is_active, text_color)
        TransportIcons.draw_jump(dl, bx, by, bw, bh, text_color)
      end,
      tooltip = Strings.TRANSPORT.jump,
      on_click = function()
        local bridge = self.state.get_bridge()
        local target_rid = nil
        local bridge_state = bridge:get_state()
        if bridge_state.playlist_order and bridge_state.playlist_pointer then
          local next_idx = bridge_state.playlist_pointer + 1
          if next_idx <= #bridge_state.playlist_order then
            target_rid = bridge_state.playlist_order[next_idx]
          end
        end

        local success = bridge:jump_to_next_quantized(self.config.quantize_lookahead)

        if success and self.container and target_rid then
          self.container:trigger_jump_flash(target_rid)
        end

        if success and self.state.set_state_change_notification then
          local quantize_mode = bridge_state.quantize_mode or "none"
          if target_rid then
            local next_region = self.state.get_region_by_rid and self.state.get_region_by_rid(target_rid)
            if next_region then
              local msg = string.format("Jump: Next → '%s' (Quantize: %s)", next_region.name, quantize_mode)
              self.state.set_state_change_notification(msg)
            end
          end
        end
      end,
    },
  }
end

function TransportView:build_quantize_dropdown(bridge_state)
  return {
    type = "dropdown_field",
    id = "transport_quantize",
    align = "center",
    width = CoreConfig.TRANSPORT_BUTTONS.quantize.width,
    config = {
      tooltip = "Grid/Quantize Mode",
      current_value = bridge_state.quantize_mode,
      options = CoreConfig.QUANTIZE.options,
      enable_mousewheel = true,
      on_change = function(new_value)
        self.state.get_bridge():set_quantize_mode(new_value)
      end,
      footer_content = function(footer_ctx)
        local ctx = footer_ctx.ctx
        local dl = footer_ctx.dl
        local width = footer_ctx.width
        local padding = footer_ctx.padding

        local label = "Jump Lookahead"
        local label_x, label_y = ImGui.GetCursorScreenPos(ctx)
        local label_color = Colors.hexrgb("#E0E0E0FF")
        ImGui.DrawList_AddText(dl, label_x + padding, label_y, label_color, label)
        ImGui.Dummy(ctx, width, 20)

        ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, Colors.hexrgb("#1A1A1AFF"))
        ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgHovered, Colors.hexrgb("#222222FF"))
        ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgActive, Colors.hexrgb("#252525FF"))
        ImGui.PushStyleColor(ctx, ImGui.Col_SliderGrab, Colors.hexrgb("#606060FF"))
        ImGui.PushStyleColor(ctx, ImGui.Col_SliderGrabActive, Colors.hexrgb("#707070FF"))
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_GrabMinSize, 14)
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, 4, 6)
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_GrabRounding, 0)

        local slider_x, slider_y = ImGui.GetCursorScreenPos(ctx)
        ImGui.SetCursorScreenPos(ctx, slider_x + padding, slider_y)
        ImGui.SetNextItemWidth(ctx, width - padding * 2)

        local lookahead_ms = self.config.quantize_lookahead * 1000
        local changed, new_val = ImGui.SliderDouble(ctx, "##quantize_lookahead", lookahead_ms, 200, 1000, "%.0fms")

        ImGui.PopStyleVar(ctx, 3)
        ImGui.PopStyleColor(ctx, 5)

        if changed then
          self.config.quantize_lookahead = new_val / 1000
          if self.state.settings then
            self.state.settings:set('quantize_lookahead', self.config.quantize_lookahead)
          end
        end

        ImGui.Dummy(ctx, width, 6)
      end,
    },
  }
end

function TransportView:build_playback_dropdown(bridge_state)
  local current_shuffle_mode = bridge_state.shuffle_mode or "true_shuffle"

  return {
    type = "dropdown_field",
    id = "transport_playback",
    align = "center",
    width = CoreConfig.TRANSPORT_BUTTONS.playback.width_dropdown,
    config = {
      tooltip = "Playback Options",
      current_value = nil,
      button_label = "Playback",  -- Label shown on button (not in dropdown menu)
      options = {
        {
          value = "shuffle",
          label = "Shuffle",
          checkbox = true,
          checked = bridge_state.shuffle_enabled or false,
        },
        {
          value = "true_shuffle",
          label = "  True Shuffle",
          checkbox = true,
          checked = current_shuffle_mode == "true_shuffle",
        },
        {
          value = "random",
          label = "  Random",
          checkbox = true,
          checked = current_shuffle_mode == "random",
        },
        {
          value = "reshuffle_now",
          label = "  Re-shuffle Now",
          checkbox = false,
        },
        { value = nil, label = "", separator = true },
        {
          value = "hijack_transport",
          label = "Override Transport",
          checkbox = true,
          checked = bridge_state.override_enabled or false,
        },
        {
          value = "follow_viewport",
          label = "Follow Viewport",
          checkbox = true,
          checked = bridge_state.follow_viewport or false,
        },
      },
      on_change = function(value)
        local bridge = self.state.get_bridge()
        if value == "reshuffle_now" then
          local engine = bridge.engine
          if engine and engine:get_shuffle_enabled() then
            engine:set_shuffle_enabled(false)
            engine:set_shuffle_enabled(true)
          end
        elseif value == "true_shuffle" or value == "random" then
          bridge:set_shuffle_mode(value)
        end
      end,
      on_checkbox_change = function(value, new_checked)
        local bridge = self.state.get_bridge()
        if not bridge then return end

        if value == "shuffle" then
          bridge:set_shuffle_enabled(new_checked)
        elseif value == "hijack_transport" then
          bridge:set_transport_override(new_checked)
        elseif value == "follow_viewport" then
          bridge:set_follow_viewport(new_checked)
        end
      end,
    },
  }
end

-- Helper function to draw shuffle context menu
function TransportView:draw_shuffle_context_menu(ctx)
  local ContextMenu = require('arkitekt.gui.widgets.overlays.context_menu')
  local bridge = self.state.get_bridge()
  local engine = bridge and bridge.engine

  if ContextMenu.begin(ctx, "shuffle_context_menu") then
    local current_mode = engine and engine:get_shuffle_mode() or "true_shuffle"

    -- Shuffle mode selection (mutually exclusive checkboxes)
    if ContextMenu.checkbox_item(ctx, "True Shuffle", current_mode == "true_shuffle") then
      if bridge then
        bridge:set_shuffle_mode("true_shuffle")
      end
    end

    if ContextMenu.checkbox_item(ctx, "Random", current_mode == "random") then
      if bridge then
        bridge:set_shuffle_mode("random")
      end
    end

    ContextMenu.separator(ctx)

    -- Re-shuffle Now
    if ContextMenu.item(ctx, "Re-shuffle Now") then
      if engine and engine:get_shuffle_enabled() then
        engine:set_shuffle_enabled(false)
        engine:set_shuffle_enabled(true)
      end
    end

    ContextMenu.end_menu(ctx)
  end
end

function TransportView:build_playback_buttons(bridge_state, shell_state)
  -- Get icon font from shell_state
  local icon_font = shell_state and shell_state.fonts and shell_state.fonts.icons
  local icon_size = 16  -- Size for button icons

  return {
    {
      type = "custom",
      id = "transport_shuffle",
      align = "center",
      width = 34,
      config = {
        on_draw = function(ctx, dl, x, y, width, height, state)
          local Button = require('arkitekt.gui.widgets.primitives.button')
          local bridge = self.state.get_bridge()
          local engine = bridge and bridge.engine

          -- Draw button
          Button.draw(ctx, dl, x, y, width, height, {
            icon = CoreConfig.REMIX_ICONS.shuffle,
            icon_font = icon_font,
            icon_size = icon_size,
            label = "",
            is_toggled = bridge_state.shuffle_enabled or false,
            preset_name = "BUTTON_TOGGLE_WHITE",
            tooltip = Strings.TRANSPORT.shuffle,
            on_click = function()
              local bridge = self.state.get_bridge()
              if bridge then
                local current_state = bridge:get_shuffle_enabled()
                bridge:set_shuffle_enabled(not current_state)
              end
            end,
            on_right_click = function()
              ImGui.OpenPopup(ctx, "shuffle_context_menu")
            end,
          }, state)

          -- Draw context menu
          self:draw_shuffle_context_menu(ctx)
        end,
      },
    },
    {
      type = "button",
      id = "transport_hijack",
      align = "center",
      width = 34,
      config = {
        icon = CoreConfig.REMIX_ICONS.hijack_transport,
        icon_font = icon_font,
        icon_size = icon_size,
        label = "",
        is_toggled = bridge_state.override_enabled or false,
        preset_name = "BUTTON_TOGGLE_WHITE",
        tooltip = Strings.TRANSPORT.hijack_transport,
        on_click = function()
          local bridge = self.state.get_bridge()
          if bridge then
            local current_state = bridge:get_transport_override()
            local new_state = not current_state
            bridge:set_transport_override(new_state)

            -- Show status message
            if self.state.set_state_change_notification then
              local msg = new_state and Strings.STATUS.override_enabled or Strings.STATUS.override_disabled
              self.state.set_state_change_notification(msg)
            end
          end
        end,
      },
    },
    {
      type = "button",
      id = "transport_follow",
      align = "center",
      width = 26,  -- Reduced to compensate for layout spacing
      config = {
        icon = CoreConfig.REMIX_ICONS.follow_viewport,
        icon_font = icon_font,
        icon_size = icon_size,
        label = "",
        is_toggled = bridge_state.follow_viewport or false,
        preset_name = "BUTTON_TOGGLE_WHITE",
        tooltip = Strings.TRANSPORT.follow_viewport,
        on_click = function()
          local bridge = self.state.get_bridge()
          if bridge then
            local current_state = bridge:get_follow_viewport()
            local new_state = not current_state
            bridge:set_follow_viewport(new_state)

            -- Show status message
            if self.state.set_state_change_notification then
              local msg = new_state and Strings.STATUS.follow_viewport_enabled or Strings.STATUS.follow_viewport_disabled
              self.state.set_state_change_notification(msg)
            end
          end
        end,
      },
    },
  }
end

-- <<< MODULAR BUTTON BUILDERS (END)

function TransportView:build_header_elements(bridge_state, available_width, shell_state)
  bridge_state = bridge_state or {}
  available_width = available_width or math.huge

  local BTN = CoreConfig.TRANSPORT_BUTTONS
  local LAYOUT = CoreConfig.TRANSPORT_LAYOUT

  -- Determine layout mode based on available width
  local ultra_compact = available_width < LAYOUT.ultra_compact_width
  local compact = available_width < LAYOUT.compact_width

  -- Ultra-compact mode: Only Play, Jump, and combined PB dropdown
  if ultra_compact then
    return {
      self:build_play_button(bridge_state),
      self:build_jump_button(bridge_state),
      self:build_combined_pb_dropdown(bridge_state),
    }
  end

  -- Calculate which buttons to show based on priority
  -- Always show: Play (1), Jump (2)
  local always_width = BTN.play.width + BTN.jump.width
  local remaining_width = available_width - always_width

  -- Determine which optional buttons fit (by priority: lower number = higher priority)
  local show_quantize = false
  local show_playback = false
  local show_loop = false
  local show_pause = false
  local show_stop = false

  local playback_width = compact and BTN.playback.width_dropdown or BTN.playback.width_buttons

  -- Check each priority level
  local budget = remaining_width

  -- Priority 3: Quantize
  if budget >= BTN.quantize.width then
    show_quantize = true
    budget = budget - BTN.quantize.width
  end

  -- Priority 4: Playback
  if budget >= playback_width then
    show_playback = true
    budget = budget - playback_width
  end

  -- Priority 5: Loop
  if budget >= BTN.loop.width then
    show_loop = true
    budget = budget - BTN.loop.width
  end

  -- Priority 6: Pause
  if budget >= BTN.pause.width then
    show_pause = true
    budget = budget - BTN.pause.width
  end

  -- Priority 7: Stop
  if budget >= BTN.stop.width then
    show_stop = true
    budget = budget - BTN.stop.width
  end

  -- Build elements array in VISUAL ORDER (not priority order)
  -- Visual order: Play, Stop, Pause, Loop, Jump, Quantize, Playback
  local elements = {}

  elements[#elements + 1] = self:build_play_button(bridge_state)

  if show_stop then
    elements[#elements + 1] = self:build_stop_button()
  end

  if show_pause then
    elements[#elements + 1] = self:build_pause_button(bridge_state)
  end

  if show_loop then
    elements[#elements + 1] = self:build_loop_button(bridge_state)
  end

  elements[#elements + 1] = self:build_jump_button(bridge_state)

  if show_quantize then
    elements[#elements + 1] = self:build_quantize_dropdown(bridge_state)
  end

  if show_playback then
    if compact then
      elements[#elements + 1] = self:build_playback_dropdown(bridge_state)
    else
      local buttons = self:build_playback_buttons(bridge_state, shell_state)
      for _, btn in ipairs(buttons) do
        elements[#elements + 1] = btn
      end
    end
  end

  return elements
end

-- Build combined "PB" dropdown for ultra-compact mode
function TransportView:build_combined_pb_dropdown(bridge_state)
  -- Combine quantize options and playback checkboxes into single dropdown
  local options = {}
  local current_shuffle_mode = bridge_state.shuffle_mode or "true_shuffle"

  -- Add quantize separator and options
  options[#options + 1] = { value = nil, label = "", separator = "Quantize" }
  for _, opt in ipairs(CoreConfig.QUANTIZE.options) do
    options[#options + 1] = opt
  end

  -- Add playback separator and options
  options[#options + 1] = { value = nil, label = "", separator = "Playback" }
  options[#options + 1] = {
    value = "shuffle",
    label = "Shuffle",
    checkbox = true,
    checked = bridge_state.shuffle_enabled or false,
  }
  options[#options + 1] = {
    value = "true_shuffle",
    label = "  True Shuffle",
    checkbox = true,
    checked = current_shuffle_mode == "true_shuffle",
  }
  options[#options + 1] = {
    value = "random",
    label = "  Random",
    checkbox = true,
    checked = current_shuffle_mode == "random",
  }
  options[#options + 1] = {
    value = "reshuffle_now",
    label = "  Re-shuffle Now",
    checkbox = false,
  }
  options[#options + 1] = {
    value = "hijack_transport",
    label = "Override Transport",
    checkbox = true,
    checked = bridge_state.override_enabled or false,
  }
  options[#options + 1] = {
    value = "follow_viewport",
    label = "Follow Viewport",
    checkbox = true,
    checked = bridge_state.follow_viewport or false,
  }

  return {
    type = "dropdown_field",
    id = "transport_pb_combined",
    align = "center",
    width = 60,  -- Compact "PB" label
    config = {
      tooltip = "Playback & Quantize Settings",
      button_label = "PB",  -- Label shown on button (not in dropdown menu)
      current_value = bridge_state.quantize_mode,
      options = options,
      enable_mousewheel = true,
      on_change = function(new_value)
        local bridge = self.state.get_bridge()
        -- Handle Re-shuffle Now
        if new_value == "reshuffle_now" then
          local engine = bridge.engine
          if engine and engine:get_shuffle_enabled() then
            engine:set_shuffle_enabled(false)
            engine:set_shuffle_enabled(true)
          end
        -- Handle shuffle mode changes
        elseif new_value == "true_shuffle" or new_value == "random" then
          bridge:set_shuffle_mode(new_value)
        -- Handle quantize mode changes
        elseif new_value and new_value ~= "shuffle" and new_value ~= "hijack_transport" and new_value ~= "follow_viewport" then
          bridge:set_quantize_mode(new_value)
        end
      end,
      on_checkbox_change = function(value, new_checked)
        local bridge = self.state.get_bridge()
        if not bridge then return end

        if value == "shuffle" then
          bridge:set_shuffle_enabled(new_checked)
        elseif value == "hijack_transport" then
          bridge:set_transport_override(new_checked)
        elseif value == "follow_viewport" then
          bridge:set_follow_viewport(new_checked)
        end
      end,
      footer_content = function(footer_ctx)
        local ctx = footer_ctx.ctx
        local dl = footer_ctx.dl
        local width = footer_ctx.width
        local padding = footer_ctx.padding

        local label = "Jump Lookahead"
        local label_x, label_y = ImGui.GetCursorScreenPos(ctx)
        local label_color = Colors.hexrgb("#E0E0E0FF")
        ImGui.DrawList_AddText(dl, label_x + padding, label_y, label_color, label)
        ImGui.Dummy(ctx, width, 20)

        ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, Colors.hexrgb("#1A1A1AFF"))
        ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgHovered, Colors.hexrgb("#222222FF"))
        ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgActive, Colors.hexrgb("#252525FF"))
        ImGui.PushStyleColor(ctx, ImGui.Col_SliderGrab, Colors.hexrgb("#606060FF"))
        ImGui.PushStyleColor(ctx, ImGui.Col_SliderGrabActive, Colors.hexrgb("#707070FF"))
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_GrabMinSize, 14)
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, 4, 6)
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_GrabRounding, 0)

        local slider_x, slider_y = ImGui.GetCursorScreenPos(ctx)
        ImGui.SetCursorScreenPos(ctx, slider_x + padding, slider_y)
        ImGui.SetNextItemWidth(ctx, width - padding * 2)

        local lookahead_ms = self.config.quantize_lookahead * 1000
        local changed, new_val = ImGui.SliderDouble(ctx, "##quantize_lookahead_pb", lookahead_ms, 200, 1000, "%.0fms")

        ImGui.PopStyleVar(ctx, 3)
        ImGui.PopStyleColor(ctx, 5)

        if changed then
          self.config.quantize_lookahead = new_val / 1000
          if self.state.settings then
            self.state.settings:set('quantize_lookahead', self.config.quantize_lookahead)
          end
        end

        ImGui.Dummy(ctx, width, 6)
      end,
    },
  }
end


function TransportView:draw(ctx, shell_state, is_blocking)
  is_blocking = is_blocking or false
  local bridge = self.state.get_bridge()
  local engine = bridge.engine

  local bridge_state = {
    is_playing = bridge:get_state().is_playing,
    time_remaining = bridge:get_time_remaining(),
    progress = bridge:get_progress() or 0,
    quantize_mode = bridge:get_state().quantize_mode,
    loop_enabled = bridge:get_loop_playlist(),
    override_enabled = engine and engine:get_transport_override() or false,
    follow_viewport = engine and engine:get_follow_viewport() or false,
    shuffle_enabled = engine and engine:get_shuffle_enabled() or false,
  }

  -- Inject icon font, size, and blocking state into corner buttons
  local icons_font = shell_state and shell_state.fonts and shell_state.fonts.icons
  local icons_size = shell_state and shell_state.fonts and shell_state.fonts.icons_size
  if self.container.panel.config.corner_buttons then
    local cb = self.container.panel.config.corner_buttons
    if cb.top_right then
      if icons_font then
        cb.top_right.icon_font = icons_font
        cb.top_right.icon_font_size = icons_size
      end
      cb.top_right.is_blocking = is_blocking
    end
    if cb.top_left then
      if icons_font then
        cb.top_left.icon_font = icons_font
        cb.top_left.icon_font_size = icons_size
      end
      cb.top_left.is_blocking = is_blocking
    end
    if cb.bottom_right then
      if icons_font then
        cb.bottom_right.icon_font = icons_font
        cb.bottom_right.icon_font_size = icons_size
      end
      cb.bottom_right.is_blocking = is_blocking
    end
    if cb.bottom_left then
      if icons_font then
        cb.bottom_left.icon_font = icons_font
        cb.bottom_left.icon_font_size = icons_size
      end
      cb.bottom_left.is_blocking = is_blocking
    end
  end

  -- Get available width for responsive header layout
  local available_width = ImGui.GetContentRegionAvail(ctx)
  self.container:set_header_elements(self:build_header_elements(bridge_state, available_width, shell_state))
  
  local spacing = self.config.spacing
  local transport_height = self.config.height
  
  local transport_start_x, transport_start_y = ImGui.GetCursorScreenPos(ctx)
  
  local region_colors = self:get_region_colors()

  -- Get current region ID for jump flash tracking
  local current_rid = nil
  if bridge then
    current_rid = bridge:get_current_rid()
  end

  local content_w, content_h = self.container:begin_draw(ctx, region_colors, current_rid)
  
  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)

  -- Show the playing playlist when playback is active, otherwise show the selected playlist
  local playlist_to_display = self.state.get_active_playlist()
  if bridge and bridge_state.is_playing then
    local playing_playlist_id = bridge:get_playing_playlist_id()
    if playing_playlist_id then
      local playing_playlist = self.state.get_playlist_by_id(playing_playlist_id)
      if playing_playlist then
        playlist_to_display = playing_playlist
      end
    end
  end

  local playlist_data = playlist_to_display and {
    name = playlist_to_display.name,
    color = playlist_to_display.chip_color or hexrgb("#888888"),
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

  ImGui.SetCursorScreenPos(ctx, transport_start_x, transport_start_y + transport_height)
end

return M

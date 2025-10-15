local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local TileMotion = require('rearkitekt.gui.fx.tile_motion')
local TransportContainer = require('rearkitekt.gui.widgets.transport.transport_container')

local TransportBar = {}
TransportBar.__index = TransportBar

local function get_animation_speed(config)
  return config
    and config.ANIMATION
    and config.ANIMATION.HOVER_SPEED
    or 0.15
end

local function get_transport_height(config)
  return config
    and config.TRANSPORT
    and config.TRANSPORT.height
    or 0
end

local function get_default_lookahead(config)
  return config
    and config.QUANTIZE
    and config.QUANTIZE.default_lookahead
    or 0
end

function TransportBar.new(deps)
  deps = deps or {}
  local config = deps.Config or deps.config

  local self = setmetatable({
    State = deps.State or deps.state,
    Config = config,
    settings = deps.settings,
    region_tiles = deps.region_tiles,
    layout_button_animator = TileMotion.new(get_animation_speed(config)),
    transport_container = TransportContainer.new({
      id = 'region_playlist_transport',
      height = get_transport_height(config),
    }),
    quantize_lookahead = get_default_lookahead(config),
  }, TransportBar)

  return self
end

function TransportBar:update(dt)
  if self.layout_button_animator then
    self.layout_button_animator:update(dt or 0.016)
  end
end

function TransportBar:draw_layout_toggle_button(ctx)
  if not (self.Config and self.State and self.State.state and self.region_tiles) then
    return
  end

  local dl = ImGui.GetWindowDrawList(ctx)
  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  local config = self.Config.LAYOUT_BUTTON
  if not config then return end

  local btn_w = config.width
  local btn_h = config.height

  local mx, my = ImGui.GetMousePos(ctx)
  local is_hovered = mx >= cursor_x and mx < cursor_x + btn_w and my >= cursor_y and my < cursor_y + btn_h

  self.layout_button_animator:track('btn', 'hover', is_hovered and 1.0 or 0.0, config.animation_speed)
  local hover_factor = self.layout_button_animator:get('btn', 'hover')

  local bg_color = Colors.lerp(config.bg_color, config.bg_hover, hover_factor)
  local border_color = Colors.lerp(config.border_color, config.border_hover, hover_factor)
  local icon_color = Colors.lerp(config.icon_color, config.icon_hover, hover_factor)

  ImGui.DrawList_AddRectFilled(dl, cursor_x, cursor_y, cursor_x + btn_w, cursor_y + btn_h, bg_color, config.rounding)
  ImGui.DrawList_AddRect(dl, cursor_x + 0.5, cursor_y + 0.5, cursor_x + btn_w - 0.5, cursor_y + btn_h - 0.5, border_color, config.rounding, 0, 1)

  local padding = 6
  local icon_x = cursor_x + padding
  local icon_y = cursor_y + padding
  local icon_w = btn_w - padding * 2
  local icon_h = btn_h - padding * 2

  if self.State.state.layout_mode == 'horizontal' then
    local bar_h = 3
    local gap = 2
    local bar_w = icon_w

    for i = 0, 2 do
      local bar_y = icon_y + i * (bar_h + gap)
      ImGui.DrawList_AddRectFilled(dl, icon_x, bar_y, icon_x + bar_w, bar_y + bar_h, icon_color, 1)
    end
  else
    local bar_w = 3
    local gap = 2
    local bar_h = icon_h

    for i = 0, 2 do
      local bar_x = icon_x + i * (bar_w + gap)
      ImGui.DrawList_AddRectFilled(dl, bar_x, icon_y, bar_x + bar_w, icon_y + bar_h, icon_color, 1)
    end
  end

  ImGui.SetCursorScreenPos(ctx, cursor_x, cursor_y)
  ImGui.InvisibleButton(ctx, '##layout_toggle', btn_w, btn_h)

  if ImGui.IsItemClicked(ctx, 0) then
    self.State.state.layout_mode = (self.State.state.layout_mode == 'horizontal') and 'vertical' or 'horizontal'
    if self.region_tiles and self.region_tiles.set_layout_mode then
      self.region_tiles:set_layout_mode(self.State.state.layout_mode)
    end
    if self.State and self.State.persist_ui_prefs then
      self.State.persist_ui_prefs()
    end
  end

  if ImGui.IsItemHovered(ctx) then
    local tooltip = self.State.state.layout_mode == 'horizontal' and 'Switch to List Mode' or 'Switch to Timeline Mode'
    ImGui.SetTooltip(ctx, tooltip)
  end

  ImGui.SameLine(ctx, 0, 12)
end

function TransportBar:draw_transport_override_checkbox(ctx)
  local engine = self.State and self.State.state and self.State.state.bridge and self.State.state.bridge.engine
  if not engine then return end

  local transport_override = engine:get_transport_override()
  local changed, new_value = ImGui.Checkbox(ctx, 'Transport Override', transport_override)

  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, 'Sync playlist when REAPER playhead\nenters any active region')
  end

  if changed then
    engine:set_transport_override(new_value)
    if self.settings and self.settings.set then
      self.settings:set('transport_override', new_value)
    end
  end

  ImGui.SameLine(ctx, 0, 12)
end

function TransportBar:draw_loop_playlist_checkbox(ctx)
  local bridge = self.State and self.State.state and self.State.state.bridge
  if not bridge then return end

  local loop_playlist = bridge:get_loop_playlist()
  local changed, new_value = ImGui.Checkbox(ctx, 'Loop Playlist', loop_playlist)

  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, 'Wrap to start when reaching\nthe end of the playlist')
  end

  if changed then
    bridge:set_loop_playlist(new_value)
  end

  ImGui.SameLine(ctx, 0, 12)
end

function TransportBar:draw(ctx)
  if not (self.State and self.Config) then return end

  self:update(0.016)

  self.transport_container:begin_draw(ctx)

  ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) + 2)

  self:draw_layout_toggle_button(ctx)
  self:draw_transport_override_checkbox(ctx)
  self:draw_loop_playlist_checkbox(ctx)

  local bridge = self.State.state.bridge
  local engine = bridge and bridge.engine

  local quantize_config = self.Config and self.Config.QUANTIZE or {}
  if engine and engine.quantize and quantize_config.grid_options then
    local current_mode = engine.quantize:get_quantize_mode()
    local options = quantize_config.grid_options

    local current_label = tostring(current_mode)
    local current_index = 1
    for i = 1, #options do
      local option = options[i]
      if option.value == current_mode then
        current_label = option.label
        current_index = i
        break
      end
    end

    ImGui.Text(ctx, 'Jump Mode:')
    ImGui.SameLine(ctx, 0, 8)
    ImGui.SetNextItemWidth(ctx, 140)

    if ImGui.BeginCombo(ctx, '##quantize_mode', current_label) then
      for i = 1, #options do
        local option = options[i]
        local is_selected = (i == current_index)
        if ImGui.Selectable(ctx, option.label, is_selected) then
          engine.quantize:set_quantize_mode(option.value)
          current_mode = option.value
          current_label = option.label
          current_index = i
        end
        if is_selected then
          ImGui.SetItemDefaultFocus(ctx)
        end
      end
      ImGui.EndCombo(ctx)
    end

    ImGui.SameLine(ctx, 0, 12)
  end

  local min_lookahead = (quantize_config.min_lookahead or 0.2) * 1000
  local max_lookahead = (quantize_config.max_lookahead or 3.0) * 1000

  if engine and engine.quantize then
    if engine.quantize.min_lookahead then
      min_lookahead = engine.quantize.min_lookahead * 1000
    end
    if engine.quantize.max_lookahead then
      max_lookahead = engine.quantize.max_lookahead * 1000
    end
  end

  ImGui.Text(ctx, 'Lookahead:')
  ImGui.SameLine(ctx, 0, 8)
  ImGui.SetNextItemWidth(ctx, 120)

  local changed, new_val = ImGui.SliderDouble(
    ctx,
    '##lookahead',
    self.quantize_lookahead * 1000,
    min_lookahead,
    max_lookahead,
    '%.0f'
  )
  if changed then
    self.quantize_lookahead = new_val / 1000
  end

  ImGui.SameLine(ctx, 0, 12)

  local bridge_state = bridge and bridge:get_state()
  local is_disabled = not (bridge_state and bridge_state.is_playing)

  if is_disabled then
    ImGui.BeginDisabled(ctx)
  end

  local button_label = 'Jump to Next'
  if engine and engine.quantize then
    local mode = engine.quantize:get_quantize_mode()
    if mode == 'measure' then
      button_label = 'Jump on Next Measure'
    else
      local grid_val = tonumber(mode)
      if grid_val == 4.0 then
        button_label = 'Jump on Next Bar'
      elseif grid_val == 2.0 then
        button_label = 'Jump on Next 1/2'
      elseif grid_val == 1.0 then
        button_label = 'Jump on Next 1/4'
      elseif grid_val == 0.5 then
        button_label = 'Jump on Next 1/8'
      elseif grid_val == 0.25 then
        button_label = 'Jump on Next 1/16'
      elseif grid_val == 0.125 then
        button_label = 'Jump on Next 1/32'
      elseif grid_val == 0.0625 then
        button_label = 'Jump on Next 1/64'
      else
        button_label = 'Jump on Next Grid'
      end
    end
  end

  if ImGui.Button(ctx, button_label) then
    bridge:jump_to_next_quantized(self.quantize_lookahead)
  end

  if is_disabled then
    ImGui.EndDisabled(ctx)
  end

  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled) then
    if is_disabled then
      ImGui.SetTooltip(ctx, 'Start playback to enable')
    else
      ImGui.SetTooltip(ctx, 'Jump to next quantize point')
    end
  end

  self.transport_container:end_draw(ctx)
end

return TransportBar

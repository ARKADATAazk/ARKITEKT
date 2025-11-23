-- @noindex
-- ARKITEKT/scripts/Sandbox/sandbox_button_test.lua
-- Button Component Test - Standalone and integrated usage

local script_path = debug.getinfo(1, "S").source:match("@?(.*)[\\/]") or ""
local root_path = script_path:match("(.*)[\\/][^\\/]+[\\/]?$") or script_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
if not root_path:match("[\\/]$") then root_path = root_path .. "/" end

local arkitekt_path = root_path .. "ARKITEKT/"
package.path = arkitekt_path .. "?.lua;" .. arkitekt_path .. "?/init.lua;" .. package.path
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path

local ImGui = require('imgui')('0.10')
local Shell = require('arkitekt.app.runtime.shell')
local Button = require('arkitekt.gui.widgets.primitives.button')
local Style = require('arkitekt.gui.style.defaults')
local Colors = require('arkitekt.core.colors')

local hexrgb = Colors.hexrgb

-- ============================================================================
-- MOCK STATE
-- ============================================================================

local mock_state = {
  click_count = 0,
  last_clicked = "None",
  selected_option = "Option A",
  progress = 0.0,
  is_playing = false,
  volume = 0.75,
  theme = "dark",
}

-- ============================================================================
-- BUTTON TESTING SECTIONS
-- ============================================================================

local function test_basic_buttons(ctx)
  ImGui.Text(ctx, "Basic Buttons:")
  ImGui.Separator(ctx)
  ImGui.Text(ctx, "")
  
  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  
  -- Standard button
  local clicked = Button.draw(
    ctx, dl,
    cursor_x, cursor_y,
    100, 28,
    {
      label = "Click Me",
      on_click = function()
        mock_state.click_count = mock_state.click_count + 1
        mock_state.last_clicked = "Standard"
      end,
      tooltip = "Standard button"
    },
    "btn_standard"
  )
  
  -- With icon
  Button.draw(
    ctx, dl,
    cursor_x + 110, cursor_y,
    110, 28,
    {
      icon = "⭐",
      label = "Starred",
      on_click = function()
        mock_state.click_count = mock_state.click_count + 1
        mock_state.last_clicked = "Starred"
      end,
      tooltip = "Button with icon"
    },
    "btn_icon"
  )
  
  -- Icon only
  Button.draw(
    ctx, dl,
    cursor_x + 230, cursor_y,
    32, 28,
    {
      icon = "⚙",
      on_click = function()
        mock_state.click_count = mock_state.click_count + 1
        mock_state.last_clicked = "Settings"
      end,
      tooltip = "Settings (icon only)"
    },
    "btn_settings"
  )
  
  ImGui.SetCursorScreenPos(ctx, cursor_x, cursor_y + 35)
  
  ImGui.Text(ctx, string.format("Clicks: %d", mock_state.click_count))
  ImGui.Text(ctx, string.format("Last clicked: %s", mock_state.last_clicked))
end

local function test_styled_buttons(ctx)
  ImGui.Text(ctx, "")
  ImGui.Text(ctx, "Styled Buttons:")
  ImGui.Separator(ctx)
  ImGui.Text(ctx, "")
  
  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  
  -- Success button
  Button.draw(
    ctx, dl,
    cursor_x, cursor_y,
    100, 28,
    {
      label = "Success",
      bg_color = hexrgb("#1E3A1EFF"),
      bg_hover_color = hexrgb("#254525FF"),
      bg_active_color = hexrgb("#2A5A2AFF"),
      text_color = Style.COLORS.ACCENT_SUCCESS,
      text_hover_color = hexrgb("#FFFFFFFF"),
      border_inner_color = hexrgb("#4CAF5033"),
      border_hover_color = hexrgb("#4CAF5066"),
      on_click = function()
        mock_state.last_clicked = "Success"
      end,
      tooltip = "Success style"
    },
    "btn_success"
  )
  
  -- Warning button
  Button.draw(
    ctx, dl,
    cursor_x + 110, cursor_y,
    100, 28,
    {
      label = "Warning",
      bg_color = hexrgb("#3A2E1EFF"),
      bg_hover_color = hexrgb("#453525FF"),
      bg_active_color = hexrgb("#5A4525FF"),
      text_color = Style.COLORS.ACCENT_WARNING,
      text_hover_color = hexrgb("#FFFFFFFF"),
      border_inner_color = hexrgb("#FFA72633"),
      border_hover_color = hexrgb("#FFA72666"),
      on_click = function()
        mock_state.last_clicked = "Warning"
      end,
      tooltip = "Warning style"
    },
    "btn_warning"
  )
  
  -- Danger button
  Button.draw(
    ctx, dl,
    cursor_x + 220, cursor_y,
    100, 28,
    {
      label = "Danger",
      bg_color = hexrgb("#3A1E1EFF"),
      bg_hover_color = hexrgb("#452525FF"),
      bg_active_color = hexrgb("#5A3030FF"),
      text_color = Style.COLORS.ACCENT_DANGER,
      text_hover_color = hexrgb("#FFFFFFFF"),
      border_inner_color = hexrgb("#EF535033"),
      border_hover_color = hexrgb("#EF535066"),
      on_click = function()
        mock_state.last_clicked = "Danger"
      end,
      tooltip = "Danger style"
    },
    "btn_danger"
  )
  
  ImGui.SetCursorScreenPos(ctx, cursor_x, cursor_y + 35)
end

local function test_rounded_buttons(ctx)
  ImGui.Text(ctx, "")
  ImGui.Text(ctx, "Rounded Buttons:")
  ImGui.Separator(ctx)
  ImGui.Text(ctx, "")
  
  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  
  -- Slightly rounded
  Button.draw(
    ctx, dl,
    cursor_x, cursor_y,
    100, 28,
    {
      label = "Rounded 4",
      rounding = 4,
      on_click = function()
        mock_state.last_clicked = "Rounded 4"
      end
    },
    "btn_round_4"
  )
  
  -- Medium rounded
  Button.draw(
    ctx, dl,
    cursor_x + 110, cursor_y,
    100, 28,
    {
      label = "Rounded 8",
      rounding = 8,
      on_click = function()
        mock_state.last_clicked = "Rounded 8"
      end
    },
    "btn_round_8"
  )
  
  -- Pill shaped
  Button.draw(
    ctx, dl,
    cursor_x + 220, cursor_y,
    100, 28,
    {
      label = "Pill",
      rounding = 14,
      on_click = function()
        mock_state.last_clicked = "Pill"
      end
    },
    "btn_pill"
  )
  
  ImGui.SetCursorScreenPos(ctx, cursor_x, cursor_y + 35)
end

local function test_button_group(ctx)
  ImGui.Text(ctx, "")
  ImGui.Text(ctx, "Button Group (Radio):")
  ImGui.Separator(ctx)
  ImGui.Text(ctx, "")
  
  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  
  local options = {"Option A", "Option B", "Option C"}
  local x = cursor_x
  
  for i, option in ipairs(options) do
    local is_selected = mock_state.selected_option == option
    
    Button.draw(
      ctx, dl,
      x, cursor_y,
      80, 28,
      {
        label = option,
        bg_color = is_selected and Style.COLORS.BG_ACTIVE or Style.COLORS.BG_BASE,
        bg_hover_color = is_selected and Style.COLORS.BG_ACTIVE or Style.COLORS.BG_HOVER,
        bg_active_color = Style.COLORS.BG_ACTIVE,
        border_inner_color = is_selected and Style.COLORS.BORDER_FOCUS or Style.COLORS.BORDER_INNER,
        text_color = is_selected and Style.COLORS.TEXT_HOVER or Style.COLORS.TEXT_NORMAL,
        on_click = function()
          mock_state.selected_option = option
        end
      },
      "btn_option_" .. i
    )
    
    x = x + 80 + 2
  end
  
  ImGui.SetCursorScreenPos(ctx, cursor_x, cursor_y + 35)
  ImGui.Text(ctx, string.format("Selected: %s", mock_state.selected_option))
end

local function test_media_controls(ctx)
  ImGui.Text(ctx, "")
  ImGui.Text(ctx, "Media Controls:")
  ImGui.Separator(ctx)
  ImGui.Text(ctx, "")
  
  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  
  -- Play/Pause
  Button.draw(
    ctx, dl,
    cursor_x, cursor_y,
    40, 32,
    {
      icon = mock_state.is_playing and "⏸" or "▶",
      rounding = 4,
      on_click = function()
        mock_state.is_playing = not mock_state.is_playing
      end,
      tooltip = mock_state.is_playing and "Pause" or "Play"
    },
    "btn_play_pause"
  )
  
  -- Stop
  Button.draw(
    ctx, dl,
    cursor_x + 45, cursor_y,
    40, 32,
    {
      icon = "⏹",
      rounding = 4,
      on_click = function()
        mock_state.is_playing = false
        mock_state.progress = 0.0
      end,
      tooltip = "Stop"
    },
    "btn_stop"
  )
  
  -- Skip Forward
  Button.draw(
    ctx, dl,
    cursor_x + 90, cursor_y,
    40, 32,
    {
      icon = "⏭",
      rounding = 4,
      on_click = function()
        mock_state.progress = math.min(1.0, mock_state.progress + 0.1)
      end,
      tooltip = "Skip Forward"
    },
    "btn_skip"
  )
  
  ImGui.SetCursorScreenPos(ctx, cursor_x + 140, cursor_y + 8)
  ImGui.Text(ctx, string.format("Progress: %d%%", mock_state.progress * 100))
  
  ImGui.SetCursorScreenPos(ctx, cursor_x, cursor_y + 40)
end

local function test_custom_draw_buttons(ctx)
  ImGui.Text(ctx, "")
  ImGui.Text(ctx, "Custom Draw Functions:")
  ImGui.Separator(ctx)
  ImGui.Text(ctx, "")
  
  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  
  -- Progress button
  Button.draw(
    ctx, dl,
    cursor_x, cursor_y,
    150, 32,
    {
      custom_draw = function(ctx, dl, x, y, w, h, is_hovered, is_active, text_color)
        -- Draw progress bar background
        local progress = mock_state.progress
        local bar_width = w * progress
        
        ImGui.DrawList_AddRectFilled(
          dl,
          x, y,
          x + bar_width, y + h,
          Style.COLORS.ACCENT_PRIMARY,
          0
        )
        
        -- Draw text
        local text = string.format("%d%%", progress * 100)
        local text_w = ImGui.CalcTextSize(ctx, text)
        local text_x = x + (w - text_w) * 0.5
        local text_y = y + (h - ImGui.GetTextLineHeight(ctx)) * 0.5
        
        ImGui.DrawList_AddText(dl, text_x, text_y, text_color, text)
      end,
      on_click = function()
        mock_state.progress = mock_state.progress + 0.1
        if mock_state.progress > 1.0 then
          mock_state.progress = 0.0
        end
      end,
      tooltip = "Click to increment progress"
    },
    "btn_progress"
  )
  
  -- Volume slider button
  Button.draw(
    ctx, dl,
    cursor_x + 160, cursor_y,
    150, 32,
    {
      custom_draw = function(ctx, dl, x, y, w, h, is_hovered, is_active, text_color)
        -- Draw volume bars
        local num_bars = 10
        local bar_width = (w - 20) / num_bars
        local bar_spacing = 2
        local volume = mock_state.volume
        
        for i = 1, num_bars do
          local bar_x = x + 10 + (i - 1) * bar_width
          local bar_height = (h - 10) * (i / num_bars)
          local bar_y = y + (h - bar_height) * 0.5
          
          local is_active_bar = (i / num_bars) <= volume
          local bar_color = is_active_bar and Style.COLORS.ACCENT_PRIMARY or Style.COLORS.BORDER_INNER
          
          ImGui.DrawList_AddRectFilled(
            dl,
            bar_x, bar_y,
            bar_x + bar_width - bar_spacing, bar_y + bar_height,
            bar_color,
            1
          )
        end
      end,
      on_click = function()
        mock_state.volume = mock_state.volume + 0.15
        if mock_state.volume > 1.0 then
          mock_state.volume = 0.1
        end
      end,
      tooltip = string.format("Volume: %d%%", mock_state.volume * 100)
    },
    "btn_volume"
  )
  
  ImGui.SetCursorScreenPos(ctx, cursor_x, cursor_y + 40)
end

local function test_action_buttons(ctx)
  ImGui.Text(ctx, "")
  ImGui.Text(ctx, "Action Buttons:")
  ImGui.Separator(ctx)
  ImGui.Text(ctx, "")
  
  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  
  local actions = {
    { icon = "💾", label = "Save", id = "save" },
    { icon = "📂", label = "Open", id = "open" },
    { icon = "🔄", label = "Refresh", id = "refresh" },
    { icon = "🗑", label = "Delete", id = "delete" },
  }
  
  local x = cursor_x
  
  for _, action in ipairs(actions) do
    Button.draw(
      ctx, dl,
      x, cursor_y,
      85, 28,
      {
        icon = action.icon,
        label = action.label,
        on_click = function()
          mock_state.last_clicked = action.label
        end,
        tooltip = action.label .. " action"
      },
      "btn_" .. action.id
    )
    
    x = x + 85 + 5
  end
  
  ImGui.SetCursorScreenPos(ctx, cursor_x, cursor_y + 35)
end

-- ============================================================================
-- MAIN SHELL
-- ============================================================================

Shell.run({
  title = "Button Component Test",
  version = "v1.0.0",
  version_color = hexrgb("#888888FF"),
  initial_pos = { x = 120, y = 120 },
  initial_size = { w = 700, h = 800 },
  min_size = { w = 600, h = 600 },
  icon_color = hexrgb("#4A9EFFFF"),
  icon_size = 18,
  
  draw = function(ctx, shell_state)
    -- Update progress if playing
    if mock_state.is_playing then
      mock_state.progress = mock_state.progress + 0.002
      if mock_state.progress >= 1.0 then
        mock_state.progress = 1.0
        mock_state.is_playing = false
      end
    end
    
    ImGui.Text(ctx, "Arkitekt Button Component Demo")
    ImGui.Text(ctx, "Testing standalone button usage")
    ImGui.Separator(ctx)
    ImGui.Text(ctx, "")
    
    test_basic_buttons(ctx)
    test_styled_buttons(ctx)
    test_rounded_buttons(ctx)
    test_button_group(ctx)
    test_media_controls(ctx)
    test_custom_draw_buttons(ctx)
    test_action_buttons(ctx)
    
    ImGui.Text(ctx, "")
    ImGui.Separator(ctx)
    ImGui.Text(ctx, string.format("State: %s | Volume: %d%% | Theme: %s", 
      mock_state.is_playing and "Playing" or "Stopped",
      math.floor(mock_state.volume * 100),
      mock_state.theme
    ))
  end,
})
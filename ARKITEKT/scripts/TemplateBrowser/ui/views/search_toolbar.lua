-- @noindex
-- TemplateBrowser/ui/views/search_toolbar.lua
-- Unified search toolbar at top of UI

local ImGui = require('arkitekt.core.imgui')
local Ark = require('arkitekt')
local Scanner = require('TemplateBrowser.domain.template.scanner')
local Layout = require('TemplateBrowser.config.constants')

local M = {}

-- Search modes
local SEARCH_MODES = {
  { value = 'templates', label = 'Templates' },
  { value = 'vsts', label = 'VSTs' },
  { value = 'tags', label = 'Tags' },
  { value = 'notes', label = 'Notes' },
  { value = 'mixed', label = 'All' },
}

local function get_search_mode_label(mode_id)
  for _, mode in ipairs(SEARCH_MODES) do
    if mode.value == mode_id then
      return mode.label
    end
  end
  return SEARCH_MODES[1].label
end

-- Draw the search toolbar
-- Returns the height consumed
function M.draw(ctx, state, width)
  local search_height = Layout.SEARCH.HEIGHT
  local clear_size = Layout.SEARCH.CLEAR_BUTTON_SIZE
  local spacing_after = Layout.SEARCH.SPACING_AFTER
  local dropdown_width = 100
  local overlap = -1  -- Overlap dropdown with input for seamless look

  local total_width = math.min(Layout.SEARCH.WIDTH + dropdown_width, width * 0.6)
  local input_width = total_width - dropdown_width + overlap
  local search_x = (width - total_width) * 0.5
  local start_y = ImGui.GetCursorPosY(ctx)

  -- Get screen position for absolute positioning
  local window_x, window_y = ImGui.GetCursorScreenPos(ctx)
  local screen_x = window_x + search_x - ImGui.GetCursorPosX(ctx)
  local screen_y = window_y

  -- Clear button (X) - detect click BEFORE input to capture it
  local search_text = state.search_query or ''
  local clear_clicked = false
  local clear_hovered = false
  local clear_x, clear_y

  if search_text ~= '' then
    local clear_padding = 8
    clear_x = screen_x + input_width - clear_size - clear_padding
    clear_y = screen_y + (search_height - clear_size) * 0.5

    -- InvisibleButton BEFORE InputText to capture click
    ImGui.SetCursorScreenPos(ctx, clear_x, clear_y)
    if ImGui.InvisibleButton(ctx, '##search_clear', clear_size, clear_size) then
      clear_clicked = true
    end
    clear_hovered = ImGui.IsItemHovered(ctx)
  end

  -- Handle keyboard focus (Ctrl+F)
  if state.focus_search then
    ImGui.SetCursorScreenPos(ctx, screen_x, screen_y)
    ImGui.SetKeyboardFocusHere(ctx)
    state.focus_search = false
  end

  -- Search input
  local search_result = Ark.InputText(ctx, {
    id = 'template_browser_search',
    x = screen_x,
    y = screen_y,
    width = input_width,
    height = search_height,
    placeholder = 'Search ' .. get_search_mode_label(state.search_mode or 'templates'):lower() .. '...',
    text = search_text,
  })

  if search_result.changed then
    state.search_query = search_result.value
    Scanner.filter_templates(state)
  end

  -- Draw X icon AFTER InputText so it appears on top
  if search_text ~= '' and clear_x then
    local dl = ImGui.GetWindowDrawList(ctx)
    local icon_color = clear_hovered and 0xFFFFFFFF or 0x888888FF
    local cx = clear_x + clear_size * 0.5
    local cy = clear_y + clear_size * 0.5
    local icon_r = 4

    ImGui.DrawList_AddLine(dl, cx - icon_r, cy - icon_r, cx + icon_r, cy + icon_r, icon_color, 1.5)
    ImGui.DrawList_AddLine(dl, cx + icon_r, cy - icon_r, cx - icon_r, cy + icon_r, icon_color, 1.5)
  end

  -- Handle clear click AFTER InputText
  if clear_clicked then
    state.search_query = ''
    Ark.InputText.Clear('template_browser_search')
    Scanner.filter_templates(state)
  end

  -- Search mode dropdown
  Ark.Combo(ctx, {
    id = 'search_mode_dropdown',
    x = screen_x + input_width + overlap,
    y = screen_y,
    width = dropdown_width,
    height = search_height,
    options = SEARCH_MODES,
    current_value = state.search_mode or 'templates',
    on_change = function(new_value)
      state.search_mode = new_value
      Scanner.filter_templates(state)
    end,
  })

  -- Move cursor past the toolbar
  ImGui.SetCursorPosY(ctx, start_y + search_height + spacing_after)

  return search_height + spacing_after
end

-- Handle Ctrl+F shortcut (call from main UI)
function M.handle_shortcuts(ctx, state)
  local ctrl = ImGui.IsKeyDown(ctx, ImGui.Key_LeftCtrl) or ImGui.IsKeyDown(ctx, ImGui.Key_RightCtrl)

  if ctrl and ImGui.IsKeyPressed(ctx, ImGui.Key_F) then
    state.focus_search = true
    return true
  end

  -- Escape clears search
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
    if state.search_query and state.search_query ~= '' then
      state.search_query = ''
      Ark.InputText.Clear('template_browser_search')
      Scanner.filter_templates(state)
      return true
    end
  end

  return false
end

return M

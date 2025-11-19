-- @noindex
-- rearkitekt/gui/widgets/primitives/markdown_field.lua
-- Markdown field widget with view/edit modes

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Style = require('rearkitekt.gui.style.defaults')
local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

-- State storage for each markdown field instance
local field_state = {}

-- ============================================================================
-- STATE MANAGEMENT
-- ============================================================================

local function get_or_create_state(id)
  if not field_state[id] then
    field_state[id] = {
      text = "",
      editing = false,
      markdown_renderer = nil,
      focus_set = false,
      hovered = false,
    }
  end
  return field_state[id]
end

-- ============================================================================
-- MARKDOWN RENDERING
-- ============================================================================

local function get_markdown_renderer(ctx, id, state)
  if not state.markdown_renderer then
    local ReaImGuiMd = require('rearkitekt.external.talagan_ReaImGui Markdown.reaimgui_markdown')

    -- Create markdown renderer with custom style
    state.markdown_renderer = ReaImGuiMd:new(ctx, id, {
      wrap = true,
      horizontal_scrollbar = false,
      width = 0,  -- Auto width
      height = 0,  -- Auto height
    })
  end

  -- Update context in case it changed
  state.markdown_renderer:updateCtx(ctx)

  return state.markdown_renderer
end

-- ============================================================================
-- RENDERING
-- ============================================================================

--- Draw markdown field with view/edit modes
-- @param ctx ImGui context
-- @param config Configuration table with:
--   - width: Field width (-1 for available width)
--   - height: Field height in edit mode
--   - text: Current text content
--   - placeholder: Text to show when empty (default: "Double-click to edit...")
--   - view_bg_color: Background color in view mode
--   - view_border_color: Border color in view mode
--   - edit_bg_color: Background color in edit mode
--   - edit_border_color: Border color in edit mode
--   - rounding: Corner rounding (default: 4)
--   - padding: Padding for view mode (default: 8)
-- @param id Unique identifier for this field
-- @return changed, new_text (changed is true when text is updated)
function M.draw_at_cursor(ctx, config, id)
  local state = get_or_create_state(id)

  -- Update text if changed externally
  if config.text ~= state.text and not state.editing then
    state.text = config.text or ""
  end

  local width = config.width or -1
  local height = config.height or 120
  local padding = config.padding or 8
  local rounding = config.rounding or 4

  -- Get current cursor position
  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)

  -- Calculate actual width if -1
  local actual_width = width
  if width == -1 then
    actual_width = ImGui.GetContentRegionAvail(ctx)
  end

  local changed = false
  local new_text = state.text

  if state.editing then
    -- ========================================================================
    -- EDIT MODE: Show multiline text input
    -- ========================================================================

    local edit_bg = config.edit_bg_color or hexrgb("#1A1A1A")
    local edit_border = config.edit_border_color or hexrgb("#4A9EFF")
    local text_color = config.text_color or hexrgb("#FFFFFF")

    -- Draw background
    local dl = ImGui.GetWindowDrawList(ctx)
    ImGui.DrawList_AddRectFilled(dl, cursor_x, cursor_y, cursor_x + actual_width, cursor_y + height, edit_bg, rounding)
    ImGui.DrawList_AddRect(dl, cursor_x, cursor_y, cursor_x + actual_width, cursor_y + height, edit_border, rounding, 0, 1.5)

    -- Position input field
    ImGui.SetCursorScreenPos(ctx, cursor_x + padding, cursor_y + padding)

    -- Auto-focus on first frame
    if not state.focus_set then
      ImGui.SetKeyboardFocusHere(ctx, 0)
      state.focus_set = true
    end

    -- Style the input to be transparent (we draw our own background)
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, hexrgb("#00000000"))
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgHovered, hexrgb("#00000000"))
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgActive, hexrgb("#00000000"))
    ImGui.PushStyleColor(ctx, ImGui.Col_Border, hexrgb("#00000000"))
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, text_color)

    local input_changed, input_text = ImGui.InputTextMultiline(
      ctx,
      "##edit_" .. id,
      state.text,
      actual_width - padding * 2,
      height - padding * 2,
      ImGui.InputTextFlags_None
    )

    ImGui.PopStyleColor(ctx, 5)

    if input_changed then
      state.text = input_text
      new_text = input_text
    end

    local is_input_active = ImGui.IsItemActive(ctx)
    local is_input_hovered = ImGui.IsItemHovered(ctx)

    -- Exit edit mode on Ctrl+Enter
    if ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl) and ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
      state.editing = false
      state.focus_set = false
      changed = true
      new_text = state.text
    end

    -- Exit edit mode on Escape (cancel)
    if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
      state.editing = false
      state.focus_set = false
      state.text = config.text or ""  -- Restore original
      new_text = state.text
    end

    -- Click away detection
    if ImGui.IsMouseClicked(ctx, ImGui.MouseButton_Left) and not is_input_active and not is_input_hovered then
      state.editing = false
      state.focus_set = false
      changed = true
      new_text = state.text
    end

    -- Move cursor to end of field
    ImGui.SetCursorScreenPos(ctx, cursor_x, cursor_y + height)
    ImGui.Dummy(ctx, actual_width, 0)  -- Ensure proper layout

  else
    -- ========================================================================
    -- VIEW MODE: Show rendered markdown
    -- ========================================================================

    local view_bg = config.view_bg_color or hexrgb("#0D0D0D")
    local view_border = config.view_border_color or hexrgb("#2A2A2A")
    local placeholder_color = config.placeholder_color or hexrgb("#666666")
    local placeholder_text = config.placeholder or "Double-click to edit..."

    -- Check if hovering over the view area
    local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
    local is_hovered = mouse_x >= cursor_x and mouse_x <= cursor_x + actual_width
                   and mouse_y >= cursor_y and mouse_y <= cursor_y + height

    state.hovered = is_hovered

    -- Adjust colors on hover
    local current_bg = view_bg
    local current_border = view_border
    if is_hovered then
      current_bg = Colors.adjust_brightness(view_bg, 1.15)
      current_border = Colors.adjust_brightness(view_border, 1.5)
    end

    -- Draw background and border
    local dl = ImGui.GetWindowDrawList(ctx)
    ImGui.DrawList_AddRectFilled(dl, cursor_x, cursor_y, cursor_x + actual_width, cursor_y + height, current_bg, rounding)
    ImGui.DrawList_AddRect(dl, cursor_x, cursor_y, cursor_x + actual_width, cursor_y + height, current_border, rounding, 0, 1)

    -- Create child window for markdown rendering or placeholder
    ImGui.SetCursorScreenPos(ctx, cursor_x, cursor_y)

    local child_flags = ImGui.ChildFlags_None
    local window_flags = ImGui.WindowFlags_NoScrollbar | ImGui.WindowFlags_NoScrollWithMouse

    if ImGui.BeginChild(ctx, "##view_" .. id, actual_width, height, child_flags, window_flags) then
      if state.text == "" or state.text == nil then
        -- Show placeholder
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, placeholder_color)
        ImGui.SetCursorPos(ctx, padding, padding)
        ImGui.TextWrapped(ctx, placeholder_text)
        ImGui.PopStyleColor(ctx)
      else
        -- Render markdown
        local renderer = get_markdown_renderer(ctx, id, state)
        renderer:setText(state.text)

        -- Add padding before rendering
        ImGui.SetCursorPos(ctx, padding, padding)

        -- Render markdown with constrained width
        local saved_cursor_x, saved_cursor_y = ImGui.GetCursorPos(ctx)
        renderer.options.width = actual_width - padding * 2
        renderer.options.height = height - padding * 2
        renderer:render(ctx)
      end

      ImGui.EndChild(ctx)
    end

    -- Detect double-click to enter edit mode
    if is_hovered and ImGui.IsMouseDoubleClicked(ctx, ImGui.MouseButton_Left) then
      state.editing = true
      state.focus_set = false
    end

    -- Move cursor to end of field
    ImGui.SetCursorScreenPos(ctx, cursor_x, cursor_y + height)
    ImGui.Dummy(ctx, actual_width, 0)  -- Ensure proper layout
  end

  return changed, new_text
end

--- Get current text for a field
-- @param id Field identifier
-- @return text Current text content
function M.get_text(id)
  local state = field_state[id]
  return state and state.text or ""
end

--- Set text for a field (updates internal state)
-- @param id Field identifier
-- @param text New text content
function M.set_text(id, text)
  local state = get_or_create_state(id)
  state.text = text or ""
end

--- Check if a field is currently being edited
-- @param id Field identifier
-- @return editing True if in edit mode
function M.is_editing(id)
  local state = field_state[id]
  return state and state.editing or false
end

--- Exit edit mode for a field
-- @param id Field identifier
function M.exit_edit_mode(id)
  local state = field_state[id]
  if state then
    state.editing = false
    state.focus_set = false
  end
end

return M

-- @noindex
-- arkitekt/gui/widgets/primitives/markdown_field.lua
-- Markdown field widget with view/edit modes

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Style = require('arkitekt.gui.style.defaults')
local Colors = require('arkitekt.core.colors')
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
      hover_alpha = 0.0,  -- For animating hover background
    }
  end
  return field_state[id]
end

-- ============================================================================
-- MARKDOWN RENDERING
-- ============================================================================

local function get_markdown_renderer(ctx, id, state)
  if not state.markdown_renderer then
    local ReaImGuiMd = require('arkitekt.external.talagan_ReaImGui Markdown.reaimgui_markdown')

    -- Teal accent color from style defaults (as hex strings for markdown lib)
    local teal_accent = "#41E0A3"
    local teal_dim = "#37775F"

    -- Create markdown renderer with custom teal-accented style
    state.markdown_renderer = ReaImGuiMd:new(ctx, id, {
      wrap = true,
      horizontal_scrollbar = false,
      width = 0,  -- Auto width
      height = 0,  -- Auto height
    }, {
      -- Apply teal accents to markdown elements (colors as hex strings)
      h1 = { base_color = teal_accent, bold_color = teal_accent, padding_left = 0 },
      h2 = { base_color = teal_accent, bold_color = teal_accent, padding_left = 0 },
      h3 = { base_color = teal_accent, bold_color = teal_accent, padding_left = 0 },
      h4 = { base_color = teal_accent, bold_color = teal_accent, padding_left = 0 },
      h5 = { base_color = teal_accent, bold_color = teal_accent, padding_left = 0 },
      paragraph = { padding_left = 0 },  -- Remove default 30px indent
      list = { padding_left = 20 },  -- Reduce from 40px to 20px for lists
      table = { padding_left = 0 },  -- Remove default 30px indent
      code = { base_color = teal_dim, bold_color = teal_dim, padding_left = 0 },  -- Remove default 30px indent
      code_block = { base_color = teal_dim, bold_color = teal_dim },
      link = { base_color = teal_accent, bold_color = teal_accent },
      strong = { base_color = teal_dim, bold_color = teal_dim },  -- Slightly dimmer teal for bold
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

    -- Exit edit mode on Enter (but NOT Shift+Enter - that's for line breaks)
    local shift_down = ImGui.IsKeyDown(ctx, ImGui.Mod_Shift)
    if not shift_down and (ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) or ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadEnter)) then
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
    local placeholder_color = config.placeholder_color or hexrgb("#666666")
    local placeholder_text = config.placeholder or "Double-click to edit..."

    -- Check if hovering over the view area
    local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
    local is_hovered = mouse_x >= cursor_x and mouse_x <= cursor_x + actual_width
                   and mouse_y >= cursor_y and mouse_y <= cursor_y + height

    state.hovered = is_hovered

    -- Animate hover alpha
    local target_alpha = is_hovered and 1.0 or 0.0
    local fade_speed = 10.0
    local alpha_delta = (target_alpha - state.hover_alpha) * fade_speed * ImGui.GetDeltaTime(ctx)
    state.hover_alpha = math.max(0.0, math.min(1.0, state.hover_alpha + alpha_delta))

    -- Draw background only when hovering (faded in)
    if state.hover_alpha > 0.01 then
      local dl = ImGui.GetWindowDrawList(ctx)
      local hover_bg = Colors.with_alpha(view_bg, math.floor(state.hover_alpha * 0x30))  -- Very subtle
      ImGui.DrawList_AddRectFilled(dl, cursor_x, cursor_y, cursor_x + actual_width, cursor_y + height, hover_bg, rounding)
    end

    -- Position cursor for content (don't create extra BeginChild - markdown renderer creates its own)
    ImGui.SetCursorScreenPos(ctx, cursor_x + padding, cursor_y + padding)

    if state.text == "" or state.text == nil then
      -- Show placeholder text
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, placeholder_color)
      ImGui.PushTextWrapPos(ctx, cursor_x + actual_width - padding)
      ImGui.Text(ctx, placeholder_text)
      ImGui.PopTextWrapPos(ctx)
      ImGui.PopStyleColor(ctx)
    else
      -- Render markdown (renderer creates its own child window)
      local renderer = get_markdown_renderer(ctx, id, state)
      renderer:setText(state.text)

      -- Configure renderer dimensions
      renderer.options.width = actual_width - padding * 2
      renderer.options.height = height - padding * 2
      renderer.options.horizontal_scrollbar = false
      renderer:render(ctx)
    end

    -- Detect double-click to enter edit mode
    if is_hovered and ImGui.IsMouseDoubleClicked(ctx, ImGui.MouseButton_Left) then
      state.editing = true
      state.focus_set = false
    end

    -- Move cursor to end of field and consume space
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

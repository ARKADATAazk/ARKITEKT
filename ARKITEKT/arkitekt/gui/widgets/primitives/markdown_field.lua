-- @noindex
-- arkitekt/gui/widgets/primitives/markdown_field.lua
-- Markdown field widget with view/edit modes

local ImGui = require('arkitekt.core.imgui')
local Theme = require('arkitekt.theme')
local Colors = require('arkitekt.core.colors')
local Base = require('arkitekt.gui.widgets.base')

local M = {}

-- ============================================================================
-- DEFAULTS
-- ============================================================================

local DEFAULTS = {
  id = 'markdown_field',
  width = -1,
  height = 120,
  text = '',
  placeholder = 'Double-click to edit...',
  view_bg_color = nil,       -- Theme.COLORS.BG_CHROME
  edit_bg_color = nil,       -- Theme.COLORS.BG_PANEL
  edit_border_color = nil,   -- Theme.COLORS.ACCENT_PRIMARY
  text_color = nil,          -- Theme.COLORS.TEXT_BRIGHT
  placeholder_color = nil,   -- Theme.COLORS.TEXT_DARK
  rounding = 4,
  padding = 8,
}

-- ============================================================================
-- INSTANCE MANAGEMENT
-- ============================================================================

local instances = Base.create_instance_registry()

local function create_instance(id)
  return {
    text = '',
    editing = false,
    markdown_renderer = nil,
    focus_set = false,
    hover_alpha = 0.0,
  }
end

-- ============================================================================
-- MARKDOWN RENDERING
-- ============================================================================

local function get_markdown_renderer(ctx, id, state)
  if not state.markdown_renderer then
    local ReaImGuiMd = require('arkitekt.vendor.talagan_ReaImGui Markdown.reaimgui_markdown')
    local teal = '#41E0A3'
    local teal_dim = '#37775F'

    state.markdown_renderer = ReaImGuiMd:new(ctx, id, {
      wrap = true,
      horizontal_scrollbar = false,
      width = 0,
      height = 0,
    }, {
      h1 = { base_color = teal, bold_color = teal, padding_left = 0 },
      h2 = { base_color = teal, bold_color = teal, padding_left = 0 },
      h3 = { base_color = teal, bold_color = teal, padding_left = 0 },
      h4 = { base_color = teal, bold_color = teal, padding_left = 0 },
      h5 = { base_color = teal, bold_color = teal, padding_left = 0 },
      paragraph = { padding_left = 0 },
      list = { padding_left = 20 },
      table = { padding_left = 0 },
      code = { base_color = teal_dim, bold_color = teal_dim, padding_left = 0 },
      code_block = { base_color = teal_dim, bold_color = teal_dim },
      link = { base_color = teal, bold_color = teal },
      strong = { base_color = teal_dim, bold_color = teal_dim },
    })
  end
  state.markdown_renderer:updateCtx(ctx)
  return state.markdown_renderer
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function M.Draw(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)

  -- Resolve colors from Theme (at runtime, not module load)
  local C = Theme.COLORS
  opts.view_bg_color = opts.view_bg_color or C.BG_CHROME
  opts.edit_bg_color = opts.edit_bg_color or C.BG_PANEL
  opts.edit_border_color = opts.edit_border_color or C.ACCENT_PRIMARY
  opts.text_color = opts.text_color or C.TEXT_BRIGHT
  opts.placeholder_color = opts.placeholder_color or C.TEXT_DARK

  -- Check disabled state (opts or stack)
  local actx = Base.get_context(ctx)
  local is_disabled = opts.is_disabled or actx:is_disabled()

  local unique_id = Base.resolve_id(ctx, opts, 'markdown_field')
  local state = Base.get_or_create_instance(instances, unique_id, create_instance, ctx)

  -- Exit edit mode if disabled while editing
  if is_disabled and state.editing then
    state.editing = false
    state.focus_set = false
  end

  -- Sync external text changes
  if opts.text ~= state.text and not state.editing then
    state.text = opts.text or ''
  end

  local width = opts.width == -1 and ImGui.GetContentRegionAvail(ctx) or opts.width
  local height = opts.height
  local padding = opts.padding
  local rounding = opts.rounding
  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  local dt = ImGui.GetDeltaTime(ctx)

  local changed = false
  local new_text = state.text

  if state.editing then
    -- Edit mode
    local dl = actx:draw_list()
    ImGui.DrawList_AddRectFilled(dl, cursor_x, cursor_y, cursor_x + width, cursor_y + height, opts.edit_bg_color, rounding)
    ImGui.DrawList_AddRect(dl, cursor_x, cursor_y, cursor_x + width, cursor_y + height, opts.edit_border_color, rounding, 0, 1.5)

    ImGui.SetCursorScreenPos(ctx, cursor_x + padding, cursor_y + padding)

    if not state.focus_set then
      ImGui.SetKeyboardFocusHere(ctx, 0)
      state.focus_set = true
    end

    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, C.BG_TRANSPARENT)
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgHovered, C.BG_TRANSPARENT)
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgActive, C.BG_TRANSPARENT)
    ImGui.PushStyleColor(ctx, ImGui.Col_Border, C.BG_TRANSPARENT)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, opts.text_color)

    local input_changed, input_text = ImGui.InputTextMultiline(ctx, '##edit_' .. unique_id, state.text,
      width - padding * 2, height - padding * 2, ImGui.InputTextFlags_None)

    ImGui.PopStyleColor(ctx, 5)

    if input_changed then
      state.text = input_text
      new_text = input_text
    end

    local is_active = ImGui.IsItemActive(ctx)
    local is_hovered = ImGui.IsItemHovered(ctx)

    -- Exit on Enter (not Shift+Enter)
    if not ImGui.IsKeyDown(ctx, ImGui.Mod_Shift) and
       (ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) or ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadEnter)) then
      state.editing = false
      state.focus_set = false
      changed = true
      new_text = state.text
    end

    -- Exit on Escape (cancel)
    if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
      state.editing = false
      state.focus_set = false
      state.text = opts.text or ''
      new_text = state.text
    end

    -- Click away
    if ImGui.IsMouseClicked(ctx, ImGui.MouseButton_Left) and not is_active and not is_hovered then
      state.editing = false
      state.focus_set = false
      changed = true
      new_text = state.text
    end

    ImGui.SetCursorScreenPos(ctx, cursor_x, cursor_y + height)
    ImGui.Dummy(ctx, width, 0)
  else
    -- View mode
    local mx, my = ImGui.GetMousePos(ctx)
    local is_hovered = mx >= cursor_x and mx <= cursor_x + width and my >= cursor_y and my <= cursor_y + height

    -- Animate hover
    local target = is_hovered and 1.0 or 0.0
    state.hover_alpha = state.hover_alpha + (target - state.hover_alpha) * 10.0 * dt
    state.hover_alpha = math.max(0.0, math.min(1.0, state.hover_alpha))

    if state.hover_alpha > 0.01 then
      local dl = actx:draw_list()
      local hover_bg = Colors.WithOpacity(opts.view_bg_color, state.hover_alpha * 0.19)
      ImGui.DrawList_AddRectFilled(dl, cursor_x, cursor_y, cursor_x + width, cursor_y + height, hover_bg, rounding)
    end

    ImGui.SetCursorScreenPos(ctx, cursor_x + padding, cursor_y + padding)

    if state.text == '' or state.text == nil then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, opts.placeholder_color)
      ImGui.PushTextWrapPos(ctx, cursor_x + width - padding)
      ImGui.Text(ctx, opts.placeholder)
      ImGui.PopTextWrapPos(ctx)
      ImGui.PopStyleColor(ctx)
    else
      local renderer = get_markdown_renderer(ctx, unique_id, state)
      renderer:setText(state.text)
      renderer.options.width = width - padding * 2
      renderer.options.height = height - padding * 2
      renderer.options.horizontal_scrollbar = false
      renderer:render(ctx)
    end

    if is_hovered and not is_disabled and ImGui.IsMouseDoubleClicked(ctx, ImGui.MouseButton_Left) then
      state.editing = true
      state.focus_set = false
    end

    ImGui.SetCursorScreenPos(ctx, cursor_x, cursor_y + height)
    ImGui.Dummy(ctx, width, 0)
  end

  return Base.create_result({
    changed = changed,
    value = new_text,
    width = width,
    height = height,
  })
end

function M.GetText(id)
  local state = instances._instances and instances._instances[id]
  return state and state.text or ''
end

function M.SetText(id, text)
  local state = instances._instances and instances._instances[id]
  if state then state.text = text or '' end
end

function M.IsEditing(id)
  local state = instances._instances and instances._instances[id]
  return state and state.editing or false
end

function M.ExitEditMode(id)
  local state = instances._instances and instances._instances[id]
  if state then
    state.editing = false
    state.focus_set = false
  end
end

-- snake_case aliases
M.get_text = M.GetText
M.set_text = M.SetText
M.is_editing = M.IsEditing
M.exit_edit_mode = M.ExitEditMode

-- ============================================================================
-- MODULE EXPORT
-- ============================================================================

return setmetatable(M, {
  __call = function(_, ctx, opts)
    return M.Draw(ctx, opts)
  end
})

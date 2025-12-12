-- @noindex
-- arkitekt/gui/widgets/modal/init.lua
-- Ark.Modal - Modular modal dialog system
--
-- USAGE:
--   -- Simple modal
--   if Ark.Modal.Begin(ctx, 'my_modal', state.show_modal, {
--     title = 'Settings',
--     width = 400,
--     height = 300,
--   }) then
--     -- Your content here (uses Ark widgets naturally)
--     Ark.InputText(ctx, { id = 'name', ... })
--     if Ark.Button(ctx, { label = 'Close' }).clicked then
--       state.show_modal = false
--     end
--     Ark.Modal.End(ctx)
--   end
--
--   -- The modal automatically:
--   -- - Disables background content (BeginDisabled)
--   -- - Draws scrim with fade animation
--   -- - Handles Escape to close
--   -- - Shows close button
--   -- - Supports click-outside-to-close

local ImGui = require('arkitekt.core.imgui')
local Context = require('arkitekt.core.context')
local Defaults = require('arkitekt.gui.widgets.modal.defaults')
local State = require('arkitekt.gui.widgets.modal.state')
local Rendering = require('arkitekt.gui.widgets.modal.rendering')

local M = {}

-- Track active modal for proper End() pairing
local _active_modal = nil
local _last_frame_time = nil
local _frame_dt = nil  -- Cached dt for current frame
local _frame_time = nil  -- Time at start of current frame

-- ============================================================================
-- CONFIGURATION HELPERS
-- ============================================================================

local function merge_config(opts, defaults)
  local config = {}
  for k, v in pairs(defaults) do
    if type(v) == 'table' then
      config[k] = {}
      for k2, v2 in pairs(v) do
        config[k][k2] = v2
      end
    else
      config[k] = v
    end
  end

  -- Apply user overrides
  if opts then
    for k, v in pairs(opts) do
      if type(v) == 'table' and type(config[k]) == 'table' then
        for k2, v2 in pairs(v) do
          config[k][k2] = v2
        end
      else
        config[k] = v
      end
    end
  end

  return config
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Begin a modal dialog
--- @param ctx userdata ImGui context
--- @param id string Unique modal identifier
--- @param is_open boolean Whether the modal should be open
--- @param opts table|nil Modal options
--- @return boolean True if modal is visible and content should be rendered
function M.Begin(ctx, id, is_open, opts)
  opts = opts or {}
  local defaults = Defaults.get()

  -- Merge options with defaults
  local config = merge_config(opts, defaults)

  -- Get or create modal state
  local state = State.get(id, config)

  -- Calculate delta time (cached per frame to handle multiple modals)
  local current_time = reaper.time_precise()
  local dt
  if not _frame_time or (current_time - _frame_time) > 0.001 then
    -- New frame detected (more than 1ms since last frame start)
    dt = _last_frame_time and math.min(current_time - _last_frame_time, 0.1) or 1/60
    _last_frame_time = current_time
    _frame_time = current_time
    _frame_dt = dt
  else
    -- Same frame, reuse cached dt
    dt = _frame_dt or 1/60
  end

  -- Handle open/close transitions
  if is_open and not state.is_closing then
    -- Opening - only trigger animation once
    if not state._is_open then
      state:open()
      state._is_open = true
    end
  else
    -- Closing - only trigger animation once
    if state._is_open then
      state:close()
      state._is_open = false
    end
  end

  -- Update animation
  state:update(dt)

  -- If fully closed, cleanup and return false
  if state:should_remove() then
    State.remove(id)
    return false
  end

  -- If not visible at all, skip rendering
  if not state:is_visible() then
    return false
  end

  local alpha = state:get_alpha()
  local actx = Context.get(ctx)

  -- Get bounds - use provided bounds or fall back to viewport
  local vp_x, vp_y, vp_w, vp_h
  if opts.bounds then
    vp_x = opts.bounds.x or 0
    vp_y = opts.bounds.y or 0
    vp_w = opts.bounds.width or opts.bounds.w or 800
    vp_h = opts.bounds.height or opts.bounds.h or 600
  else
    local viewport = ImGui.GetMainViewport(ctx)
    vp_x, vp_y = ImGui.Viewport_GetPos(viewport)
    vp_w, vp_h = ImGui.Viewport_GetSize(viewport)
  end

  -- Calculate modal dimensions
  local modal_w = opts.width or (vp_w * 0.5)
  local modal_h = opts.height or (vp_h * 0.5)

  -- Support percentage-based dimensions
  if modal_w <= 1.0 then modal_w = vp_w * modal_w end
  if modal_h <= 1.0 then modal_h = vp_h * modal_h end

  modal_w = math.floor(modal_w)
  modal_h = math.floor(modal_h)

  local modal_x = math.floor(vp_x + (vp_w - modal_w) / 2)
  local modal_y = math.floor(vp_y + (vp_h - modal_h) / 2)

  -- Store active modal info for End()
  _active_modal = {
    id = id,
    ctx = ctx,
    state = state,
    config = config,
    alpha = alpha,
    dt = dt,
    bounds = { x = vp_x, y = vp_y, width = vp_w, height = vp_h },
    modal = { x = modal_x, y = modal_y, width = modal_w, height = modal_h },
  }

  -- NOTE: disable_background is NOT handled here because the main UI
  -- is typically rendered BEFORE Modal.Begin() is called. The caller
  -- should wrap the main UI rendering with Ark.BeginDisabled/EndDisabled
  -- if they want to disable it while the modal is open.

  -- Draw scrim on foreground draw list
  local fg_dl = ImGui.GetForegroundDrawList(ctx)
  Rendering.draw_scrim(fg_dl, _active_modal.bounds, config.scrim, alpha)

  -- Draw shadow
  Rendering.draw_shadow(fg_dl, modal_x, modal_y, modal_w, modal_h, config.sheet.rounding, config.sheet.shadow, alpha)

  -- Draw sheet background
  Rendering.draw_sheet(fg_dl, modal_x, modal_y, modal_w, modal_h, config.sheet, alpha)

  -- Draw header if title provided
  local header_h = Rendering.draw_header(ctx, fg_dl, modal_x, modal_y, modal_w, opts.title, config.sheet.header, alpha)
  _active_modal.header_h = header_h

  -- Draw close button if enabled
  if config.behavior.show_close_button then
    local close_clicked = Rendering.draw_close_button(ctx, fg_dl, modal_x, modal_y, modal_w, config.close_button, state, alpha, dt)
    if close_clicked then
      state:request_close()
    end
  end

  -- Handle escape to close
  if config.behavior.close_on_escape and ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
    state:request_close()
  end

  -- Handle scrim click to close
  local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
  local over_modal = mouse_x >= modal_x and mouse_x <= modal_x + modal_w and
                     mouse_y >= modal_y and mouse_y <= modal_y + modal_h

  if not over_modal then
    if config.behavior.close_on_scrim_click and ImGui.IsMouseClicked(ctx, ImGui.MouseButton_Left) then
      state:request_close()
    end
    if config.behavior.close_on_scrim_right_click and ImGui.IsMouseClicked(ctx, ImGui.MouseButton_Right) then
      state:request_close()
    end
  end

  -- Create modal window for content
  local content_x = modal_x
  local content_y = modal_y + header_h
  local content_w = modal_w
  local content_h = modal_h - header_h
  local padding = config.sheet.padding

  ImGui.SetNextWindowPos(ctx, content_x, content_y)
  ImGui.SetNextWindowSize(ctx, content_w, content_h)

  -- Style the window
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, padding, padding)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowBorderSize, 0)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding, 0)
  ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg, 0x00000000)  -- Transparent (sheet already drawn)

  local window_flags = ImGui.WindowFlags_NoTitleBar
                     | ImGui.WindowFlags_NoResize
                     | ImGui.WindowFlags_NoMove
                     | ImGui.WindowFlags_NoCollapse
                     | ImGui.WindowFlags_NoDocking
                     | ImGui.WindowFlags_NoSavedSettings

  -- Add scrollbar flag based on config
  if not opts.scrollable then
    window_flags = window_flags | ImGui.WindowFlags_NoScrollbar
  end

  local visible = ImGui.Begin(ctx, '##modal_content_' .. id, true, window_flags)

  -- Store style push count for End()
  _active_modal.style_vars = 3
  _active_modal.style_colors = 1
  _active_modal.window_began = visible

  return visible
end

--- End the modal dialog
--- Must be called after Begin() returns true
--- @param ctx userdata ImGui context
function M.End(ctx)
  if not _active_modal then
    error('Modal.End called without matching Modal.Begin', 2)
  end

  -- End the window
  if _active_modal.window_began then
    ImGui.End(ctx)
  end

  -- Pop styles
  ImGui.PopStyleColor(ctx, _active_modal.style_colors)
  ImGui.PopStyleVar(ctx, _active_modal.style_vars)

  -- Clear active modal
  _active_modal = nil
end

--- Check if any modal is currently open
--- @return boolean
function M.IsAnyOpen()
  return _active_modal ~= nil
end

--- Request to close the current modal (triggers fade-out)
--- Can be called from within modal content
--- @param id string|nil Modal ID (optional, closes current if nil)
function M.Close(id)
  if _active_modal and (not id or _active_modal.id == id) then
    _active_modal.state:request_close()
  elseif id and State.exists(id) then
    local state = State.get(id, Defaults.get())
    state:request_close()
  end
end

--- Check if a specific modal wants to close (for external state sync)
--- @param id string Modal ID
--- @return boolean
function M.WantsClose(id)
  if State.exists(id) then
    local state = State.get(id, Defaults.get())
    return state.wants_close
  end
  return false
end

return M

-- @noindex
-- arkitekt/runtime/chrome/window/init.lua
-- Main window management with titlebar, status bar, and chrome

local ImGui = require('arkitekt.core.imgui')
local Config = require('arkitekt.core.merge')
local Constants = require('arkitekt.config.app')
local Typography = require('arkitekt.config.typography')
local Logger = require('arkitekt.debug.logger')

-- Submodules
local Helpers = require('arkitekt.runtime.chrome.window.helpers')
local Fullscreen = require('arkitekt.runtime.chrome.window.fullscreen')
local Docking = require('arkitekt.runtime.chrome.window.docking')
local Geometry = require('arkitekt.runtime.chrome.window.geometry')

local M = {}

-- Optional dependencies
local Colors = nil
do
  local ok, mod = pcall(require, 'arkitekt.core.colors')
  if ok then Colors = mod end
end

local WF_None = 0

-- ============================================================================
-- WINDOW CONSTRUCTOR
-- ============================================================================

function M.new(opts)
  -- Merge user opts with framework defaults
  local config = Config.deepMerge(Constants.WINDOW, opts or {})

  -- Deep merge fullscreen config
  local fullscreen_config = Config.deepMerge(Constants.WINDOW.fullscreen, config.fullscreen or {})
  local is_fullscreen = fullscreen_config.enabled or false

  -- Apply typography constants for font sizes if not explicitly provided
  if not opts or not opts.title_font_size then
    config.title_font_size = Typography.SIZE.lg
  end
  if not opts or not opts.version_font_size then
    config.version_font_size = Typography.SIZE.md
  end
  if not opts or not opts.titlebar_pad_v then
    config.titlebar_pad_v = Constants.TITLEBAR.pad_v
  end

  -- Build ImGui flags
  local base_flags = WF_None
  if config.imgui_flags ~= nil then
    base_flags = Constants.build_imgui_flags(ImGui, config.imgui_flags)
  end

  -- Disable ImGui's .ini persistence - we use our own settings.json
  -- This prevents ReaImGui from overriding our window geometry
  if ImGui.WindowFlags_NoSavedSettings then
    base_flags = base_flags | ImGui.WindowFlags_NoSavedSettings
  end

  -- Titlebar-only dragging: add NoMove flag to disable default drag behavior
  local titlebar_drag_only = config.titlebar_drag_only or false
  if titlebar_drag_only and ImGui.WindowFlags_NoMove then
    base_flags = base_flags | ImGui.WindowFlags_NoMove
  end

  -- Chrome configuration
  local chrome = {}
  if config.chrome and Constants.CHROME[config.chrome] then
    chrome = Config.deepMerge(Constants.CHROME[config.chrome], {})
  else
    chrome = {
      show_titlebar = nil,
      show_statusbar = nil,
      show_icon = nil,
      show_version = nil,
      enable_maximize = nil,
    }
  end

  -- Fallback to defaults
  if chrome.show_titlebar == nil then chrome.show_titlebar = true end
  if chrome.show_statusbar == nil then chrome.show_statusbar = true end
  if chrome.show_icon == nil then chrome.show_icon = Constants.TITLEBAR.show_icon end
  if chrome.show_version == nil then chrome.show_version = true end
  if chrome.enable_maximize == nil then chrome.enable_maximize = Constants.TITLEBAR.enable_maximize end

  -- Create window object
  local win = {
    settings        = config.settings,
    title           = config.title,
    version         = config.version,
    flags           = base_flags,
    topmost         = config.topmost or false,

    content_padding = config.content_padding,
    titlebar_pad_h  = config.titlebar_pad_h,
    titlebar_pad_v  = config.titlebar_pad_v,
    title_font      = config.title_font,
    title_font_size = config.title_font_size,
    version_font    = config.version_font,
    version_font_size = config.version_font_size,
    version_color   = config.version_color,

    initial_pos     = config.initial_pos,
    initial_size    = config.initial_size,
    min_size        = config.min_size,

    bg_color_floating = config.bg_color_floating,
    bg_color_docked   = config.bg_color_docked,

    chrome          = chrome,
    status_bar      = nil,
    tabs            = nil,
    active_tab      = nil,

    -- Submodule states
    fullscreen      = Fullscreen.create_state(fullscreen_config),
    _geo            = Geometry.create_state(),
    _dock           = Docking.create_state(),

    titlebar_opts   = {
      height          = config.titlebar_height or Constants.TITLEBAR.height,
      pad_h           = config.titlebar_pad_h or Constants.TITLEBAR.pad_h,
      pad_v           = config.titlebar_pad_v or Constants.TITLEBAR.pad_v,
      button_width    = config.titlebar_button_width or Constants.TITLEBAR.button_width,
      button_spacing  = config.titlebar_button_spacing or Constants.TITLEBAR.button_spacing,
      button_style    = config.titlebar_button_style or Constants.TITLEBAR.button_style,
      separator       = config.titlebar_separator,
      bg_color        = config.titlebar_bg_color,
      bg_color_active = config.titlebar_bg_color_active,
      text_color      = config.titlebar_text_color,
      enable_maximize = chrome.enable_maximize,
      title_font      = config.title_font,
      title_font_size = config.title_font_size,
      version_font    = config.version_font,
      version_font_size = config.version_font_size,
      version_color   = config.version_color,
      branding_font   = config.branding_font,
      branding_font_size = config.branding_font_size,
      branding_text   = config.branding_text,
      branding_opacity = config.branding_opacity,
      branding_color  = config.branding_color,
      show_icon       = chrome.show_icon,
      show_version    = chrome.show_version,
      icon_size       = config.icon_size,
      app_name        = opts.app_name,
      icon_spacing    = config.icon_spacing,
      icon_color      = config.icon_color,
      icon_draw       = config.icon_draw,
      dev_mode        = opts.dev_mode,
      drag_only       = titlebar_drag_only,
    },

    -- Internal state
    _body_open      = false,
    _begun          = false,
    _titlebar       = nil,
    _bg_color_pushed = false,
    _fullscreen_scrim_pushed = false,
    _nav_highlight_pushed = false,
    _last_frame_time = nil,
    _current_ctx    = nil,
    _should_close   = false,

    overlay         = nil,
    show_imgui_metrics = config.show_imgui_metrics or false,
  }

  -- Apply fullscreen flags
  if is_fullscreen then
    win.flags = Fullscreen.build_flags(win.flags, fullscreen_config)
    win.fullscreen.alpha:set_target(1.0)
  end

  -- Load saved state
  Geometry.load_from_settings(win.settings, win._geo)
  Docking.load_from_settings(win.settings, win._dock)

  -- ============================================================================
  -- CHROME COMPONENT CREATION
  -- ============================================================================
  if not is_fullscreen then
    -- Status bar
    if win.chrome.show_statusbar then
      local ok, StatusBar = pcall(require, 'arkitekt.runtime.chrome.status_bar')
      if ok and StatusBar and StatusBar.new then
        win.status_bar = StatusBar.new({
          height = Constants.STATUS_BAR.height + Constants.STATUS_BAR.compensation,
          get_status = opts.get_status_func or function() return { text = 'READY', color = 0x41E0A3FF } end,
          style = opts.style and { palette = opts.style.palette } or nil
        })
      end
    end

    -- Tabs
    if opts.tabs then
      local ok, Menutabs = pcall(require, 'arkitekt.gui.widgets.navigation.menutabs')
      if ok and Menutabs and Menutabs.new then
        win.tabs = Menutabs.new(opts.tabs)
        win.active_tab = win.tabs.active
      end
    end

    -- Titlebar
    if win.chrome.show_titlebar then
      local ok, Titlebar = pcall(require, 'arkitekt.runtime.chrome.titlebar')
      if ok and Titlebar and Titlebar.new then
        win.titlebar_opts.title = win.title
        win.titlebar_opts.version = win.version
        win.titlebar_opts.separator = opts.tabs and false or opts.titlebar_separator
        win.titlebar_opts.on_close = function()
          win._should_close = true
        end
        win.titlebar_opts.on_maximize = function()
          win:_maximize_requested()
        end
        win.titlebar_opts.on_icon_click = function(shift_clicked)
          if shift_clicked then
            win.show_imgui_metrics = not win.show_imgui_metrics
          else
            -- Launch hub
            local script_path = debug.getinfo(1, 'S').source
            if script_path:sub(1, 1) == '@' then
              script_path = script_path:sub(2)
            end
            local base_dir = script_path:match('(.+[/\\])')
            local hub_path = base_dir .. '../../../ARKITEKT.lua'
            hub_path = hub_path:gsub('[/\\]+', '/'):gsub('/+', '/')
            while hub_path:match('[^/]+/%.%./') do
              hub_path = hub_path:gsub('[^/]+/%.%./', '')
            end
            hub_path = hub_path:gsub('/', '\\')

            if reaper.file_exists(hub_path) then
              local sanitized = hub_path:gsub('[^%w]', '')
              local cmd_name = '_RS' .. sanitized
              local cmd_id = reaper.NamedCommandLookup(cmd_name)
              if not cmd_id or cmd_id == 0 then
                cmd_id = reaper.AddRemoveReaScript(true, 0, hub_path, true)
              end
              if cmd_id and cmd_id ~= 0 then
                reaper.Main_OnCommand(cmd_id, 0)
              end
            else
              Logger.warn('GUI', 'Hub not found: %s', hub_path)
            end
          end
        end

        win._titlebar = Titlebar.new(win.titlebar_opts)
        win._titlebar:set_maximized(win._geo.is_maximized)
      end
    end
  end

  -- Overlay manager
  do
    local ok, OverlayManager = pcall(require, 'arkitekt.gui.widgets.overlays.overlay.manager')
    if ok and OverlayManager and OverlayManager.new then
      win.overlay = OverlayManager.new()
    end
  end

  -- Fullscreen close button
  if is_fullscreen and win.fullscreen.show_close_button then
    win.fullscreen.close_button = Fullscreen.create_close_button(fullscreen_config, function()
      win:request_close()
    end)
  end

  -- ============================================================================
  -- PUBLIC API
  -- ============================================================================

  function win:set_title(s)
    self.title = tostring(s or self.title)
    if self._titlebar then
      self._titlebar:set_title(self.title)
    end
  end

  function win:set_version(v)
    self.version = v and tostring(v) or nil
    if self._titlebar then
      self._titlebar:set_version(self.version)
    end
  end

  function win:set_version_color(color)
    self.version_color = color
    if self._titlebar then
      self._titlebar:set_version_color(color)
    end
  end

  function win:set_title_font(font)
    self.title_font = font
    if self._titlebar then
      self._titlebar.title_font = font
    end
  end

  function win:get_active_tab()
    return self.active_tab
  end

  function win:request_close()
    if self.fullscreen.enabled then
      Fullscreen.request_close(self.fullscreen)
    else
      self._should_close = true
    end
  end

  function win:_maximize_requested()
    if ImGui.IsWindowDocked then
      if self._current_ctx and ImGui.IsWindowDocked(self._current_ctx) then
        return
      end
    end
    self._geo.pending_maximize = true
  end

  function win:_toggle_maximize()
    Geometry.toggle_maximize(self._current_ctx, self._geo, self.settings, function(is_max)
      if self._titlebar then
        self._titlebar:set_maximized(is_max)
      end
    end)
  end

  -- ============================================================================
  -- FRAME LIFECYCLE
  -- ============================================================================

  function win:Begin(ctx)
    self._body_open = false
    self._should_close = false
    self._current_ctx = ctx

    -- Fullscreen alpha update
    if self.fullscreen.enabled then
      local current_time = reaper.time_precise()
      local dt = 1/60
      if self._last_frame_time then
        dt = current_time - self._last_frame_time
        dt = math.max(0.001, math.min(dt, 0.1))
      end
      self._last_frame_time = current_time

      if Fullscreen.update_alpha(self.fullscreen, dt) then
        self._should_close = true
      end
    end

    -- Apply geometry
    Geometry.apply(ctx, self._geo, self._dock, self.fullscreen, self.initial_pos, self.initial_size, self.min_size)

    -- Status bar resize
    if self.status_bar and self.status_bar.apply_pending_resize then
      self.status_bar.apply_pending_resize(ctx)
    end

    -- Push styles
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 0, 0)
    ImGui.PushStyleColor(ctx, ImGui.Col_NavCursor, 0x00000000)
    self._nav_highlight_pushed = true

    -- Background color
    if self.fullscreen.enabled then
      if Fullscreen.push_bg_style(ctx, self.fullscreen) then
        self._fullscreen_scrim_pushed = true
      end
    else
      local bg_color = self._dock.was_docked and self.bg_color_docked or self.bg_color_floating
      if bg_color then
        ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg, bg_color)
        self._bg_color_pushed = true
      end
    end

    -- Window flags
    local window_flags = self.flags
    if self.fullscreen.enabled and self.fullscreen.is_closing and ImGui.WindowFlags_NoInputs then
      window_flags = window_flags | ImGui.WindowFlags_NoInputs
    end
    if self.topmost and ImGui.WindowFlags_TopMost then
      window_flags = window_flags | ImGui.WindowFlags_TopMost
    end

    -- Begin window (use ### for stable window ID - title can change without affecting ImGui's window identity)
    local visible, open = ImGui.Begin(ctx, self.title .. '###main', true, window_flags)
    self._begun = true

    if visible then
      if self.fullscreen.enabled then
        local wx, wy = ImGui.GetWindowPos(ctx)
        local ww, wh = ImGui.GetWindowSize(ctx)

        self.fullscreen.background_clicked = false

        Fullscreen.render_scrim(ctx, self.fullscreen, wx, wy, ww, wh)
        Fullscreen.handle_background_click(ctx, self.fullscreen, wx, wy, ww, wh)

        local dt = self._last_frame_time and (reaper.time_precise() - self._last_frame_time) or 1/60
        Fullscreen.update_close_button(ctx, self.fullscreen, wx, wy, ww, wh, dt)
      else
        -- Docking state update
        Docking.update(ctx, self._dock, self.settings)

        -- Handle pending maximize
        if self._geo.pending_maximize then
          self:_toggle_maximize()
          self._geo.pending_maximize = false
        end

        -- Render titlebar
        local titlebar_rendered = false
        if self._titlebar and not self._dock.was_docked then
          local win_w = ImGui.GetWindowSize(ctx)
          local keep_open, drag_dx, drag_dy = self._titlebar:render(ctx, win_w)
          if not keep_open then
            self._should_close = true
          end
          -- Apply titlebar drag delta
          if drag_dx and drag_dy and (drag_dx ~= 0 or drag_dy ~= 0) then
            local wx, wy = ImGui.GetWindowPos(ctx)
            self._geo.pending_pos = { x = wx + drag_dx, y = wy + drag_dy }
          end
          titlebar_rendered = true
        end

        -- Render tabs
        if self.tabs then
          if titlebar_rendered then
            local cursor_x = ImGui.GetCursorPosX(ctx)
            ImGui.SetCursorPos(ctx, cursor_x, self.titlebar_opts.height)
          end
          local active = self.tabs:draw(ctx)
          self.active_tab = active
        end

        -- Save geometry
        Geometry.save(ctx, self._geo, self._dock, self.fullscreen, self.settings)
      end
    end

    ImGui.PopStyleVar(ctx)

    if self._should_close then
      open = false
    end

    return visible, open
  end

  function win:BeginBody(ctx)
    if self._body_open then return false end

    local status_h = 0
    if not self.fullscreen.enabled then
      status_h = (self.status_bar and not self._dock.was_docked and self.status_bar.height) or 0
    end
    local body_h = -status_h

    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, self.content_padding, self.content_padding)
    local child_flags = ImGui.ChildFlags_AlwaysUseWindowPadding or 0
    local window_flags = ImGui.WindowFlags_NoScrollbar

    local success = ImGui.BeginChild(ctx, '##body', 0, body_h, child_flags, window_flags)
    self._body_open = true
    return success
  end

  function win:EndBody(ctx)
    if not self._body_open then return end
    ImGui.EndChild(ctx)
    ImGui.PopStyleVar(ctx)
    self._body_open = false
  end

  function win:BeginTabs(_) return true end
  function win:EndTabs(_) end

  function win:End(ctx)
    -- Status bar
    if not self.fullscreen.enabled then
      if self.status_bar and self.status_bar.render and not self._dock.was_docked then
        ImGui.SetCursorPosX(ctx, 0)
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 0, 0)
        local sf = self.version_font or self.title_font
        local ss = self.version_font_size or Typography.SIZE.md
        if sf and ss and ss > 0 then
          ImGui.PushFont(ctx, sf, ss)
          self.status_bar.render(ctx)
          ImGui.PopFont(ctx)
        else
          self.status_bar.render(ctx)
        end
        ImGui.PopStyleVar(ctx)
      end
    end

    -- Overlay
    if self.overlay and self.overlay.render then
      local titlebar_h = 0
      local statusbar_h = 0
      if not self.fullscreen.enabled then
        titlebar_h = (self._titlebar and not self._dock.was_docked) and self.titlebar_opts.height or 0
        statusbar_h = (self.status_bar and not self._dock.was_docked) and self.status_bar.height or 0
      end
      self.overlay:set_ui_bounds(titlebar_h, statusbar_h, self._dock.was_docked or self.fullscreen.enabled)
      self.overlay:render(ctx, 1/60)
    end

    -- Fullscreen close button
    if self.fullscreen.enabled then
      local wx, wy = ImGui.GetWindowPos(ctx)
      local ww, wh = ImGui.GetWindowSize(ctx)
      Fullscreen.render_close_button(ctx, self.fullscreen, wx, wy, ww, wh)

      if self.fullscreen.background_clicked and not self.fullscreen.is_closing then
        self:request_close()
      end
    end

    -- Metrics window
    if self.show_imgui_metrics and ImGui.ShowMetricsWindow then
      self.show_imgui_metrics = ImGui.ShowMetricsWindow(ctx, true)
    end

    -- Cleanup
    if self._body_open then
      ImGui.EndChild(ctx)
      ImGui.PopStyleVar(ctx)
      self._body_open = false
    end

    if self._begun then
      ImGui.End(ctx)
      self._begun = false
    end

    if self._fullscreen_scrim_pushed then
      ImGui.PopStyleColor(ctx)
      self._fullscreen_scrim_pushed = false
    end

    if self._bg_color_pushed then
      ImGui.PopStyleColor(ctx)
      self._bg_color_pushed = false
    end

    if self._nav_highlight_pushed then
      ImGui.PopStyleColor(ctx)
      self._nav_highlight_pushed = false
    end
  end

  return win
end

return M

-- @noindex
-- ReArkitekt/app/window.lua
-- MODIFIED: Removed monospace_font propagation (using regular font for version)

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.9'

local M = {}

local Hub = nil
do
  local ok, mod = pcall(require, 'rearkitekt.app.hub')
  if ok then Hub = mod end
end

local WF_None = 0

local function floor(n) return math.floor(n + 0.5) end

local DEFAULTS = {}
do
  local ok, Config = pcall(require, 'rearkitekt.app.config')
  if ok and Config and Config.get_defaults then
    DEFAULTS = Config.get_defaults()
  else
    DEFAULTS = {
      window = {
        content_padding = 12,
        initial_pos = { x = 100, y = 100 },
        initial_size = { w = 900, h = 600 },
        min_size = { w = 400, h = 300 },
      },
      status_bar = {
        height = 28,
      },
      titlebar = {
        height = 26,
        pad_h = 12,
        pad_v = 0,
      },
    }
  end
end

function M.new(opts)
  opts = opts or {}

  local win = {
    settings        = opts.settings,
    title           = opts.title or DEFAULTS.window.title or "Window",
    version         = opts.version,
    flags           = opts.flags or WF_None,

    content_padding = opts.content_padding or DEFAULTS.window.content_padding,
    titlebar_pad_h  = opts.titlebar_pad_h,
    titlebar_pad_v  = opts.titlebar_pad_v or DEFAULTS.titlebar.pad_v,
    title_font      = opts.title_font,
    version_font    = opts.version_font,
    version_color   = opts.version_color,

    initial_pos     = opts.initial_pos  or DEFAULTS.window.initial_pos,
    initial_size    = opts.initial_size or DEFAULTS.window.initial_size,
    min_size        = opts.min_size     or DEFAULTS.window.min_size,

    bg_color_floating = opts.bg_color_floating or DEFAULTS.window.bg_color_floating,
    bg_color_docked   = opts.bg_color_docked or DEFAULTS.window.bg_color_docked,
    
    status_bar      = nil,
    tabs            = nil,
    active_tab      = nil,

    titlebar_opts   = {
      height          = opts.titlebar_height or DEFAULTS.titlebar.height,
      pad_h           = opts.titlebar_pad_h or DEFAULTS.titlebar.pad_h,
      pad_v           = opts.titlebar_pad_v or DEFAULTS.titlebar.pad_v,
      button_width    = opts.titlebar_button_width or DEFAULTS.titlebar.button_width,
      button_spacing  = opts.titlebar_button_spacing or DEFAULTS.titlebar.button_spacing,
      button_style    = opts.titlebar_button_style or DEFAULTS.titlebar.button_style,
      separator       = opts.titlebar_separator,
      bg_color        = opts.titlebar_bg_color,
      bg_color_active = opts.titlebar_bg_color_active,
      text_color      = opts.titlebar_text_color,
      enable_maximize = opts.enable_maximize ~= false,
      title_font      = opts.title_font,
      version_font    = opts.version_font,
      version_color   = opts.version_color,
      show_icon       = opts.show_icon,
      icon_size       = opts.icon_size,
      icon_spacing    = opts.icon_spacing,
      icon_color      = opts.icon_color,
      icon_draw       = opts.icon_draw,
    },

    _is_maximized   = false,
    _pre_max_pos    = nil,
    _pre_max_size   = nil,
    _max_viewport   = nil,
    _pending_maximize = false,
    _pending_restore  = false,

    _saved_pos      = nil,
    _saved_size     = nil,
    _pos_size_set   = false,
    _body_open      = false,
    _begun          = false,
    _titlebar       = nil,
    _was_docked     = false,
    _bg_color_pushed = false,
    
    overlay         = nil,
    
    show_imgui_metrics = false,
  }

  if ImGui.WindowFlags_NoTitleBar then
    win.flags = win.flags | ImGui.WindowFlags_NoTitleBar
  end
  if ImGui.WindowFlags_NoCollapse then
    win.flags = win.flags | ImGui.WindowFlags_NoCollapse
  end
  if ImGui.WindowFlags_NoScrollbar then
    win.flags = win.flags | ImGui.WindowFlags_NoScrollbar
  end
  if ImGui.WindowFlags_NoScrollWithMouse then
    win.flags = win.flags | ImGui.WindowFlags_NoScrollWithMouse
  end

  if win.settings then
    win._saved_pos  = win.settings:get("window.pos",  nil)
    win._saved_size = win.settings:get("window.size", nil)
    win._is_maximized = win.settings:get("window.maximized", false)
  end

  if opts.show_status_bar ~= false then
    local ok, StatusBar = pcall(require, 'rearkitekt.app.chrome.status_bar')
    if ok and StatusBar and StatusBar.new then
      local status_height_compensation = 6
      win.status_bar = StatusBar.new({
        height = DEFAULTS.status_bar.height + status_height_compensation,
        get_status = opts.get_status_func or function() return { text = "READY", color = 0x41E0A3FF } end,
        style = opts.style and { palette = opts.style.palette } or nil
      })
    end
  end

  if opts.tabs then
    local ok, Menutabs = pcall(require, 'rearkitekt.gui.widgets.navigation.menutabs')
    if ok and Menutabs and Menutabs.new then
      win.tabs = Menutabs.new(opts.tabs)
      win.active_tab = win.tabs.active
    end
  end

  if opts.show_titlebar ~= false then
    do
      local ok, Titlebar = pcall(require, 'rearkitekt.app.titlebar')
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
            local script_path = debug.getinfo(1, "S").source
            if script_path:sub(1, 1) == "@" then
              script_path = script_path:sub(2)
            end
            
            local base_dir = script_path:match("(.+[/\\])")
            local hub_path = base_dir .. "../../ARKITEKT.lua"
            hub_path = hub_path:gsub("[/\\]+", "/"):gsub("/+", "/")
            while hub_path:match("[^/]+/%.%./") do
              hub_path = hub_path:gsub("[^/]+/%.%./", "")
            end
            hub_path = hub_path:gsub("/", "\\")
            
            if reaper.file_exists(hub_path) then
              local sanitized = hub_path:gsub("[^%w]", "")
              local cmd_name = "_RS" .. sanitized
              local cmd_id = reaper.NamedCommandLookup(cmd_name)
              
              if not cmd_id or cmd_id == 0 then
                cmd_id = reaper.AddRemoveReaScript(true, 0, hub_path, true)
              end
              
              if cmd_id and cmd_id ~= 0 then
                reaper.Main_OnCommand(cmd_id, 0)
              end
            else
              reaper.ShowConsoleMsg("Hub not found: " .. hub_path .. "\n")
            end
          end
        end
        
        win._titlebar = Titlebar.new(win.titlebar_opts)
        win._titlebar:set_maximized(win._is_maximized)
      end
    end
  end

  do
    local ok, OverlayManager = pcall(require, 'rearkitekt.gui.widgets.overlay.manager')
    if ok and OverlayManager and OverlayManager.new then
      win.overlay = OverlayManager.new()
    end
  end

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

  function win:_maximize_requested()
    if ImGui.IsWindowDocked then
      if self._current_ctx and ImGui.IsWindowDocked(self._current_ctx) then
        return
      end
    end
    self._pending_maximize = true
  end

  function win:_toggle_maximize()
    if not self._current_ctx then return end
    local ctx = self._current_ctx
    
    if self._is_maximized then
      self._is_maximized = false
      self._pending_restore = true
    else
      local wx, wy = ImGui.GetWindowPos(ctx)
      local ww, wh = ImGui.GetWindowSize(ctx)
      self._pre_max_pos = { x = floor(wx), y = floor(wy) }
      self._pre_max_size = { w = floor(ww), h = floor(wh) }
      
      local js_success = false
      if reaper.JS_Window_GetViewportFromRect then
        local left, top, right, bottom = reaper.JS_Window_GetViewportFromRect(
          wx, wy, wx + ww, wy + wh, true
        )
        if left and right and top and bottom then
          self._max_viewport = { 
            x = left, 
            y = top, 
            w = right - left, 
            h = bottom - top 
          }
          js_success = true
        end
      end
      
      if not js_success then
        local monitor_width = 1920
        local monitor_height = 1080
        local taskbar_offset = 40
        local monitor_index = math.floor((self._pre_max_pos.x + monitor_width / 2) / monitor_width)
        local monitor_left = monitor_index * monitor_width
        local monitor_top = 0
        
        self._max_viewport = { 
          x = monitor_left, 
          y = monitor_top,
          w = monitor_width, 
          h = monitor_height - taskbar_offset 
        }
      end
      
      self._is_maximized = true
    end
    
    if self._titlebar then
      self._titlebar:set_maximized(self._is_maximized)
    end
    
    if self.settings then
      self.settings:set("window.maximized", self._is_maximized)
    end
  end

  function win:_apply_geometry(ctx)
    if self._is_maximized and self._max_viewport then
      if self._max_viewport.x and self._max_viewport.y then
        ImGui.SetNextWindowPos(ctx, self._max_viewport.x, self._max_viewport.y, ImGui.Cond_Always)
      end
      ImGui.SetNextWindowSize(ctx, self._max_viewport.w, self._max_viewport.h, ImGui.Cond_Always)
      self._pos_size_set = true
    elseif self._pending_restore and self._pre_max_pos then
      ImGui.SetNextWindowPos(ctx, self._pre_max_pos.x, self._pre_max_pos.y, ImGui.Cond_Always)
      ImGui.SetNextWindowSize(ctx, self._pre_max_size.w, self._pre_max_size.h, ImGui.Cond_Always)
      self._pending_restore = false
      self._pos_size_set = true
    elseif not self._pos_size_set then
      local pos  = self._saved_pos  or self.initial_pos
      local size = self._saved_size or self.initial_size
      if pos  and pos.x  and pos.y  then ImGui.SetNextWindowPos(ctx,  pos.x,  pos.y) end
      if size and size.w and size.h then ImGui.SetNextWindowSize(ctx, size.w, size.h) end
      self._pos_size_set = true
    end
    
    if ImGui.SetNextWindowSizeConstraints and self.min_size then
      ImGui.SetNextWindowSizeConstraints(ctx, self.min_size.w, self.min_size.h, 99999, 99999)
    end
  end

  function win:_save_geometry(ctx)
    if not self.settings then return end
    if self._is_maximized then return end
    
    local wx, wy = ImGui.GetWindowPos(ctx)
    local ww, wh = ImGui.GetWindowSize(ctx)
    local pos  = { x = floor(wx), y = floor(wy) }
    local size = { w = floor(ww), h = floor(wh) }

    if (not self._saved_pos) or pos.x ~= self._saved_pos.x or pos.y ~= self._saved_pos.y then
      self._saved_pos = pos
      self.settings:set("window.pos", pos)
    end
    if (not self._saved_size) or size.w ~= self._saved_size.w or size.h ~= self._saved_size.h then
      self._saved_size = size
      self.settings:set("window.size", size)
    end
  end

  function win:Begin(ctx)
    self._body_open = false
    self._should_close = false
    self._current_ctx = ctx
    
    self:_apply_geometry(ctx)

    if self.status_bar and self.status_bar.apply_pending_resize then
      self.status_bar.apply_pending_resize(ctx)
    end

    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 0, 0)
    
    local bg_color = self._was_docked and self.bg_color_docked or self.bg_color_floating
    if bg_color then
      ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg, bg_color)
      self._bg_color_pushed = true
    end

    local visible, open = ImGui.Begin(ctx, self.title .. "##main", true, self.flags)
    self._begun = true

    if visible then
      if ImGui.IsWindowDocked then
        self._was_docked = ImGui.IsWindowDocked(ctx)
      end
      
      if self._pending_maximize then
        self:_toggle_maximize()
        self._pending_maximize = false
      end
      
      local titlebar_rendered = false
      if self._titlebar and not self._was_docked then
        local win_w, _ = ImGui.GetWindowSize(ctx)
        local keep_open = self._titlebar:render(ctx, win_w)
        if not keep_open then
          self._should_close = true
        end
        titlebar_rendered = true
      end
      
      if self.tabs then
        if titlebar_rendered then
          local cursor_x = ImGui.GetCursorPosX(ctx)
          ImGui.SetCursorPos(ctx, cursor_x, self.titlebar_opts.height)
        end
        local active, index = self.tabs:draw(ctx)
        self.active_tab = active
      end
      
      self:_save_geometry(ctx)
    end

    ImGui.PopStyleVar(ctx)
    
    if self._should_close then
      open = false
    end
    
    return visible, open
  end

function win:BeginBody(ctx)
    if self._body_open then return false end
    
    local status_h = (self.status_bar and not self._was_docked and self.status_bar.height) or 0
    local body_h = -status_h

    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, self.content_padding, self.content_padding)
    local child_flags = ImGui.ChildFlags_AlwaysUseWindowPadding or 0
    local window_flags = ImGui.WindowFlags_NoScrollbar
    
    local success = ImGui.BeginChild(ctx, "##body", 0, body_h, child_flags, window_flags)
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
    if self.status_bar and self.status_bar.render and not self._was_docked then
      ImGui.SetCursorPosX(ctx, 0)
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 0, 0)
      self.status_bar.render(ctx)
      ImGui.PopStyleVar(ctx)
    end

    if self.overlay and self.overlay.render then
      local titlebar_h = (self._titlebar and not self._was_docked) and self.titlebar_opts.height or 0
      local statusbar_h = (self.status_bar and not self._was_docked) and self.status_bar.height or 0
      
      self.overlay:set_ui_bounds(titlebar_h, statusbar_h, self._was_docked)
      
      local dt = 1/60
      self.overlay:render(ctx, dt)
    end
    
    if self.show_imgui_metrics and ImGui.ShowMetricsWindow then
      self.show_imgui_metrics = ImGui.ShowMetricsWindow(ctx, true)
    end

    if self._begun then 
      ImGui.End(ctx)
      self._begun = false
    end
    
    if self._bg_color_pushed then
      ImGui.PopStyleColor(ctx)
      self._bg_color_pushed = false
    end
  end

  return win
end

return M
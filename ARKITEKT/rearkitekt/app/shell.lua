-- @noindex
-- ReArkitekt/app/shell.lua
-- MODIFIED: Made font loading robust against older configuration files.
-- ADDED: Support for titlebar_version size override (uses regular font family)
-- ADDED: Integrated Lua profiler support via global config flag
-- ADDED: Support for show_icon option to disable titlebar icon
-- UPDATED: ImGui 0.10 font size handling

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui   = require 'imgui' '0.10'
local Runtime = require('rearkitekt.app.runtime')
local Window  = require('rearkitekt.app.window')

local M = {}

local DEFAULTS = {}
do
  local ok, Config = pcall(require, 'rearkitekt.app.app_defaults')
  if ok and Config and Config.get_defaults then
    DEFAULTS = Config.get_defaults()
  else
    DEFAULTS = {
      window = {
        title           = 'ReArkitekt App',
        content_padding = 12,
        min_size        = { w = 400, h = 300 },
        initial_size    = { w = 900, h = 600 },
        initial_pos     = { x = 100, y = 100 },
      },
      fonts = {
        default        = 13,
        title          = 16,
        version        = 13,
        titlebar_version = nil,
        monospace      = 13,
        family_regular = 'Inter_18pt-Regular.ttf',
        family_bold    = 'Inter_18pt-SemiBold.ttf',
        family_mono    = 'JetBrainsMono-Regular.ttf',
      },
    }
  end
end

local function merge(dst, src)
  if not src then return dst end
  for k,v in pairs(src) do
    if type(v) == 'table' and type(dst[k]) == 'table' then
      merge(dst[k], v)
    else
      dst[k] = v
    end
  end
  return dst
end

local function load_fonts(ctx, font_cfg)
  font_cfg = merge({
    default        = (DEFAULTS.fonts and DEFAULTS.fonts.default) or 13,
    title          = (DEFAULTS.fonts and DEFAULTS.fonts.title) or 16,
    version        = (DEFAULTS.fonts and DEFAULTS.fonts.version) or 13,
    titlebar_version = (DEFAULTS.fonts and DEFAULTS.fonts.titlebar_version) or nil,
    monospace      = (DEFAULTS.fonts and DEFAULTS.fonts.monospace) or 13,
    time_display   = (DEFAULTS.fonts and DEFAULTS.fonts.time_display) or nil,
    icons          = (DEFAULTS.fonts and DEFAULTS.fonts.icons) or nil,
    family_regular = (DEFAULTS.fonts and DEFAULTS.fonts.family_regular) or 'Inter_18pt-Regular.ttf',
    family_bold    = (DEFAULTS.fonts and DEFAULTS.fonts.family_bold) or 'Inter_18pt-SemiBold.ttf',
    family_mono    = (DEFAULTS.fonts and DEFAULTS.fonts.family_mono) or 'JetBrainsMono-Regular.ttf',
    family_icons   = (DEFAULTS.fonts and DEFAULTS.fonts.family_icons) or 'remixicon.ttf',
  }, font_cfg or {})

  local SEP      = package.config:sub(1,1)
  local src      = debug.getinfo(1, 'S').source:sub(2)
  local this_dir = src:match('(.*'..SEP..')') or ('.'..SEP)
  local parent   = this_dir:match('^(.*'..SEP..')[^'..SEP..']*'..SEP..'$') or this_dir
  local fontsdir = parent .. 'fonts' .. SEP

  local R = fontsdir .. font_cfg.family_regular
  local B = fontsdir .. font_cfg.family_bold
  local M = fontsdir .. font_cfg.family_mono
  local I = fontsdir .. font_cfg.family_icons

  local function exists(p) local f = io.open(p, 'rb'); if f then f:close(); return true end end
  -- Original working pattern: CreateFont(path, size) with Attach
  local default_font   = exists(R) and ImGui.CreateFont(R, font_cfg.default)
                                or ImGui.CreateFont('sans-serif', font_cfg.default)
  local title_font     = exists(B) and ImGui.CreateFont(B, font_cfg.title)
                                or default_font
  local version_font   = exists(R) and ImGui.CreateFont(R, font_cfg.version)
                                or default_font
  local monospace_font = exists(M) and ImGui.CreateFont(M, font_cfg.monospace)
                                or default_font

  local time_display_font = nil
  if font_cfg.time_display then
    time_display_font = exists(B) and ImGui.CreateFont(B, font_cfg.time_display)
                                   or ImGui.CreateFont('sans-serif', font_cfg.time_display)
    ImGui.Attach(ctx, time_display_font)
  end

  local titlebar_version_font = nil
  local titlebar_version_size = font_cfg.titlebar_version or font_cfg.version
  if font_cfg.titlebar_version then
    titlebar_version_font = exists(R) and ImGui.CreateFont(R, font_cfg.titlebar_version)
                                       or version_font
    ImGui.Attach(ctx, titlebar_version_font)
  end

  local icons_font = nil
  if font_cfg.icons then
    if exists(I) then
      icons_font = ImGui.CreateFont(I, font_cfg.icons)
      if icons_font then
        reaper.ShowConsoleMsg(string.format("[Shell] Icon font loaded: %s (size: %d, obj: %s)\n", I, font_cfg.icons, tostring(icons_font)))
        ImGui.Attach(ctx, icons_font)
      else
        reaper.ShowConsoleMsg(string.format("[Shell] ERROR: Icon font failed to load: %s\n", I))
        icons_font = default_font
      end
    else
      reaper.ShowConsoleMsg(string.format("[Shell] WARNING: Icon font file not found: %s\n", I))
      icons_font = default_font
    end
  end

  ImGui.Attach(ctx, default_font)
  ImGui.Attach(ctx, title_font)
  ImGui.Attach(ctx, version_font)
  ImGui.Attach(ctx, monospace_font)

  return {
    default = default_font,
    default_size = font_cfg.default,
    title = title_font,
    title_size = font_cfg.title,
    version = version_font,
    version_size = font_cfg.version,
    monospace = monospace_font,
    monospace_size = font_cfg.monospace,
    titlebar_version = titlebar_version_font,
    titlebar_version_size = titlebar_version_size,
    time_display = time_display_font,
    time_display_size = font_cfg.time_display,
    icons = icons_font,
    icons_size = font_cfg.icons,
  }
end

function M.run(opts)
  opts = opts or {}

  local cfg = {
    window = DEFAULTS.window,
    fonts  = DEFAULTS.fonts,
  }

  if opts.window then merge(cfg.window, opts.window) end
  if opts.fonts  or opts.font_sizes then
    merge(cfg.fonts, (opts.fonts or opts.font_sizes))
  end

  local title    = opts.title or cfg.window.title
  local version  = opts.version
  local draw_fn  = opts.draw or function(ctx) ImGui.Text(ctx, 'No draw function provided') end
  local style    = opts.style
  local settings = opts.settings
  local raw_content = (opts.raw_content == true)
  local enable_profiling = opts.enable_profiling ~= false
  
  local show_icon = opts.window and opts.window.show_icon
  if show_icon == nil then
    show_icon = opts.show_icon
  end

  local ctx   = ImGui.CreateContext(title)
  local fonts = load_fonts(ctx, cfg.fonts)

  local window = Window.new({
    fullscreen      = opts.fullscreen,
    title           = title,
    version         = version,
    title_font      = fonts.title,
    title_font_size = fonts.title_size,
    version_font    = fonts.titlebar_version or fonts.version,
    version_font_size = fonts.titlebar_version_size or fonts.version_size,
    version_color   = opts.version_color,
    settings        = settings and settings:sub('ui') or nil,
    initial_pos     = opts.initial_pos  or cfg.window.initial_pos,
    initial_size    = opts.initial_size or cfg.window.initial_size,
    min_size        = opts.min_size     or cfg.window.min_size,
    show_status_bar = opts.show_status_bar,
    show_titlebar   = opts.show_titlebar,
    show_icon       = show_icon,
    get_status_func = opts.get_status_func,
    status_bar_height = DEFAULTS.status_bar and DEFAULTS.status_bar.height or 28,
    content_padding = opts.content_padding or cfg.window.content_padding,
    titlebar_pad_h  = opts.titlebar_pad_h,
    titlebar_pad_v  = opts.titlebar_pad_v,
    flags           = opts.flags,
    style           = style,
    tabs            = opts.tabs,
    bg_color_floating = opts.bg_color_floating,
    bg_color_docked   = opts.bg_color_docked,
  })
    
  
  if opts.overlay then
    window.overlay = opts.overlay
  end

  local state = {
    window   = window,
    settings = settings,
    fonts    = fonts,
    style    = style,
    overlay  = opts.overlay,
    profiling = {
      enabled = enable_profiling,
      frame_start = 0,
      draw_time = 0,
      total_time = 0,
    }
  }

  local function draw_with_profiling(ctx, state)
    if enable_profiling and window.start_timer then
      window:start_timer("draw")
    end
    
    local result = draw_fn(ctx, state)
    
    if enable_profiling and window.end_timer then
      state.profiling.draw_time = window:end_timer("draw")
    end
    
    return result
  end

  local runtime = Runtime.new({
    title = title,
    ctx   = ctx,

    on_frame = function(ctx)
      if enable_profiling then
        state.profiling.frame_start = reaper.time_precise()
      end
      
      if style and style.PushMyStyle then 
        if enable_profiling and window.start_timer then
          window:start_timer("style_push")
        end
        style.PushMyStyle(ctx)
        if enable_profiling and window.end_timer then
          window:end_timer("style_push")
        end
      end

      ImGui.PushFont(ctx, fonts.default, fonts.default_size)

      local visible, open = window:Begin(ctx)
      if visible then
        if raw_content then
          draw_with_profiling(ctx, state)
        else
          if window:BeginBody(ctx) then
            draw_with_profiling(ctx, state)
            window:EndBody(ctx)
          end
        end
      end
      window:End(ctx)

      ImGui.PopFont(ctx)
      
      if style and style.PopMyStyle then 
        if enable_profiling and window.start_timer then
          window:start_timer("style_pop")
        end
        style.PopMyStyle(ctx)
        if enable_profiling and window.end_timer then
          window:end_timer("style_pop")
        end
      end

      if settings and settings.maybe_flush then 
        if enable_profiling and window.start_timer then
          window:start_timer("settings_flush")
        end
        settings:maybe_flush()
        if enable_profiling and window.end_timer then
          window:end_timer("settings_flush")
        end
      end
      
      if enable_profiling then
        state.profiling.total_time = (reaper.time_precise() - state.profiling.frame_start) * 1000
        if window.profiling then
          window.profiling.custom_timers["total_frame"] = state.profiling.total_time
        end
      end
      
      return open ~= false
    end,

    on_destroy = function()
      if settings and settings.flush then settings:flush() end
      if opts.on_close then opts.on_close() end
    end,
  })

  state.start_timer = function(name)
    if window.start_timer then
      window:start_timer(name)
    end
  end
  
  state.end_timer = function(name)
    if window.end_timer then
      return window:end_timer(name)
    end
    return 0
  end
  
  state.toggle_profiling = function()
    if window.toggle_profiling then
      window:toggle_profiling()
    end
  end
  
  state.get_profiling_data = function()
    if window.profiling then
      return window.profiling
    end
    return nil
  end

  runtime:start()
  return runtime
end

return M

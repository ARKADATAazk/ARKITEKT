-- @noindex
-- Arkitekt/app/shell.lua
-- MODIFIED: Made font loading robust against older configuration files.
-- ADDED: Support for titlebar_version size override (uses regular font family)
-- ADDED: Integrated Lua profiler support via global config flag
-- ADDED: Support for show_icon option to disable titlebar icon
-- UPDATED: ImGui 0.10 font size handling

local ImGui   = require('arkitekt.platform.imgui')
local Config = require('arkitekt.core.config')
local Constants = require('arkitekt.defs.app')
local Typography = require('arkitekt.defs.typography')
local Fonts = require('arkitekt.app.chrome.fonts')
local Window  = require('arkitekt.app.chrome.window')
local Logger = require('arkitekt.debug.logger')
local Base = require('arkitekt.gui.widgets.base')

local M = {}

-- ============================================================================
-- ERROR HANDLING: Wrap reaper.defer with xpcall for full stack traces
-- Logs to both Logger (debug console) and REAPER console (immediate visibility)
-- ============================================================================
do
  local original_defer = reaper.defer
  reaper.defer = function(func)
    return original_defer(function()
      xpcall(func, function(err)
        local error_msg = tostring(err)
        local stack = debug.traceback()
        -- Log to debug console
        Logger.error('SYSTEM', '%s\n%s', error_msg, stack)
        -- Also output to REAPER console for immediate visibility
        reaper.ShowConsoleMsg('ERROR: ' .. error_msg .. '\n\n' .. stack .. '\n')
      end)
    end)
  end
end

-- Helper to set REAPER toolbar button state
local function set_button_state(set)
  local _, _, sec, cmd = reaper.get_action_context()
  reaper.SetToggleCommandState(sec, cmd, set or 0)
  reaper.RefreshToolbar2(sec, cmd)
end

-- Auto-create settings from app_name
local function auto_init_settings(app_name)
  if not app_name then return nil end

  local ok, Settings = pcall(require, 'arkitekt.core.settings')
  if not ok or type(Settings.new) ~= 'function' then return nil end

  -- Get data directory (ARK global should be available from bootstrap)
  local data_dir
  if ARK and ARK.get_data_dir then
    data_dir = ARK.get_data_dir(app_name)
  else
    -- Fallback: use REAPER resource path
    data_dir = reaper.GetResourcePath() .. '/Scripts/ARKITEKT/data/' .. app_name
  end

  local success, settings = pcall(Settings.new, data_dir, 'settings.json')
  return success and settings or nil
end

local function load_fonts(ctx, font_cfg)
  font_cfg = Config.deepMerge({
    default        = Typography.SIZE.md,
    title          = Typography.SIZE.md,
    version        = Typography.SIZE.sm,
    titlebar_version = Typography.SIZE.xs,
    monospace      = Typography.SEMANTIC.code,
    time_display   = nil,
    icons          = nil,
    family_regular = Typography.FAMILY.regular,
    family_bold    = Typography.FAMILY.bold,
    family_mono    = Typography.FAMILY.mono,
    family_icons   = 'remixicon.ttf',
  }, font_cfg or {})

  -- Use shared font directory lookup
  local fontsdir = Fonts.find_fonts_dir()

  local R = fontsdir .. font_cfg.family_regular
  local B = fontsdir .. font_cfg.family_bold
  local M = fontsdir .. font_cfg.family_mono
  local I = fontsdir .. font_cfg.family_icons
  local O = fontsdir .. 'Orbitron-Bold.ttf'  -- Orbitron for branding

  local function exists(p) local f = io.open(p, 'rb'); if f then f:close(); return true end end

  -- Track attached fonts to avoid double-attaching when fonts fallback to same object
  local attached = {}
  local function attach_once(font)
    if font and not attached[font] then
      ImGui.Attach(ctx, font)
      attached[font] = true
    end
  end

  -- Use configured fonts from Typography (now DejaVu Sans)
  local default_font   = exists(R) and ImGui.CreateFontFromFile(R, 0, 0) or ImGui.CreateFont('sans-serif', 0)
  local title_font     = exists(R) and ImGui.CreateFontFromFile(R, 0, 0) or ImGui.CreateFont('sans-serif', 0)  -- Use regular, not bold
  local version_font   = exists(R) and ImGui.CreateFontFromFile(R, 0, 0) or ImGui.CreateFont('sans-serif', 0)

  -- Keep loading specific fonts from TTF files
  local monospace_font = exists(M) and ImGui.CreateFontFromFile(M, 0, 0)
                                or default_font

  -- Load Orbitron for branding text
  local orbitron_size = font_cfg.orbitron or Constants.TITLEBAR.branding_font_size
  local orbitron_font = exists(O) and ImGui.CreateFontFromFile(O, 0, 0) or nil

  local time_display_font = nil
  if font_cfg.time_display then
    time_display_font = exists(R) and ImGui.CreateFontFromFile(R, 0, 0) or ImGui.CreateFont('sans-serif', 0)
    attach_once(time_display_font)
  end

  local titlebar_version_font = nil
  local titlebar_version_size = font_cfg.titlebar_version or font_cfg.version
  if font_cfg.titlebar_version then
    titlebar_version_font = exists(R) and ImGui.CreateFontFromFile(R, 0, 0) or ImGui.CreateFont('sans-serif', 0)
    attach_once(titlebar_version_font)
  end

  local icons_font = nil
  if font_cfg.icons then
    icons_font = exists(I) and ImGui.CreateFontFromFile(I, 0, 0) or default_font
    attach_once(icons_font)
  end

  attach_once(default_font)
  attach_once(title_font)
  attach_once(version_font)
  attach_once(monospace_font)
  attach_once(orbitron_font)

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
    orbitron = orbitron_font,
    orbitron_size = orbitron_size,
  }
end

-- ============================================================================
-- OVERLAY MODE RUNNER
-- ============================================================================
-- Simplified overlay setup - handles OverlayManager automatically
local function run_overlay_mode(config)
  -- ============================================================================
  -- PROFILER INITIALIZATION (debug mode from DevKit)
  -- ============================================================================
  local profiler_enabled = false
  do
    local ok, ProfilerInit = pcall(require, 'arkitekt.debug.profiler_init')
    if ok and ProfilerInit then
      profiler_enabled = ProfilerInit.init()
      if profiler_enabled then
        ProfilerInit.attach_world()
        ProfilerInit.launch_window()
      end
    end
  end

  -- Check launch args for debug mode (metrics window)
  local show_metrics = false
  do
    local ark_ok, Ark = pcall(require, 'arkitekt')
    if ark_ok and Ark and Ark.launch_args and Ark.launch_args.debug then
      show_metrics = true
    end
  end

  local title = config.title or 'ARKITEKT Overlay'
  local draw_fn = config.draw or function(ctx) ImGui.Text(ctx, 'No draw function provided') end

  -- Handle toolbar button state
  local toggle_button = config.toggle_button
  if toggle_button then
    set_button_state(1)
  end

  -- Create ImGui context
  local ctx = ImGui.CreateContext(title)

  -- Load fonts
  local fonts = load_fonts(ctx, config.fonts or config.font_sizes)

  -- Load style
  local style = config.style
  if not style then
    local ok, default_style = pcall(require, 'arkitekt.gui.style.imgui')
    if ok then style = default_style end
  end

  -- ============================================================================
  -- THEME INITIALIZATION (same as window mode)
  -- ============================================================================
  -- Initialize theme on overlay startup to ensure Theme.COLORS is properly set.
  -- This enables overlays (ItemPicker, Template Browser, etc.) to respect the
  -- persisted theme preference from the titlebar context menu.
  local reaper_theme_sync, cross_app_theme_sync
  do
    local ok, ThemeManager = pcall(require, 'arkitekt.core.theme_manager')
    if ok and ThemeManager and ThemeManager.init then
      ThemeManager.init('adapt', config.app_name)

      -- Create live sync functions (polled in main loop)
      if ThemeManager.create_live_sync then
        reaper_theme_sync = ThemeManager.create_live_sync(1.0)  -- Poll REAPER theme every 1s
      end
      if ThemeManager.create_cross_app_sync then
        cross_app_theme_sync = ThemeManager.create_cross_app_sync(2.0, config.app_name)  -- Poll other apps every 2s
      end
    end
  end

  -- Load OverlayManager and OverlayDefaults
  local OverlayManager = require('arkitekt.gui.widgets.overlays.overlay.manager')
  local OverlayDefaults = require('arkitekt.gui.widgets.overlays.overlay.defaults')

  -- Create overlay manager
  local overlay_mgr = OverlayManager.new()

  -- Get overlay config (or use defaults)
  local overlay_cfg = config.overlay or {}

  -- Push overlay with framework defaults
  overlay_mgr:push(OverlayDefaults.create_overlay_config({
    id = overlay_cfg.id or (config.app_name or 'app') .. '_overlay',

    -- Close behavior
    esc_to_close = overlay_cfg.esc_to_close,
    close_on_scrim = overlay_cfg.close_on_scrim,
    close_on_background_click = overlay_cfg.close_on_background_click,
    close_on_background_right_click = overlay_cfg.close_on_background_right_click,
    show_close_button = overlay_cfg.show_close_button,

    -- Appearance
    scrim_opacity = overlay_cfg.scrim_opacity,
    scrim_color = overlay_cfg.scrim_color,
    fade_duration = overlay_cfg.fade_duration,

    -- Passthrough callback (for drag-to-REAPER, etc.)
    should_passthrough = overlay_cfg.should_passthrough,

    -- Render callback
    render = function(ctx, alpha_val, bounds)
      -- Push style if provided
      if style and style.PushMyStyle then
        style.PushMyStyle(ctx, { window_bg = false, modal_dim_bg = false })
      end

      -- Push default font
      ImGui.PushFont(ctx, fonts.default, fonts.default_size)

      -- Create overlay state for draw function
      local state = {
        fonts = fonts,
        style = style,
        overlay = {
          x = bounds.x,
          y = bounds.y,
          width = bounds.w,
          height = bounds.h,
          alpha = alpha_val,
          bounds = bounds,
        },
      }

      -- Call user's draw function
      draw_fn(ctx, state)

      ImGui.PopFont(ctx)

      if style and style.PopMyStyle then
        style.PopMyStyle(ctx)
      end
    end,

    -- Cleanup callback
    on_close = config.on_close,
  }))

  -- Use run_loop for overlay rendering
  M.run_loop({
    ctx = ctx,
    on_frame = function(ctx)
      overlay_mgr:render(ctx)

      -- Show metrics window if debug mode enabled
      if show_metrics and ImGui.ShowMetricsWindow then
        show_metrics = ImGui.ShowMetricsWindow(ctx, true)
      end

      return overlay_mgr:is_active()
    end,
    on_close = function()
      if toggle_button then
        set_button_state(0)
      end
      if config.on_close then
        config.on_close()
      end
    end,
    -- Pass theme sync functions
    reaper_theme_sync = reaper_theme_sync,
    cross_app_theme_sync = cross_app_theme_sync,
  })
end

function M.run(opts)
  -- Merge user opts with framework defaults
  local config = Config.deepMerge(Constants.WINDOW, opts or {})

  -- ============================================================================
  -- OVERLAY MODE: Branch to dedicated overlay setup
  -- ============================================================================
  -- Overlay mode uses OverlayManager for fullscreen, scrim, and proper multi-monitor support.
  -- This must be checked BEFORE applying imgui_flags presets.
  if config.mode == 'overlay' then
    return run_overlay_mode(config)
  end

  -- ============================================================================
  -- MODE-BASED PRESETS: Apply ImGui flags and chrome configuration
  -- ============================================================================
  -- If mode is specified (hud, window), apply the corresponding presets (unless explicitly overridden)
  if config.mode and (config.mode == 'hud' or config.mode == 'window') then
    -- Apply ImGui flags preset if not already specified
    if not opts.imgui_flags and not opts.flags then
      config.imgui_flags = config.mode
    end

    -- Apply chrome preset if not already specified
    if not opts.chrome then
      config.chrome = config.mode
    end
  end

  -- ============================================================================
  -- PROFILER INITIALIZATION (debug mode from DevKit)
  -- ============================================================================
  -- Check if launched with debug flag and initialize profiler if so
  -- This must happen BEFORE any defer loops or module loads
  local profiler_enabled = false
  do
    local ok, ProfilerInit = pcall(require, 'arkitekt.debug.profiler_init')
    if ok and ProfilerInit then
      profiler_enabled = ProfilerInit.init()
      if profiler_enabled then
        ProfilerInit.attach_world()
        ProfilerInit.launch_window()
      end
    end
  end

  -- ============================================================================
  -- WINDOW MODE: Standard window with chrome
  -- ============================================================================
  local title    = config.title
  local version  = config.version
  local draw_fn  = config.draw or function(ctx) ImGui.Text(ctx, 'No draw function provided') end

  -- Auto-load default style if none provided
  local style = config.style
  if not style then
    local ok, default_style = pcall(require, 'arkitekt.gui.style.imgui')
    if ok then style = default_style end
  end

  -- Auto-init settings from app_name if not provided
  local settings = config.settings
  if not settings and config.app_name then
    settings = auto_init_settings(config.app_name)
  end

  -- ============================================================================
  -- THEME INITIALIZATION
  -- ============================================================================
  -- Initialize theme on app startup to ensure Theme.COLORS is properly set
  -- before any UI renders. This prevents the 'dark defaults on light theme' bug.
  -- Theme preferences are persisted via REAPER ExtState and restored automatically.
  local reaper_theme_sync, cross_app_theme_sync
  do
    local ok, ThemeManager = pcall(require, 'arkitekt.core.theme_manager')
    if ok and ThemeManager and ThemeManager.init then
      -- init() loads saved preference or defaults to 'adapt' mode
      ThemeManager.init('adapt', config.app_name)

      -- Create live sync functions (polled in main loop)
      if ThemeManager.create_live_sync then
        reaper_theme_sync = ThemeManager.create_live_sync(1.0)  -- Poll REAPER theme every 1s
      end
      if ThemeManager.create_cross_app_sync then
        cross_app_theme_sync = ThemeManager.create_cross_app_sync(2.0, config.app_name)  -- Poll other apps every 2s
      end
    end
  end

  -- Handle toolbar button state
  local toggle_button = config.toggle_button
  if toggle_button then
    set_button_state(1)
  end
  local raw_content = (config.raw_content == true)
  local enable_profiling = config.enable_profiling ~= false

  local show_icon = config.window and config.window.show_icon
  if show_icon == nil then
    show_icon = config.show_icon
  end

  -- Check launch args for debug mode (metrics window)
  local show_metrics = false
  do
    local ark_ok, Ark = pcall(require, 'arkitekt')
    if ark_ok and Ark and Ark.launch_args and Ark.launch_args.debug then
      show_metrics = true
    end
  end

  local ctx   = ImGui.CreateContext(title)
  local fonts = load_fonts(ctx, config.fonts or config.font_sizes)

  local window = Window.new({
    fullscreen      = config.fullscreen,
    title           = title,
    version         = version,
    title_font      = fonts.title,
    title_font_size = fonts.title_size,
    version_font    = fonts.titlebar_version or fonts.version,
    version_font_size = fonts.titlebar_version_size or fonts.version_size,
    version_color   = config.version_color,
    branding_font   = fonts.orbitron,  -- Pass custom font for branding text
    branding_font_size = fonts.orbitron_size,
    branding_text   = Constants.TITLEBAR.branding_text,
    branding_opacity = Constants.TITLEBAR.branding_opacity,
    branding_color  = Constants.TITLEBAR.branding_color,
    settings        = settings and settings:sub('ui') or nil,
    initial_pos     = config.initial_pos,
    initial_size    = config.initial_size,
    min_size        = config.min_size,
    app_name        = config.app_name,  -- Pass app name for per-app theme overrides

    -- Chrome configuration (new)
    chrome          = config.chrome,
    imgui_flags     = config.imgui_flags,

    -- LEGACY_COMPAT: Remove in v2.0 - Use chrome/imgui_flags instead
    show_status_bar = config.show_status_bar,
    show_statusbar  = config.show_statusbar,
    show_titlebar   = config.show_titlebar,
    show_icon       = show_icon,
    show_version    = config.show_version,
    enable_maximize = config.enable_maximize,

    get_status_func = config.get_status_func,
    status_bar_height = Constants.STATUS_BAR.height,
    content_padding = config.content_padding,
    titlebar_pad_h  = config.titlebar_pad_h,
    titlebar_pad_v  = config.titlebar_pad_v,
    flags           = config.flags,  -- LEGACY_COMPAT: Use imgui_flags
    style           = style,
    tabs            = config.tabs,
    bg_color_floating = config.bg_color_floating,
    bg_color_docked   = config.bg_color_docked,
    topmost         = config.topmost,

    -- Debug mode: show ImGui metrics window
    show_imgui_metrics = show_metrics,
  })


  if config.overlay then
    window.overlay = config.overlay
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
      window:start_timer('draw')
    end

    local result = draw_fn(ctx, state)

    if enable_profiling and window.end_timer then
      state.profiling.draw_time = window:end_timer('draw')
    end
    
    return result
  end

  -- Inline runtime loop (no separate Runtime module)
  local runtime = {
    ctx = ctx,
    open = true,
  }

  local function on_frame()
    if enable_profiling then
      state.profiling.frame_start = reaper.time_precise()
    end

    if style and style.PushMyStyle then
      if enable_profiling and window.start_timer then
        window:start_timer('style_push')
      end
      style.PushMyStyle(ctx)
      if enable_profiling and window.end_timer then
        window:end_timer('style_push')
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
        window:start_timer('style_pop')
      end
      style.PopMyStyle(ctx)
      if enable_profiling and window.end_timer then
        window:end_timer('style_pop')
      end
    end

    -- Render theme debug overlay (if enabled via titlebar menu or F12)
    do
      local ok, ThemeManager = pcall(require, 'arkitekt.core.theme_manager')
      if ok and ThemeManager and ThemeManager.render_debug_overlay then
        ThemeManager.render_debug_overlay(ctx, ImGui)
      end
    end

    if settings and settings.maybe_flush then
      if enable_profiling and window.start_timer then
        window:start_timer('settings_flush')
      end
      settings:maybe_flush()
      if enable_profiling and window.end_timer then
        window:end_timer('settings_flush')
      end
    end

    if enable_profiling then
      state.profiling.total_time = (reaper.time_precise() - state.profiling.frame_start) * 1000
      if window.profiling then
        window.profiling.custom_timers['total_frame'] = state.profiling.total_time
      end
    end

    return open ~= false
  end

  local function on_destroy()
    if toggle_button then set_button_state(0) end
    if settings and settings.flush then settings:flush() end
    if opts.on_close then opts.on_close() end
  end

  -- Main defer loop
  local function frame()
    if not runtime.open then
      on_destroy()
      return
    end

    local continue = on_frame()
    if continue == false then
      runtime.open = false
    end

    -- Periodic cleanup (internally throttled)
    Base.periodic_cleanup()
    Logger.prune_stale_live()

    -- Theme live sync (REAPER theme changes + cross-app propagation)
    if reaper_theme_sync then reaper_theme_sync() end
    if cross_app_theme_sync then cross_app_theme_sync() end

    if runtime.open then
      reaper.defer(frame)
    else
      on_destroy()
    end
  end

  function runtime:start()
    reaper.defer(frame)
  end

  function runtime:request_close()
    self.open = false
  end

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

-- Simple defer loop for overlay mode apps
-- opts: {
--   ctx = ImGui context (required),
--   on_frame = function(ctx) -> bool (return false to close),
--   on_close = function() (optional cleanup)
-- }
function M.run_loop(opts)
  opts = opts or {}
  local ctx = opts.ctx
  local on_frame = opts.on_frame or function() return true end
  local on_close = opts.on_close
  local reaper_theme_sync = opts.reaper_theme_sync
  local cross_app_theme_sync = opts.cross_app_theme_sync

  local open = true
  local function frame()
    if not open then
      if on_close then on_close() end
      return
    end

    local continue = on_frame(ctx)
    if continue == false then
      open = false
    end

    -- Periodic cleanup (internally throttled)
    Base.periodic_cleanup()
    Logger.prune_stale_live()

    -- Theme live sync (REAPER theme changes + cross-app propagation)
    if reaper_theme_sync then reaper_theme_sync() end
    if cross_app_theme_sync then cross_app_theme_sync() end

    if open then
      reaper.defer(frame)
    else
      if on_close then on_close() end
    end
  end

  reaper.defer(frame)
end

return M

-- @noindex
-- arkitekt/runtime/shell.lua
-- Application shell runner - main entry point for ARKITEKT apps

local ImGui   = require('arkitekt.core.imgui')
local Config = require('arkitekt.core.merge')
local Constants = require('arkitekt.config.app')
local Typography = require('arkitekt.config.typography')
local Fonts = require('arkitekt.runtime.chrome.fonts')
local Window  = require('arkitekt.runtime.chrome.window')
local Logger = require('arkitekt.debug.logger')
local Base = require('arkitekt.gui.widgets.base')
local Context = require('arkitekt.core.context')

local M = {}

-- ============================================================================
-- DEV MODE: Visual feedback state (module-level for persistence across frames)
-- ============================================================================
local dev_toast = {
  message = nil,
  start_time = 0,
  duration = 1.5,
}
local dev_flash = {
  active = false,
  start_time = 0,
  duration = 0.3,
  color = 0x00FF0040,  -- Green with low alpha
}

local function show_dev_flash(color)
  dev_flash.active = true
  dev_flash.start_time = reaper.time_precise()
  dev_flash.color = color or 0x00FF0040  -- Default: green
end

-- Stored window bounds for flash/toast (updated each frame while window is active)
local dev_window_bounds = { x = 0, y = 0, w = 800, h = 600 }

local function update_dev_window_bounds(ctx)
  local wx, wy = ImGui.GetWindowPos(ctx)
  local ww, wh = ImGui.GetWindowSize(ctx)
  dev_window_bounds.x = wx
  dev_window_bounds.y = wy
  dev_window_bounds.w = ww
  dev_window_bounds.h = wh
end

local function draw_dev_flash(ctx)
  if not dev_flash.active then return end

  local elapsed = reaper.time_precise() - dev_flash.start_time
  if elapsed > dev_flash.duration then
    dev_flash.active = false
    return
  end

  -- Quick fade out
  local alpha = 1.0 - (elapsed / dev_flash.duration)
  alpha = alpha * alpha  -- Ease out

  local base_alpha = (dev_flash.color & 0xFF)
  local final_alpha = math.floor(base_alpha * alpha)
  local flash_color = (dev_flash.color & 0xFFFFFF00) | final_alpha

  -- Full window overlay using stored bounds
  local dl = ImGui.GetForegroundDrawList(ctx)
  ImGui.DrawList_AddRectFilled(dl,
    dev_window_bounds.x, dev_window_bounds.y,
    dev_window_bounds.x + dev_window_bounds.w,
    dev_window_bounds.y + dev_window_bounds.h,
    flash_color)
end

local function show_dev_toast(message)
  dev_toast.message = message
  dev_toast.start_time = reaper.time_precise()
end

local function draw_dev_toast(ctx)
  if not dev_toast.message then return end

  local elapsed = reaper.time_precise() - dev_toast.start_time
  if elapsed > dev_toast.duration then
    dev_toast.message = nil
    return
  end

  -- Fade out in last 0.3 seconds
  local alpha = 1.0
  local fade_start = dev_toast.duration - 0.3
  if elapsed > fade_start then
    alpha = 1.0 - (elapsed - fade_start) / 0.3
  end

  -- Draw at top center of window using stored bounds
  local text_w = ImGui.CalcTextSize(ctx, dev_toast.message)
  local x = dev_window_bounds.x + (dev_window_bounds.w - text_w) / 2
  local y = dev_window_bounds.y + 50

  local dl = ImGui.GetForegroundDrawList(ctx)
  local bg_color = 0x000000CC  -- Semi-transparent black
  local text_color = 0x00FF00FF  -- Bright green for visibility
  text_color = (text_color & 0xFFFFFF00) | math.floor(alpha * 255)
  bg_color = (bg_color & 0xFFFFFF00) | math.floor(0xCC * alpha)

  -- Background pill
  ImGui.DrawList_AddRectFilled(dl, x - 12, y - 6, x + text_w + 12, y + 22, bg_color, 6)
  -- Text
  ImGui.DrawList_AddText(dl, x, y, text_color, dev_toast.message)
end

-- Export for potential future use
M._show_dev_toast = show_dev_toast
M._show_dev_flash = show_dev_flash

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
    local ok, ThemeManager = pcall(require, 'arkitekt.theme.manager')
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

      -- Set fonts in ArkContext (widgets can access via actx:font('icons'))
      Context.get(ctx):set_fonts(fonts)

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

      -- Call user's draw function (return false to close)
      local keep_open = draw_fn(ctx, state)

      ImGui.PopFont(ctx)

      if style and style.PopMyStyle then
        style.PopMyStyle(ctx)
      end

      -- If draw function returns false, close the overlay
      if keep_open == false then
        overlay_mgr:pop()
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
  -- ============================================================================
  -- COMPONENT MODE: Return drawable handle instead of running defer loop
  -- ============================================================================
  -- When hosted by Blocks (or another container), components detect this via
  -- the global flag and return a drawable handle instead of running their own
  -- defer loop. The host manages the single defer loop for all components.
  if _G.ARKITEKT_BLOCKS_HOST then
    local config = Config.deepMerge(Constants.WINDOW, opts or {})
    local draw_fn = config.draw or function(ctx) ImGui.Text(ctx, 'No draw function') end

    -- Return component handle for host to call
    return {
      -- Draw the component (called each frame by host)
      draw = function(ctx, shell_state)
        draw_fn(ctx, shell_state or {})
      end,

      -- Component metadata
      title = config.title or 'Component',
      version = config.version,

      -- Optional lifecycle hooks
      on_close = opts and opts.on_close,
    }
  end

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
  -- DEV MODE: Configuration
  -- ============================================================================
  local Dev = require('arkitekt.debug.dev')
  local dev_mode = config.dev_mode or false
  Dev.enabled = dev_mode  -- Sync to shared module

  -- ============================================================================
  -- WINDOW MODE: Standard window with chrome
  -- ============================================================================
  -- Keep window title stable for ImGui (don't include [DEV] badge)
  -- The titlebar handles the [DEV] prefix display separately
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
    local ok, ThemeManager = pcall(require, 'arkitekt.theme.manager')
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

    -- Chrome configuration
    chrome          = config.chrome,
    imgui_flags     = config.imgui_flags,

    get_status_func = config.get_status_func,
    status_bar_height = Constants.STATUS_BAR.height,
    content_padding = config.content_padding,
    titlebar_pad_h  = config.titlebar_pad_h,
    titlebar_pad_v  = config.titlebar_pad_v,
    style           = style,
    tabs            = config.tabs,
    bg_color_floating = config.bg_color_floating,
    bg_color_docked   = config.bg_color_docked,
    topmost         = config.topmost,

    -- Titlebar-only dragging
    titlebar_drag_only = config.titlebar_drag_only,

    -- Debug mode: show ImGui metrics window
    show_imgui_metrics = show_metrics,

    -- Dev mode
    dev_mode        = dev_mode,
  })


  if config.overlay then
    window.overlay = config.overlay
  end

  -- Set initial [DEV] badge on titlebar if dev_mode is enabled at startup
  if dev_mode and window._titlebar then
    window._titlebar:set_title('[DEV] ' .. config.title)
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

    -- Set fonts in ArkContext (widgets can access via actx:font('icons'))
    Context.get(ctx):set_fonts(fonts)

    ImGui.PushFont(ctx, fonts.default, fonts.default_size)

    local visible, open = window:Begin(ctx)
    if visible then
      -- Store window bounds for dev mode overlays (flash/toast)
      update_dev_window_bounds(ctx)

      -- ======================================================================
      -- DEV MODE: Keyboard shortcuts (must be after window:Begin for focus)
      -- ======================================================================
      -- Toggle dev mode: Ctrl+Shift+Alt+D
      do
        local ctrl = ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl)
        local shift = ImGui.IsKeyDown(ctx, ImGui.Mod_Shift)
        local alt = ImGui.IsKeyDown(ctx, ImGui.Mod_Alt)
        local d_pressed = ImGui.IsKeyPressed(ctx, ImGui.Key_D, false)

        if ctrl and shift and alt and d_pressed then
          dev_mode = not dev_mode
          Dev.enabled = dev_mode  -- Sync to shared module
          -- Update titlebar display only (not window title for ImGui stability)
          if window._titlebar then
            window._titlebar:set_title(dev_mode and ('[DEV] ' .. config.title) or config.title)
            window._titlebar.dev_mode = dev_mode
          end
          show_dev_toast(dev_mode and 'Dev Mode: ON' or 'Dev Mode: OFF')
          Logger.info('DEV', 'Dev mode %s', dev_mode and 'enabled' or 'disabled')
        end
      end

      if raw_content then
        draw_with_profiling(ctx, state)
      else
        if window:BeginBody(ctx) then
          draw_with_profiling(ctx, state)
        end
        window:EndBody(ctx)
      end

      -- Draw dev mode overlays while window is active
      draw_dev_flash(ctx)
      draw_dev_toast(ctx)
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
      local ok, ThemeManager = pcall(require, 'arkitekt.theme.manager')
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

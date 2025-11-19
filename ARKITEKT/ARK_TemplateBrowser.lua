-- @noindex
-- TemplateBrowser main launcher with overlay support
-- Three-panel UI: Folders | Templates | Tags

-- ============================================================================
-- BOOTSTRAP ARKITEKT FRAMEWORK
-- ============================================================================
local function init_arkitekt()
  local sep = package.config:sub(1,1)
  local src = debug.getinfo(1, "S").source:sub(2)
  local dir = src:match("(.*"..sep..")")

  -- Scan upward for bootstrap
  local path = dir
  while path and #path > 3 do
    local bootstrap = path .. "rearkitekt" .. sep .. "app" .. sep .. "bootstrap.lua"
    local f = io.open(bootstrap, "r")
    if f then
      f:close()
      return dofile(bootstrap)(path)
    end
    path = path:match("(.*"..sep..")[^"..sep.."]-"..sep.."$")
  end

  reaper.MB("ARKITEKT bootstrap not found!", "FATAL ERROR", 0)
  return nil
end

local ARK = init_arkitekt()
if not ARK then return end

-- Load required modules
local ImGui = ARK.ImGui
local Runtime = require('rearkitekt.app.runtime')
local OverlayManager = require('rearkitekt.gui.widgets.overlays.overlay.manager')
local ImGuiStyle = require('rearkitekt.gui.style.imgui_defaults')

-- Load TemplateBrowser modules
local Config = require('TemplateBrowser.core.config')
local State = require('TemplateBrowser.core.state')
local GUI = require('TemplateBrowser.ui.gui')
local Scanner = require('TemplateBrowser.domain.scanner')

-- Configuration
local USE_OVERLAY = true  -- Set to false for normal window mode

local function SetButtonState(set)
  local is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
  reaper.SetToggleCommandState(sec, cmd, set or 0)
  reaper.RefreshToolbar2(sec, cmd)
end

-- Initialize state
State.initialize(Config)

-- Initialize scanner and load templates
Scanner.scan_templates(State)

-- Create GUI
local gui = GUI.new(Config, State, Scanner)

local function cleanup()
  SetButtonState()
  State.cleanup()
end

SetButtonState(1)

-- Font loading
local function load_fonts(ctx)
  local SEP = package.config:sub(1,1)
  local src = debug.getinfo(1, 'S').source:sub(2)
  local this_dir = src:match('(.*'..SEP..')') or ('.'..SEP)
  local parent = this_dir:match('^(.*'..SEP..')[^'..SEP..']*'..SEP..'$') or this_dir
  local fontsdir = parent .. 'rearkitekt' .. SEP .. 'fonts' .. SEP

  local regular = fontsdir .. 'Inter_18pt-Regular.ttf'
  local bold = fontsdir .. 'Inter_18pt-SemiBold.ttf'
  local mono = fontsdir .. 'JetBrainsMono-Regular.ttf'

  local function exists(p)
    local f = io.open(p, 'rb')
    if f then f:close(); return true end
  end

  local fonts = {
    default = exists(regular) and ImGui.CreateFont(regular, 14) or ImGui.CreateFont('sans-serif', 14),
    default_size = 14,
    title = exists(bold) and ImGui.CreateFont(bold, 20) or ImGui.CreateFont('sans-serif', 20),
    title_size = 20,
    monospace = exists(mono) and ImGui.CreateFont(mono, 12) or ImGui.CreateFont('sans-serif', 12),
    monospace_size = 12,
  }

  for _, font in pairs(fonts) do
    if font and type(font) ~= "number" then
      ImGui.Attach(ctx, font)
    end
  end

  return fonts
end

-- Run based on mode
if USE_OVERLAY then
  -- OVERLAY MODE
  local ctx = ImGui.CreateContext("Template Browser")
  local fonts = load_fonts(ctx)

  -- Create overlay manager
  local overlay_mgr = OverlayManager.new()

  -- Push overlay onto stack
  local Colors = require('rearkitekt.core.colors')
  overlay_mgr:push({
    id = "template_browser_main",
    use_viewport = true,
    fade_duration = 0.25,
    fade_curve = 'ease_out_quad',
    show_close_button = true,
    close_on_background_click = false,
    close_on_background_right_click = true,
    close_on_scrim = false,
    esc_to_close = true,
    close_button_size = 28,
    close_button_margin = 16,
    close_button_proximity = 140,
    content_padding = 30,

    render = function(ctx, alpha_val, bounds)
      ImGuiStyle.PushMyStyle(ctx, { window_bg = false, modal_dim_bg = false })
      ImGui.PushFont(ctx, fonts.default, fonts.default_size)

      local overlay_state = {
        x = bounds.x,
        y = bounds.y,
        width = bounds.w,
        height = bounds.h,
        alpha = alpha_val,
      }

      if gui and gui.draw then
        gui:draw(ctx, {
          fonts = fonts,
          overlay_state = overlay_state,
          overlay = { alpha = { value = function() return alpha_val end } },
          is_overlay_mode = true,
        })
      end

      ImGui.PopFont(ctx)
      ImGuiStyle.PopMyStyle(ctx)
    end,

    on_close = function()
      cleanup()
    end,
  })

  -- Create runtime
  local runtime = Runtime.new({
    title = "Template Browser",
    ctx = ctx,

    on_frame = function(ctx)
      overlay_mgr:render(ctx)
      return overlay_mgr:is_active()
    end,

    on_destroy = function()
      cleanup()
    end,
  })

  runtime:start()

else
  -- NORMAL WINDOW MODE
  local Shell = require('rearkitekt.app.shell')

  Shell.run({
    title = "Template Browser",
    version = "1.0.0",

    show_titlebar = true,
    show_status_bar = false,

    initial_size = { w = 1400, h = 800 },
    min_size = { w = 1000, h = 600 },

    fonts = {
      default = 14,
      title = 20,
      monospace = 12,
    },

    draw = function(ctx, shell_state)
      gui:draw(ctx, shell_state)
    end,

    on_close = function()
      cleanup()
    end,
  })
end

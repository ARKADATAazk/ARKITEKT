-- @noindex
-- Centralized font loading for ARKITEKT applications
-- Eliminates duplication of font loading logic across entry points

local Constants = require('rearkitekt.app.init.constants'))

local M = {}

-- Helper to check if file exists
local function file_exists(path)
  local f = io.open(path, 'rb')
  if f then
    f:close()
    return true
  end
  return false
end

-- Find fonts directory relative to any entry point
local function find_fonts_dir()
  local sep = package.config:sub(1,1)
  local src = debug.getinfo(2, 'S').source:sub(2)
  local this_dir = src:match('(.*'..sep..')') or ('.'..sep)
  local parent = this_dir:match('^(.*'..sep..')[^'..sep..']*'..sep..'$') or this_dir
  return parent .. 'rearkitekt' .. sep .. 'fonts' .. sep
end

---Load standard ARKITEKT fonts and attach to ImGui context
---@param ImGui table ReaImGui module
---@param ctx userdata ImGui context to attach fonts to
---@param opts? table Optional size overrides: { default_size, title_size, monospace_size }
---@return table fonts Table with font objects and their sizes
function M.load(ImGui, ctx, opts)
  opts = opts or {}

  -- Use constants for default sizes, allow overrides
  local default_size = opts.default_size or Constants.TYPOGRAPHY.BODY
  local title_size = opts.title_size or Constants.TYPOGRAPHY.HEADING
  local monospace_size = opts.monospace_size or Constants.TYPOGRAPHY.CODE

  -- Find fonts directory
  local fonts_dir = find_fonts_dir()
  local regular = fonts_dir .. 'Inter_18pt-Regular.ttf'
  local bold = fonts_dir .. 'Inter_18pt-SemiBold.ttf'
  local mono = fonts_dir .. 'JetBrainsMono-Regular.ttf'

  -- Create fonts with fallback to sans-serif
  local fonts = {
    default = file_exists(regular) and ImGui.CreateFont(regular, default_size) or ImGui.CreateFont('sans-serif', default_size),
    default_size = default_size,

    title = file_exists(bold) and ImGui.CreateFont(bold, title_size) or ImGui.CreateFont('sans-serif', title_size),
    title_size = title_size,

    monospace = file_exists(mono) and ImGui.CreateFont(mono, monospace_size) or ImGui.CreateFont('sans-serif', monospace_size),
    monospace_size = monospace_size,
  }

  -- Attach all font objects to context
  for _, font in pairs(fonts) do
    if font and type(font) ~= "number" then
      ImGui.Attach(ctx, font)
    end
  end

  return fonts
end

return M

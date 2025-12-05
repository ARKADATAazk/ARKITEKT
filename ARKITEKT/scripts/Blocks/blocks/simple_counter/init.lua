-- @noindex
-- Blocks/blocks/simple_counter/init.lua
-- Simple counter component for testing component mode pattern
--
-- This component can run:
-- 1. STANDALONE: Run this file directly in REAPER (runs its own defer loop)
-- 2. HOSTED: Loaded by Blocks (returns drawable handle, no defer)

local M = {}

-- Component state (persists across frames)
local state = {
  count = 0,
  initialized = false,
}

-- Lazy load dependencies (only when draw is called)
local ImGui, Theme

local function ensure_deps()
  if not ImGui then
    local Ark = require('arkitekt')
    ImGui = Ark.ImGui
    Theme = require('arkitekt.theme')
  end
end

---Initialize the component
local function init()
  if state.initialized then return end
  state.count = 0
  state.initialized = true
end

---Draw the component content
---@param ctx userdata ImGui context
local function draw_content(ctx)
  ensure_deps()
  init()

  -- Header
  ImGui.Text(ctx, 'Simple Counter Component')
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Counter display
  ImGui.Text(ctx, 'Count: ' .. state.count)
  ImGui.Spacing(ctx)

  -- Buttons
  if ImGui.Button(ctx, '+1', 60, 30) then
    state.count = state.count + 1
  end

  ImGui.SameLine(ctx)

  if ImGui.Button(ctx, '-1', 60, 30) then
    state.count = state.count - 1
  end

  ImGui.SameLine(ctx)

  if ImGui.Button(ctx, 'Reset', 60, 30) then
    state.count = 0
  end

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)

  -- Show mode info
  local mode = _G.ARKITEKT_BLOCKS_HOST and 'HOSTED' or 'STANDALONE'
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, mode == 'HOSTED' and 0x88FF88FF or 0xFFAA88FF)
  ImGui.Text(ctx, 'Mode: ' .. mode)
  ImGui.PopStyleColor(ctx)

  -- Random value (proves defer loop is working)
  ImGui.Text(ctx, 'Frame ID: ' .. math.random(1000, 9999))
end

---Get component metadata
---@return table Component metadata
function M.get_metadata()
  return {
    name = 'Simple Counter',
    description = 'A simple counter for testing component mode',
    version = '0.1.0',
    author = 'ARKITEKT',
  }
end

-- ============================================================================
-- ENTRY POINT: Use Shell for both standalone and component modes
-- ============================================================================
-- Shell.run() automatically detects if we're hosted (via _G.ARKITEKT_BLOCKS_HOST)
-- and returns a component handle instead of running a defer loop.

local Shell = require('arkitekt.runtime.shell')

return Shell.run({
  title = 'Simple Counter',
  version = 'v0.1.0',

  draw = function(ctx, shell_state)
    draw_content(ctx)
  end,

  on_close = function()
    state.initialized = false
  end,
})

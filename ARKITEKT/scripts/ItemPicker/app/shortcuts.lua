-- @noindex
local ImGui = require 'imgui' '0.10'

local M = {}
local config

function M.init(config_module)
  config = config_module
end

function M.handle_tile_size_shortcuts(ctx, state)
  local wheel = ImGui.GetMouseWheel(ctx)
  if wheel == 0 then return false end
  
  local ctrl = ImGui.IsKeyDown(ctx, ImGui.Key_LeftCtrl) or ImGui.IsKeyDown(ctx, ImGui.Key_RightCtrl)
  local alt = ImGui.IsKeyDown(ctx, ImGui.Key_LeftAlt) or ImGui.IsKeyDown(ctx, ImGui.Key_RightAlt)
  
  if not ctrl and not alt then return false end
  
  if not state.tile_sizes then
    state.tile_sizes = {
      width = config.TILE.DEFAULT_WIDTH,
      height = config.TILE.DEFAULT_HEIGHT,
    }
  end
  
  local delta = wheel > 0 and 1 or -1
  local changed = false
  
  if ctrl then
    local new_height = state.tile_sizes.height + (delta * config.TILE.HEIGHT_STEP)
    new_height = math.max(config.TILE.MIN_HEIGHT, math.min(config.TILE.MAX_HEIGHT, new_height))
    if new_height ~= state.tile_sizes.height then
      state.tile_sizes.height = new_height
      changed = true
    end
  elseif alt then
    local new_width = state.tile_sizes.width + (delta * config.TILE.WIDTH_STEP)
    new_width = math.max(config.TILE.MIN_WIDTH, math.min(config.TILE.MAX_WIDTH, new_width))
    if new_width ~= state.tile_sizes.width then
      state.tile_sizes.width = new_width
      changed = true
    end
  end
  
  if changed then
    if state.midi_grid then
      state.midi_grid.min_col_w_fn = function() return state.tile_sizes.width end
      state.midi_grid.fixed_tile_h = state.tile_sizes.height
    end
    if state.audio_grid then
      state.audio_grid.min_col_w_fn = function() return state.tile_sizes.width end
      state.audio_grid.fixed_tile_h = state.tile_sizes.height
    end
  end
  
  return changed
end

function M.handle_search_shortcuts(ctx, settings)
  local ctrl = ImGui.IsKeyDown(ctx, ImGui.Key_LeftCtrl) or ImGui.IsKeyDown(ctx, ImGui.Key_RightCtrl)
  
  if ctrl and ImGui.IsKeyPressed(ctx, ImGui.Key_F) then
    return true
  end
  
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
    if settings.search_string and settings.search_string ~= "" then
      settings.search_string = ""
      return true
    end
  end
  
  return false
end

function M.get_tile_width(state)
  if not state.tile_sizes then
    return config.TILE.DEFAULT_WIDTH
  end
  return state.tile_sizes.width
end

function M.get_tile_height(state)
  if not state.tile_sizes then
    return config.TILE.DEFAULT_HEIGHT
  end
  return state.tile_sizes.height
end

return M
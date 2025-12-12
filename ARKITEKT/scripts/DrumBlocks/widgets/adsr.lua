-- @noindex
-- DrumBlocks/widgets/adsr.lua
-- Visual ADSR envelope widget with draggable control points
-- Styled with anti-aliasing, glow effects, and smooth gradients

local M = {}

-- DEPENDENCIES
local Ark = require('arkitekt')
local ImGui = Ark.ImGui
local Colors = Ark.Colors

-- Try to load Theme (may not be available)
local Theme_ok, Theme = pcall(require, 'arkitekt.theme')
if not Theme_ok then Theme = { COLORS = {} } end

-- Try to load Base (for result creation)
local Base_ok, Base = pcall(require, 'arkitekt.gui.widgets.base')

-- CONSTANTS
local DEFAULT_WIDTH = 220
local DEFAULT_HEIGHT = 90
local HANDLE_RADIUS = 6
local HANDLE_HIT_RADIUS = 10
local GLOW_PASSES = 3

-- Widget state storage (keyed by widget id)
local widget_states = {}

-- Envelope stage identifiers
M.STAGE = {
  ATTACK = 1,
  DECAY = 2,
  SUSTAIN = 3,
  RELEASE = 4,
}

-- Default colors (can be overridden via opts)
local DEFAULT_COLORS = {
  bg = 0x1A1A1AFF,
  grid = 0x2A2A2A60,
  line = 0x4A9EFFFF,        -- Main envelope line
  line_glow = 0x4A9EFF40,   -- Glow around line
  fill_top = 0x4A9EFF30,    -- Fill gradient top
  fill_bottom = 0x4A9EFF08, -- Fill gradient bottom
  handle = 0xFFFFFFFF,      -- Handle fill
  handle_border = 0x4A9EFFFF, -- Handle border
  handle_active = 0x41E0A3FF, -- Active handle
  handle_glow = 0x4A9EFF60,  -- Handle glow
  label = 0x808080FF,
  border = 0x3A3A3AFF,
}

---Calculate envelope points for drawing
---@param x number Left edge
---@param y number Top edge
---@param w number Width
---@param h number Height
---@param attack number Attack time (0-1 normalized)
---@param decay number Decay time (0-1 normalized)
---@param sustain number Sustain level (0-1)
---@param release number Release time (0-1 normalized)
---@return table points Array of {x, y} points
local function calc_envelope_points(x, y, w, h, attack, decay, sustain, release)
  local pad = 8
  local draw_x = x + pad
  local draw_w = w - pad * 2
  local draw_y = y + pad
  local draw_h = h - pad * 2 - 12  -- Reserve space for labels

  -- ADSR segments: Attack 25%, Decay 25%, Sustain 25%, Release 25%
  local seg_w = draw_w * 0.25

  local attack_x = draw_x + seg_w * math.max(0.02, attack)
  local decay_x = attack_x + seg_w * math.max(0.02, decay)
  local sustain_x = decay_x + seg_w
  local release_x = sustain_x + seg_w * math.max(0.02, release)

  local top_y = draw_y
  local bottom_y = draw_y + draw_h
  local sustain_y = draw_y + draw_h * (1 - sustain)

  return {
    { x = draw_x, y = bottom_y },           -- Start (bottom left)
    { x = attack_x, y = top_y },            -- Attack peak
    { x = decay_x, y = sustain_y },         -- Decay end (sustain level)
    { x = sustain_x, y = sustain_y },       -- Sustain end
    { x = release_x, y = bottom_y },        -- Release end
  }
end

---Check if mouse is near a handle
local function is_near_handle(mx, my, hx, hy)
  local dx = mx - hx
  local dy = my - hy
  return (dx * dx + dy * dy) <= (HANDLE_HIT_RADIUS * HANDLE_HIT_RADIUS)
end

---Draw anti-aliased line with glow effect
local function draw_glow_line(dl, x1, y1, x2, y2, color, glow_color, thickness)
  -- Draw glow passes (larger, more transparent)
  for i = GLOW_PASSES, 1, -1 do
    local glow_thick = thickness + i * 2
    local alpha = 0.15 / i
    local glow = Colors.WithOpacity(glow_color, alpha)
    ImGui.DrawList_AddLine(dl, x1, y1, x2, y2, glow, glow_thick)
  end
  -- Draw main line
  ImGui.DrawList_AddLine(dl, x1, y1, x2, y2, color, thickness)
end

---Draw handle with glow
local function draw_handle(dl, x, y, radius, is_active, is_hovered, colors)
  local fill = is_active and colors.handle_active or colors.handle
  local border = is_active and colors.handle_active or colors.handle_border
  local r = is_active and radius + 2 or (is_hovered and radius + 1 or radius)

  -- Glow
  if is_active or is_hovered then
    for i = 3, 1, -1 do
      local glow_r = r + i * 3
      local alpha = 0.2 / i
      ImGui.DrawList_AddCircleFilled(dl, x, y, glow_r, Colors.WithOpacity(colors.handle_glow, alpha), 16)
    end
  end

  -- Fill
  ImGui.DrawList_AddCircleFilled(dl, x, y, r, fill, 16)
  -- Border
  ImGui.DrawList_AddCircle(dl, x, y, r, border, 16, 2)
end

---Draw the ADSR envelope widget
---@param ctx userdata ImGui context
---@param opts table Options
---@return table result { changed, attack, decay, sustain, release, active_stage }
function M.Draw(ctx, opts)
  opts = opts or {}

  local id = opts.id or 'adsr'
  local width = opts.width or DEFAULT_WIDTH
  local height = opts.height or DEFAULT_HEIGHT

  -- Current values (normalized 0-1)
  local attack = opts.attack or 0.1
  local decay = opts.decay or 0.2
  local sustain = opts.sustain or 0.7
  local release = opts.release or 0.3

  -- Colors (merge with defaults)
  local colors = {}
  for k, v in pairs(DEFAULT_COLORS) do
    colors[k] = opts[k] or v
  end

  -- Use theme accent if available
  if Theme.COLORS.ACCENT_PRIMARY then
    colors.line = opts.line or Theme.COLORS.ACCENT_PRIMARY
    colors.line_glow = opts.line_glow or Colors.WithOpacity(Theme.COLORS.ACCENT_PRIMARY, 0.25)
    colors.fill_top = opts.fill_top or Colors.WithOpacity(Theme.COLORS.ACCENT_PRIMARY, 0.2)
    colors.fill_bottom = opts.fill_bottom or Colors.WithOpacity(Theme.COLORS.ACCENT_PRIMARY, 0.03)
    colors.handle_border = opts.handle_border or Theme.COLORS.ACCENT_PRIMARY
    colors.handle_glow = opts.handle_glow or Colors.WithOpacity(Theme.COLORS.ACCENT_PRIMARY, 0.4)
  end

  -- State tracking
  local state_id = 'adsr_' .. id
  local widget_state = widget_states[state_id] or {}
  widget_states[state_id] = widget_state

  local changed = false
  local active_stage = nil

  -- Get position and create invisible button for interaction
  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.InvisibleButton(ctx, id, width, height)

  local hovered = ImGui.IsItemHovered(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)

  -- Calculate envelope points
  local points = calc_envelope_points(x, y, width, height, attack, decay, sustain, release)

  -- Draw background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + width, y + height, colors.bg, 6)

  -- Draw grid
  local grid_steps = 4
  for i = 1, grid_steps - 1 do
    local gx = x + (width / grid_steps) * i
    ImGui.DrawList_AddLine(dl, gx, y + 8, gx, y + height - 20, colors.grid, 1)
  end
  for i = 1, 3 do
    local gy = y + 8 + ((height - 28) / 4) * i
    ImGui.DrawList_AddLine(dl, x + 8, gy, x + width - 8, gy, colors.grid, 1)
  end

  -- Draw filled area with vertical gradient lines
  if #points >= 2 then
    local bottom_y = points[1].y
    local step = 2
    for i = 1, #points - 1 do
      local p1, p2 = points[i], points[i + 1]
      local seg_start = math.floor(p1.x)
      local seg_end = math.floor(p2.x)
      for px = seg_start, seg_end, step do
        local t = (px - p1.x) / (p2.x - p1.x + 0.001)
        t = math.max(0, math.min(1, t))
        local py = p1.y + (p2.y - p1.y) * t
        -- Gradient from top to bottom
        local line_h = bottom_y - py
        if line_h > 1 then
          ImGui.DrawList_AddLine(dl, px, py, px, bottom_y, colors.fill_top, 1)
        end
      end
    end
  end

  -- Draw envelope line with glow
  for i = 1, #points - 1 do
    draw_glow_line(dl,
      points[i].x, points[i].y,
      points[i + 1].x, points[i + 1].y,
      colors.line, colors.line_glow, 2)
  end

  -- Handle dragging
  local mx, my = ImGui.GetMousePos(ctx)
  local mouse_down = ImGui.IsMouseDown(ctx, 0)

  if widget_state.dragging and mouse_down then
    local stage = widget_state.dragging
    local pad = 8
    local draw_w = width - pad * 2
    local draw_h = height - pad * 2 - 12
    local seg_w = draw_w * 0.25

    if stage == M.STAGE.ATTACK then
      local rel_x = (mx - x - pad) / seg_w
      attack = math.max(0.01, math.min(1, rel_x))
      changed = true
    elseif stage == M.STAGE.DECAY then
      local attack_x = x + pad + seg_w * attack
      local rel_x = (mx - attack_x) / seg_w
      decay = math.max(0.01, math.min(1, rel_x))
      -- Vertical drag adjusts sustain
      local rel_y = 1 - ((my - y - pad) / draw_h)
      sustain = math.max(0, math.min(1, rel_y))
      changed = true
    elseif stage == M.STAGE.SUSTAIN then
      local rel_y = 1 - ((my - y - pad) / draw_h)
      sustain = math.max(0, math.min(1, rel_y))
      changed = true
    elseif stage == M.STAGE.RELEASE then
      local sustain_x = x + pad + seg_w * attack + seg_w * decay + seg_w
      local rel_x = (mx - sustain_x) / seg_w
      release = math.max(0.01, math.min(1, rel_x))
      changed = true
    end

    active_stage = stage
  elseif hovered and ImGui.IsMouseClicked(ctx, 0) then
    -- Check which handle was clicked (points 2, 3, 4, 5)
    if is_near_handle(mx, my, points[2].x, points[2].y) then
      widget_state.dragging = M.STAGE.ATTACK
    elseif is_near_handle(mx, my, points[3].x, points[3].y) then
      widget_state.dragging = M.STAGE.DECAY
    elseif is_near_handle(mx, my, points[4].x, points[4].y) then
      widget_state.dragging = M.STAGE.SUSTAIN
    elseif is_near_handle(mx, my, points[5].x, points[5].y) then
      widget_state.dragging = M.STAGE.RELEASE
    end
  end

  -- Clear drag state when mouse released
  if not mouse_down then
    widget_state.dragging = nil
  end

  -- Draw handles at control points (skip first point - it's the origin)
  local handle_stages = {
    [2] = M.STAGE.ATTACK,
    [3] = M.STAGE.DECAY,
    [4] = M.STAGE.SUSTAIN,
    [5] = M.STAGE.RELEASE,
  }

  for idx, stage in pairs(handle_stages) do
    local p = points[idx]
    if p then
      local is_active = widget_state.dragging == stage
      local is_hovered_handle = is_near_handle(mx, my, p.x, p.y)
      draw_handle(dl, p.x, p.y, HANDLE_RADIUS, is_active, is_hovered_handle, colors)
    end
  end

  -- Draw labels
  local label_y = y + height - 14
  local seg_w = (width - 16) / 4
  local labels = {
    { text = string.format('A:%.0f', attack * 100), x = x + 8 },
    { text = string.format('D:%.0f', decay * 100), x = x + 8 + seg_w },
    { text = string.format('S:%.0f', sustain * 100), x = x + 8 + seg_w * 2 },
    { text = string.format('R:%.0f', release * 100), x = x + 8 + seg_w * 3 },
  }

  for _, lbl in ipairs(labels) do
    ImGui.DrawList_AddText(dl, lbl.x, label_y, colors.label, lbl.text)
  end

  -- Draw border
  ImGui.DrawList_AddRect(dl, x, y, x + width, y + height, colors.border, 6, 0, 1)

  -- Tooltip
  if hovered and not widget_state.dragging then
    ImGui.SetTooltip(ctx, string.format('A: %.0f%%  D: %.0f%%  S: %.0f%%  R: %.0f%%',
      attack * 100, decay * 100, sustain * 100, release * 100))
  end

  -- Return result (with or without Base helper)
  local result = {
    changed = changed,
    attack = attack,
    decay = decay,
    sustain = sustain,
    release = release,
    active_stage = active_stage,
    width = width,
    height = height,
    hovered = hovered,
    active = widget_state.dragging ~= nil,
  }

  if Base_ok and Base.create_result then
    return Base.create_result(result)
  end

  return result
end

return M

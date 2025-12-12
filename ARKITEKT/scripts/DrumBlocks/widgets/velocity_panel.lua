-- @noindex
-- DrumBlocks/widgets/velocity_panel.lua
-- Velocity layer editor with draggable/resizable sample bars

local Ark = require('arkitekt')
local ImGui = Ark.ImGui
local Colors = Ark.Colors

-- Cache functions for performance
local max, min, floor, abs = math.max, math.min, math.floor, math.abs
local AddPolyline = ImGui.DrawList_AddPolyline
local new_array = reaper.new_array

local M = {}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local COLORS = {
  bg = 0x0E0E0EFF,
  header_bg = 0x181818FF,
  header_hover = 0x252525FF,
  header_drop = 0x2A4A3AFF,
  column_even = 0x141414FF,
  column_odd = 0x181818FF,
  boundary = 0x333333FF,
  grid_line = 0x222222FF,
  sample_fill = 0x3A6090FF,
  sample_fill_hover = 0x4A70A0FF,
  sample_fill_selected = 0x5080C0FF,
  sample_border = 0x6090C0FF,
  sample_edge = 0x80B0E0FF,
  sample_edge_hover = 0xFFFFFFDD,
  overlap_zone = 0xFFFFFF30,
  text = 0xCCCCCCFF,
  text_dim = 0x000000CC,  -- Dark text for visibility on colored bg
  waveform = 0x000000AA,  -- Dark waveform for visibility on colored bg
  rr_badge = 0x000000DD,  -- Dark RR badge for visibility
  drop_highlight = 0x42E896AA,
}

local DIMENSIONS = {
  header_height = 24,
  lane_height = 18,  -- Minimum lane height (was 32)
  lane_separator = 1,
  edge_hit_width = 6,
  min_sample_width = 20,
  new_lane_zone_height = 18,
  hash_stripe_width = 12,
  hash_stripe_gap = 8,
  default_height = 200,  -- Recommended default panel height
}

-- Velocity layer info
local LAYER_INFO = {
  [0] = { name = 'Soft',   min = 0,   max = 31  },
  [1] = { name = 'Medium', min = 32,  max = 63  },
  [2] = { name = 'Hard',   min = 64,  max = 95  },
  [3] = { name = 'Accent', min = 96,  max = 127 },
}

-- Velocity color gradient: cyan → green → yellow → red
local VELOCITY_GRADIENT = {
  { vel = 0,   r = 0x00, g = 0xDD, b = 0xFF }, -- Cyan
  { vel = 42,  r = 0x00, g = 0xEE, b = 0x66 }, -- Green
  { vel = 85,  r = 0xFF, g = 0xDD, b = 0x00 }, -- Yellow
  { vel = 127, r = 0xFF, g = 0x44, b = 0x44 }, -- Red
}

local function lerp(a, b, t)
  return a + (b - a) * t
end

-- Calculate color based on velocity midpoint (smooth gradient)
-- Returns fill (30% opacity), border (100% opacity), waveform (70% opacity), and complement colors
local function get_velocity_colors(vel_min, vel_max)
  local midpoint = (vel_min + vel_max) / 2

  -- Find the two gradient stops to interpolate between
  local c1, c2, t
  for i = 1, #VELOCITY_GRADIENT - 1 do
    if midpoint <= VELOCITY_GRADIENT[i + 1].vel then
      c1 = VELOCITY_GRADIENT[i]
      c2 = VELOCITY_GRADIENT[i + 1]
      t = (midpoint - c1.vel) / (c2.vel - c1.vel)
      break
    end
  end

  local r, g, b
  if not c1 then
    local last = VELOCITY_GRADIENT[#VELOCITY_GRADIENT]
    r, g, b = last.r, last.g, last.b
  else
    r = floor(lerp(c1.r, c2.r, t))
    g = floor(lerp(c1.g, c2.g, t))
    b = floor(lerp(c1.b, c2.b, t))
  end

  local base = (r << 24) | (g << 16) | (b << 8)
  -- Complementary color (invert RGB)
  local comp_base = ((255 - r) << 24) | ((255 - g) << 16) | ((255 - b) << 8)

  return base | 0x4D,      -- 30% fill
         base | 0xFF,      -- 100% border
         base | 0xB3,      -- 70% waveform
         comp_base | 0x88  -- ~53% complement for crossfade stripes
end

-- Brighten a color for hover state
local function brighten_color(color, factor)
  local r = (color >> 24) & 0xFF
  local g = (color >> 16) & 0xFF
  local b = (color >> 8) & 0xFF
  local a = color & 0xFF

  r = min(255, floor(r * factor))
  g = min(255, floor(g * factor))
  b = min(255, floor(b * factor))

  return (r << 24) | (g << 16) | (b << 8) | a
end

-- ============================================================================
-- INTERNAL STATE
-- ============================================================================

local drag_state = {
  active = false,
  type = nil,
  layer = nil,
  rr_idx = nil,
  start_x = 0,
  start_y = 0,
  start_vel_min = 0,
  start_vel_max = 0,
  start_lane = 0,
}

local sample_ranges = {}

local function get_range_key(pad_idx, layer, rr_idx)
  return string.format('%d_%d_%s', pad_idx, layer, rr_idx or 'p')
end

local function get_sample_range(pad_idx, layer, rr_idx)
  local key = get_range_key(pad_idx, layer, rr_idx)
  local range = sample_ranges[key]
  if not range then
    local info = LAYER_INFO[layer]
    range = { vel_min = info.min, vel_max = info.max, lane = 0 }
    sample_ranges[key] = range
  end
  return range
end

local function set_sample_range(pad_idx, layer, rr_idx, vel_min, vel_max, lane)
  local key = get_range_key(pad_idx, layer, rr_idx)
  local existing = sample_ranges[key]
  sample_ranges[key] = {
    vel_min = vel_min,
    vel_max = vel_max,
    lane = lane or (existing and existing.lane) or 0
  }
end

local function set_sample_lane(pad_idx, layer, rr_idx, lane)
  local key = get_range_key(pad_idx, layer, rr_idx)
  local range = sample_ranges[key]
  if range then
    range.lane = lane
  end
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

local function vel_to_x(vel, x_start, width)
  return x_start + (vel / 127) * width
end

local function get_filename(path)
  if not path or path == '' then return nil end
  local name = path:match('([^/\\]+)$')
  if name then
    name = name:match('(.+)%.[^.]+$') or name
  end
  return name
end

-- Draw mini waveform using polyline (like WaveEditor)
local function draw_mini_waveform(dl, peaks, x, y, w, h, color)
  if not peaks or #peaks < 4 then return end
  local num_peaks = #peaks / 2
  local mid_y = y + h / 2
  local scale = h * 0.38

  -- Build top and bottom polyline arrays
  local top_pts = {}
  local bot_pts = {}
  local ti, bi = 0, 0
  local step = max(1, floor(w / 64))  -- ~64 points max for mini display

  for i = 0, w - 1, step do
    local peak_idx = floor((i / w) * num_peaks) + 1
    if peak_idx > num_peaks then peak_idx = num_peaks end
    local peak_val = peaks[peak_idx] or 0
    local px = x + i
    local line_h = peak_val * scale

    ti = ti + 1; top_pts[ti] = px
    ti = ti + 1; top_pts[ti] = mid_y - line_h
    bi = bi + 1; bot_pts[bi] = px
    bi = bi + 1; bot_pts[bi] = mid_y + line_h
  end

  -- Draw polylines if we have enough points
  if ti >= 4 then
    AddPolyline(dl, new_array(top_pts), color, ImGui.DrawFlags_None, 1.0)
    AddPolyline(dl, new_array(bot_pts), color, ImGui.DrawFlags_None, 1.0)
  end
end

-- ============================================================================
-- MAIN DRAW FUNCTION
-- ============================================================================

function M.draw(ctx, opts)
  local pad_data = opts.pad_data
  local pad_index = opts.pad_index
  local width = opts.width or 400
  local height = opts.height or 140
  local visible_columns = opts.visible_columns or 4
  local get_peaks = opts.get_peaks
  local on_sample_drop = opts.on_sample_drop
  local on_rr_drop = opts.on_rr_drop
  local on_range_change = opts.on_range_change

  if not pad_data then
    return { hovered = false, changed = false }
  end

  local result = { hovered = false, changed = false }
  local start_cx, start_cy = ImGui.GetCursorScreenPos(ctx)
  local mx, my = ImGui.GetMousePos(ctx)
  result.hovered = mx >= start_cx and mx < start_cx + width and my >= start_cy and my < start_cy + height

  local col_width = floor(width / visible_columns)

  -- ========================================================================
  -- CHILD WINDOW (creates drop target area)
  -- ========================================================================
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, COLORS.bg)
  ImGui.PushStyleColor(ctx, ImGui.Col_Border, COLORS.boundary)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ChildRounding, 4)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 0, 0)

  local child_opened = ImGui.BeginChild(ctx, '##vel_panel_' .. pad_index, width, height, ImGui.ChildFlags_FrameStyle)

  if child_opened then
    local dl = ImGui.GetWindowDrawList(ctx)
    local cx, cy = ImGui.GetCursorScreenPos(ctx)
    local content_y = cy + DIMENSIONS.header_height

    -- Draw column headers
    for col = 0, visible_columns - 1 do
      local col_x = cx + col * col_width
      local layer = col
      local info = LAYER_INFO[layer]

      if info then
        local header_hovered = mx >= col_x and mx < col_x + col_width and my >= cy and my < cy + DIMENSIONS.header_height
        local header_bg = header_hovered and COLORS.header_hover or COLORS.header_bg
        ImGui.DrawList_AddRectFilled(dl, col_x, cy, col_x + col_width, cy + DIMENSIONS.header_height, header_bg)

        local range_text = string.format('%d-%d', info.min, info.max)
        local text_w = ImGui.CalcTextSize(ctx, range_text)
        ImGui.DrawList_AddText(dl, col_x + (col_width - text_w) / 2, cy + 4, COLORS.text, range_text)

        if col < visible_columns - 1 then
          ImGui.DrawList_AddLine(dl, col_x + col_width, cy, col_x + col_width, cy + height, COLORS.boundary)
        end
      end
    end

    ImGui.DrawList_AddLine(dl, cx, cy + DIMENSIONS.header_height, cx + width, cy + DIMENSIONS.header_height, COLORS.boundary)

    -- Column backgrounds
    for col = 0, visible_columns - 1 do
      local col_x = cx + col * col_width
      local col_bg = (col % 2 == 0) and COLORS.column_even or COLORS.column_odd
      ImGui.DrawList_AddRectFilled(dl, col_x, content_y, col_x + col_width, cy + height, col_bg)
    end

    -- Velocity grid lines
    for v = 16, 112, 16 do
      local gx = vel_to_x(v, cx, width)
      ImGui.DrawList_AddLine(dl, gx, content_y, gx, cy + height, COLORS.grid_line)
    end

    -- Collect samples with lane info
    local samples = {}
    local max_lane = 0
    for layer = 0, 3 do
      local primary = pad_data.samples and pad_data.samples[layer]
      if primary and primary ~= '' then
        local range = get_sample_range(pad_index, layer, nil)
        local lane = range.lane or 0
        max_lane = max(max_lane, lane)
        table.insert(samples, {
          layer = layer, rr_idx = nil, path = primary,
          vel_min = range.vel_min, vel_max = range.vel_max, lane = lane, is_primary = true,
        })
      end
      local rr_samples = pad_data.round_robin and pad_data.round_robin[layer] or {}
      for rr_idx, rr_path in ipairs(rr_samples) do
        local range = get_sample_range(pad_index, layer, rr_idx)
        local lane = range.lane or 0
        max_lane = max(max_lane, lane)
        table.insert(samples, {
          layer = layer, rr_idx = rr_idx, path = rr_path,
          vel_min = range.vel_min, vel_max = range.vel_max, lane = lane, is_primary = false,
        })
      end
    end

    -- Organize samples by lane
    local lanes = {}
    for i = 0, max_lane do
      lanes[i] = {}
    end
    for _, sample in ipairs(samples) do
      local lane_idx = sample.lane or 0
      if not lanes[lane_idx] then lanes[lane_idx] = {} end
      table.insert(lanes[lane_idx], sample)
    end

    -- Remove empty lanes and renumber
    local active_lanes = {}
    for i = 0, max_lane do
      if lanes[i] and #lanes[i] > 0 then
        table.insert(active_lanes, lanes[i])
      end
    end

    -- Calculate available space for lanes (reserve space for new-lane drop zone)
    local new_lane_zone_h = DIMENSIONS.new_lane_zone_height
    local lanes_area_h = height - DIMENSIONS.header_height - new_lane_zone_h
    local num_lanes = #active_lanes
    local lane_h
    if num_lanes > 0 then
      lane_h = floor((lanes_area_h - (num_lanes - 1) * DIMENSIONS.lane_separator) / num_lanes)
      lane_h = max(DIMENSIONS.lane_height, lane_h)
    else
      lane_h = lanes_area_h  -- Full height for single lane when empty
    end

    -- Track new lane zone for drop handling
    local new_lane_next_idx = num_lanes  -- Index for a new lane

    -- Store lane boundaries for drag handling
    local lane_boundaries = {}  -- { {y_start, y_end, lane_idx}, ... }

    -- Draw sample bars by lane
    local lane_y = content_y
    for lane_idx, lane_samples in ipairs(active_lanes) do
      -- Store lane boundary
      table.insert(lane_boundaries, { y_start = lane_y, y_end = lane_y + lane_h, lane_idx = lane_idx - 1 })
      local next_lane_y = lane_y + lane_h

      -- Collect overlaps for crossfade stripes (drawn after bars)
      local overlaps = {}

      -- Draw bars (full lane height)
      for _, sample in ipairs(lane_samples) do
        local x1 = vel_to_x(sample.vel_min, cx, width)
        local x2 = vel_to_x(sample.vel_max, cx, width)
        local bar_w = x2 - x1

        local bar_hovered = mx >= x1 and mx < x2 and my >= lane_y and my < next_lane_y
        local left_edge_hovered = abs(mx - x1) < DIMENSIONS.edge_hit_width and my >= lane_y and my < next_lane_y
        local right_edge_hovered = abs(mx - x2) < DIMENSIONS.edge_hit_width and my >= lane_y and my < next_lane_y

        -- Velocity-based color gradient (cyan → green → yellow → red)
        -- Fill 30%, border 100%, waveform 70%, complement for crossfade
        local fill_color, border_color, wave_color, comp_color = get_velocity_colors(sample.vel_min, sample.vel_max)
        sample.comp_color = comp_color  -- Store for crossfade stripes
        if bar_hovered then
          fill_color = brighten_color(fill_color, 1.3)
          border_color = brighten_color(border_color, 1.2)
          wave_color = brighten_color(wave_color, 1.2)
        end

        ImGui.DrawList_AddRectFilled(dl, x1, lane_y, x2, next_lane_y, fill_color, 3)
        ImGui.DrawList_AddRect(dl, x1, lane_y, x2, next_lane_y, border_color, 3, 0, 1.5)

        if bar_w > 40 and get_peaks then
          local peaks = get_peaks(sample.layer)
          if peaks then
            draw_mini_waveform(dl, peaks, x1 + 4, lane_y + 2, bar_w - 8, lane_h - 4, wave_color)
          end
        end

        -- Draw label with background pill for readability
        local name = get_filename(sample.path)
        local full_name = name  -- Store for tooltip
        if name and bar_w > 30 then
          local padding_x = 4
          local padding_y = 2
          local max_text_w = bar_w - 12
          local text_w = ImGui.CalcTextSize(ctx, name)

          -- Truncate if needed
          if text_w > max_text_w then
            local avg_char_w = text_w / #name
            local max_chars = floor(max_text_w / avg_char_w) - 2
            if max_chars > 0 then
              name = name:sub(1, max_chars) .. '..'
              text_w = ImGui.CalcTextSize(ctx, name)
            else
              name = nil
            end
          end

          if name then
            local label_x = x1 + 4
            local label_y = lane_y + 4
            local pill_x1 = label_x - padding_x
            local pill_y1 = label_y - padding_y
            local pill_x2 = label_x + text_w + padding_x
            local pill_y2 = label_y + 12 + padding_y

            -- Background pill
            ImGui.DrawList_AddRectFilled(dl, pill_x1, pill_y1, pill_x2, pill_y2, 0x00000099, 3)
            -- White text
            ImGui.DrawList_AddText(dl, label_x, label_y, 0xFFFFFFFF, name)
          end
        end

        -- RR badge (bottom right)
        if sample.rr_idx then
          local rr_text = 'RR' .. sample.rr_idx
          local rr_w = ImGui.CalcTextSize(ctx, rr_text)
          local rr_x = x2 - rr_w - 6
          local rr_y = next_lane_y - 14
          ImGui.DrawList_AddRectFilled(dl, rr_x - 3, rr_y - 1, rr_x + rr_w + 3, rr_y + 11, 0x00000099, 2)
          ImGui.DrawList_AddText(dl, rr_x, rr_y, 0xAADDFFFF, rr_text)
        end

        -- Store full name for tooltip
        sample.full_name = full_name

        if left_edge_hovered then
          ImGui.DrawList_AddRectFilled(dl, x1 - 2, lane_y, x1 + 2, next_lane_y, 0xFFFFFFDD, 2)
          ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeEW)
        end
        if right_edge_hovered then
          ImGui.DrawList_AddRectFilled(dl, x2 - 2, lane_y, x2 + 2, next_lane_y, 0xFFFFFFDD, 2)
          ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeEW)
        end

        -- Handle drag start
        if ImGui.IsMouseClicked(ctx, 0) and not drag_state.active then
          if left_edge_hovered then
            drag_state = { active = true, type = 'resize_left', layer = sample.layer, rr_idx = sample.rr_idx,
              start_x = mx, start_y = my, start_vel_min = sample.vel_min, start_vel_max = sample.vel_max,
              start_lane = sample.lane }
          elseif right_edge_hovered then
            drag_state = { active = true, type = 'resize_right', layer = sample.layer, rr_idx = sample.rr_idx,
              start_x = mx, start_y = my, start_vel_min = sample.vel_min, start_vel_max = sample.vel_max,
              start_lane = sample.lane }
          elseif bar_hovered then
            drag_state = { active = true, type = 'move', layer = sample.layer, rr_idx = sample.rr_idx,
              start_x = mx, start_y = my, start_vel_min = sample.vel_min, start_vel_max = sample.vel_max,
              start_lane = sample.lane }
          end
        end

        if bar_hovered and not drag_state.active then
          ImGui.BeginTooltip(ctx)
          if sample.full_name then
            ImGui.Text(ctx, sample.full_name)
          end
          ImGui.TextDisabled(ctx, sample.path)
          ImGui.Text(ctx, string.format('Velocity: %d - %d', sample.vel_min, sample.vel_max))
          ImGui.EndTooltip(ctx)
        end
      end

      -- Detect overlaps between samples in this lane
      for i, s1 in ipairs(lane_samples) do
        for j, s2 in ipairs(lane_samples) do
          if i < j then
            local overlap_min = max(s1.vel_min, s2.vel_min)
            local overlap_max = min(s1.vel_max, s2.vel_max)
            if overlap_min < overlap_max then
              -- Use complementary colors from both overlapping samples
              table.insert(overlaps, {
                min = overlap_min,
                max = overlap_max,
                color1 = s1.comp_color,
                color2 = s2.comp_color,
              })
            end
          end
        end
      end

      -- Draw crossfade zones on top of bars
      for _, overlap in ipairs(overlaps) do
        local ox1 = vel_to_x(overlap.min, cx, width)
        local ox2 = vel_to_x(overlap.max, cx, width)

        -- Rounded rectangle overlay for crossfade zone
        local blend_color = 0xFFFFFF18  -- White 10% fill
        local blend_border = 0xFFFFFF40  -- White 25% border
        ImGui.DrawList_AddRectFilled(dl, ox1, lane_y, ox2, next_lane_y, blend_color, 3)
        ImGui.DrawList_AddRect(dl, ox1, lane_y, ox2, next_lane_y, blend_border, 3, 0, 1)

        -- Diagonal stripes
        local stripe_spacing = 6
        local stripe_idx = 0
        for sx = ox1, ox2 + lane_h, stripe_spacing do
          local lx1 = sx
          local ly1 = lane_y
          local lx2 = sx - (lane_h * 0.5)
          local ly2 = next_lane_y
          -- Clip to overlap bounds
          if lx2 < ox1 then
            local ratio = (ox1 - lx2) / (lx1 - lx2)
            lx2 = ox1
            ly2 = ly1 + (ly2 - ly1) * (1 - ratio)
          end
          if lx1 > ox2 then
            local ratio = (lx1 - ox2) / (lx1 - lx2)
            lx1 = ox2
            ly1 = ly1 + (ly2 - ly1) * ratio
          end
          if lx1 >= ox1 or lx2 >= ox1 then
            -- Alternate between the two complementary colors
            local stripe_color = (stripe_idx % 2 == 0) and overlap.color1 or overlap.color2
            ImGui.DrawList_AddLine(dl, lx1, ly1, lx2, ly2, stripe_color, 1.5)
          end
          stripe_idx = stripe_idx + 1
        end
      end

      -- Draw lane separator line
      if lane_idx < #active_lanes then
        local sep_y = next_lane_y
        ImGui.DrawList_AddLine(dl, cx, sep_y, cx + width, sep_y, 0x444444FF, DIMENSIONS.lane_separator)
      end

      lane_y = next_lane_y + DIMENSIONS.lane_separator
    end

    -- ========================================================================
    -- NEW LANE DROP ZONE (Reaper-style hashed pattern at bottom)
    -- ========================================================================
    local drop_zone_y = cy + height - new_lane_zone_h
    local drop_zone_hovered = my >= drop_zone_y and my < cy + height and mx >= cx and mx < cx + width

    -- Draw hashed pattern background
    local hash_bg = drop_zone_hovered and 0x2A3A2AFF or 0x1A1A1AFF
    ImGui.DrawList_AddRectFilled(dl, cx, drop_zone_y, cx + width, cy + height, hash_bg)

    -- Draw wide diagonal stripes (Reaper style)
    local stripe_w = DIMENSIONS.hash_stripe_width
    local stripe_gap = DIMENSIONS.hash_stripe_gap
    local stripe_color = drop_zone_hovered and 0x3A5A3AFF or 0x2A2A2AFF
    local total_stripe = stripe_w + stripe_gap
    for sx = cx - new_lane_zone_h, cx + width + new_lane_zone_h, total_stripe do
      local lx1 = sx
      local ly1 = drop_zone_y
      local lx2 = sx + new_lane_zone_h
      local ly2 = cy + height
      -- Clip to bounds
      if lx1 < cx then
        local t = (cx - lx1) / (lx2 - lx1)
        lx1 = cx
        ly1 = drop_zone_y + t * new_lane_zone_h
      end
      if lx2 > cx + width then
        local t = (lx2 - (cx + width)) / (lx2 - lx1)
        lx2 = cx + width
        ly2 = cy + height - t * new_lane_zone_h
      end
      -- Draw stripe as thick line
      for offset = 0, stripe_w - 1 do
        ImGui.DrawList_AddLine(dl, lx1 + offset, ly1, lx2 + offset, ly2, stripe_color, 1)
      end
    end

    -- Border at top of drop zone
    ImGui.DrawList_AddLine(dl, cx, drop_zone_y, cx + width, drop_zone_y, 0x444444FF, 1)

    -- "New Lane" hint text (centered)
    local hint_text = '+ New Lane'
    local hint_w = ImGui.CalcTextSize(ctx, hint_text)
    local hint_x = cx + (width - hint_w) / 2
    local hint_y = drop_zone_y + (new_lane_zone_h - 12) / 2
    ImGui.DrawList_AddText(dl, hint_x, hint_y, 0x555555FF, hint_text)

    -- Highlight target lane/zone when dragging clip
    if drag_state.active and drag_state.type == 'move' then
      if my >= drop_zone_y then
        -- Highlight new lane zone
        ImGui.DrawList_AddRectFilled(dl, cx, drop_zone_y, cx + width, cy + height, 0x42E89650)
        ImGui.DrawList_AddRect(dl, cx, drop_zone_y, cx + width, cy + height, 0x42E896FF, 0, 0, 2)
      else
        -- Highlight target lane if different from source
        for _, boundary in ipairs(lane_boundaries) do
          if my >= boundary.y_start and my < boundary.y_end then
            if boundary.lane_idx ~= drag_state.start_lane then
              -- Different lane - show drop target
              ImGui.DrawList_AddRectFilled(dl, cx, boundary.y_start, cx + width, boundary.y_end, 0x42E89630)
              ImGui.DrawList_AddRect(dl, cx, boundary.y_start, cx + width, boundary.y_end, 0x42E896AA, 0, 0, 1)
            end
            break
          end
        end
      end
    end

    -- Helper: find which lane the mouse is over
    local function get_lane_at_y(y)
      for _, boundary in ipairs(lane_boundaries) do
        if y >= boundary.y_start and y < boundary.y_end then
          return boundary.lane_idx
        end
      end
      return nil  -- Not over any lane (possibly over new lane zone)
    end

    -- Handle active drag
    if drag_state.active then
      if ImGui.IsMouseDown(ctx, 0) then
        local delta_vel = floor(((mx - drag_state.start_x) / width) * 127 + 0.5)
        local new_min, new_max = drag_state.start_vel_min, drag_state.start_vel_max

        if drag_state.type == 'move' then
          new_min = drag_state.start_vel_min + delta_vel
          new_max = drag_state.start_vel_max + delta_vel
          if new_min < 0 then new_max = new_max - new_min; new_min = 0 end
          if new_max > 127 then new_min = new_min - (new_max - 127); new_max = 127 end
        elseif drag_state.type == 'resize_left' then
          new_min = max(0, min(new_max - 8, drag_state.start_vel_min + delta_vel))
        elseif drag_state.type == 'resize_right' then
          new_max = min(127, max(new_min + 8, drag_state.start_vel_max + delta_vel))
        end

        set_sample_range(pad_index, drag_state.layer, drag_state.rr_idx, new_min, new_max)
        result.changed = true
      else
        -- Mouse released - check for lane change
        if drag_state.type == 'move' then
          local range = get_sample_range(pad_index, drag_state.layer, drag_state.rr_idx)

          if my >= drop_zone_y then
            -- Dropped on new lane zone - create new lane
            range.lane = new_lane_next_idx
            result.changed = true
          else
            -- Check if dropped on a different lane
            local target_lane = get_lane_at_y(my)
            if target_lane ~= nil and target_lane ~= drag_state.start_lane then
              range.lane = target_lane
              result.changed = true
            end
          end
        end

        if on_range_change then
          local range = get_sample_range(pad_index, drag_state.layer, drag_state.rr_idx)
          on_range_change(drag_state.layer, drag_state.rr_idx, range.vel_min, range.vel_max)
        end
        drag_state.active = false
      end
    end

    ImGui.EndChild(ctx)
  end

  ImGui.PopStyleVar(ctx, 2)
  ImGui.PopStyleColor(ctx, 2)

  -- ========================================================================
  -- FILE DROP TARGET (checked after EndChild)
  -- ========================================================================
  if ImGui.BeginDragDropTarget(ctx) then
    -- Determine if dropping to new lane zone or existing area
    local drop_zone_y = start_cy + height - DIMENSIONS.new_lane_zone_height
    local dropping_to_new_lane = my >= drop_zone_y

    -- Highlight the drop column
    local drop_layer = floor((mx - start_cx) / col_width)
    drop_layer = max(0, min(visible_columns - 1, drop_layer))

    -- Draw drop highlight
    local fg_dl = ImGui.GetForegroundDrawList(ctx)
    local drop_x = start_cx + drop_layer * col_width

    if dropping_to_new_lane then
      -- Highlight new lane zone
      ImGui.DrawList_AddRectFilled(fg_dl, start_cx, drop_zone_y, start_cx + width, start_cy + height, COLORS.drop_highlight)
      ImGui.DrawList_AddRect(fg_dl, start_cx, drop_zone_y, start_cx + width, start_cy + height, 0x42E896FF, 4, 0, 2)
    else
      -- Highlight column
      ImGui.DrawList_AddRectFilled(fg_dl, drop_x, start_cy, drop_x + col_width, drop_zone_y, COLORS.drop_highlight)
      ImGui.DrawList_AddRect(fg_dl, drop_x, start_cy, drop_x + col_width, drop_zone_y, 0x42E896FF, 4, 0, 2)
    end

    local rv, count = ImGui.AcceptDragDropPayloadFiles(ctx)
    if rv and count > 0 then
      local _, filepath = ImGui.GetDragDropPayloadFile(ctx, 0)
      if filepath and filepath ~= '' then
        if dropping_to_new_lane then
          -- Create sample in new lane (use layer 0 for now, could be configurable)
          if on_sample_drop then
            on_sample_drop(0, filepath)
            -- Set the new sample to a new lane
            local range = get_sample_range(pad_index, 0, nil)
            range.lane = (range.lane or 0) + 1
            result.changed = true
          end
        else
          local primary = pad_data.samples and pad_data.samples[drop_layer]
          if primary and primary ~= '' then
            if on_rr_drop then on_rr_drop(drop_layer, filepath); result.changed = true end
          else
            if on_sample_drop then on_sample_drop(drop_layer, filepath); result.changed = true end
          end
        end
      end
    end
    ImGui.EndDragDropTarget(ctx)
  end

  return result
end

return M

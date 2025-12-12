-- @noindex
-- WalterBuilder/domain/flow_layout.lua
-- Flow layout positioning for WALTER 'then' DSL elements
--
-- WALTER's flow layout system positions elements sequentially based on
-- their order and widths, with support for multi-row layout.

local ExpressionEval = require('WalterBuilder.domain.expression_eval')

local M = {}

-- Group to child elements mapping
-- Groups in flow macros contain these tcp.* child elements
M.FLOW_GROUP_CHILDREN = {
  pan_group = { 'tcp.pan', 'tcp.width' },
  fx_group = { 'tcp.fx', 'tcp.fxbyp', 'tcp.fxin' },
  input_group = { 'tcp.recinput' },
  master_pan_group = { 'master.tcp.pan', 'master.tcp.width' },
  master_fx_group = { 'master.tcp.fx' },
}

-- Helper to get scalar value (some context vars are arrays)
local function get_scalar(val, default)
  if val == nil then return default end
  if type(val) == 'table' then return val[1] or default end
  return val
end

-- Helper to get value at specific index from array or scalar
local function get_at_index(val, index, default)
  if val == nil then return default end
  if type(val) == 'table' then return val[index] or default end
  return val  -- Scalar value
end

-- Format array for debug
local function fmt_arr(arr)
  if not arr then return 'nil' end
  if type(arr) ~= 'table' then return tostring(arr) end
  local parts = {}
  for i, v in ipairs(arr) do
    parts[i] = string.format('%.0f', v)
  end
  return '[' .. table.concat(parts, ', ') .. ']'
end

-- Check if a flow element should be hidden based on its hide_cond/hide_val
-- @param flow_params: Array of parameters from then statement [width, row_flag, row_val, hide_cond, hide_val]
-- @param eval_context: The evaluation context with variable values
-- @return: true if element should be hidden
function M.check_flow_hide_condition(flow_params, eval_context)
  if not flow_params or #flow_params < 5 then
    return false  -- No hide condition
  end

  local hide_cond = flow_params[4]
  local hide_val = flow_params[5]

  -- Skip if no condition (0 means no condition)
  if hide_cond == '0' then
    return false
  end

  -- Handle negated conditions (!var means hide when var is truthy)
  local negated = false
  if hide_cond:sub(1, 1) == '!' then
    negated = true
    hide_cond = hide_cond:sub(2)
  end

  -- Get the variable value from context
  local cond_value = eval_context[hide_cond]
  if cond_value == nil then
    -- Variable not set - check DEFAULT_SCALARS or assume 0 (don't hide)
    cond_value = ExpressionEval.DEFAULT_SCALARS[hide_cond] or 0
  end

  -- Get scalar value if it's an array
  if type(cond_value) == 'table' then
    cond_value = cond_value[1] or 0
  end

  -- WALTER exclude semantics: hide when the condition variable is truthy (nonzero)
  -- The second parameter (hide_val/swap) is typically 0 for no swap, not a comparison value
  local should_hide = (cond_value ~= 0)

  if negated then
    should_hide = not should_hide
  end

  return should_hide
end

-- Calculate positions for flow layout elements
-- Flow elements are positioned sequentially based on their order and widths
-- Supports multi-row layout via row_flag parameter
-- @param result: The conversion result with elements array
-- @param eval_context: The evaluation context for resolving any remaining variables
-- @param log_fn: Optional logging function: fn(level, format, ...) -> nil
function M.calculate_flow_positions(result, eval_context, log_fn)
  log_fn = log_fn or function() end

  -- Build element lookup by ID for group child resolution
  local elements_by_id = {}
  for _, entry in ipairs(result.elements) do
    elements_by_id[entry.element.id] = entry
  end

  -- Collect flow elements (preserving their order by source_line)
  local flow_elements = {}
  for _, entry in ipairs(result.elements) do
    if entry.is_flow_element then
      flow_elements[#flow_elements + 1] = entry
    end
  end

  if #flow_elements == 0 then
    return  -- No flow elements to position
  end

  -- Sort by source line to maintain macro order
  table.sort(flow_elements, function(a, b)
    return (a.source_line or 0) < (b.source_line or 0)
  end)

  -- Determine starting X position
  -- Flow elements typically start after the meter section
  -- meter_sec is [x, y, w, h], so flow starts at meter_sec.x + meter_sec.w + padding
  local meter_sec_x = get_at_index(eval_context.meter_sec, 1, 20)
  local meter_sec_w = get_at_index(eval_context.meter_sec, 3, 84)
  local tcp_padding = get_scalar(eval_context.tcp_padding, 7)
  local parent_w = get_scalar(eval_context.w, 400)
  local start_x = meter_sec_x + meter_sec_w + tcp_padding

  -- Sanity check: if start_x is beyond parent width, meter_sec calculation went wrong
  -- This can happen if meterRight flips meter to right side incorrectly
  if start_x > parent_w - 50 then  -- Need at least 50px for flow elements
    log_fn('warn', 'Flow layout: start_x=%d exceeds parent_w=%d (meter_sec=%s)',
      start_x, parent_w, fmt_arr(eval_context.meter_sec))
    log_fn('warn', '  Using safe default: start_x=111 (meter on left)')
    start_x = 111  -- Safe default: 20 (folder) + 84 (meter) + 7 (padding)
  end

  -- Element dimensions
  local element_h = get_scalar(eval_context.element_h, 20)
  local row_gap = 2  -- Gap between rows
  local elem_gap = 2  -- Gap between elements horizontally

  -- Calculate maximum width available for flow (parent width minus margins)
  local max_flow_width = parent_w - start_x - tcp_padding  -- Available space from start_x to right edge

  -- Track current position (horizontal flow with wrapping)
  local current_x = start_x
  local current_row = 0
  local current_y = tcp_padding

  local positioned_count = 0
  local hidden_count = 0

  log_fn('info', 'Flow layout: horizontal flow starting at x=%d, y=%d, max_width=%d, %d elements',
    start_x, current_y, max_flow_width, #flow_elements)
  log_fn('info', '  meter_sec=%s | parent_w=%d, tcp_padding=%d',
    fmt_arr(eval_context.meter_sec), parent_w, tcp_padding)
  log_fn('info', '  calc: start_x = meter_sec.x(%d) + meter_sec.w(%d) + tcp_padding(%d) = %d',
    meter_sec_x, meter_sec_w, tcp_padding, start_x)

  for _, entry in ipairs(flow_elements) do
    local elem = entry.element
    local coords = elem.coords
    local elem_id = elem.id
    local flow_params = entry.flow_params

    -- Check hide condition from flow params
    if M.check_flow_hide_condition(flow_params, eval_context) then
      -- Hide this element (set to 0 size)
      coords.w = 0
      coords.h = 0
      elem.visible = false
      hidden_count = hidden_count + 1
      log_fn('info', '  Flow HIDDEN: %s (hide_cond=%s)', elem_id, flow_params[4] or '?')
      goto continue
    end

    -- Get element width for wrapping calculation
    local elem_width = coords.w or 0

    -- For groups, use group width
    local children = M.FLOW_GROUP_CHILDREN[elem_id]
    if children then
      -- Group width is already set
      elem_width = coords.w or 0
    elseif elem_id:match('^tcp%.') or elem_id:match('^master%.tcp%.') then
      -- For direct elements, try to get width from flow params
      if elem_width == 0 and flow_params and flow_params[1] then
        local FLOW_WIDTH_DEFAULTS = {
          tcp_LabelSize = 80,
          tcp_VolSize = 50,
          tcp_PanSize = 40,
          tcp_InSize = 40,
          ['OVR.tcp_recarm.width'] = 20,
          ['OVR.tcp_recmon.width'] = 15,
          ['OVR.tcp_io.width'] = 34,
          ['OVR.tcp_fx.width'] = 24,
          ['OVR.tcp_env.width'] = 41,
          ['OVR.tcp_recmode.width'] = 39,
        }

        local width_var = flow_params[1]
        local width_val = tonumber(width_var)
        if not width_val then
          width_val = get_scalar(eval_context[width_var], 0)
          if (not width_val or width_val == 0) and FLOW_WIDTH_DEFAULTS[width_var] then
            width_val = FLOW_WIDTH_DEFAULTS[width_var]
          end
        end
        if width_val and width_val > 0 then
          elem_width = width_val
        end
      end
    end

    -- Check if element fits on current row, wrap if needed
    if elem_width > 0 and current_x > start_x and (current_x + elem_width) > (start_x + max_flow_width) then
      -- Wrap to next row
      current_row = current_row + 1
      current_x = start_x
      current_y = tcp_padding + (current_row * (element_h + row_gap))
      log_fn('info', '  Flow WRAP to row %d at y=%d (element %s with w=%d wouldn\'t fit)',
        current_row, current_y, elem_id, elem_width)
    end

    -- Position groups or direct elements
    if children then
      -- Position each child element at current X
      local group_width = coords.w or 0
      log_fn('info', '  Flow group: %s (w=%d) -> children: %s', elem_id, group_width, table.concat(children, ', '))

      -- Store group coordinates in eval_context so dependent elements can reference them
      -- e.g., tcp.fxbyp uses fx_group{2} (width) to determine its position
      eval_context[elem_id] = { current_x, current_y, group_width, element_h }
      log_fn('info', '  Stored %s in context: [%d, %d, %d, %d]', elem_id, current_x, current_y, group_width, element_h)

      for _, child_id in ipairs(children) do
        local child_entry = elements_by_id[child_id]
        if child_entry then
          local child_coords = child_entry.element.coords
          child_coords.x = current_x
          child_coords.y = current_y
          -- Use group width for child if child has no width
          if (child_coords.w or 0) == 0 and group_width > 0 then
            child_coords.w = group_width
          end
          if (child_coords.h or 0) == 0 then
            child_coords.h = element_h
          end
          log_fn('info', '    Child positioned: %s at x=%d, y=%d (w=%d)', child_id, child_coords.x, child_coords.y, child_coords.w or 0)
          positioned_count = positioned_count + 1
        end
      end

      -- Advance X by group width
      if group_width > 0 then
        current_x = current_x + group_width + elem_gap
      end

    elseif elem_id:match('^tcp%.') or elem_id:match('^master%.tcp%.') then
      -- Direct tcp.* element - position it
      coords.x = current_x
      coords.y = current_y
      if (coords.h or 0) == 0 then
        coords.h = element_h
      end

      -- Apply the calculated width
      if elem_width > 0 and (coords.w or 0) == 0 then
        coords.w = elem_width
      end

      -- Advance X by element width (plus gap)
      if elem_width > 0 then
        current_x = current_x + elem_width + elem_gap
        positioned_count = positioned_count + 1
        log_fn('info', '  Flow positioned: %s at x=%d, y=%d (w=%d)', elem_id, coords.x, coords.y, elem_width)

        -- Store positioned element in eval_context for dependent element lookups
        -- e.g., tcp.fxbyp references [tcp.fx tcp.fx] and tcp.fx{2} for its position
        eval_context[elem_id] = { coords.x, coords.y, elem_width, coords.h or element_h }
      end
    end

    ::continue::
  end

  if positioned_count > 0 or hidden_count > 0 then
    log_fn('success', 'Flow layout complete: positioned %d elements, hidden %d (rows: %d)', positioned_count, hidden_count, current_row + 1)
  end
end

return M

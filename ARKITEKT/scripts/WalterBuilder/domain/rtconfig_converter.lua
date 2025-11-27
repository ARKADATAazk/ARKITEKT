-- @noindex
-- WalterBuilder/domain/rtconfig_converter.lua
-- Converts parsed rtconfig AST to WalterBuilder Element models
--
-- This bridges the gap between:
--   - RtconfigParser output (AST with set/clear/front statements)
--   - Element model (our visual representation)
--
-- Currently handles:
--   - Simple coordinates: set tcp.mute [0 0 20 20 0 0 1 1]
--   - Clear statements: clear tcp.mute
--
-- Future phases will add:
--   - Variable resolution
--   - Expression evaluation
--   - Macro expansion

local Element = require('WalterBuilder.domain.element')
local Coordinate = require('WalterBuilder.domain.coordinate')
local RtconfigParser = require('WalterBuilder.domain.rtconfig_parser')
local ExpressionEval = require('WalterBuilder.domain.expression_eval')
local Console = require('WalterBuilder.ui.panels.debug_console')
local TCPElements = require('WalterBuilder.defs.tcp_elements')

local M = {}

-- Custom context overrides (set by UI)
local custom_context = {}

-- Evaluation context with default values
-- These provide reasonable defaults for visualization when runtime state isn't available
local DEFAULT_CONTEXT = {
  -- Parent dimensions (use larger values to reveal more elements)
  w = 400,  -- Default TCP width (wider to show more)
  h = 150,  -- Default TCP height (taller to pass height thresholds)
  scale = 1.0,
  lscale = 1.0,  -- Layout scale (used by some themes)

  -- Common pre-computed variables (typical values at 100% DPI)
  tcp_padding = 7,
  element_h = 20,
  meter_sec = 50,
  main_sec = 200,
  folder_sec = 20,

  -- Track state variables (defaults for visualization)
  recarm = 1,  -- Show record arm button
  recmon = 1,  -- Show record monitor
  track_selected = 1,  -- Show as if track is selected
  mixer_visible = 0,
  trackcolor_valid = 1,  -- Show track color
  folderstate = 0,
  folderdepth = 0,
  maxfolderdepth = 3,
  supercollapsed = 0,

  -- Common conditionals (assume visible/enabled by default)
  is_solo_flipped = 0,
  hide_mute_group = 0,
  hide_fx_group = 0,
  hide_pan_group = 0,
  hide_io_group = 0,
  hide_recarm_group = 0,
  hide_recmon_group = 0,
  hide_label_group = 0,
  hide_volume_group = 0,
  trackpanmode = 6,  -- Stereo pan mode (shows both pan and width)

  -- Theme variant
  theme_version = 1,
  theme_variant = 0,

  -- Main font
  main_font = 1,

  -- Height thresholds (set low to show elements)
  labelHide_h = 0,
  panHide_h = 0,
  volumeHide_h = 0,
  recinputHide_h = 0,
  fxHide_h = 0,
  ioHide_h = 0,
  phaseHide_h = 0,
  envHide_h = 0,
  recarmHide_h = 0,
  recmonHide_h = 0,
  recmodeHide_h = 0,
  folderHide_h = 0,
  meterHide_h = 0,
  fixed_lanes_hide_h = 0,

  -- Show flags (opposite of hide, some themes use these)
  show_recarm_group = 1,
  show_recmon_group = 1,
  show_recmode_group = 1,
  show_env_group = 1,

  -- Flow element widths (computed by rtconfig, we provide defaults)
  tcp_LabelSize = 80,
  tcp_VolSize = 50,
  tcp_PanSize = 40,
  tcp_InSize = 40,
  tcpLabelAutoMeasured = 80,  -- Simulated runtime label width
  tcp_LabelPair = 80,
  tcp_VolPair = 50,
  tcp_vol_len_offs = 0,
  tcp_label_len_offs = 0,

  -- OVR (override) widths for flow elements (dotted names flattened)
  ["OVR.tcp_recarm.width"] = 20,
  ["OVR.tcp_recmon.width"] = 15,
  ["OVR.tcp_io.width"] = 34,
  ["OVR.tcp_fx.width"] = 24,
  ["OVR.tcp_env.width"] = 41,
  ["OVR.tcp_recmode.width"] = 39,
}

-- Known element context prefixes (these define visual elements, not variables)
local ELEMENT_CONTEXTS = {
  tcp = true,
  mcp = true,
  envcp = true,
  trans = true,
  masterlayout = true,
  master = true,
  global = true,
}

-- Check if a SET statement defines a variable (vs an element)
-- Variables: simple names like "meter_sec", "tcp_padding"
--            OR dotted names that don't start with element contexts (OVR.*, etc.)
-- Elements: dotted names like "tcp.mute", "tcp.pan" (context.element format)
local function is_variable_definition(element_name)
  -- Simple names without dots are always variables
  if not element_name:match("%.") then
    return true
  end

  -- Dotted names: check if they start with a known element context
  local prefix = element_name:match("^([^.]+)%.")
  if prefix and ELEMENT_CONTEXTS[prefix:lower()] then
    return false  -- It's an element (tcp.mute, mcp.volume, etc.)
  end

  -- Dotted names with unknown prefixes are variables (OVR.*, etc.)
  return true
end

-- Element name to category mapping
local CATEGORY_MAP = {
  -- Buttons
  mute = Element.CATEGORIES.BUTTON,
  solo = Element.CATEGORIES.BUTTON,
  recarm = Element.CATEGORIES.BUTTON,
  recmon = Element.CATEGORIES.BUTTON,
  recmode = Element.CATEGORIES.BUTTON,
  fx = Element.CATEGORIES.BUTTON,
  fxbyp = Element.CATEGORIES.BUTTON,
  fxin = Element.CATEGORIES.BUTTON,
  io = Element.CATEGORIES.BUTTON,
  env = Element.CATEGORIES.BUTTON,
  phase = Element.CATEGORIES.BUTTON,
  folder = Element.CATEGORIES.BUTTON,
  foldercomp = Element.CATEGORIES.BUTTON,

  -- Faders
  volume = Element.CATEGORIES.FADER,
  pan = Element.CATEGORIES.FADER,
  width = Element.CATEGORIES.FADER,
  fader = Element.CATEGORIES.FADER,

  -- Labels/text
  label = Element.CATEGORIES.LABEL,
  trackidx = Element.CATEGORIES.LABEL,
  value = Element.CATEGORIES.LABEL,

  -- Inputs
  recinput = Element.CATEGORIES.INPUT,

  -- Meters
  meter = Element.CATEGORIES.METER,

  -- Containers/lists
  fxparm = Element.CATEGORIES.CONTAINER,
  fxlist = Element.CATEGORIES.CONTAINER,
  sendlist = Element.CATEGORIES.CONTAINER,
  fxembed = Element.CATEGORIES.CONTAINER,

  -- Size/margin (special)
  size = Element.CATEGORIES.OTHER,
  margin = Element.CATEGORIES.OTHER,
}

-- Get category from element ID
local function get_category(element_id)
  -- Extract the element name (e.g., "mute" from "tcp.mute" or "tcp.mute.color")
  local parts = {}
  for part in element_id:gmatch("[^.]+") do
    parts[#parts + 1] = part
  end

  -- Skip context (tcp, mcp, etc.) and get element name
  local elem_name = parts[2]

  -- Check for sub-element types (.color, .font, .margin, .label)
  if #parts >= 3 then
    local sub_type = parts[3]
    if sub_type == "color" or sub_type == "font" then
      return Element.CATEGORIES.OTHER
    end
    if sub_type == "margin" then
      return Element.CATEGORIES.OTHER
    end
    if sub_type == "label" then
      return Element.CATEGORIES.LABEL
    end
  end

  return CATEGORY_MAP[elem_name] or Element.CATEGORIES.OTHER
end

-- Get display name from element ID
local function get_display_name(element_id)
  -- Remove context prefix and capitalize
  local parts = {}
  for part in element_id:gmatch("[^.]+") do
    parts[#parts + 1] = part
  end

  if #parts >= 2 then
    -- Join all parts except context, capitalize first letters
    local name_parts = {}
    for i = 2, #parts do
      local p = parts[i]
      name_parts[#name_parts + 1] = p:sub(1, 1):upper() .. p:sub(2)
    end
    return table.concat(name_parts, " ")
  end

  return element_id
end

-- Check if element is a special type (.size, .color, .font, .margin)
local function get_element_flags(element_id)
  local flags = {
    is_size = false,
    is_color = false,
    is_font = false,
    is_margin = false,
  }

  if element_id:match("%.size$") then
    flags.is_size = true
  elseif element_id:match("%.color$") then
    flags.is_color = true
  elseif element_id:match("%.font$") then
    flags.is_font = true
  elseif element_id:match("%.margin$") then
    flags.is_margin = true
  end

  return flags
end

-- Evaluate an expression and return the result array
-- @param expr: The expression string (e.g., "+ [10 20] scale")
-- @param context: The evaluation context with variables
-- @return: Array of values, or nil on failure
local function evaluate_expression(expr, context)
  if not expr then return nil end

  -- Check if it's a simple bracket expression first
  local bracket_content = expr:match("^%[([%d%s%-%.]+)%]$")
  if bracket_content then
    local values = {}
    for num in bracket_content:gmatch("[%-%.%d]+") do
      values[#values + 1] = tonumber(num)
    end
    return values
  end

  -- Use the expression evaluator
  return ExpressionEval.evaluate(expr, context)
end

-- Process a variable definition SET statement
-- Updates the context with the computed value
-- @param item: The SET item (element = variable name, value = expression)
-- @param context: The evaluation context to update
-- @return: true if processed successfully
local function process_variable_definition(item, context)
  if not item.element or not item.value then return false end

  local result = evaluate_expression(item.value, context)
  if result and #result > 0 then
    -- Store as array if multiple values, scalar if single
    if #result == 1 then
      context[item.element] = result[1]
    else
      context[item.element] = result
    end
    return true
  end

  return false
end

-- Convert a parsed SET item to an Element
-- @param item: The SET item from parser
-- @param context: The evaluation context with variables
-- Returns element, is_computed (boolean), eval_success (boolean)
local function convert_set_item(item, context)
  if not item.element then
    return nil, false, false
  end

  local flags = get_element_flags(item.element)

  -- Create coordinate from parsed data
  local coords
  local is_computed = not item.is_simple
  local eval_success = false

  if item.is_simple and item.coords then
    -- Simple coordinates - direct mapping
    coords = Coordinate.new({
      x = item.coords[1] or 0,
      y = item.coords[2] or 0,
      w = item.coords[3] or 0,
      h = item.coords[4] or 0,
      ls = item.coords[5] or 0,
      ts = item.coords[6] or 0,
      rs = item.coords[7] or 0,
      bs = item.coords[8] or 0,
    })
    eval_success = true
  else
    -- Try to evaluate the expression using context
    local evaluated = evaluate_expression(item.value, context)

    if evaluated and #evaluated > 0 then
      -- Expression evaluated successfully
      coords = Coordinate.new({
        x = evaluated[1] or 0,
        y = evaluated[2] or 0,
        w = evaluated[3] or 0,
        h = evaluated[4] or 0,
        ls = evaluated[5] or 0,
        ts = evaluated[6] or 0,
        rs = evaluated[7] or 0,
        bs = evaluated[8] or 0,
      })
      eval_success = true

      -- Debug: log elements that evaluate to 0x0 (hidden by conditional)
      local is_visual_id = item.element:match("^tcp%.[^.]+$") and
                          not item.element:match("%.color$") and
                          not item.element:match("%.font$") and
                          not item.element:match("%.margin$")
      if is_visual_id and evaluated[3] == 0 and evaluated[4] == 0 then
        Console.warn("  HIDDEN %s: expr='%s'", item.element, item.value or "?")
      end

      -- Also store element coordinates in context for self-references
      -- (e.g., tcp.solo references tcp.mute{3})
      context[item.element] = evaluated
    else
      -- Evaluation failed - use placeholder coords
      coords = Coordinate.new({
        x = 0, y = 0, w = 20, h = 20,
        ls = 0, ts = 0, rs = 0, bs = 0,
      })
    end
  end

  -- Check if this is a custom element (not in default definitions)
  local is_custom = TCPElements.get_definition(item.element) == nil

  local element = Element.new({
    id = item.element,
    name = get_display_name(item.element),
    category = get_category(item.element),
    coords = coords,
    visible = true,
    is_size = flags.is_size,
    is_color = flags.is_color,
    is_font = flags.is_font,
    is_margin = flags.is_margin,
    is_custom = is_custom,
    description = item.comment or "",
  })

  -- Return whether this was computed and whether eval succeeded
  return element, is_computed, eval_success
end

-- Convert a parsed CLEAR item to an Element (invisible)
local function convert_clear_item(item)
  if not item.element then
    return nil
  end

  -- Handle wildcards (e.g., "clear tcp.*") - skip these
  if item.element:match("%*") then
    return nil
  end

  local flags = get_element_flags(item.element)

  -- Check if this is a custom element (not in default definitions)
  local is_custom = TCPElements.get_definition(item.element) == nil

  local element = Element.new({
    id = item.element,
    name = get_display_name(item.element),
    category = get_category(item.element),
    coords = Coordinate.new(),  -- Empty coords
    visible = false,  -- Cleared = invisible
    is_size = flags.is_size,
    is_color = flags.is_color,
    is_font = flags.is_font,
    is_margin = flags.is_margin,
    is_custom = is_custom,
  })

  return element
end

-- Group to child elements mapping
-- Groups in flow macros contain these tcp.* child elements
local FLOW_GROUP_CHILDREN = {
  pan_group = { "tcp.pan", "tcp.width" },
  fx_group = { "tcp.fx" },
  input_group = { "tcp.recinput" },
  master_pan_group = { "master.tcp.pan", "master.tcp.width" },
  master_fx_group = { "master.tcp.fx" },
}

-- Check if a flow element should be hidden based on its hide_cond/hide_val
-- @param flow_params: Array of parameters from then statement [width, row_flag, row_val, hide_cond, hide_val]
-- @param eval_context: The evaluation context with variable values
-- @return: true if element should be hidden
local function check_flow_hide_condition(flow_params, eval_context)
  if not flow_params or #flow_params < 5 then
    return false  -- No hide condition
  end

  local hide_cond = flow_params[4]
  local hide_val = flow_params[5]

  -- Skip if no condition (0 means no condition)
  if hide_cond == "0" then
    return false
  end

  -- Handle negated conditions (!var means hide when var is truthy)
  local negated = false
  if hide_cond:sub(1, 1) == "!" then
    negated = true
    hide_cond = hide_cond:sub(2)
  end

  -- Get the variable value from context
  local cond_value = eval_context[hide_cond]
  if cond_value == nil then
    return false  -- Unknown variable, don't hide
  end

  -- Get scalar value if it's an array
  if type(cond_value) == "table" then
    cond_value = cond_value[1] or 0
  end

  -- Compare with hide_val
  local target_val = tonumber(hide_val) or 0
  local should_hide = (cond_value == target_val)

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
local function calculate_flow_positions(result, eval_context)
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

  -- Helper to get scalar value (some context vars are arrays)
  local function get_scalar(val, default)
    if val == nil then return default end
    if type(val) == "table" then return val[1] or default end
    return val
  end

  -- Determine starting X position
  -- Flow elements typically start after the meter section
  local meter_sec = get_scalar(eval_context.meter_sec, 50)
  local tcp_padding = get_scalar(eval_context.tcp_padding, 7)
  local start_x = meter_sec + tcp_padding

  -- Element dimensions
  local element_h = get_scalar(eval_context.element_h, 20)
  local row_gap = 2  -- Gap between rows

  -- Track current position (multi-row support)
  local current_x = start_x
  local current_row = 0
  local current_y = tcp_padding

  local positioned_count = 0
  local hidden_count = 0

  Console.info("Flow layout: starting at x=%d, y=%d, %d elements", start_x, current_y, #flow_elements)

  for _, entry in ipairs(flow_elements) do
    local elem = entry.element
    local coords = elem.coords
    local elem_id = elem.id
    local flow_params = entry.flow_params

    -- Check hide condition from flow params
    if check_flow_hide_condition(flow_params, eval_context) then
      -- Hide this element (set to 0 size)
      coords.w = 0
      coords.h = 0
      elem.visible = false
      hidden_count = hidden_count + 1
      Console.info("  Flow HIDDEN: %s (hide_cond=%s)", elem_id, flow_params[4] or "?")
      goto continue
    end

    -- Check for row change (row_flag is param 2, row_val is param 3)
    if flow_params and #flow_params >= 2 then
      local row_flag = tonumber(flow_params[2]) or 0
      if row_flag == 1 then
        -- Move to next row
        current_row = current_row + 1
        current_x = start_x  -- Reset X to start
        current_y = tcp_padding + (current_row * (element_h + row_gap))
        Console.info("  Flow ROW %d: y=%d", current_row, current_y)
      end
    end

    -- Check if this is a group that should expand to children
    local children = FLOW_GROUP_CHILDREN[elem_id]
    if children then
      -- Position each child element at current X
      local group_width = coords.w or 0
      Console.info("  Flow group: %s (w=%d) -> children: %s", elem_id, group_width, table.concat(children, ", "))

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
          Console.info("    Child positioned: %s at x=%d, y=%d (w=%d)", child_id, child_coords.x, child_coords.y, child_coords.w or 0)
          positioned_count = positioned_count + 1
        end
      end

      -- Advance X by group width
      if group_width > 0 then
        current_x = current_x + group_width + 2
      end

    elseif elem_id:match("^tcp%.") or elem_id:match("^master%.tcp%.") then
      -- Direct tcp.* element - position it
      coords.x = current_x
      coords.y = current_y
      if (coords.h or 0) == 0 then
        coords.h = element_h
      end

      -- Get flow width from flow_params if element width is 0
      local elem_width = coords.w or 0
      if elem_width == 0 and flow_params and flow_params[1] then
        -- Try to evaluate the width from the flow parameter
        local width_var = flow_params[1]
        local width_val = tonumber(width_var)
        if not width_val then
          -- Try to look up as a variable
          width_val = get_scalar(eval_context[width_var], 0)
        end
        if width_val and width_val > 0 then
          coords.w = width_val
          elem_width = width_val
          Console.info("  Flow width from param: %s = %d", width_var, elem_width)
        end
      end

      -- Advance X by element width (plus small gap)
      if elem_width > 0 then
        current_x = current_x + elem_width + 2  -- 2px gap between elements
        positioned_count = positioned_count + 1
        Console.info("  Flow positioned: %s at x=%d, y=%d (w=%d)", elem_id, coords.x, coords.y, elem_width)
      end
    end

    ::continue::
  end

  if positioned_count > 0 or hidden_count > 0 then
    Console.success("Flow layout complete: positioned %d elements, hidden %d (rows: %d)", positioned_count, hidden_count, current_row + 1)
  end
end

-- Convert all elements from a section or layout items list
-- Returns: { elements = {...}, computed_count = n, simple_count = n, eval_success = n, eval_failed = n }
local function convert_items(items, context_filter)
  Console.info("Converting %d items with filter '%s'", #items, context_filter or "none")

  local result = {
    elements = {},
    computed_count = 0,
    simple_count = 0,
    cleared_count = 0,
    eval_success_count = 0,
    eval_failed_count = 0,
    variable_count = 0,
  }

  -- Initialize evaluation context from defaults
  -- Initialize eval context from defaults, then apply custom overrides
  local eval_context = {}
  for k, v in pairs(DEFAULT_CONTEXT) do
    eval_context[k] = v
  end
  -- Apply custom context overrides
  for k, v in pairs(custom_context) do
    eval_context[k] = v
  end

  local set_count = 0
  local matched_count = 0
  local seen_ids = {}  -- Track seen element IDs -> index in result.elements
  local duplicate_count = 0
  local replaced_count = 0
  local sample_non_matching = {}  -- Sample of elements that didn't match filter

  for _, item in ipairs(items) do
    if item.type == RtconfigParser.TOKEN.SET then
      set_count = set_count + 1

      -- Check if this is a variable definition (no dot in name)
      if is_variable_definition(item.element) then
        -- Process variable and add to context
        if process_variable_definition(item, eval_context) then
          result.variable_count = result.variable_count + 1
        end
        -- Continue to next item - variables are not visual elements
        goto continue
      end

      -- Filter by context if specified
      local matches_context = true
      if context_filter then
        matches_context = item.element and item.element:match("^" .. context_filter .. "%.")
        -- Also allow flow groups (pan_group, fx_group, input_group) for layout calculation
        if not matches_context and item.is_flow_element and FLOW_GROUP_CHILDREN[item.element] then
          matches_context = true
        end
      end

      if matches_context then
        matched_count = matched_count + 1

        -- Check for duplicate element IDs
        local existing_idx = seen_ids[item.element]
        if existing_idx then
          -- Flow elements REPLACE existing definitions (they have proper widths)
          if item.is_flow_element then
            local element, is_computed, eval_success = convert_set_item(item, eval_context)
            if element then
              result.elements[existing_idx] = {
                element = element,
                is_computed = is_computed,
                eval_success = eval_success,
                source_line = item.line,
                raw_value = item.value,
                is_flow_element = true,
                flow_params = item.flow_params,
              }
              replaced_count = replaced_count + 1
              Console.info("  REPLACED %s with flow element (w=%d)", item.element, element.coords.w or 0)
            end
          else
            duplicate_count = duplicate_count + 1
            -- Skip duplicate - keep first occurrence
          end
        else
          local element, is_computed, eval_success = convert_set_item(item, eval_context)
          if element then
            local status = "simple"
            if is_computed then
              status = eval_success and "eval OK" or "eval FAIL"
              -- Log failed expressions for debugging
              if not eval_success then
                Console.warn("  FAILED EXPR for %s: %s", item.element, item.value or "(nil)")
              end
            end
            -- Only log attachment values if non-zero
            local attach_str = ""
            local c = element.coords
            if c.ls ~= 0 or c.ts ~= 0 or c.rs ~= 0 or c.bs ~= 0 then
              attach_str = string.format(" attach=[%.0f %.0f %.0f %.0f]", c.ls, c.ts, c.rs, c.bs)
            end
            Console.info("  + %s [%s] coords: x=%.0f y=%.0f w=%.0f h=%.0f%s",
              element.id,
              status,
              c.x, c.y, c.w, c.h, attach_str)
            result.elements[#result.elements + 1] = {
              element = element,
              is_computed = is_computed,
              eval_success = eval_success,
              source_line = item.line,
              raw_value = item.value,
              is_flow_element = item.is_flow_element or false,
              flow_params = item.flow_params,
            }
            -- Store index for duplicate detection
            seen_ids[item.element] = #result.elements
            if is_computed then
              result.computed_count = result.computed_count + 1
              if eval_success then
                result.eval_success_count = result.eval_success_count + 1
              else
                result.eval_failed_count = result.eval_failed_count + 1
              end
            else
              result.simple_count = result.simple_count + 1
            end
          end
        end
      else
        -- Log a sample of non-matching elements for debugging
        if #sample_non_matching < 10 and item.element then
          sample_non_matching[#sample_non_matching + 1] = item.element
        end
      end

      ::continue::

    elseif item.type == RtconfigParser.TOKEN.CLEAR then
      -- Filter by context if specified
      local matches_context = true
      if context_filter then
        matches_context = item.element:match("^" .. context_filter .. "%.") or
                         item.element:match("^" .. context_filter .. ".%*")
      end

      if matches_context then
        local element = convert_clear_item(item)
        if element then
          result.elements[#result.elements + 1] = {
            element = element,
            is_computed = false,
            is_cleared = true,
            source_line = item.line,
          }
          result.cleared_count = result.cleared_count + 1
        end
      end
    end
  end

  -- Log summary with deduplication info
  Console.success("Conversion complete: %d SET items, %d variables processed, %d matched context, %d unique elements (%d duplicates skipped, %d replaced by flow)",
    set_count, result.variable_count, matched_count, #result.elements, duplicate_count, replaced_count)
  Console.info("  Simple: %d | Computed: %d (eval OK: %d, eval FAIL: %d) | Cleared: %d",
    result.simple_count, result.computed_count, result.eval_success_count, result.eval_failed_count, result.cleared_count)

  -- Log sample of non-matching elements to help debug
  if #sample_non_matching > 0 then
    Console.info("  Sample of non-matching SET elements: %s", table.concat(sample_non_matching, ", "))
  end

  -- Calculate positions for flow layout elements
  calculate_flow_positions(result, eval_context)

  return result
end

-- Recursively collect items from all layouts
local function collect_layout_items(layouts, all_items)
  for _, layout in ipairs(layouts) do
    for _, item in ipairs(layout.items) do
      all_items[#all_items + 1] = item
    end
    if layout.children then
      collect_layout_items(layout.children, all_items)
    end
  end
end

-- Parse a macro body line to extract SET items
-- Macro bodies are stored as raw text, so we need to re-parse them
local function parse_macro_body_item(body_entry)
  if not body_entry.code then return nil end

  local code = body_entry.code

  -- Try to parse as SET statement
  local element, value = code:match("^%s*set%s+([%w._]+)%s+(.+)$")
  if element and value then
    -- Check if value is a simple coordinate list [x y w h ...]
    local is_simple = false
    local coords = nil

    -- Match simple coordinate: just a bracket expression with numbers
    local bracket_content = value:match("^%[([%d%s%-%.]+)%]$")
    if bracket_content then
      is_simple = true
      coords = {}
      for num in bracket_content:gmatch("[%-%.%d]+") do
        coords[#coords + 1] = tonumber(num)
      end
    end

    return {
      type = RtconfigParser.TOKEN.SET,
      element = element,
      value = value,
      line = body_entry.line,
      is_simple = is_simple,
      coords = coords,
    }
  end

  -- Try to parse as THEN statement (flow layout DSL)
  -- Format: then element_id   width_var   row_flag   row_val   hide_cond   hide_val
  -- Example: then tcp.recarm     OVR.tcp_recarm.width   0   0   0   0
  -- These elements are positioned by the flow layout system, we create placeholder coords
  local then_elem = code:match("^%s*then%s+([%w._]+)")
  if then_elem then
    -- Extract all parameters after element ID
    local params_str = code:match("^%s*then%s+[%w._]+%s+(.*)$") or ""

    -- Parse the parameters (space-separated)
    -- Typical format: width_var row_flag row_val hide_condition hide_val
    local params = {}
    for param in params_str:gmatch("%S+") do
      params[#params + 1] = param
    end

    -- Build a synthetic expression for the element
    -- The width comes from the first parameter (e.g., OVR.tcp_recarm.width)
    -- For now, create a placeholder that references the width variable
    local width_var = params[1] or "20"
    local value_expr

    -- Check if width_var looks like a variable reference or a number
    if width_var:match("^[%d%-%.]+$") then
      -- It's a number, create simple coords
      value_expr = string.format("[0 0 %s 20]", width_var)
    else
      -- It's a variable reference, create expression that uses it
      -- Flow elements typically have height from context and width from variable
      value_expr = string.format("[0 0 %s element_h]", width_var)
    end

    return {
      type = RtconfigParser.TOKEN.SET,
      element = then_elem,
      value = value_expr,
      line = body_entry.line,
      is_simple = false,
      coords = nil,
      is_flow_element = true,  -- Mark as flow-positioned
      flow_params = params,     -- Keep original params for debugging
    }
  end

  -- Try to parse as CLEAR statement
  local clear_elem = code:match("^%s*clear%s+([%w._*]+)%s*$")
  if clear_elem then
    return {
      type = RtconfigParser.TOKEN.CLEAR,
      element = clear_elem,
      line = body_entry.line,
    }
  end

  return nil
end

-- Collect items from macro bodies (where many TCP elements are defined!)
-- Handles line continuations (lines ending with \)
local function collect_macro_items(macros, all_items)
  local macro_items = 0
  local flow_items = 0

  for _, macro in ipairs(macros) do
    local i = 1
    while i <= #macro.body do
      local body_entry = macro.body[i]
      local code = body_entry.code or ""
      local line_num = body_entry.line

      -- Handle line continuations: join lines ending with \
      while code:match("\\%s*$") and i < #macro.body do
        -- Remove the trailing backslash and whitespace
        code = code:gsub("\\%s*$", " ")
        -- Get next line
        i = i + 1
        local next_entry = macro.body[i]
        if next_entry then
          -- Append next line's code (trim leading whitespace for cleaner join)
          local next_code = (next_entry.code or ""):gsub("^%s+", "")
          code = code .. next_code
        end
      end

      -- Parse the (possibly joined) line
      local item = parse_macro_body_item({ code = code, line = line_num })
      if item then
        all_items[#all_items + 1] = item
        macro_items = macro_items + 1

        -- Log flow elements for debugging
        if item.is_flow_element then
          flow_items = flow_items + 1
          Console.info("  FLOW: %s from '%s' (width=%s)",
            item.element, macro.name, item.flow_params and item.flow_params[1] or "?")
        end
      end

      i = i + 1
    end
  end

  if flow_items > 0 then
    Console.info("Found %d flow elements (then statements) in macros", flow_items)
  end

  return macro_items
end

-- Convert elements from a specific layout
-- @param parsed: The parsed rtconfig result
-- @param layout_name: Name of the layout to convert (nil = all sections + layouts)
-- @param context: Filter by context (e.g., "tcp", "mcp") or nil for all
-- @return table with elements and stats
function M.convert_layout(parsed, layout_name, context)
  if not parsed then
    return nil, "No parsed rtconfig provided"
  end

  -- If no layout specified, collect from ALL sections, macros, AND layouts
  if not layout_name then
    local all_items = {}

    -- Collect from sections first (contains variable definitions needed by flow elements)
    local section_items = 0
    for _, section in ipairs(parsed.sections) do
      for _, item in ipairs(section.items) do
        all_items[#all_items + 1] = item
        section_items = section_items + 1
      end
    end
    Console.info("Collected %d items from %d sections", section_items, #parsed.sections)

    -- Collect from macro bodies (flow elements will REPLACE section duplicates)
    local macro_items = collect_macro_items(parsed.macros, all_items)
    Console.info("Collected %d items from %d macros", macro_items, #parsed.macros)

    -- Also collect from all layouts
    local before_layouts = #all_items
    collect_layout_items(parsed.layouts, all_items)
    Console.info("Collected %d items from layouts (total: %d)", #all_items - before_layouts, #all_items)

    return convert_items(all_items, context)
  end

  -- Find the specified layout
  local function find_layout(layouts, name)
    for _, layout in ipairs(layouts) do
      if layout.name == name then
        return layout
      end
      if layout.children then
        local found = find_layout(layout.children, name)
        if found then return found end
      end
    end
    return nil
  end

  local layout = find_layout(parsed.layouts, layout_name)
  if not layout then
    return nil, "Layout '" .. layout_name .. "' not found"
  end

  return convert_items(layout.items, context)
end

-- Convert all TCP elements from parsed rtconfig (global + layouts merged)
-- This gives a "flattened" view suitable for visualization
function M.convert_tcp_elements(parsed)
  return M.convert_layout(parsed, nil, "tcp")
end

-- Convert all MCP elements from parsed rtconfig
function M.convert_mcp_elements(parsed)
  return M.convert_layout(parsed, nil, "mcp")
end

-- Get list of available layouts for a context
function M.get_layouts_for_context(parsed, context)
  local layouts = {}

  local function scan_layout(layout)
    -- Check if this layout has items for the context
    local has_context_items = false
    for _, item in ipairs(layout.items) do
      if item.element and item.element:match("^" .. context .. "%.") then
        has_context_items = true
        break
      end
    end

    if has_context_items or #layout.items == 0 then
      -- Include layouts that might inherit context items
      layouts[#layouts + 1] = {
        name = layout.name,
        dpi = layout.dpi,
        item_count = #layout.items,
      }
    end

    -- Recurse into children
    if layout.children then
      for _, child in ipairs(layout.children) do
        scan_layout(child)
      end
    end
  end

  for _, layout in ipairs(parsed.layouts) do
    scan_layout(layout)
  end

  return layouts
end

-- Get conversion stats from a result
function M.get_stats(result)
  if not result then
    return { total = 0, simple = 0, computed = 0, cleared = 0 }
  end

  return {
    total = #result.elements,
    simple = result.simple_count,
    computed = result.computed_count,
    cleared = result.cleared_count,
  }
end

-- Check if an element is a visual element (should be rendered on canvas)
-- Non-visual elements: .color, .font, .margin (these are styling, not layout)
local function is_visual_element(element, force_visible)
  local id = element.id or ""
  local coords = element.coords

  -- Filter out styling elements (not positioned on canvas) - always filter these
  if id:match("%.color$") or id:match("%.color%.") then
    return false
  end
  if id:match("%.font$") or id:match("%.font%.") then
    return false
  end
  if id:match("%.margin$") then
    return false
  end
  if id:match("%.fadermode$") then
    return false  -- Fader mode flags, not visual
  end
  if id:match("%.visflags$") then
    return false  -- Visibility flags, not visual
  end

  -- Keep .size elements - they define container bounds
  if id:match("%.size$") then
    return true
  end

  -- Force visible mode: show all positioned elements regardless of size
  if force_visible then
    return true
  end

  -- Keep elements with attachment scaling (they stretch with parent)
  -- If rs > ls or bs > ts, the element has width/height from attachment
  local has_h_stretch = (coords.rs or 0) > (coords.ls or 0)
  local has_v_stretch = (coords.bs or 0) > (coords.ts or 0)

  if has_h_stretch or has_v_stretch then
    return true  -- Element stretches with parent
  end

  -- Filter elements with no valid size (0x0 and no stretching)
  if coords.w <= 0 and coords.h <= 0 then
    return false  -- Zero-size non-container elements aren't visual
  end

  return true
end

-- Extract just the Element objects (for loading into State)
-- @param result: The conversion result from convert_layout
-- @param opts: Options table:
--   include_computed: Whether to include computed elements (default: true)
--   include_cleared: Whether to include cleared elements (default: false)
--   filter_non_visual: Whether to filter out .color/.font/.margin (default: true)
--   force_visible: Show all elements regardless of size (default: false)
function M.extract_elements(result, opts)
  if not result then return {} end

  opts = opts or {}
  local include_computed = opts.include_computed ~= false
  local include_cleared = opts.include_cleared or false
  local filter_non_visual = opts.filter_non_visual ~= false
  local force_visible = opts.force_visible or false

  local elements = {}
  local filtered_count = 0

  for _, entry in ipairs(result.elements) do
    local include = true

    if entry.is_computed and not include_computed then
      include = false
    end
    if entry.is_cleared and not include_cleared then
      include = false
    end

    -- Filter non-visual elements (colors, fonts, margins)
    if include and filter_non_visual and not is_visual_element(entry.element, force_visible) then
      include = false
      filtered_count = filtered_count + 1
    end

    if include then
      elements[#elements + 1] = entry.element
    end
  end

  if filtered_count > 0 then
    Console.info("Filtered %d non-visual elements (color/font/margin/zero-size)", filtered_count)
  end

  return elements
end

-- Get default context value for a key
function M.get_default_context_value(key)
  return DEFAULT_CONTEXT[key]
end

-- Get custom context value (returns override or default)
function M.get_context_value(key)
  if custom_context[key] ~= nil then
    return custom_context[key]
  end
  return DEFAULT_CONTEXT[key]
end

-- Set custom context value
function M.set_context_value(key, value)
  if value == DEFAULT_CONTEXT[key] then
    custom_context[key] = nil  -- Remove override if it matches default
  else
    custom_context[key] = value
  end
end

-- Reset all custom context values to defaults
function M.reset_context()
  custom_context = {}
end

-- Get list of context variables that can be controlled via UI
-- Returns list of { key, label, type, default, min, max }
function M.get_controllable_context_vars()
  return {
    -- Dimensions
    { key = "w", label = "Track Width", type = "int", default = 400, min = 100, max = 800 },
    { key = "h", label = "Track Height", type = "int", default = 150, min = 40, max = 300 },
    { key = "scale", label = "DPI Scale", type = "float", default = 1.0, min = 0.5, max = 2.0 },

    -- Flow element widths
    { key = "tcp_LabelSize", label = "Label Width", type = "int", default = 80, min = 0, max = 200 },
    { key = "tcp_VolSize", label = "Volume Width", type = "int", default = 50, min = 0, max = 100 },
    { key = "tcp_PanSize", label = "Pan Width", type = "int", default = 40, min = 0, max = 100 },

    -- Visibility toggles
    { key = "hide_mute_group", label = "Hide Mute/Solo", type = "bool", default = 0 },
    { key = "hide_fx_group", label = "Hide FX", type = "bool", default = 0 },
    { key = "hide_pan_group", label = "Hide Pan", type = "bool", default = 0 },
    { key = "hide_volume_group", label = "Hide Volume", type = "bool", default = 0 },
    { key = "hide_io_group", label = "Hide I/O", type = "bool", default = 0 },
    { key = "hide_recarm_group", label = "Hide Record Arm", type = "bool", default = 0 },
    { key = "hide_label_group", label = "Hide Label", type = "bool", default = 0 },

    -- Track state
    { key = "is_solo_flipped", label = "Solo Flipped", type = "bool", default = 0 },
    { key = "recarm", label = "Record Armed", type = "bool", default = 1 },
    { key = "track_selected", label = "Track Selected", type = "bool", default = 1 },
    { key = "folderstate", label = "Is Folder", type = "bool", default = 0 },
  }
end

-- Check if context has been modified from defaults
function M.is_context_modified()
  for k, v in pairs(custom_context) do
    if v ~= nil then
      return true
    end
  end
  return false
end

return M

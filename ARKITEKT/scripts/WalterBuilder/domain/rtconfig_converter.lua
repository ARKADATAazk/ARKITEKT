-- @noindex
-- WalterBuilder/domain/rtconfig_converter.lua
-- Converts parsed rtconfig AST to WalterBuilder Element models
--
-- This bridges the gap between:
--   - RtconfigParser output (AST with set/clear/front statements)
--   - Element model (our visual representation)
--
-- Split into submodules:
--   - eval_context.lua: Context/variable management
--   - element_factory.lua: Element creation and classification
--   - flow_layout.lua: Flow positioning logic

local RtconfigParser = require('WalterBuilder.domain.rtconfig_parser')
local ExpressionEval = require('WalterBuilder.domain.expression_eval')
local EvalContext = require('WalterBuilder.domain.eval_context')
local ElementFactory = require('WalterBuilder.domain.element_factory')
local FlowLayout = require('WalterBuilder.domain.flow_layout')

local M = {}

-- Enable expression debug mode for troubleshooting
-- Set to true to trace meter/mute/solo expression evaluation
M.DEBUG_EXPRESSIONS = false

-- Logger callback (set by UI layer if desired)
-- Signature: fn(level, format, ...) where level is 'info', 'warn', 'error', 'success'
M.logger = nil

-- Internal logging helper
local function log(level, fmt, ...)
  if M.logger then
    M.logger(level, fmt, ...)
  end
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

-- Evaluate an expression and return the result array
-- @param expr: The expression string (e.g., '+ [10 20] scale')
-- @param context: The evaluation context with variables
-- @param element_name: Optional element name for debug logging
-- @return: Array of values, or nil on failure
local function evaluate_expression(expr, context, element_name)
  if not expr then return nil end

  -- Check if it's a simple bracket expression first
  local bracket_content = expr:match('^%[([%d%s%-%.]+)%]$')
  if bracket_content then
    local values = {}
    for num in bracket_content:gmatch('[%-%.%d]+') do
      values[#values + 1] = tonumber(num)
    end
    return values
  end

  -- Debug: trace specific elements
  local trace_this = M.DEBUG_EXPRESSIONS and element_name and (
    element_name == 'tcp.meter' or
    element_name == 'tcp.mute' or
    element_name == 'tcp.solo' or
    element_name == 'meter_sec' or
    element_name == 'is_solo_flipped'
  )

  if trace_this then
    log('info', '>>> EXPR DEBUG: %s', element_name)
    log('info', '    expr: %s', expr:sub(1, 100))
    log('info', '    context.meter_sec = %s', fmt_arr(context.meter_sec))
    log('info', '    context.is_solo_flipped = %s', tostring(context.is_solo_flipped))
  end

  -- Use the expression evaluator
  local result = ExpressionEval.evaluate(expr, context)

  if trace_this then
    log('info', '    result = %s', fmt_arr(result))
  end

  return result
end

-- Process a variable definition SET statement
-- Updates the context with the computed value
-- @param item: The SET item (element = variable name, value = expression)
-- @param context: The evaluation context to update
-- @return: true if processed successfully
local function process_variable_definition(item, context)
  if not item.element or not item.value then return false end

  local result = evaluate_expression(item.value, context, item.element)
  if result and #result > 0 then
    -- Store as array if multiple values, scalar if single
    if #result == 1 then
      context[item.element] = result[1]
    else
      context[item.element] = result
    end

    -- Debug: log meter_sec computation
    if M.DEBUG_EXPRESSIONS and item.element == 'meter_sec' then
      log('warn', 'SET meter_sec = %s', fmt_arr(context[item.element]))
    end

    return true
  end

  return false
end

-- Parse a macro body line to extract SET items
-- Macro bodies are stored as raw text, so we need to re-parse them
local function parse_macro_body_item(body_entry)
  if not body_entry.code then return nil end

  local code = body_entry.code

  -- Try to parse as SET statement
  local element, value = code:match('^%s*set%s+([%w._]+)%s+(.+)$')
  if element and value then
    -- Check if value is a simple coordinate list [x y w h ...]
    local is_simple = false
    local coords = nil

    -- Match simple coordinate: just a bracket expression with numbers
    local bracket_content = value:match('^%[([%d%s%-%.]+)%]$')
    if bracket_content then
      is_simple = true
      coords = {}
      for num in bracket_content:gmatch('[%-%.%d]+') do
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
  local then_elem = code:match('^%s*then%s+([%w._]+)')
  if then_elem then
    -- Extract all parameters after element ID
    local params_str = code:match('^%s*then%s+[%w._]+%s+(.*)$') or ''

    -- Parse the parameters (space-separated)
    -- Typical format: width_var row_flag row_val hide_condition hide_val
    local params = {}
    for param in params_str:gmatch('%S+') do
      params[#params + 1] = param
    end

    -- Build a synthetic expression for the element
    -- The width comes from the first parameter (e.g., OVR.tcp_recarm.width)
    -- For now, create a placeholder that references the width variable
    local width_var = params[1] or '20'
    local value_expr

    -- Check if width_var looks like a variable reference or a number
    if width_var:match('^[%d%-%.]+$') then
      -- It's a number, create simple coords
      value_expr = string.format('[0 0 %s 20]', width_var)
    else
      -- It's a variable reference, create expression that uses it
      -- Flow elements typically have height from context and width from variable
      value_expr = string.format('[0 0 %s element_h]', width_var)
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
  local clear_elem = code:match('^%s*clear%s+([%w._*]+)%s*$')
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
      local code = body_entry.code or ''
      local line_num = body_entry.line

      -- Handle line continuations: join lines ending with \
      while code:match('\\%s*$') and i < #macro.body do
        -- Remove the trailing backslash and whitespace
        code = code:gsub('\\%s*$', ' ')
        -- Get next line
        i = i + 1
        local next_entry = macro.body[i]
        if next_entry then
          -- Append next line's code (trim leading whitespace for cleaner join)
          local next_code = (next_entry.code or ''):gsub('^%s+', '')
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
          log('info', '  FLOW: %s from \'%s\' (width=%s)',
            item.element, macro.name, item.flow_params and item.flow_params[1] or '?')
        end
      end

      i = i + 1
    end
  end

  if flow_items > 0 then
    log('info', 'Found %d flow elements (then statements) in macros', flow_items)
  end

  return macro_items
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

-- Convert all elements from a section or layout items list
-- Returns: { elements = {...}, computed_count = n, simple_count = n, eval_success = n, eval_failed = n }
local function convert_items(items, context_filter)
  log('info', 'Converting %d items with filter \'%s\'', #items, context_filter or 'none')

  local result = {
    elements = {},
    computed_count = 0,
    simple_count = 0,
    cleared_count = 0,
    eval_success_count = 0,
    eval_failed_count = 0,
    variable_count = 0,
  }

  -- Build evaluation context from defaults + custom overrides
  local eval_context = EvalContext.build_eval_context()

  local set_count = 0
  local matched_count = 0
  local seen_ids = {}  -- Track seen element IDs -> index in result.elements
  local duplicate_count = 0
  local replaced_count = 0
  local sample_non_matching = {}  -- Sample of elements that didn't match filter

  for _, item in ipairs(items) do
    if item.type == RtconfigParser.TOKEN.SET then
      set_count = set_count + 1

      -- Check if this is a flow group (pan_group, fx_group, etc.)
      -- Flow groups need to be processed as elements, not variables, even though they don't have dots
      local is_flow_group = item.is_flow_element and FlowLayout.FLOW_GROUP_CHILDREN[item.element]

      -- Check if this is a variable definition (no dot in name)
      -- Skip this check for flow groups - they should be processed as elements
      if not is_flow_group and ElementFactory.is_variable_definition(item.element) then
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
        matches_context = item.element and item.element:match('^' .. context_filter .. '%.')
        -- Also allow flow groups (pan_group, fx_group, input_group) for layout calculation
        if not matches_context and is_flow_group then
          matches_context = true
        end
      end

      if matches_context then
        matched_count = matched_count + 1

        -- Check for duplicate element IDs
        local existing_idx = seen_ids[item.element]
        if existing_idx then
          local original_entry = result.elements[existing_idx]

          -- Flow elements REPLACE existing definitions (they have proper widths)
          if item.is_flow_element then
            local element, is_computed, eval_success = ElementFactory.convert_set_item(item, eval_context, evaluate_expression, log)
            if element then
              -- Preserve source_line ONLY if replacing another flow element (duplicate in macro)
              -- Otherwise use the flow element's line number to maintain macro order
              local use_source_line = item.line  -- Default: use macro line number
              if original_entry.is_flow_element then
                -- Replacing flow with flow: preserve first occurrence line
                use_source_line = original_entry.source_line
              end
              -- else: replacing section element with flow: use macro line (item.line)

              result.elements[existing_idx] = {
                element = element,
                is_computed = is_computed,
                eval_success = eval_success,
                source_line = use_source_line,
                raw_value = item.value,
                is_flow_element = true,
                flow_params = item.flow_params,
              }
              replaced_count = replaced_count + 1
              log('info', '  REPLACED %s with flow element (w=%d)', item.element, element.coords.w or 0)
            end
          -- Non-flow SET can REPLACE flow elements (e.g., drawTcp overrides calcTcpFlow)
          -- BUT only if the SET evaluation succeeds (otherwise keep flow position)
          elseif original_entry.is_flow_element then
            local element, is_computed, eval_success = ElementFactory.convert_set_item(item, eval_context, evaluate_expression, log)
            if element and (not is_computed or eval_success) then
              -- Only replace if: simple coords OR expression evaluated successfully
              result.elements[existing_idx] = {
                element = element,
                is_computed = is_computed,
                eval_success = eval_success,
                source_line = item.line,  -- Use new SET line
                raw_value = item.value,
                is_flow_element = false,
                flow_params = nil,
              }
              replaced_count = replaced_count + 1
              log('info', '  REPLACED flow %s with SET statement', item.element)
            else
              -- SET evaluation failed, keep flow element
              duplicate_count = duplicate_count + 1
              if is_computed and not eval_success then
                log('info', '  KEPT flow %s (SET expr failed)', item.element)
              end
            end
          else
            duplicate_count = duplicate_count + 1
            -- Skip duplicate - keep first occurrence
          end
        else
          local element, is_computed, eval_success = ElementFactory.convert_set_item(item, eval_context, evaluate_expression, log)
          if element then
            local status = 'simple'
            if is_computed then
              status = eval_success and 'eval OK' or 'eval FAIL'
              -- Log failed expressions for debugging
              if not eval_success then
                log('warn', '  FAILED EXPR for %s: %s', item.element, item.value or '(nil)')
              end
            end
            -- Only log attachment values if non-zero
            local attach_str = ''
            local c = element.coords
            if c.ls ~= 0 or c.ts ~= 0 or c.rs ~= 0 or c.bs ~= 0 then
              attach_str = string.format(' attach=[%.0f %.0f %.0f %.0f]', c.ls, c.ts, c.rs, c.bs)
            end
            log('info', '  + %s [%s] coords: x=%.0f y=%.0f w=%.0f h=%.0f%s',
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
        matches_context = item.element:match('^' .. context_filter .. '%.') or
                         item.element:match('^' .. context_filter .. '.%*')
      end

      if matches_context then
        local element = ElementFactory.convert_clear_item(item)
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
  log('success', 'Conversion complete: %d SET items, %d variables processed, %d matched context, %d unique elements (%d duplicates skipped, %d replaced by flow)',
    set_count, result.variable_count, matched_count, #result.elements, duplicate_count, replaced_count)
  log('info', '  Simple: %d | Computed: %d (eval OK: %d, eval FAIL: %d) | Cleared: %d',
    result.simple_count, result.computed_count, result.eval_success_count, result.eval_failed_count, result.cleared_count)

  -- Log sample of non-matching elements to help debug
  if #sample_non_matching > 0 then
    log('info', '  Sample of non-matching SET elements: %s', table.concat(sample_non_matching, ', '))
  end

  -- Calculate positions for flow layout elements
  FlowLayout.calculate_flow_positions(result, eval_context, log)

  return result
end

-- Convert elements from a specific layout
-- @param parsed: The parsed rtconfig result
-- @param layout_name: Name of the layout to convert (nil = all sections + layouts)
-- @param context: Filter by context (e.g., 'tcp', 'mcp') or nil for all
-- @return table with elements and stats
function M.convert_layout(parsed, layout_name, context)
  if not parsed then
    return nil, 'No parsed rtconfig provided'
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
    log('info', 'Collected %d items from %d sections', section_items, #parsed.sections)

    -- Collect from macro bodies (flow elements will REPLACE section duplicates)
    local macro_items = collect_macro_items(parsed.macros, all_items)
    log('info', 'Collected %d items from %d macros', macro_items, #parsed.macros)

    -- Also collect from all layouts
    local before_layouts = #all_items
    collect_layout_items(parsed.layouts, all_items)
    log('info', 'Collected %d items from layouts (total: %d)', #all_items - before_layouts, #all_items)

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
    return nil, 'Layout \'' .. layout_name .. '\' not found'
  end

  return convert_items(layout.items, context)
end

-- Convert all TCP elements from parsed rtconfig (global + layouts merged)
-- This gives a 'flattened' view suitable for visualization
function M.convert_tcp_elements(parsed)
  return M.convert_layout(parsed, nil, 'tcp')
end

-- Convert all MCP elements from parsed rtconfig
function M.convert_mcp_elements(parsed)
  return M.convert_layout(parsed, nil, 'mcp')
end

-- Get list of available layouts for a context
function M.get_layouts_for_context(parsed, context)
  local layouts = {}

  local function scan_layout(layout)
    -- Check if this layout has items for the context
    local has_context_items = false
    for _, item in ipairs(layout.items) do
      if item.element and item.element:match('^' .. context .. '%.') then
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
    if include and filter_non_visual and not ElementFactory.is_visual_element(entry.element, force_visible) then
      include = false
      filtered_count = filtered_count + 1
    end

    if include then
      elements[#elements + 1] = entry.element
    end
  end

  if filtered_count > 0 then
    log('info', 'Filtered %d non-visual elements (color/font/margin/zero-size)', filtered_count)
  end

  return elements
end

--------------------------------------------------------------------------------
-- Public API: Context management (re-exported from EvalContext for backwards compatibility)
--------------------------------------------------------------------------------

-- Get default context value for a key
function M.get_default_context_value(key)
  return EvalContext.get_default_value(key)
end

-- Get custom context value (returns override or default)
function M.get_context_value(key)
  return EvalContext.get_value(key)
end

-- Set custom context value
function M.set_context_value(key, value)
  EvalContext.set_value(key, value)
end

-- Reset all custom context values to defaults
function M.reset_context()
  EvalContext.reset()
end

-- Get list of context variables that can be controlled via UI
function M.get_controllable_context_vars()
  return EvalContext.get_controllable_vars()
end

-- Check if context has been modified from defaults
function M.is_context_modified()
  return EvalContext.is_modified()
end

return M

-- @noindex
-- WalterBuilder/domain/element_factory.lua
-- Element creation and classification for WALTER rtconfig conversion
--
-- Handles:
-- - Element ID classification (variable vs element)
-- - Category mapping (button, fader, label, etc.)
-- - Element creation from SET/CLEAR items
-- - Visual element filtering

local Element = require('WalterBuilder.domain.element')
local Coordinate = require('WalterBuilder.domain.coordinate')
local TCPElements = require('WalterBuilder.config.tcp_elements')

local M = {}

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

-- Check if a SET statement defines a variable (vs an element)
-- Variables: simple names like 'meter_sec', 'tcp_padding'
--            OR dotted names that don't start with element contexts (OVR.*, etc.)
-- Elements: dotted names like 'tcp.mute', 'tcp.pan' (context.element format)
function M.is_variable_definition(element_name)
  -- Simple names without dots are always variables
  if not element_name:match('%.') then
    return true
  end

  -- Dotted names: check if they start with a known element context
  local prefix = element_name:match('^([^.]+)%.')
  if prefix and ELEMENT_CONTEXTS[prefix:lower()] then
    return false  -- It's an element (tcp.mute, mcp.volume, etc.)
  end

  -- Dotted names with unknown prefixes are variables (OVR.*, etc.)
  return true
end

-- Get category from element ID
function M.get_category(element_id)
  -- Extract the element name (e.g., 'mute' from 'tcp.mute' or 'tcp.mute.color')
  local parts = {}
  for part in element_id:gmatch('[^.]+') do
    parts[#parts + 1] = part
  end

  -- Skip context (tcp, mcp, etc.) and get element name
  local elem_name = parts[2]

  -- Check for sub-element types (.color, .font, .margin, .label)
  if #parts >= 3 then
    local sub_type = parts[3]
    if sub_type == 'color' or sub_type == 'font' then
      return Element.CATEGORIES.OTHER
    end
    if sub_type == 'margin' then
      return Element.CATEGORIES.OTHER
    end
    if sub_type == 'label' then
      return Element.CATEGORIES.LABEL
    end
  end

  return CATEGORY_MAP[elem_name] or Element.CATEGORIES.OTHER
end

-- Get display name from element ID
function M.get_display_name(element_id)
  -- Remove context prefix and capitalize
  local parts = {}
  for part in element_id:gmatch('[^.]+') do
    parts[#parts + 1] = part
  end

  if #parts >= 2 then
    -- Join all parts except context, capitalize first letters
    local name_parts = {}
    for i = 2, #parts do
      local p = parts[i]
      name_parts[#name_parts + 1] = p:sub(1, 1):upper() .. p:sub(2)
    end
    return table.concat(name_parts, ' ')
  end

  return element_id
end

-- Check if element is a special type (.size, .color, .font, .margin)
function M.get_element_flags(element_id)
  local flags = {
    is_size = false,
    is_color = false,
    is_font = false,
    is_margin = false,
  }

  if element_id:match('%.size$') then
    flags.is_size = true
  elseif element_id:match('%.color$') then
    flags.is_color = true
  elseif element_id:match('%.font$') then
    flags.is_font = true
  elseif element_id:match('%.margin$') then
    flags.is_margin = true
  end

  return flags
end

-- Convert a parsed SET item to an Element
-- @param item: The SET item from parser
-- @param context: The evaluation context with variables
-- @param evaluate_fn: Function to evaluate expressions: fn(expr, context, element_name) -> array
-- @param log_fn: Optional logging function: fn(level, format, ...) -> nil
-- Returns element, is_computed (boolean), eval_success (boolean)
function M.convert_set_item(item, context, evaluate_fn, log_fn)
  if not item.element then
    return nil, false, false
  end

  log_fn = log_fn or function() end

  local flags = M.get_element_flags(item.element)

  -- Create coordinate from parsed data
  local coords
  local is_computed = not item.is_simple
  local eval_success = false

  -- Special handling for flow items without a value expression
  -- These come from 'then' statements where width is in flow_params[1]
  if item.is_flow_element and (not item.value or item.value == '') and item.flow_params then
    local width_var = item.flow_params[1]
    local width = 0
    if width_var then
      -- Try to parse as number first
      width = tonumber(width_var)
      if not width then
        -- Try to look up as a simple variable
        local val = context[width_var]
        if val then
          if type(val) == 'table' then
            width = val[1] or 0
          else
            width = val
          end
        else
          -- Try to evaluate as an expression (e.g., '* scale 20')
          local evaluated = evaluate_fn(width_var, context, item.element .. '.width')
          if evaluated and #evaluated > 0 then
            width = evaluated[1] or 0
          end
        end
      end
    end
    -- Use fallback widths if still 0
    if width == 0 then
      local FLOW_WIDTH_FALLBACKS = {
        pan_group = 40,
        fx_group = 24,
        input_group = 40,
        master_pan_group = 40,
        master_fx_group = 24,
      }
      width = FLOW_WIDTH_FALLBACKS[item.element] or 20
      log_fn('info', '  Flow item %s: using fallback width=%d', item.element, width)
    end
    local element_h = context.element_h or 20
    if type(element_h) == 'table' then element_h = element_h[1] or 20 end
    coords = Coordinate.new({
      x = 0, y = 0, w = width, h = element_h,
      ls = 0, ts = 0, rs = 0, bs = 0,
    })
    eval_success = true
    log_fn('info', '  Flow item %s: w=%d from flow_params[1]=\'%s\'', item.element, width, width_var or '?')
  elseif item.is_simple and item.coords then
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
    local evaluated = evaluate_fn(item.value, context, item.element)

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
      local is_visual_id = item.element:match('^tcp%.[^.]+$') and
                          not item.element:match('%.color$') and
                          not item.element:match('%.font$') and
                          not item.element:match('%.margin$')
      if is_visual_id and evaluated[3] == 0 and evaluated[4] == 0 then
        log_fn('warn', '  HIDDEN %s: expr=\'%s\'', item.element, item.value or '?')
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
    name = M.get_display_name(item.element),
    category = M.get_category(item.element),
    coords = coords,
    visible = true,
    is_size = flags.is_size,
    is_color = flags.is_color,
    is_font = flags.is_font,
    is_margin = flags.is_margin,
    is_custom = is_custom,
    description = item.comment or '',
  })

  -- Return whether this was computed and whether eval succeeded
  return element, is_computed, eval_success
end

-- Convert a parsed CLEAR item to an Element (invisible)
function M.convert_clear_item(item)
  if not item.element then
    return nil
  end

  -- Handle wildcards (e.g., 'clear tcp.*') - skip these
  if item.element:match('%*') then
    return nil
  end

  local flags = M.get_element_flags(item.element)

  -- Check if this is a custom element (not in default definitions)
  local is_custom = TCPElements.get_definition(item.element) == nil

  local element = Element.new({
    id = item.element,
    name = M.get_display_name(item.element),
    category = M.get_category(item.element),
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

-- Check if an element is a visual element (should be rendered on canvas)
-- Non-visual elements: .color, .font, .margin (these are styling, not layout)
function M.is_visual_element(element, force_visible)
  local id = element.id or ''
  local coords = element.coords

  -- Filter out styling elements (not positioned on canvas) - always filter these
  if id:match('%.color$') or id:match('%.color%.') then
    return false
  end
  if id:match('%.font$') or id:match('%.font%.') then
    return false
  end
  if id:match('%.margin$') then
    return false
  end
  if id:match('%.fadermode$') then
    return false  -- Fader mode flags, not visual
  end
  if id:match('%.visflags$') then
    return false  -- Visibility flags, not visual
  end

  -- Keep .size elements - they define container bounds
  if id:match('%.size$') then
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

return M

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
local Console = require('WalterBuilder.ui.panels.debug_console')

local M = {}

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

-- Convert a parsed SET item to an Element
-- Returns element, is_computed (boolean)
local function convert_set_item(item)
  if not item.element then
    return nil, false
  end

  local flags = get_element_flags(item.element)

  -- Create coordinate from parsed data
  local coords
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
  else
    -- Computed expression - use placeholder coords
    -- Mark as computed for UI to display appropriately
    coords = Coordinate.new({
      x = 0, y = 0, w = 20, h = 20,
      ls = 0, ts = 0, rs = 0, bs = 0,
    })
  end

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
    description = item.comment or "",
  })

  -- Return whether this was computed (for UI to show badge)
  return element, not item.is_simple
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
  })

  return element
end

-- Convert all elements from a section or layout items list
-- Returns: { elements = {...}, computed_count = n, simple_count = n }
local function convert_items(items, context_filter)
  Console.info("Converting %d items with filter '%s'", #items, context_filter or "none")

  local result = {
    elements = {},
    computed_count = 0,
    simple_count = 0,
    cleared_count = 0,
  }

  local set_count = 0
  local matched_count = 0
  local seen_ids = {}  -- Track seen element IDs to deduplicate
  local duplicate_count = 0
  local sample_non_matching = {}  -- Sample of elements that didn't match filter

  for _, item in ipairs(items) do
    if item.type == RtconfigParser.TOKEN.SET then
      set_count = set_count + 1
      -- Filter by context if specified
      local matches_context = true
      if context_filter then
        matches_context = item.element and item.element:match("^" .. context_filter .. "%.")
      end

      if matches_context then
        matched_count = matched_count + 1

        -- Check for duplicate element IDs
        if seen_ids[item.element] then
          duplicate_count = duplicate_count + 1
          -- Skip duplicate - keep first occurrence
        else
          seen_ids[item.element] = true
          local element, is_computed = convert_set_item(item)
          if element then
            Console.info("  + %s [%s] coords: x=%s y=%s w=%s h=%s",
              element.id,
              is_computed and "computed" or "simple",
              element.coords.x, element.coords.y, element.coords.w, element.coords.h)
            result.elements[#result.elements + 1] = {
              element = element,
              is_computed = is_computed,
              source_line = item.line,
              raw_value = item.value,
            }
            if is_computed then
              result.computed_count = result.computed_count + 1
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
  Console.success("Conversion complete: %d SET items, %d matched context, %d unique elements (%d duplicates skipped)",
    set_count, matched_count, #result.elements, duplicate_count)
  Console.info("  Elements: %d simple, %d computed, %d cleared",
    result.simple_count, result.computed_count, result.cleared_count)

  -- Log sample of non-matching elements to help debug
  if #sample_non_matching > 0 then
    Console.info("  Sample of non-matching SET elements: %s", table.concat(sample_non_matching, ", "))
  end

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

-- Convert elements from a specific layout
-- @param parsed: The parsed rtconfig result
-- @param layout_name: Name of the layout to convert (nil = all sections + layouts)
-- @param context: Filter by context (e.g., "tcp", "mcp") or nil for all
-- @return table with elements and stats
function M.convert_layout(parsed, layout_name, context)
  if not parsed then
    return nil, "No parsed rtconfig provided"
  end

  -- If no layout specified, collect from ALL sections AND layouts
  if not layout_name then
    local all_items = {}

    -- Collect from sections (global elements)
    local section_items = 0
    for _, section in ipairs(parsed.sections) do
      for _, item in ipairs(section.items) do
        all_items[#all_items + 1] = item
        section_items = section_items + 1
      end
    end
    Console.info("Collected %d items from %d sections", section_items, #parsed.sections)

    -- Also collect from all layouts (where most elements actually live!)
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

-- Extract just the Element objects (for loading into State)
-- @param result: The conversion result from convert_layout
-- @param include_computed: Whether to include computed elements (default: true)
-- @param include_cleared: Whether to include cleared elements (default: false)
function M.extract_elements(result, include_computed, include_cleared)
  if not result then return {} end

  include_computed = include_computed ~= false
  include_cleared = include_cleared or false

  local elements = {}
  for _, entry in ipairs(result.elements) do
    local include = true

    if entry.is_computed and not include_computed then
      include = false
    end
    if entry.is_cleared and not include_cleared then
      include = false
    end

    if include then
      elements[#elements + 1] = entry.element
    end
  end

  return elements
end

return M

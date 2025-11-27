-- @noindex
-- WalterBuilder/domain/rtconfig_parser.lua
-- Parser for WALTER rtconfig.txt files
--
-- This parser extracts structure from rtconfig files:
-- - Sections (GLOBALS, TCP, MCP, etc.)
-- - Macros (macro ... endmacro)
-- - Layouts (Layout ... EndLayout) - can be nested
-- - Element statements (set, clear, front)
-- - Parameters (define_parameter)
-- - Comments and raw lines (preserved for round-trip)

local M = {}

-- Token types
M.TOKEN = {
  COMMENT = "comment",
  SECTION_START = "section_start",
  SECTION_END = "section_end",
  MACRO_START = "macro_start",
  MACRO_END = "macro_end",
  LAYOUT_START = "layout_start",
  LAYOUT_END = "layout_end",
  SET = "set",
  CLEAR = "clear",
  FRONT = "front",
  DEFINE_PARAM = "define_param",
  MACRO_CALL = "macro_call",
  RAW = "raw",  -- Unparsed line
}

-- Parse state
local function create_state()
  return {
    lines = {},
    current_line = 0,
    in_macro = false,
    macro_depth = 0,
    layout_stack = {},
    section = nil,
  }
end

-- Strip comments from a line, return (code, comment)
local function strip_comment(line)
  -- Handle ; comments
  local code, comment = line:match("^(.-)(%s*;.*)$")
  if code then
    return code, comment
  end
  return line, nil
end

-- Parse a section header comment like "#>--- GLOBALS ---"
local function parse_section_header(line)
  local name = line:match("^#>%-*%s*([%w%s_]+)%s*%-*$")
  if name then
    return name:match("^%s*(.-)%s*$")  -- trim
  end
  return nil
end

-- Check for section end marker "#<"
local function is_section_end(line)
  return line:match("^#<%s*$") ~= nil
end

-- Parse macro definition: "macro name param1 param2 ..."
local function parse_macro_start(line)
  local name, params = line:match("^%s*macro%s+(%S+)%s*(.*)$")
  if name then
    local param_list = {}
    for p in params:gmatch("%S+") do
      param_list[#param_list + 1] = p
    end
    return name, param_list
  end
  return nil
end

-- Check for endmacro
local function is_macro_end(line)
  return line:match("^%s*endmacro%s*$") ~= nil or line:match("^%s*endMacro%s*$") ~= nil
end

-- Parse Layout: Layout "name" or Layout "name" "dpi"
local function parse_layout_start(line)
  -- Layout "A" or Layout "150%_A" "150"
  local name, dpi = line:match('^%s*Layout%s+"([^"]+)"%s*"?([^"]*)"?%s*$')
  if name then
    return name, dpi ~= "" and dpi or nil
  end
  -- Single name without quotes (shouldn't happen but handle it)
  name = line:match("^%s*Layout%s+(%S+)%s*$")
  return name, nil
end

-- Check for EndLayout
local function is_layout_end(line)
  return line:match("^%s*EndLayout%s*$") ~= nil
end

-- Parse set statement: set element value
local function parse_set(line)
  local element, value = line:match("^%s*set%s+([%w._]+)%s+(.+)$")
  if element then
    return element, value:match("^%s*(.-)%s*$")
  end
  return nil
end

-- Parse clear statement: clear element or clear element.*
local function parse_clear(line)
  local element = line:match("^%s*clear%s+([%w._*]+)%s*$")
  return element
end

-- Parse front statement: front elem1 elem2 ...
local function parse_front(line)
  local elements_str = line:match("^%s*front%s+(.+)$")
  if elements_str then
    local elements = {}
    for e in elements_str:gmatch("[%w._]+") do
      elements[#elements + 1] = e
    end
    return elements
  end
  return nil
end

-- Parse define_parameter: define_parameter 'name' 'desc' value or variations
local function parse_define_param(line)
  -- define_parameter 'name' 'desc' value
  local name, desc, value = line:match("^%s*define_parameter%s+'([^']+)'%s+'([^']+)'%s+(%S+)")
  if name then
    return { name = name, description = desc, value = tonumber(value) or value }
  end
  return nil
end

-- Check if line is a macro call (known macros)
local function parse_macro_call(line, known_macros)
  local trimmed = line:match("^%s*(.-)%s*$")
  local name = trimmed:match("^(%S+)")
  if name and known_macros[name] then
    local args_str = trimmed:sub(#name + 1):match("^%s*(.-)%s*$")
    local args = {}
    -- Parse arguments (handle tabs and spaces)
    for arg in args_str:gmatch("%S+") do
      args[#args + 1] = arg
    end
    return name, args
  end
  return nil
end

-- Main parse function
function M.parse(content)
  local result = {
    version = nil,
    globals = {},
    sections = {},
    macros = {},
    layouts = {},
    parameters = {},
    elements = {},  -- All element statements found
    raw_lines = {}, -- Original lines for round-trip
  }

  -- Known macros we've seen (for identifying macro calls)
  local known_macros = {}

  -- Split into lines
  local lines = {}
  for line in content:gmatch("([^\r\n]*)[\r\n]?") do
    lines[#lines + 1] = line
  end
  result.raw_lines = lines

  -- Current parsing context
  local current_section = { name = "global", items = {} }
  local current_macro = nil
  local layout_stack = {}
  local current_layout = nil

  local i = 1
  while i <= #lines do
    local line = lines[i]
    local trimmed = line:match("^%s*(.-)%s*$")

    -- Skip empty lines
    if trimmed == "" then
      i = i + 1
      goto continue
    end

    -- Check for section header (#>--- NAME ---)
    local section_name = parse_section_header(trimmed)
    if section_name then
      -- Save previous section
      if current_section.name ~= "global" or #current_section.items > 0 then
        result.sections[#result.sections + 1] = current_section
      end
      current_section = { name = section_name, items = {}, line = i }
      i = i + 1
      goto continue
    end

    -- Check for section end (#<)
    if is_section_end(trimmed) then
      if current_section.name ~= "global" then
        result.sections[#result.sections + 1] = current_section
        current_section = { name = "global", items = {} }
      end
      i = i + 1
      goto continue
    end

    -- Pure comment line
    if trimmed:match("^;") or trimmed:match("^#") then
      current_section.items[#current_section.items + 1] = {
        type = M.TOKEN.COMMENT,
        line = i,
        text = line,
      }
      i = i + 1
      goto continue
    end

    -- Strip inline comment
    local code, comment = strip_comment(trimmed)
    code = code:match("^%s*(.-)%s*$")

    -- Macro definition
    local macro_name, macro_params = parse_macro_start(code)
    if macro_name then
      current_macro = {
        name = macro_name,
        params = macro_params,
        body = {},
        line = i,
      }
      known_macros[macro_name] = true
      i = i + 1
      goto continue
    end

    -- End macro
    if is_macro_end(code) then
      if current_macro then
        result.macros[#result.macros + 1] = current_macro
        current_macro = nil
      end
      i = i + 1
      goto continue
    end

    -- Inside macro - collect body
    if current_macro then
      current_macro.body[#current_macro.body + 1] = {
        line = i,
        text = line,
        code = code,
      }
      i = i + 1
      goto continue
    end

    -- Layout start
    local layout_name, layout_dpi = parse_layout_start(code)
    if layout_name then
      local new_layout = {
        name = layout_name,
        dpi = layout_dpi,
        items = {},
        children = {},
        parent = current_layout,
        line = i,
      }
      if current_layout then
        current_layout.children[#current_layout.children + 1] = new_layout
      else
        result.layouts[#result.layouts + 1] = new_layout
      end
      layout_stack[#layout_stack + 1] = new_layout
      current_layout = new_layout
      i = i + 1
      goto continue
    end

    -- Layout end
    if is_layout_end(code) then
      if #layout_stack > 0 then
        table.remove(layout_stack)
        current_layout = layout_stack[#layout_stack]
      end
      i = i + 1
      goto continue
    end

    -- Version
    local version = code:match("^%s*version%s+([%d.]+)")
    if version then
      result.version = version
      i = i + 1
      goto continue
    end

    -- Define parameter
    local param = parse_define_param(code)
    if param then
      result.parameters[#result.parameters + 1] = param
      i = i + 1
      goto continue
    end

    -- Clear statement
    local clear_elem = parse_clear(code)
    if clear_elem then
      local item = {
        type = M.TOKEN.CLEAR,
        element = clear_elem,
        line = i,
        raw = line,
        comment = comment,
      }
      if current_layout then
        current_layout.items[#current_layout.items + 1] = item
      else
        current_section.items[#current_section.items + 1] = item
      end
      result.elements[#result.elements + 1] = item
      i = i + 1
      goto continue
    end

    -- Front statement
    local front_elems = parse_front(code)
    if front_elems then
      local item = {
        type = M.TOKEN.FRONT,
        elements = front_elems,
        line = i,
        raw = line,
      }
      if current_layout then
        current_layout.items[#current_layout.items + 1] = item
      else
        current_section.items[#current_section.items + 1] = item
      end
      i = i + 1
      goto continue
    end

    -- Set statement
    local set_elem, set_value = parse_set(code)
    if set_elem then
      -- Determine if value is simple (literal coords) or computed (expression)
      local is_simple = set_value:match("^%[%s*[%d%s%-%.]+%s*%]$") ~= nil
      local coords = nil
      if is_simple then
        -- Parse literal coords [x y w h ls ts rs bs]
        coords = {}
        for n in set_value:match("%[(.-)%]"):gmatch("[%-]?[%d%.]+") do
          coords[#coords + 1] = tonumber(n)
        end
      end

      local item = {
        type = M.TOKEN.SET,
        element = set_elem,
        value = set_value,
        is_simple = is_simple,
        coords = coords,
        line = i,
        raw = line,
        comment = comment,
      }
      if current_layout then
        current_layout.items[#current_layout.items + 1] = item
      else
        current_section.items[#current_section.items + 1] = item
      end
      -- Track element statements
      if set_elem:match("^tcp%.") or set_elem:match("^mcp%.") or
         set_elem:match("^envcp%.") or set_elem:match("^trans%.") then
        result.elements[#result.elements + 1] = item
      end
      i = i + 1
      goto continue
    end

    -- Macro call (check known macros)
    local call_name, call_args = parse_macro_call(code, known_macros)
    if call_name then
      local item = {
        type = M.TOKEN.MACRO_CALL,
        macro = call_name,
        args = call_args,
        line = i,
        raw = line,
      }
      if current_layout then
        current_layout.items[#current_layout.items + 1] = item
      else
        current_section.items[#current_section.items + 1] = item
      end
      i = i + 1
      goto continue
    end

    -- Unknown/raw line
    local item = {
      type = M.TOKEN.RAW,
      line = i,
      text = line,
      code = code,
    }
    if current_layout then
      current_layout.items[#current_layout.items + 1] = item
    else
      current_section.items[#current_section.items + 1] = item
    end

    i = i + 1
    ::continue::
  end

  -- Save last section
  if current_section.name ~= "global" or #current_section.items > 0 then
    result.sections[#result.sections + 1] = current_section
  end

  return result
end

-- Parse from file path
function M.parse_file(path)
  local f = io.open(path, "r")
  if not f then
    return nil, "Could not open file: " .. path
  end
  local content = f:read("*a")
  f:close()
  return M.parse(content)
end

-- Get summary of parsed rtconfig
function M.get_summary(parsed)
  local summary = {
    version = parsed.version,
    section_count = #parsed.sections,
    section_names = {},
    macro_count = #parsed.macros,
    macro_names = {},
    layout_count = #parsed.layouts,
    layout_names = {},
    parameter_count = #parsed.parameters,
    element_count = #parsed.elements,
    simple_element_count = 0,
    computed_element_count = 0,
  }

  for _, sec in ipairs(parsed.sections) do
    summary.section_names[#summary.section_names + 1] = sec.name
  end

  for _, mac in ipairs(parsed.macros) do
    summary.macro_names[#summary.macro_names + 1] = mac.name
  end

  -- Count layouts recursively
  local function count_layouts(layouts, names)
    for _, layout in ipairs(layouts) do
      names[#names + 1] = layout.name
      if layout.children then
        count_layouts(layout.children, names)
      end
    end
  end
  count_layouts(parsed.layouts, summary.layout_names)
  summary.layout_count = #summary.layout_names

  -- Count simple vs computed elements
  for _, elem in ipairs(parsed.elements) do
    if elem.is_simple then
      summary.simple_element_count = summary.simple_element_count + 1
    else
      summary.computed_element_count = summary.computed_element_count + 1
    end
  end

  return summary
end

-- Extract all TCP elements from parsed result
function M.get_tcp_elements(parsed)
  local elements = {}

  for _, elem in ipairs(parsed.elements) do
    if elem.element:match("^tcp%.") then
      elements[#elements + 1] = elem
    end
  end

  return elements
end

-- Get elements by layout
function M.get_elements_by_layout(parsed, layout_name)
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
    return nil
  end

  local elements = {}
  for _, item in ipairs(layout.items) do
    if item.type == M.TOKEN.SET and item.element:match("^tcp%.") then
      elements[#elements + 1] = item
    end
  end

  return elements, layout
end

return M

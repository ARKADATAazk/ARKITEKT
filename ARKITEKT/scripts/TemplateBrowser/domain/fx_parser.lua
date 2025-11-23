-- @noindex
-- TemplateBrowser/domain/fx_parser.lua
-- Parse FX/VST information from REAPER track template files

local M = {}

-- Extract FX name from different VST formats
local function extract_fx_name(fx_line)
  -- Examples:
  -- VST "VST3: Zebralette (u-he)" Zebralette.vst3 0 "" ...
  -- VST3 "VST3: Manipulator (Polyverse Music)" Manipulator.vst3 0 "" ...
  -- CLAP "CLAPi: Zebralette3 (u-he)" com.u-he.Zebralette3 ""
  -- JS "JS: ReaEQ" ReaEQ ""

  -- Try VST/VST3 format: VST "VST3: Name (Developer)" filename.vst3
  local name = fx_line:match('VST[23]?%s+"[^:]+:%s*([^"]+)"')
  if name then
    -- Clean up developer name in parentheses
    name = name:gsub('%s*%([^)]+%)%s*$', '')
    return name:match('^%s*(.-)%s*$')  -- Trim whitespace
  end

  -- Try CLAP format: CLAP "CLAPi: Name (Developer)" com.package.name
  name = fx_line:match('CLAP%s+"[^:]+:%s*([^"]+)"')
  if name then
    name = name:gsub('%s*%([^)]+%)%s*$', '')
    return name:match('^%s*(.-)%s*$')
  end

  -- Try JS format: JS "JS: Name" filename
  name = fx_line:match('JS%s+"JS:%s*([^"]+)"')
  if name then
    return name:match('^%s*(.-)%s*$')
  end

  -- Try AU format: AU "AU: Name" ...
  name = fx_line:match('AU%s+"AU:%s*([^"]+)"')
  if name then
    name = name:gsub('%s*%([^)]+%)%s*$', '')
    return name:match('^%s*(.-)%s*$')
  end

  return nil
end

-- Parse a track template file and extract FX names
function M.parse_template_fx(filepath)
  local file = io.open(filepath, "r")
  if not file then
    return {}
  end

  local fx_list = {}
  local fx_set = {}  -- Track unique FX
  local depth = 0    -- Track nesting depth within FXCHAIN

  for line in file:lines() do
    -- Check if we're entering FXCHAIN
    if line:match("^%s*<FXCHAIN") then
      depth = 1  -- We're now at depth 1 inside FXCHAIN
    elseif depth > 0 then
      -- Count opening brackets (increase depth)
      if line:match("^%s*<") then
        depth = depth + 1
      -- Count closing brackets (decrease depth)
      elseif line:match("^%s*>%s*$") then
        depth = depth - 1
        -- When depth reaches 0, we've exited FXCHAIN
      end
    end

    -- Parse FX lines within FXCHAIN (depth > 0)
    if depth > 0 then
      -- Look for VST, VST3, CLAP, JS, AU lines
      if line:match("^%s*<?VST[23]?%s+") or
         line:match("^%s*<?CLAP%s+") or
         line:match("^%s*<?JS%s+") or
         line:match("^%s*<?AU%s+") then

        local fx_name = extract_fx_name(line)
        if fx_name and not fx_set[fx_name] then
          fx_set[fx_name] = true
          table.insert(fx_list, fx_name)
        end
      end
    end
  end

  file:close()
  return fx_list
end

-- Get all unique FX across all templates
function M.get_all_fx(templates)
  local all_fx = {}
  local fx_set = {}

  for _, tmpl in ipairs(templates) do
    if tmpl.fx then
      for _, fx in ipairs(tmpl.fx) do
        if not fx_set[fx] then
          fx_set[fx] = true
          table.insert(all_fx, fx)
        end
      end
    end
  end

  -- Sort alphabetically
  table.sort(all_fx, function(a, b) return a:lower() < b:lower() end)

  return all_fx
end

return M

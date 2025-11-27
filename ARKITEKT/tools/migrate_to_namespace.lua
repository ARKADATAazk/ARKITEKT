#!/usr/bin/env lua
-- Migrates files from direct requires to ark.* namespace
-- Usage: lua tools/migrate_to_namespace.lua <file>

local function read_file(path)
  local f = assert(io.open(path, "r"))
  local content = f:read("*all")
  f:close()
  return content
end

local function write_file(path, content)
  local f = assert(io.open(path, "w"))
  f:write(content)
  f:close()
end

-- Maps module paths to namespace keys
local MODULE_MAP = {
  -- Primitives
  ["arkitekt.gui.widgets.primitives.badge"] = "Badge",
  ["arkitekt.gui.widgets.primitives.button"] = "Button",
  ["arkitekt.gui.widgets.primitives.checkbox"] = "Checkbox",
  ["arkitekt.gui.widgets.primitives.close_button"] = "CloseButton",
  ["arkitekt.gui.widgets.primitives.combo"] = "Combo",
  ["arkitekt.gui.widgets.primitives.corner_button"] = "CornerButton",
  ["arkitekt.gui.widgets.primitives.hue_slider"] = "HueSlider",
  ["arkitekt.gui.widgets.primitives.inputtext"] = "InputText",
  ["arkitekt.gui.widgets.primitives.markdown_field"] = "MarkdownField",
  ["arkitekt.gui.widgets.primitives.radio_button"] = "RadioButton",
  ["arkitekt.gui.widgets.primitives.scrollbar"] = "Scrollbar",
  ["arkitekt.gui.widgets.primitives.separator"] = "Separator",
  ["arkitekt.gui.widgets.primitives.slider"] = "Slider",
  ["arkitekt.gui.widgets.primitives.spinner"] = "Spinner",

  -- Containers
  ["arkitekt.gui.widgets.containers.panel"] = "Panel",
  ["arkitekt.gui.widgets.containers.tile_group"] = "TileGroup",

  -- Utilities
  ["arkitekt.core.colors"] = "Colors",
  ["arkitekt.gui.style.defaults"] = "Style",
  ["arkitekt.gui.draw.primitives"] = "Draw",
  ["arkitekt.gui.animation.easing"] = "Easing",
  ["arkitekt.core.math"] = "Math",
  ["arkitekt.core.uuid"] = "UUID",
}

local function migrate_file(path)
  local content = read_file(path)
  local original = content

  -- Track which widgets are used in this file
  local used_modules = {}
  local local_names = {}  -- Maps local var name to namespace key

  -- Find all arkitekt requires and track them
  local require_lines = {}
  for line in content:gmatch("[^\n]+") do
    local var_name, module_path = line:match("^local%s+(%w+)%s*=%s*require%s*%(?['\"]([^'\"]+)['\"]%)?")
    if var_name and module_path then
      local ns_key = MODULE_MAP[module_path]
      if ns_key then
        require_lines[#require_lines + 1] = {line = line, var = var_name, ns_key = ns_key}
        used_modules[ns_key] = true
        local_names[var_name] = ns_key
      end
    end
  end

  -- If no arkitekt modules found, skip
  if #require_lines == 0 then
    return false, "No arkitekt modules found"
  end

  -- Remove old require lines
  for _, req in ipairs(require_lines) do
    -- Escape special pattern characters
    local escaped_line = req.line:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    content = content:gsub(escaped_line .. "\n", "")
  end

  -- Replace widget usages (e.g., Button.draw -> ark.Button.draw)
  for var_name, ns_key in pairs(local_names) do
    -- Match widget usage: VarName.method or VarName:method
    content = content:gsub("([^%w_])" .. var_name .. "(%.[%w_]+)", "%1ark." .. ns_key .. "%2")
    content = content:gsub("([^%w_])" .. var_name .. "(:[%w_]+)", "%1ark." .. ns_key .. "%2")
    -- Also handle start of line
    content = content:gsub("^" .. var_name .. "(%.[%w_]+)", "ark." .. ns_key .. "%1")
    content = content:gsub("^" .. var_name .. "(:[%w_]+)", "ark." .. ns_key .. "%1")
  end

  -- Add ark namespace require at the top (after ImGui require if present)
  local ark_require = "local ark = require('arkitekt')\n"

  -- Check if ark is already required
  if content:match("local%s+ark%s*=%s*require%s*%(?['\"]arkitekt['\"]%)?") then
    -- Already has ark require, don't add
    return true, "Migrated (ark already present)"
  end

  -- Find a good place to insert (after first require block)
  local insert_after_line = nil
  local line_num = 0
  for line in content:gmatch("[^\n]+") do
    line_num = line_num + 1
    if line:match("^local%s+%w+%s*=%s*require") then
      insert_after_line = line
    elseif insert_after_line and not line:match("^local%s+") and line:match("%S") then
      -- Found end of require block
      break
    end
  end

  if insert_after_line then
    content = content:gsub("(" .. insert_after_line:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1") .. "\n)", "%1" .. ark_require)
  else
    -- No requires found, add at top
    content = ark_require .. "\n" .. content
  end

  write_file(path, content)
  return true, string.format("Migrated %d modules", #require_lines)
end

-- Main
local file_path = arg[1]
if not file_path then
  print("Usage: lua migrate_to_namespace.lua <file>")
  os.exit(1)
end

local success, message = migrate_file(file_path)
if success then
  print("✓ " .. file_path .. ": " .. message)
else
  print("✗ " .. file_path .. ": " .. message)
end

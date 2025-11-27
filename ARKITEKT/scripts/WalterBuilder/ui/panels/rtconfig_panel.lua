-- @noindex
-- WalterBuilder/ui/panels/rtconfig_panel.lua
-- Panel for viewing parsed rtconfig structure (read-only)

local ImGui = require 'imgui' '0.10'
local ark = require('arkitekt')
local RtconfigParser = require('WalterBuilder.domain.rtconfig_parser')
local ThemeConnector = require('WalterBuilder.domain.theme_connector')
local Colors = require('WalterBuilder.defs.colors')

local hexrgb = ark.Colors.hexrgb

local M = {}
local Panel = {}
Panel.__index = Panel

function M.new(opts)
  opts = opts or {}

  local self = setmetatable({
    -- Loaded rtconfig data
    rtconfig = nil,
    theme_info = nil,
    load_error = nil,

    -- UI state
    selected_section = nil,
    selected_layout = nil,
    selected_macro = nil,
    show_raw = false,
    filter_text = "",

    -- Callbacks
    on_element_select = opts.on_element_select,
  }, Panel)

  return self
end

-- Load rtconfig from current theme
function Panel:load_from_theme()
  self.load_error = nil
  self.rtconfig = nil

  local result, err = ThemeConnector.load_current_rtconfig()
  if not result then
    self.load_error = err
    return false
  end

  self.rtconfig = result.parsed
  self.theme_info = result.info
  return true
end

-- Load rtconfig from file path
function Panel:load_from_file(path)
  self.load_error = nil
  self.rtconfig = nil

  local result, err = ThemeConnector.load_rtconfig(path)
  if not result then
    self.load_error = err
    return false
  end

  self.rtconfig = result.parsed
  self.theme_info = { rtconfig_path = path }
  return true
end

-- Draw summary section
function Panel:draw_summary(ctx)
  if not self.rtconfig then
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#CC6666"))
    ImGui.Text(ctx, self.load_error or "No rtconfig loaded")
    ImGui.PopStyleColor(ctx)
    return
  end

  local summary = RtconfigParser.get_summary(self.rtconfig)

  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#88CC88"))
  ImGui.Text(ctx, "WALTER v" .. (summary.version or "?"))
  ImGui.PopStyleColor(ctx)

  ImGui.SameLine(ctx, 0, 20)
  ImGui.Text(ctx, string.format("%d sections", summary.section_count))

  ImGui.SameLine(ctx, 0, 20)
  ImGui.Text(ctx, string.format("%d macros", summary.macro_count))

  ImGui.SameLine(ctx, 0, 20)
  ImGui.Text(ctx, string.format("%d layouts", summary.layout_count))

  -- Element breakdown
  ImGui.Text(ctx, string.format("Elements: %d total (%d simple, %d computed)",
    summary.element_count,
    summary.simple_element_count,
    summary.computed_element_count))
end

-- Draw sections tree
function Panel:draw_sections(ctx)
  if not self.rtconfig then return end

  if ImGui.CollapsingHeader(ctx, "Sections (" .. #self.rtconfig.sections .. ")", ImGui.TreeNodeFlags_DefaultOpen) then
    ImGui.Indent(ctx, 8)

    for i, section in ipairs(self.rtconfig.sections) do
      local is_selected = self.selected_section == section
      local flags = ImGui.TreeNodeFlags_Leaf
      if is_selected then
        flags = flags | ImGui.TreeNodeFlags_Selected
      end

      local label = section.name .. " (" .. #section.items .. " items)"
      if ImGui.TreeNodeEx(ctx, "sec_" .. i, label, flags) then
        ImGui.TreePop(ctx)
      end

      if ImGui.IsItemClicked(ctx) then
        self.selected_section = section
        self.selected_layout = nil
        self.selected_macro = nil
      end
    end

    ImGui.Unindent(ctx, 8)
  end
end

-- Draw macros list
function Panel:draw_macros(ctx)
  if not self.rtconfig then return end

  if ImGui.CollapsingHeader(ctx, "Macros (" .. #self.rtconfig.macros .. ")") then
    ImGui.Indent(ctx, 8)

    for i, macro in ipairs(self.rtconfig.macros) do
      local is_selected = self.selected_macro == macro
      local flags = ImGui.TreeNodeFlags_Leaf
      if is_selected then
        flags = flags | ImGui.TreeNodeFlags_Selected
      end

      local params_str = table.concat(macro.params, " ")
      local label = macro.name
      if #macro.params > 0 then
        label = label .. " (" .. #macro.params .. " params)"
      end

      if ImGui.TreeNodeEx(ctx, "mac_" .. i, label, flags) then
        ImGui.TreePop(ctx)
      end

      if ImGui.IsItemClicked(ctx) then
        self.selected_macro = macro
        self.selected_section = nil
        self.selected_layout = nil
      end

      -- Tooltip with params
      if ImGui.IsItemHovered(ctx) and #macro.params > 0 then
        ImGui.BeginTooltip(ctx)
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
        ImGui.Text(ctx, "Parameters: " .. params_str)
        ImGui.Text(ctx, "Body: " .. #macro.body .. " lines")
        ImGui.PopStyleColor(ctx)
        ImGui.EndTooltip(ctx)
      end
    end

    ImGui.Unindent(ctx, 8)
  end
end

-- Draw layouts tree (recursive for nested layouts)
function Panel:draw_layouts_recursive(ctx, layouts, depth)
  for i, layout in ipairs(layouts) do
    local is_selected = self.selected_layout == layout
    local has_children = layout.children and #layout.children > 0

    local flags = 0
    if is_selected then
      flags = flags | ImGui.TreeNodeFlags_Selected
    end
    if not has_children then
      flags = flags | ImGui.TreeNodeFlags_Leaf
    end

    local label = layout.name
    if layout.dpi then
      label = label .. " [" .. layout.dpi .. "%]"
    end
    label = label .. " (" .. #layout.items .. " items)"

    local node_open = ImGui.TreeNodeEx(ctx, "layout_" .. depth .. "_" .. i, label, flags)

    if ImGui.IsItemClicked(ctx) then
      self.selected_layout = layout
      self.selected_section = nil
      self.selected_macro = nil
    end

    if node_open then
      if has_children then
        self:draw_layouts_recursive(ctx, layout.children, depth + 1)
      end
      ImGui.TreePop(ctx)
    end
  end
end

function Panel:draw_layouts(ctx)
  if not self.rtconfig then return end

  if ImGui.CollapsingHeader(ctx, "Layouts (" .. #self.rtconfig.layouts .. ")", ImGui.TreeNodeFlags_DefaultOpen) then
    ImGui.Indent(ctx, 8)
    self:draw_layouts_recursive(ctx, self.rtconfig.layouts, 0)
    ImGui.Unindent(ctx, 8)
  end
end

-- Draw detail view for selected item
function Panel:draw_detail(ctx)
  if self.selected_section then
    self:draw_section_detail(ctx, self.selected_section)
  elseif self.selected_layout then
    self:draw_layout_detail(ctx, self.selected_layout)
  elseif self.selected_macro then
    self:draw_macro_detail(ctx, self.selected_macro)
  else
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#666666"))
    ImGui.Text(ctx, "Select a section, layout, or macro to view details")
    ImGui.PopStyleColor(ctx)
  end
end

function Panel:draw_section_detail(ctx, section)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#88CCFF"))
  ImGui.Text(ctx, "Section: " .. section.name)
  ImGui.PopStyleColor(ctx)
  ImGui.Separator(ctx)

  -- Filter
  ImGui.PushItemWidth(ctx, -1)
  local changed, text = ImGui.InputTextWithHint(ctx, "##filter", "Filter items...", self.filter_text)
  if changed then self.filter_text = text end
  ImGui.PopItemWidth(ctx)

  ImGui.Dummy(ctx, 0, 4)

  -- Items list
  local filter_lower = self.filter_text:lower()
  for _, item in ipairs(section.items) do
    local show = filter_lower == ""
    local display = ""

    if item.type == RtconfigParser.TOKEN.SET then
      display = "set " .. item.element
      if item.is_simple then
        display = display .. " [simple]"
      else
        display = display .. " [computed]"
      end
      show = show or item.element:lower():find(filter_lower, 1, true)
    elseif item.type == RtconfigParser.TOKEN.CLEAR then
      display = "clear " .. item.element
      show = show or item.element:lower():find(filter_lower, 1, true)
    elseif item.type == RtconfigParser.TOKEN.FRONT then
      display = "front " .. table.concat(item.elements, " ")
    elseif item.type == RtconfigParser.TOKEN.MACRO_CALL then
      display = item.macro .. " ..."
    elseif item.type == RtconfigParser.TOKEN.COMMENT then
      display = item.text:sub(1, 60)
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#666666"))
    elseif item.type == RtconfigParser.TOKEN.RAW then
      display = (item.code or item.text or ""):sub(1, 60)
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#888888"))
    end

    if show then
      ImGui.Text(ctx, display)

      if item.type == RtconfigParser.TOKEN.COMMENT or item.type == RtconfigParser.TOKEN.RAW then
        ImGui.PopStyleColor(ctx)
      end

      -- Tooltip for set items
      if item.type == RtconfigParser.TOKEN.SET and ImGui.IsItemHovered(ctx) then
        ImGui.BeginTooltip(ctx)
        ImGui.Text(ctx, item.element)
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
        if item.is_simple and item.coords then
          ImGui.Text(ctx, string.format("Coords: [%s]", table.concat(item.coords, " ")))
        else
          -- Truncate long expressions
          local val = item.value
          if #val > 80 then val = val:sub(1, 77) .. "..." end
          ImGui.Text(ctx, "Value: " .. val)
        end
        ImGui.PopStyleColor(ctx)
        ImGui.EndTooltip(ctx)
      end
    end
  end
end

function Panel:draw_layout_detail(ctx, layout)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#FFCC88"))
  ImGui.Text(ctx, "Layout: " .. layout.name)
  if layout.dpi then
    ImGui.SameLine(ctx)
    ImGui.Text(ctx, "[" .. layout.dpi .. "%]")
  end
  ImGui.PopStyleColor(ctx)

  if layout.parent then
    ImGui.SameLine(ctx, 0, 10)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#666666"))
    ImGui.Text(ctx, "(child of " .. layout.parent.name .. ")")
    ImGui.PopStyleColor(ctx)
  end

  ImGui.Separator(ctx)

  -- Show items in this layout
  ImGui.Text(ctx, #layout.items .. " items:")
  ImGui.Dummy(ctx, 0, 4)

  for _, item in ipairs(layout.items) do
    local display = ""

    if item.type == RtconfigParser.TOKEN.SET then
      if item.is_simple then
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#88CC88"))
        display = "set " .. item.element .. " [literal]"
      else
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#CCCC88"))
        display = "set " .. item.element .. " [expr]"
      end
      ImGui.Text(ctx, display)
      ImGui.PopStyleColor(ctx)
    elseif item.type == RtconfigParser.TOKEN.MACRO_CALL then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#CC88CC"))
      ImGui.Text(ctx, item.macro .. "(" .. table.concat(item.args or {}, ", ") .. ")")
      ImGui.PopStyleColor(ctx)
    elseif item.type == RtconfigParser.TOKEN.RAW then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#888888"))
      ImGui.Text(ctx, (item.code or ""):sub(1, 50))
      ImGui.PopStyleColor(ctx)
    end
  end

  -- Show children count
  if layout.children and #layout.children > 0 then
    ImGui.Dummy(ctx, 0, 8)
    ImGui.Text(ctx, #layout.children .. " nested layouts")
  end
end

function Panel:draw_macro_detail(ctx, macro)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#CC88FF"))
  ImGui.Text(ctx, "Macro: " .. macro.name)
  ImGui.PopStyleColor(ctx)
  ImGui.Separator(ctx)

  -- Parameters
  if #macro.params > 0 then
    ImGui.Text(ctx, "Parameters:")
    ImGui.Indent(ctx, 8)
    for _, p in ipairs(macro.params) do
      ImGui.BulletText(ctx, p)
    end
    ImGui.Unindent(ctx, 8)
    ImGui.Dummy(ctx, 0, 4)
  end

  -- Body preview
  ImGui.Text(ctx, "Body (" .. #macro.body .. " lines):")
  ImGui.Dummy(ctx, 0, 2)

  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
  local max_lines = 20
  for i, line in ipairs(macro.body) do
    if i > max_lines then
      ImGui.Text(ctx, "... " .. (#macro.body - max_lines) .. " more lines")
      break
    end
    local text = line.code or line.text or ""
    if #text > 70 then text = text:sub(1, 67) .. "..." end
    ImGui.Text(ctx, text)
  end
  ImGui.PopStyleColor(ctx)
end

-- Main draw function
function Panel:draw(ctx)
  -- Load buttons
  if ImGui.Button(ctx, "Load from Theme", 120, 0) then
    self:load_from_theme()
  end

  ImGui.SameLine(ctx)

  if ImGui.Button(ctx, "Load Reference", 100, 0) then
    -- Load the bundled reference rtconfig
    local script_path = debug.getinfo(1, "S").source:sub(2)
    local script_dir = script_path:match("(.*[/\\])")
    local ref_path = script_dir:gsub("ui[/\\]panels[/\\]$", "") .. "reference/rtconfig.txt"
    self:load_from_file(ref_path)
  end

  ImGui.Dummy(ctx, 0, 4)

  -- Theme info
  if self.theme_info and self.theme_info.theme_name then
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
    ImGui.Text(ctx, "Theme: " .. self.theme_info.theme_name)
    ImGui.PopStyleColor(ctx)
  elseif self.theme_info and self.theme_info.rtconfig_path then
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
    local filename = self.theme_info.rtconfig_path:match("[^/\\]+$") or "rtconfig.txt"
    ImGui.Text(ctx, "File: " .. filename)
    ImGui.PopStyleColor(ctx)
  end

  ImGui.Dummy(ctx, 0, 4)
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 4)

  -- Summary
  self:draw_summary(ctx)

  ImGui.Dummy(ctx, 0, 8)

  -- Two-column layout: tree on left, detail on right
  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)
  local tree_w = 200

  -- Tree panel
  ImGui.BeginChild(ctx, "rtconfig_tree", tree_w, avail_h - 20, 1)
  self:draw_sections(ctx)
  self:draw_macros(ctx)
  self:draw_layouts(ctx)
  ImGui.EndChild(ctx)

  ImGui.SameLine(ctx)

  -- Detail panel
  ImGui.BeginChild(ctx, "rtconfig_detail", avail_w - tree_w - 10, avail_h - 20, 1)
  ImGui.Indent(ctx, 4)
  self:draw_detail(ctx)
  ImGui.Unindent(ctx, 4)
  ImGui.EndChild(ctx)
end

return M

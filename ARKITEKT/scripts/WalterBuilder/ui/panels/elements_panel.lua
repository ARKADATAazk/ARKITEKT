-- @noindex
-- WalterBuilder/ui/panels/elements_panel.lua
-- Element palette panel - shows available elements to add to layout

local ImGui = require 'imgui' '0.10'
local ark = require('arkitekt')
local TCPElements = require('WalterBuilder.defs.tcp_elements')
local Colors = require('WalterBuilder.defs.colors')

local hexrgb = ark.Colors.hexrgb

local M = {}
local Panel = {}
Panel.__index = Panel

function M.new(opts)
  opts = opts or {}

  local self = setmetatable({
    -- Filter/search
    search_text = "",

    -- Collapsed categories
    collapsed = {},

    -- Selected element in palette (for adding)
    selected_def = nil,

    -- Callback when element is added
    on_add = opts.on_add,

    -- Active elements (already in layout)
    active_ids = {},
  }, Panel)

  return self
end

-- Set which elements are currently active in the layout
function Panel:set_active_elements(element_ids)
  self.active_ids = {}
  for _, id in ipairs(element_ids) do
    self.active_ids[id] = true
  end
end

-- Draw a category header (collapsible)
function Panel:draw_category_header(ctx, category, display_name)
  local is_collapsed = self.collapsed[category]

  -- Header button
  ImGui.PushStyleColor(ctx, ImGui.Col_Header, hexrgb("#2A2A2A"))
  ImGui.PushStyleColor(ctx, ImGui.Col_HeaderHovered, hexrgb("#333333"))
  ImGui.PushStyleColor(ctx, ImGui.Col_HeaderActive, hexrgb("#404040"))

  local open = ImGui.CollapsingHeader(ctx, display_name, not is_collapsed and ImGui.TreeNodeFlags_DefaultOpen or 0)

  ImGui.PopStyleColor(ctx, 3)

  self.collapsed[category] = not open
  return open
end

-- Draw a single element item
function Panel:draw_element_item(ctx, def)
  local is_active = self.active_ids[def.id]
  local is_selected = self.selected_def and self.selected_def.id == def.id

  -- Item background
  local bg_color = is_selected and hexrgb("#404040") or (is_active and hexrgb("#2A3A2A") or hexrgb("#1A1A1A"))

  ImGui.PushStyleColor(ctx, ImGui.Col_Button, bg_color)
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, hexrgb("#333333"))
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, hexrgb("#444444"))

  local avail_w = ImGui.GetContentRegionAvail(ctx)

  -- Draw as selectable button
  if ImGui.Button(ctx, "##" .. def.id, avail_w - 8, 24) then
    self.selected_def = def
    return "select"
  end

  ImGui.PopStyleColor(ctx, 3)

  -- Draw content on top
  ImGui.SameLine(ctx, 8)
  ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) - 22)

  -- Category color indicator
  local cat_color = Colors.CATEGORY[def.category] or Colors.CATEGORY.other
  ImGui.ColorButton(ctx, "##cat_" .. def.id, cat_color, ImGui.ColorEditFlags_NoTooltip, 8, 16)

  ImGui.SameLine(ctx, 0, 6)

  -- Element name
  local text_color = is_active and hexrgb("#88CC88") or hexrgb("#CCCCCC")
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, text_color)
  ImGui.Text(ctx, def.name)
  ImGui.PopStyleColor(ctx)

  -- Active indicator
  if is_active then
    ImGui.SameLine(ctx, avail_w - 30)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#88CC88"))
    ImGui.Text(ctx, "[+]")
    ImGui.PopStyleColor(ctx)
  end

  -- Tooltip
  if ImGui.IsItemHovered(ctx) then
    ImGui.BeginTooltip(ctx)
    ImGui.Text(ctx, def.id)
    if def.description and def.description ~= "" then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
      ImGui.Text(ctx, def.description)
      ImGui.PopStyleColor(ctx)
    end
    ImGui.EndTooltip(ctx)
  end

  -- Double-click to add
  if ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
    return "add"
  end

  return nil
end

-- Main draw function
function Panel:draw(ctx)
  local result = nil

  -- Search bar
  ImGui.PushItemWidth(ctx, -1)
  local changed, text = ImGui.InputTextWithHint(ctx, "##search", "Search elements...", self.search_text)
  if changed then
    self.search_text = text
  end
  ImGui.PopItemWidth(ctx)

  ImGui.Dummy(ctx, 0, 4)

  -- Get elements grouped by category
  local by_category = TCPElements.get_by_category()
  local search_lower = self.search_text:lower()

  -- Draw categories
  for _, category in ipairs(TCPElements.category_order) do
    local elements = by_category[category]
    if elements and #elements > 0 then
      -- Filter elements by search
      local filtered = {}
      for _, def in ipairs(elements) do
        local name_lower = def.name:lower()
        local id_lower = def.id:lower()
        if search_lower == "" or name_lower:find(search_lower, 1, true) or id_lower:find(search_lower, 1, true) then
          filtered[#filtered + 1] = def
        end
      end

      -- Only show category if it has matching elements
      if #filtered > 0 then
        local display_name = TCPElements.category_names[category] or category
        display_name = display_name .. " (" .. #filtered .. ")"

        if self:draw_category_header(ctx, category, display_name) then
          ImGui.Indent(ctx, 4)

          for _, def in ipairs(filtered) do
            local action = self:draw_element_item(ctx, def)
            if action == "add" and self.on_add then
              result = { type = "add", definition = def }
            elseif action == "select" then
              result = { type = "select", definition = def }
            end
          end

          ImGui.Unindent(ctx, 4)
        end
      end
    end
  end

  -- Add button at bottom
  ImGui.Dummy(ctx, 0, 8)
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 4)

  if self.selected_def then
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
    ImGui.Text(ctx, "Selected: " .. self.selected_def.name)
    ImGui.PopStyleColor(ctx)

    ImGui.Dummy(ctx, 0, 4)

    if ark.Button.draw_at_cursor(ctx, {
      label = "Add to Layout",
      width = -1,
      height = 28,
      on_click = function()
        if self.on_add then
          result = { type = "add", definition = self.selected_def }
        end
      end
    }, "add_element_btn") then
    end
  else
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#666666"))
    ImGui.Text(ctx, "Select an element to add")
    ImGui.PopStyleColor(ctx)
  end

  return result
end

-- Get currently selected definition
function Panel:get_selected()
  return self.selected_def
end

-- Clear selection
function Panel:clear_selection()
  self.selected_def = nil
end

return M

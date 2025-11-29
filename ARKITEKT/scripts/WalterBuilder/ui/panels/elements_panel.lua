-- @noindex
-- WalterBuilder/ui/panels/elements_panel.lua
-- Element palette panel - shows available elements to add to layout

local ImGui = require('arkitekt.platform.imgui')
local Ark = require('arkitekt')
local TCPElements = require('WalterBuilder.defs.tcp_elements')
local Colors = require('WalterBuilder.defs.colors')
local Chip = require('arkitekt.gui.widgets.data.chip')
local Button = require('arkitekt.gui.widgets.primitives.button')

local hexrgb = Ark.Colors.hexrgb

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

    -- Callbacks
    on_add = opts.on_add,            -- When adding new element
    on_select = opts.on_select,      -- When clicking active element
    on_toggle = opts.on_toggle,      -- When toggling visibility
    on_reset = opts.on_reset,        -- When resetting to defaults

    -- Active elements (already in layout) - keyed by ID
    active_elements = {},
  }, Panel)

  return self
end

-- Set which elements are currently active in the layout
function Panel:set_active_elements(elements)
  self.active_elements = {}
  for _, elem in ipairs(elements) do
    self.active_elements[elem.id] = elem
  end
end

-- Draw a category header (collapsible)
-- Returns: open (boolean), action (string or nil)
function Panel:draw_category_header(ctx, category, display_name)
  local is_collapsed = self.collapsed[category]

  -- Header button
  ImGui.PushStyleColor(ctx, ImGui.Col_Header, hexrgb("#2A2A2A"))
  ImGui.PushStyleColor(ctx, ImGui.Col_HeaderHovered, hexrgb("#333333"))
  ImGui.PushStyleColor(ctx, ImGui.Col_HeaderActive, hexrgb("#404040"))

  local open = ImGui.CollapsingHeader(ctx, display_name, not is_collapsed and ImGui.TreeNodeFlags_DefaultOpen or 0)

  ImGui.PopStyleColor(ctx, 3)

  -- Right-click on category header toggles all elements in category
  local action = nil
  if ImGui.IsItemClicked(ctx, 1) then  -- 1 = right mouse button
    action = "toggle_category"
  end

  self.collapsed[category] = not open
  return open, action
end

-- Draw a single element item using Chip widget
function Panel:draw_element_item(ctx, def)
  local active_elem = self.active_elements[def.id]
  local is_active = active_elem ~= nil
  local is_hidden = is_active and not active_elem.visible
  local is_selected = self.selected_def and self.selected_def.id == def.id

  -- Get category color
  local cat_color = Colors.CATEGORY[def.category] or Colors.CATEGORY.other

  -- For hidden elements, dim the color
  if is_hidden then
    cat_color = hexrgb("#555555")
  end

  -- Display name with status indicators
  local label = def.name
  if is_active then
    if is_hidden then
      label = label .. " [hidden]"
    else
      label = label .. " +"
    end
  end

  local avail_w = ImGui.GetContentRegionAvail(ctx)

  -- Draw element as DOT style chip
  local clicked, chip_w, chip_h = Chip.draw(ctx, {
    id = "elem_" .. def.id,
    style = Chip.STYLE.DOT,
    label = label,
    color = cat_color,
    height = 26,
    explicit_width = avail_w - 8,
    is_selected = is_selected,
    interactive = true,
    rounding = 4,
    dot_shape = Chip.SHAPE.SQUARE,
    dot_rounding = 2,
  })

  -- Right-click on active elements directly toggles visibility (no menu)
  if is_active and ImGui.IsItemClicked(ctx, 1) then  -- 1 = right mouse button
    return "toggle", active_elem
  end

  -- Tooltip on hover
  if ImGui.IsItemHovered(ctx) then
    ImGui.BeginTooltip(ctx)
    ImGui.Text(ctx, def.id)
    if def.description and def.description ~= "" then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
      ImGui.Text(ctx, def.description)
      ImGui.PopStyleColor(ctx)
    end
    if is_active then
      if is_hidden then
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#CC6666"))
        ImGui.Text(ctx, "(hidden - right-click to show)")
        ImGui.PopStyleColor(ctx)
      else
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#88CC88"))
        ImGui.Text(ctx, "(click to select, right-click to hide)")
        ImGui.PopStyleColor(ctx)
      end
    else
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#666666"))
      ImGui.Text(ctx, "Double-click to add")
      ImGui.PopStyleColor(ctx)
    end
    ImGui.EndTooltip(ctx)
  end

  -- Check for double-click to add (only for inactive elements)
  local double_clicked = ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0)

  -- Handle click/double-click
  if clicked then
    if is_active then
      -- Active element: select it for editing
      return "select_active", active_elem
    else
      -- Inactive: select in palette
      self.selected_def = def
      return "select"
    end
  elseif double_clicked and not is_active then
    return "add"
  end

  return nil
end

-- Draw a custom element item (element from rtconfig that has no definition)
function Panel:draw_custom_element_item(ctx, elem)
  local is_hidden = not elem.visible

  -- Custom elements get a distinct color
  local cat_color = hexrgb("#9966CC")  -- Purple for custom
  if is_hidden then
    cat_color = hexrgb("#555555")
  end

  -- Display name with status
  local label = elem.name or elem.id
  if is_hidden then
    label = label .. " [hidden]"
  else
    label = label .. " +"
  end

  local avail_w = ImGui.GetContentRegionAvail(ctx)

  -- Draw as DOT style chip
  local clicked, chip_w, chip_h = Chip.draw(ctx, {
    id = "custom_" .. elem.id,
    style = Chip.STYLE.DOT,
    label = label,
    color = cat_color,
    height = 26,
    explicit_width = avail_w - 8,
    is_selected = false,
    interactive = true,
    rounding = 4,
    dot_shape = Chip.SHAPE.SQUARE,
    dot_rounding = 2,
  })

  -- Right-click toggles visibility
  if ImGui.IsItemClicked(ctx, 1) then
    return "toggle", elem
  end

  -- Tooltip
  if ImGui.IsItemHovered(ctx) then
    ImGui.BeginTooltip(ctx)
    ImGui.Text(ctx, elem.id)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#9966CC"))
    ImGui.Text(ctx, "(custom element from rtconfig)")
    ImGui.PopStyleColor(ctx)
    if is_hidden then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#CC6666"))
      ImGui.Text(ctx, "(hidden - right-click to show)")
      ImGui.PopStyleColor(ctx)
    else
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#88CC88"))
      ImGui.Text(ctx, "(click to select, right-click to hide)")
      ImGui.PopStyleColor(ctx)
    end
    ImGui.EndTooltip(ctx)
  end

  -- Click to select
  if clicked then
    return "select_active", elem
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

        local header_open, header_action = self:draw_category_header(ctx, category, display_name)

        -- Handle category header right-click (toggle all elements in category)
        if header_action == "toggle_category" then
          result = { type = "toggle_category", category = category }
        end

        if header_open then
          ImGui.Indent(ctx, 4)

          for _, def in ipairs(filtered) do
            local action, elem = self:draw_element_item(ctx, def)
            if action == "add" then
              result = { type = "add", definition = def }
            elseif action == "select" then
              result = { type = "select", definition = def }
            elseif action == "select_active" then
              result = { type = "select_active", element = elem }
            elseif action == "toggle" then
              result = { type = "toggle", element = elem }
            elseif action == "reset" then
              result = { type = "reset", element = elem }
            end
          end

          ImGui.Unindent(ctx, 4)
        end
      end
    end
  end

  -- Customs section: show custom elements from rtconfig
  local custom_elements = {}
  for _, elem in pairs(self.active_elements) do
    if elem.is_custom then
      -- Apply search filter
      local name_lower = (elem.name or elem.id):lower()
      local id_lower = elem.id:lower()
      if search_lower == "" or name_lower:find(search_lower, 1, true) or id_lower:find(search_lower, 1, true) then
        custom_elements[#custom_elements + 1] = elem
      end
    end
  end

  if #custom_elements > 0 then
    -- Sort by ID for consistent ordering
    table.sort(custom_elements, function(a, b) return a.id < b.id end)

    ImGui.Dummy(ctx, 0, 8)

    local display_name = "Customs (" .. #custom_elements .. ")"
    local header_open, header_action = self:draw_category_header(ctx, "customs", display_name)

    if header_action == "toggle_category" then
      result = { type = "toggle_category", category = "customs" }
    end

    if header_open then
      ImGui.Indent(ctx, 4)

      for _, elem in ipairs(custom_elements) do
        local action, target = self:draw_custom_element_item(ctx, elem)
        if action == "toggle" then
          result = { type = "toggle", element = target }
        elseif action == "select_active" then
          result = { type = "select_active", element = target }
        end
      end

      ImGui.Unindent(ctx, 4)
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

    local x, y = ImGui.GetCursorScreenPos(ctx)
    local avail_w = ImGui.GetContentRegionAvail(ctx)

    local add_result = Button.draw(ctx, {
      id = "add_element_btn",
      x = x,
      y = y,
      label = "Add to Layout",
      width = avail_w - 4,
      height = 28,
      advance = "vertical",
    })

    if add_result.clicked and self.on_add then
      result = { type = "add", definition = self.selected_def }
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

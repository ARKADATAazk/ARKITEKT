-- @noindex
-- ReArkitekt/gui/widgets/overlays/batch_rename_modal.lua
-- Modal for batch renaming with wildcard support

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local Style = require('rearkitekt.gui.style.defaults')
local Container = require('rearkitekt.gui.widgets.overlays.overlay.container')
local ColorPickerWindow = require('rearkitekt.gui.widgets.tools.color_picker_window')
local Button = require('rearkitekt.gui.widgets.primitives.button')
local SearchInput = require('rearkitekt.gui.widgets.inputs.search_input')
local Dropdown = require('rearkitekt.gui.widgets.inputs.dropdown')
local ContextMenu = require('rearkitekt.gui.widgets.overlays.context_menu')
local Chip = require('rearkitekt.gui.widgets.data.chip')
local hexrgb = Colors.hexrgb

local M = {}

local BatchRenameModal = {}
BatchRenameModal.__index = BatchRenameModal

-- Global settings persistence (REAPER-wide, not per-project)
local EXTSTATE_SECTION = "REARKITEKT_BATCH_RENAME"
local EXTSTATE_SEPARATOR = "wildcard_separator"
local EXTSTATE_START_INDEX = "wildcard_start_index"
local EXTSTATE_PADDING = "wildcard_padding"
local EXTSTATE_LETTER_CASE = "wildcard_letter_case"
local EXTSTATE_NAMES_CATEGORY = "common_names_category"

-- Load separator preference from global REAPER settings
local function load_separator_preference()
  local value = reaper.GetExtState(EXTSTATE_SECTION, EXTSTATE_SEPARATOR)
  if value == "underscore" then return "underscore"
  elseif value == "space" then return "space"
  else return "none" end
end

-- Save separator preference to global REAPER settings
local function save_separator_preference(separator)
  reaper.SetExtState(EXTSTATE_SECTION, EXTSTATE_SEPARATOR, separator, true)  -- persist=true saves to reaper.ini
end

-- Load start index preference (0 or 1)
local function load_start_index_preference()
  local value = reaper.GetExtState(EXTSTATE_SECTION, EXTSTATE_START_INDEX)
  return value == "0" and 0 or 1
end

-- Save start index preference
local function save_start_index_preference(start_index)
  reaper.SetExtState(EXTSTATE_SECTION, EXTSTATE_START_INDEX, tostring(start_index), true)
end

-- Load padding preference (none, 2, 3)
local function load_padding_preference()
  local value = reaper.GetExtState(EXTSTATE_SECTION, EXTSTATE_PADDING)
  if value == "2" then return 2
  elseif value == "3" then return 3
  else return 0 end  -- none
end

-- Save padding preference
local function save_padding_preference(padding)
  reaper.SetExtState(EXTSTATE_SECTION, EXTSTATE_PADDING, tostring(padding), true)
end

-- Load letter case preference (lowercase, uppercase)
local function load_letter_case_preference()
  local value = reaper.GetExtState(EXTSTATE_SECTION, EXTSTATE_LETTER_CASE)
  return value == "uppercase" and "uppercase" or "lowercase"
end

-- Save letter case preference
local function save_letter_case_preference(letter_case)
  reaper.SetExtState(EXTSTATE_SECTION, EXTSTATE_LETTER_CASE, letter_case, true)
end

-- Load common names category preference
local function load_names_category_preference()
  local value = reaper.GetExtState(EXTSTATE_SECTION, EXTSTATE_NAMES_CATEGORY)
  return value == "general" and "general" or "game"
end

-- Save common names category preference
local function save_names_category_preference(category)
  reaper.SetExtState(EXTSTATE_SECTION, EXTSTATE_NAMES_CATEGORY, category, true)
end

-- Wildcard pattern processing
local function apply_pattern(pattern, index, start_index, padding, letter_case)
  -- $n - number (with options for start index and padding)
  -- $l - letter (lowercase or uppercase based on letter_case setting)
  local result = pattern

  -- Calculate actual index based on start preference
  local num_value = index - 1 + start_index  -- index is 1-based loop counter

  -- Apply number wildcard with padding
  if padding == 2 then
    result = result:gsub("%$n", string.format("%02d", num_value))
  elseif padding == 3 then
    result = result:gsub("%$n", string.format("%03d", num_value))
  else
    result = result:gsub("%$n", tostring(num_value))
  end

  -- Apply letter wildcard (case based on preference)
  result = result:gsub("%$l", function()
    local letter_index = (num_value) % 26
    if letter_case == "uppercase" then
      return string.char(65 + letter_index)  -- 65 is 'A'
    else
      return string.char(97 + letter_index)  -- 97 is 'a'
    end
  end)

  return result
end

-- Generate preview of renamed items
local function generate_preview(pattern, count, start_index, padding, letter_case)
  local previews = {}
  for i = 1, math.min(count, 5) do  -- Show max 5 previews
    previews[i] = apply_pattern(pattern, i, start_index, padding, letter_case)
  end
  if count > 5 then
    previews[#previews + 1] = "..."
  end
  return previews
end

-- Create new batch rename modal instance
function M.new()
  return setmetatable({
    is_open = false,
    pattern = "",
    preview_items = {},
    on_confirm = nil,
    on_rename_and_recolor = nil,
    on_recolor = nil,
    focus_input = false,
    item_count = 0,
    selected_color = 0xFF5733FF,  -- Default color (RGBA)
    picker_initialized = false,
    separator = "none",  -- Wildcard separator: "none", "underscore", "space"
    start_index = 1,  -- Start from: 0 or 1
    padding = 0,  -- Padding: 0 (none), 2 (01), 3 (001)
    letter_case = "lowercase",  -- Letter case: "lowercase" or "uppercase"
    names_category = "game",  -- Common names category: "game" or "general"
  }, BatchRenameModal)
end

-- Open the batch rename modal
function BatchRenameModal:open(item_count, on_confirm_callback, opts)
  opts = opts or {}
  self.is_open = true
  self.pattern = ""
  self.preview_items = {}
  self.on_confirm = on_confirm_callback
  self.on_rename_and_recolor = opts.on_rename_and_recolor
  self.on_recolor = opts.on_recolor
  self.selected_color = opts.initial_color or 0xFF5733FF
  self.focus_input = true
  self.item_count = item_count
  self.picker_initialized = false
  self.separator = load_separator_preference()  -- Load saved separator preference
  self.start_index = load_start_index_preference()  -- Load saved start index preference
  self.padding = load_padding_preference()  -- Load saved padding preference
  self.letter_case = load_letter_case_preference()  -- Load saved letter case preference
  self.names_category = load_names_category_preference()  -- Load saved names category preference
end

-- Check if modal should be shown
function BatchRenameModal:should_show()
  return self.is_open
end

-- Close the modal
function BatchRenameModal:close()
  self.is_open = false
end

-- Draw modal content (shared between popup and overlay modes)
function BatchRenameModal:draw_content(ctx, count, is_overlay_mode, content_w, content_h)
  local modal_w = content_w or 520  -- Use provided content_w or fallback to 520
  local dl = ImGui.GetWindowDrawList(ctx)

  -- Calculate total content width for centering
  local content_max_w = 800  -- Maximum content width (increased from 700)
  local actual_content_w = math.min(modal_w, content_max_w)
  local center_offset_x = math.floor((modal_w - actual_content_w) * 0.5)

  -- Calculate layout variables early
  local picker_size = 160  -- Color picker size (left column)
  local col_gap = 20  -- Gap between columns
  local right_col_width = actual_content_w - picker_size - col_gap  -- Right column takes remaining space

  local start_x = math.floor(ImGui.GetCursorPosX(ctx) + center_offset_x)

  -- Title centered
  local title_text = string.format("Rename %d item%s", count, count > 1 and "s" or "")
  local title_w = ImGui.CalcTextSize(ctx, title_text)
  ImGui.SetCursorPosX(ctx, math.floor(ImGui.GetCursorPosX(ctx) + (modal_w - title_w) * 0.5))
  ImGui.TextColored(ctx, hexrgb("#CCCCCCFF"), title_text)
  ImGui.Dummy(ctx, 0, 24)

  -- ========================================================================
  -- TWO COLUMN LAYOUT: Left (color picker) | Right (input + chips)
  -- ========================================================================

  local start_y = ImGui.GetCursorPosY(ctx)

  -- ========================================================================
  -- LEFT COLUMN: Color picker (static size)
  -- ========================================================================

  ImGui.SetCursorPos(ctx, start_x, start_y)

  -- Initialize color picker only once per modal open
  if not self.picker_initialized then
    ColorPickerWindow.show_inline("batch_rename_picker", self.selected_color)
    self.picker_initialized = true
  end

  -- Render the inline color picker
  local color_changed = ColorPickerWindow.render_inline(ctx, "batch_rename_picker", {
    size = picker_size,
    on_change = function(color)
      self.selected_color = color
    end
  })

  -- ========================================================================
  -- RIGHT COLUMN: Pattern input + wildcards + common names + separator
  -- ========================================================================

  local right_col_x = math.floor(start_x + picker_size + col_gap)
  ImGui.SetCursorPos(ctx, right_col_x, start_y)

  -- Pattern input field using SearchInput primitive
  local input_height = 32
  local screen_x, screen_y = ImGui.GetCursorScreenPos(ctx)

  if self.focus_input then
    ImGui.SetKeyboardFocusHere(ctx)
    self.focus_input = false
  end

  -- Set text in SearchInput component
  SearchInput.set_text("batch_rename_pattern", self.pattern)

  local _, changed = SearchInput.draw(ctx, dl, screen_x, screen_y, right_col_width, input_height, {
    id = "batch_rename_pattern",
    placeholder = "pattern$wildcard",
    on_change = function(text)
      self.pattern = text
      self.preview_items = generate_preview(text, count, self.start_index, self.padding, self.letter_case)
    end
  }, "batch_rename_pattern")

  -- Advance cursor
  ImGui.SetCursorScreenPos(ctx, screen_x, screen_y + input_height)
  ImGui.Dummy(ctx, 0, 6)

  -- Wildcards label and chips (with right-click context menus)
  ImGui.SetCursorPosX(ctx, right_col_x)
  ImGui.TextColored(ctx, hexrgb("#999999FF"), "Wildcards (right-click for options):")
  ImGui.Dummy(ctx, 0, 6)
  ImGui.SetCursorPosX(ctx, right_col_x)

  local wildcard_chips = {
    {label = "number ($n)", wildcard = "$n", type = "number"},
    {label = self.letter_case == "uppercase" and "LETTER ($l)" or "letter ($l)", wildcard = "$l", type = "letter"},
  }

  local chip_spacing = 6

  for i, chip_data in ipairs(wildcard_chips) do
    if i > 1 then
      ImGui.SameLine(ctx, 0, chip_spacing)
    end

    local clicked, right_clicked = Chip.draw(ctx, {
      label = chip_data.label,
      style = Chip.STYLE.ACTION,
      interactive = true,
      id = "wildcard_" .. i,
      bg_color = Style.ACTION_CHIP_WILDCARD.bg_color,
      text_color = Style.ACTION_CHIP_WILDCARD.text_color,
      border_color = Style.ACTION_CHIP_WILDCARD.border_color,
      rounding = Style.ACTION_CHIP_WILDCARD.rounding,
      padding_h = Style.ACTION_CHIP_WILDCARD.padding_h,
    })

    -- Left click - insert wildcard
    if clicked then
      -- Insert separator before wildcard if enabled
      local sep = ""
      if self.separator == "underscore" then
        sep = "_"
      elseif self.separator == "space" then
        sep = " "
      end
      self.pattern = self.pattern .. sep .. chip_data.wildcard
      self.preview_items = generate_preview(self.pattern, count, self.start_index, self.padding, self.letter_case)
    end

    -- Right click - show context menu
    if ImGui.IsItemHovered(ctx) and ImGui.IsMouseClicked(ctx, 1) then
      ImGui.OpenPopup(ctx, "wildcard_context_" .. chip_data.type)
    end

    -- Context menu for number wildcard
    if chip_data.type == "number" and ContextMenu.begin(ctx, "wildcard_context_number") then
      ImGui.TextColored(ctx, hexrgb("#999999FF"), "Number Options")
      ContextMenu.separator(ctx)

      -- Start from options
      if ContextMenu.checkbox_item(ctx, "Start from 0", self.start_index == 0) then
        self.start_index = 0
        save_start_index_preference(0)
        self.preview_items = generate_preview(self.pattern, count, self.start_index, self.padding, self.letter_case)
      end
      if ContextMenu.checkbox_item(ctx, "Start from 1", self.start_index == 1) then
        self.start_index = 1
        save_start_index_preference(1)
        self.preview_items = generate_preview(self.pattern, count, self.start_index, self.padding, self.letter_case)
      end

      ContextMenu.separator(ctx)

      -- Padding options
      if ContextMenu.checkbox_item(ctx, "No padding", self.padding == 0) then
        self.padding = 0
        save_padding_preference(0)
        self.preview_items = generate_preview(self.pattern, count, self.start_index, self.padding, self.letter_case)
      end
      if ContextMenu.checkbox_item(ctx, "Padding: 01", self.padding == 2) then
        self.padding = 2
        save_padding_preference(2)
        self.preview_items = generate_preview(self.pattern, count, self.start_index, self.padding, self.letter_case)
      end
      if ContextMenu.checkbox_item(ctx, "Padding: 001", self.padding == 3) then
        self.padding = 3
        save_padding_preference(3)
        self.preview_items = generate_preview(self.pattern, count, self.start_index, self.padding, self.letter_case)
      end

      ContextMenu.end_menu(ctx)
    end

    -- Context menu for letter wildcard
    if chip_data.type == "letter" and ContextMenu.begin(ctx, "wildcard_context_letter") then
      ImGui.TextColored(ctx, hexrgb("#999999FF"), "Letter Case")
      ContextMenu.separator(ctx)

      if ContextMenu.checkbox_item(ctx, "lowercase (a, b, c...)", self.letter_case == "lowercase") then
        self.letter_case = "lowercase"
        save_letter_case_preference("lowercase")
        self.preview_items = generate_preview(self.pattern, count, self.start_index, self.padding, self.letter_case)
      end
      if ContextMenu.checkbox_item(ctx, "UPPERCASE (A, B, C...)", self.letter_case == "uppercase") then
        self.letter_case = "uppercase"
        save_letter_case_preference("uppercase")
        self.preview_items = generate_preview(self.pattern, count, self.start_index, self.padding, self.letter_case)
      end

      ContextMenu.end_menu(ctx)
    end
  end

  ImGui.SetCursorPosX(ctx, right_col_x)
  ImGui.Dummy(ctx, 0, 6)

  -- Common names label with category dropdown
  ImGui.SetCursorPosX(ctx, right_col_x)
  ImGui.TextColored(ctx, hexrgb("#999999FF"), "Common Names:")
  ImGui.SameLine(ctx, 0, 12)

  local dropdown_x, dropdown_y = ImGui.GetCursorScreenPos(ctx)
  local dropdown_w = 120
  local dropdown_h = 24

  local category_changed, new_category = Dropdown.draw(ctx, dl, dropdown_x, dropdown_y, dropdown_w, dropdown_h, {
    id = "names_category",
    options = {
      {value = "game", label = "Game Music"},
      {value = "general", label = "General Music"},
    },
    current_value = self.names_category,
    on_change = function(value)
      self.names_category = value
      save_names_category_preference(value)
    end,
  }, "names_category_dropdown")

  ImGui.SetCursorScreenPos(ctx, dropdown_x, dropdown_y + dropdown_h)
  ImGui.Dummy(ctx, 0, 6)
  ImGui.SetCursorPosX(ctx, right_col_x)

  -- Common names organized by category
  local game_music_names = {
    "combat", "battle", "boss", "ambience", "tension", "suspense",
    "intro", "outro", "stinger", "loop",
    "calm", "peaceful", "explore", "menu", "theme", "victory", "defeat",
    "action", "stealth", "puzzle", "cutscene", "cinematic",
  }

  local general_music_names = {
    "intro", "outro", "verse", "chorus", "refrain", "bridge", "break",
    "partA", "partB", "partC", "part",
    "theme", "variation", "reprise", "coda", "interlude",
    "solo", "tutti", "crescendo", "diminuendo",
  }

  local common_names = self.names_category == "game" and game_music_names or general_music_names

  -- Render common names with proper wrapping
  local max_x = right_col_x + right_col_width
  local line_height = 30

  for i, name in ipairs(common_names) do
    -- Calculate chip width (text + padding from chip style, NOT including spacing)
    local text_w = ImGui.CalcTextSize(ctx, name)
    local chip_width = text_w + (Style.ACTION_CHIP_TAG.padding_h or 8) * 2

    if i > 1 then
      -- Get current cursor position BEFORE potentially adding spacing
      local cur_screen_x, cur_screen_y = ImGui.GetCursorScreenPos(ctx)

      -- Check if chip would fit on current line (including spacing before it)
      if cur_screen_x + chip_spacing + chip_width > max_x then
        -- Won't fit, start new line
        ImGui.SetCursorPosX(ctx, right_col_x)
        ImGui.Dummy(ctx, 0, line_height)
        ImGui.SetCursorPosX(ctx, right_col_x)
      else
        -- Will fit, add spacing and continue on same line
        ImGui.SameLine(ctx, 0, chip_spacing)
      end
    end

    local clicked = Chip.draw(ctx, {
      label = name,
      style = Chip.STYLE.ACTION,
      interactive = true,
      id = "common_name_" .. i,
      bg_color = Style.ACTION_CHIP_TAG.bg_color,
      text_color = Style.ACTION_CHIP_TAG.text_color,
      border_color = Style.ACTION_CHIP_TAG.border_color,
      rounding = Style.ACTION_CHIP_TAG.rounding,
      padding_h = Style.ACTION_CHIP_TAG.padding_h,
    })

    if clicked then
      -- Append the name (with separator if pattern is not empty)
      if self.pattern ~= "" and not self.pattern:match("%s$") then
        self.pattern = self.pattern .. "_"
      end
      self.pattern = self.pattern .. name
      self.preview_items = generate_preview(self.pattern, count, self.start_index, self.padding, self.letter_case)
    end
  end

  ImGui.SetCursorPosX(ctx, right_col_x)
  ImGui.Dummy(ctx, 0, 6)

  -- Wildcard separator radio buttons
  ImGui.SetCursorPosX(ctx, right_col_x)
  ImGui.TextColored(ctx, hexrgb("#999999FF"), "Separator before wildcard:")
  ImGui.Dummy(ctx, 0, 6)
  ImGui.SetCursorPosX(ctx, right_col_x)

  -- Radio button for "None"
  if ImGui.RadioButton(ctx, "None##sep_none", self.separator == "none") then
    self.separator = "none"
    save_separator_preference("none")
  end

  ImGui.SameLine(ctx, 0, 12)

  -- Radio button for "Underscore"
  if ImGui.RadioButton(ctx, "Underscore (_)##sep_underscore", self.separator == "underscore") then
    self.separator = "underscore"
    save_separator_preference("underscore")
  end

  ImGui.SameLine(ctx, 0, 12)

  -- Radio button for "Space"
  if ImGui.RadioButton(ctx, "Space ( )##sep_space", self.separator == "space") then
    self.separator = "space"
    save_separator_preference("space")
  end

  -- ========================================================================
  -- Calculate final Y position (below both columns)
  -- ========================================================================

  local right_col_cursor_y = ImGui.GetCursorPosY(ctx)
  local left_col_end_y = start_y + picker_size
  local final_y = math.max(right_col_cursor_y, left_col_end_y)

  ImGui.SetCursorPosY(ctx, final_y + 20)
  ImGui.SetCursorPosX(ctx, start_x)

  -- ========================================================================
  -- SECTION 4: Preview
  -- ========================================================================

  if #self.preview_items > 0 then
    ImGui.SetCursorPosX(ctx, start_x)
    ImGui.TextColored(ctx, hexrgb("#999999FF"), "Preview:")
    ImGui.Dummy(ctx, 0, 4)
    ImGui.Indent(ctx, start_x + 12)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 0, 2)
    for _, name in ipairs(self.preview_items) do
      ImGui.TextColored(ctx, hexrgb("#DDDDDDFF"), name)
    end
    ImGui.PopStyleVar(ctx, 1)
    ImGui.Unindent(ctx, start_x + 12)
  end

  ImGui.Dummy(ctx, 0, 20)
  ImGui.SetCursorPosX(ctx, start_x)

  -- ========================================================================
  -- SECTION 5: Action buttons using primitives
  -- ========================================================================

  -- Use more of the available width for buttons
  local button_h = 32
  local spacing = 10
  local button_w_small = 100  -- Cancel, Rename, Recolor
  local button_w_large = 150  -- Rename & Recolor (wider to fit text)
  local total_w = button_w_small * 3 + button_w_large + spacing * 3
  local button_start_x = math.floor(start_x + (actual_content_w - total_w) * 0.5)

  -- Center buttons horizontally within content area
  ImGui.SetCursorPosX(ctx, button_start_x)
  local button_y = ImGui.GetCursorPosY(ctx)
  local screen_x, screen_y = ImGui.GetCursorScreenPos(ctx)

  local should_close = false
  local can_rename = self.pattern ~= ""

  -- Cancel button
  local _, cancel_clicked = Button.draw(ctx, dl, screen_x, screen_y, button_w_small, button_h, {
    id = "cancel_btn",
    label = "Cancel",
    rounding = 4,
    ignore_modal = true,
  }, "batch_rename_cancel")

  if cancel_clicked or ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
    should_close = true
  end

  -- Rename button (disabled when no pattern)
  local _, rename_clicked = Button.draw(ctx, dl, screen_x + button_w_small + spacing, screen_y, button_w_small, button_h, {
    id = "rename_btn",
    label = "Rename",
    rounding = 4,
    is_disabled = not can_rename,
    ignore_modal = true,
  }, "batch_rename_rename")

  if rename_clicked or (can_rename and ImGui.IsKeyPressed(ctx, ImGui.Key_Enter)) then
    if self.on_confirm then
      self.on_confirm(self.pattern)
    end
    should_close = true
  end

  -- Rename & Recolor button (disabled when no pattern) - WIDER
  local rename_recolor_x = screen_x + (button_w_small + spacing) * 2
  local _, rename_recolor_clicked = Button.draw(ctx, dl, rename_recolor_x, screen_y, button_w_large, button_h, {
    id = "rename_recolor_btn",
    label = "Rename & Recolor",
    rounding = 4,
    is_disabled = not can_rename,
    ignore_modal = true,
  }, "batch_rename_both")

  if rename_recolor_clicked then
    if self.on_rename_and_recolor then
      self.on_rename_and_recolor(self.pattern, self.selected_color)
    end
    should_close = true
  end

  -- Recolor button (always enabled)
  local recolor_x = rename_recolor_x + button_w_large + spacing
  local _, recolor_clicked = Button.draw(ctx, dl, recolor_x, screen_y, button_w_small, button_h, {
    id = "recolor_btn",
    label = "Recolor",
    rounding = 4,
    ignore_modal = true,
  }, "batch_rename_recolor")

  if recolor_clicked then
    if self.on_recolor then
      self.on_recolor(self.selected_color)
    end
    should_close = true
  end

  -- Advance cursor past buttons
  ImGui.SetCursorPosY(ctx, button_y + button_h)

  return should_close
end

-- Draw the modal (supports both popup and overlay modes)
function BatchRenameModal:draw(ctx, item_count, window)
  if not self.is_open then return false end

  local count = item_count or self.item_count

  -- Use overlay mode if window.overlay is available
  if window and window.overlay then
    if not self.overlay_pushed then
      self.overlay_pushed = true

      window.overlay:push({
        id = 'batch-rename-modal',
        close_on_scrim = false,  -- Disable right-click scrim exit
        esc_to_close = true,
        on_close = function()
          self:close()
          self.overlay_pushed = false
        end,
        render = function(ctx, alpha, bounds)
          -- Responsive sizing with constraints
          local max_w = 800
          local max_h = 600
          local min_w = 600
          local min_h = 400

          -- Use 80% of viewport width/height, clamped to min/max
          local modal_w = math.floor(math.max(min_w, math.min(max_w, bounds.w * 0.8)))
          local modal_h = math.floor(math.max(min_h, math.min(max_h, bounds.h * 0.8)))

          -- Center in viewport
          local modal_x = bounds.x + math.floor((bounds.w - modal_w) * 0.5)
          local modal_y = bounds.y + math.floor((bounds.h - modal_h) * 0.5)

          local padding = 32
          local content_w = modal_w - padding * 2
          local content_h = modal_h - padding * 2

          -- Draw content directly without container background
          ImGui.SetCursorScreenPos(ctx, modal_x + padding, modal_y + padding)
          local should_close = self:draw_content(ctx, count, true, content_w, content_h)

          -- Handle close
          if should_close then
            window.overlay:pop('batch-rename-modal')
            self:close()
            self.overlay_pushed = false
          end
        end
      })
    end

    return self.is_open
  end

  -- Fallback to BeginPopupModal when overlay is not available
  if not self.popup_opened then
    ImGui.OpenPopup(ctx, "Batch Rename##batch_rename_modal")
    self.popup_opened = true
  end

  -- Center modal on screen
  local viewport_w, viewport_h = ImGui.Viewport_GetSize(ImGui.GetWindowViewport(ctx))
  local modal_w, modal_h = 520, 600
  ImGui.SetNextWindowPos(ctx, (viewport_w - modal_w) * 0.5, (viewport_h - modal_h) * 0.5, ImGui.Cond_Appearing)
  ImGui.SetNextWindowSize(ctx, modal_w, modal_h, ImGui.Cond_Appearing)

  -- Modal flags
  local flags = ImGui.WindowFlags_NoCollapse |
                ImGui.WindowFlags_NoResize |
                ImGui.WindowFlags_NoDocking

  -- Apply consistent styling
  ImGui.PushStyleColor(ctx, ImGui.Col_PopupBg, hexrgb("#1A1A1AFF"))
  ImGui.PushStyleColor(ctx, ImGui.Col_Border, hexrgb("#404040FF"))
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 16, 12)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 0, 10)

  -- Begin modal popup
  local visible, open = ImGui.BeginPopupModal(ctx, "Batch Rename##batch_rename_modal", true, flags)

  if visible then
    local should_close = self:draw_content(ctx, count, false)

    if should_close then
      self:close()
      self.popup_opened = false
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.EndPopup(ctx)
  end

  ImGui.PopStyleVar(ctx, 2)
  ImGui.PopStyleColor(ctx, 2)

  if not open then
    self:close()
    self.popup_opened = false
  end

  return self.is_open
end

-- Apply pattern to a list of items (returns new names in order)
function M.apply_pattern_to_items(pattern, count)
  -- Load global preferences for wildcard processing
  local start_index = load_start_index_preference()
  local padding = load_padding_preference()
  local letter_case = load_letter_case_preference()

  local results = {}
  for i = 1, count do
    results[i] = apply_pattern(pattern, i, start_index, padding, letter_case)
  end
  return results
end

-- Legacy API compatibility (singleton pattern for backward compatibility)
local _legacy_instance = nil

function M.open(item_count, on_confirm_callback, opts)
  if not _legacy_instance then
    _legacy_instance = M.new()
  end
  _legacy_instance:open(item_count, on_confirm_callback, opts)
end

function M.is_open()
  if not _legacy_instance then return false end
  return _legacy_instance:should_show()
end

function M.draw(ctx, item_count, window)
  if not _legacy_instance then return false end
  return _legacy_instance:draw(ctx, item_count, window)
end

return M

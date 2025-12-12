-- @noindex
-- arkitekt/gui/widgets/overlays/batch_renamer.lua
-- Configurable batch rename modal with wildcards, tags, and optional color picker
--
-- USAGE:
--   local Ark = require('arkitekt')
--
--   Ark.BatchRenamer.show(ctx, window, {
--     item_count = 5,
--     on_confirm = function(result)
--       -- result.pattern, result.names, result.color, result.mode, result.action
--     end,
--     name_categories = {...},  -- App-provided (optional, has defaults)
--     show_color_picker = true, -- Toggle color picker
--     modes = {'replace', 'prefix', 'suffix'}, -- Which modes to enable
--   })

local ImGui = require('arkitekt.core.imgui')
local Base = require('arkitekt.gui.widgets.base')
local Colors = require('arkitekt.core.colors')
local Context = require('arkitekt.core.context')
local Theme = require('arkitekt.theme')
local ColorPickerWindow = require('arkitekt.gui.widgets.tools.color_picker_window')
local Button = require('arkitekt.gui.widgets.primitives.button')
local InputText = require('arkitekt.gui.widgets.primitives.inputtext')
local Combo = require('arkitekt.gui.widgets.primitives.combo')
local ContextMenu = require('arkitekt.gui.widgets.overlays.context_menu')
local LabelButton = require('arkitekt.gui.widgets.primitives.label_button')
local RadioButton = require('arkitekt.gui.widgets.primitives.radio_button')
local Unicode = require('arkitekt.core.unicode')
local ResponsiveGrid = require('arkitekt.gui.layout.responsive')

local M = {}

-- =============================================================================
-- EXTSTATE PERSISTENCE (Global REAPER-wide settings)
-- =============================================================================

local EXTSTATE_SECTION = 'ARKITEKT_BATCH_RENAMER'

local function load_pref(key, default)
  local value = reaper.GetExtState(EXTSTATE_SECTION, key)
  if value == '' then return default end
  return value
end

local function save_pref(key, value)
  reaper.SetExtState(EXTSTATE_SECTION, key, tostring(value), true)
end

-- =============================================================================
-- DEFAULT CONTENT (Used when app doesn't provide custom content)
-- =============================================================================

-- Default wildcards (always available, apps can extend)
M.DEFAULT_WILDCARDS = {
  { label = 'number ($n)', wildcard = '$n', type = 'number' },
  { label = 'letter ($l)', wildcard = '$l', type = 'letter' },
}

-- Default separators (centralized, not configurable per-app)
M.SEPARATORS = {
  { value = 'none', label = 'None' },
  { value = 'underscore', label = 'Underscore (_)' },
  { value = 'space', label = 'Space ( )' },
  { value = 'dash', label = 'Dash (-)' },
}

-- Default name categories (game/general music - apps can override entirely)
M.DEFAULT_NAME_CATEGORIES = {
  {
    value = 'game',
    label = 'Game Music',
    names = {
      { name = 'combat', color = 0xB85C5CFF },
      { name = 'battle', color = 0xB85C5CFF },
      { name = 'boss', color = 0xB85C5CFF },
      { name = 'action', color = 0xB85C5CFF },
      { name = 'tension', color = 0xB8A55CFF },
      { name = 'suspense', color = 0xB8A55CFF },
      { name = 'ambience', color = 0x6B9B7CFF },
      { name = 'calm', color = 0x6B9B7CFF },
      { name = 'peaceful', color = 0x6B9B7CFF },
      { name = 'explore', color = 0x6B9B7CFF },
      { name = 'intro', color = 0x8B8B8BFF },
      { name = 'outro', color = 0x8B8B8BFF },
      { name = 'break', color = 0x9B7CB8FF },
      { name = 'stinger', color = 0x9B7CB8FF },
      { name = 'loop', color = 0x9B7CB8FF },
      { name = 'menu', color = 0x5C7CB8FF },
      { name = 'theme', color = 0xB89B5CFF },
      { name = 'victory', color = 0xB89B5CFF },
      { name = 'defeat', color = 0x6B5C5CFF },
      { name = 'stealth', color = 0x6B6B8BFF },
      { name = 'puzzle', color = 0x5C9BB8FF },
      { name = 'cutscene', color = 0x7C7C8BFF },
      { name = 'cinematic', color = 0x7C7C8BFF },
    },
  },
  {
    value = 'general',
    label = 'General Music',
    names = {
      { name = 'intro', color = 0x8B8B8BFF },
      { name = 'outro', color = 0x8B8B8BFF },
      { name = 'verse', color = 0x8B8B8BFF },
      { name = 'chorus', color = 0x8B8B8BFF },
      { name = 'refrain', color = 0x8B8B8BFF },
      { name = 'bridge', color = 0x8B8B8BFF },
      { name = 'break', color = 0x9B7CB8FF },
      { name = 'partA', color = 0x8B8B8BFF },
      { name = 'partB', color = 0x8B8B8BFF },
      { name = 'partC', color = 0x8B8B8BFF },
      { name = 'part', color = 0x8B8B8BFF },
      { name = 'theme', color = 0xB89B5CFF },
      { name = 'variation', color = 0x9B8B6BFF },
      { name = 'reprise', color = 0x9B8B6BFF },
      { name = 'coda', color = 0x9B8B6BFF },
      { name = 'interlude', color = 0x5C7CB8FF },
      { name = 'solo', color = 0x5C9B9BFF },
      { name = 'tutti', color = 0x5C9B9BFF },
      { name = 'crescendo', color = 0x5C9B9BFF },
      { name = 'diminuendo', color = 0x5C9B9BFF },
    },
  },
}

-- =============================================================================
-- PATTERN ENGINE
-- =============================================================================

-- Apply wildcards to a pattern
local function apply_wildcards(pattern, index, opts)
  opts = opts or {}
  local start_index = opts.start_index or 1
  local padding = opts.padding or 0
  local letter_case = opts.letter_case or 'lowercase'

  local result = pattern
  local num_value = index - 1 + start_index

  -- $n - number wildcard
  if padding == 2 then
    result = result:gsub('%$n', string.format('%02d', num_value))
  elseif padding == 3 then
    result = result:gsub('%$n', string.format('%03d', num_value))
  else
    result = result:gsub('%$n', tostring(num_value))
  end

  -- $l - letter wildcard
  result = result:gsub('%$l', function()
    local letter_index = num_value % 26
    if letter_case == 'uppercase' then
      return string.char(65 + letter_index)
    else
      return string.char(97 + letter_index)
    end
  end)

  return result
end

-- Generate final names based on mode
local function generate_names(pattern, count, existing_names, mode, wildcard_opts)
  local names = {}
  for i = 1, count do
    local processed = apply_wildcards(pattern, i, wildcard_opts)
    if mode == 'prefix' then
      local existing = existing_names and existing_names[i] or ''
      names[i] = processed .. existing
    elseif mode == 'suffix' then
      local existing = existing_names and existing_names[i] or ''
      names[i] = existing .. processed
    else -- replace
      names[i] = processed
    end
  end
  return names
end

-- Generate preview (max 5 items)
local function generate_preview(pattern, count, existing_names, mode, wildcard_opts)
  local preview_count = math.min(count, 5)
  local previews = generate_names(pattern, preview_count, existing_names, mode, wildcard_opts)
  if count > 5 then
    previews[#previews + 1] = '...'
  end
  return previews
end

-- =============================================================================
-- MODAL STATE
-- =============================================================================

local _state = {}  -- Keyed by modal ID

local function get_state(id)
  if not _state[id] then
    _state[id] = {
      is_open = false,
      pattern = '',
      preview_items = {},
      selected_color = 0xFF5733FF,
      picker_initialized = false,
      focus_input = false,
      separator = load_pref('separator', 'none'),
      start_index = tonumber(load_pref('start_index', '1')) or 1,
      padding = tonumber(load_pref('padding', '0')) or 0,
      letter_case = load_pref('letter_case', 'lowercase'),
      names_category = nil,  -- Will be set to first category
      mode = 'replace',
      overlay_pushed = false,
    }
  end
  return _state[id]
end

local function clear_state(id)
  _state[id] = nil
end

-- =============================================================================
-- MODAL RENDERING
-- =============================================================================

local function draw_content(ctx, state, config)
  local count = config.item_count
  local wildcards = config.wildcards or M.DEFAULT_WILDCARDS
  local name_categories = config.name_categories or M.DEFAULT_NAME_CATEGORIES
  local show_color_picker = config.show_color_picker ~= false
  local show_wildcards = config.show_wildcards ~= false
  local show_common_names = config.show_common_names ~= false and #name_categories > 0
  local modes = config.modes or {'replace'}
  local existing_names = config.existing_names

  local modal_w = config.content_w or 520
  local dl = Base.get_context(ctx):draw_list()

  -- Initialize category if not set
  if not state.names_category and #name_categories > 0 then
    state.names_category = name_categories[1].value
  end

  -- Layout calculations
  local picker_size = show_color_picker and 160 or 0
  local col_gap = show_color_picker and 24 or 0
  local right_col_width = modal_w - picker_size - col_gap
  local start_x = ImGui.GetCursorPosX(ctx) // 1

  -- Title
  local mode_label = state.mode == 'prefix' and 'Add Prefix to' or
                     state.mode == 'suffix' and 'Add Suffix to' or 'Rename'
  local title_text = string.format('%s %d %s', mode_label, count, config.item_type or 'items')
  local title_w = ImGui.CalcTextSize(ctx, title_text)
  ImGui.SetCursorPosX(ctx, math.floor(ImGui.GetCursorPosX(ctx) + (modal_w - title_w) * 0.5))
  ImGui.TextColored(ctx, 0xCCCCCCFF, title_text)
  ImGui.Dummy(ctx, 0, 24)

  local start_y = ImGui.GetCursorPosY(ctx)

  -- ==========================================================================
  -- LEFT COLUMN: Color Picker (if enabled)
  -- ==========================================================================

  if show_color_picker then
    ImGui.SetCursorPos(ctx, start_x, start_y)

    if not state.picker_initialized then
      ColorPickerWindow.show_inline('batch_renamer_picker_' .. (config.id or 'default'), state.selected_color)
      state.picker_initialized = true
    end

    ColorPickerWindow.render_inline(ctx, 'batch_renamer_picker_' .. (config.id or 'default'), {
      size = picker_size,
      on_change = function(color)
        state.selected_color = color
      end
    })

    -- Help icon
    ImGui.SetCursorPos(ctx, start_x + (picker_size - 32) * 0.5, start_y + picker_size + 8)
    local help_x, help_y = ImGui.GetCursorScreenPos(ctx)
    local help_size = 32
    local is_help_hovered = ImGui.IsMouseHoveringRect(ctx, help_x, help_y, help_x + help_size, help_y + help_size)
    local icon_color = is_help_hovered and 0xFFFFFFFF or 0x888888FF
    local actx = Context.get(ctx)
    local icon_font = actx:font('icons')
    local icon_size = actx:font_size('icons') or 40

    if icon_font then
      ImGui.PushFont(ctx, icon_font, icon_size)
      local icon_text = Unicode.utf8(0xF044)
      local text_w, text_h = ImGui.CalcTextSize(ctx, icon_text)
      ImGui.DrawList_AddText(dl, help_x + (help_size - text_w) * 0.5, help_y + (help_size - text_h) * 0.5, icon_color, icon_text)
      ImGui.PopFont(ctx)
    else
      -- Fallback: draw "?" text if icon font not available
      local fallback_text = '?'
      local text_w, text_h = ImGui.CalcTextSize(ctx, fallback_text)
      ImGui.DrawList_AddText(dl, help_x + (help_size - text_w) * 0.5, help_y + (help_size - text_h) * 0.5, icon_color, fallback_text)
    end

    ImGui.SetCursorPos(ctx, start_x + (picker_size - 32) * 0.5, start_y + picker_size + 8)
    ImGui.InvisibleButton(ctx, 'help_icon', help_size, help_size)

    if is_help_hovered then
      ImGui.BeginTooltip(ctx)
      ImGui.PushTextWrapPos(ctx, 400)
      ImGui.TextColored(ctx, 0xEEEEEEFF, 'Batch Renamer Help')
      ImGui.Separator(ctx)
      ImGui.Dummy(ctx, 0, 4)
      if #modes > 1 then
        ImGui.TextColored(ctx, 0xCCCCCCFF, 'Modes:')
        ImGui.BulletText(ctx, 'Replace = New name replaces old')
        ImGui.BulletText(ctx, 'Prefix = Add before existing name')
        ImGui.BulletText(ctx, 'Suffix = Add after existing name')
        ImGui.Dummy(ctx, 0, 4)
      end
      if show_wildcards then
        ImGui.TextColored(ctx, 0xCCCCCCFF, 'Wildcards:')
        ImGui.BulletText(ctx, '$n = number (0, 1, 2... or 1, 2, 3...)')
        ImGui.BulletText(ctx, '$l = letter (a, b, c... or A, B, C...)')
        ImGui.BulletText(ctx, 'Right-click wildcards for options')
        ImGui.Dummy(ctx, 0, 4)
      end
      if show_common_names then
        ImGui.TextColored(ctx, 0xCCCCCCFF, 'Tags:')
        ImGui.BulletText(ctx, 'Click to insert into pattern')
        ImGui.BulletText(ctx, 'SHIFT+Click = no separator')
        ImGui.BulletText(ctx, 'SHIFT+CTRL+Click = capitalize')
      end
      ImGui.PopTextWrapPos(ctx)
      ImGui.EndTooltip(ctx)
    end
  end

  -- ==========================================================================
  -- RIGHT COLUMN: Input, Mode, Wildcards, Tags
  -- ==========================================================================

  local right_col_x = show_color_picker and ((start_x + picker_size + col_gap) // 1) or start_x
  ImGui.SetCursorPos(ctx, right_col_x, start_y)

  -- Mode selector (if multiple modes)
  if #modes > 1 then
    ImGui.TextColored(ctx, 0x999999FF, 'Mode:')
    ImGui.Dummy(ctx, 0, 4)
    ImGui.SetCursorPosX(ctx, right_col_x)

    for i, mode in ipairs(modes) do
      if i > 1 then ImGui.SameLine(ctx, 0, 12) end
      local label = mode == 'replace' and 'Replace' or
                    mode == 'prefix' and 'Prefix' or 'Suffix'
      if RadioButton.Draw(ctx, {
        id = 'mode_' .. mode,
        label = label,
        selected = state.mode == mode,
        advance = 'none',
      }).clicked then
        state.mode = mode
        state.preview_items = generate_preview(state.pattern, count, existing_names, state.mode, {
          start_index = state.start_index,
          padding = state.padding,
          letter_case = state.letter_case,
        })
      end
    end

    ImGui.Dummy(ctx, 0, 12)
    ImGui.SetCursorPosX(ctx, right_col_x)
  end

  -- Pattern input
  local input_height = 32
  local screen_x, screen_y = ImGui.GetCursorScreenPos(ctx)

  if state.focus_input then
    ImGui.SetKeyboardFocusHere(ctx)
    state.focus_input = false
  end

  InputText.SetText('batch_renamer_pattern', state.pattern)

  local placeholder = state.mode == 'prefix' and 'prefix_' or
                      state.mode == 'suffix' and '_suffix' or 'pattern$wildcard'

  local result = InputText.Search(ctx, {
    id = 'batch_renamer_pattern',
    x = screen_x,
    y = screen_y,
    width = right_col_width,
    height = input_height,
    draw_list = dl,
    placeholder = placeholder,
    on_change = function(text)
      state.pattern = text
      state.preview_items = generate_preview(text, count, existing_names, state.mode, {
        start_index = state.start_index,
        padding = state.padding,
        letter_case = state.letter_case,
      })
    end
  })

  ImGui.SetCursorScreenPos(ctx, screen_x, screen_y + input_height)
  ImGui.Dummy(ctx, 0, 6)

  -- Wildcards (if enabled)
  if show_wildcards and #wildcards > 0 then
    ImGui.SetCursorPosX(ctx, right_col_x)
    ImGui.TextColored(ctx, 0x999999FF, 'Wildcards (right-click for options):')
    ImGui.Dummy(ctx, 0, 6)
    ImGui.SetCursorPosX(ctx, right_col_x)

    local btn_spacing = 6
    local wildcard_config = Theme.build_action_chip_config('wildcard')

    for i, wc in ipairs(wildcards) do
      if i > 1 then ImGui.SameLine(ctx, 0, btn_spacing) end

      local label = wc.label
      if wc.type == 'letter' then
        label = state.letter_case == 'uppercase' and label:upper() or label
      end

      local result = LabelButton.Draw(ctx, {
        label = label,
        id = 'wildcard_' .. i,
        bg_color = wildcard_config.bg_color,
        text_color = wildcard_config.text_color,
        border_color = 0x00000000,
        rounding = wildcard_config.rounding,
        padding_h = wildcard_config.padding_h,
      })

      if result.clicked then
        local is_shift = ImGui.IsKeyDown(ctx, ImGui.Key_LeftShift) or ImGui.IsKeyDown(ctx, ImGui.Key_RightShift)
        local sep = ''
        if not is_shift then
          if state.separator == 'underscore' then sep = '_'
          elseif state.separator == 'space' then sep = ' '
          elseif state.separator == 'dash' then sep = '-'
          end
        end
        state.pattern = state.pattern .. sep .. wc.wildcard
        state.preview_items = generate_preview(state.pattern, count, existing_names, state.mode, {
          start_index = state.start_index,
          padding = state.padding,
          letter_case = state.letter_case,
        })
      end

      -- Context menus for built-in wildcards
      if ImGui.IsItemHovered(ctx) and ImGui.IsMouseClicked(ctx, 1) then
        ImGui.OpenPopup(ctx, 'wildcard_ctx_' .. wc.type)
      end

      if wc.type == 'number' and ContextMenu.begin(ctx, 'wildcard_ctx_number') then
        ImGui.TextColored(ctx, 0x999999FF, 'Number Options')
        ContextMenu.separator(ctx)
        if ContextMenu.checkbox_item(ctx, 'Start from 0', state.start_index == 0) then
          state.start_index = 0
          save_pref('start_index', '0')
          state.preview_items = generate_preview(state.pattern, count, existing_names, state.mode, {
            start_index = state.start_index, padding = state.padding, letter_case = state.letter_case,
          })
        end
        if ContextMenu.checkbox_item(ctx, 'Start from 1', state.start_index == 1) then
          state.start_index = 1
          save_pref('start_index', '1')
          state.preview_items = generate_preview(state.pattern, count, existing_names, state.mode, {
            start_index = state.start_index, padding = state.padding, letter_case = state.letter_case,
          })
        end
        ContextMenu.separator(ctx)
        if ContextMenu.checkbox_item(ctx, 'No padding', state.padding == 0) then
          state.padding = 0
          save_pref('padding', '0')
          state.preview_items = generate_preview(state.pattern, count, existing_names, state.mode, {
            start_index = state.start_index, padding = state.padding, letter_case = state.letter_case,
          })
        end
        if ContextMenu.checkbox_item(ctx, 'Padding: 01', state.padding == 2) then
          state.padding = 2
          save_pref('padding', '2')
          state.preview_items = generate_preview(state.pattern, count, existing_names, state.mode, {
            start_index = state.start_index, padding = state.padding, letter_case = state.letter_case,
          })
        end
        if ContextMenu.checkbox_item(ctx, 'Padding: 001', state.padding == 3) then
          state.padding = 3
          save_pref('padding', '3')
          state.preview_items = generate_preview(state.pattern, count, existing_names, state.mode, {
            start_index = state.start_index, padding = state.padding, letter_case = state.letter_case,
          })
        end
        ContextMenu.end_menu(ctx)
      end

      if wc.type == 'letter' and ContextMenu.begin(ctx, 'wildcard_ctx_letter') then
        ImGui.TextColored(ctx, 0x999999FF, 'Letter Case')
        ContextMenu.separator(ctx)
        if ContextMenu.checkbox_item(ctx, 'lowercase (a, b, c...)', state.letter_case == 'lowercase') then
          state.letter_case = 'lowercase'
          save_pref('letter_case', 'lowercase')
          state.preview_items = generate_preview(state.pattern, count, existing_names, state.mode, {
            start_index = state.start_index, padding = state.padding, letter_case = state.letter_case,
          })
        end
        if ContextMenu.checkbox_item(ctx, 'UPPERCASE (A, B, C...)', state.letter_case == 'uppercase') then
          state.letter_case = 'uppercase'
          save_pref('letter_case', 'uppercase')
          state.preview_items = generate_preview(state.pattern, count, existing_names, state.mode, {
            start_index = state.start_index, padding = state.padding, letter_case = state.letter_case,
          })
        end
        ContextMenu.end_menu(ctx)
      end
    end

    ImGui.Dummy(ctx, 0, 6)
  end

  -- Common names/tags (if enabled and categories provided)
  if show_common_names then
    ImGui.SetCursorPosX(ctx, right_col_x)
    ImGui.TextColored(ctx, 0x999999FF, 'Tags:')

    if #name_categories > 1 then
      ImGui.SameLine(ctx, 0, 12)
      local dropdown_x, dropdown_y = ImGui.GetCursorScreenPos(ctx)

      Combo.Draw(ctx, {
        id = 'names_category',
        draw_list = dl,
        x = dropdown_x,
        y = dropdown_y,
        width = 120,
        height = 24,
        options = name_categories,
        current_value = state.names_category,
        on_change = function(value)
          state.names_category = value
        end,
      })

      ImGui.SetCursorScreenPos(ctx, dropdown_x, dropdown_y + 24)
    end

    ImGui.Dummy(ctx, 0, 6)
    ImGui.SetCursorPosX(ctx, right_col_x)

    -- Find current category
    local current_names = {}
    for _, cat in ipairs(name_categories) do
      if cat.value == state.names_category then
        current_names = cat.names or {}
        break
      end
    end

    -- Render tags in a clipped child window with justified layout
    local tags_height = 110
    local btn_spacing = 6
    local line_height = 30
    local tag_config = Theme.build_action_chip_config('tag')

    -- Calculate min widths for justified layout
    local min_widths = {}
    for i, name_data in ipairs(current_names) do
      min_widths[i] = LabelButton.calculate_width(ctx, name_data.name, {
        padding_h = tag_config.padding_h,
      })
    end

    -- Calculate justified layout
    local layout = ResponsiveGrid.calculate_justified_layout(current_names, {
      available_width = right_col_width,
      min_widths = min_widths,
      gap = btn_spacing,
      max_stretch_ratio = 1.5,
    })

    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 0, 0)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 0, 0)

    if ImGui.BeginChild(ctx, 'tags_child', right_col_width, tags_height, ImGui.ChildFlags_None, ImGui.WindowFlags_NoScrollbar) then
      local cur_line_y = 0

      for row_idx, row in ipairs(layout) do
        local cur_line_x = 0

        for cell_idx, cell in ipairs(row) do
          local name_data = cell.item
          local name = name_data.name
          local color = name_data.color

          ImGui.SetCursorPos(ctx, cur_line_x, cur_line_y)

          local result = LabelButton.Draw(ctx, {
            label = name,
            id = 'tag_' .. cell.index,
            bg_color = color,
            text_color = tag_config.text_color,
            border_color = 0x00000000,
            rounding = tag_config.rounding,
            padding_h = tag_config.padding_h,
            explicit_width = cell.final_width,
          })

          cur_line_x = cur_line_x + cell.final_width + btn_spacing

          if result.clicked then
            local is_shift = ImGui.IsKeyDown(ctx, ImGui.Key_LeftShift) or ImGui.IsKeyDown(ctx, ImGui.Key_RightShift)
            local is_ctrl = ImGui.IsKeyDown(ctx, ImGui.Key_LeftCtrl) or ImGui.IsKeyDown(ctx, ImGui.Key_RightCtrl)

            local name_text = name
            if is_shift and is_ctrl then
              name_text = name:sub(1, 1):upper() .. name:sub(2)
            end

            if is_shift then
              state.pattern = state.pattern .. name_text
            else
              if state.pattern ~= '' and not state.pattern:match('%s$') then
                state.pattern = state.pattern .. '_'
              end
              state.pattern = state.pattern .. name_text
            end

            state.preview_items = generate_preview(state.pattern, count, existing_names, state.mode, {
              start_index = state.start_index,
              padding = state.padding,
              letter_case = state.letter_case,
            })
          end
        end

        cur_line_y = cur_line_y + line_height
      end

      ImGui.EndChild(ctx)
    end

    ImGui.PopStyleVar(ctx, 2)
    ImGui.Dummy(ctx, 0, 6)
  end

  -- Separator selector
  if show_wildcards then
    ImGui.SetCursorPosX(ctx, right_col_x)
    ImGui.TextColored(ctx, 0x999999FF, 'Separator before wildcard:')
    ImGui.Dummy(ctx, 0, 6)
    ImGui.SetCursorPosX(ctx, right_col_x)

    for i, sep in ipairs(M.SEPARATORS) do
      if i > 1 then ImGui.SameLine(ctx, 0, 12) end
      if RadioButton.Draw(ctx, {
        id = 'sep_' .. sep.value,
        label = sep.label,
        selected = state.separator == sep.value,
        advance = 'none',
      }).clicked then
        state.separator = sep.value
        save_pref('separator', sep.value)
      end
    end
  end

  -- Final Y position
  local right_col_cursor_y = ImGui.GetCursorPosY(ctx)
  local left_col_end_y = show_color_picker and (start_y + picker_size) or start_y
  local final_y = math.max(right_col_cursor_y, left_col_end_y)

  ImGui.SetCursorPosY(ctx, final_y + 20)
  ImGui.SetCursorPosX(ctx, start_x)

  -- Preview
  if #state.preview_items > 0 then
    ImGui.SetCursorPosX(ctx, start_x)
    ImGui.TextColored(ctx, 0x999999FF, 'Preview:')
    ImGui.Dummy(ctx, 0, 4)
    ImGui.Indent(ctx, start_x + 12)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 0, 2)
    for _, name in ipairs(state.preview_items) do
      ImGui.TextColored(ctx, 0xDDDDDDFF, name)
    end
    ImGui.PopStyleVar(ctx, 1)
    ImGui.Unindent(ctx, start_x + 12)
  end

  ImGui.Dummy(ctx, 0, 20)
  ImGui.SetCursorPosX(ctx, start_x)

  -- Buttons
  local button_h = 32
  local spacing = 10
  local button_w_small = 100
  local button_w_large = 150

  local can_rename = state.pattern ~= ''
  local buttons = {}

  -- Build button list based on config
  buttons[#buttons + 1] = { label = 'Cancel', action = 'cancel', enabled = true, width = button_w_small }

  if state.mode == 'replace' then
    buttons[#buttons + 1] = { label = 'Rename', action = 'rename', enabled = can_rename, width = button_w_small }
    if show_color_picker then
      buttons[#buttons + 1] = { label = 'Rename & Recolor', action = 'rename_and_recolor', enabled = can_rename, width = button_w_large }
      buttons[#buttons + 1] = { label = 'Recolor', action = 'recolor', enabled = true, width = button_w_small }
    end
  else
    -- Prefix/suffix mode
    buttons[#buttons + 1] = { label = 'Apply', action = 'rename', enabled = can_rename, width = button_w_small }
    if show_color_picker then
      buttons[#buttons + 1] = { label = 'Apply & Recolor', action = 'rename_and_recolor', enabled = can_rename, width = button_w_large }
      buttons[#buttons + 1] = { label = 'Recolor', action = 'recolor', enabled = true, width = button_w_small }
    end
  end

  local total_w = 0
  for _, btn in ipairs(buttons) do
    total_w = total_w + btn.width + spacing
  end
  total_w = total_w - spacing

  local button_start_x = (start_x + (modal_w - total_w) * 0.5) // 1
  ImGui.SetCursorPosX(ctx, button_start_x)
  local button_y = ImGui.GetCursorPosY(ctx)
  local screen_bx, screen_by = ImGui.GetCursorScreenPos(ctx)

  local should_close = false
  local result_action = nil

  local current_x = screen_bx
  for _, btn in ipairs(buttons) do
    local btn_result = Button.Draw(ctx, {
      id = 'batch_renamer_' .. btn.action,
      draw_list = dl,
      x = current_x,
      y = screen_by,
      width = btn.width,
      height = button_h,
      label = btn.label,
      rounding = 4,
      is_disabled = not btn.enabled,
      ignore_modal = true,
    })

    if btn_result.clicked then
      if btn.action == 'cancel' then
        should_close = true
      else
        result_action = btn.action
        should_close = true
      end
    end

    current_x = current_x + btn.width + spacing
  end

  -- Escape to close
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
    should_close = true
  end

  -- Enter to confirm rename
  if can_rename and ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
    result_action = 'rename'
    should_close = true
  end

  ImGui.SetCursorPosY(ctx, button_y + button_h)

  return should_close, result_action
end

-- =============================================================================
-- PUBLIC API
-- =============================================================================

--- Show the batch renamer modal
--- @param ctx userdata ImGui context
--- @param window table Window object with overlay
--- @param opts table Configuration options
function M.show(ctx, window, opts)
  opts = opts or {}
  local id = opts.id or '##batch_renamer'

  if not window or not window.overlay then
    return false
  end

  local state = get_state(id)

  if not state.overlay_pushed then
    state.overlay_pushed = true
    state.is_open = true
    state.pattern = ''
    state.preview_items = {}
    state.focus_input = true
    state.picker_initialized = false
    state.selected_color = opts.initial_color or 0xFF5733FF
    state.mode = opts.default_mode or (opts.modes and opts.modes[1]) or 'replace'

    -- Store config for rendering
    state.config = {
      item_count = opts.item_count or 0,
      item_type = opts.item_type or 'items',
      wildcards = opts.wildcards,
      name_categories = opts.name_categories,
      show_color_picker = opts.show_color_picker,
      show_wildcards = opts.show_wildcards,
      show_common_names = opts.show_common_names,
      modes = opts.modes or {'replace'},
      existing_names = opts.existing_names,
      on_confirm = opts.on_confirm,
    }

    window.overlay:push({
      id = id,
      close_on_scrim = false,
      esc_to_close = true,
      on_close = function()
        state.is_open = false
        state.overlay_pushed = false
      end,
      render = function(ctx, alpha, bounds)
        local max_w = 900
        local max_h = 700
        local min_w = 700
        local min_h = 450

        local modal_w = math.floor(math.max(min_w, math.min(max_w, bounds.w * 0.85)))
        local modal_h = math.floor(math.max(min_h, math.min(max_h, bounds.h * 0.85)))
        local modal_x = bounds.x + math.floor((bounds.w - modal_w) * 0.5)
        local modal_y = bounds.y + math.floor((bounds.h - modal_h) * 0.5)

        local padding = 40
        local content_w = modal_w - padding * 2

        state.config.content_w = content_w

        ImGui.SetCursorScreenPos(ctx, modal_x + padding, modal_y + padding)
        local should_close, action = draw_content(ctx, state, state.config)

        if should_close then
          if action and state.config.on_confirm then
            local wildcard_opts = {
              start_index = state.start_index,
              padding = state.padding,
              letter_case = state.letter_case,
            }
            state.config.on_confirm({
              pattern = state.pattern,
              mode = state.mode,
              action = action,
              color = (action == 'rename_and_recolor' or action == 'recolor') and state.selected_color or nil,
              names = generate_names(
                state.pattern,
                state.config.item_count,
                state.config.existing_names,
                state.mode,
                wildcard_opts
              ),
            })
          end
          window.overlay:pop(id)
          state.is_open = false
          state.overlay_pushed = false
        end
      end
    })
  end

  return true
end

--- Check if a batch renamer modal is open
--- @param id string|nil Modal ID (defaults to '##batch_renamer')
--- @return boolean
function M.is_open(id)
  id = id or '##batch_renamer'
  local state = _state[id]
  return state and state.is_open or false
end

--- Apply pattern to generate names (utility function)
--- @param pattern string Pattern with wildcards
--- @param count number Number of names to generate
--- @param opts table|nil Options: existing_names, mode, start_index, padding, letter_case
--- @return table names Generated names
function M.apply_pattern(pattern, count, opts)
  opts = opts or {}
  return generate_names(
    pattern,
    count,
    opts.existing_names,
    opts.mode or 'replace',
    {
      start_index = opts.start_index or 1,
      padding = opts.padding or 0,
      letter_case = opts.letter_case or 'lowercase',
    }
  )
end

return M

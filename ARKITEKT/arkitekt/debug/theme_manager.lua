-- @noindex
-- arkitekt/debug/theme_manager.lua
-- Live theme debugger with editing and export
--
-- Features:
--   - Live editing of DSL values (lerp, offset, snap)
--   - Real-time palette regeneration
--   - Export as Lua DSL code (for theme.lua)
--   - Separate export for global and script palettes

local Colors = require('arkitekt.core.colors')
local Palette = require('arkitekt.config.colors')
local Engine = require('arkitekt.theme.manager.engine')
local Registry = require('arkitekt.theme.manager.registry')

local M = {}

-- Lazy load Theme to avoid circular dependency
local _Theme
local function get_theme()
  if not _Theme then
    _Theme = require('arkitekt.theme')
  end
  return _Theme
end

-- =============================================================================
-- DEBUG STATE
-- =============================================================================

M.debug_enabled = false

-- Temporary overrides (session only, not persisted)
-- Structure: { KEY = { dark = val, light = val }, ... }
M.overrides = {}

-- Track which keys have been modified
M.modified_keys = {}
M._mod_count = 0  -- Cached count of modified keys

-- Validation cache
M._validation_cache = nil  -- { valid = bool, err = string|nil }
M._validation_dirty = true

-- Filtered palette cache
M._filtered_cache = nil  -- { categories = {}, total_keys = number }
M._filter_cache_key = ''  -- filter_text .. show_only_modified

-- Category order (matches theme.lua structure)
local CATEGORY_ORDER = {
  'BG', 'BORDER', 'ACCENT', 'TEXT', 'PATTERN',
  'TILE', 'BADGE', 'PLAYLIST', 'OP', 'BUTTON'
}

-- UI state
M.scroll_y = 0
M.filter_text = ''
M.show_only_modified = false
M.show_script_column = false  -- Toggle for two-column view
M.selected_script = nil       -- Currently selected script for column view
M.expand_global = true
M.expand_scripts = {}

function M.toggle_debug()
  M.debug_enabled = not M.debug_enabled
end

function M.enable_debug()
  M.debug_enabled = true
end

function M.disable_debug()
  M.debug_enabled = false
end

-- =============================================================================
-- OVERRIDE MANAGEMENT
-- =============================================================================

--- Apply an override to a palette key
--- @param key string Palette key
--- @param field string 'dark' or 'light'
--- @param value any New value
function M.set_override(key, field, value)
  if not M.overrides[key] then
    -- Initialize from original definition
    local def = Palette.colors[key]
    if def and type(def) == 'table' and def.mode then
      M.overrides[key] = {
        mode = def.mode,
        dark = def.dark,
        light = def.light,
      }
    else
      return -- Can't override non-DSL values
    end
  end

  M.overrides[key][field] = value
  if not M.modified_keys[key] then
    M.modified_keys[key] = true
    M._mod_count = M._mod_count + 1
  end

  -- Invalidate caches
  M._filtered_cache = nil

  -- Regenerate palette with overrides
  M.apply_overrides()
end

--- Restore a single key to its original value
local function restore_original(key)
  local Theme = get_theme()
  local base_bg = Theme.COLORS.BG_BASE
  if not base_bg then return end

  local original_def = Palette.colors[key]
  if not original_def then return end

  local _, _, bg_lightness = Colors.RgbToHsl(base_bg)
  local t = Engine.compute_t(bg_lightness)

  local original_value = Engine.derive_entry(base_bg, original_def, t)
  if original_value then
    Theme.COLORS[key] = original_value
  end
end

--- Clear override for a key (revert to original)
function M.clear_override(key)
  M.overrides[key] = nil
  if M.modified_keys[key] then
    M.modified_keys[key] = nil
    M._mod_count = M._mod_count - 1
  end
  -- Invalidate caches
  M._filtered_cache = nil
  -- Restore the original value for this key
  restore_original(key)
  Registry.clear_cache()
end

--- Clear all overrides
function M.clear_all_overrides()
  -- Collect keys to restore before clearing
  local keys_to_restore = {}
  for key in pairs(M.overrides) do
    keys_to_restore[#keys_to_restore + 1] = key
  end

  M.overrides = {}
  M.modified_keys = {}
  M._mod_count = 0

  -- Invalidate caches
  M._filtered_cache = nil

  -- Restore all original values
  for _, key in ipairs(keys_to_restore) do
    restore_original(key)
  end
  Registry.clear_cache()
end

--- Apply current overrides to Theme.COLORS
function M.apply_overrides()
  local Theme = get_theme()
  local base_bg = Theme.COLORS.BG_BASE
  if not base_bg then return end

  local _, _, bg_lightness = Colors.RgbToHsl(base_bg)
  local t = Engine.compute_t(bg_lightness)

  -- Regenerate each overridden key
  for key, override in pairs(M.overrides) do
    local def = {
      mode = override.mode,
      dark = override.dark,
      light = override.light,
    }

    -- Derive the new value
    local new_value = Engine.derive_entry(base_bg, def, t)
    if new_value then
      Theme.COLORS[key] = new_value
    end
  end

  -- Clear script palette cache so they regenerate
  Registry.clear_cache()
end

-- =============================================================================
-- VALIDATION
-- =============================================================================

--- Validate colors structure (cached)
function M.validate()
  -- Return cached result if available
  if M._validation_cache and not M._validation_dirty then
    return M._validation_cache.valid, M._validation_cache.err
  end

  local errors = {}
  local valid_modes = { bg = true, lerp = true, offset = true, snap = true }

  for key, def in pairs(Palette.colors) do
    if type(def) == 'table' and def.mode then
      if not valid_modes[def.mode] then
        errors[#errors + 1] = string.format(
          "colors.%s has invalid mode '%s'",
          key, tostring(def.mode)
        )
      end
      if def.mode ~= 'bg' then
        if def.dark == nil then
          errors[#errors + 1] = string.format("colors.%s missing 'dark' value", key)
        end
        if def.light == nil then
          errors[#errors + 1] = string.format("colors.%s missing 'light' value", key)
        end
      end
    elseif type(def) ~= 'table' then
      errors[#errors + 1] = string.format(
        "colors.%s is raw value '%s' (missing DSL wrapper?)",
        key, tostring(def)
      )
    end
  end

  local valid, err
  if #errors > 0 then
    valid, err = false, table.concat(errors, '\n')
  else
    valid, err = true, nil
  end

  -- Cache the result
  M._validation_cache = { valid = valid, err = err }
  M._validation_dirty = false

  return valid, err
end

--- Get validation summary
function M.get_validation_summary()
  local valid, err = M.validate()
  local count = 0
  for _ in pairs(Palette.colors) do count = count + 1 end
  return {
    valid = valid,
    error_message = err,
    color_count = count,
    error_count = err and select(2, err:gsub('\n', '\n')) + 1 or 0,
  }
end

-- =============================================================================
-- EXPORT AS LUA
-- =============================================================================

--- Format a value for Lua export
local function format_value(val)
  if type(val) == 'string' then
    return string.format(''%s'', val)
  elseif type(val) == 'number' then
    -- Format nicely: remove trailing zeros
    local formatted = string.format('%.4f', val):gsub('%.?0+$', '')
    if formatted == '' or formatted == '-' then formatted = '0' end
    return formatted
  else
    return tostring(val)
  end
end

--- Export global palette as Lua DSL code
function M.export_global_as_lua()
  local lines = {}
  lines[#lines + 1] = 'M.colors = {'

  -- Group by category (based on prefix)
  local categories = {}

  -- Collect all keys and categorize
  local all_keys = {}
  for key in pairs(Palette.colors) do
    all_keys[#all_keys + 1] = key
  end
  table.sort(all_keys)

  for _, key in ipairs(all_keys) do
    local def = M.overrides[key] or Palette.colors[key]
    if type(def) == 'table' and def.mode then
      -- Find category
      local cat = 'OTHER'
      for _, prefix in ipairs(CATEGORY_ORDER) do
        if key:sub(1, #prefix) == prefix then
          cat = prefix
          break
        end
      end

      categories[cat] = categories[cat] or {}
      categories[cat][#categories[cat] + 1] = { key = key, def = def }
    end
  end

  -- Output by category
  for _, cat in ipairs(CATEGORY_ORDER) do
    if categories[cat] and #categories[cat] > 0 then
      lines[#lines + 1] = ''
      lines[#lines + 1] = string.format('  -- === %s ===', cat)

      for _, item in ipairs(categories[cat]) do
        local key, def = item.key, item.def
        local modified = M.modified_keys[key] and ' -- MODIFIED' or ''

        if def.mode == 'bg' then
          lines[#lines + 1] = string.format('  %s = bg(),%s', key, modified)
        elseif def.mode == 'lerp2' then
          lines[#lines + 1] = string.format('  %s = lerp2(%s, %s),%s',
            key, format_value(def.dark), format_value(def.light), modified)
        elseif def.mode == 'offset2' then
          if def.dark == def.light then
            lines[#lines + 1] = string.format('  %s = offset2(%s),%s',
              key, format_value(def.dark), modified)
          else
            lines[#lines + 1] = string.format('  %s = offset2(%s, %s),%s',
              key, format_value(def.dark), format_value(def.light), modified)
          end
        elseif def.mode == 'snap2' then
          lines[#lines + 1] = string.format('  %s = snap2(%s, %s),%s',
            key, format_value(def.dark), format_value(def.light), modified)
        end
      end
    end
  end

  -- Handle OTHER category
  if categories.OTHER and #categories.OTHER > 0 then
    lines[#lines + 1] = ''
    lines[#lines + 1] = '  -- === OTHER ==='
    for _, item in ipairs(categories.OTHER) do
      local key, def = item.key, item.def
      local modified = M.modified_keys[key] and ' -- MODIFIED' or ''
      if def.mode == 'lerp2' then
        lines[#lines + 1] = string.format('  %s = lerp2(%s, %s),%s',
          key, format_value(def.dark), format_value(def.light), modified)
      elseif def.mode == 'snap2' then
        lines[#lines + 1] = string.format('  %s = snap2(%s, %s),%s',
          key, format_value(def.dark), format_value(def.light), modified)
      end
    end
  end

  lines[#lines + 1] = '}'

  return table.concat(lines, '\n')
end

--- Export only modified values as Lua
function M.export_modified_as_lua()
  if not next(M.modified_keys) then
    return '-- No modifications'
  end

  local lines = {}
  lines[#lines + 1] = '-- Modified values only:'

  local sorted_keys = {}
  for key in pairs(M.modified_keys) do
    sorted_keys[#sorted_keys + 1] = key
  end
  table.sort(sorted_keys)

  for _, key in ipairs(sorted_keys) do
    local def = M.overrides[key]
    if def then
      if def.mode == 'lerp2' then
        lines[#lines + 1] = string.format('  %s = lerp2(%s, %s),',
          key, format_value(def.dark), format_value(def.light))
      elseif def.mode == 'offset2' then
        if def.dark == def.light then
          lines[#lines + 1] = string.format('  %s = offset2(%s),',
            key, format_value(def.dark))
        else
          lines[#lines + 1] = string.format('  %s = offset2(%s, %s),',
            key, format_value(def.dark), format_value(def.light))
        end
      elseif def.mode == 'snap2' then
        lines[#lines + 1] = string.format('  %s = snap2(%s, %s),',
          key, format_value(def.dark), format_value(def.light))
      end
    end
  end

  return table.concat(lines, '\n')
end

--- Copy text to clipboard (REAPER)
local function copy_to_clipboard(text)
  if reaper and reaper.CF_SetClipboard then
    reaper.CF_SetClipboard(text)
    return true
  end
  return false
end

-- =============================================================================
-- UI RENDERING
-- =============================================================================

--- Draw a slider for a numeric value
local function draw_slider(ctx, ImGui, label, value, min_val, max_val, format)
  format = format or '%.3f'
  ImGui.SetNextItemWidth(ctx, 120)
  local changed, new_val = ImGui.SliderDouble(ctx, label, value, min_val, max_val, format)
  return changed, new_val
end

--- Get slider range for a key based on its type
--- @param key string Palette key name
--- @return number min, number max
local function get_slider_range(key)
  local range = Palette.get_range_for_key(key)
  if range then
    return range.min, range.max
  end
  -- Default range for unknown types
  return 0, 2
end

--- Parse hex string to simple 0xRRGGBB (no alpha)
local function hex_to_rgb(hex)
  if not hex then return 0x808080 end
  local h = hex:gsub('#', '')
  -- If 8-char hex (RRGGBBAA), strip alpha
  if #h == 8 then h = h:sub(1, 6) end
  return tonumber(h, 16) or 0x808080
end

--- Format 0xRRGGBB to hex string
local function rgb_to_hex(color_int)
  return string.format('#%06X', color_int & 0xFFFFFF)
end

--- Draw a color picker for a hex string
--- ColorEdit3 uses simple 0xRRGGBB format - no conversion needed
local function draw_color_picker(ctx, ImGui, label, hex_value)
  -- Parse hex to simple RGB int (no alpha)
  local color_rgb = hex_to_rgb(hex_value)

  -- Color picker flags
  local flags = ImGui.ColorEditFlags_NoInputs
              | ImGui.ColorEditFlags_NoLabel
              | ImGui.ColorEditFlags_NoAlpha

  local changed, new_color = ImGui.ColorEdit3(ctx, label, color_rgb, flags)

  if changed then
    return true, rgb_to_hex(new_color)
  end

  return false, hex_value
end

--- Draw editor for a single DSL entry
local function draw_entry_editor(ctx, ImGui, key, original_def, current_def)
  local def = current_def or original_def
  if type(def) ~= 'table' or not def.mode then return end

  local modified = M.modified_keys[key]
  local mode = def.mode

  ImGui.PushID(ctx, key)

  -- Key name with modification indicator
  if modified then
    ImGui.TextColored(ctx, 0xFFAA00FF, key)
  else
    ImGui.Text(ctx, key)
  end

  ImGui.SameLine(ctx, 200)
  ImGui.TextDisabled(ctx, string.format('[%s]', mode))

  if mode == 'bg' then
    ImGui.SameLine(ctx)
    ImGui.TextDisabled(ctx, '(passthrough)')

  elseif mode == 'offset2' or mode == 'offset3' then
    ImGui.SameLine(ctx)

    -- Dark offset
    local changed_d, new_d = draw_slider(ctx, ImGui, '##dark', def.dark or 0, -0.5, 0.5, 'D:%+.3f')
    if changed_d then M.set_override(key, 'dark', new_d) end

    ImGui.SameLine(ctx)
    ImGui.Text(ctx, '/')
    ImGui.SameLine(ctx)

    -- Light offset
    local changed_l, new_l = draw_slider(ctx, ImGui, '##light', def.light or 0, -0.5, 0.5, 'L:%+.3f')
    if changed_l then M.set_override(key, 'light', new_l) end

  elseif mode == 'snap2' or mode == 'lerp2' or mode == 'snap3' or mode == 'lerp3' then
    ImGui.SameLine(ctx)

    -- Get appropriate range for this key
    local range_min, range_max = get_slider_range(key)

    -- Dark value
    if type(def.dark) == 'string' then
      local changed, new_val = draw_color_picker(ctx, ImGui, '##dark', def.dark)
      if changed then M.set_override(key, 'dark', new_val) end
    elseif type(def.dark) == 'number' then
      local changed, new_val = draw_slider(ctx, ImGui, '##dark', def.dark, range_min, range_max, 'D:%.3f')
      if changed then M.set_override(key, 'dark', new_val) end
    end

    ImGui.SameLine(ctx)
    ImGui.Text(ctx, '|')
    ImGui.SameLine(ctx)

    -- Light value
    if type(def.light) == 'string' then
      local changed, new_val = draw_color_picker(ctx, ImGui, '##light', def.light)
      if changed then M.set_override(key, 'light', new_val) end
    elseif type(def.light) == 'number' then
      local changed, new_val = draw_slider(ctx, ImGui, '##light', def.light, range_min, range_max, 'L:%.3f')
      if changed then M.set_override(key, 'light', new_val) end
    end

  end

  -- Reset button for modified entries
  if modified then
    ImGui.SameLine(ctx)
    if ImGui.SmallButton(ctx, 'Reset##' .. key) then
      M.clear_override(key)
    end
  end

  ImGui.PopID(ctx)
end

--- Render debug window
function M.render_debug_window(ctx, ImGui, state)
  if not M.debug_enabled then return end
  if not ctx or not ImGui then return end

  -- Validate context is still valid
  if ImGui.ValidatePtr and not ImGui.ValidatePtr(ctx, 'ImGui_Context*') then
    return
  end

  local lightness = state.lightness or 0.14
  local t = state.t or 0
  local current_mode = state.mode

  -- Window setup - style is already pushed by shell
  ImGui.SetNextWindowSize(ctx, 750, 650, ImGui.Cond_FirstUseEver)

  -- Use unique ID suffix to prevent window ID collisions with other widgets
  local visible, open = ImGui.Begin(ctx, 'Theme Debugger###ark_theme_debug', true)
  if not visible then
    ImGui.End(ctx)
    if not open then
      M.debug_enabled = false
    end
    return
  end

  -- Header info
  ImGui.Text(ctx, string.format('Mode: %s | Lightness: %.3f | t: %.3f',
    current_mode or 'nil', lightness, t))

  -- Validation status
  local valid, err = M.validate()
  ImGui.SameLine(ctx)
  if valid then
    ImGui.TextColored(ctx, 0x4CAF50FF, '[Valid]')
  else
    ImGui.TextColored(ctx, 0xEF5350FF, '[Errors]')
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, err)
    end
  end

  -- Modified count (cached)
  local mod_count = M._mod_count
  if mod_count > 0 then
    ImGui.SameLine(ctx)
    ImGui.TextColored(ctx, 0xFFAA00FF, string.format('[%d modified]', mod_count))
  end

  ImGui.Separator(ctx)

    -- Toolbar
    if ImGui.Button(ctx, 'Copy All as Lua') then
      local lua_code = M.export_global_as_lua()
      if copy_to_clipboard(lua_code) then
        reaper.ShowConsoleMsg('Theme Debugger: Copied to clipboard!\n')
      end
    end

    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, 'Copy Modified') then
      local lua_code = M.export_modified_as_lua()
      if copy_to_clipboard(lua_code) then
        reaper.ShowConsoleMsg('Theme Debugger: Modified values copied!\n')
      end
    end

    ImGui.SameLine(ctx)
    if mod_count > 0 then
      if ImGui.Button(ctx, 'Reset All') then
        M.clear_all_overrides()
      end
    else
      ImGui.BeginDisabled(ctx)
      ImGui.Button(ctx, 'Reset All')
      ImGui.EndDisabled(ctx)
    end

    ImGui.SameLine(ctx)
    ImGui.Text(ctx, '  ')
    ImGui.SameLine(ctx)
    local _, show_mod = ImGui.Checkbox(ctx, 'Show modified only', M.show_only_modified)
    M.show_only_modified = show_mod

    ImGui.SameLine(ctx)
    local _, show_scripts = ImGui.Checkbox(ctx, 'Script column', M.show_script_column)
    M.show_script_column = show_scripts

    -- Script selector (when script column enabled)
    local script_names = {}
    for name in pairs(Registry.script_palettes) do
      script_names[#script_names + 1] = name
    end
    table.sort(script_names)

    if M.show_script_column and #script_names > 0 then
      ImGui.SameLine(ctx)
      ImGui.SetNextItemWidth(ctx, 150)

      -- Auto-select first script if none selected
      if not M.selected_script or not Registry.script_palettes[M.selected_script] then
        M.selected_script = script_names[1]
      end

      -- Find current index
      local current_idx = 1
      for i, name in ipairs(script_names) do
        if name == M.selected_script then
          current_idx = i
          break
        end
      end

      local combo_items = table.concat(script_names, '\0') .. '\0'
      local changed, new_idx = ImGui.Combo(ctx, '##script_select', current_idx, combo_items)
      if changed then
        M.selected_script = script_names[new_idx]
      end
    end

    ImGui.Separator(ctx)

    -- Filter
    ImGui.SetNextItemWidth(ctx, 200)
    local _, filter = ImGui.InputText(ctx, 'Filter', M.filter_text)
    M.filter_text = filter

    ImGui.Separator(ctx)

    -- Scrollable content
    ImGui.BeginChild(ctx, 'palette_list', 0, 0, 0)

      -- Global palette section
      local global_open = ImGui.CollapsingHeader(ctx, 'Global Theme Colors', ImGui.TreeNodeFlags_DefaultOpen)
      if global_open then
        -- Build cache key from filter state
        local cache_key = M.filter_text .. (M.show_only_modified and '1' or '0')

        -- Rebuild categories only when filter changes or cache invalidated
        local categories
        if M._filtered_cache and M._filter_cache_key == cache_key then
          categories = M._filtered_cache
        else
          categories = {}
          local filter_lower = M.filter_text ~= '' and M.filter_text:lower() or nil

          for key in pairs(Palette.colors) do
            local include = true

            -- Filter check (pre-computed filter_lower)
            if filter_lower then
              include = key:lower():find(filter_lower, 1, true) ~= nil
            end

            -- Modified-only check
            if M.show_only_modified and not M.modified_keys[key] then
              include = false
            end

            if include then
              -- Find category
              local cat = 'OTHER'
              for _, prefix in ipairs(CATEGORY_ORDER) do
                if key:sub(1, #prefix) == prefix then
                  cat = prefix
                  break
                end
              end
              categories[cat] = categories[cat] or {}
              categories[cat][#categories[cat] + 1] = key
            end
          end

          -- Sort keys within each category
          for _, keys in pairs(categories) do
            table.sort(keys)
          end

          -- Cache the result
          M._filtered_cache = categories
          M._filter_cache_key = cache_key
        end

        -- Get selected script palette for comparison
        local script_palette = nil
        if M.show_script_column and M.selected_script then
          script_palette = Registry.script_palettes[M.selected_script]
        end

        -- Draw entries by category
        local total_keys = 0
        for _, cat in ipairs(CATEGORY_ORDER) do
          if categories[cat] and #categories[cat] > 0 then
            ImGui.TextDisabled(ctx, '-- ' .. cat .. ' --')
            for _, key in ipairs(categories[cat]) do
              local original = Palette.colors[key]
              local current = M.overrides[key]
              draw_entry_editor(ctx, ImGui, key, original, current)

              -- Show script override indicator if script has this key
              if script_palette and script_palette[key] then
                ImGui.SameLine(ctx)
                ImGui.TextColored(ctx, 0x4CAF50FF, '[S]')
                if ImGui.IsItemHovered(ctx) then
                  local script_def = script_palette[key]
                  local tip = string.format('Script override: %s', M.selected_script)
                  if type(script_def) == 'table' and script_def.mode then
                    tip = tip .. string.format('\nMode: %s', script_def.mode)
                    if script_def.dark then
                      tip = tip .. string.format('\nDark: %s', format_value(script_def.dark))
                    end
                    if script_def.light then
                      tip = tip .. string.format('\nLight: %s', format_value(script_def.light))
                    end
                  end
                  ImGui.SetTooltip(ctx, tip)
                end
              end

              total_keys = total_keys + 1
            end
            ImGui.Spacing(ctx)
          end
        end

        -- Handle OTHER category
        if categories.OTHER and #categories.OTHER > 0 then
          ImGui.TextDisabled(ctx, '-- OTHER --')
          for _, key in ipairs(categories.OTHER) do
            local original = Palette.colors[key]
            local current = M.overrides[key]
            draw_entry_editor(ctx, ImGui, key, original, current)

            -- Show script override indicator
            if script_palette and script_palette[key] then
              ImGui.SameLine(ctx)
              ImGui.TextColored(ctx, 0x4CAF50FF, '[S]')
            end

            total_keys = total_keys + 1
          end
        end

        if total_keys == 0 then
          ImGui.TextDisabled(ctx, '(no matching entries)')
        end
      end

      ImGui.Spacing(ctx)

      -- Script palettes
      local script_filter_lower = M.filter_text ~= '' and M.filter_text:lower() or nil
      for script_name, palette_def in pairs(Registry.script_palettes) do
        local header = string.format('Script: %s', script_name)
        if ImGui.CollapsingHeader(ctx, header) then
          local keys = {}
          for key in pairs(palette_def) do
            local include = true
            if script_filter_lower then
              include = key:lower():find(script_filter_lower, 1, true) ~= nil
            end
            if include then
              keys[#keys + 1] = key
            end
          end
          table.sort(keys)

          for _, key in ipairs(keys) do
            local def = palette_def[key]
            if type(def) == 'table' and def.mode then
              ImGui.PushID(ctx, script_name .. '_' .. key)
              ImGui.Text(ctx, key)
              ImGui.SameLine(ctx, 200)
              ImGui.TextDisabled(ctx, string.format('[%s]', def.mode))

              -- Show values (read-only for now)
              if def.mode == 'lerp2' or def.mode == 'snap2' or def.mode == 'lerp3' or def.mode == 'snap3' then
                ImGui.SameLine(ctx)
                ImGui.TextDisabled(ctx, string.format('D:%s L:%s',
                  format_value(def.dark), format_value(def.light)))
              elseif def.mode == 'offset2' or def.mode == 'offset3' then
                ImGui.SameLine(ctx)
                ImGui.TextDisabled(ctx, string.format('D:%+.3f L:%+.3f',
                  def.dark or 0, def.light or 0))
              end

              ImGui.PopID(ctx)
            end
          end
        end
      end

  ImGui.EndChild(ctx)

  ImGui.End(ctx)

  if not open then
    M.debug_enabled = false
  end
end

--- Check for F12 key press to toggle debug window
function M.check_debug_hotkey(ctx, ImGui)
  if not ctx or not ImGui then return end
  if ImGui.IsKeyPressed and ImGui.Key_F12 then
    if ImGui.IsKeyPressed(ctx, ImGui.Key_F12) then
      M.toggle_debug()
    end
  end
end

return M

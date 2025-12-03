-- @noindex
-- ThemeAdjuster/ui/views/result_modal.lua
-- Result modal showing the final resolution breakdown

local ImGui = require('arkitekt.core.imgui')
local Ark = require('arkitekt')
local ImageMap = require('ThemeAdjuster.domain.packages.image_map')
local Constants = require('ThemeAdjuster.config.constants')

local M = {}
local ResultModal = {}
ResultModal.__index = ResultModal

-- Tile constants
local TILE_WIDTH = 220
local TILE_HEIGHT = 28
local TILE_SPACING = 4

-- Use shared theme category colors palette
local TC = Constants.THEME_CATEGORY_COLORS

-- Map area names to palette colors
local AREA_COLORS = {
  TCP = TC.tcp_blue,
  MCP = TC.mcp_green,
  Transport = TC.transport_gold,
  Toolbar = TC.toolbar_gold,
  ENVCP = TC.envcp_purple,
  Meter = TC.meter_cyan,
  Global = TC.global_gray,
  Items = TC.items_pink,
  MIDI = TC.midi_teal,
  Docker = TC.docker_brown,
  FX = TC.fx_orange,
  Menu = TC.menu_blue,
  Other = TC.other_slate,
}

-- Helper to extract area from key
local function get_area_from_key(key)
  if key:match('^tcp_') or key:match('^track_') then return 'TCP'
  elseif key:match('^mcp_') or key:match('^master_') or key:match('^mixer_') then return 'MCP'
  elseif key:match('^transport_') or key:match('^trans_') then return 'Transport'
  elseif key:match('^toolbar_') or key:match('^tb_') then return 'Toolbar'
  elseif key:match('^envcp_') or key:match('^env_') then return 'ENVCP'
  elseif key:match('^meter_') then return 'Meter'
  elseif key:match('^item_') or key:match('^mi_') then return 'Items'
  elseif key:match('^midi_') or key:match('^piano_') then return 'MIDI'
  elseif key:match('^docker_') or key:match('^dock_') then return 'Docker'
  elseif key:match('^fx_') or key:match('^vst_') then return 'FX'
  elseif key:match('^menu_') then return 'Menu'
  elseif key:match('^global_') or key:match('^gen_') or key:match('^generic_') then return 'Global'
  else return 'Other'
  end
end

function M.new(State, settings)
  local self = setmetatable({
    State = State,
    settings = settings,

    -- Modal state
    open = false,
    overlay_pushed = false,

    -- UI state
    search_text = '',
    group_by = 'provider',  -- 'provider' or 'area'
    collapsed_groups = {},

    -- Cache
    _grouped_cache = nil,
    _stats_cache = nil,
  }, ResultModal)

  return self
end

function ResultModal:show()
  self.open = true
  self.overlay_pushed = false
  self.search_text = ''
  self.collapsed_groups = {}
  self:_compute_cache()
end

function ResultModal:hide()
  self.open = false
  self.overlay_pushed = false
  self._grouped_cache = nil
  self._stats_cache = nil
end

function ResultModal:_compute_cache()
  local resolved = ImageMap.get_all()
  local stats = ImageMap.get_stats()

  -- Build grouped data
  local by_provider = {}
  local by_area = {}
  local total_pinned = 0

  for key, entry in pairs(resolved) do
    local provider = entry.provider or '(unknown)'
    local area = get_area_from_key(key)
    local is_pinned = entry.pinned or false

    if is_pinned then total_pinned = total_pinned + 1 end

    -- Group by provider
    if not by_provider[provider] then
      by_provider[provider] = { keys = {}, count = 0, pinned = 0 }
    end
    by_provider[provider].keys[#by_provider[provider].keys + 1] = { key = key, entry = entry, area = area }
    by_provider[provider].count = by_provider[provider].count + 1
    if is_pinned then by_provider[provider].pinned = by_provider[provider].pinned + 1 end

    -- Group by area
    if not by_area[area] then
      by_area[area] = { keys = {}, count = 0, pinned = 0 }
    end
    by_area[area].keys[#by_area[area].keys + 1] = { key = key, entry = entry, provider = provider }
    by_area[area].count = by_area[area].count + 1
    if is_pinned then by_area[area].pinned = by_area[area].pinned + 1 end
  end

  -- Sort keys within each group
  for _, group in pairs(by_provider) do
    table.sort(group.keys, function(a, b) return a.key < b.key end)
  end
  for _, group in pairs(by_area) do
    table.sort(group.keys, function(a, b) return a.key < b.key end)
  end

  self._grouped_cache = {
    by_provider = by_provider,
    by_area = by_area,
  }

  self._stats_cache = {
    total = stats.total_keys,
    providers = stats.active_providers,
    pinned = total_pinned,
  }
end

function ResultModal:_filter_keys(keys)
  if self.search_text == '' then return keys end

  local search_lower = self.search_text:lower()
  local filtered = {}
  for _, item in ipairs(keys) do
    if item.key:lower():find(search_lower, 1, true) then
      filtered[#filtered + 1] = item
    end
  end
  return filtered
end

function ResultModal:draw_stats_bar(ctx)
  local stats = self._stats_cache
  if not stats then return end

  local providers = stats.providers or {}
  local provider_count = 0
  for _ in pairs(providers) do provider_count = provider_count + 1 end

  ImGui.TextColored(ctx, 0x888888FF, 'Total Keys:')
  ImGui.SameLine(ctx)
  ImGui.Text(ctx, tostring(stats.total))

  ImGui.SameLine(ctx, 0, 20)
  ImGui.TextColored(ctx, 0x888888FF, 'Providers:')
  ImGui.SameLine(ctx)
  ImGui.Text(ctx, tostring(provider_count))

  ImGui.SameLine(ctx, 0, 20)
  ImGui.TextColored(ctx, 0x888888FF, 'Pinned:')
  ImGui.SameLine(ctx)
  ImGui.TextColored(ctx, 0x4AE290FF, tostring(stats.pinned))
end

function ResultModal:draw_provider_bar(ctx, dl, x, y, width)
  local stats = self._stats_cache
  if not stats or stats.total == 0 then return end

  local bar_height = 20
  local providers = stats.providers or {}

  -- Sort providers by count (descending)
  local sorted = {}
  for name, count in pairs(providers) do
    sorted[#sorted + 1] = { name = name, count = count }
  end
  table.sort(sorted, function(a, b) return a.count > b.count end)

  -- Draw stacked bar
  local x_offset = x
  for i, p in ipairs(sorted) do
    local ratio = p.count / stats.total
    local seg_width = math.floor(width * ratio)
    if i == #sorted then
      seg_width = (x + width) - x_offset  -- Last segment fills remaining
    end

    -- Generate color from provider name hash
    local hash = 0
    for j = 1, #p.name do hash = hash + string.byte(p.name, j) end
    local hue = (hash * 37) % 360
    local color = Ark.Colors.FromHSV(hue, 0.6, 0.7)

    ImGui.DrawList_AddRectFilled(dl, x_offset, y, x_offset + seg_width, y + bar_height, color, 2)
    x_offset = x_offset + seg_width
  end

  -- Border
  ImGui.DrawList_AddRect(dl, x, y, x + width, y + bar_height, 0x444444FF, 2)
end

function ResultModal:draw_key_tile(ctx, dl, item, x, y)
  local key = item.key
  local entry = item.entry
  local provider = entry.provider or item.provider or '(unknown)'
  local is_pinned = entry.pinned or false

  -- Background
  local bg_color = 0x1E1E1EFF
  ImGui.DrawList_AddRectFilled(dl, x, y, x + TILE_WIDTH, y + TILE_HEIGHT, bg_color, 3)

  -- Border (green if pinned)
  local border_color = is_pinned and 0x4AE290FF or 0x333333FF
  ImGui.DrawList_AddRect(dl, x, y, x + TILE_WIDTH, y + TILE_HEIGHT, border_color, 3, 0, is_pinned and 2 or 1)

  -- Key name (truncated)
  local display_name = key
  if #display_name > 26 then
    display_name = display_name:sub(1, 24) .. '..'
  end
  ImGui.DrawList_AddText(dl, x + 6, y + 6, 0xDDDDDDFF, display_name)

  -- Provider badge (right side)
  local provider_short = provider
  if #provider_short > 12 then
    provider_short = provider_short:sub(1, 10) .. '..'
  end
  local text_w = ImGui.CalcTextSize(ctx, provider_short)
  ImGui.DrawList_AddText(dl, x + TILE_WIDTH - text_w - 8, y + 6, 0x888888FF, provider_short)

  -- Pin indicator
  if is_pinned then
    ImGui.DrawList_AddCircleFilled(dl, x + TILE_WIDTH - 8, y + TILE_HEIGHT / 2, 4, 0x4AE290FF)
  end
end

function ResultModal:draw_group(ctx, group_name, group_data, color)
  local is_collapsed = self.collapsed_groups[group_name]

  -- Group header
  ImGui.PushStyleColor(ctx, ImGui.Col_Header, Ark.Colors.WithOpacity(color or 0x444444FF, 0.3))
  ImGui.PushStyleColor(ctx, ImGui.Col_HeaderHovered, Ark.Colors.WithOpacity(color or 0x444444FF, 0.5))

  local header_label = string.format('%s  (%d keys, %d pinned)', group_name, group_data.count, group_data.pinned)
  local header_open = ImGui.CollapsingHeader(ctx, header_label, not is_collapsed and ImGui.TreeNodeFlags_DefaultOpen or 0)

  ImGui.PopStyleColor(ctx, 2)

  self.collapsed_groups[group_name] = not header_open

  if header_open then
    local filtered = self:_filter_keys(group_data.keys)
    if #filtered == 0 then
      ImGui.TextColored(ctx, 0x666666FF, '  (no matches)')
    else
      local dl = ImGui.GetWindowDrawList(ctx)
      local avail_w = ImGui.GetContentRegionAvail(ctx)
      local cols = math.max(1, math.floor(avail_w / (TILE_WIDTH + TILE_SPACING)))

      for i, item in ipairs(filtered) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)

        if col == 0 then
          local cx, cy = ImGui.GetCursorScreenPos(ctx)
          -- Dummy for row height
          ImGui.Dummy(ctx, avail_w, TILE_HEIGHT + TILE_SPACING)
          ImGui.SetCursorScreenPos(ctx, cx, cy)
        end

        local x = ImGui.GetCursorScreenPos(ctx) + col * (TILE_WIDTH + TILE_SPACING)
        local y = select(2, ImGui.GetCursorScreenPos(ctx))

        self:draw_key_tile(ctx, dl, item, x, y)
      end

      -- Extra spacing after group
      ImGui.Dummy(ctx, 0, 8)
    end
  end
end

function ResultModal:draw_content(ctx)
  if not self._grouped_cache then
    self:_compute_cache()
  end

  -- Stats bar
  self:draw_stats_bar(ctx)

  -- Provider distribution bar
  ImGui.Dummy(ctx, 0, 4)
  local bar_x, bar_y = ImGui.GetCursorScreenPos(ctx)
  local bar_w = ImGui.GetContentRegionAvail(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  self:draw_provider_bar(ctx, dl, bar_x, bar_y, bar_w)
  ImGui.Dummy(ctx, 0, 28)

  ImGui.Separator(ctx)

  -- Search and group-by toggle
  ImGui.SetNextItemWidth(ctx, 200)
  local changed, new_text = ImGui.InputTextWithHint(ctx, '##result_search', 'Filter keys...', self.search_text)
  if changed then self.search_text = new_text end

  ImGui.SameLine(ctx, 0, 20)
  if ImGui.RadioButton(ctx, 'By Provider', self.group_by == 'provider') then
    self.group_by = 'provider'
  end
  ImGui.SameLine(ctx)
  if ImGui.RadioButton(ctx, 'By Area', self.group_by == 'area') then
    self.group_by = 'area'
  end

  ImGui.Separator(ctx)

  -- Scrollable content
  if ImGui.BeginChild(ctx, 'result_list', 0, 0, ImGui.ChildFlags_None, ImGui.WindowFlags_AlwaysVerticalScrollbar) then
    local grouped = self._grouped_cache
    if self.group_by == 'provider' then
      -- Sort providers by count
      local sorted = {}
      for name, data in pairs(grouped.by_provider) do
        sorted[#sorted + 1] = { name = name, data = data }
      end
      table.sort(sorted, function(a, b) return a.data.count > b.data.count end)

      for _, item in ipairs(sorted) do
        -- Generate color from name
        local hash = 0
        for j = 1, #item.name do hash = hash + string.byte(item.name, j) end
        local hue = (hash * 37) % 360
        local color = Ark.Colors.FromHSV(hue, 0.6, 0.7)
        self:draw_group(ctx, item.name, item.data, color)
      end
    else
      -- By area - use AREA_COLORS
      local area_order = { 'TCP', 'MCP', 'Transport', 'Toolbar', 'ENVCP', 'Meter', 'Global', 'Items', 'MIDI', 'Docker', 'FX', 'Menu', 'Other' }
      for _, area in ipairs(area_order) do
        local data = grouped.by_area[area]
        if data then
          self:draw_group(ctx, area, data, AREA_COLORS[area])
        end
      end
    end

    ImGui.EndChild(ctx)
  end
end

function ResultModal:draw(ctx, window)
  if not self.open then return end

  -- Use overlay system if available
  if window and window.overlay and not self.overlay_pushed then
    self.overlay_pushed = true

    window.overlay:push({
      id = 'result-modal',
      close_on_scrim = true,
      esc_to_close = true,
      on_close = function()
        self:hide()
      end,
      render = function(render_ctx, alpha, bounds)
        -- Modal dimensions
        local max_w = 1200
        local max_h = 800
        local min_w = 600
        local min_h = 400

        local modal_w = math.floor(math.max(min_w, math.min(max_w, bounds.w * 0.9)))
        local modal_h = math.floor(math.max(min_h, math.min(max_h, bounds.h * 0.85)))

        -- Center in viewport
        local modal_x = bounds.x + math.floor((bounds.w - modal_w) * 0.5)
        local modal_y = bounds.y + math.floor((bounds.h - modal_h) * 0.5)

        ImGui.SetCursorScreenPos(render_ctx, modal_x, modal_y)

        -- Draw modal background
        local dl = ImGui.GetWindowDrawList(render_ctx)
        ImGui.DrawList_AddRectFilled(dl, modal_x, modal_y, modal_x + modal_w, modal_y + modal_h, 0x1A1A1AFF, 6)
        ImGui.DrawList_AddRect(dl, modal_x, modal_y, modal_x + modal_w, modal_y + modal_h, 0x333333FF, 6)

        -- Title bar
        ImGui.DrawList_AddRectFilled(dl, modal_x, modal_y, modal_x + modal_w, modal_y + 32, 0x252525FF, 6)
        ImGui.DrawList_AddText(dl, modal_x + 12, modal_y + 8, 0xFFFFFFFF, 'Reassembled Result')

        -- Content area
        ImGui.SetCursorScreenPos(render_ctx, modal_x + 12, modal_y + 40)
        ImGui.BeginGroup(render_ctx)
        ImGui.PushClipRect(render_ctx, modal_x, modal_y + 32, modal_x + modal_w, modal_y + modal_h, true)

        -- Draw content with available space
        local content_w = modal_w - 24
        local content_h = modal_h - 52
        if ImGui.BeginChild(render_ctx, 'result_modal_content', content_w, content_h) then
          self:draw_content(render_ctx)
        end
        ImGui.EndChild(render_ctx)

        ImGui.PopClipRect(render_ctx)
        ImGui.EndGroup(render_ctx)
      end
    })
  end
end

return M

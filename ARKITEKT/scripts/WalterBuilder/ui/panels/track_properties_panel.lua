-- @noindex
-- WalterBuilder/ui/panels/track_properties_panel.lua
-- Properties panel for editing selected track settings
-- Uses Arkitekt widgets for consistent styling

local ImGui = require('arkitekt.platform.imgui')
local Ark = require('arkitekt')
local Button = require('arkitekt.gui.widgets.primitives.button')
local Slider = require('arkitekt.gui.widgets.primitives.slider')
local TrackDefaults = require('WalterBuilder.defs.track_defaults')
local Constants = require('WalterBuilder.defs.constants')

local hexrgb = Ark.Colors.hexrgb

local M = {}
local Panel = {}
Panel.__index = Panel

function M.new(opts)
  opts = opts or {}

  local self = setmetatable({
    -- Currently edited track
    track = nil,

    -- Callbacks
    on_change = opts.on_change,
    on_delete = opts.on_delete,
    on_add = opts.on_add,
  }, Panel)

  return self
end

-- Set the track to edit
function Panel:set_track(track)
  self.track = track
end

-- Draw height presets using Button widget
function Panel:draw_height_presets(ctx)
  local track = self.track
  local changed = false

  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#888888"))
  ImGui.Text(ctx, "Presets:")
  ImGui.PopStyleColor(ctx)

  ImGui.SameLine(ctx, 60)

  for i, preset in ipairs(Constants.HEIGHT_PRESETS) do
    local is_current = track.height == preset.height
    local x, y = ImGui.GetCursorScreenPos(ctx)

    local result = Button.draw(ctx, {
      id = "height_preset_" .. preset.name,
      x = x,
      y = y,
      label = preset.name:sub(1, 3),
      width = 38,
      height = 22,
      is_toggled = is_current,
      tooltip = preset.name .. " (" .. preset.height .. "px)",
      advance = "none",
    })

    if result.clicked then
      track.height = preset.height
      changed = true
    end

    ImGui.SetCursorScreenPos(ctx, x + 42, y)

    if i >= #Constants.HEIGHT_PRESETS then
      ImGui.SetCursorScreenPos(ctx, x, y + 26)
    end
  end

  return changed
end

-- Draw state toggles using Button widget
function Panel:draw_state_toggles(ctx)
  local track = self.track
  local changed = false
  local x, y = ImGui.GetCursorScreenPos(ctx)

  -- Armed (R)
  local armed_result = Button.draw(ctx, {
    id = "track_armed",
    x = x,
    y = y,
    label = "R",
    width = 30,
    height = 24,
    is_toggled = track.armed,
    bg_on_color = hexrgb("#CC4444"),
    tooltip = "Record Armed",
    advance = "none",
  })
  if armed_result.clicked then
    track.armed = not track.armed
    changed = true
  end

  -- Muted (M)
  local muted_result = Button.draw(ctx, {
    id = "track_muted",
    x = x + 34,
    y = y,
    label = "M",
    width = 30,
    height = 24,
    is_toggled = track.muted,
    bg_on_color = hexrgb("#888844"),
    tooltip = "Muted",
    advance = "none",
  })
  if muted_result.clicked then
    track.muted = not track.muted
    changed = true
  end

  -- Soloed (S)
  local soloed_result = Button.draw(ctx, {
    id = "track_soloed",
    x = x + 68,
    y = y,
    label = "S",
    width = 30,
    height = 24,
    is_toggled = track.soloed,
    bg_on_color = hexrgb("#44AA44"),
    tooltip = "Soloed",
    advance = "none",
  })
  if soloed_result.clicked then
    track.soloed = not track.soloed
    changed = true
  end

  ImGui.SetCursorScreenPos(ctx, x, y + 28)

  return changed
end

-- Draw folder settings
function Panel:draw_folder_settings(ctx)
  local track = self.track
  local changed = false

  ImGui.Dummy(ctx, 0, 8)

  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#FFFFFF"))
  ImGui.Text(ctx, "Folder")
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 4)

  -- Folder state buttons
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
  ImGui.Text(ctx, "State:")
  ImGui.PopStyleColor(ctx)

  ImGui.SameLine(ctx, 60)

  local x, y = ImGui.GetCursorScreenPos(ctx)
  local folder_states = {
    { name = "None", value = 0 },
    { name = "Open", value = 1 },
    { name = "Cls", value = -1 },
    { name = "Last", value = -2 },
  }

  for i, state in ipairs(folder_states) do
    local is_current = track.folder_state == state.value

    local result = Button.draw(ctx, {
      id = "folder_state_" .. state.name,
      x = x + (i - 1) * 44,
      y = y,
      label = state.name,
      width = 40,
      height = 20,
      is_toggled = is_current,
      tooltip = Constants.FOLDER_STATE_LABELS[state.value],
      advance = "none",
    })

    if result.clicked then
      track.folder_state = state.value
      changed = true
    end
  end

  ImGui.SetCursorScreenPos(ctx, x - 60, y + 26)

  -- Folder depth using Slider
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
  ImGui.Text(ctx, "Depth:")
  ImGui.PopStyleColor(ctx)

  ImGui.SameLine(ctx, 60)

  x, y = ImGui.GetCursorScreenPos(ctx)

  local depth_result = Slider.int(ctx, {
    id = "folder_depth",
    x = x,
    y = y,
    value = track.folder_depth,
    min = 0,
    max = 5,
    width = 120,
    height = 18,
    tooltip_fn = function(v) return "Depth: " .. math.floor(v) end,
    advance = "none",
  })

  if depth_result.changed then
    track.folder_depth = math.floor(depth_result.value)
    changed = true
  end

  ImGui.SetCursorScreenPos(ctx, x - 60, y + 24)

  return changed
end

-- Main draw function
function Panel:draw(ctx)
  local result = nil
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local avail_w = ImGui.GetContentRegionAvail(ctx)

  -- Add track button at top
  local add_result = Button.draw(ctx, {
    id = "add_track",
    x = x,
    y = y,
    label = "+ Add Track",
    width = avail_w - 4,
    height = 24,
    advance = "vertical",
  })

  if add_result.clicked then
    result = { type = "add_track" }
  end

  ImGui.Dummy(ctx, 0, 8)
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 8)

  if not self.track then
    -- No track selected
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#666666"))
    ImGui.Text(ctx, "No track selected")
    ImGui.Dummy(ctx, 0, 8)
    ImGui.Text(ctx, "Click a track in the canvas")
    ImGui.Text(ctx, "to edit its properties")
    ImGui.PopStyleColor(ctx)
    return result
  end

  local track = self.track
  local changed = false

  -- Track name header
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#00AAFF"))
  ImGui.Text(ctx, "Track: " .. track.name)
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 8)

  -- Name input
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
  ImGui.Text(ctx, "Name:")
  ImGui.PopStyleColor(ctx)

  ImGui.SameLine(ctx, 60)
  ImGui.SetNextItemWidth(ctx, -1)

  local name_changed, new_name = ImGui.InputText(ctx, "##track_name", track.name)
  if name_changed then
    track.name = new_name
    changed = true
  end

  ImGui.Dummy(ctx, 0, 8)

  -- Height section
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#FFFFFF"))
  ImGui.Text(ctx, "Height")
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 4)

  -- Height slider
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
  ImGui.Text(ctx, "Value:")
  ImGui.PopStyleColor(ctx)

  ImGui.SameLine(ctx, 60)

  x, y = ImGui.GetCursorScreenPos(ctx)

  local height_result = Slider.int(ctx, {
    id = "track_height",
    x = x,
    y = y,
    value = track.height,
    min = Constants.TRACK.MIN_HEIGHT,
    max = Constants.TRACK.MAX_HEIGHT,
    default = Constants.TRACK.DEFAULT_HEIGHT,
    width = 140,
    height = 18,
    tooltip_fn = function(v) return math.floor(v) .. " px" end,
    advance = "vertical",
  })

  if height_result.changed then
    track.height = math.floor(height_result.value)
    changed = true
  end

  ImGui.Dummy(ctx, 0, 4)

  if self:draw_height_presets(ctx) then
    changed = true
  end

  ImGui.Dummy(ctx, 0, 8)
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 8)

  -- State toggles section
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#FFFFFF"))
  ImGui.Text(ctx, "Track State")
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 4)

  if self:draw_state_toggles(ctx) then
    changed = true
  end

  -- Folder settings
  if self:draw_folder_settings(ctx) then
    changed = true
  end

  ImGui.Dummy(ctx, 0, 8)
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 8)

  -- Delete button
  x, y = ImGui.GetCursorScreenPos(ctx)

  local delete_result = Button.draw(ctx, {
    id = "remove_track",
    x = x,
    y = y,
    label = "Remove Track",
    width = avail_w - 4,
    height = 26,
    bg_color = hexrgb("#4A2A2A"),
    bg_hover_color = hexrgb("#5A3A3A"),
    bg_active_color = hexrgb("#6A4A4A"),
    advance = "vertical",
  })

  if delete_result.clicked then
    result = { type = "delete_track", track = track }
  end

  -- Notify of changes
  if changed and self.on_change then
    self.on_change(track)
    result = { type = "change_track", track = track }
  end

  return result
end

return M

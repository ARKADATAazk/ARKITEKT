-- @noindex
-- WalterBuilder/ui/panels/track_properties_panel.lua
-- Properties panel for editing selected track settings

local ImGui = require 'imgui' '0.10'
local ark = require('arkitekt')
local TrackDefaults = require('WalterBuilder.defs.track_defaults')

local hexrgb = ark.Colors.hexrgb

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

-- Draw height presets
function Panel:draw_height_presets(ctx)
  local track = self.track
  local changed = false

  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#888888"))
  ImGui.Text(ctx, "Height presets:")
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 2)

  local presets = {
    { name = "Super", height = TrackDefaults.HEIGHTS.SUPERCOLLAPSED },
    { name = "Collapsed", height = TrackDefaults.HEIGHTS.COLLAPSED },
    { name = "Small", height = TrackDefaults.HEIGHTS.SMALL },
    { name = "Normal", height = TrackDefaults.HEIGHTS.NORMAL },
    { name = "Large", height = TrackDefaults.HEIGHTS.LARGE },
  }

  for i, preset in ipairs(presets) do
    local is_current = track.height == preset.height

    if is_current then
      ImGui.PushStyleColor(ctx, ImGui.Col_Button, hexrgb("#404060"))
    end

    if ImGui.Button(ctx, preset.name .. "##height", 60, 22) then
      track.height = preset.height
      changed = true
    end

    if is_current then
      ImGui.PopStyleColor(ctx)
    end

    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, preset.height .. "px")
    end

    if i < #presets then
      ImGui.SameLine(ctx, 0, 4)
    end
  end

  return changed
end

-- Draw state toggles
function Panel:draw_state_toggles(ctx)
  local track = self.track
  local changed = false

  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#FFFFFF"))
  ImGui.Text(ctx, "Track State")
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 4)

  -- Armed
  local armed_color = track.armed and hexrgb("#CC4444") or hexrgb("#2A2A2A")
  ImGui.PushStyleColor(ctx, ImGui.Col_Button, armed_color)
  if ImGui.Button(ctx, "R##armed", 30, 24) then
    track.armed = not track.armed
    changed = true
  end
  ImGui.PopStyleColor(ctx)
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "Record Armed")
  end

  ImGui.SameLine(ctx, 0, 4)

  -- Muted
  local muted_color = track.muted and hexrgb("#888844") or hexrgb("#2A2A2A")
  ImGui.PushStyleColor(ctx, ImGui.Col_Button, muted_color)
  if ImGui.Button(ctx, "M##muted", 30, 24) then
    track.muted = not track.muted
    changed = true
  end
  ImGui.PopStyleColor(ctx)
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "Muted")
  end

  ImGui.SameLine(ctx, 0, 4)

  -- Soloed
  local soloed_color = track.soloed and hexrgb("#44AA44") or hexrgb("#2A2A2A")
  ImGui.PushStyleColor(ctx, ImGui.Col_Button, soloed_color)
  if ImGui.Button(ctx, "S##soloed", 30, 24) then
    track.soloed = not track.soloed
    changed = true
  end
  ImGui.PopStyleColor(ctx)
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "Soloed")
  end

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

  -- Folder state
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
  ImGui.Text(ctx, "State:")
  ImGui.PopStyleColor(ctx)

  ImGui.SameLine(ctx, 60)

  local folder_states = {
    { name = "None", value = 0 },
    { name = "Open", value = 1 },
    { name = "Closed", value = -1 },
    { name = "Last", value = -2 },
  }

  for i, state in ipairs(folder_states) do
    local is_current = track.folder_state == state.value

    if is_current then
      ImGui.PushStyleColor(ctx, ImGui.Col_Button, hexrgb("#404060"))
    end

    if ImGui.Button(ctx, state.name .. "##folder", 45, 20) then
      track.folder_state = state.value
      changed = true
    end

    if is_current then
      ImGui.PopStyleColor(ctx)
    end

    if i < #folder_states then
      ImGui.SameLine(ctx, 0, 2)
    end
  end

  -- Folder depth
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
  ImGui.Text(ctx, "Depth:")
  ImGui.PopStyleColor(ctx)

  ImGui.SameLine(ctx, 60)
  ImGui.SetNextItemWidth(ctx, 80)

  local depth_changed, new_depth = ImGui.SliderInt(ctx, "##folder_depth", track.folder_depth, 0, 5)
  if depth_changed then
    track.folder_depth = new_depth
    changed = true
  end

  return changed
end

-- Main draw function
function Panel:draw(ctx)
  local result = nil

  -- Add track button at top
  if ImGui.Button(ctx, "+ Add Track##add", -1, 24) then
    if self.on_add then
      result = { type = "add_track" }
    end
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

  -- Track name
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

  -- Height
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#FFFFFF"))
  ImGui.Text(ctx, "Height")
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 4)

  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
  ImGui.Text(ctx, "Value:")
  ImGui.PopStyleColor(ctx)

  ImGui.SameLine(ctx, 60)
  ImGui.SetNextItemWidth(ctx, 80)

  local h_changed, new_h = ImGui.DragInt(ctx, "##track_height", track.height, 1, 25, 200, "%d px")
  if h_changed then
    track.height = new_h
    changed = true
  end

  ImGui.Dummy(ctx, 0, 4)

  if self:draw_height_presets(ctx) then
    changed = true
  end

  ImGui.Dummy(ctx, 0, 8)
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 8)

  -- State toggles
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
  ImGui.PushStyleColor(ctx, ImGui.Col_Button, hexrgb("#4A2A2A"))
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, hexrgb("#5A3A3A"))
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, hexrgb("#6A4A4A"))

  if ImGui.Button(ctx, "Remove Track", -1, 26) then
    if self.on_delete then
      result = { type = "delete_track", track = track }
    end
  end

  ImGui.PopStyleColor(ctx, 3)

  -- Notify of changes
  if changed and self.on_change then
    self.on_change(track)
    result = { type = "change_track", track = track }
  end

  return result
end

return M

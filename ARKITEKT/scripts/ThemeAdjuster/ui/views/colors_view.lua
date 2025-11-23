-- @noindex
-- ThemeAdjuster/ui/views/colors_view.lua
-- Color palette and track coloring tab

local ImGui = require 'imgui' '0.10'
local Button = require('arkitekt.gui.widgets.primitives.button')
local Spinner = require('arkitekt.gui.widgets.primitives.spinner')
local Background = require('arkitekt.gui.widgets.containers.panel.background')
local Style = require('arkitekt.gui.style.defaults')
local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb

local PC = Style.PANEL_COLORS  -- Panel colors including pattern defaults

local M = {}
local ColorsView = {}
ColorsView.__index = ColorsView

-- Color palettes (from Default 6.0)
local PALETTES = {
  {
    name = 'REAPER V6',
    colors = {
      {84, 84, 84}, {105, 137, 137}, {129, 137, 137}, {168, 168, 168},
      {19, 189, 153}, {51, 152, 135}, {184, 143, 63}, {187, 156, 148},
      {134, 94, 82}, {130, 59, 42}
    }
  },
  {
    name = 'Pride',
    colors = {
      {84, 84, 84}, {138, 138, 138}, {155, 55, 55}, {155, 129, 55},
      {105, 155, 55}, {55, 155, 81}, {55, 155, 155}, {55, 81, 155},
      {105, 55, 155}, {155, 55, 129}
    }
  },
  {
    name = 'Warm',
    colors = {
      {128, 67, 64}, {184, 82, 46}, {239, 169, 81}, {230, 204, 143},
      {231, 185, 159}, {208, 193, 180}, {176, 177, 161}, {108, 120, 116},
      {128, 114, 98}, {97, 87, 74}
    }
  },
  {
    name = 'Cool',
    colors = {
      {35, 75, 84}, {58, 79, 128}, {95, 88, 128}, {92, 102, 112},
      {67, 104, 128}, {91, 125, 134}, {95, 92, 85}, {131, 135, 97},
      {55, 118, 94}, {75, 99, 32}
    }
  },
  {
    name = 'Vice',
    colors = {
      {255, 0, 111}, {255, 89, 147}, {254, 152, 117}, {255, 202, 193},
      {249, 255, 168}, {122, 242, 178}, {87, 255, 255}, {51, 146, 255},
      {168, 117, 255}, {99, 77, 196}
    }
  },
  {
    name = 'Eeek',
    colors = {
      {255, 0, 0}, {255, 111, 0}, {255, 221, 0}, {179, 255, 0},
      {0, 255, 123}, {0, 213, 255}, {0, 102, 255}, {93, 0, 255},
      {204, 0, 255}, {255, 0, 153}
    }
  },
}

-- Spinner values for palette selection
local PALETTE_NAMES = {}
for i, palette in ipairs(PALETTES) do
  PALETTE_NAMES[i] = palette.name
end

function M.new(State, Config, settings)
  local self = setmetatable({
    State = State,
    Config = Config,
    settings = settings,

    -- Current palette index (1-based)
    current_palette_idx = 1,
  }, ColorsView)

  return self
end

-- Apply color to selected tracks
local function apply_color_to_selected(color)
  if type(color) ~= "table" or #color < 3 then
    return
  end

  reaper.Undo_BeginBlock()
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    if reaper.IsTrackSelected(track) then
      local native_color = reaper.ColorToNative(color[1], color[2], color[3])
      reaper.SetTrackColor(track, native_color)
    end
  end
  reaper.Undo_EndBlock('Apply color to selected tracks', -1)
end

-- Recolor all tracks using current palette
local function recolor_all_tracks(palette_idx)
  local palette = PALETTES[palette_idx]
  if not palette then return end

  reaper.Undo_BeginBlock()

  -- Build a randomized palette
  local randpal = {}
  local color_map = {}
  local cnt = 1

  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local color_int = reaper.GetTrackColor(track)

    if color_int ~= 0 then  -- Track has a custom color
      local r, g, b = reaper.ColorFromNative(color_int)
      local color_key = (r << 16) | (g << 8) | b

      if color_map[color_key] == nil then
        -- Assign a color from the palette
        local palette_color = palette.colors[((cnt - 1) % #palette.colors) + 1]
        randpal[cnt] = palette_color
        color_map[color_key] = cnt
        cnt = cnt + 1
      end

      local mapped_idx = color_map[color_key]
      local new_color = randpal[mapped_idx]
      local native_color = reaper.ColorToNative(new_color[1], new_color[2], new_color[3])
      reaper.SetTrackColor(track, native_color)
    end
  end

  reaper.Undo_EndBlock('Recolor project using palette', -1)
end

-- Dim/brighten track colors
local function adjust_track_brightness(selected_only, darken)
  reaper.Undo_BeginBlock()

  local track_count = reaper.CountTracks(0)
  for i = 0, track_count - 1 do
    local track = reaper.GetTrack(0, i)

    if not selected_only or reaper.IsTrackSelected(track) then
      local color_int = reaper.GetTrackColor(track)

      if color_int ~= 0 then  -- Track has a custom color
        local r, g, b = reaper.ColorFromNative(color_int)

        -- Adjust brightness
        local factor = darken and 0.8 or 1.25
        r = math.floor(math.min(255, math.max(0, r * factor)))
        g = math.floor(math.min(255, math.max(0, g * factor)))
        b = math.floor(math.min(255, math.max(0, b * factor)))

        local new_color = reaper.ColorToNative(r, g, b)
        reaper.SetTrackColor(track, new_color)
      end
    end
  end

  reaper.Undo_EndBlock(selected_only and 'Dim selected track colors' or 'Dim all track colors', -1)
end

function ColorsView:draw(ctx, shell_state)
  local avail_w = ImGui.GetContentRegionAvail(ctx)

  -- Title
  ImGui.PushFont(ctx, shell_state.fonts.bold, 16)
  ImGui.Text(ctx, "Track Colors")
  ImGui.PopFont(ctx)

  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#999999"))
  ImGui.Text(ctx, "Apply color palettes to project tracks")
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 8)

  -- Single scrollable content area
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#1A1A1A"))
  if ImGui.BeginChild(ctx, "colors_content", avail_w, 0, 1) then
    -- Draw background pattern
    local child_x, child_y = ImGui.GetWindowPos(ctx)
    local child_w, child_h = ImGui.GetWindowSize(ctx)
    local dl = ImGui.GetWindowDrawList(ctx)

    local pattern_cfg = {
      enabled = true,
      primary = {
        type = 'grid',
        spacing = 50,
        color = PC.pattern_primary,
        line_thickness = 1.5,
      },
      secondary = {
        enabled = true,
        type = 'grid',
        spacing = 5,
        color = PC.pattern_secondary,
        line_thickness = 0.5,
      },
    }

    Background.draw(ctx, dl, child_x, child_y, child_x + child_w, child_y + child_h, pattern_cfg)

    ImGui.Dummy(ctx, 0, 8)
    ImGui.Indent(ctx, 12)

    -- Palette Selection
    ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
    ImGui.Text(ctx, "COLOR PALETTE")
    ImGui.PopFont(ctx)
    ImGui.Dummy(ctx, 0, 6)

    -- Palette name display
    local current_palette = PALETTES[self.current_palette_idx]
    ImGui.PushFont(ctx, shell_state.fonts.bold, 20)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
    local palette_text_w = ImGui.CalcTextSize(ctx, current_palette.name)
    ImGui.SetCursorPosX(ctx, (avail_w - palette_text_w) / 2)
    ImGui.Text(ctx, current_palette.name)
    ImGui.PopStyleColor(ctx)
    ImGui.PopFont(ctx)

    ImGui.Dummy(ctx, 0, 12)

    -- Color swatches (10 colors)
    local swatch_size = 50
    local spacing = 8
    local total_width = (swatch_size * 10) + (spacing * 9)
    local start_x = (avail_w - total_width) / 2

    ImGui.SetCursorPosX(ctx, start_x)

    for i, color in ipairs(current_palette.colors) do
      local color_hex = string.format("#%02X%02X%02X", color[1], color[2], color[3])
      local color_packed = hexrgb(color_hex)

      -- Draw color button
      ImGui.PushStyleColor(ctx, ImGui.Col_Button, color_packed)
      ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, color_packed)
      ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, color_packed)
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameRounding, 4)

      if ImGui.Button(ctx, "##color_" .. i, swatch_size, swatch_size) then
        apply_color_to_selected(color)
      end

      ImGui.PopStyleVar(ctx)
      ImGui.PopStyleColor(ctx, 3)

      if ImGui.IsItemHovered(ctx) then
        ImGui.SetTooltip(ctx, string.format("R:%d G:%d B:%d\nClick to apply to selected tracks", color[1], color[2], color[3]))
      end

      if i < #current_palette.colors then
        ImGui.SameLine(ctx, 0, spacing)
      end
    end

    ImGui.Dummy(ctx, 0, 16)

    -- Instruction text
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#888888"))
    local instr_text = "Click a color to apply it to all selected tracks"
    local instr_w = ImGui.CalcTextSize(ctx, instr_text)
    ImGui.SetCursorPosX(ctx, (avail_w - instr_w) / 2)
    ImGui.Text(ctx, instr_text)
    ImGui.PopStyleColor(ctx)

    ImGui.Dummy(ctx, 0, 24)

    -- Palette Controls Section
    ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
    ImGui.Text(ctx, "PALETTE CONTROLS")
    ImGui.PopFont(ctx)
    ImGui.Dummy(ctx, 0, 8)

    -- Palette spinner
    ImGui.AlignTextToFramePadding(ctx)
    ImGui.Text(ctx, "Select Palette")
    ImGui.SameLine(ctx, 140)

    local changed, new_idx = Spinner.draw(ctx, "palette_selector", self.current_palette_idx, PALETTE_NAMES, {w = 200, h = 28})
    if changed then
      self.current_palette_idx = new_idx
    end

    ImGui.Dummy(ctx, 0, 12)

    -- Recolor all tracks button
    if Button.draw_at_cursor(ctx, {
      label = "Recolor All Tracks Using This Palette",
      width = 320,
      height = 32,
      on_click = function()
        recolor_all_tracks(self.current_palette_idx)
      end
    }, "recolor_all") then
    end

    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, "Applies this palette to all colored tracks in the project")
    end

    ImGui.Dummy(ctx, 0, 24)

    -- Color Adjustment Section
    ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
    ImGui.Text(ctx, "COLOR ADJUSTMENTS")
    ImGui.PopFont(ctx)
    ImGui.Dummy(ctx, 0, 8)

    -- Dim/Brighten buttons in a 2x2 grid
    local btn_width = 200
    local btn_height = 32

    ImGui.BeginGroup(ctx)

    -- Row 1: Darken buttons
    if Button.draw_at_cursor(ctx, {
      label = "Darken Selected",
      width = btn_width,
      height = btn_height,
      on_click = function()
        adjust_track_brightness(true, true)
      end
    }, "darken_selected") then
    end

    ImGui.SameLine(ctx, 0, 12)

    if Button.draw_at_cursor(ctx, {
      label = "Darken All",
      width = btn_width,
      height = btn_height,
      on_click = function()
        adjust_track_brightness(false, true)
      end
    }, "darken_all") then
    end

    ImGui.Dummy(ctx, 0, 8)

    -- Row 2: Brighten buttons
    if Button.draw_at_cursor(ctx, {
      label = "Brighten Selected",
      width = btn_width,
      height = btn_height,
      on_click = function()
        adjust_track_brightness(true, false)
      end
    }, "brighten_selected") then
    end

    ImGui.SameLine(ctx, 0, 12)

    if Button.draw_at_cursor(ctx, {
      label = "Brighten All",
      width = btn_width,
      height = btn_height,
      on_click = function()
        adjust_track_brightness(false, false)
      end
    }, "brighten_all") then
    end

    ImGui.EndGroup(ctx)

    ImGui.Dummy(ctx, 0, 16)

    -- Help text
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#666666"))
    ImGui.TextWrapped(ctx, "Track colors are stored in the project file and are independent of the theme. " ..
                            "Use these tools to quickly apply coordinated color schemes to your tracks.")
    ImGui.PopStyleColor(ctx)

    ImGui.Unindent(ctx, 12)
    ImGui.Dummy(ctx, 0, 8)
    ImGui.EndChild(ctx)
  end
  ImGui.PopStyleColor(ctx)
end

return M

-- @noindex
-- ThemeAdjuster/ui/views/param_link_modal.lua
-- Parameter link selection modal

local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local ParameterLinkManager = require('ThemeAdjuster.core.parameter_link_manager')
local ChipList = require('rearkitekt.gui.widgets.data.chip_list')
local hexrgb = Colors.hexrgb

local M = {}
local ParamLinkModal = {}
ParamLinkModal.__index = ParamLinkModal

function M.new(view)
  local self = setmetatable({
    view = view,

    -- Modal state
    open = false,
    source_param = nil,  -- The parameter we're adding to a group
    source_param_type = nil,

    -- UI state
    search_text = "",
  }, ParamLinkModal)

  return self
end

-- Open the modal for a specific source parameter
function ParamLinkModal:show(param_name, param_type)
  self.open = true
  self.source_param = param_name
  self.source_param_type = param_type
  self.search_text = ""
end

function ParamLinkModal:close()
  self.open = false
  self.source_param = nil
  self.source_param_type = nil
  self.search_text = ""
end

-- Get compatible parameters (filtered by type)
function ParamLinkModal:get_compatible_params()
  local compatible = {}

  -- Get all parameters from library (not just assigned)
  for _, param in ipairs(self.view.all_params) do
    local param_name = param.name

    -- Skip self
    if param_name ~= self.source_param then
      -- Check type compatibility
      if ParameterLinkManager.are_types_compatible(self.source_param_type, param.type) then
        table.insert(compatible, {
          id = param_name,
          name = param_name,
          type = param.type,
          description = param.description or "",
        })
      end
    end
  end

  return compatible
end

-- Add parameter to link group and close modal
function ParamLinkModal:add_to_group(target_param)
  local success, error_msg = ParameterLinkManager.add_to_group(self.source_param, self.source_param_type, target_param)

  if success then
    -- Save assignments to persist link data
    self.view:save_assignments()
    self:close()
  else
    -- Show error (could use a toast notification system if available)
    print("Failed to add to group: " .. (error_msg or "Unknown error"))
  end

  return success
end

-- Remove from link group
function ParamLinkModal:remove_from_group()
  if ParameterLinkManager.is_in_group(self.source_param) then
    ParameterLinkManager.remove_from_group(self.source_param)
    self.view:save_assignments()
    self:close()
  end
end

-- Render the modal
function ParamLinkModal:render(ctx, shell_state)
  if not self.open then return end

  if not ImGui.IsPopupOpen(ctx, "##param_link_popup") then
    ImGui.OpenPopup(ctx, "##param_link_popup")
  end

  ImGui.SetNextWindowSize(ctx, 700, 600, ImGui.Cond_FirstUseEver)

  local visible = ImGui.BeginPopupModal(ctx, "##param_link_popup", true, ImGui.WindowFlags_NoTitleBar)

  if not visible then
    self.open = false
    self:close()
    return
  end

  -- Header
  if shell_state and shell_state.fonts and shell_state.fonts.bold then
    ImGui.PushFont(ctx, shell_state.fonts.bold, 16)
    ImGui.Text(ctx, "Link Parameter")
    ImGui.PopFont(ctx)
  else
    ImGui.Text(ctx, "Link Parameter")
  end

  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 8)

  -- Source parameter info
  ImGui.TextColored(ctx, hexrgb("#AAAAAA"), "Source:")
  ImGui.SameLine(ctx)
  ImGui.Text(ctx, self.source_param)
  ImGui.SameLine(ctx, 0, 20)
  ImGui.TextColored(ctx, hexrgb("#AAAAAA"), "Type:")
  ImGui.SameLine(ctx)
  ImGui.Text(ctx, self.source_param_type or "unknown")

  -- Show current link status
  local is_linked = ParameterLinkManager.is_linked(self.source_param)
  if is_linked then
    local parent = ParameterLinkManager.get_parent(self.source_param)
    local mode = ParameterLinkManager.get_link_mode(self.source_param)
    local mode_text = mode == ParameterLinkManager.LINK_MODE.LINK and "LINK" or "SYNC"

    ImGui.Spacing(ctx)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#4AE290"))
    ImGui.Text(ctx, string.format("Currently linked to: %s [%s]", parent, mode_text))
    ImGui.PopStyleColor(ctx)

    ImGui.Spacing(ctx)

    -- Remove link button
    if ImGui.Button(ctx, "Remove Link", 120, 0) then
      self:remove_link()
      ImGui.CloseCurrentPopup(ctx)
      ImGui.EndPopup(ctx)
      return
    end
  end

  ImGui.Dummy(ctx, 0, 8)
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 8)

  -- Link mode selector
  ImGui.Text(ctx, "Link Mode:")
  ImGui.SameLine(ctx, 0, 10)

  -- LINK mode button
  local link_active = self.link_mode == ParameterLinkManager.LINK_MODE.LINK
  if link_active then
    ImGui.PushStyleColor(ctx, ImGui.Col_Button, hexrgb("#4AE290"))
  end
  if ImGui.Button(ctx, "LINK", 80, 0) then
    self.link_mode = ParameterLinkManager.LINK_MODE.LINK
  end
  if link_active then
    ImGui.PopStyleColor(ctx)
  end
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "LINK: Parameters move by same delta")
  end

  ImGui.SameLine(ctx, 0, 8)

  -- SYNC mode button
  local sync_active = self.link_mode == ParameterLinkManager.LINK_MODE.SYNC
  if sync_active then
    ImGui.PushStyleColor(ctx, ImGui.Col_Button, hexrgb("#4AE290"))
  end
  if ImGui.Button(ctx, "SYNC", 80, 0) then
    self.link_mode = ParameterLinkManager.LINK_MODE.SYNC
  end
  if sync_active then
    ImGui.PopStyleColor(ctx)
  end
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "SYNC: Child mirrors parent value")
  end

  ImGui.Dummy(ctx, 0, 8)

  -- Search box
  ImGui.SetNextItemWidth(ctx, -1)
  local changed, new_text = ImGui.InputTextWithHint(ctx, "##search", "Search parameters...", self.search_text)
  if changed then
    self.search_text = new_text
  end

  ImGui.Dummy(ctx, 0, 8)

  -- Compatible parameters list using ChipList
  if ImGui.BeginChild(ctx, "##param_list", 0, -40) then
    local compatible = self:get_compatible_params()

    -- Convert to chip items
    local chip_items = {}
    for _, param_info in ipairs(compatible) do
      table.insert(chip_items, {
        id = param_info.id,
        label = param_info.name,
        color = hexrgb("#4A90E2"),  -- Blue for parameters
      })
    end

    local clicked_param = ChipList.draw_columns(ctx, chip_items, {
      search_text = self.search_text,
      use_dot_style = true,
      bg_color = hexrgb("#252530"),
      dot_size = 7,
      dot_spacing = 7,
      rounding = 5,
      padding_h = 12,
      column_width = 220,
      column_spacing = 16,
      item_spacing = 4,
    })

    if clicked_param then
      self:create_link(clicked_param)
      ImGui.CloseCurrentPopup(ctx)
      ImGui.EndChild(ctx)
      ImGui.EndPopup(ctx)
      return
    end

    ImGui.EndChild(ctx)
  end

  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 4)

  -- Close button (centered)
  local button_w = 100
  local avail_w = ImGui.GetContentRegionAvail(ctx)
  ImGui.SetCursorPosX(ctx, (avail_w - button_w) * 0.5)

  if ImGui.Button(ctx, "Cancel", button_w, 0) then
    ImGui.CloseCurrentPopup(ctx)
    self:close()
  end

  ImGui.EndPopup(ctx)
end

return M

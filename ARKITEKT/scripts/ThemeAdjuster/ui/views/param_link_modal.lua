-- @noindex
-- ThemeAdjuster/ui/views/param_link_modal.lua
-- Parameter link selection modal

local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local ParameterLinkManager = require('ThemeAdjuster.core.parameter_link_manager')
local hexrgb = Colors.hexrgb

local M = {}
local ParamLinkModal = {}
ParamLinkModal.__index = ParamLinkModal

function M.new(view)
  local self = setmetatable({
    view = view,

    -- Modal state
    open = false,
    source_param = nil,  -- The parameter we're creating a link from
    source_param_type = nil,

    -- UI state
    search_text = "",
    selected_target = nil,
  }, ParamLinkModal)

  return self
end

-- Open the modal for a specific source parameter
function ParamLinkModal:show(param_name, param_type)
  self.open = true
  self.source_param = param_name
  self.source_param_type = param_type
  self.search_text = ""
  self.selected_target = nil
end

function ParamLinkModal:close()
  self.open = false
  self.source_param = nil
  self.source_param_type = nil
  self.search_text = ""
  self.selected_target = nil
end

-- Get compatible parameters (filtered by type)
function ParamLinkModal:get_compatible_params()
  local compatible = {}

  -- Get all assigned parameters from all tabs
  for tab_id, assignments in pairs(self.view.assignments) do
    for _, assignment in ipairs(assignments) do
      local param_name = assignment.param_name

      -- Skip self
      if param_name ~= self.source_param then
        -- Find the parameter definition
        for _, param in ipairs(self.view.all_params) do
          if param.name == param_name then
            -- Check type compatibility
            if ParameterLinkManager.are_types_compatible(self.source_param_type, param.type) then
              table.insert(compatible, {
                name = param_name,
                type = param.type,
                tab = tab_id,
                description = param.description or "",
              })
            end
            break
          end
        end
      end
    end
  end

  return compatible
end

-- Create link and close modal
function ParamLinkModal:create_link(target_param, mode)
  local success, error_msg = ParameterLinkManager.create_link(self.source_param, target_param, mode)

  if success then
    -- Save assignments to persist link data
    self.view:save_assignments()
    self:close()
  else
    -- Show error (could use a toast notification system if available)
    print("Failed to create link: " .. (error_msg or "Unknown error"))
  end

  return success
end

-- Remove link
function ParamLinkModal:remove_link()
  if ParameterLinkManager.is_linked(self.source_param) then
    ParameterLinkManager.remove_link(self.source_param)
    self.view:save_assignments()
    self:close()
  end
end

-- Render the modal
function ParamLinkModal:render(ctx)
  if not self.open then return end

  local title = "Link Parameter: " .. (self.source_param or "")

  -- Center the modal
  local display_w, display_h = ImGui.GetMainViewport(ctx):GetSize()
  local modal_w = 600
  local modal_h = 500
  ImGui.SetNextWindowPos(ctx, (display_w - modal_w) / 2, (display_h - modal_h) / 2, ImGui.Cond_Appearing)
  ImGui.SetNextWindowSize(ctx, modal_w, modal_h, ImGui.Cond_Appearing)

  local visible, open = ImGui.Begin(ctx, title, true, ImGui.WindowFlags_NoCollapse)

  if not open then
    self:close()
  end

  if visible then
    -- Source parameter info
    ImGui.TextColored(ctx, hexrgb("#AAAAAA"), "Source Parameter:")
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
      ImGui.Text(ctx, string.format("Currently linked to: %s", parent))
      ImGui.PopStyleColor(ctx)

      ImGui.Spacing(ctx)
      ImGui.Text(ctx, "Link Mode:")
      ImGui.SameLine(ctx)

      -- LINK mode button
      local link_color = mode == ParameterLinkManager.LINK_MODE.LINK and hexrgb("#4AE290") or hexrgb("#555555")
      ImGui.PushStyleColor(ctx, ImGui.Col_Button, link_color)
      if ImGui.Button(ctx, "LINK", 80, 0) then
        ParameterLinkManager.set_link_mode(self.source_param, ParameterLinkManager.LINK_MODE.LINK)
        self.view:save_assignments()
      end
      ImGui.PopStyleColor(ctx)

      if ImGui.IsItemHovered(ctx) then
        ImGui.SetTooltip(ctx, "LINK: Parameters move together by same delta value")
      end

      ImGui.SameLine(ctx, 0, 8)

      -- SYNC mode button
      local sync_color = mode == ParameterLinkManager.LINK_MODE.SYNC and hexrgb("#4AE290") or hexrgb("#555555")
      ImGui.PushStyleColor(ctx, ImGui.Col_Button, sync_color)
      if ImGui.Button(ctx, "SYNC", 80, 0) then
        ParameterLinkManager.set_link_mode(self.source_param, ParameterLinkManager.LINK_MODE.SYNC)
        self.view:save_assignments()
      end
      ImGui.PopStyleColor(ctx)

      if ImGui.IsItemHovered(ctx) then
        ImGui.SetTooltip(ctx, "SYNC: Child mirrors parent's exact value")
      end

      ImGui.Spacing(ctx)

      -- Remove link button
      if ImGui.Button(ctx, "Remove Link", 100, 0) then
        self:remove_link()
        return  -- Modal closed
      end
    end

    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    -- Search box
    ImGui.PushItemWidth(ctx, -1)
    local changed, new_text = ImGui.InputTextWithHint(ctx, "##search", "Search parameters...", self.search_text)
    if changed then
      self.search_text = new_text
    end
    ImGui.PopItemWidth(ctx)

    ImGui.Spacing(ctx)

    -- Compatible parameters list
    ImGui.Text(ctx, "Compatible Parameters:")
    ImGui.Spacing(ctx)

    local compatible = self:get_compatible_params()

    -- Table for parameters
    local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)
    local table_flags = ImGui.TableFlags_ScrollY |
                       ImGui.TableFlags_RowBg |
                       ImGui.TableFlags_BordersOuter |
                       ImGui.TableFlags_BordersV

    if ImGui.BeginTable(ctx, "param_link_table", 3, table_flags, avail_w, avail_h - 60) then
      ImGui.TableSetupScrollFreeze(ctx, 0, 1)
      ImGui.TableSetupColumn(ctx, "Parameter", ImGui.TableColumnFlags_WidthStretch)
      ImGui.TableSetupColumn(ctx, "Tab", ImGui.TableColumnFlags_WidthFixed, 80)
      ImGui.TableSetupColumn(ctx, "Actions", ImGui.TableColumnFlags_WidthFixed, 150)
      ImGui.TableHeadersRow(ctx)

      -- Render rows
      for _, param_info in ipairs(compatible) do
        local param_name = param_info.name

        -- Filter by search
        if self.search_text == "" or param_name:lower():find(self.search_text:lower(), 1, true) then
          ImGui.TableNextRow(ctx)

          -- Column 0: Parameter name
          ImGui.TableSetColumnIndex(ctx, 0)
          ImGui.Text(ctx, param_name)

          -- Column 1: Tab
          ImGui.TableSetColumnIndex(ctx, 1)
          local tab_color = self.view.tab_colors[param_info.tab] or hexrgb("#888888")
          ImGui.PushStyleColor(ctx, ImGui.Col_Text, tab_color)
          ImGui.Text(ctx, param_info.tab)
          ImGui.PopStyleColor(ctx)

          -- Column 2: Actions
          ImGui.TableSetColumnIndex(ctx, 2)

          -- Link button
          if ImGui.Button(ctx, "LINK##" .. param_name, 65, 0) then
            self:create_link(param_name, ParameterLinkManager.LINK_MODE.LINK)
            return  -- Modal closed on success
          end

          ImGui.SameLine(ctx, 0, 5)

          -- Sync button
          if ImGui.Button(ctx, "SYNC##" .. param_name, 65, 0) then
            self:create_link(param_name, ParameterLinkManager.LINK_MODE.SYNC)
            return  -- Modal closed on success
          end

          -- Tooltip
          if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "LINK: Move together by same delta\nSYNC: Mirror exact value")
          end
        end
      end

      ImGui.EndTable(ctx)
    end

    ImGui.Spacing(ctx)

    -- Close button
    if ImGui.Button(ctx, "Cancel", 100, 0) then
      self:close()
    end

    ImGui.End(ctx)
  end
end

return M

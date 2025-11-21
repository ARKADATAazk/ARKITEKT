-- @noindex
-- TemplateBrowser/ui/views/helpers.lua
-- Common view helper functions to reduce duplication

local ImGui = require 'imgui' '0.10'

local M = {}

-- ImGui compatibility for BeginChild
-- ChildFlags_Border might not exist in all versions, so use hardcoded values
-- ChildFlags_None = 0, ChildFlags_Border = 1
function M.begin_child_compat(ctx, id, w, h, want_border, window_flags)
  local child_flags = want_border and 1 or 0
  return ImGui.BeginChild(ctx, id, w, h, child_flags, window_flags or 0)
end

-- Draw a section header with consistent styling
function M.section_header(ctx, title, config)
  ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.header_bg)
  ImGui.Text(ctx, title)
  ImGui.PopStyleColor(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
end

-- Draw a section header with separator text (centered)
function M.section_separator_text(ctx, title, config)
  ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.header_bg)
  ImGui.SeparatorText(ctx, title)
  ImGui.PopStyleColor(ctx)
end

return M

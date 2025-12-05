-- @noindex
-- WalterBuilder/ui/panels/code_panel.lua
-- Code preview panel - shows generated WALTER code

local ImGui = require('arkitekt.core.imgui')
local Ark = require('arkitekt')
local Serializer = require('WalterBuilder.domain.serializer')

local M = {}
local Panel = {}
Panel.__index = Panel

function M.new(opts)
  opts = opts or {}

  local self = setmetatable({
    -- Elements to serialize
    elements = {},

    -- Options
    include_comments = true,
    include_header = true,
    layout_name = '',

    -- Cached code
    cached_code = '',
    cache_dirty = true,

    -- Copy feedback
    copy_feedback_timer = 0,
  }, Panel)

  return self
end

-- Set elements to generate code for
function Panel:set_elements(elements)
  self.elements = elements
  self.cache_dirty = true
end

-- Mark cache as dirty (need to regenerate)
function Panel:invalidate()
  self.cache_dirty = true
end

-- Generate the WALTER code
function Panel:generate_code()
  if not self.cache_dirty then
    return self.cached_code
  end

  local opts = {
    include_comments = self.include_comments,
    include_header = self.include_header,
  }

  if self.layout_name and self.layout_name ~= '' then
    -- Generate as named layout
    self.cached_code = Serializer.serialize_layout(self.layout_name, self.elements, opts)
  else
    -- Generate as plain set commands
    self.cached_code = Serializer.serialize_elements(self.elements, opts)
  end

  self.cache_dirty = false
  return self.cached_code
end

-- Copy code to clipboard
function Panel:copy_to_clipboard(ctx)
  local code = self:generate_code()
  ImGui.SetClipboardText(ctx, code)
  self.copy_feedback_timer = 2.0  -- Show feedback for 2 seconds
end

-- Draw code with syntax highlighting (basic)
function Panel:draw_code_highlighted(ctx, code)
  -- Split into lines
  for line in (code .. '\n'):gmatch('([^\n]*)\n') do
    if line:match('^;') then
      -- Comment line
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x6A9955FF)
      ImGui.Text(ctx, line)
      ImGui.PopStyleColor(ctx)
    elseif line:match('^%s*set%s+') then
      -- Set command
      local element_id, coords = line:match('^(%s*set%s+[%w._]+)%s+(.*)$')
      if element_id then
        -- 'set element.id' part
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x569CD6FF)
        ImGui.Text(ctx, element_id)
        ImGui.PopStyleColor(ctx)

        -- Coordinates part
        ImGui.SameLine(ctx, 0, 0)
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xCE9178FF)
        ImGui.Text(ctx, ' ' .. coords)
        ImGui.PopStyleColor(ctx)
      else
        ImGui.Text(ctx, line)
      end
    elseif line:match('^%s*clear%s+') then
      -- Clear command
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xC586C0FF)
      ImGui.Text(ctx, line)
      ImGui.PopStyleColor(ctx)
    elseif line:match('^Layout%s+') or line:match('^EndLayout') then
      -- Layout keywords
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x4EC9B0FF)
      ImGui.Text(ctx, line)
      ImGui.PopStyleColor(ctx)
    elseif line == '' then
      ImGui.Dummy(ctx, 0, ImGui.GetTextLineHeight(ctx))
    else
      -- Default
      ImGui.Text(ctx, line)
    end
  end
end

-- Main draw function
function Panel:draw(ctx)
  -- Update copy feedback timer
  if self.copy_feedback_timer > 0 then
    self.copy_feedback_timer = self.copy_feedback_timer - ImGui.GetIO(ctx).DeltaTime
  end

  -- Header with options
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFFFFFFFF)
  ImGui.Text(ctx, 'Generated WALTER Code')
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 4)

  -- Options row
  local comments_result = Ark.Checkbox(ctx, {
    id = 'code_comments',
    label = 'Comments',
    is_checked = self.include_comments,
    advance = 'none',
  })
  if comments_result.changed then
    self.include_comments = comments_result.value
    self.cache_dirty = true
  end

  ImGui.SameLine(ctx, 0, 16)

  local header_result = Ark.Checkbox(ctx, {
    id = 'code_header',
    label = 'Header',
    is_checked = self.include_header,
    advance = 'vertical',
  })
  if header_result.changed then
    self.include_header = header_result.value
    self.cache_dirty = true
  end

  ImGui.Dummy(ctx, 0, 4)

  -- Layout name input
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xAAAAAAFF)
  ImGui.Text(ctx, 'Layout name (optional):')
  ImGui.PopStyleColor(ctx)

  ImGui.SameLine(ctx)
  local name_result = Ark.InputText(ctx, {
    id = 'layout_name',
    text = self.layout_name,
    width = 150,
    hint = 'MyLayout',
    advance = 'vertical',
  })
  if name_result.changed then
    self.layout_name = name_result.value
    self.cache_dirty = true
  end

  ImGui.Dummy(ctx, 0, 8)

  -- Copy button
  local copy_label = self.copy_feedback_timer > 0 and 'Copied!' or 'Copy to Clipboard'
  local avail_w = ImGui.GetContentRegionAvail(ctx)
  local copy_result = Ark.Button(ctx, {
    id = 'copy_code',
    label = copy_label,
    width = avail_w,
    height = 26,
    preset = self.copy_feedback_timer > 0 and 'success' or nil,
  })
  if copy_result.clicked then
    self:copy_to_clipboard(ctx)
  end

  ImGui.Dummy(ctx, 0, 8)
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 4)

  -- Code display area
  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)

  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, 0x1E1E1EFF)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 8, 8)

  if ImGui.BeginChild(ctx, 'code_view', avail_w, avail_h - 4, ImGui.ChildFlags_Borders, 0) then
    local code = self:generate_code()

    if code == '' or #self.elements == 0 then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x666666FF)
      ImGui.Text(ctx, 'No elements in layout')
      ImGui.Dummy(ctx, 0, 8)
      ImGui.Text(ctx, 'Add elements from the Elements panel')
      ImGui.Text(ctx, 'to see generated WALTER code here.')
      ImGui.PopStyleColor(ctx)
    else
      -- Use monospace-style display
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xD4D4D4FF)
      self:draw_code_highlighted(ctx, code)
      ImGui.PopStyleColor(ctx)
    end

    ImGui.EndChild(ctx)
  end

  ImGui.PopStyleVar(ctx)
  ImGui.PopStyleColor(ctx)

  return nil
end

-- Get the current generated code
function Panel:get_code()
  return self:generate_code()
end

return M

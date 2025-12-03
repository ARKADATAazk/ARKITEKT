-- @noindex
-- WalterBuilder/ui/panels/code_panel.lua
-- Code preview panel - shows generated WALTER code

local ImGui = require('arkitekt.core.imgui')
local Ark = require('arkitekt')
local Serializer = require('WalterBuilder.domain.serializer')

local hexrgb = Ark.Colors.Hexrgb

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
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb('#6A9955'))
      ImGui.Text(ctx, line)
      ImGui.PopStyleColor(ctx)
    elseif line:match('^%s*set%s+') then
      -- Set command
      local element_id, coords = line:match('^(%s*set%s+[%w._]+)%s+(.*)$')
      if element_id then
        -- 'set element.id' part
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb('#569CD6'))
        ImGui.Text(ctx, element_id)
        ImGui.PopStyleColor(ctx)

        -- Coordinates part
        ImGui.SameLine(ctx, 0, 0)
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb('#CE9178'))
        ImGui.Text(ctx, ' ' .. coords)
        ImGui.PopStyleColor(ctx)
      else
        ImGui.Text(ctx, line)
      end
    elseif line:match('^%s*clear%s+') then
      -- Clear command
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb('#C586C0'))
      ImGui.Text(ctx, line)
      ImGui.PopStyleColor(ctx)
    elseif line:match('^Layout%s+') or line:match('^EndLayout') then
      -- Layout keywords
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb('#4EC9B0'))
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
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb('#FFFFFF'))
  ImGui.Text(ctx, 'Generated WALTER Code')
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 4)

  -- Options row
  local _, inc_comments = ImGui.Checkbox(ctx, 'Comments', self.include_comments)
  self.include_comments = inc_comments
  if inc_comments ~= self.include_comments then self.cache_dirty = true end

  ImGui.SameLine(ctx, 0, 16)

  local _, inc_header = ImGui.Checkbox(ctx, 'Header', self.include_header)
  if inc_header ~= self.include_header then
    self.include_header = inc_header
    self.cache_dirty = true
  end

  ImGui.Dummy(ctx, 0, 4)

  -- Layout name input
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb('#AAAAAA'))
  ImGui.Text(ctx, 'Layout name (optional):')
  ImGui.PopStyleColor(ctx)

  ImGui.SameLine(ctx)
  ImGui.SetNextItemWidth(ctx, 150)
  local changed, name = ImGui.InputText(ctx, '##layout_name', self.layout_name)
  if changed then
    self.layout_name = name
    self.cache_dirty = true
  end

  ImGui.Dummy(ctx, 0, 8)

  -- Copy button
  local copy_label = self.copy_feedback_timer > 0 and 'Copied!' or 'Copy to Clipboard'
  local copy_color = self.copy_feedback_timer > 0 and hexrgb('#2A4A2A') or hexrgb('#2A2A2A')

  ImGui.PushStyleColor(ctx, ImGui.Col_Button, copy_color)
  if ImGui.Button(ctx, copy_label, -1, 26) then
    self:copy_to_clipboard(ctx)
  end
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 8)
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 4)

  -- Code display area
  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)

  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb('#1E1E1E'))
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 8, 8)

  if ImGui.BeginChild(ctx, 'code_view', avail_w, avail_h - 4, ImGui.ChildFlags_Borders, 0) then
    local code = self:generate_code()

    if code == '' or #self.elements == 0 then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb('#666666'))
      ImGui.Text(ctx, 'No elements in layout')
      ImGui.Dummy(ctx, 0, 8)
      ImGui.Text(ctx, 'Add elements from the Elements panel')
      ImGui.Text(ctx, 'to see generated WALTER code here.')
      ImGui.PopStyleColor(ctx)
    else
      -- Use monospace-style display
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb('#D4D4D4'))
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

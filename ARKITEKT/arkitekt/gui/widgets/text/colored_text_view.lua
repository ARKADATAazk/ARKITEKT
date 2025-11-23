-- @noindex
-- arkitekt/gui/widgets/colored_text_view.lua
-- Read-only colored text viewer with native selection support

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb


local M = {}

local ColoredTextView = {}
ColoredTextView.__index = ColoredTextView

-- Coordinates helper
local function Coordinates(line, col)
  return {line = line or 0, col = col or 0}
end

local function coords_equal(a, b)
  return a.line == b.line and a.col == b.col
end

local function coords_less_than(a, b)
  if a.line < b.line then return true end
  if a.line > b.line then return false end
  return a.col < b.col
end

local function coords_less_equal(a, b)
  return coords_equal(a, b) or coords_less_than(a, b)
end

-- Selection mode enum
local SelectionMode = {
  Normal = 0,
  Word = 1,
  Line = 2,
}

function M.new(opts)
  opts = opts or {}
  
  local self = setmetatable({}, ColoredTextView)
  
  -- Text data: array of line objects
  -- Each line: {segments = {{text="...", color=0x...}, ...}}
  self.lines = {}
  
  -- Selection state
  self.selection_start = Coordinates(0, 0)
  self.selection_end = Coordinates(0, 0)
  self.selection_mode = SelectionMode.Normal
  
  -- Interactive selection tracking
  self.interactive_start = Coordinates(0, 0)
  self.interactive_end = Coordinates(0, 0)
  
  -- Mouse tracking
  self.last_click_time = -1.0
  
  -- Visual metrics (calculated during render)
  self.char_advance = {x = 0, y = 0}
  self.text_start_x = 0
  
  -- Callbacks
  self.on_selection_changed = opts.on_selection_changed
  
  return self
end

-- Set lines from console log format
-- Input format: array of {segments = {{text="...", color=0x...}, ...}}
function ColoredTextView:set_lines(lines)
  self.lines = lines or {}
  
  -- Reset selection if out of bounds
  if self.selection_start.line >= #self.lines then
    self.selection_start = Coordinates(0, 0)
    self.selection_end = Coordinates(0, 0)
  end
end

-- Get total character count in a line
function ColoredTextView:get_line_length(line_idx)
  if line_idx < 0 or line_idx >= #self.lines then return 0 end
  
  local line = self.lines[line_idx + 1] -- Lua 1-indexed
  local total = 0
  
  for _, segment in ipairs(line.segments or {}) do
    total = total + #segment.text
  end
  
  return total
end

-- Get text content of a line (all segments concatenated)
function ColoredTextView:get_line_text(line_idx)
  if line_idx < 0 or line_idx >= #self.lines then return "" end
  
  local line = self.lines[line_idx + 1]
  local text = ""
  
  for _, segment in ipairs(line.segments or {}) do
    text = text .. segment.text
  end
  
  return text
end

-- Sanitize coordinates to valid bounds
function ColoredTextView:sanitize_coordinates(coord)
  local line = coord.line
  local col = coord.col
  
  if line >= #self.lines then
    if #self.lines == 0 then
      return Coordinates(0, 0)
    else
      line = #self.lines - 1
      col = self:get_line_length(line)
    end
  end
  
  if line < 0 then
    line = 0
    col = 0
  end
  
  local max_col = self:get_line_length(line)
  col = math.max(0, math.min(col, max_col))
  
  return Coordinates(line, col)
end

-- Convert screen position to text coordinates
function ColoredTextView:screen_pos_to_coordinates(ctx, screen_pos)
  local origin_x, origin_y = ImGui.GetCursorScreenPos(ctx)
  local local_x = screen_pos.x - origin_x
  local local_y = screen_pos.y - origin_y
  
  local line_no = math.max(0, math.floor(local_y / self.char_advance.y))
  line_no = math.min(line_no, #self.lines - 1)
  
  if line_no < 0 or line_no >= #self.lines then
    return self:sanitize_coordinates(Coordinates(line_no, 0))
  end
  
  -- Calculate column by measuring text width
  local line = self.lines[line_no + 1]
  local target_x = local_x - self.text_start_x
  local current_x = 0.0
  local col = 0
  
  for _, segment in ipairs(line.segments or {}) do
    for i = 1, #segment.text do
      local char = segment.text:sub(i, i)
      local char_width = ImGui.CalcTextSize(ctx, char)
      
      if current_x + char_width * 0.5 > target_x then
        return self:sanitize_coordinates(Coordinates(line_no, col))
      end
      
      current_x = current_x + char_width
      col = col + 1
    end
  end
  
  return self:sanitize_coordinates(Coordinates(line_no, col))
end

-- Find word boundaries
function ColoredTextView:find_word_start(coord)
  local line_idx = coord.line
  if line_idx < 0 or line_idx >= #self.lines then return coord end
  
  local text = self:get_line_text(line_idx)
  local col = coord.col
  
  if col >= #text then col = #text end
  if col == 0 then return coord end
  
  -- Skip trailing spaces
  while col > 0 and text:sub(col, col):match("%s") do
    col = col - 1
  end
  
  -- Find word start
  while col > 0 do
    local char = text:sub(col, col)
    if char:match("%s") or char:match("%p") then
      col = col + 1
      break
    end
    col = col - 1
  end
  
  return Coordinates(line_idx, math.max(0, col))
end

function ColoredTextView:find_word_end(coord)
  local line_idx = coord.line
  if line_idx < 0 or line_idx >= #self.lines then return coord end
  
  local text = self:get_line_text(line_idx)
  local col = coord.col
  
  if col >= #text then return coord end
  
  -- Skip leading spaces
  while col < #text and text:sub(col + 1, col + 1):match("%s") do
    col = col + 1
  end
  
  -- Find word end
  while col < #text do
    local char = text:sub(col + 1, col + 1)
    if char:match("%s") or char:match("%p") then
      break
    end
    col = col + 1
  end
  
  return Coordinates(line_idx, col)
end

-- Set selection with mode (Normal, Word, Line)
function ColoredTextView:set_selection(start_coord, end_coord, mode)
  mode = mode or SelectionMode.Normal
  
  start_coord = self:sanitize_coordinates(start_coord)
  end_coord = self:sanitize_coordinates(end_coord)
  
  if coords_less_than(end_coord, start_coord) then
    start_coord, end_coord = end_coord, start_coord
  end
  
  -- Apply selection mode
  if mode == SelectionMode.Word then
    start_coord = self:find_word_start(start_coord)
    end_coord = self:find_word_end(end_coord)
  elseif mode == SelectionMode.Line then
    start_coord = Coordinates(start_coord.line, 0)
    end_coord = Coordinates(end_coord.line, self:get_line_length(end_coord.line))
  end
  
  self.selection_start = start_coord
  self.selection_end = end_coord
  
  if self.on_selection_changed then
    self.on_selection_changed()
  end
end

-- Check if there's a selection
function ColoredTextView:has_selection()
  return coords_less_than(self.selection_start, self.selection_end)
end

-- Get selected text
function ColoredTextView:get_selected_text()
  if not self:has_selection() then return "" end
  
  local result = ""
  local start_line = self.selection_start.line
  local end_line = self.selection_end.line
  
  for line_idx = start_line, end_line do
    local text = self:get_line_text(line_idx)
    
    if line_idx == start_line and line_idx == end_line then
      -- Single line selection
      result = text:sub(self.selection_start.col + 1, self.selection_end.col)
    elseif line_idx == start_line then
      -- First line
      result = result .. text:sub(self.selection_start.col + 1) .. "\n"
    elseif line_idx == end_line then
      -- Last line
      result = result .. text:sub(1, self.selection_end.col)
    else
      -- Middle lines
      result = result .. text .. "\n"
    end
  end
  
  return result
end

-- Copy selection to clipboard
function ColoredTextView:copy()
  if self:has_selection() then
    local text = self:get_selected_text()
    reaper.CF_SetClipboard(text)
    return true
  end
  return false
end

-- Select all
function ColoredTextView:select_all()
  if #self.lines == 0 then return end
  
  local last_line = #self.lines - 1
  local last_col = self:get_line_length(last_line)
  
  self:set_selection(
    Coordinates(0, 0),
    Coordinates(last_line, last_col),
    SelectionMode.Normal
  )
end

-- Handle mouse inputs (called after InvisibleButton interaction)
function ColoredTextView:handle_mouse_inputs(ctx, is_hovered)
  if not is_hovered then return end
  
  local is_shift = ImGui.IsKeyDown(ctx, ImGui.Mod_Shift)
  local is_ctrl = ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl)
  
  local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
  local click = ImGui.IsMouseClicked(ctx, 0)
  local double_click = ImGui.IsMouseDoubleClicked(ctx, 0)
  local current_time = reaper.time_precise()
  
  -- Triple click detection
  local triple_click = click and not double_click and 
                       (self.last_click_time ~= -1.0 and 
                        current_time - self.last_click_time < 0.5)
  
  if triple_click then
    -- Line selection mode
    if not is_ctrl then
      local coord = self:screen_pos_to_coordinates(ctx, {x = mouse_x, y = mouse_y})
      self.interactive_start = coord
      self.interactive_end = coord
      self.selection_mode = SelectionMode.Line
      self:set_selection(self.interactive_start, self.interactive_end, self.selection_mode)
    end
    self.last_click_time = -1.0
    
  elseif double_click then
    -- Word selection mode
    if not is_ctrl then
      local coord = self:screen_pos_to_coordinates(ctx, {x = mouse_x, y = mouse_y})
      self.interactive_start = coord
      self.interactive_end = coord
      self.selection_mode = SelectionMode.Word
      self:set_selection(self.interactive_start, self.interactive_end, self.selection_mode)
    end
    self.last_click_time = current_time
    
  elseif click then
    -- Single click
    local coord = self:screen_pos_to_coordinates(ctx, {x = mouse_x, y = mouse_y})
    self.interactive_start = coord
    self.interactive_end = coord
    
    if is_ctrl then
      self.selection_mode = SelectionMode.Word
    else
      self.selection_mode = SelectionMode.Normal
    end
    
    self:set_selection(self.interactive_start, self.interactive_end, self.selection_mode)
    self.last_click_time = current_time
    
  elseif ImGui.IsMouseDragging(ctx, 0) and ImGui.IsMouseDown(ctx, 0) then
    -- Drag to extend selection
    local coord = self:screen_pos_to_coordinates(ctx, {x = mouse_x, y = mouse_y})
    self.interactive_end = coord
    self:set_selection(self.interactive_start, self.interactive_end, self.selection_mode)
  end
end

-- Handle keyboard inputs
function ColoredTextView:handle_keyboard_inputs(ctx)
  if not ImGui.IsWindowFocused(ctx) then return end
  
  local is_ctrl = ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl)
  
  -- Ctrl+A - Select all
  if is_ctrl and ImGui.IsKeyPressed(ctx, ImGui.Key_A) then
    self:select_all()
  end
  
  -- Ctrl+C - Copy
  if is_ctrl and ImGui.IsKeyPressed(ctx, ImGui.Key_C) then
    self:copy()
  end
end

-- Render the text view
function ColoredTextView:render(ctx, width, height)
  -- Calculate metrics
  local font_size = ImGui.GetFontSize(ctx)
  local char_width = ImGui.CalcTextSize(ctx, "#")
  self.char_advance = {
    x = char_width,
    y = ImGui.GetTextLineHeightWithSpacing(ctx)
  }
  self.text_start_x = 10 -- Left margin
  
  -- Get visible region
  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  local scroll_y = ImGui.GetScrollY(ctx)
  
  local first_line = math.floor(scroll_y / self.char_advance.y)
  local visible_lines = math.ceil(height / self.char_advance.y) + 1
  local last_line = math.min(#self.lines - 1, first_line + visible_lines)
  
  -- Calculate total content height
  local total_height = math.max(height, #self.lines * self.char_advance.y)
  
  -- Create invisible button to capture all mouse input
  local button_start_x, button_start_y = ImGui.GetCursorScreenPos(ctx)
  ImGui.InvisibleButton(ctx, "##text_view_input", width, total_height)
  local is_hovered = ImGui.IsItemHovered(ctx)
  
  -- Reset cursor for drawing
  ImGui.SetCursorScreenPos(ctx, button_start_x, button_start_y)
  
  if #self.lines == 0 then
    ImGui.Text(ctx, "(empty)")
    return
  end
  
  local draw_list = ImGui.GetWindowDrawList(ctx)
  
  -- Render visible lines
  for line_idx = first_line, last_line do
    if line_idx >= #self.lines then break end
    
    local line = self.lines[line_idx + 1]
    local line_y = cursor_y + line_idx * self.char_advance.y
    local text_x = cursor_x + self.text_start_x
    
    -- Draw selection background for this line
    if self:has_selection() then
      local line_start_coord = Coordinates(line_idx, 0)
      local line_end_coord = Coordinates(line_idx, self:get_line_length(line_idx))
      
      if coords_less_equal(self.selection_start, line_end_coord) and
         coords_less_equal(line_start_coord, self.selection_end) then
        
        -- Calculate selection bounds for this line
        local sel_start_col = 0
        local sel_end_col = self:get_line_length(line_idx)
        
        if self.selection_start.line == line_idx then
          sel_start_col = self.selection_start.col
        elseif self.selection_start.line > line_idx then
          sel_start_col = sel_end_col -- No selection on this line
        end
        
        if self.selection_end.line == line_idx then
          sel_end_col = self.selection_end.col
        elseif self.selection_end.line < line_idx then
          sel_end_col = 0 -- No selection on this line
        end
        
        if sel_start_col < sel_end_col then
          -- Calculate pixel positions
          local line_text = self:get_line_text(line_idx)
          local start_text = line_text:sub(1, sel_start_col)
          local sel_text = line_text:sub(sel_start_col + 1, sel_end_col)
          
          local start_width = ImGui.CalcTextSize(ctx, start_text)
          local sel_width = ImGui.CalcTextSize(ctx, sel_text)
          
          local sel_x1 = text_x + start_width
          local sel_x2 = sel_x1 + sel_width
          local sel_y1 = line_y
          local sel_y2 = line_y + self.char_advance.y
          
          -- Draw selection rectangle with dark grey
          ImGui.DrawList_AddRectFilled(draw_list, sel_x1, sel_y1, sel_x2, sel_y2, hexrgb("#404040CC"))
        end
      end
    end
    
    -- Render colored text segments
    local current_x = text_x
    for _, segment in ipairs(line.segments or {}) do
      if segment.text and #segment.text > 0 then
        ImGui.DrawList_AddText(draw_list, current_x, line_y, segment.color, segment.text)
        local seg_width = ImGui.CalcTextSize(ctx, segment.text)
        current_x = current_x + seg_width
      end
    end
  end
  
  -- Handle inputs
  self:handle_mouse_inputs(ctx, is_hovered)
  self:handle_keyboard_inputs(ctx)
end

return M

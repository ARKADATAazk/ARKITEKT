-- @noindex
-- TemplateBrowser/data/undo.lua
-- Undo/redo system for file operations

local Logger = require('arkitekt.debug.logger')

local M = {}

local UndoManager = {}
UndoManager.__index = UndoManager

function M.new()
  local self = setmetatable({
    stack = {},
    current_index = 0,
    max_stack_size = 50,
  }, UndoManager)
  return self
end

-- Add an operation to the undo stack
-- operation = { undo_fn = function, redo_fn = function, description = string }
function UndoManager:push(operation)
  -- Remove any operations after current index (when doing new operation after undo)
  while #self.stack > self.current_index do
    table.remove(self.stack)
  end

  -- Add new operation
  table.insert(self.stack, operation)
  self.current_index = #self.stack

  -- Limit stack size
  if #self.stack > self.max_stack_size then
    table.remove(self.stack, 1)
    self.current_index = self.current_index - 1
  end

  Logger.debug("UNDO", "Added operation '%s' (stack: %d)", operation.description, #self.stack)
end

-- Undo the last operation
function UndoManager:undo()
  if self.current_index <= 0 then
    Logger.debug("UNDO", "Nothing to undo")
    return false
  end

  local operation = self.stack[self.current_index]
  if operation and operation.undo_fn then
    local success = operation.undo_fn()
    if success then
      self.current_index = self.current_index - 1
      Logger.info("UNDO", "Undo: '%s'", operation.description)
      return true
    else
      Logger.error("UNDO", "Undo FAILED: '%s'", operation.description)
      return false
    end
  end

  return false
end

-- Redo an undone operation
function UndoManager:redo()
  if self.current_index >= #self.stack then
    Logger.debug("UNDO", "Nothing to redo")
    return false
  end

  local operation = self.stack[self.current_index + 1]
  if operation and operation.redo_fn then
    local success = operation.redo_fn()
    if success then
      self.current_index = self.current_index + 1
      Logger.info("UNDO", "Redo: '%s'", operation.description)
      return true
    else
      Logger.error("UNDO", "Redo FAILED: '%s'", operation.description)
      return false
    end
  end

  return false
end

-- Check if undo is available
function UndoManager:can_undo()
  return self.current_index > 0
end

-- Check if redo is available
function UndoManager:can_redo()
  return self.current_index < #self.stack
end

-- Clear the undo stack
function UndoManager:clear()
  self.stack = {}
  self.current_index = 0
  Logger.debug("UNDO", "Stack cleared")
end

return M

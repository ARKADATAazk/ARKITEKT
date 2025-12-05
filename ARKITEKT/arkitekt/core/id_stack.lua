-- @noindex
-- arkitekt/core/id_stack.lua
-- ImGui-style PushID/PopID stack for scoping widget IDs
-- Enables ImGui-familiar ID scoping without requiring explicit IDs everywhere
-- Syncs with ImGui's PushID/PopID for red square debugging support

local ImGui = require('arkitekt.core.imgui')

local M = {}

-- Per-context ID stacks (weak keys to prevent memory leaks when ctx is GC'd)
-- _stacks[ctx] = { 'parent', 'child', ... }
local _stacks = setmetatable({}, { __mode = 'k' })

--- Push an ID onto the stack for this context
-- Syncs with ImGui.PushID for red square debugging support
-- All widgets drawn until PopID will have this ID prepended
-- @param ctx ImGui context
-- @param id string|number - ID to push (converted to string)
function M.push(ctx, id)
  if not ctx then
    error('PushID: ctx is nil', 2)
  end
  if not id then
    error('PushID: id is nil', 2)
  end

  -- Track in ARKITEKT stack (for instance lookup)
  _stacks[ctx] = _stacks[ctx] or {}
  table.insert(_stacks[ctx], tostring(id))

  -- Sync with ImGui stack (for red square debugging + ImGui widgets)
  ImGui.PushID(ctx, id)
end

--- Pop an ID from the stack for this context
-- Syncs with ImGui.PopID
-- @param ctx ImGui context
function M.pop(ctx)
  if not ctx then
    error('PopID: ctx is nil', 2)
  end

  local stack = _stacks[ctx]
  if not stack or #stack == 0 then
    error('PopID: No matching PushID (stack is empty)', 2)
  end

  -- Pop from ARKITEKT stack
  table.remove(stack)

  -- Sync with ImGui stack
  ImGui.PopID(ctx)
end

--- Resolve a base ID with the current stack
-- If stack exists, prepends stack path to base_id
-- If no stack, returns base_id unchanged
-- @param ctx ImGui context
-- @param base_id string - Base ID to resolve
-- @return string - Resolved ID with stack prefix if applicable
function M.resolve(ctx, base_id)
  if not ctx then
    error('IdStack.resolve: ctx is nil', 2)
  end
  if not base_id then
    error('IdStack.resolve: base_id is nil', 2)
  end

  local stack = _stacks[ctx]
  if not stack or #stack == 0 then
    return base_id  -- No stack active, return as-is
  end

  -- Prepend stack path: 'parent/child/base_id'
  -- Optimized: Single table.concat instead of concat + '..' + base_id
  local n = #stack
  stack[n + 1] = base_id
  local result = table.concat(stack, '/')
  stack[n + 1] = nil  -- Restore stack (don't permanently add base_id)
  return result
end

--- Clear the stack for this context (for cleanup/testing)
-- @param ctx ImGui context
function M.Clear(ctx)
  _stacks[ctx] = nil
end

--- Get current stack depth (for debugging)
-- @param ctx ImGui context
-- @return number - Current stack depth
function M.depth(ctx)
  local stack = _stacks[ctx]
  return stack and #stack or 0
end

return M

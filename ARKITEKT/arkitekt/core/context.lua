-- @noindex
-- arkitekt/core/context.lua
-- ArkContext: Frame-scoped ARKITEKT context paired with ImGui ctx
--
-- Provides centralized per-frame caching and widget utilities.
-- Widgets get cached values without individual optimization work.
--
-- USAGE (internal to widgets):
--   local Context = require('arkitekt.core.context')
--   local actx = Context.get(ctx)
--   local dl = actx:draw_list()       -- Cached per-frame
--   local now = actx.time             -- Sampled once per-frame
--   local id = actx:resolve_id('btn') -- Delegates to IdStack
--   local val = actx:cache('key', fn) -- Per-frame memoization
--
-- ARCHITECTURE:
--   - One actx per ImGui ctx (weak table, GC handles cleanup)
--   - Refresh on new frame (detected via GetFrameCount)
--   - Zero API change for users (widgets use it internally)

local ImGui = require('arkitekt.core.imgui')
local IdStack = require('arkitekt.core.id_stack')

local M = {}

-- =============================================================================
-- CONTEXT STORAGE
-- =============================================================================

-- Weak keys: when ImGui ctx is collected, actx is automatically cleaned up
local _contexts = setmetatable({}, { __mode = 'k' })

-- =============================================================================
-- ARKCONTEXT CLASS
-- =============================================================================

local ArkContext = {}
ArkContext.__index = ArkContext

--- Refresh context state for new frame
-- Called once per frame when frame count changes
function ArkContext:_refresh()
  -- Reset lazy caches
  self._draw_list = nil
  self._mouse_x = nil
  self._mouse_y = nil
  self._delta_time = nil
  self._cache = {}

  -- Reset stacks (should be balanced, but safety reset per frame)
  self._disabled = false
  self._disabled_stack = {}

  -- Sample time once per frame
  self.time = reaper.time_precise()
end

--- Get the window draw list (lazy, cached per-frame)
-- IMPORTANT: Must be called AFTER a window's Begin() is called
-- @return userdata ImGui DrawList
function ArkContext:draw_list()
  if not self._draw_list then
    self._draw_list = ImGui.GetWindowDrawList(self.ctx)
  end
  return self._draw_list
end

--- Get foreground draw list (for overlays, tooltips)
-- @return userdata ImGui DrawList
function ArkContext:foreground_draw_list()
  return ImGui.GetForegroundDrawList(self.ctx)
end

--- Get background draw list (for window backgrounds)
-- @return userdata ImGui DrawList
function ArkContext:background_draw_list()
  return ImGui.GetBackgroundDrawList(self.ctx)
end

--- Get mouse position (cached per-frame)
-- @return number, number x, y screen coordinates
function ArkContext:mouse_pos()
  if not self._mouse_x then
    self._mouse_x, self._mouse_y = ImGui.GetMousePos(self.ctx)
  end
  return self._mouse_x, self._mouse_y
end

--- Get delta time since last frame (cached per-frame)
-- @return number Delta time in seconds
function ArkContext:delta_time()
  if not self._delta_time then
    self._delta_time = ImGui.GetDeltaTime(self.ctx)
  end
  return self._delta_time
end

--- Frame-level memoization cache
-- Value computed once per frame and reused across all calls
-- @param key string Cache key
-- @param compute_fn function Factory function if not cached
-- @return any Cached or computed value
function ArkContext:cache(key, compute_fn)
  local cached = self._cache[key]
  if cached == nil then
    cached = compute_fn()
    self._cache[key] = cached
  end
  return cached
end

--- Clear a specific cache entry (rare, for forced recomputation)
-- @param key string Cache key to clear
function ArkContext:clear_cache(key)
  if key then
    self._cache[key] = nil
  else
    self._cache = {}
  end
end

-- =============================================================================
-- DISABLED STACK
-- =============================================================================
-- Scope-based disabled state - widgets check actx:is_disabled()

--- Begin a disabled region
-- All widgets in this region should be non-interactive and visually dimmed
-- @param condition boolean Whether to disable (allows conditional: begin_disabled(is_loading))
function ArkContext:begin_disabled(condition)
  self._disabled_stack = self._disabled_stack or {}
  table.insert(self._disabled_stack, self._disabled)
  -- Disabled state is sticky - once disabled, stays disabled until end_disabled
  self._disabled = self._disabled or (condition and true or false)
end

--- End a disabled region
-- Restores previous disabled state
function ArkContext:end_disabled()
  if self._disabled_stack and #self._disabled_stack > 0 then
    self._disabled = table.remove(self._disabled_stack)
  else
    self._disabled = false
  end
end

--- Check if currently in a disabled region
-- Widgets should call this and combine with opts.is_disabled
-- @return boolean True if disabled
function ArkContext:is_disabled()
  return self._disabled or false
end

-- =============================================================================
-- ID STACK DELEGATION
-- =============================================================================
-- Convenience wrappers around existing IdStack module

--- Push an ID onto the stack
-- @param id string|number ID to push
function ArkContext:push_id(id)
  IdStack.push(self.ctx, id)
end

--- Pop an ID from the stack
function ArkContext:pop_id()
  IdStack.pop(self.ctx)
end

--- Resolve a base ID with the current stack prefix
-- @param base_id string Base ID to resolve
-- @return string Full ID with stack prefix
function ArkContext:resolve_id(base_id)
  return IdStack.resolve(self.ctx, base_id)
end

--- Get current ID stack depth
-- @return number Stack depth
function ArkContext:id_depth()
  return IdStack.depth(self.ctx)
end

-- =============================================================================
-- FACTORY
-- =============================================================================

--- Create a new ArkContext for an ImGui context
-- @param ctx userdata ImGui context
-- @return table ArkContext instance
local function create(ctx)
  local actx = setmetatable({
    -- Core reference
    ctx = ctx,

    -- Frame tracking
    frame = -1,

    -- Per-frame state (refreshed each frame)
    time = 0,

    -- Lazy caches (nil until first access)
    _draw_list = nil,
    _cache = {},
  }, ArkContext)

  return actx
end

-- =============================================================================
-- PUBLIC API
-- =============================================================================

--- Get or create ArkContext for an ImGui context
-- Primary entry point - call this in every widget
-- @param ctx userdata ImGui context
-- @return table ArkContext instance (cached, refreshed per-frame)
function M.get(ctx)
  if not ctx then
    error('Context.get: ctx is nil', 2)
  end

  -- Lookup or create
  local actx = _contexts[ctx]
  if not actx then
    actx = create(ctx)
    _contexts[ctx] = actx
  end

  -- Refresh if new frame
  local frame = ImGui.GetFrameCount(ctx)
  if actx.frame ~= frame then
    actx:_refresh()
    actx.frame = frame
  end

  return actx
end

-- Alias for convenience
M.actx = M.get

--- Check if a context has an associated ArkContext
-- @param ctx userdata ImGui context
-- @return boolean True if context exists
function M.exists(ctx)
  return _contexts[ctx] ~= nil
end

--- Get context count (for debugging/testing)
-- @return number Number of tracked contexts
function M.count()
  local n = 0
  for _ in pairs(_contexts) do
    n = n + 1
  end
  return n
end

return M

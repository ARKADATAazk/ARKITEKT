-- @noindex
-- arkitekt/core/callbacks.lua
-- Safe callback execution with error handling and chaining
-- Extracted from RegionPlaylist coordinator_bridge for reuse

local M = {}

--- Safely call a function with pcall, returning result or nil on error
--- @param fn? function The function to call
--- @return any|nil The result of the function, or nil if error/nil function
function M.safe_call(fn)
  if not fn then return nil end
  local ok, result = pcall(fn)
  if ok then return result end
  return nil
end

--- Safely call a function, returning a default value on error
--- @param fn? function The function to call
--- @param default any Default value to return on error
--- @return any The result of the function, or default if error
function M.safe_call_or(fn, default)
  if not fn then return default end
  local ok, result = pcall(fn)
  if ok then return result end
  return default
end

--- Safely call a function with arguments
--- @param fn? function The function to call
--- @param ... any Arguments to pass to the function
--- @return boolean success Whether the call succeeded
--- @return any result The result or error message
function M.try_call(fn, ...)
  if not fn then
    return false, "Function is nil"
  end

  local ok, result = pcall(fn, ...)
  return ok, result
end

--- Call a function and log errors (requires Logger)
--- @param fn? function The function to call
--- @param context? string Context for error logging (e.g., "OnClick")
--- @param ... any Arguments to pass to the function
--- @return any|nil The result or nil on error
function M.safe_call_with_log(fn, context, ...)
  if not fn then return nil end

  local ok, result = pcall(fn, ...)
  if not ok then
    local Logger = require('arkitekt.debug.logger')
    Logger.error("CALLBACK", "%s failed: %s", context or "Function", tostring(result))
    return nil
  end

  return result
end

--- Chain multiple callbacks, calling them in sequence
--- Stops on first error unless continue_on_error is true
--- @param callbacks function[] Array of functions to call
--- @param continue_on_error? boolean If true, continue even if a callback fails (default: false)
--- @return boolean success True if all callbacks succeeded
--- @return string[] errors Array of error messages (empty if all succeeded)
function M.chain(callbacks, continue_on_error)
  local errors = {}

  for i, callback in ipairs(callbacks) do
    if callback then
      local ok, err = pcall(callback)
      if not ok then
        table.insert(errors, string.format("Callback #%d failed: %s", i, tostring(err)))
        if not continue_on_error then
          return false, errors
        end
      end
    end
  end

  return #errors == 0, errors
end

--- Create a debounced callback that only fires after delay_ms of inactivity
--- @param fn function The function to debounce
--- @param delay_ms number Delay in milliseconds
--- @return function debounced_fn The debounced function
function M.debounce(fn, delay_ms)
  local timer = nil
  local delay_seconds = delay_ms / 1000.0

  return function(...)
    local args = {...}
    local current_time = reaper.time_precise()

    -- Store timer and args for this invocation
    timer = current_time

    -- Defer the actual call
    reaper.defer(function()
      local elapsed = reaper.time_precise() - timer
      if elapsed >= delay_seconds then
        fn(table.unpack(args))
      end
    end)
  end
end

--- Create a throttled callback that fires at most once per interval_ms
--- @param fn function The function to throttle
--- @param interval_ms number Minimum interval in milliseconds between calls
--- @return function throttled_fn The throttled function
function M.throttle(fn, interval_ms)
  local last_call = 0
  local interval_seconds = interval_ms / 1000.0

  return function(...)
    local current_time = reaper.time_precise()
    local elapsed = current_time - last_call

    if elapsed >= interval_seconds then
      last_call = current_time
      fn(...)
    end
  end
end

--- Wrap a callback to ensure it's only called once
--- @param fn function The function to wrap
--- @return function once_fn Function that only executes once
function M.once(fn)
  local called = false

  return function(...)
    if not called then
      called = true
      return fn(...)
    end
  end
end

--- Create a callback that retries on failure
--- @param fn function The function to retry
--- @param max_attempts? number Maximum retry attempts (default: 3)
--- @param delay_ms? number Delay between retries in ms (default: 100)
--- @return function retry_fn The retrying function
function M.retry(fn, max_attempts, delay_ms)
  max_attempts = max_attempts or 3
  delay_ms = delay_ms or 100

  return function(...)
    local args = {...}
    local attempt = 1

    while attempt <= max_attempts do
      local ok, result = pcall(fn, table.unpack(args))
      if ok then
        return result
      end

      attempt = attempt + 1
      if attempt <= max_attempts then
        -- Simple delay using busy wait (not ideal but works)
        local start = reaper.time_precise()
        while (reaper.time_precise() - start) < (delay_ms / 1000.0) do
          -- Wait
        end
      end
    end

    return nil
  end
end

--- Wrap multiple functions into a single callback
--- All functions are called with the same arguments
--- @param ... function Functions to wrap
--- @return function combined_fn The combined function
function M.combine(...)
  local fns = {...}

  return function(...)
    local results = {}
    for i, fn in ipairs(fns) do
      if fn then
        results[i] = M.safe_call(fn, ...)
      end
    end
    return table.unpack(results)
  end
end

return M

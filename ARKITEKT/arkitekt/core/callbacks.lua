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
  local delay_seconds = delay_ms / 1000.0
  local pending_call = nil  -- { time, args }

  return function(...)
    local args = {...}
    local call_time = reaper.time_precise()

    -- Update pending call (overwrites any previous)
    pending_call = { time = call_time, args = args }

    -- Schedule check after delay
    local function check_and_fire()
      if not pending_call then return end
      local elapsed = reaper.time_precise() - pending_call.time
      if elapsed >= delay_seconds then
        -- Enough time has passed since last call, fire it
        local call_args = pending_call.args
        pending_call = nil
        fn(table.unpack(call_args))
      end
      -- If elapsed < delay, another defer was scheduled by a newer call
    end

    -- Wait for delay then check
    local start_time = reaper.time_precise()
    local function wait_then_check()
      if reaper.time_precise() - start_time >= delay_seconds then
        check_and_fire()
      else
        reaper.defer(wait_then_check)
      end
    end
    reaper.defer(wait_then_check)
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

--- Create a callback that retries on failure (async with defer)
--- @param fn function The function to retry
--- @param max_attempts? number Maximum retry attempts (default: 3)
--- @param delay_ms? number Delay between retries in ms (default: 100)
--- @param on_success? function Callback on success with result
--- @param on_failure? function Callback on final failure
function M.retry(fn, max_attempts, delay_ms, on_success, on_failure)
  max_attempts = max_attempts or 3
  delay_ms = delay_ms or 100
  local delay_seconds = delay_ms / 1000.0

  return function(...)
    local args = {...}
    local attempt = 1

    local function try_once()
      local ok, result = pcall(fn, table.unpack(args))
      if ok then
        if on_success then on_success(result) end
        return
      end

      attempt = attempt + 1
      if attempt <= max_attempts then
        -- Schedule next attempt after delay (non-blocking)
        local start_time = reaper.time_precise()
        local function wait_and_retry()
          if reaper.time_precise() - start_time >= delay_seconds then
            try_once()
          else
            reaper.defer(wait_and_retry)
          end
        end
        reaper.defer(wait_and_retry)
      else
        if on_failure then on_failure() end
      end
    end

    try_once()
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

# ARKITEKT Error Handler

Enhanced error handling system with full stack traces and configurable logging.

## Features

- ✅ **Full Stack Traces** - No more REAPER truncation, see complete call stacks
- ✅ **Configurable** - Enable/disable via `arkitekt/defs/app.lua`
- ✅ **Error Statistics** - Track error count and recent errors
- ✅ **Production Ready** - Can be disabled for release builds
- ✅ **Zero Boilerplate** - Auto-initialized in `shell.lua`
- ✅ **Timestamps** - Optional timestamp on each error
- ✅ **Strict Mode** - Optional halt-on-error for debugging

## Configuration

Edit `ARKITEKT/arkitekt/defs/app.lua`:

```lua
M.ERROR_HANDLER = {
    enabled = true,                -- Enable/disable error handler
    log_to_console = true,         -- Print full stack traces to console
    show_in_ui = false,            -- Show error count in status bar (future)
    max_stored_errors = 10,        -- Keep last N errors in memory
    include_timestamp = true,      -- Add timestamp to error logs
    halt_on_error = false,         -- Stop execution on error (strict debugging)
}
```

## For Development

**Recommended Settings:**
```lua
enabled = true
log_to_console = true
include_timestamp = true
halt_on_error = false  -- Let app continue after errors
```

## For Production/Release

**Recommended Settings:**
```lua
enabled = false  -- Disable for end users
```

Or keep it enabled with minimal logging:
```lua
enabled = true
log_to_console = false  -- Don't spam console
show_in_ui = true       -- Show error indicator only
```

## Error Output Format

```
═══════════════════════════════════════════════════════════════
TIME: 2025-11-24 10:30:45
ERROR #1
MESSAGE: attempt to call a nil value (method 'select')

STACK TRACE:
stack traceback:
	...pool_grid_factory.lua:271: in function <...pool_grid_factory.lua:267>
	...coordinator_render.lua:300: in method 'draw'
	...shell.lua:294: in upvalue 'on_frame'
	...shell.lua:341: in function <...shell.lua:335>
	[C]: in function 'xpcall'
	...shell.lua:28: in function <...shell.lua:27>
═══════════════════════════════════════════════════════════════
```

## API Usage (Advanced)

```lua
local ErrorHandler = require('arkitekt.debug.error_handler')

-- Get error statistics
local count = ErrorHandler.get_error_count()
local last = ErrorHandler.get_last_error()
local recent = ErrorHandler.get_recent_errors()

-- Clear error history
ErrorHandler.clear_errors()

-- UI integration (status bar)
local status = ErrorHandler.get_status_text()  -- "⚠ 5 errors"
local summary = ErrorHandler.get_error_summary()  -- Multi-line summary
```

## How It Works

1. **Initialization**: `ErrorHandler.init()` is called in `shell.lua` startup
2. **defer Wrapping**: Original `reaper.defer` is wrapped with `xpcall`
3. **Error Capture**: All errors in defer loop are caught by xpcall
4. **Error Handler**: Custom error handler logs and stores errors
5. **Graceful Continuation**: App continues running (unless `halt_on_error = true`)

## Benefits

### Before (REAPER Default)
```
...window.lua:750: ImGui_End: Must call EndChild() and not End()!
```
❌ Truncated path
❌ No stack trace
❌ Hard to debug

### After (Error Handler)
```
═══════════════════════════════════════════════════════════════
TIME: 2025-11-24 10:30:45
ERROR #1
MESSAGE: attempt to call a nil value (method 'select')

STACK TRACE:
stack traceback:
	.../RegionPlaylist/ui/tiles/pool_grid_factory.lua:271: in function
	.../RegionPlaylist/ui/tiles/coordinator_render.lua:300: in method
	.../arkitekt/app/runtime/shell.lua:294: in upvalue
	[full trace with exact line numbers...]
═══════════════════════════════════════════════════════════════
```
✅ Full paths
✅ Complete stack trace
✅ Easy to debug
✅ Timestamps
✅ Error numbering

## Credit

Original xpcall technique from **BenTalagan**

# ARKITEKT Error Handler

Simple xpcall wrapper for full stack traces in REAPER Console.

## What It Does

Wraps `reaper.defer` with `xpcall` so errors print **full stack traces** to the REAPER Console instead of truncated messages.

## Why?

**Before (REAPER Default):**
```
...window.lua:750: ImGui_End: Must call EndChild() and not End()!
```
❌ Truncated path
❌ No stack trace
❌ Hard to debug

**After (Error Handler):**
```
═══════════════════════════════════════════════════════════════
TIME: 2025-11-24 10:30:45
ERROR: attempt to call a nil value (method 'select')

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

## Configuration

Edit `ARKITEKT/arkitekt/defs/app.lua`:

```lua
M.ERROR_HANDLER = {
    enabled = true,                -- Enable/disable error handler
    log_to_console = true,         -- Print to REAPER Console
    include_timestamp = true,      -- Add timestamp to errors
}
```

### For Development
```lua
enabled = true
log_to_console = true
include_timestamp = true
```

### For Production/Release
```lua
enabled = false  -- Disable for end users
```

## How It Works

1. `ErrorHandler.init()` called in `shell.lua` at startup
2. Original `reaper.defer` is wrapped with `xpcall`
3. All errors in defer loop are caught
4. Full stack trace printed to REAPER Console
5. App continues (or crashes, depending on error severity)

## Note

This handler logs to **REAPER Console only**. Since most errors crash the app, there's no point in UI integration or error statistics - console output is what matters.

## Credit

Original xpcall technique from **BenTalagan**

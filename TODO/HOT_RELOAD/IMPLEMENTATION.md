# Hot Reload Implementation Checklist

## Phase 1: Core Reload (MVP)

### arkitekt/debug/reload.lua
- [ ] Create module file
- [ ] `M.reload(patterns)` - clear matching package.loaded entries
- [ ] `M.default_patterns(app_name)` - generate standard patterns
- [ ] Return count of cleared modules

### Shell Integration
- [ ] Add `dev_mode` option to Shell.run()
- [ ] Detect Ctrl+Shift+R in frame loop
- [ ] Call reload with app-specific patterns
- [ ] Add `[DEV]` badge to titlebar when dev_mode=true

### Toast Notification
- [ ] Implement toast state (message, start_time, duration)
- [ ] `show_dev_toast(ctx, message)`
- [ ] `draw_dev_toast(ctx)` - foreground overlay with fade
- [ ] Position at top center of window

## Phase 2: Polish

### Customization
- [ ] `dev.reload_shortcut` option (parse string like 'Ctrl+Shift+R')
- [ ] `dev.reload_patterns` option (override defaults)
- [ ] `dev.show_badge` option (default true)
- [ ] `opts.on_reload` callback for app reinitialization

### Visual Feedback
- [ ] Sound on reload? (optional, might be annoying)
- [ ] Brief screen flash? (optional)
- [ ] Console log of reloaded modules

## Phase 3: Advanced (Future)

### File Watching
- [ ] Poll-based file change detection
- [ ] Track file sizes as signature
- [ ] Configurable check interval (frames)
- [ ] Auto-reload option

### DevTools Panel
- [ ] List watched modules
- [ ] Manual reload button per module
- [ ] Show last reload time
- [ ] Module dependency graph?

## Testing Checklist

- [ ] Reload preserves scroll position
- [ ] Reload preserves selection state
- [ ] Reload preserves input field content
- [ ] Multiple rapid reloads don't crash
- [ ] Circular dependencies handled
- [ ] Missing module after reload shows error (not crash)
- [ ] Dev badge appears in titlebar
- [ ] Toast displays and fades
- [ ] Shortcut doesn't conflict with REAPER shortcuts

## Files to Create/Modify

| File | Action |
|------|--------|
| `arkitekt/debug/reload.lua` | Create |
| `arkitekt/runtime/shell.lua` | Modify (add dev_mode handling) |
| `cookbook/DEV_MODE.md` | Create (user documentation) |

## Estimated Effort

| Task | Time |
|------|------|
| reload.lua | 30 min |
| Shell integration | 1 hour |
| Toast system | 30 min |
| Testing | 1 hour |
| Documentation | 30 min |
| **Total** | **3.5 hours** |

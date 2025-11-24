# Contributing to ARKITEKT

## Current Status: Active Development

⚠️ **ARKITEKT is in active refactoring.** APIs are unstable, breaking changes are frequent.

We're looking for contributors to help **build the framework**, not use it yet.

## What We Need

- Widget development and bug fixes
- API standardization
- Pattern refinement
- Testing and bug hunting
- Documentation

## How to Contribute

1. Open an issue or discussion for major changes
2. Follow the patterns below
3. Test thoroughly in REAPER
4. Submit PR with clear description
5. All changes require review

## Core Patterns

### Widget API
All widgets use opts-based API:
```lua
Widget.draw(ctx, {
  id = "##widget",
  x = 100, y = 100,
  width = 200, height = 30,
})
```

No positional arguments beyond `ctx` and opts.

### State Management
Use **strong tables** for animated widgets:
```lua
local instances = {}  -- NOT weak tables
```

### ImGui Stack Safety
Always balance Begin/End calls:
```lua
local success = container:begin_draw(ctx)

if success then
  -- drawing code
end

container:end_draw(ctx)  -- ALWAYS call, even if begin_draw failed
```

### Code Style
- 2-space indentation
- `snake_case` for variables/functions
- `PascalCase` for module tables
- Comment *why*, not *what*
- No emojis in code

## License

GPL v3. By contributing, you agree your contributions will be licensed accordingly.

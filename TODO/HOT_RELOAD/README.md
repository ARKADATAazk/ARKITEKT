# Hot Reload Feature

Development-time module reloading for faster iteration.

## Status: Planning

## Overview

Enable reloading UI modules without restarting the entire script. Preserves state, reloads code.

## Constraints

| Challenge | Reality |
|-----------|---------|
| No fs.watch() | Must poll file changes |
| require() caches | Must clear package.loaded |
| Closures capture old code | Only UI layer is safely reloadable |
| State in modules | Must externalize to survive reload |

## Scope

**In Scope:**
- UI module reloading (views, components, widgets)
- Manual trigger via keyboard shortcut
- Visual feedback (toast notification)
- Dev mode indicator in titlebar

**Out of Scope:**
- Domain/core module reloading (too risky)
- True hot reload (React-style component state preservation)
- Automatic file watching (too complex for v1)

## Files

- [DESIGN.md](./DESIGN.md) - Technical design and API
- [IMPLEMENTATION.md](./IMPLEMENTATION.md) - Implementation checklist

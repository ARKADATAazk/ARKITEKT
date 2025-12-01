# ARKITEKT Documentation Index

> Central navigation for all ARKITEKT documentation.

---

## Quick Start

| I want to... | Go to... |
|--------------|----------|
| Get started with ARKITEKT | [README.md](../README.md) |
| Understand as an AI assistant | [CLAUDE.md](../CLAUDE.md) |
| Learn coding conventions | [cookbook/CONVENTIONS.md](../cookbook/CONVENTIONS.md) |
| Build a widget | [cookbook/WIDGETS.md](../cookbook/WIDGETS.md) |
| Choose Panel vs Grid | [docs/reference/WIDGET_SELECTION.md](reference/WIDGET_SELECTION.md) |
| Debug performance issues | [docs/guides/DEBUGGING.md](guides/DEBUGGING.md) |

---

## Documentation Structure

```
ARKITEKT-Toolkit/
├── CLAUDE.md                    # AI assistant guide (start here)
├── README.md                    # Project overview
├── CONTRIBUTING.md              # Contribution guidelines
├── CHANGELOG.md                 # Version history
│
├── docs/                        # User documentation
│   ├── INDEX.md                 # This file
│   ├── guides/                  # How-to guides
│   │   └── DEBUGGING.md         # Profiling & troubleshooting
│   └── reference/               # Reference documentation
│       └── WIDGET_SELECTION.md  # Panel vs Grid vs TileGroup
│
├── cookbook/                    # Developer guides
│   ├── CONVENTIONS.md           # Coding standards
│   ├── PROJECT_STRUCTURE.md     # Architecture guide
│   ├── WIDGETS.md               # Widget development
│   ├── THEME_MANAGER.md         # Theming system
│   ├── LUA_PERFORMANCE_GUIDE.md # Performance optimization
│   ├── MIGRATION_PLANS.md       # Migration roadmaps
│   └── DEPRECATED.md            # Deprecation tracker
│
└── TODO/                        # Actionable tasks
    ├── README.md                # Task overview
    └── PERFORMANCE.md           # Performance TODOs
```

---

## By Topic

### Getting Started

- [README.md](../README.md) - Project overview, installation
- [CLAUDE.md](../CLAUDE.md) - Quick reference for AI assistants
- [CONTRIBUTING.md](../CONTRIBUTING.md) - How to contribute

### Architecture

- [cookbook/PROJECT_STRUCTURE.md](../cookbook/PROJECT_STRUCTURE.md) - Clean architecture layers
- [cookbook/CONVENTIONS.md](../cookbook/CONVENTIONS.md) - Naming, modules, patterns
- [ARKITEKT/docs/NAMESPACE.md](../ARKITEKT/docs/NAMESPACE.md) - Namespace conventions

### Widgets & UI

- [cookbook/WIDGETS.md](../cookbook/WIDGETS.md) - Widget development guide
- [docs/reference/WIDGET_SELECTION.md](reference/WIDGET_SELECTION.md) - Panel vs Grid vs TileGroup
- [docs/widgets/grid/README.md](widgets/grid/README.md) - Grid widget guide (API, performance, examples)

### Theming

- [cookbook/THEME_MANAGER.md](../cookbook/THEME_MANAGER.md) - Dynamic theming system
- [ARKITEKT/docs/DYNAMIC_THEMING_STATUS.md](../ARKITEKT/docs/DYNAMIC_THEMING_STATUS.md) - Theme implementation status

### Performance & Debugging

- [docs/guides/DEBUGGING.md](guides/DEBUGGING.md) - Profiling, common issues, solutions
- [cookbook/LUA_PERFORMANCE_GUIDE.md](../cookbook/LUA_PERFORMANCE_GUIDE.md) - Optimization patterns
- [TODO/PERFORMANCE.md](../TODO/PERFORMANCE.md) - Performance improvement tasks

### Migration & Deprecation

- [cookbook/MIGRATION_PLANS.md](../cookbook/MIGRATION_PLANS.md) - Per-script migration roadmaps
- [cookbook/DEPRECATED.md](../cookbook/DEPRECATED.md) - Deprecation tracker
- [ARKITEKT/arkitekt/app/DEPRECATION_TRACKER.md](../ARKITEKT/arkitekt/app/DEPRECATION_TRACKER.md) - App layer deprecations

### API Documentation

- [ARKITEKT/docs/API_DOCUMENTATION_GUIDE.md](../ARKITEKT/docs/API_DOCUMENTATION_GUIDE.md) - API docs patterns
- [ARKITEKT/docs/LUALS_ANNOTATIONS_GUIDE.md](../ARKITEKT/docs/LUALS_ANNOTATIONS_GUIDE.md) - Type annotations
- [ARKITEKT/arkitekt/app/SHELL_API.md](../ARKITEKT/arkitekt/app/SHELL_API.md) - Shell API reference

---

## By Role

### For New Contributors

1. [README.md](../README.md) - Understand the project
2. [cookbook/PROJECT_STRUCTURE.md](../cookbook/PROJECT_STRUCTURE.md) - Learn the architecture
3. [cookbook/CONVENTIONS.md](../cookbook/CONVENTIONS.md) - Follow coding standards
4. [CONTRIBUTING.md](../CONTRIBUTING.md) - Contribution process

### For Widget Developers

1. [cookbook/WIDGETS.md](../cookbook/WIDGETS.md) - Widget patterns
2. [docs/reference/WIDGET_SELECTION.md](reference/WIDGET_SELECTION.md) - Choose the right container
3. [cookbook/THEME_MANAGER.md](../cookbook/THEME_MANAGER.md) - Theme-reactive widgets

### For Performance Work

1. [docs/guides/DEBUGGING.md](guides/DEBUGGING.md) - Profiling techniques
2. [cookbook/LUA_PERFORMANCE_GUIDE.md](../cookbook/LUA_PERFORMANCE_GUIDE.md) - Optimization patterns
3. [TODO/PERFORMANCE.md](../TODO/PERFORMANCE.md) - Known performance tasks

### For AI Assistants

1. [CLAUDE.md](../CLAUDE.md) - Primary reference (start here)
2. [cookbook/CONVENTIONS.md](../cookbook/CONVENTIONS.md) - Coding standards
3. [docs/reference/WIDGET_SELECTION.md](reference/WIDGET_SELECTION.md) - Widget decisions

---

## Component-Specific Documentation

| Component | Location | Description |
|-----------|----------|-------------|
| Grid system | [docs/widgets/grid/README.md](widgets/grid/README.md) | Tile grid with selection, drag-drop |
| MediaGrid | [media_grid/README.md](../ARKITEKT/arkitekt/gui/widgets/media/media_grid/README.md) | Media browser grid |
| Overlay system | [overlay/README.md](../ARKITEKT/arkitekt/gui/widgets/overlays/overlay/README.md) | Modal overlays |
| App framework | [app/README.md](../ARKITEKT/arkitekt/app/README.md) | Application bootstrap |
| Theme manager | [theme_manager/README.md](../ARKITEKT/arkitekt/core/theme_manager/README.md) | Theming system |
| Style system | [style/README.md](../ARKITEKT/arkitekt/gui/style/README.md) | Widget styling |

---

## Scripts Documentation

| Script | Documentation |
|--------|---------------|
| TemplateBrowser | [README.md](../ARKITEKT/scripts/TemplateBrowser/README.md) |
| RegionPlaylist | [REFACTORING.md](../ARKITEKT/scripts/RegionPlaylist/REFACTORING.md) |
| ThemeAdjuster | [INTEGRATION_STATUS.md](../ARKITEKT/scripts/ThemeAdjuster/INTEGRATION_STATUS.md) |
| Sandbox | [IMPLEMENTATION_GUIDE.md](../ARKITEKT/scripts/Sandbox/IMPLEMENTATION_GUIDE.md) |

---

## External Resources

- [ReaImGui Documentation](https://github.com/cfillion/reaimgui) - ImGui for REAPER
- [Lua 5.3 Reference Manual](https://www.lua.org/manual/5.3/) - Lua language reference
- [Lua Performance Tips](https://www.lua.org/gems/sample.pdf) - Roberto Ierusalimschy

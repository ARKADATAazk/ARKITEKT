# File Organization Improvement: Reference Materials

## Problem

**Current state:**
```
helpers/
├── ReaImGui_Demo.lua    # Official ImGui demo/patterns
└── imgui_defs.lua       # LuaCATS type definitions
```

**Issues:**
- ❌ "helpers" is vague - helpers for what?
- ❌ Not clear these are **external reference materials**
- ❌ Not mentioned in CLAUDE.md - poor discoverability
- ❌ Mixed with actual helper scripts (if we had any)

## Proposed Reorganization

**Move to: `/reference/imgui/`**

```
reference/
└── imgui/
    ├── ReaImGui_Demo.lua       # Official demo (read-only reference)
    ├── imgui_defs.lua          # Type definitions (read-only reference)
    └── README.md               # What these files are for
```

**Why "reference"?**
- ✅ Clear purpose: "reference material to consult"
- ✅ Parallel to `cookbook/` (guides) and `docs/` (project docs)
- ✅ Common convention in many projects
- ✅ Scope to `/imgui/` allows for other references later

**Alternative considered:**
- `/external/reaimgui/` - Also good, emphasizes external
- `/docs/imgui/` - Could work but might confuse with ARKITEKT docs
- `/vendor/` - Usually for bundled dependencies, not references

## Updated Structure

```
ARKITEKT-Toolkit/
├── ARKITEKT/              # Framework code
├── cookbook/              # Developer guides (how to build with ARKITEKT)
├── docs/                  # Project documentation
├── reference/             # ← NEW: External reference materials
│   └── imgui/
│       ├── README.md
│       ├── ReaImGui_Demo.lua
│       └── imgui_defs.lua
├── scripts/               # Example applications
├── TODO/                  # Planning documents
└── CLAUDE.md             # AI assistant guide
```

## README.md for reference/imgui/

```markdown
# ReaImGui Reference Materials

This directory contains **reference materials** from the ReaImGui project to help understand ImGui API patterns and conventions.

## Files

### ReaImGui_Demo.lua
Official ImGui demo ported to Lua/ReaImGui. Shows all ImGui widgets, patterns, and usage examples.

**Source**: ReaImGui official repository
**Purpose**: Learn ImGui patterns before implementing in ARKITEKT
**Usage**: Read for examples of Begin/End patterns, widget usage, etc.

**Key sections:**
- [SECTION] Helpers - Helper functions and utilities
- [SECTION] DemoWindowMenuBar() - Menu bar patterns
- [SECTION] DemoWindowWidgets() - All widget examples
- [SECTION] DemoWindowPopups() - Popup patterns
- [SECTION] DemoWindowTables() - Table API usage

### imgui_defs.lua
LuaCATS type definitions for ReaImGui API. Provides autocomplete and type checking in LSP-enabled editors.

**Source**: ReaImGui official repository
**Purpose**: IDE autocomplete for ImGui functions
**Usage**: Not imported by ARKITEKT code, used by LSP only

## When to Consult

**When implementing widgets:**
1. Check ReaImGui_Demo.lua for equivalent ImGui widget
2. See how ImGui does it (Begin/End pattern, return values, etc.)
3. Decide whether to match or improve (see cookbook/API_DESIGN_PHILOSOPHY.md)

**When porting ImGui code:**
- Use Demo as reference for correct API usage
- Compare with ARKITEKT equivalents

## Related Documents

- [API Design Philosophy](../../cookbook/API_DESIGN_PHILOSOPHY.md) - When to match vs improve
- [ImGui API Coverage](../../TODO/IMGUI_API_COVERAGE.md) - What's implemented
- [Migration Script](../../TODO/Later/MIGRATION_SCRIPT.md) - Automated porting
```

## Updates to CLAUDE.md

Add new section after "Documentation Hierarchy":

```markdown
## Reference Materials

### ImGui API Reference

**Location**: `reference/imgui/`

When implementing widgets or understanding ImGui patterns:

1. **ReaImGui_Demo.lua** - Official ImGui demo
   - Shows all ImGui widgets and patterns
   - Search for specific widgets (e.g., "BeginMenu", "BeginTable")
   - See how Begin/End pairs work
   - Example of real-world ImGui code

2. **imgui_defs.lua** - Type definitions
   - LuaCATS definitions for autocomplete
   - Reference for exact function signatures
   - Lists all ImGui constants/flags

**Usage:**
```lua
-- Want to implement a menu? Check the demo:
grep -A 20 "BeginMenu" reference/imgui/ReaImGui_Demo.lua

-- Want to see table API? Search:
grep -A 50 "BeginTable" reference/imgui/ReaImGui_Demo.lua
```

**Remember:** These show **ImGui patterns**. Consult `cookbook/API_DESIGN_PHILOSOPHY.md` to decide whether to match exactly or improve for ARKITEKT.
```

## Migration Steps

1. Create `/reference/imgui/` directory
2. Move files:
   ```bash
   mkdir -p reference/imgui
   mv helpers/ReaImGui_Demo.lua reference/imgui/
   mv helpers/imgui_defs.lua reference/imgui/
   ```
3. Create `reference/imgui/README.md` (content above)
4. Update CLAUDE.md with new section
5. Update any references in other docs
6. Remove empty `helpers/` directory
7. Update `.gitignore` if needed

## Benefits

- ✅ Clear purpose: "reference material"
- ✅ Easy to discover (referenced in CLAUDE.md)
- ✅ Logical grouping (all ImGui references together)
- ✅ Room to grow (add other references later)
- ✅ Parallel structure (cookbook/ for guides, reference/ for external)

## Impact

**Breaking changes:** None (internal reorganization only)
**Files to update:** CLAUDE.md, maybe some grep/search commands in docs
**User impact:** Better discoverability, clearer purpose

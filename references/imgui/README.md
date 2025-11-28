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

### imgui_defs_min.lua
Minified version of imgui_defs.lua for faster loading.

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

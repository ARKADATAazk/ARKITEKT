# LuaLS Type Annotations Guide for ARKITEKT

A comprehensive guide to adding Lua Language Server (LuaLS) annotations to the ARKITEKT codebase for improved IDE support, autocomplete, and type checking.

---

## Table of Contents

1. [What is LuaLS?](#what-is-luals)
2. [Why Add Annotations?](#why-add-annotations)
3. [Basic Annotation Syntax](#basic-annotation-syntax)
4. [Common Annotation Types](#common-annotation-types)
5. [ARKITEKT-Specific Patterns](#arkitekt-specific-patterns)
6. [File-by-File Guide](#file-by-file-guide)
7. [IDE Setup](#ide-setup)
8. [Best Practices](#best-practices)
9. [Common Pitfalls](#common-pitfalls)

---

## What is LuaLS?

**LuaLS** (Lua Language Server) is a language server that provides IDE features for Lua:

- **Autocomplete**: Suggests fields, functions, and variables as you type
- **Hover Documentation**: Shows function signatures and descriptions on hover
- **Type Checking**: Warns about type mismatches before runtime
- **Go-to-Definition**: Jump to where a function/class is defined
- **Find References**: Find all usages of a symbol
- **Rename Symbol**: Safely rename variables across files

LuaLS reads special comments (annotations) in your code to understand types.

---

## Why Add Annotations?

### Before Annotations

```lua
-- User types: Ark.Button(ctx, {
-- IDE shows: Nothing helpful, just generic "table"

function M.Draw(ctx, opts)
  -- opts.??? - IDE has no idea what fields exist
end
```

### After Annotations

```lua
-- User types: Ark.Button(ctx, {
-- IDE shows dropdown with all valid options:
--   label, icon, width, height, on_click, disabled, preset_name...

-- Typing opts.widht shows error: "Unknown field 'widht', did you mean 'width'?"
```

### Benefits Summary

| Benefit | Description |
|---------|-------------|
| **Faster Development** | Autocomplete means less typing and fewer doc lookups |
| **Fewer Bugs** | Type errors caught before running code |
| **Self-Documenting** | Types serve as always-up-to-date documentation |
| **Refactoring Safety** | IDE can find all usages when renaming |
| **Onboarding** | New developers understand APIs instantly |

---

## Basic Annotation Syntax

All LuaLS annotations are **comments** starting with `---@`:

```lua
---@annotation_name parameters
```

They go **directly above** the thing they describe (no blank lines between).

### Simple Examples

```lua
-- Variable type
---@type number
local count = 0

-- Function parameter and return
---@param name string The user's name
---@param age number The user's age
---@return string greeting The formatted greeting
function greet(name, age)
  return string.format("Hello %s, you are %d", name, age)
end

-- Class definition
---@class Person
---@field name string
---@field age number
local Person = {}
```

---

## Common Annotation Types

### @type - Variable Types

```lua
---@type number
local count = 0

---@type string|nil
local maybe_name = nil

---@type table<string, number>
local scores = { alice = 100, bob = 95 }

---@type number[]
local numbers = {1, 2, 3, 4, 5}

---@type fun(x: number): number
local square = function(x) return x * x end
```

### @param - Function Parameters

```lua
---@param ctx userdata ImGui context
---@param width number Widget width in pixels
---@param height number Widget height in pixels
---@param callback fun(result: boolean) Called when complete
function create_widget(ctx, width, height, callback)
end
```

### @return - Return Values

```lua
-- Single return
---@return boolean success

-- Multiple returns
---@return boolean success
---@return string? error_message

-- Named return (for documentation)
---@return number width The calculated width
---@return number height The calculated height
function measure()
  return 100, 50
end
```

### @class - Define Custom Types

```lua
---@class ButtonOptions
---@field label string Button text
---@field width? number Optional width (? = optional)
---@field height? number Optional height
---@field on_click? fun() Optional click callback

---@class ButtonResult
---@field clicked boolean Was button clicked
---@field hovered boolean Is mouse over button
```

### @field - Class Fields

```lua
---@class Config
---@field name string Required field
---@field count? number Optional field (note the ?)
---@field items string[] Array of strings
---@field metadata table<string, any> Dictionary
---@field callback fun(x: number): boolean Function field
```

### @alias - Type Aliases

```lua
---@alias Color integer Color in 0xRRGGBBAA format
---@alias Rect number[] Array of 4 numbers: {x1, y1, x2, y2}
---@alias EventCallback fun(event: string, data: any)

-- Now use the alias
---@param color Color
---@param bounds Rect
function draw_rect(color, bounds)
end
```

### @generic - Generic Types

```lua
---@generic T
---@param array T[]
---@return T first
function first(array)
  return array[1]
end

---@generic K, V
---@param tbl table<K, V>
---@param key K
---@return V?
function safe_get(tbl, key)
  return tbl[key]
end
```

### @overload - Multiple Signatures

```lua
---@overload fun(color: string): integer
---@overload fun(r: number, g: number, b: number): integer
---@param color string|number
---@return integer
function parse_color(color, g, b)
  -- handles both parse_color("#FF0000") and parse_color(255, 0, 0)
end
```

### @deprecated - Mark Old APIs

```lua
---@deprecated Use `new_function` instead
function old_function()
end
```

### @private / @protected

```lua
---@private
function M._internal_helper()
  -- IDE won't suggest this in autocomplete
end

---@protected
function BaseClass:_override_me()
  -- Subclasses can override
end
```

### @async - Async Functions

```lua
---@async
---@param url string
---@return string content
function fetch(url)
  -- coroutine-based async
end
```

---

## ARKITEKT-Specific Patterns

### Color Type

ARKITEKT uses 0xRRGGBBAA format colors throughout:

```lua
-- In a shared types file (e.g., arkitekt/types.lua)
---@alias Color integer Color in 0xRRGGBBAA format (e.g., 0xFF0000FF for red)
```

Usage:
```lua
---@param bg_color Color Background color
---@param text_color Color Text color
function draw_button(bg_color, text_color)
end
```

### Widget Options Pattern

All ARKITEKT widgets follow the `opts` table pattern:

```lua
---@class SliderOptions
---@field id? string Unique identifier
---@field value number Current value
---@field min number Minimum value
---@field max number Maximum value
---@field step? number Step increment (default: 1)
---@field width? number Slider width
---@field on_change? fun(value: number) Called when value changes
---@field disabled? boolean Disable interaction
---@field preset_name? string Style preset name

---@class SliderResult
---@field value number Current value (may have changed)
---@field changed boolean True if value changed this frame
---@field hovered boolean True if mouse is over slider
---@field active boolean True if slider is being dragged

---Draw a slider widget
---@param ctx userdata ImGui context
---@param opts SliderOptions Slider configuration
---@return SliderResult
function M.draw(ctx, opts)
```

### Panel Configuration

Complex nested configurations:

```lua
---@class ToolbarConfig
---@field height? number Toolbar height
---@field bg_color? Color Background color
---@field elements? ToolbarElement[] Toolbar elements

---@class ToolbarElement
---@field type "button"|"search"|"dropdown"|"spacer"|"separator"
---@field config? table Element-specific configuration

---@class PanelConfig
---@field bg_color? Color Panel background
---@field border_color? Color Border color
---@field border_thickness? number Border width (default: 1)
---@field rounding? number Corner radius
---@field padding? number Content padding
---@field header? ToolbarConfig Top toolbar configuration
---@field footer? ToolbarConfig Bottom toolbar configuration
---@field scroll? ScrollConfig Scroll behavior configuration
---@field corner_buttons? CornerButtonsConfig Corner button configuration
```

### Callback Patterns

```lua
---@alias ClickCallback fun()
---@alias ChangeCallback fun(value: any)
---@alias SelectCallback fun(keys: string[])
---@alias ReorderCallback fun(grid: Grid, new_order: string[])

---@class GridBehaviors
---@field on_select? SelectCallback Called when selection changes
---@field on_click? fun(grid: Grid, key: string) Called on item click
---@field double_click? fun(grid: Grid, key: string) Called on double-click
---@field reorder? ReorderCallback Called when items are reordered
---@field delete? fun(grid: Grid, keys: string[]) Called to delete items
```

### ImGui Context

Since ImGui context is a userdata type:

```lua
---@alias ImGuiContext userdata

---@param ctx ImGuiContext
function M.draw(ctx)
end
```

### Rect Type

Used throughout for bounds:

```lua
---@class Rect
---@field [1] number x1 (left)
---@field [2] number y1 (top)
---@field [3] number x2 (right)
---@field [4] number y2 (bottom)

-- Or as alias for simpler usage
---@alias Rect number[] {x1, y1, x2, y2}
```

---

## File-by-File Guide

### Priority 1: Core Types (Create New File)

Create `arkitekt/types.lua` with shared type definitions:

```lua
---@meta
-- This file contains type definitions only, no runtime code

-- =============================================================================
-- PRIMITIVE TYPES
-- =============================================================================

---@alias Color integer Color in 0xRRGGBBAA format

---@alias Rect number[] Array of 4 numbers: {x1, y1, x2, y2}

---@alias ImGuiContext userdata ReaImGui context handle

-- =============================================================================
-- CALLBACK TYPES
-- =============================================================================

---@alias ClickCallback fun()
---@alias ChangeCallback fun(value: any)
---@alias SelectCallback fun(keys: string[])

-- =============================================================================
-- COMMON OPTION PATTERNS
-- =============================================================================

---@class CornerRounding
---@field rounding? number Corner radius
---@field round_top_left? boolean
---@field round_top_right? boolean
---@field round_bottom_left? boolean
---@field round_bottom_right? boolean

---@class BaseWidgetOptions
---@field id? string Unique identifier
---@field x? number X position (nil = cursor)
---@field y? number Y position (nil = cursor)
---@field width? number Widget width
---@field height? number Widget height
---@field disabled? boolean Disable interactions
---@field tooltip? string Hover tooltip text

---@class BaseWidgetResult
---@field hovered boolean Mouse is over widget
---@field active boolean Widget is being interacted with
---@field width number Actual rendered width
---@field height number Actual rendered height
```

### Priority 2: Style Defaults

`arkitekt/gui/style/defaults.lua`:

```lua
---@class StyleColors
---@field BG_BASE Color Standard control background
---@field BG_HOVER Color Hovered control background
---@field BG_ACTIVE Color Active/pressed control background
---@field BG_PANEL Color Panel container background
---@field BG_TRANSPARENT Color Transparent background
---@field BORDER_OUTER Color Black outer border
---@field BORDER_INNER Color Gray inner highlight
---@field BORDER_HOVER Color Lighter border on hover
---@field TEXT_NORMAL Color Standard text
---@field TEXT_HOVER Color Bright text on hover
---@field TEXT_DIMMED Color Dimmed/secondary text
---@field ACCENT_PRIMARY Color Primary accent (blue)
---@field ACCENT_TEAL Color Teal accent
---@field ACCENT_SUCCESS Color Success (green)
---@field ACCENT_WARNING Color Warning (orange)
---@field ACCENT_DANGER Color Danger (red)

---@class StyleModule
---@field COLORS StyleColors Shared primitive colors
---@field PANEL_COLORS table Panel-specific colors
---@field BUTTON_COLORS table Button color variants
---@field BUTTON table Default button preset
---@field BUTTON_TOGGLE_TEAL table Teal toggle button preset
---@field DROPDOWN table Dropdown preset
---@field TOOLTIP table Tooltip preset

---@type StyleModule
local M = {}
```

### Priority 3: Primitive Widgets

Example for `button.lua`:

```lua
---@class ButtonOptions : BaseWidgetOptions
---@field label? string Button text
---@field icon? string Icon character
---@field icon_font? userdata Icon font handle
---@field icon_size? number Icon size (default: 16)
---@field is_toggled? boolean Toggle state
---@field is_blocking? boolean Block input when modal open
---@field rounding? number Corner rounding
---@field padding_x? number Horizontal padding
---@field preset_name? string Style preset ("BUTTON_TOGGLE_TEAL", etc.)
---@field preset? table Custom style preset
---@field bg_color? Color Background color
---@field bg_hover_color? Color Hover background
---@field bg_active_color? Color Active background
---@field bg_on_color? Color Toggle ON background
---@field text_color? Color Text color
---@field on_click? ClickCallback Left-click callback
---@field on_right_click? ClickCallback Right-click callback
---@field corner_rounding? CornerRounding Panel corner integration
---@field advance? "vertical"|"horizontal"|"none" Cursor advance mode

---@class ButtonResult : BaseWidgetResult
---@field clicked boolean Button was left-clicked
---@field right_clicked boolean Button was right-clicked

---@class ButtonModule
local M = {}

---Draw a button widget
---@param ctx ImGuiContext ImGui context
---@param opts ButtonOptions Button configuration
---@return ButtonResult
function M.draw(ctx, opts)
end

---Measure button width based on content
---@param ctx ImGuiContext ImGui context
---@param opts ButtonOptions Button configuration
---@return number width Calculated width in pixels
function M.measure(ctx, opts)
end

---Clean up all button instances
function M.cleanup()
end

return M
```

### Priority 4: Core Utilities

`arkitekt/core/colors.lua`:

```lua
---@class ColorsModule
local M = {}

---Convert hex string to 0xRRGGBBAA color
---@param hex string Hex color ("#RGB", "#RRGGBB", or "#RRGGBBAA")
---@return Color
---
---Examples:
---```lua
---Colors.hex("#F00")      -- 0xFF0000FF (red)
---Colors.hex("#00FF00")   -- 0x00FF00FF (green)
---Colors.hex("#0000FF80") -- 0x0000FF80 (blue, 50% alpha)
---```
function M.hex(hex)
end

---Extract RGBA components from color
---@param color Color Input color
---@return number r Red (0-255)
---@return number g Green (0-255)
---@return number b Blue (0-255)
---@return number a Alpha (0-255)
function M.extract_rgba(color)
end

---Create color from RGBA components
---@param r number Red (0-255)
---@param g number Green (0-255)
---@param b number Blue (0-255)
---@param a number Alpha (0-255)
---@return Color
function M.components_to_rgba(r, g, b, a)
end

---Replace alpha component of a color
---@param color Color Input color
---@param alpha number New alpha (0-255)
---@return Color
function M.with_alpha(color, alpha)
end

---Convert RGB color to HSL
---@param color Color Input color (alpha ignored)
---@return number h Hue (0-1)
---@return number s Saturation (0-1)
---@return number l Lightness (0-1)
function M.rgb_to_hsl(color)
end

---Convert HSL to RGB components
---@param h number Hue (0-1)
---@param s number Saturation (0-1)
---@param l number Lightness (0-1)
---@return number r Red (0-255)
---@return number g Green (0-255)
---@return number b Blue (0-255)
function M.hsl_to_rgb(h, s, l)
end

---Adjust color lightness
---@param color Color Input color
---@param amount number Adjustment (-1 to 1, negative = darker)
---@return Color
function M.adjust_lightness(color, amount)
end

---Adjust color saturation
---@param color Color Input color
---@param amount number Adjustment (-1 to 1, negative = less saturated)
---@return Color
function M.adjust_saturation(color, amount)
end

---Get appropriate text color for background (black or white)
---@param bg_color Color Background color
---@return Color text_color White or black depending on luminance
function M.auto_text_color(bg_color)
end

---Compare two colors for sorting (by hue, then saturation, then lightness)
---@param a Color First color
---@param b Color Second color
---@return boolean a_less_than_b True if a should sort before b
function M.compare_colors(a, b)
end

---Linear interpolation between two colors
---@param a Color Start color
---@param b Color End color
---@param t number Interpolation factor (0-1)
---@return Color
function M.lerp(a, b, t)
end

return M
```

---

## IDE Setup

### VS Code

1. Install the **Lua** extension by sumneko (now called "Lua" by LuaLS)

2. Create `.luarc.json` in project root:

```json
{
  "$schema": "https://raw.githubusercontent.com/sumneko/vscode-lua/master/setting/schema.json",
  "runtime": {
    "version": "Lua 5.4",
    "special": {
      "require": "require"
    }
  },
  "diagnostics": {
    "globals": [
      "reaper",
      "gfx"
    ],
    "disable": [
      "lowercase-global"
    ]
  },
  "workspace": {
    "library": [],
    "checkThirdParty": false
  },
  "hint": {
    "enable": true,
    "setType": true,
    "paramName": "All"
  },
  "completion": {
    "callSnippet": "Replace",
    "keywordSnippet": "Replace"
  }
}
```

3. Optional: Create `.vscode/settings.json`:

```json
{
  "Lua.workspace.ignoreDir": [
    ".git",
    "node_modules"
  ],
  "Lua.diagnostics.workspaceDelay": 3000,
  "Lua.hint.enable": true
}
```

### Neovim (with nvim-lspconfig)

```lua
require('lspconfig').lua_ls.setup {
  settings = {
    Lua = {
      runtime = {
        version = 'Lua 5.4',
      },
      diagnostics = {
        globals = { 'reaper', 'gfx' },
      },
      workspace = {
        checkThirdParty = false,
      },
      telemetry = {
        enable = false,
      },
      hint = {
        enable = true,
      },
    },
  },
}
```

---

## Best Practices

### 1. Document Public APIs First

Focus on functions that users call directly:

```lua
-- HIGH PRIORITY: Public API
---@param ctx ImGuiContext
---@param opts ButtonOptions
---@return ButtonResult
function M.draw(ctx, opts)

-- LOW PRIORITY: Internal helper
local function calculate_size(label, padding)
```

### 2. Use Descriptive Field Comments

```lua
---@class GridOptions
---@field gap number Space between tiles in pixels
---@field min_col_w number Minimum column width before wrapping
---@field fixed_tile_h? number Fixed tile height (nil = auto)
```

Not just:
```lua
---@class GridOptions
---@field gap number
---@field min_col_w number
---@field fixed_tile_h? number
```

### 3. Mark Optional Fields with `?`

```lua
---@class Options
---@field required_field string This is required
---@field optional_field? string This is optional (note the ?)
```

### 4. Use Aliases for Repeated Types

```lua
-- Define once
---@alias Color integer

-- Use everywhere
---@param bg Color
---@param fg Color
---@param border Color
```

### 5. Add Examples in Documentation

```lua
---Convert hex string to color
---@param hex string Hex color string
---@return Color
---
---Examples:
---```lua
---local red = hex("#FF0000")
---local transparent_blue = hex("#0000FF80")
---```
function M.hex(hex)
```

### 6. Use Inheritance for Related Types

```lua
---@class BaseWidgetOptions
---@field id? string
---@field disabled? boolean

---@class ButtonOptions : BaseWidgetOptions
---@field label string
---@field on_click? fun()

---@class CheckboxOptions : BaseWidgetOptions
---@field checked boolean
---@field on_change? fun(checked: boolean)
```

### 7. Document Return Tables Properly

```lua
-- GOOD: Defined result class
---@return ButtonResult
function M.draw(ctx, opts)

-- BAD: Inline anonymous table
---@return {clicked: boolean, hovered: boolean}
function M.draw(ctx, opts)
```

---

## Common Pitfalls

### 1. Blank Lines Break Annotations

```lua
-- WRONG: Blank line breaks the connection
---@param x number

function foo(x) end

-- CORRECT: No blank line
---@param x number
function foo(x) end
```

### 2. Order Matters for @param

```lua
-- WRONG: Parameters in wrong order
---@param b number
---@param a number
function foo(a, b) end

-- CORRECT: Match parameter order
---@param a number
---@param b number
function foo(a, b) end
```

### 3. @field vs @param

```lua
-- @field is for class definitions
---@class Options
---@field name string

-- @param is for function parameters
---@param opts Options
function foo(opts) end
```

### 4. nil vs Optional

```lua
-- Use ? for optional fields
---@field value? number  -- Can be nil or absent

-- Use |nil for nullable but present
---@field value number|nil  -- Must be present, but can be nil
```

### 5. Self Parameter in Methods

```lua
-- For method syntax (obj:method()), self is implicit
---@param value number
function MyClass:set_value(value)  -- self is automatic
end

-- For function syntax (obj.method(self)), include self
---@param self MyClass
---@param value number
function MyClass.set_value(self, value)
end
```

### 6. Circular References

```lua
-- Can cause issues - use forward declaration
---@class Node
---@field children Node[]  -- Works because Node is declared above

-- For mutual references, declare class first
---@class Parent
---@class Child

---@class Parent
---@field child Child

---@class Child
---@field parent Parent
```

---

## Checklist for Adding Annotations

When annotating a file:

- [ ] Add `---@class` for all option/config tables
- [ ] Add `---@class` for all result/return tables
- [ ] Add `---@param` for all public function parameters
- [ ] Add `---@return` for all public function returns
- [ ] Add `---@field` descriptions, not just types
- [ ] Mark optional fields with `?`
- [ ] Add examples for complex functions
- [ ] Use aliases for repeated types (Color, Rect, etc.)
- [ ] Test autocomplete works in your IDE
- [ ] Test hover documentation shows correctly

---

## Resources

- [LuaLS Annotations Documentation](https://luals.github.io/wiki/annotations/)
- [LuaLS GitHub](https://github.com/LuaLS/lua-language-server)
- [VS Code Lua Extension](https://marketplace.visualstudio.com/items?itemName=sumneko.lua)

---

*Last updated: 2025-01-25*

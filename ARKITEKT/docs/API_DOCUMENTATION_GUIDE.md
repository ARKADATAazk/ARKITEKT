# API Documentation Guide for ARKITEKT

A comprehensive guide to creating and maintaining API documentation for the ARKITEKT library.

---

## Table of Contents

1. [Documentation Philosophy](#documentation-philosophy)
2. [Documentation Structure](#documentation-structure)
3. [Widget Documentation Template](#widget-documentation-template)
4. [Core Module Documentation Template](#core-module-documentation-template)
5. [Writing Style Guide](#writing-style-guide)
6. [Examples and Code Snippets](#examples-and-code-snippets)
7. [Visual Documentation](#visual-documentation)
8. [Maintenance Guidelines](#maintenance-guidelines)
9. [Tools and Automation](#tools-and-automation)

---

## Documentation Philosophy

### Core Principles

1. **Examples First**: Show working code before explaining theory
2. **Progressive Disclosure**: Simple use cases first, advanced options later
3. **Copy-Paste Ready**: All examples should work when pasted
4. **Up-to-Date**: Documentation updated with every API change
5. **Searchable**: Clear headings and consistent terminology

### Target Audiences

| Audience | Needs | Priority |
|----------|-------|----------|
| **New Users** | Quick start, basic examples | HIGH |
| **Regular Users** | Parameter reference, common patterns | HIGH |
| **Advanced Users** | Edge cases, customization, internals | MEDIUM |
| **Contributors** | Architecture, conventions, testing | LOW |

---

## Documentation Structure

### Recommended Directory Layout

```
ARKITEKT/docs/
├── index.md                      # Library overview and quick start
├── getting-started.md            # First script in 5 minutes
├── LUALS_ANNOTATIONS_GUIDE.md    # Type annotation guide
├── API_DOCUMENTATION_GUIDE.md    # This file
│
├── api/                          # API Reference
│   ├── index.md                  # API overview
│   │
│   ├── widgets/                  # Widget documentation
│   │   ├── index.md              # Widgets overview
│   │   ├── button.md
│   │   ├── checkbox.md
│   │   ├── combo.md
│   │   ├── slider.md
│   │   ├── spinner.md
│   │   ├── inputtext.md
│   │   └── ...
│   │
│   ├── containers/               # Container documentation
│   │   ├── index.md
│   │   ├── panel.md
│   │   ├── grid.md
│   │   └── tile-group.md
│   │
│   ├── style/                    # Style system
│   │   ├── index.md
│   │   ├── colors.md
│   │   ├── presets.md
│   │   └── theming.md
│   │
│   └── core/                     # Core modules
│       ├── index.md
│       ├── bootstrap.md
│       ├── shell.md
│       ├── settings.md
│       └── colors.md
│
├── guides/                       # How-to guides
│   ├── creating-widgets.md
│   ├── custom-theming.md
│   ├── state-management.md
│   ├── drag-and-drop.md
│   └── building-apps.md
│
└── examples/                     # Complete examples
    ├── simple-window.md
    ├── todo-app.md
    └── media-browser.md
```

---

## Widget Documentation Template

Use this template for all widget documentation:

```markdown
# Widget Name

Brief one-sentence description of what this widget does.

---

## Quick Start

\`\`\`lua
local Ark = require('arkitekt')

-- Minimal working example
local result = Ark.WidgetName(ctx, {
    required_param = 'value',
})
\`\`\`

---

## Usage Examples

### Basic Usage

\`\`\`lua
-- Most common use case
Ark.WidgetName(ctx, {
    label = 'Example',
    on_click = function()
        print('Clicked!')
    end,
})
\`\`\`

### With Styling

\`\`\`lua
-- Using a preset
Ark.WidgetName(ctx, {
    label = 'Styled',
    preset_name = 'WIDGET_PRESET_NAME',
})

-- With custom colors
Ark.WidgetName(ctx, {
    label = 'Custom',
    bg_color = 0xFF0000FF,  -- Red background
    text_color = 0xFFFFFFFF,  -- White text
})
\`\`\`

### Advanced Usage

\`\`\`lua
-- All options example
local result = Ark.WidgetName(ctx, {
    id = 'unique_id',
    label = 'Full Example',
    icon = '\u{F00C}',  -- Remix icon
    width = 120,
    height = 32,
    disabled = state.is_loading,
    preset_name = 'WIDGET_TOGGLE_TEAL',
    on_click = function() handle_click() end,
    on_right_click = function() show_context_menu() end,
    tooltip = 'Click to perform action',
})

if result.clicked then
    -- Handle click
end
\`\`\`

---

## Parameters

### Required Parameters

| Name | Type | Description |
|------|------|-------------|
| `required_param` | `type` | Description of what this does |

### Optional Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `id` | `string` | auto | Unique identifier |
| `label` | `string` | `""` | Display text |
| `icon` | `string` | `""` | Icon character |
| `width` | `number` | auto | Width in pixels |
| `height` | `number` | `24` | Height in pixels |
| `disabled` | `boolean` | `false` | Disable interaction |
| `preset_name` | `string` | `nil` | Style preset name |
| `tooltip` | `string` | `nil` | Hover tooltip |

### Style Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `bg_color` | `Color` | theme | Background color |
| `bg_hover_color` | `Color` | theme | Hover background |
| `text_color` | `Color` | theme | Text color |
| `border_color` | `Color` | theme | Border color |
| `rounding` | `number` | `0` | Corner radius |
| `padding_x` | `number` | `10` | Horizontal padding |

### Callback Parameters

| Name | Type | Description |
|------|------|-------------|
| `on_click` | `function()` | Called on left-click |
| `on_right_click` | `function()` | Called on right-click |
| `on_change` | `function(value)` | Called when value changes |

---

## Return Value

Returns a table with the following fields:

| Field | Type | Description |
|-------|------|-------------|
| `clicked` | `boolean` | `true` if clicked this frame |
| `right_clicked` | `boolean` | `true` if right-clicked |
| `hovered` | `boolean` | `true` if mouse is over |
| `active` | `boolean` | `true` if being pressed |
| `width` | `number` | Actual rendered width |
| `height` | `number` | Actual rendered height |

---

## Style Presets

Available presets for this widget:

| Preset Name | Description |
|-------------|-------------|
| `WIDGET_DEFAULT` | Standard appearance |
| `WIDGET_ACCENT` | Accent-colored variant |
| `WIDGET_DANGER` | Red/danger variant |

### Creating Custom Presets

\`\`\`lua
local my_preset = {
    bg_color = 0x2A2A2AFF,
    bg_hover_color = 0x3A3A3AFF,
    text_color = 0xFFFFFFFF,
    rounding = 4,
}

Ark.WidgetName(ctx, {
    label = "Custom",
    preset = my_preset,
})
\`\`\`

---

## Related

- [OtherWidget](other-widget.md) - Similar widget for different use case
- [Theming Guide](../guides/theming.md) - How to customize appearance
- [Style Reference](../style/index.md) - All available style options

---

## Changelog

- **v1.2.0**: Added `preset_name` parameter
- **v1.1.0**: Added `on_right_click` callback
- **v1.0.0**: Initial release
```

---

## Core Module Documentation Template

For utility/core modules:

```markdown
# Module Name

Brief description of what this module provides.

---

## Import

\`\`\`lua
local ModuleName = require('arkitekt.core.module_name')
-- or via namespace
local Ark = require('arkitekt')
local result = Ark.ModuleName.function_name()
\`\`\`

---

## Quick Reference

| Function | Description |
|----------|-------------|
| `function_a(x)` | Does X |
| `function_b(a, b)` | Does Y |
| `function_c(opts)` | Does Z |

---

## Functions

### function_a

Brief description.

\`\`\`lua
-- Signature
result = ModuleName.function_a(param)
\`\`\`

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `param` | `type` | Description |

**Returns:** `type` - Description

**Example:**

\`\`\`lua
local result = ModuleName.function_a("input")
print(result)  -- Output: expected_output
\`\`\`

---

### function_b

Brief description.

\`\`\`lua
-- Signature
result_a, result_b = ModuleName.function_b(param_a, param_b)
\`\`\`

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `param_a` | `type` | Description |
| `param_b` | `type` | Description |

**Returns:**
- `type` - Description of first return value
- `type` - Description of second return value

**Example:**

\`\`\`lua
local x, y = ModuleName.function_b(10, 20)
print(x, y)  -- Output: 30, 200
\`\`\`

---

## Constants

| Name | Value | Description |
|------|-------|-------------|
| `CONSTANT_A` | `100` | Description |
| `CONSTANT_B` | `"value"` | Description |

---

## Types

### TypeName

\`\`\`lua
---@class TypeName
---@field field_a string Description
---@field field_b number Description
---@field field_c? boolean Optional field
\`\`\`

---

## See Also

- [Related Module](related.md)
- [Guide: Using This Module](../guides/using-module.md)
```

---

## Writing Style Guide

### Language and Tone

- **Active voice**: "The function returns..." not "It is returned by..."
- **Present tense**: "This creates..." not "This will create..."
- **Second person**: "You can use..." not "One can use..."
- **Concise**: Avoid unnecessary words

### Terminology Consistency

Use these terms consistently:

| Use | Don't Use |
|-----|-----------|
| widget | component, control, element |
| opts/options | params, config, settings |
| callback | handler, listener, hook |
| color | colour |
| draw | render (for the main function) |
| ctx | context |

### Code Style in Examples

```lua
-- Use 2-space indentation
local Ark = require('arkitekt')

-- Show complete, runnable examples
Ark.Button(ctx, {
  label = "Click Me",
  on_click = function()
    print("Clicked!")
  end,
})

-- Add comments for non-obvious things
local color = 0xFF0000FF  -- Red (0xRRGGBBAA format)

-- Show expected output in comments
print(result)  -- Output: 42
```

### Parameter Tables

Always show parameter tables with one field per line for clarity:

```lua
-- GOOD: Easy to read, easy to modify
Ark.Button(ctx, {
  label = "Save",
  icon = "\u{F00C}",
  width = 100,
  preset_name = "BUTTON_SUCCESS",
  on_click = save_handler,
})

-- BAD: Hard to read
Ark.Button(ctx, {label = "Save", icon = "\u{F00C}", width = 100, preset_name = "BUTTON_SUCCESS", on_click = save_handler})
```

---

## Examples and Code Snippets

### Types of Examples

1. **Minimal Example**: Absolute minimum to get something working
2. **Common Example**: Most typical use case
3. **Full Example**: All options shown
4. **Real-World Example**: Practical application

### Example: Button Documentation

#### Minimal Example
```lua
Ark.Button(ctx, { label = "OK" })
```

#### Common Example
```lua
Ark.Button(ctx, {
  label = "Save",
  on_click = function()
    save_data()
  end,
})
```

#### Full Example
```lua
local result = Ark.Button(ctx, {
  id = "save_button",
  label = "Save",
  icon = "\u{F0C7}",  -- floppy disk icon
  icon_font = fonts.icons,
  width = 120,
  height = 32,
  disabled = not has_changes,
  is_toggled = false,
  preset_name = "BUTTON_SUCCESS",
  bg_color = nil,  -- use preset
  text_color = nil,  -- use preset
  rounding = 4,
  padding_x = 12,
  on_click = function()
    save_data()
    show_notification("Saved!")
  end,
  on_right_click = function()
    show_save_options()
  end,
  tooltip = "Save changes (Ctrl+S)",
})

if result.clicked then
  -- Additional handling if needed
end
```

#### Real-World Example
```lua
-- Toolbar with multiple buttons
local function draw_toolbar(ctx)
  Ark.Button(ctx, {
    icon = "\u{EA13}",  -- plus icon
    tooltip = "New",
    on_click = function() create_new() end,
  })

  ImGui.SameLine(ctx)

  Ark.Button(ctx, {
    icon = "\u{EB7D}",  -- folder icon
    tooltip = "Open",
    on_click = function() open_file() end,
  })

  ImGui.SameLine(ctx)

  Ark.Button(ctx, {
    icon = "\u{F0C7}",  -- save icon
    tooltip = "Save",
    disabled = not state.has_changes,
    preset_name = state.has_changes and "BUTTON_ACCENT" or nil,
    on_click = function() save_file() end,
  })
end
```

---

## Visual Documentation

### Screenshots

Include screenshots for:
- Default widget appearance
- All preset variants
- Hover/active states
- Light and dark themes

Naming convention:
```
images/
├── button-default.png
├── button-hover.png
├── button-toggle-teal.png
├── button-disabled.png
└── button-all-presets.png
```

### State Diagrams

For interactive widgets, show state transitions:

```
┌─────────┐  mouse enter   ┌─────────┐
│ Normal  │ ────────────▶  │ Hovered │
└─────────┘                └─────────┘
     ▲                          │
     │ mouse leave              │ mouse down
     │                          ▼
     │                     ┌─────────┐
     └──────────────────── │ Active  │
         mouse up          └─────────┘
```

### Color Swatches

For style documentation, show color swatches:

```markdown
| Name | Color | Hex | Usage |
|------|-------|-----|-------|
| BG_BASE | ![#252525](https://via.placeholder.com/20/252525/252525) | `#252525` | Control backgrounds |
| ACCENT_TEAL | ![#295650](https://via.placeholder.com/20/295650/295650) | `#295650` | Toggle ON state |
```

---

## Maintenance Guidelines

### When to Update Documentation

- **New Feature**: Document before merge
- **API Change**: Update immediately
- **Bug Fix**: Update if behavior changes
- **Deprecation**: Add deprecation notice

### Deprecation Notice Format

```markdown
> ⚠️ **Deprecated since v1.3.0**
>
> `old_function()` is deprecated. Use `new_function()` instead.
>
> ```lua
> -- Old (deprecated)
> old_function(a, b)
>
> -- New (recommended)
> new_function({ param_a = a, param_b = b })
> ```
```

### Version Tags

Use version tags to indicate when features were added:

```markdown
### on_double_click

*Added in v1.2.0*

Callback fired when widget is double-clicked.
```

### Documentation Review Checklist

Before merging documentation:

- [ ] All code examples are tested and work
- [ ] Parameter tables are complete
- [ ] Return values are documented
- [ ] Related links are valid
- [ ] No typos or grammar errors
- [ ] Consistent terminology
- [ ] Screenshots are up-to-date (if applicable)

---

## Tools and Automation

### Documentation Generator Script

Create a script to generate documentation stubs from code:

```lua
-- tools/generate_docs.lua
-- Parses Lua files and generates markdown documentation stubs

local function extract_annotations(file_path)
  local file = io.open(file_path, "r")
  if not file then return nil end

  local content = file:read("*all")
  file:close()

  -- Parse ---@class, ---@param, ---@return annotations
  local classes = {}
  local functions = {}

  -- ... parsing logic ...

  return { classes = classes, functions = functions }
end

local function generate_markdown(module_name, annotations)
  local md = string.format("# %s\n\n", module_name)

  -- Generate documentation structure
  -- ... generation logic ...

  return md
end
```

### Link Checker

```lua
-- tools/check_links.lua
-- Verifies all markdown links are valid

local function check_links(docs_dir)
  local broken_links = {}

  -- Scan all .md files
  -- Check all [text](link) patterns
  -- Verify internal links exist
  -- Report broken links

  return broken_links
end
```

### Example Tester

```lua
-- tools/test_examples.lua
-- Extracts and runs code examples from documentation

local function extract_code_blocks(markdown_file)
  local blocks = {}

  -- Parse ```lua ... ``` blocks
  -- Return array of code strings

  return blocks
end

local function test_example(code)
  -- Try to load and execute
  local fn, err = load(code)
  if not fn then
    return false, err
  end

  -- Execute in sandbox
  local ok, result = pcall(fn)
  return ok, result
end
```

---

## Quick Reference: Documentation Files Needed

### High Priority (Create First)

| File | Description | Template |
|------|-------------|----------|
| `docs/index.md` | Library overview | Custom |
| `docs/getting-started.md` | Quick start guide | Custom |
| `docs/api/widgets/button.md` | Button widget | Widget |
| `docs/api/widgets/checkbox.md` | Checkbox widget | Widget |
| `docs/api/widgets/combo.md` | Dropdown widget | Widget |
| `docs/api/containers/panel.md` | Panel container | Widget |
| `docs/api/style/colors.md` | Color system | Core |

### Medium Priority

| File | Description | Template |
|------|-------------|----------|
| `docs/api/widgets/slider.md` | Slider widget | Widget |
| `docs/api/widgets/spinner.md` | Number spinner | Widget |
| `docs/api/widgets/inputtext.md` | Text input | Widget |
| `docs/api/containers/grid.md` | Grid container | Widget |
| `docs/api/core/settings.md` | Settings module | Core |
| `docs/guides/theming.md` | Theme customization | Guide |

### Lower Priority

| File | Description | Template |
|------|-------------|----------|
| `docs/api/widgets/tabs.md` | Tab navigation | Widget |
| `docs/api/widgets/tree-view.md` | Tree view | Widget |
| `docs/api/core/bootstrap.md` | Bootstrap system | Core |
| `docs/guides/creating-widgets.md` | Custom widgets | Guide |
| `docs/guides/drag-and-drop.md` | D&D system | Guide |

---

## Sample: Getting Started Document

```markdown
# Getting Started with ARKITEKT

Create your first ARKITEKT script in 5 minutes.

## Prerequisites

- REAPER (recent version)
- ReaImGui extension installed
- SWS extension installed

## Your First Script

Create a new file `my_first_script.lua`:

\`\`\`lua
-- Bootstrap ARKITEKT
local Ark = dofile(debug.getinfo(1,'S').source:sub(2):match('(.-ARKITEKT[/\\])') .. 'arkitekt' .. package.config:sub(1,1) .. 'init.lua')

local Shell = require('arkitekt.runtime.shell')

-- Define your app
local function app(ctx)
  Ark.Button(ctx, {
    label = "Hello ARKITEKT!",
    on_click = function()
      reaper.ShowMessageBox("It works!", "Success", 0)
    end,
  })
end

-- Run it
Shell.run({
  title = "My First ARKITEKT App",
  width = 300,
  height = 200,
  app = app,
})
\`\`\`

## What's Next?

- [Widget Reference](api/widgets/index.md) - All available widgets
- [Style Guide](api/style/index.md) - Customize appearance
- [Building Apps](guides/building-apps.md) - Full application architecture
```

---

*Last updated: 2025-01-25*

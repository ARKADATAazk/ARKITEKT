# Modularisation Guide

> How to identify, extract, and maintain reusable components across ARKITEKT scripts.

## Philosophy

**DRY across scripts, not within scripts.**

A utility function repeated 3 times in one file is fine. The same utility duplicated across 3 scripts should be extracted to the framework.

---

## When to Modularise

### Extract When:
1. **Same code in 3+ scripts** - Clear pattern, worth the abstraction
2. **Same code in 2 scripts with likelihood of 3rd** - Proactive extraction
3. **Complex logic that's copy-pasted** - Bug fixes need to propagate
4. **UI component used in multiple places** - Consistent behavior expected

### Don't Extract When:
1. **Only used in one script** - Wait until second use case appears
2. **Implementations differ significantly** - Forced abstraction adds complexity
3. **Trivial one-liners** - Overhead of import not worth it
4. **Script-specific business logic** - Belongs in the script

---

## Discovery Process

### Step 1: Compare Scripts

When working on a script, compare with others to find patterns:

```bash
# Find similar function names across scripts
grep -r "function.*filter" scripts/*/

# Find similar patterns
grep -r "search.*lower.*find" scripts/*/

# Find similar file names
find scripts/ -name "*state*.lua"
find scripts/ -name "*sort*.lua"
```

### Step 2: Categorize the Pattern

| Pattern Type | Location | Example |
|-------------|----------|---------|
| Pure utility | `arkitekt/core/` | sorting, filtering, math |
| UI component | `arkitekt/gui/widgets/` | buttons, inputs, status bars |
| Interaction | `arkitekt/gui/interaction/` | drag-drop, selection, reorder |
| Data pattern | `arkitekt/core/` | incremental loader, cache |
| Platform wrapper | `arkitekt/platform/` | REAPER/ImGui abstractions |

### Step 3: Design the API

Compare all implementations:

```lua
-- Script A
local function sort_by_name(list)
  table.sort(list, function(a, b)
    return a.name:lower() < b.name:lower()
  end)
end

-- Script B
local function sort_alphabetical(items, reverse)
  table.sort(items, function(a, b)
    local cmp = a.label:lower() < b.label:lower()
    return reverse and not cmp or cmp
  end)
end

-- Unified API
Sorting.apply(list, {
  mode = "alpha",
  direction = "asc",  -- or "desc"
  get_value = function(x) return x.name or x.label end
})
```

Key questions:
- What's the minimal common interface?
- What variations exist? (field names, options)
- Can options handle variations without bloat?

---

## Extraction Process

### 1. Create the Module

```lua
-- arkitekt/core/[module_name].lua
-- Brief description

local M = {}

-- Constants (if any)
M.DEFAULTS = { ... }

-- Main API
function M.do_thing(input, opts)
  opts = opts or {}
  -- implementation
end

return M
```

### 2. Migrate Reference Implementation

Pick the most complete implementation and migrate first:

```lua
-- Before (in script)
local function filter_items(items, search)
  local result = {}
  local search_lower = search:lower()
  for _, item in ipairs(items) do
    if item.name:lower():find(search_lower, 1, true) then
      result[#result + 1] = item
    end
  end
  return result
end

-- After (in script)
local Filter = require('arkitekt.core.filter')

local filtered = Filter.by_text(items, search, {
  get_value = function(x) return x.name end
})
```

### 3. Test Thoroughly

- Verify the script still works correctly
- Check edge cases the original handled
- Ensure performance is equivalent or better

### 4. Migrate Remaining Scripts

One at a time, test after each migration.

### 5. Document

Update:
- [ ] Module header comments
- [ ] `cookbook/` if significant
- [ ] `TODO/MODULARISATION.md` status

---

## Common Patterns to Look For

### Text Search/Filter

```lua
-- Pattern: case-insensitive substring search
if item.name:lower():find(search:lower(), 1, true) then
```

**Extract to**: `arkitekt/core/filter.lua`

### Sorting with Options

```lua
-- Pattern: table.sort with mode selection
if sort_mode == "alpha" then
  table.sort(list, function(a, b) return a.name < b.name end)
elseif sort_mode == "color" then
  -- ...
end
```

**Extract to**: `arkitekt/core/sorting.lua` ✓ (done)

### Selection State

```lua
-- Pattern: tracking selected items
local selected = {}
function select(id) selected[id] = true end
function deselect(id) selected[id] = nil end
function toggle(id) selected[id] = not selected[id] or nil end
function is_selected(id) return selected[id] end
```

**Extract to**: `arkitekt/gui/interaction/selection.lua`

### Drag Detection

```lua
-- Pattern: mouse threshold for drag start
local drag_start_x, drag_start_y
local is_dragging = false

if mouse_down and not is_dragging then
  local dx = mouse_x - drag_start_x
  local dy = mouse_y - drag_start_y
  if dx*dx + dy*dy > DRAG_THRESHOLD^2 then
    is_dragging = true
  end
end
```

**Extract to**: `arkitekt/gui/interaction/drag.lua`

### Status Messages with Timeout

```lua
-- Pattern: timed message display
local message = ""
local message_time = 0

function set_message(text, duration)
  message = text
  message_time = reaper.time_precise() + (duration or 3)
end

function get_message()
  if reaper.time_precise() > message_time then
    return nil
  end
  return message
end
```

**Extract to**: `arkitekt/gui/widgets/status_bar.lua` or `arkitekt/core/timed_value.lua`

---

## Checklist for New Extraction

- [ ] Pattern found in 2+ scripts
- [ ] Implementations compared, common API identified
- [ ] Module created in correct location (`core/`, `gui/`, `platform/`)
- [ ] One script migrated as reference
- [ ] Tests pass
- [ ] Remaining scripts migrated
- [ ] `TODO/MODULARISATION.md` updated
- [ ] No script-specific logic leaked into framework

---

## Anti-Patterns

### Over-Abstraction

```lua
-- BAD: Too generic, hard to use
function process(data, opts)
  local processor = opts.processor or default_processor
  local transformer = opts.transformer or identity
  local validator = opts.validator or always_true
  -- ...100 lines of configuration...
end

-- GOOD: Focused, easy to use
function filter_by_text(items, search, opts)
  opts = opts or {}
  local get = opts.get_value or function(x) return x.name end
  -- ...simple implementation...
end
```

### Premature Extraction

```lua
-- BAD: Only used in one place, extracted anyway
local SuperSpecificHelper = require('arkitekt.core.super_specific_helper')

-- GOOD: Keep in script until second use case appears
local function super_specific_helper()
  -- ...
end
```

### Breaking Existing API

```lua
-- BAD: Changing function signature breaks all callers
-- Before: Sorting.apply(list, mode)
-- After:  Sorting.apply(list, opts)  -- BREAKING

-- GOOD: Backward compatible
function Sorting.apply(list, opts)
  -- Support old signature
  if type(opts) == "string" then
    opts = { mode = opts }
  end
  -- ...
end
```

---

## Framework Module Locations

| Type | Location | Pure? |
|------|----------|-------|
| Utilities | `arkitekt/core/` | Yes |
| Widgets | `arkitekt/gui/widgets/` | No |
| Interactions | `arkitekt/gui/interaction/` | No |
| Animations | `arkitekt/gui/animation/` | No |
| Platform | `arkitekt/platform/` | No |
| REAPER | `arkitekt/reaper/` | No |
| Definitions | `arkitekt/defs/` | Yes |

---

## Script-Specific vs Framework

### Keep in Script
- Business logic specific to that script
- UI layouts unique to that script
- Domain models (Region, Playlist, Template, Item)
- Script-specific constants

### Move to Framework
- Generic utilities (sort, filter, format)
- Reusable UI components
- Common interaction patterns
- Platform abstractions

---

*See also: [TODO/MODULARISATION.md](../TODO/MODULARISATION.md) for current extraction status*

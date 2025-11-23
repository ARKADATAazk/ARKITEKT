# Modal & Overlay Conventions

This document outlines the standardized patterns for implementing modals and overlays in the ARKITEKT framework.

## Overview

ARKITEKT supports two rendering modes for modals:

1. **Overlay Mode** (Preferred): Uses `window.overlay:push()` with Container rendering for consistent styling
2. **Popup Mode** (Fallback): Uses `ImGui.BeginPopupModal()` for environments where overlay is unavailable

All framework modals should support **both modes** to ensure maximum compatibility.

## Architecture

### Core Components

- **Container** (`overlay/container.lua`): Provides consistent dark container styling with borders and padding
- **Overlay Manager** (in window chrome): Manages overlay stack, scrim dimming, and ESC key handling
- **Modal Views**: Instance-based classes following standardized patterns

### File Structure

```
arkitekt/gui/widgets/overlays/
├── overlay/
│   ├── container.lua        # Reusable container with styling
│   ├── defaults.lua         # Default configuration values
│   ├── manager.lua          # Overlay stack management
│   └── README.md           # This file
├── batch_rename_modal.lua  # Example: Batch rename modal
└── tooltip.lua             # Other overlay widgets
```

## Implementation Pattern

### 1. Instance-Based State

Use instance-based state instead of module-level singleton state:

```lua
local M = {}
local MyModal = {}
MyModal.__index = MyModal

function M.new()
  return setmetatable({
    is_open = false,
    -- ... other state
  }, MyModal)
end
```

**Why?**
- Supports multiple modal instances
- Cleaner state management
- Easier testing
- Prevents state leakage between uses

### 2. Required Methods

Every modal instance should implement:

#### `modal:open(args...)`
Opens the modal and initializes state.

```lua
function MyModal:open(item_count, on_confirm_callback, opts)
  opts = opts or {}
  self.is_open = true
  self.on_confirm = on_confirm_callback
  -- ... initialize state
end
```

#### `modal:should_show()`
Returns whether the modal should be visible.

```lua
function MyModal:should_show()
  return self.is_open
end
```

#### `modal:close()`
Closes the modal and cleans up state.

```lua
function MyModal:close()
  self.is_open = false
  -- ... cleanup
end
```

#### `modal:draw(ctx, ..., window)`
Renders the modal in appropriate mode based on window availability.

```lua
function MyModal:draw(ctx, args, window)
  if not self.is_open then return false end

  -- Use overlay mode if available
  if window and window.overlay then
    self:draw_overlay_mode(ctx, args, window)
  else
    self:draw_popup_mode(ctx, args)
  end

  return self.is_open
end
```

### 3. Dual-Mode Rendering

#### Overlay Mode (Preferred)

Use when `window.overlay` is available:

```lua
function MyModal:draw_overlay_mode(ctx, args, window)
  if not self.overlay_pushed then
    self.overlay_pushed = true

    window.overlay:push({
      id = 'my-modal',           -- Unique identifier
      close_on_scrim = true,      -- Click outside to close
      esc_to_close = true,        -- ESC key to close
      on_close = function()
        self:close()
        self.overlay_pushed = false
      end,
      render = function(ctx, alpha, bounds)
        Container.render(ctx, alpha, bounds, function(ctx, content_w, content_h, w, h, a, padding)
          local should_close = self:draw_content(ctx, args)

          if should_close then
            window.overlay:pop('my-modal')
            self:close()
            self.overlay_pushed = false
          end
        end, { width = 0.5, height = 0.7 })
      end
    })
  end
end
```

**Overlay Push Options:**
- `id` (string): Unique identifier for the overlay
- `close_on_scrim` (boolean): Click dimmed background to close
- `esc_to_close` (boolean): Press ESC to close
- `on_close` (function): Cleanup callback when overlay is closed
- `render` (function): Render callback receiving `(ctx, alpha, bounds)`

**Container Options:**
- `width` (number): Percentage of bounds width (0.0 - 1.0)
- `height` (number): Percentage of bounds height (0.0 - 1.0)
- `rounding` (number): Corner rounding in pixels (default: 0)
- `bg_color` (number): Background color hex
- `bg_opacity` (number): Background opacity (0.0 - 1.0)
- `border_color` (number): Border color hex
- `border_opacity` (number): Border opacity (0.0 - 1.0)
- `border_thickness` (number): Border thickness in pixels (default: 1)
- `padding` (number): Internal padding in pixels (default: 12)

#### Popup Mode (Fallback)

Use when overlay is not available:

```lua
function MyModal:draw_popup_mode(ctx, args)
  if not self.popup_opened then
    ImGui.OpenPopup(ctx, "My Modal##unique_id")
    self.popup_opened = true
  end

  -- Center modal on screen
  local viewport_w, viewport_h = ImGui.Viewport_GetSize(ImGui.GetWindowViewport(ctx))
  local modal_w, modal_h = 500, 400
  ImGui.SetNextWindowPos(ctx, (viewport_w - modal_w) * 0.5, (viewport_h - modal_h) * 0.5, ImGui.Cond_Appearing)
  ImGui.SetNextWindowSize(ctx, modal_w, modal_h, ImGui.Cond_Appearing)

  -- Apply styling
  ImGui.PushStyleColor(ctx, ImGui.Col_PopupBg, hexrgb("#1A1A1AFF"))
  ImGui.PushStyleColor(ctx, ImGui.Col_Border, hexrgb("#404040FF"))
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 16, 12)

  local visible, open = ImGui.BeginPopupModal(ctx, "My Modal##unique_id", true, flags)

  if visible then
    local should_close = self:draw_content(ctx, args)

    if should_close then
      self:close()
      self.popup_opened = false
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.EndPopup(ctx)
  end

  ImGui.PopStyleVar(ctx, 1)
  ImGui.PopStyleColor(ctx, 2)

  if not open then
    self:close()
    self.popup_opened = false
  end
end
```

### 4. Shared Content Rendering

Extract common UI rendering into a separate method:

```lua
function MyModal:draw_content(ctx, args)
  -- Title
  ImGui.Text(ctx, "My Modal Title")
  ImGui.Separator(ctx)

  -- Content
  -- ... render your content

  -- Buttons
  local should_close = false

  if ImGui.Button(ctx, "Cancel") then
    should_close = true
  end

  ImGui.SameLine(ctx)

  if ImGui.Button(ctx, "Confirm") then
    if self.on_confirm then
      self.on_confirm(self.data)
    end
    should_close = true
  end

  return should_close
end
```

**Why?**
- DRY (Don't Repeat Yourself)
- Content looks identical in both modes
- Easier to maintain

## Legacy API Compatibility

For backward compatibility with existing code, provide a singleton wrapper:

```lua
-- Legacy API compatibility
local _legacy_instance = nil

function M.open(...)
  if not _legacy_instance then
    _legacy_instance = M.new()
  end
  _legacy_instance:open(...)
end

function M.is_open()
  if not _legacy_instance then return false end
  return _legacy_instance:should_show()
end

function M.draw(ctx, ..., window)
  if not _legacy_instance then return false end
  return _legacy_instance:draw(ctx, ..., window)
end
```

**Migration Path:**
1. Add instance-based API alongside legacy singleton
2. Update framework code to use instance-based API
3. Keep legacy API for backward compatibility
4. Deprecate legacy API in future versions

## Usage Examples

### Example 1: Batch Rename Modal

See `arkitekt/gui/widgets/overlays/batch_rename_modal.lua` for complete implementation.

**Opening the modal:**
```lua
local BatchRenameModal = require('arkitekt.gui.widgets.overlays.batch_rename_modal')

-- Legacy API (still supported)
BatchRenameModal.open(5, function(pattern)
  print("Rename pattern:", pattern)
end, {
  on_rename_and_recolor = function(pattern, color)
    print("Rename and recolor:", pattern, color)
  end
})

-- Modern instance-based API (preferred)
local modal = BatchRenameModal.new()
modal:open(5, function(pattern)
  print("Rename pattern:", pattern)
end)
```

**Drawing the modal:**
```lua
-- In your draw loop
if BatchRenameModal.is_open() then
  BatchRenameModal.draw(ctx, item_count, window)  -- window enables overlay mode
end
```

### Example 2: Overflow Modal

See `scripts/RegionPlaylist/ui/views/overflow_modal_view.lua` for complete implementation.

**Creating the modal:**
```lua
local OverflowModalView = require('RegionPlaylist.ui.views.overflow_modal_view')

local overflow_modal = OverflowModalView.new(region_tiles, state, function()
  print("Tab selected")
end)
```

**Drawing the modal:**
```lua
function GUI:draw(ctx, window, shell_state)
  -- ... other rendering

  overflow_modal:draw(ctx, window)
end
```

## Style Guidelines

### Colors

Use framework color constants for consistency:

```lua
local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb

-- Standard colors
local bg_color = hexrgb("#1A1A1A")     -- Dark background
local border_color = hexrgb("#404040")  -- Subtle border
local text_color = hexrgb("#CCCCCC")    -- Light text
local hint_color = hexrgb("#999999")    -- Dimmed hints
```

### Spacing

Follow ImGui spacing patterns:

```lua
ImGui.Spacing(ctx)              -- Standard spacing (uses StyleVar_ItemSpacing)
ImGui.Dummy(ctx, 0, 8)          -- Custom spacing (8 pixels)
ImGui.Separator(ctx)            -- Visual separator line
ImGui.Indent(ctx, 16)           -- Indent content
ImGui.Unindent(ctx, 16)         -- Remove indent
```

### Button Layout

Center buttons with consistent sizing:

```lua
local button_w = 100
local spacing = 8
local total_w = button_w * 2 + spacing
ImGui.SetCursorPosX(ctx, (modal_w - total_w) * 0.5)

if ImGui.Button(ctx, "Cancel", button_w, 28) then
  -- handle cancel
end

ImGui.SameLine(ctx, 0, spacing)

if ImGui.Button(ctx, "Confirm", button_w, 28) then
  -- handle confirm
end
```

## Testing Checklist

When implementing a new modal, verify:

- [ ] Works in overlay mode (with window.overlay)
- [ ] Works in popup mode (fallback)
- [ ] ESC key closes modal (overlay mode)
- [ ] Click outside closes modal (overlay mode, if close_on_scrim=true)
- [ ] Close button works
- [ ] Confirm/action buttons work
- [ ] State resets on close
- [ ] Multiple opens work correctly
- [ ] No state leakage between uses
- [ ] Visual consistency between modes
- [ ] Keyboard focus on inputs (if applicable)

## Common Patterns

### Focus Input on Open

```lua
function MyModal:open(...)
  self.is_open = true
  self.focus_input = true  -- Flag to focus input
end

function MyModal:draw_content(ctx, args)
  if self.focus_input then
    ImGui.SetKeyboardFocusHere(ctx)
    self.focus_input = false
  end

  ImGui.InputText(ctx, "##my_input", self.text)
end
```

### Disable Button Until Valid

```lua
local can_confirm = self.text ~= ""

if not can_confirm then
  ImGui.BeginDisabled(ctx)
end

if ImGui.Button(ctx, "Confirm") then
  -- action
end

if not can_confirm then
  ImGui.EndDisabled(ctx)
end
```

### Keyboard Shortcuts

```lua
-- ESC to cancel (overlay mode handles this automatically)
if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
  should_close = true
end

-- Enter to confirm (when input is valid)
if can_confirm and ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
  self:confirm()
  should_close = true
end
```

## Migration Guide

### Updating Existing Modals

1. **Add instance-based API:**
   ```lua
   local MyModal = {}
   MyModal.__index = MyModal

   function M.new()
     return setmetatable({ is_open = false }, MyModal)
   end
   ```

2. **Move state from module-level to instance:**
   ```lua
   -- Before (singleton)
   local state = { is_open = false }

   -- After (instance)
   function M.new()
     return setmetatable({
       is_open = false,
       -- ... other state
     }, MyModal)
   end
   ```

3. **Update methods to use `self`:**
   ```lua
   -- Before
   function M.draw(ctx)
     if not state.is_open then return end
   end

   -- After
   function MyModal:draw(ctx, window)
     if not self.is_open then return end
   end
   ```

4. **Add dual-mode rendering:**
   - Extract content to `draw_content()`
   - Add overlay mode branch
   - Keep popup mode as fallback

5. **Add legacy compatibility:**
   ```lua
   local _legacy_instance = nil
   function M.draw(...)
     if not _legacy_instance then
       _legacy_instance = M.new()
     end
     return _legacy_instance:draw(...)
   end
   ```

6. **Update call sites to pass window:**
   ```lua
   -- Before
   MyModal.draw(ctx, args)

   -- After
   MyModal.draw(ctx, args, window)
   ```

## Best Practices

1. **Always support both modes** - Don't assume overlay is available
2. **Use Container.render** - Ensures visual consistency
3. **Extract shared content** - DRY principle for draw_content()
4. **Reset state on close** - Prevent state leakage
5. **Focus inputs on open** - Better UX
6. **Handle keyboard shortcuts** - ESC, Enter
7. **Center content properly** - Responsive to window size
8. **Provide legacy API** - Smooth migration path
9. **Document your modal** - Help others understand usage
10. **Test both modes** - Verify functionality in all scenarios

## Reference Implementations

Study these files for complete examples:

- **Batch Rename Modal**: `arkitekt/gui/widgets/overlays/batch_rename_modal.lua`
  - Instance-based with legacy compatibility
  - Dual-mode rendering
  - Color picker integration
  - Input validation

- **Overflow Modal**: `scripts/RegionPlaylist/ui/views/overflow_modal_view.lua`
  - Instance-based
  - Search input
  - Grid layout
  - Click selection

- **Container**: `arkitekt/gui/widgets/overlays/overlay/container.lua`
  - Reusable container pattern
  - Configurable styling
  - Responsive sizing

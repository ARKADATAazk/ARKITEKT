# Window Management QOL Ideas

Future quality-of-life improvements for ARKITEKT window management.

---

## Quick Wins (Easy to Implement)

### Remember Last Dock Location
**Status:** Not Implemented
**Effort:** Easy

When you undock a window, save which dock ID it was in. Next time you dock that window, it could auto-snap to the same dock spot.

**Use Case:** "I always dock Region Playlist on the right side of REAPER"

**Implementation Notes:**
- Save `last_dock_id` in settings when docking
- On next dock attempt, check if user is near that dock area
- Auto-suggest or snap to the previous dock location

---

### Prevent Accidental Undocking
**Status:** Not Implemented
**Effort:** Easy

Require Shift+drag (or double-click titlebar) to undock windows.

**Use Case:** Avoid accidentally undocking when you meant to click a button in the titlebar

**Implementation Notes:**
- Check for Shift modifier in drag detection
- Or require double-click on docked window titlebar to float
- Could be a toggle in settings

---

### Smart Window Cascade/Tile
**Status:** Not Implemented
**Effort:** Medium

When opening multiple floating windows, offset them instead of stacking exactly on top of each other.

**Use Case:** Opening 3 tools at once - they automatically cascade instead of overlapping

**Implementation Notes:**
- Track recently opened window positions
- Apply small offset (20-30px x/y) for each new window
- Wrap around when reaching screen edge

---

### Snap to Grid/Edges
**Status:** Not Implemented
**Effort:** Medium

When dragging near screen edges or other windows, snap to align (like modern OS window managers).

**Use Case:** Manually tiling windows becomes easier with magnetic snapping

**Implementation Notes:**
- Detect proximity to screen edges (10-20px threshold)
- Detect proximity to other ARKITEKT windows
- Apply snap during drag (modify position before releasing)
- Visual feedback (highlight snap zones)

---

## Medium Effort

### Dock Layout Presets
**Status:** Not Implemented
**Effort:** Medium-High

Save/restore entire dock layouts with named presets.

**Use Case:**
- "Layout 1: Editing" - Region Playlist + Item Picker on right
- "Layout 2: Mixing" - only Transport visible

**Implementation Notes:**
- Save dock states for all ARKITEKT windows
- Serialized layout in central config or per-project
- UI in titlebar context menu: "Save Layout...", "Load Layout..."
- Could integrate with REAPER screensets

---

### Multi-Monitor Smart Placement
**Status:** Not Implemented
**Effort:** Medium

Remember which monitor each window was on. Detect when monitors are disconnected and handle gracefully.

**Use Case:** Laptop + external monitor workflow - windows restore to correct monitor

**Implementation Notes:**
- Save monitor index/ID with window position
- On startup, check if that monitor still exists
- Fallback to primary monitor if disconnected
- Could use `JS_Window_GetViewportFromRect` for monitor detection

---

### Minimize to Dock
**Status:** Not Implemented
**Effort:** High

Collapsed/minimized windows auto-dock to a sidebar or panel.

**Use Case:** Keep tools accessible but out of the way (like macOS dock)

**Implementation Notes:**
- Create dedicated "minimized windows" dock area
- Show window icons/titles in compact form
- Click to restore and float
- Could be horizontal bar at bottom or vertical on side

---

## Advanced

### Magnetic Window Groups
**Status:** Not Implemented
**Effort:** High

Group related windows so they move/dock together as a unit.

**Use Case:** "Region Playlist + Transport always stay together and dock as one"

**Implementation Notes:**
- Define groups in config or via UI
- When moving/docking one window, move all in group
- Maintain relative positions within group
- Could use REAPER's window attachment API if available

---

## Tested But Not Feasible ⚠️

### ⚠️ Keyboard Dock Shortcuts
**Status:** Attempted, Not Feasible
**Effort:** High (ImGui API limitation)

Quick keyboard shortcuts to dock to screen edges using numpad.

**Why It Doesn't Work:**
ImGui's `SetNextWindowDockID()` API causes Begin/End stack corruption when called programmatically. The docking system is designed for manual drag-and-drop only, not programmatic docking. Multiple approaches tested:
- Calling `SetNextWindowDockID` before Begin → corrupts ImGui state
- Calling `gfx.dock()` → only works for GFX windows, not ImGui
- Deferring to next frame → still corrupts state

**Alternative:**
Manual drag-to-dock works perfectly and preserves seamless undock position restoration.

---

## Implemented ✅

### ✅ Double-Click Titlebar to Maximize
**Status:** ✅ Implemented
**Effort:** Easy

Double-clicking the titlebar toggles maximize (alternative to maximize button).

**Implementation:**
- `arkitekt/app/chrome/titlebar.lua:505-511` - double-click detection on titlebar child window
- Uses `IsWindowHovered` + `IsMouseDoubleClicked` to detect double-click
- Only active when `enable_maximize` is true
- Does not interfere with titlebar dragging or buttons

**Use Case:** Quick maximize/restore without reaching for the maximize button

---

### ✅ Seamless Dock/Undock Position Restoration
**Status:** ✅ Implemented
**Effort:** Medium

When undocking, window returns to position before drag started (not end-of-drag position).

**Implementation:**
- `arkitekt/app/chrome/window.lua:259-260, 779-845` - tracks `_drag_start_pos` on mouse down
- Captures position at exact moment of mouse press
- Restores both position and size when undocking
- Persisted in settings for cross-session support

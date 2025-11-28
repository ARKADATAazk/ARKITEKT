# ItemPicker Feature Requests

> **Status:** Proposed
> **Priority:** Medium
> **App:** ItemPicker

---

## 1. Keyboard Navigation

**Description:** Arrow keys to move selection through the grid.

**Behavior:**
- Arrow keys move focus/selection in grid
- Wrap at edges or stop (configurable?)
- Home/End for first/last item
- Page Up/Down for larger jumps
- Shift+Arrow for extend selection
- Ctrl+Arrow for move without selecting

**Implementation:**
- Grid widget needs keyboard focus handling
- Track "cursor" position separate from selection
- Render cursor highlight (different from selection highlight)

---

## 2. Quick Insert (Enter Key)

**Description:** Press Enter to insert selected item(s) at edit cursor position.

**Behavior:**
- Single selection: Insert at edit cursor
- Multi-selection: Insert sequentially (respecting selection order - see SelectionNumbering.md)
- Shift+Enter: Insert and close picker
- Option for gap between sequential items (0, snap to grid, custom)

**Implementation:**
- New keyboard behavior in grid factories
- Reuse existing insert logic from drag handler
- Add setting for default gap/spacing

---

## 3. Auto-Preview on Hover

**Description:** Optional setting to auto-preview items when hovering.

**Behavior:**
- Hover delay before preview starts (e.g., 300ms)
- Moving to new item stops previous, starts new
- Moving off all items stops preview
- Setting to enable/disable (default: off)
- Respects current preview mode (direct vs through track)

**Implementation:**
- Track hover state with timer in grid
- Call existing preview API on timeout
- Add toggle in settings panel

---

## 4. Smart Collections

**Description:** Save and recall filter combinations.

**Behavior:**
- Save current filter state as named collection
- Includes: search string, track filter, region filter, sort mode, content type
- Quick access from dropdown or keyboard shortcut
- Edit/delete collections
- Sync across sessions (persist to project or global)

**Example Collections:**
- "Drums from Verse 1" = track:Drums + region:Verse1
- "All FX" = search:"fx" + sort:name
- "Favorites only" = favorites:on

**Implementation:**
- New `domain/collections/` module
- Persistence via existing storage
- UI: Dropdown near search bar or in settings panel
- Keyboard: Number keys 1-9 for quick recall?

---

## 5. Additional Ideas (Lower Priority)

### Insert with Options
- Insert at cursor vs insert at end of track
- Insert with crossfade
- Insert and move cursor to end of inserted item

### Preview Enhancements
- Loop preview toggle
- Preview volume control
- Waveform playhead indicator during preview

### Visual Density Options
- Compact mode (smaller tiles, more items visible)
- Text-only mode (list-like but still grid layout)
- Waveform zoom level per-tile

### Organization
- Custom color tags (beyond favorites)
- Pin items to top
- Hide items (temporary, not disabled)

---

## Priority Order

1. **Keyboard Navigation** - Most impactful for power users
2. **Quick Insert** - Natural complement to keyboard nav
3. **Auto-Preview** - Nice QoL improvement
4. **Smart Collections** - Powerful but more complex

---

## Related

- [SelectionNumbering.md](./SelectionNumbering.md) - Sequential selection ordering

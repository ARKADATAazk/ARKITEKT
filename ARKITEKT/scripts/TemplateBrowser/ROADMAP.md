# TemplateBrowser Roadmap

## High Priority

### Fuzzy Search
- Critical for large libraries (100+ templates)
- "drm" matches "drums", "kick drm" matches "Kick Drum Kit"
- Levenshtein distance or similar algorithm
- **Note**: Should be part of arkitekt library's search module (reusable)

### Track Count Parsing & Display
- Parse `<TRACK>` blocks from .RTrackTemplate files
- Show badge on tiles: `16T` for 16-track templates
- FX count badge: `12 FX` indicator
- Stacked tile visual for multi-track templates (like ItemPicker drag preview)

### Inbox Workflow
- `_Inbox` folder pinned at top of tree
- Badge showing unsorted count
- Users save via REAPER's native UI → organize in browser
- Special visual treatment (highlight, notification dot)

### Track-Tree Hover Preview
- On hover, show tooltip/popup with track hierarchy
- Display FX per track (not flat list)
- Show routing structure if possible

### Insert Workflow Improvements
- **Apply and close** - Insert template then auto-close browser
- **Insert multiple** - Shift+click to queue multiple templates for batch insert
- **Template sets** - Save groups of templates to insert together as a preset

## Medium Priority

### Star Ratings
- 1-5 stars replacing binary favorites
- Filter by minimum rating
- Sort by rating

### Search in Notes/Metadata
- Full-text search across notes field
- Search in tags, FX names
- Combined search (name + notes + tags)

### Color Inheritance
- Folders can have assigned colors
- Templates inside inherit folder color if not overridden
- Visual consistency for template organization

### Usage Statistics
- Track insertion count over time
- "Used 12 times this month"
- Usage graphs/trends
- "Trending" sort option

### Stacked Tile Visual
- Multi-track templates show layered "depth" effect
- 2-3 offset layers behind main tile (like ItemPicker drag UI)
- Visual indicator of template complexity

## Lower Priority

### Recent Searches
- Dropdown showing last 5-10 searches
- Quick re-apply previous search
- **Note**: Should be in arkitekt library's search module (reusable)

### Regex/Wildcard Search
- Toggle for advanced users
- Pattern matching: `drum*`, `*kit*`
- **Note**: Should be globalized in arkitekt search module

### New Template Indicator
- Templates added since last session highlighted
- "New" badge or subtle glow
- Clear after first view

### Auto-tagging Suggestions
- Based on FX: "Has Kontakt" → suggest "Sampler" tag
- Based on track count: >8 tracks → suggest "Ensemble"
- User confirms suggestions

### Bulk Operations
- Select multiple templates
- Apply tags to selection
- Move selection to folder
- Bulk color assignment
- **Note**: Batch Rename And Recolor modularisation already planned

### Quick Filter Presets
- Save current filter combination
- "Drums + Kontakt + 4+ stars"
- One-click apply

### Keyboard Navigation
- Arrow keys / vim-style j/k
- Enter to insert
- Space to toggle favorite
- Number keys for star rating

## Future / Investigate

### Template Health Check
- Scan for missing plugins
- Warning indicator on tiles
- "3 missing plugins" tooltip

### Template Creation Helper
- Guide user through REAPER's save process
- Auto-move to Inbox after save
- Pre-fill suggested tags based on selection

### Grid Customization
- Zoom slider for tile size
- Adjustable columns
- Compact/comfortable/spacious presets

### Export Selection
- Zip templates + metadata for sharing
- Import metadata from shared packs
- Low priority

## Won't Do / Out of Scope

- Template preview/audition (templates aren't audio)
- Thumbnail generation (nothing visual to capture)
- Cloud sync (users sync REAPER folder)
- Template editing (REAPER doesn't support this)
- Import from other DAWs (format incompatibility)
- Track type icons (tags sufficient)
- Routing complexity indicators (overkill)

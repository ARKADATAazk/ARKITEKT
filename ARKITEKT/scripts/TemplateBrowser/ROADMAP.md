# TemplateBrowser Roadmap

## High Priority

### Fuzzy Search
- Critical for large libraries (100+ templates)
- "drm" matches "drums", "kick drm" matches "Kick Drum Kit"
- Levenshtein distance or similar algorithm

### Track Count Parsing & Display
- Parse `<TRACK>` blocks from .RTrackTemplate files
- Show badge on tiles: `16T` for 16-track templates
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

## Medium Priority

### Star Ratings
- 1-5 stars replacing binary favorites
- Filter by minimum rating
- Sort by rating

### Search in Notes/Metadata
- Full-text search across notes field
- Search in tags, FX names
- Combined search (name + notes + tags)

### Usage Statistics
- Track insertion count over time
- "Used 12 times this month"
- Usage graphs/trends
- "Trending" sort option

### Stacked Tile Visual
- Multi-track templates show layered "depth" effect
- 2-3 offset layers behind main tile
- Visual indicator of template complexity

## Lower Priority

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

## Won't Do / Out of Scope

- Template preview/audition (templates aren't audio)
- Thumbnail generation (nothing visual to capture)
- Cloud sync (users sync REAPER folder)
- Template editing (REAPER doesn't support this)
- Import from other DAWs (format incompatibility)

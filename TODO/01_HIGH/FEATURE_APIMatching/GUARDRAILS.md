# API Guardrails: Pit of Success Design

> **Philosophy: Make the right thing easy, the wrong thing hard (but not impossible)**

---

## Principle

Users who follow the documentation naturally end up with good results. Those who want to deviate must actively seek out escape hatches.

---

## Implementation Strategy

### Tier 1: Easy Path (Documented, Encouraged)

```lua
-- This is what tutorials show
-- This is what examples use
-- This is what autocomplete suggests

Ark.Button(ctx, {label = "Delete", preset = "danger"})
Ark.Button(ctx, {label = "Save", preset = "success"})
Theme.set_mode("adapt")  -- Follow REAPER theme
```

**Guardrails:**
- All docs/guides use presets only
- QUICKSTART shows preset examples
- LuaCATS hints show preset options

### Tier 2: Hidden Path (Undocumented, Works)

```lua
-- Not in docs, not in examples
-- Power users can find it in source code
-- No autocomplete hints

Ark.Button(ctx, {label = "X", bg_color = 0xFF0000FF})
```

**Guardrails:**
- Not mentioned in any documentation
- No LuaCATS annotations for raw color fields
- Works silently (no warnings yet)

### Tier 3: Friction Path (Future, If Needed)

```lua
-- Requires explicit opt-in
-- Named to signal "you sure about this?"

Ark.Button(ctx, {
  label = "X",
  _override = {bg_color = 0xFF0000FF},  -- Underscore = internal
})

-- OR require a flag
Theme.allow_raw_colors = true  -- Must enable first
```

**Guardrails:**
- Verbose syntax discourages casual use
- Explicit flag makes it a conscious choice
- Easy to grep for in codebases

---

## Current Implementation

| Feature | Tier | Status |
|---------|------|--------|
| `preset = "danger"` | Easy | ✅ Documented |
| `Theme.set_mode()` | Easy | ✅ Documented |
| `bg_color = 0xFF...` | Hidden | ⏳ Works, undocumented |
| Deprecation warnings | Friction | 🔮 Future |

---

## Documentation Strategy

### DO Document
- Semantic presets (`preset = "danger"`)
- Theme modes (`Theme.set_mode("dark"/"light"/"adapt")`)
- Custom BG color (`Theme.set_custom(color)`)

### DON'T Document
- Raw color overrides (`bg_color`, `text_color`, etc.)
- Internal color fields
- Legacy compatibility options

### Example: Button Documentation

```lua
-- GOOD: What the docs show
Ark.Button(ctx, "Click me")
Ark.Button(ctx, {label = "Delete", preset = "danger"})
Ark.Button(ctx, {label = "Save", preset = "success", on_click = save})

-- NOT SHOWN: These exist but aren't documented
-- bg_color, text_color, border_color, etc.
```

---

## Rationale

### Why Not Hard Block?
- Breaks existing code
- Frustrating for edge cases
- Power users feel trapped

### Why Not Full Freedom?
- Inconsistent ecosystem
- "Christmas tree" UIs
- Theme adaptation breaks
- More support burden

### Why Soft Guardrails?
- 95% of users follow docs → good results
- 5% power users can find escape hatch
- No broken code, no frustration
- Natural migration path

---

## Future Considerations

### If Raw Colors Become a Problem

1. **Phase 1**: Add console warning (once per session)
   ```
   [ARKITEKT] Warning: bg_color is deprecated, use preset instead
   ```

2. **Phase 2**: Require opt-in flag
   ```lua
   Theme.legacy_colors = true  -- Enable deprecated color API
   ```

3. **Phase 3**: Remove from codebase (major version)

### Metrics to Watch

- How many scripts use raw colors? (grep community repos)
- User complaints about restrictions?
- Theme adaptation bugs from raw colors?

---

## Summary

| Who | Experience |
|-----|------------|
| **New user** | Reads docs → uses presets → beautiful UI |
| **Experienced user** | Knows presets → chooses appropriate one → consistent UI |
| **Power user** | Digs into source → finds raw colors → takes responsibility |
| **Legacy code** | Still works → no breakage → migrate at own pace |

**The goal:** An opinionated framework that guides users to success while respecting expert autonomy.

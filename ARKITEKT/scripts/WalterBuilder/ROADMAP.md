# WALTER Builder - Development Roadmap

> **Goal**: A full visual programming IDE for REAPER theming that can replace manual rtconfig editing.

---

## Progress Assessment

### Current Progress: ~25-30%

**What works:**
- ✅ Rtconfig parsing (sections, macros, expressions)
- ✅ Polish notation expression evaluation (80/80 test cases)
- ✅ Coordinate system with attachments
- ✅ Flow layout parsing (`then` statements)
- ✅ Flow group expansion (pan_group, fx_group, etc.)
- ✅ Visual canvas with element rendering
- ✅ Element panel with categories
- ✅ Custom element detection
- ✅ Debug console
- ✅ Basic property inspector

**What's missing for a full IDE:**
- ❌ AST preservation (expressions stored as strings, not editable AST)
- ❌ Element editing (drag to reposition, resize)
- ❌ Expression editor (visual builder for WALTER expressions)
- ❌ Variable editor (create/modify variables)
- ❌ Macro editor (create/modify macros)
- ❌ Conditional logic editor (if/then/else visual flow)
- ❌ Export to rtconfig (serialize changes back to file)
- ❌ Undo/redo system
- ❌ Multi-context editing (TCP, MCP, EnvCP, Transport)
- ❌ Live preview sync with REAPER

---

## Development Paths

### Path A: Override Mode (Simpler)
**Effort: ~40% more | Result: Non-destructive editor**

Keep original rtconfig read-only, store overrides separately.

```
User loads rtconfig → Parses to current model
User edits element → Override stored in separate JSON
Export → Merge overrides into rtconfig
```

**Pros:**
- Non-destructive (original file preserved)
- Simpler implementation (no AST mutation)
- Can start editing sooner
- Easy rollback of changes

**Cons:**
- Can't edit existing expressions
- Limited macro support
- "Bolt-on" feel, not native editing

**Best for:** Quick wins, theme tweaking, position adjustments

---

### Path B: Full AST Editor (Complex)
**Effort: ~70% more | Result: Complete rtconfig IDE**

Parse rtconfig to full AST, support in-place editing.

```
User loads rtconfig → Full AST with source locations
User edits element → AST node modified
Export → Serialize AST back to rtconfig syntax
```

**Requires:**
1. **AST nodes with source tracking**
   - Each node knows its line/column in source
   - Preserves comments and formatting
   - Handles macro definitions as AST subtrees

2. **Expression AST builder**
   - Visual node graph for Polish notation
   - Drag-and-drop expression construction
   - Real-time evaluation preview

3. **Serializer**
   - AST → rtconfig text
   - Preserve original formatting where unchanged
   - Handle macro expansion/collapse

**Pros:**
- Full control over rtconfig
- Can edit any expression/macro
- True visual programming experience

**Cons:**
- Significant implementation effort
- Complex AST mutation logic
- More edge cases to handle

**Best for:** Power users, theme creators, complex layouts

---

### Path C: Hybrid Approach (Recommended)
**Effort: ~50% more | Result: Progressive enhancement**

Start with Override Mode, gradually add AST capabilities.

**Phase 1: Override Mode Foundation**
- Element position/size editing via overrides
- Simple property changes (colors, flags)
- Export overrides as rtconfig snippet
- ~20% effort

**Phase 2: Simple Expression Editing**
- Parse and display expressions
- Edit coordinate arrays directly
- Add/remove simple conditionals
- ~15% effort

**Phase 3: AST Integration**
- Store original AST alongside evaluated values
- Edit expressions with AST preservation
- Full macro editing
- ~35% effort

**Pros:**
- Usable at each phase
- Risk spread over time
- Can pivot based on user feedback
- Incremental complexity

**Best for:** Sustainable development, real-world feedback loop

---

## Immediate Next Steps

### Priority 1: Element Interaction
1. **Click to select** - already works
2. **Drag to move** - update element coordinates
3. **Edge drag to resize** - update width/height
4. **Constraints** - snap to grid, alignment guides

### Priority 2: Property Editing
1. **Direct coordinate input** - edit [x y w h] values
2. **Attachment toggles** - visual ls/ts/rs/bs controls
3. **Visibility toggle** - show/hide element
4. **Layer ordering** - z-index control

### Priority 3: Export Foundation
1. **Generate SET statement** - from element coords
2. **Copy to clipboard** - quick export
3. **Diff view** - show changes vs original

### Priority 4: Context Variables
1. **Variable panel** - show/edit context vars
2. **Sliders for dimensions** - w, h, scale
3. **Toggles for flags** - is_solo_flipped, hide_groups
4. **Live preview update** - re-evaluate on change

---

## Technical Debt

### Current Issues
1. **No AST preservation** - expressions are strings, not trees
2. **Hardcoded flow layout** - only handles specific patterns
3. **Limited macro support** - extracts SETs, doesn't expand fully
4. **No validation** - invalid coordinates silently accepted

### Refactoring Needed
1. **Element model expansion** - add source_expr, is_modified flags
2. **Override layer** - separate modified values from parsed values
3. **Serializer module** - Element → rtconfig text
4. **Validation module** - check coordinate bounds, attachment logic

---

## Feature Comparison

| Feature | Path A | Path B | Path C |
|---------|--------|--------|--------|
| Element repositioning | ✅ | ✅ | ✅ (Phase 1) |
| Simple property edits | ✅ | ✅ | ✅ (Phase 1) |
| Expression viewing | ✅ | ✅ | ✅ (Phase 1) |
| Coordinate editing | ✅ | ✅ | ✅ (Phase 2) |
| Expression editing | ❌ | ✅ | ✅ (Phase 3) |
| Macro editing | ❌ | ✅ | ✅ (Phase 3) |
| Preserve formatting | ❌ | ✅ | Partial |
| Non-destructive | ✅ | ❌ | ✅ |
| Implementation effort | Low | High | Medium |

---

## Success Metrics

### Phase 1 Complete When:
- [ ] Can drag element to new position
- [ ] Can resize element by dragging edges
- [ ] Changes visible in property panel
- [ ] Can export element as SET statement

### Phase 2 Complete When:
- [ ] Can edit coordinate values directly
- [ ] Can toggle attachments visually
- [ ] Context variables adjustable via UI
- [ ] Live preview updates on variable change

### Phase 3 Complete When:
- [ ] Can export full modified rtconfig
- [ ] Changes preserve original formatting
- [ ] Undo/redo works for all operations
- [ ] Can create new elements from scratch

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| AST complexity spiral | High | Start with Phase 1 (overrides) |
| Macro edge cases | Medium | Document unsupported patterns |
| WALTER syntax evolution | Low | Pin to known REAPER version |
| Performance with large themes | Medium | Lazy evaluation, caching |
| User confusion with Polish notation | Medium | Visual expression builder |

---

## Estimated Timeline (Effort-Based)

**Note**: No calendar dates - effort measured in "focused sessions"

| Milestone | Sessions | Cumulative |
|-----------|----------|------------|
| Element drag/resize | 2-3 | 2-3 |
| Property editing | 2-3 | 4-6 |
| Export basics | 1-2 | 5-8 |
| Context variable UI | 2-3 | 7-11 |
| Expression editing | 4-6 | 11-17 |
| Full export | 3-5 | 14-22 |
| Polish & edge cases | 3-5 | 17-27 |

**Current session count**: ~3 sessions completed

---

## Recommendation

**Start with Path C (Hybrid Approach)**

1. **Immediate focus**: Element interaction (drag/resize)
2. **Quick win**: Export single element as SET statement
3. **User feedback**: Test with real theme creators
4. **Iterate**: Add expression editing based on demand

This approach:
- Delivers value early
- Avoids over-engineering
- Allows course correction
- Builds on solid foundation already established

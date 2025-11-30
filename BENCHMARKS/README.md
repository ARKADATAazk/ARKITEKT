# ARKITEKT Performance Benchmarks

This directory contains performance analysis and optimization documentation for ARKITEKT widgets.

## Contents

- **BUTTON_OPTIMIZATION_2025-01.md** - Button primitive optimization analysis
- **scripts/** - Benchmark test scripts (Sandbox_10.lua)

## Philosophy

Performance optimization follows a **pragmatic approach**:

1. **Profile first** - Measure before optimizing
2. **Simple wins** - Prefer simple changes with big impact over complex micro-optimizations
3. **Maintainability** - Code clarity > micro-gains
4. **Context matters** - Widget performance is rarely the bottleneck in Reaper scripts

## Key Findings

### Where The Real Bottlenecks Are

In typical Reaper scripts, time is spent:

1. **Reaper API calls** (99% of time) - Crossing Lua→C boundary
2. **String operations in loops** - Allocations and concatenation
3. **File I/O** - Reading/writing project data
4. **Audio processing** - Working with media items/takes

### Where Widgets Fit

UI rendering is typically **<1% of total script time**, unless you're building a pure UI app (like DevKit, theme editors, config panels).

**Optimization priority:**
- 🔴 Cache Reaper API calls
- 🔴 Avoid string concat in loops
- 🟡 Localize frequently-used functions
- 🟢 Widget rendering optimizations

See `cookbook/LUA_PERFORMANCE_GUIDE.md` for Lua-level optimizations.

## Benchmark Results Summary

### Button Primitive (1000 buttons/frame)

| Optimization | Time (ms) | vs Baseline | Complexity | Kept? |
|--------------|-----------|-------------|------------|-------|
| Baseline (initial) | 14.0 | 14x slower | - | - |
| #1: Fixed ID conflicts | 14.0 | - | Low | ✅ YES (bug fix) |
| #2: Remove table reuse bug | 14.0 | - | Low | ✅ YES (bug fix) |
| #3: Cached result tables | 13.5 | -3.5% | Medium | ❌ NO (complexity not worth it) |
| #4: Remove config table copies | 9.0 | -35% | Low | ✅ YES (huge win, simple) |
| #5: Cache text measurements | 8.0 | -11% | Medium | ❌ NO (complexity not worth 1ms) |
| #6: Cache ID string | 8.0 | minimal | Low | ❌ NO (negligible gain) |
| #7: Inline color fast path | 8.0 | -6% | Medium | ❌ NO (code duplication) |
| **FINAL** | **9.0** | **9x slower** | **Low** | ✅ **Clean & fast** |

**vs ImGui.Button (native C):** 1.0ms baseline
**vs Minimal DrawList:** 2.0ms (just InvisibleButton + AddText)

### Final Optimizations Applied

Only kept simple, high-impact changes:

1. **Fixed ID conflicts** - Use `rawget()` to detect explicit opts vs defaults
2. **Fixed table reuse bug** - Fresh opts table per call instead of singleton
3. **Remove config table copying** - Use opts directly instead of copying 80 fields

**Net result:** 43% faster with minimal code complexity increase.

## Lessons Learned

### Worth It ✅

- **Simple, big wins** - Removing 80-field table copy was one line, massive gain
- **Bug fixes** - ID conflicts and table reuse were bugs that also improved performance
- **Profile-driven** - Benchmarking revealed table copying as the bottleneck

### Not Worth It ❌

- **Micro-optimizations** - Caching strings, text measurements added complexity for <1ms gain
- **Code duplication** - Inlining fast paths trades maintainability for tiny gains
- **Premature caching** - Labels rarely change, so cache invalidation overhead wasn't worth it

### Golden Rule

> **If the optimization requires explanation, it's probably not worth it.**

The final optimizations are self-evident:
- Don't copy 80 fields when you don't need to
- Use fresh tables to avoid state pollution
- Check for explicit values vs defaults

## Testing Your Own Optimizations

Use `scripts/Sandbox/Sandbox_10.lua` as a template for benchmarking:

1. **Test multiple scenarios** - ImGui baseline, ARKITEKT full, minimal DrawList
2. **Measure repeatedly** - Average over multiple samples
3. **Isolate changes** - Test one optimization at a time
4. **Calculate overhead** - Compare against minimal implementation

Remember: **8ms for 1000 buttons = 0.008ms per button**. A single `reaper.GetTrack()` call can cost 0.01-0.1ms. Optimize where it matters.

# Lua Performance Optimization - Complete Reference

## 🎯 Golden Rules

**Rule #1:** Don't optimize  
**Rule #2:** Don't optimize yet (for experts only)  
**Rule #3:** Profile before and after - measure everything

### Performance Targets
- **Idle CPU < 1%** = Fine
- **Idle CPU > 5%** = Problem - investigate
- **Stress test scale:** 10 → 50 → 100 → 500 → 10,000 items

---

## 🔥 Critical: Use Local Variables

**Impact:** 30% faster for function calls in loops

```lua
-- ❌ SLOW (4 global lookups per iteration)
for i = 1, 1000000 do
  local x = math.sin(i)
end

-- ✅ FAST (1 global lookup total)
local sin = math.sin
for i = 1, 1000000 do
  local x = sin(i)
end
```

**Why:** Local variables are stored in registers (up to 250 per function). Global access requires `GETGLOBAL` instructions. External locals (from enclosing functions) are also faster than globals.

---

## ⚡ Math Operations

### Floor Division
```lua
math.floor(x)  -- ❌ C function call (5-10% CPU in loops)
x//1           -- ✅ VM operation (near 0% CPU)
```

### Ceiling
```lua
math.ceil(n)        -- ❌ Expensive
(n + 1 - n%1)       -- ✅ Fast alternative
```

**Rule:** Cache all `math.*` functions as locals in hot paths

---

## 📝 String Operations

### Search vs Match
```lua
string.match(str, "pattern")  -- ❌ Allocates new string
string.find(str, "pattern")   -- ✅ Returns indices only
```

### String Creation in Loops
```lua
-- ❌ SLOW (creates 100 new strings)
for i = 1, 100 do
  local s = "prefix_" .. i
end

-- ✅ FAST (store in table, allocate once)
local strings = {}
for i = 1, 100 do
  strings[i] = "prefix_" .. i
end
```

### Large String Concatenation
```lua
-- ❌ QUADRATIC TIME (5 minutes for 5MB file)
local s = ""
for line in io.lines() do
  s = s .. line .. "\n"
end

-- ✅ LINEAR TIME (0.28 seconds for 5MB file)
local t = {}
for line in io.lines() do
  t[#t + 1] = line
end
local s = table.concat(t, "\n")
```

**Why:** Lua strings are immutable and internalized (single copy). Concatenation creates new strings. Use table as buffer.

---

## 📊 Table Operations

### Insert
```lua
table.insert(tbl, x)  -- ❌ Function call overhead
tbl[#tbl + 1] = x     -- ✅ Direct indexing
```

### Preallocation
```lua
-- ❌ SLOW (3 rehashes, 2.0 seconds for 1M iterations)
for i = 1, 1000000 do
  local a = {}
  a[1] = 1; a[2] = 2; a[3] = 3
end

-- ✅ FAST (0.7 seconds - presized)
for i = 1, 1000000 do
  local a = {true, true, true}
  a[1] = 1; a[2] = 2; a[3] = 3
end
```

**In C:** Use `lua_createtable(L, array_size, hash_size)` to preallocate

### Cache Length
```lua
for i = 1, #items do      -- ❌ Recalculates length
  process(items[i])
end

local n = #items          -- ✅ Cache once
for i = 1, n do
  process(items[i])
end
```

### Table Internals
- **Array part:** Integer keys 1 to n (>50% filled)
- **Hash part:** All other keys
- **Rehash triggers:** When table is full and needs new element
- **Sizes:** Always powers of 2

---

## 🔄 Function Calls

### Cache Global Functions
```lua
-- ❌ SLOW (looks up 'math' every call)
for i = 1, 1000 do
  x = math.sin(i) + math.cos(i)
end

-- ✅ FAST (single lookup)
local sin, cos = math.sin, math.cos
for i = 1, 1000 do
  x = sin(i) + cos(i)
end
```

**Why:** Function calls to `table.*`, `math.*`, `string.*` are expensive. Cache as locals.

---

## 🔁 Loop Optimization

### Avoid Creating Objects
```lua
-- ❌ SLOW (allocates 1000 tables)
for i = 1, 1000 do
  local point = {x = i, y = i*2}
  draw(point)
end

-- ✅ FAST (reuses single table)
local point = {x = 0, y = 0}
for i = 1, 1000 do
  point.x, point.y = i, i*2
  draw(point)
end
```

### Iterator Overhead
```lua
for k, v in pairs(t) do   -- ❌ Iterator overhead
  process(v)
end

local n = #keys           -- ✅ Direct indexing (if order known)
for i = 1, n do
  process(t[keys[i]])
end
```

### Move Constants Out
```lua
-- ❌ SLOW (creates table every iteration)
for i = 1, n do
  local t = {1, 2, 3, "hi"}
  work(t)
end

-- ✅ FAST (create once)
local t = {1, 2, 3, "hi"}
for i = 1, n do
  work(t)
end
```

---

## 🎨 Drawing (ImGui)

### Batch Draw Calls
```lua
-- ❌ SLOW (1000 draw calls, CPU→GPU overhead)
for i = 1, 1000 do
  r.ImGui_DrawList_AddLine(dl, x1, y1, x2, y2, color)
end

-- ✅ FAST (single batched call)
r.ImGui_DrawList_AddPolyline(dl, points, color)
```

**Note:** Even GPU-based drawing has CPU overhead for each call. Batch when possible.

---

## 🧠 Memory Management

### Reduce: Change Data Representation
```lua
-- 95 KB for 1M points
polyline = {{x=10.3, y=98.5}, {x=10.3, y=18.3}, ...}

-- 65 KB for 1M points
polyline = {{10.3, 98.5}, {10.3, 18.3}, ...}

-- 24 KB for 1M points (best)
polyline = {
  x = {10.3, 10.3, 15.0, ...},
  y = {98.5, 18.3, 98.5, ...}
}
```

### Reuse: Memoization
```lua
function memoize(f)
  local mem = {}
  setmetatable(mem, {__mode = "kv"})  -- weak table
  return function(x)
    local r = mem[x]
    if not r then
      r = f(x)
      mem[x] = r
    end
    return r
  end
end

loadstring = memoize(loadstring)  -- Cache compiled code
```

### Recycle: Coroutine Reuse
```lua
co = coroutine.create(function(f)
  while f do
    f = coroutine.yield(f())
  end
end)

-- Reuse same coroutine for multiple jobs
coroutine.resume(co, job1)
coroutine.resume(co, job2)
```

---

## 🗑️ Garbage Collection Tuning

### When to Stop GC
- **Batch programs:** Stop forever if no memory pressure
- **Time-critical sections:** Stop during critical periods
- **Idle callbacks:** Force collection when idle

```lua
collectgarbage("stop")           -- Stop collector
collectgarbage("collect")        -- Force full collection
collectgarbage("step", size)     -- Force incremental step
collectgarbage("count")          -- Get memory in KB
```

### Tuning Parameters
```lua
-- Faster collection (more CPU, less memory)
collectgarbage("setpause", 100)      -- Default: 200
collectgarbage("setstepmul", 200)    -- Default: 200

-- Slower collection (less CPU, more memory)
collectgarbage("setpause", 300)
collectgarbage("setstepmul", 100)
```

**Note:** Effects are hard to predict - profile carefully

### Table Shrinking
Tables only shrink during rehash. To force shrink:
```lua
for i = lim + 1, 2*lim do
  a[i] = nil  -- Insert many nils to trigger rehash
end
```
**Warning:** This is slow and unreliable - better to free the table entirely

---

## 🚫 Avoid Dynamic Compilation

```lua
-- ❌ VERY SLOW (1.4 seconds for 10K functions)
local a = {}
for i = 1, 10000 do
  a[i] = loadstring(string.format("return %d", i))
end

-- ✅ FAST (0.14 seconds with closures)
local function fk(k)
  return function() return k end
end
local a = {}
for i = 1, 10000 do
  a[i] = fk(i)
end
```

**Why:** Compilation is expensive. Use closures unless code is truly dynamic (user input).

---

## 🎯 Common Patterns

### String Processing: Use Indices
```lua
-- ❌ Creates substring
local match = string.match(text, "pattern")

-- ✅ Just returns position
local start, finish = string.find(text, "pattern")
local match = string.sub(text, start, finish)  -- Only if needed
```

### Table Traversal with Deletion
```lua
-- ✅ CORRECT (0.04s for 100K elements)
for k in pairs(t) do
  if should_delete(k) then
    t[k] = nil
  end
end

-- ❌ VERY SLOW (20s for 100K elements)
while true do
  local k = next(t)
  if not k then break end
  t[k] = nil
end
```

**Why:** `next()` without previous key searches from start each time. As elements are deleted, search gets longer.

---

## ⚠️ Common Pitfalls

### Ternary Pattern with Boolean Values
```lua
-- ❌ BROKEN (fails when value is false)
local enabled = opts.enabled ~= nil and opts.enabled or default
-- When opts.enabled = false: false or default → returns default!

-- ✅ CORRECT (handles false properly)
local enabled = opts.enabled == nil and default or opts.enabled
-- When opts.enabled = false: false → returns false
-- When opts.enabled = nil: default → returns default
```

**Why:** Lua's idiomatic ternary `cond and val or default` returns `default` when `val` is `false` because `false or default` evaluates to `default`. The inverted pattern `val == nil and default or val` correctly distinguishes between `nil` (use default) and `false` (use false).

**Use for:** Config merges, optional boolean parameters, any option that could legitimately be `false`.

---

## 📚 Best Practices Summary

1. **Profile first** - Don't guess, measure
2. **Local everything** - Cache globals, functions, lengths
3. **Preallocate tables** - Use constructors or `lua_createtable`
4. **Batch strings** - Use `table.concat` for large concatenations
5. **Reuse objects** - Move allocations out of loops
6. **Cache computations** - Memoize expensive functions
7. **Avoid `loadstring`** - Use closures instead
8. **Use `//1` not `math.floor`** - In hot loops
9. **Use `string.find` not `string.match`** - When just searching
10. **Batch draw calls** - Use polyline/polygon over individual lines

---

## 📖 Resources

- [Lua Performance Tips (PDF)](https://www.lua.org/gems/sample.pdf) - Roberto Ierusalimschy
- Profile with `reaper.time_precise()` in REAPER
- Use stress testing: 10 → 100 → 1,000 → 10,000 items

**Remember:** Premature optimization is the root of all evil. Profile, measure, then optimize.
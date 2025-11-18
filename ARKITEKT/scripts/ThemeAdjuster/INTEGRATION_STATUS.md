# Theme Adjuster - Integration Status & Quick Reference

## ✅ WHAT'S WORKING NOW

### Global Color Controls (100% Complete)
**File:** `ui/views/global_view.lua`

```lua
-- All sliders connected to REAPER:
- Gamma: -1000 (reversed direction, 0.50-2.00)
- Highlights: -1003 (-2.00 to +2.00)
- Midtones: -1002 (-2.00 to +2.00)
- Shadows: -1001 (-2.00 to +2.00)
- Saturation: -1004 (0%-200%)
- Tint: -1005 (-180° to +180°)
- Affect Project Colors: -1006 (checkbox)
```

**Test it:**
1. Run ThemeAdjuster
2. Go to Global tab
3. Move any slider → REAPER theme updates immediately!

---

### TCP View (30% Complete)
**File:** `ui/views/tcp_view.lua`

**Working:**
- ✅ Layout buttons (A/B/C) switch layouts
- ✅ Apply Size buttons (100%/150%/200%) assign to tracks
- ✅ These spinners write to REAPER:
  - Indent (global)
  - Alignment (global)
  - Meter Loc (per-layout)

**Still TODO:** Apply same pattern to remaining spinners:
- tcp_LabelSize
- tcp_vol_size
- tcp_MeterSize
- tcp_InputSize
- tcp_sepSends
- tcp_fxparms_size
- tcp_recmon_size
- tcp_pan_size
- tcp_width_size

---

## 🔧 HOW TO FINISH INTEGRATION

### Pattern: Connect a Spinner to REAPER

**Find this:**
```lua
changed, new_idx = draw_spinner_row("Label Size", "tcp_LabelSize", self.tcp_LabelSize_idx, SPINNER_VALUES.tcp_LabelSize)
if changed then self.tcp_LabelSize_idx = new_idx end
```

**Replace with:**
```lua
changed, new_idx = draw_spinner_row("Label Size", "tcp_LabelSize", self.tcp_LabelSize_idx, SPINNER_VALUES.tcp_LabelSize)
if changed then
  self.tcp_LabelSize_idx = new_idx
  local value = ThemeParams.get_spinner_value('tcp_LabelSize', new_idx)
  ThemeParams.set_param('tcp_LabelSize', value, true)
end
```

**That's it!** The spinner now:
1. Updates local state
2. Converts spinner index → theme value
3. Writes to REAPER theme
4. REAPER refreshes automatically

---

### Pattern: Connect Visibility Checkboxes

**Current code (tcp_view.lua around line 350+):**
```lua
-- Find the visibility table section with checkboxes
for col_idx, col in ipairs(VISIBILITY_COLUMNS) do
  local is_checked = (self.visibility[elem.id] & col.bit) ~= 0
  if Checkbox.draw_at_cursor(ctx, "", is_checked) then
    -- TODO: Toggle bit and write to theme
  end
end
```

**Replace with:**
```lua
for col_idx, col in ipairs(VISIBILITY_COLUMNS) do
  local is_checked = ThemeParams.is_flag_set(elem.id, col.bit)
  if Checkbox.draw_at_cursor(ctx, "", is_checked) then
    ThemeParams.toggle_flag(elem.id, col.bit)
    -- Reload to sync UI
    local param = ThemeParams.get_param(elem.id)
    if param then self.visibility[elem.id] = param.value end
  end
end
```

---

## 📋 REMAINING TASKS BY VIEW

### tcp_view.lua
- [ ] Add ThemeParams writes to ~9 remaining spinners (copy/paste pattern)
- [ ] Connect visibility flag checkboxes (4 columns × 12 elements = 48 checkboxes)

### mcp_view.lua
- [ ] Add `local ThemeParams = require('ThemeAdjuster.core.theme_params')`
- [ ] Update `load_from_theme()` (same pattern as tcp_view)
- [ ] Update layout button handlers
- [ ] Update "Apply Size" handlers
- [ ] Connect all spinners
- [ ] Connect visibility checkboxes

### envelope_view.lua
- [ ] Same pattern as tcp_view (simpler - fewer spinners)

### transport_view.lua
- [ ] Same pattern as tcp_view (simpler - fewer spinners)

---

## 🧪 TESTING CHECKLIST

### Test Global View
- [ ] Move gamma slider → theme brightness changes
- [ ] Move highlights → bright areas adjust
- [ ] Move midtones → mid-tones adjust
- [ ] Move shadows → dark areas adjust
- [ ] Move saturation → colors intensify/desaturate
- [ ] Move tint → color temperature shifts
- [ ] Toggle "affect project colors" → state saves

### Test TCP View
- [ ] Click Layout B → spinner values change
- [ ] Click Layout A → spinner values revert
- [ ] Change "Indent" spinner → TCP indent changes in REAPER
- [ ] Click "150%" → selected tracks use Layout A at 150%
- [ ] Change remaining spinners → TCP updates (after integration)

### Test Layout Persistence
- [ ] Switch to Layout B
- [ ] Change a spinner value
- [ ] Switch to Layout A (should be different)
- [ ] Switch back to Layout B (should remember change)
- [ ] Restart REAPER → changes persist

---

## 🚀 QUICKSTART FOR COMPLETING INTEGRATION

1. **Copy the working spinner pattern** from tcp_view.lua lines 290-309
2. **Find each spinner** with only `if changed then self.XXX_idx = new_idx end`
3. **Replace** with the 4-line pattern (update idx, get value, set param)
4. **Test** each spinner as you go
5. **Commit** when a section works

**Estimated time:** ~2 hours to finish all spinners and checkboxes

---

## 📚 API REFERENCE

```lua
-- Get parameter for current layout
local param = ThemeParams.get_param('tcp_LabelSize')
-- Returns: {index, name, desc, value, default, min, max}

-- Set parameter (writes to theme)
ThemeParams.set_param('tcp_LabelSize', 80, true)
-- true = persist immediately, false = defer until mouse-up

-- Get spinner index from theme value
local idx = ThemeParams.get_spinner_index('tcp_LabelSize', 80)
-- Returns: 3 (for value 80 in the spinner list)

-- Get theme value from spinner index
local value = ThemeParams.get_spinner_value('tcp_LabelSize', 3)
-- Returns: 80

-- Layout management
ThemeParams.set_active_layout('tcp', 'B')
local layout = ThemeParams.get_active_layout('tcp')  -- Returns: 'B'

-- Apply layout to tracks
ThemeParams.apply_layout_to_tracks('tcp', 'A', '150%_')
-- Sets selected tracks to Layout A at 150%

-- Visibility flags (bitwise)
ThemeParams.toggle_flag('tcp_Record_Arm', 1)  -- Toggle bit 1
local is_set = ThemeParams.is_flag_set('tcp_Record_Arm', 1)  -- Check bit
```

---

## 🎯 PRIORITY ORDER

1. **Finish TCP spinners** (most visible, easy to test)
2. **Add TCP visibility checkboxes** (demonstrates bitwise flags)
3. **Integrate MCP view** (copy TCP pattern)
4. **Integrate Envelope/Transport** (simpler, fewer controls)

---

## 💡 TIPS

- **Test incrementally**: Connect 1-2 spinners, test, commit
- **Watch REAPER**: Changes should appear instantly in TCP/MCP
- **Check console**: ThemeParams logs errors if parameters fail
- **Use Default 6.0**: Reference the uploaded script for correct parameter names
- **Global vs Layout**: Remember indent/alignment affect ALL layouts

---

## 🐛 COMMON ISSUES

**Issue:** Spinner changes don't update theme
**Fix:** Check you're calling `ThemeParams.set_param()` not just updating `self.XXX_idx`

**Issue:** Layout switch doesn't change values
**Fix:** Ensure `ThemeParams.set_active_layout()` is called before `self:load_from_theme()`

**Issue:** "Parameter not found" in console
**Fix:** Check parameter name matches exactly (case-sensitive)

**Issue:** Changes don't persist after REAPER restart
**Fix:** Ensure 3rd parameter to `set_param()` is `true` (persist=true)

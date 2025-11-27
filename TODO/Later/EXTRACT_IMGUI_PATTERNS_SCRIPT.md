# Extract ImGui Patterns Script

## Purpose

Programmatically extract AI-friendly pattern summaries from massive ImGui reference files (22K lines → 500 line summaries).

**Why programmatic:**
- ✅ Repeatable when ImGui updates
- ✅ No manual errors
- ✅ Maintainable and documented
- ✅ Can evolve extraction logic

## Location

`devtools/extract_imgui_patterns.py` (or `.lua`)

## Input Files

```
helpers/
├── ReaImGui_Demo.lua     # 439KB - Extract patterns
└── imgui_defs.lua        # 824KB, 22K lines - Extract signatures
```

## Output Files

```
reference/imgui/
├── patterns/
│   ├── INDEX.md
│   ├── widgets.md
│   ├── menus.md
│   ├── popups.md
│   ├── tables.md
│   ├── layout.md
│   └── begin_end.md
└── signatures/
    ├── INDEX.md
    ├── widgets.md
    ├── containers.md
    └── utilities.md
```

---

## Part 1: Extract Signatures from imgui_defs.lua

### What to Extract

From 22,000 lines of LuaCATS definitions, extract:
- Function names
- Parameter types and names
- Return types
- Brief descriptions

### Example Input (imgui_defs.lua)

```lua
--- @param ctx ImGui_Context
--- @param label string
--- @param size_w? number
--- @param size_h? number
--- @return boolean retval
function ImGui.Button(ctx, label, size_w, size_h) end

--- @param ctx ImGui_Context
--- @param label string
--- @param v boolean
--- @return boolean retval
--- @return boolean v
function ImGui.Checkbox(ctx, label, v) end
```

### Desired Output (signatures/widgets.md)

```markdown
# Widget Signatures

## Button
```lua
Button(ctx, label) -> boolean
Button(ctx, label, size_x, size_y) -> boolean
```

**Parameters:**
- `ctx` - ImGui context
- `label` - Button text
- `size_x`, `size_y` - Optional size

**Returns:** `boolean` - True if clicked

---

## Checkbox
```lua
Checkbox(ctx, label, checked) -> boolean, boolean
```

**Parameters:**
- `ctx` - ImGui context
- `label` - Checkbox label
- `checked` - Current state

**Returns:** `boolean, boolean` - (changed, new_value)
```

### Extraction Logic (Python)

```python
import re

def extract_function_signature(lines, start_idx):
    """Extract function signature from LuaCATS annotations"""
    annotations = []
    i = start_idx

    # Collect --- comment lines (annotations)
    while i < len(lines) and lines[i].strip().startswith('---'):
        annotations.append(lines[i].strip()[3:].strip())
        i += 1

    # Get function definition
    if i < len(lines) and 'function' in lines[i]:
        func_line = lines[i].strip()

        # Parse: function ImGui.Button(ctx, label, size_w, size_h) end
        match = re.match(r'function\s+ImGui\.(\w+)\((.*?)\)', func_line)
        if match:
            name = match.group(1)
            params = [p.strip() for p in match.group(2).split(',')]

            # Parse @return annotations
            returns = [a for a in annotations if '@return' in a]

            return {
                'name': name,
                'params': params,
                'returns': returns,
                'annotations': annotations
            }

    return None

def categorize_function(name):
    """Categorize function by name pattern"""
    if name in ['Button', 'Checkbox', 'InputText', 'Slider', 'SliderInt',
                'SliderFloat', 'Combo', 'Selectable']:
        return 'widgets'
    elif name in ['BeginChild', 'BeginGroup', 'BeginMenuBar', 'BeginMenu']:
        return 'containers'
    elif name in ['Text', 'SameLine', 'Separator', 'Spacing']:
        return 'utilities'
    return 'other'

def extract_signatures(imgui_defs_path):
    """Main extraction function"""
    with open(imgui_defs_path, 'r') as f:
        lines = f.readlines()

    functions = {'widgets': [], 'containers': [], 'utilities': [], 'other': []}

    for i, line in enumerate(lines):
        if line.strip().startswith('function ImGui.'):
            sig = extract_function_signature(lines, i - 10)  # Look back for annotations
            if sig:
                category = categorize_function(sig['name'])
                functions[category].append(sig)

    return functions

def generate_markdown(functions, category):
    """Generate markdown for a category"""
    md = f"# {category.title()} Signatures\n\n"

    for func in sorted(functions[category], key=lambda f: f['name']):
        md += f"## {func['name']}\n\n"
        md += "```lua\n"

        # Simplified signature
        params = ', '.join(func['params'])
        returns = ' -> ' + ', '.join(r.split()[1] for r in func['returns'] if '@return' in r)
        md += f"{func['name']}({params}){returns}\n"
        md += "```\n\n"

    return md
```

---

## Part 2: Extract Patterns from ReaImGui_Demo.lua

### What to Extract

From demo file, extract:
- Section markers (e.g., "DemoWindowWidgets")
- Widget usage examples
- Begin/End patterns
- Real-world code snippets

### Example Input (ReaImGui_Demo.lua)

```lua
-- [SECTION] DemoWindowWidgetsBasic()

function demo.DemoWindowWidgetsBasic()
  -- Basic Button
  if ImGui.Button(ctx, 'Click Me') then
    clicked_count = clicked_count + 1
  end
  ImGui.SameLine(ctx)
  ImGui.Text(ctx, ('Clicked %d times'):format(clicked_count))

  -- Button with size
  if ImGui.Button(ctx, 'Wide Button', 200, 30) then
    print('Wide button clicked')
  end
end
```

### Desired Output (patterns/widgets.md)

```markdown
# Widget Patterns

Extracted from ReaImGui_Demo.lua

## Button

### Basic Button
```lua
if ImGui.Button(ctx, 'Click Me') then
    clicked_count = clicked_count + 1
end
```

**Pattern:** Returns boolean on click

### Button with Size
```lua
if ImGui.Button(ctx, 'Wide Button', 200, 30) then
    print('Wide button clicked')
end
```

**Signature:** `Button(ctx, label, width, height)`

### ARKITEKT Equivalent
```lua
if Ark.Button.draw(ctx, "Click Me").clicked then
    clicked_count = clicked_count + 1
end

-- Or with opts
Ark.Button.draw(ctx, {
    label = "Wide Button",
    width = 200,
    height = 30,
    on_click = function()
        print('Wide button clicked')
    end
})
```
```

### Extraction Logic (Python)

```python
import re

def find_section(lines, section_name):
    """Find section markers in demo file"""
    section_pattern = re.compile(r'-- \[SECTION\] (.+)')

    for i, line in enumerate(lines):
        match = section_pattern.match(line.strip())
        if match and section_name in match.group(1):
            return i
    return -1

def extract_code_block(lines, start_idx, widget_name):
    """Extract code block for a widget"""
    blocks = []
    in_block = False
    current_block = []

    for i in range(start_idx, min(start_idx + 500, len(lines))):
        line = lines[i]

        # Detect widget usage
        if widget_name in line and ('ImGui.' + widget_name) in line:
            in_block = True
            current_block = []

        if in_block:
            current_block.append(line.rstrip())

            # End of block detection (empty line or new widget)
            if not line.strip() or (len(current_block) > 10):
                if len(current_block) >= 3:  # Minimum useful block
                    blocks.append('\n'.join(current_block))
                in_block = False

    return blocks

def extract_patterns(demo_path):
    """Main pattern extraction"""
    with open(demo_path, 'r') as f:
        lines = f.readlines()

    patterns = {}

    # Extract widget patterns
    widgets_section = find_section(lines, 'DemoWindowWidgets')
    if widgets_section >= 0:
        patterns['Button'] = extract_code_block(lines, widgets_section, 'Button')
        patterns['Checkbox'] = extract_code_block(lines, widgets_section, 'Checkbox')
        # ... more widgets

    return patterns
```

---

## Script Structure

```python
#!/usr/bin/env python3
"""
Extract ImGui patterns and signatures for AI-friendly reference.

Usage:
    python devtools/extract_imgui_patterns.py

Output:
    reference/imgui/patterns/*.md
    reference/imgui/signatures/*.md
"""

import os
import re
from pathlib import Path

def main():
    # Paths
    imgui_defs = Path('helpers/imgui_defs.lua')
    demo_file = Path('helpers/ReaImGui_Demo.lua')
    output_dir = Path('reference/imgui')

    print("Extracting ImGui patterns...")

    # Extract signatures
    print("  [1/3] Parsing imgui_defs.lua (22K lines)...")
    signatures = extract_signatures(imgui_defs)

    print("  [2/3] Parsing ReaImGui_Demo.lua (439KB)...")
    patterns = extract_patterns(demo_file)

    # Generate markdown
    print("  [3/3] Generating markdown files...")
    generate_all_markdown(signatures, patterns, output_dir)

    print("✓ Done! Check reference/imgui/")

if __name__ == '__main__':
    main()
```

---

## Manual First Pass (Recommended)

### Step 1: Manually Extract ONE Widget

**You do this manually first:**
1. Open `helpers/ReaImGui_Demo.lua`
2. Search for "Button" examples
3. Copy 2-3 good examples
4. Create `reference/imgui/patterns/widgets.md`
5. Format as shown above

**Benefits:**
- See what patterns are useful
- Understand the structure
- Define the template

### Step 2: Script Replicates Your Work

Once you have **one manual example** (Button):
1. I help write script that extracts similar patterns
2. Script runs on all widgets
3. You review and adjust

### Step 3: Iterate

- Run script
- Review output
- Adjust extraction logic
- Re-run

---

## Where to Start

**Recommendation:**
1. **Manually extract Button patterns** (30 minutes)
   - Open ReaImGui_Demo.lua
   - Find 3 good Button examples
   - Create `patterns/widgets.md` template
   - Add ARKITEKT equivalent

2. **I help write the script** (based on your template)
   - Python script in `devtools/`
   - Replicates your manual work
   - Runs on all widgets

3. **Run and refine**
   - Execute script
   - Review output quality
   - Adjust patterns

---

## Deliverables

```
devtools/
└── extract_imgui_patterns.py    # Main extraction script

reference/imgui/
├── patterns/
│   ├── INDEX.md                 # Generated by script
│   ├── widgets.md               # Generated by script
│   ├── menus.md                 # Generated by script
│   └── ...
└── signatures/
    ├── INDEX.md                 # Generated by script
    └── widgets.md               # Generated by script
```

---

## Benefits

- ✅ **Repeatable** - Run when ImGui updates
- ✅ **Maintainable** - Script is self-documenting
- ✅ **Consistent** - All patterns formatted the same
- ✅ **Fast** - Regenerate in seconds
- ✅ **Accurate** - No manual copy-paste errors

---

## Next Steps

1. **You**: Manually extract Button pattern (template)
2. **Me**: Help write Python script to replicate
3. **You**: Run script, review output
4. **Both**: Iterate until perfect

Want to start with the manual Button extraction first?

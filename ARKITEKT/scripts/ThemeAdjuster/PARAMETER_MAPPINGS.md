# Theme Parameter Mappings

ThemeAdjuster supports custom theme parameters through JSON mapping files. This allows any theme to work with ThemeAdjuster, even if it wasn't explicitly designed for it.

## How It Works

1. **Auto-Discovery**: ThemeAdjuster scans all parameters exposed by your theme
2. **JSON Export**: Click "Export to JSON" to save parameter metadata
3. **Customization**: Edit the JSON to organize and describe parameters
4. **Auto-Loading**: ThemeAdjuster automatically loads the JSON on startup

## File Location

Mapping files should be placed in your `ColorThemes/` directory alongside your theme:

```
REAPER/ColorThemes/
  MyTheme.ReaperThemeZip    # Your theme
  MyTheme.json              # Companion mappings (same base name)
```

## JSON Format

### Basic Structure

```json
{
  "theme_name": "MyAwesomeTheme",
  "version": "1.0.0",
  "created_at": "2025-01-18 12:00:00",
  "description": "Parameter mappings for MyAwesomeTheme",
  "params": {
    "parameter_name": {
      "index": 42,
      "display_name": "Custom Display Name",
      "category": "Track Panel",
      "type": "spinner",
      "min": 1,
      "max": 7,
      "default": 1,
      "description": "Human-readable description"
    }
  }
}
```

### Example: Real Parameters

```json
{
  "theme_name": "MyCustomTheme",
  "version": "1.0.0",
  "created_at": "2025-01-18 14:30:00",
  "description": "Auto-generated parameter mappings for Theme Adjuster",
  "params": {
    "tcp_custom_meter": {
      "index": 15,
      "display_name": "TCP Meter Size",
      "category": "Track Panel",
      "type": "spinner",
      "min": 1,
      "max": 7,
      "default": 4,
      "description": "Controls the size of track panel meters"
    },
    "mcp_custom_fader": {
      "index": 28,
      "display_name": "MCP Fader Width",
      "category": "Mixer Panel",
      "type": "slider",
      "min": 20,
      "max": 200,
      "default": 60,
      "description": "Width of mixer faders in pixels"
    },
    "glb_custom_highlight": {
      "index": 5,
      "display_name": "Highlight Color Intensity",
      "category": "Global",
      "type": "toggle",
      "min": 0,
      "max": 1,
      "default": 1,
      "description": "Enable/disable highlight color effect"
    }
  }
}
```

## Field Reference

### Root Level

| Field | Type | Description |
|-------|------|-------------|
| `theme_name` | string | Name of the theme (matches .ReaperThemeZip filename) |
| `version` | string | Mapping file version (semantic versioning) |
| `created_at` | string | ISO timestamp of creation |
| `description` | string | Human-readable description |
| `params` | object | Parameter definitions (key = parameter name) |
| `assignments` | object | Tab assignments (param_name -> tab assignments) |

### Parameter Definition

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `index` | number | ✅ | REAPER parameter index |
| `display_name` | string | ✅ | Human-readable name shown in UI |
| `category` | string | ✅ | Grouping category |
| `type` | string | ✅ | Control type: `toggle`, `spinner`, `slider` |
| `min` | number | ✅ | Minimum value |
| `max` | number | ✅ | Maximum value |
| `default` | number | ✅ | Default value |
| `description` | string | ❌ | Optional detailed description |

### Control Types

- **toggle**: Boolean (0/1) - Renders as checkbox
- **spinner**: Discrete values (≤10 options) - Renders as spinner/dropdown
- **slider**: Continuous range - Renders as slider

### Categories

Common categories (auto-detected by prefix):

- `Track Panel` - `tcp_*` parameters
- `Mixer Panel` - `mcp_*` parameters
- `Envelope Panel` - `envcp_*` parameters
- `Transport` - `trans_*` parameters
- `Global` - `glb_*` parameters
- `Uncategorized` - Other parameters

## Workflow

### For Theme Authors

1. Load your theme in REAPER
2. Open ThemeAdjuster → Additional tab
3. Click "Export to JSON"
4. Edit `ColorThemes/YourTheme.json` to customize names/descriptions
5. Distribute the JSON alongside your theme

### For Theme Users

1. Extract theme to `ColorThemes/`
2. If JSON included, extract it to `ColorThemes/` too
3. Load theme in REAPER
4. Open ThemeAdjuster - parameters auto-load!

### For Advanced Users

1. Export base JSON from Additional tab
2. Manually edit to organize parameters
3. Add custom `display_name`, `description`, `category`
4. Share your improved mappings with the community

## Tab Assignments

Parameters can be assigned to specific tabs using the assignable chips in the Additional tab UI. This allows you to organize parameters and make them available in their respective tab views.

### Assignments Format

```json
{
  "theme_name": "MyTheme",
  "params": { ... },
  "assignments": {
    "tcp_custom_meter": {
      "TCP": true,
      "MCP": false,
      "ENVCP": false,
      "TRANS": false,
      "GLOBAL": false
    },
    "mcp_custom_fader": {
      "TCP": false,
      "MCP": true,
      "ENVCP": false,
      "TRANS": false,
      "GLOBAL": false
    }
  }
}
```

### Using Assignments

1. **In Additional Tab**: Click the colored chips (TCP, MCP, ENV, TRN, GLB) to assign parameters
2. **Chip Colors**:
   - Blue: TCP (Track Control Panel)
   - Pink: MCP (Mixer Control Panel)
   - Green: ENVCP (Envelope Control Panel)
   - Orange: TRANS (Transport)
   - Purple: GLOBAL (Global)
3. **Persistence**: Assignments are automatically saved to the JSON file
4. **Future Integration**: Assigned parameters will appear in their respective tabs

## Future Enhancements

- **Tab Integration**: Make assigned params appear in TCP/MCP/etc tabs
- **Custom Colors**: Per-parameter color coding
- **Tooltips**: Rich tooltip customization
- **Community Repository**: Centralized mapping database

## Example Use Cases

### Use Case 1: Theme with Custom Meters

```json
{
  "params": {
    "tcp_meter_custom_size": {
      "display_name": "Custom Meter Size",
      "category": "Metering",
      "type": "spinner",
      "description": "Adjusts the custom meter display algorithm"
    }
  }
}
```

### Use Case 2: Unique Transport Controls

```json
{
  "params": {
    "trans_playhead_style": {
      "display_name": "Playhead Style",
      "category": "Transport",
      "type": "spinner",
      "description": "Visual style of the playhead: Classic, Modern, Minimal"
    }
  }
}
```

## Troubleshooting

**Q: JSON not loading?**
- Verify filename matches theme: `MyTheme.ReaperThemeZip` → `MyTheme.json`
- Check JSON syntax (use JSONLint.com)
- Ensure file is in `ColorThemes/` directory

**Q: Parameters not appearing?**
- Check `index` values match REAPER's parameter indices
- Verify parameter actually exists in theme
- Look in Additional tab for raw discovered params

**Q: Wrong control type?**
- Edit `type` field: `toggle`, `spinner`, or `slider`
- Ensure `min`/`max` match your needs
- Toggles must have `min: 0, max: 1`

## Contributing

Share your theme mappings:
1. Fork the ARKITEKT-Project repository
2. Add `ColorThemes/YourTheme.json` to mappings directory
3. Submit a pull request

## License

Mapping files are public domain - share freely!

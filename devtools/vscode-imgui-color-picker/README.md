# ImGui Hex Byte Color Picker

VSCode extension that enables color picker support for ImGui's hex byte color format.

## Features

- **Color Preview**: See inline color previews for ImGui hex byte colors
- **Color Picker**: Click on colors to open VSCode's color picker
- **Format Preservation**: Automatically formats colors back to `0xRRGGBBAA` format

## Supported Format

This extension matches the ImGui/ReaImGui color format:

```lua
0xRRGGBBAA
```

Where:
- `RR` = Red channel (00-FF)
- `GG` = Green channel (00-FF)
- `BB` = Blue channel (00-FF)
- `AA` = Alpha channel (00-FF)

### Examples

```lua
0xFF0000FF  -- Red with full alpha
0x00FF00FF  -- Green with full alpha
0x0000FFFF  -- Blue with full alpha
0xFFFFFFFF  -- White with full alpha
0x000000FF  -- Black with full alpha
0xFFFFFF80  -- White with 50% alpha
0xFF000080  -- Red with 50% alpha
```

## Configuration

You can customize which file types enable the color picker:

```json
{
  "vscode-imgui-color-picker.languages": ["lua", "cpp", "c"]
}
```

Default: `["lua"]`

## Installation

### From Source

1. Navigate to the extension directory:
   ```bash
   cd devtools/vscode-imgui-color-picker
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Compile the extension:
   ```bash
   npm run compile
   ```

4. Package the extension:
   ```bash
   npm run package
   ```

5. Install in VSCode:
   - Press `Cmd+Shift+P` (Mac) or `Ctrl+Shift+P` (Windows/Linux)
   - Type "Extensions: Install from VSIX"
   - Select the generated `.vsix` file

### Development

To test during development:

1. Open the extension directory in VSCode
2. Press `F5` to open a new VSCode window with the extension loaded
3. Open a `.lua` file with ImGui hex byte colors
4. Color previews should appear automatically

## How It Works

The extension uses VSCode's color provider API to:

1. **Detect Colors**: Regex pattern matches `0x[0-9A-Fa-f]{8}` (8 hex digits after `0x`)
2. **Parse Colors**: Extracts RGBA components from the hex bytes
3. **Display Preview**: Shows color decorations inline
4. **Provide Picker**: Opens VSCode's native color picker when clicked
5. **Update Value**: Converts selected color back to `0xRRGGBBAA` format

## Forked From

This extension is inspired by [vscode-color-picker](https://github.com/krispy-snacc/vscode-color-picker) but adapted specifically for ImGui's hex byte format instead of CSS colors.

## License

MIT

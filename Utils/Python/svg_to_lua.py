#!/usr/bin/env python3
"""
SVG to Lua Path Converter for ReaImGui
Converts SVG path elements to ReaImGui DrawList API calls

Usage:
    python svg_to_lua.py input.svg [--output output.lua] [--function-name draw_icon] [--normalize]

Example:
    python svg_to_lua.py arkitekt_logo.svg --function-name draw_arkitekt_accurate --normalize
"""

import argparse
import re
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import List, Tuple, Optional
import sys


class SVGPathParser:
    """Parse SVG path data and convert to Lua DrawList commands."""

    def __init__(self, normalize=True):
        self.normalize = normalize
        self.min_x = float('inf')
        self.min_y = float('inf')
        self.max_x = float('-inf')
        self.max_y = float('-inf')

    def parse_path_data(self, d: str) -> List[Tuple[str, List[float]]]:
        """Parse SVG path d attribute into commands and coordinates."""
        commands = []

        # SVG path command pattern
        cmd_pattern = r'([MmLlHhVvCcSsQqTtAaZz])'

        # Split by commands but keep the command character
        parts = re.split(cmd_pattern, d)
        parts = [p.strip() for p in parts if p.strip()]

        i = 0
        current_cmd = None

        while i < len(parts):
            part = parts[i]

            # Check if it's a command
            if re.match(cmd_pattern, part):
                current_cmd = part
                i += 1
                continue

            # Parse coordinates for current command
            if current_cmd:
                coords = self._parse_coordinates(part)
                commands.append((current_cmd, coords))

            i += 1

        return commands

    def _parse_coordinates(self, coord_str: str) -> List[float]:
        """Parse coordinate string into list of floats."""
        # Handle both comma and space separated, including negative numbers
        coord_str = coord_str.replace(',', ' ')
        coord_str = re.sub(r'([0-9])-', r'\1 -', coord_str)  # "10-5" -> "10 -5"
        coords = [float(x) for x in coord_str.split() if x]
        return coords

    def _update_bounds(self, x: float, y: float):
        """Update bounding box."""
        self.min_x = min(self.min_x, x)
        self.min_y = min(self.min_y, y)
        self.max_x = max(self.max_x, x)
        self.max_y = max(self.max_y, y)

    def commands_to_lua(self, commands: List[Tuple[str, List[float]]],
                       fill_color: Optional[str] = None,
                       stroke_color: Optional[str] = None,
                       stroke_width: float = 1.0) -> List[str]:
        """Convert path commands to Lua DrawList API calls."""
        lua_lines = []

        # Track current position for relative commands
        current_x, current_y = 0.0, 0.0
        last_ctrl_x, last_ctrl_y = 0.0, 0.0  # For smooth bezier commands

        # Start new path
        lua_lines.append("  ImGui.DrawList_PathClear(dl)")

        for cmd, coords in commands:
            if cmd == 'M':  # Moveto (absolute)
                for i in range(0, len(coords), 2):
                    x, y = coords[i], coords[i+1]
                    self._update_bounds(x, y)
                    if self.normalize:
                        lua_lines.append(f"  ImGui.DrawList_PathLineTo(dl, x + s*{x:.6f}, y + s*{y:.6f})")
                    else:
                        lua_lines.append(f"  ImGui.DrawList_PathLineTo(dl, x + s*({x}/{self.max_x:.6f}), y + s*({y}/{self.max_y:.6f}))")
                    current_x, current_y = x, y

            elif cmd == 'm':  # Moveto (relative)
                for i in range(0, len(coords), 2):
                    dx, dy = coords[i], coords[i+1]
                    current_x += dx
                    current_y += dy
                    self._update_bounds(current_x, current_y)
                    if self.normalize:
                        lua_lines.append(f"  ImGui.DrawList_PathLineTo(dl, x + s*{current_x:.6f}, y + s*{current_y:.6f})")
                    else:
                        lua_lines.append(f"  ImGui.DrawList_PathLineTo(dl, x + s*({current_x}/{self.max_x:.6f}), y + s*({current_y}/{self.max_y:.6f}))")

            elif cmd == 'L':  # Lineto (absolute)
                for i in range(0, len(coords), 2):
                    x, y = coords[i], coords[i+1]
                    self._update_bounds(x, y)
                    if self.normalize:
                        lua_lines.append(f"  ImGui.DrawList_PathLineTo(dl, x + s*{x:.6f}, y + s*{y:.6f})")
                    else:
                        lua_lines.append(f"  ImGui.DrawList_PathLineTo(dl, x + s*({x}/{self.max_x:.6f}), y + s*({y}/{self.max_y:.6f}))")
                    current_x, current_y = x, y

            elif cmd == 'l':  # Lineto (relative)
                for i in range(0, len(coords), 2):
                    dx, dy = coords[i], coords[i+1]
                    current_x += dx
                    current_y += dy
                    self._update_bounds(current_x, current_y)
                    if self.normalize:
                        lua_lines.append(f"  ImGui.DrawList_PathLineTo(dl, x + s*{current_x:.6f}, y + s*{current_y:.6f})")
                    else:
                        lua_lines.append(f"  ImGui.DrawList_PathLineTo(dl, x + s*({current_x}/{self.max_x:.6f}), y + s*({current_y}/{self.max_y:.6f}))")

            elif cmd == 'H':  # Horizontal lineto (absolute)
                for x in coords:
                    self._update_bounds(x, current_y)
                    if self.normalize:
                        lua_lines.append(f"  ImGui.DrawList_PathLineTo(dl, x + s*{x:.6f}, y + s*{current_y:.6f})")
                    else:
                        lua_lines.append(f"  ImGui.DrawList_PathLineTo(dl, x + s*({x}/{self.max_x:.6f}), y + s*({current_y}/{self.max_y:.6f}))")
                    current_x = x

            elif cmd == 'h':  # Horizontal lineto (relative)
                for dx in coords:
                    current_x += dx
                    self._update_bounds(current_x, current_y)
                    if self.normalize:
                        lua_lines.append(f"  ImGui.DrawList_PathLineTo(dl, x + s*{current_x:.6f}, y + s*{current_y:.6f})")
                    else:
                        lua_lines.append(f"  ImGui.DrawList_PathLineTo(dl, x + s*({current_x}/{self.max_x:.6f}), y + s*({current_y}/{self.max_y:.6f}))")

            elif cmd == 'V':  # Vertical lineto (absolute)
                for y in coords:
                    self._update_bounds(current_x, y)
                    if self.normalize:
                        lua_lines.append(f"  ImGui.DrawList_PathLineTo(dl, x + s*{current_x:.6f}, y + s*{y:.6f})")
                    else:
                        lua_lines.append(f"  ImGui.DrawList_PathLineTo(dl, x + s*({current_x}/{self.max_x:.6f}), y + s*({y}/{self.max_y:.6f}))")
                    current_y = y

            elif cmd == 'v':  # Vertical lineto (relative)
                for dy in coords:
                    current_y += dy
                    self._update_bounds(current_x, current_y)
                    if self.normalize:
                        lua_lines.append(f"  ImGui.DrawList_PathLineTo(dl, x + s*{current_x:.6f}, y + s*{current_y:.6f})")
                    else:
                        lua_lines.append(f"  ImGui.DrawList_PathLineTo(dl, x + s*({current_x}/{self.max_x:.6f}), y + s*({current_y}/{self.max_y:.6f}))")

            elif cmd == 'C':  # Cubic bezier (absolute)
                for i in range(0, len(coords), 6):
                    cp1x, cp1y = coords[i], coords[i+1]
                    cp2x, cp2y = coords[i+2], coords[i+3]
                    x, y = coords[i+4], coords[i+5]
                    self._update_bounds(x, y)

                    if self.normalize:
                        lua_lines.append(f"  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*{cp1x:.6f}, y + s*{cp1y:.6f}, x + s*{cp2x:.6f}, y + s*{cp2y:.6f}, x + s*{x:.6f}, y + s*{y:.6f})")
                    else:
                        lua_lines.append(f"  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*({cp1x}/{self.max_x:.6f}), y + s*({cp1y}/{self.max_y:.6f}), x + s*({cp2x}/{self.max_x:.6f}), y + s*({cp2y}/{self.max_y:.6f}), x + s*({x}/{self.max_x:.6f}), y + s*({y}/{self.max_y:.6f}))")

                    last_ctrl_x, last_ctrl_y = cp2x, cp2y
                    current_x, current_y = x, y

            elif cmd == 'c':  # Cubic bezier (relative)
                for i in range(0, len(coords), 6):
                    cp1x = current_x + coords[i]
                    cp1y = current_y + coords[i+1]
                    cp2x = current_x + coords[i+2]
                    cp2y = current_y + coords[i+3]
                    x = current_x + coords[i+4]
                    y = current_y + coords[i+5]
                    self._update_bounds(x, y)

                    if self.normalize:
                        lua_lines.append(f"  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*{cp1x:.6f}, y + s*{cp1y:.6f}, x + s*{cp2x:.6f}, y + s*{cp2y:.6f}, x + s*{x:.6f}, y + s*{y:.6f})")
                    else:
                        lua_lines.append(f"  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*({cp1x}/{self.max_x:.6f}), y + s*({cp1y}/{self.max_y:.6f}), x + s*({cp2x}/{self.max_x:.6f}), y + s*({cp2y}/{self.max_y:.6f}), x + s*({x}/{self.max_x:.6f}), y + s*({y}/{self.max_y:.6f}))")

                    last_ctrl_x, last_ctrl_y = cp2x, cp2y
                    current_x, current_y = x, y

            elif cmd == 'Q':  # Quadratic bezier (absolute)
                for i in range(0, len(coords), 4):
                    cpx, cpy = coords[i], coords[i+1]
                    x, y = coords[i+2], coords[i+3]
                    self._update_bounds(x, y)

                    if self.normalize:
                        lua_lines.append(f"  ImGui.DrawList_PathBezierQuadraticCurveTo(dl, x + s*{cpx:.6f}, y + s*{cpy:.6f}, x + s*{x:.6f}, y + s*{y:.6f})")
                    else:
                        lua_lines.append(f"  ImGui.DrawList_PathBezierQuadraticCurveTo(dl, x + s*({cpx}/{self.max_x:.6f}), y + s*({cpy}/{self.max_y:.6f}), x + s*({x}/{self.max_x:.6f}), y + s*({y}/{self.max_y:.6f}))")

                    last_ctrl_x, last_ctrl_y = cpx, cpy
                    current_x, current_y = x, y

            elif cmd == 'q':  # Quadratic bezier (relative)
                for i in range(0, len(coords), 4):
                    cpx = current_x + coords[i]
                    cpy = current_y + coords[i+1]
                    x = current_x + coords[i+2]
                    y = current_y + coords[i+3]
                    self._update_bounds(x, y)

                    if self.normalize:
                        lua_lines.append(f"  ImGui.DrawList_PathBezierQuadraticCurveTo(dl, x + s*{cpx:.6f}, y + s*{cpy:.6f}, x + s*{x:.6f}, y + s*{y:.6f})")
                    else:
                        lua_lines.append(f"  ImGui.DrawList_PathBezierQuadraticCurveTo(dl, x + s*({cpx}/{self.max_x:.6f}), y + s*({cpy}/{self.max_y:.6f}), x + s*({x}/{self.max_x:.6f}), y + s*({y}/{self.max_y:.6f}))")

                    last_ctrl_x, last_ctrl_y = cpx, cpy
                    current_x, current_y = x, y

            elif cmd in ['Z', 'z']:  # Close path
                # Path will be closed by PathFillConvex or PathStroke with closed flag
                pass

            else:
                print(f"Warning: Unsupported SVG command '{cmd}' - skipping", file=sys.stderr)

        # Finish path with fill or stroke
        if fill_color:
            lua_lines.append(f"  ImGui.DrawList_PathFillConvex(dl, {fill_color})")
        if stroke_color:
            closed = "ImGui.DrawFlags_Closed" if any(cmd in ['Z', 'z'] for cmd, _ in commands) else "ImGui.DrawFlags_None"
            lua_lines.append(f"  ImGui.DrawList_PathStroke(dl, {stroke_color}, {closed}, {stroke_width} * dpi)")

        return lua_lines


def parse_svg_file(filepath: Path) -> List[Tuple[str, str, str, float]]:
    """
    Parse SVG file and extract path elements.
    Returns list of (path_d, fill, stroke, stroke_width) tuples.
    """
    tree = ET.parse(filepath)
    root = tree.getroot()

    # Handle SVG namespace
    ns = {'svg': 'http://www.w3.org/2000/svg'}

    paths = []

    # Find all path elements (with and without namespace)
    for path in root.findall('.//svg:path', ns) + root.findall('.//path'):
        d = path.get('d', '')
        fill = path.get('fill', 'none')
        stroke = path.get('stroke', 'none')
        stroke_width = float(path.get('stroke-width', '1'))

        if d:
            paths.append((d, fill, stroke, stroke_width))

    return paths


def generate_lua_function(svg_path: Path, function_name: str = "draw_icon", normalize: bool = True) -> str:
    """Generate complete Lua function from SVG file."""

    paths = parse_svg_file(svg_path)

    if not paths:
        raise ValueError(f"No paths found in SVG file: {svg_path}")

    parser = SVGPathParser(normalize=normalize)

    # First pass: collect all commands and calculate bounds
    all_commands = []
    for path_d, fill, stroke, stroke_width in paths:
        commands = parser.parse_path_data(path_d)
        all_commands.append((commands, fill, stroke, stroke_width))

    # Normalize coordinates if requested
    if normalize and parser.max_x > 0 and parser.max_y > 0:
        # Scale factor to normalize to 0-1 range
        width = parser.max_x - parser.min_x
        height = parser.max_y - parser.min_y
        max_dim = max(width, height)

        # Update parser for normalization
        parser.min_x /= max_dim
        parser.min_y /= max_dim
        parser.max_x /= max_dim
        parser.max_y /= max_dim

    # Generate Lua code
    lua_lines = [
        f"-- Auto-generated from {svg_path.name}",
        f"-- Normalized coordinates: {normalize}",
        f"-- Bounding box: ({parser.min_x:.4f}, {parser.min_y:.4f}) to ({parser.max_x:.4f}, {parser.max_y:.4f})",
        f"function M.{function_name}(ctx, x, y, size, color)",
        "  local dl = ImGui.GetWindowDrawList(ctx)",
        "  local dpi = ImGui.GetWindowDpiScale(ctx)",
        "  local s = size * dpi",
        ""
    ]

    # Process each path
    for idx, (commands, fill, stroke, stroke_width) in enumerate(all_commands):
        if idx > 0:
            lua_lines.append("")  # Blank line between paths

        lua_lines.append(f"  -- Path {idx + 1}")

        # Convert fill/stroke colors to Lua
        fill_color = "color" if fill not in ['none', 'transparent'] else None
        stroke_color = "color" if stroke not in ['none', 'transparent'] else None

        path_lua = parser.commands_to_lua(commands, fill_color, stroke_color, stroke_width)
        lua_lines.extend(path_lua)

    lua_lines.append("end")

    return '\n'.join(lua_lines)


def main():
    parser = argparse.ArgumentParser(
        description='Convert SVG path to ReaImGui Lua DrawList code',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Basic conversion
  python svg_to_lua.py icon.svg

  # With custom function name
  python svg_to_lua.py logo.svg --function-name draw_arkitekt_logo

  # Save to file
  python svg_to_lua.py icon.svg --output icon_generated.lua

  # Without normalization (keep original coordinates)
  python svg_to_lua.py icon.svg --no-normalize
        """
    )

    parser.add_argument('input', type=Path, help='Input SVG file')
    parser.add_argument('-o', '--output', type=Path, help='Output Lua file (default: stdout)')
    parser.add_argument('-f', '--function-name', default='draw_icon',
                       help='Lua function name (default: draw_icon)')
    parser.add_argument('--no-normalize', action='store_true',
                       help='Do not normalize coordinates to 0-1 range')

    args = parser.parse_args()

    if not args.input.exists():
        print(f"Error: File not found: {args.input}", file=sys.stderr)
        sys.exit(1)

    try:
        lua_code = generate_lua_function(
            args.input,
            args.function_name,
            normalize=not args.no_normalize
        )

        if args.output:
            # Add module wrapper
            full_code = [
                "-- @noindex",
                f"-- Generated from {args.input.name}",
                "package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path",
                "local ImGui = require 'imgui' '0.10'",
                "",
                "local M = {}",
                "",
                lua_code,
                "",
                "return M"
            ]

            args.output.write_text('\n'.join(full_code))
            print(f"Generated Lua code written to: {args.output}")
        else:
            print(lua_code)

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()

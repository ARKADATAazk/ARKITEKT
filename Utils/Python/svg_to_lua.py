#!/usr/bin/env python3
"""
SVG to Lua Path Converter for ReaImGui
Converts SVG paths to ReaImGui DrawList API calls using svgpathtools

Requires: pip install svgpathtools

Usage:
    python svg_to_lua.py input.svg [--output output.lua] [--function-name draw_icon]

Example:
    python svg_to_lua.py arkitekt_logo.svg --function-name draw_arkitekt_accurate -o icon.lua
"""

import argparse
import sys
import math
from pathlib import Path
from typing import List, Tuple, Optional

try:
    from svgpathtools import svg2paths, Line, QuadraticBezier, CubicBezier, Arc
    from svgpathtools import parse_path
except ImportError:
    print("Error: svgpathtools not installed", file=sys.stderr)
    print("Install with: pip install svgpathtools", file=sys.stderr)
    sys.exit(1)

import xml.etree.ElementTree as ET


class LuaCodeGenerator:
    """Generate ReaImGui DrawList code from parsed SVG paths."""

    def __init__(self, normalize: bool = True, viewbox: Optional[Tuple[float, float, float, float]] = None):
        self.normalize = normalize
        self.viewbox = viewbox
        self.min_x = float('inf')
        self.min_y = float('inf')
        self.max_x = float('-inf')
        self.max_y = float('-inf')

    def _update_bounds(self, x: float, y: float):
        """Update bounding box."""
        self.min_x = min(self.min_x, x)
        self.min_y = min(self.min_y, y)
        self.max_x = max(self.max_x, x)
        self.max_y = max(self.max_y, y)

    def _normalize_coord(self, value: float, is_x: bool = True) -> str:
        """Normalize coordinate to 0-1 range based on viewbox or bounds."""
        if not self.normalize:
            return f"{value:.6f}"

        if self.viewbox:
            vx, vy, vw, vh = self.viewbox
            if is_x:
                normalized = (value - vx) / vw
            else:
                normalized = (value - vy) / vh
        else:
            # Use calculated bounds
            width = self.max_x - self.min_x
            height = self.max_y - self.min_y
            max_dim = max(width, height) if max(width, height) > 0 else 1.0

            if is_x:
                normalized = (value - self.min_x) / max_dim
            else:
                normalized = (value - self.min_y) / max_dim

        return f"{normalized:.6f}"

    def _arc_to_lua(self, arc: Arc, lua_lines: List[str]):
        """Convert Arc to ImGui PathArcTo or approximate with bezier."""
        # Get arc parameters
        start = arc.start
        end = arc.end
        radius = arc.radius

        # For ReaImGui, we'll approximate arcs with cubic bezier curves
        # This is more compatible than trying to use PathArcTo with elliptical arcs
        # svgpathtools can help us sample the arc

        # Sample the arc at multiple points for better approximation
        num_samples = 4
        for i in range(num_samples):
            t_start = i / num_samples
            t_end = (i + 1) / num_samples

            p0 = arc.point(t_start)
            p3 = arc.point(t_end)

            # Approximate with cubic bezier
            # Control points at 1/3 and 2/3 along the arc
            p1 = arc.point(t_start + (t_end - t_start) * 0.33)
            p2 = arc.point(t_start + (t_end - t_start) * 0.67)

            self._update_bounds(p3.real, p3.imag)

            nx0 = self._normalize_coord(p0.real, True)
            ny0 = self._normalize_coord(p0.imag, False)
            nx1 = self._normalize_coord(p1.real, True)
            ny1 = self._normalize_coord(p1.imag, False)
            nx2 = self._normalize_coord(p2.real, True)
            ny2 = self._normalize_coord(p2.imag, False)
            nx3 = self._normalize_coord(p3.real, True)
            ny3 = self._normalize_coord(p3.imag, False)

            if i == 0:
                lua_lines.append(f"  ImGui.DrawList_PathLineTo(dl, x + s*{nx0}, y + s*{ny0})")

            lua_lines.append(f"  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*{nx1}, y + s*{ny1}, x + s*{nx2}, y + s*{ny2}, x + s*{nx3}, y + s*{ny3})")

    def path_to_lua(self, path, fill: str = 'none', stroke: str = 'none',
                    stroke_width: float = 1.0) -> List[str]:
        """Convert a svgpathtools Path to Lua DrawList commands."""
        lua_lines = []

        if not path:
            return lua_lines

        # Start new path
        lua_lines.append("  ImGui.DrawList_PathClear(dl)")

        # First pass: calculate bounds if we need them for normalization
        if self.normalize and not self.viewbox:
            for segment in path:
                if isinstance(segment, Line):
                    self._update_bounds(segment.end.real, segment.end.imag)
                elif isinstance(segment, QuadraticBezier):
                    self._update_bounds(segment.end.real, segment.end.imag)
                    self._update_bounds(segment.control.real, segment.control.imag)
                elif isinstance(segment, CubicBezier):
                    self._update_bounds(segment.end.real, segment.end.imag)
                    self._update_bounds(segment.control1.real, segment.control1.imag)
                    self._update_bounds(segment.control2.real, segment.control2.imag)
                elif isinstance(segment, Arc):
                    # Sample arc for bounds
                    for t in [0, 0.5, 1.0]:
                        pt = segment.point(t)
                        self._update_bounds(pt.real, pt.imag)

        # Second pass: generate Lua code
        first_point = True
        for segment in path:
            if isinstance(segment, Line):
                # Line segment
                start_x, start_y = segment.start.real, segment.start.imag
                end_x, end_y = segment.end.real, segment.end.imag

                if first_point:
                    nx = self._normalize_coord(start_x, True)
                    ny = self._normalize_coord(start_y, False)
                    lua_lines.append(f"  ImGui.DrawList_PathLineTo(dl, x + s*{nx}, y + s*{ny})")
                    first_point = False

                nx = self._normalize_coord(end_x, True)
                ny = self._normalize_coord(end_y, False)
                lua_lines.append(f"  ImGui.DrawList_PathLineTo(dl, x + s*{nx}, y + s*{ny})")

            elif isinstance(segment, QuadraticBezier):
                # Quadratic bezier curve
                start_x, start_y = segment.start.real, segment.start.imag
                ctrl_x, ctrl_y = segment.control.real, segment.control.imag
                end_x, end_y = segment.end.real, segment.end.imag

                if first_point:
                    nx = self._normalize_coord(start_x, True)
                    ny = self._normalize_coord(start_y, False)
                    lua_lines.append(f"  ImGui.DrawList_PathLineTo(dl, x + s*{nx}, y + s*{ny})")
                    first_point = False

                nc_x = self._normalize_coord(ctrl_x, True)
                nc_y = self._normalize_coord(ctrl_y, False)
                ne_x = self._normalize_coord(end_x, True)
                ne_y = self._normalize_coord(end_y, False)

                lua_lines.append(f"  ImGui.DrawList_PathBezierQuadraticCurveTo(dl, x + s*{nc_x}, y + s*{nc_y}, x + s*{ne_x}, y + s*{ne_y})")

            elif isinstance(segment, CubicBezier):
                # Cubic bezier curve
                start_x, start_y = segment.start.real, segment.start.imag
                cp1_x, cp1_y = segment.control1.real, segment.control1.imag
                cp2_x, cp2_y = segment.control2.real, segment.control2.imag
                end_x, end_y = segment.end.real, segment.end.imag

                if first_point:
                    nx = self._normalize_coord(start_x, True)
                    ny = self._normalize_coord(start_y, False)
                    lua_lines.append(f"  ImGui.DrawList_PathLineTo(dl, x + s*{nx}, y + s*{ny})")
                    first_point = False

                nc1_x = self._normalize_coord(cp1_x, True)
                nc1_y = self._normalize_coord(cp1_y, False)
                nc2_x = self._normalize_coord(cp2_x, True)
                nc2_y = self._normalize_coord(cp2_y, False)
                ne_x = self._normalize_coord(end_x, True)
                ne_y = self._normalize_coord(end_y, False)

                lua_lines.append(f"  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*{nc1_x}, y + s*{nc1_y}, x + s*{nc2_x}, y + s*{nc2_y}, x + s*{ne_x}, y + s*{ne_y})")

            elif isinstance(segment, Arc):
                # Arc - approximate with bezier curves
                if first_point:
                    start_x, start_y = segment.start.real, segment.start.imag
                    nx = self._normalize_coord(start_x, True)
                    ny = self._normalize_coord(start_y, False)
                    lua_lines.append(f"  ImGui.DrawList_PathLineTo(dl, x + s*{nx}, y + s*{ny})")
                    first_point = False

                self._arc_to_lua(segment, lua_lines)

        # Finish path with fill or stroke
        has_fill = fill not in ['none', 'transparent', '']
        has_stroke = stroke not in ['none', 'transparent', '']

        if has_fill:
            lua_lines.append(f"  ImGui.DrawList_PathFillConvex(dl, color)")

        if has_stroke:
            lua_lines.append(f"  ImGui.DrawList_PathStroke(dl, color, ImGui.DrawFlags_Closed, {stroke_width:.2f} * dpi)")

        if not has_fill and not has_stroke:
            # Default to fill if nothing specified
            lua_lines.append(f"  ImGui.DrawList_PathFillConvex(dl, color)")

        return lua_lines


def parse_viewbox(svg_root) -> Optional[Tuple[float, float, float, float]]:
    """Parse viewBox attribute from SVG root."""
    viewbox_str = svg_root.get('viewBox')
    if viewbox_str:
        try:
            parts = viewbox_str.replace(',', ' ').split()
            if len(parts) == 4:
                return tuple(float(p) for p in parts)
        except ValueError:
            pass
    return None


def parse_basic_shapes(svg_root) -> List[Tuple[str, str, str, float]]:
    """Convert basic SVG shapes (circle, rect, ellipse, polygon) to path strings."""
    shapes = []
    ns = {'svg': 'http://www.w3.org/2000/svg'}

    # Circles
    for circle in svg_root.findall('.//svg:circle', ns) + svg_root.findall('.//circle'):
        cx = float(circle.get('cx', 0))
        cy = float(circle.get('cy', 0))
        r = float(circle.get('r', 0))
        fill = circle.get('fill', 'black')
        stroke = circle.get('stroke', 'none')
        stroke_width = float(circle.get('stroke-width', 1))

        # Convert circle to path using arc commands
        path_d = f"M {cx-r},{cy} A {r},{r} 0 1,0 {cx+r},{cy} A {r},{r} 0 1,0 {cx-r},{cy} Z"
        shapes.append((path_d, fill, stroke, stroke_width))

    # Rectangles
    for rect in svg_root.findall('.//svg:rect', ns) + svg_root.findall('.//rect'):
        x = float(rect.get('x', 0))
        y = float(rect.get('y', 0))
        w = float(rect.get('width', 0))
        h = float(rect.get('height', 0))
        fill = rect.get('fill', 'black')
        stroke = rect.get('stroke', 'none')
        stroke_width = float(rect.get('stroke-width', 1))

        # Convert rect to path
        path_d = f"M {x},{y} L {x+w},{y} L {x+w},{y+h} L {x},{y+h} Z"
        shapes.append((path_d, fill, stroke, stroke_width))

    # Polygons
    for polygon in svg_root.findall('.//svg:polygon', ns) + svg_root.findall('.//polygon'):
        points_str = polygon.get('points', '')
        fill = polygon.get('fill', 'black')
        stroke = polygon.get('stroke', 'none')
        stroke_width = float(polygon.get('stroke-width', 1))

        if points_str:
            points = points_str.replace(',', ' ').split()
            if len(points) >= 2:
                path_d = f"M {points[0]} {points[1]}"
                for i in range(2, len(points), 2):
                    if i+1 < len(points):
                        path_d += f" L {points[i]} {points[i+1]}"
                path_d += " Z"
                shapes.append((path_d, fill, stroke, stroke_width))

    return shapes


def generate_lua_function(svg_path: Path, function_name: str = "draw_icon",
                         normalize: bool = True) -> str:
    """Generate complete Lua function from SVG file."""

    # Parse SVG file
    try:
        paths, attributes = svg2paths(str(svg_path))
    except Exception as e:
        raise ValueError(f"Failed to parse SVG: {e}")

    if not paths:
        raise ValueError(f"No paths found in SVG file: {svg_path}")

    # Parse viewBox for proper normalization
    tree = ET.parse(svg_path)
    root = tree.getroot()
    viewbox = parse_viewbox(root)

    # Parse basic shapes (circles, rects, etc.) and convert to paths
    basic_shapes = parse_basic_shapes(root)
    for path_d, fill, stroke, stroke_width in basic_shapes:
        try:
            path = parse_path(path_d)
            paths.append(path)
            attributes.append({'fill': fill, 'stroke': stroke, 'stroke-width': str(stroke_width)})
        except:
            pass  # Skip invalid shapes

    # Initialize code generator
    generator = LuaCodeGenerator(normalize=normalize, viewbox=viewbox)

    # Generate Lua code header
    lua_lines = [
        f"-- Auto-generated from {svg_path.name}",
        f"-- Normalized: {normalize}",
    ]

    if viewbox:
        lua_lines.append(f"-- ViewBox: {viewbox[0]:.1f} {viewbox[1]:.1f} {viewbox[2]:.1f} {viewbox[3]:.1f}")

    lua_lines.extend([
        f"function M.{function_name}(ctx, x, y, size, color)",
        "  local dl = ImGui.GetWindowDrawList(ctx)",
        "  local dpi = ImGui.GetWindowDpiScale(ctx)",
        "  local s = size * dpi",
        ""
    ])

    # Process each path
    for idx, (path, attrs) in enumerate(zip(paths, attributes)):
        if idx > 0:
            lua_lines.append("")  # Blank line between paths

        lua_lines.append(f"  -- Path {idx + 1}")

        # Get fill and stroke attributes
        fill = attrs.get('fill', 'black')
        stroke = attrs.get('stroke', 'none')
        stroke_width = float(attrs.get('stroke-width', 1))

        # Generate path code
        path_lua = generator.path_to_lua(path, fill, stroke, stroke_width)
        lua_lines.extend(path_lua)

    lua_lines.append("end")

    # Add bounding box info as comment
    if generator.min_x != float('inf'):
        lua_lines.insert(2, f"-- Bounds: ({generator.min_x:.2f}, {generator.min_y:.2f}) to ({generator.max_x:.2f}, {generator.max_y:.2f})")

    return '\n'.join(lua_lines)


def main():
    parser = argparse.ArgumentParser(
        description='Convert SVG to ReaImGui Lua DrawList code using svgpathtools',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Basic conversion
  python svg_to_lua.py icon.svg

  # With custom function name and output file
  python svg_to_lua.py logo.svg -f draw_arkitekt_logo -o icon.lua

  # Without normalization
  python svg_to_lua.py icon.svg --no-normalize

Requirements:
  pip install svgpathtools
        """
    )

    parser.add_argument('input', type=Path, help='Input SVG file')
    parser.add_argument('-o', '--output', type=Path, help='Output Lua file (default: stdout)')
    parser.add_argument('-f', '--function-name', default='draw_icon',
                       help='Lua function name (default: draw_icon)')
    parser.add_argument('--no-normalize', action='store_true',
                       help='Do not normalize coordinates')

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
            print(f"✓ Generated Lua code written to: {args.output}")
        else:
            print(lua_code)

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()

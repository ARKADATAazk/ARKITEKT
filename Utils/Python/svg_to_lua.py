# @noindex
#!/usr/bin/env python3
"""
SVG to Lua Path Converter for ReaImGui
Converts SVG paths to ReaImGui DrawList API calls using svgpathtools

Requires: pip install svgpathtools

Usage:
    # Auto-detect svg/ folder and process all files
    python svg_to_lua.py
    
    # Single file conversion
    python svg_to_lua.py input.svg [--output output.lua] [--function-name draw_icon]

    # Batch conversion from svg/ folder
    python svg_to_lua.py --batch [--output-dir output/]

Example:
    python svg_to_lua.py arkitekt_logo.svg --function-name draw_arkitekt_accurate -o icon.lua
    python svg_to_lua.py --batch --output-dir lua_icons/
"""

import argparse
import sys
import math
import re
from pathlib import Path
from typing import List, Tuple, Optional, Dict

try:
    from svgpathtools import svg2paths, Line, QuadraticBezier, CubicBezier, Arc
    from svgpathtools import parse_path
except ImportError:
    print("Error: svgpathtools not installed", file=sys.stderr)
    print("Install with: pip install svgpathtools", file=sys.stderr)
    sys.exit(1)

import xml.etree.ElementTree as ET


def parse_style_attribute(style_str: str) -> Dict[str, str]:
    """Parse CSS-style attribute string into a dictionary."""
    styles = {}
    if not style_str:
        return styles

    for item in style_str.split(';'):
        item = item.strip()
        if ':' in item:
            key, value = item.split(':', 1)
            styles[key.strip()] = value.strip()

    return styles


def get_element_style(element, attr_name: str, default: str = 'none') -> str:
    """Get style attribute from element, checking both direct attribute and style string."""
    value = element.get(attr_name)
    if value:
        return value

    style_str = element.get('style', '')
    styles = parse_style_attribute(style_str)
    return styles.get(attr_name, default)


def sanitize_function_name(name: str) -> str:
    """Convert filename to valid Lua function name."""
    name = Path(name).stem
    name = re.sub(r'[^a-zA-Z0-9_]', '_', name)
    if name and name[0].isdigit():
        name = '_' + name
    return name or 'draw_icon'


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
        """Normalize coordinate to 0-1 range based on actual content bounds."""
        if not self.normalize:
            return f"{value:.6f}"

        # Always use actual content bounds for normalization
        width = self.max_x - self.min_x
        height = self.max_y - self.min_y
        max_dim = max(width, height) if max(width, height) > 0 else 1.0

        if is_x:
            normalized = (value - self.min_x) / max_dim
        else:
            normalized = (value - self.min_y) / max_dim

        return f"{normalized:.6f}"

    def _arc_to_lua(self, arc: Arc, lua_lines: List[str]):
        """Convert Arc to cubic bezier approximation.

        Arcs are split into segments of at most 90 degrees for accuracy.
        """
        delta = arc.delta
        num_segments = max(1, int(math.ceil(abs(delta) / 90.0)))

        for i in range(num_segments):
            t_start = i / num_segments
            t_end = (i + 1) / num_segments

            p0 = arc.point(t_start)
            p3 = arc.point(t_end)

            segment_angle = abs(delta) / num_segments * math.pi / 180.0

            if segment_angle > 0:
                k = (4.0 / 3.0) * math.tan(segment_angle / 4.0)
            else:
                k = 0

            d0 = arc.derivative(t_start)
            d3 = arc.derivative(t_end)

            arc_len = abs(arc.length() * (t_end - t_start))
            if arc_len > 0:
                scale = arc_len * k / 3.0
                d0_norm = abs(d0)
                d3_norm = abs(d3)

                if d0_norm > 0:
                    p1 = p0 + (d0 / d0_norm) * scale
                else:
                    p1 = p0 + (p3 - p0) * 0.33

                if d3_norm > 0:
                    p2 = p3 - (d3 / d3_norm) * scale
                else:
                    p2 = p0 + (p3 - p0) * 0.67
            else:
                p1 = p0 + (p3 - p0) * 0.33
                p2 = p0 + (p3 - p0) * 0.67

            self._update_bounds(p3.real, p3.imag)

            nx1 = self._normalize_coord(p1.real, True)
            ny1 = self._normalize_coord(p1.imag, False)
            nx2 = self._normalize_coord(p2.real, True)
            ny2 = self._normalize_coord(p2.imag, False)
            nx3 = self._normalize_coord(p3.real, True)
            ny3 = self._normalize_coord(p3.imag, False)

            lua_lines.append(f"  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*{nx1}, y + s*{ny1}, x + s*{nx2}, y + s*{ny2}, x + s*{nx3}, y + s*{ny3})")

    def _is_likely_convex(self, path) -> bool:
        """Heuristic check if a path is likely convex (safe for PathFillConvex)."""
        if len(path) <= 3:
            return True  # Triangle or simpler is always convex
        
        # Simple rectangle (4 line segments)
        if len(path) == 4 and all(isinstance(seg, Line) for seg in path):
            return True
        
        # Circle-like shapes (smooth bezier curves, no lines)
        if all(isinstance(seg, (CubicBezier, QuadraticBezier)) for seg in path):
            # If it's 4 bezier segments, likely a circle/ellipse
            if len(path) == 4:
                return True
        
        # Mixed line and bezier with many segments suggests complex shape
        has_lines = any(isinstance(seg, Line) for seg in path)
        has_beziers = any(isinstance(seg, (CubicBezier, QuadraticBezier)) for seg in path)
        
        if has_lines and has_beziers and len(path) > 5:
            return False  # Complex mixed shape, probably non-convex
        
        return True  # Default to convex

    def path_to_lua(self, path, fill: str = 'none', stroke: str = 'none',
                    stroke_width: float = 1.0) -> List[str]:
        """Convert a svgpathtools Path to Lua DrawList commands."""
        lua_lines = []

        if not path:
            return lua_lines

        lua_lines.append("  ImGui.DrawList_PathClear(dl)")

        # Calculate bounds from actual path data (always needed for normalization)
        if self.normalize:
            for segment in path:
                if isinstance(segment, Line):
                    self._update_bounds(segment.start.real, segment.start.imag)
                    self._update_bounds(segment.end.real, segment.end.imag)
                elif isinstance(segment, QuadraticBezier):
                    self._update_bounds(segment.start.real, segment.start.imag)
                    self._update_bounds(segment.end.real, segment.end.imag)
                    self._update_bounds(segment.control.real, segment.control.imag)
                elif isinstance(segment, CubicBezier):
                    self._update_bounds(segment.start.real, segment.start.imag)
                    self._update_bounds(segment.end.real, segment.end.imag)
                    self._update_bounds(segment.control1.real, segment.control1.imag)
                    self._update_bounds(segment.control2.real, segment.control2.imag)
                elif isinstance(segment, Arc):
                    for t in [0, 0.25, 0.5, 0.75, 1.0]:
                        pt = segment.point(t)
                        self._update_bounds(pt.real, pt.imag)

        # Second pass: generate Lua code
        first_point = True
        for segment in path:
            if isinstance(segment, Line):
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
                if first_point:
                    start_x, start_y = segment.start.real, segment.start.imag
                    nx = self._normalize_coord(start_x, True)
                    ny = self._normalize_coord(start_y, False)
                    lua_lines.append(f"  ImGui.DrawList_PathLineTo(dl, x + s*{nx}, y + s*{ny})")
                    first_point = False

                self._arc_to_lua(segment, lua_lines)

        has_fill = fill not in ['none', 'transparent', '']
        has_stroke = stroke not in ['none', 'transparent', '']
        
        # Check if path is likely convex
        is_convex = self._is_likely_convex(path)

        if has_fill:
            if is_convex:
                lua_lines.append(f"  ImGui.DrawList_PathFillConvex(dl, color)")
            else:
                # Non-convex path - use stroke instead to avoid rendering issues
                lua_lines.append(f"  ImGui.DrawList_PathStroke(dl, color, ImGui.DrawFlags_Closed, 2.5 * dpi)")

        if has_stroke:
            lua_lines.append(f"  ImGui.DrawList_PathStroke(dl, color, ImGui.DrawFlags_Closed, {stroke_width:.2f} * dpi)")

        if not has_fill and not has_stroke:
            if is_convex:
                lua_lines.append(f"  ImGui.DrawList_PathFillConvex(dl, color)")
            else:
                lua_lines.append(f"  ImGui.DrawList_PathStroke(dl, color, ImGui.DrawFlags_Closed, 2.0 * dpi)")

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
    """Convert basic SVG shapes (circle, rect, ellipse, polygon, line, polyline) to path strings."""
    shapes = []
    ns = {'svg': 'http://www.w3.org/2000/svg'}

    def find_elements(tag):
        """Find elements with or without SVG namespace."""
        return svg_root.findall(f'.//svg:{tag}', ns) + svg_root.findall(f'.//{tag}')

    for circle in find_elements('circle'):
        cx = float(circle.get('cx', 0))
        cy = float(circle.get('cy', 0))
        r = float(circle.get('r', 0))
        fill = get_element_style(circle, 'fill', 'black')
        stroke = get_element_style(circle, 'stroke', 'none')
        stroke_width = float(get_element_style(circle, 'stroke-width', '1'))

        path_d = f"M {cx-r},{cy} A {r},{r} 0 1,0 {cx+r},{cy} A {r},{r} 0 1,0 {cx-r},{cy} Z"
        shapes.append((path_d, fill, stroke, stroke_width))

    for ellipse in find_elements('ellipse'):
        cx = float(ellipse.get('cx', 0))
        cy = float(ellipse.get('cy', 0))
        rx = float(ellipse.get('rx', 0))
        ry = float(ellipse.get('ry', 0))
        fill = get_element_style(ellipse, 'fill', 'black')
        stroke = get_element_style(ellipse, 'stroke', 'none')
        stroke_width = float(get_element_style(ellipse, 'stroke-width', '1'))

        path_d = f"M {cx-rx},{cy} A {rx},{ry} 0 1,0 {cx+rx},{cy} A {rx},{ry} 0 1,0 {cx-rx},{cy} Z"
        shapes.append((path_d, fill, stroke, stroke_width))

    for rect in find_elements('rect'):
        x = float(rect.get('x', 0))
        y = float(rect.get('y', 0))
        w = float(rect.get('width', 0))
        h = float(rect.get('height', 0))
        rx = float(rect.get('rx', 0))
        ry = float(rect.get('ry', rx))
        fill = get_element_style(rect, 'fill', 'black')
        stroke = get_element_style(rect, 'stroke', 'none')
        stroke_width = float(get_element_style(rect, 'stroke-width', '1'))

        if rx > 0 or ry > 0:
            path_d = (f"M {x+rx},{y} "
                     f"L {x+w-rx},{y} "
                     f"A {rx},{ry} 0 0,1 {x+w},{y+ry} "
                     f"L {x+w},{y+h-ry} "
                     f"A {rx},{ry} 0 0,1 {x+w-rx},{y+h} "
                     f"L {x+rx},{y+h} "
                     f"A {rx},{ry} 0 0,1 {x},{y+h-ry} "
                     f"L {x},{y+ry} "
                     f"A {rx},{ry} 0 0,1 {x+rx},{y} Z")
        else:
            path_d = f"M {x},{y} L {x+w},{y} L {x+w},{y+h} L {x},{y+h} Z"
        shapes.append((path_d, fill, stroke, stroke_width))

    for line in find_elements('line'):
        x1 = float(line.get('x1', 0))
        y1 = float(line.get('y1', 0))
        x2 = float(line.get('x2', 0))
        y2 = float(line.get('y2', 0))
        stroke = get_element_style(line, 'stroke', 'black')
        stroke_width = float(get_element_style(line, 'stroke-width', '1'))

        path_d = f"M {x1},{y1} L {x2},{y2}"
        shapes.append((path_d, 'none', stroke, stroke_width))

    for polyline in find_elements('polyline'):
        points_str = polyline.get('points', '')
        fill = get_element_style(polyline, 'fill', 'none')
        stroke = get_element_style(polyline, 'stroke', 'black')
        stroke_width = float(get_element_style(polyline, 'stroke-width', '1'))

        if points_str:
            points = points_str.replace(',', ' ').split()
            if len(points) >= 2:
                path_d = f"M {points[0]} {points[1]}"
                for i in range(2, len(points), 2):
                    if i+1 < len(points):
                        path_d += f" L {points[i]} {points[i+1]}"
                shapes.append((path_d, fill, stroke, stroke_width))

    for polygon in find_elements('polygon'):
        points_str = polygon.get('points', '')
        fill = get_element_style(polygon, 'fill', 'black')
        stroke = get_element_style(polygon, 'stroke', 'none')
        stroke_width = float(get_element_style(polygon, 'stroke-width', '1'))

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


def deduplicate_paths(paths, attributes):
    """Remove duplicate paths based on their geometry."""
    unique_paths = []
    unique_attrs = []
    
    for i, (path, attr) in enumerate(zip(paths, attributes)):
        is_duplicate = False
        
        # Check against all previously added paths
        for j, prev_path in enumerate(unique_paths):
            if len(path) != len(prev_path):
                continue
            
            # Compare each segment
            all_match = True
            for seg1, seg2 in zip(path, prev_path):
                if type(seg1) != type(seg2):
                    all_match = False
                    break
                    
                # Compare coordinates with small tolerance
                tolerance = 0.001
                if hasattr(seg1, 'start') and hasattr(seg2, 'start'):
                    if abs(seg1.start - seg2.start) > tolerance:
                        all_match = False
                        break
                if hasattr(seg1, 'end') and hasattr(seg2, 'end'):
                    if abs(seg1.end - seg2.end) > tolerance:
                        all_match = False
                        break
            
            if all_match:
                # Also check if attributes match
                if (attr.get('fill') == unique_attrs[j].get('fill') and
                    attr.get('stroke') == unique_attrs[j].get('stroke')):
                    is_duplicate = True
                    break
        
        if not is_duplicate:
            unique_paths.append(path)
            unique_attrs.append(attr)
    
    return unique_paths, unique_attrs


def generate_lua_function(svg_path: Path, function_name: str = "draw_icon",
                         normalize: bool = True) -> str:
    """Generate complete Lua function from SVG file."""

    try:
        paths, attributes = svg2paths(str(svg_path))
    except Exception as e:
        raise ValueError(f"Failed to parse SVG: {e}")

    tree = ET.parse(svg_path)
    root = tree.getroot()
    viewbox = parse_viewbox(root)

    basic_shapes = parse_basic_shapes(root)
    for path_d, fill, stroke, stroke_width in basic_shapes:
        try:
            path = parse_path(path_d)
            paths.append(path)
            attributes.append({'fill': fill, 'stroke': stroke, 'stroke-width': str(stroke_width)})
        except:
            pass

    # Deduplicate paths
    paths, attributes = deduplicate_paths(paths, attributes)

    if not paths:
        raise ValueError(f"No paths found in SVG file: {svg_path}")

    generator = LuaCodeGenerator(normalize=normalize, viewbox=viewbox)

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

    for idx, (path, attrs) in enumerate(zip(paths, attributes)):
        if idx > 0:
            lua_lines.append("")

        lua_lines.append(f"  -- Path {idx + 1}")

        fill = attrs.get('fill', 'black')
        stroke = attrs.get('stroke', 'none')
        stroke_width = float(attrs.get('stroke-width', 1))

        path_lua = generator.path_to_lua(path, fill, stroke, stroke_width)
        lua_lines.extend(path_lua)

    lua_lines.append("end")

    if generator.min_x != float('inf'):
        lua_lines.insert(2, f"-- Bounds: ({generator.min_x:.2f}, {generator.min_y:.2f}) to ({generator.max_x:.2f}, {generator.max_y:.2f})")

    return '\n'.join(lua_lines)


def process_batch(svg_dir: Path, output_dir: Optional[Path] = None,
                  normalize: bool = True, verbose: bool = True) -> Tuple[int, int]:
    """Process all SVG files in a directory."""
    svg_files = list(svg_dir.glob('*.svg'))

    if not svg_files:
        if verbose:
            print(f"No SVG files found in: {svg_dir}", file=sys.stderr)
        return 0, 0

    if output_dir:
        output_dir.mkdir(parents=True, exist_ok=True)

    success_count = 0
    error_count = 0
    total = len(svg_files)

    if verbose:
        print(f"Processing {total} SVG file(s) from: {svg_dir}")
        if output_dir:
            print(f"Output directory: {output_dir}")
        print()

    for idx, svg_file in enumerate(svg_files, 1):
        function_name = f"draw_{sanitize_function_name(svg_file.name)}"

        try:
            lua_code = generate_lua_function(
                svg_file,
                function_name,
                normalize=normalize
            )

            # Always write to file (in svg dir if no output_dir specified)
            if output_dir:
                output_file = output_dir / f"{svg_file.stem}.lua"
            else:
                output_file = svg_file.parent / f"{svg_file.stem}.lua"
            
            full_code = [
                "-- @noindex",
                f"-- Generated from {svg_file.name}",
                "package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path",
                "local ImGui = require 'imgui' '0.10'",
                "",
                "local M = {}",
                "",
                lua_code,
                "",
                "return M"
            ]
            output_file.write_text('\n'.join(full_code))

            if verbose:
                print(f"[{idx}/{total}] OK: {svg_file.name} -> {output_file.name}")

            success_count += 1

        except Exception as e:
            error_count += 1
            if verbose:
                print(f"[{idx}/{total}] ERROR: {svg_file.name}: {e}", file=sys.stderr)

    if verbose:
        print()
        print(f"Completed: {success_count} succeeded, {error_count} failed")

    return success_count, error_count


def main():
    parser = argparse.ArgumentParser(
        description='Convert SVG to ReaImGui Lua DrawList code using svgpathtools',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Auto-detect and process svg/ folder
  python svg_to_lua.py

  # Basic conversion
  python svg_to_lua.py icon.svg

  # With custom function name and output file
  python svg_to_lua.py logo.svg -f draw_arkitekt_logo -o icon.lua

  # Batch conversion from svg/ folder
  python svg_to_lua.py --batch

  # Batch conversion with custom directories
  python svg_to_lua.py --batch --svg-dir my_icons/ --output-dir lua_output/

  # Without normalization
  python svg_to_lua.py icon.svg --no-normalize

Requirements:
  pip install svgpathtools
        """
    )

    parser.add_argument('input', type=Path, nargs='?', help='Input SVG file')
    parser.add_argument('-o', '--output', type=Path, help='Output Lua file (default: stdout)')
    parser.add_argument('-f', '--function-name', default='draw_icon',
                       help='Lua function name (default: draw_icon)')
    parser.add_argument('--no-normalize', action='store_true',
                       help='Do not normalize coordinates')
    parser.add_argument('--batch', action='store_true',
                       help='Batch process all SVG files in svg/ folder')
    parser.add_argument('--svg-dir', type=Path, default=None,
                       help='SVG input directory for batch mode (default: svg/)')
    parser.add_argument('--output-dir', type=Path, default=None,
                       help='Output directory for batch mode (default: prints to stdout)')
    parser.add_argument('-q', '--quiet', action='store_true',
                       help='Suppress progress output')

    args = parser.parse_args()

    if not args.input and not args.batch:
        script_dir = Path(__file__).parent
        default_svg_dir = script_dir / 'svg'
        
        if default_svg_dir.exists() and list(default_svg_dir.glob('*.svg')):
            args.batch = True
            if not args.quiet:
                print(f"Auto-detected SVG files in: {default_svg_dir}")
                print("Running in batch mode...\n")

    if args.batch:
        if args.svg_dir:
            svg_dir = args.svg_dir
        else:
            script_dir = Path(__file__).parent
            svg_dir = script_dir / 'svg'

        if not svg_dir.exists():
            print(f"Error: SVG directory not found: {svg_dir}", file=sys.stderr)
            print(f"Create it with: mkdir -p {svg_dir}", file=sys.stderr)
            sys.exit(1)

        success, errors = process_batch(
            svg_dir,
            args.output_dir,
            normalize=not args.no_normalize,
            verbose=not args.quiet
        )

        sys.exit(0 if errors == 0 else 1)

    if not args.input:
        parser.error("Either provide an input SVG file, use --batch mode, or place SVG files in svg/ folder")

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
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
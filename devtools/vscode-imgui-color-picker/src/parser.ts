import * as vscode from 'vscode';

/**
 * Parser for ImGui hex byte colors
 *
 * ImGui format: 0xRRGGBBAA
 * - RR: Red channel (00-FF)
 * - GG: Green channel (00-FF)
 * - BB: Blue channel (00-FF)
 * - AA: Alpha channel (00-FF)
 */

/**
 * Parse a hex byte color string to a VSCode Color
 *
 * @param hexByte - Hex byte string (e.g., "0xFF0000FF")
 * @returns VSCode Color object or null if invalid
 */
export function parseHexByte(hexByte: string): vscode.Color | null {
  // Remove "0x" prefix and validate
  const hex = hexByte.slice(2);
  if (hex.length !== 8) {
    return null;
  }

  try {
    // Parse RRGGBBAA components
    const r = parseInt(hex.slice(0, 2), 16);
    const g = parseInt(hex.slice(2, 4), 16);
    const b = parseInt(hex.slice(4, 6), 16);
    const a = parseInt(hex.slice(6, 8), 16);

    // Validate values
    if (isNaN(r) || isNaN(g) || isNaN(b) || isNaN(a)) {
      return null;
    }

    // Convert to 0-1 range for VSCode
    return new vscode.Color(r / 255, g / 255, b / 255, a / 255);
  } catch (error) {
    return null;
  }
}

/**
 * Convert a VSCode Color to ImGui hex byte format
 *
 * @param color - VSCode Color object
 * @returns Hex byte string (e.g., "0xFF0000FF")
 */
export function hexByteFromColor(color: vscode.Color): string {
  // Convert from 0-1 range to 0-255 range
  const r = Math.round(color.red * 255);
  const g = Math.round(color.green * 255);
  const b = Math.round(color.blue * 255);
  const a = Math.round(color.alpha * 255);

  // Format as hex with padding
  const rHex = r.toString(16).padStart(2, '0').toUpperCase();
  const gHex = g.toString(16).padStart(2, '0').toUpperCase();
  const bHex = b.toString(16).padStart(2, '0').toUpperCase();
  const aHex = a.toString(16).padStart(2, '0').toUpperCase();

  return `0x${rHex}${gHex}${bHex}${aHex}`;
}

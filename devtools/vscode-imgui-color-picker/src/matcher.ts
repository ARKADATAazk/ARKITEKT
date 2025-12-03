/**
 * Pattern matcher for ImGui hex byte colors
 *
 * Matches: 0xRRGGBBAA format (8 hex digits)
 * Examples: 0xFF0000FF, 0x00FF00FF, 0x0000FFFF, 0xFFFFFF80
 */

export interface Match {
  text: string;
  start: number;
  end: number;
}

export class Matcher {
  // Matches 0x followed by exactly 8 hex digits (RRGGBBAA)
  private static readonly PATTERN = /0x[0-9A-Fa-f]{8}/g;

  /**
   * Find all ImGui hex byte color matches in the given text
   */
  public static getMatches(text: string): Match[] {
    const matches: Match[] = [];
    let match: RegExpExecArray | null;

    while ((match = this.PATTERN.exec(text)) !== null) {
      matches.push({
        text: match[0],
        start: match.index,
        end: match.index + match[0].length,
      });
    }

    return matches;
  }
}

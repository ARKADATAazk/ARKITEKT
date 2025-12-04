import * as vscode from 'vscode';
import { Matcher } from './matcher';
import { parseHexByte, hexByteFromColor } from './parser';

/**
 * ImGui Hex Byte Color Picker
 *
 * Provides color picker support for ImGui's hex byte color format: 0xRRGGBBAA
 *
 * Example formats:
 *   0xFF0000FF - Red with full alpha
 *   0x00FF00FF - Green with full alpha
 *   0x0000FFFF - Blue with full alpha
 *   0xFFFFFF80 - White with 50% alpha
 */
export function activate(context: vscode.ExtensionContext) {
  const picker = new ImGuiColorPicker();
  picker.activate(context);
}

export function deactivate() {}

class ImGuiColorPicker {
  public activate(context: vscode.ExtensionContext) {
    const config = vscode.workspace.getConfiguration('vscode-imgui-color-picker');
    const languages = config.get<string[]>('languages', ['lua']);

    for (const language of languages) {
      const provider = vscode.languages.registerColorProvider(language, {
        provideDocumentColors: this.provideDocumentColors.bind(this),
        provideColorPresentations: this.provideColorPresentations.bind(this),
      });
      context.subscriptions.push(provider);
    }
  }

  private provideDocumentColors(
    document: vscode.TextDocument,
    token: vscode.CancellationToken
  ): vscode.ColorInformation[] {
    const text = document.getText();
    const matches = Matcher.getMatches(text);
    const colors: vscode.ColorInformation[] = [];

    for (const match of matches) {
      const color = parseHexByte(match.text);
      if (color) {
        const range = new vscode.Range(
          document.positionAt(match.start),
          document.positionAt(match.end)
        );
        colors.push(new vscode.ColorInformation(range, color));
      }
    }

    return colors;
  }

  private provideColorPresentations(
    color: vscode.Color,
    context: { document: vscode.TextDocument; range: vscode.Range },
    token: vscode.CancellationToken
  ): vscode.ColorPresentation[] {
    const hexByte = hexByteFromColor(color);
    return [new vscode.ColorPresentation(hexByte)];
  }
}

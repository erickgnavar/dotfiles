/**
 * Prompt Prefix Extension - Shows ❯ before text in the editor, like a shell prompt.
 *
 * Place in ~/.pi/agent/extensions/ for auto-discovery.
 */

import {
  CustomEditor,
  type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";

class PromptEditor extends CustomEditor {
  render(width: number): string[] {
    const lines = super.render(width);
    if (lines.length < 3) return lines;

    // Only show ❯ when the actual first line of text is visible (not scrolled)
    if (this.scrollOffset > 0) return lines;

    // First content line is at index 1 (after the top border)
    const prompt = this.borderColor("❯ ");
    // Consume 2 columns from the right (padding) so total width stays within limits
    lines[1] = prompt + truncateToWidth(lines[1]!, Math.max(0, width - 2), "");

    return lines;
  }
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    ctx.ui.setEditorComponent(
      (tui, theme, kb) => new PromptEditor(tui, theme, kb),
    );
  });
}

/** Expands single-word aliases from "## Aliases" sections in AGENTS.md files. */

import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

function aliasesFrom(content: string): Record<string, string> {
  const aliases: Record<string, string> = {};
  const section = content.split(/^##\s+Aliases\s*$/im)[1];
  if (!section) return aliases;
  for (const [, alias, expansion] of section
    .split(/^##\s/m)[0]
    .matchAll(/^-\s+`([^`\n]+)`\s*→\s*"(.+)"\s*$/gm))
    aliases[alias.trim()] = expansion.trim();
  return aliases;
}

const read = (path: string) => {
  try {
    return readFileSync(path, "utf-8");
  } catch {
    return "";
  }
};

export default function (pi: ExtensionAPI) {
  pi.on("input", async (event, ctx) => {
    const text = event.text.trim();
    if (event.source !== "interactive" || /\s/.test(text)) return;
    const aliases = {
      ...aliasesFrom(read(join(homedir(), ".pi", "agent", "AGENTS.md"))),
      ...aliasesFrom(read(join(ctx.cwd, "AGENTS.md"))),
    };
    if (aliases[text]) return { action: "transform", text: aliases[text] };
  });
}

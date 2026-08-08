/**
 * Lang Directives Extension
 *
 * Reads lang-directives.json which maps path and word triggers to skill names.
 * At before_agent_start, scans the user's prompt for matching triggers and
 * reminds the model to read the relevant skill files.
 *
 * The skill files and their paths come from pi's own skill loader
 * (event.systemPromptOptions.skills); this extension only owns the
 * trigger->name mapping. Keep directive content in skill files under
 * ~/.pi/agent/skills/<name>/SKILL.md, not here.
 */

import {
  CONFIG_DIR_NAME,
  type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";

interface SkillEntry {
  name: string;
  paths: string[];
  words: string[];
}

interface Config {
  skills: SkillEntry[];
}

const HOME = homedir();
const GLOBAL_CONFIG = join(HOME, ".pi/agent/lang-directives.json");

/** Path triggers match literal substrings; word triggers require word boundaries. */
type MatchMode = "path" | "word";
type Matcher = (promptLower: string) => boolean;

function buildMatcher(value: string, mode: MatchMode): Matcher {
  const key = value.toLowerCase();
  if (mode === "path") return (prompt) => prompt.includes(key);

  const re = new RegExp(
    `(?<![\\p{L}\\p{N}_])${escapeRegex(key)}(?![\\p{L}\\p{N}_])`,
    "u",
  );
  return (prompt) => re.test(prompt);
}

function escapeRegex(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

class DirectiveIndex {
  /** keyword -> matcher */
  private matchers = new Map<string, Matcher>();
  /** keyword -> skill names */
  private names = new Map<string, Set<string>>();

  isEmpty(): boolean {
    return this.matchers.size === 0;
  }

  /** Rebuild from one or more configs (later configs add to, not replace). */
  rebuild(configs: Config[]): void {
    this.matchers.clear();
    this.names.clear();
    for (const config of configs) {
      for (const skill of config.skills) {
        if (!skill.name) continue;
        const groups: Array<[MatchMode, string[]]> = [
          ["path", skill.paths],
          ["word", skill.words],
        ];
        for (const [mode, values] of groups) {
          if (!Array.isArray(values)) continue;
          for (const value of values) {
            if (!value) continue;
            const key = `${mode}:${value.toLowerCase()}`;
            if (!this.matchers.has(key)) {
              this.matchers.set(key, buildMatcher(value, mode));
            }
            const set = this.names.get(key) ?? new Set<string>();
            set.add(skill.name);
            this.names.set(key, set);
          }
        }
      }
    }
  }

  /** Return de-duplicated skill names whose keywords appear in the prompt. */
  matchedSkillNames(prompt: string): string[] {
    const lower = prompt.toLowerCase();
    const result = new Set<string>();
    for (const [kw, matcher] of this.matchers) {
      if (matcher(lower)) {
        for (const name of this.names.get(kw) ?? []) result.add(name);
      }
    }
    return [...result];
  }
}

function loadConfig(filePath: string): Config | null {
  try {
    if (!existsSync(filePath)) return null;
    const config = JSON.parse(readFileSync(filePath, "utf-8")) as Config;
    return config.skills?.length ? config : null;
  } catch {
    return null;
  }
}

export default function (pi: ExtensionAPI) {
  const index = new DirectiveIndex();
  let lastCwd = "";

  function rebuild(cwd: string) {
    if (cwd === lastCwd && !index.isEmpty()) return; // cheap no-op re-entry
    const configs: Config[] = [];
    const global = loadConfig(GLOBAL_CONFIG);
    if (global) configs.push(global);
    const project = loadConfig(
      join(cwd, CONFIG_DIR_NAME, "lang-directives.json"),
    );
    if (project) configs.push(project);
    index.rebuild(configs);
    lastCwd = cwd;
  }

  pi.on("session_start", async (_event, ctx) => rebuild(ctx.cwd));
  pi.on("resources_discover", async (_event, ctx) => rebuild(ctx.cwd));

  pi.on("before_agent_start", async (event) => {
    if (index.isEmpty()) return;
    const wanted = index.matchedSkillNames(event.prompt);
    if (wanted.length === 0) return;

    // Resolve against pi's already-loaded skills so paths/discovery stay in
    // sync with the rest of the system. Skills flagged
    // disableModelInvocation are hidden from the model by pi itself; skip
    // them here too so we never remind the model of an un-invokable skill.
    const loaded = event.systemPromptOptions.skills ?? [];
    const byName = new Map(loaded.map((s) => [s.name, s]));
    const out = new Set<string>();
    for (const name of wanted) {
      const skill = byName.get(name);
      if (skill && !skill.disableModelInvocation) {
        out.add(`- \`${skill.filePath}\` — \`read\` for ${name} conventions`);
      }
    }
    if (out.size === 0) return;

    const reminder =
      `\n\n## Relevant conventions\n` +
      `Read these before writing or reviewing code:\n` +
      [...out].join("\n");

    return { systemPrompt: event.systemPrompt + reminder };
  });
}

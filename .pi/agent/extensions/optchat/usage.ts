import * as fs from "node:fs";
import { appendLine } from "./store.ts";

export interface UsageTotal {
  calls: number;
  promptTokens: number;
  cacheRead: number;
}

type Kind = "chat" | "compactor";
type Tokens = { input?: number; cacheRead?: number; cacheWrite?: number };

const empty = (): UsageTotal => ({ calls: 0, promptTokens: 0, cacheRead: 0 });

/** Append one dated provider response; replay the journal for cumulative totals. */
export class UsageJournal {
  readonly totals: Record<Kind, UsageTotal> = {
    chat: empty(),
    compactor: empty(),
  };
  private writable = true;
  private readonly file: string;

  constructor(file: string) {
    this.file = file;
    let text: string;
    try {
      text = fs.readFileSync(file, "utf8");
    } catch (err) {
      if ((err as NodeJS.ErrnoException).code === "ENOENT") return;
      throw err;
    }
    if (text && !text.endsWith("\n")) {
      const end = text.lastIndexOf("\n") + 1;
      const tail = text.slice(end);
      let complete = true;
      try {
        JSON.parse(tail);
      } catch {
        complete = false;
      }
      if (complete) {
        appendLine(file, ""); // a complete last record needs its newline
      } else {
        const fd = fs.openSync(file, "r+");
        try {
          fs.ftruncateSync(fd, Buffer.byteLength(text.slice(0, end)));
          fs.fsyncSync(fd);
        } finally {
          fs.closeSync(fd);
        }
        text = text.slice(0, end);
      }
    }
    for (const line of text.split("\n")) {
      if (!line) continue;
      const entry = JSON.parse(line) as {
        kind?: Kind;
        promptTokens?: number;
        cacheRead?: number;
      };
      if (
        (entry.kind !== "chat" && entry.kind !== "compactor") ||
        typeof entry.promptTokens !== "number" ||
        !Number.isSafeInteger(entry.promptTokens) ||
        entry.promptTokens < 0 ||
        typeof entry.cacheRead !== "number" ||
        !Number.isSafeInteger(entry.cacheRead) ||
        entry.cacheRead < 0
      )
        throw new Error(`invalid usage record in ${file}`);
      const total = this.totals[entry.kind];
      total.calls++;
      total.promptTokens += entry.promptTokens;
      total.cacheRead += entry.cacheRead;
    }
  }

  record(kind: Kind, usage: Tokens): void {
    const promptTokens =
      (usage.input ?? 0) + (usage.cacheRead ?? 0) + (usage.cacheWrite ?? 0);
    const cacheRead = usage.cacheRead ?? 0;
    const total = this.totals[kind];
    total.calls++;
    total.promptTokens += promptTokens;
    total.cacheRead += cacheRead;
    if (!this.writable) return;
    try {
      appendLine(
        this.file,
        JSON.stringify({
          date: new Date().toISOString().slice(0, 10),
          kind,
          promptTokens,
          cacheRead,
        }),
      );
    } catch (err) {
      this.writable = false;
      throw err;
    }
  }

  isWritable(): boolean {
    return this.writable;
  }
}

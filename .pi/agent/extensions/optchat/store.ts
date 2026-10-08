/**
 * Storage for the OptChat memory (§2 of optchat.md): two append-only
 * JSONL streams (main/, tree/), one write + fsync per line, torn-line
 * handling at load, and the single-writer lock (a Unix socket).
 */

import * as fs from "node:fs";
import * as net from "node:net";
import * as path from "node:path";

/** One message of the log, verbatim, with a permanent id. */
export interface LogMessage {
  i: number;
  kind: "user" | "talk" | "tool" | "echo" | "note";
  text: string;
  size: number;
  date: string;
}

/** One node of the summary tree: node (l, i) covers [i·2^l, (i+1)·2^l). */
export interface TreeNode {
  l: number;
  i: number;
  text: string;
  size: number;
}

export function byteLength(s: string): number {
  return Buffer.byteLength(s, "utf8");
}

/** First `limit` bytes of `s`, never splitting a UTF-8 character. */
export function cutToBytes(s: string, limit: number): string {
  const buf = Buffer.from(s, "utf8");
  if (buf.length <= limit) return s;
  let end = limit;
  while (end > 0 && (buf[end] & 0xc0) === 0x80) end--;
  return buf.toString("utf8", 0, end);
}

/** Local day of the moment, as the file name of the JSONL streams. */
export function localDay(): string {
  const d = new Date();
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

/** Append one line and fsync it before returning (§2: durability). */
export function appendLine(file: string, line: string): void {
  const buf = Buffer.from(`${line}\n`, "utf8");
  const fd = fs.openSync(file, "a");
  try {
    let off = 0;
    while (off < buf.length)
      off += fs.writeSync(fd, buf, off, buf.length - off);
    fs.fsyncSync(fd);
  } finally {
    fs.closeSync(fd);
  }
}

/**
 * Read every *.jsonl file of a stream directory, oldest day first. A
 * crash mid-write leaves a last line without "\n": the file gets one
 * appended so the next write starts on its own line; invalid lines are
 * skipped and counted.
 */
export function loadJsonl(dir: string): { lines: unknown[]; torn: number } {
  const lines: unknown[] = [];
  let torn = 0;
  let files: string[] = [];
  try {
    files = fs
      .readdirSync(dir)
      .filter((f) => f.endsWith(".jsonl"))
      .sort();
  } catch {
    return { lines, torn };
  }
  for (const f of files) {
    const file = path.join(dir, f);
    let text = "";
    try {
      text = fs.readFileSync(file, "utf8");
    } catch {
      continue;
    }
    if (text.length === 0) continue;
    if (!text.endsWith("\n")) appendLine(file, "");
    for (const raw of text.split("\n")) {
      if (raw.length === 0) continue;
      try {
        lines.push(JSON.parse(raw));
      } catch {
        torn++;
      }
    }
  }
  return { lines, torn };
}

export interface Lock {
  close(): void;
}

/**
 * Single-writer lock (§2): the owner listens on a Unix socket at
 * `lockPath`. A second process that can connect to it exits; a socket
 * that refuses connections is stale (the OS frees it when the owner
 * dies), so it is deleted and taken over. No PID files, no timeouts.
 */
export function acquireLock(lockPath: string): Promise<Lock> {
  return new Promise((resolve, reject) => {
    const server = net.createServer((socket) => socket.destroy());
    const lock: Lock = {
      close: () => {
        server.close();
        try {
          fs.unlinkSync(lockPath);
        } catch {
          // already gone
        }
      },
    };
    server.once("error", (err: NodeJS.ErrnoException) => {
      if (err.code !== "EADDRINUSE") {
        reject(err);
        return;
      }
      const probe = net.connect({ path: lockPath });
      probe.once("connect", () => {
        probe.destroy();
        reject(
          new Error("another pi process is already writing this OptChat log"),
        );
      });
      probe.once("error", (probeErr: NodeJS.ErrnoException) => {
        probe.destroy();
        if (probeErr.code !== "ECONNREFUSED") {
          reject(probeErr);
          return;
        }
        // Stale socket file from a dead owner: take it over.
        try {
          fs.unlinkSync(lockPath);
        } catch {
          // already gone
        }
        server.once("error", reject);
        server.listen({ path: lockPath }, () => resolve(lock));
      });
    });
    server.listen({ path: lockPath }, () => resolve(lock));
  });
}

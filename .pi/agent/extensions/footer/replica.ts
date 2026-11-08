/** Default footer layout based on pi 1.5.0's FooterComponent.
 * Uses public extension handles only; virtual-model routing is not exposed.
 */
import { isAbsolute, relative, resolve, sep } from "node:path";
import type {
  ExtensionContext,
  ReadonlyFooterDataProvider,
  Theme,
} from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

export function formatTokens(count: number): string {
  if (count < 1000) return count.toString();
  if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
  if (count < 1000000) return `${Math.round(count / 1000)}k`;
  if (count < 10000000) return `${(count / 1000000).toFixed(1)}M`;
  return `${Math.round(count / 1000000)}M`;
}

export function formatCwdForFooter(cwd: string, home?: string): string {
  if (!home) return cwd;
  const fromHome = relative(resolve(home), resolve(cwd));
  if (
    fromHome === ".." ||
    fromHome.startsWith(`..${sep}`) ||
    isAbsolute(fromHome)
  )
    return cwd;
  return fromHome === "" ? "~" : `~${sep}${fromHome}`;
}

function sanitizeStatusText(text: string): string {
  return text
    .replace(/[\r\n\t]/g, " ")
    .replace(/ +/g, " ")
    .trim();
}

type FooterContext = Pick<
  ExtensionContext,
  | "model"
  | "thinkingLevel"
  | "sessionManager"
  | "modelRegistry"
  | "getContextUsage"
>;
type Usage = {
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
  cost: { total: number };
};

export class ReplicaFooter {
  private cached?: {
    sessionId: string;
    leafId: string | null;
    entryCount: number;
    totals: {
      input: number;
      output: number;
      cacheRead: number;
      cacheWrite: number;
      cost: number;
    };
    latestCacheHitRate: number | undefined;
  };

  constructor(
    private readonly ctx: FooterContext,
    private readonly data: ReadonlyFooterDataProvider,
    private readonly theme: Pick<Theme, "fg" | "bold">,
    private readonly autoCompactEnabled: () => boolean,
    private readonly modelSuffix: () => string = () => "",
  ) {}

  invalidate(): void {
    this.cached = undefined;
  }

  private getStats() {
    const manager = this.ctx.sessionManager;
    // Unlike the internal SessionManager, the public view has no getEntryCount().
    const entries = manager.getEntries();
    const sessionId = manager.getSessionId();
    const leafId = manager.getLeafId();
    if (
      this.cached?.sessionId === sessionId &&
      this.cached.leafId === leafId &&
      this.cached.entryCount === entries.length
    )
      return this.cached;

    const totals = {
      input: 0,
      output: 0,
      cacheRead: 0,
      cacheWrite: 0,
      cost: 0,
    };
    const add = (usage: Usage) => {
      totals.input += usage.input;
      totals.output += usage.output;
      totals.cacheRead += usage.cacheRead;
      totals.cacheWrite += usage.cacheWrite;
      totals.cost += usage.cost.total;
    };
    let latestCacheHitRate: number | undefined;
    for (const entry of entries) {
      if (entry.type === "usage") {
        add(entry.usage);
      } else if (
        entry.type === "message" &&
        entry.message.role === "assistant"
      ) {
        const usage = entry.message.usage;
        add(usage);
        const prompt = usage.input + usage.cacheRead + usage.cacheWrite;
        latestCacheHitRate =
          prompt > 0 ? (usage.cacheRead / prompt) * 100 : undefined;
      } else if (
        entry.type === "message" &&
        entry.message.role === "toolResult" &&
        entry.message.usage
      ) {
        add(entry.message.usage);
      } else if (
        (entry.type === "branch_summary" || entry.type === "compaction") &&
        entry.usage
      ) {
        add(entry.usage);
      }
    }
    this.cached = {
      sessionId,
      leafId,
      entryCount: entries.length,
      totals,
      latestCacheHitRate,
    };
    return this.cached;
  }

  /** Separate model formatting so later additions need not change the stats layout. */
  private modelText(): string {
    const model = this.ctx.model;
    let text = model?.id || "no-model";
    if (model?.reasoning) {
      const level = this.ctx.thinkingLevel || "off";
      text += level === "off" ? " • thinking off" : ` • ${level}`;
    }
    const suffix = this.modelSuffix();
    return suffix ? `${text} • ${suffix}` : text;
  }

  render(width: number): string[] {
    const { totals, latestCacheHitRate } = this.getStats();
    const model = this.ctx.model;
    const context = this.ctx.getContextUsage();
    const contextWindow = context?.contextWindow ?? model?.contextWindow ?? 0;
    const percentValue = context?.percent ?? 0;
    const percent = context?.percent !== null ? percentValue.toFixed(1) : "?";
    let pwd = formatCwdForFooter(
      this.ctx.sessionManager.getCwd(),
      process.env.HOME || process.env.USERPROFILE,
    );
    const branch = this.data.getGitBranch();
    if (branch) pwd += ` (${branch})`;
    const sessionName = this.ctx.sessionManager.getSessionName();
    if (sessionName) pwd += ` • ${sessionName}`;

    const stats: string[] = [];
    if (totals.input) stats.push(`↑${formatTokens(totals.input)}`);
    if (totals.output) stats.push(`↓${formatTokens(totals.output)}`);
    if (totals.cacheRead) stats.push(`R${formatTokens(totals.cacheRead)}`);
    if (totals.cacheWrite) stats.push(`W${formatTokens(totals.cacheWrite)}`);
    if (
      (totals.cacheRead > 0 || totals.cacheWrite > 0) &&
      latestCacheHitRate !== undefined
    )
      stats.push(`CH${latestCacheHitRate.toFixed(1)}%`);
    const subscription =
      model &&
      (model.provider === "kimi-coding" ||
        (this.ctx.modelRegistry.isUsingOAuth(model) &&
          this.ctx.modelRegistry.getProvider(model.provider)?.auth.oauth
            ?.isSubscription === true));
    if (totals.cost || subscription)
      stats.push(`$${totals.cost.toFixed(3)}${subscription ? " (sub)" : ""}`);
    const auto = this.autoCompactEnabled() ? " (auto)" : "";
    let contextText =
      percent === "?"
        ? `?/${formatTokens(contextWindow)}${auto}`
        : `${percent}%/${formatTokens(contextWindow)}${auto}`;
    if (percentValue > 90) contextText = this.theme.fg("error", contextText);
    else if (percentValue > 70)
      contextText = this.theme.fg("warning", contextText);
    stats.push(contextText);
    if (process.env.PI_EXPERIMENTAL === "1")
      stats.push(
        `${this.theme.fg("dim", "•")} ${this.theme.bold(this.theme.fg("warning", "xp"))}`,
      );

    let left = stats.join(" ");
    let leftWidth = visibleWidth(left);
    if (leftWidth > width) {
      left = truncateToWidth(left, width, "...");
      leftWidth = visibleWidth(left);
    }
    const minPadding = 2;
    const withoutProvider = this.modelText();
    let right = withoutProvider;
    if (this.data.getAvailableProviderCount() > 1 && model) {
      right = `(${model.provider}) ${withoutProvider}`;
      if (leftWidth + minPadding + visibleWidth(right) > width)
        right = withoutProvider;
    }
    let line: string;
    if (leftWidth + minPadding + visibleWidth(right) <= width) {
      line = left + " ".repeat(width - leftWidth - visibleWidth(right)) + right;
    } else {
      const available = width - leftWidth - minPadding;
      if (available > 0) {
        const shortened = truncateToWidth(right, available, "");
        line =
          left +
          " ".repeat(Math.max(0, width - leftWidth - visibleWidth(shortened))) +
          shortened;
      } else {
        line = left;
      }
    }
    const lines = [
      truncateToWidth(
        this.theme.fg("dim", pwd),
        width,
        this.theme.fg("dim", "..."),
      ),
      this.theme.fg("dim", left) +
        this.theme.fg("dim", line.slice(left.length)),
    ];
    const statuses = this.data.getExtensionStatuses();
    if (statuses.size > 0) {
      const statusLine = Array.from(statuses.entries())
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([, text]) => sanitizeStatusText(text))
        .join(" ");
      lines.push(
        truncateToWidth(statusLine, width, this.theme.fg("dim", "...")),
      );
    }
    return lines;
  }
}

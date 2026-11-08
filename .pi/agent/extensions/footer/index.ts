/** Standalone replacement for pi's default footer. No OptChat dependency. */
import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { ReplicaFooter } from "./replica.ts";

export default function footerExtension(pi: ExtensionAPI) {
  let enabled = true;
  let requestRender: (() => void) | undefined;
  const modelSuffixes = new Map<string, string>();

  pi.events.on("footer:model-suffix", (data) => {
    const update = data as { id?: unknown; text?: unknown } | null;
    if (!update || typeof update.id !== "string" || !update.id) return;
    if (update.text !== undefined && typeof update.text !== "string") return;
    const text = update.text?.replace(/[\r\n\t]/g, " ").trim();
    if (text) modelSuffixes.set(update.id, text);
    else modelSuffixes.delete(update.id);
    requestRender?.();
  });

  function install(ctx: ExtensionContext): void {
    if (ctx.mode !== "tui") return;
    ctx.ui.setFooter((tui, theme, data) => {
      const footer = new ReplicaFooter(
        ctx,
        data,
        theme,
        () => pi.getSettings().compaction?.enabled ?? true,
        () => [...modelSuffixes.values()].join(" • "),
      );
      const render = () => tui.requestRender();
      requestRender = render;
      const unsubscribe = data.onBranchChange(render);
      return {
        render: (width) => footer.render(width),
        invalidate: () => footer.invalidate(),
        dispose() {
          unsubscribe();
          if (requestRender === render) requestRender = undefined;
        },
      };
    });
  }

  pi.on("session_start", (_event, ctx) => {
    modelSuffixes.clear();
    if (enabled) install(ctx);
    // Request current values even when a producer started before this footer.
    pi.events.emit("footer:request-model-suffix", {});
  });
  pi.on("model_select", () => requestRender?.());
  pi.on("thinking_level_select", () => requestRender?.());
  pi.on("session_shutdown", (_event, ctx) => {
    modelSuffixes.clear();
    if (enabled && ctx.mode === "tui") ctx.ui.setFooter(undefined);
  });
  pi.registerCommand("footer", {
    description:
      "Toggle the standalone footer replica and pi's built-in footer",
    handler: async (_args, ctx) => {
      if (ctx.mode !== "tui") {
        ctx.ui.notify("The footer requires interactive mode.", "warning");
        return;
      }
      enabled = !enabled;
      if (enabled) install(ctx);
      else ctx.ui.setFooter(undefined);
      ctx.ui.notify(
        enabled ? "Footer replica enabled." : "Built-in footer restored.",
        "info",
      );
    },
  });
}

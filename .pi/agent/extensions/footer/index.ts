/** Standalone replacement for pi's default footer. No OptChat dependency. */
import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { ReplicaFooter } from "./replica.ts";

export default function footerExtension(pi: ExtensionAPI) {
  let enabled = true;
  let requestRender: (() => void) | undefined;

  function install(ctx: ExtensionContext): void {
    if (ctx.mode !== "tui") return;
    ctx.ui.setFooter((tui, theme, data) => {
      const footer = new ReplicaFooter(
        ctx,
        data,
        theme,
        () => pi.getSettings().compaction?.enabled ?? true,
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
    if (enabled) install(ctx);
  });
  pi.on("model_select", () => requestRender?.());
  pi.on("thinking_level_select", () => requestRender?.());
  pi.on("session_shutdown", (_event, ctx) => {
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

# Footer

Standalone replacement based on pi 1.5.0's default footer. It runs without
OptChat and keeps the default directory/branch/session-name line, usage and
cost counters, cache-hit rate, context warnings, model/thinking display,
width fitting, and other extensions' status texts.

The replica is enabled when the extension loads in interactive mode.
Use `/footer` to switch between it and pi's built-in footer for comparison.
Reload enables the replica again. Like any `setFooter` extension, it owns
Pi's single custom-footer slot while enabled.

`replica.ts` owns the layout; `index.ts` handles installation and lifecycle.
No compactor display or OptChat integration is included yet. Those can be
added later without making OptChat responsible for rendering the footer.

The public extension API does not expose the live virtual-model routing
state, so the default footer's routed-model arrow is not replicated.
Subscription markers are resolved through the public model registry.
The layout should be checked against upstream when upgrading pi.

## Install

Link this directory into `~/.pi/agent/extensions/footer`, then `/reload`.
No environment variables or OptChat configuration are required.

## Tests

```sh
node test/footer.test.mjs /path/to/@earendil-works/pi-coding-agent
```

Tests use the installed pi loader and compare rendered output with pi's
built-in footer across widths, themes, usage sources, and state changes.
They also exercise standalone loading, toggling, and watcher cleanup.
No model calls are made.

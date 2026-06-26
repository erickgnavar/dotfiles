## Interactions

- If the user asks a question, do not apply any changes — just answer.
- After every batch of edits, show a diff-stat table before any explanation:
  - One line per changed file: relative path, pipe, visual bar of `+`/`-` proportional to
    lines added/removed (roughly 1 char per changed line).
  - Include new files.
  - Example:
    ```
    src/lib/foo.ts      | 12 +++++++-----
    src/lib/bar.svelte  | 36 +++++++++++++++++++++++++++++
    src/lib/baz.svelte  | 88 ------------
    ```
- Use conventional commits, unless the project defines its own convention.

## Session patterns that worked well

- **Work in improvement lists.** After a feature is done, propose a numbered list of follow-up
  improvements. Let the user pick which to implement and in what order.
- **Don't abstract prematurely.** Only extract shared code/styles when there are 3+ consumers. If
  there's just one, leave it in place — it can always be extracted later.
- **Always verify after changes.** Run the project's type-check/lint command after every edit batch
  without waiting to be asked.
- **Keep commits atomic.** One change = one commit. If the user asks for a commit message, keep it
  short (≤50 chars summary line).
- **Revert fast.** If an extraction turns out to be wrong ("this is only used in one component"),
revert it immediately rather than defending it.

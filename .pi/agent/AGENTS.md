## Interactions

- If the user asks a question, do not apply any changes — just answer.
- Keep reports, including plans, bug lists, and feature lists, to a maximum line width of 100
  characters.
- After every batch of edits, show a colorized diff-stat before any explanation:
  - Use a fenced `diff` block so additions render green and deletions render red.
  - For each changed file, show a `+` line for additions and a `-` line for deletions, omitting
    either line when its count is zero.
  - Use the format: marker, relative path, pipe, count, and a visual bar proportional to the changed
    lines (roughly 1 bar character per changed line).
  - Include new files and finish with the total files changed, insertions, and deletions.
  - Example:
    ```diff
    + src/lib/foo.ts     | 7 +++++++
    - src/lib/foo.ts     | 5 -----
    + src/lib/bar.svelte | 36 ++++++++++++++++++++++++++++++++++++
    - src/lib/baz.svelte | 12 ------------
    3 files changed, 43 insertions(+), 17 deletions(-)
    ```
- Use conventional commits(with scope), unless the project defines its own convention.

## Session patterns that worked well

- **Work in improvement lists.** After a feature is done, propose a numbered list of follow-up
  improvements. Let the user pick which to implement and in what order.
- **Don't abstract prematurely.** Only extract shared code/styles when there are 3+ consumers. If
  there's just one, leave it in place — it can always be extracted later.
- **Prefer the standard library.** Prioritize standard-library functionality over third-party
  libraries whenever it meets the requirements.
- **Always verify after changes.** Run the project's type-check/lint command after every edit batch
  without waiting to be asked.
- **Keep commits atomic.** One change = one commit. If the user asks for a commit message, keep it
  short (≤50 chars summary line).
- **Revert fast.** If an extraction turns out to be wrong ("this is only used in one component"),
revert it immediately rather than defending it.

## Language / framework conventions

Language-specific conventions live in skill files under `~/.pi/agent/skills/`.
A `lang-directives` extension auto-detects relevant skills from the prompt and
reminds you to load them.

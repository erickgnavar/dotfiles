---
name: terraform
description: Safe, minimal Terraform changes. Use for HCL, plans, upgrades, and commands.
---

# Terraform Conventions

## Inspect before editing

- Project-specific instructions and established repository conventions take precedence over this
  skill.
- Read the applicable instructions, `.editorconfig`, version files, and environment README.
- Inspect the current diff first and preserve user changes.
- Find the closest working resource in the same repository and follow its naming, ordering, and
  environment-specific patterns.
- Confirm the requested environment and exact resource scope. Do not silently expand the rollout.
- Before planning, verify the module directory, backend or workspace, cloud account, project or
  subscription, region, and variable files or inputs. Report anything that cannot be confirmed.
- Reuse existing variables, locals, resources, outputs, and computed values before adding data
  sources or duplicate configuration.

## Keep changes minimal

- Make targeted edits only. Do not reformat unrelated blocks or files.
- Preserve block ordering and heredoc indentation when possible to avoid noisy plans and diffs.
- Format only edited Terraform files, then inspect the diff and revert incidental formatting.
- Do not modify `.terraform.lock.hcl` unless dependency selection is part of the request.
- Never edit state files, generated plans, `.terraform/`, or secret-bearing variable files.
- Do not add inferred IAM roles, resources, environment variables, or abstractions beyond the stated
  requirement. Copy an existing pattern only after checking which parts are actually required.
- Keep development and production behavior distinct, and modify both only when requested.

## Validate safely

From the correct module or environment directory, use the repository's selected Terraform or
OpenTofu toolchain and existing wrappers. Respect pinned versions from `mise`, version files, or
wrapper configuration instead of substituting a globally installed binary. Prefer this sequence
when available:

1. `<tool> fmt -check <edited files>`
2. `<tool> validate`
3. The project's lint or test command, such as `tflint`

Use `mise` when the repository selects the tool through it. Do not run `terraform init` or
`tofu init` merely to make
validation pass without first considering backend access and lockfile changes. Report commands that
cannot run because credentials, providers, or initialization are unavailable.

## Plan and apply safety

- Never run `terraform apply`, `destroy`, `import`, or state-changing commands unless the user
  explicitly asks you to execute them.
- Before suggesting an apply, inspect or request a fresh plan and separate intended changes from
  drift, unrelated changes, and provider-default churn.
- Call out counts for create, update, replace, and destroy, plus likely downtime, restart, or
  data-loss effects. Validation or a no-op-looking configuration diff does not prove runtime safety.
- Treat `-/+`, `+/-`, and `forces replacement` as replacement. Do not call them in-place changes.
- Use `-target` only for exceptional, user-requested isolation. Explain that it can produce an
  incomplete plan and recommend a full plan afterward.
- When giving targeted commands, quote resource addresses containing indexes or string keys.
- Use an existing secrets wrapper, such as `1p_run_with_env.py .env --`, only when the repository
  uses it. Preserve the user's requested working directory and command shape.
- Do not use unavailable version-control tools; inspect files and diffs directly.

## Terraform-specific review points

- For provider upgrades, read the official upgrade guide and changelog, then cross-reference every
  affected resource and argument used by the repository. Keep lockfile changes intentional.
- Distinguish cloud IAM roles from instance OAuth/API scopes; one does not imply the other.
- Verify whether fields force replacement or require stop/start by checking the provider schema or
  official documentation instead of guessing.
- Keep temporary `moved` blocks until the migration has been successfully applied, then remove them
  in a separate cleanup.
- When reviewing a plan, do not dismiss changes under outputs, computed collections, or externally
  changed objects; explain whether configuration will preserve, undo, or ignore the drift.

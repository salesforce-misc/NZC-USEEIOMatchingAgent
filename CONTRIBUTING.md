# Contributing to USEEIO Matching Agent

Thank you for contributing. This document is the **policy of record** for how work lands in this repository.

## 1. Canonical repository

`salesforce-misc/NZC-USEEIOMatchingAgent` is the **single source of truth** for this project.

- All new development happens here.
- The earlier repo `nicholaschughes/USEEIOMatchingAgent` is **no longer synced from**; do not open PRs against it expecting them to flow here, and do not commit there expecting it to migrate.
- There is intentionally **no `upstream` git remote**. Do not re-add one.

If you previously worked in the old repo and need write access here, ask `@carlosvl` for collaborator access.

## 2. Branch and PR workflow

`main` is **protected**:

- Direct pushes are blocked. All changes go through pull requests.
- At least **one approving review from a CODEOWNER** is required (see [`.github/CODEOWNERS`](./.github/CODEOWNERS)).
- **Stale reviews are dismissed** when new commits are pushed to the PR.
- **Linear history** is required — merge with squash or rebase, no merge commits.
- **Force pushes and branch deletions** on `main` are disabled.
- **All review conversations** must be resolved before merge.

### Standard flow

```bash
# Always branch off latest main
git checkout main
git pull --ff-only
git checkout -b feat/short-description    # or fix/, chore/, docs/

# Make commits with imperative-mood messages
git commit -m "Add Scope3 matching threshold override"

# Push and open PR
git push -u origin feat/short-description
gh pr create --base main --fill
```

### Branch naming conventions

| Prefix    | Use for                                       |
| --------- | --------------------------------------------- |
| `feat/`   | New capability                                |
| `fix/`    | Bug fix                                       |
| `chore/`  | Build/tooling/config-only changes             |
| `docs/`   | Documentation-only changes                    |
| `refactor/` | Internal restructuring with no behavior change |
| `test/`   | Adding or refactoring tests                   |

## 3. Commit message style

Follow [Conventional Commits](https://www.conventionalcommits.org/) loosely:

```
<type>: <short imperative summary>

<optional body explaining *why* — not *what* (the diff shows what)>
```

`type` is one of `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `perf`, `build`, `ci`.

## 4. Coding standards

This is a Salesforce DX project with Apex and Lightning Web Components. Before submitting code, read the relevant guides:

- [`REPOSITORY_SUMMARY.md`](./REPOSITORY_SUMMARY.md) — orientation, architecture, and documentation index.
- [`documentation/standards/SALESFORCE_BEST_PRACTICES.md`](./documentation/standards/SALESFORCE_BEST_PRACTICES.md) — Apex/LWC patterns specific to this app, including Queueable (not `@future`), Prompt Builder–first LLM configuration, and review guardrails.
- [`.cursor/rules/Salesforce Quality.mdc`](./.cursor/rules/Salesforce%20Quality.mdc) — quality bar enforced in code review (security, governance, style).

### Apex specifics

- **Always declare sharing** on every class: `with sharing`, `without sharing`, or `inherited sharing`. Do not rely on the default.
- **Bulkify** — no SOQL/DML inside loops.
- **No hardcoded credentials**; use Named Credentials and Custom Metadata.
- Add Javadoc class headers with `@description`, `@author`, `@date`.

### LWC specifics

- **JSDoc every `@api` property** (`@type`, `@description`).
- Set `<masterLabel>` and `<description>` in `*.js-meta.xml` for any component exposed to admins.
- Tests via `sfdx-lwc-jest` under `__tests__/`.

### Pre-commit

`husky` + `lint-staged` are configured. Lint/Prettier run automatically on staged files. Do not skip hooks with `--no-verify`.

## 5. Documentation

- Project-level docs live under [`documentation/`](./documentation/), organized into thematic subfolders. See the index in [`REPOSITORY_SUMMARY.md` §8](./REPOSITORY_SUMMARY.md).
- New design or operational docs belong in the matching subfolder (`architecture/`, `llm-grounding/`, `llm-integration/`, `reference/`, `standards/`, `testing/`, `operations/`, `implementation/`).
- Link new docs from `REPOSITORY_SUMMARY.md` so they're discoverable.

## 6. License

This project is licensed under the **Apache License, Version 2.0**. See [`LICENSE`](./LICENSE).

By contributing, you agree your contributions are licensed under the same terms.

## 7. Questions

For access, scoping, or roadmap questions, reach out to `@carlosvl` or `@nicholaschughes` via the issue tracker.

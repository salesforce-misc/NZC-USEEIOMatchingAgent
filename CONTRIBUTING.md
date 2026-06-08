# Contributing Guide For USEEIO Matching Agent

This page lists the operational governance model of this project, as well as the recommendations and requirements for how to best contribute to the **USEEIO Matching Agent**. We strive to obey these as best as possible. As always, thanks for contributing – we hope these guidelines make it easier and shed some light on our approach and processes.

## Canonical repository

[`salesforce-misc/NZC-USEEIOMatchingAgent`](https://github.com/salesforce-misc/NZC-USEEIOMatchingAgent) is the **single source of truth** for this project.

- All new development happens here.
- The earlier repo `nicholaschughes/USEEIOMatchingAgent` is **no longer synced from**; do not open PRs against it expecting them to flow here, and do not commit there expecting it to migrate.
- There is intentionally **no `upstream` git remote**. Do not re-add one.

If you previously worked in the old repo and need write access here, ask a project maintainer (see [CODEOWNERS](./CODEOWNERS)) for collaborator access.

# Governance Model

## Salesforce Sponsored

The intent and goal of open sourcing this project is to increase the contributor and user base. However, only Salesforce employees will be given `admin` rights and will be the final arbiters of what contributions are accepted or not.

Current maintainers: see [CODEOWNERS](./CODEOWNERS).

# Getting started

1. Read the project [README](./README.md) and [REPOSITORY_SUMMARY.md](./REPOSITORY_SUMMARY.md) (the primary onboarding doc).
2. Review the documentation under [`documentation/`](./documentation/) — design notes are organized by theme (architecture, LLM integration, standards, testing, operations, etc.).
3. Set up a Salesforce DX scratch org or sandbox; see [`documentation/operations/`](./documentation/operations/).
4. For LLM/Prompt Builder configuration, see [`documentation/llm-integration/`](./documentation/llm-integration/).

# Issues, requests & ideas

Use the [GitHub Issues](https://github.com/salesforce-misc/NZC-USEEIOMatchingAgent/issues) page to submit issues, enhancement requests and discuss ideas.

### Bug Reports and Fixes
- If you find a bug, please search for it in [Issues](https://github.com/salesforce-misc/NZC-USEEIOMatchingAgent/issues), and if it isn't already tracked, [create a new issue](https://github.com/salesforce-misc/NZC-USEEIOMatchingAgent/issues/new). Even if an Issue is closed, feel free to comment and add details — it will still be reviewed.
- Issues that have already been identified as a bug (note: able to reproduce) will be labelled `bug`.
- If you'd like to submit a fix for a bug, [send a Pull Request](#creating-a-pull-request) and mention the Issue number.
- Include tests that isolate the bug and verify that it was fixed.

### New Features
- If you'd like to add new functionality to this project, describe the problem you want to solve in a [new Issue](https://github.com/salesforce-misc/NZC-USEEIOMatchingAgent/issues/new).
- Issues that have been identified as a feature request will be labelled `enhancement`.
- If you'd like to implement the new feature, please wait for feedback from the project maintainers before spending too much time writing the code. In some cases, `enhancement`s may not align well with the project objectives at the time.

### Tests, Documentation, Miscellaneous
- If you'd like to improve the tests, make the documentation clearer, or have an alternative implementation of something that may have advantages over the way it's currently done, we'd be happy to hear about it.
- If it's a trivial change, go ahead and [send a Pull Request](#creating-a-pull-request) with the changes you have in mind.
- If not, [open an Issue](https://github.com/salesforce-misc/NZC-USEEIOMatchingAgent/issues/new) to discuss the idea first.

If you're new to our project and looking for some way to make your first contribution, look for Issues labelled `good first contribution`.

# Contribution Checklist

- [x] Clean, simple, well-styled code.
- [x] Commits are atomic and messages are descriptive (we use [Conventional Commits](https://www.conventionalcommits.org/) loosely — `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `perf`, `build`, `ci`). Related issues should be mentioned by Issue number.
- [x] Comments
  - Class-level and method-level Javadoc/JSDoc.
  - Comments on complex blocks of code or algorithms (include references to sources).
- [x] Tests
  - Apex unit tests (`sf apex run test --test-level RunLocalTests`) must pass.
  - LWC unit tests (`npm run test:unit`) must pass.
  - Increase code coverage, not the reverse.
- [x] Dependencies
  - Minimize number of dependencies.
  - Prefer Apache 2.0, BSD-3, MIT, ISC, and MPL-licensed dependencies.
- [x] Reviews
  - Changes must be approved via peer code review (≥ 1 approving review from a [CODEOWNER](./CODEOWNERS)).

## Salesforce-specific standards

This is a Salesforce DX project with Apex and Lightning Web Components. The project-specific guides:

- [`REPOSITORY_SUMMARY.md`](./REPOSITORY_SUMMARY.md) — orientation, architecture, and documentation index.
- [`documentation/standards/SALESFORCE_BEST_PRACTICES.md`](./documentation/standards/SALESFORCE_BEST_PRACTICES.md) — Apex/LWC patterns specific to this app (Queueable not `@future`, Prompt Builder–first LLM configuration, review guardrails).
- [`.cursor/rules/Salesforce Quality.mdc`](./.cursor/rules/Salesforce%20Quality.mdc) — quality bar enforced in code review (security, governance, style).

**Apex specifics**

- **Always declare sharing** on every class: `with sharing`, `without sharing`, or `inherited sharing`. Do not rely on the default.
- **Bulkify** — no SOQL/DML inside loops.
- **No hardcoded credentials**; use Named Credentials and Custom Metadata.
- Add Javadoc class headers with `@description`, `@author`, `@date`.

**LWC specifics**

- **JSDoc every `@api` property** (`@type`, `@description`).
- Set `<masterLabel>` and `<description>` in `*.js-meta.xml` for any component exposed to admins.
- Tests via `sfdx-lwc-jest` under `__tests__/`.

**Pre-commit**

`husky` + `lint-staged` are configured. Lint/Prettier run automatically on staged files. Do not skip hooks with `--no-verify`.

# Creating a Pull Request

`main` is **protected**:

- Direct pushes are blocked. All changes go through pull requests.
- At least **one approving review from a CODEOWNER** is required (see [`CODEOWNERS`](./CODEOWNERS)).
- **Stale reviews are dismissed** when new commits are pushed to the PR.
- **Linear history** is required — merge with squash or rebase, no merge commits.
- **Force pushes and branch deletions** on `main` are disabled.
- **All review conversations** must be resolved before merge.

### Standard flow

1. **Ensure the bug/feature was not already reported** by searching [Issues](https://github.com/salesforce-misc/NZC-USEEIOMatchingAgent/issues). If none exists, create a new issue so other contributors can keep track of what you are trying to add/fix and offer suggestions.
2. **Clone** the repo (or your fork) to your machine.
3. **Branch** off the latest `main` using a descriptive prefix:

   | Prefix       | Use for                                       |
   | ------------ | --------------------------------------------- |
   | `feat/`      | New capability                                |
   | `fix/`       | Bug fix                                       |
   | `chore/`     | Build/tooling/config-only changes             |
   | `docs/`      | Documentation-only changes                    |
   | `refactor/`  | Internal restructuring with no behavior change |
   | `test/`      | Adding or refactoring tests                   |

   ```bash
   git checkout main
   git pull --ff-only
   git checkout -b feat/short-description
   ```

4. **Commit** atomic, descriptive commits.
5. **Push** your branch and open a Pull Request against `main`, referencing any related Issue(s).
6. **Sign** the [Salesforce CLA](https://cla.salesforce.com/sign-cla) — you'll be prompted to do so when submitting the Pull Request.

> **NOTE**: If you're working from a fork, [sync your fork](https://help.github.com/articles/syncing-a-fork/) before opening a pull request.

# Contributor License Agreement ("CLA")

In order to accept your pull request, we need you to submit a CLA. You only need to do this once to work on any of Salesforce's open source projects.

Complete your CLA here: <https://cla.salesforce.com/sign-cla>

# Code of Conduct

Please follow our [Code of Conduct](./CODE_OF_CONDUCT.md). Report unacceptable behavior to <ossconduct@salesforce.com>.

# Security

To report a security vulnerability, please see [SECURITY.md](./SECURITY.md). Do **not** open a public GitHub issue for security-sensitive reports.

# License

By contributing your code, you agree to license your contribution under the terms of our project [LICENSE.txt](./LICENSE.txt) (Apache License 2.0) and to sign the [Salesforce CLA](https://cla.salesforce.com/sign-cla).

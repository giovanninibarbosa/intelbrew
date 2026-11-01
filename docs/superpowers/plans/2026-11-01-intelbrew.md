---
last_review_date: "2026-11-01"
---

# Intelbrew Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.
> Steps use checkbox syntax for tracking.

**Goal:** Establish Intelbrew as a maintained Intel macOS fork with unchanged `brew` commands and updates that retain the fork.

**Architecture:** Retain Homebrew's Ruby/Bash structure, package interfaces and bootstrap assets.
Use a small shared Bash release selector, independent fork update defaults and accurate Intel diagnostics.
Add a dedicated Intel CI workflow and migration documentation without creating package infrastructure.

**Tech Stack:** Bash 3.2, Ruby 4.0, Sorbet, RSpec, RuboCop, Git and GitHub Actions.

**Spec:** [Approved Intelbrew design](../specs/2026-11-01-intelbrew-design.md).

## Global constraints

- Intel x86_64 macOS Big Sur 11 through Tahoe 26 is a compatibility target, not a claim of testing on every release.
- Use `Intelbrew` as the display name and `intelbrew` as the repository name.
- The default brew repository is `https://github.com/giovanninibarbosa/intelbrew`.
- Keep `brew`, its options, `Homebrew` Ruby namespaces, `HOMEBREW_*` settings, `/usr/local` and `/usr/local/Homebrew`.
- Leave core, cask, bottle and API defaults unchanged; retain checksums, artifact verification, licence files and upstream attribution.
- Normal updates follow `origin/HEAD`; explicit `HOMEBREW_UPDATE_TO_TAG` selects only `intelbrew-X.Y.Z` tags and fails if none exist.
- Keep Apple Silicon and Linux paths intact; do not claim restored bottle coverage or universal Tier 1 support.
- Use only this checkout's `./bin/brew`; Ruby runs through `./bin/brew ruby --`.
- Follow root and docs `AGENTS.md`; changed examples require exact `--only=file:line` red/green runs.
- Run `HOMEBREW_NO_AUTO_UPDATE=1 ./bin/brew lgtm --online` before commits and before asking the user for input.
- Amend the existing task commit for related work; do not sign commits, add AI trailers, push or modify the user's installed package manager.
- The approved execution method is subagent-driven development; implementation tasks run sequentially with an independent task review.

## Review focus

- A fork containing inherited numeric tags must stay on fork code during both normal and automatic updates: Task 2 tests actual Git revisions.
- An explicit release request with no valid fork tags must fail before changing a checkout or discarding local files: Task 2 tests the revision and dirty file.
- Cached versions containing a fork tag prefix and dirty development versions must remain usable by version consumers: Task 1 tests cache hits and misses.
- Existing third-party taps and explicit remote overrides must preserve their own remotes and branch behaviour: Task 2 uses temporary repositories.
- Old Intel macOS must retain useful toolchain/package warnings while supported Apple Silicon diagnostics remain unchanged: Task 3 exercises both inputs.

## File responsibilities

- `Library/Homebrew/utils/git.sh`: shared release tag selection and internal version normalisation.
- `Library/Homebrew/cmd/--version.sh` and `--version.rb`: project display identity.
- `Library/Homebrew/brew.sh`, `cmd/update.sh` and `cmd/update-reset.sh`: fork repository and update policy.
- `Library/Homebrew/env_config.rb`: document the explicit release setting.
- `Library/Homebrew/diagnostic.rb` and `extend/os/mac/diagnostic.rb`: shared Intel guidance and thin OS-specific selection.
- `Library/Homebrew/help.sh` and `.github/ISSUE_TEMPLATE/config.yml`: primary fork help routing.
- `.github/workflows/intelbrew.yml`: CI for the checked-out fork on Intel.
- `README.md`, `docs/Intelbrew.md`, `docs/Installation.md` and `docs/Support-Tiers.md`: identity, adoption and support boundaries.
- `manpages/` and `completions/`: regenerate only when command/environment documentation requires it.

### Task 1: identify the fork and handle release metadata

**Files:**

- Modify: `Library/Homebrew/utils/git.sh`, `Library/Homebrew/cmd/--version.sh`, `Library/Homebrew/cmd/--version.rb`.
- Test: `Library/Homebrew/test/bash_spec.rb`, `Library/Homebrew/test/cmd/--version_spec.rb`.
- Generated documentation is regenerated together with Task 2's documentation changes.

**Interfaces:**

- Consumes: `set-homebrew-version-from-git()`, `HOMEBREW_VERSION` and the existing shell version command.
- Produces: `latest-intelbrew-tag(repository)`, a Bash function printing the highest version-sorted full `intelbrew-X.Y.Z` tag, returning nonzero with no stdout when none match.
- Produces: internal versions with the `intelbrew-` prefix removed, preserving Git's development/dirty suffixes.

- [x] **Step 1: Add failing behavioural tests.**
  Extend the existing version integration example to expect `/^Intelbrew #{Regexp.escape(HOMEBREW_VERSION)}\n/o`, keeping its existing success/stderr checks.
  In `bash_spec.rb`, use temporary real Git repositories and `Open3.capture3` to check `latest-intelbrew-tag` selects `intelbrew-7.0.10` from `intelbrew-7.0.2`, `intelbrew-7.0.10`, inherited `99.0.0` and malformed/prerelease tags.
  The no-valid-tag case expects `[stdout, status.success?] == ["", false]`.
  Extend version-cache examples so a freshly described and previously cached `intelbrew-7.0.10` both expose `7.0.10`; a dirty development value keeps its suffix.
  Ensure an inherited upstream development version still works before the first fork release.

- [x] **Step 2: Run each changed example at its actual line.**
  Use `./bin/brew tests --only=bash:LINE` and `./bin/brew tests --only=cmd/--version:LINE`.
  Record the exact failing assertions before product changes.
  Use the existing integration-test flag if needed to execute the version example.

- [x] **Step 3: Implement the metadata contract.**
  Add `latest-intelbrew-tag()` to `utils/git.sh`, with strict matching of three numeric components and Git version sorting.
  Use a selector that does not fail because of SIGPIPE when many tags exist.
  Prefer fork tags for version descriptions where available, fall back to the existing upstream-derived description before a fork release and normalise both cached and fresh values.
  Change only the project's display label and version command description, leaving actual tap identifiers intact.
  Keep shell compatibility and existing ownership restrictions on cache writes.

- [x] **Step 4: Verify and hand off.**
  Rerun exact examples green, then `./bin/brew tests --only=bash` and the version integration example.
  Run `HOMEBREW_NO_AUTO_UPDATE=1 ./bin/brew lgtm --online`, inspect the diff and amend the task commit with a subject under 51 characters.
  Report the helper interface and exact red/green commands for Task 2 and the reviewer.

### Task 2: keep all self-update paths on the fork

**Files:**

- Modify: `Library/Homebrew/brew.sh`, `Library/Homebrew/cmd/update.sh`, `Library/Homebrew/cmd/update-reset.sh`, `Library/Homebrew/cmd/update-report.rb`, `Library/Homebrew/env_config.rb` and `Library/Homebrew/utils/git.rb` if needed for shared release metadata.
- Test: `Library/Homebrew/test/cmd/update_spec.rb`, `Library/Homebrew/test/cmd/update-reset_spec.rb`, `Library/Homebrew/test/cmd/update-report_spec.rb`, `Library/Homebrew/test/bash_spec.rb` and the matching Git utility specs if changed.
- Generate: affected files under `manpages/` and `completions/` using `./bin/brew generate-man-completions`.

**Interfaces:**

- Consumes: `latest-intelbrew-tag(repository)` from Task 1.
- Produces: the existing `homebrew-update()` and `homebrew-update-reset()` commands with fork branch defaults and explicit fork-tag selection.
- Produces: unchanged environment-variable names and explicit remote override semantics.

- [x] **Step 1: Add failing update regressions using isolated repositories.**
  Extend the existing shell harness in `cmd/update_spec.rb`; use real local Git repositories and local remotes, substituting only unrelated network/API/reporting work.
  Cover normal and `--auto-update` runs on non-developer installs with inherited `99.0.0` tags: the checked-out revision must equal the fork default branch tip.
  Test a non-`main` default branch, explicit remote overrides and a third-party tap retaining its own branch.
  Test explicit release mode choosing `intelbrew-7.0.10` over `intelbrew-7.0.2` and ignoring inherited/malformed tags.
  Add equivalent branch/tag tests for `update-reset`.
  With no matching release, assert a failing exit, actionable stderr, the original revision and preservation of an uncommitted marker file before destructive reset operations.
  Test bootstrap default-remote output through executable shell behaviour, including a user-supplied override; do not assert source text.
  Test update reporting with no tags before the first fork release, inherited/malformed tags and valid fork releases; reports must describe actual revision changes and link to the fork's release.

- [x] **Step 2: Run new examples red.**
  Record exact `./bin/brew tests --only=cmd/update:LINE`, `--only=cmd/update-reset:LINE` and `--only=bash:LINE` targets.
  No test may update, clean or reset the development checkout or the user's actual installation.

- [x] **Step 3: Implement branch and release policy.**
  Set only `HOMEBREW_BREW_DEFAULT_GIT_REMOTE` to the approved fork URL.
  Remove the implicit non-developer tag preference while preserving deliberate `HOMEBREW_UPDATE_TO_TAG`.
  Use the shared selector in both update commands; missing fork releases must fail before any checkout/reset/clean.
  In explicit release mode, refuse an existing core directory without `.git` before bootstrap/reset and explain how to initialise it through a normal branch update before retrying.
  Keep a user's explicit brew remote and all tap remote choices intact.
  Preserve failure propagation from shell subshells and automatic updates, and existing cleanup/developer behaviour unrelated to tag selection.
  Update the environment setting description to explain namespaced Intelbrew releases.
  Make update reporting tolerate the absence of a fork release, select valid fork metadata, normalise prefixes before version comparisons and use the fork's release links.
  If Ruby mirrors the shared Bash tag selector, keep the helpers in matching Git utility files with two-way comments and focused parity tests.
  Regenerate documentation for Task 1 and this task, retaining only changes caused by their sources.

- [x] **Step 4: Verify and hand off.**
  Run exact examples green, then `./bin/brew tests --only=cmd/update`, `--only=cmd/update-reset` and `--only=bash`.
  Run `HOMEBREW_NO_AUTO_UPDATE=1 ./bin/brew lgtm --online`, inspect the diff and amend the existing commit.
  Report any unexercised network paths explicitly; do not run a real `brew update` against this development branch.

### Task 3: give accurate support guidance

**Files:**

- Modify: `Library/Homebrew/diagnostic.rb`, `Library/Homebrew/extend/os/mac/diagnostic.rb`, `Library/Homebrew/help.sh`, `.github/ISSUE_TEMPLATE/config.yml`.
- Test: `Library/Homebrew/test/diagnostic/macos_bottle_remediation_spec.rb`, `Library/Homebrew/test/os/mac/diagnostic_spec.rb`, `Library/Homebrew/test/bash_spec.rb`.

**Interfaces:**

- Consumes: existing `macos_bottle_remediation(version, intel:)`, `check_for_unsupported_macos` and `Diagnostic::Finding`.
- Produces: accurate Intelbrew guidance through existing diagnostic interfaces without introducing a new support tier.

- [x] **Step 1: Write failing diagnostic examples.**
  For Intel versions `11`, `13`, `15.7` and `26.1`, assert the shared remediation says Intelbrew retains Intel support, upstream no longer supplies new Intel bottles and updated formulae may build from source.
  Preserve assertions for future Intel versions, outdated Apple Silicon and currently supported Apple Silicon.
  Update OS-specific examples to retain Tier 3/package limitations while replacing the statement that this project cannot support Intel.
  Preserve existing missing developer-tool checks; do not add OS-only tests for new shared logic.
  Add a small shell help execution example verifying `brew install` remains documented and the fork guide is the help destination.

- [x] **Step 2: Run exact changed examples red.**
  Use `./bin/brew tests --only=diagnostic/macos_bottle_remediation:LINE`, `--only=os/mac/diagnostic:LINE` and `--only=bash:LINE`.

- [x] **Step 3: Implement minimal support changes.**
  Keep substantive new messaging in shared `diagnostic.rb`; make the OS-specific method select that guidance for in-range Intel versions while retaining old-OS and toolchain warnings.
  Do not alter minimum OS, CPU detection, portable Ruby manifests, bottle selection, checksums or verification.
  Replace the generic help destination with the fork's `docs/Intelbrew.md` page and point primary issue-template contact links to the fork.
  Preserve upstream contribution references where they are specifically about upstream formulae/casks.
  Do not change `OS::ISSUES_URL` merely to enable reporting: its definition also controls support-tier detection.

- [x] **Step 4: Verify and hand off.**
  Rerun exact examples green and the affected diagnostic and Bash test files.
  Run existing hardware and bottle tests if relevant changed behaviour touches their boundaries; otherwise document those unchanged paths for final review.
  Run `HOMEBREW_NO_AUTO_UPDATE=1 ./bin/brew lgtm --online`, inspect the diff and amend the existing commit.

### Task 4: make the fork operable and document adoption

**Files:**

- Create: `.github/workflows/intelbrew.yml`, `docs/Intelbrew.md`.
- Modify: `README.md`, `docs/Installation.md`, `docs/Support-Tiers.md`.
- Update: this plan's completion checkboxes and the design status if needed.
- No tests that merely inspect documentation or workflow source text.

**Interfaces:**

- Consumes: the update channel, release names, version output and guidance implemented by Tasks 1–3.
- Produces: a fork-specific Intel CI workflow and instructions that match the implemented migration/update policy.

- [x] **Step 1: Add a narrowly scoped Intel CI workflow.**
  Verify the `macos-15-intel` runner label in [GitHub's runner documentation](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).
  Trigger on pull requests, pushes to `main` and manual dispatch for this fork, with `contents: read` permissions and no upstream secrets.
  Pin checkout to the repository's existing reviewed action revision and fetch complete Git history for changed-file checks.
  Verify `uname -m` is `x86_64`, disable automatic updates/analytics during validation and invoke only the checked-out `./bin/brew`.
  Run type/style/relevant tests, plus the Bash, version and changed Intel diagnostic regressions so a new `main` push cannot silently exercise zero relevant tests.
  Do not enable upstream publication workflows or claim hosted execution has passed before a remote run exists.

- [x] **Step 2: Write the Intelbrew operations guide and identity documentation.**
  Describe macOS 11–26 as a runtime target, list actual local/CI coverage and distinguish upstream Tier 3 packages from fork runtime maintenance.
  Explain missing new Intel bottles, source-build/toolchain requirements, portable Ruby dependency and third-party Intel incompatibilities.
  Keep `brew` command examples and paths unchanged.
  In the README, replace project identity and primary links, preserve Homebrew attribution/licences and remove or clearly label upstream organisation, sponsorship and donation claims.
  Put visible fork-policy notices in Installation and Support Tiers, linking to the guide and identifying retained text as upstream policy.

- [x] **Step 3: Document and exercise migration and rollback in disposable Git repositories.**
  The guide first records the old source/revision and exports a package list, requires a clean repository and uses the user's existing `brew` only to locate that installation.
  Explain saved environment overrides and unset explicit tag mode before adopting the branch channel.
  Fetch the fork, set the installation's origin to the fork and explicitly check out the fork's default branch; never recommend only changing a remote and then running the old updater.
  Preserve Cellar/package contents and provide rollback restoring the recorded remote and revision.
  Describe any destructive command before presenting it and avoid forced reset/checkout in the migration happy path.
  Run equivalent branch operations on local fixture repositories with a dirty-worktree refusal case and a marker representing installed packages.
  Do not execute the published migration commands on the user's installation or this development checkout.

- [x] **Step 4: Verify documentation and the complete implementation.**
  Run `./bin/brew --version`, `./bin/brew --help`, the focused tests from Tasks 1–3 and `HOMEBREW_NO_AUTO_UPDATE=1 ./bin/brew lgtm --online`.
  Run `./bin/brew style docs` and the required docs site, Markdown and Vale checks from `docs/AGENTS.md`, using this checkout's brew to honour the user's higher-priority command constraint.
  Resolve tooling prerequisites locally when practical; record exact environmental failures instead of claiming checks passed.
  Validate the workflow with actionlint if available, otherwise report that gap with the static review.
  Inspect `git diff` for unrelated generated changes and check `git diff --check`.
  Amend the existing commit with a final implementation subject under 51 characters and provide the final review with exact verification evidence.

## Completion evidence and limits

Implementation and local verification completed on 1 November 2026 on Intel macOS 26.3.
Tasks 1–3 received independent specification and quality reviews, including exact-example red/green evidence for code regressions.
Task 4 adds the fork workflow and operations documentation; its migration and rollback blocks were executed in disposable Git repositories with main, custom-branch and detached starting states, dirty-worktree refusal and preserved Cellar markers.
Final review found that adoption onto a separate tracking branch could leave developer-mode updates running old code; a red/green fixture reproduced the failure, and adoption now uses a detached `origin/main` checkout.
The corrected fixture executes 18 actual `homebrew-update` calls across ordinary, developer and persisted prior-developer-command modes, covering both normal and automatic updates, then verifies active HEAD advancement, preserved original branch work and rollback.
No actual installation or development checkout was migrated or reset.

Final local checks passed:

- `./bin/brew --version` identified Intelbrew and `./bin/brew --help` retained `brew` examples and linked the fork guide.
- `./bin/brew tests --online --only=bash,cmd/--version,cmd/update,cmd/update-reset,cmd/update-report,utils/git,diagnostic/macos_bottle_remediation,os/mac/diagnostic` passed 199 examples.
- `HOMEBREW_NO_AUTO_UPDATE=1 ./bin/brew lgtm --online` passed global typechecking, changed-file style (15 Ruby files plus shell/workflow checks) and 10 changed online specs (280 examples).
- `./bin/brew style docs .github/workflows/intelbrew.yml README.md`, Markdown lint, Jekyll build, HTML-Proofer, Vale and actionlint passed.
- `git diff --check` passed and the task diff contains no unrelated generated changes.

All commands used this checkout's `./bin/brew`, with Ruby through `./bin/brew ruby --`.
A tools directory containing verified portable shellcheck, shfmt and actionlint binaries was prepended to `PATH` for style and `lgtm` to avoid large Intel compiler dependency builds.
The docs checks used isolated Bundler gems with Homebrew's portable Ruby because the docs Brewfile's Ruby and xz formulae were unavailable locally; no system Ruby or system Homebrew was used.
The unchanged upstream development origin produced the expected non-standard-origin warning, and HTML-Proofer's dependency emitted its existing experimental `IO::Buffer` warning; neither prevented validation.

GitHub documents `macos-15-intel`, but no remote workflow has run.
The maintainer must enable Actions as needed and enable Issues before publishing issue-reporting entry points; no repository settings were changed.
There is no full macOS 11–26 matrix, new Intel bottle service, installer or separate portable Ruby distribution.
Git update tests use local remotes; live GitHub ETag/tag discovery and a real fork update were not exercised.
A tag added at an unchanged branch tip can require `brew update --force` to refresh it.
The first release number remains undecided and must respect the inherited numeric version lineage.
No push or release was performed.

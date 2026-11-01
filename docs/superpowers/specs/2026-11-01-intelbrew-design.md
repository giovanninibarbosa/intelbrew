---
last_review_date: "2026-11-01"
---

# Intelbrew Design

## Status and intent

Approved by the user on 2026-11-01 for planning and subagent-driven implementation.
Implementation and local verification are complete; see the [completion evidence and limits](../plans/2026-11-01-intelbrew.md#completion-evidence-and-limits).
Hosted CI and publication remain pending.
Intelbrew is an independently maintained fork of Homebrew for Intel Macs.
The project lives at [giovanninibarbosa/intelbrew](https://github.com/giovanninibarbosa/intelbrew).
Users continue to run `brew` with the same commands, options, formulae, casks and taps.
The first milestone establishes the fork and protects the existing Intel runtime; maintaining a separate package distribution is later work.

The user selected the small maintained fork approach and supplied the repository address.
The proposed initial compatibility range is Intel x86_64 macOS Big Sur 11 through Tahoe 26, matching the runtime retained in this checkout.
This range is a compatibility target, not a claim that every combination has already been tested.
The development host is an Intel Mac running macOS 26.3.

## Current state

The starting revision is `3ee8416c08b25dde3f57b0a9d20f4450864fadd6` from `Homebrew/brew`.
The public Intelbrew fork already exists, but this local checkout's `origin` still points to Homebrew.
Intel architecture detection, `/usr/local` handling, Intel bottle tags and a Big Sur portable Ruby manifest remain present.
The implementation must retain these paths when incorporating future upstream changes.

Homebrew's [support policy](../../Support-Tiers.md#future-macos-support) says new Intel bottles are no longer built and Intel runtime removal is planned for September 2027 or later.
The current [installation documentation](../../Installation.md) describes installers for Apple Silicon rather than Intel.
The shell installer is maintained in a separate repository, while the `.pkg` definition in this repository is restricted to ARM64.
Changing the project name does not solve installer coverage, portable Ruby availability or package compatibility.

The shell bootstrap supplies a default Homebrew Git remote.
Normal updates select the latest numeric Git tag for non-developers, and `update-reset` also selects tags for those users.
An inherited Homebrew tag can therefore select a revision without Intelbrew's changes even when the Git remote points to the fork.
The principal syntax and test jobs in `.github/workflows/tests.yml` are restricted to the Homebrew organisation.

## Approaches

### Small maintained fork: selected

Keep the Homebrew architecture and compatibility interfaces, change the project identity and update source, and selectively incorporate upstream fixes.
Reuse Homebrew's current formula catalogue, cask catalogue, API, available bottles and portable Ruby distribution initially.
This keeps the initial diff manageable and preserves familiar commands.
It leaves package availability dependent on upstream and requires ongoing review of upstream changes.

### Independent package distribution: deferred

Also maintain formulae, Intel bottle builders, artifact hosting, bootstrap runtimes and installers.
This provides control over package availability but requires infrastructure and maintenance across several repositories.
The user explicitly deferred this approach.
It is a later project, not an implied deliverable of the first milestone.

## Goals and compatibility contract

- Identify the project as Intelbrew in its README, primary version output and fork-specific support documentation.
- Keep the executable named `brew`, including shell completions, aliases, subcommands and existing options.
- Keep `Homebrew` Ruby namespaces, `HOMEBREW_*` variables, formula and cask DSLs, tap names and installed package metadata compatible.
- Keep Intel's `/usr/local` prefix and `/usr/local/Homebrew` repository layout; existing installations should not need to reinstall packages.
- Preserve current Intel runtime, architecture and bottle-selection behaviour for macOS 11 through 26.
- Ensure self-updates continue to use Intelbrew code rather than inherited Homebrew releases.
- Describe the fork's actual support and testing limits without claiming Homebrew's support, infrastructure or maintainers.
- Add checks that can run for this fork and document reproducible local Intel validation.
- Keep upstream attribution, copyright notices and licence files intact.

## Non-goals and failure conditions

No global search-and-replace of the Homebrew name, namespaces, URLs or environment variables.
References to upstream package services, historical changes and Homebrew authors remain accurate references to Homebrew.
Existing Apple Silicon and Linux paths remain intact, but expanded support commitments for those systems are outside this milestone.
No new `intelbrew` executable, new installation prefix, package migration or command syntax.
No Catalina or earlier support, 32-bit Intel support or automatic upstream merges.
No bottle farm, API mirror, custom portable Ruby build, `.pkg` release or standalone shell installer in this milestone.
No promise that a formula or cask whose upstream project dropped Intel will become compatible again.

The milestone fails if an ordinary update silently restores Homebrew, if existing packages require relocation, if tests exercise an unrelated installed Homebrew, or if documentation advertises support that has not been verified.

## Proposed implementation boundaries

The following technical choices were proposed by the author and approved with this design.

### Identity and support routing

Use `Intelbrew` as the display name and `intelbrew` as the repository name.
`brew --version` starts with `Intelbrew` while retaining a usable version number.
Keep upstream tap identifiers in that output accurate.
Update the README and add a concise Intelbrew operations guide with requirements, migration, rollback, support boundaries and maintenance instructions.
Make the existing installation and support-tier documents visibly distinguish the fork policy from the inherited Homebrew policy.
Route the primary project help and bug-report entry points to Intelbrew without redirecting upstream package downloads or historical issue references.
Label retained upstream sponsorship and authorship material as upstream material rather than presenting it as Intelbrew's organisation.
Generated command documentation must be regenerated through `./bin/brew generate-man-completions` when its source descriptions change.

### Updates and releases

Set the default brew repository to `https://github.com/giovanninibarbosa/intelbrew`.
Continue to honour an explicitly configured `HOMEBREW_BREW_GIT_REMOTE`, including a user's deliberate choice of another repository.
Leave core, cask, bottle and API defaults unchanged.

Initially, normal updates and automatic updates follow the fork's default branch, normally `main`.
`brew update-reset` follows that same fork branch by default and retains its existing destructive semantics and warning.
Maintainers review changes before admitting them to this branch.

Explicit `HOMEBREW_UPDATE_TO_TAG` use selects only release tags named `intelbrew-X.Y.Z`.
If no matching release exists, report an actionable error before checking out a different revision.
Never select an inherited numeric Homebrew tag as an Intelbrew release.
Keep internal version consumers compatible by normalising the Intelbrew tag prefix where required; before the first fork release, an upstream-derived development version is acceptable.
The implementation plan must cover both update paths, explicit remote overrides, inherited tags, missing fork tags and version caching.
Publishing the first release and its tag is separate from implementing and testing this policy locally.

### Intel compatibility and diagnostics

Retain the current minimum macOS version and Intel bootstrap artifacts.
Do not remove real OS, developer tool, package requirement or missing-bottle checks to make the fork appear healthier.
Replace the Intel-specific statement that this project cannot maintain Intel Macs with accurate Intelbrew guidance.
For older macOS versions, retain useful warnings about toolchains and package availability and distinguish these from the fork's runtime compatibility target.
Do not mark every Intel machine Tier 1 or imply that bottle coverage has been restored.
Retain security, checksum and artifact verification.

### Validation and CI

Add narrowly scoped fork CI rather than enabling all upstream release, publication and organisation automation.
Use a currently available Intel macOS runner if one can be verified during planning, and explicitly check its architecture.
CI must run the checked-out fork's `./bin/brew`, not a preinstalled copy of Homebrew.
Keep permissions minimal and do not require upstream organisation secrets.
If hosted Intel runners are unavailable, document that limitation and provide local validation; do not invent a working runner or provision paid infrastructure.
Repository settings may need Actions enabled before remote jobs can run.
Running CI on every target macOS version is a future infrastructure task.

### Installation, migration and rollback

The initial supported adoption path is an existing Intel Homebrew installation with a clean Git checkout and a functioning bootstrap runtime.
Document how to record its current revision and remotes, back up its package list and select the Intelbrew source without moving its Cellar or replacing installed packages.
The procedure must fetch and explicitly check out fork code; changing only a remote URL is insufficient when inherited release tags remain.
Explain how saved `HOMEBREW_BREW_GIT_REMOTE` settings interact with the fork default.
Require a clean repository or manual resolution of local work before migration; do not silently discard it.
Rollback restores the recorded repository source and revision and explains any update-channel settings that must also be restored.
Migration and rollback documentation must not run those operations against the user's installed package manager during development.
Do not advertise the upstream installer as an Intelbrew installer.
Fresh installation automation remains deferred and is clearly stated in the README.

## Acceptance criteria

1. `./bin/brew --version` identifies Intelbrew and exits successfully on the Intel development host.
2. Existing command names, help examples, environment variables, paths and package DSLs remain compatible.
3. Isolated Git tests demonstrate that normal and automatic updates retain fork changes despite inherited Homebrew tags.
4. Isolated tests cover `update-reset`, explicit remote overrides, fork release selection and missing fork releases without changing a real installation.
5. Version reporting and its cache handle fork tags and development revisions consistently.
6. Targeted tests protect Intel architecture handling, bottle tags and meaningful diagnostics without pretending an unavailable bottle exists.
7. Fork CI configuration can run without Homebrew-only secrets and checks the intended checkout and architecture.
8. Documentation contains an honest support matrix, adoption prerequisites, migration, rollback and deferred infrastructure work.
9. Changed tests demonstrate a red/green cycle with exact `--only=file:line` targets where required by `AGENTS.md`.
10. `./bin/brew lgtm --online` passes, or an environmental blocker is recorded with its exact failure and without claiming the checks passed.
11. Required documentation checks are run and their outcomes recorded.
12. The final diff is reviewed for unnecessary renames, accidental package-service changes and unsupported claims.

## Delivery and maintenance

After design approval, write the implementation plan with exact files, tests and task boundaries.
Use subagent-driven development with specification and code-quality review of each implementation task.
Keep changes on a named branch created from `origin/HEAD`, preserve user edits and follow the repository's commit rules.
Amend related work into the task's existing commit rather than creating follow-up commits for fixes.
Prepare the implementation and verification results locally before any publication step.

Future upstream updates require review for Intel code removal, minimum macOS changes, portable Ruby manifests, package metadata assumptions and update behaviour.
Future package work includes selecting a maintained formula set, acquiring Intel builders, publishing bottles and preserving bootstrap runtimes.
These are ongoing maintenance obligations; this initial fork cannot guarantee indefinite operation of every package.

## Decisions left to the builder

Choose the smallest shared helpers and existing test seams that satisfy the acceptance criteria.
Choose exact spec examples, narrow support-link changes and CI layout after inspecting the relevant code.
Verify runner availability before choosing a hosted label.
Choose the first Intelbrew release number when a release is prepared; do not publish a release merely to complete this milestone.
Do not expand the work into a package distribution or wholesale rebranding without a new design decision.

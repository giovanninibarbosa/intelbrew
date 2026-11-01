---
last_review_date: "2026-11-01"
---

# Intelbrew

Intelbrew is an independently maintained fork of [Homebrew](https://github.com/Homebrew/brew) for Intel Macs, hosted at [giovanninibarbosa/intelbrew](https://github.com/giovanninibarbosa/intelbrew).
Continue to use `brew`, its options, `HOMEBREW_*` settings, formulae, casks and taps.
The Intel prefix remains `/usr/local`, normally with the repository at `/usr/local/Homebrew` and installed formulae in `/usr/local/Cellar`.

## Compatibility and coverage

| Configuration                    | Runtime target            | Verification in this milestone                                   |
| -------------------------------- | ------------------------- | ---------------------------------------------------------------- |
| Intel x86_64 macOS Big Sur 11–15   | Retain the existing paths | Selected OS versions simulated in unit tests; no local OS matrix  |
| Intel x86_64 macOS Tahoe 26       | Retain the existing paths | Local Intel macOS 26.3 command, update and diagnostic checks       |
| Intel x86_64 macOS Sequoia 15 CI  | Retain the existing paths | Workflow configured for `macos-15-intel`; no hosted run yet        |
| Intel macOS Catalina 10.15/older  | Outside the target        | Existing unsupported-system checks retained                       |
| Apple Silicon and Linux          | Existing paths retained   | No expanded fork support commitment or hosted matrix in this work |

macOS 11–26 is a compatibility target, not a claim that every OS, toolchain or package combination has been tested.
Intelbrew maintains the package manager runtime; Homebrew's [support tiers](Support-Tiers.md) still classify Intel macOS packages as Tier 3.
The fork does not turn Intel systems into Tier 1 configurations.
Older macOS versions can also lack Apple security updates and compatible developer tools.

Homebrew no longer builds new Intel bottles (binary packages).
Previously published bottles may remain usable, but updated formulae can require source builds and their build dependencies.
Source builds require compatible Xcode or Command Line Tools, a usable SDK and enough time, disk space and memory.
A successful `brew --version` does not establish that a particular package can build or run.
Formulae, casks and their upstream projects can independently require newer macOS versions or Apple Silicon.
Third-party taps are responsible for their own compatibility.

The inherited portable Ruby bootstrap and its download service remain dependencies, including the retained Big Sur manifest.
Intelbrew does not yet build or host a separate Ruby distribution, bottle service, API mirror or installer.
Core, cask, API and bottle defaults, checksums and artifact verification remain unchanged.
The upstream shell installer and Apple Silicon `.pkg` must not be advertised as Intelbrew installers.
The adoption path below requires an existing installation with a functioning runtime.

## Adopt an existing installation

Run this as the installation's owner on the intended Intel Mac, with Git and a working `brew` already available.
Resolve any local repository changes first; the procedure refuses tracked and untracked changes.
Review the fork's code before granting it the same trust as your current package manager.
Back up important data separately: a package inventory records what is installed, but is not a backup of package data or files.

First record the source, revision, branch or detached state, package inventory and relevant environment overrides.
The existing `brew` is used only to locate the installation; subsequent commands use that repository's executable.
This creates a new `~/intelbrew-backup` directory and refuses to overwrite an existing one.
Run each code block in the same shell, stopping if it fails.

```sh
intelbrew_repo="$(brew --repository)"
intelbrew_backup="$HOME/intelbrew-backup"
(
  set -eu
  test -z "$(git -C "$intelbrew_repo" status --porcelain)" || {
    echo "Resolve local repository changes before migration." >&2
    exit 1
  }
  mkdir "$intelbrew_backup"
  printf '%s\n' "$intelbrew_repo" > "$intelbrew_backup/repository.txt"
  git -C "$intelbrew_repo" remote -v > "$intelbrew_backup/remotes.txt"
  git -C "$intelbrew_repo" remote get-url origin > "$intelbrew_backup/origin.txt"
  git -C "$intelbrew_repo" rev-parse HEAD > "$intelbrew_backup/revision.txt"
  git -C "$intelbrew_repo" symbolic-ref --quiet --short HEAD \
    > "$intelbrew_backup/branch.txt" || true
  env | LC_ALL=C sort | sed -n \
    '/^HOMEBREW_BREW_GIT_REMOTE=/p; /^HOMEBREW_UPDATE_TO_TAG=/p' \
    > "$intelbrew_backup/update-environment.txt"
  "$intelbrew_repo/bin/brew" list --formula --versions \
    > "$intelbrew_backup/formulae.txt"
  "$intelbrew_repo/bin/brew" list --cask --versions \
    > "$intelbrew_backup/casks.txt"
  "$intelbrew_repo/bin/brew" tap > "$intelbrew_backup/taps.txt"
)
```

Review `update-environment.txt` and any persistent settings in your shell startup files and `brew.env` files; see [environment configuration](Manpage.md#environment).
Save those files before editing them.
An explicit `HOMEBREW_BREW_GIT_REMOTE` overrides the fork default: remove an old override or set it to the fork URL.
Remove `HOMEBREW_UPDATE_TO_TAG` from persistent configuration and unset it in the current shell to adopt the branch channel.
Unsetting a shell variable does not remove a value saved in `brew.env`.
The commands below assume these persistent settings have been addressed.
They fetch fork code before changing the source and check out `origin/main` in a detached state, preserving existing local branches.
Keep this detached state when using Intelbrew: normal updates advance the active checkout even when developer mode or a prior developer command enables branch preservation.
A separate local tracking branch would be restored after such updates and could leave the active code behind the updated default branch.

```sh
unset HOMEBREW_UPDATE_TO_TAG HOMEBREW_BREW_GIT_REMOTE
(
  set -eu
  test -z "$(git -C "$intelbrew_repo" status --porcelain)" || {
    echo "Resolve local repository changes before migration." >&2
    exit 1
  }
  git -C "$intelbrew_repo" fetch \
    https://github.com/giovanninibarbosa/intelbrew \
    refs/heads/main:refs/remotes/intelbrew/main
  git -C "$intelbrew_repo" remote set-url origin \
    https://github.com/giovanninibarbosa/intelbrew
  git -C "$intelbrew_repo" fetch origin
  git -C "$intelbrew_repo" remote set-head origin --auto
  git -C "$intelbrew_repo" switch --detach origin/main
  "$intelbrew_repo/bin/brew" --version
)
```

Confirm the version starts with `Intelbrew` before using `brew update` or `brew doctor`.
Changing only the remote and running the old updater can select an inherited Homebrew release; explicitly checking out the fork is essential.
The procedure changes only repository source and checkout state: it does not relocate, reinstall or delete Cellar packages, casks or package data.
A fetch or checkout failure leaves the recorded rollback information available; stop and inspect the error rather than proceeding with updates.
Fresh installation automation remains deferred.

## Roll back

Rollback also requires a clean repository; resolve local changes before continuing.
It restores the recorded origin and revision, with the original local branch when that branch still points at the recorded revision.
If the branch has since moved, it leaves the recorded revision detached to preserve that later work.
An originally detached checkout remains detached.
Run this before any package-manager update; restore the saved environment and persistent configuration afterwards.

```sh
intelbrew_backup="$HOME/intelbrew-backup"
intelbrew_repo="$(cat "$intelbrew_backup/repository.txt")"
(
  set -eu
  test -z "$(git -C "$intelbrew_repo" status --porcelain)" || {
    echo "Resolve local repository changes before rollback." >&2
    exit 1
  }
  git -C "$intelbrew_repo" remote set-url origin \
    "$(cat "$intelbrew_backup/origin.txt")"
  git -C "$intelbrew_repo" fetch origin
  git -C "$intelbrew_repo" remote set-head origin --auto
  git -C "$intelbrew_repo" switch --detach \
    "$(cat "$intelbrew_backup/revision.txt")"
  if test -s "$intelbrew_backup/branch.txt" &&
     test "$(git -C "$intelbrew_repo" rev-parse \
       "$(cat "$intelbrew_backup/branch.txt")")" = \
       "$(cat "$intelbrew_backup/revision.txt")"; then
    git -C "$intelbrew_repo" switch "$(cat "$intelbrew_backup/branch.txt")"
  fi
)
```

Restore the previous `HOMEBREW_BREW_GIT_REMOTE` and `HOMEBREW_UPDATE_TO_TAG` values, or leave them unset if they were originally absent.
Review the saved values rather than executing the environment inventory as a script.
Rollback restores package-manager code, not package versions: packages installed or upgraded since adoption require their own recovery plan.
The backup directory can be retained for inspection; adoption does not create a local branch.

## Updates and releases

Normal `brew update` and automatic updates follow the configured origin's default branch (`origin/HEAD`), normally `main` for Intelbrew.
The adoption procedure keeps the active checkout detached so updates activate new code without moving existing local branches.
If you later switch to your own development branch, inherited developer behaviour can restore that branch after updating the default branch; check the active revision before assuming new code is running.
Explicit remote overrides and third-party tap remotes remain supported.
Before the first namespaced release, branch updates and version reporting work without an Intelbrew release tag.
An upstream-derived development version number is expected at this stage.

Set `HOMEBREW_UPDATE_TO_TAG=1` only when deliberately choosing the release channel.
It selects the highest valid `intelbrew-X.Y.Z` tag and refuses inherited numeric Homebrew tags, malformed tags and prereleases.
If no matching release exists, update and reset fail before changing the checkout.
If an existing `homebrew/core` directory lacks `.git`, release mode also refuses to bootstrap it: unset `HOMEBREW_UPDATE_TO_TAG`, run a normal `brew update` to initialise core, then retry release mode if desired.
Persistent configuration must also stop supplying tag mode during that recovery.

A normal branch update can skip fetching after GitHub reports an unchanged branch SHA.
If a new release tag was published at the same branch tip, use `brew update --force` to refresh tags; explicit release mode checks the tags API.
Local tests cover cache invalidation after a real tags-only fetch, but live GitHub tag discovery was not exercised in this milestone.

`brew update-reset` **discards local repository changes**, as its existing warning explains.
It follows the fork default branch normally or a namespaced release in explicit tag mode.
It is not part of the migration or rollback procedure.

When preparing a future release, choose the numeric portion of `intelbrew-X.Y.Z` to remain compatible with the inherited Homebrew version lineage.
Restarting at `1.0.0` could mislead version-dependent consumers.
This milestone does not select or publish the first release number.

## Help and maintenance

Run `brew doctor` and read its toolchain and package warnings; runtime compatibility does not remove those constraints.
Use the [Intelbrew repository](https://github.com/giovanninibarbosa/intelbrew) for fork runtime problems and the appropriate tap for package problems.
GitHub Issues are disabled on the fork as of 1 November 2026.
The maintainer must enable Issues before publishing the fork's issue-reporting entry points; inherited upstream contacts do not imply Homebrew maintains Intelbrew.

The Intel CI workflow (`.github/workflows/intelbrew.yml`) uses `macos-15-intel`, verifies `x86_64` and invokes the checked-out `./bin/brew`.
GitHub lists this label in its [runner documentation](https://docs.github.com/en/actions/reference/runners/github-hosted-runners), checked on 1 November 2026.
Enable Actions on the fork before expecting hosted validation; no hosted run has passed yet.
The workflow runs typechecking, changed-file style and online tests plus explicit Bash, version, update, reset, reporting, Git utility and Intel diagnostic suites on every trigger.
Its portable lint tools have pinned versions and SHA-256 digests; maintainers must keep those aligned with Homebrew's tool requirements to avoid compiler bootstraps during style checks.
It uses read-only repository permissions and no upstream organisation secrets or publication jobs.

For local runtime verification from a development checkout, use:

```sh
HOMEBREW_NO_AUTO_UPDATE=1 ./bin/brew --version
HOMEBREW_NO_AUTO_UPDATE=1 ./bin/brew --help
HOMEBREW_NO_AUTO_UPDATE=1 ./bin/brew tests --online \
  --only=bash,cmd/--version,cmd/update,cmd/update-reset,cmd/update-report,utils/git,diagnostic/macos_bottle_remediation,os/mac/diagnostic
HOMEBREW_NO_AUTO_UPDATE=1 ./bin/brew lgtm --online
```

Install the required style tools before validation; Intel source builds of their dependencies can be substantial.
The local checks ran on Intel macOS 26.3.
Disposable Git fixtures covered migration, subsequent normal and automatic updates in ordinary, developer and prior-developer-command modes and rollback.
They did not migrate the development checkout or an actual installation.
There is no full macOS 11–26 hosted matrix and no restored bottle coverage.

Review upstream changes for Intel code removal, minimum macOS checks, portable Ruby manifests, bottle selection and update policy before incorporating them.
Keep checksum and artifact verification intact.
Future infrastructure work includes an installer, preserved bootstrap runtimes, a maintained package set and Intel bottle builders and hosting.

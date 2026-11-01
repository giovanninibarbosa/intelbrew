# 🍺 Intelbrew

Intelbrew is an independently maintained [Homebrew](https://github.com/Homebrew/brew) fork for Intel Macs.
Keep using `brew`, existing packages and the `/usr/local` installation layout.
Intel x86_64 macOS Big Sur 11 through Tahoe 26 is the runtime compatibility target; it is not a claim of testing on every release.

Start with the [Intelbrew operations guide](docs/Intelbrew.md) for requirements, existing-installation migration, rollback and maintenance.
Fresh installation automation, an Intel bottle service and a separate portable Ruby distribution are deferred.
The upstream Homebrew installer and Apple Silicon `.pkg` are not Intelbrew installers.

## Documentation

Read the [operations guide](docs/Intelbrew.md), [command manual](docs/Manpage.md) and [troubleshooting checklist](docs/Troubleshooting.md).
The retained [installation](docs/Installation.md) and [support tiers](docs/Support-Tiers.md) describe upstream Homebrew policy, with visible fork notices.

Normal updates follow this fork's default branch.
Explicit release mode selects only `intelbrew-X.Y.Z` tags and fails before the first such release.
See the [project repository](https://github.com/giovanninibarbosa/intelbrew) for changes.

## Packages

Intelbrew initially uses Homebrew's [formulae, casks and package metadata](https://formulae.brew.sh), API and available bottles.
Upstream Homebrew no longer builds new Intel bottles.
Existing bottles may work; updated formulae may require source builds, compatible developer tools and dependencies.
A formula, cask or third-party project may independently drop Intel or older macOS support.
Runtime maintenance does not restore package coverage or change upstream's Tier 3 policy.

Read how Homebrew uses [anonymous analytics](docs/Analytics.md).
The inherited `HOMEBREW_*` settings and package interfaces remain compatible.

## Help and contributions

Run `brew update`, read `brew doctor` and consult the [operations guide](docs/Intelbrew.md#help-and-maintenance).
Intelbrew runtime problems belong with this fork, rather than upstream Homebrew maintainers.
The maintainer must enable GitHub Issues before the fork's issue-reporting entry points can accept reports.
Issues are disabled as of 1 November 2026; use the [project repository](https://github.com/giovanninibarbosa/intelbrew) to check current availability.

Contributions should follow the [contribution guide](CONTRIBUTING.md), target this fork and preserve Intel compatibility.
Package changes still belong with the relevant tap's maintainers.

## Attribution and licences

Intelbrew derives from Homebrew and retains its copyright notices and licences.
Homebrew was originally created by [Max Howell](https://github.com/mxcl) and developed by [Homebrew's contributors](https://github.com/Homebrew/brew/graphs/contributors).
Homebrew's governance, sponsors, donations, social accounts and security-reporting arrangements belong to the upstream project; they do not represent Intelbrew.
See [upstream Homebrew](https://github.com/Homebrew/brew) for that project's organisation and support information.

Code is under the [BSD 2-clause “Simplified” Licence](LICENSE.txt).
Documentation is under the [Creative Commons Attribution licence](https://creativecommons.org/licenses/by/4.0/).

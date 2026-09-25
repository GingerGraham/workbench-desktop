# Changelog

All notable changes to `workbench-desktop` are documented here.

## [Unreleased]

## [0.3.1] - 2026-09-25

### Security

- **OpenDeck and NotesHub installers no longer install unverified
  packages as root.** `install-opendeck` now prefers the verified Flathub
  build (`me.amankhanna.opendeck`, published by upstream) when `flatpak`
  is available, falling back to the release RPM/DEB only if that fails.
  Both `install-opendeck` and `install-noteshub` now verify every
  downloaded RPM/DEB against the SHA-256 GitHub publishes for it
  (`_wb_fetch_verified`/`_wb_gh_asset_digest`, workbench-core Core API
  1.4) before installing, and refuse to install a package with no
  published digest rather than silently falling back to an unverified
  download. NotesHub has no Flathub listing, so only the digest
  verification applies there. See security review M3.

## [0.3.0] - 2026-09-23

### Added

- **Manual `workflow_dispatch` release override.** `release.yml` now
  accepts a `bump_type` (patch/minor/major) input to force a release
  through `workbench-core`'s reusable `module-release.yml`, regardless of
  what Conventional Commits since the last tag would compute — a floor,
  never a downgrade of a higher severity already pending. Manual dispatch
  only runs from `main`. See `workbench-core`'s `docs/decisions-log.md` D67.

- **Agent-instruction files** (`AGENTS.md`, `CLAUDE.md`,
  `.github/copilot-instructions.md`,
  `.claude/skills/conventional-commits/SKILL.md`) — ports
  `workbench-core`'s D32 agent-instruction topology to this repo. See
  `workbench-core`'s `docs/decisions-log.md` D58.
- **Repo governance files** (`.github/PULL_REQUEST_TEMPLATE.md`,
  `.github/ISSUE_TEMPLATE/{bug_report,feature_request,config}.yml`,
  `.github/CODEOWNERS`, `CONTRIBUTING.md`, `SECURITY.md`) — ports
  `workbench-core`'s D31 governance-file topology to this repo,
  piloted on `workbench-git` first. See `workbench-core`'s
  `docs/decisions-log.md` D60.

## [0.2.0] - 2026-09-09

### Added

- Added `installed-flatpak` — reports install status to `wb tools upgrade`/
  `list --status` (workbench-core §12 D43).
  `install-opendeck`/`install-opendeck-version`/`install-noteshub`/
  `install-noteshub-version` deliberately have no predicate — see PR
  description for why.

## [0.1.0] - 2026-09-09

### Added

- Initial decomposition from `workbench-precursor` (Wave C):
  `list-opendeck-releases`/`list-noteshub-releases` (interactive),
  `install-opendeck`/`install-opendeck-version`/`install-noteshub`/
  `install-noteshub-version`/`install-flatpak` (`wb tools`).

### Changed

- Split `list-opendeck-releases`/`list-noteshub-releases` out of
  `installers.sh` into a new `shell/desktop.sh` (`register.shell`, tier:
  tools) — `wb tools` only sources `register.installers[].src` files
  transiently, to invoke one `install-<name>` function at a time, so a
  read-only helper living only in `installers.sh` would never actually be
  reachable from an interactive shell.
- Dropped the precursor's `DOTFILES_OPTIONAL_INSTALLERS=true` gate —
  registering this module at all (`wb add desktop`) is the equivalent
  opt-in under `workbench-core`'s model.
- `WORKBENCH_OS`/`WORKBENCH_DISTRO`/`WORKBENCH_ARCH` replace
  `DOTFILES_OS`/`DOTFILES_DISTRO`.

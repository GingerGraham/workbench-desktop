# Changelog

All notable changes to `workbench-desktop` are documented here.

## [Unreleased]

### Added

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

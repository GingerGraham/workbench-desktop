# Changelog

All notable changes to `workbench-desktop` are documented here.

## [Unreleased]

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

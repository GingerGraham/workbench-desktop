# workbench-desktop

GUI desktop app installers + Flatpak, for the
[`workbench`](https://github.com/GingerGraham/workbench-core) ecosystem.

An **ecosystem module** (`workbench-core` ARCHITECTURE.md §2) — meaningless
standalone. Requires `workbench-core` installed first:

```sh
wb add desktop
```

## What this gives you

- `list-opendeck-releases`/`list-noteshub-releases` — interactive helpers.
- `install-opendeck`, `install-opendeck-version` (not yet implemented — use
  `install-opendeck` for latest), `install-noteshub`,
  `install-noteshub-version` (same caveat), `install-flatpak` — via
  `wb tools update`.

`install-flatpak` is grouped here rather than `workbench-devtools`:
Flatpak exists specifically to distribute GUI applications, so it belongs
with its consumers.

## Deliberate change from the precursor

The precursor gated this whole file behind
`DOTFILES_OPTIONAL_INSTALLERS=true` on top of `loader.sh`'s own
optional-tier registration — a second, redundant opt-in for a grab-bag
file mixing unrelated apps. `workbench-core` has no equivalent second
gate: registering this module at all (`wb add desktop`) *is* the opt-in,
so that extra layer is dropped rather than ported.

## Requires

Nothing at install time — each app is installed via its own
`install-<name>` function (`wb tools update`).

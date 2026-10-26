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
- Installers for `opendeck`, `noteshub` and `flatpak` — `wb tools install
  <name>` to install the latest release, `wb tools upgrade <name>` to
  update an app you already have. There is no version pin.
- `wb tools list --status` and `wb tools upgrade` see OpenDeck as
  installed when its Flatpak (user or system) is installed or the
  `opendeck` binary is on `PATH`. NotesHub's status shows as unknown, so
  `wb tools upgrade` skips it: its package names aren't confirmed yet.
  Run `wb tools install noteshub` to update it.

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
`install-<name>` function, run with `wb tools install <name>`.

#!/usr/bin/env bash
# shell/desktop.sh — workbench-desktop
# list-opendeck-releases, list-noteshub-releases. Registered at tier: tools
# (.dotfiles-sync.yml) so these are reachable interactively — unlike the
# install-* functions in shell/installers.sh, which `wb tools` only sources
# transiently, these two are read-only informational helpers meant to be
# called directly from the shell.
# Ported from workbench-precursor's lazy/optional/installers-desktop-addons.sh.

list-opendeck-releases() {
    curl -s https://api.github.com/repos/nekename/OpenDeck/releases \
        | grep -o '"tag_name": *"[^"]*"' \
        | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' \
        | head -10
}

list-noteshub-releases() {
    curl -s https://api.github.com/repos/NotesHubApp/noteshub-releases/releases \
        | grep -o '"tag_name": *"[^"]*"' \
        | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' \
        | head -10
}

get-desktop-functions() {
    local _f="${BASH_SOURCE[0]}"
    _get_functions_in "Desktop functions" "" "${_f}"
}

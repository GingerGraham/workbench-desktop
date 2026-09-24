#!/usr/bin/env bash
# shell/installers.sh — workbench-desktop
# install-opendeck, install-opendeck-version, install-noteshub,
# install-noteshub-version, install-flatpak. (list-opendeck-releases/
# list-noteshub-releases live in shell/desktop.sh instead — register.shell
# content, not register.installers, since `wb tools` only sources this
# file transiently to invoke one install-<name> function; those two are
# read-only helpers meant to be called directly from an interactive shell.)
#
# Ported from workbench-precursor's lazy/optional/installers-desktop-addons.sh
# and the Flatpak slice of lazy/installers-system.sh (Flatpak exists
# specifically to distribute GUI applications, so it belongs with its
# consumers here rather than workbench-devtools — per the module map §3).
#
# The precursor gated these behind DOTFILES_OPTIONAL_INSTALLERS=true,
# on top of loader.sh's own optional-tier registration — belt-and-suspenders
# opt-in for a grab-bag file mixing many unrelated tools. workbench-core has
# no equivalent second gate: the module itself IS the opt-in (you only get
# these functions at all once you `wb add desktop`), so that layer is
# dropped as redundant rather than ported.
#
# WORKBENCH_OS/WORKBENCH_DISTRO/WORKBENCH_ARCH are workbench-core Core API
# platform facts (contracts/core-api.md), replacing the precursor's
# DOTFILES_OS/DOTFILES_DISTRO. _download_file_robust/_gh_release_asset_url*
# — *_gh_release_asset_url is duplicated locally below (small enough that
# per-module duplication is the accepted norm here — see workbench-git's
# own copy and ARCHITECTURE.md §12 D34 for the bar actually applied to
# promote a helper to Core API instead).

_gh_release_asset_url() {
    local api_response="$1" pattern="$2"
    printf '%s' "${api_response}" \
        | grep -Eo '"browser_download_url": *"[^"]+"' \
        | sed -E 's/.*"(https[^"]+)"/\1/' \
        | grep -E "${pattern}" \
        | head -1
}

# ── OpenDeck install ──────────────────────────────────────────────────────────
install-opendeck() {
    log_info "Installing or updating OpenDeck..."

    # Flathub build — signed by Flathub, published by upstream; preferred
    # over installing an unverified RPM/DEB as root (security review M3).
    # Scope is explicit (--user, then --system) rather than left to flatpak's
    # own default: with a "flathub" remote configured in both scopes,
    # an unscoped `flatpak install` is ambiguous and fails/prompts instead
    # of installing.
    if [[ "${WORKBENCH_OS}" == "Linux" ]] && command -v flatpak &>/dev/null; then
        if flatpak install -y --user flathub me.amankhanna.opendeck 2>/dev/null; then
            return 0
        elif flatpak install -y --system flathub me.amankhanna.opendeck; then
            return 0
        fi
        log_warn "Flathub install failed — falling back to the release package"
    fi

    [[ -z "${PACKAGE_MANAGER:-}" ]] && { detect-package-manager || return 1; }

    local api_response ver elevation_cmd="" temp_dir
    api_response="$(curl -fsS https://api.github.com/repos/nekename/OpenDeck/releases/latest)" \
        || { log_error "Could not query the latest OpenDeck release (network or GitHub API rate limit)"; return 1; }
    ver="$(echo "${api_response}" | grep '"tag_name":' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')"
    [[ -z "${ver}" ]] && { log_error "Could not determine OpenDeck version"; return 1; }

    if [[ "${PACKAGE_MANAGER}" != "brew" ]]; then
        elevation_cmd="$(get-elevation-command)" || return 1
    fi
    temp_dir="$(mktemp -d)"

    case "${PACKAGE_MANAGER}" in
        apt)
            local url; url="$(_gh_release_asset_url "${api_response}" '\.deb$')"
            [[ -z "${url}" ]] && { log_error "No DEB asset found"; rm -rf "${temp_dir}"; return 1; }
            local digest; digest="$(_wb_gh_asset_digest "${api_response}" "${url}")"
            [[ -z "${digest}" ]] && { log_error "No published SHA-256 for ${url##*/} — refusing to install"; rm -rf "${temp_dir}"; return 1; }
            _wb_fetch_verified "${url}" "${temp_dir}/opendeck.deb" "${digest}" || { rm -rf "${temp_dir}"; return 1; }
            if ! { ${elevation_cmd} dpkg -i "${temp_dir}/opendeck.deb" || ${elevation_cmd} apt-get install -f -y; }; then
                log_error "OpenDeck DEB install failed"; rm -rf "${temp_dir}"; return 1
            fi
            ;;
        dnf|yum|zypper)
            local url; url="$(_gh_release_asset_url "${api_response}" '\.rpm$')"
            [[ -z "${url}" ]] && { log_error "No RPM asset found"; rm -rf "${temp_dir}"; return 1; }
            local digest; digest="$(_wb_gh_asset_digest "${api_response}" "${url}")"
            [[ -z "${digest}" ]] && { log_error "No published SHA-256 for ${url##*/} — refusing to install"; rm -rf "${temp_dir}"; return 1; }
            _wb_fetch_verified "${url}" "${temp_dir}/opendeck.rpm" "${digest}" || { rm -rf "${temp_dir}"; return 1; }
            if [[ "${PACKAGE_MANAGER}" == "zypper" ]]; then
                ${elevation_cmd} zypper install -y "${temp_dir}/opendeck.rpm" \
                    || { log_error "OpenDeck RPM install failed"; rm -rf "${temp_dir}"; return 1; }
            else
                ${elevation_cmd} "${PACKAGE_MANAGER}" install -y "${temp_dir}/opendeck.rpm" \
                    || { log_error "OpenDeck RPM install failed"; rm -rf "${temp_dir}"; return 1; }
            fi
            ;;
        *)
            log_error "No native package for ${PACKAGE_MANAGER}"; rm -rf "${temp_dir}"; return 1
            ;;
    esac

    rm -rf "${temp_dir}"
    log_info "OpenDeck installation complete"
}

install-opendeck-version() {
    local target="$1"
    [[ -z "${target}" ]] && { log_error "Usage: install-opendeck-version <version>"; return 1; }
    log_info "install-opendeck-version: use install-opendeck for latest; specific-version flow not yet implemented"
    return 1
}

# ── NotesHub install ──────────────────────────────────────────────────────────
install-noteshub() {
    log_info "Installing or updating NotesHub..."
    [[ -z "${PACKAGE_MANAGER:-}" ]] && { detect-package-manager || return 1; }

    local api_response ver arch_suffix elevation_cmd="" temp_dir
    api_response="$(curl -fsS https://api.github.com/repos/NotesHubApp/noteshub-releases/releases/latest)" \
        || { log_error "Could not query the latest NotesHub release (network or GitHub API rate limit)"; return 1; }
    ver="$(echo "${api_response}" | grep '"tag_name":' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')"
    [[ -z "${ver}" ]] && { log_error "Could not determine NotesHub version"; return 1; }

    case "${WORKBENCH_ARCH}" in
        x86_64)        arch_suffix="amd64" ;;
        aarch64|arm64) arch_suffix="arm64" ;;
        *) log_error "Unsupported arch: ${WORKBENCH_ARCH}"; return 1 ;;
    esac

    [[ "${PACKAGE_MANAGER}" != "brew" ]] && { elevation_cmd="$(get-elevation-command)" || return 1; }
    temp_dir="$(mktemp -d)"

    case "${PACKAGE_MANAGER}" in
        apt)
            local url; url="$(_gh_release_asset_url "${api_response}" "noteshub_.*_${arch_suffix}\.deb")"
            [[ -z "${url}" ]] && { log_error "No DEB asset"; rm -rf "${temp_dir}"; return 1; }
            local digest; digest="$(_wb_gh_asset_digest "${api_response}" "${url}")"
            [[ -z "${digest}" ]] && { log_error "No published SHA-256 for ${url##*/} — refusing to install"; rm -rf "${temp_dir}"; return 1; }
            _wb_fetch_verified "${url}" "${temp_dir}/noteshub.deb" "${digest}" || { rm -rf "${temp_dir}"; return 1; }
            if ! { ${elevation_cmd} dpkg -i "${temp_dir}/noteshub.deb" || ${elevation_cmd} apt-get install -f -y; }; then
                log_error "NotesHub DEB install failed"; rm -rf "${temp_dir}"; return 1
            fi
            ;;
        dnf|yum|zypper)
            [[ "${arch_suffix}" != "amd64" ]] && { log_error "RPM only for x86_64"; rm -rf "${temp_dir}"; return 1; }
            local url; url="$(_gh_release_asset_url "${api_response}" "NotesHub-.*\.x86_64\.rpm")"
            [[ -z "${url}" ]] && { log_error "No RPM asset"; rm -rf "${temp_dir}"; return 1; }
            local digest; digest="$(_wb_gh_asset_digest "${api_response}" "${url}")"
            [[ -z "${digest}" ]] && { log_error "No published SHA-256 for ${url##*/} — refusing to install"; rm -rf "${temp_dir}"; return 1; }
            _wb_fetch_verified "${url}" "${temp_dir}/noteshub.rpm" "${digest}" || { rm -rf "${temp_dir}"; return 1; }
            if [[ "${PACKAGE_MANAGER}" == "zypper" ]]; then
                ${elevation_cmd} zypper install -y "${temp_dir}/noteshub.rpm" \
                    || { log_error "NotesHub RPM install failed"; rm -rf "${temp_dir}"; return 1; }
            else
                ${elevation_cmd} "${PACKAGE_MANAGER}" install -y "${temp_dir}/noteshub.rpm" \
                    || { log_error "NotesHub RPM install failed"; rm -rf "${temp_dir}"; return 1; }
            fi
            ;;
        *)
            log_error "No supported install method for ${PACKAGE_MANAGER}"; rm -rf "${temp_dir}"; return 1
            ;;
    esac

    rm -rf "${temp_dir}"
    log_info "NotesHub installation complete"
}

install-noteshub-version() {
    local target="$1"
    [[ -z "${target}" ]] && { log_error "Usage: install-noteshub-version <version>"; return 1; }
    log_info "install-noteshub-version: use install-noteshub for latest; specific-version flow not yet implemented"
    return 1
}

# ── flatpak install ───────────────────────────────────────────────────────────
install-flatpak() {
    log_info "Installing flatpak and configuring Flathub..."
    [[ "${WORKBENCH_OS}" != "Linux" ]] && { log_error "flatpak is Linux-only"; return 1; }

    local elevation_cmd; elevation_cmd="$(get-elevation-command)" || return 1

    # ── Package install (skip if flatpak already present) ─────────────────────
    if ! command -v flatpak &>/dev/null; then
        case "${WORKBENCH_DISTRO}" in
            rhel)
                if command -v dnf &>/dev/null; then
                    ${elevation_cmd} dnf install -y flatpak
                else
                    ${elevation_cmd} yum install -y flatpak
                fi
                ;;
            debian)
                ${elevation_cmd} apt-get update
                ${elevation_cmd} apt-get install -y flatpak
                ${elevation_cmd} apt-get install -y gnome-software-plugin-flatpak 2>/dev/null || true
                ;;
            suse)
                ${elevation_cmd} zypper install -y flatpak
                ;;
            arch)
                ${elevation_cmd} pacman -S --noconfirm flatpak
                ;;
            *)
                log_error "flatpak: unsupported distro (${WORKBENCH_DISTRO})"; return 1
                ;;
        esac
    else
        log_info "flatpak: already installed ($(flatpak --version))"
    fi

    command -v flatpak &>/dev/null \
        || { log_error "flatpak not on PATH after install"; return 1; }

    # ── Flathub remote (only add if not already configured) ───────────────────
    # Try user-level first (no elevation for subsequent flatpak install calls).
    # Fall back to system-level for environments where user remotes aren't
    # recognised by the desktop software centre.
    local flathub_url="https://dl.flathub.org/repo/flathub.flatpakrepo"

    if flatpak remote-list --user 2>/dev/null | grep -q 'flathub' \
        || flatpak remote-list --system 2>/dev/null | grep -q 'flathub'; then
        log_info "flatpak: Flathub remote already configured"
    else
        log_info "flatpak: adding Flathub remote (user scope)..."
        if ! flatpak remote-add --user --if-not-exists flathub "${flathub_url}" 2>/dev/null; then
            log_warn "flatpak: user-scope remote add failed — trying system scope..."
            ${elevation_cmd} flatpak remote-add --if-not-exists flathub "${flathub_url}"
        fi
    fi

    log_info "flatpak $(flatpak --version) ready with Flathub configured."
    log_info "A session restart may be required before installing apps."
}

installed-flatpak() {
    command -v flatpak &>/dev/null
}

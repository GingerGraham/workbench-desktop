#!/usr/bin/env bash
# tests/check-installers-verified.sh — workbench-desktop
# Verifies install-opendeck/install-noteshub refuse to install an unverified
# package and prefer Flathub where available (security review M3). Stubs
# the Core API surface (_wb_gh_asset_digest, _wb_fetch_verified, curl,
# flatpak, the package managers) rather than requiring a workbench-core
# checkout alongside this module — this repo's own CI (structural-tests in
# workbench-core's module-ci.yml) runs tests/check-*.sh from this checkout
# alone, with no _core/ sibling present. installers-common.sh's own
# behaviour (JSON parsing, hash verification) is covered by
# workbench-core's tests/check-fetch-verified.sh; this suite only checks
# that shell/installers.sh wires into it correctly.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

FAILED=0
check_no=0
ok()   { check_no=$((check_no + 1)); echo "OK:   [$check_no] $*"; }
fail() { check_no=$((check_no + 1)); echo "FAIL: [$check_no] $*"; FAILED=$((FAILED + 1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# ── Stubs standing in for workbench-core's Core API ─────────────────────────
log_info()  { :; }
log_warn()  { :; }
log_error() { :; }
detect-package-manager() { :; }
get-elevation-command()  { printf '%s\n' ""; }

# TEST_DIGEST controls what the stubbed _wb_gh_asset_digest returns; empty
# simulates a release asset with no published SHA-256 ("digest": null).
_wb_gh_asset_digest() { printf '%s\n' "${TEST_DIGEST:-}"; }

# Records every call so a refused install can be told apart from a real one.
CALL_LOG="${WORK}/calls"
_wb_fetch_verified() {
    printf 'fetch_verified %s %s %s\n' "$1" "$3" "${4:-}" >> "${CALL_LOG}"
    : > "$2"
    return 0
}
_download_file_robust() { printf 'download_file_robust %s\n' "$1" >> "${CALL_LOG}"; : > "$2"; return 0; }
# shellcheck disable=SC2317 # invoked indirectly by the sourced install-opendeck/install-noteshub
dpkg()          { printf 'dpkg %s\n' "$*" >> "${CALL_LOG}"; return 0; }
# shellcheck disable=SC2317 # invoked indirectly by the sourced install-opendeck/install-noteshub
apt-get()       { printf 'apt-get %s\n' "$*" >> "${CALL_LOG}"; return 0; }
zypper()        { printf 'zypper %s\n' "$*" >> "${CALL_LOG}"; return 0; }
# shellcheck disable=SC2317 # invoked indirectly by the sourced install-opendeck/install-noteshub
dnf()           { printf 'dnf %s\n' "$*" >> "${CALL_LOG}"; return 0; }
yum()           { printf 'yum %s\n' "$*" >> "${CALL_LOG}"; return 0; }

# shellcheck source=shell/installers.sh
source "${REPO_ROOT}/shell/installers.sh"

# ── OpenDeck: no flatpak on PATH, forces the package-manager fallback ──────
unset -f flatpak 2>/dev/null || true
WORKBENCH_OS="Linux"
PACKAGE_MANAGER="apt"

api_json_deb='{"tag_name":"v1.0.0","assets":[{"digest":"sha256:deadbeef","browser_download_url":"https://example.invalid/opendeck.deb"}]}'
curl() { printf '%s' "${api_json_deb}"; }

# Check 1: no published digest -- apt branch refuses, never calls dpkg.
: > "${CALL_LOG}"
TEST_DIGEST=""
if install-opendeck >/dev/null 2>&1; then
    fail "install-opendeck (apt, no digest): unexpectedly succeeded"
else
    if grep -q '^dpkg' "${CALL_LOG}" 2>/dev/null; then
        fail "install-opendeck (apt, no digest): dpkg was invoked despite the missing digest"
    else
        ok "install-opendeck (apt, no digest): refused before touching dpkg"
    fi
fi

# Check 2: a published digest -- apt branch verifies via _wb_fetch_verified,
# then installs.
: > "${CALL_LOG}"
TEST_DIGEST="deadbeef"
if install-opendeck >/dev/null 2>&1 \
    && grep -q '^fetch_verified https://example.invalid/opendeck.deb deadbeef' "${CALL_LOG}" \
    && grep -q '^dpkg' "${CALL_LOG}"; then
    ok "install-opendeck (apt, digest present): verified via _wb_fetch_verified, then installed"
else
    fail "install-opendeck (apt, digest present): expected fetch_verified then dpkg — got: $(cat "${CALL_LOG}" 2>/dev/null)"
fi

# Check 3: apt branch never falls back to the unverified _download_file_robust.
if grep -q '^download_file_robust' "${CALL_LOG}" 2>/dev/null; then
    fail "install-opendeck (apt): fell back to _download_file_robust (unverified)"
else
    ok "install-opendeck (apt): never used the unverified _download_file_robust path"
fi

# Check 4: dnf branch — no digest refuses, never calls dnf/zypper.
PACKAGE_MANAGER="dnf"
api_json_rpm='{"tag_name":"v1.0.0","assets":[{"digest":"sha256:cafef00d","browser_download_url":"https://example.invalid/opendeck.rpm"}]}'
curl() { printf '%s' "${api_json_rpm}"; }
: > "${CALL_LOG}"
TEST_DIGEST=""
if install-opendeck >/dev/null 2>&1; then
    fail "install-opendeck (dnf, no digest): unexpectedly succeeded"
else
    if grep -q '^dnf' "${CALL_LOG}" 2>/dev/null; then
        fail "install-opendeck (dnf, no digest): dnf was invoked despite the missing digest"
    else
        ok "install-opendeck (dnf, no digest): refused before touching dnf"
    fi
fi

# Check 5: dnf branch — a published digest installs via _wb_fetch_verified.
: > "${CALL_LOG}"
TEST_DIGEST="cafef00d"
if install-opendeck >/dev/null 2>&1 \
    && grep -q '^fetch_verified https://example.invalid/opendeck.rpm cafef00d' "${CALL_LOG}" \
    && grep -q '^dnf' "${CALL_LOG}"; then
    ok "install-opendeck (dnf, digest present): verified via _wb_fetch_verified, then installed"
else
    fail "install-opendeck (dnf, digest present): expected fetch_verified then dnf — got: $(cat "${CALL_LOG}" 2>/dev/null)"
fi

# ── OpenDeck: Flathub preferred when it's on PATH and the install succeeds ─
# --user succeeds outright -- --system is never even tried.
flatpak() { printf 'flatpak %s\n' "$*" >> "${CALL_LOG}"; return 0; }
curl() { echo "FAIL: curl was called -- should have returned via Flathub" >&2; printf '%s' "${api_json_deb}"; }
: > "${CALL_LOG}"
if install-opendeck >/dev/null 2>&1 \
    && grep -q '^flatpak install -y --user flathub me.amankhanna.opendeck$' "${CALL_LOG}" \
    && ! grep -qE '^(dpkg|dnf|fetch_verified|flatpak install -y --system)' "${CALL_LOG}"; then
    ok "install-opendeck: Flathub --user install succeeds and short-circuits the package-manager path"
else
    fail "install-opendeck: Flathub short-circuit did not behave as expected — got: $(cat "${CALL_LOG}" 2>/dev/null)"
fi

# Check: --user fails (e.g. remote only configured system-wide), --system succeeds.
flatpak() {
    printf 'flatpak %s\n' "$*" >> "${CALL_LOG}"
    [[ "$*" == *"--user"* ]] && return 1
    return 0
}
: > "${CALL_LOG}"
if install-opendeck >/dev/null 2>&1 \
    && grep -q '^flatpak install -y --user' "${CALL_LOG}" \
    && grep -q '^flatpak install -y --system flathub me.amankhanna.opendeck$' "${CALL_LOG}" \
    && ! grep -qE '^(dpkg|dnf|fetch_verified)' "${CALL_LOG}"; then
    ok "install-opendeck: --user failure falls through to --system, which succeeds"
else
    fail "install-opendeck: expected a --system fallback after --user failed — got: $(cat "${CALL_LOG}" 2>/dev/null)"
fi

# Check: both scopes fail (no flathub remote at all) -- falls back to the
# verified package-manager path rather than giving up.
flatpak() { printf 'flatpak %s\n' "$*" >> "${CALL_LOG}"; return 1; }
: > "${CALL_LOG}"
TEST_DIGEST="deadbeef"
curl() { printf '%s' "${api_json_deb}"; }
PACKAGE_MANAGER="apt"
if install-opendeck >/dev/null 2>&1 \
    && [[ "$(grep -c '^flatpak install' "${CALL_LOG}")" -eq 2 ]] \
    && grep -q '^dpkg' "${CALL_LOG}"; then
    ok "install-opendeck: both Flathub scopes failing falls back to the verified package"
else
    fail "install-opendeck: expected two Flathub attempts then a package-manager fallback — got: $(cat "${CALL_LOG}" 2>/dev/null)"
fi
unset -f flatpak

# ── OpenDeck: a package-manager install failure is not swallowed ──────────
# (Copilot review finding: dpkg/apt-get and dnf/zypper failures used to fall
# through to "installation complete" and a zero return.)
# shellcheck disable=SC2317 # invoked indirectly by the sourced install-opendeck/install-noteshub
dpkg() { printf 'dpkg %s\n' "$*" >> "${CALL_LOG}"; return 1; }
# shellcheck disable=SC2317 # invoked indirectly by the sourced install-opendeck/install-noteshub
apt-get() { printf 'apt-get %s\n' "$*" >> "${CALL_LOG}"; return 1; }
: > "${CALL_LOG}"
TEST_DIGEST="deadbeef"
# shellcheck disable=SC2317 # invoked indirectly by the sourced install-opendeck/install-noteshub
curl() { printf '%s' "${api_json_deb}"; }
PACKAGE_MANAGER="apt"
if install-opendeck >/dev/null 2>&1; then
    fail "install-opendeck (apt): a failed dpkg AND apt-get -f unexpectedly reported success"
else
    ok "install-opendeck (apt): a failed dpkg/apt-get -f install returns non-zero"
fi
# shellcheck disable=SC2317 # invoked indirectly by the sourced install-opendeck/install-noteshub
dpkg() { printf 'dpkg %s\n' "$*" >> "${CALL_LOG}"; return 0; }
# shellcheck disable=SC2317 # invoked indirectly by the sourced install-opendeck/install-noteshub
apt-get() { printf 'apt-get %s\n' "$*" >> "${CALL_LOG}"; return 0; }

# shellcheck disable=SC2317 # invoked indirectly by the sourced install-opendeck/install-noteshub
dnf() { printf 'dnf %s\n' "$*" >> "${CALL_LOG}"; return 1; }
: > "${CALL_LOG}"
TEST_DIGEST="cafef00d"
curl() { printf '%s' "${api_json_rpm}"; }
PACKAGE_MANAGER="dnf"
if install-opendeck >/dev/null 2>&1; then
    fail "install-opendeck (dnf): a failed dnf install unexpectedly reported success"
else
    ok "install-opendeck (dnf): a failed dnf install returns non-zero"
fi
dnf() { printf 'dnf %s\n' "$*" >> "${CALL_LOG}"; return 0; }

# ── NotesHub: no Flathub listing (per the brief), verified-package path only ─
WORKBENCH_ARCH="x86_64"
PACKAGE_MANAGER="apt"
api_json_noteshub_deb='{"tag_name":"v1.0.0","assets":[{"digest":"sha256:noteshubdeb","browser_download_url":"https://example.invalid/noteshub_1.0.0_amd64.deb"}]}'
curl() { printf '%s' "${api_json_noteshub_deb}"; }

# Check: no published digest -- apt branch refuses.
: > "${CALL_LOG}"
TEST_DIGEST=""
if install-noteshub >/dev/null 2>&1; then
    fail "install-noteshub (apt, no digest): unexpectedly succeeded"
else
    if grep -q '^dpkg' "${CALL_LOG}" 2>/dev/null; then
        fail "install-noteshub (apt, no digest): dpkg was invoked despite the missing digest"
    else
        ok "install-noteshub (apt, no digest): refused before touching dpkg"
    fi
fi

# Check: a published digest -- apt branch verifies then installs.
: > "${CALL_LOG}"
TEST_DIGEST="noteshubdeb"
if install-noteshub >/dev/null 2>&1 \
    && grep -q '^fetch_verified https://example.invalid/noteshub_1.0.0_amd64.deb noteshubdeb' "${CALL_LOG}" \
    && grep -q '^dpkg' "${CALL_LOG}"; then
    ok "install-noteshub (apt, digest present): verified via _wb_fetch_verified, then installed"
else
    fail "install-noteshub (apt, digest present): expected fetch_verified then dpkg — got: $(cat "${CALL_LOG}" 2>/dev/null)"
fi

# Check: a package-manager install failure is not swallowed (same Copilot
# review finding, flagged separately for install-noteshub's apt branch).
# shellcheck disable=SC2317 # invoked indirectly by the sourced install-opendeck/install-noteshub
dpkg() { printf 'dpkg %s\n' "$*" >> "${CALL_LOG}"; return 1; }
# shellcheck disable=SC2317 # invoked indirectly by the sourced install-opendeck/install-noteshub
apt-get() { printf 'apt-get %s\n' "$*" >> "${CALL_LOG}"; return 1; }
: > "${CALL_LOG}"
TEST_DIGEST="noteshubdeb"
if install-noteshub >/dev/null 2>&1; then
    fail "install-noteshub (apt): a failed dpkg/apt-get -f install unexpectedly reported success"
else
    ok "install-noteshub (apt): a failed dpkg/apt-get -f install returns non-zero"
fi
dpkg() { printf 'dpkg %s\n' "$*" >> "${CALL_LOG}"; return 0; }
apt-get() { printf 'apt-get %s\n' "$*" >> "${CALL_LOG}"; return 0; }

# ── curl's API query fails closed instead of proceeding with empty JSON ────
curl() { return 22; }
PACKAGE_MANAGER="apt"
: > "${CALL_LOG}"
if install-opendeck >/dev/null 2>&1; then
    fail "install-opendeck: a failed GitHub API query unexpectedly succeeded"
else
    ok "install-opendeck: a failed GitHub API query (curl -fsS) returns non-zero"
fi

echo
echo "==============================="
echo "Total OK/FAIL checks: ${check_no}, failed: ${FAILED}"
echo "==============================="
[[ "${FAILED}" -eq 0 ]]

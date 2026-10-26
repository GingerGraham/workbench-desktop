#!/usr/bin/env bash
# tests/check-installed-predicates.sh — workbench-desktop
# Plain bash, numbered OK:/FAIL: checks, matching workbench-core's
# tests/check-*.sh convention (no framework). No network, no root.
#
# installed-opendeck / installed-noteshub follow core's contract (exit 0
# installed, 1 not installed, anything else "can't tell"), and the
# unimplemented install-*-version installers are gone (workbench-core D102).
# flatpak, rpm, dpkg and the opendeck binary are stubs on a PATH that holds
# nothing else, so the host's own package managers never answer.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTALLERS="${REPO_ROOT}/shell/installers.sh"

FAILED=0
check_no=0
ok()   { check_no=$((check_no + 1)); echo "OK:   [$check_no] $*"; }
fail() { check_no=$((check_no + 1)); echo "FAIL: [$check_no] $*"; FAILED=$((FAILED + 1)); }

WORK="$(mktemp -d)" || { echo "FAIL: mktemp -d failed"; exit 1; }
trap 'rm -rf "${WORK}"' EXIT

# Base PATH: only what the predicates themselves need.
BASE_BIN="${WORK}/base-bin"
mkdir -p "${BASE_BIN}"
for bin in bash grep; do
    ln -s "$(command -v "${bin}")" "${BASE_BIN}/${bin}"
done

# stub <dir> <name> <exit-code> [stdout]
stub() {
    mkdir -p "$1"
    printf '#!%s\nprintf "%%s" "%s"\nexit %s\n' "$(command -v bash)" "${4:-}" "$3" > "$1/$2"
    chmod +x "$1/$2"
}

# A flatpak stub that succeeds only for `flatpak info --<scope> ...`.
flatpak_stub() {
    mkdir -p "$1"
    # shellcheck disable=SC2016 # $1/$2 belong to the generated stub
    printf '#!%s\n[ "$1" = info ] && [ "$2" = "--%s" ] && exit 0\nexit 1\n' "$(command -v bash)" "$2" > "$1/flatpak"
    chmod +x "$1/flatpak"
}

# run_pred <stub-dir> <predicate> [VAR=value ...] — prints the exit code.
run_pred() {
    local dir="$1" pred="$2"; shift 2
    # shellcheck disable=SC2016 # expanded by the child bash, not here
    env -i PATH="${dir}:${BASE_BIN}" "$@" "${BASE_BIN}/bash" -c \
        '. "$1"; for a in "${@:3}"; do eval "$a"; done; "$2"; echo $?' \
        _ "${INSTALLERS}" "${pred}" "$@" 2>/dev/null | tail -1
}

expect() {
    local want="$1" got="$2" what="$3"
    if [[ "${got}" == "${want}" ]]; then
        ok "${what} (exit ${got})"
    else
        fail "${what}: want exit ${want}, got '${got}'"
    fi
}

# ── installed-opendeck ───────────────────────────────────────────────────────
d="${WORK}/od-user"; flatpak_stub "${d}" user; stub "${d}" rpm 1
expect 0 "$(run_pred "${d}" installed-opendeck)" "installed-opendeck: user Flatpak installed"

d="${WORK}/od-system"; flatpak_stub "${d}" system; stub "${d}" rpm 1
expect 0 "$(run_pred "${d}" installed-opendeck)" "installed-opendeck: system Flatpak installed"

d="${WORK}/od-bin"; stub "${d}" opendeck 0; stub "${d}" rpm 1
expect 0 "$(run_pred "${d}" installed-opendeck)" "installed-opendeck: opendeck binary on PATH (the RPM/DEB route installs it)"

d="${WORK}/od-none"; flatpak_stub "${d}" none; stub "${d}" rpm 1; stub "${d}" dpkg 1
expect 1 "$(run_pred "${d}" installed-opendeck)" "installed-opendeck: no Flatpak, no binary, no package"

# ── installed-noteshub ───────────────────────────────────────────────────────
d="${WORK}/nh-rpm"; stub "${d}" rpm 0
expect 0 "$(run_pred "${d}" installed-noteshub)" "installed-noteshub: rpm host, NotesHub package installed"

d="${WORK}/nh-rpm-no"; stub "${d}" rpm 1
expect 1 "$(run_pred "${d}" installed-noteshub)" "installed-noteshub: rpm host, NotesHub package not installed"

# A name that isn't confirmed (empty) still means "can't tell", never a guess.
d="${WORK}/nh-rpm-unset"; stub "${d}" rpm 0
expect 2 "$(run_pred "${d}" installed-noteshub _NOTESHUB_RPM_NAME=)" "installed-noteshub: rpm host, package name unset -> can't tell"

d="${WORK}/nh-dpkg"; stub "${d}" dpkg 0 "Status: install ok installed"
expect 0 "$(run_pred "${d}" installed-noteshub)" "installed-noteshub: dpkg host, noteshub package installed"

d="${WORK}/nh-dpkg-no"; stub "${d}" dpkg 1
expect 1 "$(run_pred "${d}" installed-noteshub)" "installed-noteshub: dpkg host, noteshub package not installed"

d="${WORK}/nh-none"; mkdir -p "${d}"
expect 1 "$(run_pred "${d}" installed-noteshub)" "installed-noteshub: no rpm or dpkg (no route on this host)"

# ── _desktop_pkg_installed, once a name is set ───────────────────────────────
d="${WORK}/pkg-rpm-yes"; stub "${d}" rpm 0
expect 0 "$(run_pred "${d}" installed-noteshub _NOTESHUB_RPM_NAME=example)" "package check: rpm -q succeeds"

d="${WORK}/pkg-rpm-no"; stub "${d}" rpm 1
expect 1 "$(run_pred "${d}" installed-noteshub _NOTESHUB_RPM_NAME=example)" "package check: rpm -q fails"

d="${WORK}/pkg-deb-yes"; stub "${d}" dpkg 0 "Status: install ok installed"
expect 0 "$(run_pred "${d}" installed-noteshub _NOTESHUB_DEB_NAME=example)" "package check: dpkg -s says installed"

d="${WORK}/pkg-deb-cfg"; stub "${d}" dpkg 0 "Status: deinstall ok config-files"
expect 1 "$(run_pred "${d}" installed-noteshub _NOTESHUB_DEB_NAME=example)" "package check: dpkg -s says removed, config files left"

# ── D102: no positional-argument installers ──────────────────────────────────
if ! grep -qE '^[[:space:]]*install-[a-z-]+-version[[:space:]]*\(\)' "${INSTALLERS}"; then
    ok "shell/installers.sh defines no install-*-version installer (D102)"
else
    fail "shell/installers.sh still defines an install-*-version installer (D102: installers take no arguments)"
fi

echo
echo "==============================="
echo "Total OK/FAIL checks: ${check_no}, failed: ${FAILED}"
echo "==============================="
[[ "${FAILED}" -eq 0 ]]

#!/usr/bin/env bash
# Prerequisites before the first `chezmoi apply` on Ubuntu 26.10 (standard desktop
# install, GNOME).
#
# Checks first (stops if one is missing). Install them by hand (step 1 of
# docs/install-ubuntu.md):
#   sudo apt-get install git build-essential curl keepassxc-full
#   - keepassxc-full, not keepassxc-minimal: only the full build has the SSH Agent
#   - curl: the official mise and rustup scripts need it, the desktop does not ship it
# Then:
#   1. ssh-agent                 SSH_AUTH_SOCK and ssh-add -l (KeePassXC loads the keys)
#   2. Applications              Alacritty (apt-get), Zed (official script)
#   3. chezmoi                   official script, into ~/.local/bin
#   4. mise                      official script, into ~/.local/bin
#   5. rustup + stable           official script; rust-analyzer component
# and ends with `gh auth login` (SSH protocol).
#
# Run it as your normal user, never with sudo (it calls sudo itself for apt-get).
# The SSH agent is the one the GNOME session already provides: this script only
# checks it, it never starts, installs or replaces an agent. No shell profile is
# edited (chezmoi manages them): ~/.local/bin and ~/.cargo/bin are put on PATH for
# this script only, so open a new terminal afterwards.
#
# Idempotent: every step checks first and skips what is already there.
#
# Updates later:
#   sudo apt-get update && sudo apt-get upgrade   system packages and Alacritty
#   zed                                           updates itself (or rerun its script)
#   rustup update                                 Rust toolchains
#   mise self-update                              mise itself; `mise upgrade` for its tools
#   chezmoi upgrade                               chezmoi itself
#
# Usage: bash scripts/bootstrap-ubuntu.sh

set -euo pipefail

LOCAL_BIN="${HOME}/.local/bin"
CARGO_BIN="${HOME}/.cargo/bin"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# -- Helpers ------------------------------------------------------------------

if [[ -t 1 ]]; then
    C_STEP=$'\033[36m'; C_OK=$'\033[32m'; C_SKIP=$'\033[90m'; C_WARN=$'\033[33m'; C_OFF=$'\033[0m'
else
    C_STEP=''; C_OK=''; C_SKIP=''; C_WARN=''; C_OFF=''
fi
step() { printf '\n%s==> %s%s\n' "${C_STEP}" "$1" "${C_OFF}"; }
ok()   { printf '  %s[ok]%s %s\n' "${C_OK}" "${C_OFF}" "$1"; }
skip() { printf '  %s[--]%s %s\n' "${C_SKIP}" "${C_OFF}" "$1"; }
warn() { printf '  %s[!!]%s %s\n' "${C_WARN}" "${C_OFF}" "$1"; }

have() { command -v "$1" >/dev/null 2>&1; }

# True when the apt package is installed.
pkg_installed() {
    [[ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null)" == "install ok installed" ]]
}

# Put a directory first on PATH for this script, once.
path_prepend() {
    case ":${PATH}:" in
        *":$1:"*) ;;
        *) PATH="$1:${PATH}" ;;
    esac
    export PATH
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

# Download an official install script to a file first: a failed download then
# stops the script instead of running an empty `sh -c ""`.
fetch() { curl --proto '=https' --tlsv1.2 -fsSL "$1" -o "$2"; }

# -- Preconditions ------------------------------------------------------------

if [[ "$(id -u)" -eq 0 ]]; then
    warn "Running as root: chezmoi, mise and rustup must be installed as your normal user."
    warn "Run the script again without sudo."
    exit 1
fi

os_id=""; os_version=""
if [[ -r /etc/os-release ]]; then
    # shellcheck source=/dev/null
    os_id="$(. /etc/os-release && printf '%s' "${ID:-}")"
    # shellcheck source=/dev/null
    os_version="$(. /etc/os-release && printf '%s' "${VERSION_ID:-}")"
fi
if [[ "${os_id}" != "ubuntu" ]]; then
    warn "This script is for Ubuntu 26.10. On macOS use scripts/bootstrap-macos.sh."
    exit 1
fi
if [[ "${os_version}" != "26.10" ]]; then
    warn "Ubuntu ${os_version} detected; this script is written and tested for 26.10."
fi

step "Prerequisites (git, build-essential, curl, keepassxc-full)"
need_pkgs=()
if have git; then skip "git present"; else need_pkgs+=(git); fi
if have cc; then skip "cc present"; else need_pkgs+=(build-essential); fi
if have curl; then skip "curl present"; else need_pkgs+=(curl); fi
if pkg_installed keepassxc-full; then
    skip "KeePassXC present (keepassxc-full, includes the SSH Agent)"
elif pkg_installed keepassxc-minimal; then
    warn "keepassxc-minimal is installed: it has no SSH Agent. Replace it:"
    warn "  sudo apt-get install keepassxc-full"
    exit 1
else
    need_pkgs+=(keepassxc-full)
fi
if [[ ${#need_pkgs[@]} -gt 0 ]]; then
    warn "Missing prerequisites. Install them, then run the script again:"
    warn "  sudo apt-get install ${need_pkgs[*]}"
    exit 1
fi

mkdir -p "${LOCAL_BIN}"
path_prepend "${CARGO_BIN}"
path_prepend "${LOCAL_BIN}"

# -- 1. ssh-agent (KeePassXC SSH Agent integration) ---------------------------
# The GNOME session provides the agent (gcr-ssh-agent, a user socket unit of the
# gcr4 package) and exports SSH_AUTH_SOCK. Nothing is started or installed here.

step "ssh-agent"
if ! have ssh-add; then
    warn "ssh-add not found: sudo apt-get install openssh-client"
elif [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
    warn "SSH_AUTH_SOCK is not set: open a terminal inside the GNOME session (see the troubleshooting section of docs/install-ubuntu.md)"
else
    session_sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/gcr/ssh"
    if [[ "${SSH_AUTH_SOCK}" == "${session_sock}" ]]; then
        skip "SSH_AUTH_SOCK points to the GNOME session agent"
    else
        warn "SSH_AUTH_SOCK is ${SSH_AUTH_SOCK}, not ${session_sock} (the GNOME session agent): another agent is in use"
    fi
    rc=0
    keys="$(ssh-add -l 2>/dev/null)" || rc=$?
    if [[ "${rc}" -eq 0 ]]; then
        skip "ssh-agent holds $(printf '%s\n' "${keys}" | wc -l | tr -d ' ') key(s)"
    elif [[ "${rc}" -eq 1 ]]; then
        warn "ssh-agent holds no keys: unlock KeePassXC (Settings > SSH Agent must be enabled)"
    else
        warn "ssh-add -l could not reach the agent at SSH_AUTH_SOCK: unlock KeePassXC and check the session agent"
    fi
fi

# -- 2. Applications ----------------------------------------------------------

step "Applications"
failed=()
if pkg_installed alacritty; then
    skip "alacritty already installed"
else
    # One failing application must not stop the others.
    if sudo apt-get update && sudo apt-get install -y alacritty; then
        ok "alacritty installed"
    else
        warn "alacritty not installed"
        failed+=(alacritty)
    fi
fi
if have zed || [[ -d "${HOME}/.local/zed.app" ]]; then
    skip "zed already installed"
else
    if fetch "https://zed.dev/install.sh" "${TMP_DIR}/zed-install.sh" && sh "${TMP_DIR}/zed-install.sh"; then
        ok "zed installed"
    else
        warn "zed not installed"
        failed+=(zed)
    fi
fi

# -- 3. chezmoi ---------------------------------------------------------------

step "chezmoi"
if [[ -x "${LOCAL_BIN}/chezmoi" ]]; then
    skip "already in ${LOCAL_BIN}"
else
    fetch "https://get.chezmoi.io" "${TMP_DIR}/chezmoi-install.sh"
    sh "${TMP_DIR}/chezmoi-install.sh" -b "${LOCAL_BIN}"
    ok "installed in ${LOCAL_BIN}"
fi

# -- 4. mise ------------------------------------------------------------------

step "mise"
if [[ -x "${LOCAL_BIN}/mise" ]]; then
    skip "already in ${LOCAL_BIN}"
else
    fetch "https://mise.run" "${TMP_DIR}/mise-install.sh"
    MISE_INSTALL_PATH="${LOCAL_BIN}/mise" sh "${TMP_DIR}/mise-install.sh"
    ok "installed in ${LOCAL_BIN}"
fi

# -- 5. rustup ----------------------------------------------------------------

step "rustup"
if have rustup; then
    skip "already installed"
else
    fetch "https://sh.rustup.rs" "${TMP_DIR}/rustup-init.sh"
    # -y: no prompts. --no-modify-path: chezmoi manages the shell profiles.
    sh "${TMP_DIR}/rustup-init.sh" -y --no-modify-path --default-toolchain stable --profile default
    ok "rustup and the stable toolchain installed"
fi
path_prepend "${CARGO_BIN}"
# The default profile does not include rust-analyzer; repeat for every new toolchain.
if rustup component list --installed 2>/dev/null | grep -q '^rust-analyzer'; then
    skip "rust-analyzer component present"
else
    rustup component add rust-analyzer
    ok "rust-analyzer component added"
fi

# -- Summary ------------------------------------------------------------------

step "Summary"
for tool in git cc curl alacritty zed chezmoi mise rustup cargo; do
    if have "${tool}"; then ok "$(printf '%-9s %s' "${tool}" "$(command -v "${tool}")")"; else warn "${tool} not found in PATH"; fi
done
if [[ ${#failed[@]} -gt 0 ]]; then
    warn "not installed: ${failed[*]} - rerun the script later"
fi

# -- gh auth login ------------------------------------------------------------
# gh is a mise tool. `mise x gh` installs only gh, and no mise configuration
# exists yet at this point (chezmoi writes it later), so nothing else is pulled in.
# The SSH keys are already on GitHub: --skip-ssh-key skips the key upload prompt.

step "GitHub CLI login"
if gh_status="$(mise x gh -- gh auth status 2>&1)"; then
    skip "gh already authenticated:"
    # gh masks the token; the line is dropped anyway.
    printf '%s\n' "${gh_status}" | grep -v -i 'token' | sed 's/^/       /'
else
    if mise x gh -- gh auth login --git-protocol ssh --skip-ssh-key; then
        ok "gh authenticated (git protocol: ssh)"
    else
        warn "gh auth login did not finish. Rerun later: mise x gh -- gh auth login --git-protocol ssh --skip-ssh-key"
    fi
fi

cat <<EOF

Updates later: apt-get upgrade, rustup update, mise self-update, chezmoi upgrade

Next steps (new terminal, so the updated PATH is loaded):
  5. Profile 'poste' only: save the key.txt attachment from KeePassXC to
       ${HOME}/.config/chezmoi/key.txt
     and install the company Claude Code package from the company Download Portal.
  6. chezmoi init --source ${REPO_ROOT}
     (profile 'poste': paste the Bedrock ARNs from the KeePassXC entry notes)
  7. chezmoi diff
     chezmoi apply
EOF

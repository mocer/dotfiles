#!/usr/bin/env bash
# Prerequisites before the first `chezmoi apply` on macOS.
#
# Checks first (stops if one is missing):
#   - Xcode Command Line Tools   git and the C compiler (xcode-select --install)
#   - KeePassXC                  /Applications/KeePassXC.app
# Then:
#   1. ssh-agent                 SSH_AUTH_SOCK and ssh-add -l (KeePassXC loads the keys)
#   2. Applications              Alacritty, Zed, IINA, OrbStack: only reports a missing one
#   3. chezmoi                   official script, into ~/.local/bin
#   4. mise                      official script, into ~/.local/bin
#   5. rustup + stable           official script; rust-analyzer component
# and ends with `gh auth login` (SSH protocol).
#
# Run it as your normal user, never with sudo. No Homebrew. Nothing is installed
# system-wide and no shell profile is edited (chezmoi manages them): ~/.local/bin
# and ~/.cargo/bin are put on PATH for this script only, so open a new terminal
# afterwards.
#
# Idempotent: every step checks first and skips what is already there.
#
# Updates later:
#   rustup update            Rust toolchains
#   mise self-update         mise itself; `mise upgrade` for its tools
#   chezmoi upgrade          chezmoi itself
#   applications             their own updaters
#
# Usage: bash scripts/bootstrap-macos.sh

set -euo pipefail

LOCAL_BIN="${HOME}/.local/bin"
CARGO_BIN="${HOME}/.cargo/bin"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Applications that are not installed here: name|path|official download page.
APPS=(
    "Alacritty|/Applications/Alacritty.app|https://github.com/alacritty/alacritty/releases"
    "Zed|/Applications/Zed.app|https://zed.dev/download"
    "IINA|/Applications/IINA.app|https://iina.io/"
    "OrbStack|/Applications/OrbStack.app|https://orbstack.dev/download"
)
KEEPASSXC_APP="/Applications/KeePassXC.app"
KEEPASSXC_URL="https://keepassxc.org/download/"

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

if [[ "$(uname -s)" != "Darwin" ]]; then
    warn "This script is for macOS. On Ubuntu use scripts/bootstrap-ubuntu.sh."
    exit 1
fi
if [[ "$(id -u)" -eq 0 ]]; then
    warn "Running as root: chezmoi, mise and rustup must be installed as your normal user."
    warn "Run the script again without sudo."
    exit 1
fi
if ! have curl; then
    warn "curl not found (it ships with macOS)."
    exit 1
fi

step "Prerequisites (Xcode Command Line Tools, KeePassXC)"
missing=0
if xcode-select -p >/dev/null 2>&1 && have git && have cc; then
    skip "git and cc present (Xcode Command Line Tools)"
else
    warn "git and the C compiler are missing. Run: xcode-select --install"
    missing=1
fi
if [[ -d "${KEEPASSXC_APP}" ]]; then
    skip "KeePassXC present"
else
    warn "KeePassXC not found in /Applications. Download it from ${KEEPASSXC_URL}"
    missing=1
fi
if [[ "${missing}" -ne 0 ]]; then
    warn "Install the missing prerequisites, then run the script again."
    exit 1
fi

mkdir -p "${LOCAL_BIN}"
path_prepend "${CARGO_BIN}"
path_prepend "${LOCAL_BIN}"

# -- 1. ssh-agent (KeePassXC SSH Agent integration) ---------------------------

step "ssh-agent"
if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
    warn "SSH_AUTH_SOCK is not set: KeePassXC needs a running ssh-agent. Open a new terminal and rerun."
else
    rc=0
    keys="$(ssh-add -l 2>/dev/null)" || rc=$?
    if [[ "${rc}" -eq 0 ]]; then
        skip "ssh-agent holds $(printf '%s\n' "${keys}" | wc -l | tr -d ' ') key(s)"
    elif [[ "${rc}" -eq 1 ]]; then
        warn "ssh-agent holds no keys: unlock KeePassXC (Settings > SSH Agent must be enabled)"
    else
        warn "ssh-add -l could not reach the agent at SSH_AUTH_SOCK: unlock KeePassXC and check the agent"
    fi
fi

# -- 2. Applications (reported, never installed) ------------------------------

step "Applications"
missing_apps=()
for entry in "${APPS[@]}"; do
    IFS='|' read -r name path url <<< "${entry}"
    if [[ -d "${path}" || -d "${HOME}${path}" ]]; then
        skip "${name} present"
    else
        warn "${name} not found in /Applications. Download it from ${url}"
        missing_apps+=("${name}")
    fi
done

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
for tool in git cc chezmoi mise rustup cargo; do
    if have "${tool}"; then ok "$(printf '%-8s %s' "${tool}" "$(command -v "${tool}")")"; else warn "${tool} not found in PATH"; fi
done
if [[ ${#missing_apps[@]} -gt 0 ]]; then
    warn "not installed: ${missing_apps[*]} (download pages above)"
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

Updates later: rustup update, mise self-update, chezmoi upgrade

Next steps (new terminal, so the updated PATH is loaded):
  5. Profile 'poste' only: save the key.txt attachment from KeePassXC to
       ${HOME}/.config/chezmoi/key.txt
     and install the company Claude Code package from the company Download Portal.
  6. chezmoi init --source ${REPO_ROOT}
     (profile 'poste': paste the Bedrock ARNs from the KeePassXC entry notes)
  7. chezmoi diff
     chezmoi apply
EOF

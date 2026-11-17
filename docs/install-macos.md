# Install on macOS

macOS, no Homebrew. Everything below runs as your normal user in Terminal.

The steps are the same on every OS; only steps 1 to 4 differ. Replace `<owner>` with the GitHub account that owns the dotfiles repository.

| # | Step |
| - | ---- |
| 1 | Install the prerequisites |
| 2 | KeePassXC: open the database, enable SSH Agent integration, check `ssh-add -l` |
| 3 | Clone the repository over SSH into `~/Repos/github.com/<owner>/dotfiles` |
| 4 | Run the bootstrap script from the clone; it ends with `gh auth login` |
| 5 | Profile `poste` only: age key and company Claude Code package |
| 6 | `chezmoi init --source <clone>` |
| 7 | `chezmoi diff`, then `chezmoi apply` |

Private SSH keys live only in KeePassXC (SSH Agent). They are never on disk and never in the repository.

## 1. Prerequisites

```sh
xcode-select --install
```

This opens the installer of the Xcode Command Line Tools, which provide Git and the C compiler (`cc`). Wait for it to finish.

Then install KeePassXC: download it from <https://keepassxc.org/download/>, open the disk image and drag KeePassXC to `/Applications`.

Open a new terminal window.

## 2. KeePassXC and the SSH agent

macOS runs an ssh-agent for your session. KeePassXC loads your private keys into it ([user guide](https://keepassxc.org/docs/KeePassXC_UserGuide): on macOS and Linux `SSH_AUTH_SOCK` must be set).

1. Check that the variable is set: `echo "$SSH_AUTH_SOCK"` must print a path.
2. Open KeePassXC and open your database.
3. Open the application settings (**Tools > Settings**), go to **SSH Agent** and tick **Enable SSH Agent integration**.
   Leave both override fields (the `ssh-agent` executable and the authentication socket path) empty. The Windows-only OpenSSH option does not exist on macOS.
4. For every key entry: attach the private key to the entry, then in the entry's **SSH Agent** tab tick **Add key to agent when database is opened/unlocked** and **Remove key from agent when database is closed/locked**. Save the database.

Check:

```sh
ssh-add -l
```

It must list one fingerprint per key. If it says "The agent has no identities", unlock the KeePassXC database.

## 3. Clone the repository

```sh
mkdir -p ~/Repos/github.com/<owner>
git clone git@github.com:<owner>/dotfiles.git ~/Repos/github.com/<owner>/dotfiles
```

The first time, ssh asks you to trust the `github.com` host key: compare it with [GitHub's published fingerprints](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints) before answering `yes`.

There is no `~/.ssh/config` yet, so ssh offers every key loaded in the agent; that is enough to clone.

## 4. Bootstrap

```sh
cd ~/Repos/github.com/<owner>/dotfiles
bash scripts/bootstrap-macos.sh
```

The script refuses to run as root. It checks Git, the C compiler and KeePassXC, checks `SSH_AUTH_SOCK` and `ssh-add -l`, installs chezmoi and mise into `~/.local/bin` and rustup (with `rust-analyzer`) with their official scripts, and puts `~/.local/bin` and `~/.cargo/bin` on the `PATH` of the script only: it edits no shell profile, chezmoi manages them. It installs no application: if Alacritty, Zed, IINA or OrbStack is missing from `/Applications` it prints the official download page; install it by hand, then run the script again. It ends with `gh auth login`: follow the browser flow (SSH protocol; the key upload is skipped, your keys are already on GitHub).

Every step checks first and skips what is already there, so you can run it again. Open a new terminal when it ends.

## 5. Profile `poste` only: age key and company Claude Code package

Skip this step for any other profile: without `poste` nothing in the repository is encrypted, so no key is needed.

1. In KeePassXC, open the entry that holds the age key and save its `key.txt` attachment to `~/.config/chezmoi/key.txt` (`~` is your home folder, `%USERPROFILE%` on Windows). Create the folder if it does not exist.
2. Download the company Claude Code package from the company Download Portal (`<Download Portal URL>`, written in the same KeePassXC entry notes) and run its installer as the package README says. It provides the credential helper `credential-process` in `~/claude-code-with-bedrock/`; chezmoi does not install or vendor it.
<!-- os-note -->
   **macOS:** run `install.sh`. The helper must end up as `~/claude-code-with-bedrock/credential-process`: if the package leaves it as `credential-process*` with another suffix, rename it to exactly `credential-process`.
<!-- /os-note -->
3. Do not paste the key, the portal address or the ARNs anywhere in the repository.

## 6. Initialise chezmoi

```sh
chezmoi init --source <clone>
```

`<clone>` is the clone from step 3. Always use `--source <clone>`; never `chezmoi init <url>`, which would create a second copy of the repository.

chezmoi renders `.chezmoi.toml.tmpl` into `~/.config/chezmoi/chezmoi.toml` and asks:

| Prompt | Answer |
| ------ | ------ |
| Profiles for this machine | `poste`, `mobile`, both, or none. A machine with no profile gets the base configuration. |
| Opus inference profile ARN (empty to skip) | `poste` only. Paste it from the KeePassXC entry notes. |
| Sonnet inference profile ARN (empty to skip) | `poste` only. Same entry. |
| Haiku inference profile ARN (empty to skip) | `poste` only. Same entry. |

The answers are stored in `chezmoi.toml` and reused by every later `chezmoi init`. To be asked again, run `chezmoi init --source <clone> --prompt`. An empty ARN skips the Bedrock files (`~/.claude/settings.json` and the Bedrock blocks of the Zed settings).

The generated file looks like this (placeholders instead of real values):

```toml
sourceDir  = "<clone>"
encryption = "age"

[age]
useBuiltin = true
identity   = "<home>/.config/chezmoi/key.txt"
recipient  = "age1..."

[cd]
command = "nu"

[edit]
command = "hx"

# Windows only
[interpreters.nu]
command = "mise"
args    = ["exec", "aqua:nushell/nushell", "--", "nu"]

[data]
profiles = ["poste"]

[data.mpv]
hardware_decoding = "<d3d11va | videotoolbox | vaapi>"

# profile poste only
[data.bedrock]
opus_arn   = "<opus-inference-profile-arn>"
sonnet_arn = "<sonnet-inference-profile-arn>"
haiku_arn  = "<haiku-inference-profile-arn>"
```

`chezmoi.toml` is generated, never written by hand and never copied between machines: it holds paths and answers that belong to one machine. To change a value, rerun `chezmoi init` as above.

## 7. Review and apply

```sh
chezmoi diff
chezmoi apply
```

`chezmoi diff` shows what would change; read it before applying. `chezmoi apply` writes the configuration and then runs the install scripts: the two-pass `mise install`, the stable links in `~/.local/bin`, the Nushell integrations. The first apply can take a long time because some tools compile from source. If chezmoi asks about a file that changed since it last wrote it, answer the prompt; do not force the apply.

When it ends, open a new terminal, go to `<clone>` and run `just doctor`: every line should be `ok`.

**Profile `poste`: check Claude.** The dotfiles install no separate Claude Code command. Zed runs Claude Code as the Claude Agent and takes its Bedrock settings from `~/.claude/settings.json`, which chezmoi rendered from your ARNs.

1. In Zed, open the Agent Panel, start a new Claude Agent thread and send a short message. An answer means the credential helper, Bedrock and the inference profile ARNs work together.
2. Optional: pick a Bedrock model in the Agent Panel to test Zed's native Bedrock provider, which uses the same AWS profile.
3. If you also run Claude Code in a terminal, `/status` shows the resolved region.

If the thread cannot authenticate, see the `poste` entries of the troubleshooting section.

## After the apply

**FiraCode Nerd Font.** Alacritty and Zed use it. Download `FiraCode.zip` from the [Nerd Fonts releases](https://github.com/ryanoasis/nerd-fonts/releases) and extract it. Open the `.ttf` files with Font Book and click **Install Font**, or copy them to `~/Library/Fonts`. Restart Alacritty and Zed.

**Login shell.** Leave it as it is: zsh on macOS. Nushell is never the login shell; Alacritty, Zed and Helix start it explicitly. chezmoi manages a short `~/.zprofile` that puts the mise shims, `~/.local/bin` and `~/.cargo/bin` on `PATH` for graphical applications.

**Updates later:** `rustup update`, `mise self-update`, `chezmoi upgrade`; for the tools managed by the repository use `system_upgrade` in Nushell.

## Troubleshooting

**GitHub rate limit.** Anonymous GitHub API requests are limited to 60 per hour, and the first `mise install` can exceed that. Check `gh auth status`. If you are not logged in, run `mise x gh -- gh auth login --git-protocol ssh --skip-ssh-key`, then `chezmoi apply` again: the install script passes the token of `gh auth token` to `mise` for its own process only.

**`ssh-add -l` is empty or cannot connect.**
- The database is locked or closed: with the options of step 2 KeePassXC removes the keys from the agent on lock. Unlock it.
- **Enable SSH Agent integration** is not ticked in the KeePassXC settings, or the entry's **SSH Agent** tab has no attached key.
- `echo "$SSH_AUTH_SOCK"` prints nothing: open a new Terminal window; the variable is set for the login session.
- A failed Git or ssh command that prints `Load key "...pub": invalid format` followed by `Permission denied (publickey)` means ssh found no matching key in the agent. It is the same cause.

**`poste`: Claude Agent in Zed (or Claude Code) fails to authenticate.**
- The company session expired. Run the helper once, the same command `awsAuthRefresh` runs, without printing its output: `~/claude-code-with-bedrock/credential-process --profile claude-code > /dev/null`. Complete the sign-in it asks for, then start a new thread.
- The helper is missing or misnamed. The templates call exactly `~/claude-code-with-bedrock/credential-process`; rename the file from the package if needed (step 5).
- Wrong region: `AWS_REGION` in `~/.claude/settings.json` comes from `.chezmoidata/bedrock.toml` and must be the region of your inference profile ARNs. Claude Code uses `AWS_REGION` first ([Claude Code on Amazon Bedrock](https://code.claude.com/docs/en/amazon-bedrock)).
- The model resolves to a built-in or global profile instead of your ARN. This happens when an ARN is empty: the Bedrock files are not rendered, and Claude Code falls back to its default model IDs. Run `chezmoi init --source <clone> --prompt`, enter the three ARNs, then `chezmoi apply`.

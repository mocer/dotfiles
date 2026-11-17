# Install on Windows 11

Windows 11, amd64. Everything below runs as your normal user in Windows PowerShell, except where a step says "elevated".

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

Git and KeePassXC are prerequisites: the bootstrap script checks that they are present and stops if they are not.

```powershell
winget install -e --id Git.Git
winget install -e --id KeePassXCTeam.KeePassXC
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

`Set-ExecutionPolicy` is needed because chezmoi runs every `.ps1` script of this repository with `powershell -NoLogo -File <script>` (with `pwsh -NoLogo -File` when PowerShell 7 is installed), and the bootstrap script is a `.ps1` too. On a Windows client the default policy is Restricted, which does not run script files; RemoteSigned runs local scripts ([about_Execution_Policies](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-5.1)). If `Get-ExecutionPolicy` already prints `RemoteSigned` or a looser policy, you can skip that line.

Open a new terminal, so the updated `PATH` finds `git`.

## 2. KeePassXC and the SSH agent

KeePassXC loads your private keys into the Windows `ssh-agent` service. That service is disabled by default ([Microsoft: key-based authentication in OpenSSH for Windows](https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_keymanagement)). In an **elevated** PowerShell (Run as administrator):

```powershell
Get-Service ssh-agent | Set-Service -StartupType Automatic
Start-Service ssh-agent
Get-Service ssh-agent
```

The last command must show `Running`. Then, in KeePassXC ([user guide](https://keepassxc.org/docs/KeePassXC_UserGuide)):

1. Close the elevated window and continue in a normal one.
2. Open KeePassXC and open your database.
3. Open the application settings (**Tools > Settings**), go to **SSH Agent** and tick **Enable SSH Agent integration**.
   Also tick **Use OpenSSH for Windows instead of Pageant**. Leave both override fields (the `ssh-agent` executable and the authentication socket path) empty.
4. For every key entry: attach the private key to the entry, then in the entry's **SSH Agent** tab tick **Add key to agent when database is opened/unlocked** and **Remove key from agent when database is closed/locked**. Save the database.

Check, in PowerShell (it uses `C:\Windows\System32\OpenSSH\ssh-add.exe`; Git Bash has its own `ssh-add`):

```powershell
ssh-add -l
```

It must list one fingerprint per key. If it says "The agent has no identities", unlock the KeePassXC database.

## 3. Clone the repository

```powershell
New-Item -ItemType Directory -Force "$HOME\Repos\github.com\<owner>" | Out-Null
git -c core.sshCommand=C:/Windows/System32/OpenSSH/ssh.exe clone git@github.com:<owner>/dotfiles.git "$HOME\Repos\github.com\<owner>\dotfiles"
```

The first time, ssh asks you to trust the `github.com` host key: compare it with [GitHub's published fingerprints](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints) before answering `yes`.

`-c core.sshCommand=...` is needed only for this first clone: Git for Windows uses its own bundled ssh by default, while your keys are in the Windows `ssh-agent` service. After step 7, `~/.gitconfig` sets `core.sshCommand` for every repository.

There is no `~/.ssh/config` yet, so ssh offers every key loaded in the agent; that is enough to clone.

## 4. Bootstrap

From the clone, in a normal (not elevated) terminal:

```powershell
cd "$HOME\Repos\github.com\<owner>\dotfiles"
.\scripts\bootstrap-windows.ps1
```

The script checks Git and KeePassXC, then installs the other applications with winget (Alacritty, Zed, mpv.net, yt-dlp, FFmpeg, GIMP, SumatraPDF), checks the `ssh-agent` service and `ssh-add -l`, installs the NVIDIA Control Panel (only with an NVIDIA GPU and its driver), the MSVC Build Tools, chezmoi, mise and rustup (with `rust-analyzer`) and adds `~/.local/bin` to the user `PATH`. UAC prompts appear for the steps that need elevation. It ends with `gh auth login`: follow the browser flow (SSH protocol; the key upload is skipped, your keys are already on GitHub).

Every step checks first and skips what is already there, so you can run it again. Options: `-SkipBuildTools` (Visual Studio is already installed), `-SkipNvidia`. The NVIDIA driver itself is not installed: on AtlasOS install it with NVCleanstall first.

Open a new terminal when it ends.

## 5. Profile `poste` only: age key and company Claude Code package

Skip this step for any other profile: without `poste` nothing in the repository is encrypted, so no key is needed.

1. In KeePassXC, open the entry that holds the age key and save its `key.txt` attachment to `~/.config/chezmoi/key.txt` (`~` is your home folder, `%USERPROFILE%` on Windows). Create the folder if it does not exist.
2. Download the company Claude Code package from the company Download Portal (`<Download Portal URL>`, written in the same KeePassXC entry notes) and run its installer as the package README says. It provides the credential helper `credential-process` in `~/claude-code-with-bedrock/`; chezmoi does not install or vendor it.
<!-- os-note -->
   **Windows:** run `install.bat` as Administrator. The helper must end up as `%USERPROFILE%\claude-code-with-bedrock\credential-process.exe`: if the package leaves it as `credential-process*.exe` with another suffix, rename it to exactly `credential-process.exe`.
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

**FiraCode Nerd Font.** Alacritty and Zed use it. Download `FiraCode.zip` from the [Nerd Fonts releases](https://github.com/ryanoasis/nerd-fonts/releases) and extract it. Select the `.ttf` files, right-click and choose **Install**. Restart Alacritty and Zed.

**Login shell.** Leave it as it is: PowerShell on Windows. Nushell is never the login shell; Alacritty, Zed and Helix start it explicitly.

**Updates later:** `winget upgrade --all`, `rustup update`, `mise self-update`, `chezmoi upgrade`; for the tools managed by the repository use `system_upgrade` in Nushell.

## Troubleshooting

**GitHub rate limit.** Anonymous GitHub API requests are limited to 60 per hour, and the first `mise install` can exceed that. Check `gh auth status`. If you are not logged in, run `mise x gh -- gh auth login --git-protocol ssh --skip-ssh-key`, then `chezmoi apply` again: the install script passes the token of `gh auth token` to `mise` for its own process only.

**`ssh-add -l` is empty or cannot connect.**
- The database is locked or closed: with the options of step 2 KeePassXC removes the keys from the agent on lock. Unlock it.
- **SSH Agent** is not enabled, or **Use OpenSSH for Windows instead of Pageant** is not ticked, in the KeePassXC settings.
- The service is not running: `Get-Service ssh-agent`, then the commands of step 2.
- A failed Git or ssh command that prints `Load key "...pub": invalid format` followed by `Permission denied (publickey)` means ssh found no matching key in the agent. It is the same cause.
- Run `ssh-add -l` in PowerShell, not in Git Bash.

**A `cargo:` tool compiles for a long time.** Some tools of `conf.d/cargo.toml` have no Windows binaries, so `mise install` builds them from source with the MSVC Build Tools. That is expected and the first build can take many minutes. sccache caches the compilation, so reruns are fast. If the install is interrupted, run `mise install` again; a tool that fails only produces a warning, and `just doctor` lists what is missing.

**`poste`: Claude Agent in Zed (or Claude Code) fails to authenticate.**
- The company session expired. Run the helper once, the same command `awsAuthRefresh` runs, without printing its output: `& "$HOME\claude-code-with-bedrock\credential-process.exe" --profile claude-code | Out-Null`. Complete the sign-in it asks for, then start a new thread.
- The helper is missing or misnamed. The templates call exactly `%USERPROFILE%\claude-code-with-bedrock\credential-process.exe`; rename the file from the package if needed (step 5).
- Wrong region: `AWS_REGION` in `~/.claude/settings.json` comes from `.chezmoidata/bedrock.toml` and must be the region of your inference profile ARNs. Claude Code uses `AWS_REGION` first ([Claude Code on Amazon Bedrock](https://code.claude.com/docs/en/amazon-bedrock)).
- The model resolves to a built-in or global profile instead of your ARN. This happens when an ARN is empty: the Bedrock files are not rendered, and Claude Code falls back to its default model IDs. Run `chezmoi init --source <clone> --prompt`, enter the three ARNs, then `chezmoi apply`.

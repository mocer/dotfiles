#Requires -Version 5.1
<#
.SYNOPSIS
    Prerequisites before the first `chezmoi apply` on Windows 11 (amd64, AtlasOS).

.DESCRIPTION
    Checks first (stops if one is missing):
      - Git                      (winget install -e --id Git.Git)
      - KeePassXC                (winget install -e --id KeePassXCTeam.KeePassXC)
    Then installs, in order:
      1. Applications            (winget, see $WingetApps)
      2. ssh-agent service       (Automatic + Running; KeePassXC loads the SSH keys into it)
      3. NVIDIA Control Panel    (Microsoft Store via winget; only with an NVIDIA GPU)
      4. MSVC Build Tools        (winget; linker required by rustup's MSVC toolchain)
      5. chezmoi                 (official script, into ~/.local/bin)
      6. mise                    (official script, into ~/.local/bin)
      7. rustup + stable         (official rustup-init.exe; rust-analyzer component)
    adds ~/.local/bin to the user PATH, and ends with `gh auth login` (SSH protocol).

    Run it as your NORMAL user, not "as Administrator": chezmoi, mise and
    rustup are per-user installs and must land in your own profile. Steps that
    need elevation (ssh-agent service, Build Tools, machine-wide apps) open a UAC
    prompt by themselves.

    Idempotent: every step checks first and skips what is already there.

    Not installed here: the NVIDIA driver. AtlasOS recommends a stripped
    driver installed with NVCleanstall; do that first, then run this script.

    Updates later (NOT handled by Windows Update):
      winget upgrade --all     apps installed with winget
      rustup update            Rust toolchains
      mise self-update         mise itself; `mise upgrade` for its tools
      chezmoi upgrade          chezmoi itself
    The NVIDIA Control Panel is a Store app: the Store updates it.

.PARAMETER SkipBuildTools
    Do not install the MSVC Build Tools (e.g. Visual Studio is already installed).

.PARAMETER SkipNvidia
    Do not install the NVIDIA Control Panel.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-windows.ps1
#>
[CmdletBinding()]
param(
    [switch] $SkipBuildTools,
    [switch] $SkipNvidia
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is much faster without the progress bar

$LocalBin = Join-Path $HOME '.local\bin'
$RepoRoot = Split-Path -Parent $PSScriptRoot   # the clone this script runs from

# Applications installed with winget (source: winget). Add or remove IDs here.
# Check an ID with:  winget show --id <Id> --exact
# Git and KeePassXC are prerequisites: installed by hand, only checked here.
$WingetApps = @(
    'Alacritty.Alacritty'
    'ZedIndustries.Zed'
    'mpv.net'
    'yt-dlp.yt-dlp'              # used by mpv.net to play online URLs
    'yt-dlp.FFmpeg'              # FFmpeg build maintained for yt-dlp (merges audio/video)
    'GIMP.GIMP.3'                # GIMP 3 (GIMP.GIMP is a different package)
    'SumatraPDF.SumatraPDF'
)

# NVIDIA Control Panel: Microsoft Store product ID and its Appx package name.
$NvcpStoreId = '9NF8H0H7WMLT'
$NvcpAppx = 'NVIDIACorp.NVIDIAControlPanel'

# Windows OpenSSH client (the agent KeePassXC talks to is its ssh-agent service).
$SshAdd = Join-Path $env:SystemRoot 'System32\OpenSSH\ssh-add.exe'

# -- Helpers ------------------------------------------------------------------

function Write-Step([string] $msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok([string] $msg)   { Write-Host "  [ok] $msg" -ForegroundColor Green }
function Write-Skip([string] $msg) { Write-Host "  [--] $msg" -ForegroundColor DarkGray }
function Write-Warn([string] $msg) { Write-Host "  [!!] $msg" -ForegroundColor Yellow }

function Test-Command([string] $name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }

# Run a native command line through cmd.exe and return its output lines.
# Windows PowerShell 5.1 throws on stderr output of native commands under
# $ErrorActionPreference = 'Stop', even with 2>$null; cmd.exe avoids it.
# The exit code is left in $LASTEXITCODE.
function Invoke-Native([string] $commandLine) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { return @(cmd.exe /c "$commandLine 2>&1") } finally { $ErrorActionPreference = $previous }
}

# Reload PATH from the registry so tools installed by this script are visible
# in the current session, keeping ~/.local/bin and ~/.cargo/bin in front.
function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = (@($LocalBin, (Join-Path $HOME '.cargo\bin'), $user, $machine) |
        Where-Object { $_ }) -join ';'
}

# Add a directory to the user PATH (persistent) if it is not there yet.
function Add-UserPath([string] $dir) {
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @($user -split ';' | Where-Object { $_ })
    if ($parts -contains $dir) { Write-Skip "$dir already in user PATH"; return }
    [Environment]::SetEnvironmentVariable('Path', (@($dir) + $parts) -join ';', 'User')
    Write-Ok "$dir added to user PATH"
}

# winget install, skipped when the package is already present.
function Install-Winget([string] $id, [string[]] $extra = @(), [string] $source = 'winget') {
    $listed = winget list --id $id --exact --accept-source-agreements 2>$null | Out-String
    if ($listed -match [regex]::Escape($id)) { Write-Skip "$id already installed"; return }
    winget install --id $id --exact --source $source `
        --accept-package-agreements --accept-source-agreements @extra
    # 3010 = success, reboot required (Visual Studio installer)
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 3010) {
        throw "winget install $id failed (exit $LASTEXITCODE)"
    }
    if ($LASTEXITCODE -eq 3010) { Write-Warn "$id installed; a reboot is required" }
    Write-Ok "$id installed"
}

# Git and KeePassXC may have been installed in this very terminal, before PATH
# was reloaded: also look in the default install directories.
function Test-Git {
    (Test-Command git) -or (Test-Path (Join-Path $env:ProgramFiles 'Git\cmd\git.exe'))
}
function Test-KeePassXC {
    $dirs = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ }
    (Test-Command keepassxc-cli) -or
        [bool]($dirs | Where-Object { Test-Path (Join-Path $_ 'KeePassXC\KeePassXC.exe') })
}

# Number of keys the ssh-agent holds, or -1 when the agent cannot be reached.
function Get-AgentKeyCount {
    if (-not (Test-Path $SshAdd)) { return -1 }
    $out = Invoke-Native "$SshAdd -l"
    if ($LASTEXITCODE -eq 0) { return @($out | Where-Object { $_ }).Count }
    if ($LASTEXITCODE -eq 1) { return 0 }   # agent reachable, no identities
    return -1
}

# -- Preconditions ------------------------------------------------------------

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-Warn 'Running elevated: chezmoi, mise and rustup must be installed as your normal user.'
    Write-Warn 'Close this window and run the script from a non-admin terminal.'
    exit 1
}
if (-not (Test-Command winget)) {
    throw 'winget not found. Install "App Installer" from the Microsoft Store and retry.'
}

Write-Step 'Prerequisites (Git, KeePassXC)'
$missingPrereq = @()
if (Test-Git) { Write-Skip 'Git present' } else { $missingPrereq += 'winget install -e --id Git.Git' }
if (Test-KeePassXC) { Write-Skip 'KeePassXC present' } else { $missingPrereq += 'winget install -e --id KeePassXCTeam.KeePassXC' }
if ($missingPrereq) {
    Write-Warn 'Missing prerequisites. Install them, open a new terminal and rerun the script:'
    $missingPrereq | ForEach-Object { Write-Warn "  $_" }
    exit 1
}

New-Item -ItemType Directory -Force -Path $LocalBin | Out-Null

# -- 1. Applications (winget) -------------------------------------------------

Write-Step 'Applications (winget)'
winget source update --name winget | Out-Null
$failed = @()
foreach ($id in $WingetApps) {
    # One failing package must not stop the others.
    try { Install-Winget $id } catch { Write-Warn $_.Exception.Message; $failed += $id }
}

# -- 2. ssh-agent service (KeePassXC SSH Agent integration) ------------------

Write-Step 'ssh-agent service'
$agent = Get-Service -Name ssh-agent -ErrorAction SilentlyContinue
if (-not $agent) {
    Write-Warn 'ssh-agent service not found: the Windows OpenSSH Client feature is missing'
} else {
    $agentReady = ($agent.StartType -eq 'Automatic') -and ($agent.Status -eq 'Running')
    if ($agentReady) {
        Write-Skip 'ssh-agent is Automatic and Running'
    } else {
        # One elevated call fixes both the start type and the running state.
        $cmd = "Set-Service -Name ssh-agent -StartupType Automatic; Start-Service -Name ssh-agent"
        try {
            Start-Process powershell.exe -Verb RunAs -Wait -WindowStyle Hidden `
                -ArgumentList '-NoProfile', '-Command', $cmd
        } catch {
            Write-Warn "elevation refused or failed: $($_.Exception.Message)"
        }
        $agent = Get-Service -Name ssh-agent
        if (($agent.StartType -eq 'Automatic') -and ($agent.Status -eq 'Running')) {
            Write-Ok 'ssh-agent set to Automatic and started (UAC)'
        } else {
            Write-Warn "ssh-agent is $($agent.StartType) / $($agent.Status): run in an elevated PowerShell:"
            Write-Warn '  Set-Service -Name ssh-agent -StartupType Automatic; Start-Service ssh-agent'
        }
    }
    $keys = Get-AgentKeyCount
    if ($keys -gt 0) {
        Write-Skip "ssh-agent holds $keys key(s)"
    } elseif ($keys -eq 0) {
        Write-Warn 'ssh-agent holds no keys: unlock KeePassXC (Settings > SSH Agent must be enabled)'
    } else {
        Write-Warn 'ssh-add -l could not reach the agent: unlock KeePassXC and check the ssh-agent service'
    }
}

# -- 3. NVIDIA Control Panel (Microsoft Store) --------------------------------

Write-Step 'NVIDIA Control Panel'
$nvidiaGpu = Get-CimInstance Win32_VideoController |
    Where-Object { $_.Name -match 'NVIDIA' } | Select-Object -First 1
if ($SkipNvidia) {
    Write-Skip 'skipped (-SkipNvidia)'
} elseif (-not $nvidiaGpu) {
    Write-Skip 'no NVIDIA GPU found'
} elseif ($nvidiaGpu.Status -ne 'OK' -or $nvidiaGpu.DriverVersion -eq $null) {
    Write-Warn "$($nvidiaGpu.Name): driver not installed - install it with NVCleanstall, then rerun"
} elseif (Get-AppxPackage -Name $NvcpAppx) {
    Write-Skip "already installed ($($nvidiaGpu.Name))"
} else {
    # The panel needs a DCH driver; it is distributed only through the Store.
    try {
        Install-Winget $NvcpStoreId @() 'msstore'
    } catch {
        Write-Warn $_.Exception.Message
        Write-Warn 'Is the Microsoft Store available? Manual link: https://apps.microsoft.com/detail/9nf8h0h7wmlt'
        $failed += 'NVIDIA Control Panel'
    }
}

# -- 4. MSVC Build Tools (rustup prerequisite) --------------------------------

Write-Step 'MSVC Build Tools'
if ($SkipBuildTools) {
    Write-Skip 'skipped (-SkipBuildTools)'
} else {
    # Desktop C++ workload: MSVC linker, libraries and Windows SDK.
    Install-Winget 'Microsoft.VisualStudio.2022.BuildTools' @(
        '--override',
        '--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'
    )
}

Update-SessionPath

# -- 5. chezmoi ---------------------------------------------------------------

Write-Step 'chezmoi'
if (Test-Path (Join-Path $LocalBin 'chezmoi.exe')) {
    Write-Skip "already in $LocalBin"
} else {
    Invoke-Expression "&{$(Invoke-RestMethod 'https://get.chezmoi.io/ps1')} -b '$LocalBin'"
    Write-Ok "installed in $LocalBin"
}

# -- 6. mise ------------------------------------------------------------------

Write-Step 'mise'
$miseExe = Join-Path $LocalBin 'mise.exe'
if (Test-Path $miseExe) {
    Write-Skip "already in $LocalBin"
} else {
    $env:MISE_INSTALL_PATH = $miseExe
    Invoke-RestMethod 'https://mise.run/powershell' | Invoke-Expression
    Remove-Item Env:MISE_INSTALL_PATH -ErrorAction SilentlyContinue
    if (-not (Test-Path $miseExe)) {
        Update-SessionPath
        $found = Get-Command mise -ErrorAction SilentlyContinue
        if ($found) {
            Write-Warn "installed in $($found.Source) instead of $LocalBin"
        } else {
            throw 'mise installer finished but mise.exe was not found'
        }
    } else {
        Write-Ok "installed in $LocalBin"
    }
}

# -- 7. rustup ----------------------------------------------------------------

Write-Step 'rustup'
Update-SessionPath
if (Test-Command rustup) {
    Write-Skip 'already installed'
} else {
    $init = Join-Path $env:TEMP 'rustup-init.exe'
    Invoke-WebRequest 'https://win.rustup.rs/x86_64' -OutFile $init
    # -y: no prompts; Build Tools are already installed, so rustup-init does not
    # offer to install Visual Studio Community.
    & $init -y --default-toolchain stable --profile default
    if ($LASTEXITCODE -ne 0) { throw "rustup-init failed (exit $LASTEXITCODE)" }
    Remove-Item $init -Force
    Write-Ok 'rustup and the stable toolchain installed'
}
Update-SessionPath
# The default profile does not include rust-analyzer; repeat for every new toolchain.
rustup component add rust-analyzer
Write-Ok 'rust-analyzer component present'

# -- PATH and summary ---------------------------------------------------------

Write-Step 'PATH'
Add-UserPath $LocalBin
Update-SessionPath

Write-Step 'Summary'
foreach ($t in 'git', 'alacritty', 'zed', 'yt-dlp', 'ffmpeg', 'chezmoi', 'mise', 'rustup', 'cargo') {
    $c = Get-Command $t -ErrorAction SilentlyContinue
    if ($c) { Write-Ok ('{0,-10} {1}' -f $t, $c.Source) } else { Write-Warn "$t not found in PATH" }
}
if ($failed) { Write-Warn ('not installed: ' + ($failed -join ', ') + ' - rerun the script later') }

# -- gh auth login ------------------------------------------------------------
# gh is a mise tool. `mise x gh` installs only gh, and no mise configuration
# exists yet at this point (chezmoi writes it later), so nothing else is pulled in.
# The SSH keys are already on GitHub: --skip-ssh-key skips the key upload prompt.

Write-Step 'GitHub CLI login'
$ghStatus = Invoke-Native 'mise x gh -- gh auth status'
if ($LASTEXITCODE -eq 0) {
    Write-Skip 'gh already authenticated:'
    # gh masks the token; the line is dropped anyway.
    $ghStatus | Where-Object { $_ -and $_ -notmatch 'Token' } | ForEach-Object { Write-Host "       $_" }
} else {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    mise x gh -- gh auth login --git-protocol ssh --skip-ssh-key
    $ghExit = $LASTEXITCODE
    $ErrorActionPreference = $previous
    if ($ghExit -eq 0) {
        Write-Ok 'gh authenticated (git protocol: ssh)'
    } else {
        Write-Warn 'gh auth login did not finish. Rerun later: mise x gh -- gh auth login --git-protocol ssh --skip-ssh-key'
    }
}

Write-Host @"

Updates later: winget upgrade --all  (plus rustup update, mise self-update, chezmoi upgrade)

Next steps (new terminal, so the updated PATH is loaded):
  5. Profile 'poste' only: save the key.txt attachment from KeePassXC to
       $HOME\.config\chezmoi\key.txt
     and install the company Claude Code package from the company Download Portal.
  6. chezmoi init --source $RepoRoot
     (profile 'poste': paste the Bedrock ARNs from the KeePassXC entry notes)
  7. chezmoi diff
     chezmoi apply
"@

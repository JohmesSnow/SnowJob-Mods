<#
  Snow Job mod pack updater for Valheim (Steam, Windows).

  Reads manifest.json from the SnowJob-Mods GitHub repo, compares it with the Valheim folder and
  brings the folder in line: installs or updates mods whose files differ, removes mods the pack
  dropped, and refreshes the few config presets the pack manages.

  Safety rules:
    - only writes inside the Valheim folder (every target path is checked)
    - only downloads from thunderstore.io, raw.githubusercontent.com (this repo) and cdn.hexium.gg
    - every download is checked against the SHA-256 in the manifest before anything is written
    - never touches mods or configs the pack does not list
    - overwritten config presets are kept as <name>.cfg.bak
#>
[CmdletBinding()]
param(
    [string]$GameDir,
    [string]$ManifestUrl = 'https://raw.githubusercontent.com/JohmesSnow/SnowJob-Mods/main/manifest.json',
    [string]$ManifestPath,
    [string]$LocalRepo,   # testing: read this repo's own files from disk instead of GitHub
    [switch]$CheckOnly,
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'
$UpdaterVersion = '1.0.0'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

$AllowedHosts = @('thunderstore.io', 'gcdn.thunderstore.io', 'raw.githubusercontent.com', 'cdn.hexium.gg')
$RepoPrefix = 'https://raw.githubusercontent.com/JohmesSnow/SnowJob-Mods/'

function Say([string]$text, [string]$color = 'Gray') { Write-Host $text -ForegroundColor $color }

function Finish([int]$code) {
    if (-not $NoPause) { Write-Host ''; Read-Host 'Press Enter to close' | Out-Null }
    exit $code
}

function Get-Sha256([string]$path) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $fs = [System.IO.File]::OpenRead($path)
    try { return ([BitConverter]::ToString($sha.ComputeHash($fs)) -replace '-', '').ToLowerInvariant() }
    finally { $fs.Dispose(); $sha.Dispose() }
}

function Get-BytesSha256([byte[]]$bytes) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

# Resolve a manifest path to a full path inside the game folder, or stop.
function Resolve-Target([string]$rel) {
    $r = $rel -replace '/', '\'
    if ([string]::IsNullOrWhiteSpace($r) -or $r.StartsWith('\') -or $r.Contains(':') -or ($r.Split('\') -contains '..')) {
        throw "Refusing unsafe path in manifest: $rel"
    }
    $full = [System.IO.Path]::GetFullPath((Join-Path $script:Game $r))
    if (-not $full.StartsWith($script:GameFull, [StringComparison]::OrdinalIgnoreCase)) { throw "Refusing path outside the Valheim folder: $rel" }
    return $full
}

function Test-AllowedUrl([string]$url) {
    $u = [Uri]$url
    if ($u.Scheme -ne 'https') { return $false }
    if ($AllowedHosts -notcontains $u.Host.ToLowerInvariant()) { return $false }
    if ($u.Host -eq 'raw.githubusercontent.com' -and -not $url.StartsWith($RepoPrefix)) { return $false }
    return $true
}

function Get-Download([string]$url) {
    if (-not (Test-AllowedUrl $url)) { throw "Refusing download from an unexpected address: $url" }
    $wc = New-Object Net.WebClient
    $wc.Headers.Add('User-Agent', "SnowJob-Updater/$UpdaterVersion")
    try { return $wc.DownloadData($url) } finally { $wc.Dispose() }
}

function Get-RepoFile([string]$base, [string]$rel) {
    if ($LocalRepo) { return [System.IO.File]::ReadAllBytes((Join-Path $LocalRepo $rel.Replace('/', [IO.Path]::DirectorySeparatorChar))) }
    return Get-Download ($base + ((($rel -split '/') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'))
}

function Write-FileSafely([string]$dest, [byte[]]$bytes) {
    $dir = Split-Path $dest -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $tmp = "$dest.snowjob-tmp"
    [System.IO.File]::WriteAllBytes($tmp, $bytes)
    if (Test-Path $dest) { Remove-Item $dest -Force }
    Move-Item $tmp $dest -Force
}

function Find-Valheim {
    $roots = @()
    foreach ($key in 'HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam') {
        try {
            $p = Get-ItemProperty -Path $key -ErrorAction Stop
            foreach ($name in 'SteamPath', 'InstallPath') { if ($p.$name) { $roots += ($p.$name -replace '/', '\') } }
        } catch { }
    }
    $libs = @()
    foreach ($root in ($roots | Select-Object -Unique)) {
        $libs += $root
        $vdf = Join-Path $root 'steamapps\libraryfolders.vdf'
        if (Test-Path $vdf) {
            foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) { $libs += ($m.Groups[1].Value -replace '\\\\', '\') }
        }
    }
    foreach ($lib in ($libs | Select-Object -Unique)) {
        $candidate = Join-Path $lib 'steamapps\common\Valheim'
        if (Test-Path (Join-Path $candidate 'valheim.exe')) { return $candidate }
    }
    return $null
}

# ---------------------------------------------------------------------------------------------
Say "Snow Job mod updater $UpdaterVersion" 'Cyan'
Say '-----------------------------------' 'Cyan'

if (Get-Process -Name valheim -ErrorAction SilentlyContinue) {
    Say 'Valheim is running. Close the game, then run the updater again.' 'Yellow'
    Finish 1
}

if (-not $GameDir) { $GameDir = Find-Valheim }
if (-not $GameDir) {
    Say 'Could not find Valheim automatically.' 'Yellow'
    Say 'In Steam: right-click Valheim > Manage > Browse local files, then paste that folder here.'
    $GameDir = (Read-Host 'Valheim folder').Trim('"', ' ')
}
if (-not (Test-Path (Join-Path $GameDir 'valheim.exe'))) {
    Say "valheim.exe was not found in '$GameDir'. Nothing was changed." 'Red'
    Finish 1
}
$script:Game = (Resolve-Path $GameDir).Path
$script:GameFull = [System.IO.Path]::GetFullPath($script:Game).TrimEnd('\') + '\'
Say "Valheim folder: $($script:Game)"

try {
    if ($ManifestPath) { $json = Get-Content $ManifestPath -Raw }
    else { $json = [Text.Encoding]::UTF8.GetString((Get-Download $ManifestUrl)) }
    $manifest = $json | ConvertFrom-Json
} catch {
    Say "Could not read the mod list: $($_.Exception.Message)" 'Red'
    Say 'Check your internet connection and try again. Nothing was changed.'
    Finish 1
}
if ($manifest.schema -ne 1) { Say 'This updater is too old for the current mod list. Download SnowJob-Updater.bat again.' 'Red'; Finish 1 }
Say "Pack: $($manifest.name) for $($manifest.game)"
Say ''

$statePath = Join-Path $script:Game 'BepInEx\SnowJob-Updater-state.json'
$state = @{}
if (Test-Path $statePath) {
    try { (Get-Content $statePath -Raw | ConvertFrom-Json).configs.PSObject.Properties | ForEach-Object { $state[$_.Name] = $_.Value } } catch { }
}

# Check every path and address in the list before touching anything.
try {
    foreach ($mod in $manifest.mods) {
        foreach ($f in $mod.files) { Resolve-Target $f.to | Out-Null }
        if ($mod.source.type -eq 'zip' -and -not (Test-AllowedUrl $mod.source.url)) { throw "unexpected download address for $($mod.name)" }
    }
    foreach ($c in $manifest.configs) { Resolve-Target $c.to | Out-Null }
    foreach ($rel in $manifest.remove) { Resolve-Target $rel | Out-Null }
} catch {
    Say "The mod list failed a safety check ($($_.Exception.Message)). Nothing was changed." 'Red'
    Finish 1
}

$changes = New-Object System.Collections.Generic.List[string]
$failures = New-Object System.Collections.Generic.List[string]

# 1. Mods
foreach ($mod in $manifest.mods) {
    $todo = @()
    foreach ($f in $mod.files) {
        $dest = Resolve-Target $f.to
        if (Test-Path $dest) {
            if ($f.onlyIfMissing) { continue }
            if ((Get-Sha256 $dest) -eq $f.sha256) { continue }
        }
        $todo += [pscustomobject]@{ File = $f; Dest = $dest }
    }
    if ($todo.Count -eq 0) { Say ("  ok       {0} {1}" -f $mod.name, $mod.version) 'DarkGray'; continue }

    $present = @($mod.files | Where-Object { -not $_.onlyIfMissing -and (Test-Path (Resolve-Target $_.to)) }).Count
    $verb = if ($present -eq 0) { 'install ' } else { 'update  ' }
    Say ("  {0} {1} {2}" -f $verb, $mod.name, $mod.version) 'Green'
    if ($CheckOnly) { $changes.Add("$($verb.Trim()) $($mod.name) $($mod.version)"); continue }

    try {
        if ($mod.source.type -eq 'zip') {
            $zipBytes = Get-Download $mod.source.url
            if ((Get-BytesSha256 $zipBytes) -ne $mod.source.sha256) { throw 'download checksum does not match' }
            $zip = New-Object System.IO.Compression.ZipArchive((New-Object IO.MemoryStream(, $zipBytes)), [IO.Compression.ZipArchiveMode]::Read)
            try {
                foreach ($t in $todo) {
                    $want = $t.File.from.Replace([char]92, [char]47)
                    $entry = $zip.Entries | Where-Object { $_.FullName.Replace([char]92, [char]47) -eq $want } | Select-Object -First 1
                    if (-not $entry) { throw "missing $($t.File.from) in package" }
                    $ms = New-Object IO.MemoryStream; $s = $entry.Open(); $s.CopyTo($ms); $s.Dispose()
                    $bytes = $ms.ToArray()
                    if ((Get-BytesSha256 $bytes) -ne $t.File.sha256) { throw "checksum mismatch for $($t.File.to)" }
                    Write-FileSafely $t.Dest $bytes
                }
            } finally { $zip.Dispose() }
        } elseif ($mod.source.type -eq 'files') {
            foreach ($t in $todo) {
                $bytes = Get-RepoFile $mod.source.base $t.File.from
                if ((Get-BytesSha256 $bytes) -ne $t.File.sha256) { throw "checksum mismatch for $($t.File.to)" }
                Write-FileSafely $t.Dest $bytes
            }
        } else { throw "unknown source type $($mod.source.type)" }
        $changes.Add("$($verb.Trim()) $($mod.name) $($mod.version)")
    } catch {
        Say "           failed: $($_.Exception.Message)" 'Red'
        $failures.Add("$($mod.name): $($_.Exception.Message)")
    }
}

# 2. Mods the pack no longer uses
foreach ($rel in $manifest.remove) {
    $target = Resolve-Target $rel
    if (Test-Path $target) {
        Say "  remove   $rel" 'Yellow'
        if (-not $CheckOnly) { Remove-Item $target -Recurse -Force }
        $changes.Add("removed $rel")
    }
}

# 3. Config presets the pack manages (only rewritten when the pack publishes a new version)
foreach ($c in $manifest.configs) {
    $dest = Resolve-Target $c.to
    $exists = Test-Path $dest
    $current = if ($exists) { Get-Sha256 $dest } else { $null }
    if ($current -eq $c.sha256) { $state[$c.to] = $c.sha256; continue }
    if ($exists -and $state[$c.to] -eq $c.sha256) { continue }  # we already applied this version, the player changed it since
    Say ("  config   {0}" -f (Split-Path $c.to -Leaf)) 'Green'
    if ($CheckOnly) { $changes.Add("config $($c.to)"); continue }
    try {
        $bytes = Get-RepoFile $manifest.repoBase $c.from
        if ((Get-BytesSha256 $bytes) -ne $c.sha256) { throw 'checksum mismatch' }
        if ($exists) { Copy-Item $dest "$dest.bak" -Force }
        Write-FileSafely $dest $bytes
        $state[$c.to] = $c.sha256
        $changes.Add("config $($c.to)")
    } catch {
        Say "           failed: $($_.Exception.Message)" 'Red'
        $failures.Add("$($c.to): $($_.Exception.Message)")
    }
}

if (-not $CheckOnly -and (Test-Path (Join-Path $script:Game 'BepInEx'))) {
    $out = [ordered]@{ updater = $UpdaterVersion; manifest = $manifest.generated; lastRun = (Get-Date).ToString('s'); configs = $state }
    ($out | ConvertTo-Json -Depth 4) | Set-Content -Path $statePath -Encoding UTF8
}

Say ''
if ($failures.Count -gt 0) {
    Say "$($failures.Count) item(s) failed. Run the updater again; if it keeps failing, send a screenshot of this window." 'Red'
    Finish 2
}
if ($changes.Count -eq 0) { Say 'Everything is up to date.' 'Cyan' }
elseif ($CheckOnly) { Say "$($changes.Count) change(s) needed. Run without -CheckOnly to apply them." 'Yellow'; Finish 0 }
else { Say "Done: $($changes.Count) change(s) applied." 'Cyan' }

if (-not $NoPause) {
    $answer = Read-Host 'Start Valheim now? (Y/N)'
    if ($answer -match '^[Yy]') { Start-Process 'steam://rungameid/892970' }
}
exit 0

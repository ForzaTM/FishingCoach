<#
.SYNOPSIS
    Finds World of Warcraft: Forever on this PC and installs (or updates /
    removes) the Fishing Coach addon in <WoW>\_forever_\Interface\AddOns\FishingCoach.

.DESCRIPTION
    Where it looks, in this order:
      1. Windows registry entries written by the Blizzard installer
      2. Install paths remembered by the Battle.net app
      3. Common folders on every fixed drive (C:\World of Warcraft,
         C:\Program Files (x86)\World of Warcraft, D:\Games\World of Warcraft, ...)
      4. Optional deeper scan of all fixed drives (asks first, can take a while)
    It never changes anything outside the Fishing Coach addon folder. Your settings
    and fishing history are stored in the WTF folder and are kept.

.PARAMETER Path
    Install into this folder instead of searching. Accepts the WoW folder,
    the _forever_ folder or the AddOns folder itself.
.PARAMETER Yes
    Do not ask questions: use the first Forever folder found (live before beta).
.PARAMETER Uninstall
    Remove Fishing Coach from the chosen Forever folder.
.PARAMETER ListOnly
    Only print the Forever folders that were found.
.PARAMETER DeepScan
    Also scan fixed drives (3 folder levels deep) without asking.
.PARAMETER SearchRoot
    Extra folders to treat as possible WoW folders (used by the tests).
.PARAMETER NoDefaultSearch
    Skip registry, Battle.net and drive search (used by the tests).
#>
[CmdletBinding()]
param(
    [string]$Path,
    [switch]$Yes,
    [switch]$Uninstall,
    [switch]$ListOnly,
    [switch]$DeepScan,
    [string[]]$SearchRoot = @(),
    [switch]$NoDefaultSearch
)

$ErrorActionPreference = 'Stop'
$AddonName = 'FishingCoach'      # folder / TOC name
$DisplayName = 'Fishing Coach'    # name shown to players
$OldAddonName = 'ReelGold'        # the addon's previous name (migrated on install)
$Flavors = [ordered]@{
    '_forever_'      = 'WoW: Forever'
    '_forever_beta_' = 'WoW: Forever (beta)'
    '_forever_ptr_'  = 'WoW: Forever (PTR)'
}

function Write-Title($text) { Write-Host ''; Write-Host $text -ForegroundColor Yellow }
function Write-Ok($text)    { Write-Host "  $text" -ForegroundColor Green }
function Write-Note($text)  { Write-Host "  $text" -ForegroundColor Gray }
function Write-Warn2($text) { Write-Host "  $text" -ForegroundColor DarkYellow }

#---------------------------------------------------------------------
# Source files
#---------------------------------------------------------------------
function Get-AddonSource {
    # Release bundle: .\Fishing Coach\FishingCoach.toc next to this script.
    $bundle = Join-Path $PSScriptRoot $AddonName
    if (Test-Path (Join-Path $bundle "$AddonName.toc")) {
        return @{ Root = $bundle; Files = @(Get-ChildItem $bundle -Recurse -File | ForEach-Object { $_.FullName.Substring($bundle.Length + 1) }) }
    }
    # Repository: tools\installer\install.ps1 -> repo root. Copy only what the TOC loads.
    $repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    $toc = Join-Path $repo "$AddonName.toc"
    if (-not (Test-Path $toc)) { throw "Cannot find the $DisplayName addon files next to the installer." }
    $files = @("$AddonName.toc")
    foreach ($line in Get-Content $toc) {
        $l = $line.Trim()
        if ($l -and -not $l.StartsWith('#')) { $files += $l }
    }
    if (Test-Path (Join-Path $repo 'LICENSE')) { $files += 'LICENSE' }
    # Textures (logo) are not listed in the TOC.
    $media = Join-Path $repo 'Media'
    if (Test-Path $media) {
        $files += @(Get-ChildItem $media -Recurse -File | ForEach-Object { $_.FullName.Substring($repo.Length + 1) })
    }
    return @{ Root = $repo; Files = $files }
}

function Get-TocVersion([string]$tocPath) {
    if (-not (Test-Path $tocPath)) { return $null }
    $m = Select-String -Path $tocPath -Pattern '^## Version:\s*(.+)$' | Select-Object -First 1
    if (-not $m) { return 'unknown' }
    $v = $m.Matches[0].Groups[1].Value.Trim()
    if ($v -eq '@project-version@') { return 'dev' }
    return $v
}

#---------------------------------------------------------------------
# Finding World of Warcraft
#---------------------------------------------------------------------
function Get-WowRootFromPath([string]$p) {
    # Turn ...\World of Warcraft\_retail_\Wow.exe (or similar) into ...\World of Warcraft
    if (-not $p) { return $null }
    $p = $p.Trim().Trim('"').TrimEnd('\', '/')
    if (Test-Path $p -PathType Leaf) { $p = Split-Path $p -Parent }
    while ($p -and (Split-Path $p -Leaf) -match '^_.+_$') { $p = Split-Path $p -Parent }
    if ($p -and (Test-Path $p -PathType Container)) { return (Resolve-Path $p).Path }
    return $null
}

function Get-RegistryRoots {
    $keys = @(
        'HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft',
        'HKLM:\SOFTWARE\Blizzard Entertainment\World of Warcraft',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\World of Warcraft',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\World of Warcraft',
        'HKCU:\SOFTWARE\Blizzard Entertainment\World of Warcraft'
    )
    foreach ($k in $keys) {
        try {
            $item = Get-ItemProperty -Path $k -ErrorAction Stop
            foreach ($name in 'InstallPath', 'InstallLocation', 'GamePath') {
                $val = $item.$name
                if ($val) { Get-WowRootFromPath $val }
            }
        } catch { }
    }
}

function Get-BattleNetRoots {
    # product.db is a binary file; install paths are stored as plain text inside it.
    $db = Join-Path $env:ProgramData 'Battle.net\Agent\product.db'
    if (-not (Test-Path $db)) { return }
    try {
        $text = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($db))
        foreach ($m in [regex]::Matches($text, '[A-Za-z]:[\\/][^\x00-\x1f"<>|*?]{0,200}?World of Warcraft')) {
            Get-WowRootFromPath ($m.Value -replace '/', '\')
        }
    } catch { }
}

function Get-FixedDrives {
    Get-PSDrive -PSProvider FileSystem | Where-Object {
        $_.Root -match '^[A-Za-z]:\\$' -and (Test-Path $_.Root)
    } | Where-Object {
        try { ([System.IO.DriveInfo]$_.Root).DriveType -eq 'Fixed' } catch { $false }
    } | ForEach-Object { $_.Root }
}

function Get-CommonRoots {
    $relative = @(
        'World of Warcraft',
        'Program Files (x86)\World of Warcraft',
        'Program Files\World of Warcraft',
        'Games\World of Warcraft',
        'Game\World of Warcraft',
        'Blizzard\World of Warcraft',
        'Blizzard Games\World of Warcraft',
        'Battle.net\World of Warcraft',
        'Program Files (x86)\Battle.net\World of Warcraft',
        'Program Files (x86)\Blizzard Games\World of Warcraft'
    )
    foreach ($drive in Get-FixedDrives) {
        foreach ($rel in $relative) {
            $p = Join-Path $drive $rel
            if (Test-Path $p -PathType Container) { (Resolve-Path $p).Path }
        }
    }
}

function Get-DeepScanRoots {
    $skip = '^(Windows|\$Recycle\.Bin|System Volume Information|ProgramData|Recovery|PerfLogs|AppData|node_modules|\.git)$'
    foreach ($drive in Get-FixedDrives) {
        Write-Note "Scanning $drive ..."
        $queue = New-Object System.Collections.Queue
        $queue.Enqueue(@($drive, 0))
        while ($queue.Count -gt 0) {
            $item = $queue.Dequeue()
            $dir = $item[0]; $depth = $item[1]
            try { $children = [System.IO.Directory]::GetDirectories($dir) } catch { continue }
            foreach ($child in $children) {
                $leaf = [System.IO.Path]::GetFileName($child)
                if ($leaf -match $skip) { continue }
                if ($Flavors.Contains($leaf)) { Get-WowRootFromPath $child; continue }
                if ($depth -lt 3) { $queue.Enqueue(@($child, $depth + 1)) }
            }
        }
    }
}

function Find-ForeverFolders([string[]]$roots) {
    $seen = @{}
    $result = @()
    foreach ($root in $roots) {
        if (-not $root -or -not (Test-Path $root -PathType Container)) { continue }
        $key = $root.ToLowerInvariant()
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = $true
        foreach ($flavor in $Flavors.Keys) {
            $game = Join-Path $root $flavor
            if (Test-Path $game -PathType Container) {
                $addons = Join-Path $game 'Interface\AddOns'
                $result += [pscustomobject]@{
                    Name      = $Flavors[$flavor]
                    Flavor    = $flavor
                    GameDir   = $game
                    AddOnsDir = $addons
                    Installed = Get-TocVersion (Join-Path $addons "$AddonName\$AddonName.toc")
                }
            }
        }
    }
    return ,$result
}

function Get-OtherFlavors([string[]]$roots) {
    $other = @()
    foreach ($root in ($roots | Select-Object -Unique)) {
        if (-not $root -or -not (Test-Path $root)) { continue }
        Get-ChildItem $root -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^_.+_$' -and -not $Flavors.Contains($_.Name) } |
            ForEach-Object { $other += $_.FullName }
    }
    return $other
}

function Resolve-ManualTarget([string]$p) {
    $p = $p.Trim().Trim('"').TrimEnd('\', '/')
    if (-not (Test-Path $p -PathType Container)) { throw "Folder not found: $p" }
    $p = (Resolve-Path $p).Path
    $leaf = Split-Path $p -Leaf
    if ($leaf -ieq 'AddOns') {
        return [pscustomobject]@{ Name = 'Custom folder'; GameDir = (Split-Path (Split-Path $p -Parent) -Parent); AddOnsDir = $p; Installed = Get-TocVersion (Join-Path $p "$AddonName\$AddonName.toc") }
    }
    if ($leaf -ieq 'Interface') { return Resolve-ManualTarget (Join-Path $p 'AddOns') }
    if ($Flavors.Contains($leaf.ToLowerInvariant())) {
        $addons = Join-Path $p 'Interface\AddOns'
        return [pscustomobject]@{ Name = $Flavors[$leaf.ToLowerInvariant()]; GameDir = $p; AddOnsDir = $addons; Installed = Get-TocVersion (Join-Path $addons "$AddonName\$AddonName.toc") }
    }
    $found = Find-ForeverFolders @($p)
    if ($found.Count -gt 0) { return $found[0] }
    throw "No _forever_ folder inside $p. Pick the World of Warcraft folder, its _forever_ folder, or Interface\AddOns."
}

#---------------------------------------------------------------------
# Install / uninstall
#---------------------------------------------------------------------
function Install-Addon($target, $source) {
    $dest = Join-Path $target.AddOnsDir $AddonName
    if (-not (Test-Path $target.AddOnsDir)) {
        New-Item -ItemType Directory -Path $target.AddOnsDir -Force | Out-Null
        Write-Note "Created $($target.AddOnsDir)"
    }
    if (Test-Path $dest) {
        # Only ever delete a folder that really is Fishing Coach.
        if (-not (Test-Path (Join-Path $dest "$AddonName.toc"))) {
            throw "$dest exists but does not look like $DisplayName. Nothing was changed."
        }
        Remove-Item -LiteralPath $dest -Recurse -Force
    }
    foreach ($rel in $source.Files) {
        $from = Join-Path $source.Root $rel
        $to = Join-Path $dest $rel
        if (-not (Test-Path $from)) { throw "Missing addon file: $rel" }
        New-Item -ItemType Directory -Path (Split-Path $to -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $from -Destination $to -Force
    }
    Write-Ok "Installed $DisplayName $(Get-TocVersion (Join-Path $dest "$AddonName.toc")) ($($source.Files.Count) files) into:"
    Write-Ok $dest
}

function Uninstall-Addon($target) {
    $dest = Join-Path $target.AddOnsDir $AddonName
    if (-not (Test-Path (Join-Path $dest "$AddonName.toc"))) {
        Write-Note "$DisplayName is not installed in $($target.AddOnsDir)."
        return
    }
    Remove-Item -LiteralPath $dest -Recurse -Force
    Write-Ok "Removed $dest"
    Write-Note 'Your Fishing Coach settings and fishing history in the WTF folder were kept.'
}

#---------------------------------------------------------------------
# Migration from the old addon name (ReelGold -> FishingCoach)
#---------------------------------------------------------------------
function Move-OldAddon($target) {
    # 1. Remove the old addon folder, but only if it really is the old addon.
    $old = Join-Path $target.AddOnsDir $OldAddonName
    if (Test-Path (Join-Path $old "$OldAddonName.toc")) {
        Remove-Item -LiteralPath $old -Recurse -Force
        Write-Ok "Removed the old $OldAddonName folder ($DisplayName replaces it)."
    }
    # 2. Copy saved settings and fishing history to the new name, once.
    $wtf = Join-Path $target.GameDir 'WTF\Account'
    if (-not (Test-Path $wtf)) { return }
    $moved = 0
    Get-ChildItem $wtf -Recurse -File -Filter "$OldAddonName.lua" -ErrorAction SilentlyContinue |
        Where-Object { $_.Directory.Name -eq 'SavedVariables' } |
        ForEach-Object {
            $dest = Join-Path $_.DirectoryName "$AddonName.lua"
            if (-not (Test-Path $dest)) {
                $text = [System.IO.File]::ReadAllText($_.FullName)
                $text = $text -replace "\b${OldAddonName}CharDB\b", "${AddonName}CharDB" -replace "\b${OldAddonName}DB\b", "${AddonName}DB"
                [System.IO.File]::WriteAllText($dest, $text)
                $moved++
            }
        }
    if ($moved -gt 0) { Write-Ok "Kept your settings and fishing history ($moved saved file(s) carried over from $OldAddonName)." }
}

function Confirm-Step([string]$question) {
    if ($Yes) { return $true }
    $answer = Read-Host "$question [Y/n]"
    return ($answer -eq '' -or $answer -match '^(y|yes)$')
}

#---------------------------------------------------------------------
# Main
#---------------------------------------------------------------------
Write-Host ''
Write-Host "  Fishing " -NoNewline -ForegroundColor Cyan
Write-Host "Coach" -NoNewline -ForegroundColor Yellow
Write-Host " installer for World of Warcraft: Forever"

$source = Get-AddonSource
$newVersion = Get-TocVersion (Join-Path $source.Root "$AddonName.toc")
Write-Note "Addon version in this package: $newVersion"

if ($Path) {
    $targets = @(Resolve-ManualTarget $Path)
} else {
    Write-Title 'Looking for World of Warcraft: Forever...'
    $roots = @($SearchRoot | ForEach-Object { Get-WowRootFromPath $_ })
    if (-not $NoDefaultSearch) {
        $roots += @(Get-RegistryRoots) + @(Get-BattleNetRoots) + @(Get-CommonRoots)
    }
    $targets = Find-ForeverFolders $roots
    if ($targets.Count -eq 0 -and -not $NoDefaultSearch) {
        if ($DeepScan -or (-not $Yes -and -not $ListOnly -and (Confirm-Step 'Not found in the usual places. Scan all fixed drives (can take a minute)?'))) {
            $roots += @(Get-DeepScanRoots)
            $targets = Find-ForeverFolders $roots
        }
    }
    if ($targets.Count -eq 0) {
        $other = Get-OtherFlavors $roots
        if ($other.Count -gt 0) {
            Write-Warn2 'World of Warcraft was found, but without a _forever_ folder:'
            $other | ForEach-Object { Write-Note $_ }
            Write-Note 'Install and start WoW: Forever once from the Battle.net app, then run this again.'
        } else {
            Write-Warn2 'No WoW: Forever folder found.'
        }
        if ($ListOnly -or $Yes) { exit 1 }
        $manual = Read-Host 'Paste your World of Warcraft folder (or press Enter to quit)'
        if (-not $manual) { exit 1 }
        $targets = @(Resolve-ManualTarget $manual)
    }
}

# Live client first, then beta / PTR.
$order = @{ '_forever_' = 0; '_forever_beta_' = 1; '_forever_ptr_' = 2 }
$targets = @($targets | Sort-Object { if ($_.Flavor -and $order.ContainsKey($_.Flavor)) { $order[$_.Flavor] } else { 9 } }, GameDir)

Write-Title 'Found:'
for ($i = 0; $i -lt $targets.Count; $i++) {
    $t = $targets[$i]
    $state = if ($t.Installed) { "Fishing Coach $($t.Installed) installed" } else { 'Fishing Coach not installed' }
    Write-Host ("  [{0}] {1,-22} {2}" -f ($i + 1), $t.Name, $t.AddOnsDir)
    Write-Note ("      $state")
}
if ($ListOnly) { exit 0 }

$choice = $targets[0]
if ($targets.Count -gt 1 -and -not $Yes) {
    $raw = Read-Host "Choose a folder [1-$($targets.Count), Enter = 1, M = type a path]"
    if ($raw -match '^[Mm]$') {
        $choice = Resolve-ManualTarget (Read-Host 'Folder')
    } elseif ($raw) {
        $n = 0
        if (-not [int]::TryParse($raw, [ref]$n) -or $n -lt 1 -or $n -gt $targets.Count) { throw "Invalid choice: $raw" }
        $choice = $targets[$n - 1]
    }
}

Write-Host ''
if ($Uninstall) {
    if (Confirm-Step "Remove Fishing Coach from $($choice.AddOnsDir)?") { Uninstall-Addon $choice } else { Write-Note 'Nothing changed.' }
    exit 0
}

$verb = if ($choice.Installed) { "Update Fishing Coach $($choice.Installed) -> $newVersion in" } else { "Install Fishing Coach $newVersion into" }
if (-not (Confirm-Step "$verb $($choice.AddOnsDir)?")) { Write-Note 'Nothing changed.'; exit 0 }
Install-Addon $choice $source
Move-OldAddon $choice

Write-Title 'Next steps'
$running = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^Wow' }
if ($running) {
    Write-Note 'WoW is running: type /reload in game (a new addon may need a full restart).'
} else {
    Write-Note 'Start WoW: Forever. On the character screen, open AddOns and make sure Fishing Coach is enabled.'
}
Write-Note 'In game, type /fcoach to open Fishing Coach.'
exit 0

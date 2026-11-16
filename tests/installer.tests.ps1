# Tests for tools\installer\install.ps1 using fake WoW folders in a temp directory.
# Run:  powershell -NoProfile -ExecutionPolicy Bypass -File tests\installer.tests.ps1
#       (or: npm run test:installer)
param([string]$Shell = 'powershell.exe')

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$installer = Join-Path $repo 'tools\installer\install.ps1'
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("ReelGoldInstallerTest_" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmp | Out-Null

$script:passed = 0; $script:failed = 0
function Check($cond, $msg) { if (-not $cond) { throw $msg } }
function Test($name, [scriptblock]$body) {
    try { & $body; $script:passed++; Write-Host "  PASS  $name" -ForegroundColor Green }
    catch { $script:failed++; Write-Host "  FAIL  $name`n        $($_.Exception.Message)" -ForegroundColor Red }
}
function Run([string]$script, [string[]]$installerArgs) {
    # Errors printed by the installer are expected in some tests; don't let
    # Windows PowerShell 5.1 turn its stderr into an exception here.
    $ErrorActionPreference = 'Continue'
    $out = & $Shell -NoProfile -ExecutionPolicy Bypass -File $script @installerArgs 2>&1 | Out-String
    return @{ Code = $LASTEXITCODE; Out = $out }
}
function NewWow([string]$name, [string[]]$flavors) {
    $root = Join-Path $tmp $name
    foreach ($f in $flavors) { New-Item -ItemType Directory -Path (Join-Path $root $f) -Force | Out-Null }
    return $root
}

Write-Host "Installer tests ($Shell)`n"
$wow = NewWow 'World of Warcraft' @('_forever_', '_forever_beta_', '_retail_')
New-Item -ItemType Directory -Path (Join-Path $wow '_forever_\WTF\Account\TEST\SavedVariables') -Force | Out-Null
Set-Content (Join-Path $wow '_forever_\WTF\Account\TEST\SavedVariables\ReelGold.lua') 'ReelGoldDB = {}'
$addon = Join-Path $wow '_forever_\Interface\AddOns\ReelGold'
$common = @('-NoDefaultSearch', '-SearchRoot', $wow)

Test 'finds _forever_ and _forever_beta_, live first, ignores _retail_' {
    $r = Run $installer ($common + '-ListOnly')
    Check ($r.Code -eq 0) "exit code $($r.Code)`n$($r.Out)"
    $live = $r.Out.IndexOf('[1] WoW: Forever ')
    $beta = $r.Out.IndexOf('[2] WoW: Forever (beta)')
    Check ($live -ge 0 -and $beta -gt $live) "order wrong:`n$($r.Out)"
    Check ($r.Out -notmatch '_retail_') 'retail listed'
}

Test 'installs into _forever_\Interface\AddOns\ReelGold (creates AddOns)' {
    $r = Run $installer ($common + '-Yes')
    Check ($r.Code -eq 0) "exit code $($r.Code)`n$($r.Out)"
    Check (Test-Path (Join-Path $addon 'ReelGold.toc')) 'toc missing'
    Check (Test-Path (Join-Path $addon 'Core\Tracker.lua')) 'Core missing'
    Check (Test-Path (Join-Path $addon 'UI\MainFrame.lua')) 'UI missing'
    Check (-not (Test-Path (Join-Path $addon 'tests'))) 'tests copied'
    Check (-not (Test-Path (Join-Path $addon 'tools'))) 'tools copied'
    $count = (Get-ChildItem $addon -Recurse -File).Count
    Check ($count -eq 16) "expected 16 files, got $count"
    Check ($r.Out -match 'Installed ReelGold dev') "message:`n$($r.Out)"
}

Test 'update replaces old files and removes stale ones, keeps WTF data' {
    Set-Content (Join-Path $addon 'Old.lua') '-- stale'
    Set-Content (Join-Path $addon 'Core\Tracker.lua') '-- modified'
    $r = Run $installer ($common + '-Yes')
    Check ($r.Code -eq 0) "exit code $($r.Code)"
    Check ($r.Out -match 'ReelGold dev installed') 'did not detect existing install'
    Check (-not (Test-Path (Join-Path $addon 'Old.lua'))) 'stale file kept'
    Check ((Get-Content (Join-Path $addon 'Core\Tracker.lua') -Raw) -match 'RecordCatch') 'file not replaced'
    Check (Test-Path (Join-Path $wow '_forever_\WTF\Account\TEST\SavedVariables\ReelGold.lua')) 'saved variables touched'
}

Test 'refuses to overwrite a ReelGold folder that is not ReelGold' {
    $w2 = NewWow 'WoW2' @('_forever_')
    $fake = Join-Path $w2 '_forever_\Interface\AddOns\ReelGold'
    New-Item -ItemType Directory -Path $fake -Force | Out-Null
    Set-Content (Join-Path $fake 'keep.txt') 'user file'
    $r = Run $installer @('-NoDefaultSearch', '-SearchRoot', $w2, '-Yes')
    Check ($r.Code -ne 0) 'should fail'
    Check (Test-Path (Join-Path $fake 'keep.txt')) 'user file deleted'
}

Test '-Path accepts the WoW folder, the _forever_ folder and the AddOns folder' {
    foreach ($p in @($wow, (Join-Path $wow '_forever_'), (Join-Path $wow '_forever_\Interface\AddOns'))) {
        $r = Run $installer @('-Path', $p, '-Yes')
        Check ($r.Code -eq 0) "failed for $p`n$($r.Out)"
        Check ($r.Out -match [regex]::Escape($addon)) "wrong target for $p`n$($r.Out)"
    }
}

Test 'WoW without Forever gives a clear message and exit code 1' {
    $w3 = NewWow 'RetailOnly' @('_retail_', '_classic_era_')
    $r = Run $installer @('-NoDefaultSearch', '-SearchRoot', $w3, '-Yes')
    Check ($r.Code -eq 1) "exit code $($r.Code)"
    Check ($r.Out -match 'without a _forever_ folder') "message:`n$($r.Out)"
    Check ($r.Out -match '_classic_era_') 'other flavors not listed'
}

Test 'a registry-style path (..._forever_\Wow.exe) resolves to the WoW folder' {
    New-Item -ItemType File -Path (Join-Path $wow '_forever_\WowForever.exe') -Force | Out-Null
    $r = Run $installer @('-NoDefaultSearch', '-SearchRoot', (Join-Path $wow '_forever_\WowForever.exe'), '-ListOnly')
    Check ($r.Code -eq 0 -and $r.Out -match [regex]::Escape((Join-Path $wow '_forever_\Interface\AddOns'))) $r.Out
}

Test 'uninstall removes the addon and keeps WTF data' {
    $r = Run $installer ($common + '-Yes', '-Uninstall')
    Check ($r.Code -eq 0) "exit code $($r.Code)"
    Check (-not (Test-Path $addon)) 'addon still there'
    Check (Test-Path (Join-Path $wow '_forever_\WTF\Account\TEST\SavedVariables\ReelGold.lua')) 'saved variables removed'
}

Test 'release bundle (installer zip) installs the packaged version' {
    $bundle = Join-Path $tmp 'bundle'
    & python (Join-Path $repo 'tools\release.py') package --version 9.9.9 | Out-Null
    Expand-Archive (Join-Path $repo 'dist\ReelGold-9.9.9-windows-installer.zip') $bundle
    Remove-Item (Join-Path $repo 'dist\ReelGold-9.9.9*.zip')
    Check (Test-Path (Join-Path $bundle 'Install-ReelGold.cmd')) 'launcher missing in bundle'
    $r = Run (Join-Path $bundle 'install.ps1') ($common + '-Yes')
    Check ($r.Code -eq 0) "exit code $($r.Code)`n$($r.Out)"
    Check ((Get-Content (Join-Path $addon 'ReelGold.toc') -Raw) -match '## Version: 9\.9\.9') 'version not stamped'
}

Remove-Item -LiteralPath $tmp -Recurse -Force
Write-Host "`n$script:passed passed, $script:failed failed"
if ($script:failed -gt 0) { exit 1 }

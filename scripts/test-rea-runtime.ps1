$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'rea-runtime.ps1')
$repository = Split-Path $PSScriptRoot -Parent
$testRoot = Join-Path $repository ('.tools/runtime-tests-' + [guid]::NewGuid().ToString('N'))
$script:RuntimeTestRoot = $testRoot
$script:RuntimeInstallCount = 0
$script:RuntimeProbeCount = 0
$script:RuntimeFailInstall = $false
$script:RuntimeFailProbe = $false
$realNode = Get-ReaRuntimeNode

function Assert($Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    Write-Host "PASS: $Message"
}
function Assert-Fails([scriptblock]$Action, [string]$Pattern) {
    $failure = $null
    try { & $Action } catch { $failure = $_ }
    Assert ($null -ne $failure -and "$failure" -match $Pattern) "errore atteso $Pattern"
}
function Get-ReaRuntimeRoot { return $script:RuntimeTestRoot }
function Invoke-ReaRuntimeInstall([string]$Directory, [string]$Cache) {
    $script:RuntimeInstallCount++
    Assert ($Cache -eq (Join-Path $script:RuntimeTestRoot '.tools/npm-cache')) 'npm usa la cache del repository'
    if ($script:RuntimeFailInstall) { throw 'fixture-install-failed' }
    $package = Join-Path $Directory 'node_modules/rea-agents'
    New-Item -ItemType Directory -Path (Join-Path $package 'scripts') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $package 'package.json') -Value '{"version":"6.5.0"}'
    Set-Content -LiteralPath (Join-Path $package 'scripts/rea.mjs') -Value 'import fs from "node:fs"; fs.writeFileSync(process.argv[2], JSON.stringify(process.argv.slice(3)));'
}
function Test-ReaRuntime([string]$Directory, [string]$Version, [string]$Node) {
    $script:RuntimeProbeCount++
    if ($script:RuntimeFailProbe) { throw 'fixture-probe-failed' }
    $entry = Join-Path $Directory 'node_modules/rea-agents/scripts/rea.mjs'
    if (-not (Test-Path -LiteralPath $entry)) { throw 'fixture-runtime-incomplete' }
}

try {
    foreach ($version in @('v22.19.0', 'v24.11.0', 'v26.0.0', 'v27.0.0')) { Assert-ReaNodeVersion $version }
    foreach ($version in @('v22.18.9', 'v23.9.0', 'v24.10.9', 'v25.0.0', 'v24.11.0-beta')) { Assert-Fails { Assert-ReaNodeVersion $version } 'Node.js' }
    Assert-Fails { Get-ReaLaunchCommand '../escape' } 'Versione REA'
    Assert-Fails { Get-ReaLaunchCommand '6.5.0' } 'assente o incompleto'
    Assert (-not (Test-Path -LiteralPath $testRoot)) 'resolver assente non scrive e non scarica'
    $configuration = Join-Path $testRoot 'config/rea-runtime'
    New-Item -ItemType Directory -Path $configuration -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repository 'config/rea-runtime/package.json'), (Join-Path $repository 'config/rea-runtime/package-lock.json') -Destination $configuration
    Assert-Fails { Install-ReaRuntime '9.9.9' } 'Lockfile runtime'
    $script:RuntimeFailInstall = $true
    Assert-Fails { Install-ReaRuntime '6.5.0' } 'fixture-install-failed'
    $destination = Get-ReaRuntimeDirectory '6.5.0'
    Assert (-not (Test-Path -LiteralPath $destination)) 'installazione fallita non pubblica runtime'
    Assert (@(Get-ChildItem -LiteralPath (Split-Path $destination -Parent) -Force).Count -eq 0) 'installazione fallita elimina solo staging proprio'
    $script:RuntimeFailInstall = $false
    $script:RuntimeFailProbe = $true
    Assert-Fails { Install-ReaRuntime '6.5.0' } 'fixture-probe-failed'
    Assert (-not (Test-Path -LiteralPath $destination)) 'handshake fallito non pubblica runtime'
    $script:RuntimeFailProbe = $false
    Install-ReaRuntime '6.5.0'
    $command = Get-ReaLaunchCommand '6.5.0'
    Assert ($command.Executable -eq $realNode -and $command.Prefix[0] -eq (Join-Path $destination 'node_modules/rea-agents/scripts/rea.mjs')) 'launcher Node assoluto seleziona entry locale'
    $before = $script:RuntimeInstallCount
    Install-ReaRuntime '6.5.0'
    Assert ($script:RuntimeInstallCount -eq $before) 'ripetizione verifica runtime senza installare'
    $argumentPath = Join-Path $testRoot 'observed-arguments.json'
    Invoke-ReaCommand '6.5.0' @($argumentPath, 'one two', 'a&b', '"quoted"')
    $observed = Get-Content -LiteralPath $argumentPath -Raw | ConvertFrom-Json
    Assert (($observed -join '|') -eq 'one two|a&b|"quoted"') 'CLI reale conserva spazi e metacaratteri senza cmd'
    Set-Content -LiteralPath (Join-Path $destination 'node_modules/rea-agents/package.json') -Value '{"version":"0.0.0"}'
    Assert-Fails { Get-ReaLaunchCommand '6.5.0' } 'Versione runtime'
    Install-ReaRuntime '6.5.0'
    Assert ($script:RuntimeInstallCount -eq $before + 1) 'runtime danneggiato viene reinstallato'
    Assert (@(Get-ChildItem -LiteralPath (Split-Path $destination -Parent) -Directory -Filter '*.broken-*').Count -eq 1) 'runtime precedente conservato per diagnosi'
    Write-Host 'Tutti i test runtime sono passati. Nessun download o modifica alla configurazione utente.'
} finally {
    $owned = [IO.Path]::GetFullPath($testRoot)
    if ((Split-Path $owned -Parent) -ne [IO.Path]::GetFullPath((Join-Path $repository '.tools'))) { throw 'Test runtime fuori dal repository.' }
    if (Test-Path -LiteralPath $owned) { Remove-Item -LiteralPath $owned -Recurse -Force }
}

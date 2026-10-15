$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'install-tools.ps1') -Tool Jadx

$root = Join-Path (Split-Path $PSScriptRoot -Parent) ('.tools\installer-tests-' + [guid]::NewGuid().ToString('N'))
$script:Downloads = 0
$script:WingetCalls = @()
$script:Answer = 's'
$script:Source = ''
function Read-Host { param($Prompt); $script:Answer }
function Invoke-WebRequest { param($Uri,$OutFile,[switch]$UseBasicParsing); $script:Downloads++; Copy-Item -LiteralPath $script:Source -Destination $OutFile }
function winget.exe { $script:WingetCalls += ,@($args); $global:LASTEXITCODE = 0 }
function Check([bool]$Condition, [string]$Name) { if (-not $Condition) { throw "FAIL: $Name" }; Write-Host "PASS: $Name" }
function Must-Fail([scriptblock]$Action, [string]$Name) { $failed=$false; try { & $Action | Out-Null } catch { $failed=$true }; Check $failed $Name }

New-Item -ItemType Directory -Path $root -Force | Out-Null
try {
    $catalog = Get-OptionalToolCatalog
    Check ($catalog.Count -eq 28 -and $catalog.Jadx.Version -eq '0.7.1' -and $catalog.Java.Package -eq 'EclipseAdoptium.Temurin.21.JDK') 'Catalogo completo, JDK separato e motore JADX headless richiesto da REA'
    foreach ($name in $catalog.Keys) { Invoke-OptionalToolInstaller $name Instructions (Join-Path $root 'unused') | Out-Null }
    Check ($script:Downloads -eq 0 -and $script:WingetCalls.Count -eq 0 -and -not (Test-Path (Join-Path $root 'unused'))) 'Istruzioni senza download, installazioni o cartelle'
    $script:Answer='n'
    Invoke-OptionalToolInstaller Jadx Install (Join-Path $root 'declined') | Out-Null
    Check ($script:Downloads -eq 0 -and -not (Test-Path (Join-Path $root 'declined'))) 'Rifiuto senza effetti'
    $script:Answer='s'
    Invoke-OptionalToolInstaller Node | Out-Null
    Check ($script:WingetCalls.Count -eq 1 -and ($script:WingetCalls[0] -join ' ') -eq 'install --id OpenJS.NodeJS.LTS --exact --source winget') 'Winget ID esatto senza accettazione automatica accordi'
    $script:Source = Join-Path $root 'fixture.jar'
    Set-Content -LiteralPath $script:Source -Value 'jar fixture'
    $entry = $catalog.Apktool.Clone()
    $entry.Hash = (Get-FileHash -LiteralPath $script:Source -Algorithm SHA256).Hash
    $installed = Install-PortableTool $entry (Join-Path $root 'tools')
    Check ((Test-Path (Join-Path $installed 'apktool.jar')) -and (Get-Content (Join-Path $installed 'apktool.cmd') -Raw) -match 'java -jar "%~dp0apktool.jar" %\*') 'JAR e launcher reale con argomenti preservati'
    Check ((Get-Content (Join-Path $installed 'apktool.cmd') -Raw) -match '"%JAVA_HOME%\\bin\\java.exe" -jar "%~dp0apktool.jar" %\*') 'Launcher APKtool rispetta il JDK del profilo'
    $jadx = $catalog.Jadx.Clone()
    $jadx.Hash = $entry.Hash
    $jadxInstalled = Install-PortableTool $jadx (Join-Path $root 'tools')
    Check ((Test-Path (Join-Path $jadxInstalled 'jadx-headless-mcp-0.7.1-all.jar')) -and -not (Test-Path (Join-Path $jadxInstalled 'apktool.cmd'))) 'JADX conserva JAR headless e non genera launcher APKtool'
    $before = $script:Downloads
    $second = Install-PortableTool $entry ((Join-Path $root 'tools') + '\')
    Check ($second -eq $installed -and $script:Downloads -eq $before) 'Riutilizzo verificato e separatore finale'
    Add-Content -LiteralPath (Join-Path $installed 'apktool.jar') -Value 'modificato'
    Must-Fail { Install-PortableTool $entry (Join-Path $root 'tools') } 'File modificato rifiutato senza sovrascrittura'
    $entry.Directory = 'bad-checksum'
    $entry.Hash = '0' * 64
    Must-Fail { Install-PortableTool $entry (Join-Path $root 'tools') } 'SHA errato rifiutato'
    Check (-not (Test-Path (Join-Path $root 'tools\bad-checksum')) -and @(Get-ChildItem (Join-Path $root 'tools') -Directory -Filter '.staging-*').Count -eq 0) 'Download fallito ripulito e destinazione assente'
    $fixture = Join-Path $root 'archive-source'
    New-Item -ItemType Directory -Path (Join-Path $fixture 'wabt\bin') -Force | Out-Null
    Set-Content (Join-Path $fixture 'wabt\bin\wasm2wat.exe') 'fixture'
    Set-Content (Join-Path $fixture 'wabt\bin\wasm-objdump.exe') 'fixture'
    $script:Source = Join-Path $root 'fixture.tar.gz'
    & tar.exe -czf $script:Source -C $fixture wabt
    if ($LASTEXITCODE -ne 0) { throw 'Creazione archivio fixture fallita.' }
    $entry = $catalog.Wabt.Clone()
    $entry.Hash = (Get-FileHash $script:Source -Algorithm SHA256).Hash
    $installed = Install-PortableTool $entry (Join-Path $root 'tools')
    Check (Test-Path (Join-Path $installed 'bin\wasm2wat.exe')) 'Estrazione archivio WABT e rilevamento cartella'
    $entry.Directory = 'incomplete'
    New-Item -ItemType Directory (Join-Path $root 'tools\incomplete') | Out-Null
    Set-Content (Join-Path $root 'tools\incomplete\keep.txt') 'keep'
    Must-Fail { Install-PortableTool $entry (Join-Path $root 'tools') } 'Destinazione incompleta preservata'
    Check ((Get-Content (Join-Path $root 'tools\incomplete\keep.txt')) -eq 'keep') 'Contenuto utente conservato'
    Must-Fail { Install-PortableTool $entry ([IO.Path]::GetPathRoot($root)) } 'Radice volume rifiutata'
    Write-Host 'Tutti i test installer completati senza download o installazioni reali.'
} finally {
    $workspace = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent)).TrimEnd('\')
    if (-not ([IO.Path]::GetFullPath($root)).StartsWith($workspace + '\.tools\installer-tests-', [StringComparison]::OrdinalIgnoreCase)) { throw 'Percorso test non valido.' }
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}

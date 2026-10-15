[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repository = Split-Path $PSScriptRoot -Parent
$destination = Join-Path $repository ('.tools/clean clone ' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $destination -Force | Out-Null
foreach ($name in @('scripts', 'config', 'docs', 'README.md', 'setup.bat', 'rea-profile.bat')) {
    Copy-Item -LiteralPath (Join-Path $repository $name) -Destination $destination -Recurse
}
Write-Host "Verifica senza runtime, profili o cache preesistenti: $destination"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $destination 'scripts/setup.ps1') -Action Runtime
if ($LASTEXITCODE -ne 0) { throw 'Bootstrap da copia pulita fallito.' }
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $destination 'scripts/setup.ps1') -Action Create -Profile smoke -Template builtin
if ($LASTEXITCODE -ne 0) { throw 'Creazione profilo da copia pulita fallita.' }
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $destination 'scripts/setup.ps1') -Action Mcp -Profile smoke
if ($LASTEXITCODE -ne 0) { throw 'Export da copia pulita fallito.' }
& node.exe (Join-Path $destination 'scripts/test-mcp.mjs') --snapshot (Join-Path $destination '.rea/mcp/smoke.json') --output (Join-Path $destination '.tools/mcp-evidence.json')
if ($LASTEXITCODE -ne 0) { throw 'Handshake da copia pulita fallito.' }
Write-Host "PASS: setup e MCP da copia pulita con spazi nel percorso. Evidenze: $destination"

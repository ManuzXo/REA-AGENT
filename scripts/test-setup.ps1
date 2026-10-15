[CmdletBinding()]
param([ValidateSet('powershell.exe', 'pwsh.exe')][string]$PowerShell = 'powershell.exe')
$ErrorActionPreference = 'Stop'
foreach ($test in @('test-rea-runtime.ps1', 'test-setup-ghidra.ps1', 'test-profiles.ps1', 'test-existing-tools.ps1', 'test-install-tools.ps1')) {
    & $PowerShell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot $test)
    if ($LASTEXITCODE -ne 0) { throw "Verifica fallita: $test" }
}
& node.exe (Join-Path $PSScriptRoot 'check-documentation.mjs')
if ($LASTEXITCODE -ne 0) { throw 'Verifica documentazione fallita.' }

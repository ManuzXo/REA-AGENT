$ErrorActionPreference = 'Stop'

function Get-ReaRuntimeRoot { return Split-Path $PSScriptRoot -Parent }

function Get-ReaRuntimeNode {
    $node = Get-Command node.exe -ErrorAction SilentlyContinue
    if (-not $node) { throw 'Installa Node.js 22.19+, 24.11+ o >=26 con npm.' }
    $version = & $node.Source --version
    if ($LASTEXITCODE -ne 0) { throw 'Impossibile verificare Node.js.' }
    Assert-ReaNodeVersion $version
    return $node.Source
}

function Assert-ReaNodeVersion([string]$Version) {
    if ($Version -notmatch '^v(\d+)\.(\d+)\.(\d+)$') { throw 'Impossibile verificare Node.js.' }
    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    if (-not (($major -eq 22 -and $minor -ge 19) -or ($major -eq 24 -and $minor -ge 11) -or $major -ge 26)) { throw 'REA richiede Node.js 22.19+, 24.11+ o >=26.' }
}

function Get-ReaRuntimeDirectory([string]$Version) {
    if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Versione REA non valida.' }
    return Join-Path (Get-ReaRuntimeRoot) ".tools/rea-runtime/$Version"
}

function Get-ReaLaunchCommand([string]$Version) {
    $directory = Get-ReaRuntimeDirectory $Version
    $entry = Join-Path $directory 'node_modules/rea-agents/scripts/rea.mjs'
    $manifest = Join-Path $directory 'node_modules/rea-agents/package.json'
    if (-not (Test-Path -LiteralPath $entry -PathType Leaf) -or -not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
        throw "Runtime REA $Version assente o incompleto. Esegui setup.bat -Action Runtime."
    }
    $package = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
    if ($package.version -ne $Version) { throw "Versione runtime REA inattesa in $directory. Ripeti setup.bat -Action Runtime." }
    return [pscustomobject]@{ Executable = (Get-ReaRuntimeNode); Prefix = @($entry) }
}

function Test-ReaRuntime([string]$Directory, [string]$Version, [string]$Node) {
    $entry = Join-Path $Directory 'node_modules/rea-agents/scripts/rea.mjs'
    $observed = & $Node $entry --version
    if ($LASTEXITCODE -ne 0 -or (($observed -join "`n").Trim() -notmatch ('(?:^|\s)' + [regex]::Escape($Version) + '$'))) {
        throw "Runtime REA $Version non avviabile."
    }
    & $Node (Join-Path (Get-ReaRuntimeRoot) 'scripts/test-mcp.mjs') --entry $entry --node $Node
    if ($LASTEXITCODE -ne 0) { throw 'Verifica initialize/tools/list del runtime REA fallita.' }
}

function Invoke-ReaRuntimeInstall([string]$Directory, [string]$Cache) {
    $npm = Get-Command npm.cmd -ErrorAction SilentlyContinue
    if (-not $npm) { throw 'npm.cmd assente. Installa Node.js con npm.' }
    & $npm.Source ci --prefix $Directory --cache $Cache --no-audit --no-fund
    if ($LASTEXITCODE -ne 0) { throw "Installazione npm REA fallita con codice $LASTEXITCODE." }
}

function Install-ReaRuntime([string]$Version) {
    $directory = Get-ReaRuntimeDirectory $Version
    $node = Get-ReaRuntimeNode
    if (Test-Path -LiteralPath $directory) {
        try {
            $null = Get-ReaLaunchCommand $Version
            Test-ReaRuntime $directory $Version $node
            Write-Host "Runtime REA $Version verificato e riutilizzato."
            return
        } catch { Write-Host "Runtime locale da ripristinare. $($_.Exception.Message)" }
    }
    $source = Join-Path (Get-ReaRuntimeRoot) 'config/rea-runtime'
    $manifest = Get-Content -LiteralPath (Join-Path $source 'package.json') -Raw | ConvertFrom-Json
    if ($manifest.dependencies.'rea-agents' -ne $Version) { throw "Lockfile runtime non disponibile per REA $Version. Aggiorna config/rea-runtime insieme a config/rea.json." }
    $parent = Split-Path $directory -Parent
    $staging = Join-Path $parent ('.staging-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $staging -Force | Out-Null
    try {
        Copy-Item -LiteralPath (Join-Path $source 'package.json'), (Join-Path $source 'package-lock.json') -Destination $staging
        Invoke-ReaRuntimeInstall $staging (Join-Path (Get-ReaRuntimeRoot) '.tools/npm-cache')
        Test-ReaRuntime $staging $Version $node
        if (Test-Path -LiteralPath $directory) {
            $backup = $directory + '.broken-' + [guid]::NewGuid().ToString('N')
            [IO.Directory]::Move($directory, $backup)
            Write-Host "Runtime precedente conservato in $backup"
        }
        [IO.Directory]::Move($staging, $directory)
        Write-Host "Runtime REA $Version installato e verificato."
    } finally {
        $owned = [IO.Path]::GetFullPath($staging)
        if ((Split-Path $owned -Parent) -ne [IO.Path]::GetFullPath($parent)) { throw 'Staging runtime fuori dalla directory prevista.' }
        if (Test-Path -LiteralPath $owned) { Remove-Item -LiteralPath $owned -Recurse -Force }
    }
}

function Invoke-ReaCommand([string]$Version, [string[]]$Arguments) {
    $command = Get-ReaLaunchCommand $Version
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $command.Executable
    $allArguments = @($command.Prefix) + $Arguments
    $start.Arguments = (($allArguments | ForEach-Object {
        $escaped = [regex]::Replace($_, '(\\*)"', '$1$1\"')
        $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
        '"' + $escaped + '"'
    }) -join ' ')
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $process = [Diagnostics.Process]::Start($start)
    try {
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) { throw "REA terminato con codice $($process.ExitCode)." }
    } finally { $process.Dispose() }
}

[CmdletBinding()]
param(
    [ValidateSet('Prompt', 'Rea', 'Install', 'Existing')][string]$Mode = 'Prompt',
    [string]$GhidraPath,
    [string]$JavaPath,
    [string]$ToolsDirectory,
    [switch]$SkipMcp
)

$ErrorActionPreference = 'Stop'
$script:SetupRoot = Split-Path $PSScriptRoot -Parent
$script:ReaVersion = '6.5.0'

function Get-ToolManifest {
    @(
        [pscustomobject]@{
            Name = 'Ghidra'; Version = '12.1.4'
            URL = 'https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.1.4_build/ghidra_12.1.4_PUBLIC_20260921.zip'
            SHA256 = 'ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db'
            InstallDir = 'ghidra_12.1.4_PUBLIC'
            RequiredFiles = @('ghidraRun.bat', 'support/analyzeHeadless.bat', 'Ghidra/application.properties')
        }
        [pscustomobject]@{
            Name = 'Temurin JDK'; Version = '21.0.12.1+1'
            URL = 'https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/OpenJDK21U-jdk_x64_windows_hotspot_21.0.12.1_1.zip'
            SHA256 = 'f9d6e191ab098c0d416e7d588a24420a8621cd2f4720dab2459b8b7b2d2d8b4e'
            InstallDir = 'jdk-21.0.12.1+1'
            RequiredFiles = @('bin/java.exe', 'bin/javac.exe', 'release')
        }
    )
}

function Get-ExtendedPath([string]$Path) {
    $fullPath = [IO.Path]::GetFullPath($Path)
    if ($fullPath.StartsWith('\\?\')) { return $fullPath }
    if ($fullPath.StartsWith('\\')) { return '\\?\UNC\' + $fullPath.Substring(2) }
    return '\\?\' + $fullPath
}

function Test-ToolFiles($Tool, [string]$Path) {
    foreach ($file in $Tool.RequiredFiles) {
        if (-not (Test-Path -LiteralPath (Get-ExtendedPath ([IO.Path]::Combine($Path, $file))) -PathType Leaf)) { return $false }
    }
    return $true
}

function Assert-ToolVersion($Tool, [string]$Path) {
    if (-not (Test-ToolFiles $Tool $Path)) { throw "Installazione $($Tool.Name) incompleta: $Path" }
    if ($Tool.Name -eq 'Ghidra') {
        $properties = Get-Content -LiteralPath (Get-ExtendedPath ([IO.Path]::Combine($Path, 'Ghidra/application.properties'))) -Raw
        if ($properties -notmatch '(?m)^application\.version=12\.1\.\d+\s*$') {
            throw 'Occorre Ghidra 12.1.x. Verifica poi la compatibilita effettiva con REA doctor.'
        }
    } else {
        $release = Get-Content -LiteralPath (Get-ExtendedPath ([IO.Path]::Combine($Path, 'release'))) -Raw
        if ($release -notmatch '(?m)^JAVA_VERSION="(\d+)(?:\.|\")' -or [int]$Matches[1] -lt 21) { throw 'Occorre un JDK Java 21 o successivo.' }
    }
}

function Install-ManagedTool($Tool, [string]$Root) {
    $Root = [IO.Path]::GetFullPath($Root)
    if ($Root.TrimEnd('\', '/') -eq [IO.Path]::GetPathRoot($Root).TrimEnd('\', '/')) { throw 'Scegli una sottocartella per gli strumenti, non la radice del volume.' }
    $Root = $Root.TrimEnd('\', '/')
    $destination = Join-Path $Root $Tool.InstallDir
    if (Test-Path -LiteralPath $destination) {
        Assert-ToolVersion $Tool $destination
        Write-Host "Riutilizzo $destination"
        return $destination
    }
    $staging = Join-Path $Root ('.staging-' + [guid]::NewGuid().ToString('N').Substring(0, 12))
    New-Item -ItemType Directory -Path (Get-ExtendedPath $staging) -Force | Out-Null
    try {
        $archive = Join-Path $staging 'download.zip'
        Invoke-WebRequest -Uri $Tool.URL -OutFile (Get-ExtendedPath $archive) -UseBasicParsing
        if ((Get-FileHash -LiteralPath (Get-ExtendedPath $archive) -Algorithm SHA256).Hash -ne $Tool.SHA256) {
            throw "SHA-256 non valido per $($Tool.Name). Nessun archivio estratto."
        }
        $expanded = Join-Path $staging 'expanded'
        New-Item -ItemType Directory -Path (Get-ExtendedPath $expanded) | Out-Null
        & tar.exe --no-same-owner --no-same-permissions -xf $archive -C $expanded
        if ($LASTEXITCODE -ne 0) { throw "Estrazione $($Tool.Name) fallita (codice $LASTEXITCODE)." }
        $candidates = @(Get-ChildItem -LiteralPath (Get-ExtendedPath $expanded) -Directory | Where-Object { Test-ToolFiles $Tool $_.FullName })
        if ($candidates.Count -ne 1) { throw "Struttura archivio inattesa per $($Tool.Name)." }
        Assert-ToolVersion $Tool $candidates[0].FullName
        $candidatePath = [IO.Path]::GetFullPath((Join-Path $expanded $candidates[0].Name))
        if (-not $candidatePath.StartsWith([IO.Path]::GetFullPath($staging).TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Installazione fuori dalla cartella staging.' }
        if (Test-Path -LiteralPath $destination) { throw "Destinazione creata durante il setup: $destination. Ripeti il setup per verificarla." }
        if ((Split-Path ([IO.Path]::GetFullPath($destination)) -Parent) -ne [IO.Path]::GetFullPath($Root)) { throw 'Destinazione fuori dalla cartella strumenti.' }
        [IO.Directory]::Move($candidatePath, $destination)
        return $destination
    } finally {
        $ownedPath = [IO.Path]::GetFullPath($staging)
        if ((Split-Path $ownedPath -Parent) -ne [IO.Path]::GetFullPath($Root)) { throw 'Percorso staging fuori dalla cartella strumenti.' }
        if (Test-Path -LiteralPath (Get-ExtendedPath $ownedPath)) { Remove-Item -LiteralPath (Get-ExtendedPath $ownedPath) -Recurse -Force }
    }
}

function Get-NpxCommand {
    if (-not (Get-Command node.exe -ErrorAction SilentlyContinue)) { throw 'Installa Node.js supportato con npm prima di procedere.' }
    $nodeVersion = & node.exe --version
    if ($LASTEXITCODE -ne 0 -or $nodeVersion -notmatch '^v(\d+)\.(\d+)\.(\d+)$') { throw 'Impossibile verificare la versione stabile di Node.js.' }
    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    if (-not (($major -eq 22 -and $minor -ge 19) -or ($major -eq 24 -and $minor -ge 11) -or $major -ge 26)) { throw 'REA richiede Node.js 22.19+, 24.11+ o >=26.' }
    $npx = Get-Command npx.cmd -ErrorAction SilentlyContinue
    if (-not $npx) { throw 'npx.cmd non disponibile nel PATH. Installa Node.js con npm.' }
    return $npx.Source
}

function Invoke-RepositorySetup {
    [CmdletBinding()]
    param(
        [ValidateSet('Prompt', 'Rea', 'Install', 'Existing')][string]$Mode = 'Prompt',
        [string]$GhidraPath, [string]$JavaPath, [string]$ToolsDirectory, [switch]$SkipMcp
    )
    if ($Mode -eq 'Prompt') {
        Write-Host '1. Configura solo REA e MCP'
        Write-Host '2. Scarica Ghidra e JDK Java 21 portabili e configura REA'
        Write-Host '3. Usa Ghidra e JDK Java 21+ gia installati'
        Write-Host '4. Annulla'
        switch (Read-Host 'Scelta [4]') {
            '1' { $Mode = 'Rea' }
            '2' { $Mode = 'Install' }
            '3' { $Mode = 'Existing' }
            default { Write-Host 'Setup annullato.'; return }
        }
    }
    $npx = Get-NpxCommand
    if ($Mode -eq 'Install' -and -not (Get-Command tar.exe -ErrorAction SilentlyContinue)) { throw 'tar.exe richiesto per estrarre archivi con percorsi lunghi. Usa Windows 10/11 aggiornato o la modalita Existing.' }
    if ($Mode -eq 'Rea') {
        & (Join-Path $PSScriptRoot 'setup-rea.ps1') -ReaVersion $script:ReaVersion
        return
    }
    $manifest = @(Get-ToolManifest)
    if (-not $ToolsDirectory) { $ToolsDirectory = Join-Path $script:SetupRoot '.tools' }
    $ToolsDirectory = [IO.Path]::GetFullPath($ToolsDirectory)
    if ($Mode -eq 'Existing') {
        if (-not $GhidraPath) { $GhidraPath = Read-Host 'Cartella Ghidra' }
        if (-not $JavaPath) { $JavaPath = Read-Host 'Cartella JDK Java 21+' }
        $GhidraPath = (Resolve-Path -LiteralPath $GhidraPath).Path
        $JavaPath = (Resolve-Path -LiteralPath $JavaPath).Path
        Assert-ToolVersion $manifest[0] $GhidraPath
        Assert-ToolVersion $manifest[1] $JavaPath
        Write-Host "Ghidra: $GhidraPath"
        Write-Host "JDK Java: $JavaPath"
    }
    Write-Host "REA npm: rea-agents@$script:ReaVersion"
    if ($Mode -eq 'Install') {
        foreach ($tool in $manifest) {
            Write-Host "$($tool.Name) $($tool.Version): $($tool.URL)"
            Write-Host "Destinazione: $(Join-Path $ToolsDirectory $tool.InstallDir)"
        }
    }
    Write-Host 'Il controllo provider puo scaricare REA tramite npm. Le variabili GHIDRA_INSTALL_DIR e JAVA_HOME saranno temporanee nel processo.'
    if (-not $SkipMcp) { Write-Host 'Il setup REA proporra la registrazione MCP in Codex utente, inclusi i percorsi verificati. Nessuna modifica globale a PATH o Java.' }
    if ((Read-Host 'Procedere? [s/N]') -notmatch '^(s|si|y|yes)$') { Write-Host 'Setup annullato.'; return }
    if ($Mode -eq 'Install') {
        $GhidraPath = Install-ManagedTool $manifest[0] $ToolsDirectory
        $JavaPath = Install-ManagedTool $manifest[1] $ToolsDirectory
    }
    $previousGhidra = $env:GHIDRA_INSTALL_DIR
    $previousJava = $env:JAVA_HOME
    try {
        $env:GHIDRA_INSTALL_DIR = $GhidraPath
        $env:JAVA_HOME = $JavaPath
        & $npx --yes "rea-agents@$script:ReaVersion" doctor --provider ghidra --json
        if ($LASTEXITCODE -ne 0) { throw "REA doctor ha rifiutato il provider Ghidra (codice $LASTEXITCODE). MCP non configurato." }
        if (-not $SkipMcp) { & (Join-Path $PSScriptRoot 'setup-rea.ps1') -ReaVersion $script:ReaVersion }
        if ($SkipMcp) { Write-Host 'Provider Ghidra verificato. Registrazione MCP saltata.' }
        else { Write-Host 'Provider Ghidra verificato. Riavvia Codex per controllare la registrazione MCP.' }
    } finally {
        $env:GHIDRA_INSTALL_DIR = $previousGhidra
        $env:JAVA_HOME = $previousJava
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try { Invoke-RepositorySetup @PSBoundParameters }
    catch { Write-Error $_ -ErrorAction Continue; exit 1 }
}

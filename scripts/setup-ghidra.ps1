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
$script:ReaVersion = (Get-Content -LiteralPath (Join-Path $script:SetupRoot 'config/rea.json') -Raw | ConvertFrom-Json).reaVersion
. (Join-Path $PSScriptRoot 'rea-profiles.ps1')

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
        Invoke-WebRequest -Uri $Tool.URL -OutFile $archive -UseBasicParsing
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
    Write-Host 'Il controllo provider prepara REA locale tramite npm. Le variabili GHIDRA_INSTALL_DIR e JAVA_HOME saranno temporanee nel processo.'
    if (-not $SkipMcp) { Write-Host 'Verra aggiornato il profilo ghidra e registrato rea-ghidra in Codex utente con i percorsi verificati. Nessuna modifica globale a PATH o Java.' }
    if ((Read-Host 'Procedere? [s/N]') -notmatch '^(s|si|y|yes)$') { Write-Host 'Setup annullato.'; return }
    if ($Mode -eq 'Install') {
        $GhidraPath = Install-ManagedTool $manifest[0] $ToolsDirectory
        $JavaPath = Install-ManagedTool $manifest[1] $ToolsDirectory
    }
    $profilePath = Get-ProfilePath ghidra
    if (Test-Path -LiteralPath $profilePath) { $profileData = Read-ReaProfile ghidra }
    else { $profileData = [pscustomobject]@{ schemaVersion = 1; reaVersion = $script:ReaVersion; template = 'native-ghidra'; description = $script:ReaConfig.templates.'native-ghidra'.description; environment = [pscustomobject]@{} } }
    $profileData.reaVersion = $script:ReaVersion
    $profileData.template = 'native-ghidra'
    foreach ($item in @{ REA_ANALYSIS_PROVIDER = 'ghidra'; GHIDRA_INSTALL_DIR = $GhidraPath; JAVA_HOME = $JavaPath }.GetEnumerator()) {
        $profileData.environment | Add-Member -MemberType NoteProperty -Name $item.Key -Value $item.Value -Force
    }
    Install-ReaRuntime $profileData.reaVersion | Out-Null
    Invoke-InReaProfile $profileData { Invoke-ReaCommand $profileData.reaVersion @('doctor', '--provider', 'ghidra', '--json') }
    Save-ReaProfile ghidra $profileData
    if (-not $SkipMcp) { Export-ReaMcp ghidra $profileData; Register-ReaMcp ghidra $profileData }
    if ($SkipMcp) { Write-Host 'Provider Ghidra verificato. Registrazione MCP saltata.' }
    else { Write-Host 'Provider Ghidra verificato. Riavvia Codex per controllare la registrazione MCP.' }
}

if ($MyInvocation.InvocationName -ne '.') {
    try { Invoke-RepositorySetup @PSBoundParameters }
    catch { Write-Error $_ -ErrorAction Continue; exit 1 }
}

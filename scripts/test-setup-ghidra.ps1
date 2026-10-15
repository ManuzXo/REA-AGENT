$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'setup-ghidra.ps1')
$testParent = Join-Path $script:SetupRoot '.tools'
$testRoot = Join-Path $testParent ('rea-setup-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$script:RepositoryRoot = $testRoot
$originalGhidra = $env:GHIDRA_INSTALL_DIR
$originalJava = $env:JAVA_HOME
$global:ReaSetupTest = @{ Fixtures = @(Get-ToolManifest) }
$global:ReaSetupTest.Downloads = 0
$global:ReaSetupTest.Calls = @()
$global:ReaSetupTest.Answers = New-Object 'System.Collections.Generic.Queue[string]'
$global:ReaSetupTest.Exit = 0

function Assert($Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    Write-Host "PASS: $Message"
}
function Assert-Fails([scriptblock]$Action, [string]$Pattern) {
    $failure = $null
    try { & $Action } catch { $failure = $_ }
    Assert ($null -ne $failure -and "$failure" -match $Pattern) "errore atteso $Pattern"
}
function Get-ToolManifest { return $global:ReaSetupTest.Fixtures }
function Install-ReaRuntime { param($Version); if ($Version -ne '6.5.0') { throw 'Versione runtime inattesa.' } }
function Export-ReaMcp { param($Name, $Profile); if ($Name -ne 'ghidra') { throw 'Profilo MCP inatteso.' } }
function Register-ReaMcp {
    param($Name, $Profile)
    $global:ReaSetupTest.Calls += [pscustomobject]@{ Arguments = 'register rea-ghidra'; Ghidra = $Profile.environment.GHIDRA_INSTALL_DIR; Java = $Profile.environment.JAVA_HOME }
}
function Read-Host { param($Prompt); if ($global:ReaSetupTest.Answers.Count -eq 0) { throw "Prompt inatteso: $Prompt" }; return $global:ReaSetupTest.Answers.Dequeue() }
function Invoke-ReaCommand {
    param($Version, $Arguments)
    $global:ReaSetupTest.Calls += [pscustomobject]@{ Arguments = ($Arguments -join ' '); Ghidra = $env:GHIDRA_INSTALL_DIR; Java = $env:JAVA_HOME }
    if ($global:ReaSetupTest.Exit -ne 0) { throw "REA terminato con codice $($global:ReaSetupTest.Exit)." }
}
function Invoke-WebRequest {
    param($Uri, $OutFile, [switch]$UseBasicParsing)
    $global:ReaSetupTest.Downloads++
    Copy-Item -LiteralPath $Uri -Destination $OutFile
}

try {
    Assert-Fails { Assert-ReaNodeVersion 'v23.0.0' } 'Node.js 22.19'
    foreach ($tool in $global:ReaSetupTest.Fixtures) {
        $fixtureRoot = Join-Path $testRoot ('fixture-' + $tool.InstallDir)
        $folder = Join-Path $fixtureRoot $tool.InstallDir
        foreach ($file in $tool.RequiredFiles) {
            $target = Join-Path $folder $file
            New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
            Set-Content -LiteralPath $target -Value 'fixture'
        }
        if ($tool.Name -eq 'Ghidra') { Set-Content -LiteralPath (Join-Path $folder 'Ghidra/application.properties') -Value 'application.version=12.1.4' }
        else { Set-Content -LiteralPath (Join-Path $folder 'release') -Value 'JAVA_VERSION="21.0.12"' }
        $zip = Join-Path $testRoot ($tool.InstallDir + '.zip')
        Compress-Archive -LiteralPath $folder -DestinationPath $zip
        $tool.URL = $zip
        $tool.SHA256 = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
    }
    $managed = Join-Path $testRoot 'managed tools'
    $global:ReaSetupTest.Answers.Enqueue('4')
    Invoke-RepositorySetup -ToolsDirectory $managed
    Assert ($global:ReaSetupTest.Downloads -eq 0 -and $global:ReaSetupTest.Calls.Count -eq 0 -and -not (Test-Path $managed)) 'annullamento menu senza effetti'
    $global:ReaSetupTest.Answers.Enqueue('')
    Invoke-RepositorySetup -Mode Install -ToolsDirectory $managed
    Assert ($global:ReaSetupTest.Downloads -eq 0 -and $global:ReaSetupTest.Calls.Count -eq 0 -and -not (Test-Path $managed)) 'rifiuto installazione senza rete o scritture'
    $env:GHIDRA_INSTALL_DIR = 'original-ghidra'
    $env:JAVA_HOME = 'original-java'
    $global:ReaSetupTest.Answers.Enqueue('s')
    Invoke-RepositorySetup -Mode Install -ToolsDirectory $managed
    $ghidra = Join-Path $managed $global:ReaSetupTest.Fixtures[0].InstallDir
    $java = Join-Path $managed $global:ReaSetupTest.Fixtures[1].InstallDir
    Assert ($global:ReaSetupTest.Downloads -eq 2 -and (Test-ToolFiles $global:ReaSetupTest.Fixtures[0] $ghidra) -and (Test-ToolFiles $global:ReaSetupTest.Fixtures[1] $java)) 'installazione da ZIP e hash validi, percorsi con spazi'
    Assert ($global:ReaSetupTest.Calls.Count -eq 2 -and $global:ReaSetupTest.Calls[0].Arguments -eq 'doctor --provider ghidra --json' -and $global:ReaSetupTest.Calls[1].Arguments -eq 'register rea-ghidra') 'doctor precede registrazione del profilo ghidra'
    $saved = Read-ReaProfile ghidra
    Assert ($saved.environment.GHIDRA_INSTALL_DIR -eq $ghidra -and $saved.environment.JAVA_HOME -eq $java -and $saved.environment.REA_ANALYSIS_PROVIDER -eq 'ghidra') 'profilo ghidra persistito con percorsi verificati'
    Assert ($global:ReaSetupTest.Calls[0].Ghidra -eq $ghidra -and $global:ReaSetupTest.Calls[1].Java -eq $java -and $env:GHIDRA_INSTALL_DIR -eq 'original-ghidra' -and $env:JAVA_HOME -eq 'original-java') 'percorsi propagati a REA e ambiente ripristinato'
    $global:ReaSetupTest.Answers.Enqueue('s')
    Invoke-RepositorySetup -Mode Install -ToolsDirectory ($managed + '\') -SkipMcp
    Assert ($global:ReaSetupTest.Downloads -eq 2 -and $global:ReaSetupTest.Calls.Count -eq 3) 'secondo setup con separatore finale riutilizza installazioni e SkipMcp omette registrazione'
    $global:ReaSetupTest.Answers.Enqueue('s')
    Invoke-RepositorySetup -Mode Existing -GhidraPath $ghidra -JavaPath $java
    Assert ($global:ReaSetupTest.Downloads -eq 2 -and $global:ReaSetupTest.Calls.Count -eq 5) 'Existing verifica e registra senza download'
    Set-Content -LiteralPath (Join-Path $java 'release') -Value 'JAVA_VERSION="25.0.0"'
    $global:ReaSetupTest.Answers.Enqueue('s')
    Invoke-RepositorySetup -Mode Existing -GhidraPath $ghidra -JavaPath $java -SkipMcp
    Assert ($global:ReaSetupTest.Calls.Count -eq 6) 'Existing accetta un JDK Java 25 completo'
    $global:ReaSetupTest.Exit = 7
    $profileBeforeFailure = Get-Content -LiteralPath (Get-ProfilePath ghidra) -Raw
    $alternativeJava = Join-Path $testRoot 'alternative-jdk'
    Copy-Item -LiteralPath $java -Destination $alternativeJava -Recurse
    $global:ReaSetupTest.Answers.Enqueue('s')
    Assert-Fails { Invoke-RepositorySetup -Mode Existing -GhidraPath $ghidra -JavaPath $alternativeJava } 'codice 7'
    Assert ($global:ReaSetupTest.Calls.Count -eq 7 -and $env:JAVA_HOME -eq 'original-java') 'doctor fallito blocca MCP e ripristina ambiente'
    Assert ($profileBeforeFailure -ceq (Get-Content -LiteralPath (Get-ProfilePath ghidra) -Raw)) 'doctor fallito conserva il profilo precedente'
    $global:ReaSetupTest.Exit = 0
    $global:ReaSetupTest.Fixtures[1].SHA256 = '0' * 64
    $partial = Join-Path $testRoot 'partial'
    $global:ReaSetupTest.Answers.Enqueue('s')
    Assert-Fails { Invoke-RepositorySetup -Mode Install -ToolsDirectory $partial } 'SHA-256'
    Assert ((Test-Path (Join-Path $partial $global:ReaSetupTest.Fixtures[0].InstallDir)) -and -not (Test-Path (Join-Path $partial $global:ReaSetupTest.Fixtures[1].InstallDir)) -and @(Get-ChildItem $partial -Filter '.staging-*').Count -eq 0) 'hash errato non pubblica Java e rimuove solo staging proprio'
    $global:ReaSetupTest.Fixtures[1].SHA256 = (Get-FileHash $global:ReaSetupTest.Fixtures[1].URL -Algorithm SHA256).Hash
    $beforeRetry = $global:ReaSetupTest.Downloads
    $global:ReaSetupTest.Answers.Enqueue('s')
    Invoke-RepositorySetup -Mode Install -ToolsDirectory $partial -SkipMcp
    Assert ($global:ReaSetupTest.Downloads -eq $beforeRetry + 1) 'retry riusa Ghidra completo e riscarica solo Java'
    $incomplete = Join-Path $testRoot 'incomplete'
    New-Item -ItemType Directory -Path (Join-Path $incomplete $global:ReaSetupTest.Fixtures[0].InstallDir) -Force | Out-Null
    $beforeIncomplete = $global:ReaSetupTest.Downloads
    $global:ReaSetupTest.Answers.Enqueue('s')
    Assert-Fails { Invoke-RepositorySetup -Mode Install -ToolsDirectory $incomplete } 'incompleta'
    Assert ($global:ReaSetupTest.Downloads -eq $beforeIncomplete) 'installazione incompleta esistente conservata senza sovrascrivere'
    $broken = Join-Path $testRoot 'broken.zip'
    Set-Content $broken 'not a zip'
    $global:ReaSetupTest.Fixtures[0].URL = $broken
    $global:ReaSetupTest.Fixtures[0].SHA256 = (Get-FileHash $broken -Algorithm SHA256).Hash
    $failedRoot = Join-Path $testRoot 'failed-extraction'
    $global:ReaSetupTest.Answers.Enqueue('s')
    Assert-Fails { Invoke-RepositorySetup -Mode Install -ToolsDirectory $failedRoot } '.'
    Assert (@(Get-ChildItem $failedRoot -Force).Count -eq 0) 'estrazione fallita non lascia installazione finale o staging'
    Assert ($global:ReaSetupTest.Answers.Count -eq 0) 'tutte le conferme previste consumate'
    Write-Host 'Tutti i test setup sono passati. Nessuna installazione reale o configurazione Codex modificata.'
} finally {
    $env:GHIDRA_INSTALL_DIR = $originalGhidra
    $env:JAVA_HOME = $originalJava
    $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
    if ((Split-Path $resolvedTestRoot -Parent) -ne [IO.Path]::GetFullPath($testParent).TrimEnd('\')) { throw 'Cartella test fuori dalla cartella test del workspace.' }
    Remove-Item -LiteralPath (Get-ExtendedPath $resolvedTestRoot) -Recurse -Force
    Remove-Variable ReaSetupTest -Scope Global
}

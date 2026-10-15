$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'setup.ps1')
$originalRoot = $script:RepositoryRoot
$testRoot = Join-Path $originalRoot ('.tools/existing-tools-tests-' + [guid]::NewGuid().ToString('N'))
$script:RepositoryRoot = Join-Path $testRoot 'repository'
$external = Join-Path $testRoot 'Existing software outside repository'
$script:Answers = New-Object 'System.Collections.Generic.Queue[string]'

function Assert($Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    Write-Host "PASS: $Message"
}
function Assert-Fails([scriptblock]$Action, [string]$Pattern) {
    $before = Get-Content -LiteralPath (Get-ProfilePath first) -Raw
    $failure = $null
    try { & $Action } catch { $failure = $_ }
    Assert ($null -ne $failure -and "$failure" -match $Pattern -and $before -ceq (Get-Content -LiteralPath (Get-ProfilePath first) -Raw)) "errore $Pattern lascia il profilo invariato"
}
function Read-Host { param($Prompt); if ($script:Answers.Count -eq 0) { throw "Prompt inatteso: $Prompt" }; return $script:Answers.Dequeue() }
function Invoke-WebRequest { throw 'Download inatteso' }
function Invoke-NativeArguments { throw 'Esecuzione strumento inattesa' }
function New-Fixture([string]$Relative, [string]$Content = 'fixture, never execute') {
    $file = Join-Path $external $Relative
    New-Item -ItemType Directory -Path (Split-Path $file -Parent) -Force | Out-Null
    [IO.File]::WriteAllText($file, $Content)
    return $file
}

try {
    Invoke-ProfileSetup -Action Create -Profile first
    Invoke-ProfileSetup -Action Create -Profile second
    $ghidra = Join-Path $external 'Ghidra 12.1'
    New-Fixture 'Ghidra 12.1/ghidraRun.bat' | Out-Null
    New-Fixture 'Ghidra 12.1/support/analyzeHeadless.bat' | Out-Null
    New-Fixture 'Ghidra 12.1/Ghidra/application.properties' 'application.version=12.1.4' | Out-Null
    Invoke-ProfileSetup -Action Link -Profile first -Tool Ghidra -Path $ghidra
    Assert ((Read-ReaProfile first).environment.GHIDRA_INSTALL_DIR -eq $ghidra -and -not $ghidra.StartsWith($script:RepositoryRoot)) 'Ghidra esistente esterno al repository collegato con spazi'
    $java = Join-Path $external 'JDK 17'
    New-Fixture 'JDK 17/bin/java.exe' | Out-Null
    New-Fixture 'JDK 17/bin/javac.exe' | Out-Null
    New-Fixture 'JDK 17/release' 'JAVA_VERSION="17.0.12"' | Out-Null
    Invoke-ProfileSetup -Action Link -Profile first -Tool Java -Path $java
    Assert ((Read-ReaProfile first).environment.JAVA_HOME -eq $java) 'JDK17 completo ammesso per JADX senza eseguirlo'
    $fixtures = @(
        @('Jadx','jadx/jadx-headless-mcp-0.7.1-all.jar','REA_JADX_MCP_JAR'),
        @('Apktool','apktool/apktool.cmd','REA_APKTOOL_COMMAND'),
        @('Adb','platform-tools/adb.exe','REA_ADB_PATH'),
        @('Browser','Chrome/chrome.exe','REA_BROWSER_EXECUTABLE'),
        @('Rizin','rizin/bin/rizin.exe','REA_RIZIN_COMMAND'),
        @('Ilspy','dotnet-tools/ilspycmd.exe','REA_ILSPY_CMD_PATH')
    )
    foreach ($fixture in $fixtures) {
        $file = New-Fixture $fixture[1]
        Invoke-ProfileSetup -Action Link -Profile first -Tool $fixture[0] -Path $file
        Assert ((Read-ReaProfile first).environment.PSObject.Properties[$fixture[2]].Value -eq $file) "collegamento $($fixture[0]) usa variabile REA reale"
    }
    $wabt = Join-Path $external 'wabt/bin'
    New-Fixture 'wabt/bin/wasm2wat.exe' | Out-Null
    New-Fixture 'wabt/bin/wasm-objdump.exe' | Out-Null
    Assert-Fails { Invoke-ProfileSetup -Action Link -Profile first -Tool Wabt -Path $wabt } 'wasm-validate'
    New-Fixture 'wabt/bin/wasm-validate.exe' | Out-Null
    Invoke-ProfileSetup -Action Link -Profile first -Tool Wabt -Path $wabt
    Assert ((Read-ReaProfile first).environment.REA_WABT_BIN_DIRECTORY -eq $wabt) 'WABT richiede tutti e tre gli eseguibili'
    $cutter = Join-Path $external 'Cutter bridge sessions'
    New-Item -ItemType Directory -Path $cutter | Out-Null
    Invoke-ProfileSetup -Action Link -Profile first -Tool Cutter -Path $cutter
    Assert ((Read-ReaProfile first).environment.REA_CUTTER_BRIDGE_DIR -eq $cutter) 'Cutter accetta cartella sessioni esistente senza sessioni attive'
    $ida = New-Fixture 'IDA/mcp.json' '{"mcpServers":{"ida-pro-mcp":{"command":"python","args":["server.py"]}}}'
    Invoke-ProfileSetup -Action Link -Profile first -Tool Ida -Path $ida
    Assert ((Read-ReaProfile first).environment.REA_IDA_MCP_CONFIG -eq $ida) 'IDA accetta registrazione MCP JSON'
    Invoke-ProfileSetup -Action Mcp -Profile first
    $export = Get-Content -LiteralPath (Join-Path $script:RepositoryRoot '.rea/mcp/first.json') -Raw | ConvertFrom-Json
    $toml = Get-Content -LiteralPath (Join-Path $script:RepositoryRoot '.rea/mcp/first.toml') -Raw
    Assert ($export.mcpServers.'rea-first'.env.GHIDRA_INSTALL_DIR -eq $ghidra -and $export.mcpServers.'rea-first'.env.REA_IDA_MCP_CONFIG -eq $ida -and $toml.Contains((ConvertTo-Json -InputObject $ghidra -Compress))) 'snapshot MCP JSON e TOML conservano percorsi esterni reali'
    $otherBrowser = New-Fixture 'Other Chrome/chrome.exe'
    Invoke-ProfileSetup -Action Link -Profile first -Tool Browser -Path $otherBrowser
    Invoke-ProfileSetup -Action Link -Profile first -Tool Browser -Path $otherBrowser
    Assert ((Read-ReaProfile first).environment.REA_BROWSER_EXECUTABLE -eq $otherBrowser -and (Read-ReaProfile first).environment.GHIDRA_INSTALL_DIR -eq $ghidra) 'collegamenti ripetuti aggiornano il singolo strumento e conservano gli altri'
    Assert (@((Read-ReaProfile second).environment.PSObject.Properties).Count -eq 0) 'profili distinti restano isolati'
    Assert-Fails { Invoke-ProfileSetup -Action Link -Profile first -Tool Adb -Path (Join-Path $external 'absent.exe') } 'inesistente'
    Assert-Fails { Invoke-ProfileSetup -Action Link -Profile first -Tool Browser -Path $cutter } 'Tipo di percorso'
    Assert-Fails { Invoke-ProfileSetup -Action Link -Profile first -Tool Wabt -Path $otherBrowser } 'Tipo di percorso'
    $plainJar = New-Fixture 'apktool/apktool.jar'
    Assert-Fails { Invoke-ProfileSetup -Action Link -Profile first -Tool Apktool -Path $plainJar } 'Tipo di file'
    Assert-Fails { Invoke-ProfileSetup -Action Link -Profile first -Tool Ida -Path $otherBrowser } 'Tipo di file'
    $invalidJson = New-Fixture 'IDA/broken.json' '{bad'
    Assert-Fails { Invoke-ProfileSetup -Action Link -Profile first -Tool Ida -Path $invalidJson } 'JSON non valida'
    $emptyJson = New-Fixture 'IDA/empty.json' '{}'
    Assert-Fails { Invoke-ProfileSetup -Action Link -Profile first -Tool Ida -Path $emptyJson } 'command/args'
    New-Fixture 'Ghidra 12.1/Ghidra/application.properties' 'application.version=11.0.0' | Out-Null
    Assert-Fails { Invoke-ProfileSetup -Action Link -Profile first -Tool Ghidra -Path $ghidra } '12.1'
    New-Fixture 'JDK 17/release' 'JAVA_VERSION="11.0.1"' | Out-Null
    Assert-Fails { Invoke-ProfileSetup -Action Link -Profile first -Tool Java -Path $java } '17 o successivo'
    Remove-Item -LiteralPath (Join-Path $java 'bin/javac.exe')
    Assert-Fails { Invoke-ProfileSetup -Action Link -Profile first -Tool Java -Path $java } 'javac'
    foreach ($tool in @('Node','Python','Frida','Kuna','Jeb','Hopper','Linux','Tshark','Capinfos','Binwalk','Unblob','Sigrok','Pwntools','Mitmproxy','Objdump','Gdb','Pwndbg','Wakaru')) {
        Assert-Fails { Invoke-ProfileSetup -Action Link -Profile first -Tool $tool } 'PATH|binding|6.5.0|endpoint|Linux'
    }
    Assert-Fails { Invoke-ProfileSetup -Action Link -Profile first -Tool NotATool } 'sconosciuto'
    $script:Answers.Enqueue('Adb')
    $script:Answers.Enqueue((Join-Path $external 'platform-tools/adb.exe'))
    Invoke-ProfileSetup -Action Link -Profile second
    Assert ((Read-ReaProfile second).environment.REA_ADB_PATH -eq (Join-Path $external 'platform-tools/adb.exe') -and $script:Answers.Count -eq 0) 'scelta guidata chiede strumento e percorso solo quando omessi'
    Push-Location $external
    try { Invoke-ProfileSetup -Action Link -Profile second -Tool Browser -Path 'Chrome/chrome.exe' } finally { Pop-Location }
    Assert ([IO.Path]::IsPathRooted((Read-ReaProfile second).environment.REA_BROWSER_EXECUTABLE)) 'percorso relativo salvato come assoluto'
    $script:Answers.Enqueue('10')
    $script:Answers.Enqueue('second')
    $script:Answers.Enqueue('Browser')
    $script:Answers.Enqueue($otherBrowser)
    Invoke-ProfileSetup
    Assert ((Read-ReaProfile second).environment.REA_BROWSER_EXECUTABLE -eq $otherBrowser -and $script:Answers.Count -eq 0) 'menu10 collega uno strumento al profilo scelto'
    Assert (@(Get-ChildItem -LiteralPath $testRoot -Filter '.rea-install.json' -Recurse -Force).Count -eq 0 -and -not (Test-Path -LiteralPath (Join-Path $script:RepositoryRoot '.tools'))) 'nessuna ricevuta o cartella di installazione creata'
} finally {
    $script:RepositoryRoot = $originalRoot
    $resolved = [IO.Path]::GetFullPath($testRoot)
    if ((Split-Path $resolved -Parent) -ne [IO.Path]::GetFullPath((Join-Path $originalRoot '.tools'))) { throw 'Test root fuori dal workspace.' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}

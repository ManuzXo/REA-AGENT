$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'setup.ps1')
$originalRoot = $script:RepositoryRoot
$testRoot = Join-Path $originalRoot ('.tools/profile-tests-' + [guid]::NewGuid().ToString('N'))
$script:RepositoryRoot = $testRoot
$script:Calls = @()
$script:Answers = New-Object 'System.Collections.Generic.Queue[string]'
$script:OriginalProvider = $env:REA_ANALYSIS_PROVIDER

function Assert($Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    Write-Host "PASS: $Message"
}
function Assert-Fails([scriptblock]$Action, [string]$Pattern) {
    $failure = $null
    try { & $Action } catch { $failure = $_ }
    Assert ($null -ne $failure -and "$failure" -match $Pattern) "errore atteso $Pattern"
}
function Install-ReaRuntime { param($Version); Assert ($Version -eq '6.5.0') 'runtime fissato prima del comando' }
function Get-ReaLaunchCommand { param($Version); return [pscustomobject]@{ Executable = (Get-Command node.exe).Source; Prefix = @('C:\REA with spaces\scripts\rea.mjs'); Version = $Version } }
function Read-Host { param($Prompt); if ($script:Answers.Count -eq 0) { throw "Prompt inatteso: $Prompt" }; return $script:Answers.Dequeue() }
function Invoke-ReaCommand {
    param($Version, $Arguments)
    $script:Calls += [pscustomobject]@{ Arguments = @($Arguments); Provider = $env:REA_ANALYSIS_PROVIDER; Java = $env:JAVA_HOME }
}

try {
    $script:Answers.Enqueue('0')
    Invoke-ProfileSetup
    Assert (-not (Test-Path -LiteralPath $testRoot)) 'annullamento del menu non crea profili'
    Invoke-ProfileSetup -Action Runtime
    Assert (-not (Test-Path -LiteralPath (Join-Path $testRoot '.rea/profiles/default.json'))) 'preparazione runtime non richiede o crea un profilo'
    Invoke-ProfileSetup -Action Create -Profile base
    $base = Read-ReaProfile base
    Assert ($base.reaVersion -eq '6.5.0' -and $base.template -eq 'builtin' -and @($base.environment.PSObject.Properties).Count -eq 0) 'creazione builtin non inventa strumenti'
    Assert-Fails { Invoke-ProfileSetup -Action Create -Profile base } 'gia esistente'
    Assert-Fails { Invoke-ProfileSetup -Action Create -Profile '../escape' } 'Nome profilo'
    Assert-Fails { Invoke-ProfileSetup -Action Create -Profile unknown -Template missing } 'Modello sconosciuto'
    Assert-Fails { Invoke-ProfileSetup -Action Set -Profile base -Key PATH -Value 'unsafe' } 'non ammessa'
    Assert-Fails { Invoke-ProfileSetup -Action Set -Profile base -Key REA_EXAMPLE -Value "bad`nvalue" } 'Valore non valido'
    Invoke-ProfileSetup -Action Set -Profile base -Key HOPPER_LOADER_ARGS_JSON -Value '["--loader", "raw"]'
    Invoke-ProfileSetup -Action Set -Profile base -Key JAVA_TOOL_OPTIONS -Value '-Xmx2g'
    Assert ((Read-ReaProfile base).environment.JAVA_TOOL_OPTIONS -eq '-Xmx2g' -and (Read-ReaProfile base).environment.HOPPER_LOADER_ARGS_JSON -eq '["--loader", "raw"]') 'override Hopper e JVM documentati vengono conservati'
    Invoke-ProfileSetup -Action RemoveVariable -Profile base -Key JAVA_TOOL_OPTIONS
    Invoke-ProfileSetup -Action RemoveVariable -Profile base -Key HOPPER_LOADER_ARGS_JSON
    Invoke-ProfileSetup -Action Create -Profile native -Template native-ghidra
    Assert-Fails { Invoke-ProfileSetup -Action Doctor -Profile native } 'GHIDRA_INSTALL_DIR'
    Invoke-ProfileSetup -Action Set -Profile native -Key GHIDRA_INSTALL_DIR -Value 'C:\Tools with spaces\Ghidra'
    Invoke-ProfileSetup -Action Set -Profile native -Key JAVA_HOME -Value 'C:\Tools with spaces\JDK'
    $env:REA_ANALYSIS_PROVIDER = 'previous'
    Invoke-ProfileSetup -Action Doctor -Profile native
    Assert (($script:Calls[0].Arguments -join ' ') -eq 'doctor --provider ghidra --json' -and $script:Calls[0].Provider -eq 'ghidra' -and $env:REA_ANALYSIS_PROVIDER -eq 'previous') 'doctor del provider usa profilo e ripristina ambiente'
    Assert-Fails { Invoke-InReaProfile (Read-ReaProfile native) { throw 'failed-action' } } 'failed-action'
    Assert ($env:REA_ANALYSIS_PROVIDER -eq 'previous') 'ambiente ripristinato anche se il comando fallisce'
    Invoke-ProfileSetup -Action Mcp -Profile native
    $export = Get-Content -LiteralPath (Join-Path $testRoot '.rea/mcp/native.json') -Raw | ConvertFrom-Json
    Assert ($export.mcpServers.'rea-native'.command -eq (Get-Command node.exe).Source -and ($export.mcpServers.'rea-native'.args -join '|') -eq 'C:\REA with spaces\scripts\rea.mjs|mcp' -and $export.mcpServers.'rea-native'.env.JAVA_HOME -eq 'C:\Tools with spaces\JDK') 'snapshot MCP diretto contiene node, entry locale e variabili'
    $toml = Get-Content -LiteralPath (Join-Path $testRoot '.rea/mcp/native.toml') -Raw
    Assert ($toml -match '\[mcp_servers.rea-native.env\]' -and $toml.Contains('C:\\Tools with spaces\\JDK')) 'frammento TOML conserva i percorsi Windows'
    Invoke-ProfileSetup -Action Set -Profile native -Key JAVA_HOME -Value 'C:\other-jdk'
    Assert ($export.mcpServers.'rea-native'.env.JAVA_HOME -eq 'C:\Tools with spaces\JDK') 'export e uno snapshot esplicito, non un collegamento nascosto'
    Invoke-ProfileSetup -Action RemoveVariable -Profile native -Key JAVA_HOME
    Assert (-not (Read-ReaProfile native).environment.PSObject.Properties['JAVA_HOME']) 'rimozione variabile persistita'
    Assert (@($base.environment.PSObject.Properties).Count -eq 0) 'modifica di un profilo non contamina un altro'
    Invoke-ProfileSetup -Action Create -Profile device -Template android
    Invoke-ProfileSetup -Action Set -Profile device -Key REA_JADX_MCP_JAR -Value 'C:\jadx.jar'
    Invoke-ProfileSetup -Action Set -Profile device -Key JAVA_HOME -Value 'C:\jdk'
    Invoke-ProfileSetup -Action Doctor -Profile device
    Assert (($script:Calls[-1].Arguments -join ' ') -match 'doctor --provider jadx --json$') 'JADX e un provider doctor reale'
    Invoke-ProfileSetup -Action Doctor -Profile base
    Assert (($script:Calls[-1].Arguments -join ' ') -match 'capabilities --json$') 'builtin ispeziona capacita reali senza cercare la registrazione standard rea'
    Assert-Fails { Invoke-ProfileSetup -Action Register -Profile base -Client cursor } 'Register supporta codex e claude'
    $argvPath = Join-Path $testRoot 'native-argv.json'
    $values = @('REA_JSON=["a", "b"]', 'REA_PATH=C:\folder with spaces\', 'REA_URL=https://example.invalid/?a=1&b=2', 'REA_PATTERN=\\"quoted"', 'REA_PERCENT=100% (x) | x', '')
    $nodePath = (Get-Command node.exe).Source
    $exitCode = Invoke-NativeArguments $nodePath (@('-e', 'require("fs").writeFileSync(process.argv[1], JSON.stringify(process.argv.slice(2)))', $argvPath) + $values)
    [string[]]$observed = Get-Content -LiteralPath $argvPath -Raw | ConvertFrom-Json
    $expectedJson = ConvertTo-Json -InputObject $values -Compress
    $observedJson = ConvertTo-Json -InputObject $observed -Compress
    if ($observedJson -ne $expectedJson) { Write-Host "Expected $expectedJson"; Write-Host "Observed $observedJson" }
    Assert ($exitCode -eq 0 -and $observedJson -eq $expectedJson) 'trasporto nativo reale conserva JSON, backslash, spazi e metacaratteri senza cmd'
    $script:RegistrationPath = Join-Path $testRoot 'registration-argv.json'
    $script:RegistrationNode = $nodePath
    function Get-CodexRegistrationCommand {
        return [pscustomobject]@{ Executable = $script:RegistrationNode; Prefix = @('-e', 'require("fs").writeFileSync(process.argv[1], JSON.stringify(process.argv.slice(2)))', $script:RegistrationPath) }
    }
    Invoke-ProfileSetup -Action Set -Profile native -Key HOPPER_LOADER_ARGS_JSON -Value '["a", "b"]'
    $script:Answers.Enqueue('n')
    Invoke-ProfileSetup -Action Register -Profile native
    Assert (-not (Test-Path -LiteralPath $script:RegistrationPath)) 'registrazione rifiutata non avvia il comando nativo'
    $script:Answers.Enqueue('s')
    Invoke-ProfileSetup -Action Register -Profile native
    [string[]]$registrationArgs = Get-Content -LiteralPath $script:RegistrationPath -Raw | ConvertFrom-Json
    $expectedLaunch = @('--', (Get-Command node.exe).Source, 'C:\REA with spaces\scripts\rea.mjs', 'mcp')
    Assert ($registrationArgs[0] -eq 'mcp' -and $registrationArgs[2] -eq 'rea-native' -and $registrationArgs -contains 'HOPPER_LOADER_ARGS_JSON=["a", "b"]' -and (ConvertTo-Json -InputObject @($registrationArgs[-4..-1]) -Compress) -eq (ConvertTo-Json -InputObject $expectedLaunch -Compress)) 'registrazione profilo conserva gli argomenti distinti su processo nativo reale'
    Invoke-ProfileSetup -Action Register -Profile native -Yes
    Assert ($script:Answers.Count -eq 0) 'Yes registra senza richiedere conferma interattiva'
    Invoke-ProfileSetup -Action Client -Profile native -Client codex -Yes
    [string[]]$clientRegistrationArgs = Get-Content -LiteralPath $script:RegistrationPath -Raw | ConvertFrom-Json
    Assert ((ConvertTo-Json -InputObject $clientRegistrationArgs -Compress) -eq (ConvertTo-Json -InputObject $registrationArgs -Compress)) 'Client Codex riusa la stessa registrazione diretta del profilo'
    $script:ClaudeCalls = Join-Path $testRoot 'claude-argv.jsonl'
    function Get-ClaudeRegistrationCommand {
        return [pscustomobject]@{ Executable = $script:RegistrationNode; Prefix = @('-e', 'require("fs").appendFileSync(process.argv[1], JSON.stringify(process.argv.slice(2)) + "\n")', $script:ClaudeCalls) }
    }
    Invoke-ProfileSetup -Action Register -Profile native -Client claude -Yes
    $claudeArgv = @(Get-Content -LiteralPath $script:ClaudeCalls | ForEach-Object { , [string[]]($_ | ConvertFrom-Json) })
    Assert ($claudeArgv.Count -eq 2 -and ($claudeArgv[0] -join ' ') -eq 'mcp remove rea-native --scope local') 'registrazione Claude Code sostituisce il server locale con lo stesso nome'
    $claudeServer = $claudeArgv[1][-1] | ConvertFrom-Json
    Assert ((($claudeArgv[1][0..4]) -join ' ') -eq 'mcp add-json --scope local rea-native' -and $claudeServer.command -eq (Get-Command node.exe).Source -and ($claudeServer.args -join '|') -eq 'C:\REA with spaces\scripts\rea.mjs|mcp' -and $claudeServer.env.HOPPER_LOADER_ARGS_JSON -eq '["a", "b"]') 'registrazione Claude Code passa launch e variabili del profilo come JSON'
    Invoke-ProfileSetup -Action Client -Profile native -Client claude_code -Yes
    Assert (@(Get-Content -LiteralPath $script:ClaudeCalls).Count -eq 4) 'Client claude_code riusa la registrazione diretta del profilo'
    Invoke-ProfileSetup -Action Client -Profile base -Client cursor
    Assert (($script:Calls[-1].Arguments -join ' ') -match 'setup --client cursor$') 'setup ufficiale accetta client selezionato'
    $bad = [pscustomobject]@{ schemaVersion = 1; reaVersion = 'latest;bad'; environment = [pscustomobject]@{} }
    Save-ReaProfile broken $bad
    Assert-Fails { Read-ReaProfile broken } 'Profilo non valido'
    Write-Host 'Tutti i test profili sono passati. Nessuna registrazione MCP modificata.'
} finally {
    $env:REA_ANALYSIS_PROVIDER = $script:OriginalProvider
    $resolvedTest = [IO.Path]::GetFullPath($testRoot)
    $expectedParent = [IO.Path]::GetFullPath((Join-Path $originalRoot '.tools'))
    if ((Split-Path $resolvedTest -Parent) -ne $expectedParent) { throw 'Test root fuori dal workspace.' }
    if (Test-Path -LiteralPath $resolvedTest) { Remove-Item -LiteralPath $resolvedTest -Recurse -Force }
    $script:RepositoryRoot = $originalRoot
}

$script:RepositoryRoot = Split-Path $PSScriptRoot -Parent
$script:ReaConfig = Get-Content -LiteralPath (Join-Path $script:RepositoryRoot 'config/rea.json') -Raw | ConvertFrom-Json
. (Join-Path $PSScriptRoot 'rea-runtime.ps1')

function Get-ProfilePath([string]$Name) {
    if ($Name -notmatch '^[a-z][a-z0-9-]{0,47}$') { throw 'Nome profilo non valido. Usa lettere minuscole, numeri e trattini, iniziando con una lettera.' }
    return Join-Path $script:RepositoryRoot ".rea/profiles/$Name.json"
}

function Read-ReaProfile([string]$Name) {
    $path = Get-ProfilePath $Name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Profilo assente: $Name. Crealo con setup.bat -Action Create -Profile $Name." }
    $profile = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if ($profile.schemaVersion -ne 1 -or $profile.reaVersion -notmatch '^\d+\.\d+\.\d+$' -or $null -eq $profile.environment -or $profile.environment -isnot [pscustomobject]) { throw "Profilo non valido: $path" }
    foreach ($property in $profile.environment.PSObject.Properties) { Assert-ProfileVariable $property.Name $property.Value }
    return $profile
}

function Assert-ProfileVariable([string]$Key, $Value) {
    if ($Key -cnotmatch '^(REA_[A-Z0-9_]+|GHIDRA_INSTALL_DIR|JAVA_HOME|JAVA_TOOL_OPTIONS|JDK_JAVA_OPTIONS|_JAVA_OPTIONS|HOPPER_LAUNCHER_PATH|HOPPER_TARGET_PATH|HOPPER_TARGET_KIND|HOPPER_LOADER_ARGS_JSON)$') { throw "Variabile non ammessa: $Key" }
    if ($Value -isnot [string] -or $Value -match '[\x00-\x1f]' -or [string]::IsNullOrWhiteSpace($Value)) { throw "Valore non valido per $Key. Usa una stringa non vuota senza caratteri di controllo." }
}

function Save-ReaProfile([string]$Name, $Profile) {
    $path = Get-ProfilePath $Name
    New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
    $temporary = $path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::WriteAllText($temporary, ($Profile | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding($false)))
        Move-Item -LiteralPath $temporary -Destination $path -Force
    } finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary }
    }
}

function Invoke-InReaProfile($Profile, [scriptblock]$Action) {
    $previous = @{}
    try {
        foreach ($property in $Profile.environment.PSObject.Properties) {
            $previous[$property.Name] = [Environment]::GetEnvironmentVariable($property.Name, 'Process')
            [Environment]::SetEnvironmentVariable($property.Name, $property.Value, 'Process')
        }
        & $Action
    } finally {
        foreach ($key in $previous.Keys) { [Environment]::SetEnvironmentVariable($key, $previous[$key], 'Process') }
    }
}

function Export-ReaMcp([string]$Name, $Profile) {
    $serverName = 'rea-' + $Name
    $environment = [ordered]@{}
    foreach ($property in $Profile.environment.PSObject.Properties) { $environment[$property.Name] = $property.Value }
    $launch = Get-ReaLaunchCommand $Profile.reaVersion
    $server = [ordered]@{ command = $launch.Executable; args = @($launch.Prefix) + @('mcp'); env = $environment }
    $servers = [ordered]@{}
    $servers[$serverName] = $server
    $directory = Join-Path $script:RepositoryRoot '.rea/mcp'
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $jsonPath = Join-Path $directory "$Name.json"
    [IO.File]::WriteAllText($jsonPath, (@{ mcpServers = $servers } | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding($false)))
    $lines = @("[mcp_servers.$serverName]", ('command = ' + (ConvertTo-Json -InputObject $server.command -Compress)), ('args = ' + (ConvertTo-Json -InputObject $server.args -Compress)))
    if ($environment.Count -gt 0) {
        $lines += "[mcp_servers.$serverName.env]"
        foreach ($key in $environment.Keys) { $lines += $key + ' = ' + (ConvertTo-Json -InputObject $environment[$key] -Compress) }
    }
    $tomlPath = Join-Path $directory "$Name.toml"
    [IO.File]::WriteAllText($tomlPath, ($lines -join [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
    Write-Host "Snapshot MCP creati: $jsonPath e $tomlPath"
    Write-Host 'Controllali prima di importarli. Dopo ogni modifica al profilo, rigenera e aggiorna la registrazione. Riavvia il client.'
}

function Register-ReaMcp([string]$Name, $Profile) {
    $codex = Get-CodexRegistrationCommand
    $launch = Get-ReaLaunchCommand $Profile.reaVersion
    $arguments = @('mcp', 'add', ('rea-' + $Name))
    foreach ($property in $Profile.environment.PSObject.Properties) { $arguments += @('--env', ($property.Name + '=' + $property.Value)) }
    $arguments += @('--', $launch.Executable) + @($launch.Prefix) + @('mcp')
    $registrationExit = Invoke-NativeArguments $codex.Executable (@($codex.Prefix) + $arguments)
    if ($registrationExit -ne 0) { throw "Registrazione Codex fallita: $registrationExit" }
}

function Register-ReaClaudeMcp([string]$Name, $Profile) {
    $claude = Get-ClaudeRegistrationCommand
    $launch = Get-ReaLaunchCommand $Profile.reaVersion
    $environment = [ordered]@{}
    foreach ($property in $Profile.environment.PSObject.Properties) { $environment[$property.Name] = $property.Value }
    $server = [ordered]@{ type = 'stdio'; command = $launch.Executable; args = @($launch.Prefix) + @('mcp'); env = $environment }
    $serverName = 'rea-' + $Name
    Invoke-NativeArguments $claude.Executable (@($claude.Prefix) + @('mcp', 'remove', $serverName, '--scope', 'local')) | Out-Null
    $json = ConvertTo-Json -InputObject $server -Depth 10 -Compress
    $registrationExit = Invoke-NativeArguments $claude.Executable (@($claude.Prefix) + @('mcp', 'add-json', '--scope', 'local', $serverName, $json))
    if ($registrationExit -ne 0) { throw "Registrazione Claude Code fallita: $registrationExit" }
}

function ConvertTo-WindowsArgument([string]$Argument) {
    $escaped = [regex]::Replace($Argument, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function Invoke-NativeArguments([string]$Executable, [string[]]$Arguments) {
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $Executable
    $start.Arguments = (($Arguments | ForEach-Object { ConvertTo-WindowsArgument $_ }) -join ' ')
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $process = [Diagnostics.Process]::Start($start)
    try { $process.WaitForExit(); return $process.ExitCode }
    finally { $process.Dispose() }
}

function Get-CodexRegistrationCommand {
    $codex = Get-Command codex.exe -ErrorAction SilentlyContinue
    if ($codex) { return [pscustomobject]@{ Executable = $codex.Source; Prefix = @() } }
    $shim = Get-Command codex.cmd -ErrorAction SilentlyContinue
    $node = Get-Command node.exe -ErrorAction SilentlyContinue
    if ($shim -and $node) {
        $entry = Join-Path (Split-Path $shim.Source -Parent) 'node_modules/@openai/codex/bin/codex.js'
        if (Test-Path -LiteralPath $entry -PathType Leaf) { return [pscustomobject]@{ Executable = $node.Source; Prefix = @($entry) } }
    }
    throw 'Codex CLI nativo o npm standard assente. Usa Mcp e importa lo snapshot TOML nel client.'
}

function Get-ClaudeRegistrationCommand {
    $claude = Get-Command claude.exe -ErrorAction SilentlyContinue
    if ($claude) { return [pscustomobject]@{ Executable = $claude.Source; Prefix = @() } }
    $shim = Get-Command claude.cmd -ErrorAction SilentlyContinue
    $node = Get-Command node.exe -ErrorAction SilentlyContinue
    if ($shim -and $node) {
        $entry = Join-Path (Split-Path $shim.Source -Parent) 'node_modules/@anthropic-ai/claude-code/cli.js'
        if (Test-Path -LiteralPath $entry -PathType Leaf) { return [pscustomobject]@{ Executable = $node.Source; Prefix = @($entry) } }
    }
    throw 'Claude Code CLI nativo o npm standard assente. Usa Mcp e importa lo snapshot JSON nel client.'
}

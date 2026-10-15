[CmdletBinding()]
param(
    [ValidateSet('Menu', 'List', 'Create', 'Set', 'Link', 'RemoveVariable', 'Doctor', 'Mcp', 'Register', 'Client', 'Runtime')][string]$Action = 'Menu',
    [string]$Profile = 'default',
    [string]$Template = 'builtin',
    [string]$Key,
    [string]$Value,
    [string]$Client = 'codex',
    [string]$Tool,
    [string]$Path,
    [switch]$Yes
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'rea-profiles.ps1')
. (Join-Path $PSScriptRoot 'setup-ghidra.ps1')
. (Join-Path $PSScriptRoot 'existing-tools.ps1')

function Invoke-ProfileSetup {
    param([string]$Action = 'Menu', [string]$Profile = 'default', [string]$Template = 'builtin', [string]$Key, [string]$Value, [string]$Client = 'codex', [string]$Tool, [string]$Path, [switch]$Yes)
    if ($Action -eq 'Menu') {
        Write-Host 'REA workspace. Profili e strumenti facoltativi.'
        Write-Host '1. Elenca modelli e profili'
        Write-Host '2. Crea un profilo'
        Write-Host '3. Configura una variabile del profilo'
        Write-Host '4. Controlla provider o capacita del profilo'
        Write-Host '5. Esporta configurazione MCP JSON e TOML'
        Write-Host '6. Registra il profilo in Codex con codex mcp add'
        Write-Host '7. Setup ufficiale REA per client e istruzioni agente'
        Write-Host '8. Installa Ghidra e JDK oppure collega quelli esistenti'
        Write-Host '9. Altri strumenti esterni e guide'
        Write-Host '10. Collega software gia installato a un profilo'
        Write-Host '11. Prepara o ripara il runtime REA locale'
        Write-Host '0. Esci'
        switch (Read-Host 'Scelta [0]') {
            '1' { $Action = 'List' }
            '2' { $Action = 'Create'; $Profile = Read-Host 'Nome nuovo profilo'; $Template = Read-Host 'Modello (builtin, native-ghidra, native-ida, native-hopper, android, browser, offline-tools, linux)' }
            '3' { $Action = 'Set'; $Profile = Read-Host 'Nome profilo'; $Key = Read-Host 'Nome variabile'; $Value = Read-Host 'Valore' }
            '4' { $Action = 'Doctor'; $Profile = Read-Host 'Nome profilo' }
            '5' { $Action = 'Mcp'; $Profile = Read-Host 'Nome profilo' }
            '6' { $Action = 'Register'; $Profile = Read-Host 'Nome profilo' }
            '7' { $Action = 'Client'; $Profile = Read-Host 'Nome profilo'; $Client = Read-Host 'Client REA (codex, cursor, claude_code, ...)' }
            '8' { Invoke-RepositorySetup; return }
            '9' { Get-ChildItem -LiteralPath $script:RepositoryRoot -Filter 'install-*.bat' | ForEach-Object { Write-Host $_.Name }; Write-Host 'Leggi docs/setup-external-tools.md e docs/rea-capabilities.md prima di installare.'; return }
            '10' { $Action = 'Link'; $Profile = Read-Host 'Nome profilo' }
            '11' { $Action = 'Runtime' }
            default { Write-Host 'Setup annullato.'; return }
        }
    }
    if ($Action -eq 'Runtime') { Install-ReaRuntime $script:ReaConfig.reaVersion | Out-Null; return }
    if ($Action -eq 'List') {
        $script:ReaConfig.templates.PSObject.Properties | ForEach-Object { Write-Host "$($_.Name): $($_.Value.description)" }
        $folder = Join-Path $script:RepositoryRoot '.rea/profiles'
        if (Test-Path -LiteralPath $folder) { Get-ChildItem -LiteralPath $folder -Filter '*.json' | ForEach-Object { Write-Host "Profilo locale: $($_.BaseName)" } }
        return
    }
    if ($Action -eq 'Create') {
        $path = Get-ProfilePath $Profile
        $definition = $script:ReaConfig.templates.PSObject.Properties[$Template]
        if (-not $definition) { throw "Modello sconosciuto: $Template" }
        if (Test-Path -LiteralPath $path) { throw "Profilo gia esistente: $Profile. Usa Set per modificarlo." }
        $profileData = [pscustomobject]@{ schemaVersion = 1; reaVersion = $script:ReaConfig.reaVersion; template = $Template; description = $definition.Value.description; environment = $definition.Value.environment }
        Save-ReaProfile $Profile $profileData
        Write-Host "Profilo creato: $path"
        Write-Host "Variabili da configurare: $($definition.Value.requiredEnvironment -join ', ')"
        Write-Host 'Consulta docs/setup-profiles.md. La creazione non verifica o installa gli strumenti.'
        return
    }
    $selected = Read-ReaProfile $Profile
    if ($Action -eq 'Link') {
        $link = Get-ExistingToolLink -Tool $Tool -Path $Path
        Assert-ProfileVariable $link.Environment $link.Path
        $selected.environment | Add-Member -MemberType NoteProperty -Name $link.Environment -Value $link.Path -Force
        Save-ReaProfile $Profile $selected
        Write-Host "Collegato $($link.Tool) al profilo $Profile tramite $($link.Environment)."
        Write-Host 'Il percorso e stato verificato senza avviare lo strumento. Verifica poi il provider con Doctor o il comando REA dedicato.'
        Write-Host 'Rigenera lo snapshot con Mcp e aggiorna la registrazione con Register se gia presente. Riavvia il client.'
        return
    }
    if ($Action -eq 'Set') {
        Assert-ProfileVariable $Key $Value
        $selected.environment | Add-Member -MemberType NoteProperty -Name $Key -Value $Value -Force
        Save-ReaProfile $Profile $selected
        Write-Host "Variabile $Key aggiornata nel profilo $Profile. Aggiorna anche lo snapshot MCP se gia registrato."
        return
    }
    if ($Action -eq 'RemoveVariable') {
        Assert-ProfileVariable $Key 'validate'
        $selected.environment.PSObject.Properties.Remove($Key)
        Save-ReaProfile $Profile $selected
        Write-Host "Variabile $Key rimossa. Aggiorna anche lo snapshot MCP."
        return
    }
    if ($Action -eq 'Mcp') { Install-ReaRuntime $selected.reaVersion | Out-Null; Export-ReaMcp $Profile $selected; return }
    if ($Action -eq 'Register') {
        if ($Client -ne 'codex') { throw 'Register usa codex mcp add. Per altri client usa Mcp ed importa lo snapshot JSON.' }
        $serverName = 'rea-' + $Profile
        Write-Host "Registrazione utente Codex $serverName, versione REA $($selected.reaVersion)."
        Write-Host "Variabili: $($selected.environment.PSObject.Properties.Name -join ', ')"
        Write-Host 'Un server con lo stesso nome verra aggiornato. Le altre registrazioni restano separate.'
        if (-not $Yes -and (Read-Host 'Procedere? [s/N]') -notmatch '^(s|si|y|yes)$') { Write-Host 'Registrazione annullata.'; return }
        Install-ReaRuntime $selected.reaVersion | Out-Null
        Register-ReaMcp $Profile $selected
        Write-Host "Riavvia Codex. Usa codex mcp get $serverName per verificare lo snapshot registrato."
        return
    }
    if ($Action -eq 'Client') {
        if ($Client -notmatch '^[a-z][a-z0-9_]*$') { throw 'Identificatore client non valido.' }
        if ($Client -eq 'codex') { Invoke-ProfileSetup -Action Register -Profile $Profile -Client codex -Yes:$Yes; return }
        Write-Host 'Il setup ufficiale mostra e richiede approvazione del piano. Non collega automaticamente tutte le variabili del profilo.'
        Install-ReaRuntime $selected.reaVersion | Out-Null
        Invoke-InReaProfile $selected {
            Invoke-ReaCommand $selected.reaVersion @('setup', '--client', $Client)
        }
        return
    }
    $definition = $script:ReaConfig.templates.PSObject.Properties[$selected.template]
    if (-not $definition) { throw "Modello assente per il profilo $Profile." }
    if ($definition.Value.host -and $env:OS -eq 'Windows_NT') { throw 'Questo modello richiede Linux/macOS. Installa REA su quell host e usa percorsi locali a quell host.' }
    foreach ($required in $definition.Value.requiredEnvironment) {
        if (-not $selected.environment.PSObject.Properties[$required]) { throw "Variabile richiesta nel profilo: $required" }
    }
    $arguments = @('capabilities', '--json')
    if ($definition.Value.doctorProvider) { $arguments = @('doctor', '--provider', $definition.Value.doctorProvider, '--json') }
    Write-Host 'La diagnosi usa doctor per il provider del modello oppure capabilities per i modelli senza motore.'
    Write-Host "Per la registrazione Codex del profilo usa codex mcp get rea-$Profile. REA doctor --client verifica solo la registrazione standard rea."
    Write-Host 'La diagnosi non prova ogni helper su un campione o la connessione MCP attiva.'
    Install-ReaRuntime $selected.reaVersion | Out-Null
    Invoke-InReaProfile $selected {
        Invoke-ReaCommand $selected.reaVersion $arguments
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try { Invoke-ProfileSetup @PSBoundParameters }
    catch { Write-Error $_ -ErrorAction Continue; exit 1 }
}

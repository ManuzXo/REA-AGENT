function Get-ExistingToolCatalog {
    @{
        Ghidra = @{ Environment='GHIDRA_INSTALL_DIR'; PathType='Container'; RequiredFiles=@('ghidraRun.bat','support/analyzeHeadless.bat','Ghidra/application.properties'); Hint='Cartella principale Ghidra 12.1.x, anche fuori dal repository.' }
        Java = @{ Environment='JAVA_HOME'; PathType='Container'; RequiredFiles=@('bin/java.exe','bin/javac.exe','release'); Hint='Cartella di un JDK completo 17+. Ghidra richiede 21+ e la verifica Doctor.' }
        Jadx = @{ Environment='REA_JADX_MCP_JAR'; PathType='Leaf'; Extension='\.jar$'; Hint='File jadx-headless-mcp-*-all.jar. Il normale JADX GUI non sostituisce il server headless MCP.' }
        Apktool = @{ Environment='REA_APKTOOL_COMMAND'; PathType='Leaf'; Extension='\.(cmd|bat|exe)$'; Hint='Launcher apktool.cmd, apktool.bat oppure eseguibile. Un file JAR da solo non e un comando.' }
        Adb = @{ Environment='REA_ADB_PATH'; PathType='Leaf'; Extension='\.exe$'; Hint='File adb.exe della propria installazione Android Platform-Tools.' }
        Browser = @{ Environment='REA_BROWSER_EXECUTABLE'; PathType='Leaf'; Extension='\.exe$'; Hint='Eseguibile Chrome/Chromium compatibile con CDP, per esempio chrome.exe.' }
        Rizin = @{ Environment='REA_RIZIN_COMMAND'; PathType='Leaf'; Extension='\.exe$'; Hint='Eseguibile rizin.exe. Verifica poi compatibilita e piattaforma con il comando REA dedicato.' }
        Ilspy = @{ Environment='REA_ILSPY_CMD_PATH'; PathType='Leaf'; Extension='\.exe$'; Hint='ILSpy CLI ilspycmd.exe, non la GUI ILSpy.' }
        Wabt = @{ Environment='REA_WABT_BIN_DIRECTORY'; PathType='Container'; RequiredFiles=@('wasm2wat.exe','wasm-objdump.exe','wasm-validate.exe'); Hint='Cartella bin di WABT 1.0.42 contenente i tre eseguibili.' }
        Cutter = @{ Environment='REA_CUTTER_BRIDGE_DIR'; PathType='Container'; RequiredFiles=@(); Hint='Cartella sessioni del bridge Python Cutter v2. Deve esistere. Non e la cartella di Cutter.exe e non richiede sessioni attive al collegamento.' }
        Ida = @{ Environment='REA_IDA_MCP_CONFIG'; PathType='Leaf'; Extension='\.json$'; Hint='Registrazione MCP IDA JSON, diretta oppure mcpServers.ida-pro-mcp. Non scegliere ida.exe.' }
        Node = @{ Hint='REA usa Node e npx dal PATH del client MCP. Riutilizza l installazione esistente nel PATH e riavvia il client. Nessuna variabile REA di percorso dedicata.' }
        Python = @{ Hint='Python generico si seleziona nel PATH o nell ambiente virtuale dello strumento. REA non definisce una variabile di percorso Python globale.' }
        Frida = @{ Hint='REA carica i binding Node Frida opzionali dal pacchetto npm. Una CLI frida-tools esistente non sostituisce questi binding. Nessuna variabile REA di percorso dedicata.' }
        Kuna = @{ Hint='Kuna non e disponibile nella versione REA 6.5.0 fissata dal repository. Non viene creata una variabile per un provider assente.' }
        Jeb = @{ Hint='JEB si collega tramite endpoint MCP. Usa Set con REA_JEB_MCP_URL e l URL del server avviato nel client JEB, non un percorso di installazione.' }
        Hopper = @{ Hint='Hopper richiede macOS/Linux. Configura HOPPER_LAUNCHER_PATH nel profilo sul relativo host. Un percorso Windows non rende disponibile il provider.' }
        Linux = @{ Hint='Questo workflow richiede un host Linux o una VM/WSL compatibile. Installa REA e configura i percorsi dentro quell host, non con percorsi Windows.' }
        Tshark = @{ Hint='Il provider TShark REA richiede Linux e prlimit. Configura REA_TSHARK_COMMAND dentro l host Linux.' }
        Capinfos = @{ Hint='Il provider PCAP REA richiede Linux. Configura REA_CAPINFOS_COMMAND dentro l host Linux.' }
        Binwalk = @{ Hint='Il provider Binwalk REA richiede Linux. Configura REA_BINWALK_COMMAND dentro l host Linux.' }
        Unblob = @{ Hint='Il provider Unblob REA richiede Linux. Configura REA_UNBLOB_COMMAND dentro l host Linux.' }
        Sigrok = @{ Hint='Il provider Sigrok REA richiede Linux e prlimit. Configura REA_SIGROK_COMMAND dentro l host Linux.' }
        Pwntools = @{ Hint='Il provider Pwntools REA richiede Linux. Configura REA_PWNTOOLS_PYTHON con il Python del virtualenv dentro l host Linux.' }
        Mitmproxy = @{ Hint='Gli adattatori mitmproxy REA richiedono Linux. Configura i relativi comandi dentro l host Linux.' }
        Objdump = @{ Hint='Il provider Objdump REA richiede Linux. Configura REA_OBJDUMP_COMMAND dentro l host Linux.' }
        Gdb = @{ Hint='Il provider GDB REA richiede Linux e prlimit. Configura REA_GDB_COMMAND dentro l host Linux.' }
        Pwndbg = @{ Hint='Pwndbg richiede GDB su Linux. Configura il relativo ambiente virtuale dentro l host Linux.' }
        Wakaru = @{ Hint='Il provider Wakaru REA richiede Linux x64 e prlimit. Configura REA_WAKARU_COMMAND dentro l host Linux.' }
    }
}

function Get-ExistingToolLink([string]$Tool, [string]$Path) {
    $catalog = Get-ExistingToolCatalog
    if ([string]::IsNullOrWhiteSpace($Tool)) {
        foreach ($name in ($catalog.Keys | Sort-Object)) {
            Write-Host "$name. $($catalog[$name].Hint)"
        }
        $Tool = Read-Host 'Strumento da collegare'
    }
    if (-not $catalog.ContainsKey($Tool)) { throw "Strumento sconosciuto: $Tool. Avvia Link senza Tool per vedere le scelte." }
    $entry = $catalog[$Tool]
    if (-not $entry.Environment) { throw $entry.Hint }
    Write-Host $entry.Hint
    if ([string]::IsNullOrWhiteSpace($Path)) { $Path = Read-Host 'Percorso esistente' }
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path -match '[\x00-\x1f]') { throw 'Percorso non valido. Specifica un percorso locale esistente.' }
    $item = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $item -or $item.PSProvider.Name -ne 'FileSystem') { throw "Percorso inesistente o non filesystem: $Path" }
    $resolved = $item.FullName
    if (-not (Test-Path -LiteralPath $resolved -PathType $entry.PathType)) { throw "Tipo di percorso errato per $Tool. $($entry.Hint)" }
    if ($entry.Extension -and $resolved -notmatch $entry.Extension) { throw "Tipo di file errato per $Tool. $($entry.Hint)" }
    foreach ($file in $entry.RequiredFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $resolved $file) -PathType Leaf)) { throw "Installazione $Tool incompleta. File richiesto: $file" }
    }
    if ($Tool -eq 'Ghidra') {
        $manifest = @(Get-ToolManifest | Where-Object { $_.Name -eq 'Ghidra' })[0]
        Assert-ToolVersion $manifest $resolved
    }
    if ($Tool -eq 'Java') {
        $release = Get-Content -LiteralPath (Join-Path $resolved 'release') -Raw
        if ($release -notmatch '(?m)^JAVA_VERSION="(\d+)(?:\.|\")' -or [int]$Matches[1] -lt 17) { throw 'Occorre un JDK completo Java 17 o successivo. Ghidra richiede 21+.' }
    }
    if ($Tool -eq 'Ida') {
        if ($item.Length -gt 65536) { throw 'La registrazione MCP IDA supera 64 KiB.' }
        try { $registration = Get-Content -LiteralPath $resolved -Raw | ConvertFrom-Json } catch { throw 'Registrazione MCP IDA JSON non valida.' }
        if ($registration.mcpServers) { $registration = $registration.mcpServers.'ida-pro-mcp' }
        if ($null -eq $registration -or $registration -isnot [pscustomobject] -or (-not $registration.command -and -not $registration.url)) { throw 'Il JSON deve contenere una registrazione MCP IDA con command/args oppure url. Usa poi Doctor per la validazione completa.' }
    }
    return [pscustomobject]@{ Tool=$Tool; Environment=$entry.Environment; Path=$resolved }
}

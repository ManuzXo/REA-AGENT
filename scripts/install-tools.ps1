[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet('Jadx','Adb','Apktool','Wabt','Node','Java','Browser','Python','Rizin','Ida','Jeb','Hopper','Linux','Frida','Tshark','Binwalk','Unblob','Sigrok','Pwntools','Mitmproxy','Objdump','Gdb','Capinfos','Wakaru','Cutter','Ilspy','Pwndbg','Kuna')][string]$Tool,
    [ValidateSet('Install','Instructions')][string]$Mode = 'Install',
    [string]$ToolsDirectory
)

$ErrorActionPreference = 'Stop'

function Get-OptionalToolCatalog {
    @{
        Jadx = @{ Kind='Jar'; Version='0.7.1'; Url='https://github.com/1013503897/jadx-headless-mcp/releases/download/v0.7.1/jadx-headless-mcp-0.7.1-all.jar'; Hash='6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75'; Directory='jadx-headless-mcp-0.7.1'; FileName='jadx-headless-mcp-0.7.1-all.jar'; Required=@('jadx-headless-mcp-0.7.1-all.jar'); Environment='REA_JADX_MCP_JAR'; EnvironmentPath='jadx-headless-mcp-0.7.1-all.jar'; Hint='Motore headless MCP richiesto da REA: richiede JDK completo 17+. Configura il profilo android.' }
        Wabt = @{ Kind='Archive'; Version='1.0.42'; Url='https://github.com/WebAssembly/wabt/releases/download/1.0.42/wabt-1.0.42-windows-x64.tar.gz'; Hash='62f1eb2b51aa57cf0f0b8ba333bf2c72a049930aa9c5de01dcad271c4fe48c88'; Directory='wabt-1.0.42'; Required=@('bin/wasm2wat.exe','bin/wasm-objdump.exe'); Environment='REA_WABT_BIN_DIRECTORY'; EnvironmentPath='bin'; Hint='Configura la cartella bin nel profilo offline-tools.' }
        Apktool = @{ Kind='Jar'; Version='3.0.3'; Url='https://github.com/iBotPeaches/Apktool/releases/download/v3.0.3/apktool_3.0.3.jar'; Hash='dbf930b076c6b9be08d57c449cacefc3bdd6b71ebd59b3066fc0e1f5b14f9423'; Directory='apktool-3.0.3'; FileName='apktool.jar'; Required=@('apktool.jar','apktool.cmd'); Environment='REA_APKTOOL_COMMAND'; EnvironmentPath='apktool.cmd'; Hint='Richiede Java compatibile con APKTool 3. Configura il launcher apktool.cmd nel profilo android.' }
        Node = @{ Kind='Winget'; Package='OpenJS.NodeJS.LTS'; Url='https://nodejs.org/en/download'; Hint='Riapri il terminale e verifica node --version e npx.cmd --version. REA richiede 22.19+, 24.11+ o >=26.' }
        Java = @{ Kind='Winget'; Package='EclipseAdoptium.Temurin.21.JDK'; Url='https://adoptium.net/installation/'; Hint='JDK completo Java 21 per JADX, Apktool e Ghidra. Alternativa separata dal download Ghidra. Riapri il terminale e configura JAVA_HOME nel profilo con la directory installata. Verifica java -version e javac -version.' }
        Browser = @{ Kind='Winget'; Package='Google.Chrome'; Url='https://www.google.com/chrome/'; Hint='Chrome per il provider browser. Configura REA_BROWSER_EXECUTABLE nel profilo browser.' }
        Python = @{ Kind='Winget'; Package='Python.Python.3.13'; Url='https://www.python.org/downloads/windows/'; Hint='Riapri il terminale. Usa ambienti virtuali per gli strumenti Python opzionali su un host supportato. I binding Frida di REA sono Node, non Python.' }
        Adb = @{ Kind='Manual'; Url='https://developer.android.com/tools/releases/platform-tools'; Hint='Leggi e accetta la licenza Android SDK sul sito ufficiale, scarica Platform-Tools Windows ed estrai in .tools\platform-tools. Configura il percorso adb.exe nel profilo android. Il setup non accetta la licenza e non collega dispositivi.' }
        Rizin = @{ Kind='Manual'; Url='https://github.com/rizinorg/rizin/releases'; Hint='Rizin e caller-supplied: scegli il pacchetto ufficiale per il tuo sistema, verifica il checksum pubblicato e configura REA_RIZIN_COMMAND. Verifica compatibilita e limiti della piattaforma nella guida REA.' }
        Ida = @{ Kind='Manual'; Url='https://hex-rays.com/ida-pro'; Hint='Scarica una versione IDA compatibile con REA dal tuo account e completa licenza e installazione. Configura REA_IDA_MCP_CONFIG con la registrazione del server MCP IDA; controlla la versione supportata con rea doctor --provider ida. Nessuna licenza acquistata dal setup.' }
        Jeb = @{ Kind='Manual'; Url='https://www.pnfsoftware.com/jeb/'; Hint='Installa JEB dal produttore e attiva la tua licenza. Avvia MCP da File nel client JEB e configura REA_JEB_MCP_URL (default http://127.0.0.1:8425/mcp); verifica con inspect-jeb-client.' }
        Hopper = @{ Kind='Manual'; Url='https://www.hopperapp.com/'; Hint='Hopper richiede macOS o Linux e la relativa licenza. Non e un installer Windows. Configura il provider sulla macchina supportata seguendo la guida e verifica rea doctor --provider hopper.' }
        Linux = @{ Kind='Manual'; Url='https://learn.microsoft.com/windows/wsl/install'; Hint='Per funzioni REA specifiche Linux usa una VM Linux isolata, oppure valuta WSL2 leggendo i requisiti. Il setup non abilita WSL, non riavvia Windows e non avvia campioni. Installa REA e configura i percorsi dentro Linux.' }
        Frida = @{ Kind='Manual'; Url='https://frida.re/docs/installation/'; Hint='REA carica i binding Node Frida come dipendenza npm opzionale. Non usare npm con --omit=optional per questo profilo. frida-tools Python e una CLI separata, non sostituisce i binding Node. Per device remoti installa frida-server compatibile sul dispositivo autorizzato seguendo la guida ufficiale: il setup non lo installa e non esegue attach/spawn.' }
        Tshark = @{ Kind='Manual'; Url='https://www.wireshark.org/docs/man-pages/tshark.html'; Hint='Il provider REA richiede TShark 4.x su Linux e util-linux prlimit. In una VM Debian/Ubuntu: sudo apt install tshark util-linux. Valuta prima le richieste del gestore pacchetti sui privilegi di cattura. Configura REA_TSHARK_COMMAND=/usr/bin/tshark nel profilo Linux; analizza registrazioni esistenti.' }
        Capinfos = @{ Kind='Manual'; Url='https://www.wireshark.org/docs/man-pages/capinfos.html'; Hint='Capinfos fa parte degli strumenti Wireshark. Installa il pacchetto della distribuzione Linux, verifica capinfos --version e configura il profilo registrazioni PCAP. Nessuna cattura di rete viene avviata dal setup.' }
        Binwalk = @{ Kind='Manual'; Url='https://github.com/ReFirmLabs/binwalk'; Hint='Provider firmware esterno su Linux. Segui la build/installazione Binwalk ufficiale e verifica versione e dipendenze richieste da REA. Non sostituire automaticamente il pacchetto di sistema con pip; configura REA_BINWALK_COMMAND nel profilo Linux.' }
        Unblob = @{ Kind='Manual'; Url='https://unblob.org/installation/'; Hint='Unblob richiede Linux e dipendenze di estrazione native. Segui la guida ufficiale, usa un ambiente isolato per firmware non fidati e configura il comando nel profilo Linux. Il setup Windows non installa tool di estrazione globali.' }
        Sigrok = @{ Kind='Manual'; Url='https://sigrok.org/wiki/Downloads'; Hint='REA richiede sigrok-cli 0.7.2 con libsigrokdecode su Linux e util-linux prlimit. Installa i pacchetti della distribuzione, verifica sigrok-cli --version e configura REA_SIGROK_COMMAND. Si analizzano registrazioni esistenti; nessun hardware viene avviato.' }
        Pwntools = @{ Kind='Manual'; Url='https://docs.pwntools.com/en/stable/install.html'; Hint='Usa Linux e un ambiente virtuale Python dedicato. Segui i prerequisiti ufficiali pwntools, poi python3 -m venv .venv e .venv/bin/python -m pip install pwntools==4.15.0 pyelftools==0.33 unicorn==2.1.2. Configura REA_PWNTOOLS_PYTHON con .venv/bin/python assoluto. Il setup non esegue script o payload.' }
        Mitmproxy = @{ Kind='Manual'; Url='https://docs.mitmproxy.org/stable/overview/installation/'; Hint='Per gli adattatori REA Linux segui la versione e i prerequisiti descritti nella guida del profilo. Installa mitmproxy seguendo la guida ufficiale. Il setup non avvia proxy, modifica impostazioni di rete o installa certificati.' }
        Objdump = @{ Kind='Manual'; Url='https://www.gnu.org/software/binutils/'; Hint='Provider esterno Linux: installa binutils dalla distribuzione, ad esempio sudo apt install binutils, verifica objdump --version e configura il profilo. Per altre architetture scegli il toolchain binutils corrispondente al campione.' }
        Gdb = @{ Kind='Manual'; Url='https://www.sourceware.org/gdb/'; Hint='Provider esterno Linux: installa GDB e i prerequisiti REA della guida, ad esempio sudo apt install gdb util-linux. Verifica gdb --version e configura il profilo Linux. Il setup non esegue o collega processi.' }
        Wakaru = @{ Kind='Manual'; Url='https://github.com/pionxzh/wakaru/releases/tag/v1.14.0'; Hint='REA richiede il binario standalone Linux x64 Wakaru ^1.13, verificato con 1.14.0, e util-linux prlimit. Scarica la release ufficiale verificandone il checksum, configura REA_WAKARU_COMMAND con il percorso assoluto. Il setup Windows non esegue il binario Linux.' }
        Cutter = @{ Kind='Manual'; Url='https://cutter.re/'; Hint='Installa Cutter dal sito ufficiale. Il collegamento REA richiede il suo bridge Python v2: segui docs/reverse-engineering-tools.md upstream, configura REA_CUTTER_BRIDGE_DIR e abilita il bridge nella GUI. Il setup non avvia GUI o campioni.' }
        Ilspy = @{ Kind='Manual'; Url='https://github.com/icsharpcode/ILSpy'; Hint='L analisi CIL statica integrata in REA non richiede .NET. ILSpy CLI e opzionale: segui installazione ufficiale di ilspycmd e runtime .NET richiesto dalla versione, configura REA_ILSPY_CMD_PATH con il comando assoluto. Nessuna installazione .NET automatica.' }
        Pwndbg = @{ Kind='Manual'; Url='https://pwndbg.re/pwndbg/latest/setup/'; Hint='Estensione GDB su Linux: segui il metodo ufficiale per la tua distribuzione, poi configura il profilo offline-tools. Il setup non esegue installer shell remoti o avvia sessioni GDB.' }
        Kuna = @{ Kind='Manual'; Url='https://github.com/morluto/rea/blob/main/docs/kuna-provider.md'; Hint='Funzionalita documentata sul branch main upstream, non disponibile nel pacchetto REA 6.5.0 fissato qui. Consulta la guida e verifica release, piattaforma e licenza prima di configurarla; questo installer non registra un provider non disponibile.' }
    }
}

function Get-InstalledToolFiles([string]$Path) {
    @(Get-ChildItem -LiteralPath $Path -File -Recurse | Where-Object { $_.Name -ne '.rea-install.json' } | ForEach-Object {
        @{ Path=$_.FullName.Substring($Path.TrimEnd('\').Length + 1); Hash=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
    })
}

function Assert-PortableTool($Entry, [string]$Path) {
    foreach ($required in $Entry.Required) {
        if (-not (Test-Path -LiteralPath (Join-Path $Path $required) -PathType Leaf)) { throw "Installazione incompleta: $Path ($required)." }
    }
    $receiptPath = Join-Path $Path '.rea-install.json'
    if (-not (Test-Path -LiteralPath $receiptPath -PathType Leaf)) { throw "Destinazione non gestita dal setup: $Path. Scegli una cartella diversa." }
    $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
    if ($receipt.ArchiveHash -ne $Entry.Hash -or $receipt.Version -ne $Entry.Version) { throw "Metadati incompatibili: $Path." }
    $actual = @(Get-InstalledToolFiles $Path)
    if ($actual.Count -ne @($receipt.Files).Count) { throw "File modificati in $Path." }
    foreach ($file in $actual) {
        $expected = @($receipt.Files | Where-Object { $_.Path -eq $file.Path })
        if ($expected.Count -ne 1 -or $expected[0].Hash -ne $file.Hash) { throw "File modificato: $($file.Path). Nessuna sovrascrittura." }
    }
}

function Install-PortableTool($Entry, [string]$Root) {
    $Root = [IO.Path]::GetFullPath($Root).TrimEnd('\','/')
    if (-not $Root -or $Root -eq [IO.Path]::GetPathRoot($Root).TrimEnd('\','/')) { throw 'Scegli una sottocartella, non la radice del volume.' }
    $destination = Join-Path $Root $Entry.Directory
    if (Test-Path -LiteralPath $destination) { Assert-PortableTool $Entry $destination; return $destination }
    $staging = Join-Path $Root ('.staging-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $staging -Force | Out-Null
    try {
        $download = Join-Path $staging 'download'
        Invoke-WebRequest -Uri $Entry.Url -OutFile $download -UseBasicParsing
        if ((Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash -ne $Entry.Hash) { throw 'SHA-256 non valido. Download rifiutato prima di estrarre o eseguire file.' }
        $expanded = Join-Path $staging 'expanded'
        New-Item -ItemType Directory -Path $expanded | Out-Null
        if ($Entry.Kind -eq 'Jar') {
            Move-Item -LiteralPath $download -Destination (Join-Path $expanded $Entry.FileName)
            if ($Entry.Environment -eq 'REA_APKTOOL_COMMAND') {
                Set-Content -LiteralPath (Join-Path $expanded 'apktool.cmd') -Encoding ASCII -Value '@echo off', 'if defined JAVA_HOME (', '  "%JAVA_HOME%\bin\java.exe" -jar "%~dp0apktool.jar" %*', ') else (', '  java -jar "%~dp0apktool.jar" %*', ')', 'exit /b %ERRORLEVEL%'
            }
            $candidate = $expanded
        } else {
            & tar.exe --no-same-owner --no-same-permissions -xf $download -C $expanded
            if ($LASTEXITCODE -ne 0) { throw "Estrazione fallita: $LASTEXITCODE." }
            $candidates = @($expanded) + @(Get-ChildItem -LiteralPath $expanded -Directory | ForEach-Object { $_.FullName })
            $valid = @($candidates | Where-Object { $path=$_; @($Entry.Required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $path $_) -PathType Leaf) }).Count -eq 0 })
            if ($valid.Count -ne 1) { throw 'Struttura archivio inattesa.' }
            $candidate = $valid[0]
        }
        @{ Version=$Entry.Version; ArchiveHash=$Entry.Hash; Files=@(Get-InstalledToolFiles $candidate) } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $candidate '.rea-install.json') -Encoding UTF8
        Assert-PortableTool $Entry $candidate
        if (Test-Path -LiteralPath $destination) { throw 'Destinazione creata da un altro processo. Ripeti il setup.' }
        [IO.Directory]::Move($candidate, $destination)
        return $destination
    } finally {
        $resolvedStaging = [IO.Path]::GetFullPath($staging)
        if ((Split-Path $resolvedStaging -Parent) -ne $Root -or (Split-Path $resolvedStaging -Leaf) -notlike '.staging-*') { throw 'Percorso staging non valido.' }
        if (Test-Path -LiteralPath $resolvedStaging) { Remove-Item -LiteralPath $resolvedStaging -Recurse -Force }
    }
}

function Invoke-OptionalToolInstaller([string]$Tool, [string]$Mode='Install', [string]$ToolsDirectory) {
    $entry = (Get-OptionalToolCatalog)[$Tool]
    if (-not $entry) { throw "Strumento sconosciuto: $Tool." }
    Write-Host "$Tool - $($entry.Url)"
    Write-Host $entry.Hint
    if ($Mode -eq 'Instructions' -or $entry.Kind -eq 'Manual') {
        Write-Host 'Istruzioni mostrate. Nessuna installazione automatica effettuata.'
        return
    }
    if ($entry.Kind -eq 'Winget') {
        if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) { throw "winget non disponibile. Usa l'installer ufficiale: $($entry.Url)" }
        Write-Host "Pacchetto winget: $($entry.Package), versione disponibile nella sorgente winget. Eventuali licenze saranno presentate da winget."
        Write-Host 'Installer di sistema: puo richiedere UAC e modificare PATH. Non viene forzata l accettazione degli accordi.'
    } else {
        if (-not $ToolsDirectory) { $ToolsDirectory = Join-Path (Split-Path $PSScriptRoot -Parent) '.tools' }
        if ($entry.Kind -eq 'Archive' -and -not (Get-Command tar.exe -ErrorAction SilentlyContinue)) { throw 'Occorre tar.exe (Windows 10/11 aggiornato).' }
        Write-Host "Versione: $($entry.Version); SHA-256: $($entry.Hash)"
        Write-Host "Destinazione: $(Join-Path $ToolsDirectory $entry.Directory)"
    }
    if ((Read-Host 'Procedere con installazione o riutilizzo verificato? [s/N]') -notmatch '^(s|si|y|yes)$') { Write-Host 'Installazione annullata.'; return }
    if ($entry.Kind -eq 'Winget') {
        & winget.exe install --id $entry.Package --exact --source winget
        if ($LASTEXITCODE -ne 0) { throw "winget ha restituito $LASTEXITCODE. Controlla il suo messaggio; nessun profilo REA modificato." }
        Write-Host 'Installazione winget completata. Riapri il terminale e configura il profilo REA.'
        return
    }
    $installed = Install-PortableTool $entry $ToolsDirectory
    Write-Host "Installazione verificata: $installed"
    foreach ($required in $entry.Required) { Write-Host (Join-Path $installed $required) }
    if ($entry.Environment) { Write-Host ('$env:' + $entry.Environment + ' = ' + [char]39 + (Join-Path $installed $entry.EnvironmentPath) + [char]39) }
    Write-Host 'Ora esegui setup.bat e configura il profilo REA. PATH e MCP non sono stati modificati da questo installer.'
    return $installed
}

if ($MyInvocation.InvocationName -ne '.') {
    try { Invoke-OptionalToolInstaller @PSBoundParameters }
    catch { Write-Error $_ -ErrorAction Continue; exit 1 }
}

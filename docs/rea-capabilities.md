# Funzionalità di REA e requisiti

Questo repository prepara configurazioni per `rea-agents@6.5.0`. REA fornisce un server MCP e una CLI. Ghidra, JADX e gli altri programmi sono strumenti esterni opzionali.

L'inventario sotto deriva dai contratti del pacchetto npm 6.5.0 presente durante la verifica del 15 ottobre 2026. La presenza di un comando non dimostra che il programma esterno sia installato o che il workflow funzioni sul computer corrente. `binary_session` restituisce la disponibilità effettiva delle operazioni. Il [catalogo ufficiale](https://github.com/morluto/rea/blob/main/docs/mcp-contracts.md#generated-catalog) descrive `main`, che può contenere modifiche successive alla release.

## Funzioni incluse nel pacchetto

| Utilizzo | Funzioni | Configurazione aggiuntiva e limiti |
| --- | --- | --- |
| JavaScript statico | Moduli, import, mappe sorgenti, semantica, IPC Electron, confronto sorgenti e bundle, confronto versioni. | Node.js. Su Linux serve `ps` compatibile con procps. Non esegue l'applicazione. |
| Archivi e risorse | Inventario, estrazione, hash, PE resources, plist, keyed archive, Interface Builder e asset catalog. | Alcune decodifiche Apple dipendono dagli strumenti di macOS. La disponibilità dipende dal formato e dall'operazione. |
| Grafi di applicazione | Android, Apple, macOS, HarmonyOS, collegamenti gestiti e nativi. | Usa Evidence precedentemente raccolte. HarmonyOS identifica HAP, HSP e App Pack senza decompilare Ark bytecode. |
| .NET | Metadata PE/CLI, tipi, CIL, stringhe, dipendenze native dichiarate, confronti e importazione di ricostruzioni. | Lettura statica inclusa. `REA_ILSPY_CMD_PATH` seleziona un eventuale `ilspycmd` esterno. Non installare .NET per la sola lettura dei metadata. |
| Go e Rust | Informazioni di build Go e dipendenze cargo-auditable Rust. | Lettura statica inclusa. Non occorrono Go o Rust. |
| Flutter e Dart AOT | Identità build, snapshot, librerie per ABI, provenienza del motore. | Lettura statica APK inclusa. Non equivale a recuperare il sorgente Dart. |
| SQLite | Schema e righe selezionate di database e snapshot WAL. | Node.js 24.15 o successivo della linea 24, oppure 26+. Node.js 22 soddisfa REA ma non questo workflow. |
| Catture HTTP salvate | HAR 1.2 e SAZ Fiddler, payload esposti, confronto e API derivate. | Lettura inclusa. Fiddler non è necessario per leggere SAZ. Native mitmproxy richiede il programma esterno sotto. |
| EVM offline | Selettori, offset, argomenti e mutabilità inferiti da bytecode locale. | Profilo incluso, verificato su Linux x64. Nessun endpoint blockchain. |
| Evidence e ricostruzione | Esportazione, importazione, confronti, tracciamento feature, obblighi di ricostruzione, gestione delle incognite e verifica della copertura. | Nessun motore aggiuntivo per manipolare Evidence già disponibili. Le analisi necessarie richiedono i rispettivi provider. |

## Motori e programmi esterni

| Strumento | Utilizzo | Variabili | Host e versione richiesta |
| --- | --- | --- | --- |
| Ghidra | Decompilazione, assembly, funzioni, riferimenti, annotazioni e analisi native. | `GHIDRA_INSTALL_DIR`, `JAVA_HOME`. | Ghidra 12.1.x, verificato 12.1.4 e JDK 21. Windows x64 sperimentale P0, Linux e macOS. |
| Hopper | Analisi nativa con database e GUI Hopper. | `HOPPER_LAUNCHER_PATH`, `HOPPER_TARGET_PATH`, `HOPPER_TARGET_KIND`, `HOPPER_LOADER_ARGS_JSON`. | macOS e Linux. Licenza o demo del produttore. Installazione opzionale tramite `rea setup` sui sistemi supportati. |
| IDA | Analisi nativa tramite MCP upstream collegato alla GUI o headless. | `REA_IDA_MCP_CONFIG`, eventuale `IDADIR` nella configurazione upstream. | Installazione e licenza fornite dall'utente. Attached legacy 1.4.0 oppure supervisor headless con `idb_open`, `idb_list`, `idb_close`. Ponte nativo IDA Free separato e sperimentale. |
| JADX | Manifest, classi, metodi Java o smali e riferimenti APK. | `REA_JADX_MCP_JAR`, `JAVA_HOME`, opzionali `REA_JADX_HEAP_MIB`, `REA_JADX_ACTIVE_PROCESSOR_COUNT`. | `jadx-headless-mcp` 0.7.1 e JDK completo 17+. Linux, macOS e Windows x64 con controlli nativi inclusi nel pacchetto. |
| Android Platform Tools | Dispositivi, pacchetti, processi, log, schermate, trasferimenti e operazioni sui dispositivi. | `REA_ADB_PATH` oppure `adb` nel `PATH`. | Client adb fornito dall'utente. USB, autorizzazione del dispositivo e seriale dipendono dall'operazione. |
| Apktool | Decodifica delle risorse Android. | `REA_APKTOOL_COMMAND` oppure `apktool` nel `PATH`. | Apktool 2.7.0 o successivo e Java. Accetta launcher BAT Windows. |
| JEB | Progetti, unità e decompilazione dal server MCP JEB. | `REA_JEB_MCP_URL`. | Client JEB già avviato con MCP. Default `http://127.0.0.1:8425/mcp`. REA non avvia JEB. |
| Browser Chromium | CDP, DOM, script, screenshot, osservazione e scenari Playwright. | `REA_BROWSER_EXECUTABLE` per le operazioni che avviano il browser o risolvono moduli. Endpoint CDP passato alla singola richiesta per attach. | Chrome, Edge, Chromium o altro browser compatibile. Profilo dedicato e porta di debug loopback. Playwright Core è incluso, il browser è separato. |
| Electron e V8 Inspector | Osservazione renderer, main process, runtime JavaScript e scenari Electron. | Endpoint e percorso dell'applicazione selezionati nella richiesta. | L'attach richiede un target già avviato con il relativo debug. Gli scenari avviano e pilotano il target. |
| Frida | Dispositivi, processi, attach o spawn, script di strumentazione. | Selezione dispositivo e opzioni remote nella singola richiesta. | Binding Node Frida 17.23.2 opzionale incluso come dipendenza. Frida server sul dispositivo resta esterno. Compatibilità e permessi dipendono dal target. |
| GNU objdump | Header, sezioni, simboli, relocazioni, DWARF e disassembly offline. | `REA_OBJDUMP_COMMAND` oppure `objdump` nel `PATH`. | GNU binutils. Le architetture dipendono dalla build installata. |
| Rizin | Comandi statici e debugger. | `REA_RIZIN_COMMAND` oppure `rizin` nel `PATH`. | Analisi statica dipendente dalla build. Debug persistente solo Linux con TTY esplicito. |
| Cutter | Comandi nella sessione GUI tramite ponte Python REA. | `REA_CUTTER_BRIDGE_DIR`. | Plugin REA e client devono usare l'handshake v2. Installazione manuale del plugin nel Cutter fornito dall'utente. |
| GDB e pwndbg | Debug persistente o CLI, analisi aggiuntiva di crash registrati. | `REA_GDB_COMMAND`, `REA_PWNDBG_GDB`, `REA_PWNDBG_GDBINIT`, `REA_PWNDBG_VENV_PATH`. | GDB persistente solo Linux. TTY durevole esplicito. pwndbg opzionale. |
| pwntools | Layout ELF e crash Linux registrati. | `REA_PWNTOOLS_PYTHON`, opzionale `REA_PWNTOOLS_MAX_INPUT_BYTES`. | Linux x64, Python con pwntools 4.15.0, pyelftools 0.33 e Unicorn 2.1.2. |
| WABT | Validazione WASM, sezioni, import, export e WAT. | `REA_WABT_BIN_DIRECTORY`. | WABT 1.0.42. La variabile indica la directory degli eseguibili. |
| Wakaru | Recupero di moduli leggibili da bundle JavaScript. | `REA_WAKARU_COMMAND`, `REA_JAVASCRIPT_PRLIMIT_COMMAND`. | Linux x64, Wakaru ^1.13.0, verificato 1.14.0, e `prlimit`. |
| Binwalk e Unblob | Regioni firmware ed estrazione. | `REA_BINWALK_COMMAND`, `REA_UNBLOB_COMMAND`, `REA_FIRMWARE_PRLIMIT_COMMAND`. | Linux, Binwalk 3.1.x e Unblob 26.6.x, verificati 3.1.0 e 26.6.4. `prlimit` ed estrattori del formato. |
| Wireshark CLI | Sommari PCAP e campi selezionati dei pacchetti. | `REA_TSHARK_COMMAND`, `REA_CAPINFOS_COMMAND`, `REA_TSHARK_PRLIMIT_COMMAND`. | TShark e capinfos 4.x. Sommari verificati Linux. Lettura campi e catture limitata a Linux con `prlimit`. |
| mitmdump | Decodifica dei file nativi mitmproxy. | `REA_MITMDUMP_COMMAND`. | Linux, mitmdump 12.2.3. HAR e SAZ non richiedono questo programma. |
| sigrok-cli | Decoder e annotazioni di registrazioni logiche. | `REA_SIGROK_COMMAND`, `REA_SIGROK_PRLIMIT_COMMAND`. | Linux, sigrok-cli 0.7.2 con libsigrokdecode e `prlimit`. Non acquisisce segnali hardware. |
| Strumenti Apple | Mach-O, firme, Objective-C, Swift, UI e chiamate native macOS. | `REA_DARWIN_SWIFTC_PATH`, `REA_DARWIN_MODULE_CACHE_PATH` per override del compilatore Swift. | Le operazioni dinamiche Apple richiedono macOS e relativi strumenti di sviluppo. |
| PTY nativo | Cattura e confronto degli scenari di processi. | Ambiente e azioni dichiarati nella richiesta. | Linux o macOS. Windows non supportato da questo workflow. |

Le guide ufficiali descrivono [motori nativi](https://github.com/morluto/rea/blob/main/docs/installation.md), [IDA](https://github.com/morluto/rea/blob/main/docs/ida-provider.md), [Android](https://github.com/morluto/rea/blob/main/docs/android-analysis.md), [strumenti offline e debugger](https://github.com/morluto/rea/blob/main/docs/reverse-engineering-tools.md), [Frida](https://github.com/morluto/rea/blob/main/docs/frida-instrumentation.md), [browser](https://github.com/morluto/rea/blob/main/docs/browser-observation.md), [firmware](https://github.com/morluto/rea/blob/main/docs/firmware-analysis.md) e [segnali](https://github.com/morluto/rea/blob/main/docs/signal-recordings.md).

## Impostazioni comuni

`REA_ANALYSIS_PROVIDER` seleziona `auto`, `ghidra`, `hopper` o `ida` nella release 6.5.0. Più provider compatibili richiedono una scelta esplicita. JADX ha strumenti APK separati.

`REA_GHIDRA_STARTUP_TIMEOUT_MS` e `REA_HOPPER_STARTUP_TIMEOUT_MS` alzano il tempo di avvio per binari grandi. Ghidra ammette anche `REA_GHIDRA_LANGUAGE_ID`, `REA_GHIDRA_COMPILER_SPEC_ID`, `REA_GHIDRA_DISABLED_ANALYZERS`, `REA_GHIDRA_SEED_FILE` e `REA_GHIDRA_NATIVEAOT_JAR`. Il compiler spec richiede un language ID. Non impostare questi override senza una domanda di analisi che li richieda.

`REA_MCP_INPUT_SCHEMA_PROFILE`, `REA_MCP_OUTPUT_SCHEMA_PROFILE` e `REA_MCP_MAX_RESPONSE_BYTES` adattano schemi e dimensione delle risposte al client. `REA_LOG_LEVEL` controlla i log. `REA_REFERENCE_SECRET_PATTERNS_JSON` contiene pattern espliciti per i riferimenti. La [guida MCP upstream](https://github.com/morluto/rea/blob/main/docs/mcp-contracts.md) definisce valori e limiti.

## Diagnostica e confine della release

`doctor --provider` accetta solo `hopper`, `ghidra`, `ida` e `jadx` nel pacchetto 6.5.0. `doctor --client` verifica una registrazione, mentre `doctor --skill` controlla le istruzioni installate. Un controllo generale può fallire per strumenti opzionali non necessari al profilo scelto.

Per gli altri adattatori usa il comando specifico, quando disponibile, per esempio `inspect-adb-client`, `inspect-apktool-client`, `inspect-jeb-client`, `inspect-pcap-client` e `list-objdump-architectures`. Per il server MCP usa `binary_session` prima di aprire un target. Leggi `tool_availability` e le motivazioni restituite.

[Kuna](https://github.com/morluto/rea/blob/main/docs/kuna-provider.md) è documentato su `main` con `REA_KUNA_COMMAND`, ma non appartiene al catalogo del pacchetto 6.5.0 verificato qui. Richiede una release successiva o un build sorgente che lo contenga. Non è un provider utilizzabile con il pin di questo repository. Il provider upstream non supporta ancora Windows.

## Inventario completo del pacchetto 6.5.0

I gruppi seguenti usano i nomi MCP esatti esportati da `dist/contracts/toolContracts.js` del pacchetto npm. La CLI usa spesso nomi con trattini e può avere argomenti diversi. Consulta `rea --help` e l'help del comando prima di costruire uno script.

Per confrontare l'inventario con un pacchetto già disponibile localmente esegui `node scripts/check-documentation.mjs --package PERCORSO_PACCHETTO_REA`. Il controllo legge l'export dei contratti senza rete e segnala nomi mancanti, estranei o duplicati. Senza `--package` verifica i link locali e la nomenclatura del launcher.

### official-proxy

`annotate_native_function`, `inspect_native_load_image`, `inspect_native_data_type`, `inspect_native_instruction`, `resolve_native_call_targets`, `address_name`, `comment`, `current_address`, `current_procedure`, `current_document`, `goto_address`, `inline_comment`, `list_bookmarks`, `list_documents`, `list_names`, `list_procedures`, `list_segments`, `list_strings`, `next_address`, `prev_address`, `procedure_address`, `procedure_assembly`, `procedure_callees`, `procedure_callers`, `procedure_info`, `read_function_instructions`, `search_bytes`, `read_bytes`, `address_to_file_offset`, `procedure_references`, `procedure_pseudo_code`, `resolve_containing_procedure`, `search_procedures`, `search_strings`, `set_address_name`, `set_addresses_names`, `set_bookmark`, `set_comment`, `set_inline_comment`, `unset_bookmark`, `xrefs`.

### enhanced

`inspect_native_dispatch_metadata`, `get_objc_classes`, `get_objc_protocols`, `batch_decompile`, `get_call_graph`, `analyze_swift_types`, `find_xrefs_to_name`, `binary_overview`, `analyze_function`, `inspect_native_api`, `trace_feature`, `trace_call_path`, `trace_native_ui_action`, `trace_native_values`.

### native-provider

`observe_native_ui`, `capture_native_ui_scenario`, `observe_native_calls`, `inspect_macho`, `inspect_signature`, `inspect_plist`, `list_architectures`, `demangle_swift`, `inspect_pe_resources`, `inspect_binary_layout`, `inspect_recorded_crash`, `list_cutter_sessions`, `cutter_command`, `inspect_with_objdump`, `execute_rizin_command`, `start_gdb_session`, `gdb_console`, `gdb_session_status`, `close_gdb_session`, `start_rizin_debug_session`, `rizin_debug_command`, `rizin_debug_session_status`, `close_rizin_debug_session`, `list_frida_devices`, `list_frida_processes`, `start_frida_session`, `load_frida_script`, `resume_frida_session`, `unload_frida_script`, `frida_session_status`, `close_frida_session`, `instrument_with_frida`.

### application

`inspect_analysis_view`, `compare_wasm_interfaces`, `compare_managed_members`, `verify_managed_native_boundaries`, `import_managed_reconstruction`, `project_managed_application_graph`, `trace_application_feature`, `trace_javascript_semantics`, `compare_application_versions`, `compare_source_to_bundle`, `compare_javascript_export_shapes`, `build_reconstruction_obligation_ledger`, `evaluate_reconstruction_coverage`, `project_android_application_graph`, `project_apple_application_graph`, `project_harmony_application_graph`, `trace_web_source_location`, `trace_web_module_imports`, `export_web_scripts`, `recover_javascript_sources`.

### artifact-provider

`inspect_artifact`, `extract_artifact`, `decode_interface_builder`, `inspect_keyed_archive`, `inspect_asset_catalog`, `trace_dylib_resolution`, `inspect_evm_interface`, `inspect_go_binary`, `inspect_rust_binary`, `inspect_wasm_artifact`, `inspect_sqlite_database`, `inspect_packet_fields`, `inspect_packet_capture`, `inspect_signal_decoders`, `decode_signal_recording`, `inspect_electron_fuses`.

### managed-provider

`inspect_managed_artifact`, `inspect_managed_members`, `inspect_managed_native_boundaries`.

### android-provider

`inspect_android_package`, `search_android_classes`, `inspect_android_class`, `inspect_android_method`, `trace_android_references`.

### apktool-provider

`inspect_apktool_client`, `decode_android_resources`.

### pcap-provider

`inspect_pcap_client`, `inspect_pcap_capture`.

### flutter-provider

`identify_flutter_build`, `inspect_dart_aot`.

### jeb-provider

`inspect_jeb_client`, `open_jeb_project`, `list_jeb_units`, `decompile_jeb_item`.

### adb-provider

`inspect_adb_client`, `list_adb_devices`, `inspect_adb_device`, `list_adb_packages`, `pull_adb_package`, `read_adb_logcat`, `inspect_adb_package`, `pull_adb_file`, `push_adb_file`, `capture_adb_screen`, `list_adb_processes`, `list_adb_directory`, `list_adb_features`, `list_adb_services`, `inspect_adb_display`, `inspect_adb_window`, `read_adb_setting`, `collect_adb_bugreport`, `resolve_adb_packages`, `install_adb_package`, `uninstall_adb_package`, `start_adb_app`, `start_adb_activity`, `stop_adb_app`.

### firmware-provider

`inspect_firmware_regions`, `extract_firmware`.

### browser-provider

`list_browser_targets`, `inspect_web_page`, `analyze_web_bundle`, `observe_web_session`, `discover_webmcp_tools`, `compare_web_captures`, `capture_web_screenshot`, `compare_web_screenshots`, `capture_browser_scenario`, `observe_web_execution`, `inspect_web_event_listeners`, `inspect_web_network_capture`.

### electron-provider

`list_electron_targets`, `inspect_electron_page`, `analyze_javascript_application`, `reconcile_javascript_runtime`, `capture_electron_scenario`.

### runtime-provider

`list_javascript_runtime_targets`, `observe_javascript_runtime`.

### session

`open_binary`, `close_binary`, `binary_session`, `export_evidence_bundle`, `import_evidence_bundle`, `capture_process_scenario`, `compare_process_captures`, `compare_artifacts`, `compare_functions`, `compare_bundles`, `find_changed_behavior`, `build_call_path`, `correlate_static_and_runtime`, `verify_reconstruction`, `list_unknowns`, `record_unknown`, `update_unknown`, `verify_unknown_resolution`, `get_evidence_bundle`, `get_navigation_context`, `inspect_address_context`.

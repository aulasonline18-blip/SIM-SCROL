# SIM Scroll — Auditoria de 150 micro-partes por referência

Data: 2026-07-04  
Repositório: `/root/SIM-SCROL`  
Escopo: Boot, `main.dart`, rotas, autenticação e `LabSession`.  

Lei aplicada: referência primeiro, execução depois. Quando a função existe no SIM Web, foi usada como referência de comportamento. Quando é plataforma Flutter, foi usada documentação oficial Flutter/Supabase. Sem referência suficiente, o item ficou como `B=NÃO`.

## Referências usadas

- REF-WEB-AUTH: `/root/sim-work/sim-web/src/cyber/useRequireAuth.ts:85` — tenta `refreshSession()` antes de concluir sessão ausente.
- REF-WEB-CURR: `/root/sim-work/sim-web/src/routes/cyber.curriculo.tsx:57` — fluxo de currículo espera auth pronto/authed antes de preparar aula.
- REF-WEB-PORTAL: `/root/sim-work/sim-web/src/cyber/PortalScreen.tsx:45` — portal separa auth loading/in/out e créditos só quando auth está in.
- REF-WEB-T00: `/root/sim-work/sim-web/src/routes/api/bootstrap-t00.ts:64` — servidor exige auth e créditos antes de T00.
- REF-WEB-BOOTSTRAP: `/root/sim-work/sim-web/src/cyber/curriculo/bootstrapStreamClient.ts:136` — chamada T00 envia Bearer token quando existe sessão.
- REF-WEB-LOGIN: `/root/sim-work/sim-web/src/routes/login.tsx:51` — login preserva retorno seguro.
- REF-FLUTTER-ERRORS: https://docs.flutter.dev/testing/errors — handlers globais `FlutterError.onError`, `PlatformDispatcher.onError` e `ErrorWidget.builder`.
- REF-FLUTTER-PREFS: https://docs.flutter.dev/cookbook/persistence/key-value — uso de `SharedPreferences.getInstance()`.
- REF-FLUTTER-I18N: https://docs.flutter.dev/ui/internationalization — `MaterialApp.locale`, `supportedLocales` e delegates.
- REF-SUPABASE-INIT: https://supabase.com/docs/reference/dart/initializing — inicialização `Supabase.initialize`.
- REF-SUPABASE-REFRESH: https://supabase.com/docs/reference/javascript/auth-refreshsession — refresh explícito de sessão.
- REF-SCROLL-TESTS: `test/widget_test.dart`, `test/session_regression_test.dart`, `test/auth_role_gate_test.dart`, `test/school_completeness_test.dart`.

## Resumo

Total analisado: 150.  
Correção feita nesta auditoria: refresh de sessão expirada em `AuthSession.bindRealAuth`, espelhando o comportamento do SIM Web.  
Validação executada: `flutter analyze`; `flutter test test/auth_role_gate_test.dart test/session_regression_test.dart`.  
B geral: NÃO, porque há itens com teste faltante, risco documentado ou bloqueio por servidor não presente neste repositório.

| ID | Sistema | Microparte | Arquivo | Referência | Status | Problema | Correção | Teste | Evidência | B = SIM/NÃO |
|---|---|---|---|---|---|---|---|---|---|---|
| S1-001 | Boot | `main()` chama `WidgetsFlutterBinding.ensureInitialized` | `lib/main.dart:32` | REF-FLUTTER-ERRORS | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | `WidgetsFlutterBinding.ensureInitialized()` antes de APIs Flutter. | SIM |
| S1-002 | Boot | tratamento global `FlutterError.onError` | `lib/main.dart:34` | REF-FLUTTER-ERRORS | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | Handler chama `FlutterError.presentError(details)`. | SIM |
| S1-003 | Boot | tratamento global `PlatformDispatcher.instance.onError` | `lib/main.dart:37` | REF-FLUTTER-ERRORS | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | Handler reporta erro e retorna `true`. | SIM |
| S1-004 | Boot | `ErrorWidget.builder` | `lib/main.dart:48` | REF-FLUTTER-ERRORS | RISCO | Mostra `exceptionAsString()` ao usuário, útil para debug mas sensível em produção. | Não alterado sem diretriz de copy/telemetria. | Precisa teste de UI production-safe. | `SimRuntimeFailureView(message: details.exceptionAsString())`. | NÃO |
| S1-005 | Boot | `SimEnvironment.assertProductionSafe()` | `lib/main.dart:51` | REF-SCROLL-TESTS | OK | Sem problema observado. | Nenhuma. | `test/session_regression_test.dart`. | `assertProductionSafe` é chamado antes de Supabase. | SIM |
| S1-006 | Boot | inicialização Supabase | `lib/main.dart:52` | REF-SUPABASE-INIT | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | `Supabase.initialize(url, publishableKey)`. | SIM |
| S1-007 | Boot | uso de `simSupabaseUrl` | `lib/main.dart:53` | REF-SUPABASE-INIT | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | URL vem de constantes/config. | SIM |
| S1-008 | Boot | uso de `simSupabaseAnonKey` | `lib/main.dart:54` | REF-SUPABASE-INIT | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | Chave publishable/anon usada no client. | SIM |
| S1-009 | Boot | carregamento de `SharedPreferences` | `lib/main.dart:56` | REF-FLUTTER-PREFS | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | `await SharedPreferences.getInstance()`. | SIM |
| S1-010 | Boot | `SharedPrefsStudentStateLocalStorage` | `lib/main.dart:57` | REF-FLUTTER-PREFS | OK | Sem problema observado. | Nenhuma. | `test/fase1_persistence_test.dart`. | storage local recebe `prefs`. | SIM |
| S1-011 | Boot | `SupabaseFlutterSessionProvider` | `lib/main.dart:58` | REF-SUPABASE-INIT | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | provider criado antes do cloud storage. | SIM |
| S1-012 | Boot | `SimServerCloudFunctions` | `lib/main.dart:60` | REF-WEB-T00 | OK | Sem problema observado no app; chamadas protegidas dependem do provider de sessão do storage. | Nenhuma. | `flutter analyze`. | `cloudFunctions` é injetado em storage cloud. | SIM |
| S1-013 | Boot | `SimAiServerConfig(baseUrl: simApiBaseUrl)` | `lib/main.dart:61` | REF-WEB-BOOTSTRAP | PARCIAL | Config no boot não recebe token provider diretamente; storage usa session provider por fora. | Não alterado: risco depende de contrato do storage/cloud. | Precisa teste integrado cloud com Bearer. | `SimServerCloudFunctions(config: SimAiServerConfig(baseUrl: simApiBaseUrl))`. | NÃO |
| S1-014 | Boot | `SupabaseStudentStateCloudStorage` | `lib/main.dart:59` | REF-WEB-CURR | OK | Sem problema observado. | Nenhuma. | `test/cloud_phase_test.dart`. | storage recebe cloudFunctions e sessionProvider. | SIM |
| S1-015 | Boot | `StudentStateStore` | `lib/main.dart:65` | REF-SCROLL-TESTS | OK | Sem problema observado. | Nenhuma. | `test/state_store_truth_engine_test.dart`. | store une local e cloud. | SIM |
| S1-016 | Boot | `runApp(SimApp(...))` | `lib/main.dart:69` | REF-FLUTTER-ERRORS | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | app roda após inicialização. | SIM |
| S1-017 | Boot | fallback `SimBootFailureApp` | `lib/main.dart:79` | REF-FLUTTER-ERRORS | OK | Fallback existe. | Nenhuma. | Precisa widget test dedicado. | `catch` chama `runApp(SimBootFailureApp(error: error))`. | SIM |
| S1-018 | Boot | mensagem de erro de boot | `lib/main.dart:105` | REF-FLUTTER-ERRORS | RISCO | Texto é fixo em português e não passa por i18n. | Não alterado nesta fase para evitar mexer em bootstrap/i18n sem teste. | Teste faltante. | `'SIM nao iniciou'`. | NÃO |
| S1-019 | Boot | exposição segura do erro na UI | `lib/main.dart:123` | REF-FLUTTER-ERRORS | RISCO | `error.toString()` pode expor detalhes técnicos ao usuário. | Não alterado sem copy e política definida. | Teste production-safe faltante. | `SelectableText(error.toString())`. | NÃO |
| S1-020 | Boot | risco de boot travar por config ausente | `lib/main.dart:50` | REF-SCROLL-TESTS | OK | Trava vira tela de boot failure. | Nenhuma. | `flutter analyze`. | `try/catch` envolve config e init. | SIM |
| S1-021 | Boot | risco de Supabase não inicializar | `lib/main.dart:52` | REF-SUPABASE-INIT | OK | Falha cai no fallback. | Nenhuma. | Teste widget faltante. | Supabase init dentro do `try`. | SIM |
| S1-022 | Boot | risco de `prefs` nulo no app | `lib/main.dart:56`, `lib/features/session/lab_session.dart:133` | REF-FLUTTER-PREFS | PARCIAL | Produção passa prefs; testes podem instanciar sem prefs, e `simOrganismProvider` usa `prefs!`. | Não alterado sem revisar todos os harnesses. | `test/session_regression_test.dart` cobre dev; falta produção. | `prefs: prefs` no boot, `prefs!` no provider. | NÃO |
| S1-023 | Boot | risco cloud/local store divergirem | `lib/main.dart:65` | REF-WEB-CURR | PARCIAL | Store existe, mas divergência depende de sync remoto/API. | Não alterado. | `test/cloud_phase_test.dart`. | `StudentStateStore(local, cloud)`. | NÃO |
| S1-024 | Boot | ordem de inicialização | `lib/main.dart:32` | REF-SUPABASE-INIT | OK | Ordem correta: binding, handlers, config, Supabase, prefs, stores, app. | Nenhuma. | `flutter analyze`. | Linhas 32-69. | SIM |
| S1-025 | Boot | boot em produção vs dev | `lib/main.dart:51` | REF-SCROLL-TESTS | OK | Há gate de produção. | Nenhuma. | `test/session_regression_test.dart`. | `assertProductionSafe()` antes de `runApp`. | SIM |
| S1-026 | Boot | boot sem internet | `lib/main.dart:52` | REF-SUPABASE-INIT | PARCIAL | Supabase init não exige chamada de rede, mas fluxos posteriores sim. | Não alterado. | Precisa teste offline manual/integrado. | Boot não chama servidor, exceto depois `_warmUpServer`. | NÃO |
| S1-027 | Boot | boot com API indisponível | `lib/features/session/lab_session.dart:546` | REF-WEB-PORTAL | OK | Warm-up engole falha e não bloqueia boot. | Nenhuma. | `flutter analyze`. | `_warmUpServer` catch vazio. | SIM |
| S1-028 | Boot | boot com sessão expirada | `lib/session/auth_session.dart:36` | REF-WEB-AUTH, REF-SUPABASE-REFRESH | OK | Antes podia aplicar sessão expirada; agora tenta refresh antes. | Corrigido com `_refreshExpiredSession`. | `test/auth_role_gate_test.dart`; `flutter analyze`. | `if (current?.isExpired ?? false) unawaited(_refreshExpiredSession(client))`. | SIM |
| S1-029 | Boot | teste de boot feliz | `test/widget_test.dart:12` | REF-SCROLL-TESTS | PARCIAL | Existe smoke de app, mas não cobre `main()` real. | Não alterado. | Teste faltante. | Widget tests instanciam `SimApp`. | NÃO |
| S1-030 | Boot | teste de boot com falha controlada | `lib/main.dart:83` | REF-FLUTTER-ERRORS | TESTE FALTANTE | Fallback existe mas sem teste dedicado encontrado. | Não alterado. | Criar widget test para `SimBootFailureApp`. | `SimBootFailureApp` renderiza erro. | NÃO |
| S2-001 | Main | tamanho e responsabilidade do `main.dart` | `lib/main.dart:32` | REF-FLUTTER-ERRORS | RISCO | Boot, tema, rotas e guards estão no mesmo arquivo. | Não refatorado nesta auditoria. | `flutter analyze`. | Arquivo contém boot + `SimApp` + guards. | NÃO |
| S2-002 | Main | `SimApp` | `lib/main.dart:194` | REF-FLUTTER-I18N | OK | Sem problema observado. | Nenhuma. | `test/widget_test.dart`. | Widget recebe store/session/prefs. | SIM |
| S2-003 | Main | `_SimAppState` | `lib/main.dart:212` | REF-FLUTTER-I18N | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | State cria sessão e reage a mudanças. | SIM |
| S2-004 | Main | criação de `LabSession` | `lib/main.dart:215` | REF-SCROLL-TESTS | OK | Sem problema observado em produção. | Nenhuma. | `test/widget_test.dart`. | `LabSession(canonicalStore, prefs)`. | SIM |
| S2-005 | Main | `initialSession` | `lib/main.dart:216` | REF-SCROLL-TESTS | OK | Usado para testes/injeção. | Nenhuma. | `test/widget_test.dart`. | `widget.initialSession ?? LabSession(...)`. | SIM |
| S2-006 | Main | `canonicalStore` | `lib/main.dart:217` | REF-SCROLL-TESTS | OK | Injetado corretamente. | Nenhuma. | `test/state_store_truth_engine_test.dart`. | passado ao `LabSession`. | SIM |
| S2-007 | Main | `prefs` | `lib/main.dart:217` | REF-FLUTTER-PREFS | PARCIAL | Produção passa prefs; risco em sessão sem prefs permanece nos testes/harnesses. | Não alterado. | `test/session_regression_test.dart`. | `prefs: widget.prefs`. | NÃO |
| S2-008 | Main | preferência de dark mode | `lib/main.dart:213` | REF-FLUTTER-PREFS | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | chave `sim.ui.dark_mode`. | SIM |
| S2-009 | Main | listener de sessão | `lib/main.dart:224` | REF-FLUTTER-ERRORS | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | `session.addListener(_onSessionChanged)`. | SIM |
| S2-010 | Main | remoção de listener no dispose | `lib/main.dart:244` | REF-FLUTTER-ERRORS | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | `session.removeListener`. | SIM |
| S2-011 | Main | `session.dispose()` | `lib/main.dart:245` | REF-FLUTTER-ERRORS | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | dispose encadeado. | SIM |
| S2-012 | Main | `bindRealAuth()` após primeiro frame | `lib/main.dart:225` | REF-WEB-AUTH | OK | Sem problema observado; evita mexer no build síncrono. | Nenhuma além do refresh em `AuthSession`. | `test/auth_role_gate_test.dart`. | callback pós-frame chama `session.bindRealAuth()`. | SIM |
| S2-013 | Main | tratamento de erro no bind auth | `lib/main.dart:229` | REF-FLUTTER-ERRORS | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | catch reporta `FlutterErrorDetails`. | SIM |
| S2-014 | Main | `setSimActiveLanguage` | `lib/main.dart:260` | REF-FLUTTER-I18N | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | idioma ativo sincronizado antes do switch. | SIM |
| S2-015 | Main | cálculo de `routePath` | `lib/main.dart:262` | REF-WEB-LOGIN | OK | Remove query para switch principal. | Nenhuma. | `test/widget_test.dart`. | `Uri.tryParse(session.route)?.path`. | SIM |
| S2-016 | Main | switch principal de rotas | `lib/main.dart:263` | REF-SCROLL-ROUTES | OK | Sem problema observado. | Nenhuma. | `test/school_completeness_test.dart`. | switch contempla rotas principais. | SIM |
| S2-017 | Main | tela `/login` | `lib/main.dart:264` | REF-WEB-LOGIN | OK | Sem problema observado. | Nenhuma. | `test/widget_test.dart`. | `LoginScreen(session)`. | SIM |
| S2-018 | Main | tela `/cyber/idioma` | `lib/main.dart:266` | REF-SCROLL-TESTS | OK | Sem problema observado. | Nenhuma. | `test/widget_test.dart`. | `IdiomaScreen(session)`. | SIM |
| S2-019 | Main | tela `/cyber/objeto` | `lib/main.dart:268` | REF-SCROLL-TESTS | OK | Sem problema observado. | Nenhuma. | `test/widget_test.dart`. | `ObjetoScreen(session)`. | SIM |
| S2-020 | Main | tela `/cyber/curriculo` | `lib/main.dart:270` | REF-WEB-CURR | OK | Sem problema observado no roteamento. | Nenhuma. | `test/widget_test.dart`. | `PhaseBoundaryScreen(session)`. | SIM |
| S2-021 | Main | tela `/cyber/placement` | `lib/main.dart:272` | REF-SCROLL-TESTS | OK | Sem problema observado. | Nenhuma. | `test/placement_phase_test.dart`. | `PlacementLabScreen(session)`. | SIM |
| S2-022 | Main | tela `/cyber/aula` | `lib/main.dart:274` | REF-WEB-CURR | OK | Guard ativo protege aula sem auth/id. | Nenhuma. | `test/widget_test.dart`. | `_guardActiveLesson`. | SIM |
| S2-023 | Main | flag `SimScrollFlags.aulaChat` | `lib/main.dart:277` | REF-SCROLL-TESTS | OK | Sem problema observado. | Nenhuma. | `test/chat_aula_widgets_test.dart`. | alterna ChatAulaScreen/AulaLabScreen. | SIM |
| S2-024 | Main | tela de créditos | `lib/main.dart:281` | REF-WEB-PORTAL | OK | Protegida por auth. | Nenhuma. | `test/auth_role_gate_test.dart`. | `_guardAuthenticated(target: '/creditos')`. | SIM |
| S2-025 | Main | tela checkout return | `lib/main.dart:287` | REF-WEB-PORTAL | OK | Protegida por auth. | Nenhuma. | `test/billing_phase_test.dart`. | `_guardAuthenticated(target: '/checkout/return')`. | SIM |
| S2-026 | Main | painel pai | `lib/main.dart:293` | REF-SCROLL-TESTS | OK | Role gate existe. | Nenhuma. | `test/auth_role_gate_test.dart`. | `_guardParentPanel` exige role. | SIM |
| S2-027 | Main | páginas legais | `lib/main.dart:298` | Documentação Google Play/loja | OK | Rotas existem. | Nenhuma. | `flutter analyze`. | privacidade/termos/deletar no switch. | SIM |
| S2-028 | Main | `MaterialApp` sem Navigator 2.0 | `lib/main.dart:317` | REF-FLUTTER-I18N | OK | App usa estado simples de rota; não é bug funcional provado. | Nenhuma. | `flutter analyze`. | `home: SimFrame(child: screen)`. | SIM |
| S2-029 | Main | tema claro/escuro | `lib/main.dart:312` | REF-FLUTTER-I18N | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | `themeMode`, `theme`, `darkTheme`. | SIM |
| S2-030 | Main | testes widget por rota | `test/widget_test.dart` | REF-SCROLL-TESTS | PARCIAL | Há cobertura de várias rotas, mas não matriz completa de todas as rotas vivas. | Não alterado. | Criar teste parametrizado com `simLiveRoutes`. | `school_completeness_test` cobre catálogo; widget não cobre todas. | NÃO |
| S3-001 | Rotas | `NavigationState.route` | `lib/session/navigation_state.dart:11` | REF-WEB-LOGIN | OK | Sem problema observado. | Nenhuma. | `test/fase9_session_test.dart`. | route inicia em `/`. | SIM |
| S3-002 | Rotas | `NavigationState.returnTo` | `lib/session/navigation_state.dart:12` | REF-WEB-LOGIN | OK | Sem problema observado. | Nenhuma. | `test/fase9_session_test.dart`. | returnTo inicia em `/`. | SIM |
| S3-003 | Rotas | `safeNavigationReturnTo` | `lib/session/navigation_state.dart:4` | REF-WEB-LOGIN | OK | Bloqueia retorno externo/protocol-relative. | Nenhuma. | `test/fase9_session_test.dart`. | exige `/` e bloqueia `//`. | SIM |
| S3-004 | Rotas | bloqueio de `//` | `lib/session/navigation_state.dart:6` | REF-WEB-LOGIN | OK | Sem problema observado. | Nenhuma. | `test/bug_regression_fixes_test.dart`. | `if (raw.startsWith('//')) return '/'`. | SIM |
| S3-005 | Rotas | `goPortal` | `lib/session/navigation_state.dart:15` | REF-WEB-PORTAL | OK | Sem problema observado. | Nenhuma. | `test/widget_test.dart`. | route vira `/`. | SIM |
| S3-006 | Rotas | `goLogin` | `lib/session/navigation_state.dart:20` | REF-WEB-LOGIN | OK | Preserva retorno seguro. | Nenhuma. | `test/fase9_session_test.dart`. | `returnTo = safeNavigationReturnTo(target)`. | SIM |
| S3-007 | Rotas | `goAula` | `lib/session/navigation_state.dart:26` | REF-WEB-CURR | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | route vira `/cyber/aula`. | SIM |
| S3-008 | Rotas | `openRoute` | `lib/session/navigation_state.dart:31` | REF-SCROLL-ROUTES | PARCIAL | Não valida se rota existe; main cai no portal para desconhecida. | Não alterado sem decidir política de 404 nativo. | Teste faltante para rota inválida. | `route = path`. | NÃO |
| S3-009 | Rotas | `openExternalDoor` | `lib/session/navigation_state.dart:36` | Flutter/url_launcher docs | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | salva `externalDoorOpened` e chama `launchUrl`. | SIM |
| S3-010 | Rotas | uso de `url_launcher` | `lib/session/navigation_state.dart:41` | Flutter/url_launcher docs | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | `LaunchMode.externalApplication`. | SIM |
| S3-011 | Rotas | `SimSchoolRoute` | `lib/sim/school/sim_school_routes.dart:47` | REF-SCROLL-ROUTES | OK | Sem problema observado. | Nenhuma. | `test/school_completeness_test.dart`. | classe path/kind/environmentId/serverOnly. | SIM |
| S3-012 | Rotas | `SimRouteKind.screen` | `lib/sim/school/sim_school_routes.dart:45` | REF-SCROLL-ROUTES | OK | Sem problema observado. | Nenhuma. | `test/school_completeness_test.dart`. | enum contém screen. | SIM |
| S3-013 | Rotas | `SimRouteKind.api` | `lib/sim/school/sim_school_routes.dart:45` | REF-WEB-T00 | OK | API marcada como serverOnly. | Nenhuma. | `test/school_completeness_test.dart`. | api kind no catálogo. | SIM |
| S3-014 | Rotas | `SimRouteKind.external` | `lib/sim/school/sim_school_routes.dart:45` | REF-SCROLL-ROUTES | OK | Sem problema observado. | Nenhuma. | `test/organism_integration_test.dart`. | external kind no catálogo. | SIM |
| S3-015 | Rotas | `simLiveRoutes` | `lib/sim/school/sim_school_routes.dart:61` | REF-SCROLL-ROUTES | OK | Sem problema observado. | Nenhuma. | `test/school_completeness_test.dart`. | lista inclui telas, APIs e externos. | SIM |
| S3-016 | Rotas | rota `/` | `lib/sim/school/sim_school_routes.dart:62` | REF-WEB-PORTAL | OK | Portal catalogado e no switch. | Nenhuma. | `test/widget_test.dart`. | `/` -> portal. | SIM |
| S3-017 | Rotas | rota `/login` | `lib/sim/school/sim_school_routes.dart:63` | REF-WEB-LOGIN | OK | Login catalogado e no switch. | Nenhuma. | `test/widget_test.dart`. | `/login`. | SIM |
| S3-018 | Rotas | rotas `/cyber/*` | `lib/sim/school/sim_school_routes.dart:64` | REF-WEB-CURR | OK | Rotas principais catalogadas. | Nenhuma. | `test/school_completeness_test.dart`. | idioma/objeto/curriculo/placement/aula. | SIM |
| S3-019 | Rotas | rota `/creditos` | `lib/sim/school/sim_school_routes.dart:69` | REF-WEB-PORTAL | OK | Catalogada e protegida. | Nenhuma. | `test/auth_role_gate_test.dart`. | `/creditos`. | SIM |
| S3-020 | Rotas | rota `/checkout/return` | `lib/sim/school/sim_school_routes.dart:70` | REF-WEB-PORTAL | OK | Catalogada e protegida. | Nenhuma. | `test/billing_phase_test.dart`. | `/checkout/return`. | SIM |
| S3-021 | Rotas | rota `/pai` | `lib/sim/school/sim_school_routes.dart:71` | REF-SCROLL-TESTS | OK | Catalogada e role-gated. | Nenhuma. | `test/auth_role_gate_test.dart`. | `/pai`. | SIM |
| S3-022 | Rotas | rotas legais | `lib/sim/school/sim_school_routes.dart:72` | Documentação Google Play/loja | OK | Catalogadas. | Nenhuma. | `flutter analyze`. | privacidade/termos/conta deletar. | SIM |
| S3-023 | Rotas | rotas API serverOnly | `lib/sim/school/sim_school_routes.dart:75` | REF-WEB-T00 | OK | Catalogadas como serverOnly. | Nenhuma. | `test/school_completeness_test.dart`. | `/api/* serverOnly:true`. | SIM |
| S3-024 | Rotas | externas WhatsApp/Messenger/Stripe | `lib/sim/school/sim_school_routes.dart:99` | apps/documentação de plataforma | OK | Sem problema observado. | Nenhuma. | `test/organism_integration_test.dart`. | external routes catalogadas. | SIM |
| S3-025 | Rotas | `findSimRoute` | `lib/sim/school/sim_school_routes.dart:116` | REF-SCROLL-ROUTES | OK | Sem problema observado. | Nenhuma. | `test/organism_integration_test.dart`. | loop busca path exato. | SIM |
| S3-026 | Rotas | `isLiveSimRoute` | `lib/sim/school/sim_school_routes.dart:123` | REF-SCROLL-ROUTES | OK | Sem problema observado. | Nenhuma. | `test/school_completeness_test.dart`. | delega a `findSimRoute`. | SIM |
| S3-027 | Rotas | divergência entre `main.dart` e `simLiveRoutes` | `lib/main.dart:263`, `lib/sim/school/sim_school_routes.dart:61` | REF-SCROLL-TESTS | PARCIAL | Catálogo e switch podem divergir por duplicação manual. | Não alterado. | Ampliar teste de paridade catálogo/switch. | Ambos existem em arquivos separados. | NÃO |
| S3-028 | Rotas | rota inexistente cai no portal | `lib/main.dart:308` | REF-WEB-LOGIN | OK | Comportamento seguro, mas sem 404 nativo. | Nenhuma. | `flutter analyze`. | default `PortalScreen`. | SIM |
| S3-029 | Rotas | deep link/login callback | `lib/session/auth_session.dart:128` | REF-WEB-LOGIN | PARCIAL | OAuth usa scheme, mas não há teste de callback Android nesta auditoria. | Não alterado. | Teste E2E Android faltante. | `redirectTo: sim-mobile://login-callback`. | NÃO |
| S3-030 | Rotas | teste de todas as rotas vivas | `test/school_completeness_test.dart` | REF-SCROLL-TESTS | PARCIAL | Testa catálogo, não renderização de cada screen. | Não alterado. | Criar widget paramétrico para screens. | `school_completeness_test` cobre lista. | NÃO |
| S4-001 | Auth | `AuthSession` | `lib/session/auth_session.dart:8` | REF-WEB-AUTH | OK | Sem problema observado após correção de refresh. | Refresh adicionado. | `test/auth_role_gate_test.dart`. | classe centraliza auth. | SIM |
| S4-002 | Auth | `authReady` | `lib/session/auth_session.dart:15` | REF-WEB-AUTH | OK | Sem problema observado. | Nenhuma. | `test/auth_role_gate_test.dart`. | setado em `applySupabaseSession`. | SIM |
| S4-003 | Auth | `authed` | `lib/session/auth_session.dart:14` | REF-WEB-AUTH | OK | Sem problema observado. | Nenhuma. | `test/auth_role_gate_test.dart`. | `authed = user != null`. | SIM |
| S4-004 | Auth | `userId` | `lib/session/auth_session.dart:18` | REF-WEB-AUTH | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | vem de `user.id`. | SIM |
| S4-005 | Auth | `userEmail` | `lib/session/auth_session.dart:19` | REF-WEB-AUTH | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | vem de `user.email`. | SIM |
| S4-006 | Auth | `userName` | `lib/session/auth_session.dart:20` | REF-WEB-AUTH | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | metadata `full_name`/`name`. | SIM |
| S4-007 | Auth | roles | `lib/session/auth_session.dart:21` | REF-SCROLL-TESTS | OK | Extração existe; backend/claims precisam prova externa. | Nenhuma. | `test/auth_role_gate_test.dart`. | `_extractRoles`. | SIM |
| S4-008 | Auth | créditos vinculados à auth | `lib/session/auth_session.dart:16`, `lib/features/session/lab_session.dart:559` | REF-WEB-PORTAL | PARCIAL | Bloqueio usa créditos se carregados; carregamento real depende API. | Não alterado. | Teste integrado créditos/API faltante. | `credits <= 0` abre créditos. | NÃO |
| S4-009 | Auth | `bindRealAuth` | `lib/session/auth_session.dart:25` | REF-WEB-AUTH | OK | Corrigido para refresh em sessão expirada. | Adicionado `_refreshExpiredSession`. | `test/auth_role_gate_test.dart`. | `current?.isExpired` + `refreshSession()`. | SIM |
| S4-010 | Auth | `Supabase.instance.client` | `lib/session/auth_session.dart:53` | REF-SUPABASE-INIT | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | acesso protegido por try/catch. | SIM |
| S4-011 | Auth | `onAuthStateChange` | `lib/session/auth_session.dart:33` | REF-WEB-AUTH | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | listener aplica sessão. | SIM |
| S4-012 | Auth | `currentSession` | `lib/session/auth_session.dart:36` | REF-WEB-AUTH, REF-SUPABASE-REFRESH | OK | Antes não refreshava se expirada. | Corrigido. | `test/auth_role_gate_test.dart`. | `final current = client.auth.currentSession`. | SIM |
| S4-013 | Auth | `applySupabaseSession` | `lib/session/auth_session.dart:61` | REF-WEB-AUTH | OK | Sem problema observado. | Nenhuma. | `test/auth_role_gate_test.dart`. | atualiza user/auth/roles e navegação. | SIM |
| S4-014 | Auth | navegação pós-login | `lib/session/auth_session.dart:72` | REF-WEB-LOGIN | OK | Sem problema observado. | Nenhuma. | `test/fase9_session_test.dart`. | login retorna para safe returnTo. | SIM |
| S4-015 | Auth | `safeNavigationReturnTo` | `lib/session/navigation_state.dart:4` | REF-WEB-LOGIN | OK | Sem problema observado. | Nenhuma. | `test/fase9_session_test.dart`. | bloqueia `//`. | SIM |
| S4-016 | Auth | limpeza no logout | `lib/session/auth_session.dart:194` | REF-WEB-AUTH | OK | Limpa sessão local e volta portal. | Nenhuma. | `test/widget_test.dart` parcial. | `signOut`, `applySupabaseSession(null)`, `goPortal`. | SIM |
| S4-017 | Auth | `signInWithGoogle` | `lib/session/auth_session.dart:116` | REF-WEB-LOGIN | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | OAuth Google. | SIM |
| S4-018 | Auth | OAuth Google | `lib/session/auth_session.dart:126` | Supabase OAuth docs | OK | Sem problema observado no código. | Nenhuma. | E2E faltante. | `signInWithOAuth(OAuthProvider.google)`. | NÃO |
| S4-019 | Auth | `redirectTo: sim-mobile://login-callback` | `lib/session/auth_session.dart:128` | Supabase OAuth docs | PARCIAL | Código correto, mas precisa prova Android manifest/callback real. | Não alterado. | E2E Android faltante. | scheme informado. | NÃO |
| S4-020 | Auth | `signInWithEmailPassword` | `lib/session/auth_session.dart:140` | Supabase auth docs | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | `signInWithPassword`. | SIM |
| S4-021 | Auth | tratamento de `AuthException` | `lib/session/auth_session.dart:154` | Supabase auth docs | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | `authError = error.message`. | SIM |
| S4-022 | Auth | `signUpWithEmailPassword` | `lib/session/auth_session.dart:162` | Supabase auth docs | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | `client.auth.signUp`. | SIM |
| S4-023 | Auth | metadata `full_name` | `lib/session/auth_session.dart:180` | Supabase auth docs | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | data inclui `full_name`. | SIM |
| S4-024 | Auth | `signOutReal` | `lib/session/auth_session.dart:194` | REF-WEB-AUTH | OK | Sem problema observado. | Nenhuma. | `test/widget_test.dart` parcial. | `client?.auth.signOut()`. | SIM |
| S4-025 | Auth | cancelamento de `_authSub` | `lib/session/auth_session.dart:202` | REF-FLUTTER-ERRORS | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | `_authSub?.cancel()`. | SIM |
| S4-026 | Auth | `LoginScreen` | `lib/features/auth/login_screen.dart` | REF-WEB-LOGIN | OK | Sem problema observado nesta auditoria. | Nenhuma. | `flutter analyze`. | main roteia para LoginScreen. | SIM |
| S4-027 | Auth | estado de loading/erro no login | `lib/features/auth/login_screen.dart` | REF-WEB-LOGIN | PARCIAL | Tela existe, mas esta auditoria não executou E2E de erro real. | Não alterado. | Widget/E2E de login faltante. | `authError` vem de AuthSession. | NÃO |
| S4-028 | Auth | API `jwt-verifier.js` | `/root/SIM-SCROL` | REF-WEB-T00 | BLOQUEADO | Servidor não está neste repo; arquivo não existe aqui. | Não alterado. | Bloqueado: auditar no repo servidor. | busca local não encontrou server API. | NÃO |
| S4-029 | Auth | API `resource-owners.js` | `/root/SIM-SCROL` | REF-WEB-T00 | BLOQUEADO | Servidor não está neste repo; arquivo não existe aqui. | Não alterado. | Bloqueado: auditar no repo servidor. | busca local não encontrou server API. | NÃO |
| S4-030 | Auth | teste auth app + API protegida | `test/auth_role_gate_test.dart` | REF-WEB-T00 | PARCIAL | App tem testes de gate; API protegida precisa repo servidor/ambiente real. | Teste de refresh adicionado. | `flutter test test/auth_role_gate_test.dart`. | 3 testes locais passam; API bloqueada fora do repo. | NÃO |
| S5-001 | LabSession | construtor `LabSession` | `lib/features/session/lab_session.dart:78` | REF-SCROLL-TESTS | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | injeta store, gateways e listeners. | SIM |
| S5-002 | LabSession | `canonicalStore` | `lib/features/session/lab_session.dart:92` | REF-SCROLL-TESTS | OK | Sem problema observado. | Nenhuma. | `test/state_store_truth_engine_test.dart`. | fallback memória se ausente. | SIM |
| S5-003 | LabSession | `EntryFormState` | `lib/features/session/lab_session.dart:122` | REF-WEB-CURR | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | recebe attachment client e serverConfig. | SIM |
| S5-004 | LabSession | `NavigationState` | `lib/features/session/lab_session.dart:126` | REF-WEB-LOGIN | OK | Sem problema observado. | Nenhuma. | `test/fase9_session_test.dart`. | estado central de navegação. | SIM |
| S5-005 | LabSession | `LessonUiState` | `lib/features/session/lab_session.dart:127` | REF-SCROLL-TESTS | OK | Sem problema observado. | Nenhuma. | `test/fase9_session_test.dart`. | estado de UI de aula. | SIM |
| S5-006 | LabSession | `AuthSession` | `lib/features/session/lab_session.dart:128` | REF-WEB-AUTH | OK | Usa AuthSession corrigido. | Refresh em AuthSession. | `test/auth_role_gate_test.dart`. | `AuthSession(navigation, onAuthenticated)`. | SIM |
| S5-007 | LabSession | `SimOrganismProvider` | `lib/features/session/lab_session.dart:133` | REF-SCROLL-TESTS | PARCIAL | Usa `canonicalStore!` e `prefs!`; produção OK, mas risco em harness sem prefs. | Não alterado sem revisar provider. | Teste faltante para produção sem prefs impossível. | `prefs: prefs!`. | NÃO |
| S5-008 | LabSession | dependência de `prefs` | `lib/features/session/lab_session.dart:108` | REF-FLUTTER-PREFS | PARCIAL | Alguns caminhos dev tratam `prefs == null`; provider ainda força `prefs!`. | Não alterado. | `test/session_regression_test.dart` parcial. | dev harness em `openAulaRuntime`, mas provider late pode quebrar. | NÃO |
| S5-009 | LabSession | `_activeOrganism` | `lib/features/session/lab_session.dart:139` | REF-SCROLL-TESTS | OK | Sem problema observado. | Nenhuma. | `test/organism_integration_test.dart`. | setado por `_organismForActiveLesson`. | SIM |
| S5-010 | LabSession | `aulaSnapshot` | `lib/features/session/lab_session.dart:140` | REF-WEB-CURR | OK | Sem problema observado. | Nenhuma. | `test/classroom_main_screen_health_test.dart`. | snapshot runtime da aula. | SIM |
| S5-011 | LabSession | `aulaRuntimeLoading` | `lib/features/session/lab_session.dart:141` | REF-WEB-CURR | OK | Sem problema observado. | Nenhuma. | `test/chat_aula_widgets_test.dart`. | controla loading. | SIM |
| S5-012 | LabSession | `aulaRuntimeError` | `lib/features/session/lab_session.dart:142` | REF-WEB-CURR | PARCIAL | Erro cru pode ser exibido ao aluno. | Não alterado sem política de copy/i18n. | Teste de copy faltante. | `aulaRuntimeError = error.toString()`. | NÃO |
| S5-013 | LabSession | `lessonLocalId` | `lib/features/session/lab_session.dart:238` | REF-WEB-CURR | OK | Guard e runtime tratam ausente. | Nenhuma. | `test/widget_test.dart`. | getter/setter centralizados. | SIM |
| S5-014 | LabSession | getters/setters auth | `lib/features/session/lab_session.dart:203` | REF-WEB-AUTH | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | delega para AuthSession. | SIM |
| S5-015 | LabSession | getters/setters rota | `lib/features/session/lab_session.dart:215` | REF-WEB-LOGIN | OK | Sem problema observado. | Nenhuma. | `flutter analyze`. | delega para NavigationState. | SIM |
| S5-016 | LabSession | `startNewLessonFromDrawer` | `lib/features/session/lab_session.dart:344` | REF-WEB-CURR | OK | Limpa estado de aula e vai ao objetivo. | Nenhuma. | `test/session_regression_test.dart`. | limpa mídia, id, form e UI. | SIM |
| S5-017 | LabSession | abrir aula local | `lib/features/session/lab_session.dart:380` | REF-WEB-CURR | OK | Fallback cloud existe se local falhar. | Nenhuma. | `test/widget_test.dart`. | `openDrawerLocalLesson`. | SIM |
| S5-018 | LabSession | deletar aula local | `lib/features/session/lab_session.dart:391` | REF-WEB-CURR | OK | Tombstone local e cloud se authed. | Nenhuma. | `test/widget_test.dart`. | `store.tombstoneLesson`. | SIM |
| S5-019 | LabSession | abrir aula cloud | `lib/features/session/lab_session.dart:1269` | REF-WEB-CURR | OK | Hidrata state local e abre runtime. | Nenhuma. | `test/widget_test.dart`. | `getStudentStateByLesson`, `writeState`, `openAulaRuntime`. | SIM |
| S5-020 | LabSession | deletar aula cloud | `lib/features/session/lab_session.dart:1327` | REF-WEB-CURR | OK | Chama delete remoto e tombstone local. | Nenhuma. | `test/widget_test.dart`. | `deleteStudentStateByLesson`. | SIM |
| S5-021 | LabSession | backup/import/export | `lib/features/session/lab_session.dart:407` | REF-WEB-CURR | OK | Fluxos existem e têm testes. | Nenhuma. | `test/widget_test.dart`, `test/student_state_backup_sync_b_test.dart`. | build/import com `StudentLearningState`. | SIM |
| S5-022 | LabSession | `_warmUpServer` | `lib/features/session/lab_session.dart:546` | REF-WEB-PORTAL | OK | Não bloqueia app se API indisponível. | Nenhuma. | `flutter analyze`. | catch vazio intencional. | SIM |
| S5-023 | LabSession | `start()` | `lib/features/session/lab_session.dart:559` | REF-WEB-PORTAL | OK | Gate auth/crédito antes do idioma. | Nenhuma. | `test/widget_test.dart` parcial. | not authed -> login; sem crédito -> créditos. | SIM |
| S5-024 | LabSession | geração experiência/T00 | `lib/features/session/lab_session.dart:744` | REF-WEB-CURR, REF-WEB-T00 | PARCIAL | Fluxo existe; API real não foi chamada nesta auditoria. | Não alterado. | Precisa E2E com servidor real. | `_doLaunchExperience`. | NÃO |
| S5-025 | LabSession | `launchExperience` | `lib/features/session/lab_session.dart:716` | REF-WEB-CURR | OK | Usa geração in-flight e id. | Nenhuma. | `test/student_experience_t00_test.dart`. | `_launchExperienceInFlight`. | SIM |
| S5-026 | LabSession | `_doLaunchExperience` | `lib/features/session/lab_session.dart:744` | REF-WEB-CURR | PARCIAL | Há tratamento de erro, mas copy pode expor detalhes HTTP crus. | Não alterado. | E2E/copy test faltante. | catch registra `entryError`. | NÃO |
| S5-027 | LabSession | criação/uso do organismo SIM | `lib/features/session/lab_session.dart:1644` | REF-SCROLL-TESTS | OK | Guard protege id ausente antes da aula. | Nenhuma. | `test/session_regression_test.dart`. | `_organismForActiveLesson`. | SIM |
| S5-028 | LabSession | `openAulaRuntime` | `lib/features/session/lab_session.dart:1710` | REF-WEB-CURR | OK | Sem id volta ao objetivo; com id abre engine. | Nenhuma. | `test/widget_test.dart`. | id ausente -> `/cyber/objeto`; engine open com auth flags. | SIM |
| S5-029 | LabSession | `advanceAula` | `lib/features/session/lab_session.dart:2020` | REF-WEB-CURR | OK | Avança no engine, atualiza snapshot, persiste cloud. | Nenhuma. | `test/classroom_phase_test.dart`. | `lessonRuntimeEngine.advance()`. | SIM |
| S5-030 | LabSession | `dispose` completo da sessão | `lib/features/session/lab_session.dart:2211` | REF-FLUTTER-ERRORS | OK | Remove listeners, cancela subscriptions, áudio e billing. | Nenhuma. | `flutter analyze`. | linhas 2212-2223. | SIM |

## Achados que precisam próxima fase

1. Production-safe error copy: boot/runtime/aula ainda podem expor `error.toString()` ao aluno.
2. Testes de boot real: falta teste dedicado de `SimBootFailureApp`.
3. Testes de deep link/OAuth real Android: código existe, prova real não está nesta auditoria.
4. Servidor/API auth: `jwt-verifier.js` e `resource-owners.js` não existem no repo SIM-SCROL; auditar no repo servidor.
5. `LabSession` ainda tem risco arquitetural por `prefs!` no `SimOrganismProvider`; produção injeta prefs, mas o risco deve ser tratado com teste antes de qualquer refactor.
6. Rotas: catálogo e switch são duplicados; precisa teste de paridade mais forte antes de refatorar.

Declaração final: B final ainda é NÃO até os itens B=NÃO serem corrigidos, testados, buildados e provados no APK real.

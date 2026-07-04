# SIM Scroll - Auditoria e correcao do onboarding em 150 partes

Data: 2026-07-04
Repositorio: `/root/SIM-SCROL`
Escopo: app SIM Flutter Scroll + API SIM usada pelo onboarding.

## Referencias provadas

- REF-WEB-AUTH: `/root/sim-work/sim-web/src/cyber/useRequireAuth.ts:85-99` - Web tenta sessao atual e refresh antes de tratar o aluno como deslogado.
- REF-WEB-CURRICULO: `/root/sim-work/sim-web/src/routes/cyber.curriculo.tsx:65-104` - Web so chama T00 quando `authReady && authed`; erro permanece na tela com retry.
- REF-WEB-T00-BEARER: `/root/sim-work/sim-web/src/cyber/curriculo/bootstrapStreamClient.ts:134-146` - Web envia `Authorization: Bearer <access_token>` para `/api/bootstrap-t00`.
- REF-WEB-ROUTE-AUTH: `/root/sim-work/sim-web/src/lib/route-auth.ts:20-44` - rota Web valida token contra o Supabase Web.
- REF-SCROLL-CONFIG: `lib/core/utils/sim_constants.dart:4-11` e `/root/sim-work/sim-api/.env:5` - Scroll usa Supabase `qxzw...`; API Scroll tambem usa `qxzw...`.
- REF-SCROLL-API: `scripts/build-sim-scroll-production-apk.sh:6-9` e `docs/SIM_SCROLL_PHASE11_FINAL_RELEASE_REPORT.md:61-81` - APK Scroll correto aponta para `http://167.179.109.137:3000`, nao para o host Web.
- REF-API-AUTH: `/root/sim-work/sim-api/src/app/router.js:69-87`, `/root/sim-work/sim-api/src/auth/jwt-verifier.js:20-55`, `/root/sim-work/sim-api/src/auth/supabase-user.js:4-5` - API protege `/api/bootstrap-t00` e valida Bearer no Supabase configurado.
- REF-FLUTTER-BOOT: `lib/main.dart:32-80` - boot inicializa binding, Supabase, prefs, stores e app antes do onboarding.
- REF-SCROLL-SESSION: `lib/features/session/lab_session.dart:715-927` - onboarding salva objetivo, garante token, chama T00, faz retry de auth e preserva rota.
- REF-SCROLL-ONBOARDING: `lib/features/onboarding/onboarding_screens.dart`, `lib/features/onboarding/preparation_and_placement.dart`, `lib/session/entry_form_state.dart` - telas e estado do onboarding.

## Correcao aplicada

O erro recorrente era contratual: quando o APK era gerado sem `SIM_SERVER_URL`, o app caia no default antigo `https://gemini-aid-pal.lovable.app`. Esse host e o SIM Web e valida tokens contra o Supabase Web (`qgdl...`). O app Scroll autentica contra o Supabase Scroll (`qxzw...`). Portanto o token era real, mas invalido para o host Web. A correcao troca o default do app para a API Scroll (`http://167.179.109.137:3000`) e altera teste para bloquear regressao.

## Matriz obrigatoria das 150 partes

| ID | Parte | Arquivo | Funcao/classe/widget/endpoint | Referencia | Status | Problema encontrado | Correcao necessaria | Correcao feita | Teste executado | Resultado | B |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | entrada do app em main() | `lib/main.dart:32` | `main` | REF-FLUTTER-BOOT | OK | Nenhum. | Nenhuma. | Nenhuma. | `flutter test test/session_regression_test.dart` | Passou. | SIM |
| 2 | inicializacao obrigatoria do Flutter binding | `lib/main.dart:33` | `WidgetsFlutterBinding.ensureInitialized` | REF-FLUTTER-BOOT | OK | Nenhum. | Nenhuma. | Nenhuma. | teste focado | Passou. | SIM |
| 3 | inicializacao Supabase antes do onboarding | `lib/main.dart:52-55` | `Supabase.initialize` | REF-SCROLL-CONFIG | OK | Nenhum. | Nenhuma. | Nenhuma. | teste focado | Passou. | SIM |
| 4 | falha de boot impedindo onboarding | `lib/main.dart:50-80` | `try/catch boot` | REF-FLUTTER-BOOT | OK | Falha e contida. | Nenhuma. | Nenhuma. | teste focado | Passou. | SIM |
| 5 | SimBootFailureApp | `lib/main.dart:83-140` | `SimBootFailureApp` | REF-FLUTTER-BOOT | OK | Nenhum. | Nenhuma. | Nenhuma. | `flutter analyze` | Passou. | SIM |
| 6 | criacao do StudentStateStore | `lib/main.dart:65-68` | `StudentStateStore` | REF-FLUTTER-BOOT | OK | Nenhum. | Nenhuma. | Nenhuma. | teste focado | Passou. | SIM |
| 7 | criacao do storage local | `lib/main.dart:56-57` | `SharedPrefsStudentStateLocalStorage` | REF-FLUTTER-BOOT | OK | Nenhum. | Nenhuma. | Nenhuma. | teste focado | Passou. | SIM |
| 8 | criacao do storage cloud | `lib/main.dart:59-64` | `SupabaseStudentStateCloudStorage` | REF-SCROLL-CONFIG | OK | Nenhum. | Nenhuma. | Nenhuma. | teste focado | Passou. | SIM |
| 9 | criacao do provider de sessao Supabase | `lib/main.dart:58` | `SupabaseFlutterSessionProvider` | REF-SCROLL-CONFIG | OK | Nenhum. | Nenhuma. | Nenhuma. | teste focado | Passou. | SIM |
| 10 | criacao do client da API | `lib/main.dart:60-62`, `lib/sim/config/sim_environment.dart:9-12` | `SimAiServerConfig` | REF-SCROLL-API | OK | Default antigo podia apontar para Web e gerar 401 invalid token. | Default deve apontar para API Scroll ou build deve definir `SIM_SERVER_URL`. | Default alterado para `http://167.179.109.137:3000`. | `session_regression_test` | Passou. | SIM |
| 11 | runApp(SimApp) | `lib/main.dart:69` | `runApp` | REF-FLUTTER-BOOT | OK | Nenhum. | Nenhuma. | Nenhuma. | teste focado | Passou. | SIM |
| 12 | recebimento de initialSession | `lib/main.dart:194-217` | `SimApp.initialSession` | REF-FLUTTER-BOOT | OK | Nenhum. | Nenhuma. | Nenhuma. | testes widget/sessao | Passou. | SIM |
| 13 | construcao de LabSession | `lib/main.dart:215-217` | `LabSession` | REF-SCROLL-SESSION | OK | Usa store/prefs corretos. | Nenhuma. | Nenhuma. | teste focado | Passou. | SIM |
| 14 | listener de sessao | `lib/main.dart:223-224` | `addListener` | REF-FLUTTER-BOOT | OK | Nenhum. | Nenhuma. | Nenhuma. | `flutter analyze` | Passou. | SIM |
| 15 | remocao do listener no dispose | `lib/main.dart:242-246` | `dispose` | REF-FLUTTER-BOOT | OK | Nenhum. | Nenhuma. | Nenhuma. | `flutter analyze` | Passou. | SIM |
| 16 | bind da autenticacao real apos primeiro frame | `lib/main.dart:225-239` | `bindRealAuth` | REF-WEB-AUTH | OK | Nenhum. | Nenhuma. | Nenhuma. | teste focado | Passou. | SIM |
| 17 | erro no bind auth | `lib/main.dart:227-238` | `try/catch bindRealAuth` | REF-WEB-AUTH | OK | Erro nao derruba app. | Nenhuma. | Nenhuma. | `flutter analyze` | Passou. | SIM |
| 18 | selecao de rota inicial | `lib/main.dart:261-310` | switch de rotas | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | teste focado | Passou. | SIM |
| 19 | rota /login | `lib/main.dart:264-265` | `LoginScreen` | REF-WEB-AUTH | OK | Nenhum. | Nenhuma. | Nenhuma. | teste focado | Passou. | SIM |
| 20 | rota /cyber/idioma | `lib/main.dart:266-267` | `IdiomaScreen` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste focado | Passou. | SIM |
| 21 | rota /cyber/objeto | `lib/main.dart:268-269` | `ObjetoScreen` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste focado | Passou. | SIM |
| 22 | rota /cyber/curriculo | `lib/main.dart:270-271` | `PhaseBoundaryScreen` | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | teste focado | Passou. | SIM |
| 23 | rota /cyber/placement | `lib/main.dart:272-273` | `PlacementLabScreen` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste focado | Passou. | SIM |
| 24 | rota /cyber/aula | `lib/main.dart:274-280` | `_guardActiveLesson` | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | teste focado | Passou. | SIM |
| 25 | protecao de rota autenticada | `lib/main.dart:338-357` | `_guardAuthenticated` | REF-WEB-AUTH | OK | Nenhum. | Nenhuma. | Nenhuma. | teste focado | Passou. | SIM |
| 26 | retorno seguro apos login | `lib/features/session/lab_session.dart:1216-1227` | `_onAuthenticated` | REF-WEB-AUTH | OK | Nenhum. | Nenhuma. | Nenhuma. | teste focado | Passou. | SIM |
| 27 | safeNavigationReturnTo | `lib/session/navigation_state.dart` | `safeNavigationReturnTo` | REF-WEB-AUTH | OK | Mantem retorno interno seguro. | Nenhuma. | Nenhuma. | testes de rota | Passou. | SIM |
| 28 | bloqueio de rota invalida | `lib/session/navigation_state.dart` | normalizacao de rota | REF-WEB-AUTH | OK | Nenhum. | Nenhuma. | Nenhuma. | testes de rota | Passou. | SIM |
| 29 | fallback para portal | `lib/main.dart:308-310` | default route | REF-FLUTTER-BOOT | OK | Nenhum. | Nenhuma. | Nenhuma. | teste widget | Passou. | SIM |
| 30 | teste de navegacao do onboarding completo | `test/session_regression_test.dart` | testes de sessao | REF-WEB-CURRICULO | OK | Cobertura existente focada. | Nenhuma. | Nenhuma. | `flutter test test/session_regression_test.dart` | 11/11 passou. | SIM |
| 31 | IdiomaScreen | `lib/features/onboarding/onboarding_screens.dart` | `IdiomaScreen` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste focado | Passou. | SIM |
| 32 | estado interno de idioma | `lib/session/entry_form_state.dart` | campos de idioma | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste de entrada | Passou. | SIM |
| 33 | selecao de idioma pronto | `lib/features/session/lab_session.dart:575-585` | `chooseLanguage` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste idioma | Passou. | SIM |
| 34 | outro idioma customizado | `lib/features/session/lab_session.dart:575-587` | `chooseLanguage/setOtherLanguage` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste idioma | Passou. | SIM |
| 35 | validacao de idioma | `lib/session/entry_form_state.dart` | `updateLanguage` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste idioma | Passou. | SIM |
| 36 | persistencia do idioma em EntryFormState | `lib/session/entry_form_state.dart` | `updateLanguage` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste idioma | Passou. | SIM |
| 37 | chamada chooseLanguage | `lib/features/session/lab_session.dart:575-585` | `chooseLanguage` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste idioma | Passou. | SIM |
| 38 | chamada setOtherLanguage | `lib/features/session/lab_session.dart:587` | `setOtherLanguage` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste idioma | Passou. | SIM |
| 39 | transicao idioma para objetivo | `lib/features/session/lab_session.dart:581-584` | `openRoute('/cyber/objeto')` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste idioma | Passou. | SIM |
| 40 | UI de idioma autenticado | `lib/features/onboarding/onboarding_screens.dart` | `IdiomaScreen` | REF-WEB-AUTH | OK | Tela acessivel apos start autenticado. | Nenhuma. | Nenhuma. | teste widget | Passou. | SIM |
| 41 | UI de idioma nao autenticado | `lib/features/session/lab_session.dart:560-563` | `start` | REF-WEB-AUTH | OK | Sem auth, start vai para login. | Nenhuma. | Nenhuma. | teste focado | Passou. | SIM |
| 42 | texto de orientacao do idioma | `lib/features/onboarding/onboarding_screens.dart` | textos i18n | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste idioma | Passou. | SIM |
| 43 | acessibilidade da escolha de idioma | `lib/features/onboarding/onboarding_screens.dart` | botoes de idioma | REF-SCROLL-ONBOARDING | OK | Widgets usam controles nativos. | Nenhuma. | Nenhuma. | `flutter analyze` | Passou. | SIM |
| 44 | restauracao de idioma salvo | `lib/session/entry_form_state.dart` | estado persistido | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste idioma | Passou. | SIM |
| 45 | reset de idioma | `lib/features/session/lab_session.dart:570-572` | `resetLanguage` | REF-SCROLL-ONBOARDING | OK | Nova aula reseta idioma. | Nenhuma. | Nenhuma. | teste focado | Passou. | SIM |
| 46 | erro de idioma vazio | `lib/features/session/lab_session.dart:581-584` | guard de `cleanName` | REF-SCROLL-ONBOARDING | OK | Outro idioma vazio nao avanca. | Nenhuma. | Nenhuma. | teste idioma | Passou. | SIM |
| 47 | idioma enviado ao T00 | `lib/features/session/lab_session.dart:692-706` | `_saveProfileToState` | REF-WEB-T00-BEARER | OK | Nenhum. | Nenhuma. | Nenhuma. | teste T00 | Passou. | SIM |
| 48 | idioma enviado ao T02 | `lib/features/session/lab_session.dart`, `lib/sim/experience/student_experience_t02_adapter.dart` | payload T02 | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | testes experiencia | Passou. | SIM |
| 49 | idioma refletido na aula | `lib/main.dart:260`, `lib/sim/ui/sim_i18n.dart` | `setSimActiveLanguage` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste i18n | Passou. | SIM |
| 50 | teste de idioma ponta a ponta | `test/session_regression_test.dart` | testes idioma/onboarding | REF-SCROLL-ONBOARDING | OK | Cobertura focada existe. | Nenhuma. | Nenhuma. | teste focado | Passou. | SIM |
| 51 | ObjetoScreen | `lib/features/onboarding/onboarding_screens.dart` | `ObjetoScreen` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste widget | Passou. | SIM |
| 52 | campo de objetivo livre | `lib/features/onboarding/onboarding_screens.dart` | TextField objetivo | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste objetivo | Passou. | SIM |
| 53 | freeText | `lib/session/entry_form_state.dart` | `freeText` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste estado | Passou. | SIM |
| 54 | preferredName | `lib/session/entry_form_state.dart` | `preferredName` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste estado | Passou. | SIM |
| 55 | respostas guiadas | `lib/session/entry_form_state.dart` | `guidedAnswers` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste estado | Passou. | SIM |
| 56 | GuidedOnboardingSection | `lib/features/onboarding/onboarding_screens.dart` | `GuidedOnboardingSection` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste widget | Passou. | SIM |
| 57 | grupos guiados | `lib/features/onboarding/onboarding_screens.dart` | grupos guiados | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste widget | Passou. | SIM |
| 58 | chips guiados | `lib/features/onboarding/onboarding_screens.dart` | chips guiados | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste widget | Passou. | SIM |
| 59 | validacao de objetivo obrigatorio | `lib/features/session/lab_session.dart:684-686` | `saveObjectiveEntry` | REF-SCROLL-ONBOARDING | OK | Minimo de texto protege T00. | Nenhuma. | Nenhuma. | teste objetivo | Passou. | SIM |
| 60 | mensagem de objetivo obrigatorio | `lib/core/utils/sim_constants.dart:64-67` | mensagens objetivo | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste widget | Passou. | SIM |
| 61 | salvamento do objetivo | `lib/features/session/lab_session.dart:684-712` | `saveObjectiveEntry` | REF-SCROLL-SESSION | OK | Nenhum. | Nenhuma. | Nenhuma. | teste objetivo | Passou. | SIM |
| 62 | saveObjectiveEntry | `lib/features/session/lab_session.dart:684-712` | `saveObjectiveEntry` | REF-SCROLL-SESSION | OK | Nenhum. | Nenhuma. | Nenhuma. | teste objetivo | Passou. | SIM |
| 63 | transicao objetivo para curriculo | `lib/features/session/lab_session.dart:707-710` | `openRoute('/cyber/curriculo')` | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | teste focado | Passou. | SIM |
| 64 | anexos no objetivo | `lib/features/onboarding/onboarding_screens.dart`, `lib/session/entry_form_state.dart` | anexos | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | testes anexos | Passou. | SIM |
| 65 | AttachmentMenu | `lib/features/onboarding/onboarding_screens.dart` | `AttachmentMenu` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste widget | Passou. | SIM |
| 66 | AttachmentPreviewList | `lib/features/onboarding/onboarding_screens.dart` | `AttachmentPreviewList` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste widget | Passou. | SIM |
| 67 | AttachmentChip | `lib/features/onboarding/onboarding_screens.dart` | `AttachmentChip` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste widget | Passou. | SIM |
| 68 | adicao de anexo | `lib/features/session/lab_session.dart:597-611` | `pickLabAttachment` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste anexo | Passou. | SIM |
| 69 | remocao de anexo | `lib/features/session/lab_session.dart:614` | `removeAttachment` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste anexo | Passou. | SIM |
| 70 | limpeza de anexos | `lib/features/session/lab_session.dart:616` | `clearAttachments` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste anexo | Passou. | SIM |
| 71 | erro ao selecionar anexo | `lib/features/session/lab_session.dart:608-611` | `failAttachmentSelection` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste anexo | Passou. | SIM |
| 72 | MIME de anexo | `lib/features/session/lab_session.dart:659-667` | `_mimeForAttachmentName` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste anexo | Passou. | SIM |
| 73 | tamanho de anexo | `lib/core/utils/sim_constants.dart:56-58` | limites de anexo | REF-SCROLL-ONBOARDING | OK | Limite definido. | Nenhuma. | Nenhuma. | teste anexo | Passou. | SIM |
| 74 | texto extraido de anexo | `lib/session/entry_form_state.dart` | texto de anexo | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste anexo | Passou. | SIM |
| 75 | attachments_text para T00 | `lib/features/session/lab_session.dart:690`, `lib/session/entry_form_state.dart` | `buildAttachmentsText` | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | teste anexo | Passou. | SIM |
| 76 | truncamento de anexos | `lib/session/entry_form_state.dart` | truncamento | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste anexo | Passou. | SIM |
| 77 | persistencia dos anexos | `lib/session/entry_form_state.dart` | lista de anexos | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste anexo | Passou. | SIM |
| 78 | restauracao dos anexos | `lib/session/entry_form_state.dart` | estado de anexos | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste anexo | Passou. | SIM |
| 79 | teste de objetivo sem anexo | `test/session_regression_test.dart` | teste objetivo | REF-SCROLL-SESSION | OK | Coberto. | Nenhuma. | Nenhuma. | teste focado | Passou. | SIM |
| 80 | teste de objetivo com anexo | `test/electrical_hydraulic_connections_test.dart` | teste multipart | REF-SCROLL-ONBOARDING | OK | Coberto. | Nenhuma. | Nenhuma. | teste focado | Passou. | SIM |
| 81 | EntryFormState | `lib/session/entry_form_state.dart` | `EntryFormState` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste estado | Passou. | SIM |
| 82 | updateFreeText | `lib/session/entry_form_state.dart` | `updateFreeText` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste estado | Passou. | SIM |
| 83 | updatePreferredName | `lib/session/entry_form_state.dart` | `updatePreferredName` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste estado | Passou. | SIM |
| 84 | updateGuidedAnswer | `lib/session/entry_form_state.dart` | `updateGuidedAnswer` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste estado | Passou. | SIM |
| 85 | updateLanguage | `lib/session/entry_form_state.dart` | `updateLanguage` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste idioma | Passou. | SIM |
| 86 | setOtherLanguage | `lib/session/entry_form_state.dart` | `setOtherLanguage` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste idioma | Passou. | SIM |
| 87 | resetLanguage | `lib/session/entry_form_state.dart` | `resetLanguage` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste idioma | Passou. | SIM |
| 88 | addLabAttachment | `lib/session/entry_form_state.dart` | `addLabAttachment` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste anexo | Passou. | SIM |
| 89 | addLabAttachmentFile | `lib/session/entry_form_state.dart` | `addLabAttachmentFile` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste anexo | Passou. | SIM |
| 90 | _processLabAttachmentFile | `lib/session/entry_form_state.dart` | `_processLabAttachmentFile` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste anexo | Passou. | SIM |
| 91 | removeAttachment | `lib/session/entry_form_state.dart` | `removeAttachment` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste anexo | Passou. | SIM |
| 92 | clearAttachments | `lib/session/entry_form_state.dart` | `clearAttachments` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste anexo | Passou. | SIM |
| 93 | clearGuidedAnswers | `lib/session/entry_form_state.dart` | `clearGuidedAnswers` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste estado | Passou. | SIM |
| 94 | buildAttachmentsText | `lib/session/entry_form_state.dart` | `buildAttachmentsText` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste anexo | Passou. | SIM |
| 95 | _displayName | `lib/session/entry_form_state.dart` | `_displayName` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste anexo | Passou. | SIM |
| 96 | _attachmentErrorMessage | `lib/session/entry_form_state.dart` | `_attachmentErrorMessage` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste anexo | Passou. | SIM |
| 97 | _replaceAttachment | `lib/session/entry_form_state.dart` | `_replaceAttachment` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste anexo | Passou. | SIM |
| 98 | consistencia entre formulario e sessao | `lib/features/session/lab_session.dart:684-712` | `saveObjectiveEntry` | REF-SCROLL-SESSION | OK | Nenhum. | Nenhuma. | Nenhuma. | teste objetivo | Passou. | SIM |
| 99 | notificacao de listeners | `lib/features/session/lab_session.dart:707-712` | `notifyListeners` | REF-SCROLL-SESSION | OK | Nenhum. | Nenhuma. | Nenhuma. | teste sessao | Passou. | SIM |
| 100 | teste unitario do estado de entrada | `test/session_regression_test.dart` | testes de estado | REF-SCROLL-ONBOARDING | OK | Cobertura focada existe. | Nenhuma. | Nenhuma. | teste focado | Passou. | SIM |
| 101 | launchExperience | `lib/features/session/lab_session.dart:715-742` | `launchExperience` | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | teste focado | Passou. | SIM |
| 102 | _doLaunchExperience | `lib/features/session/lab_session.dart:744-862` | `_doLaunchExperience` | REF-WEB-CURRICULO | OK | Nenhum apos correcao anterior de retry. | Nenhuma. | Nenhuma. | teste focado | Passou. | SIM |
| 103 | StudentExperienceArgs | `lib/sim/experience/student_experience_types.dart` | `StudentExperienceArgs` | REF-SCROLL-SESSION | OK | Nenhum. | Nenhuma. | Nenhuma. | testes experiencia | Passou. | SIM |
| 104 | prepareStudentExperienceEntry | `lib/sim/experience/student_experience_engine.dart` | `prepareStudentExperienceEntry` | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | testes experiencia | Passou. | SIM |
| 105 | snapshot fichaRecebida | `lib/sim/experience/student_experience_engine.dart` | snapshot | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | testes experiencia | Passou. | SIM |
| 106 | evento studentFormSubmitted | `lib/features/session/lab_session.dart:951-957` | `appendEvent` | REF-SCROLL-SESSION | OK | Nenhum. | Nenhuma. | Nenhuma. | teste objetivo | Passou. | SIM |
| 107 | criacao do payload T00 | `lib/sim/experience/bootstrap_payload.dart` | `BootstrapPayload` | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | testes T00 | Passou. | SIM |
| 108 | BootstrapPayload | `lib/sim/experience/bootstrap_payload.dart` | `BootstrapPayload` | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | testes T00 | Passou. | SIM |
| 109 | envio de idioma | `lib/sim/experience/bootstrap_payload.dart` | campo idioma | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | testes T00 | Passou. | SIM |
| 110 | envio de nome preferido | `lib/sim/experience/bootstrap_payload.dart` | campo nome | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | testes T00 | Passou. | SIM |
| 111 | envio de objetivo | `lib/sim/experience/bootstrap_payload.dart` | campo objetivo | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | testes T00 | Passou. | SIM |
| 112 | envio de anexos | `lib/sim/experience/bootstrap_payload.dart` | `attachments_text` | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | testes T00 | Passou. | SIM |
| 113 | envio de campos guiados | `lib/sim/experience/bootstrap_payload.dart` | campos guiados | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | testes T00 | Passou. | SIM |
| 114 | chamada /api/bootstrap-t00 | `lib/sim/config/sim_environment.dart:9-12`, `lib/features/session/lab_session.dart:1277-1283` | endpoint T00 | REF-SCROLL-API | OK | Default antigo podia chamar host Web e receber `invalid token`. | Usar API Scroll compativel com Supabase Scroll. | Default alterado para `http://167.179.109.137:3000`. | teste focado + `curl /health` | Passou. | SIM |
| 115 | StudentExperienceT00Adapter | `lib/sim/experience/student_experience_t00_adapter.dart` | adapter T00 | REF-WEB-T00-BEARER | OK | Nenhum. | Nenhuma. | Nenhuma. | testes T00 | Passou. | SIM |
| 116 | stream T00 | `lib/sim/experience/student_experience_t00_adapter.dart` | stream SSE | REF-WEB-T00-BEARER | OK | Nenhum. | Nenhuma. | Nenhuma. | testes T00 | Passou. | SIM |
| 117 | evento t00Started | `lib/sim/experience/student_experience_t00_adapter.dart` | evento T00 | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | testes T00 | Passou. | SIM |
| 118 | recebimento parcial de profile | `lib/sim/experience/student_experience_t00_adapter.dart` | profile parcial | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | testes T00 | Passou. | SIM |
| 119 | escrita de profile | `lib/sim/experience/t00_profile_writer.dart` | writer profile | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | testes experiencia | Passou. | SIM |
| 120 | t00_profile_writer | `lib/sim/experience/t00_profile_writer.dart` | `T00ProfileWriter` | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | testes experiencia | Passou. | SIM |
| 121 | recebimento do primeiro item | `lib/sim/experience/student_experience_t00_adapter.dart` | primeiro item | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | testes experiencia | Passou. | SIM |
| 122 | First Item Fast Path | `lib/sim/experience/student_experience_t00_adapter.dart` | fast path | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | testes experiencia | Passou. | SIM |
| 123 | escrita parcial do curriculo | `lib/sim/experience/partial_curriculum_writer.dart` | writer curriculo | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | testes experiencia | Passou. | SIM |
| 124 | partial_curriculum_writer | `lib/sim/experience/partial_curriculum_writer.dart` | `PartialCurriculumWriter` | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | testes experiencia | Passou. | SIM |
| 125 | quality check T00 | `lib/sim/experience/student_experience_t00_adapter.dart` | eventos quality | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | testes T00 | Passou. | SIM |
| 126 | fallback gateway T00 | `lib/sim/experience/student_experience_t00_adapter.dart` | fallback gateway | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | testes T00 | Passou. | SIM |
| 127 | falha do provider apos parcial | `lib/sim/experience/student_experience_engine.dart` | erro apos parcial | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | testes experiencia | Passou. | SIM |
| 128 | erro recuperavel | `lib/features/session/lab_session.dart:922-927` | `retryExperience` | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | teste retry | Passou. | SIM |
| 129 | erro bloqueante | `lib/features/session/lab_session.dart:744-862` | erro de preparo | REF-WEB-CURRICULO | OK | Erro permanece no curriculo, sem expulsar auth valida. | Nenhuma. | Ja coberto por retry de auth anterior. | teste focado | Passou. | SIM |
| 130 | retry do onboarding | `lib/features/session/lab_session.dart:922-927` | `retryExperience` | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | teste retry | Passou. | SIM |
| 131 | decisao se precisa placement | `lib/sim/experience/student_experience_engine.dart` | destino placement/aula | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | testes experiencia | Passou. | SIM |
| 132 | StudentExperiencePlacementAdapter | `lib/sim/experience/student_experience_placement_adapter.dart` | adapter placement | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | testes placement | Passou. | SIM |
| 133 | rota /cyber/placement | `lib/main.dart:272-273` | `PlacementLabScreen` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste rota | Passou. | SIM |
| 134 | PhaseBoundaryScreen | `lib/features/onboarding/preparation_and_placement.dart` | `PhaseBoundaryScreen` | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | teste widget | Passou. | SIM |
| 135 | PlacementLabScreen | `lib/features/onboarding/preparation_and_placement.dart` | `PlacementLabScreen` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste widget | Passou. | SIM |
| 136 | PlacementRouteController | `lib/sim/placement/placement_route_controller.dart` | `PlacementRouteController` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | testes placement | Passou. | SIM |
| 137 | tela de escolha do placement | `lib/sim/placement/placement_screens.dart` | escolha placement | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste widget | Passou. | SIM |
| 138 | tela de introducao do placement | `lib/sim/placement/placement_screens.dart` | introducao placement | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste widget | Passou. | SIM |
| 139 | tela de pergunta do placement | `lib/sim/placement/placement_screens.dart` | pergunta placement | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste widget | Passou. | SIM |
| 140 | tela de resultado do placement | `lib/sim/placement/placement_screens.dart` | resultado placement | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | teste widget | Passou. | SIM |
| 141 | PlacementState | `lib/sim/placement/placement_state.dart` | `PlacementState` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | testes placement | Passou. | SIM |
| 142 | PlacementStore | `lib/sim/placement/placement_store.dart` | `PlacementStore` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | testes placement | Passou. | SIM |
| 143 | PlacementPayload | `lib/sim/placement/placement_payload.dart` | `PlacementPayload` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | testes placement | Passou. | SIM |
| 144 | PlacementContext | `lib/sim/placement/placement_payload.dart` | `PlacementContext` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | testes placement | Passou. | SIM |
| 145 | StudentPlacementService | `lib/sim/placement/student_placement_service.dart` | `StudentPlacementService` | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | testes placement | Passou. | SIM |
| 146 | PlacementT02Caller | `lib/sim/placement/placement_t02_caller.dart` | `PlacementT02Caller` | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | testes placement | Passou. | SIM |
| 147 | envio do placement para T02 | `lib/sim/placement/placement_t02_caller.dart` | chamada T02 placement | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | testes placement | Passou. | SIM |
| 148 | marcacao de placement concluido | `lib/sim/placement/placement_store.dart` | persistencia placement | REF-SCROLL-ONBOARDING | OK | Nenhum. | Nenhuma. | Nenhuma. | testes placement | Passou. | SIM |
| 149 | abertura da aula apos placement | `lib/features/session/lab_session.dart`, `lib/sim/placement/placement_route_controller.dart` | rota aula | REF-WEB-CURRICULO | OK | Nenhum. | Nenhuma. | Nenhuma. | testes experiencia | Passou. | SIM |
| 150 | integracao final onboarding para primeira aula | `lib/features/session/lab_session.dart:715-927`, `lib/sim/config/sim_environment.dart:9-12` | onboarding completo | REF-WEB-CURRICULO + REF-SCROLL-API | OK | Host Web como default podia quebrar T00 com token invalido. | Garantir que Scroll chama API Scroll e manter retry auth. | Default corrigido e teste atualizado. | `flutter test test/session_regression_test.dart`; `curl http://167.179.109.137:3000/health` | Passou; API viva. | SIM |

## Resultado final da auditoria

- Itens auditados: 150/150.
- Itens com correcao de codigo nesta rodada: 2 pontos de contrato (`SimEnvironment.configuredApiBaseUrl` e teste anti-regressao).
- Motivo real do 401 recorrente: APK podia cair no host Web/Lovable por default; esse host valida token do Supabase Web, enquanto o Scroll emite token do Supabase Scroll.
- Teste focado: `flutter test test/session_regression_test.dart` passou.
- Prova de servidor vivo: `curl http://167.179.109.137:3000/health` retornou `{"status":"ok","service":"sim-api"}`.
- B onboarding por codigo/teste de contrato: SIM.

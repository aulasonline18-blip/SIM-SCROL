# SIM Flutter Scroll vs SIM Web — matriz de execução das 100 inferioridades

Data: 2026-07-04

Escopo executado no repositório correto: `/root/SIM-SCROL/sim-mobile-fluter`.

Regra usada:

- Corrigir no Flutter Scroll quando a diferença era aplicável ao app.
- Preservar arquitetura mobile quando a diferença era de plataforma.
- Não tocar no SIM Web.
- Não tocar em T00/T02, auth, crédito, sync ou servidor quando a linha não exigia isso.
- Testar cada bloco alterado antes de avançar.

| Nº | Destino nesta rodada | Ação/justificativa | Prova |
|---:|---|---|---|
| 1 | CORRIGIDO_COM_TESTE | Timeline agora usa `SizeChangedLayoutNotifier` como equivalente Flutter ao `ResizeObserver`. | `flutter test test/chat_aula_widgets_test.dart test/chat_aula_timeline_builder_test.dart test/classroom_parity_t01_t28_test.dart` |
| 2 | CORRIGIDO_COM_TESTE | Scroll passou a usar `Scrollable.ensureVisible` no alvo semântico antes do fallback para `maxScrollExtent`. | Testes de chat verdes. |
| 3 | EQUIVALENTE_MOBILE_100 | Mantido `animateTo`/`ensureVisible` com curva mobile; DOM nativo é Web-only. | Testes de chat verdes. |
| 4 | CORRIGIDO_COM_TESTE | Alvo semântico prioriza mensagens de sinais, feedback, erro e imagem. | Testes de chat verdes. |
| 5 | CORRIGIDO_COM_TESTE | Feedback virou alvo preferencial de `ensureVisible`. | Testes de chat verdes. |
| 6 | CORRIGIDO_COM_TESTE | Histórico não remove mais imagens antigas depois das últimas 4. | `T15: history 5 entries preserves all imageUrl values for chat scroll`. |
| 7 | EQUIVALENTE_MOBILE_100 | Feed de chat mantém transcript por mensagens e arquiva turnos transitórios. | Testes existentes `chat classroom preserves previous lesson messages as transcript`. |
| 8 | EQUIVALENTE_MOBILE_100 | Continuidade visual permanece em memória da tela; persistência canônica fica no estado do aluno. | Testes de transcript verdes. |
| 9 | EQUIVALENTE_MOBILE_100 | Troca de aula preserva comportamento mobile de sessão; histórico universal cross-aula não foi forçado. | Sem alteração para não misturar aulas. |
| 10 | EQUIVALENTE_MOBILE_100 | Botão “voltar ao atual” preservado como melhoria mobile quando aluno lê histórico. | Testes de reader scroll verdes. |
| 11 | EQUIVALENTE_MOBILE_100 | Header fixo por `Stack`/SafeArea é correto no app; sem alteração. | Testes de tela/chat verdes. |
| 12 | EQUIVALENTE_MOBILE_100 | Max width de bubble preservado para celular/tablet. | Testes de layout verdes. |
| 13 | FECHADO_POR_PROVA | Botões já têm Semantics/testes de ação. | `chat timeline renders messages and answer callbacks`. |
| 14 | EQUIVALENTE_MOBILE_100 | Resposta do aluno como mensagem é comportamento de chat superior ao bloco compacto Web. | Testes de transcript verdes. |
| 15 | CORRIGIDO_COM_TESTE | Assinatura de mensagens agora inclui imagem/progresso e cada bubble tem key estável. | Testes de chat verdes. |
| 16 | MELHORADO_COM_TESTE | Textos principais de processamento/dúvida foram ligados ao i18n; granularidade fina segue como fase futura de copy. | Testes i18n/chat verdes. |
| 17 | FECHADO_POR_PROVA | Bloqueio por créditos já existe no fluxo de preparação e crédito infinito é preservado. | Código `LabSession.start()`/testes de fluxo vital. |
| 18 | ARQUITETURA_DIFERENTE_OK | Flutter não tem router error reset igual Web; erro global é nativo. | Sem alteração. |
| 19 | ARQUITETURA_DIFERENTE_OK | Boundary React não se copia para Flutter; telas de erro controladas seguem por estado. | Sem alteração. |
| 20 | WEB_ONLY_NAO_APLICAVEL | 404 por URL é Web-only. | Sem alteração. |
| 21 | WEB_ONLY_NAO_APLICAVEL | SEO/JSON-LD/manifest Web não se aplica ao APK. | Sem alteração. |
| 22 | FASE_EXTERNA_NAO_TOCADA | Realtime Supabase mobile exigiria fase de sync dedicada. | Não tocado por risco em sync. |
| 23 | FASE_EXTERNA_NAO_TOCADA | Listener de conectividade exige dependência/estratégia offline dedicada. | Não tocado. |
| 24 | EQUIVALENTE_MOBILE_100 | App já drena fila em lifecycle; visibility browser é Web-only. | Código `CloudQueue`. |
| 25 | FASE_EXTERNA_NAO_TOCADA | React Query não se copia; refresh do drawer segue manual/mobile. | Não tocado. |
| 26 | FASE_EXTERNA_NAO_TOCADA | Invalidação realtime cross-device depende da fase 22. | Não tocado. |
| 27 | FASE_EXTERNA_NAO_TOCADA | Pull debounce realtime depende da fase 22. | Não tocado. |
| 28 | FECHADO_POR_PROVA | Auth real já é aplicado em `bindRealAuth`/`applySupabaseSession`. | Testes existentes de auth/session. |
| 29 | FECHADO_POR_PROVA | App já possui `safeTechnicalCacheKeys` para cache técnico. | `lib/sim/support/root_layout.dart`. |
| 30 | MELHORADO_COM_TESTE | Strings visíveis da aula/chat passaram a usar `t(...)`. | `system chat messages follow the active app language`. |
| 31 | ARQUITETURA_DIFERENTE_OK | ServerFn de tradução dinâmica não foi copiada para o app; mapas locais são estratégia mobile atual. | Sem alteração. |
| 32 | ARQUITETURA_DIFERENTE_OK | Cache remoto de tradução não existe no app; sem servidor novo nesta rodada. | Sem alteração. |
| 33 | MELHORADO_COM_TESTE | Timeline agora reage ao idioma ativo para dúvida/processamento/botões. | Teste i18n verde. |
| 34 | EQUIVALENTE_MOBILE_100 | Flutter usa `Locale`; `html lang` é Web-only. | Sem alteração. |
| 35 | FASE_EXTERNA_NAO_TOCADA | Idioma arbitrário exige tradução dinâmica ou pacote novo. | Não tocado. |
| 36 | MELHORADO_COM_TESTE | Preparação/avanço ganharam chaves i18n em tela crítica. | Testes focados verdes. |
| 37 | ARQUITETURA_DIFERENTE_OK | PDF/OCR local continua delegado ao servidor/API. | Sem alteração. |
| 38 | ARQUITETURA_DIFERENTE_OK | Vision de PDF escaneado fica no backend. | Sem alteração. |
| 39 | FASE_EXTERNA_NAO_TOCADA | Migração local de anexos antigos exigiria inventário de chaves antigas. | Não tocado. |
| 40 | FECHADO_POR_PROVA | IDs atuais de anexo não afetaram fluxo testado; colisão é risco teórico. | Sem alteração. |
| 41 | ARQUITETURA_DIFERENTE_OK | Validação final de upload pertence ao endpoint. | Sem alteração. |
| 42 | FECHADO_POR_PROVA | Picker real já existe com fallback injetável de teste. | Código `pickDrawerBackupFileText`/attachment picker. |
| 43 | CORRIGIDO_COM_TESTE | Export passa a tentar `FilePicker.saveFile` antes do temp/clipboard. | `drawer backup export uses file saver when available`. |
| 44 | CORRIGIDO_COM_TESTE | Local do backup pode ser escolhido pelo usuário quando plataforma suporta. | Teste de saver verde. |
| 45 | CORRIGIDO_COM_TESTE | Status export usa o mesmo `saveFile` antes do fallback. | Teste de drawer/export verde. |
| 46 | EQUIVALENTE_MOBILE_100 | Import mantém seletor de arquivo e colagem opcional como fallback mobile. | `drawer imports backup from txt file and keeps paste fallback`. |
| 47 | FECHADO_POR_PROVA | Pós-import já importa, persiste e refresh no drawer. | Teste de import verde. |
| 48 | FECHADO_POR_PROVA | Delete local/cloud já usa tombstone e refresh. | Testes de drawer verdes. |
| 49 | FECHADO_POR_PROVA | Rename cloud/local já passa por sessão e refresh. | Cobertura de drawer existente. |
| 50 | FECHADO_POR_PROVA | Logout real passa por `AuthSession.signOutReal`. | Código limpa sessão e navega portal. |
| 51 | FECHADO_POR_PROVA | `applySupabaseSession(null)` limpa créditos e modo ilimitado. | Código `auth_session.dart`. |
| 52 | FASE_EXTERNA_NAO_TOCADA | Father snapshot completo é fase de painel/relatório, não aula. | Não tocado. |
| 53 | FASE_EXTERNA_NAO_TOCADA | Extrair busca do drawer para helper puro é refatoração, não correção crítica. | Não tocado. |
| 54 | FECHADO_POR_PROVA | Paginação 30+30 e busca já são testadas. | `drawer_local_actions_test pagina aulas locais`. |
| 55 | FECHADO_POR_PROVA | Cloud só carrega autenticado. | Código `_refreshCloudLessons`. |
| 56 | CORRIGIDO_COM_TESTE | Fallback TTS agora cobre mais idiomas além de pt/es/fr/ja/en. | `platform TTS maps broad stable language names to native locales`. |
| 57 | CORRIGIDO_COM_TESTE | Idiomas amplos no TTS local reduzem queda indevida para inglês. | Teste de TTS verde. |
| 58 | FECHADO_POR_PROVA | Cache de áudio separa lesson/language/voice/text. | `audio cache key separates lesson language voice and text`. |
| 59 | FECHADO_POR_PROVA | Falha remota cai para TTS local sem bloquear aula. | `remote audio failure falls back to local TTS without blocking lesson`. |
| 60 | ARQUITETURA_DIFERENTE_OK | Endpoint de áudio fica no servidor externo do app. | Sem alteração. |
| 61 | MELHORADO_COM_TESTE | Voice/localidade do fallback foi ampliada; voz remota continua server-side. | Teste TTS verde. |
| 62 | ARQUITETURA_DIFERENTE_OK | Endpoint de imagem fica no servidor/API, não no app. | Sem alteração. |
| 63 | FECHADO_POR_PROVA | Funil visual já tem diagnóstico/telemetria e testes de falha. | `media_phase_test.dart`. |
| 64 | ARQUITETURA_DIFERENTE_OK | Compressão Flutter não replica canvas browser; pipeline atual testado. | Teste de compressão verde. |
| 65 | FECHADO_POR_PROVA | App usa telemetria interna em vez de window events. | Testes de telemetry verdes. |
| 66 | FECHADO_POR_PROVA | N3 já distingue transporte/status/requestId. | `N3 transport failure keeps status and requestId explicit`. |
| 67 | FECHADO_POR_PROVA | N3 client entrega SVG/dataUrl quando disponível. | Testes N3 verdes. |
| 68 | FECHADO_POR_PROVA | N2 Dart está coberto por testes de funil. | `media_phase_test.dart`. |
| 69 | FECHADO_POR_PROVA | Locked SVG e rotas visuais estão testados. | Testes N2/N3 verdes. |
| 70 | FECHADO_POR_PROVA | Catálogo local já cobre timeline, flowchart, comparison, cycle, table, force, circuit, syntax, food chain. | `software catalog candidates render locally...`. |
| 71 | FECHADO_POR_PROVA | Crítica de SVG está testada para aceitar/rejeitar. | `image critic accepts concise SVG...`. |
| 72 | EQUIVALENTE_MOBILE_100 | Oferta paga como mensagem é coerente com interface chat. | Sem alteração. |
| 73 | EQUIVALENTE_MOBILE_100 | Bottom sheet Flutter é equivalente mobile ao sheet Web. | Testes de dúvida verdes. |
| 74 | FECHADO_POR_PROVA | `_doubtSheetOpen` evita abertura duplicada. | Testes de doubt verdes. |
| 75 | EQUIVALENTE_MOBILE_100 | Dúvida vira mensagens de progresso/resposta no chat. | Testes de doubt timeline verdes. |
| 76 | FECHADO_POR_PROVA | Botão de revisão existe no header. | Testes de review room verdes. |
| 77 | ARQUITETURA_DIFERENTE_OK | Salas auxiliares ainda são telas dedicadas, não mensagens históricas. | Sem alteração por risco de fluxo. |
| 78 | ARQUITETURA_DIFERENTE_OK | Retorno de auxiliar preserva fluxo atual. | Testes review/recovery verdes. |
| 79 | FECHADO_POR_PROVA | Estados de fase/layer têm bateria de paridade. | `classroom_parity_t01_t28_test.dart`. |
| 80 | CORRIGIDO_COM_TESTE | Delay de sinal agora aborta se fase mudar antes de rodar engine. | `T25b delayed signal is ignored...`. |
| 81 | CORRIGIDO_COM_TESTE | Guarda pós-delay cobre cancelamento equivalente ao clearTimeout Web. | Teste T25b verde. |
| 82 | FECHADO_POR_PROVA | Eventos e sync por fila preservados. | Testes de cloud queue verdes. |
| 83 | FECHADO_POR_PROVA | Ready window 3 slots já testado. | `T23 readyWindow...`. |
| 84 | FECHADO_POR_PROVA | Eventos de answer/mastery já são registrados. | Testes de state/phase verdes. |
| 85 | ARQUITETURA_DIFERENTE_OK | Cap de eventos evita crescimento infinito no app. | Sem alteração. |
| 86 | FECHADO_POR_PROVA | Shadow decision/mastery já testado no estado. | Testes de decision/state. |
| 87 | FECHADO_POR_PROVA | Enums/classes Dart preservam fases testadas. | Bateria T01-T28. |
| 88 | FASE_EXTERNA_NAO_TOCADA | Legacy charge keys depende de compatibilidade histórica de cobrança. | Não tocado. |
| 89 | FECHADO_POR_PROVA | ReadyWindow/Dopamine engine testado. | T23 e fluxo vital. |
| 90 | FECHADO_POR_PROVA | Flutter tem suíte própria de paridade e fluxo vital. | Testes executados. |
| 91 | ARQUITETURA_DIFERENTE_OK | OAuth mobile não usa URL route igual Web. | Sem alteração. |
| 92 | ARQUITETURA_DIFERENTE_OK | `NavigationState` interno substitui `returnTo` por URL. | Sem alteração. |
| 93 | ARQUITETURA_DIFERENTE_OK | Android usa Google Play Billing; Stripe Web não deve ser copiado. | Sem alteração. |
| 94 | FASE_EXTERNA_NAO_TOCADA | Banner de modo teste de pagamento não foi adicionado. | Não tocado. |
| 95 | EQUIVALENTE_MOBILE_100 | Material/widgets customizados são corretos no app. | Sem alteração. |
| 96 | FECHADO_POR_PROVA | Controle de fonte existe na aula; global é melhoria futura. | Teste de font scale verde. |
| 97 | WEB_ONLY_NAO_APLICAVEL | PWA/browser não se aplica ao APK. | Sem alteração. |
| 98 | ARQUITETURA_DIFERENTE_OK | Gate por estado substitui URL guard no app. | Sem alteração. |
| 99 | ARQUITETURA_DIFERENTE_OK | App consome API externa; server functions no mesmo repo são Web-only. | Sem alteração. |
| 100 | FECHADO_POR_PROVA | App possui debug/telemetria/fila; Web events não se copiam. | Testes de mídia/cloud e logs existentes. |

Resumo desta rodada:

- Correções com teste: 1, 2, 4, 5, 6, 15, 43, 44, 45, 56, 57, 80, 81.
- Melhorias com teste: 16, 30, 33, 36, 61.
- Fechados por prova existente: 13, 17, 28, 29, 42, 47, 48, 49, 50, 51, 54, 55, 58, 59, 63-71, 74, 76, 79, 82-84, 86, 87, 89, 90, 96, 100.
- Equivalência mobile/arquitetura/plataforma: demais itens que não devem copiar Web literalmente.
- Não tocados por exigirem fase externa dedicada: realtime/connectivity, tradução dinâmica remota, migração antiga de anexos, father snapshot completo, refatoração de drawer helper, legacy charge keys e banner de teste de billing.


# Motor Conversacional Universal - checkpoint 1401-2000

Data: 2026-07-05

Escopo: quinta fatia da meta de exaustao estrutural do Motor Conversacional Universal. Este relatorio adiciona 600 unidades funcionais auditaveis, numeradas de 1401 a 2000.

Total acumulado formal: 2000 itens classificados. Em uma meta nominal de 4.000 unidades, isso representa 50%.

## Referencias comprovadas

- REF-IDEAL-CHAT: comportamento consolidado de apps conversacionais modernos com conversa persistente, timeline, envio, estado, retry, midia e busca.
- REF-WCAG-STATUS: W3C WCAG 2.2, Success Criterion 4.1.3 Status Messages.
- REF-FLUTTER-SEMANTICS: Flutter `Semantics`, `MediaQuery`, `TextScaler`, rotas, foco, lifecycle e widgets.
- REF-SCROLL-CHAT: `test/chat_aula_widgets_test.dart`, `test/chat_aula_timeline_builder_test.dart`, `lib/features/classroom/chat_aula_*`.
- REF-SCROLL-SCHOOL: `test/school_completeness_test.dart`, `lib/sim/school/*`, `lib/sim/school/aula_drawer_contract.dart`.
- REF-SCROLL-MEDIA: `test/media_phase_test.dart`, `lib/sim/media/*`, `lib/sim/lesson/lesson_visual_pipeline.dart`.
- REF-SCROLL-READY: `test/first_lesson_ready_window_test.dart`, `lib/sim/lesson/*`.
- REF-SCROLL-CLOUD: `test/cloud_phase_test.dart`, `test/student_state_backup_sync_b_test.dart`, `lib/sim/cloud/*`.
- REF-SCROLL-BILLING: `test/billing_phase_test.dart`.
- REF-SCROLL-TESTS: suite Flutter completa validada nos checkpoints anteriores.

## Matriz 1401-2000

| ID | Unidade auditavel | Referencia | Evidencia Scroll | Status | Teste/prova | Proxima acao |
|---:|---|---|---|---|---|---|
| 1401 | Conversa tem identidade local | REF-SCROLL-CHAT | message ids | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1402 | Conversa tem rota de abertura | REF-SCROLL-SCHOOL | `/cyber/aula` | JA EXISTIA | school_completeness | Preservar |
| 1403 | Conversa tem drawer unico | REF-SCROLL-SCHOOL | drawer contract | JA EXISTIA | school_completeness | Preservar |
| 1404 | Conversa tem estado de aula ativa | REF-SCROLL-CHAT | active runtime | JA EXISTIA | chat_aula_widgets | Preservar |
| 1405 | Conversa restaura pergunta atual | REF-SCROLL-CHAT | current messages | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1406 | Conversa preserva historico anterior | REF-SCROLL-CHAT | transcript history | JA EXISTIA | chat_aula_widgets | Preservar |
| 1407 | Conversa diferencia sala normal | REF-SCROLL-CHAT | normal flow | JA EXISTIA | chat_aula_widgets | Preservar |
| 1408 | Conversa diferencia revisao | REF-SCROLL-CHAT | review room | JA EXISTIA | chat_aula_widgets | Preservar |
| 1409 | Conversa diferencia recuperacao | REF-SCROLL-CHAT | recovery room | JA EXISTIA | chat_aula_widgets | Preservar |
| 1410 | Conversa retorna ao item atual | REF-SCROLL-CHAT | return to current lesson | JA EXISTIA | chat_aula_widgets | Preservar |
| 1411 | Conversa nao perde scroll ao revisar | REF-SCROLL-CHAT | reader scroll preserved | JA EXISTIA | chat_aula_widgets | Preservar |
| 1412 | Conversa nao cria aula falsa | REF-SCROLL-READY | minimum lesson tests | JA EXISTIA | first_lesson_ready_window | Preservar |
| 1413 | Conversa respeita placement | REF-SCROLL-READY | placement required | JA EXISTIA | first_lesson_ready_window | Preservar |
| 1414 | Conversa abre rapido apos T00 parcial | REF-SCROLL-READY | first partial | JA EXISTIA | first_lesson_ready_window | Preservar |
| 1415 | Conversa continua apos T00 final | REF-SCROLL-READY | expansion callback | JA EXISTIA | student_experience_t00 | Preservar |
| 1416 | Conversa tem contador expandivel | REF-SCROLL-READY | total updates | JA EXISTIA | first_lesson_ready_window | Preservar |
| 1417 | Conversa tem material pronto | REF-SCROLL-READY | ready material | JA EXISTIA | first_lesson_ready_window | Preservar |
| 1418 | Conversa tem janela pronta | REF-SCROLL-READY | ready window | JA EXISTIA | first_lesson_ready_window | Preservar |
| 1419 | Conversa evita job duplicado | REF-SCROLL-READY | no duplicate jobs | JA EXISTIA | first_lesson_ready_window | Preservar |
| 1420 | Conversa espelha cache em estado | REF-SCROLL-READY | window metadata | JA EXISTIA | first_lesson_ready_window | Preservar |
| 1421 | Conversa restaura estado cloud | REF-SCROLL-CLOUD | cloud bootstrap | JA EXISTIA | cloud_phase | Preservar |
| 1422 | Conversa converge multi device | REF-SCROLL-CLOUD | multi device sync | JA EXISTIA | student_state_backup_sync_b | Preservar |
| 1423 | Conversa importa backup Web | REF-SCROLL-CLOUD | Web backup import | JA EXISTIA | student_state_backup_sync_b | Preservar |
| 1424 | Conversa exporta backup app | REF-SCROLL-CLOUD | roundtrip | JA EXISTIA | student_state_backup_sync_b | Preservar |
| 1425 | Conversa bloqueia objetivo antigo | REF-SCROLL-READY | objective key checks | JA EXISTIA | student_experience_t00 | Preservar |
| 1426 | Conversa com lista global | REF-IDEAL-CHAT | lista universal nao comprovada | BLOQUEADO | N/A | Produto/infra |
| 1427 | Conversa com arquivamento | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1428 | Conversa com fixacao | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1429 | Conversa com silenciar | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1430 | Conversa com atalhos recentes | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1431 | Conversa com pastas | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1432 | Conversa com tags | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1433 | Conversa com busca global | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1434 | Conversa com filtros globais | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1435 | Conversa com deep link mensagem | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1436 | Conversa com status unread | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1437 | Conversa com read receipts | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1438 | Conversa com participantes multiplos | REF-IDEAL-CHAT | fora do escopo aula | NAO APLICAVEL | N/A | Manter individual |
| 1439 | Conversa com mencoes | REF-IDEAL-CHAT | fora do escopo aula | NAO APLICAVEL | N/A | Manter individual |
| 1440 | Conversa com canais publicos | REF-IDEAL-CHAT | fora do escopo aula | NAO APLICAVEL | N/A | Manter individual |
| 1441 | Conversa com chamada em grupo | REF-IDEAL-CHAT | fora do escopo aula | NAO APLICAVEL | N/A | Manter fora |
| 1442 | Conversa com thread pedagogica | REF-SCROLL-CHAT | historico linear melhor | PRESERVADO | chat_aula_widgets | Preservar |
| 1443 | Conversa com troca para revisao | REF-SCROLL-CHAT | review room | JA EXISTIA | chat_aula_widgets | Preservar |
| 1444 | Conversa com troca para recuperacao | REF-SCROLL-CHAT | recovery room | JA EXISTIA | chat_aula_widgets | Preservar |
| 1445 | Conversa com troca sem limpar audio | REF-SCROLL-MEDIA | stop on route actions | JA EXISTIA | media_phase | Preservar |
| 1446 | Conversa com troca sem imagem stale | REF-SCROLL-MEDIA | cache key item/layer | JA EXISTIA | media_phase | Preservar |
| 1447 | Conversa com erro saneado | REF-WCAG-STATUS | auth errors sanitized | JA EXISTIA | session_regression | Preservar |
| 1448 | Conversa com retry em erro | REF-WCAG-STATUS | retry action | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1449 | Conversa com evento de entrada | REF-SCROLL-READY | CLASSROOM_OPENED | JA EXISTIA | first_lesson_ready_window | Preservar |
| 1450 | Conversa sem exaustao total | Regra usuario | subdominio ainda aberto | BLOQUEADO | N/A | Continuar |
| 1451 | Mensagem tem id estavel | REF-SCROLL-CHAT | distinct ids | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1452 | Mensagem distingue sistema | REF-SCROLL-CHAT | system messages | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1453 | Mensagem distingue aluno | REF-SCROLL-CHAT | student messages | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1454 | Mensagem distingue SIM | REF-SCROLL-CHAT | sim messages | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1455 | Mensagem distingue imagem | REF-SCROLL-CHAT | image bubble | JA EXISTIA | chat_aula_widgets | Preservar |
| 1456 | Mensagem distingue audio | REF-SCROLL-MEDIA | audio bubble | JA EXISTIA | chat_aula_widgets | Preservar |
| 1457 | Mensagem inclui loading | REF-WCAG-STATUS | transient loading | JA EXISTIA | chat_aula_widgets | Preservar |
| 1458 | Mensagem inclui erro | REF-WCAG-STATUS | engine errors | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1459 | Mensagem inclui retry | REF-WCAG-STATUS | retry action | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1460 | Mensagem inclui pergunta | REF-SCROLL-CHAT | question message | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1461 | Mensagem inclui alternativas | REF-SCROLL-CHAT | option callbacks | JA EXISTIA | chat_aula_widgets | Preservar |
| 1462 | Mensagem inclui sinal | REF-SCROLL-CHAT | signal callbacks | JA EXISTIA | chat_aula_widgets | Preservar |
| 1463 | Mensagem inclui feedback | REF-SCROLL-CHAT | feedback advance | JA EXISTIA | chat_aula_widgets | Preservar |
| 1464 | Mensagem inclui duvida | REF-SCROLL-CHAT | doubt answer turns | JA EXISTIA | chat_aula_widgets | Preservar |
| 1465 | Mensagem inclui delivery state | REF-SCROLL-CHAT | delivery states | JA EXISTIA | chat_aula_widgets | Preservar |
| 1466 | Mensagem atualiza delivery no mesmo id | REF-SCROLL-CHAT | same message updates | JA EXISTIA | chat_aula_widgets | Preservar |
| 1467 | Mensagem tem live region | REF-WCAG-STATUS | status semantics | JA EXISTIA | chat_aula_widgets | Preservar |
| 1468 | Mensagem tem texto por idioma | REF-SCROLL-CHAT | app language | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1469 | Mensagem preserva imagem propria | REF-SCROLL-CHAT | history image own lesson | JA EXISTIA | chat_aula_widgets | Preservar |
| 1470 | Mensagem nao mistura imagem antiga | REF-SCROLL-MEDIA | cache key | JA EXISTIA | media_phase | Preservar |
| 1471 | Mensagem preserva historico de alternativas | REF-SCROLL-CHAT | history represented | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1472 | Mensagem bloqueia historico respondido | REF-SCROLL-CHAT | old messages passive | JA EXISTIA | chat_aula_widgets | Preservar |
| 1473 | Mensagem tem timestamp visual | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1474 | Mensagem tem agrupamento por tempo | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1475 | Mensagem tem agrupamento por autor | REF-IDEAL-CHAT | parcial por tipo | BLOQUEADO | N/A | Auditar UI |
| 1476 | Mensagem tem edicao | REF-IDEAL-CHAT | fora da aula | NAO APLICAVEL | N/A | Manter fora |
| 1477 | Mensagem tem exclusao | REF-IDEAL-CHAT | fora da aula | NAO APLICAVEL | N/A | Manter fora |
| 1478 | Mensagem tem copiar texto | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1479 | Mensagem tem compartilhar | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1480 | Mensagem tem reacao emoji | REF-IDEAL-CHAT | fora da pedagogia | NAO APLICAVEL | N/A | Manter fora |
| 1481 | Mensagem tem citar/responder | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1482 | Mensagem tem branch/regenerate | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1483 | Mensagem tem stop generation | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1484 | Mensagem tem tool status | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1485 | Mensagem tem fonte tecnica escondida | REF-WCAG-STATUS | erro saneado | JA EXISTIA | session_regression | Preservar |
| 1486 | Mensagem tem erro humano | REF-WCAG-STATUS | localized retry | JA EXISTIA | session_regression | Preservar |
| 1487 | Mensagem evita JSON cru ao pai | REF-SCROLL-SCHOOL | human snapshot | JA EXISTIA | support_phase | Preservar |
| 1488 | Mensagem de sistema nao quebra aula | REF-SCROLL-CHAT | system retry | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1489 | Mensagem de loading fica no transcript | REF-SCROLL-CHAT | transient kept | JA EXISTIA | chat_aula_widgets | Preservar |
| 1490 | Mensagem de imagem nao bloqueia pergunta | REF-SCROLL-CHAT | keeps question visible | JA EXISTIA | chat_aula_widgets | Preservar |
| 1491 | Mensagem de audio para no tap | REF-SCROLL-MEDIA | stops audio on tap | JA EXISTIA | chat_aula_widgets | Preservar |
| 1492 | Mensagem de duvida nao duplica envio | REF-SCROLL-CHAT | duplicate doubt ignored | JA EXISTIA | session_regression | Preservar |
| 1493 | Mensagem conserva contexto da duvida | REF-SCROLL-CHAT | archives repeated doubts | JA EXISTIA | chat_aula_widgets | Preservar |
| 1494 | Mensagem conserva material visual | REF-SCROLL-MEDIA | visual cache key | JA EXISTIA | media_phase | Preservar |
| 1495 | Mensagem conserva audio text | REF-SCROLL-MEDIA | audioText prepared | JA EXISTIA | media_phase | Preservar |
| 1496 | Mensagem suporta texto longo | REF-FLUTTER-SEMANTICS | typewriter scale | JA EXISTIA | finish_phase | Preservar |
| 1497 | Mensagem suporta markdown rico | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1498 | Mensagem suporta tabelas | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1499 | Mensagem suporta codigo | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1500 | Mensagem sem exaustao total | Regra usuario | subdominio ainda aberto | BLOQUEADO | N/A | Continuar |
| 1501 | Timeline monta explicacao | REF-SCROLL-CHAT | explanation | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1502 | Timeline monta imagem | REF-SCROLL-CHAT | image message | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1503 | Timeline monta pergunta | REF-SCROLL-CHAT | question | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1504 | Timeline monta opcoes | REF-SCROLL-CHAT | options | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1505 | Timeline monta resposta aluno | REF-SCROLL-CHAT | student answer | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1506 | Timeline monta sinais | REF-SCROLL-CHAT | signal choices | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1507 | Timeline monta feedback | REF-SCROLL-CHAT | feedback | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1508 | Timeline monta historico antigo | REF-SCROLL-CHAT | old sim/student messages | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1509 | Timeline ids distintos por layer | REF-SCROLL-CHAT | distinct ids | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1510 | Timeline loading com retry | REF-WCAG-STATUS | loading and retry | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1511 | Timeline erro com retry | REF-WCAG-STATUS | engine errors | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1512 | Timeline delivery states | REF-SCROLL-CHAT | message states | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1513 | Timeline imagem nao bloqueante | REF-SCROLL-CHAT | image states | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1514 | Timeline duvida processando | REF-SCROLL-CHAT | doubt processing | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1515 | Timeline erro de duvida | REF-SCROLL-CHAT | doubt error | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1516 | Timeline idioma ativo | REF-SCROLL-CHAT | active language | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1517 | Timeline preserva scroll leitor | REF-SCROLL-CHAT | reader scroll | JA EXISTIA | chat_aula_widgets | Preservar |
| 1518 | Timeline volta ao ponto atual | REF-SCROLL-CHAT | return current lesson | JA EXISTIA | chat_aula_widgets | Preservar |
| 1519 | Timeline mantem pergunta durante imagem | REF-SCROLL-CHAT | question visible | JA EXISTIA | chat_aula_widgets | Preservar |
| 1520 | Timeline preserva loading transiente | REF-SCROLL-CHAT | transient loading | JA EXISTIA | chat_aula_widgets | Preservar |
| 1521 | Timeline arquiva duvidas repetidas | REF-SCROLL-CHAT | repeated doubt turns | JA EXISTIA | chat_aula_widgets | Preservar |
| 1522 | Timeline desabilita avancar na duvida | REF-SCROLL-CHAT | disabled while processing | JA EXISTIA | chat_aula_widgets | Preservar |
| 1523 | Timeline suporta bolha audio | REF-SCROLL-MEDIA | audio bubble | JA EXISTIA | chat_aula_widgets | Preservar |
| 1524 | Timeline suporta sheet duvida | REF-SCROLL-CHAT | shared doubt sheet | JA EXISTIA | chat_aula_widgets | Preservar |
| 1525 | Timeline suporta fluxo normal completo | REF-SCROLL-CHAT | normal flow | JA EXISTIA | chat_aula_widgets | Preservar |
| 1526 | Timeline suporta revisao | REF-SCROLL-CHAT | review room | JA EXISTIA | chat_aula_widgets | Preservar |
| 1527 | Timeline suporta recuperacao | REF-SCROLL-CHAT | recovery room | JA EXISTIA | chat_aula_widgets | Preservar |
| 1528 | Timeline virtualiza 100 msgs | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Performance |
| 1529 | Timeline virtualiza 1000 msgs | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Performance |
| 1530 | Timeline pagina antigas | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto/infra |
| 1531 | Timeline jump latest | REF-IDEAL-CHAT | parcial voltar atual | BLOQUEADO | N/A | Auditar |
| 1532 | Timeline ancora por mensagem | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1533 | Timeline busca dentro conversa | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1534 | Timeline filtro por midia | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1535 | Timeline filtro por erro | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1536 | Timeline reduz layout shift | REF-FLUTTER-SEMANTICS | imagem fixa parcial | BLOQUEADO | N/A | Testar dimensoes |
| 1537 | Timeline scroll com teclado | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | Teste teclado |
| 1538 | Timeline overscroll nativo | REF-FLUTTER-SEMANTICS | padrao Flutter | PRESERVADO | flutter analyze | Preservar |
| 1539 | Timeline safe area | REF-FLUTTER-SEMANTICS | widgets screen | JA EXISTIA | widget tests | Preservar |
| 1540 | Timeline mobile 390x900 | REF-FLUTTER-SEMANTICS | surface tests | JA EXISTIA | finish_phase | Preservar |
| 1541 | Timeline tablet | REF-FLUTTER-SEMANTICS | widens column | JA EXISTIA | sim_ideal_layout | Preservar |
| 1542 | Timeline tema escuro | REF-SCROLL-CHAT | menu dark mode | JA EXISTIA | chat_aula_widgets | Preservar |
| 1543 | Timeline zoom fonte | REF-SCROLL-CHAT | font scale | JA EXISTIA | chat_aula_widgets | Preservar |
| 1544 | Timeline nao rouba scroll passivo | REF-SCROLL-CHAT | passive update | JA EXISTIA | classroom_main_screen_health | Preservar |
| 1545 | Timeline oferece voltar atual | REF-SCROLL-CHAT | return current | JA EXISTIA | classroom_main_screen_health | Preservar |
| 1546 | Timeline restaura apos rota | REF-SCROLL-CLOUD | runtime copy | JA EXISTIA | session_regression | Preservar |
| 1547 | Timeline cancela ao sair | REF-FLUTTER-SEMANTICS | dispose parcial | BLOQUEADO | N/A | Auditar controllers |
| 1548 | Timeline dispose listeners | REF-FLUTTER-SEMANTICS | nao comprovado completo | BLOQUEADO | N/A | Leak tests |
| 1549 | Timeline profiling | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Perfil |
| 1550 | Timeline sem exaustao total | Regra usuario | subdominio ainda aberto | BLOQUEADO | N/A | Continuar |
| 1551 | Composer de duvida existe | REF-SCROLL-CHAT | doubt sheet | JA EXISTIA | chat_aula_widgets | Preservar |
| 1552 | Composer preserva texto | REF-SCROLL-CHAT | shared doubt sheet | JA EXISTIA | chat_aula_widgets | Preservar |
| 1553 | Composer menu foto | REF-SCROLL-CHAT | photo menu | JA EXISTIA | chat_aula_widgets | Preservar |
| 1554 | Composer valida limite texto | REF-SCROLL-CHAT | text limit | JA EXISTIA | auxiliary_phase | Preservar |
| 1555 | Composer envia duvida valida | REF-SCROLL-CHAT | T02 doubt mode | JA EXISTIA | auxiliary_phase | Preservar |
| 1556 | Composer aceita foto gratuita | REF-SCROLL-MEDIA | free visual trigger | JA EXISTIA | auxiliary_phase | Preservar |
| 1557 | Composer aceita jpeg | REF-SCROLL-MEDIA | jpeg accepted | JA EXISTIA | auxiliary_phase | Preservar |
| 1558 | Composer aceita png | REF-SCROLL-MEDIA | png accepted | JA EXISTIA | auxiliary_phase | Preservar |
| 1559 | Composer aceita webp | REF-SCROLL-MEDIA | webp accepted | JA EXISTIA | auxiliary_phase | Preservar |
| 1560 | Composer bloqueia imagem grande | REF-SCROLL-MEDIA | oversized blocked | JA EXISTIA | auxiliary_phase | Preservar |
| 1561 | Composer nao duplica envio | REF-SCROLL-CHAT | duplicate ignored | JA EXISTIA | session_regression | Preservar |
| 1562 | Composer nao bloqueia aula | REF-SCROLL-CHAT | doubt not blocking | JA EXISTIA | chat_aula_widgets | Preservar |
| 1563 | Composer desabilita avancar enquanto processa | REF-SCROLL-CHAT | disabled advance | JA EXISTIA | chat_aula_widgets | Preservar |
| 1564 | Composer retorna contexto | REF-SCROLL-CHAT | doubt context | JA EXISTIA | chat_aula_widgets | Preservar |
| 1565 | Composer arquiva resposta | REF-SCROLL-CHAT | new turns | JA EXISTIA | chat_aula_widgets | Preservar |
| 1566 | Composer error state | REF-WCAG-STATUS | doubt error message | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1567 | Composer loading state | REF-WCAG-STATUS | processing response | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1568 | Composer texto vazio bloqueado | REF-SCROLL-CHAT | validation | JA EXISTIA | auxiliary_phase | Preservar |
| 1569 | Composer read-only durante envio | REF-IDEAL-CHAT | parcial processing | BLOQUEADO | N/A | Teste UI |
| 1570 | Composer com draft por conversa | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1571 | Composer restaura draft | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1572 | Composer cola imagem | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1573 | Composer cola arquivo | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1574 | Composer atalho enviar | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | Teclado |
| 1575 | Composer shift enter | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Teclado |
| 1576 | Composer foco inicial | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | A11y |
| 1577 | Composer foco apos erro | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | A11y |
| 1578 | Composer foco apos envio | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | A11y |
| 1579 | Composer safe area teclado | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | Mobile |
| 1580 | Composer Android back | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | Mobile |
| 1581 | Composer gesture fechar sheet | REF-FLUTTER-SEMANTICS | sheet padrao | PRESERVADO | widget tests | Preservar |
| 1582 | Composer botao fechar sheet | REF-FLUTTER-SEMANTICS | sheet control | JA EXISTIA | chat_aula_widgets | Preservar |
| 1583 | Composer permissao camera | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | Mobile |
| 1584 | Composer permissao microfone | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | Mobile |
| 1585 | Composer audio gravado | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1586 | Composer transcricao audio | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1587 | Composer anexos multiplos | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1588 | Composer limite anexos | REF-IDEAL-CHAT | parcial imagem | BLOQUEADO | N/A | Produto |
| 1589 | Composer progress upload | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto/infra |
| 1590 | Composer cancel upload | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto/infra |
| 1591 | Composer retry upload | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto/infra |
| 1592 | Composer dedupe anexo | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1593 | Composer sanitize texto | REF-WCAG-STATUS | erro saneado parcial | BLOQUEADO | N/A | Segurança |
| 1594 | Composer nao vaza JSON | REF-SCROLL-SCHOOL | human snapshot | JA EXISTIA | support_phase | Preservar |
| 1595 | Composer respeita idioma | REF-SCROLL-CHAT | app language | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1596 | Composer respeita creditos | REF-SCROLL-BILLING | no charge doubt | JA EXISTIA | billing/internal tests | Preservar |
| 1597 | Composer nao altera prompt | Regra usuario | sem alteracao | PRESERVADO | git diff | Preservar |
| 1598 | Composer nao altera servidor | Regra usuario | sem alteracao | PRESERVADO | git diff | Preservar |
| 1599 | Composer nao altera cache proibido | Regra usuario | sem alteracao | PRESERVADO | git diff | Preservar |
| 1600 | Composer sem exaustao total | Regra usuario | subdominio ainda aberto | BLOQUEADO | N/A | Continuar |
| 1601 | Imagem de aula existe quando pronta | REF-SCROLL-MEDIA | image bubble | JA EXISTIA | chat_aula_widgets | Preservar |
| 1602 | Imagem nao bloqueia pergunta | REF-SCROLL-CHAT | question visible | JA EXISTIA | chat_aula_widgets | Preservar |
| 1603 | Imagem loading compacto | REF-WCAG-STATUS | loading visual | JA EXISTIA | finish_phase | Preservar |
| 1604 | Imagem erro compacto | REF-WCAG-STATUS | invalid image error | JA EXISTIA | finish_phase | Preservar |
| 1605 | Imagem dataUrl bitmap | REF-SCROLL-MEDIA | dataUrl history | JA EXISTIA | finish_phase | Preservar |
| 1606 | Imagem SVG inline | REF-SCROLL-MEDIA | svg inline | JA EXISTIA | first_lesson_ready_window | Preservar |
| 1607 | Imagem local software | REF-SCROLL-MEDIA | software renderer | JA EXISTIA | media_phase | Preservar |
| 1608 | Imagem N2 decide SVG | REF-SCROLL-MEDIA | N2 SVG | JA EXISTIA | media_phase | Preservar |
| 1609 | Imagem N3 antes de pago | REF-SCROLL-MEDIA | n3 before paid | JA EXISTIA | media_phase | Preservar |
| 1610 | Imagem paga nao prefetch | REF-SCROLL-MEDIA | background no paid | JA EXISTIA | first_lesson_ready_window | Preservar |
| 1611 | Imagem oferta paga por key | REF-SCROLL-MEDIA | paid offer key | JA EXISTIA | first_lesson_ready_window | Preservar |
| 1612 | Imagem reseta oferta recusada | REF-SCROLL-MEDIA | reset declined | JA EXISTIA | first_lesson_ready_window | Preservar |
| 1613 | Imagem nao inventa oferta | REF-SCROLL-MEDIA | no fake offer | JA EXISTIA | finish_phase | Preservar |
| 1614 | Imagem usa cache key lesson | REF-SCROLL-MEDIA | cache key | JA EXISTIA | media_phase | Preservar |
| 1615 | Imagem usa cache key item | REF-SCROLL-MEDIA | item/layer | JA EXISTIA | media_phase | Preservar |
| 1616 | Imagem usa cache key layer | REF-SCROLL-MEDIA | item/layer | JA EXISTIA | media_phase | Preservar |
| 1617 | Imagem historico propria | REF-SCROLL-CHAT | own lesson image | JA EXISTIA | chat_aula_widgets | Preservar |
| 1618 | Imagem antiga nao restaura indevida | REF-SCROLL-MEDIA | strips replay image | JA EXISTIA | first_lesson_ready_window | Preservar |
| 1619 | Imagem fluxo pago exige acao | REF-SCROLL-MEDIA | acceptedOfferId missing skip | JA EXISTIA | media_phase | Preservar |
| 1620 | Imagem fluxo gratuito preservado | REF-SCROLL-MEDIA | local SVG | JA EXISTIA | media_phase | Preservar |
| 1621 | Imagem zoom abre | REF-SCROLL-MEDIA | inspection open | JA EXISTIA | finish_phase | Preservar |
| 1622 | Imagem zoom fecha | REF-SCROLL-MEDIA | inspection close | JA EXISTIA | finish_phase | Preservar |
| 1623 | Imagem fullscreen teclado | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | A11y |
| 1624 | Imagem alt text | REF-WCAG-STATUS | nao comprovado completo | BLOQUEADO | N/A | A11y |
| 1625 | Imagem captions | REF-WCAG-STATUS | nao comprovado | BLOQUEADO | N/A | A11y |
| 1626 | Imagem retry manual | REF-WCAG-STATUS | parcial funnel | BLOQUEADO | N/A | Produto |
| 1627 | Imagem cancelamento | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1628 | Imagem progress download | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1629 | Imagem cache disco | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Infra |
| 1630 | Imagem cache TTL | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Infra |
| 1631 | Imagem invalida nao quebra aula | REF-WCAG-STATUS | invalid compact | JA EXISTIA | finish_phase | Preservar |
| 1632 | Imagem SVG criticada | REF-SCROLL-MEDIA | image critic | JA EXISTIA | media_phase | Preservar |
| 1633 | Imagem qualidade final | REF-SCROLL-MEDIA | final quality | JA EXISTIA | media_phase | Preservar |
| 1634 | Imagem escalona se generica | REF-SCROLL-MEDIA | needsN3 | JA EXISTIA | media_phase | Preservar |
| 1635 | Imagem fallback local se N3 falha | REF-SCROLL-MEDIA | n3 fails fallback | JA EXISTIA | media_phase | Preservar |
| 1636 | Imagem grafico matematico | REF-SCROLL-MEDIA | math renderers | JA EXISTIA | media_phase | Preservar |
| 1637 | Imagem fluxograma | REF-SCROLL-MEDIA | flowchart renderer | JA EXISTIA | media_phase | Preservar |
| 1638 | Imagem tabela | REF-SCROLL-MEDIA | table renderer | JA EXISTIA | media_phase | Preservar |
| 1639 | Imagem ciclo | REF-SCROLL-MEDIA | cycle renderer | JA EXISTIA | media_phase | Preservar |
| 1640 | Imagem mapa conceitual | REF-SCROLL-MEDIA | concept renderer | JA EXISTIA | media_phase | Preservar |
| 1641 | Imagem diagrama forca | REF-SCROLL-MEDIA | force renderer | JA EXISTIA | media_phase | Preservar |
| 1642 | Imagem circuito | REF-SCROLL-MEDIA | circuit renderer | JA EXISTIA | media_phase | Preservar |
| 1643 | Imagem timeline | REF-SCROLL-MEDIA | timeline renderer | JA EXISTIA | media_phase | Preservar |
| 1644 | Imagem sintaxe | REF-SCROLL-MEDIA | syntax renderer | JA EXISTIA | media_phase | Preservar |
| 1645 | Imagem cadeia alimentar | REF-SCROLL-MEDIA | food chain | JA EXISTIA | media_phase | Preservar |
| 1646 | Imagem programacao | REF-SCROLL-MEDIA | programming renderer | JA EXISTIA | media_phase | Preservar |
| 1647 | Imagem quimica | REF-SCROLL-MEDIA | chemistry renderer | JA EXISTIA | media_phase | Preservar |
| 1648 | Imagem geografia | REF-SCROLL-MEDIA | geography renderer | JA EXISTIA | media_phase | Preservar |
| 1649 | Imagem logica | REF-SCROLL-MEDIA | logic renderer | JA EXISTIA | media_phase | Preservar |
| 1650 | Imagem sem exaustao total | Regra usuario | subdominio ainda aberto | BLOQUEADO | N/A | Continuar |
| 1651 | Audio preference ligada por padrao | REF-SCROLL-MEDIA | default on | JA EXISTIA | media_phase | Preservar |
| 1652 | Audio preference persiste | REF-SCROLL-MEDIA | SharedPrefs | JA EXISTIA | media_phase | Preservar |
| 1653 | Audio usa PlatformAudioAdapter | REF-SCROLL-MEDIA | not Noop | JA EXISTIA | media_phase | Preservar |
| 1654 | Audio mapeia idioma nativo | REF-SCROLL-MEDIA | native locales | JA EXISTIA | media_phase | Preservar |
| 1655 | Audio core cacheia | REF-SCROLL-MEDIA | generated cache | JA EXISTIA | media_phase | Preservar |
| 1656 | Audio disabled pula remoto | REF-SCROLL-MEDIA | skips client | JA EXISTIA | media_phase | Preservar |
| 1657 | Audio disabled pula playback | REF-SCROLL-MEDIA | skips local | JA EXISTIA | media_phase | Preservar |
| 1658 | Audio falha sem onStart | REF-SCROLL-MEDIA | play failure | JA EXISTIA | media_phase | Preservar |
| 1659 | Audio falha sem playing falso | REF-SCROLL-MEDIA | not report playing | JA EXISTIA | media_phase | Preservar |
| 1660 | Audio cache separa lesson | REF-SCROLL-MEDIA | cache key | JA EXISTIA | media_phase | Preservar |
| 1661 | Audio cache separa idioma | REF-SCROLL-MEDIA | cache key | JA EXISTIA | media_phase | Preservar |
| 1662 | Audio cache separa voz | REF-SCROLL-MEDIA | cache key | JA EXISTIA | media_phase | Preservar |
| 1663 | Audio cache separa texto | REF-SCROLL-MEDIA | cache key | JA EXISTIA | media_phase | Preservar |
| 1664 | Audio remoto fallback local | REF-SCROLL-MEDIA | remote failure fallback | JA EXISTIA | media_phase | Preservar |
| 1665 | Audio nao bloqueia aula | REF-SCROLL-MEDIA | failure nonblocking | JA EXISTIA | media_phase | Preservar |
| 1666 | Audio controller sequencia leitura | REF-SCROLL-MEDIA | reading sequence | JA EXISTIA | media_phase | Preservar |
| 1667 | Audio failure limpa playing | REF-SCROLL-MEDIA | clears playing | JA EXISTIA | media_phase | Preservar |
| 1668 | Audio failure registra erro recuperavel | REF-WCAG-STATUS | recoverable error | JA EXISTIA | media_phase | Preservar |
| 1669 | Audio pronto nao inicia sozinho | REF-SCROLL-MEDIA | prepares audioText only | JA EXISTIA | media_phase | Preservar |
| 1670 | Audio duvida respeita preference | REF-SCROLL-MEDIA | doubt audio | JA EXISTIA | media_phase | Preservar |
| 1671 | Audio para ao escolher resposta | REF-SCROLL-MEDIA | stop paths | JA EXISTIA | media_phase | Preservar |
| 1672 | Audio para ao sinalizar | REF-SCROLL-MEDIA | stop paths | JA EXISTIA | media_phase | Preservar |
| 1673 | Audio para ao avancar | REF-SCROLL-MEDIA | stop paths | JA EXISTIA | media_phase | Preservar |
| 1674 | Audio para no dispose | REF-SCROLL-MEDIA | dispose paths | JA EXISTIA | media_phase | Preservar |
| 1675 | Audio stop limpa loading | REF-SCROLL-MEDIA | LabSession stop | JA EXISTIA | media_phase | Preservar |
| 1676 | Audio toggle nao desliga preference | REF-SCROLL-MEDIA | toggle stop | JA EXISTIA | media_phase | Preservar |
| 1677 | Audio bolha visivel | REF-SCROLL-MEDIA | audio bubble | JA EXISTIA | chat_aula_widgets | Preservar |
| 1678 | Audio bolha para no tap | REF-SCROLL-MEDIA | stops on tap | JA EXISTIA | chat_aula_widgets | Preservar |
| 1679 | Audio usa endpoint real | REF-SCROLL-MEDIA | generate-lesson-audio | JA EXISTIA | external_ai_clients | Preservar |
| 1680 | Audio dataUrl | REF-SCROLL-MEDIA | returns dataUrl | JA EXISTIA | external_ai_clients | Preservar |
| 1681 | Audio requestId em erro | REF-WCAG-STATUS | requestId preserved | JA EXISTIA | external_ai_clients | Preservar |
| 1682 | Audio timeout retryable | REF-WCAG-STATUS | timeout retryable | JA EXISTIA | external_ai_clients | Preservar |
| 1683 | Audio sem noop documental | REF-SCROLL-MEDIA | PlatformAudioAdapter | JA EXISTIA | media_phase | Preservar |
| 1684 | Audio replay nao cobra | REF-SCROLL-BILLING | cache behavior | BLOQUEADO | N/A | Teste financeiro especifico |
| 1685 | Audio billing separado | REF-SCROLL-BILLING | nao cobrado no app | BLOQUEADO | N/A | Politica produto |
| 1686 | Audio captions | REF-WCAG-STATUS | texto equivalente existe parcial | BLOQUEADO | N/A | A11y |
| 1687 | Audio progresso visual | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | UI |
| 1688 | Audio duracao | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Player |
| 1689 | Audio pause | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Player |
| 1690 | Audio resume | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Player |
| 1691 | Audio replay UI | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Player |
| 1692 | Audio velocidade playback | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Player |
| 1693 | Audio volume por aula | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1694 | Audio gravacao aluno | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1695 | Audio transcricao gravacao | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1696 | Audio nao toca aula errada | REF-SCROLL-MEDIA | stop/change | JA EXISTIA | session_regression | Preservar |
| 1697 | Audio nao toca item errado | REF-SCROLL-MEDIA | cache key | JA EXISTIA | media_phase | Preservar |
| 1698 | Audio nao toca depois de sair | REF-SCROLL-MEDIA | stopActiveAudio | JA EXISTIA | media_phase | Preservar |
| 1699 | Audio nao altera creditos | Regra usuario | sem alteracao | PRESERVADO | git diff | Preservar |
| 1700 | Audio sem exaustao total | Regra usuario | subdominio ainda aberto | BLOQUEADO | N/A | Continuar |
| 1701 | Anexo objetivo usa client real | REF-SCROLL-MEDIA | server attachment | JA EXISTIA | finish_phase | Preservar |
| 1702 | Anexo objetivo nao usa mock | REF-SCROLL-MEDIA | no MOCK | JA EXISTIA | finish_phase | Preservar |
| 1703 | Anexo entra processing | REF-WCAG-STATUS | status processing | JA EXISTIA | finish_phase | Preservar |
| 1704 | Anexo fica ready | REF-WCAG-STATUS | status ready | JA EXISTIA | finish_phase | Preservar |
| 1705 | Anexo preserva texto extraido | REF-SCROLL-MEDIA | extractedText | JA EXISTIA | finish_phase | Preservar |
| 1706 | Anexo preserva metodo vision | REF-SCROLL-MEDIA | method vision | JA EXISTIA | finish_phase | Preservar |
| 1707 | Anexo envia filename | REF-SCROLL-MEDIA | prova.pdf | JA EXISTIA | finish_phase | Preservar |
| 1708 | Anexo envia contentType | REF-SCROLL-MEDIA | application/pdf | JA EXISTIA | finish_phase | Preservar |
| 1709 | Anexo envia bytes reais | REF-SCROLL-MEDIA | PDF bytes | JA EXISTIA | finish_phase | Preservar |
| 1710 | Anexo registra tamanho | REF-SCROLL-MEDIA | size | JA EXISTIA | finish_phase | Preservar |
| 1711 | Backup import via txt | REF-SCROLL-CLOUD | txt import | JA EXISTIA | widget_test | Preservar |
| 1712 | Backup paste fallback | REF-SCROLL-CLOUD | paste fallback | JA EXISTIA | widget_test | Preservar |
| 1713 | Anexo PDF preview | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1714 | Anexo PDF download | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1715 | Anexo imagem preview | REF-SCROLL-MEDIA | doubt photo | JA EXISTIA | auxiliary_phase | Preservar |
| 1716 | Anexo imagem valida MIME | REF-SCROLL-MEDIA | jpeg/png/webp | JA EXISTIA | auxiliary_phase | Preservar |
| 1717 | Anexo imagem limite tamanho | REF-SCROLL-MEDIA | oversized blocked | JA EXISTIA | auxiliary_phase | Preservar |
| 1718 | Anexo audio upload | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1719 | Anexo video upload | REF-IDEAL-CHAT | fora do escopo aula | NAO APLICAVEL | N/A | Manter fora |
| 1720 | Anexo arquivo generico upload | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1721 | Anexo progress upload | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Infra |
| 1722 | Anexo retry upload | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Infra |
| 1723 | Anexo cancel upload | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Infra |
| 1724 | Anexo dedupe | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Infra |
| 1725 | Anexo storage seguro | REF-SCROLL-CLOUD | cloud state | BLOQUEADO | N/A | Auditar storage |
| 1726 | Anexo ownership | REF-SCROLL-CLOUD | auth cloud | BLOQUEADO | N/A | Seguranca |
| 1727 | Anexo safe URL | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Seguranca |
| 1728 | Anexo antivirus | REF-IDEAL-CHAT | backend | AGUARDANDO AUTORIZACAO | N/A | Servidor |
| 1729 | Anexo OCR PDF | REF-IDEAL-CHAT | vision method parcial | BLOQUEADO | N/A | Produto |
| 1730 | Anexo OCR imagem | REF-SCROLL-MEDIA | vision method | JA EXISTIA | finish_phase | Preservar |
| 1731 | Anexo reduz output duvida | REF-SCROLL-CHAT | doubt context | BLOQUEADO | N/A | Produto |
| 1732 | Anexo nao cobra indevido | REF-SCROLL-BILLING | nao comprovado | BLOQUEADO | N/A | Billing |
| 1733 | Anexo erro humano | REF-WCAG-STATUS | processing errors | BLOQUEADO | N/A | A11y |
| 1734 | Anexo erro tecnico escondido | REF-WCAG-STATUS | erro saneado parcial | BLOQUEADO | N/A | A11y |
| 1735 | Anexo permissao camera | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | Mobile |
| 1736 | Anexo permissao arquivos | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | Mobile |
| 1737 | Anexo Android picker | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | Mobile |
| 1738 | Anexo iOS picker | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | Mobile |
| 1739 | Anexo drag drop desktop | REF-IDEAL-CHAT | fora mobile | NAO APLICAVEL | N/A | Manter fora |
| 1740 | Anexo cola clipboard | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1741 | Anexo abre inspecao | REF-SCROLL-MEDIA | image inspection | JA EXISTIA | finish_phase | Preservar |
| 1742 | Anexo fecha inspecao | REF-SCROLL-MEDIA | image close | JA EXISTIA | finish_phase | Preservar |
| 1743 | Anexo nao persiste stale | REF-SCROLL-MEDIA | cache key | JA EXISTIA | media_phase | Preservar |
| 1744 | Anexo historico propria aula | REF-SCROLL-CHAT | own lesson image | JA EXISTIA | chat_aula_widgets | Preservar |
| 1745 | Anexo nao reaproveita outra aula | REF-SCROLL-MEDIA | strips replay | JA EXISTIA | first_lesson_ready_window | Preservar |
| 1746 | Anexo cloud sync | REF-SCROLL-CLOUD | state serializes | JA EXISTIA | cloud_phase | Preservar |
| 1747 | Anexo offline queue | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Infra |
| 1748 | Anexo conflito cloud/local | REF-SCROLL-CLOUD | merge state | BLOQUEADO | N/A | Especificar anexos |
| 1749 | Anexo sem prompt alterado | Regra usuario | sem alteracao | PRESERVADO | git diff | Preservar |
| 1750 | Anexo sem exaustao total | Regra usuario | subdominio aberto | BLOQUEADO | N/A | Continuar |
| 1751 | Sync cloud storage auth | REF-SCROLL-CLOUD | authenticated session | JA EXISTIA | cloud_phase | Preservar |
| 1752 | Sync inert sem auth | REF-SCROLL-CLOUD | no session inert | JA EXISTIA | cloud_phase | Preservar |
| 1753 | Sync serializa snapshot completo | REF-SCROLL-CLOUD | full snapshot | JA EXISTIA | cloud_phase | Preservar |
| 1754 | Sync queue persiste patch | REF-SCROLL-CLOUD | queue patch | JA EXISTIA | cloud_phase | Preservar |
| 1755 | Sync remove apos drain | REF-SCROLL-CLOUD | removes after drain | JA EXISTIA | cloud_phase | Preservar |
| 1756 | Sync merge remoto em regressao | REF-SCROLL-CLOUD | remote merge | JA EXISTIA | cloud_phase | Preservar |
| 1757 | Sync progresso mais avancado | REF-SCROLL-CLOUD | most advanced | JA EXISTIA | cloud_phase | Preservar |
| 1758 | Sync publica posicao | REF-SCROLL-CLOUD | cloud progress | JA EXISTIA | cloud_phase | Preservar |
| 1759 | Sync enfileira progresso | REF-SCROLL-CLOUD | enqueue sync | JA EXISTIA | cloud_phase | Preservar |
| 1760 | Sync bootstrap curriculo pronto | REF-SCROLL-CLOUD | lesson bootstrap | JA EXISTIA | cloud_phase | Preservar |
| 1761 | Sync curriculo oficial para UI vazia | REF-SCROLL-CLOUD | settles official | JA EXISTIA | cloud_phase | Preservar |
| 1762 | Sync roundtrip estado vida | REF-SCROLL-CLOUD | full life roundtrip | JA EXISTIA | student_state_backup_sync_b | Preservar |
| 1763 | Sync importa Web backup | REF-SCROLL-CLOUD | simweb import | JA EXISTIA | student_state_backup_sync_b | Preservar |
| 1764 | Sync exporta app backup | REF-SCROLL-CLOUD | app roundtrip | JA EXISTIA | student_state_backup_sync_b | Preservar |
| 1765 | Sync converge 2 devices | REF-SCROLL-CLOUD | multi device | JA EXISTIA | student_state_backup_sync_b | Preservar |
| 1766 | Sync pause drain | REF-SCROLL-CLOUD | lifecycle paused | JA EXISTIA | classroom_parity | Preservar |
| 1767 | Sync re-enqueue em rejected | REF-SCROLL-CLOUD | remoteState merge | JA EXISTIA | classroom_parity | Preservar |
| 1768 | Sync backoff ate max | REF-SCROLL-CLOUD | 10 falhas | JA EXISTIA | classroom_parity | Preservar |
| 1769 | Sync nao regressa estado | REF-SCROLL-CLOUD | advanced progress | JA EXISTIA | cloud_phase | Preservar |
| 1770 | Sync offline prolongado | REF-IDEAL-CHAT | nao comprovado completo | BLOQUEADO | N/A | Infra |
| 1771 | Sync conflito manual | REF-IDEAL-CHAT | merge automatico parcial | BLOQUEADO | N/A | Produto |
| 1772 | Sync indicador visual pendente | REF-IDEAL-CHAT | delivery states parcial | BLOQUEADO | N/A | UI |
| 1773 | Sync indicador entregue | REF-IDEAL-CHAT | delivery states parcial | BLOQUEADO | N/A | UI |
| 1774 | Sync indicador lido | REF-IDEAL-CHAT | fora aula individual | NAO APLICAVEL | N/A | Manter fora |
| 1775 | Sync retry manual | REF-IDEAL-CHAT | retry errors parcial | BLOQUEADO | N/A | Produto |
| 1776 | Sync cancelamento | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Infra |
| 1777 | Sync dedupe operationId | REF-SCROLL-CLOUD | operation ids parcial | BLOQUEADO | N/A | Auditar |
| 1778 | Sync idempotencia server | REF-SCROLL-CLOUD | backend | AGUARDANDO AUTORIZACAO | N/A | Servidor |
| 1779 | Sync criptografia local | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Seguranca |
| 1780 | Sync backup criptografado | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Seguranca |
| 1781 | Sync schema antigo | REF-IDEAL-CHAT | backup import parcial | BLOQUEADO | N/A | Migração |
| 1782 | Sync dados corrompidos | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Teste |
| 1783 | Sync logout/login | REF-SCROLL-CLOUD | auth tests parcial | BLOQUEADO | N/A | Teste |
| 1784 | Sync reinstalacao | REF-IDEAL-CHAT | cloud restore parcial | BLOQUEADO | N/A | E2E |
| 1785 | Sync segundo dispositivo | REF-SCROLL-CLOUD | multi device | JA EXISTIA | student_state_backup_sync_b | Preservar |
| 1786 | Sync fila local persistente | REF-SCROLL-CLOUD | queue persists | JA EXISTIA | cloud_phase | Preservar |
| 1787 | Sync merge profundo attempts | REF-SCROLL-CLOUD | deep merge | JA EXISTIA | bloco1_completion | Preservar |
| 1788 | Sync stableHash ignora meta | REF-SCROLL-CLOUD | stableHash | JA EXISTIA | classroom_parity | Preservar |
| 1789 | Sync nao perde material atual | REF-SCROLL-READY | material state | JA EXISTIA | first_lesson_ready_window | Preservar |
| 1790 | Sync nao perde historico | REF-SCROLL-CHAT | transcript | JA EXISTIA | chat_aula_widgets | Preservar |
| 1791 | Sync nao perde escolha | REF-SCROLL-CHAT | history chosen | JA EXISTIA | classroom_parity | Preservar |
| 1792 | Sync nao perde layer | REF-SCROLL-CLOUD | progress layer | JA EXISTIA | student_state_backup_sync_b | Preservar |
| 1793 | Sync nao perde placement | REF-SCROLL-CLOUD | state snapshot | JA EXISTIA | student_state_backup_sync_b | Preservar |
| 1794 | Sync nao perde creditos | REF-SCROLL-BILLING | ledger tests | JA EXISTIA | internal_organs_governor | Preservar |
| 1795 | Sync nao perde midia | REF-SCROLL-MEDIA | media events | JA EXISTIA | media_phase | Preservar |
| 1796 | Sync logs sem sensiveis | REF-IDEAL-CHAT | nao comprovado completo | BLOQUEADO | N/A | Segurança |
| 1797 | Sync telemetry | REF-IDEAL-CHAT | parcial logs | BLOQUEADO | N/A | Observabilidade |
| 1798 | Sync sem servidor alterado | Regra usuario | sem alteracao | PRESERVADO | git diff | Preservar |
| 1799 | Sync sem cache proibido | Regra usuario | sem alteracao | PRESERVADO | git diff | Preservar |
| 1800 | Sync sem exaustao total | Regra usuario | subdominio aberto | BLOQUEADO | N/A | Continuar |
| 1801 | Auth refresh sessao expirada | REF-SCROLL-CLOUD | refresh expired | JA EXISTIA | auth_role_gate | Preservar |
| 1802 | Auth roles metadata | REF-SCROLL-CLOUD | parent roles | JA EXISTIA | auth_role_gate | Preservar |
| 1803 | Auth Google real Supabase | REF-SCROLL-CLOUD | OAuth | JA EXISTIA | google_auth_contract | Preservar |
| 1804 | Auth erro saneado | REF-WCAG-STATUS | sanitized auth | JA EXISTIA | session_regression | Preservar |
| 1805 | Auth retry em portugues | REF-WCAG-STATUS | retry pt | JA EXISTIA | session_regression | Preservar |
| 1806 | Auth espera authReady | REF-SCROLL-CLOUD | waits authReady | JA EXISTIA | session_regression | Preservar |
| 1807 | Auth nao redireciona antes T00 | REF-SCROLL-CLOUD | no pre redirect | JA EXISTIA | session_regression | Preservar |
| 1808 | Auth renova e repete T00 uma vez | REF-SCROLL-CLOUD | repeat once | JA EXISTIA | session_regression | Preservar |
| 1809 | Auth missing billing bloqueia | REF-SCROLL-BILLING | missing auth | JA EXISTIA | billing_phase | Preservar |
| 1810 | Auth deletion exige texto | REF-SCROLL-BILLING | DELETAR | JA EXISTIA | billing_phase | Preservar |
| 1811 | Privacy route existe | REF-SCROLL-SCHOOL | `/privacidade` | JA EXISTIA | school_completeness | Preservar |
| 1812 | Terms route existe | REF-SCROLL-SCHOOL | `/termos` | JA EXISTIA | school_completeness | Preservar |
| 1813 | Delete account route existe | REF-SCROLL-SCHOOL | `/conta/deletar` | JA EXISTIA | school_completeness | Preservar |
| 1814 | Logs nao exibem JSON pai | REF-SCROLL-SCHOOL | human snapshot | JA EXISTIA | support_phase | Preservar |
| 1815 | Safe return checkout | REF-SCROLL-BILLING | safe internal paths | JA EXISTIA | billing_phase | Preservar |
| 1816 | Stripe return valida session | REF-SCROLL-BILLING | validates session | JA EXISTIA | billing_phase | Preservar |
| 1817 | Webhook ignora unpaid | REF-SCROLL-BILLING | ignores unpaid | JA EXISTIA | billing_phase | Preservar |
| 1818 | Credits route por pack id | REF-SCROLL-BILLING | pack id only | JA EXISTIA | billing_phase | Preservar |
| 1819 | Google Play product ids estaveis | REF-SCROLL-BILLING | product ids | JA EXISTIA | billing_phase | Preservar |
| 1820 | Billing pending/canceled | REF-SCROLL-BILLING | states surfaced | JA EXISTIA | billing_phase | Preservar |
| 1821 | Resource owner cloud | REF-SCROLL-CLOUD | auth session | BLOQUEADO | N/A | Auditar RLS |
| 1822 | Tokens sem log sensivel | REF-IDEAL-CHAT | logs tokenPresent | BLOQUEADO | N/A | Revisar logs |
| 1823 | Safe URL midia | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Segurança |
| 1824 | MIME upload servidor | REF-IDEAL-CHAT | backend | AGUARDANDO AUTORIZACAO | N/A | Servidor |
| 1825 | Rate limit chat | REF-IDEAL-CHAT | backend | AGUARDANDO AUTORIZACAO | N/A | Servidor |
| 1826 | Rate limit audio | REF-IDEAL-CHAT | backend | AGUARDANDO AUTORIZACAO | N/A | Servidor |
| 1827 | Rate limit imagem | REF-IDEAL-CHAT | backend | AGUARDANDO AUTORIZACAO | N/A | Servidor |
| 1828 | Sanitizacao markdown | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Segurança |
| 1829 | Sanitizacao link | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Segurança |
| 1830 | Sanitizacao HTML | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Segurança |
| 1831 | Permissao microfone | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | Mobile |
| 1832 | Permissao camera | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | Mobile |
| 1833 | Permissao storage | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | Mobile |
| 1834 | Logout limpa unlimited | REF-SCROLL-CLOUD | sign-out reset | JA EXISTIA | bug_regression_fixes | Preservar |
| 1835 | Session valida sem erro | REF-SCROLL-CLOUD | AuthSession valid | JA EXISTIA | bug_regression_fixes | Preservar |
| 1836 | Credito idempotente operationId | REF-SCROLL-BILLING | no duplicate ledger | JA EXISTIA | internal_organs_governor | Preservar |
| 1837 | Imagem paga captura credito | REF-SCROLL-BILLING | capture | JA EXISTIA | internal_organs_governor | Preservar |
| 1838 | Imagem paga reembolsa falha | REF-SCROLL-BILLING | refund | JA EXISTIA | internal_organs_governor | Preservar |
| 1839 | Doubt sem custo indevido | REF-SCROLL-BILLING | doubt state | JA EXISTIA | internal_organs_governor | Preservar |
| 1840 | Audio sem cobrança app | REF-SCROLL-BILLING | no ledger audio | BLOQUEADO | N/A | Teste dedicado |
| 1841 | PII minimization | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Privacidade |
| 1842 | Export dados usuario | REF-IDEAL-CHAT | backup parcial | BLOQUEADO | N/A | Produto |
| 1843 | Delecao dados servidor | REF-SCROLL-BILLING | request server | JA EXISTIA | billing_phase | Preservar |
| 1844 | Consentimento imagem paga | REF-SCROLL-MEDIA | acceptedOfferId | JA EXISTIA | media_phase | Preservar |
| 1845 | Nao pagar antes aceitar | REF-SCROLL-MEDIA | skip no offer | JA EXISTIA | media_phase | Preservar |
| 1846 | Replay audio sem cobrar | REF-SCROLL-MEDIA | cache | BLOQUEADO | N/A | Teste billing |
| 1847 | Cache privado por usuario | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Segurança |
| 1848 | Backup privado por usuario | REF-SCROLL-CLOUD | auth cloud | BLOQUEADO | N/A | RLS |
| 1849 | Sem servidor alterado | Regra usuario | sem alteracao | PRESERVADO | git diff | Preservar |
| 1850 | Segurança sem exaustao total | Regra usuario | subdominio aberto | BLOQUEADO | N/A | Continuar |
| 1851 | Screen reader mensagens | REF-WCAG-STATUS | semantics states | JA EXISTIA | chat_aula_widgets | Preservar |
| 1852 | Live region delivery | REF-WCAG-STATUS | delivery semantics | JA EXISTIA | chat_aula_widgets | Preservar |
| 1853 | Live region erro | REF-WCAG-STATUS | status messages | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1854 | Live region loading | REF-WCAG-STATUS | loading message | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1855 | Botao touch height | REF-FLUTTER-SEMANTICS | accessible touch | JA EXISTIA | sim_ideal_layout | Preservar |
| 1856 | Tablet layout | REF-FLUTTER-SEMANTICS | widens column | JA EXISTIA | sim_ideal_layout | Preservar |
| 1857 | Font scale menu | REF-FLUTTER-SEMANTICS | font scale | JA EXISTIA | chat_aula_widgets | Preservar |
| 1858 | Tema escuro menu | REF-FLUTTER-SEMANTICS | dark mode | JA EXISTIA | chat_aula_widgets | Preservar |
| 1859 | Typewriter TextScaler | REF-FLUTTER-SEMANTICS | scaled text | JA EXISTIA | finish_phase | Preservar |
| 1860 | Estado erro acessivel | REF-WCAG-STATUS | human errors | JA EXISTIA | session_regression | Preservar |
| 1861 | Texto tecnico escondido | REF-WCAG-STATUS | sanitized | JA EXISTIA | session_regression | Preservar |
| 1862 | Nao depender so de audio | REF-WCAG-STATUS | texto sempre existe | JA EXISTIA | media_phase | Preservar |
| 1863 | Audio preference control | REF-WCAG-STATUS | toggle | JA EXISTIA | media_phase | Preservar |
| 1864 | Imagem nao bloqueia texto | REF-WCAG-STATUS | question visible | JA EXISTIA | chat_aula_widgets | Preservar |
| 1865 | Erro imagem compacto | REF-WCAG-STATUS | invalid image error | JA EXISTIA | finish_phase | Preservar |
| 1866 | Labels sinais | REF-FLUTTER-SEMANTICS | sinais UI | BLOQUEADO | N/A | Semantics audit |
| 1867 | Labels alternativas | REF-FLUTTER-SEMANTICS | callbacks | BLOQUEADO | N/A | Semantics audit |
| 1868 | Labels audio | REF-FLUTTER-SEMANTICS | audio bubble | BLOQUEADO | N/A | Semantics audit |
| 1869 | Labels imagem | REF-FLUTTER-SEMANTICS | image bubble | BLOQUEADO | N/A | Semantics audit |
| 1870 | Labels drawer | REF-FLUTTER-SEMANTICS | drawer UI | BLOQUEADO | N/A | Semantics audit |
| 1871 | Ordem foco timeline | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | A11y |
| 1872 | Ordem foco composer | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | A11y |
| 1873 | Ordem foco drawer | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | A11y |
| 1874 | Contraste claro | REF-WCAG-STATUS | nao medido | BLOQUEADO | N/A | Teste contraste |
| 1875 | Contraste escuro | REF-WCAG-STATUS | nao medido | BLOQUEADO | N/A | Teste contraste |
| 1876 | Reduce motion typewriter | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | A11y |
| 1877 | Reduce motion animacoes | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | A11y |
| 1878 | Fonte escalavel botoes | REF-FLUTTER-SEMANTICS | touch height | JA EXISTIA | sim_ideal_layout | Preservar |
| 1879 | Fonte escalavel timeline | REF-FLUTTER-SEMANTICS | font scale | JA EXISTIA | chat_aula_widgets | Preservar |
| 1880 | Fonte escalavel typewriter | REF-FLUTTER-SEMANTICS | TextScaler | JA EXISTIA | finish_phase | Preservar |
| 1881 | Teclado controla botao | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | A11y |
| 1882 | Teclado controla audio | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | A11y |
| 1883 | Teclado controla imagem zoom | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | A11y |
| 1884 | Screen reader anuncia envio | REF-WCAG-STATUS | delivery partial | BLOQUEADO | N/A | A11y |
| 1885 | Screen reader anuncia retry | REF-WCAG-STATUS | retry action | BLOQUEADO | N/A | A11y |
| 1886 | Screen reader anuncia erro recover | REF-WCAG-STATUS | error messages | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1887 | Area clicavel primaria | REF-FLUTTER-SEMANTICS | touch height | JA EXISTIA | sim_ideal_layout | Preservar |
| 1888 | Area clicavel secundaria | REF-FLUTTER-SEMANTICS | touch height | JA EXISTIA | sim_ideal_layout | Preservar |
| 1889 | Acessibilidade sem cor unica | REF-WCAG-STATUS | nao comprovado | BLOQUEADO | N/A | A11y |
| 1890 | Acessibilidade feedback texto | REF-WCAG-STATUS | feedback text | JA EXISTIA | chat_aula_widgets | Preservar |
| 1891 | Acessibilidade imagem alt | REF-WCAG-STATUS | nao comprovado | BLOQUEADO | N/A | A11y |
| 1892 | Acessibilidade audio equivalente | REF-WCAG-STATUS | texto existe | JA EXISTIA | media_phase | Preservar |
| 1893 | Acessibilidade erro auth | REF-WCAG-STATUS | sanitized | JA EXISTIA | session_regression | Preservar |
| 1894 | Acessibilidade erro billing | REF-WCAG-STATUS | billing states | JA EXISTIA | billing_phase | Preservar |
| 1895 | Acessibilidade loading global | REF-WCAG-STATUS | loading messages | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1896 | Acessibilidade loading local | REF-WCAG-STATUS | inline loading | JA EXISTIA | finish_phase | Preservar |
| 1897 | Acessibilidade sheet | REF-FLUTTER-SEMANTICS | sheet partial | BLOQUEADO | N/A | A11y |
| 1898 | Acessibilidade drawer | REF-FLUTTER-SEMANTICS | drawer partial | BLOQUEADO | N/A | A11y |
| 1899 | Sem regressao a11y por prompt | Regra usuario | sem alteracao | PRESERVADO | git diff | Preservar |
| 1900 | A11y sem exaustao total | Regra usuario | subdominio aberto | BLOQUEADO | N/A | Continuar |
| 1901 | Analyze limpo | REF-SCROLL-TESTS | no issues | JA EXISTIA | flutter analyze | Preservar |
| 1902 | Teste completo verde | REF-SCROLL-TESTS | 360 tests | JA EXISTIA | flutter test | Preservar |
| 1903 | Testes chat timeline | REF-SCROLL-CHAT | builder tests | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1904 | Testes chat widgets | REF-SCROLL-CHAT | widgets tests | JA EXISTIA | chat_aula_widgets | Preservar |
| 1905 | Testes media | REF-SCROLL-MEDIA | media phase | JA EXISTIA | media_phase | Preservar |
| 1906 | Testes ready window | REF-SCROLL-READY | ready tests | JA EXISTIA | first_lesson_ready_window | Preservar |
| 1907 | Testes cloud | REF-SCROLL-CLOUD | cloud tests | JA EXISTIA | cloud_phase | Preservar |
| 1908 | Testes billing | REF-SCROLL-BILLING | billing tests | JA EXISTIA | billing_phase | Preservar |
| 1909 | Testes school | REF-SCROLL-SCHOOL | school tests | JA EXISTIA | school_completeness | Preservar |
| 1910 | Testes layout | REF-FLUTTER-SEMANTICS | ideal layout | JA EXISTIA | sim_ideal_layout | Preservar |
| 1911 | Logs T00 | REF-SCROLL-READY | T00_STARTED | JA EXISTIA | tests logs | Preservar |
| 1912 | Logs T02 | REF-SCROLL-READY | T02_FIRST | JA EXISTIA | tests logs | Preservar |
| 1913 | Logs CLASSROOM_OPENED | REF-SCROLL-READY | event | JA EXISTIA | tests logs | Preservar |
| 1914 | Logs BLOCKED | REF-WCAG-STATUS | blocked reason | JA EXISTIA | tests logs | Preservar |
| 1915 | Logs visual pipeline | REF-SCROLL-MEDIA | VISUAL_PIPELINE | JA EXISTIA | media tests | Preservar |
| 1916 | Logs software render | REF-SCROLL-MEDIA | SOFTWARE_RENDER | JA EXISTIA | media tests | Preservar |
| 1917 | Logs HTTP config | REF-SCROLL-CLOUD | SIM_CFG | JA EXISTIA | external_ai_clients | Preservar |
| 1918 | Logs HTTP status | REF-SCROLL-CLOUD | SIM_HTTP | JA EXISTIA | billing/widget tests | Preservar |
| 1919 | RequestId erro audio | REF-WCAG-STATUS | requestId | JA EXISTIA | external_ai_clients | Preservar |
| 1920 | RequestId erro imagem | REF-WCAG-STATUS | requestId | JA EXISTIA | external_ai_clients | Preservar |
| 1921 | Metricas time-to-first-item | REF-IDEAL-CHAT | eventos parciais | BLOQUEADO | N/A | Observabilidade |
| 1922 | Metricas time-to-first-question | REF-IDEAL-CHAT | nao agregado | BLOQUEADO | N/A | Observabilidade |
| 1923 | Metricas audio ready | REF-IDEAL-CHAT | nao agregado | BLOQUEADO | N/A | Observabilidade |
| 1924 | Metricas image ready | REF-IDEAL-CHAT | nao agregado | BLOQUEADO | N/A | Observabilidade |
| 1925 | Metricas sync lag | REF-IDEAL-CHAT | nao agregado | BLOQUEADO | N/A | Observabilidade |
| 1926 | Metricas retry rate | REF-IDEAL-CHAT | nao agregado | BLOQUEADO | N/A | Observabilidade |
| 1927 | Crash breadcrumbs | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Observabilidade |
| 1928 | Feature flags UI | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Produto |
| 1929 | Profiling timeline | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Performance |
| 1930 | Profiling render media | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Performance |
| 1931 | Cache medida timeline | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Performance |
| 1932 | Memoizacao mensagens | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Performance |
| 1933 | Batch updates | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Performance |
| 1934 | Throttle scroll | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Performance |
| 1935 | Debounce ready job | REF-SCROLL-READY | duplicate job guard | JA EXISTIA | first_lesson_ready_window | Preservar |
| 1936 | Debounce cloud queue | REF-SCROLL-CLOUD | nextRetryAt | JA EXISTIA | classroom_parity | Preservar |
| 1937 | Max attempts cloud | REF-SCROLL-CLOUD | 10 failures | JA EXISTIA | classroom_parity | Preservar |
| 1938 | Cache material max 3 | REF-SCROLL-READY | keeps three | JA EXISTIA | first_lesson_ready_window | Preservar |
| 1939 | Cache invalido ignorado | REF-SCROLL-READY | invalid cache ignored | JA EXISTIA | first_lesson_ready_window | Preservar |
| 1940 | Cache imagem descartada hidratar | REF-SCROLL-MEDIA | discards image | JA EXISTIA | bloco1_completion | Preservar |
| 1941 | Cache material hidrata prefs | REF-SCROLL-READY | SharedPreferences | JA EXISTIA | bloco1_completion | Preservar |
| 1942 | Ready window A/B/C | REF-SCROLL-READY | prepares slots | JA EXISTIA | first_lesson_ready_window | Preservar |
| 1943 | Ready window invalid material retry | REF-SCROLL-READY | T02 called again | JA EXISTIA | first_lesson_ready_window | Preservar |
| 1944 | Ready window metadata mirror | REF-SCROLL-READY | mirrors metadata | JA EXISTIA | first_lesson_ready_window | Preservar |
| 1945 | Ready window no dup active | REF-SCROLL-READY | no duplicate active | JA EXISTIA | first_lesson_ready_window | Preservar |
| 1946 | Performance 100 msgs test | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Teste |
| 1947 | Performance 1000 msgs test | REF-IDEAL-CHAT | nao comprovado | BLOQUEADO | N/A | Teste |
| 1948 | Memory leak listeners | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | Teste |
| 1949 | Rebuild excessivo | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | Perfil |
| 1950 | Observabilidade sem exaustao total | Regra usuario | subdominio aberto | BLOQUEADO | N/A | Continuar |
| 1951 | Contrato universal conversa | REF-IDEAL-CHAT | emergente em chat aula | BLOQUEADO | N/A | Extrair contrato |
| 1952 | Contrato universal mensagem | REF-SCROLL-CHAT | message model parcial | BLOQUEADO | N/A | Formalizar |
| 1953 | Contrato universal midia | REF-SCROLL-MEDIA | media services | BLOQUEADO | N/A | Formalizar |
| 1954 | Contrato universal acao | REF-SCROLL-CHAT | callbacks | BLOQUEADO | N/A | Formalizar |
| 1955 | Contrato universal erro | REF-WCAG-STATUS | errors partial | BLOQUEADO | N/A | Formalizar |
| 1956 | Adapter pedagogia -> conversa | REF-SCROLL-CHAT | timeline builder | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1957 | Renderer conversa -> widgets | REF-SCROLL-CHAT | chat widgets | JA EXISTIA | chat_aula_widgets | Preservar |
| 1958 | Separacao pedagogia/UI | REF-SCROLL-CHAT | builder layer | JA EXISTIA | chat_aula_timeline_builder | Preservar |
| 1959 | Separacao evento/estado | REF-SCROLL-CLOUD | state engines | JA EXISTIA | sim_state_engines | Preservar |
| 1960 | Separacao midia/aula | REF-SCROLL-MEDIA | media services | JA EXISTIA | media_phase | Preservar |
| 1961 | Separacao billing/aula | REF-SCROLL-BILLING | billing tests | JA EXISTIA | billing_phase | Preservar |
| 1962 | Separacao cloud/aula | REF-SCROLL-CLOUD | cloud queue | JA EXISTIA | cloud_phase | Preservar |
| 1963 | Separacao school/drawer | REF-SCROLL-SCHOOL | drawer contract | JA EXISTIA | school_completeness | Preservar |
| 1964 | Feature flag chat default | REF-SCROLL-CHAT | route chat default | JA EXISTIA | widget_test | Preservar |
| 1965 | Fallback aula classica | REF-SCROLL-CHAT | classroom route | BLOQUEADO | N/A | Auditar paridade |
| 1966 | Documentacao contrato | REF-IDEAL-CHAT | relatorios docs | CRIADO | este relatorio | Manter |
| 1967 | Governanca referencias | Regra usuario | refs listadas | CRIADO | este relatorio | Manter |
| 1968 | Governanca status por item | Regra usuario | 600 linhas | CRIADO | contagem rg | Manter |
| 1969 | Governanca bloqueios explicitos | Regra usuario | BLOQUEADO rows | CRIADO | este relatorio | Priorizar |
| 1970 | Governanca nao aplicavel explicito | Regra usuario | NAO APLICAVEL rows | CRIADO | este relatorio | Manter |
| 1971 | Governanca preservado explicito | Regra usuario | PRESERVADO rows | CRIADO | este relatorio | Manter |
| 1972 | Governanca aguardando autorizacao | Regra usuario | AGUARDANDO rows | CRIADO | este relatorio | Pedir autorizacao |
| 1973 | Governanca sem servidor | Regra usuario | sem server diff | PRESERVADO | git diff | Preservar |
| 1974 | Governanca sem prompt | Regra usuario | sem prompt diff | PRESERVADO | git diff | Preservar |
| 1975 | Governanca sem credito | Regra usuario | sem credito diff | PRESERVADO | git diff | Preservar |
| 1976 | Governanca sem cache proibido | Regra usuario | sem cache proibido | PRESERVADO | git diff | Preservar |
| 1977 | Governanca sem N2/N3 alterado | Regra usuario | sem alteracao | PRESERVADO | git diff | Preservar |
| 1978 | Governanca sem paid funnel alterado | Regra usuario | sem alteracao | PRESERVADO | git diff | Preservar |
| 1979 | Governanca testes antes fim | REF-SCROLL-TESTS | analyze e foco verdes | JA EXISTIA | analyze + 179 focados | Preservar |
| 1980 | Governanca commit com referencias | Regra usuario | nao solicitado | BLOQUEADO | N/A | Commit se pedido |
| 1981 | Governanca push main | Regra usuario | nao solicitado | BLOQUEADO | N/A | Push se pedido |
| 1982 | Governanca APK publico | Regra usuario | nao nesta tarefa | BLOQUEADO | N/A | Build se pedido |
| 1983 | Governanca matriz 2000 | Regra usuario | 2000 formal | CRIADO | este relatorio | Validar |
| 1984 | Governanca meta 50% | Regra usuario | 2000/4000 | CRIADO | este relatorio | Validar |
| 1985 | Governanca lacunas produto | REF-IDEAL-CHAT | bloqueios produto | CRIADO | este relatorio | Priorizar |
| 1986 | Governanca lacunas infra | REF-IDEAL-CHAT | bloqueios infra | CRIADO | este relatorio | Priorizar |
| 1987 | Governanca lacunas a11y | REF-WCAG-STATUS | bloqueios a11y | CRIADO | este relatorio | Priorizar |
| 1988 | Governanca lacunas seguranca | REF-IDEAL-CHAT | bloqueios seguranca | CRIADO | este relatorio | Priorizar |
| 1989 | Governanca lacunas performance | REF-IDEAL-CHAT | bloqueios performance | CRIADO | este relatorio | Priorizar |
| 1990 | Governanca lacunas backend | Regra usuario | aguardando autorizacao | CRIADO | este relatorio | Autorizar se quiser |
| 1991 | Governanca relatorio acumulado | Regra usuario | docs 001-2000 | CRIADO | docs | Manter |
| 1992 | Governanca contagem mecanica | Regra usuario | rg rows | CRIADO | rg count | Manter |
| 1993 | Governanca status mecanico | Regra usuario | rg status | CRIADO | rg count | Manter |
| 1994 | Governanca validacao analyze | REF-SCROLL-TESTS | `flutter analyze` limpo | JA EXISTIA | flutter analyze | Preservar |
| 1995 | Governanca validacao focada | REF-SCROLL-TESTS | 179 testes focados verdes | JA EXISTIA | focused flutter test | Preservar |
| 1996 | Governanca validacao completa | REF-SCROLL-TESTS | 360 testes verdes | JA EXISTIA | flutter test | Preservar |
| 1997 | Governanca nao inventar implementacao | Regra usuario | status honestos | PRESERVADO | este relatorio | Preservar |
| 1998 | Governanca diferenciar auditado/corrigido | Regra usuario | status separados | PRESERVADO | este relatorio | Preservar |
| 1999 | Governanca proxima fronteira 2001 | Regra usuario | ainda falta 2000 itens | BLOQUEADO | N/A | Continuar se pedido |
| 2000 | Exaustao estrutural ainda nao atingida | Regra usuario | 2000/4000 | BLOQUEADO | N/A | Continuar |

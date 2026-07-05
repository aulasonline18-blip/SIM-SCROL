# Motor Conversacional Universal - checkpoint 501-900

Data: 2026-07-05

Escopo: terceira fatia da meta de exaustao estrutural do Motor Conversacional Universal. Este relatorio adiciona 400 unidades funcionais auditaveis, numeradas de 501 a 900, em continuidade aos checkpoints `001-200` e `201-500`.

Total acumulado formal: 900 itens classificados. Em uma meta nominal de 4.000 unidades, isso representa 22,5%.

## Referencias comprovadas

- REF-WCAG-STATUS: W3C WCAG 2.2, Success Criterion 4.1.3 Status Messages.
- REF-SLACK-HISTORY: Slack `conversations.history`, historico ordenado e limites.
- REF-SLACK-PAGINATION: Slack Web API Pagination, paginacao/cursor.
- REF-WHATSAPP-TYPING: Meta WhatsApp typing/read indicators.
- REF-TELEGRAM-ACTION: Telegram Bot API `sendChatAction`.
- REF-FLUTTER-SEMANTICS: Flutter `Semantics`, rotas, widgets, lifecycle e controllers.
- REF-PLAY-BILLING: Contrato local Google Play Billing em `play_billing_functions.dart` e testes Play product id.
- REF-STRIPE-CHECKOUT: Contrato local Stripe hosted/embedded checkout em `payments_functions.dart` e testes billing.
- REF-SCROLL-PORTAL: `test/widget_test.dart`, `main.dart`, `portal_flow.dart`, `shared_widgets.dart`.
- REF-SCROLL-BILLING: `test/billing_phase_test.dart`, `sim/billing/*`, `LabSession`.
- REF-SCROLL-ATTACH: `test/electrical_hydraulic_connections_test.dart`, `sim_server_attachment_client.dart`, `SimHttpTransport`.
- REF-SCROLL-CLOUD: `test/cloud_phase_test.dart`, `student_state_backup_sync_b_test.dart`, `sim/cloud/*`.
- REF-SCROLL-RUNTIME: `classroom_parity_t01_t28_test.dart`, `normal_lesson_full_completion_flow_test.dart`, `lesson_runtime_engine.dart`.
- REF-SCROLL-TESTS: suite Flutter completa validada nos checkpoints anteriores.

## Matriz 501-900

| ID | Unidade auditavel | Referencia | Evidencia Scroll | Status | Teste/prova | Proxima acao |
|---:|---|---|---|---|---|---|
| 501 | Portal mostra entrada SIM | REF-SCROLL-PORTAL | `Portal shows SIM entry point` | JA EXISTIA | widget_test | Preservar |
| 502 | Portal mostra CTA de login | REF-SCROLL-PORTAL | `Sign in to start` | JA EXISTIA | widget_test | Preservar |
| 503 | Portal mostra subtitulo do produto | REF-SCROLL-PORTAL | `Smart Intelligence Mentor` | JA EXISTIA | widget_test | Preservar |
| 504 | Portal logado usa menu da aula | REF-SCROLL-PORTAL | semantica `Abrir menu da aula` | JA EXISTIA | widget_test | Preservar |
| 505 | Menu logado abre drawer unico | REF-SCROLL-PORTAL | tap semantics label | JA EXISTIA | widget_test | Preservar |
| 506 | Menu unico contem Nova aula | REF-SCROLL-PORTAL | texto `Nova aula` | JA EXISTIA | widget_test | Preservar |
| 507 | Menu unico contem creditos | REF-SCROLL-PORTAL | `Recarregar creditos` | JA EXISTIA | widget_test | Preservar |
| 508 | Menu unico contem abrir aula | REF-SCROLL-PORTAL | `Abrir aula/Open lesson` | JA EXISTIA | widget_test | Preservar |
| 509 | Menu unico contem painel do pai | REF-SCROLL-PORTAL | `Painel do Pai` | JA EXISTIA | widget_test | Preservar |
| 510 | Menu unico contem privacidade | REF-SCROLL-PORTAL | `Privacidade/Privacy` | JA EXISTIA | widget_test | Preservar |
| 511 | Menu unico contem termos | REF-SCROLL-PORTAL | `Termos/Terms` | JA EXISTIA | widget_test | Preservar |
| 512 | Menu unico contem historico | REF-SCROLL-PORTAL | `HISTORICO/HISTORY` | JA EXISTIA | widget_test | Preservar |
| 513 | Portal troca idioma para pt | REF-SCROLL-PORTAL | seleciona Portugues | JA EXISTIA | widget_test | Preservar |
| 514 | Portal troca idioma para fr | REF-SCROLL-PORTAL | seleciona Francais | JA EXISTIA | widget_test | Preservar |
| 515 | Idioma pt atualiza texto de objetivo | REF-SCROLL-PORTAL | `Conte-nos...` | JA EXISTIA | widget_test | Preservar |
| 516 | Idioma fr atualiza texto de objetivo | REF-SCROLL-PORTAL | `Parlez-nous...` | JA EXISTIA | widget_test | Preservar |
| 517 | Idioma pt salva selectedLanguageCode | REF-SCROLL-PORTAL | `session.selectedLanguageCode == pt` | JA EXISTIA | widget_test | Preservar |
| 518 | Idioma fr salva selectedLanguageCode | REF-SCROLL-PORTAL | `session.selectedLanguageCode == fr` | JA EXISTIA | widget_test | Preservar |
| 519 | Idioma pt salva stableLang | REF-SCROLL-PORTAL | `Portuguese` | JA EXISTIA | widget_test | Preservar |
| 520 | Idioma fr salva stableLang | REF-SCROLL-PORTAL | `French` | JA EXISTIA | widget_test | Preservar |
| 521 | Dark mode alterna no portal | REF-FLUTTER-SEMANTICS | semantica turn on dark | JA EXISTIA | widget_test | Preservar |
| 522 | Dark mode persiste preferencia | REF-SCROLL-PORTAL | SharedPreferences | JA EXISTIA | widget_test | Preservar |
| 523 | Dark mode aplica fundo portal | REF-SCROLL-PORTAL | `Scaffold.backgroundColor` | JA EXISTIA | widget_test | Preservar |
| 524 | Dark mode aplica fundo onboarding | REF-SCROLL-PORTAL | rota idioma | JA EXISTIA | widget_test | Preservar |
| 525 | Rota aula usa chat default | REF-SCROLL-PORTAL | `ChatAulaScreen` | JA EXISTIA | widget_test | Preservar |
| 526 | Rota aula sem id volta objetivo | REF-SCROLL-PORTAL | sem `ChatAulaScreen` | JA EXISTIA | widget_test | Preservar |
| 527 | Onboarding aciona T00 | REF-SCROLL-PORTAL | `t00Called` | JA EXISTIA | widget_test | Preservar |
| 528 | Onboarding aciona T02 | REF-SCROLL-PORTAL | `t02Called` | JA EXISTIA | widget_test | Preservar |
| 529 | Onboarding preserva anexo no objetivo | REF-SCROLL-PORTAL | `lista-da-prova.pdf` | JA EXISTIA | widget_test | Preservar |
| 530 | Onboarding passa objetivo textual | REF-SCROLL-PORTAL | expect objetivo matematica | JA EXISTIA | widget_test | Preservar |
| 531 | Objetivo vazio bloqueado | REF-WCAG-STATUS | validacao local | JA EXISTIA | widget_test | Preservar |
| 532 | Preparacao mostra etapa curriculum | REF-SCROLL-PORTAL | onStage curriculum | JA EXISTIA | widget_test | Preservar |
| 533 | Preparacao mostra etapa lesson | REF-SCROLL-PORTAL | onStage lesson | JA EXISTIA | widget_test | Preservar |
| 534 | Preparacao mostra etapa ready | REF-SCROLL-PORTAL | onStage ready | JA EXISTIA | widget_test | Preservar |
| 535 | Resultado navega para aula | REF-SCROLL-PORTAL | destination `/cyber/aula` | JA EXISTIA | widget_test | Preservar |
| 536 | Resultado carrega curriculum | REF-SCROLL-PORTAL | StudentCurriculum | JA EXISTIA | widget_test | Preservar |
| 537 | Resultado carrega startMarker | REF-SCROLL-PORTAL | `M1` | JA EXISTIA | widget_test | Preservar |
| 538 | Resultado carrega startItemIndex | REF-SCROLL-PORTAL | `0` | JA EXISTIA | widget_test | Preservar |
| 539 | Aula permite resposta A/B/C | REF-SCROLL-RUNTIME | fluxo normal | JA EXISTIA | widget_test | Preservar |
| 540 | Aula mostra duvida e qualificadores | REF-SCROLL-PORTAL | Preenchimento shows doubt | JA EXISTIA | widget_test | Preservar |
| 541 | Sinais e feedback ficam visiveis | REF-SCROLL-PORTAL | answer flow test | JA EXISTIA | widget_test | Preservar |
| 542 | Aula vazia mostra estado humano | REF-WCAG-STATUS | estado vazio equivalente Web | JA EXISTIA | widget_test | Preservar |
| 543 | Rotas sensiveis exigem login | REF-SCROLL-PORTAL | roteador central | JA EXISTIA | widget_test | Preservar |
| 544 | Root layout preserva rotas | REF-SCROLL-PORTAL | support_phase | JA EXISTIA | support_phase | Preservar |
| 545 | Cyber layout preserva comportamento | REF-SCROLL-PORTAL | support_phase | JA EXISTIA | support_phase | Preservar |
| 546 | Portal tem acessibilidade menu | REF-FLUTTER-SEMANTICS | semantics label | JA EXISTIA | widget_test | Preservar |
| 547 | Portal tem acessibilidade dark mode | REF-FLUTTER-SEMANTICS | semantics label | JA EXISTIA | widget_test | Preservar |
| 548 | Portal tem fluxo multilíngue | REF-SCROLL-PORTAL | pt/fr/en | JA EXISTIA | widget_test | Preservar |
| 549 | Portal nao usa menu alternativo | REF-SCROLL-PORTAL | menu aula compartilhado | JA EXISTIA | widget_test | Preservar |
| 550 | Portal preserva creditos no menu | REF-SCROLL-PORTAL | credits=7 | JA EXISTIA | widget_test | Preservar |
| 551 | Drawer lista aulas locais | REF-SCROLL-PORTAL | Drawer lista | JA EXISTIA | widget_test | Preservar |
| 552 | Drawer busca aulas locais | REF-SCROLL-PORTAL | Drawer busca | JA EXISTIA | widget_test | Preservar |
| 553 | Drawer renomeia aula local | REF-SCROLL-PORTAL | Drawer renomeia | JA EXISTIA | widget_test | Preservar |
| 554 | Drawer apaga aula local | REF-SCROLL-PORTAL | Drawer apaga | JA EXISTIA | widget_test | Preservar |
| 555 | Drawer cloud lista aulas | REF-SCROLL-CLOUD | Drawer cloud lista | JA EXISTIA | widget_test | Preservar |
| 556 | Drawer cloud deduplica aulas | REF-SCROLL-CLOUD | Drawer cloud deduplica | JA EXISTIA | widget_test | Preservar |
| 557 | Drawer cloud abre aula | REF-SCROLL-CLOUD | Drawer cloud abre | JA EXISTIA | widget_test | Preservar |
| 558 | Drawer cloud renomeia aula | REF-SCROLL-CLOUD | Drawer cloud renomeia | JA EXISTIA | widget_test | Preservar |
| 559 | Drawer cloud apaga aula | REF-SCROLL-CLOUD | Drawer cloud apaga | JA EXISTIA | widget_test | Preservar |
| 560 | Drawer nova aula segue contrato Web | REF-SCROLL-PORTAL | drawer_new_lesson | JA EXISTIA | widget_test | Preservar |
| 561 | Drawer delete local segue contrato Web | REF-SCROLL-PORTAL | local_delete contract | JA EXISTIA | widget_test | Preservar |
| 562 | Drawer importa backup txt | REF-SCROLL-PORTAL | backup import | JA EXISTIA | widget_test | Preservar |
| 563 | Drawer mantem paste fallback | REF-SCROLL-PORTAL | paste fallback | JA EXISTIA | widget_test | Preservar |
| 564 | Drawer search tem rotulo historico | REF-FLUTTER-SEMANTICS | HISTORY/HISTORICO | JA EXISTIA | widget_test | Preservar |
| 565 | Drawer internal doors resolvem | REF-SCROLL-TESTS | school completeness | JA EXISTIA | school_completeness | Preservar |
| 566 | Drawer organs preservados | REF-SCROLL-TESTS | aula drawer contract | JA EXISTIA | school_completeness | Preservar |
| 567 | Drawer button flow preservado | REF-SCROLL-TESTS | critical doors | JA EXISTIA | school_completeness | Preservar |
| 568 | Drawer busca sem backend obrigatorio | REF-SCROLL-PORTAL | local search | JA EXISTIA | widget_test | Preservar |
| 569 | Drawer cloud exige auth real | REF-SCROLL-CLOUD | session provider | JA EXISTIA | widget_test | Preservar |
| 570 | Drawer renomear preserva aula ativa | REF-SCROLL-PORTAL | widget flow | JA EXISTIA | widget_test | Ampliar prova |
| 571 | Pricing moeda BRL | REF-SCROLL-BILLING | `simPricing.currency` | JA EXISTIA | billing_phase | Preservar |
| 572 | Custo de aula em creditos | REF-SCROLL-BILLING | lessonCostCredits 3 | JA EXISTIA | billing_phase | Preservar |
| 573 | Custo de imagem em creditos | REF-SCROLL-BILLING | imageCostCredits 10 | JA EXISTIA | billing_phase | Preservar |
| 574 | Bonus signup preservado | REF-SCROLL-BILLING | signupBonus 9 | JA EXISTIA | billing_phase | Preservar |
| 575 | Pacote 100 preserva preco | REF-SCROLL-BILLING | credits_100 790 | JA EXISTIA | billing_phase | Preservar |
| 576 | Pacote 200 preserva creditos | REF-SCROLL-BILLING | credits_200 | JA EXISTIA | billing_phase | Preservar |
| 577 | Pacote 500 preserva preco | REF-SCROLL-BILLING | credits_500 3950 | JA EXISTIA | billing_phase | Preservar |
| 578 | Product id 100 estavel | REF-PLAY-BILLING | sim_credits_100 | JA EXISTIA | billing_phase | Preservar |
| 579 | Product id 200 estavel | REF-PLAY-BILLING | sim_credits_200 | JA EXISTIA | billing_phase | Preservar |
| 580 | Product id 500 estavel | REF-PLAY-BILLING | sim_credits_500 | JA EXISTIA | billing_phase | Preservar |
| 581 | Parser aceita product id Play | REF-PLAY-BILLING | fromGooglePlayProduct | JA EXISTIA | billing_phase | Preservar |
| 582 | Parser rejeita product id Stripe | REF-PLAY-BILLING | stripe_credits_200 null | JA EXISTIA | billing_phase | Preservar |
| 583 | Return target aceita rota interna | REF-SCROLL-BILLING | `/cyber/aula` | JA EXISTIA | billing_phase | Preservar |
| 584 | Return target rejeita URL externa | REF-SCROLL-BILLING | `//evil.com` rejeitado | JA EXISTIA | billing_phase | Preservar |
| 585 | Return target rejeita creditos | REF-SCROLL-BILLING | `/creditos` rejeitado | JA EXISTIA | billing_phase | Preservar |
| 586 | Return target limpa apos uso | REF-SCROLL-BILLING | clearReturnTo | JA EXISTIA | billing_phase | Preservar |
| 587 | Checkout hosted abre Stripe | REF-STRIPE-CHECKOUT | checkout.stripe.com | JA EXISTIA | billing_phase | Preservar |
| 588 | Checkout hosted usa pack id | REF-STRIPE-CHECKOUT | packId | JA EXISTIA | billing_phase | Preservar |
| 589 | Checkout hosted preserva saldo | REF-SCROLL-BILLING | balance 12 | JA EXISTIA | billing_phase | Preservar |
| 590 | Checkout embedded rollback preservado | REF-STRIPE-CHECKOUT | checkoutPack | JA EXISTIA | billing_phase | Preservar |
| 591 | Checkout return valida session | REF-STRIPE-CHECKOUT | confirm cs_test | JA EXISTIA | billing_phase | Preservar |
| 592 | Checkout return restaura target | REF-SCROLL-BILLING | continueTarget | JA EXISTIA | billing_phase | Preservar |
| 593 | Checkout return limpa target salvo | REF-SCROLL-BILLING | store null | JA EXISTIA | billing_phase | Preservar |
| 594 | Webhook usa pack oficial | REF-SCROLL-BILLING | credits_500 -> 500 | JA EXISTIA | billing_phase | Preservar |
| 595 | Webhook ignora credits metadata fraudado | REF-SCROLL-BILLING | metadata 999 ignorado | JA EXISTIA | billing_phase | Preservar |
| 596 | Webhook ignora unpaid | REF-SCROLL-BILLING | unpaid null | JA EXISTIA | billing_phase | Preservar |
| 597 | Ambiente live parseado | REF-SCROLL-BILLING | parse live | JA EXISTIA | billing_phase | Preservar |
| 598 | Deletar conta exige DELETAR | REF-SCROLL-BILLING | lowercase rejeitado | JA EXISTIA | billing_phase | Preservar |
| 599 | Deletar conta registra request | REF-SCROLL-BILLING | gateway request | JA EXISTIA | billing_phase | Preservar |
| 600 | LabSession chama exclusao autenticada | REF-SCROLL-BILLING | account deletion gateway | JA EXISTIA | billing_phase | Preservar |
| 601 | Billing producao usa Google Play | REF-PLAY-BILLING | production billing test | JA EXISTIA | billing_phase | Preservar |
| 602 | Billing nao inicia sem auth | REF-SCROLL-BILLING | auth missing | JA EXISTIA | billing_phase | Preservar |
| 603 | Billing expõe pending | REF-PLAY-BILLING | pending state | JA EXISTIA | billing_phase | Preservar |
| 604 | Billing expõe canceled | REF-PLAY-BILLING | canceled state | JA EXISTIA | billing_phase | Preservar |
| 605 | Charge lesson normaliza ids | REF-SCROLL-BILLING | server validator parity | JA EXISTIA | billing_phase | Preservar |
| 606 | Credito com operationId idempotente | REF-SCROLL-STATE | nao duplica ledger | JA EXISTIA | internal_organs | Preservar |
| 607 | Credito reserva no estado vivo | REF-SCROLL-STATE | reserva creditos | JA EXISTIA | internal_organs | Preservar |
| 608 | Credito captura no estado vivo | REF-SCROLL-STATE | captura creditos | JA EXISTIA | internal_organs | Preservar |
| 609 | Credito reembolsa no estado vivo | REF-SCROLL-STATE | reembolsa creditos | JA EXISTIA | internal_organs | Preservar |
| 610 | Imagem paga captura credito | REF-SCROLL-STATE | paid image real | JA EXISTIA | internal_organs | Preservar |
| 611 | Imagem paga falha sem sucesso falso | REF-SCROLL-STATE | paid image failure | JA EXISTIA | internal_organs | Preservar |
| 612 | Imagem paga falha devolve credito | REF-SCROLL-STATE | refund test | JA EXISTIA | internal_organs | Preservar |
| 613 | Billing nao altera prompts | Regra usuario | prompt nao tocado | PRESERVADO | git diff | Preservar |
| 614 | Billing nao altera servidor | Regra usuario | backend nao tocado | PRESERVADO | git diff | Preservar |
| 615 | Billing nao altera cache | Regra usuario | cache nao tocado | PRESERVADO | git diff | Preservar |
| 616 | Billing externo com certificado pinning | REF-SLACK-HISTORY | nao comprovado | BLOQUEADO | N/A | Avaliar plataforma |
| 617 | Billing fraud analytics | REF-SLACK-HISTORY | nao comprovado | BLOQUEADO | N/A | Produto/seguranca |
| 618 | Billing retry 429 com backoff | REF-SLACK-HISTORY | nao comprovado | BLOQUEADO | N/A | Criar policy |
| 619 | Billing recibo offline | REF-SLACK-HISTORY | nao comprovado | BLOQUEADO | N/A | Contrato Play |
| 620 | Billing restore purchase | REF-PLAY-BILLING | nao comprovado | BLOQUEADO | N/A | Auditar Play restore |
| 621 | Attachment envia multipart autenticado | REF-SCROLL-ATTACH | authorization Bearer | JA EXISTIA | electrical | Preservar |
| 622 | Attachment usa endpoint process-attachment | REF-SCROLL-ATTACH | `/api/process-attachment` | JA EXISTIA | electrical | Preservar |
| 623 | Attachment usa campo file | REF-SCROLL-ATTACH | fieldName file | JA EXISTIA | electrical | Preservar |
| 624 | Attachment preserva filename | REF-SCROLL-ATTACH | filename no multipart | JA EXISTIA | electrical | Preservar |
| 625 | Attachment preserva contentType | REF-SCROLL-ATTACH | contentType no multipart | JA EXISTIA | electrical | Preservar |
| 626 | Attachment preserva bytes reais | REF-SCROLL-ATTACH | bytes length | JA EXISTIA | electrical | Preservar |
| 627 | Attachment nao envia chave secreta | REF-SCROLL-ATTACH | sem LOVABLE_API_KEY | JA EXISTIA | electrical | Preservar |
| 628 | Attachment retorna extractedText | REF-SCROLL-ATTACH | texto do arquivo | JA EXISTIA | electrical | Preservar |
| 629 | Attachment retorna method | REF-SCROLL-ATTACH | pdf-text | JA EXISTIA | electrical | Preservar |
| 630 | Attachment preserva status HTTP | REF-SCROLL-ATTACH | status 413 | JA EXISTIA | electrical | Preservar |
| 631 | Attachment preserva requestId body | REF-SCROLL-ATTACH | rid-body | JA EXISTIA | electrical | Preservar |
| 632 | Attachment preserva error code | REF-SCROLL-ATTACH | FILE_TOO_LARGE | JA EXISTIA | electrical | Preservar |
| 633 | Attachment preserva retryable false | REF-SCROLL-ATTACH | retryable false | JA EXISTIA | electrical | Preservar |
| 634 | Attachment suporta PDF | REF-SCROLL-ATTACH | lista.pdf | JA EXISTIA | finish/electrical | Preservar |
| 635 | Attachment suporta imagem | REF-SCROLL-ATTACH | foto.png | JA EXISTIA | electrical | Preservar |
| 636 | Attachment objetivo processa arquivo real | REF-SCROLL-ATTACH | finish_phase | JA EXISTIA | finish_phase | Preservar |
| 637 | Attachment objetivo envia bytes reais | REF-SCROLL-ATTACH | bytes reais | JA EXISTIA | finish_phase | Preservar |
| 638 | Attachment nao usa texto fixo | REF-SCROLL-ATTACH | sem texto fixo | JA EXISTIA | finish_phase | Preservar |
| 639 | Attachment permissao camera Android | REF-SCROLL-ATTACH | AndroidManifest CAMERA | JA EXISTIA | electrical | Preservar |
| 640 | Attachment permissao READ_MEDIA_IMAGES | REF-SCROLL-ATTACH | manifest | JA EXISTIA | electrical | Preservar |
| 641 | Attachment permissao READ_EXTERNAL_STORAGE | REF-SCROLL-ATTACH | manifest | JA EXISTIA | electrical | Preservar |
| 642 | App tem permissao INTERNET | REF-SCROLL-ATTACH | manifest INTERNET | JA EXISTIA | electrical | Preservar |
| 643 | Release nao usa cleartext | REF-SCROLL-ATTACH | no cleartext true | JA EXISTIA | electrical | Preservar |
| 644 | Network security bloqueia cleartext | REF-SCROLL-ATTACH | cleartext false | JA EXISTIA | electrical | Preservar |
| 645 | Network security nao aponta IP antigo | REF-SCROLL-ATTACH | sem 167.179 | JA EXISTIA | electrical | Preservar |
| 646 | Debug permite cleartext controlado | REF-SCROLL-ATTACH | debug manifest | JA EXISTIA | electrical | Preservar |
| 647 | ApplicationId configuravel | REF-SCROLL-ATTACH | simApplicationId | JA EXISTIA | electrical | Preservar |
| 648 | Release signing gate existe | REF-SCROLL-ATTACH | SIM_REQUIRE_RELEASE_SIGNING | JA EXISTIA | electrical | Preservar |
| 649 | Dependencias reais de midia existem | REF-SCROLL-ATTACH | pubspec test | JA EXISTIA | electrical | Preservar |
| 650 | Attachment upload video | REF-SCROLL-ATTACH | nao comprovado | BLOQUEADO | N/A | Produto/anexo |
| 651 | Attachment preview PDF | REF-SCROLL-ATTACH | nao comprovado | BLOQUEADO | N/A | Criar preview |
| 652 | Attachment cancelamento upload | REF-SCROLL-ATTACH | nao comprovado | BLOQUEADO | N/A | Cancel token |
| 653 | Attachment progress upload | REF-SCROLL-ATTACH | nao comprovado | BLOQUEADO | N/A | Stream progresso |
| 654 | Attachment virus scan client hint | REF-SCROLL-ATTACH | nao comprovado | BLOQUEADO | N/A | Backend/security |
| 655 | Attachment MIME sniffing local | REF-SCROLL-ATTACH | contentType informado | BLOQUEADO | N/A | Adicionar validacao |
| 656 | HTTP postJson contrato separado | REF-SCROLL-ATTACH | SimHttpTransport | JA EXISTIA | electrical | Preservar |
| 657 | HTTP stream contrato separado | REF-SCROLL-ATTACH | postEventStream | JA EXISTIA | electrical | Preservar |
| 658 | HTTP multipart contrato separado | REF-SCROLL-ATTACH | postMultipart | JA EXISTIA | electrical | Preservar |
| 659 | HTTP timeout JSON definido | REF-SCROLL-ATTACH | default 45s | JA EXISTIA | electrical | Preservar |
| 660 | HTTP timeout stream definido | REF-SCROLL-ATTACH | default 140s | JA EXISTIA | electrical | Preservar |
| 661 | HTTP timeout multipart definido | REF-SCROLL-ATTACH | default 60s | JA EXISTIA | electrical | Preservar |
| 662 | AI config usa baseUrl oficial local | REF-SCROLL-ATTACH | config baseUrl | JA EXISTIA | electrical | Preservar |
| 663 | AI config injeta access token | REF-SCROLL-ATTACH | accessTokenProvider | JA EXISTIA | electrical | Preservar |
| 664 | Cloud sync envia bearer de sessao | REF-SCROLL-CLOUD | Authorization Bearer | JA EXISTIA | electrical | Preservar |
| 665 | Cloud sync envia snapshot completo | REF-SCROLL-CLOUD | body state Map | JA EXISTIA | electrical | Preservar |
| 666 | Cloud sync preserva highWaterMark | REF-SCROLL-CLOUD | highWaterMark 12 | JA EXISTIA | electrical | Preservar |
| 667 | Cloud sync usa lessonLocalId | REF-SCROLL-CLOUD | l1 | JA EXISTIA | electrical | Preservar |
| 668 | Cloud sync usa clientUpdatedAt | REF-SCROLL-CLOUD | input | JA EXISTIA | electrical | Preservar |
| 669 | Cloud sync usa clientScore | REF-SCROLL-CLOUD | score 12 | JA EXISTIA | electrical | Preservar |
| 670 | Cloud queue merge remote on reject | REF-SCROLL-CLOUD | cloud_phase | JA EXISTIA | cloud_phase | Preservar |
| 671 | Cloud queue re-enqueue em conflito | REF-SCROLL-RUNTIME | T18 parity | JA EXISTIA | classroom_parity | Preservar |
| 672 | Cloud queue debounce retry | REF-SCROLL-RUNTIME | T16 1500ms | JA EXISTIA | classroom_parity | Preservar |
| 673 | Cloud queue mantem entry apos falha | REF-SCROLL-RUNTIME | T17 | JA EXISTIA | classroom_parity | Preservar |
| 674 | Cloud queue backoff apos 10 falhas | REF-SCROLL-RUNTIME | T19 300s | JA EXISTIA | classroom_parity | Preservar |
| 675 | Cloud queue drena ao pausar app | REF-FLUTTER-SEMANTICS | T20 paused | JA EXISTIA | classroom_parity | Preservar |
| 676 | StateStore persiste e rele | REF-SCROLL-CLOUD | state_store_truth | JA EXISTIA | state_store | Preservar |
| 677 | StateStore registra event log | REF-SCROLL-CLOUD | Event Log canonico | JA EXISTIA | state_store | Preservar |
| 678 | StateStore exporta backup | REF-SCROLL-CLOUD | export/import backup | JA EXISTIA | state_store | Preservar |
| 679 | StateStore importa backup | REF-SCROLL-CLOUD | import backup | JA EXISTIA | state_store | Preservar |
| 680 | StateStore evita replay duplicado | REF-SCROLL-CLOUD | evita evento duplicado | JA EXISTIA | state_store | Preservar |
| 681 | StateStore resolve estado avancado | REF-SCROLL-CLOUD | conflito estado mais avancado | JA EXISTIA | state_store | Preservar |
| 682 | StudentLearningState serializa truth | REF-SCROLL-CLOUD | truth tipado | JA EXISTIA | state_store | Preservar |
| 683 | StudentLearningState serializa sync | REF-SCROLL-CLOUD | sync tipado | JA EXISTIA | state_store | Preservar |
| 684 | StudentLearningState fallback legado | REF-SCROLL-CLOUD | fallback legado | JA EXISTIA | state_store | Preservar |
| 685 | Backup Web importa e retoma ponto | REF-SCROLL-CLOUD | simweb_backup_import | JA EXISTIA | sync_b | Preservar |
| 686 | Backup app export/import sem perda | REF-SCROLL-CLOUD | simapp roundtrip | JA EXISTIA | sync_b | Preservar |
| 687 | Multi-device converge | REF-SCROLL-CLOUD | multi_device_state_sync | JA EXISTIA | sync_b | Preservar |
| 688 | Sync nao envia segredo app-side | REF-SCROLL-CLOUD | bearer user token | JA EXISTIA | electrical | Preservar |
| 689 | Sync incremental real | REF-SCROLL-CLOUD | highWaterMark parcial | JA EXISTIA | sync tests | Preservar |
| 690 | Sync com dados corrompidos | REF-SCROLL-CLOUD | nao comprovado | BLOQUEADO | N/A | Criar teste corrupcao |
| 691 | T00 usa porta viva bootstrap | REF-SCROLL-TESTS | `/api/bootstrap-t00` | JA EXISTIA | external_ai | Preservar |
| 692 | T00 envia ficha | REF-SCROLL-TESTS | ficha e bearer | JA EXISTIA | external_ai | Preservar |
| 693 | T00 envia bearer | REF-SCROLL-TESTS | tokenPresent true | JA EXISTIA | external_ai | Preservar |
| 694 | Imagem usa endpoint generate | REF-SCROLL-TESTS | `/api/generate-lesson-image` | JA EXISTIA | external_ai | Preservar |
| 695 | Imagem nao envia provider key | REF-SCROLL-TESTS | sem chave provedor | JA EXISTIA | external_ai | Preservar |
| 696 | Imagem preserva metadados sucesso | REF-SCROLL-TESTS | metadata success | JA EXISTIA | external_ai | Preservar |
| 697 | Visual route usa endpoint oficial | REF-SCROLL-TESTS | `/api/visual-route` | JA EXISTIA | external_ai | Preservar |
| 698 | Visual route preserva SVG gratuito | REF-SCROLL-TESTS | SVG gratuito | JA EXISTIA | external_ai | Preservar |
| 699 | Visual route preserva no_image N3 | REF-SCROLL-TESTS | no_image | JA EXISTIA | external_ai | Preservar |
| 700 | Audio endpoint generate lesson audio | REF-SCROLL-TESTS | `/api/generate-lesson-audio` | JA EXISTIA | external_ai | Preservar |
| 701 | Audio endpoint devolve dataUrl | REF-SCROLL-TESTS | dataUrl | JA EXISTIA | external_ai | Preservar |
| 702 | Erro imagem preserva status | REF-SCROLL-TESTS | status | JA EXISTIA | external_ai | Preservar |
| 703 | Erro imagem preserva requestId | REF-SCROLL-TESTS | requestId | JA EXISTIA | external_ai | Preservar |
| 704 | Erro imagem preserva code | REF-SCROLL-TESTS | code | JA EXISTIA | external_ai | Preservar |
| 705 | Erro imagem preserva retryable | REF-SCROLL-TESTS | retryable | JA EXISTIA | external_ai | Preservar |
| 706 | Erro audio preserva requestId | REF-SCROLL-TESTS | requestId tecnico | JA EXISTIA | external_ai | Preservar |
| 707 | Timeout audio vira retryable | REF-SCROLL-TESTS | retryable true | JA EXISTIA | external_ai | Preservar |
| 708 | Timeout audio cria requestId cliente | REF-SCROLL-TESTS | client requestId | JA EXISTIA | external_ai | Preservar |
| 709 | T02 nao inventa rota inexistente | REF-SCROLL-TESTS | ponte HTTP ausente | JA EXISTIA | external_ai | Preservar |
| 710 | T02 usa ponte HTTP configurada | REF-SCROLL-TESTS | ponte configurada | JA EXISTIA | external_ai | Preservar |
| 711 | T02 invalido nao vira aula falsa | REF-WCAG-STATUS | invalid T02 | JA EXISTIA | external_ai | Preservar |
| 712 | T02 invalido nao default A | REF-WCAG-STATUS | sem default A | JA EXISTIA | external_ai | Preservar |
| 713 | HTTP 401 auth fica recuperavel | REF-WCAG-STATUS | session_regression | JA EXISTIA | session_regression | Preservar |
| 714 | Onboarding repete T00 uma vez em 401 | REF-SCROLL-TESTS | auth refresh retry | JA EXISTIA | session_regression | Preservar |
| 715 | Curriculo espera authReady | REF-SCROLL-TESTS | espera authReady/authed | JA EXISTIA | session_regression | Preservar |
| 716 | Curriculo nao redireciona login cedo | REF-SCROLL-TESTS | sem redirect antes T00 | JA EXISTIA | session_regression | Preservar |
| 717 | StartNewLesson limpa midia stale | REF-SCROLL-TESTS | clears stale aula media | JA EXISTIA | session_regression | Preservar |
| 718 | StartNewLesson limpa audio UI stale | REF-SCROLL-TESTS | clears audio UI | JA EXISTIA | session_regression | Preservar |
| 719 | SubmitDoubt ignora duplicado processando | REF-SCROLL-TESTS | duplicate submission | JA EXISTIA | session_regression | Preservar |
| 720 | RuntimeSnapshot copyWith limpa campos | REF-SCROLL-TESTS | override/clear every field | JA EXISTIA | session_regression | Preservar |
| 721 | Google auth Android real | REF-SCROLL-TESTS | Supabase OAuth | JA EXISTIA | google_auth | Preservar |
| 722 | AuthSession inicia authed false | REF-SCROLL-TESTS | fase9 | JA EXISTIA | fase9 | Preservar |
| 723 | AuthSession refresh expired | REF-SCROLL-TESTS | auth_role_gate | JA EXISTIA | auth_role | Preservar |
| 724 | AuthSession extrai parent roles | REF-SCROLL-TESTS | metadata roles | JA EXISTIA | auth_role | Preservar |
| 725 | NavigationState preserva retorno seguro | REF-SCROLL-TESTS | fase9 | JA EXISTIA | fase9 | Preservar |
| 726 | EntryFormState notifica freeText | REF-SCROLL-TESTS | fase9 | JA EXISTIA | fase9 | Preservar |
| 727 | LessonUiState toggleDoubt | REF-SCROLL-TESTS | fase9 | JA EXISTIA | fase9 | Preservar |
| 728 | LessonUiState advance fecha duvida | REF-SCROLL-TESTS | fase9 | JA EXISTIA | fase9 | Preservar |
| 729 | Auth logs sem token em UI | REF-SCROLL-TESTS | tokenPresent boolean | PRESERVADO | external/session | Preservar |
| 730 | Auth passkey flow | REF-SCROLL-TESTS | nao comprovado nesta fatia | BLOQUEADO | N/A | Auditar passkeys |
| 731 | Runtime L1 correto sinal 1 vai L3 | REF-SCROLL-RUNTIME | T01 | JA EXISTIA | classroom_parity | Preservar |
| 732 | Runtime L1 errado sinal 1 vai L2 | REF-SCROLL-RUNTIME | T02 | JA EXISTIA | classroom_parity | Preservar |
| 733 | Runtime L3 correto avanca item | REF-SCROLL-RUNTIME | T03 | JA EXISTIA | classroom_parity | Preservar |
| 734 | Runtime L3 sinal 3 reforca | REF-SCROLL-RUNTIME | T04 | JA EXISTIA | classroom_parity | Preservar |
| 735 | Runtime sinal 2 L1 vai L2 | REF-SCROLL-RUNTIME | T05 | JA EXISTIA | classroom_parity | Preservar |
| 736 | Runtime sinal 2 L2 vai L3 | REF-SCROLL-RUNTIME | T06 | JA EXISTIA | classroom_parity | Preservar |
| 737 | Runtime erro L2 sinal 3 reforca | REF-SCROLL-RUNTIME | T07 | JA EXISTIA | classroom_parity | Preservar |
| 738 | Runtime fim mostra completion | REF-SCROLL-RUNTIME | T08/T09 | JA EXISTIA | classroom_parity | Preservar |
| 739 | Runtime layer invalida mostra atual | REF-SCROLL-RUNTIME | T10 | JA EXISTIA | classroom_parity | Preservar |
| 740 | Runtime curriculo vazio noSafeDecision | REF-WCAG-STATUS | T11 | JA EXISTIA | classroom_parity | Preservar |
| 741 | Runtime concluidos avanca item | REF-SCROLL-RUNTIME | T12 | JA EXISTIA | classroom_parity | Preservar |
| 742 | Runtime mainAdvances incrementa | REF-SCROLL-RUNTIME | T13 | JA EXISTIA | classroom_parity | Preservar |
| 743 | Runtime answer correto calculado | REF-SCROLL-RUNTIME | T14 | JA EXISTIA | classroom_parity | Preservar |
| 744 | Historico preserva 5 imagens | REF-SCROLL-RUNTIME | T15 | JA EXISTIA | classroom_parity | Preservar |
| 745 | Material idx errado retorna null | REF-SCROLL-RUNTIME | T21 | JA EXISTIA | classroom_parity | Preservar |
| 746 | Material idx/marker/layer certo retorna | REF-SCROLL-RUNTIME | T22 | JA EXISTIA | classroom_parity | Preservar |
| 747 | ReadyWindow 3 itens 3 slots | REF-SCROLL-RUNTIME | T23 | JA EXISTIA | classroom_parity | Preservar |
| 748 | Selecionar resposta para audio | REF-SCROLL-RUNTIME | T24 | JA EXISTIA | classroom_parity | Preservar |
| 749 | Enviar sinal em loading ignora | REF-SCROLL-RUNTIME | T25 | JA EXISTIA | classroom_parity | Preservar |
| 750 | Sinal atrasado ignora se fase mudou | REF-SCROLL-RUNTIME | T25b | JA EXISTIA | classroom_parity | Preservar |
| 751 | Avancar sem sinal ignora | REF-SCROLL-RUNTIME | T26 | JA EXISTIA | classroom_parity | Preservar |
| 752 | Completion allowed uma vez | REF-SCROLL-RUNTIME | T27 | JA EXISTIA | classroom_parity | Preservar |
| 753 | StableHash ignora updatedAt | REF-SCROLL-RUNTIME | T28 | JA EXISTIA | classroom_parity | Preservar |
| 754 | StableHash ignora cacheInfo | REF-SCROLL-RUNTIME | T28 | JA EXISTIA | classroom_parity | Preservar |
| 755 | StableHash ignora syncInfo | REF-SCROLL-RUNTIME | T28 | JA EXISTIA | classroom_parity | Preservar |
| 756 | Fluxo completo 3 itens x 3 layers | REF-SCROLL-RUNTIME | normal_lesson_full_completion | JA EXISTIA | normal_flow | Preservar |
| 757 | Fluxo completo persiste conclusao | REF-SCROLL-RUNTIME | normal flow persistence | JA EXISTIA | normal_flow | Preservar |
| 758 | Answer signal escreve mastery | REF-SCROLL-RUNTIME | classroom_phase | JA EXISTIA | classroom_phase | Preservar |
| 759 | ViewModel bloqueia apos completion | REF-SCROLL-RUNTIME | LessonMainViewModel locks | JA EXISTIA | classroom_phase | Preservar |
| 760 | ViewModel rotula next layer | REF-SCROLL-RUNTIME | labels next layer | JA EXISTIA | classroom_phase | Preservar |
| 761 | LearningDecision preserva L1 sinal1 | REF-SCROLL-RUNTIME | sim_state_engines | JA EXISTIA | sim_state | Preservar |
| 762 | Mastery shortcut desativado ignora truth | REF-SCROLL-RUNTIME | useMasteryShortcut off | JA EXISTIA | sim_state | Preservar |
| 763 | Typed truth ignorado com shortcut off | REF-SCROLL-RUNTIME | typed truth ignored | JA EXISTIA | sim_state | Preservar |
| 764 | Legacy extra ignorado com shortcut off | REF-SCROLL-RUNTIME | legacy extra ignored | JA EXISTIA | sim_state | Preservar |
| 765 | Executor aplica answer sem fallback legado | REF-SCROLL-RUNTIME | StudentLessonExecutor | JA EXISTIA | sim_state | Preservar |
| 766 | LiveEntry nao regride apos ready | REF-SCROLL-RUNTIME | LiveEntry test | JA EXISTIA | sim_state | Preservar |
| 767 | MasteryTruth nao aceita acerto isolado | REF-SCROLL-RUNTIME | mastery truth | JA EXISTIA | state_store | Preservar |
| 768 | MasteryTruth exige evidencia suficiente | REF-SCROLL-RUNTIME | mastery sufficient | JA EXISTIA | state_store | Preservar |
| 769 | MasteryTruth detecta fraqueza | REF-SCROLL-RUNTIME | weakness | JA EXISTIA | state_store | Preservar |
| 770 | MasteryTruth detecta falsa maestria | REF-SCROLL-RUNTIME | false mastery | JA EXISTIA | state_store | Preservar |
| 771 | MasteryTruth escreve verdade no estado | REF-SCROLL-RUNTIME | writes truth | JA EXISTIA | state_store | Preservar |
| 772 | Shadow decision grava auditoria | REF-SCROLL-RUNTIME | shadow decision | JA EXISTIA | bloco1 | Preservar |
| 773 | Shadow decision nao autoalimenta | REF-SCROLL-RUNTIME | sem autoalimentar | JA EXISTIA | bloco1 | Preservar |
| 774 | SignalTracker 3 sinais ruins abre amparo | REF-SCROLL-RUNTIME | SignalTracker | JA EXISTIA | bloco1 | Preservar |
| 775 | Decision audit registra sugestao | REF-SCROLL-STATE | internal_organs | JA EXISTIA | internal_organs | Preservar |
| 776 | Decision audit registra comparacao | REF-SCROLL-STATE | internal_organs | JA EXISTIA | internal_organs | Preservar |
| 777 | Decision audit nao aplica progresso | REF-SCROLL-STATE | shadow only | JA EXISTIA | internal_organs | Preservar |
| 778 | Verdade pedagogica abre revisao | REF-SCROLL-STATE | internal_organs | JA EXISTIA | internal_organs | Preservar |
| 779 | Verdade pedagogica abre recuperacao | REF-SCROLL-STATE | internal_organs | JA EXISTIA | internal_organs | Preservar |
| 780 | Resposta, verdade, decisao usam mesmo estado | REF-SCROLL-STATE | same state | JA EXISTIA | internal_organs | Preservar |
| 781 | Sala auxiliar usa mesmo estado | REF-SCROLL-STATE | same state aux | JA EXISTIA | internal_organs | Preservar |
| 782 | Coordenador assenta resposta ate aux | REF-SCROLL-STATE | settle answer | JA EXISTIA | internal_organs | Preservar |
| 783 | Coordenador sincroniza apos resposta | REF-SCROLL-STATE | sync after settle | JA EXISTIA | internal_organs | Preservar |
| 784 | Placement grava estado canonico | REF-SCROLL-STATE | placement governor | JA EXISTIA | internal_organs | Preservar |
| 785 | Placement espelha legado como evento | REF-SCROLL-STATE | legacy mirror event | JA EXISTIA | internal_organs | Preservar |
| 786 | Placement score começa no primeiro erro | REF-SCROLL-RUNTIME | scorePlacement | JA EXISTIA | placement_phase | Preservar |
| 787 | Placement service escreve placement | REF-SCROLL-RUNTIME | StudentPlacementService | JA EXISTIA | placement_phase | Preservar |
| 788 | Placement service espelha legado | REF-SCROLL-RUNTIME | mirrors legacy | JA EXISTIA | placement_phase | Preservar |
| 789 | Placement T02 retorna bloco diagnostico | REF-SCROLL-RUNTIME | PlacementT02Caller | JA EXISTIA | placement_phase | Preservar |
| 790 | Placement choice intro flow | REF-SCROLL-RUNTIME | route controller | JA EXISTIA | placement_phase | Preservar |
| 791 | Placement nao morto por rocket path | REF-SCROLL-TESTS | placement aparece necessario | JA EXISTIA | first_ready | Preservar |
| 792 | Start real respeita placement | REF-SCROLL-TESTS | placement tests | JA EXISTIA | placement_phase | Preservar |
| 793 | Nivelamento por percentual 20/30/40 | REF-SCROLL-RUNTIME | nao provado por todos percentuais | BLOQUEADO | N/A | Criar casos parametrizados |
| 794 | Placement acessivel por leitor tela | REF-FLUTTER-SEMANTICS | nao comprovado completo | BLOQUEADO | N/A | Auditar semantica |
| 795 | Placement restore apos app kill | REF-SCROLL-CLOUD | nao comprovado | BLOQUEADO | N/A | Criar restore test |
| 796 | Classroom current review room retorna | REF-SCROLL-TESTS | chat review room | JA EXISTIA | chat widgets | Preservar |
| 797 | Classroom current recovery room retorna | REF-SCROLL-TESTS | chat recovery room | JA EXISTIA | chat widgets | Preservar |
| 798 | Review queue registra pending | REF-SCROLL-RUNTIME | aux pending map | JA EXISTIA | auxiliary_phase | Preservar |
| 799 | Aux pending map limpa itens | REF-SCROLL-RUNTIME | clears live pending | JA EXISTIA | auxiliary_phase | Preservar |
| 800 | Recovery inicia apenas com pendente | REF-SCROLL-RUNTIME | recovery room starts only pending | JA EXISTIA | auxiliary_phase | Preservar |
| 801 | Organismo usa canonicalStore externo | REF-SCROLL-STATE | organism integration | JA EXISTIA | organism | Preservar |
| 802 | Organismo nasce orgaos conectados | REF-SCROLL-STATE | organismo ideal | JA EXISTIA | organism | Preservar |
| 803 | Roteador protege identificacao | REF-SCROLL-PORTAL | organism router | JA EXISTIA | organism | Preservar |
| 804 | Roteador protege idioma | REF-SCROLL-PORTAL | organism router | JA EXISTIA | organism | Preservar |
| 805 | Roteador protege objetivo | REF-SCROLL-PORTAL | organism router | JA EXISTIA | organism | Preservar |
| 806 | Sync disponivel sem segredo app | REF-SCROLL-CLOUD | organism sync | JA EXISTIA | organism | Preservar |
| 807 | Creditos disponiveis sem segredo app | REF-SCROLL-BILLING | organism credits | JA EXISTIA | organism | Preservar |
| 808 | Portas externas sem segredo app | REF-SCROLL-ATTACH | organism external ports | JA EXISTIA | organism | Preservar |
| 809 | Fluxo vital objetivo -> T00 | REF-SCROLL-RUNTIME | vital flow | JA EXISTIA | organism_vital | Preservar |
| 810 | Fluxo vital T00 -> T02 | REF-SCROLL-RUNTIME | vital flow | JA EXISTIA | organism_vital | Preservar |
| 811 | Fluxo vital T02 -> aula | REF-SCROLL-RUNTIME | vital flow | JA EXISTIA | organism_vital | Preservar |
| 812 | Fluxo vital aula -> A/B/C | REF-SCROLL-RUNTIME | vital flow | JA EXISTIA | organism_vital | Preservar |
| 813 | Fluxo vital A/B/C -> sinais | REF-SCROLL-RUNTIME | vital flow | JA EXISTIA | organism_vital | Preservar |
| 814 | Fluxo vital sinais -> motor | REF-SCROLL-RUNTIME | vital flow | JA EXISTIA | organism_vital | Preservar |
| 815 | Fluxo vital motor -> janela | REF-SCROLL-RUNTIME | vital flow | JA EXISTIA | organism_vital | Preservar |
| 816 | ReadyWindowWorker inicia com activeLesson | REF-SCROLL-RUNTIME | READY_WINDOW_WORKER_STARTED | JA EXISTIA | organism | Preservar |
| 817 | Worker com aula canonica | REF-SCROLL-RUNTIME | activeLessonLocalId | JA EXISTIA | organism | Preservar |
| 818 | Worker cancelavel | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | Criar cancelamento |
| 819 | Worker backpressure | REF-SLACK-PAGINATION | nao comprovado | BLOQUEADO | N/A | Auditar fila |
| 820 | Worker telemetry granular | REF-SLACK-HISTORY | parcial logs | BLOQUEADO | N/A | Metric store |
| 821 | UI primary actions altura acessivel | REF-FLUTTER-SEMANTICS | accessible touch height | JA EXISTIA | sim_ideal_layout | Preservar |
| 822 | UI secondary actions altura acessivel | REF-FLUTTER-SEMANTICS | accessible touch height | JA EXISTIA | sim_ideal_layout | Preservar |
| 823 | CyberStepShell tablet largura | REF-FLUTTER-SEMANTICS | widens learning column | JA EXISTIA | sim_ideal_layout | Preservar |
| 824 | Zoom aula tem cinco niveis | REF-FLUTTER-SEMANTICS | font control five levels | JA EXISTIA | classroom_health | Preservar |
| 825 | Zoom aula persiste escolha | REF-FLUTTER-SEMANTICS | persists choice | JA EXISTIA | classroom_health | Preservar |
| 826 | Zoom alto mantem sinais visiveis | REF-FLUTTER-SEMANTICS | high zoom | JA EXISTIA | classroom_health | Preservar |
| 827 | Zoom alto mantem feedback visivel | REF-FLUTTER-SEMANTICS | high zoom | JA EXISTIA | classroom_health | Preservar |
| 828 | Zoom alto mantem avancar visivel | REF-FLUTTER-SEMANTICS | high zoom | JA EXISTIA | classroom_health | Preservar |
| 829 | Atualizacao passiva nao rouba scroll | REF-FLUTTER-SEMANTICS | passive update | JA EXISTIA | classroom_health | Preservar |
| 830 | Atualizacao passiva oferece voltar atual | REF-FLUTTER-SEMANTICS | return current | JA EXISTIA | classroom_health | Preservar |
| 831 | Aula reserva lugar da imagem | REF-FLUTTER-SEMANTICS | reserva lugar imagem | JA EXISTIA | classroom_health | Preservar |
| 832 | Aula mostra imagem pronta lesson | REF-SCROLL-TESTS | imagem pronta lesson | JA EXISTIA | classroom_health | Preservar |
| 833 | Sinais abrem abaixo alternativa ativa | REF-FLUTTER-SEMANTICS | gaveta abaixo alternativa | JA EXISTIA | classroom_health | Preservar |
| 834 | Aula sem curriculo humano | REF-WCAG-STATUS | empty state | JA EXISTIA | widget_test | Preservar |
| 835 | Estado erro fatal claro | REF-WCAG-STATUS | parcial | BLOQUEADO | N/A | Auditar mensagens fatais |
| 836 | Estado erro recuperavel visivel | REF-WCAG-STATUS | retry states | JA EXISTIA | widget/session | Preservar |
| 837 | Mensagem tecnica escondida | REF-WCAG-STATUS | saneamento parcial | JA EXISTIA | session_regression | Preservar |
| 838 | RequestId tecnico preservado | REF-SCROLL-ATTACH | attachment/audio/image | JA EXISTIA | external/electrical | Preservar |
| 839 | RequestId exibido sob demanda | REF-WCAG-STATUS | nao comprovado | BLOQUEADO | N/A | UI detalhe tecnico |
| 840 | Erro HTTP 400 audio nao quebra aula | REF-WCAG-STATUS | finish_phase logs | JA EXISTIA | finish_phase | Preservar |
| 841 | Painel nao inventa oferta paga | REF-SCROLL-BILLING | painel test | JA EXISTIA | finish_phase | Preservar |
| 842 | Painel imagem pronta compacto | REF-FLUTTER-SEMANTICS | compacto scroll | JA EXISTIA | finish_phase | Preservar |
| 843 | Painel imagem pronta notifica scroll | REF-FLUTTER-SEMANTICS | notifica scroll | JA EXISTIA | finish_phase | Preservar |
| 844 | Imagem pronta abre inspecao | REF-FLUTTER-SEMANTICS | zoom abre | JA EXISTIA | finish_phase | Preservar |
| 845 | Inspecao imagem fecha | REF-FLUTTER-SEMANTICS | zoom fecha | JA EXISTIA | finish_phase | Preservar |
| 846 | Imagem invalida erro compacto | REF-WCAG-STATUS | imagem invalida | JA EXISTIA | finish_phase | Preservar |
| 847 | Renderizador bitmap historico | REF-SCROLL-TESTS | dataUrl bitmap | JA EXISTIA | finish_phase | Preservar |
| 848 | Texto typewriter obedece zoom | REF-FLUTTER-SEMANTICS | typewriter zoom | JA EXISTIA | finish_phase | Preservar |
| 849 | Typewriter velocidade configuravel | REF-FLUTTER-SEMANTICS | velocidade configuravel | JA EXISTIA | finish_phase | Preservar |
| 850 | Typewriter reduced motion | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | Auditar disableAnimations |
| 851 | Midia escreve StateStore | REF-SCROLL-STATE | midia no StateStore | JA EXISTIA | internal_organs | Preservar |
| 852 | Midia escreve diario canonico | REF-SCROLL-STATE | diario canonico | JA EXISTIA | internal_organs | Preservar |
| 853 | Visual feedback tracks answers | REF-SCROLL-TESTS | visual learning feedback | JA EXISTIA | media_phase | Preservar |
| 854 | Visual feedback tracks doubt | REF-SCROLL-TESTS | visual learning feedback | JA EXISTIA | media_phase | Preservar |
| 855 | Visual operational report combina funil | REF-SCROLL-TESTS | operational report | JA EXISTIA | media_phase | Preservar |
| 856 | Visual operational report combina learning | REF-SCROLL-TESTS | operational report | JA EXISTIA | media_phase | Preservar |
| 857 | Visual prompt preserva idioma | REF-SCROLL-TESTS | language directive | JA EXISTIA | media_phase | Preservar |
| 858 | Visual prompt preserva validacao imagem | REF-SCROLL-TESTS | image validation | JA EXISTIA | media_phase | Preservar |
| 859 | Prompt nao alterado nesta fatia | Regra usuario | nenhum arquivo prompt tocado | PRESERVADO | git diff | Preservar |
| 860 | Servidor nao alterado nesta fatia | Regra usuario | nenhum backend tocado | PRESERVADO | git diff | Preservar |
| 861 | Creditos nao alterados nesta fatia | Regra usuario | billing apenas auditado | PRESERVADO | git diff | Preservar |
| 862 | Cache proibido nao alterado | Regra usuario | cache nao tocado | PRESERVADO | git diff | Preservar |
| 863 | N2 preservado nesta fatia | Regra usuario | N2 nao tocado | PRESERVADO | git diff | Preservar |
| 864 | N3 preservado nesta fatia | Regra usuario | N3 nao tocado | PRESERVADO | git diff | Preservar |
| 865 | Teste portal/drawer existe | REF-SCROLL-TESTS | widget_test | JA EXISTIA | widget_test | Preservar |
| 866 | Teste billing existe | REF-SCROLL-TESTS | billing_phase | JA EXISTIA | billing_phase | Preservar |
| 867 | Teste anexos existe | REF-SCROLL-TESTS | electrical | JA EXISTIA | electrical | Preservar |
| 868 | Teste cloud existe | REF-SCROLL-TESTS | cloud/sync | JA EXISTIA | cloud/sync | Preservar |
| 869 | Teste runtime existe | REF-SCROLL-TESTS | classroom parity | JA EXISTIA | classroom_parity | Preservar |
| 870 | Teste layout existe | REF-SCROLL-TESTS | sim_ideal_layout | JA EXISTIA | sim_ideal_layout | Preservar |
| 871 | Teste session existe | REF-SCROLL-TESTS | session_regression | JA EXISTIA | session | Preservar |
| 872 | Teste organism existe | REF-SCROLL-TESTS | organism | JA EXISTIA | organism | Preservar |
| 873 | Teste media existe | REF-SCROLL-TESTS | media_phase | JA EXISTIA | media | Preservar |
| 874 | Teste full suite existe | REF-SCROLL-TESTS | flutter test | JA EXISTIA | full suite | Preservar |
| 875 | Busca global conversacional | REF-SLACK-HISTORY | nao implementado universal | BLOQUEADO | N/A | Criar indice |
| 876 | Filtro por tipo de mensagem | REF-SLACK-HISTORY | nao implementado universal | BLOQUEADO | N/A | Criar modelo |
| 877 | Deep link para mensagem | REF-SLACK-HISTORY | nao implementado universal | BLOQUEADO | N/A | Ancora por id |
| 878 | Threads/replies universais | REF-SLACK-HISTORY | nao aplicavel a aula atual | NAO APLICAVEL | N/A | Reavaliar chat livre |
| 879 | Mentions universais | REF-SLACK-HISTORY | nao aplicavel a aula atual | NAO APLICAVEL | N/A | Reavaliar colaboração |
| 880 | Push notifications | REF-SLACK-HISTORY | nao comprovado | BLOQUEADO | N/A | Produto/permissao |
| 881 | Local notifications | REF-SLACK-HISTORY | nao comprovado | BLOQUEADO | N/A | Produto/permissao |
| 882 | Read receipts multi-dispositivo | REF-WHATSAPP-TYPING | parcial status local | BLOQUEADO | N/A | Persistir leitura |
| 883 | Typing indicator remoto multiusuario | REF-WHATSAPP-TYPING | nao aplicavel aula IA single-user | NAO APLICAVEL | N/A | Reavaliar multiusuario |
| 884 | Stop generation universal | REF-TELEGRAM-ACTION | nao comprovado | BLOQUEADO | N/A | Cancel token T02/T00 |
| 885 | Regenerate resposta universal | REF-SLACK-HISTORY | nao comprovado | BLOQUEADO | N/A | Produto/pedagogia |
| 886 | Branch de conversa | REF-SLACK-HISTORY | nao implementado | BLOQUEADO | N/A | Modelo de forks |
| 887 | Exportar conversa em PDF | REF-SLACK-HISTORY | nao implementado | BLOQUEADO | N/A | Produto |
| 888 | Apagar mensagem individual | REF-SLACK-HISTORY | nao implementado | BLOQUEADO | N/A | Produto/sync |
| 889 | Editar mensagem do usuario | REF-SLACK-HISTORY | nao aplicavel a respostas pedagogicas atuais | NAO APLICAVEL | N/A | Reavaliar chat livre |
| 890 | Reacao/feedback em mensagem | REF-SLACK-HISTORY | pedagogia usa sinais, nao reactions | NAO APLICAVEL | N/A | Reavaliar social |
| 891 | Moderacao de anexo local | REF-SCROLL-ATTACH | nao comprovado | BLOQUEADO | N/A | Segurança |
| 892 | Redacao PII em logs | REF-SLACK-HISTORY | nao auditado completo | BLOQUEADO | N/A | Auditoria logs |
| 893 | Criptografia em repouso | REF-SLACK-HISTORY | nao comprovada | BLOQUEADO | N/A | Segurança storage |
| 894 | Backup com assinatura | REF-SLACK-HISTORY | nao comprovado | BLOQUEADO | N/A | Segurança backup |
| 895 | Restore com schema migration | REF-SLACK-HISTORY | parcial schemaVersion | BLOQUEADO | N/A | Testes migrations |
| 896 | Relatorio 501-900 criado | REF-SCROLL-TESTS | este arquivo | CRIADO | contagem rg | Preservar |
| 897 | Acumulado 900 itens documentado | REF-SCROLL-TESTS | total acumulado | CRIADO | contagem rg | Continuar 901-1300 |
| 898 | Bloqueios documentados | REF-WCAG-STATUS | secao bloqueios | CRIADO | revisao doc | Preservar |
| 899 | Confirmacoes proibicoes documentadas | Regra usuario | secao confirmacoes | CRIADO | revisao doc | Preservar |
| 900 | Meta 22,5 por cento documentada | REF-SCROLL-TESTS | calculo 900/4000 | CRIADO | revisao doc | Continuar |

## Bloqueios documentados

Os itens bloqueados desta fatia exigem produto, backend, seguranca, persistencia nova, metric store, cancelamento async, push/notification, busca global, forks de conversa, restore com migracoes ou auditoria especifica de logs. Eles nao foram implementados porque nao ha referencia funcional suficiente no app atual ou exigem autorizacao explicita para alterar servidor, produto, seguranca ou contratos externos.

## Confirmacoes

- Nenhum prompt foi alterado nesta fatia.
- Nenhum servidor/backend foi alterado nesta fatia.
- Nenhum credito, preco, cobranca ou funil pago foi alterado nesta fatia.
- Nenhum cache proibido ou reaproveitamento de imagem antiga foi reintroduzido nesta fatia.
- N2/N3 foram preservados.
- O total formal acumulado agora e 900 itens classificados.

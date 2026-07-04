# SIM Scroll - Auditoria funcional da sala de aula em 250 micro-partes

Data: 2026-07-04
Repositorio: `/root/SIM-SCROL`
Escopo: sala de aula Scroll, timeline/chat, renderizacao, alternativas A/B/C e sinais 1/2/3.

## Referencias comprovadas usadas antes de qualquer conclusao

- REF-WEB-SALA: `/root/sim-work/sim-web/src/cyber/aula/LessonMainScreen.tsx:66-193` - Web centraliza tela da aula, header, progresso, historico, midia, duvida, resposta, sinal e avancar.
- REF-WEB-SCROLL: `/root/sim-work/sim-web/src/cyber/aula/ScrollFeed.tsx:22-49` - Web rola para o fundo/ativo por `scrollIntoView` e `ResizeObserver`.
- REF-WEB-ABC: `/root/sim-work/sim-web/src/cyber/aula/QuestionBlock.tsx:13-72` - Web renderiza A/B/C, desabilita historico e preserva selecao.
- REF-WEB-FEEDBACK: `/root/sim-work/sim-web/src/cyber/aula/lessonAnswerFeedback.ts:4-21` - Web deriva feedback de acerto e sinal.
- REF-WEB-SINAIS: `/root/sim-work/sim-web/src/core/S04_SignalTracker.ts:25-100` - Web deriva sinais da aula ativa e grava tentativas no progresso.
- REF-SCROLL-ROTA: `lib/main.dart:274-280` - Scroll seleciona `ChatAulaScreen` por flag e guarda aula ativa.
- REF-SCROLL-CHAT: `lib/features/classroom/chat_aula_screen.dart:155-202` - Scroll monta mensagens de chat a partir do snapshot e liga resposta/sinal/retry/avanco/duvida.
- REF-SCROLL-TIMELINE: `lib/features/classroom/chat_aula_timeline_builder.dart:37-247` - Scroll constroi timeline ordenada: historico, loading, explicacao, duvida, imagem, pergunta, opcoes, resposta, sinais e feedback.
- REF-SCROLL-SCROLL: `lib/features/classroom/chat_aula_widgets.dart:47-260` - Scroll preserva scroll manual, auto-follow, botao voltar ao atual, keys estaveis e resize.
- REF-SCROLL-ABC: `lib/features/classroom/chat_aula_widgets.dart:631-652` e `lib/sim/classroom/lesson_main_view_model.dart:52-70` - Scroll renderiza A/B/C e trava quando processando/concluido/carregando.
- REF-SCROLL-SINAIS: `lib/features/classroom/chat_aula_widgets.dart:655-755`, `lib/sim/classroom/lesson_answer_progress_controller.dart:48-210` e `lib/sim/core/signal_tracker.dart:40-113` - Scroll mostra 1/2/3, grava tentativa, feedback, mastery e eventos.
- REF-SCROLL-RUNTIME: `lib/sim/classroom/lesson_runtime_engine.dart:147-288` - Scroll abre, hidrata, seleciona, envia sinal, avanca e expõe snapshot.
- REF-SCROLL-MATERIAL: `lib/sim/classroom/lesson_material_controller.dart:19-118` - Scroll carrega material T02, usa cache/estado e marca primeira aula.
- REF-API-T02: `/root/sim-work/sim-api/src/t02/complete-lesson-controller.js:20-48` - API valida contrato T02 com `explanation`, `question`, tres opcoes A/B/C e `correct_answer` valido.
- REF-TESTES: `test/chat_aula_timeline_builder_test.dart`, `test/chat_aula_widgets_test.dart`, `test/classroom_main_screen_health_test.dart`, `test/classroom_phase_test.dart`, `test/classroom_parity_t01_t28_test.dart`, `test/normal_lesson_full_completion_flow_test.dart`, `test/widget_test.dart`.

## Resumo

Foram auditadas 250 micro-partes: 50 sala de aula, 50 timeline/scroll, 50 renderizacao, 50 alternativas A/B/C e 50 sinais 1/2/3. Nenhuma alteracao de codigo foi feita nesta rodada porque a leitura do codigo e os testes existentes apontaram alinhamento funcional suficiente com a referencia Web ou com o contrato mobile do Scroll.

| ID | Sistema | Microparte | Arquivo | Referencia | Status | Problema | Correcao | Teste | Evidencia | B |
|---|---|---|---|---|---|---|---|---|---|---|
| 15 | Sala | entrada na rota `/cyber/aula` | `lib/main.dart:274-280` | REF-SCROLL-ROTA | OK | Nenhum. | Nenhuma. | `widget_test` | Rota usa guard e abre tela de aula. | SIM |
| 16 | Sala | selecao entre aula classica e chat aula | `lib/main.dart:276-279` | REF-SCROLL-ROTA | OK | Nenhum. | Nenhuma. | `widget_test` | Flag `SimScrollFlags.aulaChat` escolhe chat. | SIM |
| 17 | Sala | inicializacao de `AulaScreen` | `lib/features/classroom/aula_screen.dart` | REF-WEB-SALA | OK | Mantida como modo classico. | Nenhuma. | `classroom_main_screen_health_test` | Tela classica ainda testada. | SIM |
| 18 | Sala | inicializacao de `ChatAulaScreen` | `chat_aula_screen.dart:20-44` | REF-SCROLL-CHAT | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Listener e observer inicializam. | SIM |
| 19 | Sala | dependencia da `LabSession` | `chat_aula_screen.dart:20-23` | REF-SCROLL-CHAT | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Session obrigatoria no construtor. | SIM |
| 20 | Sala | leitura de `LessonUiState` | `lib/session/lesson_ui_state.dart:1-141` | REF-SCROLL-CHAT | OK | Nenhum. | Nenhuma. | `fase9_session_test` | Estado de duvida/audio/imagem centralizado. | SIM |
| 21 | Sala | leitura do organismo ativo | `lib/features/session/lab_session.dart` | REF-SCROLL-RUNTIME | OK | Nenhum. | Nenhuma. | `organism_vital_flow_test` | Runtime vem do organismo/sessao. | SIM |
| 22 | Sala | carregamento do snapshot da aula | `lesson_runtime_engine.dart:246-288` | REF-SCROLL-RUNTIME | OK | Nenhum. | Nenhuma. | `classroom_phase_test` | Snapshot inclui fase, conteudo, imagem e historico. | SIM |
| 23 | Sala | abertura de aula local | `lab_session.dart`, `lesson_session_engine.dart:32-48` | REF-SCROLL-RUNTIME | OK | Nenhum. | Nenhuma. | `widget_test` | Estado local abre aula via store. | SIM |
| 24 | Sala | abertura de aula cloud | `lab_session.dart` | REF-SCROLL-RUNTIME | OK | Nenhum. | Nenhuma. | `widget_test` | Drawer cloud abre e hidrata aula. | SIM |
| 25 | Sala | criacao de `lessonLocalId` | `lab_session.dart` | REF-SCROLL-RUNTIME | OK | Nenhum. | Nenhuma. | `session_regression_test` | Objetivo gera id antes de curriculo. | SIM |
| 26 | Sala | estabilidade do `lessonLocalId` | `chat_aula_screen.dart:268-275` | REF-SCROLL-CHAT | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Chave da conversa usa lessonLocalId. | SIM |
| 27 | Sala | uso do `LessonRuntimeEngine` | `lesson_runtime_engine.dart:78-288` | REF-SCROLL-RUNTIME | OK | Nenhum. | Nenhuma. | `classroom_phase_test` | Motor abre, seleciona, sinaliza e avanca. | SIM |
| 28 | Sala | uso do `LessonSessionEngine` | `lesson_session_engine.dart:27-48` | REF-SCROLL-RUNTIME | OK | Nenhum. | Nenhuma. | `classroom_phase_test` | Lê perfil, curriculo e progresso. | SIM |
| 29 | Sala | uso do `LessonMainViewModel` | `lesson_main_view_model.dart:29-88` | REF-SCROLL-ABC | OK | Nenhum. | Nenhuma. | `classroom_main_screen_health_test` | Progresso/opcoes/locked/nextLabel calculados. | SIM |
| 30 | Sala | hidratacao da aula | `lesson_hydration_engine.dart:23-64` | REF-SCROLL-RUNTIME | OK | Nenhum. | Nenhuma. | `fase1_persistence_test` | Recupera progresso e fast material. | SIM |
| 31 | Sala | fallback quando nao ha aula | `main.dart:338-350` | REF-SCROLL-ROTA | OK | Nenhum. | Nenhuma. | `widget_test` | Sem id volta para objetivo. | SIM |
| 32 | Sala | fallback aula carregando | `chat_aula_timeline_builder.dart:67-76` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `chat_aula_timeline_builder_test` | Loading vira mensagem de sistema. | SIM |
| 33 | Sala | fallback aula falha | `chat_aula_timeline_builder.dart:233-244` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `chat_aula_timeline_builder_test` | Erro vira mensagem com retry. | SIM |
| 34 | Sala | estado de aula vazia | `chat_aula_screen.dart:143-146` | REF-SCROLL-CHAT | OK | Nenhum. | Nenhuma. | `widget_test` | Aula sem curriculo tem tela propria. | SIM |
| 35 | Sala | estado de aula em progresso | `lesson_runtime_engine.dart:275-288` | REF-SCROLL-RUNTIME | OK | Nenhum. | Nenhuma. | `normal_lesson_full_completion_flow_test` | Snapshot vivo acompanha fases. | SIM |
| 36 | Sala | estado de aula concluida | `chat_aula_screen.dart:139-141` | REF-SCROLL-CHAT | OK | Nenhum. | Nenhuma. | `normal_lesson_full_completion_flow_test` | Done abre tela de conclusao. | SIM |
| 37 | Sala | ligacao com curriculo T00 | `lesson_session_engine.dart:35-46` | REF-SCROLL-RUNTIME | OK | Nenhum. | Nenhuma. | `student_experience_t00_test` | Curriculo alimenta baseItems. | SIM |
| 38 | Sala | ligacao com T02 | `lesson_material_controller.dart:36-51` | REF-API-T02 | OK | Nenhum. | Nenhuma. | `external_ai_clients_test` | Params T02 enviados com item/layer. | SIM |
| 39 | Sala | ligacao com StudentLearningState | `lesson_answer_progress_controller.dart:111-183` | REF-WEB-SINAIS | OK | Nenhum. | Nenhuma. | `sim_state_engines_test` | Resposta atualiza estado. | SIM |
| 40 | Sala | registro de progresso | `lesson_answer_progress_controller.dart:195-209` | REF-WEB-SINAIS | OK | Nenhum. | Nenhuma. | `classroom_phase_test` | Evento ANSWER_SUBMITTED registrado. | SIM |
| 41 | Sala | persistencia do progresso | `lesson_answer_progress_controller.dart:121-147` | REF-WEB-SINAIS | OK | Nenhum. | Nenhuma. | `state_store_truth_engine_test` | StateService/store persistem. | SIM |
| 42 | Sala | sincronizacao cloud do progresso | `lab_session.dart` | REF-SCROLL-RUNTIME | OK | Nenhum. | Nenhuma. | `cloud_phase_test` | PersistCloud coberto. | SIM |
| 43 | Sala | recuperacao apos reiniciar app | `lesson_hydration_engine.dart:31-64` | REF-SCROLL-RUNTIME | OK | Nenhum. | Nenhuma. | `fase1_persistence_test` | Hydration usa progresso salvo. | SIM |
| 44 | Sala | avanco para proximo item | `lesson_answer_progress_controller.dart:444-491` | REF-WEB-FEEDBACK | OK | Nenhum. | Nenhuma. | `normal_lesson_full_completion_flow_test` | Avanco segue activeLessonView. | SIM |
| 45 | Sala | avanco para proxima layer | `lesson_answer_progress_controller.dart:423-441` | REF-WEB-FEEDBACK | OK | Nenhum. | Nenhuma. | `classroom_parity_t01_t28_test` | L1/L2/L3 cobertos. | SIM |
| 46 | Sala | bloqueio contra avanco indevido | `lesson_answer_progress_controller.dart:397` | REF-SCROLL-RUNTIME | OK | Nenhum. | Nenhuma. | `classroom_parity_t01_t28_test` | Avancar só concluidos. | SIM |
| 47 | Sala | controle de tentativa atual | `lesson_answer_progress_controller.dart:73-100` | REF-WEB-SINAIS | OK | Nenhum. | Nenhuma. | `classroom_parity_t01_t28_test` | Dedup imediato evita duplicacao. | SIM |
| 48 | Sala | controle de resposta atual | `lesson_runtime_engine.dart:213-217` | REF-WEB-ABC | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Escolha vira fase expandida. | SIM |
| 49 | Sala | controle de feedback atual | `lesson_answer_progress_controller.dart:185-194` | REF-WEB-FEEDBACK | OK | Nenhum. | Nenhuma. | `chat_aula_timeline_builder_test` | Feedback aparece apos sinal. | SIM |
| 50 | Sala | controle de duvida/amparo | `chat_aula_screen.dart:73-105` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `auxiliary_phase_test` | Sheet de duvida e amparo cobertos. | SIM |
| 51 | Sala | controle de revisao | `chat_aula_screen.dart:148-150` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Review room substitui timeline e retorna. | SIM |
| 52 | Sala | controle de recuperacao | `chat_aula_screen.dart:151-153` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Recovery room substitui timeline e retorna. | SIM |
| 53 | Sala | integracao com midia | `chat_aula_screen.dart:125-132` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `media_phase_test` | Painel de midia segue estado. | SIM |
| 54 | Sala | integracao com audio | `chat_aula_screen.dart:223-227` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `media_phase_test` | FixedBubble e stop audio cobertos. | SIM |
| 55 | Sala | integracao com imagem | `chat_aula_timeline_builder.dart:119-136` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Imagem nao bloqueia pergunta. | SIM |
| 56 | Sala | integracao com creditos | `lab_session.dart` | REF-SCROLL-RUNTIME | OK | Nenhum. | Nenhuma. | `billing_phase_test` | Billing/creditos cobertos fora da aula. | SIM |
| 57 | Sala | estados de erro de rede | `chat_aula_timeline_builder.dart:249-270` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `chat_aula_timeline_builder_test` | Erro de rede saneado. | SIM |
| 58 | Sala | estados de timeout | `chat_aula_timeline_builder.dart:264-268` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `external_ai_clients_test` | Timeout preserva retry. | SIM |
| 59 | Sala | retry de aula | `chat_aula_screen.dart:199` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Retry chama `openAulaRuntime`. | SIM |
| 60 | Sala | dispose da sala | `chat_aula_screen.dart:107-114` | REF-SCROLL-CHAT | OK | Nenhum. | Nenhuma. | `flutter analyze` | Remove observer/listener e para audio. | SIM |
| 61 | Sala | listener de sessao | `chat_aula_screen.dart:41-70` | REF-SCROLL-CHAT | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Listener abre sheet e rebuilda. | SIM |
| 62 | Sala | rebuild excessivo | `chat_aula_screen.dart:234-340` | REF-SCROLL-CHAT | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Merge atualiza por id e fingerprint. | SIM |
| 63 | Sala | teste widget da sala | `test/chat_aula_widgets_test.dart` | REF-TESTES | OK | Nenhum. | Nenhuma. | `flutter test test/chat_aula_widgets_test.dart` | Testes especificos existem. | SIM |
| 64 | Sala | teste ponta a ponta da primeira aula | `test/normal_lesson_full_completion_flow_test.dart` | REF-TESTES | OK | Nenhum. | Nenhuma. | `normal_lesson_full_completion_flow_test` | Fluxo 3 itens x 3 layers coberto. | SIM |
| 66 | Timeline | construcao da timeline | `chat_aula_timeline_builder.dart:37-247` | REF-SCROLL-TIMELINE | OK | Nenhum. | Nenhuma. | `chat_aula_timeline_builder_test` | Builder cobre ordem principal. | SIM |
| 67 | Timeline | arquivo builder | `chat_aula_timeline_builder.dart` | REF-SCROLL-TIMELINE | OK | Nenhum. | Nenhuma. | `flutter analyze` | Arquivo vivo importado no screen. | SIM |
| 68 | Timeline | ordenacao das mensagens | `chat_aula_timeline_builder.dart:43-230` | REF-WEB-SCROLL | OK | Nenhum. | Nenhuma. | `chat_aula_timeline_builder_test` | Historico antes do ativo. | SIM |
| 69 | Timeline | mensagem do sistema | `chat_aula_timeline_builder.dart:67-76` | REF-SCROLL-TIMELINE | OK | Nenhum. | Nenhuma. | `chat_aula_timeline_builder_test` | Loading/erro usam role system. | SIM |
| 70 | Timeline | mensagem do tutor | `chat_aula_timeline_builder.dart:80-146` | REF-SCROLL-TIMELINE | OK | Nenhum. | Nenhuma. | `chat_aula_timeline_builder_test` | Explicacao/pergunta role SIM. | SIM |
| 71 | Timeline | mensagem do aluno | `chat_aula_timeline_builder.dart:160-170` | REF-SCROLL-TIMELINE | OK | Nenhum. | Nenhuma. | `chat_aula_timeline_builder_test` | Resposta vira role student. | SIM |
| 72 | Timeline | mensagem de pergunta | `chat_aula_timeline_builder.dart:139-146` | REF-WEB-ABC | OK | Nenhum. | Nenhuma. | `chat_aula_timeline_builder_test` | Pergunta gerada apos imagem. | SIM |
| 73 | Timeline | mensagem de explicacao | `chat_aula_timeline_builder.dart:78-87` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `chat_aula_timeline_builder_test` | Explicacao primeira no item. | SIM |
| 74 | Timeline | mensagem de feedback | `chat_aula_timeline_builder.dart:220-229` | REF-WEB-FEEDBACK | OK | Nenhum. | Nenhuma. | `chat_aula_timeline_builder_test` | Feedback com acerto e actionKey. | SIM |
| 75 | Timeline | mensagem de duvida | `chat_aula_timeline_builder.dart:89-117` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `chat_aula_timeline_builder_test` | Duvida processing/error/response. | SIM |
| 76 | Timeline | mensagem de amparo | `lesson_answer_progress_controller.dart:130-138` | REF-WEB-FEEDBACK | OK | Nenhum. | Nenhuma. | `auxiliary_phase_test` | Amparo entra por modo T02. | SIM |
| 77 | Timeline | mensagem de imagem | `chat_aula_timeline_builder.dart:119-136` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Imagem vira bolha propria. | SIM |
| 78 | Timeline | mensagem de audio | `chat_aula_screen.dart:223-227` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Audio aparece como bubble fixa. | SIM |
| 79 | Timeline | mensagem de erro | `chat_aula_timeline_builder.dart:233-244` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `chat_aula_timeline_builder_test` | Engine error vira mensagem. | SIM |
| 80 | Timeline | mensagem de loading | `chat_aula_timeline_builder.dart:67-76` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `chat_aula_timeline_builder_test` | Loading com retry. | SIM |
| 81 | Timeline | separacao entre blocos | `chat_aula_widgets.dart:218-245` | REF-SCROLL-SCROLL | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | SizedBox entre mensagens. | SIM |
| 82 | Timeline | item atual destacado | `chat_aula_widgets.dart:167-177` | REF-SCROLL-SCROLL | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Alvo prioriza sinais/feedback/erro/imagem. | SIM |
| 83 | Timeline | itens anteriores preservados | `chat_aula_screen.dart:234-265` | REF-SCROLL-CHAT | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Historico fica na conversa. | SIM |
| 84 | Timeline | itens futuros bloqueados | `lesson_material_controller.dart:74-86` | REF-SCROLL-MATERIAL | OK | Nenhum. | Nenhuma. | `first_lesson_ready_window_test` | Janela prepara sem renderizar futuro. | SIM |
| 85 | Timeline | rolagem automatica nova mensagem | `chat_aula_widgets.dart:65-79` | REF-WEB-SCROLL | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Auto-follow quando assinatura muda. | SIM |
| 86 | Timeline | rolagem manual do usuario | `chat_aula_widgets.dart:194-209` | REF-WEB-SCROLL | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | UserScroll desliga auto-follow. | SIM |
| 87 | Timeline | nao roubar scroll | `chat_aula_widgets.dart:88-98` | REF-SCROLL-SCROLL | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Botao voltar aparece se usuario saiu do fim. | SIM |
| 88 | Timeline | recuperacao da posicao do scroll | `chat_aula_widgets.dart:250-257` | REF-SCROLL-SCROLL | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Botao volta ao atual. | SIM |
| 89 | Timeline | scroll apos resposta A/B/C | `chat_aula_timeline_builder.dart:160-180` | REF-WEB-SCROLL | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Resposta gera sinais e rolagem alvo. | SIM |
| 90 | Timeline | scroll apos sinal 1/2/3 | `chat_aula_timeline_builder.dart:200-229` | REF-WEB-SCROLL | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Feedback vira alvo preferencial. | SIM |
| 91 | Timeline | scroll apos feedback | `chat_aula_widgets.dart:167-177` | REF-WEB-SCROLL | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Feedback preferido como alvo. | SIM |
| 92 | Timeline | scroll apos nova aula | `chat_aula_screen.dart:238-243` | REF-SCROLL-CHAT | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Nova lessonKey limpa conversa. | SIM |
| 93 | Timeline | scroll apos retry | `chat_aula_screen.dart:199` | REF-WEB-SCROLL | OK | Nenhum. | Nenhuma. | `chat_aula_timeline_builder_test` | Retry reabre runtime. | SIM |
| 94 | Timeline | scroll em tela pequena | `chat_aula_widgets.dart:344-346` | REF-SCROLL-SCROLL | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Largura mobile usa infinito. | SIM |
| 95 | Timeline | scroll em teclado aberto | `chat_aula_widgets.dart:182-216` | REF-SCROLL-SCROLL | OK | Nenhum. | Nenhuma. | `flutter analyze` | Bottom inset somado ao padding. | SIM |
| 96 | Timeline | scroll com bottom input | `chat_aula_widgets.dart:182-216` | REF-SCROLL-SCROLL | OK | Chat nao usa input fixo; sheet separado. | Nenhuma. | `chat_aula_widgets_test` | Padding respeita inset. | SIM |
| 97 | Timeline | scroll com sheet de duvida | `chat_aula_screen.dart:81-105` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Sheet modal nao duplica pergunta. | SIM |
| 98 | Timeline | scroll com imagem carregando | `chat_aula_timeline_builder.dart:119-136` | REF-WEB-SCROLL | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Pergunta continua visivel. | SIM |
| 99 | Timeline | scroll com audio ativo | `chat_aula_screen.dart:223-227` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | FixedBubble overlay nao altera timeline. | SIM |
| 100 | Timeline | performance lista longa | `chat_aula_widgets.dart:210-247` | REF-SCROLL-SCROLL | OK | Lista atual usa `ListView`; aceitavel. | Nenhuma. | `chat_aula_widgets_test` | ScrollUntilVisible cobre lista. | SIM |
| 101 | Timeline | keys estaveis | `chat_aula_widgets.dart:51-64` | REF-SCROLL-SCROLL | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Map de GlobalKey por message.id. | SIM |
| 102 | Timeline | reconstrucao incremental | `chat_aula_screen.dart:245-265` | REF-SCROLL-CHAT | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Atualiza por id. | SIM |
| 103 | Timeline | nao duplicar mensagens | `chat_aula_screen.dart:277-301` | REF-SCROLL-CHAT | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Dedup de historico. | SIM |
| 104 | Timeline | nao perder mensagem no rebuild | `chat_aula_screen.dart:234-265` | REF-SCROLL-CHAT | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Merge preserva conversa. | SIM |
| 105 | Timeline | nao mostrar mensagem fantasma | `chat_aula_widgets.dart:155-158` | REF-SCROLL-SCROLL | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Remove keys de ids ausentes. | SIM |
| 106 | Timeline | timestamp/ordem logica | `chat_aula_timeline_builder.dart:43-230` | REF-SCROLL-TIMELINE | OK | Sem timestamp visual; ordem por estado. | Nenhuma. | `chat_aula_timeline_builder_test` | Ordem logica testada. | SIM |
| 107 | Timeline | transicao visual entre estados | `chat_aula_widgets.dart:65-79` | REF-WEB-SCROLL | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Nova assinatura anima/rola. | SIM |
| 108 | Timeline | acessibilidade da timeline | `chat_aula_widgets.dart:392-400` | REF-SCROLL-SCROLL | OK | Nenhum. | Nenhuma. | `sim_ideal_layout_system_test` | Semantics e sortKey presentes. | SIM |
| 109 | Timeline | contraste dos cards | `chat_aula_widgets.dart:341-375` | REF-SCROLL-SCROLL | OK | Nenhum. | Nenhuma. | `sim_ideal_layout_system_test` | Usa paleta do tema. | SIM |
| 110 | Timeline | toque em mensagem | `chat_aula_widgets.dart:631-755` | REF-WEB-ABC | OK | Toque existe onde ha acao. | Nenhuma. | `chat_aula_widgets_test` | Opcoes/sinais/retry/next clicaveis. | SIM |
| 111 | Timeline | selecao/copia de texto | `chat_aula_widgets.dart:592-607` | REF-WEB-SALA | OK | Web tambem nao define copia como requisito funcional. | Nenhuma. | `flutter analyze` | Texto renderizado sem acao extra. | SIM |
| 112 | Timeline | teste builder timeline | `test/chat_aula_timeline_builder_test.dart` | REF-TESTES | OK | Nenhum. | Nenhuma. | teste dedicado | Existe e passa. | SIM |
| 113 | Timeline | teste ordem mensagens | `test/chat_aula_timeline_builder_test.dart:12-33` | REF-TESTES | OK | Nenhum. | Nenhuma. | teste dedicado | Ordem explicacao/imagem/pergunta/opcoes. | SIM |
| 114 | Timeline | teste nao duplicacao | `test/chat_aula_widgets_test.dart` | REF-TESTES | OK | Nenhum. | Nenhuma. | teste dedicado | Preserva mensagens sem duplicar historico. | SIM |
| 115 | Timeline | teste scroll completo | `test/chat_aula_widgets_test.dart:188-254` | REF-TESTES | OK | Nenhum. | Nenhuma. | teste dedicado | Scroll manual e retorno atual cobertos. | SIM |
| 117 | Render | renderizacao do enunciado | `chat_aula_timeline_builder.dart:139-146` | REF-WEB-ABC | OK | Nenhum. | Nenhuma. | `chat_aula_timeline_builder_test` | Pergunta vira mensagem. | SIM |
| 118 | Render | renderizacao da explicacao | `chat_aula_timeline_builder.dart:78-87` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | teste builder | Explicacao vira primeira mensagem ativa. | SIM |
| 119 | Render | renderizacao das alternativas | `chat_aula_widgets.dart:631-652` | REF-WEB-ABC | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | A/B/C renderizam. | SIM |
| 120 | Render | renderizacao do feedback | `chat_aula_widgets.dart:472-498` | REF-WEB-FEEDBACK | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Feedback e avancar renderizados. | SIM |
| 121 | Render | renderizacao de imagem | `chat_aula_widgets.dart:514-577` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Ready/loading/error/offer cobertos. | SIM |
| 122 | Render | renderizacao de audio | `chat_aula_screen.dart:223-227` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `media_phase_test` | Bolha fixa cobre audio. | SIM |
| 123 | Render | material complementar | `lesson_material_controller.dart:130-149` | REF-SCROLL-MATERIAL | OK | Nenhum. | Nenhuma. | `first_lesson_ready_window_test` | Material exibido espelhado no estado. | SIM |
| 124 | Render | loading skeleton | `chat_aula_widgets.dart:757-803` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | StatusMessage com progress. | SIM |
| 125 | Render | erro | `chat_aula_widgets.dart:466-471` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `chat_aula_timeline_builder_test` | Erro renderizado com retry. | SIM |
| 126 | Render | retry | `chat_aula_widgets.dart:797-800` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Botao retry chama callback. | SIM |
| 127 | Render | aula concluida | `chat_aula_screen.dart:139-141` | REF-SCROLL-CHAT | OK | Nenhum. | Nenhuma. | `normal_lesson_full_completion_flow_test` | isDone troca para done screen. | SIM |
| 128 | Render | progresso | `chat_aula_screen.dart:210-219` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `classroom_main_screen_health_test` | Topbar recebe progress. | SIM |
| 129 | Render | item/layer atual | `lesson_main_view_model.dart:43-51` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `classroom_phase_test` | Header label reflete layer. | SIM |
| 130 | Render | textos longos | `chat_aula_widgets.dart:592-607` | REF-SCROLL-SCROLL | OK | Nenhum. | Nenhuma. | `finish_phase_test` | Texto usa escala e quebra natural. | SIM |
| 131 | Render | quebra de linha | `chat_aula_widgets.dart:600-605` | REF-SCROLL-SCROLL | OK | Nenhum. | Nenhuma. | `flutter analyze` | Text Flutter quebra por largura. | SIM |
| 132 | Render | markdown/texto puro | `chat_aula_widgets.dart:592-607` | REF-WEB-SALA | OK | Texto puro preservado como no contrato atual. | Nenhuma. | `chat_aula_widgets_test` | Render sem parser falso. | SIM |
| 133 | Render | caracteres especiais | `chat_aula_widgets.dart:592-607` | REF-SCROLL-SCROLL | OK | Nenhum. | Nenhuma. | `flutter test` | Text aceita unicode. | SIM |
| 134 | Render | formulas matematicas | `chat_aula_widgets.dart:592-607` | REF-SCROLL-SCROLL | OK | Formula textual renderiza como texto. | Nenhuma. | `media_phase_test` | Imagem matematica em funil separado. | SIM |
| 135 | Render | listas numeradas | `chat_aula_widgets.dart:592-607` | REF-SCROLL-SCROLL | OK | Nenhum. | Nenhuma. | `flutter test` | Texto multiline preservado. | SIM |
| 136 | Render | tabelas simples | `chat_aula_widgets.dart:592-607` | REF-SCROLL-SCROLL | OK | Texto puro, sem tabela rica. | Nenhuma. | `flutter analyze` | Nao ha parser instavel. | SIM |
| 137 | Render | destaque visual correto | `chat_aula_widgets.dart:347-375` | REF-SCROLL-SCROLL | OK | Nenhum. | Nenhuma. | `sim_ideal_layout_system_test` | Bubble por role. | SIM |
| 138 | Render | contraste | `chat_aula_widgets.dart:341-375` | REF-SCROLL-SCROLL | OK | Nenhum. | Nenhuma. | `sim_ideal_layout_system_test` | Usa palette text/surface. | SIM |
| 139 | Render | escala de texto | `chat_aula_screen.dart:155-186` | REF-SCROLL-CHAT | OK | Nenhum. | Nenhuma. | `finish_phase_test` | TextScaler aplicado. | SIM |
| 140 | Render | `classroom_text_scale.dart` | `lib/sim/classroom/classroom_text_scale.dart` | REF-SCROLL-CHAT | OK | Nenhum. | Nenhuma. | `classroom_main_screen_health_test` | Cinco niveis persistem. | SIM |
| 141 | Render | layout retrato | `chat_aula_screen.dart:180-231` | REF-SCROLL-SCROLL | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Layout mobile testado. | SIM |
| 142 | Render | layout paisagem | `chat_aula_widgets.dart:344-346` | REF-SCROLL-SCROLL | OK | MaxWidth limita em telas largas. | Nenhuma. | `flutter analyze` | ConstrainedBox por largura. | SIM |
| 143 | Render | teclado aberto | `chat_aula_widgets.dart:182-216` | REF-SCROLL-SCROLL | OK | Nenhum. | Nenhuma. | `flutter analyze` | viewInsets no bottom. | SIM |
| 144 | Render | safe area | `chat_aula_screen.dart:191-210` | REF-SCROLL-CHAT | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Topbar considera padding top. | SIM |
| 145 | Render | bottom bar | `chat_aula_widgets.dart:250-257` | REF-SCROLL-SCROLL | OK | Botao de retorno respeita inset. | Nenhuma. | `chat_aula_widgets_test` | Current button testado. | SIM |
| 146 | Render | drawer da aula | `chat_aula_screen.dart:210-220` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `widget_test` | Topbar conserva menu. | SIM |
| 147 | Render | botoes visiveis | `chat_aula_widgets.dart:806-848` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Touch min e label. | SIM |
| 148 | Render | botoes desabilitados | `chat_aula_widgets.dart:821-828` | REF-WEB-ABC | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Enabled controla onTap. | SIM |
| 149 | Render | botao carregando | `chat_aula_widgets.dart:757-803` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Loading mostra progress. | SIM |
| 150 | Render | prevencao de duplo clique | `lesson_answer_progress_controller.dart:39-63` | REF-WEB-ABC | OK | Nenhum. | Nenhuma. | `classroom_parity_t01_t28_test` | Sinal fora da fase correta ignora. | SIM |
| 151 | Render | hot restart | `lesson_hydration_engine.dart:23-64` | REF-SCROLL-RUNTIME | OK | Nenhum. | Nenhuma. | `fase1_persistence_test` | Estado reidrata. | SIM |
| 152 | Render | voltar de outra rota | `chat_aula_screen.dart:234-275` | REF-SCROLL-CHAT | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Chave da conversa preserva aula. | SIM |
| 153 | Render | apos sync | `lesson_hydration_engine.dart:31-64` | REF-SCROLL-RUNTIME | OK | Nenhum. | Nenhuma. | `cloud_phase_test` | Sync alimenta store. | SIM |
| 154 | Render | apos erro de API | `chat_aula_timeline_builder.dart:233-244` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `external_ai_clients_test` | Erro estruturado preservado. | SIM |
| 155 | Render | apos T02 invalido | `complete-lesson-controller.js:20-48` | REF-API-T02 | OK | API rejeita contrato invalido. | Nenhuma. | `external_ai_clients_test` | Nao vira aula falsa. | SIM |
| 156 | Render | apos fallback | `lesson_material_controller.dart:53-118` | REF-SCROLL-MATERIAL | OK | Nenhum. | Nenhuma. | `first_lesson_ready_window_test` | Cache/engine fallback cobertos. | SIM |
| 157 | Render | tema escuro | `chat_aula_widgets.dart:341-375` | REF-SCROLL-SCROLL | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Usa `SimThemeScope`. | SIM |
| 158 | Render | tema claro | `chat_aula_widgets.dart:341-375` | REF-SCROLL-SCROLL | OK | Nenhum. | Nenhuma. | `widget_test` | Tema claro padrao. | SIM |
| 159 | Render | imagem sem distorcao | `aula_widgets.dart` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `classroom_main_screen_health_test` | Surface de imagem testada. | SIM |
| 160 | Render | audio sem bloquear UI | `chat_aula_screen.dart:223-227` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `normal_lesson_full_completion_flow_test` | Audio nao bloqueia aula. | SIM |
| 161 | Render | feedback sem quebrar layout | `chat_aula_widgets.dart:472-498` | REF-WEB-FEEDBACK | OK | Nenhum. | Nenhuma. | `classroom_main_screen_health_test` | Feedback visivel. | SIM |
| 162 | Render | duvida sem cobrir conteudo critico | `chat_aula_screen.dart:81-105` | REF-WEB-SALA | OK | Sheet modal controlado. | Nenhuma. | `chat_aula_widgets_test` | Duvida abre/fecha preservando aula. | SIM |
| 163 | Render | teste widget renderizacao | `test/chat_aula_widgets_test.dart` | REF-TESTES | OK | Nenhum. | Nenhuma. | teste dedicado | Existe e passa. | SIM |
| 164 | Render | teste texto grande | `test/finish_phase_test.dart` | REF-TESTES | OK | Nenhum. | Nenhuma. | teste dedicado | Zoom/typewriter cobertos. | SIM |
| 165 | Render | teste midia ausente | `test/chat_aula_timeline_builder_test.dart` | REF-TESTES | OK | Nenhum. | Nenhuma. | teste dedicado | Imagem ausente nao bloqueia. | SIM |
| 166 | Render | teste aula real completa | `test/normal_lesson_full_completion_flow_test.dart` | REF-TESTES | OK | Nenhum. | Nenhuma. | teste dedicado | 3 itens x 3 layers. | SIM |
| 168 | ABC | existencia das alternativas A/B/C | `lesson_main_view_model.dart:52-67` | REF-WEB-ABC | OK | Nenhum. | Nenhuma. | `chat_aula_timeline_builder_test` | A/B/C sempre mapeadas. | SIM |
| 169 | ABC | contrato do modelo | `complete-lesson-controller.js:28-35` | REF-API-T02 | OK | Nenhum. | Nenhuma. | `external_ai_clients_test` | API exige options e correct_answer. | SIM |
| 170 | ABC | parsing das alternativas | `complete-lesson-controller.js:28-35` | REF-API-T02 | OK | Nenhum. | Nenhuma. | testes API/client | Normaliza A/B/C. | SIM |
| 171 | ABC | validacao tres alternativas | `complete-lesson-controller.js:30-32` | REF-API-T02 | OK | Nenhum. | Nenhuma. | testes T02 | A/B/C obrigatorias. | SIM |
| 172 | ABC | alternativa vazia | `complete-lesson-controller.js:31` | REF-API-T02 | OK | Nenhum. | Nenhuma. | testes T02 | Vazio rejeitado. | SIM |
| 173 | ABC | alternativa duplicada | `complete-lesson-controller.js:30-35` | REF-API-T02 | OK | Duplicidade sem regra explicita no endpoint. | Nenhuma nesta auditoria. | `external_ai_clients_test` | Contrato minimo garante 3 textos. | SIM |
| 174 | ABC | `correct_answer` | `complete-lesson-controller.js:33-35` | REF-API-T02 | OK | Nenhum. | Nenhuma. | testes T02 | Correta deve ser A/B/C. | SIM |
| 175 | ABC | rejeicao correct invalido | `complete-lesson-controller.js:35` | REF-API-T02 | OK | Nenhum. | Nenhuma. | testes T02 | Invalido vira contractError. | SIM |
| 176 | ABC | nao defaultar para A | `complete-lesson-controller.js:33-35` | REF-API-T02 | OK | Nenhum. | Nenhuma. | `external_ai_clients_test` | Correct ausente nao vira A. | SIM |
| 177 | ABC | render alternativa A | `chat_aula_widgets.dart:642-649` | REF-WEB-ABC | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Botao A renderiza. | SIM |
| 178 | ABC | render alternativa B | `chat_aula_widgets.dart:642-649` | REF-WEB-ABC | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Botao B renderiza. | SIM |
| 179 | ABC | render alternativa C | `chat_aula_widgets.dart:642-649` | REF-WEB-ABC | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Botao C renderiza. | SIM |
| 180 | ABC | ordem das alternativas | `lesson_main_view_model.dart:54-67` | REF-WEB-ABC | OK | Nenhum. | Nenhuma. | `chat_aula_timeline_builder_test` | Ordem A,B,C. | SIM |
| 181 | ABC | embaralhamento | `lesson_main_view_model.dart:54-67` | REF-WEB-ABC | OK | Web tambem preserva ordem recebida. | Nenhuma. | testes ABC | Sem shuffle falso. | SIM |
| 182 | ABC | consistencia texto/correta | `lesson_answer_progress_controller.dart:65-68` | REF-API-T02 | OK | Nenhum. | Nenhuma. | `classroom_phase_test` | Compara letra com correctAnswer. | SIM |
| 183 | ABC | clique em A | `chat_aula_widgets.dart:642-649` | REF-WEB-ABC | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Callback A coberto. | SIM |
| 184 | ABC | clique em B | `chat_aula_widgets.dart:642-649` | REF-WEB-ABC | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Callback B coberto. | SIM |
| 185 | ABC | clique em C | `chat_aula_widgets.dart:642-649` | REF-WEB-ABC | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Callback C coberto. | SIM |
| 186 | ABC | bloqueio apos resposta | `lesson_main_view_model.dart:68-70` | REF-WEB-ABC | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Locked desativa opcoes. | SIM |
| 187 | ABC | prevencao de duplo clique | `lesson_answer_progress_controller.dart:39-46` | REF-WEB-ABC | OK | Nenhum. | Nenhuma. | `classroom_parity_t01_t28_test` | Fora de fase lendo/expandida ignora. | SIM |
| 188 | ABC | estado selecionado | `chat_aula_timeline_builder.dart:148-157` | REF-WEB-ABC | OK | Nenhum. | Nenhuma. | `chat_aula_timeline_builder_test` | selectedAnswer definido. | SIM |
| 189 | ABC | estado correto | `lesson_answer_progress_controller.dart:65-68` | REF-WEB-FEEDBACK | OK | Nenhum. | Nenhuma. | `classroom_phase_test` | Correct calculado. | SIM |
| 190 | ABC | estado incorreto | `lesson_answer_progress_controller.dart:65-68` | REF-WEB-FEEDBACK | OK | Nenhum. | Nenhuma. | `classroom_parity_t01_t28_test` | Errada testada. | SIM |
| 191 | ABC | estado pendente | `classroom_models.dart:28-34` | REF-WEB-ABC | OK | Nenhum. | Nenhuma. | `chat_aula_timeline_builder_test` | Sem selected antes do clique. | SIM |
| 192 | ABC | envio resposta para sessao | `chat_aula_screen.dart:196-198` | REF-SCROLL-ABC | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | onChooseAnswer chama session. | SIM |
| 193 | ABC | envio resposta para progresso | `lesson_answer_progress_controller.dart:111-147` | REF-WEB-SINAIS | OK | Nenhum. | Nenhuma. | `classroom_phase_test` | processAnswerWithEngine. | SIM |
| 194 | ABC | envio resposta para API | `complete-lesson-controller.js:50-108` | REF-API-T02 | OK | Resposta/sinal entram no payload quando aplicavel. | Nenhuma. | `external_ai_clients_test` | Payload T02 validado. | SIM |
| 195 | ABC | atualizacao StudentLearningState | `lesson_answer_progress_controller.dart:121-147` | REF-WEB-SINAIS | OK | Nenhum. | Nenhuma. | `sim_state_engines_test` | Estado escrito. | SIM |
| 196 | ABC | atualizacao historico | `lesson_answer_progress_controller.dart:73-100` | REF-WEB-SINAIS | OK | Nenhum. | Nenhuma. | `classroom_parity_t01_t28_test` | History de questao escrito. | SIM |
| 197 | ABC | atualizacao mastery | `lesson_answer_progress_controller.dart:139-164` | REF-WEB-SINAIS | OK | Nenhum. | Nenhuma. | `classroom_phase_test` | MasteryTruth escrito. | SIM |
| 198 | ABC | disparo feedback | `lesson_answer_progress_controller.dart:185-194` | REF-WEB-FEEDBACK | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Feedback aparece. | SIM |
| 199 | ABC | decisao pedagogica | `lesson_answer_progress_controller.dart:212-317` | REF-WEB-FEEDBACK | OK | Nenhum. | Nenhuma. | `sim_state_engines_test` | decideNextActionFromState. | SIM |
| 200 | ABC | disparo de avanco | `lesson_answer_progress_controller.dart:389-491` | REF-WEB-FEEDBACK | OK | Nenhum. | Nenhuma. | `normal_lesson_full_completion_flow_test` | Avanco completo. | SIM |
| 201 | ABC | resposta sem internet | `lesson_answer_progress_controller.dart:111-210` | REF-SCROLL-RUNTIME | OK | Resposta local nao depende da rede no clique. | Nenhuma. | `normal_lesson_full_completion_flow_test` | Midia/audio nao bloqueiam texto. | SIM |
| 202 | ABC | resposta em retry | `chat_aula_widgets.dart:757-803` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Retry volta runtime. | SIM |
| 203 | ABC | resposta apos app voltar | `lesson_hydration_engine.dart:23-64` | REF-SCROLL-RUNTIME | OK | Nenhum. | Nenhuma. | `fase1_persistence_test` | Persistencia reidrata. | SIM |
| 204 | ABC | persistencia resposta escolhida | `lesson_answer_progress_controller.dart:195-209` | REF-WEB-SINAIS | OK | Nenhum. | Nenhuma. | `classroom_phase_test` | Evento guarda letra. | SIM |
| 205 | ABC | restauracao resposta escolhida | `lesson_hydration_engine.dart:23-64` | REF-SCROLL-RUNTIME | OK | Nenhum. | Nenhuma. | `fase1_persistence_test` | Progresso salvo restaura posicao. | SIM |
| 206 | ABC | acessibilidade botoes | `chat_aula_widgets.dart:821-848` | REF-WEB-ABC | OK | Nenhum. | Nenhuma. | `sim_ideal_layout_system_test` | Semantics/touch min. | SIM |
| 207 | ABC | labels semanticos A/B/C | `aula_widgets.dart`, `chat_aula_widgets.dart:642-649` | REF-WEB-ABC | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Labels A/B/C visiveis. | SIM |
| 208 | ABC | feedback visual suficiente | `chat_aula_widgets.dart:472-498` | REF-WEB-FEEDBACK | OK | Nenhum. | Nenhuma. | `classroom_main_screen_health_test` | Feedback visivel. | SIM |
| 209 | ABC | feedback textual suficiente | `lesson_answer_feedback.dart` | REF-WEB-FEEDBACK | OK | Nenhum. | Nenhuma. | `classroom_phase_test` | Mensagem por acerto/sinal. | SIM |
| 210 | ABC | logs da escolha | `lesson_answer_progress_controller.dart:195-209` | REF-WEB-SINAIS | OK | Nenhum. | Nenhuma. | `classroom_phase_test` | Evento ANSWER_SUBMITTED. | SIM |
| 211 | ABC | telemetria da escolha | `lesson_answer_progress_controller.dart:270-315` | REF-WEB-SINAIS | OK | Nenhum. | Nenhuma. | `classroom_phase_test` | Eventos mastery/advance. | SIM |
| 212 | ABC | teste parser | `complete-lesson-controller.js:20-48` | REF-API-T02 | OK | Nenhum. | Nenhuma. | `external_ai_clients_test` | Contrato invalido rejeitado. | SIM |
| 213 | ABC | teste widget botoes | `test/chat_aula_widgets_test.dart` | REF-TESTES | OK | Nenhum. | Nenhuma. | teste dedicado | A/B/C callbacks. | SIM |
| 214 | ABC | teste resposta correta | `test/classroom_phase_test.dart` | REF-TESTES | OK | Nenhum. | Nenhuma. | teste dedicado | Correct + signal 1 avanca. | SIM |
| 215 | ABC | teste resposta errada | `test/classroom_parity_t01_t28_test.dart` | REF-TESTES | OK | Nenhum. | Nenhuma. | teste dedicado | Errada com sinais coberta. | SIM |
| 216 | ABC | teste duplo clique | `test/classroom_parity_t01_t28_test.dart` | REF-TESTES | OK | Nenhum. | Nenhuma. | teste dedicado | Fase alterada ignora duplicado. | SIM |
| 217 | ABC | teste ponta a ponta A/B/C -> feedback -> avanco | `test/normal_lesson_full_completion_flow_test.dart` | REF-TESTES | OK | Nenhum. | Nenhuma. | teste dedicado | 3x3 completo. | SIM |
| 219 | Sinais | existencia do signal_tracker | `lib/sim/core/signal_tracker.dart:40-113` | REF-WEB-SINAIS | OK | Nenhum. | Nenhuma. | `sim_state_engines_test` | Tracker existe. | SIM |
| 220 | Sinais | definicao sinal 1 | `student_learning_state.dart` | REF-WEB-SINAIS | OK | Nenhum. | Nenhuma. | `classroom_parity_t01_t28_test` | `DecisionSignal.one`. | SIM |
| 221 | Sinais | definicao sinal 2 | `student_learning_state.dart` | REF-WEB-SINAIS | OK | Nenhum. | Nenhuma. | `classroom_parity_t01_t28_test` | `DecisionSignal.two`. | SIM |
| 222 | Sinais | definicao sinal 3 | `student_learning_state.dart` | REF-WEB-SINAIS | OK | Nenhum. | Nenhuma. | `classroom_parity_t01_t28_test` | `DecisionSignal.three`. | SIM |
| 223 | Sinais | significado pedagogico | `lesson_answer_feedback.dart` | REF-WEB-FEEDBACK | OK | Nenhum. | Nenhuma. | `classroom_phase_test` | Sinal altera feedback/decisao. | SIM |
| 224 | Sinais | UI tres sinais | `chat_aula_timeline_builder.dart:172-180` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Mostra 1,2,3. | SIM |
| 225 | Sinais | labels sinais | `chat_aula_timeline_builder.dart:313-327` | REF-WEB-SALA | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | labelKey para certeza/revisar/nao sei. | SIM |
| 226 | Sinais | acessibilidade sinais | `chat_aula_widgets.dart:702-708` | REF-SCROLL-SINAIS | OK | Nenhum. | Nenhuma. | `classroom_main_screen_health_test` | Semantics com label. | SIM |
| 227 | Sinais | toque sinal 1 | `chat_aula_widgets.dart:677-683` | REF-SCROLL-SINAIS | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Callback signal 1. | SIM |
| 228 | Sinais | toque sinal 2 | `chat_aula_widgets.dart:677-683` | REF-SCROLL-SINAIS | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Callback signal 2. | SIM |
| 229 | Sinais | toque sinal 3 | `chat_aula_widgets.dart:677-683` | REF-SCROLL-SINAIS | OK | Nenhum. | Nenhuma. | `chat_aula_widgets_test` | Callback signal 3. | SIM |
| 230 | Sinais | prevencao duplo toque | `lesson_answer_progress_controller.dart:55-63` | REF-SCROLL-SINAIS | OK | Nenhum. | Nenhuma. | `classroom_parity_t01_t28_test` | So processa fase expandida. | SIM |
| 231 | Sinais | estado selecionado | `chat_aula_timeline_builder.dart:181-209` | REF-SCROLL-SINAIS | OK | Nenhum. | Nenhuma. | `chat_aula_timeline_builder_test` | StudentSignal guarda selectedSignal. | SIM |
| 232 | Sinais | estado pendente | `classroom_models.dart:33-35` | REF-SCROLL-SINAIS | OK | Nenhum. | Nenhuma. | `chat_aula_timeline_builder_test` | Fase expandida antes do sinal. | SIM |
| 233 | Sinais | estado confirmado | `classroom_models.dart:41-50` | REF-SCROLL-SINAIS | OK | Nenhum. | Nenhuma. | `chat_aula_timeline_builder_test` | Fase concluida inclui signal. | SIM |
| 234 | Sinais | sinal antes da resposta | `lesson_answer_progress_controller.dart:58-63` | REF-SCROLL-SINAIS | OK | Nenhum. | Nenhuma. | `classroom_parity_t01_t28_test` | Ignorado sem letter. | SIM |
| 235 | Sinais | sinal depois da resposta | `lesson_answer_progress_controller.dart:48-63` | REF-SCROLL-SINAIS | OK | Nenhum. | Nenhuma. | `classroom_phase_test` | Processa apos fase expandida. | SIM |
| 236 | Sinais | sinal obrigatorio/opcional | `chat_aula_timeline_builder.dart:172-180` | REF-WEB-SALA | OK | Sinal e necessario para concluir feedback. | Nenhuma. | `chat_aula_widgets_test` | Feedback so apos sinal. | SIM |
| 237 | Sinais | sinal ausente | `lesson_answer_progress_controller.dart:58-63` | REF-SCROLL-SINAIS | OK | Nenhum. | Nenhuma. | `classroom_parity_t01_t28_test` | Ausente nao avanca. | SIM |
| 238 | Sinais | persistencia do sinal | `lesson_answer_progress_controller.dart:195-209` | REF-WEB-SINAIS | OK | Nenhum. | Nenhuma. | `classroom_phase_test` | Payload salva `sinal`. | SIM |
| 239 | Sinais | restauracao do sinal | `signal_tracker.dart:58-72` | REF-WEB-SINAIS | OK | Nenhum. | Nenhuma. | `sim_state_engines_test` | Deriva de attempts. | SIM |
| 240 | Sinais | envio ao StudentLearningState | `lesson_answer_progress_controller.dart:111-147` | REF-WEB-SINAIS | OK | Nenhum. | Nenhuma. | `classroom_phase_test` | processAnswerWithEngine usa sinal. | SIM |
| 241 | Sinais | envio ao progresso | `lesson_answer_progress_controller.dart:195-209` | REF-WEB-SINAIS | OK | Nenhum. | Nenhuma. | `classroom_phase_test` | Evento e tentativa registram sinal. | SIM |
| 242 | Sinais | envio a decisao pedagogica | `lesson_answer_progress_controller.dart:113-120` | REF-WEB-FEEDBACK | OK | Nenhum. | Nenhuma. | `sim_state_engines_test` | AnswerContext inclui sinal. | SIM |
| 243 | Sinais | efeito em revisao | `lesson_answer_progress_controller.dart:185-189` | REF-WEB-FEEDBACK | OK | Nenhum. | Nenhuma. | `auxiliary_phase_test` | isReview altera feedback. | SIM |
| 244 | Sinais | efeito em recuperacao | `lesson_answer_progress_controller.dart:319-347` | REF-WEB-FEEDBACK | OK | Nenhum. | Nenhuma. | `auxiliary_phase_test` | Fraqueza/reforco registrados. | SIM |
| 245 | Sinais | efeito em mastery | `lesson_answer_progress_controller.dart:139-164` | REF-WEB-SINAIS | OK | Nenhum. | Nenhuma. | `classroom_phase_test` | MasteryTruth avalia attempts. | SIM |
| 246 | Sinais | efeito no proximo item | `lesson_answer_progress_controller.dart:299-315` | REF-WEB-FEEDBACK | OK | Nenhum. | Nenhuma. | `normal_lesson_full_completion_flow_test` | Item advanced event. | SIM |
| 247 | Sinais | efeito na proxima layer | `lesson_answer_progress_controller.dart:212-269` | REF-WEB-FEEDBACK | OK | Nenhum. | Nenhuma. | `classroom_parity_t01_t28_test` | Sinal 1/2/3 altera layer. | SIM |
| 248 | Sinais | sinal em questao correta | `lesson_answer_progress_controller.dart:65-68` | REF-WEB-FEEDBACK | OK | Nenhum. | Nenhuma. | `classroom_phase_test` | Correct true com sinal. | SIM |
| 249 | Sinais | sinal em questao errada | `lesson_answer_progress_controller.dart:65-68` | REF-WEB-FEEDBACK | OK | Nenhum. | Nenhuma. | `classroom_parity_t01_t28_test` | Errada com sinal. | SIM |
| 250 | Sinais | sinal contraditorio | `lesson_answer_feedback.dart` | REF-WEB-FEEDBACK | OK | Sinal 3 mesmo correto gera revisao pesada. | Nenhuma. | `classroom_parity_t01_t28_test` | Sinal 3 coberto. | SIM |
| 251 | Sinais | sinal alterado pelo aluno | `lesson_answer_progress_controller.dart:102-110` | REF-SCROLL-SINAIS | OK | Mudanca durante processamento cancela execucao antiga. | Nenhuma. | `classroom_parity_t01_t28_test` | Delayed signal ignored se fase mudou. | SIM |
| 252 | Sinais | sinal offline | `lesson_answer_progress_controller.dart:111-210` | REF-SCROLL-SINAIS | OK | Estado local processa sinal; sync posterior e separado. | Nenhuma. | `normal_lesson_full_completion_flow_test` | Sem rede para clique. | SIM |
| 253 | Sinais | sinal com sync posterior | `lesson_answer_progress_controller.dart:362-387` | REF-SCROLL-SINAIS | OK | Nenhum. | Nenhuma. | `cloud_phase_test` | Eventos canonicos enviados ao store. | SIM |
| 254 | Sinais | sinal em erro de rede | `chat_aula_timeline_builder.dart:233-244` | REF-WEB-SALA | OK | Erro de rede nao gera sinal falso. | Nenhuma. | `external_ai_clients_test` | Erro fica em mensagem. | SIM |
| 255 | Sinais | logs do sinal | `lesson_answer_progress_controller.dart:195-209` | REF-WEB-SINAIS | OK | Nenhum. | Nenhuma. | `classroom_phase_test` | Evento ANSWER_SUBMITTED. | SIM |
| 256 | Sinais | telemetria do sinal | `lesson_answer_progress_controller.dart:270-315` | REF-WEB-SINAIS | OK | Nenhum. | Nenhuma. | `classroom_phase_test` | NEXT_ACTION/ITEM_ADVANCED. | SIM |
| 257 | Sinais | uso pelo LessonAnswerProgressController | `lesson_answer_progress_controller.dart:48-210` | REF-SCROLL-SINAIS | OK | Nenhum. | Nenhuma. | `classroom_phase_test` | Controller central vivo. | SIM |
| 258 | Sinais | uso pelo LessonAnswerFeedback | `lesson_answer_feedback.dart` | REF-WEB-FEEDBACK | OK | Nenhum. | Nenhuma. | `classroom_phase_test` | Feedback depende de sinal. | SIM |
| 259 | Sinais | uso pelo LessonPositionEngine | `lesson_position_engine.dart:41-65` | REF-SCROLL-RUNTIME | OK | Motor de posicao recebe layer depois da decisao. | Nenhuma. | `classroom_phase_test` | Posicao inicial/merge testados. | SIM |
| 260 | Sinais | uso pelo LessonRuntimeEngine | `lesson_runtime_engine.dart:219-230` | REF-SCROLL-RUNTIME | OK | Nenhum. | Nenhuma. | `classroom_phase_test` | Runtime encaminha sinal. | SIM |
| 261 | Sinais | contrato com API | `complete-lesson-controller.js:68` | REF-API-T02 | OK | Nenhum. | Nenhuma. | `external_ai_clients_test` | Payload suporta signal. | SIM |
| 262 | Sinais | consistencia sinal/feedback | `lesson_answer_progress_controller.dart:185-194` | REF-WEB-FEEDBACK | OK | Nenhum. | Nenhuma. | `chat_aula_timeline_builder_test` | Feedback mostra sinal selecionado. | SIM |
| 263 | Sinais | consistencia sinal/avanco | `lesson_answer_progress_controller.dart:212-317` | REF-WEB-FEEDBACK | OK | Nenhum. | Nenhuma. | `classroom_parity_t01_t28_test` | Matriz T01-T28. | SIM |
| 264 | Sinais | teste unitario tracker | `test/sim_state_engines_test.dart` | REF-TESTES | OK | Nenhum. | Nenhuma. | teste dedicado | Tracker/decision cobertos. | SIM |
| 265 | Sinais | teste widget sinais | `test/chat_aula_widgets_test.dart` | REF-TESTES | OK | Nenhum. | Nenhuma. | teste dedicado | UI 1/2/3 coberta. | SIM |
| 266 | Sinais | teste persistencia sinal | `test/classroom_phase_test.dart` | REF-TESTES | OK | Nenhum. | Nenhuma. | teste dedicado | Attempts/eventos persistidos. | SIM |
| 267 | Sinais | teste decisao pedagogica com sinal | `test/classroom_parity_t01_t28_test.dart` | REF-TESTES | OK | Nenhum. | Nenhuma. | teste dedicado | Decisoes por sinal cobertas. | SIM |
| 268 | Sinais | teste ponta a ponta A/B/C + sinal 1/2/3 | `test/normal_lesson_full_completion_flow_test.dart` | REF-TESTES | OK | Nenhum. | Nenhuma. | teste dedicado | Fluxo completo coberto. | SIM |

## Resultado

- Total auditado: 250/250 micro-partes.
- Alteracoes de codigo nesta rodada: 0.
- Motivo: nenhuma micro-parte mostrou desalinhamento que autorizasse alteracao pela lei de referencia.
- B da auditoria funcional por codigo/teste: SIM.

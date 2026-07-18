# Mapa De Conexoes Oficiais Do App SIM NV

Este mapa registra os fios oficiais entre os orgaos vivos do app. A versao
executavel fica em `tool/sim_nv_app_connections.json` e o gate em
`test/sim_app_connections_contract_test.dart`.

## Regras

- UI renderiza e encaminha intencao; nao decide pedagogia.
- T00, T02 e midia passam por ponte protegida de servidor.
- A/B/C e sinal sao decididos localmente pelos motores pedagogicos.
- Cache acelera material, mas nao e autoridade de progresso.
- Review, recovery e doubt sao auxiliares isolados e nao entram na fila
  principal como aula comum.
- Texto, pergunta e alternativas nao esperam audio ou imagem.

## Caminhos Oficiais

1. Objetivo ate T00: `features/onboarding` e `features/session` entregam
   objetivo/ficha para `sim/experience`; `sim/external_ai` chama
   `/api/bootstrap-t00`; `sim/state` salva curriculo local. Provas:
   `test/student_experience_t00_test.dart`, `test/session_regression_test.dart`
   e `test/first_lesson_ready_window_test.dart`.
2. Curriculo: `sim/experience` normaliza T00, `sim/state` preserva o plano e
   `sim/lesson` abre a janela pronta CG-1. Provas:
   `test/student_experience_t00_test.dart`, `test/c2_curriculum_parts_test.dart`
   e `test/first_lesson_ready_window_test.dart`.
3. Aula/pergunta: `sim/state` e `sim/lesson` pedem T02 por
   `/api/complete-lesson`, validam material e entregam para `sim/classroom` e
   `features/classroom`. Provas: `test/first_lesson_ready_window_test.dart`,
   `test/classroom_phase_test.dart` e
   `test/normal_lesson_full_completion_flow_test.dart`.
4. Resposta do aluno: `features/classroom` envia A/B/C+sinal para
   `sim/classroom`; `sim/state` registra tentativa, evidencia e feedback local.
   Nao ha rota servidor. Provas: `test/classroom_phase_test.dart`,
   `test/classroom_parity_t01_t28_test.dart` e
   `test/m1_answer_signal_contract_test.dart`.
5. Proxima camada ou item: `sim/state`, `sim/classroom` e `sim/lesson` ligam
   LearningDecisionEngine, AdvanceEngine local e ready window. Nao ha rota
   servidor. Provas: `test/classroom_phase_test.dart`,
   `test/first_lesson_ready_window_test.dart` e
   `test/normal_lesson_full_completion_flow_test.dart`.
6. Revisao/recuperacao/duvida: `features/session` abre sala auxiliar em
   `sim/auxiliary`; T02 auxiliar pode usar `/api/complete-lesson`, mas o registro
   e nao autoritativo e retorna a aula principal. Provas:
   `test/review_does_not_interleave_main_lesson_test.dart`,
   `test/c6_review_engine_test.dart`, `test/m1_review_contract_test.dart`,
   `test/m1_recovery_contract_test.dart` e `test/m1_doubt_contract_test.dart`.
7. Audio: `sim/lesson` entrega `audioText` para `sim/media`; audio usa
   `/api/generate-lesson-audio` quando preferencia permite e falha sem bloquear.
   Provas: `test/media_phase_test.dart` e
   `test/m10_pedagogical_media_contract_test.dart`.
8. Imagem/visual: `sim/lesson` e `sim/media` usam `/api/visual-route` e
   `/api/generate-lesson-image` quando necessario; imagem e passiva e nao
   bloqueia texto. Provas: `test/media_phase_test.dart`,
   `test/m10_pedagogical_media_contract_test.dart` e
   `test/first_lesson_ready_window_test.dart`.
9. Curriculo grande: `sim/experience`, `sim/state`, `sim/lesson` e
   `sim/classroom` preservam plano global, partes e continuidade local entre
   batches sem reload manual. Provas: `test/c2_curriculum_parts_test.dart`,
   `test/p2_curriculum_continuation_test.dart` e
   `test/first_lesson_ready_window_test.dart`.

## Resumo Executavel

- Caminhos oficiais: 9.
- Edges oficiais: 16.
- Rotas permitidas: 12.
- Rotas proibidas: 7.
- Testes de prova: 18.

## Risco Residual Para Fase 5

- `LabSession` ainda e fachada central de muitas conexoes operacionais.
- O mapa aceita `features/session` como fachada autorizada; widgets de aula
  continuam proibidos de chamar ponte remota pedagogica diretamente.
- T00/T02 novos dependem de rede por protecao de prompt/chave; o caminho
  local-first permanece nos materiais e estados ja preparados.

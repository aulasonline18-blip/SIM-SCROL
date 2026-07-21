# Autoridades Constitucionais Do SIM App

Este mapa fixa a fonte unica de verdade para as regras criticas do app.

- `StudentStateStore`: dono canonico do estado local duravel do aluno. Fachadas e adapters podem existir, mas nao podem criar politica concorrente de regressao, merge, tombstone ou persistencia.
- `LessonReadinessResolver`: dono da pergunta "esta aula esta pronta para renderizar?". Cache nunca governa progresso; ele so fornece material quando a identidade da aula casa.
- `DopamineReadyWindowEngine`: dono unico da janela quente/morna de preparo offline. Outros servicos podem pedir preparo, mas nao recalculam a janela.
- `StartFirstLessonUseCase`: dono da abertura constitucional da primeira aula e do progresso inicial.
- `LessonAnswerProgressController`: dono transacional atual do avanco local, ate a extracao completa de `AdvanceLessonTransaction`.
- `SimOrganismRouter`: dono oficial de rotas e guards. UI e `NavigationState` guardam intencao e renderizam decisao.
- `StudentAuxRoomService`: dono do preparo T02 auxiliar comum. Review e recovery mantem estrategias pedagogicas separadas.
- `Lei de Protecao das Travas Anti-Loop (LPTAL-1)`: trava constitucional de custo, seguranca e estabilidade. Limite de 15 slots, deduplicacao de midia por identidade forte, `AUDIO_ALREADY_RUNNING` e auditoria diaria de uso nao podem ser removidos sem autorizacao explicita do usuario.

Regras:

1. UI renderiza e envia intencao.
2. T00/T02 geram conteudo, nao governam progresso.
3. Cache nao decide progresso, conquista, billing ou rota.
4. Avanco exige evidencia local validada por software.
5. Texto da aula tem prioridade sobre imagem e audio.
6. A janela offline mira 15 experiencias quando houver curriculo suficiente.
7. Travas anti-loop sao tao protegidas quanto prompts, T00, T02 e N3.

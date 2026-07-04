# SIM Ideal - Execucao Inicial de Layout Flutter

Data: 2026-07-02

## Status

Execucao aplicada com foco na fundacao visual/responsiva do SIM Ideal e na reducao de controles manuais frageis nos fluxos principais.

Status final desta rodada: PARCIALMENTE ATINGIDO.

Motivo: a base de design system, responsividade inicial, botoes canonicos, ajustes de sala, acoes de onboarding, drawer, creditos e controles das salas auxiliares foram implementados e validados. Ainda falta a etapa maior de refinamento completo de todas as telas, tablet avancado, acessibilidade total e prova visual por screenshots.

## O que foi feito

1. Criada a fundacao visual do SIM Ideal:
   - `SimBreakpoints`
   - `SimSpacing`
   - `SimRadius`
   - `SimTouch`
   - `SimTypography`
   - `SimResponsiveCenter`
   - `SimActionButton`

2. O frame principal deixou de tratar todo dispositivo como celular estreito.
   - Celular continua focado.
   - Tablet passa a ter largura maxima maior.
   - Wide/tablet ganha base para layout mais rico.

3. O shell de onboarding/nivelamento ficou responsivo.
   - Padding e largura passam a depender do viewport.
   - O conteudo abre melhor em tablet sem mudar o fluxo.

4. Botoes principais foram migrados para componente canonico.
   - `PrimaryWideButton`
   - `SecondaryWideButton`
   - Mantidos os nomes antigos para nao quebrar telas existentes.

5. Alternativas da aula ficaram mais proximas de botoes reais.
   - Saiu a dependencia pura de `GestureDetector`.
   - Entrou `Material` + `InkWell`, mantendo Semantics e efeito de press.
   - Alvo minimo de toque preservado.

6. Sala de aula ganhou largura de leitura melhor.
   - Em telas maiores, o conteudo nao se espalha demais.
   - Em telas pequenas, mantem foco e scroll.

7. Tipografia principal da aula foi padronizada.
   - Texto de teoria usa `SimTypography.lessonBody`.
   - Pergunta usa `SimTypography.lessonQuestion`.

8. Painel de imagem ficou mais util em tablet.
   - Altura maxima aumenta em telas maiores.
   - Celular continua limitado para nao esconder aula.

9. Controles do topo da aula ganharam alvo de toque maior.
   - Menu e audio passam para tamanho canonico de toque.

10. Feedback da aula foi corrigido para tela pequena com fonte maxima.
    - Antes da correcao, a suite detectou overflow horizontal em zoom alto.
    - Agora o feedback vira layout vertical quando a largura e curta.

11. Controles manuais da aula foram aproximados de botoes nativos.
    - Menu, audio, revisao, avancar do feedback e sinais usam `Material`/`InkWell` ou `SimIconAction`.
    - Mantem Semantics e melhora feedback de toque.

12. Foi criado um trilho lateral de estudo para telas largas.
    - Em tela larga, o controle de fonte sai do canto inferior e entra em um painel lateral.
    - O painel mostra progresso vertical e item atual.
    - Em celular, o comportamento antigo de botao flutuante e preservado.

13. A acao principal do objetivo/onboarding virou botao real.
    - Saiu o `GestureDetector` externo como ponto principal de toque.
    - Entrou `Material` + `InkWell`, mantendo a validacao de objetivo obrigatorio.
    - O estado de processamento continua bloqueando toque indevido.

14. A acao "Trocar objetivo" passou a usar componente textual canonico.
    - O comportamento foi preservado.
    - O alvo de toque ficou mais previsivel.

15. Salas auxiliares foram aproximadas do mesmo padrao de interacao da aula.
    - Botao voltar e audio usam `SimIconAction`.
    - Botoes de sinal, alternativas, avancar feedback, fechar revisao e escolhas de quantidade usam `InkWell`, `SimActionButton` ou `SimTextAction`.
    - O fluxo de duvida, revisao e recuperacao foi preservado.

16. Drawer da aula teve os principais controles migrados.
    - Fechar menu, nova aula, recarregar creditos, logout, carregar mais, abrir aula, renomear/apagar e exportar/importar/status usam botoes reais.
    - O contrato de abrir, buscar, renomear, apagar, exportar e importar aulas foi preservado pelos testes existentes.

17. A folha de duvida ficou mais robusta para toque e acessibilidade.
    - Remover foto, anexar foto, tirar foto e escolher imagem passaram a ter controles com feedback de toque e Semantics.
    - Validacao, limite de texto e fluxo de foto foram preservados.

18. A tela de creditos e a bolha de audio foram ajustadas.
    - Voltar e cards de compra usam botoes reais.
    - A bolha de audio manteve animacao, mas agora usa Semantics e `InkWell`.
    - A varredura dos fluxos-alvo principais nao encontrou mais `GestureDetector`.

## Testes criados

Arquivo:

- `test/sim_ideal_layout_system_test.dart`

Cobre:

- breakpoints de celular/tablet/wide;
- altura minima acessivel de botoes principais;
- largura responsiva do `CyberStepShell` em tablet.

Arquivo atualizado:

- `test/classroom_main_screen_health_test.dart`

Cobre:

- trilho lateral em tela larga;
- preservacao do botao de fonte em celular;
- manutencao de Semantics e fluxo de sala.

## Validacoes executadas

- `flutter analyze --no-pub`: PASSOU
- `flutter test test/sim_ideal_layout_system_test.dart`: PASSOU
- `flutter test test/classroom_main_screen_health_test.dart`: PASSOU
- `flutter test test/widget_test.dart`: PASSOU
- `flutter test test/auxiliary_phase_test.dart`: PASSOU
- `flutter test test/billing_phase_test.dart test/classroom_main_screen_health_test.dart`: PASSOU
- `flutter test`: PASSOU
- `flutter build apk --release --dart-define=FLUTTER_APP_MODE=production`: PASSOU

APK buildado localmente:

- `build/app/outputs/flutter-apk/app-release.apk`

## Arquivos alterados

- `docs/SIM_IDEAL_INTERFACE_LAYOUT_AUDIT.md`
- `docs/SIM_IDEAL_LAYOUT_EXECUTION_REPORT.md`
- `lib/sim/ui/sim_design_system.dart`
- `lib/shared/widgets/shared_widgets.dart`
- `lib/features/portal/portal_flow.dart`
- `lib/sim/ui/widgets/cyber_step_shell.dart`
- `lib/features/classroom/aula_screen.dart`
- `lib/features/classroom/aula_widgets.dart`
- `lib/features/classroom/aux_room_screens.dart`
- `lib/features/onboarding/onboarding_screens.dart`
- `lib/features/onboarding/preparation_and_placement.dart`
- `lib/features/billing/billing_and_simple_pages.dart`
- `lib/sim/ui/widgets/fixed_bubble.dart`
- `test/sim_ideal_layout_system_test.dart`

## O que ainda falta

1. Migrar mais botoes manuais para componentes canonicos.
2. Expandir o layout de tablet com painel lateral mais rico quando couber.
3. Refinar visualmente a sala inteira, nao so a fundacao.
4. Melhorar onboarding para capturar campos ricos sem cansar.
5. Fazer auditoria completa de Semantics e contraste.
6. Criar provas visuais por viewport/screenshot.
7. Fechar checklist Google Play.

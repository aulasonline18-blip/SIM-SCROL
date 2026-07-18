# Fase 8 — Recuperacao De Produto Vivo

Esta auditoria bloqueia limpeza cega no app Flutter. A decisao abaixo usa os documentos SIM NV lidos, o mapa de paridade da interface, o inventario de arquitetura do app e o historico Git dos arquivos apagados.

| Arquivo | Decisao | Motivo | Fonte antiga | Onde ficou agora | Teste de prova |
| --- | --- | --- | --- | --- | --- |
| `lib/sim/ui/sim_accessibility.dart` | RESTAURAR | Continha contrato de contraste, escala de texto e estados com pista nao-cromatica; nao havia equivalente completo. | `git show 3ed3d6a^:lib/sim/ui/sim_accessibility.dart` | Restaurado em `lib/sim/ui/sim_accessibility.dart`. | `test/product_live_features_guard_test.dart` |
| `lib/sim/ui/sim_components.dart` | RESTAURAR | Continha componentes responsivos reutilizaveis; complementa `sim_design_system.dart` sem duplicar motor. | `git show 3ed3d6a^:lib/sim/ui/sim_components.dart` | Restaurado em `lib/sim/ui/sim_components.dart`. | `test/product_live_features_guard_test.dart` |
| `lib/sim/ui/widgets/fixed_bubble.dart` | RESTAURAR | Indicador visual de audio/fala era produto vivo e nao existia como bolha persistente. | `git show 3ed3d6a^:lib/sim/ui/widgets/fixed_bubble.dart` | Restaurado e ligado em `ChatAulaScreen`. | `test/product_live_features_guard_test.dart`, `test/media_phase_test.dart` |
| `lib/sim/ui/widgets/sim_typewriter.dart` | RESTAURAR | Efeito de explicacao viva com respeito a reducao de movimento; nao governa pedagogia. | `git show 3ed3d6a^:lib/sim/ui/widgets/sim_typewriter.dart` | Restaurado e usado em explicacao ativa da timeline. | `test/product_live_features_guard_test.dart` |
| `lib/sim/ui/widgets/lesson_audio_controls.dart` | FUNDIR | O arquivo antigo dependia direto de `AudioPreference`; a versao nova usa a facade local da sessao e preserva toggle/estado visual sem importar infra antiga. | `git show aa4a735^:lib/sim/ui/widgets/lesson_audio_controls.dart` | Novo controle em `lib/sim/ui/widgets/lesson_audio_controls.dart`, ligado no `AulaTopBar`. | `test/product_live_features_guard_test.dart`, `test/media_phase_test.dart` |
| `lib/sim/ui/widgets/lesson_avatar.dart` | RESTAURAR | Avatar/onda de fala era sinal visual vivo de audio e nao reintroduz rota ou motor. | `git show aa4a735^:lib/sim/ui/widgets/lesson_avatar.dart` | Restaurado e ligado no `AulaTopBar`. | `test/product_live_features_guard_test.dart` |
| `lib/features/classroom/aula_screen.dart` | MANTER_APAGADO | Era tela monolitica com imports circulares, Supabase, AI clients e UI duplicada; foi substituida pela tela fina `ChatAulaScreen` + widgets atuais. | `git show aa4a735^:lib/features/classroom/aula_screen.dart` | `lib/features/classroom/chat_aula_screen.dart`, `aula_widgets.dart`, `chat_aula_widgets.dart`. | `test/product_live_features_guard_test.dart`, `test/classroom_main_screen_health_test.dart` |
| `lib/sim/placement/placement_screens.dart` | MANTER_APAGADO | Guardava apenas modelos de tela; o fluxo vivo foi refeito em `PlacementLabScreen` usando controlador local. | `git show b12bdb4^:lib/sim/placement/placement_screens.dart` | `lib/features/onboarding/preparation_and_placement.dart` e `lib/sim/placement/*`. | `test/product_live_features_guard_test.dart` |
| `lib/sim/auxiliary/aux_room_screens.dart` | MANTER_APAGADO | O arquivo antigo era DTO/modelo auxiliar; telas vivas de revisao/recuperacao estao no orgao de UI. | `git show 2b8bb81^:lib/sim/auxiliary/aux_room_screens.dart` | `lib/features/classroom/aux_room_screens.dart`. | `test/product_live_features_guard_test.dart`, `test/review_manual_only_contract_test.dart` |
| `lib/sim/auxiliary/doubt_progress_bar.dart` | RESTAURAR | O snapshot/label de progresso da duvida estava ausente; o fluxo atual tinha progresso no estado, mas sem contrato reutilizavel. | `git show 3ed3d6a^:lib/sim/auxiliary/doubt_progress_bar.dart` | Restaurado como contrato leve de progresso. | `test/product_live_features_guard_test.dart` |
| `lib/sim/ui/widgets/doubt_progress_bar.dart` | RESTAURAR | A timeline tinha progresso da duvida, mas renderizava apenas texto/loading. | `git show 3ed3d6a^:lib/sim/ui/widgets/doubt_progress_bar.dart` | Restaurado e ligado ao bloco `doubt-processing`. | `test/product_live_features_guard_test.dart` |

## Protecoes Vivas

- Night view: `SimPalette.darkMode`, `SimThemeScope`, toggle no portal e persistencia `sim.ui.dark_mode`.
- Idiomas: tela `/cyber/idioma`, idiomas principais, outro idioma, `localeContract` enviado para T00/T02, audio e visual com idioma estruturado.
- Telas: portal, login, creditos, idioma, objetivo/anexos, preparacao, placement, aula, feedback, duvida, revisao, recuperacao e menu/drawer seguem no runtime.
- Interface: componentes reutilizaveis, acessibilidade, responsividade, botoes tocaveis, feedback visual, loading/erro e midia visivel quando existe.
- Imagem/audio: S12, N2, N3, templates matematicos, SVG/raster sem WebView e audio nao bloqueante preservados.

Nenhum arquivo de servidor, prompt, T00/T02, N3, billing, assinatura Android ou documento normativo foi alterado nesta fase.

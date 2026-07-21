# Constituicao Dos Contratos SIM

Codigo: CCSIM-1
Status: VIGENTE
Escopo: app SIM-SCROL e servidor sim-api.

Este documento e a autoridade maxima sobre contratos, leis, prompts, rotas, orgaos, cache, midia, estado, custo, IA e UI. Qualquer contrato antigo, teste, prompt, comentario ou documento que contradiga esta Constituicao fica subordinado, historico ou removido.

## Regra De Autoridade

1. Se dois contratos conflitarem, vence o contrato da camada mais alta.
2. Se estiverem na mesma camada, vence o contrato mais novo e explicitamente marcado como VIGENTE.
3. Se ainda houver empate, a execucao deve falhar com erro de governanca. O sistema nao escolhe silenciosamente.
4. Documento historico nao e fonte de implementacao.
5. Teste antigo nao pode reviver contrato rebaixado.

## Hierarquia Unica

1. Seguranca, custo, privacidade e protecao anti-loop.
2. Aula textual do aluno.
3. Estado, progresso, dominio e avanco.
4. T00/T02 e contratos de IA textual.
5. Imagem, audio, midia e anexos.
6. Cache, janela viva, fila e pre-carregamento.
7. UI, layout e experiencia visual.

## Autoridades Unicas

| Tema | Autoridade unica | Regra |
|---|---|---|
| Rotas oficiais | Servidor `src/app/router.js` e esta Constituicao | O app nao cria lista concorrente sem contrato claro. |
| Custo/rate limit | `AiCostProtectionGate` | Router e controllers podem aplicar protecao local, mas nao viram autoridade financeira superior. |
| Aula pronta | `LessonReadinessResolver` no app, subordinado ao contrato textual | Cache e espelhos nao decidem prontidao final. |
| Navegacao inicial | Coordenador unico de entrada/placement | Warmup, curriculo e primeira aula nao competem como decisores finais. |
| Visual/imagem | S12 julga/enriquece; N3 produz SVG; app renderiza | App nao decide qualidade final nem cria produtor paralelo. |
| Audio | Servidor gera/valida; app toca honestamente | Audio nao bloqueia texto nem progresso. |
| Estado/dominio | Software com evidencia estruturada | IA, cache e fallback nao fabricam progresso. |

## Classificacao De Contratos

| Arquivo | Tema | Status | Autoridade superior | Observacao |
|---|---|---|---|---|
| `docs/CONSTITUICAO_CONTRATOS_SIM.md` | Constituicao | VIGENTE | Nenhuma | Autoridade maxima. |
| `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md` | Anti-loop/custo | VIGENTE | CCSIM-1 camada 1 | Subordinada a esta Constituicao. |
| `/root/sim-work/sim-api/docs/migracao-sim-nv/CONTRATO_ESTADO_DOMINIO_AVANCO.md` | Estado/dominio/avanco | VIGENTE | CCSIM-1 camada 3 | Estado exige evidencia. |
| `/root/sim-work/sim-api/docs/migracao-sim-nv/CONTRATO_RUNTIME_T00_CG1.md` | T00/CG-1 | VIGENTE | CCSIM-1 camada 4 | Governa T00 no servidor. |
| `/root/sim-work/sim-api/docs/migracao-sim-nv/CONTRATO_RUNTIME_T02_AULA_AUXILIARES.md` | T02/aula/auxiliares | VIGENTE | CCSIM-1 camada 4 | Nao pode contrariar estado/custo. |
| `/root/sim-work/sim-api/docs/migracao-sim-nv/CONTRATO_RUNTIME_MIDIA_VISUAL_N3.md` | Midia/N3 | VIGENTE | CCSIM-1 camada 5 | Nao bloqueia texto. |
| `/root/sim-work/sim-api/docs/migracao-sim-nv/CLASSIFICACAO_DE_LEGADOS_E_ESPELHOS.md` | Legados | VIGENTE | CCSIM-1 | Define historico vs runtime. |
| `PLANTA-MAE DO SIM IDEAL.txt` | Planta-mae app | VIGENTE | CCSIM-1 | Fonte normativa, subordinada se houver conflito operacional. |
| `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md` | Evento A | VIGENTE | CCSIM-1 | Aceite app, subordinado a seguranca/custo. |
| `docs/SIM_FLUTTER_CONTRATO_FIO.md` | Fio app | SUBORDINADO | CCSIM-1 | Vale onde nao cria decisor paralelo. |
| `docs/CONTRATO_SYNC_OFFLINE_CACHE.md` | Sync/cache | SUBORDINADO | CCSIM-1 camada 6 | Cache nao vira verdade final. |
| `docs/B-audio-flutter-real-root-cause.md` | Audio historico | HISTORICO | CCSIM-1 | Diagnostico antigo, nao autoridade superior. |
| `docs/B-audio-flutter-real-final-report.md` | Audio final | HISTORICO | CCSIM-1 | Relatorio de fase. |
| `docs/B1-audio-system-inventory.md` | Audio inventario | HISTORICO | CCSIM-1 | Nao decide runtime. |
| `docs/B2-audio-system-parity.md` | Audio paridade | HISTORICO | CCSIM-1 | Referencia, nao autoridade superior. |
| `docs/SIM_IMAGE_VISUAL_TAXONOMY.md` | Taxonomia visual | SUBORDINADO | CCSIM-1 camada 5 | S12/N3 vencem em runtime. |
| `lib/sim/media/*` | Midia app | SUBORDINADO | CCSIM-1 camada 5 | Executa, nao governa IA/custo. |
| `lib/sim/state/*` | Estado app | VIGENTE | CCSIM-1 camada 3 | Autoridade local com evidencias. |
| `lib/sim/lesson/*` | Aula/cache/janela | SUBORDINADO | CCSIM-1 camadas 2 e 6 | Texto vence cache. |
| `src/web-startup-engine/**`, `src/web-visual-engine/**`, `src/flutter-visual-engine/**` | Espelhos runtime | REMOVIDO | CCSIM-1 | Nao podem voltar ao runtime oficial. |
| `/root/sim-work/sim-api/docs/CONSTITUICAO_CONTRATOS_SIM.md` | Constituicao servidor | VIGENTE | CCSIM-1 | Copia espelhada obrigatoria. |

## Resolucao Dos 50 Conflitos

| No | Conflito | Regra vencedora | Regra rebaixada/removida | Acao | Teste |
|---|---|---|---|---|---|
| 1 | Rotas oficiais do app contra inventario mais amplo | Servidor e Constituicao | Inventario | Inventario e historico | constitutional governance |
| 2 | `_serverRoutes` menor que mapa oficial | Servidor como fonte | Lista app concorrente | App deve ser subordinado | constitutional governance |
| 3 | Rotas proibidas repetidas em testes | Constituicao central | Listas soltas | Testes devem referenciar a Constituicao | constitutional governance |
| 4 | Producao HTTPS contra HTTP autorizado por flag | Privacidade/seguranca | Flag dev | HTTP so dev/autorizado | constitutional governance |
| 5 | Google Play HTTPS contra APK HTTP temporario | Google Play/seguranca | APK temporario | Marcar temporario, nao ideal | constitutional governance |
| 6 | `SIM_SERVER_URL` contra fallback dev | Build config explicito | Fallback dev | Fallback so desenvolvimento | constitutional governance |
| 7 | T00/T02 duplicados em ambiente/clientes | Contrato T00/T02 servidor | Duplicacao app | App apenas consome | constitutional governance |
| 8 | `/api/sim/t02` em teste contra `/api/complete-lesson` | `/api/complete-lesson` | Alias antigo | Alias historico | constitutional governance |
| 9 | `protectedRoutes` e `routeHandlers` separados | Router oficial validado | Lista divergente | Testar sincronismo | constitutional governance |
| 10 | `allowedServerRoutes` app contra router servidor | Router servidor | Lista app solta | App subordinado | constitutional governance |
| 11 | Rate limit geral contra AiCostProtectionGate | AiCostProtectionGate | Rate limit generico como juiz | Generico vira protecao local | ai cost gate |
| 12 | Audio limitado em varios pontos | AiCostProtectionGate + audio controller subordinado | Limites paralelos | Gate superior | ai cost gate |
| 13 | Imagem limitada em varios pontos | AiCostProtectionGate + controller subordinado | Limites paralelos | Gate superior | ai cost gate |
| 14 | Visual N3 limite proprio e rota AI | AiCostProtectionGate | Limite proprio superior | Proprio e subordinado | ai cost gate |
| 15 | Timeout T02 app 140s contra servidor 110/90s | Servidor define tentativa; app espera margem | App como autoridade | App nao decide retry | constitutional governance |
| 16 | Timeout T00 app 140s contra servidor 120s | Servidor define tentativa; app espera margem | App como autoridade | App nao decide retry | constitutional governance |
| 17 | Visual app 35s contra raster 10s | Servidor/midia define geracao | App como juiz | App so mostra estado | constitutional governance |
| 18 | Cache 12/32/15 com mesmo nome | Constituicao separa cache/midia/janela | Numeros soltos | Cada numero recebe escopo | constitutional governance |
| 19 | Aula pronta no resolver contra service aplicando material | LessonReadinessResolver | Service como juiz | Service executa, nao decide | app governance |
| 20 | `currentLessonMaterial` contra `readyLessonMaterials` | Resolver/estado canonico | Duplicacao sem autoridade | Definir papel | app governance |
| 21 | Servidor remove material remoto; app guarda local | Texto local executavel | Servidor como vault de material completo | Privacidade vence remoto completo | state governance |
| 22 | Cache nao autoridade mas dentro do estado | Estado marca cache como auxiliar | Cache como verdade | Cache subordinado | state governance |
| 23 | `CACHE_WINDOW_UPDATED` conta janela, nao pronto | Evento deve nomear realidade | Nome enganoso | Ajustar quando tocar fluxo | app governance |
| 24 | `hotTextReadyCount=4` contra janela 15 | Janela 15 e meta; 4 e pista quente | 4 como lei geral | Separar pista/estoque | app governance |
| 25 | `offlineWarmCacheSize` contra `localLessonTraySize` | Um nome canonico | Nome duplicado | Alias subordinado | app governance |
| 26 | Janela atual+3 contra janela viva 15 | Janela viva 15; atual+3 e prioridade | Atual+3 como limite total | Subordinar | app governance |
| 27 | Worker dedupe por lesson contra hot-local furando inflight | Single-flight por operacao | Furo sem gate | Gate superior | anti-loop test |
| 28 | Idempotencia por posicao contra payload mutavel | Idempotency key com identidade forte | Posicao sozinha | Exigir hash/conteudo | anti-loop test |
| 29 | Menu abre aula antes; fast path chama janela depois | Aula textual do aluno vence | Janela disputando prioridade | Janela subordinada | readiness test |
| 30 | `forceRefresh` ignora cache contra resolver | Resolver governa prontidao | Force refresh como juiz | Force refresh e comando explicito | app governance |
| 31 | T00 fallback desativado contra `fallback_gateway` | Fallback nao e contrato final | Evento legado | Evento historico/erro seguro | T00 governance |
| 32 | `adendo_amparo_t00` carregado mas amparo T00 nao roda | Prompt protegido, fluxo oficial decide | Prompt carregado como autoridade | Prompt ocioso subordinado | prompt governance |
| 33 | `AuxRoomsController` concentra auxiliares contra servicos proprios | Um coordenador oficial | Servicos paralelos como juiz | Definir papeis | app governance |
| 34 | `StudentAuxRoomService` comum contra servicos especificos | Servico especifico governa fluxo | Comum como autoridade | Comum vira utilitario | app governance |
| 35 | Revisao manual contra pendingMap/cursor programado | Revisao manual | Programacao automatica | Pending e estado, nao disparo | review governance |
| 36 | Recuperacao prioridade sobre amparo parcial | Recuperacao obrigatoria | Amparo concorrente | Amparo subordinado | recovery governance |
| 37 | `/cyber/amparo` sem objetivo contra auth/idioma | Entrada pedagogica minima | Rota sem objetivo | Exigir objetivo quando ativo | route governance |
| 38 | Warmup coordenador contra logica em LabSession | Coordenador unico | LabSession decisor | LabSession executa UI | entry governance |
| 39 | Placement decide destino contra LabSession abrindo rotas | Coordenador de entrada | LabSession como decisor final | LabSession subordinada | entry governance |
| 40 | StartFirstLessonUseCase contra fluxo placement/curriculo/warmup | Coordenador unico | Use case concorrente | Use case executa acao | entry governance |
| 41 | DoubtT02Caller contra AuxRoomT02Caller | Caller oficial por sala | Caller duplicado | Unificar quando tocar fluxo | doubt governance |
| 42 | Modelo auxiliar de duvida contra widget classroom | Modelo governa dados; widget executa | Widget como regra | UI subordinada | doubt governance |
| 43 | `doubt_progress_bar` duplicado | Componente canonico | Duplicata | Rebaixar/remover duplicata | UI governance |
| 44 | Autoridade visual no app/N2/N3 servidor | S12/N3 servidor | App como juiz final | App renderiza | visual governance |
| 45 | Templates locais e N3 decidem tipo | S12 decide rota; N3 produz | Template como autoridade final | Template e executor local | visual governance |
| 46 | Imagem paga permitida contra proibicao em background | Custo/consentimento vence | Background pago | Paga so com oferta aceita | media governance |
| 47 | Audio nao bloqueia contra preferencia/adapter impedindo chamada | Aula textual e execucao honesta | Preferencia como falha silenciosa | Preferencia so habilita/desabilita | audio governance |
| 48 | Docs antigos audio fallback contra proibicao fallback falso | Audio honesto | Fallback falso | Historico ou fallback real comprovado | audio test |
| 49 | Inventario manda fundir duplicatas | Constituicao manda autoridade unica | Inventario como ordem atual | Inventario historico | constitutional governance |
| 50 | Relatorios antigos dizem fechado com risco APK/manual | Marco final/uso real | "Fechado" historico | Fechado nao equivale a APK real | final governance |

## Servidor Como Juiz

O servidor e juiz final para chamadas de IA, custo, rate limit, idempotencia, single-flight, contrato de saida, validacao de T00/T02/N3, geracao/validacao de midia, privacidade de logs e erros publicos.

A IA nunca se autoaprova. O app nunca cria gasto infinito. O cache nunca vira autoridade final.

## App Como Executor

O app mostra aula textual, toca audio, renderiza imagem, preserva estado local, permite resposta do aluno, mantem fluidez e funciona com internet ruim quando ha material pronto.

O app nao inventa progresso, nao cria gasto sem servidor, nao decide contrato de IA, nao trata cache como verdade final e nao mantem rota oficial divergente do servidor.

## Referencias Oficiais

- OWASP API4:2023 Unrestricted Resource Consumption: APIs devem limitar consumo de recursos, taxa e operacoes caras.
- RFC 6585 / HTTP 429: excesso de chamadas usa 429 e pode usar `Retry-After`.
- RFC 9110 / Retry-After: servidor informa quanto tempo o cliente deve esperar.
- Flutter Testing: unit, widget e integration tests protegem camadas diferentes.
- Node.js runtime: servidor e testes JS rodam no runtime oficial Node.js.

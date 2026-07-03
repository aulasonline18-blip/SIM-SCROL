# Projeto — Sistema de Imagem Educativa do SIM App

## Objetivo

Transformar o sistema de imagem do SIM App em um recurso pedagógico de padrão mundial: a imagem deve aparecer quando ajuda o aluno a entender, deve ser correta, leve, rápida, segura, alinhada ao item ativo e deve depender de IA paga só quando o software não consegue entregar um visual didático suficiente.

O ponto B não é copiar o SIM Web. O ponto B é o SIM App ter um funil visual melhor que o Web saudável quando isso for possível, preservando a arquitetura Flutter/API já refinada.

## Estado Atual Lido no Código

Arquivos principais lidos:

- `lib/sim/media/lesson_visual_pipeline.dart`
- `lib/sim/media/visual_router_n2.dart`
- `lib/sim/media/visual_router_n3.dart`
- `lib/sim/media/local_visual_fallback.dart`
- `lib/sim/media/math_templates/math_templates.dart`
- `lib/sim/media/student_lesson_media_service.dart`
- `lib/sim/lesson/lesson_orchestrator.dart`
- `lib/features/classroom/aula_widgets.dart`
- `test/media_phase_test.dart`
- `test/first_lesson_ready_window_test.dart`

O app já tem órgãos bons:

- `LessonVisualPipeline` como funil central.
- S12 para decidir se a imagem deve existir.
- SVG inline vindo do T02.
- Templates matemáticos.
- N2 determinístico por palavras-chave.
- N3 por endpoint/cliente externo.
- Fallback local gratuito para alguns casos.
- Oferta paga com aceite explícito.
- Orquestrador publicando imagem por `lessonKey`.
- Testes para parábola local, N3, SVG, oferta paga e prefetch seguro.

O que ainda limita o padrão mundial:

- O fallback local ainda é pequeno perto do universo de ensino.
- N2 é útil, mas ainda depende muito de palavras-chave.
- N3 pode decidir melhor, mas precisa de contrato pedagógico mais forte.
- Templates existem principalmente para matemática.
- A UI exibe imagem, mas ainda pode evoluir para "imagem como ferramenta de estudo", com foco, legenda, zoom e inspeção.
- A observabilidade mostra estágio do funil, mas ainda não mede qualidade pedagógica da imagem.
- Falta uma matriz de cobertura visual por disciplina, idade, tipo de raciocínio e objetivo pedagógico.

## Benchmark Externo Usado

Este projeto não copia um app específico. Ele usa o que há de mais forte em produtos educacionais reconhecidos e define onde o SIM deve superá-los.

Fontes analisadas em 2026-07-02:

- Brilliant: referência em aprendizado visual e interativo. A proposta central é que cada sessão use orientação visual e problemas passo a passo para fazer o conceito "clicar" para o aluno.
- Khanmigo/Khan Academy: referência em tutoria por IA que guia o aluno a pensar, sem apenas entregar a resposta, com preocupação explícita de segurança e aprendizagem.
- Photomath: referência em matemática passo a passo, múltiplos métodos de solução e ajudas visuais customizadas.
- GeoGebra: referência em matemática visual, gráficos, geometria, 3D, calculadoras e exploração interativa.
- SIM Web saudável: referência interna de funil visual já validado: software/template antes de IA paga.

### O Que Cada Referência Faz Bem

| Referência | Força observada | O que o SIM deve absorver |
|---|---|---|
| Brilliant | Visual + interativo + raciocínio ativo | imagem não decorativa; imagem precisa fazer o conceito "clicar" |
| Khanmigo | tutor que guia sem entregar resposta direta | imagem deve provocar pensamento, não só mostrar resposta |
| Photomath | passo a passo, múltiplos métodos, ajuda visual | imagem deve acompanhar etapas e explicar o "porquê" |
| GeoGebra | gráficos e construções matemáticas manipuláveis | desenhos matemáticos devem ser precisos, escaláveis e interativos quando útil |
| SIM Web | funil software → N2/N3 → oferta paga | preservar software-first e aceite explícito |

### Onde Eles Ainda Deixam Espaço Para o SIM Superar

1. Muitos apps são fortes em uma disciplina, mas não em todas.
2. Muitos geram visual estático, mas não adaptado ao estado pedagógico do aluno.
3. Muitos mostram solução, mas não ligam a imagem ao erro específico do aluno.
4. Muitos não explicam por que uma imagem foi escolhida.
5. Muitos não têm funil econômico claro entre software gratuito e IA cara.
6. Muitos não têm imagem por item/layer com chave segura e histórico pedagógico.
7. Muitos não tratam a imagem como órgão do processo de aula em tempo real.
8. Muitos não adaptam profundidade visual ao nível escolar, dificuldade conhecida e idioma.
9. Muitos não têm decisão explícita: desenhar, não desenhar, ofertar IA ou esperar.
10. Muitos não têm prova operacional de que a imagem não atrapalha o fluxo da aula.

### Tese de Superioridade do SIM

O SIM deve ser melhor porque combina cinco capacidades que normalmente aparecem separadas:

1. Professor IA que gera aula personalizada.
2. Funil de imagem software-first para reduzir custo e latência.
3. Estado pedagógico vivo do aluno.
4. Renderização mobile/tablet integrada à aula.
5. Segurança financeira e pedagógica: sem cobrança indevida, sem imagem enganosa, sem bloquear estudo.

O alvo não é "gerar imagem bonita". O alvo é gerar o visual mais útil naquele momento da aprendizagem.

## Modelo Ideal: Imagem Como Tutor Visual

Toda imagem do SIM deve ter uma função pedagógica explícita. O sistema deve registrar uma dessas funções:

- `concept_anchor`: fixar um conceito abstrato.
- `step_visualizer`: mostrar etapas de resolução.
- `error_repair`: corrigir um erro típico do aluno.
- `comparison`: comparar duas ideias.
- `timeline`: ordenar eventos ou processos.
- `cycle`: explicar repetição/ciclo.
- `structure_map`: mostrar partes de um sistema.
- `graph_reasoning`: apoiar leitura de gráfico.
- `spatial_reasoning`: apoiar geometria/espaço.
- `memory_hook`: criar gancho visual leve para memorizar.
- `realistic_reference`: mostrar algo realista quando esquema não basta.

Se a imagem não tiver função pedagógica, ela não deve ser gerada.

## Nova Arquitetura Alvo de Decisão

O funil atual deve evoluir para:

1. `visual_trigger` bruto do T02.
2. `VisualTriggerNormalizer`.
3. `VisualPedagogicalIntentClassifier`.
4. `S12VisualDecision`.
5. `SoftwareRenderCatalog`.
6. `TemplateRenderer`.
7. `N2DomainRouter`.
8. `N3PedagogicalSvgJudge`.
9. `PaidImageOfferPolicy`.
10. `PaidImageGeneration`.
11. `ImageLearningEventLogger`.
12. `LessonImageStudySurface`.

Cada etapa precisa devolver:

- `decision`
- `reason`
- `confidence`
- `pedagogicalRole`
- `costClass`: `free_software`, `cheap_judge`, `paid_ai`, `none`
- `risk`: `low`, `medium`, `high`

## Princípios

1. Texto primeiro, imagem depois.
2. Imagem nunca bloqueia aula.
3. Software gratuito tenta antes de IA paga.
4. IA paga só depois de aceite explícito.
5. Imagem deve ensinar, não decorar.
6. Imagem errada é pior que ausência de imagem.
7. Toda imagem precisa estar presa a `lessonKey/item/layer`.
8. O app deve saber explicar por que desenhou ou por que não desenhou.
9. Imagem pronta deve aparecer sem poluir a aula.
10. O sistema deve ser mensurável: taxa de software, taxa de IA, taxa de erro, taxa de imagem útil.

## Funil Visual Alvo

1. T02 gera aula e `visual_trigger` estruturado.
2. Normalizador fortalece o trigger sem aceitar lixo.
3. S12 decide se existe necessidade pedagógica.
4. SVG inline seguro é aceito quando já veio pronto.
5. Template explícito é renderizado.
6. Template inferido é tentado quando o assunto permite.
7. N2 classifica por domínio e tipo visual.
8. Biblioteca local tenta renderizar software especializado.
9. N3 barato julga casos ambíguos e pode devolver SVG.
10. Se software não resolve, cria oferta paga por key.
11. Aceite explícito gera IA paga.
12. Cache seguro evita repetição.
13. UI recebe imagem por key e renderiza.
14. Logs registram o caminho completo.
15. Testes e APK provam os caminhos.

## Frentes de Trabalho

### Frente 1 — Taxonomia Pedagógica de Imagem

Criar uma matriz que diga quais imagens o SIM deve tentar desenhar por software.

Tipos mínimos:

- Gráfico cartesiano.
- Função linear.
- Função quadrática/parábola.
- Funções exponenciais e logarítmicas.
- Trigonometria/círculo unitário.
- Vetores e forças.
- Tabela.
- Linha do tempo.
- Fluxograma.
- Ciclo.
- Mapa conceitual.
- Diagrama de comparação.
- Diagrama de causa e efeito.
- Árvore sintática.
- Tabela gramatical.
- Cadeia alimentar.
- Ciclos de biologia.
- Circuito elétrico esquemático.
- Geometria plana.
- Geometria espacial simples.

Entrega:

- `docs/SIM_IMAGE_VISUAL_TAXONOMY.md`
- Testes de classificação N2 por tipo visual.
- Benchmark incorporado de Brilliant, Khanmigo, Photomath, GeoGebra e SIM Web.

### Frente 2 — Normalizador Forte de `visual_trigger`

Objetivo: o app não pode depender de um trigger perfeito demais.

Implementar/aperfeiçoar:

- Alias de `math_template`.
- Alias de `visual_type`.
- Normalização de `render_strategy`.
- Normalização de `pedagogical_need`.
- Preservação de idioma.
- Preservação de `topic`, `key_elements`, `color_legend`, `highlight_focus`.
- Rejeição segura de campos perigosos.

Entrega:

- Normalizador explícito no app ou no servidor, conforme arquitetura.
- Testes com trigger perfeito, incompleto, ambíguo e inválido.

### Frente 3 — Biblioteca Local de Desenhos por Software

Ampliar `local_visual_fallback.dart` e `math_templates`.

Prioridade:

- Matemática: linear, quadrática, custom formula, unit circle, cinemática, exponencial, logarítmica, inequações, vetores.
- Física: força resultante, bloco/plano inclinado, circuito simples, onda, MRU/MRUV.
- Linguagem: árvore sintática simples, tabela de classes gramaticais, conjugação verbal, comparação semântica.
- Ciências: ciclo da água, cadeia alimentar, célula esquemática simples quando não for realista, etapas de processo.
- História/geografia: linha do tempo, comparação, mapa conceitual, causa e consequência.

Regra:

- O desenho local só deve atuar quando puder ser pedagogicamente honesto.
- Se o assunto exige realismo visual, anatomia detalhada, foto, mapa físico ou cena histórica, deve ir para oferta paga.

Entrega:

- Novos renderizadores SVG determinísticos.
- Testes por disciplina.
- Prova de que software desenha mais sem aumentar custo.

### Frente 4 — N2 Mais Inteligente e Menos Frágil

Melhorar `visual_router_n2.dart`.

Implementar:

- Classificação por tipo visual, não só palavra solta.
- Pesos por domínio.
- Distinção entre "diagrama esquemático" e "foto realista".
- Distinção entre "célula esquema" e "célula realista".
- Detecção de "a imagem é essencial para responder".
- Saída com motivo estruturado.

Entrega:

- `VisualN2Result` com score/confiança.
- Testes PT/EN/ES.
- Testes que provam que parábola, linha do tempo, fluxograma e tabela não viram oferta paga.
- Métrica de custo salvo por N2.

### Frente 5 — N3 Pedagógico Forte

N3 deve ser um avaliador barato, mas com missão pedagógica rígida.

Novo contrato de N3:

- Entrada: tópico, pergunta, alternativas, resposta correta, visual_trigger, decisão N2, idade/nível, idioma.
- Saída: `svg`, `ai`, `no_image`, `reason`, `confidence`, `pedagogical_role`.

Prompt/ordem de N3:

- Tentar salvar o caso como SVG se for pedagogicamente honesto.
- Não mandar para IA paga por preguiça.
- Não desenhar se o visual pode confundir.
- Não criar texto excessivo dentro da imagem.
- Gerar SVG simples, limpo, com legenda curta e sem dependência externa.

Entrega:

- Contrato atualizado com servidor.
- Testes de N3 com casos ambíguos.
- Logs mostrando quando N3 salvou uma imagem gratuita.

### Frente 6 — T02 Como Primeiro Desenhista

O maior ganho começa antes do app: o professor T02 deve entregar `visual_trigger` rico.

Sem mexer em prompt às cegas, revisar:

- Se T02 está gerando `svg_payload` quando deveria.
- Se T02 está gerando `math_template` quando a aula é matemática.
- Se T02 informa `key_elements`.
- Se T02 diferencia software vs IA.
- Se T02 usa `pedagogical_need` corretamente.

Entrega:

- Proposta de melhoria do prompt T02.
- Teste servidor/app com aulas de matemática, linguagem, ciências e história.
- Métrica: porcentagem de aulas com visual gratuito resolvido antes da IA paga.

### Frente 7 — UI da Imagem Como Ferramenta de Estudo

Hoje a imagem aparece. O padrão mundial exige que ela ajude a estudar.

Melhorias:

- Toque para ampliar.
- Zoom/pan da imagem.
- Legenda pedagógica curta.
- Botão "ver imagem" quando ela estiver abaixo do ponto visível.
- Estado de erro discreto e honesto.
- Imagem responsiva para celular e tablet.
- Sem texto inútil "imagem pronta".
- Acessibilidade/Semantics.
- Dark mode correto no painel de imagem.

Entrega:

- `LessonImagePanel` com modo estudável.
- Testes de layout: celular pequeno, tablet, zoom alto, dark mode.
- Tela de inspeção da imagem com zoom/pan e legenda pedagógica.

### Frente 11 — Interatividade Visual

Esta frente vem depois da estabilidade de SVG estático.

Objetivo:

Transformar algumas imagens em mini-explorações, sem virar jogo pesado e sem atrasar a aula.

Exemplos:

- mover ponto em uma reta;
- alterar coeficiente de uma parábola;
- ligar/desligar forças em um bloco;
- ordenar etapas de um ciclo;
- comparar duas colunas;
- tocar em partes de um diagrama para revelar explicação.

Regra:

- Interatividade só entra quando reduz esforço mental e aumenta compreensão.
- Não pode atrasar texto, pergunta, sinais, feedback ou avançar.
- Não pode exigir internet extra.

Entrega:

- `InteractiveVisualWidget`.
- 3 protótipos: parábola, ciclo e comparação.
- Testes de acessibilidade e layout.

### Frente 12 — Image Critic

Criar um avaliador barato antes de publicar imagem.

Ele deve checar:

- a imagem ensina o que a aula pede?
- há texto demais dentro da imagem?
- há risco de entregar a resposta sem raciocínio?
- está adequada ao nível escolar?
- é segura?
- é melhor mostrar esta imagem ou não mostrar nada?

Entrega:

- `ImagePedagogicalCritic`.
- Testes com imagem boa, imagem confusa, imagem decorativa e imagem que entrega resposta.

### Frente 13 — Feedback Loop Pedagógico

O sistema deve aprender operacionalmente com o uso.

Sinais:

- aluno acertou depois da imagem?
- aluno pediu dúvida depois da imagem?
- aluno recusou muita oferta paga?
- imagens de certo tipo estão falhando?
- N3 está mandando para IA paga demais?

Entrega:

- Eventos de uso ligados ao tipo visual.
- Relatório de melhoria do funil.
- Lista de renderizadores que mais precisam evoluir.

### Frente 8 — Observabilidade e Métrica de Eficiência

Sem métrica, o sistema pode parecer funcionar e ainda estar ruim.

Eventos mínimos:

- `VISUAL_TRIGGER_RECEIVED`
- `VISUAL_S12_DECISION`
- `VISUAL_SVG_INLINE_ACCEPTED/REJECTED`
- `VISUAL_TEMPLATE_ACCEPTED/REJECTED`
- `VISUAL_N2_DECISION`
- `VISUAL_N3_DECISION`
- `VISUAL_LOCAL_FALLBACK_ACCEPTED`
- `VISUAL_PAID_OFFER_CREATED`
- `VISUAL_PAID_ACCEPTED/DECLINED`
- `VISUAL_IMAGE_READY/FAILED`

Métricas:

- % de aulas com imagem.
- % resolvida por software.
- % resolvida por IA paga.
- % de ofertas recusadas.
- % de falhas.
- tempo até imagem pronta.
- casos em que imagem chegou depois da pergunta.

Entrega:

- Logs técnicos sem vazar prompt completo ou token.
- Relatório semanal de funil visual.

### Frente 9 — Segurança, Crédito e Cache

Preservar:

- `acceptedOfferId` obrigatório.
- `idempotencyKey` estável.
- Sem imagem paga em prefetch.
- Sem cobrança sem aceite.
- Sem cruzamento de usuário.
- Cache por userId/lessonKey/item/layer/idioma/hash.

Melhorar:

- Provar cache hit sem cobrança.
- Provar duplo toque.
- Provar timeout/refund pelo servidor.
- Provar resource owner.

Entrega:

- Testes de integridade financeira e cache.

### Frente 10 — Prova Real no APK

Nada de B documental.

Cenários obrigatórios no APK:

- Aula sem imagem.
- Parábola por software.
- Função linear por software.
- Fluxograma por software.
- Linha do tempo por software.
- Tabela por software.
- Ciclo por software.
- Caso ambíguo salvo por N3.
- Caso realista virando oferta paga.
- Recusar oferta.
- Aceitar oferta.
- Duplo toque.
- Imagem lenta.
- Troca de item antes da imagem chegar.
- Tablet.
- Celular pequeno.
- Dark mode.
- Zoom alto.

Entrega:

- Checklist APK.
- Screenshots.
- Logs do funil.

## Roadmap de Execução

### Fase 1 — Diagnóstico e Métricas

Objetivo: saber por que não desenhou.

Itens:

- Criar taxonomia visual.
- Fortalecer logs do funil.
- Criar painel/relatório técnico do funil.
- Cobrir 30 cenários de imagem com testes.
- Criar benchmark formal dos melhores apps e o que o SIM deve superar.

Critério de saída:

- Para qualquer aula, o app consegue dizer em qual estágio a imagem caiu.

### Fase 2 — Software Desenha Mais

Objetivo: aumentar a taxa de imagem gratuita.

Itens:

- Expandir templates matemáticos.
- Expandir fallback local.
- Melhorar N2.
- Criar testes por disciplina.
- Criar `SoftwareRenderCatalog`.

Critério de saída:

- Parábola, gráfico, tabela, fluxograma, ciclo, linha do tempo e comparação desenham sem IA paga.

### Fase 3 — N3 Pedagógico

Objetivo: resolver ambíguos baratos antes da IA paga.

Itens:

- Atualizar contrato N3.
- Melhorar prompt N3.
- Fazer N3 devolver SVG limpo quando possível.
- Criar testes contra preguiça de N3.

Critério de saída:

- Casos ambíguos comuns deixam de virar oferta paga quando são desenháveis.

### Fase 4 — T02 Visual Mais Forte

Objetivo: melhorar o que chega ao app.

Itens:

- Auditar prompt T02.
- Fazer T02 produzir `math_template` e `svg_payload` quando apropriado.
- Preservar segurança e arquitetura.

Critério de saída:

- Mais imagens resolvidas nos estágios 1 e 2 do funil.

### Fase 5 — UI Estudável

Objetivo: imagem como instrumento de aprendizagem.

Itens:

- Zoom/pan.
- Legenda curta.
- Dark mode.
- Semantics.
- Layout tablet/celular.
- Botão de localizar imagem se necessário.
- Tela de inspeção de imagem.
- Legenda pedagógica por função visual.

Critério de saída:

- A imagem é confortável de estudar no APK real.

### Fase 6 — Segurança e Prova Final

Objetivo: provar que não cobra errado e não mistura mídia.

Itens:

- Crédito/idempotência.
- Cache.
- Resource owner.
- APK real.

Critério de saída:

- B só se imagem apareceu e crédito ficou correto.

## Definição de Pronto

O projeto só está pronto quando:

- A imagem aparece no APK real.
- O software desenha muito mais que hoje.
- O app sabe justificar por que desenhou ou por que ofereceu IA.
- IA paga só aparece quando é realmente necessária.
- Nenhum fluxo cobra sem aceite.
- Imagem não atrapalha pergunta, sinais, feedback ou avançar.
- Tablet, celular, zoom alto e dark mode funcionam.
- Testes e build passam.
- Casos reais de aula provam o funil.

## Primeira Execução Recomendada

Começar pela Fase 1 e Fase 2:

1. Criar taxonomia visual.
2. Melhorar N2 com score/confiança.
3. Expandir fallback local para fluxograma, linha do tempo, tabela, comparação e ciclos.
4. Adicionar testes para 30 casos reais.
5. Medir quantos casos deixam de virar oferta paga.

Isso dá ganho direto de eficiência sem mexer em crédito, sem chamar IA paga, sem quebrar arquitetura e sem depender de mudança de prompt antes da hora.

## Primeira Sprint Implementável

Escopo pequeno, de alto impacto:

1. Criar `VisualPedagogicalRole`.
2. Criar `SoftwareRenderCatalog`.
3. Migrar `local_visual_fallback.dart` para usar renderizadores nomeados.
4. Implementar cinco renderizadores:
   - `TimelineRenderer`
   - `FlowchartRenderer`
   - `ComparisonRenderer`
   - `CycleRenderer`
   - `TableRenderer`
5. Adicionar score/confiança ao N2.
6. Criar 30 testes de aula real.
7. Garantir que nenhum desses casos chama IA paga.

Critério de aceite:

- Pelo menos 30 cenários comuns geram SVG gratuito.
- Logs mostram renderer escolhido.
- Parábola continua funcionando.
- Oferta paga continua segura.
- `flutter analyze` e `flutter test` passam.

## Fontes Externas

- Brilliant: https://brilliant.org/
- Khanmigo/Khan Academy: https://khanmigo.ai
- Photomath: https://photomath.com/
- GeoGebra: https://www.geogebra.org/

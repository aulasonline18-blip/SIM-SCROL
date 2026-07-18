# SIM - Motor de Travessia

Data: 2026-07-02
Repositorio: `/root/sim-mobile-fluter`
Repositorio servidor relacionado: `/root/sim-work/sim-api`
Status: diretriz construtiva. Nenhum comportamento de runtime foi alterado por este documento.

## 1. Nova definicao central

O SIM nao deve ser entendido apenas como uma ferramenta que "ensina bem".

O SIM deve ser entendido como um motor de travessia: um sistema que pega um aluno em um ponto de baixa clareza, baixa energia, baixa tolerancia a frustracao ou baixa motivacao, e o conduz por uma sequencia de passos pequenos ate ele sair do outro lado com conhecimento utilizavel em uma prova, concurso, vestibular, exame, livro ou tarefa real.

Ensinar continua sendo obrigatorio, mas deixa de ser o centro isolado. O centro passa a ser conduzir o aluno ate o dominio real.

Em termos simples:

- O conteudo e a estrada.
- A IA e o professor que prepara cada trecho.
- A tela, o som e a imagem sao instrumentos de conducao.
- A pergunta nao e castigo; e um passo ativo de memoria e movimento.
- O feedback nao e julgamento; e reposicionamento.
- A recompensa nao e enfeite; e evidencia perceptivel de avancar.
- O objetivo final nao e "ver aula"; e atravessar o caminho ate conseguir responder fora do SIM.

## 2. Aluno-alvo de projeto

O desenho deve assumir o pior caso razoavel:

- adolescente ou adulto com baixa motivacao para estudar;
- acostumado a estimulos curtos, intensos e baratos;
- pouca paciencia para atraso, texto longo e erro repetido;
- possivel ansiedade, vergonha, resistencia, TDAH, dislexia, autismo, baixa escolaridade ou historico ruim com estudo;
- precisa estudar para algo real, com padrao externo real.

Se o SIM funcionar para esse aluno, tende a funcionar melhor para todos os outros.

Isso nao autoriza padroes manipulativos. O SIM deve usar recompensa, clareza e microprogresso sem transformar estudo em cassino, rolagem infinita ou dependencia artificial.

## 3. Fundamentos externos usados

Esta diretriz usa estes principios, aplicados de forma pratica:

- Teoria da autodeterminacao: motivacao melhora quando o aluno sente competencia, autonomia e vinculo. Fonte: Ryan e Deci, Self-Determination Theory, American Psychologist/PubMed: https://pubmed.ncbi.nlm.nih.gov/11392867/ e PDF: https://selfdeterminationtheory.org/SDT/documents/2000_RyanDeci_SDT.pdf
- Pratica de recuperacao: lembrar ativamente fortalece aprendizagem mais do que apenas reler. Fonte: Karpicke e Roediger, Science 2008/PubMed: https://pubmed.ncbi.nlm.nih.gov/18276894/
- Pratica distribuida e testes praticos: entre as tecnicas de maior utilidade para aprendizagem ampla. Fonte: Dunlosky et al., Psychological Science in the Public Interest: https://journals.sagepub.com/doi/abs/10.1177/1529100612453266
- Carga cognitiva: quando a memoria de trabalho e sobrecarregada, o aluno trava; a solucao e sequenciar, reduzir ruido e mostrar exemplos. Fonte: NSW practice guide: https://education.nsw.gov.au/content/dam/main-education/about-us/educational-data/cese/2017-cognitive-load-theory-practice-guide.pdf
- UDL: oferecer multiplas formas de engajamento, representacao e acao/expressao aumenta acesso a aprendizagem significativa. Fonte: CAST UDL Guidelines 3.0: https://udlguidelines.cast.org/
- Multimidia: imagem, texto e audio ajudam quando reduzem carga e segmentam o conteudo, nao quando decoram. Fonte: Mayer, teoria cognitiva da aprendizagem multimidia: https://link.springer.com/article/10.1007/s10648-023-09842-1
- Flow: engajamento sustentado depende de desafio ajustado a habilidade, objetivo claro e feedback rapido. Fonte: revisao em PMC: https://pmc.ncbi.nlm.nih.gov/articles/PMC7033418/

## 4. O que o SIM ja tem alinhado com esse centro

O app ja possui bastante estrutura compativel com o Motor de Travessia.

### 4.1. Entrada viva do aluno

Arquivos principais:

- `lib/features/onboarding/onboarding_screens.dart`
- `lib/features/onboarding/preparation_and_placement.dart`
- `lib/sim/experience/student_experience_engine.dart`
- `lib/sim/experience/student_experience_t00_adapter.dart`
- `/root/sim-work/sim-api/src/t00/bootstrap-controller.js`
- `/root/sim-work/sim-api/prompts/t00.txt`

Estado atual:

- recebe objetivo em texto;
- recebe anexos de imagem/PDF/texto extraido;
- roda T00 em streaming;
- gera perfil, curriculo e primeiro item;
- registra eventos de experiencia.

Leitura pelo novo eixo:

Essa parte e a recepcao do aluno na travessia. Ela nao deve apenas perguntar "o que voce quer estudar?", mas entender "qual caminho precisamos atravessar, com qual nivel de atrito e quais riscos de abandono?".

### 4.2. Curriculo em micro-itens

Arquivos principais:

- `lib/sim/state/student_learning_state.dart`
- `lib/sim/experience/partial_curriculum_writer.dart`
- `/root/sim-work/sim-api/prompts/t00.txt`

Estado atual:

- curriculo vem em micro-itens com `marker`, titulo e proposito;
- T00 ja tem regras para nao reduzir muitos exercicios a um tema generico;
- existe minimo de itens e progressao por dificuldade.

Leitura pelo novo eixo:

O curriculo ja e uma trilha. Falta transformar cada micro-item em um "trecho atravessavel", com contrato de entrada, microvitoria, risco de bloqueio e criterio de saida.

### 4.3. Aula em camadas

Arquivos principais:

- `lib/sim/state/student_learning_state.dart`
- `lib/sim/state/learning_decision_engine.dart`
- `lib/sim/classroom/lesson_answer_progress_controller.dart`
- `/root/sim-work/sim-api/prompts/t02.txt`

Estado atual:

- existem camadas L1/L2/L3;
- resposta correta, erro e sinal 1/2/3 influenciam avanco;
- `LearningDecisionEngine` decide avancar camada, avancar item, reforcar ou concluir;
- T02 respeita item exato, camada e padrao real de prova.

Leitura pelo novo eixo:

Esse e o esqueleto do condutor. Falta uma camada explicita de "estado de travessia", que interprete nao apenas dominio, mas movimento, atrito, cansaco, inseguranca e risco de abandono.

### 4.4. Amparo, recuperacao e duvida

Arquivos principais:

- `lib/sim/classroom/amparo_controller.dart`
- `lib/sim/auxiliary/*`
- `/root/sim-work/sim-api/prompts/adendo_amparo_t02.txt`
- `/root/sim-work/sim-api/prompts/adendo_recovery.txt`
- `/root/sim-work/sim-api/prompts/adendo_doubt.txt`

Estado atual:

- ha amparo depois de erros/sinal 3;
- ha salas auxiliares de revisao, recuperacao e duvida;
- o prompt de amparo ja diz explicitamente: "nao e ensinar, e guiar"; "objetivo e travessia".

Leitura pelo novo eixo:

O melhor texto conceitual do novo SIM ja existe no amparo. O erro arquitetural e que essa filosofia esta isolada em um modo especial. Ela precisa subir para o contrato central de todo o produto.

### 4.5. Recompensa operacional e prontidao

Arquivos principais:

- `lib/sim/lesson/dopamine_ready_window_engine.dart`
- `lib/sim/lesson/ready_window_worker.dart`
- `lib/sim/lesson/lesson_orchestrator.dart`
- `lib/sim/classroom/lesson_answer_feedback.dart`

Estado atual:

- existe janela "dopamine ready" que prepara proximas aulas;
- feedback responde acerto, erro e inseguranca;
- prefetch reduz espera entre passos.

Leitura pelo novo eixo:

O nome ja aponta para a intencao correta. Mas a recompensa ainda e tecnica: aula pronta, feedback pronto, proximo conteudo pronto. Falta representar microvitorias pedagogicas como objeto de produto e estado.

### 4.6. Tela, imagem e audio

Arquivos principais:

- `lib/features/classroom/aula_screen.dart`
- `lib/features/classroom/aula_widgets.dart`
- `lib/sim/media/student_lesson_media_service.dart`
- `lib/sim/media/lesson_visual_pipeline.dart`
- `lib/sim/media/audio_core.dart`
- `/root/sim-work/sim-api/src/media/image-controller.js`
- `/root/sim-work/sim-api/src/media/audio-controller.js`

Estado atual:

- aula renderiza explicacao, imagem, pergunta, alternativas e sinais;
- existe streaming/typewriter da explicacao;
- imagem e tratada como instrumento pedagogico;
- audio e opcional e nao bloqueante.

Leitura pelo novo eixo:

Tela, som e imagem devem ser coordenados como instrumentos de conducao. O aluno precisa saber sempre: onde estou, qual e o proximo passo, o que acabei de conquistar e por que isso me aproxima do objetivo real.

## 5. Desalinhamentos principais

### D1. A missao ainda esta dividida

Hoje ha documentos e prompts falando em "tutor vivo", "ensinar", "dominio", "amparo" e "travessia". Isso nao e errado, mas a hierarquia ainda nao esta formalizada.

Acao necessaria:

- criar uma Constituicao do SIM;
- declarar o Motor de Travessia como contrato superior;
- fazer T00, T02, UI, estado, amparo, revisao e midia obedecerem ao mesmo centro.

### D2. "Travessia" nao e um objeto de estado

Hoje existem progresso, camada, tentativa, erro, historia, dominio e eventos. Falta um objeto explicito que represente movimento e atrito.

Acao necessaria:

- adicionar `TraversalState` ou equivalente;
- registrar ritmo, atrito, risco de abandono, microvitoria, modo atual e proxima melhor acao;
- persistir isso dentro de `StudentLearningState.extra` inicialmente, depois tipar se estabilizar.

### D3. Motivacao ainda entra como texto de perfil, nao como motor

T00 extrai `motivation_strategy`; T02 recebe `motivation_profile`. Mas o app nao tem um orgao que leia sinais reais da sessao e adapte a conducao.

Acao necessaria:

- criar `MotivationConductor` ou integrar no novo `TraversalConductor`;
- usar eventos reais: erro repetido, sinal 3, tempo parado, pedido de duvida, audio ligado/desligado, imagem aberta, abandono de tela, retorno apos pausa;
- decidir: reduzir passo, mostrar exemplo, abrir amparo, revisar, trocar representacao, pausar com retorno planejado.

### D4. Recompensa ainda nao e suficientemente concreta

Feedback existe, mas microvitoria nao e entidade. O aluno deve sentir avancos pequenos e reais, sem excesso visual.

Acao necessaria:

- criar `MicroVictory`;
- exemplos: "voce reconheceu a ideia", "voce diferenciou a armadilha", "voce aplicou em caso real", "voce recuperou o passo que travava";
- conectar microvitoria com `ITEM_MASTERED`, `MASTERY_EVALUATED`, `REINFORCEMENT_REQUIRED` e `NEXT_ACTION_DECIDED`.

### D5. A pergunta ainda pode parecer teste, nao movimento

Do ponto de vista cientifico, pergunta e correta: retrieval practice e essencial. Do ponto de vista emocional, para o aluno resistente, pergunta pode parecer cobranca.

Acao necessaria:

- a UI e o texto devem enquadrar pergunta como "passo de avancar";
- a pergunta deve ser curta, justa e no nivel certo;
- erro deve abrir caminho, nao encerrar energia;
- sinal 3 deve ser tratado como dado nobre, nao fracasso.

### D6. Preparacao inicial ainda nao captura perfil de atrito suficiente

O onboarding aceita texto livre, o que e bom. Mas faltam campos leves ou inferencias mais explicitas sobre:

- prazo;
- prova real;
- nivel de urgencia;
- tolerancia a texto;
- preferencia por audio/imagem;
- historico de dificuldade;
- se o aluno quer comecar do zero ou atacar lista/prova.

Acao necessaria:

- manter entrada livre como principal;
- adicionar chips opcionais de baixo atrito, sem formulario pesado;
- enviar isso a T00/T02 como perfil de conducao.

### D7. Observabilidade pedagogica ainda nao mede travessia

Ha eventos locais. Falta painel/telemetria orientada a abandono, bloqueio e avanco.

Acao necessaria:

- eventos: `TRAVERSAL_STEP_STARTED`, `TRAVERSAL_STEP_COMPLETED`, `FRICTION_DETECTED`, `MICRO_VICTORY_SHOWN`, `STUDENT_RETURNED`, `DROP_OFF_RISK`;
- metricas: tempo ate primeira acao, passos por sessao, erros antes de amparo, recuperacoes bem-sucedidas, retorno apos pausa, aula concluida por objetivo.

## 6. Arquitetura alvo

### 6.1. Novo orgao: StudentJourneyConductor

Nome sugerido em Dart:

- `StudentJourneyConductor`
- ou `TraversalConductor`

Responsabilidade:

Ler o estado vivo do aluno e escolher a proxima forma de conducao, sem gerar conteudo e sem substituir motores existentes.

Entrada:

- `StudentLearningState`;
- `DecisionResult`;
- `MasteryEvidence`;
- `StudentExperienceSnapshot`;
- eventos recentes;
- preferencias de audio/imagem;
- perfil T00/T02.

Saida:

- `TraversalDecision`;
- `TraversalState`;
- `MicroVictory?`;
- `FrictionSignal?`;
- recomendacao de modo: normal, curto, amparo, revisao, recuperacao, exemplo resolvido, pausa, retorno.

Regra:

O condutor nao decide verdade pedagogica sozinho. Ele coordena motores ja existentes.

### 6.2. Modelos minimos

```dart
enum TraversalMode {
  normal,
  quickWin,
  guidedStep,
  review,
  recovery,
  amparo,
  doubt,
  pauseAndReturn,
}

enum FrictionKind {
  repeatedWrong,
  repeatedSignalThree,
  longIdle,
  fastAbandon,
  lowConfidence,
  overloadedText,
  mediaNeeded,
  prerequisiteGap,
}

class TraversalState {
  final TraversalMode mode;
  final int stepIndex;
  final int microVictories;
  final List<FrictionKind> recentFriction;
  final String nextBestAction;
  final int updatedAt;
}

class MicroVictory {
  final String id;
  final String marker;
  final LessonLayer layer;
  final String kind;
  final String messageKey;
  final int ts;
}
```

Inicialmente isso pode morar em `StudentLearningState.extra['traversal']`, para evitar migration grande. Quando estabilizar, vira modelo tipado completo.

### 6.3. Relação com orgaos atuais

O novo condutor deve ficar acima destes orgaos:

- `LearningDecisionEngine`: decide progresso academico imediato.
- `MasteryTruthEngine`: decide dominio por evidencia.
- `LessonAnswerProgressController`: registra resposta e aplica decisao.
- `AmparoController`: ativa modo de travessia assistida.
- `DopamineReadyWindowEngine`: garante que o proximo passo esteja pronto.
- `StudentLessonMediaService`: coordena audio.
- `LessonVisualPipeline`: coordena imagem.

O condutor nao substitui esses orgaos. Ele da unidade ao comportamento.

## 7. Novo contrato de prompts

### 7.1. T00

T00 deve gerar curriculo como trilha de travessia.

Adicionar ao contrato:

- perfil de atrito provavel;
- ritmo inicial recomendado;
- primeiros 3 microganhos;
- pontos de bloqueio esperados;
- quando usar imagem/audio;
- quando comecar do zero;
- como preservar padrao real da prova sem esmagar o aluno.

### 7.2. T02

T02 deve continuar ensinando item exato, mas sob a regra superior:

> Ensine o menor trecho que permite movimento real. A pergunta e o passo ativo da travessia. O feedback reposiciona. A meta e manter o aluno em movimento ate dominio real, sem reduzir o padrao final.

O prompt principal `t02.txt` ja tem muitos elementos corretos. O `adendo_amparo_t02.txt` deve deixar de ser apenas excecao e virar fonte de linguagem para o modo normal, sem transformar toda aula em amparo.

### 7.3. Duvida, recuperacao e amparo

Manter contratos separados, mas padronizar a filosofia:

- duvida remove bloqueio;
- recuperacao reconstrui prerequisito;
- amparo restaura movimento;
- revisao consolida memoria;
- aula normal avanca a trilha.

## 8. Produto e UI

### 8.1. A tela da aula deve responder quatro perguntas

Em qualquer momento, sem explicacao extra, o aluno deve perceber:

1. Onde estou?
2. O que eu faco agora?
3. O que eu acabei de conquistar ou corrigir?
4. Como isso me aproxima do objetivo real?

### 8.2. Comportamento ideal por passo

Cada passo da aula deve seguir:

1. Microcontexto: "agora vamos pegar esta parte".
2. Explicacao curta.
3. Visual ou audio se reduzir carga.
4. Pergunta ativa.
5. Sinal de confianca.
6. Feedback/reparacao.
7. Microvitoria ou proxima correcao.
8. Proximo melhor passo preparado.

### 8.3. Recompensa etica

Permitido:

- progresso visivel;
- microvitoria real;
- feedback imediato;
- retorno claro;
- conquistas por dominio;
- linguagem de controle recuperado.

Proibido:

- streak punitivo;
- notificacao manipulativa;
- recompensa por tempo infinito;
- visual cassino;
- vergonha por erro;
- falsa facilidade;
- enfraquecer padrao real para parecer que aprendeu.

## 9. Fases de implementacao

### Fase 1 - Constituicao e contratos

Objetivo:

Formalizar o novo centro de gravidade sem mexer ainda em grandes fluxos.

Tarefas:

- criar documento de Constituicao do SIM baseado nesta diretriz;
- atualizar a Planta-Mae vigente do SIM NV ou criar versao normativa sucessora;
- adicionar secao de Motor de Travessia em `docs/SIM_FLUTTER_CONTRATO_FIO.md`;
- revisar textos centrais de T00/T02 para declarar "conducao ate dominio real";
- mapear strings visiveis que ainda dizem apenas "aula" quando deveriam indicar passo/trilha/progresso.

Criterio de aceite:

- qualquer dev consegue responder: "qual e a missao superior do SIM?";
- nenhum prompt principal contradiz essa missao.

### Fase 2 - Estado de travessia minimo

Objetivo:

Adicionar estado observavel sem refatorar tudo.

Tarefas:

- criar modelos `TraversalState`, `FrictionSignal`, `MicroVictory`;
- gravar snapshot inicial em `StudentLearningState.extra['traversal']`;
- emitir eventos de travessia ao entrar na aula, responder, errar, acertar, pedir duvida, entrar em amparo e avancar;
- adicionar testes unitarios.

Criterio de aceite:

- uma sessao real gera linha do tempo de travessia;
- erro, acerto e sinal 3 aparecem como movimento interpretavel.

### Fase 3 - StudentJourneyConductor

Objetivo:

Criar o orgao central de conducao.

Tarefas:

- implementar `StudentJourneyConductor`;
- integrar apos `MasteryTruthEngine` e `LearningDecisionEngine`;
- decidir modo: normal, quickWin, guidedStep, review, recovery, amparo;
- manter compatibilidade com fluxo atual.

Criterio de aceite:

- o app consegue justificar a proxima melhor acao em linguagem de produto e em evento tecnico;
- nenhuma decisao pedagogica fica escondida em widget.

### Fase 4 - UI da microvitoria

Objetivo:

Fazer o aluno sentir avanco real sem poluir a tela.

Tarefas:

- adicionar componente discreto de microvitoria;
- conectar com `ITEM_MASTERED`, `MASTERY_EVALUATED` e `TraversalState`;
- ajustar feedback para "reposicionar e conduzir";
- garantir acessibilidade, dark mode e ausencia de layout shift.

Criterio de aceite:

- depois de cada resposta, ha feedback claro e proxima acao clara;
- acerto, erro e "nao sei" nao deixam o aluno sem caminho.

### Fase 5 - Onboarding orientado a atrito

Objetivo:

Capturar melhor o caminho sem transformar entrada em formulario pesado.

Tarefas:

- adicionar chips opcionais: prova/prazo, comecar do zero, lista de exercicios, dificuldade, pouco tempo, prefiro audio, prefiro imagem;
- enviar ao T00 como `motivation_profile`, `attention_profile`, `real_use_goal`, `known_weaknesses`;
- manter texto livre como fonte principal.

Criterio de aceite:

- T00 recebe dados suficientes para planejar travessia, nao apenas tema.

### Fase 6 - Prompt T00/T02 v2

Objetivo:

Fazer a IA produzir conteudo sob o contrato de travessia.

Tarefas:

- T00: gerar `TRAVERSAL_PLAN` ou campos equivalentes;
- T02: incluir microconducao, microvitoria esperada e risco de bloqueio;
- manter JSON/contratos estaveis;
- atualizar normalizadores e testes do servidor.

Criterio de aceite:

- T02 normal nao vira amparo, mas sempre respeita a postura de conducao;
- conteudo continua preparado para padrao real externo.

### Fase 7 - Revisao espacada e retorno

Objetivo:

Transformar aprendizagem em permanencia de conhecimento.

Tarefas:

- criar `SpacedReviewScheduler`;
- agendar revisoes leves por dominio/sinal/erro;
- inserir revisao dentro da trilha, nao como sala esquecida;
- criar retorno inteligente: "vamos retomar pelo ultimo ponto seguro".

Criterio de aceite:

- o aluno nao apenas conclui tela; ele reencontra pontos antes de esquecer.

### Fase 8 - Observabilidade de travessia

Objetivo:

Medir se o SIM conduz mesmo.

Tarefas:

- instrumentar eventos locais e servidor;
- criar export de diagnostico;
- medir drop-off, stuck states, tempo ate primeiro passo, recuperacao bem-sucedida, retorno apos pausa;
- preparar painel simples para dev/responsavel.

Criterio de aceite:

- quando um aluno trava, o sistema mostra onde e por que.

## 10. Ordem recomendada agora

Proxima frente ideal:

1. Implementar Fase 1 e Fase 2 juntas.
2. Nao mexer ainda em grandes telas.
3. Criar estado/eventos de travessia com testes.
4. Depois integrar o `StudentJourneyConductor`.
5. So entao mudar UI e prompts em profundidade.

Motivo:

Sem estado e contrato, qualquer mudanca visual vira opiniao. Com estado de travessia, cada ajuste passa a responder: isso move o aluno, reduz atrito, preserva padrao real e registra evidencia?

## 11. Criterios finais do novo SIM

O SIM esta alinhado ao Motor de Travessia quando:

- o aluno nunca fica sem proxima acao clara;
- cada resposta gera progresso, recuperacao ou explicacao de rota;
- erro nao quebra movimento;
- sinal 3 ativa ajuda, nao punicao;
- pergunta e usada como pratica de memoria, nao como humilhacao;
- imagem e audio reduzem carga, nao decoram;
- a trilha preserva padrao real de prova;
- o app sabe retomar de onde o aluno parou;
- o sistema mede abandono e bloqueio;
- o aluno sai capaz de enfrentar tarefa real fora do SIM.

## 12. Frase constitucional

O SIM existe para conduzir o aluno, passo por passo, por uma travessia de aprendizagem real. Ele usa IA, tela, som, imagem, pergunta, feedback, recuperacao e revisao para manter movimento, restaurar controle quando houver bloqueio e construir dominio verificavel sem reduzir o padrao do mundo real.

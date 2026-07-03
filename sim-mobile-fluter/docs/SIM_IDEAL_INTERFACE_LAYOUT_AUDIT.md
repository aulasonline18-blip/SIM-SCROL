# SIM Ideal - Auditoria de Interface, Layout e Funcionamento do Flutter

Data: 2026-07-02

Escopo: leitura do app Flutter atual, mirando o novo Ponto B definido pelo dono: nao mais "igual ao SimWeb", mas sim um app de aprendizagem de nivel mundial, com atrito minimo, legibilidade alta, responsividade real, botoes confiaveis e experiencia pronta para primeira distribuicao no Google Play.

## 1. Conclusao executiva

O Flutter ja tem uma base funcional importante: sala de aula real, estado canonico, audio, imagem, duvida, revisao, recuperacao, drawer, escala de fonte, testes de Semantics e testes de visibilidade em tela pequena. Isso e uma base boa.

Mas o layout ainda nao esta no nivel de um "melhor app do mundo para aprender". O problema principal nao e uma tela isolada. O problema e que a interface ainda nao tem um sistema visual e ergonomico unificado o suficiente. Existem muitos tamanhos, paddings, raios, estilos de botao e decisoes de layout espalhados por arquivos grandes. Funciona em muitos cenarios, mas ainda nao tem a previsibilidade, adaptacao e polimento de um produto de aprendizagem premium.

B ideal ainda e NAO.

Motivo: falta uma camada de design system responsivo, falta layout proprio para tablet, falta prova visual sistematica por viewport, falta padrao unico de botoes/estados, falta auditoria completa de toque/acessibilidade, e algumas telas ainda parecem "portadas" em vez de desenhadas para o fluxo de estudo ideal.

## 2. O que ja esta saudavel e deve ser preservado

1. Arquitetura de estado e aula separada da UI.
   - `LabSession`, `LessonRuntimeEngine`, `StudentLearningState` e controllers mantem a UI longe da logica pedagogica pesada.
   - Preservar: a UI deve continuar consumindo estado, nao virar motor pedagogico.

2. Sala de aula com fluxo real.
   - A aula tem teoria, pergunta, alternativas, sinais, feedback, duvida, avancar, revisao e recuperacao.
   - Isso e melhor do que uma tela estatica de pergunta.

3. Tratamento de imagem na UI ja tem base correta.
   - `LessonImagePanel` aceita SVG, dataUrl e URL.
   - Imagem pronta dispara `onImageSettled`, e a aula recalcula scroll.
   - Erro de imagem aparece como erro de imagem, nao como erro pedagogico.

4. Audio ja tem politicas importantes.
   - Ao trocar item/layer, sair da aula e app ir para background, o audio para.
   - Bolha depende de `audioPlaying`.

5. Fonte ajustavel ja existe.
   - `ClassroomTextScale` tem 5 niveis e persistencia.
   - Existem testes para zoom alto, sinais, feedback e botao avancar visiveis em tela pequena.

6. Testes de sala ja cobrem pontos criticos.
   - Ha testes para Semantics, escala de fonte, bolha de audio, sinais sob alternativa ativa, feedback visivel, drawer e fluxo de duvida.

## 3. Lacunas para um app de aprendizagem ideal

### P0 - Sistema visual unificado

Hoje ha constantes globais de cor e sombra em `sim_constants.dart`, mas ainda falta um design system real:

- escala tipografica oficial;
- espacamentos oficiais;
- tamanhos minimos de toque;
- breakpoints;
- raios;
- altura de botoes;
- largura de leitura;
- estados: loading, disabled, pressed, error, success;
- componentes canonicos para botao, card, input, topbar, drawer e painel de midia.

Risco atual: cada tela decide seus numeros. Isso cria pequenas diferencas que, somadas, fazem o app parecer menos preciso.

Direcao: criar `SimTheme`, `SimSpacing`, `SimTypography`, `SimBreakpoints` e componentes canonicos. Nao colocar logica no `main.dart`; manter como camada de UI.

### P0 - Responsividade real para tablet

Hoje o app centraliza tudo em uma coluna estreita. `SimFrame` limita a largura maxima em 480 px, e `CyberStepShell` usa 576 px. Isso e aceitavel para celular, mas pobre para tablet.

No app ideal:

- celular usa uma coluna focada;
- tablet usa layout de duas areas quando fizer sentido;
- sala de aula pode ter conteudo principal + painel lateral de progresso/historico;
- drawer em tablet pode virar painel persistente;
- imagem pode ganhar mais area sem esconder pergunta;
- teclado, rotacao e paisagem precisam ser tratados.

Risco atual: em tablet, o app parece apenas um telefone esticado no centro.

### P0 - Sala de aula como superficie de estudo premium

A sala atual funciona, mas ainda precisa de refinamento:

- hierarquia visual mais clara entre teoria, imagem, desafio, sinais e feedback;
- menos dependencia de cards parecidos para tudo;
- topbar mais util e menos comprimida em telas pequenas;
- feedback e proximo passo com peso visual mais claro;
- estados de geracao de aula, imagem, audio e duvida visualmente distintos;
- espaco reservado para midia sem causar salto visual excessivo;
- "Dúvida" precisa parecer ferramenta principal de aprendizagem, nao botao secundario solto.

Meta ideal: o aluno deve bater o olho e saber exatamente: onde estou, o que estou aprendendo, o que devo responder agora, o que aconteceu, e qual e o proximo passo.

### P0 - Botoes e toque

Ha muitos `GestureDetector` em acoes que sao botoes. Alguns tem `Semantics`, mas nem todos herdam comportamento nativo de foco, ripple, teclado, desabilitado e acessibilidade.

No app ideal:

- botao deve ser `ButtonStyleButton`, `InkWell` bem configurado ou componente canonico;
- alvo minimo de toque: 48x48;
- estado desabilitado deve ser visual e semantico;
- duplo toque deve ser bloqueado quando ha operacao em andamento;
- todos os botoes importantes precisam de feedback visual imediato;
- testes devem provar que tocar duas vezes nao duplica acao sensivel.

### P0 - Tipografia de aprendizagem

O app usa Inter no tema e JetBrains Mono para labels tecnicos. Isso e bom, mas os tamanhos estao espalhados. A sala de aula usa texto de explicacao em 15 px antes da escala, pergunta 15 px, alternativa 16 px, historico 18 px. Precisa de regra pedagogica.

No app ideal:

- explicacao deve ter largura de leitura controlada;
- linha deve respirar bem;
- pergunta deve ter peso maior que metadados, menor que hero;
- alternativa precisa ser escaneavel sem parecer card de marketing;
- labels tecnicos devem ser pequenos, mas nao ilegíveis;
- escala de fonte deve respeitar sistema e preferencia do app, sem quebrar layout.

### P1 - Onboarding como coleta inteligente de objetivo

O onboarding coleta idioma, nome, objetivo e anexos. Mas para o SIM Ideal, ele precisa capturar melhor:

- nivel escolar;
- prova/meta real;
- curriculo oficial;
- conhecimento previo;
- dificuldades conhecidas;
- prazo;
- formato preferido de estudo;
- idioma de estudo;
- necessidade de acessibilidade.

Isso nao precisa virar questionario pesado. Precisa ser uma conversa guiada, curta e inteligente.

Impacto: melhora T00/T02, qualidade da aula, imagens, audio e revisao.

### P1 - Estados de erro e recuperacao

Ha estados de erro, mas ainda falta padrao unico:

- erro tecnico discreto para aluno;
- diagnostico tecnico preservado para suporte;
- retry claro;
- diferenciar sem credito, sem internet, servidor ocupado, erro de auth, timeout, erro de imagem, erro de audio;
- nunca deixar loading infinito.

O app ideal nao assusta o aluno, mas tambem nao esconde diagnostico.

### P1 - Acessibilidade completa

Ja existem Semantics em acoes importantes, mas ainda falta auditoria ampla:

- todos os controles interativos;
- labels de imagem e audio;
- ordem de leitura por leitor de tela;
- contraste;
- movimento reduzido;
- touch target;
- estado selecionado;
- feedback falado/semantico depois de resposta;
- navegacao por teclado em tablet/Chromebook.

### P1 - Prova visual automatizada

Os testes atuais sao bons, mas ainda nao bastam para "melhor do mundo".

Faltam provas por screenshot/golden ou equivalente em:

- celular pequeno;
- celular medio;
- tablet retrato;
- tablet paisagem;
- zoom maximo;
- texto longo;
- pergunta longa;
- alternativas longas;
- imagem 1:1;
- imagem 16:9;
- SVG matematico;
- erro de imagem;
- audio carregando/tocando/erro;
- drawer aberto;
- teclado aberto na duvida;
- onboarding com anexo.

### P1 - Google Play readiness de experiencia

Antes de Play Store, precisa checklist de produto:

- icone final legivel;
- nome do app consistente;
- splash sem tela preta estranha;
- primeira abertura sem travar;
- login funcionando;
- logout/conta;
- privacidade/termos/exclusao acessiveis;
- permissao de camera/galeria com explicacao;
- comportamento offline ou erro claro;
- links externos seguros;
- Android back button em todas as telas;
- deep link de login;
- bundle/release assinado;
- crash/logging basico.

### P2 - Polimento visual

O visual atual e limpo, mas ainda pode ficar mais proprio do SIM:

- reduzir sensacao de "tudo em card";
- usar mais superficie de leitura e menos moldura;
- melhorar identidade visual sem poluir a aula;
- tornar progresso mais compreensivel;
- fazer imagens e diagramas parecerem parte natural da explicacao;
- diferenciar revisao, recuperacao e duvida sem parecer outro app.

## 4. Arquitetura: preservar ou mudar?

Preservar:

- `LabSession` como fachada de experiencia;
- motores de aula/estado fora da UI;
- `StudentLearningState` como memoria canonica;
- midia assincrona;
- audio/imagem nao bloqueando texto;
- Flutter consumindo contrato, nao decidindo pedagogia central pesada.

Mudar com cuidado:

- criar camada de design system;
- quebrar arquivos grandes de UI em componentes menores;
- trocar `GestureDetector` por componentes canonicos de acao;
- criar layout adaptativo para tablet;
- adicionar testes visuais e de interacao.

Nao recomendo refatorar a arquitetura pedagogica agora. Recomendo refatorar a arquitetura de UI.

## 5. Plano de execucao recomendado

### Fase 1 - Fundacao visual e responsiva

Criar tokens e componentes canonicos:

- `SimTheme`;
- `SimSpacing`;
- `SimTypography`;
- `SimBreakpoints`;
- `SimActionButton`;
- `SimIconButton`;
- `SimCardSurface`;
- `SimStatusBanner`;
- `SimLearningScaffold`.

Migrar primeiro sala de aula e onboarding, sem mudar comportamento pedagogico.

### Fase 2 - Sala de aula ideal

Redesenhar a ergonomia da aula:

- topbar responsiva;
- largura de leitura por viewport;
- imagem integrada;
- pergunta e alternativas mais escaneaveis;
- feedback mais claro;
- duvida como ferramenta principal;
- botao avancar sempre previsivel;
- audio e bolha honestos e nao invasivos.

### Fase 3 - Tablet e paisagem

Implementar layout dedicado:

- tablet com painel lateral opcional;
- drawer persistente quando houver espaco;
- imagem maior sem tomar fluxo;
- historico e progresso em coluna secundaria;
- teclado e duvida sem cobrir conteudo essencial.

### Fase 4 - Acessibilidade e Google Play

Fechar:

- Semantics completa;
- contraste;
- motion reduzido;
- Android back;
- permissoes;
- estados de erro;
- splash/icone/nome;
- Play Store checklist.

### Fase 5 - Prova visual

Adicionar testes:

- screenshots/golden;
- widget tests por viewport;
- testes de toque em todos os botoes;
- testes de erro/loading;
- testes com texto grande e fonte maxima.

## 6. Lista objetiva de proximas correcoes

P0:

1. Criar design system Flutter do SIM.
2. Definir breakpoints e layout tablet.
3. Padronizar botoes e trocar acoes principais baseadas em `GestureDetector`.
4. Reorganizar sala de aula com hierarquia visual de estudo.
5. Garantir que todos os estados de loading/erro/sucesso tenham componente padrao.
6. Criar testes visuais para celular pequeno, celular normal e tablet.

P1:

7. Melhorar onboarding para coletar campos ricos sem cansar.
8. Padronizar tipografia da aula.
9. Auditar Semantics completa.
10. Melhorar drawer/historico para estudo recorrente.
11. Fortalecer UX de duvida com foto/anexo.
12. Criar checklist Play Store dentro do repo.

P2:

13. Polir identidade visual.
14. Melhorar animacoes com suporte a reduzir movimento.
15. Criar estados vazios mais humanos.
16. Melhorar telas legais/credito/pai para parecerem parte do mesmo produto.

## 7. Status final desta auditoria

Estamos em B ideal? NAO.

O app esta quebrado? NAO.

O app ja tem base para virar ideal? SIM.

O que impede o B ideal agora:

- falta sistema visual canonico;
- falta layout tablet real;
- falta prova visual sistematica;
- falta padronizacao de botoes/estados;
- falta refinamento ergonomico da sala de aula;
- falta auditoria completa de acessibilidade e Play Store.

Codigo funcional alterado nesta auditoria: NAO.

Documento criado: `docs/SIM_IDEAL_INTERFACE_LAYOUT_AUDIT.md`.

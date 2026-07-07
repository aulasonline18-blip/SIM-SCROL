# EVENTO A — SIM App 100% em Concordancia com a Planta-Mae

## Fonte de Verdade

Este documento define o que precisa ser verdadeiro para declarar:

**Evento A = VERDADEIRO**

> O SIM App esta 100% em concordancia com a Planta-Mae do SIM Ideal.

Este documento nao descreve uma melhoria isolada. Ele descreve o estado-alvo constitucional do SIM App. Toda implementacao, auditoria, teste, commit, APK e validacao futura deve usar este documento como referencia.

---

## 1. Definicao do Evento A

O Evento A so pode ser considerado verdadeiro quando o SIM App, em funcionamento real, provar que obedece a Planta-Mae em todos os pontos essenciais:

1. O SIM App nao e chatbot.
2. O SIM App nao e quiz superficial.
3. O SIM App e uma interface operacional de um sistema pedagogico adaptativo supervisionado.
4. A IA gera conteudo, mas nao governa o estado final do aluno.
5. O software governa fluxo, progresso, validacao, revisao, recuperacao e memoria.
6. O aluno avanca apenas quando ha evidencia real de aprendizagem.
7. O Pai pode supervisionar progresso real, nao apenas telas vistas.
8. A primeira aula chega rapido.
9. Texto da aula nao espera imagem, audio, curriculo gigante ou cache pesado.
10. O sistema funciona de modo aceitavel em celular fraco e internet ruim.

Se qualquer item acima for falso, o Evento A e falso.

---

## 2. Principio Supremo

O SIM App deve ser simples para o aluno e rigoroso por dentro.

O aluno ve:

- explicacao;
- pergunta;
- alternativas A/B/C;
- sinais de confianca;
- feedback humano;
- revisao;
- recuperacao;
- progresso claro.

O aluno nao ve:

- JSON;
- logs;
- payload;
- engine;
- state;
- layer como jargao tecnico;
- erro bruto;
- decisao interna da IA.

Por dentro, o App deve manter estado, eventos, progresso, tentativas, revisoes, recuperacoes, cache e sincronizacao de forma rastreavel.

---

## 3. Separacao Constitucional de Poderes

### 3.1 Pai

No App, o Pai aparece como governanca, leis, testes e bloqueios. Ele garante:

- que o aluno dificil nao seja abandonado;
- que falsa maestria seja detectada;
- que progresso nao seja inventado;
- que revisao e recuperacao existam;
- que a IA nao decida sozinha;
- que o aluno nao avance sem evidencia.

### 3.2 Assistente

No App, o Assistente e o software operacional. Ele deve governar:

- rota;
- estado local;
- item atual;
- camada atual;
- historico;
- tentativas;
- progresso;
- cache;
- fila;
- revisao;
- recuperacao;
- duvida;
- sincronizacao;
- restauracao.

O Assistente pode estar dividido entre App e servidor, mas o contrato precisa ser claro. Nao pode haver dois donos conflitantes do progresso.

### 3.3 Tutor

O Tutor e a IA. Ele pode gerar:

- interpretacao de objetivo;
- curriculo;
- aula;
- pergunta;
- alternativas;
- feedback;
- imagem;
- audio;
- revisao;
- recuperacao;
- amparo.

O Tutor nao pode:

- salvar progresso final sozinho;
- decidir conquista;
- apagar estado;
- pular etapa;
- substituir o software;
- governar rota;
- validar dominio sem o Advance Gate.

---

## 4. Estado-Alvo do SIM App

Para o Evento A ser verdadeiro, o SIM App deve ter estes motores funcionando em conjunto:

1. Motor de Onboarding.
2. Motor de Idioma.
3. Motor de Navegacao.
4. Motor de Layout Responsivo.
5. Motor Conversacional.
6. Motor Pedagogico.
7. Motor de Estado do Aluno.
8. Motor de Imagem.
9. Motor de Audio.
10. Motor de Revisao.
11. Motor de Recuperacao.
12. Motor de Duvida.
13. Motor de Cache e Fila.
14. Motor de Sincronizacao e Backup.
15. Motor de Pai/Supervisao.
16. Motor de Erro/Retry/Recovery.

Nao basta cada motor existir isolado. Eles precisam estar conectados, testados e obedecer a mesma constituicao.

---

## 5. Fluxo Constitucional Obrigatorio

O fluxo minimo do SIM App deve ser:

1. App abre.
2. Le estado local.
3. Restaura sessao se houver.
4. Se nao houver idioma, pede idioma.
5. Se nao houver objetivo, pede objetivo.
6. Interpreta objetivo.
7. Confirma plano.
8. Prepara curriculo inicial pequeno.
9. Prepara primeira aula.
10. Mostra texto assim que estiver pronto.
11. Mostra imagem apenas se estiver pronta ou se for opcional.
12. Aluno responde A/B/C.
13. Aluno informa sinal 1/2/3.
14. Sistema registra tentativa.
15. Sistema valida acerto e confianca.
16. Sistema decide proximo passo.
17. Sistema salva estado.
18. Sistema mostra feedback.
19. Sistema agenda revisao ou recuperacao quando necessario.
20. Sistema prepara proximo material.

Qualquer fluxo que pule objetivo, curriculo, validacao, tentativa, sinal, estado ou decisao pedagogica torna o Evento A falso.

---

## 6. Motor Pedagogico Obrigatorio

O SIM App deve ensinar por microitem, nao por tela.

Cada microitem deve ter:

- identidade propria;
- marker ou itemId estavel;
- texto pedagogico;
- camada;
- pergunta;
- alternativas;
- gabarito;
- historico de tentativas;
- estado de dominio;
- relacao com revisao/recuperacao.

O aluno responde sempre em duas dimensoes:

- alternativa escolhida: A, B ou C;
- sinal de confianca: 1, 2 ou 3.

O sistema deve registrar tentativa com:

- marker;
- layer;
- letra;
- sinal;
- correct;
- timestamp.

O App deve tratar diferentemente:

- acerto com certeza;
- acerto com duvida;
- acerto inseguro;
- erro com certeza;
- erro com duvida;
- erro inseguro;
- erro repetido;
- acerto apos erro;
- falsa maestria.

Acertar uma vez nao e dominio.

---

## 7. Advance Gate

O SIM App precisa ter um portao de avanco.

O aluno so pode avancar quando o software tiver evidencia suficiente.

O Advance Gate deve considerar:

- acerto;
- erro;
- sinal de confianca;
- camada;
- historico de tentativas;
- marcador do item;
- fragilidade ativa;
- revisao pendente;
- recuperacao pendente;
- dominio real;
- falsa maestria.

Decisoes permitidas:

- continuar mesmo item;
- subir camada;
- avancar item;
- mostrar revisao;
- exigir recuperacao;
- oferecer amparo;
- mostrar conclusao;
- bloquear avanco inseguro.

Decisoes proibidas:

- avancar porque a tela acabou;
- avancar porque a IA elogiou;
- avancar porque o aluno clicou rapido;
- marcar dominio por acerto unico;
- finalizar aula ignorando pendencias;
- perder historico ao avancar.

---

## 8. Camadas Pedagogicas

O SIM App deve respeitar camadas pedagogicas.

### Camada 1

Reconhecimento inicial. Serve para ver se o aluno entende a ideia basica.

### Camada 2

Intermediacao. Serve para aluno com erro, duvida ou baixa confianca.

### Camada 3

Consolidacao. Serve para confirmar que o aluno pode seguir.

### Retencao futura

Mesmo apos avancar, revisao futura deve proteger contra esquecimento.

O App pode ter motor mais sofisticado que o Web, mas nao pode remover a logica minima de camadas.

---

## 9. Revisao

Revisao e obrigatoria.

A revisao deve:

- ser curta;
- aparecer sem parecer punicao;
- usar itens com evidencia de fragilidade ou baixa confianca;
- registrar resposta;
- atualizar dominio;
- reagendar se necessario.

Revisao nao pode:

- apagar progresso;
- virar aula principal sem necessidade;
- criar ruido;
- punir visualmente o aluno;
- ser opcional quando ha risco pedagogico real.

---

## 10. Recuperacao

Recuperacao e reparo de rachadura.

Ela deve acontecer quando existem pendencias fortes, por exemplo:

- erro repetido;
- falsa maestria;
- baixa confianca persistente;
- falha em revisao;
- dominio insuficiente no fim da aula.

O App nao deve declarar aula finalizada de verdade se ha recuperacao obrigatoria pendente.

---

## 11. Duvida

A duvida deve ser sala auxiliar, nao substituta do fluxo principal.

Quando o aluno pede duvida, o App deve preservar:

- item atual;
- camada atual;
- pergunta atual;
- resposta escolhida, se houver;
- contexto da aula;
- progresso principal.

Entrar em duvida nao deve apagar tentativa, nao deve avancar item e nao deve reescrever historico morto.

---

## 12. Motor Conversacional

O App deve representar a aula como conversa pedagogica moderna, mas sem perder a Constituicao.

A timeline deve conter:

- explicacao;
- imagem;
- enunciado;
- alternativas;
- escolha do aluno;
- sinais;
- feedback;
- botoes de duvida e avancar;
- mensagens de duvida;
- resposta da duvida;
- erro/retry;
- loading;
- historico morto.

Historico antigo deve permanecer visivel, morto e intocavel.

---

## 13. Primeira Aula e Janela Dopaminica

Antes da primeira aula estar pronta, nada pesado pode competir com ela.

Prioridade:

1. salvar estado critico;
2. gerar/obter texto da aula atual;
3. exibir texto;
4. preparar proximo material minimo;
5. gerar imagem se necessaria;
6. gerar audio se habilitado;
7. expandir curriculo maior;
8. sincronizar pesado;
9. relatorios.

A janela dopaminica deve manter fluidez, mas nao pode inventar material falso.

---

## 14. Imagem

Imagem e aula, nao enfeite.

O App deve:

- receber imagem do servidor quando pronta;
- associar imagem ao item/camada corretos;
- nao bloquear texto por imagem;
- nao mostrar oferta paga quando o desenho pedagogico software/servidor deveria existir;
- preservar imagem antiga no historico;
- nao trocar imagem de item antigo por item novo;
- nao usar trigger velho para aula nova.

O servidor pode desenhar, rasterizar ou encaminhar para IA paga, mas a decisao deve ser pedagogica, rastreavel e ligada ao visual_trigger correto.

---

## 15. Audio

Audio e opcional.

Ele nao pode bloquear aula, progresso, texto, pergunta ou resposta.

O audio deve:

- respeitar idioma pedagogico;
- estar ligado ao item/camada correto;
- poder falhar sem derrubar aula;
- ser reproduzido/pausado sem corromper estado.

---

## 16. Idioma

O SIM App deve separar:

- idioma da interface;
- idioma pedagogico da aula;
- idioma alvo quando a aula for de lingua.

O App deve:

- seguir idioma do dispositivo quando suportado;
- permitir escolha manual;
- preservar idioma da aula criada;
- nao misturar idiomas sem intencao pedagogica;
- garantir que servidor, prompts, imagem, audio e feedback recebam idioma estruturado.

---

## 17. Estado do Aluno

O estado do aluno e sagrado.

Deve conter, no minimo:

- perfil;
- idioma;
- objetivo;
- curriculo;
- item atual;
- camada atual;
- progresso;
- tentativas;
- historico;
- concluidos;
- pendencias;
- revisoes;
- recuperacoes;
- eventos;
- snapshots;
- material atual;
- materiais preparados.

O App nunca deve usar memoria temporaria como fonte final de verdade.

---

## 18. Event Log

O SIM App precisa registrar eventos pedagogicos e tecnicos relevantes.

Eventos minimos:

- STUDENT_PROFILE_CREATED;
- PROFILE_INTERPRETED;
- CURRICULUM_GENERATION_STARTED;
- CURRICULUM_GENERATED;
- LESSON_TEXT_REQUESTED;
- LESSON_TEXT_READY;
- IMAGE_OFFERED;
- IMAGE_ACCEPTED;
- IMAGE_READY;
- AUDIO_READY;
- ANSWER_SUBMITTED;
- SIGNAL_SUBMITTED;
- ITEM_ADVANCED;
- ITEM_MASTERED;
- WEAKNESS_REGISTERED;
- REVIEW_SCHEDULED;
- REINFORCEMENT_REQUIRED;
- SYNC_STARTED;
- SYNC_COMPLETED;
- SYNC_BLOCKED_REGRESSION;
- TECHNICAL_CACHE_CLEARED;
- ERROR_RECORDED.

Cada evento deve ter:

- id;
- tipo;
- payload;
- timestamp;
- origem;
- versao antes, quando aplicavel;
- versao depois, quando aplicavel.

---

## 19. Sincronizacao e Backup

O App deve proteger progresso contra perda.

Regras:

- local nao apaga remoto mais avancado;
- remoto nao apaga local mais avancado;
- estado vazio nao sobrescreve estado rico;
- conflito deve manter o mais avancado ou pedir decisao humana;
- progresso precisa sobreviver a fechar/reabrir;
- backup deve restaurar aula, item, camada, tentativas e pendencias.

High Water Mark e obrigatorio para declarar Evento A verdadeiro.

---

## 20. Cache

Cache nao e fonte da verdade.

Cache pode guardar:

- aula atual;
- proximas duas aulas;
- imagens recentes;
- metadados leves;
- estado temporario de fila.

Cache nao pode:

- apagar progresso;
- substituir estado;
- ressuscitar material antigo;
- gerar aula duplicada;
- fazer imagem velha bloquear imagem nova;
- crescer sem limite.

---

## 21. Servidor

O servidor deve agir como AI Gateway e/ou Assistente operacional supervisionado.

Ele pode:

- proteger chaves;
- chamar IA;
- validar contratos;
- gerar aula;
- gerar imagem;
- rasterizar SVG;
- preparar slots;
- manter sessao;
- devolver material pronto;
- aplicar rate limit;
- registrar erro tecnico.

Ele nao pode:

- decidir progresso final sem contrato com o App;
- apagar estado do aluno;
- depender de arquivo volatil em producao sem persistencia garantida;
- chamar professor antigo escondido;
- aceitar resposta de IA sem validacao;
- bloquear texto por imagem/audio.

Para o Evento A ser verdadeiro, o servidor precisa ter persistencia segura, testes verdes e contrato claro com o App.

---

## 22. Offline e Internet Ruim

O SIM App deve funcionar de modo aceitavel com internet ruim.

Se a internet cair:

- aula atual permanece;
- respostas locais sao salvas;
- fila fica pendente;
- sincronizacao tenta depois;
- erro e humano;
- progresso nao some.

O App nao precisa gerar aula nova offline se isso depender de IA, mas nao pode perder o que ja estava pronto.

---

## 23. Celular Fraco

Evento A exige funcionamento aceitavel em celular fraco.

O App deve:

- abrir rapido;
- nao carregar tudo de uma vez;
- limitar cache;
- nao segurar imagens demais;
- nao travar tela por tarefa pesada;
- evitar animacoes caras;
- manter botoes grandes;
- preservar leitura.

---

## 24. Painel do Pai

O Painel do Pai deve mostrar progresso real.

Deve mostrar:

- itens estudados;
- itens dominados;
- itens frageis;
- revisoes pendentes;
- recuperacoes;
- sinais de confianca;
- erros relevantes;
- andamento geral;
- alertas de falsa maestria.

Nao deve mostrar:

- logs crus;
- prompts;
- JSON;
- detalhes internos desnecessarios.

---

## 25. Criterios de Prova do Evento A

O Evento A so pode ser marcado como verdadeiro apos provas.

### Provas obrigatorias no App

- Flutter analyze sem issues.
- Testes unitarios dos motores pedagogicos passando.
- Testes widget da aula/conversa passando.
- Testes de idioma passando.
- Testes de navegacao passando.
- Testes de estado/restauracao passando.
- Testes de imagem passando.
- Testes de sync/backup passando.
- Testes de revisao/recuperacao passando.

### Provas obrigatorias no servidor

- npm test passando.
- Rotas de aula passando.
- Rotas de imagem passando.
- Contratos T00/T02 passando.
- Persistencia de sessao validada.
- Nenhum fallback antigo escondido.
- Nenhum teste quebrado.

### Provas obrigatorias integradas

- APK real abre.
- Aluno cria objetivo.
- Primeira aula aparece rapido.
- Texto aparece antes da imagem.
- Aluno responde A/B/C.
- Sinal aparece.
- Feedback aparece.
- Progresso e salvo.
- App fecha e reabre no ponto correto.
- Imagem correta aparece quando deveria.
- Revisao/recuperacao funcionam.
- Internet ruim nao apaga estado.

---

## 26. Checklist de Verdade do Evento A

Marcar cada item como SIM/NAO.

1. O App nao e chatbot.
2. O App nao e quiz superficial.
3. O aluno responde com A/B/C + sinal.
4. O estado fica fora da IA.
5. A IA nao decide progresso final.
6. O software valida resposta.
7. O Advance Gate existe.
8. Acerto unico nao gera dominio pleno.
9. Falsa maestria e detectada.
10. Revisao existe.
11. Recuperacao existe.
12. Duvida existe sem quebrar progresso.
13. Historico morto e preservado.
14. Primeira aula chega rapido.
15. Texto nao espera imagem.
16. Imagem pertence ao item/camada correto.
17. Audio nao bloqueia aula.
18. Idioma e consistente.
19. Estado restaura ao reabrir.
20. Sync nao regride progresso.
21. Cache e limitado.
22. Servidor tem persistencia segura.
23. Servidor valida IA.
24. App funciona em celular fraco.
25. App tolera internet ruim.
26. Pai ve progresso real.
27. Nao ha jargao interno para aluno.
28. Nao ha JSON/log visivel.
29. Testes do App passam.
30. Testes do servidor passam.
31. APK real comprova o fluxo.

Se qualquer item estiver NAO, o Evento A ainda e falso.

---

## 27. Criterio Final

O Evento A nao e uma opiniao.

Ele so e verdadeiro quando o SIM App, conectado ao servidor correto, demonstrar em teste e uso real que:

- o Tutor gera;
- o Assistente governa;
- o Pai protege;
- o aluno responde;
- o sistema valida;
- o progresso e salvo;
- a revisao retorna;
- a recuperacao repara;
- a imagem ensina;
- o audio ajuda;
- o cache nao manda;
- a IA nao governa;
- a aprendizagem e real.

Enquanto isso nao for provado, o Evento A permanece:

**EVENTO A = FALSO / EM CONSTRUCAO**

Quando tudo for provado:

**EVENTO A = VERDADEIRO**


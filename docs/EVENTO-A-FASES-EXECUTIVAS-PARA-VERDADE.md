# EVENTO A — Fases Executivas Para Tornar Verdade

## Objetivo

Este documento divide o Evento A em eventos parciais executaveis:

**A1, A2, A3, ...**

Cada evento parcial precisa virar **VERDADEIRO** com implementacao, testes e evidencia.

Somente quando todos os eventos parciais obrigatorios forem verdadeiros, pode-se declarar:

**EVENTO A = VERDADEIRO**

Enquanto qualquer evento parcial obrigatorio estiver falso, parcial ou sem prova:

**EVENTO A = FALSO / EM CONSTRUCAO**

---

## Regra Suprema

Nenhuma janela executora pode declarar o Evento A completo.

Cada janela so pode trabalhar em um evento parcial bem delimitado.

Exemplo:

- A1 = verdadeiro.
- A2 = verdadeiro.
- A3 = parcial.
- A4 = falso.

Resultado:

**A = falso.**

O objetivo e evitar conclusao falsa.

---

## Estados Permitidos

Cada evento parcial deve ser classificado como:

- **NAO INICIADO**
- **EM EXECUCAO**
- **IMPLEMENTADO**
- **TESTADO**
- **VERDADEIRO**
- **PARCIAL**
- **BLOQUEADO**
- **FALSO**

Um evento so vira **VERDADEIRO** quando:

1. Escopo foi implementado.
2. Testes automaticos relevantes passaram.
3. Teste manual ou evidencia funcional foi registrada quando necessario.
4. Nao quebrou outro motor.
5. Foi commitado e enviado para `origin/main`.
6. O relatorio cita arquivos alterados, testes e limites.

---

# Eventos Parciais do Evento A

## A1 — Contrato Constitucional do SIM App

### Objetivo

Garantir que o App tenha uma camada clara de leis do SIM:

- SIM nao e chatbot;
- SIM nao e quiz superficial;
- IA nao governa estado;
- software valida aprendizagem;
- aluno so avanca com evidencia;
- primeira aula tem prioridade;
- texto nao espera imagem/audio.

### Entrega

- Criar/validar contratos centrais de constituicao do app.
- Criar testes que falham se regra constitucional for violada.
- Documentar quais motores obedecem a essas regras.

### Evidencia de Verdade

- Testes constitucionais passam.
- Nenhuma tela/motor principal viola as regras.

---

## A2 — Separacao de Poderes: Pai, Assistente e Tutor

### Objetivo

Garantir que cada entidade cumpra seu papel:

- Pai governa leis e protecao.
- Assistente/software governa estado, rota e progresso.
- Tutor/IA gera conteudo, mas nao decide aprendizagem final.

### Entrega

- Mapear onde cada papel aparece no App e no servidor.
- Impedir que IA escreva progresso final diretamente.
- Garantir que toda resposta de IA passe por contrato/adaptador.

### Evidencia de Verdade

- Teste prova que conteudo de IA invalido nao altera estado final.
- Teste prova que avanco depende do motor de software.

---

## A3 — Estado do Aluno Como Fonte de Verdade

### Objetivo

Garantir que o progresso do aluno nao fique solto na tela, na IA ou em memoria fragil.

### Entrega

Estado deve conter e restaurar:

- perfil;
- idioma;
- objetivo;
- curriculo;
- item atual;
- camada atual;
- tentativas;
- historico;
- concluidos;
- pendencias;
- revisoes;
- recuperacoes;
- eventos;
- material atual;
- materiais preparados.

### Evidencia de Verdade

- Fechar/reabrir preserva item, camada, historico e pendencias.
- Estado vazio nao sobrescreve estado rico.
- Testes de store/restauracao passam.

---

## A4 — Motor Pedagogico Principal

### Objetivo

Garantir que o aluno aprenda por microitem, camada e evidencia.

### Entrega

Implementar/provar:

- microitem com marker estavel;
- camada 1, 2 e 3;
- resposta A/B/C;
- sinal 1/2/3;
- tentativa com marker, layer, letra, sinal, correct e timestamp;
- decisao pedagogica auditavel.

### Evidencia de Verdade

- Acerto seguro na L1 segue regra oficial.
- Duvida/erro na L1 leva para L2.
- L2 consolidada leva para L3.
- L3 consolidada avanca item.
- L3 fragil nao avanca falsamente.

---

## A5 — Advance Gate e Dominio Real

### Objetivo

Impedir falsa aprendizagem.

### Entrega

O Advance Gate deve considerar:

- acerto;
- erro;
- sinal;
- camada;
- historico;
- tentativa repetida;
- falsa maestria;
- fragilidade;
- revisao;
- recuperacao.

### Evidencia de Verdade

- Acerto unico nao vira dominio pleno.
- Erro com certeza registra falsa maestria.
- Erro repetido registra fragilidade.
- Conquista so acontece com evidencia suficiente.

---

## A6 — Revisao

### Objetivo

Garantir que o SIM volte aos pontos que precisam ser fortalecidos.

### Entrega

- Fila de revisao.
- Gatilhos por baixa confianca, erro ou consolidacao parcial.
- Tela/sala de revisao.
- Registro de resposta de revisao.
- Atualizacao de dominio apos revisao.

### Evidencia de Verdade

- Item fragil entra em revisao.
- Revisao nao apaga progresso principal.
- Acerto/erro na revisao atualiza evidencia.

---

## A7 — Recuperacao

### Objetivo

Impedir conclusao falsa quando existem rachaduras fortes.

### Entrega

- Fila de recuperacao.
- Bloqueio de conclusao quando necessario.
- Sala de recuperacao.
- Registro de resposta.
- Liberacao de conclusao apenas apos reparo.

### Evidencia de Verdade

- Aula com pendencia grave nao finaliza como dominada.
- Recuperacao concluida libera finalizacao.
- Recuperacao nao destrói historico.

---

## A8 — Duvida Como Sala Auxiliar

### Objetivo

Permitir ajuda sem corromper o fluxo principal.

### Entrega

- Botao/acao de duvida.
- Composer de duvida.
- Contexto do item/camada atual.
- Resposta da duvida na conversa.
- Historico preservado.

### Evidencia de Verdade

- Entrar em duvida nao avanca item.
- Duvida nao apaga resposta.
- Duvida nao altera dominio sem nova evidencia.

---

## A9 — Motor Conversacional Pedagogico

### Objetivo

Representar aula como conversa moderna sem virar chatbot solto.

### Entrega

Timeline deve conter:

- explicacao;
- imagem;
- enunciado;
- alternativas;
- escolha do aluno;
- sinais;
- feedback;
- duvida;
- avancar;
- loading;
- erro/retry;
- historico morto.

### Evidencia de Verdade

- Historico antigo permanece visivel e intocavel.
- Botoes nao reativam tentativa antiga.
- Scroll mostra o bloco certo no momento certo.

---

## A10 — Primeira Aula e Janela Dopaminica

### Objetivo

Garantir que o aluno comece rapido.

### Entrega

- Primeira aula tem prioridade absoluta.
- Texto vem antes da imagem.
- Curriculo inicial pequeno.
- Preparacao das proximas aulas sem bloquear tela atual.
- Dedupe de preparacao.

### Evidencia de Verdade

- Primeira aula aparece sem esperar imagem/audio/curriculo completo.
- Nao ha duas geracoes concorrentes para o mesmo slot.
- Material velho nao bloqueia material novo.

---

## A11 — Imagem Pedagogica

### Objetivo

Garantir que imagem ensine e pertença ao item correto.

### Entrega

- Visual trigger rico.
- Validador de desenhabilidade.
- Servidor gera/rasteriza quando adequado.
- App exibe imagem pronta.
- Oferta paga so aparece quando realmente aplicavel.
- Imagem antiga fica morta no historico.

### Evidencia de Verdade

- Aula de grafico fisico/matematico desenha pelo caminho correto.
- Imagem nao troca de item.
- Texto nao espera imagem.

---

## A12 — Audio Pedagogico

### Objetivo

Fazer audio ajudar sem bloquear a aula.

### Entrega

- Audio ligado ao item/camada.
- Falha de audio nao derruba aula.
- Audio respeita idioma pedagogico.
- Controle de play/pause seguro.

### Evidencia de Verdade

- Aula funciona sem audio.
- Audio errado nao troca progresso.
- Estado da aula permanece correto.

---

## A13 — Motor de Idioma

### Objetivo

Separar idioma da interface e idioma pedagogico.

### Entrega

- Idioma do app.
- Idioma da aula.
- Fallback seguro.
- Conteudo gerado no idioma correto.
- App, servidor, imagem, audio e feedback recebem idioma estruturado.

### Evidencia de Verdade

- Trocar idioma da interface muda menus/botoes.
- Aula nova respeita idioma pedagogico.
- Aula antiga nao muda sem autorizacao.
- Nao ha mistura acidental de idiomas.

---

## A14 — Servidor Como AI Gateway Constitucional

### Objetivo

Garantir que servidor chame IA, valide contrato e proteja chaves sem virar IA solta.

### Entrega

- Chaves protegidas.
- Contratos T00/T02/imagem/audio validados.
- Rate limit.
- Retry seguro.
- Fallback de modelo sem professor antigo escondido.
- Persistencia segura de sessoes.

### Evidencia de Verdade

- `npm test` passa.
- Resposta invalida de IA e rejeitada.
- Servidor nao usa storage volatil em producao sem garantia.
- App aponta para servidor correto.

---

## A15 — Fila, Cache e Prioridade

### Objetivo

Impedir bagunca de tarefas concorrentes.

### Entrega

Fila com prioridade:

1. salvar estado critico;
2. texto da aula atual;
3. validacao de resposta;
4. amparo;
5. proxima aula;
6. imagem;
7. audio;
8. expansao curricular;
9. sync pesado.

Cache deve ser limitado e nao ser fonte da verdade.

### Evidencia de Verdade

- Cache pode ser limpo sem apagar progresso.
- Tarefa duplicada e deduplicada.
- Imagem/audio nao passam na frente da aula atual.

---

## A16 — Sincronizacao, Backup e High Water Mark

### Objetivo

Proteger a jornada do aluno contra perda e regressao.

### Entrega

- Snapshot local.
- Sync para nuvem/servidor quando aplicavel.
- High Water Mark.
- Conflito nao apaga progresso avancado.
- Backup/restauracao.

### Evidencia de Verdade

- Local vazio nao apaga remoto rico.
- Remoto antigo nao apaga local avancado.
- Reabrir app restaura estado correto.

---

## A17 — Offline, Erro e Internet Ruim

### Objetivo

Fazer o SIM continuar aceitavel em falha real.

### Entrega

- Aula atual permanece sem internet.
- Respostas locais sao salvas.
- Fila pendente aguarda retry.
- Erro humano.
- Retry claro.

### Evidencia de Verdade

- Sem internet nao perde resposta.
- IA falhando nao derruba estado.
- App explica falha sem log bruto.

---

## A18 — Celular Fraco e Performance

### Objetivo

Garantir que SIM funcione em aparelho limitado.

### Entrega

- Cache pequeno.
- Renderizacao leve.
- Imagens controladas.
- Sem carregar muitas aulas.
- Animacoes seguras.
- Timeline eficiente.

### Evidencia de Verdade

- Teste em dispositivo/emulador fraco.
- Sem travamento critico na primeira aula.
- Memoria nao cresce sem limite.

---

## A19 — Painel do Pai

### Objetivo

Mostrar progresso real, nao vaidade.

### Entrega

Painel deve mostrar:

- progresso;
- itens dominados;
- itens frageis;
- revisoes;
- recuperacoes;
- sinais;
- erros relevantes;
- alerta de falsa maestria.

### Evidencia de Verdade

- Dados vêm do estado real do aluno.
- Pai nao ve JSON/log/prompt bruto.

---

## A20 — Prova Integrada do Carro Andando

### Objetivo

Provar o SIM inteiro funcionando em APK real.

### Entrega

Fluxo real:

1. instalar APK;
2. abrir app;
3. escolher idioma;
4. informar objetivo;
5. confirmar;
6. receber primeira aula;
7. ver texto;
8. ver imagem quando aplicavel;
9. responder A/B/C;
10. escolher sinal;
11. ver feedback;
12. avancar;
13. fechar app;
14. reabrir;
15. continuar do ponto certo;
16. testar duvida;
17. testar revisao/recuperacao;
18. simular internet ruim.

### Evidencia de Verdade

- APK gerado.
- Link publico disponibilizado.
- Teste manual registrado.
- App e servidor no mesmo estado commitado/pushado.

---

# Ordem Recomendada de Execucao

## Bloco 1 — Verdade Pedagogica

1. A1
2. A2
3. A3
4. A4
5. A5

Sem isso, o SIM vira quiz/chatbot.

## Bloco 2 — Reparacao da Aprendizagem

6. A6
7. A7
8. A8
9. A9

Sem isso, o aluno pode passar sem aprender.

## Bloco 3 — Fluidez e Midia

10. A10
11. A11
12. A12
13. A13

Sem isso, a experiencia fica quebrada ou inconsistente.

## Bloco 4 — Arquitetura Operacional

14. A14
15. A15
16. A16
17. A17
18. A18

Sem isso, o sistema nao sobrevive a producao real.

## Bloco 5 — Supervisao e Prova Final

19. A19
20. A20

Sem isso, nao ha prova do todo funcionando.

---

# Formula do Evento A

O Evento A e verdadeiro somente se:

```text
A1 = VERDADEIRO
A2 = VERDADEIRO
A3 = VERDADEIRO
A4 = VERDADEIRO
A5 = VERDADEIRO
A6 = VERDADEIRO
A7 = VERDADEIRO
A8 = VERDADEIRO
A9 = VERDADEIRO
A10 = VERDADEIRO
A11 = VERDADEIRO
A12 = VERDADEIRO
A13 = VERDADEIRO
A14 = VERDADEIRO
A15 = VERDADEIRO
A16 = VERDADEIRO
A17 = VERDADEIRO
A18 = VERDADEIRO
A19 = VERDADEIRO
A20 = VERDADEIRO
```

Se qualquer um for falso:

```text
A = FALSO
```

---

# Relatorio Obrigatorio Por Evento Parcial

Toda janela executora deve entregar:

1. Evento trabalhado.
2. Objetivo do evento.
3. Referencias usadas.
4. Arquivos alterados.
5. O que ja existia.
6. O que estava faltando.
7. O que foi implementado.
8. O que ficou bloqueado.
9. Testes criados.
10. Testes executados.
11. Resultado dos testes.
12. Risco residual.
13. Confirmacao de que nao tocou fora do escopo.
14. Hash do commit.
15. Confirmacao de push para `origin/main`.

Sem commit e push, o evento nao pode virar verdadeiro.

---

# Regra Contra Autoengano

Implementar parte visual nao torna o evento verdadeiro.

Implementar motor isolado nao torna o evento verdadeiro.

Teste unitario sem fluxo real nao torna o evento verdadeiro.

Fluxo manual sem teste automatico nao torna o evento verdadeiro.

Commit sem push nao torna o evento verdadeiro.

Documento sem implementacao nao torna o evento verdadeiro.

O evento so vira verdadeiro quando comportamento, estado, teste, evidencia, commit e push concordam.


# Motor Conversacional Universal - checkpoint 200 itens

Data: 2026-07-05

Escopo: primeira fatia de 200 unidades funcionais auditaveis da meta de exaustao estrutural do Motor Conversacional Universal no SIM Scroll.

Importante: 200 itens representam 5% nominais de uma meta de 4.000 itens, nao 20%. Esta entrega classifica e prova 200 unidades; nao declara a exaustao estrutural completa.

## Referencias comprovadas

- REF-WCAG-STATUS: W3C WCAG 2.2, Success Criterion 4.1.3 Status Messages. Autoriza expor estados de espera, progresso e erro para tecnologia assistiva sem mudar foco.
- REF-SLACK-HISTORY: Slack `conversations.history`. Autoriza modelo de historico de conversa com mensagens ordenadas, limites e checagem de erros.
- REF-SLACK-PAGINATION: Slack Web API Pagination. Autoriza paginacao/particionamento para colecoes longas e evita carregar tudo como bloco unico.
- REF-WHATSAPP-TYPING: Meta WhatsApp Business typing/read indicators. Autoriza estados de processamento e leitura como parte do contrato conversacional.
- REF-TELEGRAM-ACTION: Telegram Bot API `sendChatAction`. Autoriza sinalizar que algo esta acontecendo quando a resposta demora perceptivelmente.
- REF-FLUTTER-SEMANTICS: Flutter `Semantics`, `liveRegion`, `OrdinalSortKey` e labels programaticos. Autoriza semantica mobile, ordenacao de foco e anuncios de status.
- REF-SCROLL-CODE: SIM Scroll validado nos arquivos `chat_aula_screen.dart`, `chat_aula_messages.dart`, `chat_aula_timeline_builder.dart`, `chat_aula_widgets.dart`, `doubt_input_sheet_widget.dart`, `classroom_models.dart` e `lesson_answer_progress_controller.dart`.
- REF-SCROLL-TESTS: Testes `chat_aula_timeline_builder_test.dart`, `chat_aula_widgets_test.dart`, `first_lesson_ready_window_test.dart`, `media_phase_test.dart`, `classroom_phase_test.dart` e suite Flutter completa validada anteriormente.

## Criterio de classificacao

- JA EXISTIA: comportamento ja estava presente e foi preservado.
- AJUSTADO: comportamento existia, mas recebeu ajuste em codigo nesta frente.
- CRIADO: unidade funcional foi criada nesta frente.
- MELHORADO: comportamento ficou mais forte que o estado anterior com teste.
- PRESERVADO: comportamento do Scroll estava melhor/adequado e nao foi alterado.
- NAO APLICAVEL: unidade nao pertence ao palco conversacional atual sem violar escopo.
- BLOQUEADO: unidade exige autorizacao, backend, persistencia nova, prompt, servidor, produto ou prova adicional.

## Matriz 001-200

| ID | Unidade auditavel | Referencia | Evidencia Scroll | Status | Teste/prova | Proxima acao |
|---:|---|---|---|---|---|---|
| 001 | Criar conversa ativa por aula | REF-SCROLL-CODE | `_conversationLessonKey` em `chat_aula_screen.dart` | JA EXISTIA | Suite classroom | Preservar isolamento |
| 002 | Trocar conversa quando muda aula | REF-SCROLL-CODE | `_conversationKeyFor(session)` | JA EXISTIA | Widget/classroom | Manter chave estavel |
| 003 | Limpar mensagens ao mudar conversa | REF-SCROLL-CODE | `_mergeConversationMessages` limpa se chave muda | JA EXISTIA | Widget/classroom | Preservar |
| 004 | Evitar historico cruzado entre aulas | REF-SCROLL-CODE | Filtro por lesson key | JA EXISTIA | Suite completa | Monitorar regressao |
| 005 | Arquivar turno respondido | REF-SCROLL-CODE | `_conversationArchiveSeq` | JA EXISTIA | Widget/classroom | Preservar |
| 006 | Deduplicar historico restaurado | REF-SLACK-HISTORY | `_isDuplicateHistoryMessage` | JA EXISTIA | Widget/classroom | Ampliar teste dedicado |
| 007 | Fingerprint de mensagem | REF-SLACK-HISTORY | `_messageFingerprint` | JA EXISTIA | Widget/classroom | Preservar |
| 008 | ID estavel para mensagem arquivada | REF-SCROLL-CODE | `_archivedMessageId` | JA EXISTIA | Widget/classroom | Preservar |
| 009 | Separar palco universal de pedagogia | REF-SCROLL-CODE | `ChatLessonMessage` independente de UI concreta | MELHORADO | Timeline builder | Evoluir contrato |
| 010 | Nao abrir conversa falsa | REF-SCROLL-CODE | Tela depende de sessao/material real | PRESERVADO | Classroom tests | Preservar |
| 011 | Fechar recursos ao sair da conversa | REF-FLUTTER-SEMANTICS | `dispose` para controllers/audio | JA EXISTIA | Widget tests | Preservar |
| 012 | Pausar audio ao background | REF-SCROLL-CODE | Lifecycle paused/inactive/detached | JA EXISTIA | Audio/widget | Preservar |
| 013 | Cancelar overlays ao sair | REF-FLUTTER-SEMANTICS | Bottom sheets controlados por tela | JA EXISTIA | Widget tests | Cobrir mais cenarios |
| 014 | Manter conversa durante rebuild | REF-SCROLL-CODE | Estado local + merge deterministico | JA EXISTIA | Widget tests | Preservar |
| 015 | Recuperar conversa da sessao | REF-SCROLL-CODE | Snapshot/session runtime | JA EXISTIA | Classroom tests | Preservar |
| 016 | Lista de conversas global | REF-SLACK-HISTORY | Nao ha inbox universal separado | BLOQUEADO | N/A | Exige produto/arquitetura |
| 017 | Arquivamento manual de conversa | REF-SLACK-HISTORY | Nao ha UI de arquivo manual | BLOQUEADO | N/A | Exige decisao de produto |
| 018 | Fixar conversa | REF-SLACK-HISTORY | Nao ha pin universal | BLOQUEADO | N/A | Exige decisao de produto |
| 019 | Busca em conversas | REF-SLACK-HISTORY | Nao ha busca global | BLOQUEADO | N/A | Projetar indice |
| 020 | Ordenacao de conversas | REF-SLACK-HISTORY | Nao ha lista global | NAO APLICAVEL | N/A | Reavaliar quando houver inbox |
| 021 | Modelo com ID local | REF-SLACK-HISTORY | `ChatLessonMessage.id` | JA EXISTIA | Timeline tests | Preservar |
| 022 | Papel do autor | REF-SCROLL-CODE | `ChatLessonMessageRole` | JA EXISTIA | Widget tests | Preservar |
| 023 | Tipo de mensagem | REF-SCROLL-CODE | `ChatLessonMessageKind` | JA EXISTIA | Timeline tests | Preservar |
| 024 | Payload textual | REF-SCROLL-CODE | `text` opcional | JA EXISTIA | Widget tests | Preservar |
| 025 | Payload de opcoes | REF-SCROLL-CODE | `options` | JA EXISTIA | Timeline tests | Preservar |
| 026 | Payload de imagem | REF-SCROLL-CODE | `imageData` | JA EXISTIA | Widget tests | Preservar |
| 027 | Estado de imagem | REF-SCROLL-CODE | `imageStatus` | JA EXISTIA | Media tests | Preservar |
| 028 | Oferta paga sinalizada sem cobrar | REF-SCROLL-CODE | `hasPaidImageOffer` | JA EXISTIA | Media tests | Preservar |
| 029 | Progresso em mensagem | REF-WCAG-STATUS | `progress` | JA EXISTIA | Doubt progress | Preservar |
| 030 | Status de entrega universal | REF-WHATSAPP-TYPING | `ChatLessonDeliveryStatus` | CRIADO | Timeline tests | Expandir para persistencia |
| 031 | Status `sending` no contrato | REF-WHATSAPP-TYPING | Enum criado | CRIADO | Compile/analyze | Ligar a fila real |
| 032 | Status `sent` no contrato | REF-WHATSAPP-TYPING | Resposta/sinal do aluno | AJUSTADO | Timeline tests | Persistir no historico |
| 033 | Status `delivered` no contrato | REF-WHATSAPP-TYPING | Mensagens do SIM | AJUSTADO | Widget tests | Preservar |
| 034 | Status `read` no contrato | REF-WHATSAPP-TYPING | Historico respondido | AJUSTADO | Timeline tests | Preservar |
| 035 | Status `processing` no contrato | REF-TELEGRAM-ACTION | Loading/processando | AJUSTADO | Widget tests | Preservar |
| 036 | Status `failed` no contrato | REF-WCAG-STATUS | Erros runtime/doubt/imagem | AJUSTADO | Widget tests | Preservar |
| 037 | Timestamp visual de historico | REF-SLACK-HISTORY | `timestampLabel` | CRIADO | Timeline tests | Persistir todos eventos |
| 038 | Sequencia deterministica | REF-FLUTTER-SEMANTICS | `sequenceIndex` | CRIADO | Timeline tests | Preservar |
| 039 | `copyWith` preserva status | REF-SCROLL-CODE | `ChatLessonMessage.copyWith` | AJUSTADO | Analyze/tests | Preservar |
| 040 | `copyWith` preserva timestamp | REF-SCROLL-CODE | `copyWith.timestampLabel` | AJUSTADO | Analyze/tests | Preservar |
| 041 | `copyWith` preserva sequencia | REF-SCROLL-CODE | `copyWith.sequenceIndex` | AJUSTADO | Analyze/tests | Preservar |
| 042 | Historico preserva pergunta | REF-SLACK-HISTORY | `historyQuestion` | JA EXISTIA | Timeline tests | Preservar |
| 043 | Historico preserva resposta | REF-SLACK-HISTORY | `historyAnswer` | JA EXISTIA | Timeline tests | Preservar |
| 044 | Historico preserva alternativa escolhida | REF-SLACK-HISTORY | `selectedAnswer` | MELHORADO | Timeline tests | Preservar |
| 045 | Historico preserva corretude | REF-SLACK-HISTORY | `isCorrect` | MELHORADO | Timeline tests | Preservar |
| 046 | Historico preserva opcoes | REF-SLACK-HISTORY | Opcoes mapeadas para `ChatLessonOption` | MELHORADO | Timeline tests | Preservar |
| 047 | Historico bloqueia opcoes antigas | REF-SCROLL-CODE | `enabled: false` | MELHORADO | Timeline/widget tests | Preservar |
| 048 | Historico preserva imagem propria | REF-SCROLL-CODE | `imageUrl` -> `imageData` | MELHORADO | Widget tests | Preservar |
| 049 | Historico nao reusa imagem alheia | REF-SCROLL-CODE | Dados carregados do entry | PRESERVADO | Media tests | Manter teste |
| 050 | Timestamp derivado de `answeredAt` | REF-SLACK-HISTORY | `_formatTimestampLabel` | CRIADO | Timeline tests | Preservar |
| 051 | Ordem semantica por sequencia | REF-FLUTTER-SEMANTICS | `OrdinalSortKey` | MELHORADO | Widget tests | Preservar |
| 052 | Live region para processamento | REF-WCAG-STATUS | `_isLiveRegion` | CRIADO | Widget semantics | Preservar |
| 053 | Live region para erro | REF-WCAG-STATUS | `_isLiveRegion` | CRIADO | Widget semantics | Preservar |
| 054 | Live region para feedback | REF-WCAG-STATUS | `_isLiveRegion` | CRIADO | Widget semantics | Preservar |
| 055 | Label semantico com autor | REF-FLUTTER-SEMANTICS | `_semanticLabel` | MELHORADO | Widget semantics | Preservar |
| 056 | Label semantico com status | REF-WCAG-STATUS | `_deliveryStatusLabel` | MELHORADO | Widget semantics | Preservar |
| 057 | Label semantico com horario | REF-FLUTTER-SEMANTICS | `timestampLabel` no label | MELHORADO | Widget semantics | Preservar |
| 058 | Label semantico com texto | REF-FLUTTER-SEMANTICS | Texto no label | JA EXISTIA | Widget semantics | Preservar |
| 059 | Status muda sem trocar mensagem | REF-WCAG-STATUS | `copyWith(deliveryStatus)` | MELHORADO | Widget tests | Ligar a fila real |
| 060 | Status humano em portugues | REF-WCAG-STATUS | `enviando/enviada/...` | AJUSTADO | Widget tests | Internacionalizar depois |
| 061 | Timeline com scroll controller externo | REF-SLACK-PAGINATION | `scrollController` opcional | JA EXISTIA | Widget tests | Preservar |
| 062 | Auto-follow quando usuario esta no fim | REF-SCROLL-CODE | `_autoFollow` | JA EXISTIA | Widget tests | Preservar |
| 063 | Botao voltar ao atual | REF-SCROLL-CODE | `chat-return-current-button` | JA EXISTIA | Widget tests | Preservar |
| 064 | Preservar scroll manual | REF-SCROLL-CODE | `_autoFollow` desliga | JA EXISTIA | Widget tests | Preservar |
| 065 | Reativar auto-scroll por botao | REF-SCROLL-CODE | Callback do botao atual | JA EXISTIA | Widget tests | Preservar |
| 066 | ListView para timeline | REF-SLACK-PAGINATION | `ListView` | JA EXISTIA | Widget tests | Avaliar virtualizacao |
| 067 | Virtualizacao para milhares de mensagens | REF-SLACK-PAGINATION | ListView padrao, sem paginacao dedicada | BLOQUEADO | N/A | Projetar paging/limites |
| 068 | Paginacao de historico antigo | REF-SLACK-PAGINATION | Nao ha cursor local universal | BLOQUEADO | N/A | Criar contrato |
| 069 | Ancora de mensagem | REF-SLACK-HISTORY | IDs estaveis, sem deep link | BLOQUEADO | N/A | Criar indice |
| 070 | Jump to latest acessivel | REF-FLUTTER-SEMANTICS | Botao atual com key | JA EXISTIA | Widget tests | Adicionar label especifico |
| 071 | Bottom safe area | REF-FLUTTER-SEMANTICS | Insets no layout | JA EXISTIA | Widget tests | Preservar |
| 072 | Teclado nao cobre composer/sheet | REF-FLUTTER-SEMANTICS | Bottom sheet usa insets | JA EXISTIA | Widget tests | Ampliar cenarios |
| 073 | Dismiss teclado por scroll | REF-FLUTTER-SEMANTICS | `keyboardDismissBehavior` | JA EXISTIA | Widget tests | Preservar |
| 074 | Render incremental de mensagens | REF-SCROLL-CODE | `_messageSignature` | MELHORADO | Widget tests | Preservar |
| 075 | Assinatura inclui status | REF-WCAG-STATUS | `deliveryStatus.name` | AJUSTADO | Widget tests | Preservar |
| 076 | Assinatura inclui timestamp | REF-SLACK-HISTORY | `timestampLabel` | AJUSTADO | Widget tests | Preservar |
| 077 | Assinatura inclui sequencia | REF-FLUTTER-SEMANTICS | `sequenceIndex` | AJUSTADO | Widget tests | Preservar |
| 078 | Assinatura inclui oferta paga | REF-SCROLL-CODE | `hasPaidImageOffer` | AJUSTADO | Media tests | Preservar |
| 079 | Assinatura inclui corretude | REF-SCROLL-CODE | `isCorrect` | AJUSTADO | Widget tests | Preservar |
| 080 | Evitar rebuild invisivel de progresso | REF-WCAG-STATUS | `progress` na assinatura | JA EXISTIA | Widget tests | Preservar |
| 081 | Bolha por papel de mensagem | REF-SCROLL-CODE | `ChatLessonMessageRole` | JA EXISTIA | Widget tests | Preservar |
| 082 | Bolha do aluno alinhada distinta | REF-SCROLL-CODE | `Align` por papel | JA EXISTIA | Widget tests | Preservar |
| 083 | Bolha do sistema distinta | REF-WCAG-STATUS | Role system | JA EXISTIA | Widget tests | Preservar |
| 084 | Pergunta ativa renderizada | REF-SCROLL-CODE | `question` | JA EXISTIA | Timeline tests | Preservar |
| 085 | Explicacao renderizada antes da pergunta | REF-SCROLL-CODE | Builder adiciona explanation | JA EXISTIA | Timeline tests | Preservar |
| 086 | Opcoes A/B/C renderizadas | REF-SCROLL-CODE | `_OptionsMessage` | JA EXISTIA | Widget tests | Preservar |
| 087 | Opcoes bloqueiam apos escolha | REF-SCROLL-CODE | `enabled: !locked` | JA EXISTIA | Timeline tests | Preservar |
| 088 | Resposta do aluno vira mensagem | REF-SCROLL-CODE | `studentAnswer` | JA EXISTIA | Timeline tests | Preservar |
| 089 | Sinais 1/2/3 renderizados | REF-SCROLL-CODE | `signals` | JA EXISTIA | Widget tests | Preservar |
| 090 | Sinal escolhido vira mensagem | REF-SCROLL-CODE | `studentSignal` | JA EXISTIA | Timeline tests | Preservar |
| 091 | Processamento apos sinal | REF-TELEGRAM-ACTION | `processing` message | AJUSTADO | Timeline tests | Preservar |
| 092 | Feedback final renderizado | REF-WCAG-STATUS | `feedback` | JA EXISTIA | Widget tests | Preservar |
| 093 | Acerto/erro em feedback | REF-SCROLL-CODE | `isCorrect` | JA EXISTIA | Widget tests | Preservar |
| 094 | Botao avancar no feedback | REF-SCROLL-CODE | `actionKey` label | JA EXISTIA | Widget tests | Preservar |
| 095 | Erro recuperavel com retry | REF-WCAG-STATUS | `error` + `actionKey: retry` | JA EXISTIA | Widget tests | Preservar |
| 096 | Loading inicial com retry | REF-WCAG-STATUS | Loading `actionKey: retry` | JA EXISTIA | Timeline tests | Preservar |
| 097 | Erro tecnico traduzido para aluno | REF-WCAG-STATUS | `_studentFacingRuntimeError` | JA EXISTIA | Timeline tests | Preservar |
| 098 | Evitar botao morto | REF-SCROLL-CODE | Callbacks obrigatorios no widget | JA EXISTIA | Widget tests | Preservar |
| 099 | Prevencao de double answer | REF-SCROLL-CODE | Locked phase | JA EXISTIA | Classroom tests | Preservar |
| 100 | Prevencao de double advance | REF-SCROLL-CODE | Controladores de fase | JA EXISTIA | Classroom tests | Ampliar prova |
| 101 | Imagem antes da pergunta sem bloquear | REF-SCROLL-CODE | Ordem image/question/options | JA EXISTIA | Media tests | Preservar |
| 102 | Loading de imagem nao bloqueia resposta | REF-SCROLL-CODE | `imageStatus == loading` | JA EXISTIA | Media tests | Preservar |
| 103 | Erro de imagem nao derruba aula | REF-WCAG-STATUS | `imageError` -> failed | AJUSTADO | Media tests | Preservar |
| 104 | Retry de imagem | REF-WCAG-STATUS | `actionKey` imagem | JA EXISTIA | Media tests | Preservar |
| 105 | Oferta paga segue funil existente | REF-SCROLL-CODE | `paid-image-offer` | PRESERVADO | Media tests | Nao alterar credito |
| 106 | Imagem SVG renderizada | REF-SCROLL-CODE | `LessonMediaImageView` | JA EXISTIA | Widget/media | Preservar |
| 107 | Imagem historica compacta | REF-SCROLL-CODE | `_HistoryQuestionMessage` | MELHORADO | Widget tests | Preservar |
| 108 | Semantica de imagem historica | REF-FLUTTER-SEMANTICS | `Semantics(image: true)` | MELHORADO | Widget tests | Melhorar alt text |
| 109 | Alt text especifico da imagem atual | REF-FLUTTER-SEMANTICS | Parcial/generico | BLOQUEADO | N/A | Exige metadado pedagogico |
| 110 | Zoom/fullscreen de imagem | REF-SCROLL-CODE | Nao comprovado no chat | BLOQUEADO | N/A | Projetar sem quebrar aula |
| 111 | Cache correto de imagem propria | REF-SCROLL-CODE | Media tests existentes | PRESERVADO | Media tests | Preservar |
| 112 | Nao reintroduzir imagem antiga | REF-SCROLL-CODE | Media tests existentes | PRESERVADO | Media tests | Preservar |
| 113 | Audio nao bloqueia aula | REF-SCROLL-CODE | Audio controllers separados | PRESERVADO | Audio/media tests | Preservar |
| 114 | Parar audio ao sair | REF-SCROLL-CODE | Lifecycle/dispose | JA EXISTIA | Audio/widget | Preservar |
| 115 | Audio acompanha aula atual | REF-SCROLL-CODE | Chaves de sessao/material | PRESERVADO | Audio tests | Ampliar teste |
| 116 | Bolha flutuante de audio | REF-SCROLL-CODE | Nao comprovada nesta fatia | BLOQUEADO | N/A | Auditar audio dedicado |
| 117 | Replay sem cobrar credito | REF-SCROLL-CODE | Nao alterado | PRESERVADO | Audio tests | Preservar |
| 118 | TTS em background | REF-TELEGRAM-ACTION | Nao alterado nesta fatia | BLOQUEADO | N/A | Requer auditoria audio |
| 119 | Download de anexo universal | REF-SLACK-HISTORY | Fora da tela auditada | BLOQUEADO | N/A | Auditar anexos |
| 120 | Preview de anexo no chat | REF-FLUTTER-SEMANTICS | Parcial em duvida/imagem | BLOQUEADO | N/A | Criar contrato universal |
| 121 | Campo de duvida por texto | REF-SCROLL-CODE | `DoubtInputSheet` controller | JA EXISTIA | Widget/doubt | Preservar |
| 122 | Validacao de duvida vazia | REF-SCROLL-CODE | `DoubtInputDraft.validate` | JA EXISTIA | Widget/doubt | Preservar |
| 123 | Limite de caracteres | REF-SCROLL-CODE | `maxLength` | JA EXISTIA | Widget/doubt | Preservar |
| 124 | Estado busy no envio da duvida | REF-WCAG-STATUS | `_busy` | JA EXISTIA | Widget/doubt | Expor live region |
| 125 | Erro visivel da duvida | REF-WCAG-STATUS | `_error` | JA EXISTIA | Widget/doubt | Melhorar semantica |
| 126 | Anexo de imagem na duvida | REF-SCROLL-CODE | Picker camera/gallery | JA EXISTIA | Widget/doubt | Preservar |
| 127 | Remocao de anexo na duvida | REF-SCROLL-CODE | Estado de draft | JA EXISTIA | Widget/doubt | Preservar |
| 128 | Menu de anexo | REF-FLUTTER-SEMANTICS | Bottom sheet/menu | JA EXISTIA | Widget/doubt | Preservar |
| 129 | Fechar sheet por botao | REF-FLUTTER-SEMANTICS | Callback close | JA EXISTIA | Widget/doubt | Preservar |
| 130 | Fechar sheet sem perder aula | REF-SCROLL-CODE | Sheet local | JA EXISTIA | Widget/doubt | Preservar |
| 131 | Draf temporario da duvida | REF-SCROLL-CODE | Controller local | JA EXISTIA | Widget/doubt | Preservar |
| 132 | Draft persistente por conversa | REF-SLACK-HISTORY | Nao ha persistencia universal | BLOQUEADO | N/A | Criar store de drafts |
| 133 | Colagem de texto longo | REF-FLUTTER-SEMANTICS | TextField padrao | JA EXISTIA | Widget/doubt | Testar limite |
| 134 | Anexo de audio em duvida | REF-SCROLL-CODE | Existe modulo `doubt_audio`, nao validado aqui | BLOQUEADO | N/A | Auditar audio |
| 135 | Composer universal fora da duvida | REF-SLACK-HISTORY | Aula usa botoes, nao chat livre | NAO APLICAVEL | N/A | Manter dominio pedagogico |
| 136 | Read-only quando aula bloqueada | REF-SCROLL-CODE | Fases controlam interacao | JA EXISTIA | Classroom tests | Preservar |
| 137 | Optimistic UI para resposta | REF-WHATSAPP-TYPING | Resposta aparece como sent | AJUSTADO | Timeline tests | Ligar a fila real |
| 138 | Retry de mensagem falha | REF-WCAG-STATUS | Erro com retry global | JA EXISTIA | Widget tests | Granularizar |
| 139 | Fila offline universal | REF-SLACK-HISTORY | Nao comprovada no chat | BLOQUEADO | N/A | Auditar sync/offline |
| 140 | Idempotencia de envio | REF-SLACK-HISTORY | Parcial por phase/locks | BLOQUEADO | N/A | Criar chave por evento |
| 141 | Reconciliacao local/cloud | REF-SLACK-HISTORY | Fora da fatia | BLOQUEADO | N/A | Auditar sync |
| 142 | Backoff de retry | REF-SLACK-HISTORY | Nao comprovado no palco | BLOQUEADO | N/A | Criar policy |
| 143 | Timeout humano | REF-WCAG-STATUS | Erros traduzidos | JA EXISTIA | Runtime tests | Preservar |
| 144 | Erro 401/403 sem dados sensiveis | REF-WCAG-STATUS | Nao alterado | BLOQUEADO | N/A | Auditar auth |
| 145 | Rate limit humano | REF-SLACK-HISTORY | Nao comprovado | BLOQUEADO | N/A | Auditar API |
| 146 | Typing/processing indicator | REF-TELEGRAM-ACTION | `processing` message | AJUSTADO | Timeline/widget | Preservar |
| 147 | Indicador de leitura | REF-WHATSAPP-TYPING | Historico `read` | AJUSTADO | Timeline tests | Persistir leitura real |
| 148 | Indicador entregue | REF-WHATSAPP-TYPING | SIM `delivered` | AJUSTADO | Widget tests | Preservar |
| 149 | Indicador enviado | REF-WHATSAPP-TYPING | Aluno `sent` | AJUSTADO | Timeline tests | Preservar |
| 150 | Indicador falhou | REF-WCAG-STATUS | Erros `failed` | AJUSTADO | Widget tests | Preservar |
| 151 | Indicador global online/offline | REF-SLACK-HISTORY | Nao comprovado no chat | BLOQUEADO | N/A | Auditar conectividade |
| 152 | Badge de mensagens novas | REF-SLACK-HISTORY | Nao ha inbox universal | NAO APLICAVEL | N/A | Reavaliar com inbox |
| 153 | Estado de upload | REF-WHATSAPP-TYPING | Nao comprovado | BLOQUEADO | N/A | Auditar anexos |
| 154 | Estado de download | REF-SLACK-HISTORY | Nao comprovado | BLOQUEADO | N/A | Auditar anexos |
| 155 | Estado de gerando imagem | REF-TELEGRAM-ACTION | `imageStatus loading` | JA EXISTIA | Media tests | Preservar |
| 156 | Markdown em texto do SIM | REF-SLACK-HISTORY | Texto simples atual | BLOQUEADO | N/A | Decidir renderer seguro |
| 157 | Links clicaveis seguros | REF-FLUTTER-SEMANTICS | Nao comprovado | BLOQUEADO | N/A | Sanitizar/allowlist |
| 158 | Tabelas em mensagem | REF-SLACK-HISTORY | Nao comprovado | BLOQUEADO | N/A | Criar rich renderer |
| 159 | Codigo em mensagem | REF-SLACK-HISTORY | Nao comprovado | BLOQUEADO | N/A | Criar rich renderer |
| 160 | Formulas em mensagem | REF-SLACK-HISTORY | Nao comprovado | BLOQUEADO | N/A | Criar renderer matematico |
| 161 | Texto longo sem overflow | REF-FLUTTER-SEMANTICS | Widgets com Expanded/Text | JA EXISTIA | Widget tests | Ampliar golden |
| 162 | Fonte escalavel | REF-FLUTTER-SEMANTICS | `SimTypography` | JA EXISTIA | Widget tests | Auditar text scale |
| 163 | Contraste por tema | REF-FLUTTER-SEMANTICS | Palette central | JA EXISTIA | Theme tests | Ampliar contraste |
| 164 | Nao depender so de cor | REF-WCAG-STATUS | Status text + labels | MELHORADO | Widget semantics | Preservar |
| 165 | Ordem de foco previsivel | REF-FLUTTER-SEMANTICS | `OrdinalSortKey` | MELHORADO | Widget semantics | Preservar |
| 166 | Labels em botoes de opcao | REF-FLUTTER-SEMANTICS | `answer_option_named` | JA EXISTIA | Widget tests | Preservar |
| 167 | Labels em imagem historica | REF-FLUTTER-SEMANTICS | Label generico | MELHORADO | Widget tests | Melhorar alt pedagogico |
| 168 | Labels em erro | REF-WCAG-STATUS | Semantics + failed | MELHORADO | Widget semantics | Preservar |
| 169 | Labels em loading | REF-WCAG-STATUS | Semantics + processing | MELHORADO | Widget semantics | Preservar |
| 170 | Reduced motion | REF-FLUTTER-SEMANTICS | Nao auditado | BLOQUEADO | N/A | Auditar animacoes |
| 171 | Safe area mobile | REF-FLUTTER-SEMANTICS | Layout existente | JA EXISTIA | Widget tests | Preservar |
| 172 | Android back no sheet | REF-FLUTTER-SEMANTICS | Bottom sheet padrao | JA EXISTIA | Widget tests | Testar explicitamente |
| 173 | Long press em mensagem | REF-SLACK-HISTORY | Nao ha acoes universais | BLOQUEADO | N/A | Produto/UX |
| 174 | Swipe em mensagem | REF-SLACK-HISTORY | Nao ha gesto universal | BLOQUEADO | N/A | Produto/UX |
| 175 | Pull to refresh | REF-SLACK-HISTORY | Nao aplicavel a aula viva | NAO APLICAVEL | N/A | Manter sync automatico |
| 176 | Haptic feedback | REF-FLUTTER-SEMANTICS | Nao comprovado | BLOQUEADO | N/A | Auditar plataforma |
| 177 | Tablet layout | REF-FLUTTER-SEMANTICS | Responsivo basico | BLOQUEADO | N/A | Teste viewport tablet |
| 178 | Performance 100 mensagens | REF-SLACK-PAGINATION | ListView sem profiling | BLOQUEADO | N/A | Criar benchmark |
| 179 | Performance 1000 mensagens | REF-SLACK-PAGINATION | Sem paginacao dedicada | BLOQUEADO | N/A | Criar virtualizacao |
| 180 | Evitar layout shift com imagem | REF-FLUTTER-SEMANTICS | Constraints imagem | JA EXISTIA | Media/widget | Preservar |
| 181 | Dispose de scroll controller proprio | REF-FLUTTER-SEMANTICS | Controladores descartados | JA EXISTIA | Widget tests | Preservar |
| 182 | Dispose de listeners | REF-FLUTTER-SEMANTICS | Tela descarta recursos | JA EXISTIA | Widget tests | Preservar |
| 183 | Cancelamento ao sair de rota | REF-FLUTTER-SEMANTICS | Audio lifecycle, requests nao completos | BLOQUEADO | N/A | Auditar async requests |
| 184 | Logs de envio | REF-SLACK-HISTORY | Fora da fatia | BLOQUEADO | N/A | Auditar telemetria |
| 185 | Logs de erro | REF-WCAG-STATUS | Fora da fatia | BLOQUEADO | N/A | Auditar logging |
| 186 | Telemetria de scroll | REF-SLACK-PAGINATION | Nao comprovado | BLOQUEADO | N/A | Criar metricas |
| 187 | Telemetria de midia | REF-SLACK-HISTORY | Nao comprovado | BLOQUEADO | N/A | Auditar media |
| 188 | Request id em erro | REF-SLACK-HISTORY | Nao comprovado no label | BLOQUEADO | N/A | Expor detalhe tecnico oculto |
| 189 | Crash breadcrumbs | REF-SLACK-HISTORY | Nao comprovado | BLOQUEADO | N/A | Auditar observabilidade |
| 190 | Teste unitario do modelo | REF-SCROLL-TESTS | Timeline builder cobre modelo | JA EXISTIA | Timeline tests | Preservar |
| 191 | Teste widget de semantica | REF-FLUTTER-SEMANTICS | `chat_aula_widgets_test.dart` | CRIADO | Widget semantics | Preservar |
| 192 | Teste de status delivery | REF-WHATSAPP-TYPING | Timeline/widget tests | CRIADO | Timeline/widget | Preservar |
| 193 | Teste de historico com imagem | REF-SCROLL-TESTS | Widget test | CRIADO | Widget tests | Preservar |
| 194 | Teste de timestamp | REF-SLACK-HISTORY | Timeline test | CRIADO | Timeline tests | Preservar |
| 195 | Teste de sequencia | REF-FLUTTER-SEMANTICS | Timeline test | CRIADO | Timeline tests | Preservar |
| 196 | Teste de full suite | REF-SCROLL-TESTS | Suite Flutter validada anteriormente | PRESERVADO | 360 testes | Reexecutar apos doc |
| 197 | Prompt inalterado | Regra do usuario | Nenhum arquivo de prompt tocado | PRESERVADO | Git diff | Preservar |
| 198 | Servidor inalterado | Regra do usuario | Nenhum backend tocado | PRESERVADO | Git diff | Preservar |
| 199 | Creditos/funil pago inalterados | Regra do usuario | Funil de paid image preservado | PRESERVADO | Media tests | Preservar |
| 200 | Cache/reuso antigo nao reintroduzido | Regra do usuario | Media/cache tests existentes | PRESERVADO | Media tests | Preservar |

## Itens nao implementados nesta fatia

Os itens classificados como BLOQUEADO nao foram implementados porque exigem uma destas condicoes: decisao de produto, contrato de backend, persistencia nova, indice global, politica de sync/offline, telemetria de infraestrutura, renderer rico seguro, auditoria especifica de audio/anexos, ou autorizacao explicita para mudar comportamento fora do palco atual da aula.

Risco de manter bloqueados: o palco conversacional atual fica funcional para a aula, mas ainda nao e um motor universal completo no nivel de Slack/Telegram/WhatsApp/ChatGPT para inbox global, busca, paginacao historica, offline queue, rich content universal e observabilidade profunda.

Acao futura recomendada: transformar cada BLOQUEADO em uma fatia propria com referencia, contrato, teste e implementacao incremental, sem misturar com prompts, servidor, creditos ou cache proibido.

## Confirmacoes

- Nenhum prompt foi alterado por esta fatia.
- Nenhum servidor/backend foi alterado por esta fatia.
- Nenhum credito ou funil pago foi alterado por esta fatia.
- Nenhum cache proibido ou reaproveitamento de imagem antiga foi reintroduzido por esta fatia.
- Esta fatia nao declara conclusao da meta de 4.000; declara apenas 200 itens classificados com evidencia.

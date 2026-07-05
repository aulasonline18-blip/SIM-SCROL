# Motor Conversacional Universal - checkpoint 201-500

Data: 2026-07-05

Escopo: segunda fatia da meta de exaustao estrutural do Motor Conversacional Universal. Este relatorio adiciona 300 unidades funcionais auditaveis, numeradas de 201 a 500, em continuidade ao arquivo `docs/universal-conversation-engine-audit-200.md`.

Total acumulado formal: 500 itens classificados. Em uma meta nominal de 4.000 unidades, isso representa 12,5%.

## Referencias comprovadas

- REF-WCAG-STATUS: W3C WCAG 2.2, Success Criterion 4.1.3 Status Messages. Autoriza estados de espera, progresso e erro anunciaveis sem deslocar foco.
- REF-SLACK-HISTORY: Slack `conversations.history`. Autoriza historico ordenado, checagem de erro, limites e continuidade conversacional.
- REF-SLACK-PAGINATION: Slack Web API Pagination. Autoriza particionamento/cursor para colecoes longas.
- REF-WHATSAPP-TYPING: Meta WhatsApp Business typing/read indicators. Autoriza estados de processamento, leitura e feedback de entrega.
- REF-TELEGRAM-ACTION: Telegram Bot API `sendChatAction`. Autoriza sinalizar processamento perceptivel do lado do bot.
- REF-FLUTTER-SEMANTICS: Flutter `Semantics`, `ValueNotifier`, `Listenable`, controllers e ciclo de vida de widgets.
- REF-SCROLL-AUDIO: `lib/sim/media/audio_core.dart`, `lesson_audio_controller.dart`, `student_lesson_media_service.dart`, `platform_audio_adapter.dart`, `lesson_audio_api_contract.dart`.
- REF-SCROLL-STATE: `lib/sim/state/student_state_store.dart`, `student_learning_state.dart`, `internal_organs_governor.dart`, `student_state_store_adapter.dart`.
- REF-SCROLL-READY: `lib/sim/lesson/dopamine_ready_window_engine.dart`, `lesson_orchestrator.dart`, `student_lesson_material_service.dart`, `lesson_material_cache.dart`.
- REF-SCROLL-AUX: `lib/sim/auxiliary/lesson_doubt_controller.dart`, `doubt_t02_caller.dart`, `doubt_input_sheet.dart`, `student_aux_room_service.dart`, `aux_rooms_controller.dart`.
- REF-SCROLL-TESTS: `media_phase_test.dart`, `student_state_backup_sync_b_test.dart`, `first_lesson_ready_window_test.dart`, `auxiliary_phase_test.dart`, `chat_aula_widgets_test.dart`, `chat_aula_timeline_builder_test.dart`.

## Matriz 201-500

| ID | Unidade auditavel | Referencia | Evidencia Scroll | Status | Teste/prova | Proxima acao |
|---:|---|---|---|---|---|---|
| 201 | Audio possui preferencia liga/desliga | REF-SCROLL-AUDIO | `AudioPreference` | JA EXISTIA | media_phase | Preservar |
| 202 | Desligar audio para playback ativo | REF-SCROLL-AUDIO | `preference.subscribe` chama `stop` | JA EXISTIA | media_phase | Preservar |
| 203 | Audio rejeita texto vazio | REF-SCROLL-AUDIO | `clean.isEmpty` retorna false | JA EXISTIA | media_phase | Preservar |
| 204 | Audio nao bloqueia quando desativado | REF-SCROLL-AUDIO | `getAudioEnabled` false | JA EXISTIA | media_phase | Preservar |
| 205 | Audio chama `onEnd` se desativado | REF-SCROLL-AUDIO | `opts.onEnd?.call()` | JA EXISTIA | media_phase | Preservar |
| 206 | Audio remoto antes do TTS local | REF-SCROLL-AUDIO | `generatedAudioClient` antes de platform TTS | JA EXISTIA | media_phase | Preservar |
| 207 | Fallback para TTS local | REF-SCROLL-AUDIO | `speakWithPlatformTts` | JA EXISTIA | media_phase | Preservar |
| 208 | Erro remoto nao derruba audio | REF-WCAG-STATUS | catch + `onGeneratedAudioError` | JA EXISTIA | media_phase | Preservar |
| 209 | Cache de audio em memoria | REF-SCROLL-AUDIO | `_generatedAudioCache` | JA EXISTIA | media_phase | Preservar |
| 210 | Cache de audio tem limite | REF-SCROLL-AUDIO | `maxAudioCache` | JA EXISTIA | media_phase | Preservar |
| 211 | Cache remove entrada mais antiga | REF-SCROLL-AUDIO | remove first key | JA EXISTIA | media_phase | Preservar |
| 212 | Chave de cache inclui aula | REF-SCROLL-AUDIO | `lessonKey` em `audioCacheKey` | JA EXISTIA | media_phase | Preservar |
| 213 | Chave de cache inclui idioma | REF-SCROLL-AUDIO | lang em `audioCacheKey` | JA EXISTIA | media_phase | Preservar |
| 214 | Chave de cache inclui voz | REF-SCROLL-AUDIO | voice em `audioCacheKey` | JA EXISTIA | media_phase | Preservar |
| 215 | Chave de cache inclui hash do texto | REF-SCROLL-AUDIO | `hashString(text)` | JA EXISTIA | media_phase | Preservar |
| 216 | Replay usa cache sem nova geracao | REF-SCROLL-AUDIO | `cached != null` toca dataUrl | JA EXISTIA | media_phase | Preservar |
| 217 | Replay nao cobra credito | Regra usuario | Audio nao toca funil de creditos | PRESERVADO | media_phase | Preservar |
| 218 | Audio sequencial junta partes validas | REF-SCROLL-AUDIO | `speakSequence` filtra vazio | JA EXISTIA | media_phase | Preservar |
| 219 | Audio sequencial evita ponto duplicado | REF-SCROLL-AUDIO | `replaceAll('..','.')` | JA EXISTIA | media_phase | Preservar |
| 220 | Idioma estavel vira BCP-47 | REF-SCROLL-AUDIO | `stableLangToBCP47` | JA EXISTIA | media_phase | Preservar |
| 221 | Portugues mapeado para pt-BR | REF-SCROLL-AUDIO | regex pt/portu/brasil | JA EXISTIA | media_phase | Preservar |
| 222 | Ingles mapeado para en-US | REF-SCROLL-AUDIO | regex en/engl | JA EXISTIA | media_phase | Preservar |
| 223 | Espanhol mapeado para es-ES | REF-SCROLL-AUDIO | regex es/span/espa | JA EXISTIA | media_phase | Preservar |
| 224 | Fallback de idioma seguro | REF-SCROLL-AUDIO | retorna en-US | JA EXISTIA | media_phase | Preservar |
| 225 | Voz default definida | REF-SCROLL-AUDIO | `voice = Charon` | JA EXISTIA | media_phase | Preservar |
| 226 | Velocidade default definida | REF-SCROLL-AUDIO | `rate = 1` | JA EXISTIA | media_phase | Preservar |
| 227 | Audio sabe parar playback | REF-SCROLL-AUDIO | `playback.stop()` | JA EXISTIA | media_phase | Preservar |
| 228 | Adapter real separado de core | REF-SCROLL-AUDIO | `AudioPlaybackAdapter` | JA EXISTIA | media_phase | Preservar |
| 229 | Cliente de geracao separado de core | REF-SCROLL-AUDIO | `GeneratedAudioClient` | JA EXISTIA | media_phase | Preservar |
| 230 | Noop isolado para teste | REF-SCROLL-AUDIO | `NoopAudioPlaybackAdapter` | JA EXISTIA | media_phase | Nao usar em producao |
| 231 | Producao usa adapter de plataforma | REF-SCROLL-TESTS | teste "not Noop" | PRESERVADO | media_phase | Preservar |
| 232 | Audio de aula monta explicacao | REF-SCROLL-AUDIO | `conteudo.explanation` | JA EXISTIA | media_phase | Preservar |
| 233 | Audio de aula monta pergunta | REF-SCROLL-AUDIO | `conteudo.question` | JA EXISTIA | media_phase | Preservar |
| 234 | Audio de aula le alternativa A | REF-SCROLL-AUDIO | `A: ...` | JA EXISTIA | media_phase | Preservar |
| 235 | Audio de aula le alternativa B | REF-SCROLL-AUDIO | `B: ...` | JA EXISTIA | media_phase | Preservar |
| 236 | Audio de aula le alternativa C | REF-SCROLL-AUDIO | `C: ...` | JA EXISTIA | media_phase | Preservar |
| 237 | Audio de aula respeita preferencia | REF-SCROLL-AUDIO | controller verifica `getAudioEnabled` | JA EXISTIA | media_phase | Preservar |
| 238 | Audio de aula sabe estado falando | REF-FLUTTER-SEMANTICS | `ValueNotifier<bool>` | JA EXISTIA | media_phase | Preservar |
| 239 | UI pode reagir a estado falando | REF-FLUTTER-SEMANTICS | `falandoNotifier` | JA EXISTIA | widget/media | Preservar |
| 240 | Tocar novamente alterna para parar | REF-SCROLL-AUDIO | `ouvirAula` para se falando | JA EXISTIA | media_phase | Preservar |
| 241 | Auto speak nao duplica playback | REF-SCROLL-AUDIO | `if (falando) false` | JA EXISTIA | media_phase | Preservar |
| 242 | Audio vincula posicao da aula | REF-SCROLL-AUDIO | `LessonMediaPosition` | JA EXISTIA | media_phase | Preservar |
| 243 | Audio inclui lessonLocalId | REF-SCROLL-AUDIO | position lessonLocalId | JA EXISTIA | media_phase | Preservar |
| 244 | Audio inclui marker do item | REF-SCROLL-AUDIO | position itemMarker | JA EXISTIA | media_phase | Preservar |
| 245 | Audio inclui layer | REF-SCROLL-AUDIO | position layer | JA EXISTIA | media_phase | Preservar |
| 246 | Audio limpa estado se falha iniciar | REF-SCROLL-AUDIO | `if (!started) falando=false` | JA EXISTIA | media_phase | Preservar |
| 247 | Stop externo limpa estado | REF-SCROLL-AUDIO | `pararAudio` | JA EXISTIA | media_phase | Preservar |
| 248 | Audio nao toca aula errada por chave | REF-SCROLL-AUDIO | lessonKey/cache key | PRESERVADO | media_phase | Ampliar teste |
| 249 | Cache em disco de audio | REF-SLACK-HISTORY | nao existe contrato auditado | BLOQUEADO | N/A | Projetar storage |
| 250 | Transcricao/captions de audio | REF-WCAG-STATUS | Texto equivalente existe, caption dedicado nao | BLOQUEADO | N/A | Criar contrato acessivel |
| 251 | Progresso temporal do audio | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | Expor stream de progresso |
| 252 | Duracao do audio | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | Adapter deve expor duracao |
| 253 | Pausa/resume real | REF-SCROLL-AUDIO | adapter so tem stop/play | BLOQUEADO | N/A | Ampliar contrato |
| 254 | Controle de volume | REF-SCROLL-AUDIO | nao existe no contrato | BLOQUEADO | N/A | Produto/plataforma |
| 255 | Velocidade de playback ajustavel na UI | REF-SCROLL-AUDIO | rate existe, UI nao comprovada | BLOQUEADO | N/A | Criar controle |
| 256 | Bolha flutuante mostra audio ativo | REF-SCROLL-TESTS | widget test cobre bolha | JA EXISTIA | chat_aula_widgets | Preservar |
| 257 | Bolha de audio para no toque | REF-SCROLL-TESTS | "stops audio on tap" | JA EXISTIA | chat_aula_widgets | Preservar |
| 258 | Audio para ao escolher resposta | REF-SCROLL-TESTS | "stop covers answer selection" | JA EXISTIA | media_phase | Preservar |
| 259 | Audio para ao sinalizar | REF-SCROLL-TESTS | "stop covers signal" | JA EXISTIA | media_phase | Preservar |
| 260 | Audio para ao avancar | REF-SCROLL-TESTS | "stop covers advance" | JA EXISTIA | media_phase | Preservar |
| 261 | Audio para no dispose | REF-SCROLL-TESTS | "stop covers dispose paths" | JA EXISTIA | media_phase | Preservar |
| 262 | Request de audio canônico | REF-SCROLL-STATE | `requestAudio` governor | JA EXISTIA | internal_organs | Preservar |
| 263 | Audio pronto canônico | REF-SCROLL-STATE | `AUDIO_READY`/media state | JA EXISTIA | internal_organs | Preservar |
| 264 | Audio falho canônico | REF-SCROLL-STATE | failure event | JA EXISTIA | internal_organs | Preservar |
| 265 | Audio pendente sem chamada real | REF-SCROLL-TESTS | "sem chamada real fica pendente" | JA EXISTIA | internal_organs | Preservar |
| 266 | Audio pronto com chamada real | REF-SCROLL-TESTS | "com chamada real fica pronto" | JA EXISTIA | internal_organs | Preservar |
| 267 | Audio sincroniza apos sucesso | REF-SCROLL-STATE | coordinator syncAfter | JA EXISTIA | internal_organs | Preservar |
| 268 | Audio falha sem fingir sucesso | REF-WCAG-STATUS | failure result | JA EXISTIA | internal_organs | Preservar |
| 269 | Audio nao altera prompt | Regra usuario | arquivos prompt nao tocados | PRESERVADO | git diff | Preservar |
| 270 | Audio nao altera servidor | Regra usuario | backend nao tocado | PRESERVADO | git diff | Preservar |
| 271 | Estado canônico tem eventId | REF-SLACK-HISTORY | `CanonicalLearningEvent.eventId` | JA EXISTIA | state tests | Preservar |
| 272 | Estado canônico tem tipo | REF-SLACK-HISTORY | `type` | JA EXISTIA | state tests | Preservar |
| 273 | Estado canônico tem lessonLocalId | REF-SLACK-HISTORY | `lessonLocalId` | JA EXISTIA | state tests | Preservar |
| 274 | Estado canônico tem userId opcional | REF-SLACK-HISTORY | `userId` | JA EXISTIA | state tests | Preservar |
| 275 | Estado canônico tem payload | REF-SLACK-HISTORY | `payload` | JA EXISTIA | state tests | Preservar |
| 276 | Estado canônico tem timestamp | REF-SLACK-HISTORY | `createdAt` | JA EXISTIA | state tests | Preservar |
| 277 | Estado canônico tem source | REF-SLACK-HISTORY | `source` | JA EXISTIA | state tests | Preservar |
| 278 | Estado canônico tem schemaVersion | REF-SCROLL-STATE | `schemaVersion` | JA EXISTIA | state tests | Preservar |
| 279 | Evento preserva versao anterior | REF-SCROLL-STATE | `stateVersionBefore` | JA EXISTIA | state tests | Preservar |
| 280 | Evento preserva versao posterior | REF-SCROLL-STATE | `stateVersionAfter` | JA EXISTIA | state tests | Preservar |
| 281 | Evento converte para legado | REF-SCROLL-STATE | `toLegacyEvent` | JA EXISTIA | state tests | Preservar |
| 282 | Evento serializa JSON | REF-SCROLL-STATE | `toJson` | JA EXISTIA | state tests | Preservar |
| 283 | Evento hidrata de JSON | REF-SCROLL-STATE | `fromJson` | JA EXISTIA | state tests | Preservar |
| 284 | Evento tolera `ts` legado | REF-SCROLL-STATE | fallback `json['ts']` | JA EXISTIA | state tests | Preservar |
| 285 | Store local le estado por aula | REF-SCROLL-STATE | `readState(lessonLocalId)` | JA EXISTIA | cloud/state tests | Preservar |
| 286 | Store local escreve estado por aula | REF-SCROLL-STATE | `writeState` | JA EXISTIA | cloud/state tests | Preservar |
| 287 | Store local le eventos | REF-SCROLL-STATE | `readEvents` | JA EXISTIA | state tests | Preservar |
| 288 | Store local escreve eventos | REF-SCROLL-STATE | `writeEvents` | JA EXISTIA | state tests | Preservar |
| 289 | Store lista aulas locais | REF-SCROLL-STATE | `listStateIds` | JA EXISTIA | backup/sync | Preservar |
| 290 | Store tem cache em memoria | REF-SCROLL-STATE | `_memory` | JA EXISTIA | state tests | Preservar |
| 291 | Store tem event log em memoria | REF-SCROLL-STATE | `_eventLog` | JA EXISTIA | state tests | Preservar |
| 292 | Store tolera JSON local invalido | REF-SCROLL-STATE | catch FormatException | JA EXISTIA | state tests | Preservar |
| 293 | Store cria estado vazio seguro | REF-SCROLL-STATE | `StudentLearningState.empty` | JA EXISTIA | state tests | Preservar |
| 294 | Store grava updatedAt | REF-SCROLL-STATE | `copyWith(updatedAt: now())` | JA EXISTIA | state tests | Preservar |
| 295 | Store aplica patch atomico local | REF-SCROLL-STATE | `patchState` | JA EXISTIA | state tests | Preservar |
| 296 | Mutacao sempre gera evento | REF-SCROLL-STATE | `mutateWithEvent` | JA EXISTIA | state tests | Preservar |
| 297 | Mutacao inclui foundation revision before | REF-SCROLL-STATE | payload revision before | JA EXISTIA | state tests | Preservar |
| 298 | Mutacao inclui foundation revision after | REF-SCROLL-STATE | payload revision after | JA EXISTIA | state tests | Preservar |
| 299 | Mutacao preserva userId do estado | REF-SCROLL-STATE | `userId ?? before.userId` | JA EXISTIA | state tests | Preservar |
| 300 | Store tem cloud opcional | REF-SCROLL-STATE | `StudentStateCloudStorage?` | JA EXISTIA | cloud tests | Preservar |
| 301 | Cloud load por aula | REF-SCROLL-STATE | `loadCloud` | JA EXISTIA | cloud tests | Preservar |
| 302 | Cloud persist por estado | REF-SCROLL-STATE | `persistCloud` | JA EXISTIA | cloud tests | Preservar |
| 303 | Hidratacao cloud resolve conflito | REF-SCROLL-STATE | `hydrateFromCloud`/`syncState` | JA EXISTIA | sync tests | Preservar |
| 304 | Persistencia cloud separada da UI | REF-SCROLL-STATE | Store/governor | JA EXISTIA | sync tests | Preservar |
| 305 | Status de sync tipado | REF-SCROLL-STATE | `StudentSyncStatus` | JA EXISTIA | sync tests | Preservar |
| 306 | Audio state tipado | REF-SCROLL-STATE | `StudentAudioState` | JA EXISTIA | media/state | Preservar |
| 307 | Sync multi-dispositivo converge | REF-SCROLL-TESTS | `multi_device_state_sync_test` | JA EXISTIA | sync tests | Preservar |
| 308 | Backup restaura estado | REF-SCROLL-TESTS | backup sync test | JA EXISTIA | sync tests | Preservar |
| 309 | Estado deletado nao sincroniza como ativo | REF-SCROLL-STATE | `deletedAt` check | JA EXISTIA | sync tests | Preservar |
| 310 | Fila cloud local | REF-SCROLL-TESTS | `CloudQueue` tests | JA EXISTIA | sync tests | Preservar |
| 311 | Drain de fila cloud | REF-SCROLL-TESTS | `drainQueue` | JA EXISTIA | sync tests | Preservar |
| 312 | Conflito local/cloud classificado | REF-SCROLL-STATE | `StateConflictResolution` | JA EXISTIA | sync tests | Preservar |
| 313 | Merge profundo de attempts | REF-SCROLL-TESTS | bloco1 merge test | JA EXISTIA | full suite | Preservar |
| 314 | Estado stale detectado por versao | REF-SCROLL-STATE | stateVersion/revision | JA EXISTIA | state tests | Ampliar teste |
| 315 | Criptografia local de estado | REF-SLACK-HISTORY | nao comprovada | BLOQUEADO | N/A | Requer arquitetura seguranca |
| 316 | Retencao/LGPD por conversa | REF-SLACK-HISTORY | nao comprovada | BLOQUEADO | N/A | Produto/legal |
| 317 | Exportacao universal de conversa | REF-SLACK-HISTORY | backup existe, nao universal | BLOQUEADO | N/A | Definir contrato |
| 318 | Importacao universal de conversa | REF-SLACK-HISTORY | backup existe, nao universal | BLOQUEADO | N/A | Definir contrato |
| 319 | Apagar conversa com tombstone | REF-SCROLL-STATE | deletedAt parcial | BLOQUEADO | sync tests parciais | Completar UX |
| 320 | Auditoria sem dados sensiveis | REF-SLACK-HISTORY | nao comprovada completa | BLOQUEADO | N/A | Auditar logs |
| 321 | Ready window constrói slot A | REF-SCROLL-READY | loop A/B/C | JA EXISTIA | first_lesson_ready | Preservar |
| 322 | Ready window constrói slot B | REF-SCROLL-READY | loop A/B/C | JA EXISTIA | first_lesson_ready | Preservar |
| 323 | Ready window constrói slot C | REF-SCROLL-READY | loop A/B/C | JA EXISTIA | first_lesson_ready | Preservar |
| 324 | Ready window respeita maxSlots | REF-SCROLL-READY | `take(maxSlots...)` | JA EXISTIA | first_lesson_ready | Preservar |
| 325 | Return mode limita a 2 slots | REF-SCROLL-READY | `returnMode ? 2 : 3` | JA EXISTIA | first_lesson_ready | Preservar |
| 326 | Slot carrega itemIdx | REF-SCROLL-READY | `DopamineReadySlot.itemIdx` | JA EXISTIA | first_lesson_ready | Preservar |
| 327 | Slot carrega marker | REF-SCROLL-READY | `marker` | JA EXISTIA | first_lesson_ready | Preservar |
| 328 | Slot carrega layer | REF-SCROLL-READY | `layer` | JA EXISTIA | first_lesson_ready | Preservar |
| 329 | Slot carrega params T02 | REF-SCROLL-READY | `CompleteLessonParams` | JA EXISTIA | first_lesson_ready | Preservar |
| 330 | Slot carrega expectedKey | REF-SCROLL-READY | `expectedKey` | JA EXISTIA | first_lesson_ready | Preservar |
| 331 | Ready window registra request | REF-SCROLL-READY | `DOPAMINE_WINDOW_REQUESTED` | JA EXISTIA | first_lesson_ready | Preservar |
| 332 | Ready window valida chave | REF-SCROLL-READY | key parity check | JA EXISTIA | first_lesson_ready | Preservar |
| 333 | Ready window loga mismatch | REF-SCROLL-READY | `DOPAMINE_KEY_MISMATCH` | JA EXISTIA | first_lesson_ready | Preservar |
| 334 | Ready window reaproveita state pronto | REF-SCROLL-READY | `_readReadyMaterial` | JA EXISTIA | first_lesson_ready | Preservar |
| 335 | Ready window reaproveita cache pronto | REF-SCROLL-READY | `peekCachedLesson` | JA EXISTIA | first_lesson_ready | Preservar |
| 336 | Cache pronto espelha para state | REF-SCROLL-READY | `_mirrorPreparedLesson` | JA EXISTIA | first_lesson_ready | Preservar |
| 337 | Primeiro slot marca T02 rodando | REF-SCROLL-READY | `t02FirstLessonRunning` | JA EXISTIA | first_lesson_ready | Preservar |
| 338 | Slot requested tem prioridade active | REF-SCROLL-READY | index 0 active | JA EXISTIA | first_lesson_ready | Preservar |
| 339 | Slot requested tem prioridade background | REF-SCROLL-READY | index >0 background | JA EXISTIA | first_lesson_ready | Preservar |
| 340 | Prefetch T02 por slot | REF-SCROLL-READY | `prefetchCompleteLesson` | JA EXISTIA | first_lesson_ready | Preservar |
| 341 | Slot pronto espelha material | REF-SCROLL-READY | `_mirrorPreparedLesson` | JA EXISTIA | first_lesson_ready | Preservar |
| 342 | Slot pronto registra evento | REF-SCROLL-READY | `DOPAMINE_SLOT_READY` | JA EXISTIA | first_lesson_ready | Preservar |
| 343 | Falha do primeiro slot atualiza live entry | REF-SCROLL-READY | `failedT02` | JA EXISTIA | first_lesson_ready | Preservar |
| 344 | Falha de slot background nao derruba janela | REF-SCROLL-READY | `results.add(false)` | JA EXISTIA | first_lesson_ready | Preservar |
| 345 | Ready window registra conclusao | REF-SCROLL-READY | `DOPAMINE_WINDOW_READY` | JA EXISTIA | first_lesson_ready | Preservar |
| 346 | Ready window dedupe inflight | REF-SCROLL-READY | `_inflight[lessonLocalId]` | JA EXISTIA | first_lesson_ready | Preservar |
| 347 | Ready window limpa inflight no finally | REF-SCROLL-READY | `finally remove` | JA EXISTIA | first_lesson_ready | Preservar |
| 348 | Ready window roda do state | REF-SCROLL-READY | `runDopamineReadyWindowFromStudentState` | JA EXISTIA | first_lesson_ready | Preservar |
| 349 | Ready window nao duplica jobs ativos | REF-SCROLL-TESTS | teste dedicado | JA EXISTIA | first_lesson_ready | Preservar |
| 350 | Ready window espelha metadados | REF-SCROLL-TESTS | mirror cache window test | JA EXISTIA | first_lesson_ready | Preservar |
| 351 | Ready window ignora cache persistente invalido | REF-SCROLL-TESTS | invalid cache ignored | JA EXISTIA | first_lesson_ready | Preservar |
| 352 | Ready window prepara A/B/C | REF-SCROLL-TESTS | prepares A/B/C slots | JA EXISTIA | first_lesson_ready | Preservar |
| 353 | Ready window agenda visual gratuito | REF-SCROLL-TESTS | ready material visual | JA EXISTIA | first_lesson_ready | Preservar |
| 354 | Ready window preserva visual_trigger revisao | REF-SCROLL-TESTS | review visual trigger | JA EXISTIA | first_lesson_ready | Preservar |
| 355 | Ready window preserva visual_trigger recuperacao | REF-SCROLL-TESTS | recovery visual trigger | JA EXISTIA | first_lesson_ready | Preservar |
| 356 | Ready window nao cria imagem paga em background | REF-SCROLL-TESTS | background paid test | JA EXISTIA | first_lesson_ready | Preservar |
| 357 | Ready window reexecuta material invalido | REF-SCROLL-TESTS | invalid ready state material | JA EXISTIA | first_lesson_ready | Preservar |
| 358 | Ready window atualiza live first lesson | REF-SCROLL-READY | `_markFirstLessonIfNeeded` | JA EXISTIA | first_lesson_ready | Preservar |
| 359 | Ready window com reviewLayer | REF-SCROLL-READY | `DopamineWindowItem.reviewLayer` | JA EXISTIA | first_lesson_ready | Preservar |
| 360 | Ready window com item de review | REF-SCROLL-READY | `isReview` | JA EXISTIA | first_lesson_ready | Preservar |
| 361 | Ready window com fim de curriculo | REF-SCROLL-READY | cursor null/break | JA EXISTIA | first_lesson_ready | Preservar |
| 362 | Ready window nao prepara layer inexistente | REF-SCROLL-READY | `_nextSlot` controla cursor | JA EXISTIA | first_lesson_ready | Preservar |
| 363 | Ready window respeita start atual | REF-SCROLL-READY | currentItemIdx/currentLayer | JA EXISTIA | first_lesson_ready | Preservar |
| 364 | Ready window por item novo T00 | REF-SCROLL-TESTS | expansion triggers callback | JA EXISTIA | student_experience_t00 | Preservar |
| 365 | Ready window apos placement | REF-SCROLL-TESTS | placement + ready test | JA EXISTIA | first_lesson_ready | Preservar |
| 366 | Ready window apos resposta | REF-SCROLL-READY | runtime/orchestrator parcial | BLOQUEADO | N/A | Provar evento por resposta |
| 367 | Ready window apos duvida | REF-SCROLL-READY | nao comprovado | BLOQUEADO | N/A | Criar gatilho |
| 368 | Ready window apos sync/reload | REF-SCROLL-READY | nao comprovado | BLOQUEADO | N/A | Criar teste restore |
| 369 | Ready window telemetria tempo ate ready | REF-SCROLL-READY | eventos existem, metrica duracao nao | BLOQUEADO | N/A | Adicionar medicao |
| 370 | Ready window cancelamento por rota | REF-FLUTTER-SEMANTICS | inflight nao cancelavel | BLOQUEADO | N/A | Projetar cancel token |
| 371 | Duvida tem estados tipados | REF-SCROLL-AUX | `DoubtStatus` | JA EXISTIA | auxiliary_phase | Preservar |
| 372 | Duvida inicia idle | REF-SCROLL-AUX | `DoubtState.idle` | JA EXISTIA | auxiliary_phase | Preservar |
| 373 | Abrir duvida nao duplica processamento | REF-SCROLL-AUX | `if processing return` | JA EXISTIA | auxiliary_phase | Preservar |
| 374 | Dismiss limpa duvida | REF-SCROLL-AUX | `dismissDoubt` | JA EXISTIA | auxiliary_phase | Preservar |
| 375 | Duvida valida input antes de enviar | REF-SCROLL-AUX | `input.validate` | JA EXISTIA | auxiliary_phase | Preservar |
| 376 | Duvida vazia mostra erro humano | REF-SCROLL-AUX | `emptyDoubtMessage` | JA EXISTIA | auxiliary_phase | Preservar |
| 377 | Duvida entra em processing | REF-WCAG-STATUS | `DoubtStatus.processing` | JA EXISTIA | auxiliary_phase | Preservar |
| 378 | Duvida chama T02 modo duvida | REF-SCROLL-AUX | `DoubtT02Caller.call` | JA EXISTIA | auxiliary_phase | Preservar |
| 379 | Duvida envia texto limpo | REF-SCROLL-AUX | `input.cleanText` | JA EXISTIA | auxiliary_phase | Preservar |
| 380 | Duvida envia imagem opcional | REF-SCROLL-AUX | `doubtImage` | JA EXISTIA | auxiliary_phase | Preservar |
| 381 | Duvida aceita texto default contextual | REF-SCROLL-AUX | `defaultDoubtText` | JA EXISTIA | auxiliary_phase | Preservar |
| 382 | Duvida preserva visualTrigger | REF-SCROLL-AUX | `DoubtResponse.visualTrigger` | JA EXISTIA | auxiliary_phase | Preservar |
| 383 | Duvida sucesso vira explaining | REF-SCROLL-AUX | status explaining | JA EXISTIA | auxiliary_phase | Preservar |
| 384 | Duvida falha vira error | REF-WCAG-STATUS | catch -> defaultDoubtError | JA EXISTIA | auxiliary_phase | Preservar |
| 385 | Duvida nao bloqueia aula | REF-SCROLL-TESTS | chat feedback disabled only while processing | JA EXISTIA | chat widgets | Preservar |
| 386 | Duvida preserva questao atual | REF-SCROLL-TESTS | doubt preserves context | JA EXISTIA | auxiliary_phase | Preservar |
| 387 | Duvida preserva alternativa escolhida | REF-SCROLL-AUX | payload/contexto | JA EXISTIA | auxiliary_phase | Preservar |
| 388 | Duvida por foto aceita jpeg/png/webp | REF-SCROLL-TESTS | auxiliary photo test | JA EXISTIA | auxiliary_phase | Preservar |
| 389 | Duvida bloqueia imagem grande | REF-SCROLL-TESTS | oversized image test | JA EXISTIA | auxiliary_phase | Preservar |
| 390 | Duvida tem progresso visual | REF-SCROLL-AUX | `DoubtProgressSnapshot` | JA EXISTIA | auxiliary_phase | Preservar |
| 391 | Duvida entra no estado canônico | REF-SCROLL-STATE | `DoubtStateGovernor` | JA EXISTIA | internal_organs | Preservar |
| 392 | Duvida sincroniza | REF-SCROLL-STATE | coordinator `askDoubt` syncAfter | JA EXISTIA | internal_organs | Preservar |
| 393 | Duvida falha sem explicacao falsa | REF-SCROLL-TESTS | "duvida falha sem fingir" | JA EXISTIA | internal_organs | Preservar |
| 394 | Duvida reduz output | REF-SCROLL-AUX | nao comprovado | BLOQUEADO | N/A | Auditar payload T02 |
| 395 | Duvida por audio | REF-SCROLL-AUX | modulo existe, fluxo nao completo aqui | BLOQUEADO | N/A | Auditar audio doubt |
| 396 | Duvida por arquivo generico | REF-SCROLL-AUX | nao existe | BLOQUEADO | N/A | Produto/anexos |
| 397 | Revisao tem modo auxiliar | REF-SCROLL-AUX | `AuxRoomMode.review` | JA EXISTIA | auxiliary_phase | Preservar |
| 398 | Recuperacao tem modo auxiliar | REF-SCROLL-AUX | `AuxRoomMode.recovery` | JA EXISTIA | auxiliary_phase | Preservar |
| 399 | Sala de duvida tem modo auxiliar | REF-SCROLL-AUX | `AuxRoomMode.doubt` | JA EXISTIA | auxiliary_phase | Preservar |
| 400 | Revisao possui status tipado | REF-SCROLL-AUX | `ReviewRoomStatus` | JA EXISTIA | auxiliary_phase | Preservar |
| 401 | Recuperacao possui status tipado | REF-SCROLL-AUX | `RecoveryRoomStatus` | JA EXISTIA | auxiliary_phase | Preservar |
| 402 | Revisao monta fila | REF-SCROLL-AUX | `buildReviewQueueForLesson` | JA EXISTIA | auxiliary_phase | Preservar |
| 403 | Recuperacao monta fila | REF-SCROLL-AUX | `buildRecoveryQueueForLesson` | JA EXISTIA | auxiliary_phase | Preservar |
| 404 | Revisao responde e completa | REF-SCROLL-TESTS | review room test | JA EXISTIA | auxiliary_phase | Preservar |
| 405 | Recuperacao inicia quando ha pendencia | REF-SCROLL-TESTS | recovery room test | JA EXISTIA | auxiliary_phase | Preservar |
| 406 | Aux rooms preservam comandos | REF-SCROLL-TESTS | aux rooms controller test | JA EXISTIA | auxiliary_phase | Preservar |
| 407 | Recovery gate impede finalizacao prematura | REF-SCROLL-AUX | `lesson_recovery_gate` | JA EXISTIA | auxiliary_phase | Preservar |
| 408 | Aux queue entra em estado canônico | REF-SCROLL-STATE | `AuxiliaryStateGovernor` | JA EXISTIA | internal_organs | Preservar |
| 409 | Review nao apaga progresso normal | REF-SCROLL-AUX | fila auxiliar separada | JA EXISTIA | auxiliary_phase | Preservar |
| 410 | Recovery nao apaga progresso normal | REF-SCROLL-AUX | fila auxiliar separada | JA EXISTIA | auxiliary_phase | Preservar |
| 411 | Historico alimenta review/recovery | REF-SCROLL-AUX | service usa StudentLearningState | JA EXISTIA | auxiliary_phase | Preservar |
| 412 | Mastery alimenta decisao auxiliar | REF-SCROLL-STATE | mastery truth/governor | JA EXISTIA | state tests | Preservar |
| 413 | Erros recentes alimentam recuperacao | REF-SCROLL-AUX | buildRecoveryQueue | JA EXISTIA | auxiliary_phase | Preservar |
| 414 | Known weaknesses alimentam recuperacao | REF-SCROLL-AUX | state queues | JA EXISTIA | auxiliary_phase | Ampliar teste |
| 415 | Revisao por tempo | REF-SCROLL-AUX | nao comprovada completa | BLOQUEADO | N/A | Criar regra/teste |
| 416 | Revisao por sinal fraco | REF-SCROLL-AUX | nao comprovada completa | BLOQUEADO | N/A | Criar regra/teste |
| 417 | Recuperacao por prerequisito | REF-SCROLL-AUX | nao comprovada completa | BLOQUEADO | N/A | Criar regra/teste |
| 418 | Aux room com midia propria | REF-SCROLL-AUX | visual trigger preservado parcialmente | BLOQUEADO | N/A | Auditar midia aux |
| 419 | Aux room com audio proprio | REF-SCROLL-AUDIO | nao comprovado | BLOQUEADO | N/A | Auditar audio aux |
| 420 | Aux room restauravel apos restart | REF-SCROLL-STATE | estado existe, UI restore nao comprovado | BLOQUEADO | N/A | Criar teste restore |
| 421 | Imagem gratuita por SVG local | REF-SCROLL-TESTS | visual tests | JA EXISTIA | first_lesson_ready/media | Preservar |
| 422 | Imagem paga so com aceite | REF-SCROLL-TESTS | paid offer tests | JA EXISTIA | first_lesson_ready | Preservar |
| 423 | Background nao gera imagem paga | REF-SCROLL-TESTS | background paid image test | JA EXISTIA | first_lesson_ready | Preservar |
| 424 | Oferta paga tem status tipado | REF-SCROLL-CODE | `PaidImageOfferStatus` | JA EXISTIA | media tests | Preservar |
| 425 | Oferta paga pendente | REF-SCROLL-CODE | pending | JA EXISTIA | media tests | Preservar |
| 426 | Oferta paga aceita | REF-SCROLL-CODE | accepted | JA EXISTIA | media tests | Preservar |
| 427 | Oferta paga recusada | REF-SCROLL-CODE | declined | JA EXISTIA | media tests | Preservar |
| 428 | Oferta paga consumida | REF-SCROLL-CODE | consumed | JA EXISTIA | media tests | Preservar |
| 429 | Oferta paga falha | REF-SCROLL-CODE | failed | JA EXISTIA | media tests | Preservar |
| 430 | Stream de oferta paga | REF-SCROLL-CODE | `offerStream` | JA EXISTIA | media tests | Preservar |
| 431 | Aceite captura credito | REF-SCROLL-STATE | CreditStateGovernor | JA EXISTIA | internal_organs | Preservar |
| 432 | Falha paga reembolsa | REF-SCROLL-TESTS | paid image failure refund | JA EXISTIA | internal_organs | Preservar |
| 433 | Nao inventar oferta paga | REF-SCROLL-TESTS | painel nao inventa oferta | JA EXISTIA | finish/media | Preservar |
| 434 | Decline reset por lesson key | REF-SCROLL-TESTS | paid offer reset | JA EXISTIA | first_lesson_ready | Preservar |
| 435 | EventBus replay oferta pendente | REF-SCROLL-TESTS | replay pending offer | JA EXISTIA | first_lesson_ready | Preservar |
| 436 | EventBus nao reenvia imagem em late replay | REF-SCROLL-TESTS | strips image from late replay | JA EXISTIA | first_lesson_ready | Preservar |
| 437 | Critico aceita SVG rico util | REF-SCROLL-TESTS | image critic tests | JA EXISTIA | media_phase | Preservar |
| 438 | Avaliador final aceita imagem pedagogica | REF-SCROLL-TESTS | final visual quality accepts | JA EXISTIA | media_phase | Preservar |
| 439 | Avaliador final escala imagem sem keys | REF-SCROLL-TESTS | escalates SVG ignoring keys | JA EXISTIA | media_phase | Preservar |
| 440 | Imagem local por dominio matematica | REF-SCROLL-CODE | render catalog math | JA EXISTIA | media/ready | Preservar |
| 441 | Imagem local por timeline | REF-SCROLL-CODE | TimelineRenderer | JA EXISTIA | media/ready | Preservar |
| 442 | Imagem local por fluxograma | REF-SCROLL-CODE | FlowchartRenderer | JA EXISTIA | media/ready | Preservar |
| 443 | Imagem local por comparacao | REF-SCROLL-CODE | ComparisonRenderer | JA EXISTIA | media/ready | Preservar |
| 444 | Imagem local por ciclo | REF-SCROLL-CODE | CycleRenderer | JA EXISTIA | media/ready | Preservar |
| 445 | Imagem local por mapa conceitual | REF-SCROLL-CODE | ConceptMapRenderer | JA EXISTIA | media/ready | Preservar |
| 446 | Imagem local por fisica | REF-SCROLL-CODE | Force/Circuit renderers | JA EXISTIA | media/ready | Preservar |
| 447 | Imagem local por programacao | REF-SCROLL-CODE | ProgrammingFlowRenderer | JA EXISTIA | media/ready | Preservar |
| 448 | Imagem local por biologia | REF-SCROLL-CODE | FoodChain/Biology domain | JA EXISTIA | media/ready | Preservar |
| 449 | Imagem local por geografia | REF-SCROLL-CODE | GeographyLayersRenderer | JA EXISTIA | media/ready | Preservar |
| 450 | Imagem local por quimica | REF-SCROLL-CODE | ChemistryReactionRenderer | JA EXISTIA | media/ready | Preservar |
| 451 | Layout visual pedagogico separado | REF-SCROLL-CODE | pedagogical visual layout | JA EXISTIA | media tests | Preservar |
| 452 | Paleta pedagogica separada | REF-SCROLL-CODE | pedagogical palette | JA EXISTIA | media tests | Preservar |
| 453 | Nivel visual pedagogico | REF-SCROLL-CODE | pedagogical_visual_level | JA EXISTIA | media tests | Preservar |
| 454 | Hierarquia visual pedagogica | REF-SCROLL-CODE | visual hierarchy | JA EXISTIA | media tests | Preservar |
| 455 | Escalation policy visual | REF-SCROLL-CODE | visual_escalation_policy | JA EXISTIA | media tests | Preservar |
| 456 | Visual N2 preservado | Regra usuario | N2 nao alterado | PRESERVADO | git diff/media | Preservar |
| 457 | Visual N3 preservado | Regra usuario | N3 nao alterado | PRESERVADO | git diff/media | Preservar |
| 458 | Prompt visual nao alterado nesta fatia | Regra usuario | blueprint_prompt nao tocado | PRESERVADO | git diff | Preservar |
| 459 | Cache de imagem antiga nao reintroduzido | Regra usuario | cache tests | PRESERVADO | media/bloco1 | Preservar |
| 460 | Compressao data URL isolada | REF-SCROLL-CODE | image_data_url_compression | JA EXISTIA | media tests | Preservar |
| 461 | Fullscreen/zoom imagem atual | REF-SCROLL-TESTS | inspeção com zoom test | JA EXISTIA | finish_phase | Preservar |
| 462 | Erro compacto de imagem invalida | REF-WCAG-STATUS | teste imagem invalida | JA EXISTIA | finish_phase | Preservar |
| 463 | Bitmap dataUrl no historico | REF-SCROLL-TESTS | renderizador aceita dataUrl | JA EXISTIA | finish_phase | Preservar |
| 464 | Alt text pedagogico dinamico | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | Adicionar metadado alt |
| 465 | Zoom acessivel por teclado | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | Teste teclado |
| 466 | Menu unico aula/home | REF-SCROLL-CODE | alteracoes anteriores nao auditadas aqui | BLOQUEADO | N/A | Auditar drawer separado |
| 467 | Drawer lista aulas locais | REF-SCROLL-TESTS | widget drawer test | JA EXISTIA | widget_test | Preservar |
| 468 | Drawer busca aulas locais | REF-SCROLL-TESTS | widget drawer test | JA EXISTIA | widget_test | Preservar |
| 469 | Drawer renomeia aulas locais | REF-SCROLL-TESTS | widget drawer test | JA EXISTIA | widget_test | Preservar |
| 470 | Drawer apaga aulas locais | REF-SCROLL-TESTS | widget drawer test | JA EXISTIA | widget_test | Preservar |
| 471 | Drawer importa backup txt | REF-SCROLL-TESTS | widget backup import | JA EXISTIA | widget_test | Preservar |
| 472 | Drawer mantem paste fallback | REF-SCROLL-TESTS | widget backup import | JA EXISTIA | widget_test | Preservar |
| 473 | Drawer preserva creditos | REF-SCROLL-TESTS | chat menu credits | JA EXISTIA | chat widgets | Preservar |
| 474 | Drawer preserva dark mode | REF-SCROLL-TESTS | chat menu dark mode | JA EXISTIA | chat widgets | Preservar |
| 475 | Drawer preserva escala de fonte | REF-SCROLL-TESTS | chat menu font scale | JA EXISTIA | chat widgets | Preservar |
| 476 | Rota aula default chat | REF-SCROLL-TESTS | widget route test | JA EXISTIA | widget_test | Preservar |
| 477 | Aula sem lessonLocalId volta objetivo | REF-SCROLL-TESTS | widget route test | JA EXISTIA | widget_test | Preservar |
| 478 | Erro auth saneado no chat | REF-WCAG-STATUS | session_regression | JA EXISTIA | session tests | Preservar |
| 479 | Aula sem id saneada no chat | REF-WCAG-STATUS | session_regression | JA EXISTIA | session tests | Preservar |
| 480 | Retry auth respeita portugues | REF-WCAG-STATUS | session_regression | JA EXISTIA | session tests | Preservar |
| 481 | Auth ready antes de T00 | REF-SCROLL-TESTS | session_regression | JA EXISTIA | session tests | Preservar |
| 482 | Onboarding renova auth em 401 | REF-SCROLL-TESTS | session_regression | JA EXISTIA | session tests | Preservar |
| 483 | T00 abre sala no parcial | REF-SCROLL-TESTS | first_lesson_ready | JA EXISTIA | first_lesson_ready | Preservar |
| 484 | T00 continua apos primeiro item | REF-SCROLL-TESTS | student_experience_t00 | JA EXISTIA | student_experience | Preservar |
| 485 | Contador cresce apos expansao | REF-SCROLL-TESTS | first/window + t00 tests | JA EXISTIA | first/student | Preservar |
| 486 | Placement aparece quando necessario | REF-SCROLL-TESTS | placement required tests | JA EXISTIA | placement/first | Preservar |
| 487 | Placement define inicio real | REF-SCROLL-TESTS | placement phase tests | JA EXISTIA | placement_phase | Preservar |
| 488 | Sala nao abre falsa antes de aula viva | REF-SCROLL-TESTS | route/session tests | PRESERVADO | widget/session | Preservar |
| 489 | Curriculo completo continua formando | REF-SCROLL-TESTS | T00 expansion test | JA EXISTIA | student_experience | Preservar |
| 490 | Runtime relê curriculo expandido | REF-SCROLL-TESTS | contador/ready tests | JA EXISTIA | first_lesson_ready | Preservar |
| 491 | Observabilidade T00 started | REF-SCROLL-TESTS | logs/eventos `[SIM] T00_STARTED` | JA EXISTIA | full suite | Preservar |
| 492 | Observabilidade first item | REF-SCROLL-TESTS | `T00_FIRST_ITEM_RECEIVED` | JA EXISTIA | full suite | Preservar |
| 493 | Observabilidade T02 started | REF-SCROLL-TESTS | `T02_FIRST_LESSON_STARTED` | JA EXISTIA | full suite | Preservar |
| 494 | Observabilidade T02 ready | REF-SCROLL-TESTS | `T02_FIRST_MINIMUM_LESSON_READY` | JA EXISTIA | full suite | Preservar |
| 495 | Observabilidade classroom opened | REF-SCROLL-TESTS | `CLASSROOM_OPENED` | JA EXISTIA | full suite | Preservar |
| 496 | Observabilidade blocked | REF-WCAG-STATUS | `BLOCKED reason` logs | JA EXISTIA | full suite | Preservar |
| 497 | Telemetria time-to-classroom persistida | REF-SLACK-HISTORY | logs existem, metrica persistida nao | BLOQUEADO | N/A | Criar metric store |
| 498 | Telemetria time-to-first-question persistida | REF-SLACK-HISTORY | logs existem, metrica persistida nao | BLOQUEADO | N/A | Criar metric store |
| 499 | Relatorio 201-500 criado | REF-SCROLL-TESTS | este arquivo | CRIADO | contagem rg | Preservar |
| 500 | Acumulado 500 itens documentado | REF-SCROLL-TESTS | total acumulado neste relatorio | CRIADO | contagem rg | Continuar 501-800 |

## Bloqueios documentados

Os itens bloqueados nesta fatia exigem uma ou mais condicoes: novo contrato de produto, backend, persistencia segura, criptografia, metric store, paginacao universal, cancelamento async, renderer rico seguro, UI de captions/progresso de audio, ou auditoria especifica fora do palco de aula. Eles nao foram implementados porque isso violaria a regra de referencia/autorizacao ou misturaria escopos proibidos.

## Confirmacoes

- Nenhum prompt foi alterado nesta fatia.
- Nenhum servidor/backend foi alterado nesta fatia.
- Nenhum credito ou regra de cobranca foi alterado nesta fatia.
- Nenhum cache proibido ou reaproveitamento de imagem antiga foi reintroduzido nesta fatia.
- N2/N3 foram preservados.
- O total formal acumulado agora e 500 itens classificados.

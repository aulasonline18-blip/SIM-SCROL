# Resposta tecnica a auditoria do funil de imagem

Data: 2026-07-02
Repo: sim-mobile-fluter

## Resumo

A auditoria encontrou problemas reais e tambem misturou alguns pontos de arquitetura/debito tecnico com falhas funcionais. Corrigi os pontos que tinham risco direto no funil de imagem ou que podiam gerar confusao perigosa entre modelos de oferta paga.

## Itens avaliados

### 1. `ensureFirstLessonPrepared` / `ensureLessonWindow` como codigo morto

Status: parcialmente exagerado.

As funcoes existem e nao sao o caminho principal chamado hoje, mas a conclusao de que a primeira aula nao e preparada esta exagerada. O fluxo vivo atual passa por `StudentExperienceT02Adapter` e pela ReadyWindow; ha testes cobrindo primeira aula pronta e slots A/B/C. Nao mexi nessas funcoes nesta correcao para nao trocar a arquitetura do runtime sem necessidade.

Evidencia: `test/first_lesson_ready_window_test.dart` cobre primeira aula e janela A/B/C.

### 2. `PaidImageService` como codigo duplicado

Status: debito real de arquitetura, nao bug vivo da UI atual.

O caminho vivo da sala usa `LessonOrchestrator + LessonEventBus`. O `PaidImageService` e um servico auxiliar testado isoladamente. O problema real era a colisao de nomes com outro `PaidImageOffer`.

Correcao feita: renomeei o estado interno do servico para `PaidImageServiceOffer` e documentei que o modelo vivo da UI e `LessonPaidImageOffer`.

### 3. Dois modelos incompatíveis de oferta paga

Status: erro real corrigido.

Antes havia `PaidImageOffer` em `lesson_paid_image_offer.dart` e `LessonPaidImageOffer` no `LessonEventBus`. O controller legado agora usa o modelo canonico `LessonPaidImageOffer`, removendo a incompatibilidade.

Arquivo alterado: `lib/sim/media/lesson_paid_image_offer.dart`.

### 4. `_declinedKeys` nunca limpo

Status: risco real corrigido.

Agora o orquestrador tem `resetDeclinedPaidImageOffer(lessonKey)`. Quando o aluno vai comprar creditos a partir de uma oferta ativa, a sessao remove a recusa local e reseta a recusa no orquestrador para aquela aula.

Arquivos alterados:
- `lib/sim/lesson/lesson_orchestrator.dart`
- `lib/features/session/lab_session.dart`

Teste criado: `LessonOrchestrator can reset declined paid image offer by lesson key`.

### 5. Falha de rede do N3 retornava `ai`

Status: erro real corrigido.

Falha de rede nao e decisao pedagogica. O N3 agora retorna `VisualVerdict.ambiguous` com motivo `N3_HTTP_FAILED`. Assim o funil continua tentando fallback local/software antes de chegar a oferta paga.

Arquivo alterado: `lib/sim/media/visual_router_n3.dart`.

Teste atualizado: `N3 failure keeps diagnostic reason before falling back to paid path`.

### 6. `offerKey` era `lessonKey`

Status: melhoria real de robustez corrigida.

Renomeei a assinatura da interface e da implementacao para `lessonKey`, que e o que o sistema realmente usa hoje.

Arquivos alterados:
- `lib/sim/media/lesson_paid_image_offer.dart`
- `lib/sim/lesson/lesson_orchestrator.dart`
- `test/media_phase_test.dart`

### 7. `buyCredits()` com navegacao passiva

Status: melhoria real corrigida no controller legado.

O controller agora aceita `onNavigate`, mantendo `navigationTarget` para compatibilidade, mas permitindo reacao imediata de UI.

Arquivo alterado: `lib/sim/media/lesson_paid_image_offer.dart`.

Teste atualizado: `paid image offer accepts, declines and routes to credits`.

## Consenso recomendado

O engenheiro acertou nos itens 3, 4, 5, 6 e 7. O item 2 e um debito real, mas nao e bug vivo do caminho atual; corrigimos a armadilha de tipo sem desmontar o sistema testado. O item 1 esta exagerado como diagnostico funcional: as funcoes citadas podem estar fora do caminho principal, mas o app ja tem outro caminho testado para primeira aula e janela de prontidao.

## Validacao

- `flutter analyze --no-pub`: passou.
- `flutter test test/media_phase_test.dart`: passou.
- `flutter test test/first_lesson_ready_window_test.dart`: passou.
- `flutter test`: passou, 246 testes.
- `flutter build apk --release --dart-define=FLUTTER_APP_MODE=production`: passou.

Resultado: os erros funcionais aplicaveis foram corrigidos sem alterar preco, credito, auth, endpoint, arquitetura do servidor ou SimWeb.

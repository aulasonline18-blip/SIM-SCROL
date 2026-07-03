# SIM App/API Audit Corrections - 2026-07-02

## Status

B final de operacao real ainda nao pode ser declarado sem teste em Android real e sem infraestrutura final de producao.

Esta execucao corrigiu os erros de codigo que eram corrigiveis sem copiar doenca do Web e sem mover segredo para o Flutter.

## Corrigido

| Item | Status | O que foi feito | Prova |
|---|---|---|---|
| Checkout falso no Flutter | Corrigido | Tela de creditos deixou de abrir retorno fake; agora chama checkout hosted real e abre URL externa recebida do servidor. | `flutter test`, `flutter analyze --no-pub` |
| Rotas `/api/payments/*` ausentes | Corrigido | API agora expoe checkout hosted, checkout embedded e checkout-status com auth, pacote oficial e Stripe server-side. | `npm test`, `node --check` |
| Creditos em memoria | Corrigido parcialmente | Ledger saiu de `Map` em memoria e passou a persistir em `.data/credits-ledger.json`, com idempotencia por operation/session. | `npm test` |
| Payload fraco de creditos | Corrigido | `reserve/capture/refund` agora validam custo positivo, operationId e reservationId. | `npm test` |
| HTTP em production | Corrigido | App agora falha em production se `SIM_SERVER_URL` nao for HTTPS. | `flutter analyze`, build release com HTTPS |
| Checkout return decorativo | Corrigido | Tela de retorno consulta status real da sessao Stripe e atualiza saldo. | `flutter test` |
| `requestId` ausente | Corrigido | API gera `X-Request-Id` quando cliente nao envia. | `npm test`, `node --check` |
| Auth lab-trust em production | Corrigido | API aborta production sem auth forte e bloqueia lab trust inseguro. | `node --check` |
| Healthcheck vazando detalhes | Corrigido | `/health` publico em production retorna somente status/servico. | `node --check` |
| Logs Flutter vazando corpo em release | Corrigido | Transporte HTTP loga detalhes apenas em `kDebugMode`. | `flutter analyze`, `flutter test` |
| Aula fake com `prefs == null` | Corrigido | Caminho dev continua para teste/dev, mas e bloqueado em production. | `flutter test` |
| Anexo nao lido fingindo metadata util | Corrigido honestamente | API agora retorna erro explicito para mime sem processador real em vez de fingir leitura. | `node --check` |
| Audio gratuito passando pelo ledger | Corrigido | Audio com custo 0 nao reserva/captura credito. | `npm test` |

## Bloqueados ou dependentes de infraestrutura/prova real

| Item | Status | Motivo |
|---|---|---|
| APK em Android real | Nao provado aqui | Nenhum aparelho Android real conectado nesta sessao. |
| Banco transacional real para creditos | Parcial | Persistencia em arquivo corrige restart simples, mas ideal de producao ainda e banco transacional/Stripe webhook. |
| Webhook Stripe real | Pendente infra | Checkout-status credita idempotente; webhook exige chave/evento Stripe de producao/staging. |
| OCR/PDF/Vision real | Nao implementado | Sem provedor/contrato final; corrigido para nao prometer leitura falsa. |
| TTS local Android real | Nao implementado | Exige plugin/adaptador nativo e teste em device. |
| Student-state multi-instancia | Parcial | Arquivo local funciona em instancia unica; ideal e storage transacional compartilhado. |
| Offline/TalkBack | Nao provado | Precisa teste real ou suite E2E em dispositivo/emulador. |

## Validacoes executadas

- API: `npm test` PASSOU.
- API: `node --check` nos arquivos alterados PASSOU.
- Flutter: `flutter analyze --no-pub` PASSOU.
- Flutter: `flutter test` PASSOU, 246 testes.
- Flutter: `flutter build apk --release --dart-define=FLUTTER_APP_MODE=production --dart-define=SIM_SERVER_URL=https://gemini-aid-pal.lovable.app` PASSOU.

## Observacao de release

O build production sem `SIM_SERVER_URL=https://...` agora deve falhar por seguranca. Para publicar, o servidor real do SIM precisa estar atras de HTTPS.

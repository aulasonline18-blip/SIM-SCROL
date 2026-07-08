# Google Play Billing — Implementacao SIM-SCROL

Data: 2026-07-04

## Fonte oficial

- Politica de pagamentos Google Play: apps distribuidos pela Play que vendem bens digitais consumidos no app devem usar o sistema de billing do Google Play.
- Integracao oficial Android/Flutter: compras devem ser recebidas pelo fluxo da loja, verificadas antes de liberar conteudo e finalizadas/consumidas depois da entrega.

## Decisao de arquitetura

O build Android production do SIM-SCROL usa Google Play Billing para compra de creditos digitais.

O Stripe fica preservado como legado tecnico, mas nao e o provedor permitido no build production Google Play.

## Gate de build

`SimEnvironment.assertProductionSafe()` bloqueia build production quando:

- `SIM_SERVER_URL` nao usa HTTPS;
- `SIM_BILLING_PROVIDER` nao e `google_play`.

## Produtos que precisam existir no Play Console

| Pack interno | Produto Google Play | Creditos |
|---|---|---:|
| `credits_100` | `sim_credits_100` | 100 |
| `credits_200` | `sim_credits_200` | 200 |
| `credits_500` | `sim_credits_500` | 500 |

Todos devem ser configurados como produtos consumiveis no Play Console.

## Fluxo implementado no app

1. Usuario toca em comprar creditos.
2. `LabSession.startCreditsCheckout` confirma auth.
3. Em production, o app usa `GooglePlayBillingFunctions`.
4. O app consulta `ProductDetails` no Google Play.
5. O app inicia compra consumivel com `autoConsume: false`.
6. O app recebe a compra pelo `purchaseStream`.
7. O app envia `packId`, `productId`, `purchaseToken`, `verificationSource`, `localVerificationData` e `purchaseId` para a API.
8. A API valida a compra com Google Play Developer API e concede os creditos.
9. So depois da concessao a compra e consumida/finalizada no Android.
10. O app recarrega saldo do servidor.

## Contrato da API

Endpoint:

```text
POST /api/play-billing/consume-credit-pack
Authorization: Bearer <Supabase JWT>
Content-Type: application/json
```

Body:

```json
{
  "packId": "credits_100",
  "productId": "sim_credits_100",
  "purchaseToken": "<google-play-purchase-token>",
  "verificationSource": "google_play",
  "localVerificationData": "<original-json>",
  "purchaseId": "<order-id>"
}
```

Resposta esperada:

```json
{
  "credits": 100,
  "balance": 112
}
```

## Servidor M17

O servidor registra `POST /api/play-billing/consume-credit-pack`, valida a
relacao `productId`/`packId`, consulta a Android Publisher API por token de
compra, concede credito de forma idempotente e retorna erro humano controlado
sem expor `purchaseToken`.

## Proibicoes

- Nao conceder credito localmente no Flutter.
- Nao confiar em `productId` sem validar `purchaseToken` no servidor.
- Nao consumir/finalizar compra antes de a API confirmar concessao.
- Nao usar Stripe no build Android production distribuido pela Google Play.
- Nao criar fallback falso que transforme falha de Play/API em credito.

## Testes adicionados

- IDs de produtos Google Play estaveis.
- `LabSession` usa fluxo Google Play para compra em vez de Stripe.
- Login obrigatorio antes de iniciar billing.
- Estados pendente e cancelado do Google Play sobem para a UI.
- M17 adiciona teste servidor para validacao Play, idempotencia, mismatch de
  produto/pacote e erro humano sem vazamento de token.

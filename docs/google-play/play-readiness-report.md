# Relatorio de Prontidao Google Play — SIM-SCROL

Data: 04/07/2026

## Veredito honesto

Google Play readiness no codigo do app: PARCIALMENTE FEITO.

O app ficou mais preparado para build de loja, mas ainda nao deve ser declarado 100% pronto para Google Play enquanto faltarem as dependencias externas abaixo.

## Feito nesta etapa

1. Lei Mandatoria de Execucao adicionada em `docs/LEI-MANDATORIA-DE-EXECUCAO.md`.
2. `applicationId` Android passou a ser configuravel por `SIM_ANDROID_APPLICATION_ID`.
3. Build release passa a usar assinatura release quando keystore existe.
4. Build release pode falhar obrigatoriamente sem assinatura real com `SIM_REQUIRE_RELEASE_SIGNING=true`.
5. Cleartext HTTP foi bloqueado no `network_security_config` principal.
6. Documentos de privacidade, data safety e exclusao foram criados em `docs/google-play/`.
7. Tela de privacidade/termos passou a renderizar texto legal real, nao placeholder.
8. Rotas sensiveis `/creditos`, `/checkout/return` e `/conta/deletar` passaram a ter gate formal de auth no roteador central.
9. `/pai` passou a exigir auth e role/claim de responsavel/admin.
10. Testes cobrem gates, package configuravel, cleartext off e role.

## Bloqueios externos restantes

### 1. URL publica de privacidade

Google Play exige URL publica. O documento existe no repo, mas a URL final deve ser publicada em dominio ou GitHub Pages.

Sugestao temporaria:

`https://github.com/aulasonline18-blip/SIM-SCROL/blob/main/docs/google-play/privacy-policy.md`

Sugestao ideal:

`https://simapp.com.br/privacidade`

### 2. URL publica de exclusao de conta

Google Play exige recurso web para solicitar exclusao.

Sugestao temporaria:

`https://github.com/aulasonline18-blip/SIM-SCROL/blob/main/docs/google-play/account-deletion.md`

Sugestao ideal:

`https://simapp.com.br/excluir-conta`

### 3. Exclusao real no servidor

O app chama `/api/account/request-deletion`, mas a remocao real de dados precisa existir no servidor. Este repo nao contem mais a pasta do servidor. Portanto, este item precisa ser implementado no repositorio do servidor.

Contrato minimo do endpoint:

1. Exigir Bearer token valido.
2. Confirmar que `userId` do body e igual ao usuario autenticado ou ignorar `userId` do body e usar apenas token.
3. Registrar auditoria da solicitacao.
4. Apagar/anonimizar perfil, progresso, aulas, duvidas e anexos do usuario.
5. Preservar registros financeiros obrigatorios pelo prazo legal.
6. Retornar requestId.

### 4. Google Play Billing

O app ainda contem fluxo Stripe. Para bens digitais consumidos dentro do Android, a fase Google Play Billing precisa substituir o checkout Stripe no build de loja ou receber decisao juridica/politica documentada.

### 5. Keystore real

Para build Play:

1. Criar upload key.
2. Guardar fora do repo.
3. Configurar `android/key.properties` local ou variaveis `SIM_ANDROID_*`.
4. Compilar com `-PSIM_REQUIRE_RELEASE_SIGNING=true`.

### 6. Dominio HTTPS da API

Google Play build nao deve apontar para HTTP. O servidor precisa estar em HTTPS.

## Comando esperado para validar build de loja

```bash
flutter analyze
flutter test
flutter build appbundle --release \
  --dart-define=FLUTTER_APP_MODE=production \
  --dart-define=SIM_SERVER_URL=https://SEU-DOMINIO-API \
  --dart-define=SIM_CHECKOUT_RETURN_ORIGIN=https://SEU-DOMINIO-APP \
  -PSIM_ANDROID_APPLICATION_ID=com.aulasonline.sim \
  -PSIM_REQUIRE_RELEASE_SIGNING=true
```

## Declaracao final

O app esta mais perto de Play readiness, mas Google Play 100% = NAO ate:

1. Servidor executar exclusao real.
2. URLs publicas finais existirem.
3. Google Play Billing ser implementado ou decisao formal ser registrada.
4. Build AAB assinado com upload key real ser gerado.
5. API de producao usar HTTPS.

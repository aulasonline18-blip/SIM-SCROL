# SIM Android Google Play Release Readiness

Status desta frente: prontidao local reforcada pela Fase 1. Publicacao real
permanece bloqueada ate haver keystore oficial, dominio HTTPS publico e
aprovacao Play Console.

## Identidade Android

- Package ID oficial de loja: `com.aulasonline.sim`
- Android namespace oficial: `com.aulasonline.sim`
- Observacao: trocar package muda a identidade Android. Instalacoes antigas com
  outro package nao recebem atualizacao direta sem estrategia de migracao.
- App label: `SIM`
- Build de producao: sem `android:usesCleartextTraffic`
- Debug/profile: cleartext liberado apenas para desenvolvimento local

## Assinatura

O release usa `android/key.properties` ou variaveis de ambiente. O arquivo real
`key.properties` e o keystore nao devem ser commitados.

Modelo:

```properties
storePassword=...
keyPassword=...
keyAlias=sim_upload
storeFile=upload-keystore.jks
```

Variaveis equivalentes:

```bash
SIM_ANDROID_STOREFILE=/abs/path/upload-keystore.jks
SIM_ANDROID_STOREPASSWORD=...
SIM_ANDROID_KEYALIAS=sim_upload
SIM_ANDROID_KEYPASSWORD=...
```

Comando oficial para gerar o Android App Bundle:

```bash
flutter build appbundle --release \
  --dart-define=FLUTTER_APP_MODE=production \
  --dart-define=SIM_BILLING_PROVIDER=google_play \
  --dart-define=SIM_SERVER_URL=https://SEU_DOMINIO_API \
  --dart-define=SIM_CHECKOUT_RETURN_ORIGIN=https://SEU_DOMINIO_PUBLICO \
  -PSIM_ANDROID_APPLICATION_ID=com.aulasonline.sim \
  -PSIM_REQUIRE_RELEASE_SIGNING=true
```

Para publicar no Google Play, envie o `.aab` em
`build/app/outputs/bundle/release/app-release.aab`.

## Play Console

Antes de revisao aberta/producao, preencher:

- Privacy Policy URL publica.
- Data Safety.
- Target audience and content.
- Content rating.
- Ads declaration.
- App access instructions para conta/login de teste, se necessario.
- Permissoes sensiveis: camera e leitura de imagens.

## Pontos externos ainda obrigatorios

- Definir dominio HTTPS publico para API (`SIM_SERVER_URL`) apontando para as
  rotas publicas do servidor.
- Publicar a politica de privacidade em uma URL HTTPS publica.
- Atualizar Google Cloud/Supabase OAuth com o package usado no build de loja.
  e o SHA-1/SHA-256 do certificado de upload/app signing.
- Guardar o upload keystore fora do repositorio e em backup seguro.

## Fontes oficiais

- Android App Signing: https://developer.android.com/studio/publish/app-signing
- Google Play User Data: https://support.google.com/googleplay/android-developer/answer/10144311
- Data Safety: https://support.google.com/googleplay/android-developer/answer/10787469
- Prepare app for review: https://support.google.com/googleplay/android-developer/answer/9859455

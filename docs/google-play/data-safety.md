# Google Play Data Safety — SIM AI Tutor

Este documento orienta o preenchimento da secao Data Safety da Play Console. A resposta final deve ser revisada pelo responsavel legal antes da submissao.

## Dados coletados

| Categoria Play | SIM coleta? | Uso |
|---|---:|---|
| Email address | Sim | Login, suporte, exclusao de conta |
| User IDs | Sim | Auth, sync, seguranca |
| Name | Opcional | Personalizacao |
| Photos/videos | Opcional | Duvidas/anexos quando o usuario envia |
| Files/docs | Opcional | Anexos de objetivo/backup/import |
| App activity | Sim | Progresso, respostas, eventos de aula |
| App info/performance | Sim | Diagnostico, estabilidade |
| Purchase history | Sim | Creditos, suporte, antifraude |

## Finalidades

1. App functionality.
2. Account management.
3. Analytics basico de estabilidade/funil.
4. Fraud prevention/security.
5. Developer communications/support.

## Compartilhamento

Dados podem ser processados por provedores necessarios ao funcionamento: Supabase, provedores de IA, Google Play Billing, Stripe quando aplicavel e ferramenta de observabilidade configurada.

## Criptografia em transito

O build de loja deve usar HTTPS para servidor de producao. HTTP so pode ser usado em build de desenvolvimento ou APK externo de teste, nunca em build Google Play.

## Exclusao de dados

O app tem caminho in-app para solicitar exclusao e documento publico em `docs/google-play/account-deletion.md`.

## Bloqueios antes da Play Console

1. Publicar `privacy-policy.md` em URL publica.
2. Publicar `account-deletion.md` em URL publica.
3. Criar produtos consumiveis no Play Console e configurar endpoint de validacao de compra no servidor.
4. Confirmar ferramenta real de observabilidade e politica de retencao.

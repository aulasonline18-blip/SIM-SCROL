# DOCUMENTO HISTORICO. NAO E AUTORIDADE DE RUNTIME OU PUBLICACAO.

Use `docs/GOOGLE_PLAY_DATA_SAFETY_FINAL.md` como espelho vigente da submissao.
Este rascunho permanece apenas para auditoria historica.

# SIM Google Play Data Safety Draft

Este rascunho serve para preencher o Play Console. Deve ser revisado pelo dono
do produto antes da submissao.

## Dados coletados

- Email e identificadores de conta: login e sincronizacao.
- Nome preferido: personalizacao da aula.
- Conteudo informado pelo usuario: objetivo de estudo, duvidas e anexos.
- Imagens/arquivos enviados pelo usuario: OCR, leitura pedagogica e suporte a
  aula.
- Progresso educacional: curriculo, respostas, sinais e historico de aula.
- Dados de compra: creditos, transacoes e comprovantes conforme provedor de
  pagamento.
- Diagnosticos tecnicos: logs de erro, request id e falhas de rede quando
  observabilidade for ativada.

## Finalidades

- Funcionalidade do app.
- Personalizacao.
- Gerenciamento de conta.
- Prevencao de fraude e seguranca.
- Suporte ao usuario.
- Analise agregada de qualidade, quando analytics for ativado.

## Compartilhamento/processadores

- Supabase: autenticacao, banco e sincronizacao.
- Google Gemini/OpenAI ou provedor de IA configurado no servidor: geracao e
  leitura pedagogica.
- Google Play Billing ou Apple/Stripe conforme plataforma futura: pagamentos.

## Seguranca

- Trafego de producao deve usar HTTPS.
- Chaves de IA e pagamento ficam no servidor, nunca no app.
- Usuario autenticado acessa apenas seus proprios recursos.
- Exclusao de conta deve apagar dados pessoais conforme politica, mantendo
  registros financeiros quando exigidos por lei.

## Menores

Se o app for disponibilizado para criancas ou adolescentes, declarar coleta de
dados de menores e manter consentimento de pais/responsaveis conforme LGPD Art.
14 e politicas Google Play Families.

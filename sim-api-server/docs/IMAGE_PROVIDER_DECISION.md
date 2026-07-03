# Decisao de Provider de Imagem

Status: manter provider proprio do SIM-API nesta Wave 2.

O SIM Web usa gateway/provedor diferente em alguns fluxos de imagem. O SIM-API/Flutter tem comunicacao externa propria, auth propria e contrato proprio com o app. Por isso, a Wave 2 nao migra automaticamente `/api/generate-lesson-image` para Lovable/Replicate.

Decisao atual:

- manter `GEMINI_IMAGE_MODEL` como modelo configuravel por ambiente;
- nao hardcodar provider Web no SIM-API;
- preservar auth/resource owner do SIM-API;
- preservar aceite explicito e idempotencia de imagem paga;
- normalizar `aspectRatio`, prompt, retry, cache e refund no controller atual.

Para trocar de provider no futuro, precisa decisao explicita sobre:

- chave/credencial usada em producao;
- custo real por imagem;
- timeout e retry aceitos;
- contrato exato de resposta;
- impacto em credito/refund;
- prova APK de imagem real.

Enquanto isso, a paridade buscada e funcional: imagem correta, aceite correto, uma cobranca, cache seguro e erro honesto, sem copiar infraestrutura do Web cegamente.

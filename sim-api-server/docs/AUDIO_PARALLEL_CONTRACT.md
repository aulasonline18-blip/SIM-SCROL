# Contrato de Audio Paralelo

Objetivo: permitir que o cliente prepare audio sem bloquear a aula.

Contrato atual do servidor:

- endpoint: `POST /api/generate-lesson-audio`;
- resposta: JSON, nao binario puro;
- campos aceitos: `text`, `lang`/`language`, `voice`, `speed`, `lessonKey`;
- limite padrao de texto: `AUDIO_TEXT_MAX_CHARS=4096`;
- cache por `lessonKey + language + voice + speed + hash(text)`;
- rate limit por usuario para audio;
- `Retry-After` pode aparecer em 429;
- `X-Credits-Balance` pode aparecer quando houver reserva/captura/refund.

Regra de arquitetura:

- o servidor aceita requisicoes de audio sobrepostas;
- o cliente nao deve bloquear texto/aula esperando audio;
- o cliente pode chamar audio quando tiver texto falavel suficiente;
- o audio nao deve fingir sucesso se a API falhar;
- o audio desligado no app nao deve chamar este endpoint.

Politica recomendada para Flutter:

- iniciar preparo quando houver explicacao suficiente e preferencia de audio ligada;
- usar `lessonKey` estavel;
- propagar `language`, `voice` e `speed`;
- respeitar `Retry-After`;
- limpar estado visual se a chamada falhar.

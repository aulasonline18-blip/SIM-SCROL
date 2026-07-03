const allowedAspectRatios = new Set(['1:1', '16:9', '9:16', '4:3', '3:4']);

function normalizeAspectRatio(value) {
  const ratio = String(value || '1:1').trim();
  return allowedAspectRatios.has(ratio) ? ratio : '1:1';
}

function buildImagePrompt(data) {
  return [
    String(data.prompt || data.visual_prompt || data.explanation || '').trim(),
    data.aspectRatio ? `Aspect ratio: ${data.aspectRatio}` : '',
    'Generate a precise didactic classroom image. Avoid decorative content.',
  ].filter(Boolean).join('\n');
}

function findInlineData(response, mimePrefix) {
  const parts = response?.candidates?.[0]?.content?.parts || [];
  for (const p of parts) {
    const inline = p.inlineData || p.inline_data;
    if (inline?.data && String(inline.mimeType || inline.mime_type || '').startsWith(mimePrefix)) {
      return inline;
    }
  }
  return null;
}

function publicError(error) {
  if (error?.statusCode === 402) return 'Créditos insuficientes para gerar imagem.';
  if (error?.statusCode === 400) return error.message;
  if (error?.statusCode === 403) return error.message;
  if (error?.statusCode === 409) return error.message;
  if (error?.statusCode === 429) return 'Muitas imagens solicitadas. Tente novamente em instantes.';
  return 'Não foi possível gerar a imagem da aula agora.';
}

function validatePayload(data) {
  if (!data || typeof data !== 'object' || Array.isArray(data)) {
    const e = new Error('payload inválido');
    e.statusCode = 400;
    throw e;
  }
  if (data.allow_paid === false || data.allowPaid === false || data.allowPaidImages === false) {
    const e = new Error('paid_images_disabled');
    e.statusCode = 403;
    throw e;
  }
  let prompt = buildImagePrompt(data);
  if (prompt.length < 12) {
    const e = new Error('prompt obrigatório com ao menos 12 caracteres');
    e.statusCode = 400;
    throw e;
  }
  let promptTruncated = false;
  if (prompt.length > 4000) {
    prompt = prompt.slice(0, 4000);
    promptTruncated = true;
  }
  const lessonKey = String(data.lessonKey || data.cacheKey || data.lessonLocalId || '').trim();
  if (lessonKey.length < 3 || lessonKey.length > 180) {
    const e = new Error('lessonKey obrigatório e deve ter até 180 caracteres');
    e.statusCode = 400;
    throw e;
  }
  const requestedAspectRatio = String(data.aspectRatio || data.aspect_ratio || '1:1').trim();
  const aspectRatio = normalizeAspectRatio(requestedAspectRatio);
  const aspectFallback = requestedAspectRatio !== aspectRatio;
  const acceptedOfferId = String(data.acceptedOfferId || data.offerId || '').trim();
  if (acceptedOfferId.length < 6 || acceptedOfferId.length > 160) {
    const e = new Error('acceptedOfferId obrigatório para imagem paga');
    e.statusCode = 409;
    throw e;
  }
  const idempotencyKey = String(data.idempotencyKey || acceptedOfferId).trim();
  if (idempotencyKey.length < 6 || idempotencyKey.length > 200) {
    const e = new Error('idempotencyKey inválido');
    e.statusCode = 400;
    throw e;
  }
  const promptSuspect = prompt.length < 40 || !/(background\s*:|style\s*:)/i.test(prompt);
  return {
    prompt,
    lessonKey,
    aspectRatio,
    acceptedOfferId,
    idempotencyKey,
    promptTruncated,
    promptSuspect,
    aspectFallback,
    requestedAspectRatio,
  };
}

function createWindowLimiter({limit, windowMs}) {
  const buckets = new Map();
  return function assertWithinLimit(key) {
    const now = Date.now();
    const cutoff = now - windowMs;
    const arr = (buckets.get(key) || []).filter((ts) => ts > cutoff);
    if (arr.length >= limit) {
      const retryAfter = Math.max(1, Math.ceil((arr[0] + windowMs - now) / 1000));
      const e = new Error('Too Many Requests');
      e.statusCode = 429;
      e.retryAfter = retryAfter;
      throw e;
    }
    arr.push(now);
    buckets.set(key, arr);
  };
}

function isTransientProviderError(error) {
  const status = Number(error?.statusCode || error?.status || 0);
  return [429, 502, 503, 504].includes(status);
}

async function wait(ms) {
  await new Promise((resolve) => setTimeout(resolve, ms));
}

async function callImageProviderWithRetry({gemini, config, prompt}) {
  const delays = [1000, 3000, 7000];
  let lastError = null;
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    try {
      return await gemini.callMedia({
        model: config.GEMINI_IMAGE_MODEL,
        body: {
          contents: [{role: 'user', parts: [{text: prompt}]}],
          generationConfig: {responseModalities: ['TEXT', 'IMAGE']},
        },
        timeout: 60000,
      });
    } catch (error) {
      lastError = error;
      if (attempt === 3 || !isTransientProviderError(error)) throw error;
      await wait(delays[attempt - 1]);
    }
  }
  throw lastError;
}

function creditBalanceHeader(credits, auth) {
  if (!credits?.getCreditAccount || !auth?.userId) return null;
  const account = credits.getCreditAccount(auth.userId, auth.email || '');
  return String(account.balance);
}

function createImageController({config, gemini, credits, cache, readJson, sendJson, hashKey, assertResourceOwner}) {
  const operations = new Map();
  const assertImageRateLimit = createWindowLimiter({
    limit: Number(config.IMAGE_RATE_LIMIT_PER_MINUTE || 10),
    windowMs: 60000,
  });

  function log(req, type, details = {}) {
    const safe = {
      type,
      requestId: req?.headers?.['x-request-id'] || null,
      userId: req?.auth?.userId || null,
      ...details,
    };
    delete safe.prompt;
    delete safe.authorization;
    delete safe.token;
    console.warn('[image]', JSON.stringify(safe));
  }

  return async function handle(req, res) {
    const startedAt = Date.now();
    const auth = req.auth;
    if (!auth?.authenticated || !auth.userId) {
      return sendJson(res, 401, {error: 'Unauthorized'});
    }

    let data;
    let validated;
    try {
      assertImageRateLimit(auth.userId);
      data = await readJson(req);
      validated = validatePayload(data);
    } catch (error) {
      const status = error?.statusCode || 400;
      if (error?.retryAfter) res._extraHeaders = {...(res._extraHeaders || {}), 'Retry-After': String(error.retryAfter)};
      log(req, 'IMAGE_VALIDATION_FAILED', {status, reason: error?.message || String(error), retryAfter: error?.retryAfter || null});
      return sendJson(res, status, {error: publicError(error), code: status === 429 ? 'IMAGE_RATE_LIMITED' : 'IMAGE_VALIDATION_FAILED', retry_after: error?.retryAfter});
    }

    if (validated.aspectFallback) {
      log(req, 'IMAGE_ASPECT_FALLBACK', {requested: validated.requestedAspectRatio, aspect: validated.aspectRatio});
    }
    if (validated.promptTruncated) log(req, 'IMAGE_PROMPT_TRUNCATED', {cap: 4000});
    if (validated.promptSuspect) log(req, 'IMAGE_PROMPT_SUSPECT', {promptChars: validated.prompt.length});

    const promptHash = hashKey(validated.prompt);
    const lessonHash = hashKey(validated.lessonKey);
    const cacheKey = `image:${auth.userId}:${lessonHash}:${validated.aspectRatio}:${promptHash}`;
    const operationId = `image:${auth.userId}:${hashKey(validated.idempotencyKey)}:${promptHash}`;

    assertResourceOwner(auth, 'media', cacheKey, {
      create: true,
      metadata: {type: 'image', lessonKey: validated.lessonKey},
    });

    res._extraHeaders = {
      ...(res._extraHeaders || {}),
      'Cache-Control': 'private, max-age=3600',
    };

    const cached = cache.get(cacheKey);
    if (cached) {
      log(req, 'IMAGE_CACHE_HIT', {cacheKey, operationId, ms: Date.now() - startedAt});
      return sendJson(res, 200, {
        ...cached,
        cache_hit: true,
        cached: true,
        charged: false,
        requestId: res?._requestId || undefined,
      });
    }

    const previous = operations.get(operationId);
    if (previous?.status === 'succeeded') {
      log(req, 'IMAGE_IDEMPOTENT_REPLAY', {cacheKey, operationId, ms: Date.now() - startedAt});
      return sendJson(res, 200, {
        ...previous.body,
        idempotent_replay: true,
        charged: false,
        requestId: res?._requestId || undefined,
      });
    }
    if (previous?.status === 'running') {
      return sendJson(res, 409, {
        error: 'Geração de imagem já está em andamento para esta oferta.',
        code: 'IMAGE_ALREADY_RUNNING',
      });
    }

    operations.set(operationId, {status: 'running', startedAt: Date.now()});
    let reservationId = null;
    let captured = false;
    try {
      log(req, 'IMAGE_GENERATION_STARTED', {cacheKey, operationId, cost: config.IMAGE_CREDIT_COST, model: config.GEMINI_IMAGE_MODEL});
      reservationId = credits.reserveCredit(
        auth.userId,
        config.IMAGE_CREDIT_COST,
        'lesson-image',
        operationId,
        auth.email || '',
      ).reservationId;

      const result = await callImageProviderWithRetry({gemini, config, prompt: validated.prompt});
      const inline = findInlineData(result, 'image/');
      if (!inline?.data) throw new Error('provider returned no image');

      const mimeType = inline.mimeType || inline.mime_type || 'image/png';
      const body = {
        dataUrl: `data:${mimeType};base64,${inline.data}`,
        image_data_url: `data:${mimeType};base64,${inline.data}`,
        used_prompt: validated.prompt,
        aspect_ratio: validated.aspectRatio,
        mime_type: mimeType,
        provider: 'gemini',
        model: config.GEMINI_IMAGE_MODEL,
        cacheKey,
        cost: config.IMAGE_CREDIT_COST,
        charged: config.IMAGE_CREDIT_COST > 0,
        acceptedOfferId: validated.acceptedOfferId,
        idempotencyKey: validated.idempotencyKey,
        auth_verified: true,
      };
      credits.captureCredit(auth.userId, reservationId);
      captured = true;
      const balance = creditBalanceHeader(credits, auth);
      if (balance != null) res._extraHeaders = {...(res._extraHeaders || {}), 'X-Credits-Balance': balance};
      cache.set(cacheKey, body);
      operations.set(operationId, {status: 'succeeded', body, completedAt: Date.now()});
      log(req, 'IMAGE_GEN_OK', {
        cacheKey,
        operationId,
        charged: body.charged,
        model: body.model,
        aspect: body.aspect_ratio,
        promptSha: promptHash,
        bytes: inline.data.length,
        ms: Date.now() - startedAt,
      });
      return sendJson(res, 200, {...body, requestId: res?._requestId || undefined});
    } catch (error) {
      if (reservationId && !captured) credits.releaseCredit(auth.userId, reservationId);
      const balance = creditBalanceHeader(credits, auth);
      if (balance != null) res._extraHeaders = {...(res._extraHeaders || {}), 'X-Credits-Balance': balance};
      operations.set(operationId, {
        status: 'failed',
        failedAt: Date.now(),
        error: error?.message || String(error),
      });
      const status = error?.statusCode || 502;
      log(req, 'IMAGE_GEN_FAIL', {
        cacheKey,
        operationId,
        status,
        model: config.GEMINI_IMAGE_MODEL,
        aspect: validated.aspectRatio,
        promptSha: promptHash,
        refunded: Boolean(reservationId && !captured),
        reason: status === 402 ? 'INSUFFICIENT_CREDITS' : 'PROVIDER_OR_IMAGE_ERROR',
        ms: Date.now() - startedAt,
      });
      return sendJson(res, status, {
        error: publicError(error),
        code: status === 402 ? 'INSUFFICIENT_CREDITS' : 'IMAGE_GENERATION_FAILED',
        refunded: Boolean(reservationId && !captured),
        charged: false,
        retryable: status >= 500 || status === 429,
      });
    }
  };
}

module.exports = {
  createImageController,
  buildImagePrompt,
  findInlineData,
  validatePayload,
  normalizeAspectRatio,
  callImageProviderWithRetry,
};

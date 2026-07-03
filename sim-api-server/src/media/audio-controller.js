function pcm16ToWavBase64(pcmBase64, sampleRate = 24000, channels = 1) {
  const pcm = Buffer.from(pcmBase64, 'base64');
  const byteRate = sampleRate * channels * 2;
  const blockAlign = channels * 2;
  const header = Buffer.alloc(44);
  header.write('RIFF', 0);
  header.writeUInt32LE(36 + pcm.length, 4);
  header.write('WAVE', 8);
  header.write('fmt ', 12);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(channels, 22);
  header.writeUInt32LE(sampleRate, 24);
  header.writeUInt32LE(byteRate, 28);
  header.writeUInt16LE(blockAlign, 32);
  header.writeUInt16LE(16, 34);
  header.write('data', 36);
  header.writeUInt32LE(pcm.length, 40);
  return Buffer.concat([header, pcm]).toString('base64');
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

function voiceByLang(lang) {
  const normalized = String(lang || '').trim();
  const base = normalized.split('-')[0];
  const voices = {
    pt: 'Charon',
    'pt-BR': 'Charon',
    en: 'Charon',
    'en-US': 'Charon',
    es: 'Fenrir',
    fr: 'Fenrir',
  };
  return voices[normalized] || voices[base] || 'Charon';
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

function creditBalanceHeader(credits, auth) {
  if (!credits?.getCreditAccount || !auth?.userId) return null;
  const account = credits.getCreditAccount(auth.userId, auth.email || '');
  return String(account.balance);
}

function createAudioController({config, gemini, credits, cache, readJson, sendJson, hashKey, assertResourceOwner}) {
  const assertAudioRateLimit = createWindowLimiter({
    limit: Number(config.AUDIO_RATE_LIMIT_PER_MINUTE || 20),
    windowMs: 60000,
  });

  function log(req, type, details = {}) {
    console.warn('[audio]', JSON.stringify({
      type,
      requestId: req?.headers?.['x-request-id'] || null,
      userId: req?.auth?.userId || null,
      ...details,
    }));
  }

  return async function handle(req, res) {
    const startedAt = Date.now();
    const auth = req.auth;
    if (!auth?.authenticated || !auth.userId) {
      return sendJson(res, 401, {error: 'Unauthorized'});
    }

    let data;
    try {
      assertAudioRateLimit(auth.userId);
      data = await readJson(req);
    } catch (error) {
      if (error?.retryAfter) res._extraHeaders = {...(res._extraHeaders || {}), 'Retry-After': String(error.retryAfter)};
      return sendJson(res, error.statusCode || 400, {
        error: error.statusCode === 429 ? 'Muitas solicitações de áudio. Tente novamente em instantes.' : (error.message || String(error)),
        code: error.statusCode === 429 ? 'AUDIO_RATE_LIMITED' : 'AUDIO_REQUEST_INVALID',
        retry_after: error.retryAfter,
      });
    }

    const originalText = String(data.text || data.explanation || '').trim();
    if (originalText.length < 2) return sendJson(res, 400, {error: 'text obrigatorio'});
    const cap = Number(config.AUDIO_TEXT_MAX_CHARS || 4096);
    const text = originalText.length > cap ? originalText.slice(0, cap) : originalText;
    if (originalText.length > cap) log(req, 'TTS_TEXT_TRUNCATED', {originalChars: originalText.length, cap});
    const lang = String(data.lang || data.language || data.stable_lang || 'pt');
    const language = String(data.language || lang);
    const speed = Number(data.speed || 1);
    const voice = String(data.voice || voiceByLang(lang));
    const lessonKey = String(data.lessonKey || data.cacheKey || hashKey(text));
    const cacheKey = `audio:${lessonKey}:${language}:${voice}:${speed}:${hashKey(text)}`;

    assertResourceOwner(auth, 'media', cacheKey, {
      create: true,
      metadata: {type: 'audio', lessonKey},
    });

    const cached = cache.get(cacheKey);
    if (cached) {
      log(req, 'AUDIO_CACHE_HIT', {cacheKey, ms: Date.now() - startedAt});
      return sendJson(res, 200, {...cached, cache_hit: true, cached: true, charged: false, lab_credit_mode: true});
    }

    const operationId = `audio:${cacheKey}`;
    let reservationId = null;
    const creditCost = Number(config.AUDIO_CREDIT_COST || 0);
    try {
      if (creditCost > 0) {
        reservationId = credits.reserveCredit(auth.userId, creditCost, 'lesson-audio', operationId, auth.email || '').reservationId;
      }
      const instruction = `Leia em voz clara e didatica no idioma ${language}, velocidade ${speed}. Texto: ${text}`;
      log(req, 'TTS_GEN', {model: config.GEMINI_TTS_MODEL, voice, language, speed, textChars: text.length});
      const result = await gemini.callMedia({
        model: config.GEMINI_TTS_MODEL,
        body: {
          contents: [{role: 'user', parts: [{text: instruction}]}],
          generationConfig: {
            responseModalities: ['AUDIO'],
            speechConfig: {voiceConfig: {prebuiltVoiceConfig: {voiceName: voice}}},
          },
        },
        timeout: 90000,
      });
      const inline = findInlineData(result, 'audio/');
      const dataPart = inline?.inlineData || inline?.inline_data || inline;
      if (!dataPart?.data) throw new Error('Gemini nao retornou audio.');
      let mimeType = dataPart.mimeType || dataPart.mime_type || 'audio/wav';
      let audioBase64 = dataPart.data;
      if (/audio\/L16/i.test(mimeType)) {
        audioBase64 = pcm16ToWavBase64(audioBase64, 24000, 1);
        mimeType = 'audio/wav';
      }
      const body = {
        audio_base64: audioBase64,
        dataUrl: `data:${mimeType};base64,${audioBase64}`,
        mime_type: mimeType,
        voice,
        language,
        speed,
        provider: 'gemini',
        model: config.GEMINI_TTS_MODEL,
        cacheKey,
        cost: config.AUDIO_CREDIT_COST,
        charged: config.AUDIO_CREDIT_COST > 0,
        lab_credit_mode: true,
        auth_verified: auth.authenticated,
      };
      if (reservationId) credits.captureCredit(auth.userId, reservationId);
      const balance = creditBalanceHeader(credits, auth);
      if (balance != null) res._extraHeaders = {...(res._extraHeaders || {}), 'X-Credits-Balance': balance};
      cache.set(cacheKey, body);
      log(req, 'TTS_GEN_OK', {cacheKey, model: config.GEMINI_TTS_MODEL, ms: Date.now() - startedAt});
      return sendJson(res, 200, body);
    } catch (error) {
      if (reservationId) credits.releaseCredit(auth.userId, reservationId);
      const balance = creditBalanceHeader(credits, auth);
      if (balance != null) res._extraHeaders = {...(res._extraHeaders || {}), 'X-Credits-Balance': balance};
      log(req, 'TTS_GEN_FAIL', {status: error.statusCode || 500, refunded: Boolean(reservationId), ms: Date.now() - startedAt});
      return sendJson(res, error.statusCode || 500, {
        error: error.message || String(error),
        refunded: Boolean(reservationId),
        lab_credit_mode: true,
        retryable: (error.statusCode || 500) >= 500,
      });
    }
  };
}

module.exports = {createAudioController, pcm16ToWavBase64, voiceByLang};

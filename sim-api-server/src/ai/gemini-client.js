const https = require('https');

function isTemporaryGeminiError(e) {
  const m = String(e?.message || '').toLowerCase();
  return [
    'high demand',
    'overloaded',
    'unavailable',
    'timeout',
    'temporar',
    '429',
    '503',
    '500',
    '404',
    'not found',
    'not_found',
  ].some((x) => m.includes(x));
}

function createGeminiClient(config) {
  function requestGemini(model, method, body, timeout) {
    return new Promise((resolve, reject) => {
      let settled = false;
      const finishResolve = (value) => {
        if (settled) return;
        settled = true;
        resolve(value);
      };
      const finishReject = (error) => {
        if (settled) return;
        settled = true;
        reject(error);
      };
      const req = https.request({
        hostname: 'generativelanguage.googleapis.com',
        path: `/v1beta/models/${encodeURIComponent(model)}${method}?key=${encodeURIComponent(config.GEMINI_API_KEY)}`,
        method: 'POST',
        headers: {'content-type': 'application/json', 'content-length': Buffer.byteLength(body)},
        timeout,
      }, (r) => {
        let data = '';
        r.on('data', (c) => { data += c; });
        r.on('end', () => {
          try {
            const p = JSON.parse(data || '{}');
            if (r.statusCode < 200 || r.statusCode >= 300) {
              const e = new Error(p?.error?.message || `Gemini HTTP ${r.statusCode}`);
              e.statusCode = r.statusCode;
              e.model = model;
              finishReject(e);
            } else {
              finishResolve(p);
            }
          } catch (e) {
            finishReject(e);
          }
        });
      });
      req.on('timeout', () => finishReject(new Error('Timeout ao chamar Gemini.')));
      req.on('error', finishReject);
      req.write(body);
      req.end();
    });
  }

  function callTextWithModel({
    model,
    systemPrompt,
    userPayload,
    json = false,
    maxTokens = 8192,
    temperature = 0.2,
    inlineData,
    timeout = 90000,
  }) {
    const parts = [{text: userPayload}];
    if (inlineData) parts.push({inline_data: inlineData});
    const body = JSON.stringify({
      systemInstruction: {parts: [{text: systemPrompt}]},
      contents: [{role: 'user', parts}],
      generationConfig: {
        temperature,
        maxOutputTokens: maxTokens,
        ...(json ? {responseMimeType: 'application/json'} : {}),
      },
    });
    return requestGemini(model, ':generateContent', body, timeout).then((p) => (
      p?.candidates?.[0]?.content?.parts?.map((x) => x.text || '').join('\n') || ''
    ));
  }

  async function callText(options) {
    if (!config.GEMINI_API_KEY) throw new Error('GEMINI_API_KEY nao configurada no servidor.');
    let last = null;
    const models = options?.model ? [options.model] : config.GEMINI_TEXT_MODELS;
    for (const model of models) {
      try {
        return await callTextWithModel({...options, model});
      } catch (e) {
        last = e;
        console.warn(JSON.stringify({event: 'GEMINI_TEXT_MODEL_FAILED', model, temporary: isTemporaryGeminiError(e), statusCode: e?.statusCode || null, message: String(e?.message || '').slice(0, 180), at: new Date().toISOString()}));
        if (!isTemporaryGeminiError(e)) break;
      }
    }
    throw last || new Error('Falha ao chamar Gemini.');
  }

  function parseStreamLine(line, state) {
    const t = String(line || '').trim();
    if (!t || !t.startsWith('data:')) return '';
    const payload = t.slice(5).trim();
    if (!payload || payload === '[DONE]') return '';
    try {
      const parsed = JSON.parse(payload);
      const candidate = parsed?.candidates?.[0];
      if (candidate?.finishReason) state.finishReason = candidate.finishReason;
      return candidate?.content?.parts?.map((p) => p?.text || '').join('') || '';
    } catch (_) {
      state.parseErrors += 1;
      return '';
    }
  }

  function streamWithModel({
    model,
    systemPrompt,
    userPayload,
    maxTokens = 24576,
    temperature = 0.2,
    onTextDelta,
    timeout = 120000,
  }) {
    const body = JSON.stringify({
      systemInstruction: {parts: [{text: systemPrompt}]},
      contents: [{role: 'user', parts: [{text: userPayload}]}],
      generationConfig: {temperature, maxOutputTokens: maxTokens},
    });
    return new Promise((resolve, reject) => {
      let raw = '';
      let buffer = '';
      let responseBody = '';
      const state = {finishReason: null, parseErrors: 0};
      const startedAt = Date.now();
      const req = https.request({
        hostname: 'generativelanguage.googleapis.com',
        path: `/v1beta/models/${encodeURIComponent(model)}:streamGenerateContent?alt=sse&key=${encodeURIComponent(config.GEMINI_API_KEY)}`,
        method: 'POST',
        headers: {'content-type': 'application/json', 'content-length': Buffer.byteLength(body)},
        timeout,
      }, (r) => {
        r.setEncoding('utf8');
        r.on('data', (chunk) => {
          responseBody += chunk;
          if (r.statusCode < 200 || r.statusCode >= 300) return;
          buffer += chunk;
          const lines = buffer.split(/\r?\n/);
          buffer = lines.pop() || '';
          for (const line of lines) {
            const d = parseStreamLine(line, state);
            if (!d) continue;
            raw += d;
            if (onTextDelta) onTextDelta(d, raw);
          }
        });
        r.on('end', () => {
          if (r.statusCode < 200 || r.statusCode >= 300) {
            let m = `Gemini stream HTTP ${r.statusCode}`;
            try { m = JSON.parse(responseBody || '{}')?.error?.message || m; } catch (_) {}
            const e = new Error(m);
            e.statusCode = r.statusCode;
            e.model = model;
            return reject(e);
          }
          const tail = parseStreamLine(buffer, state);
          if (tail) {
            raw += tail;
            if (onTextDelta) onTextDelta(tail, raw);
          }
          console.log(JSON.stringify({event: 'GEMINI_STREAM_END', model, status: r.statusCode, chars: raw.length, finishReason: state.finishReason, parseErrors: state.parseErrors, ms: Date.now() - startedAt}));
          resolve({raw, modelUsed: model, finishReason: state.finishReason, parseErrors: state.parseErrors});
        });
      });
      req.on('timeout', () => req.destroy(new Error('Timeout ao chamar Gemini streaming.')));
      req.on('error', reject);
      req.write(body);
      req.end();
    });
  }

  async function callTextStream(options) {
    if (!config.GEMINI_API_KEY) throw new Error('GEMINI_API_KEY nao configurada no servidor.');
    let last = null;
    for (const model of config.GEMINI_TEXT_MODELS) {
      try {
        options?.onModelChosen?.(model);
        return await streamWithModel({...options, model});
      } catch (e) {
        last = e;
        console.warn(JSON.stringify({event: 'GEMINI_TEXT_STREAM_MODEL_FAILED', model, temporary: isTemporaryGeminiError(e), statusCode: e?.statusCode || null, message: String(e?.message || '').slice(0, 180), at: new Date().toISOString()}));
        if (!isTemporaryGeminiError(e)) break;
      }
    }
    throw last || new Error('Falha ao chamar Gemini streaming.');
  }

  function callMedia({model, body, timeout = 120000}) {
    if (!config.GEMINI_API_KEY) throw new Error('GEMINI_API_KEY nao configurada no servidor.');
    return requestGemini(model, ':generateContent', JSON.stringify(body), timeout);
  }

  return {callText, callTextStream, callMedia};
}

module.exports = {createGeminiClient, isTemporaryGeminiError};

const {
  extractBlock,
  mapT00ProfileToStudentState,
  parseT00Items,
  buildT00UserPayload,
  normalizeLanguage,
  sanitizeText,
} = require('./t00-parser');

function fatalCode(error) {
  const msg = String(error?.message || error || '').toLowerCase();
  if (msg.includes('timeout')) return 'T00_TIMEOUT';
  if (msg.includes('max_tokens') || msg.includes('truncated')) return 'T00_TRUNCATED';
  if (msg.includes('gemini') || msg.includes('model') || msg.includes('unavailable') || msg.includes('overloaded')) return 'T00_MODEL_UNAVAILABLE';
  return 'T00_UNKNOWN';
}

function createBootstrapController({prompts, gemini, readJson, sendJson, cors, assertRequestResourceOwners}) {
  return async function handle(req, res) {
    const auth = req.auth || await req.requireAuth(req);
    const body = await readJson(req);
    assertRequestResourceOwners(auth, body, 'bootstrap-t00');
    const ficha = body.ficha && typeof body.ficha === 'object' ? body.ficha : {};
    const freeText = sanitizeText(ficha.free_text || ficha.objetivo || '');
    if (freeText.length < 10) return sendJson(res, 400, {error: 'ficha.free_text precisa de ao menos 10 caracteres'});

    const mode = String(body?.modo || body?.mode || '').toLowerCase();
    if (body?.modo && !body?.mode) console.warn('[T00_LEGACY_MODO_FIELD]');
    const userPayload = buildT00UserPayload(ficha);
    const attachmentsText = String(ficha.attachments_text || '');
    console.log('[T00_PAYLOAD]', JSON.stringify({
      freeTextChars: freeText.length,
      attachmentsCount: (attachmentsText.match(/--- Anexo:/g) || []).length,
      totalExtractedChars: attachmentsText.length,
      payloadChars: userPayload.length,
      hasNivel: ficha.nivel != null,
      hasOfficialCurriculumReference: ficha.official_curriculum_reference != null,
      hasPriorKnowledge: ficha.prior_knowledge != null,
      hasKnownWeaknesses: ficha.known_weaknesses != null,
    }));

    res.writeHead(200, cors({'content-type': 'text/event-stream; charset=utf-8', 'cache-control': 'no-cache, no-transform', connection: 'keep-alive'}, res));
    let closed = false;
    const send = (obj) => {
      if (!closed && !res.destroyed && !res.writableEnded) res.write(`data: ${JSON.stringify(obj)}\n\n`);
    };
    const hb = setInterval(() => {
      try {
        if (!closed) res.write(`: hb ${Date.now()}\n\n`);
      } catch (_) {}
    }, 5000);
    req.on('close', () => { closed = true; clearInterval(hb); });

    let chosenModel = null;
    let startSent = false;
    const sendStart = () => {
      if (startSent) return;
      startSent = true;
      send({type: 'start', mode: 't00', ts: Date.now(), prompt_sha: prompts.sha?.t00 || null, model: chosenModel});
    };
    const startedAt = Date.now();
    try {
      let profileEmitted = false;
      const emitted = new Set();
      const partial = [];
      const emitProfile = (raw) => {
        if (profileEmitted) return;
        const profileRaw = extractBlock(raw, 'PROFILE');
        if (!profileRaw) return;
        profileEmitted = true;
        const mapped = mapT00ProfileToStudentState(profileRaw, ficha);
        send({type: 't00_profile', profile: profileRaw, ficha_for_next: {...ficha, free_text: freeText, language: normalizeLanguage(ficha), objetivo: mapped.objetivo || ficha.objetivo || freeText, target_topic: ficha.target_topic || ficha.TARGET_TOPIC || freeText, student_profile_notes: profileRaw, student_profile_internal: mapped.student_profile_internal, teaching_style_for_T02: mapped.teaching_style_for_T02, review_strategy: mapped.review_strategy, recovery_strategy: mapped.recovery_strategy, motivation_strategy: mapped.motivation_strategy, do_not_do: mapped.do_not_do, probable_level: mapped.nivel, reported_difficulties: mapped.dificuldades, knowledge_gaps: mapped.lacunas, minimum_curriculum_size: mapped.minimum_curriculum_size, pedagogical_inferences: mapped.inferencias, guidance_for_T01: profileRaw, guidance_for_T02: mapped.guidance_for_T02 || profileRaw, bootstrap_engine: 'T00', bootstrap_status: 'complete'}});
      };
      const emitItems = (raw) => {
        const m = String(raw || '').match(/<CURRICULUM>\s*([\s\S]*?)(?:<\/CURRICULUM>|$)/i);
        if (!m) return;
        let text = m[1];
        if (!/<\/CURRICULUM>/i.test(String(raw || '')) && !/[\r\n]\s*$/.test(text)) text = text.replace(/[^\r\n]*$/, '');
        for (const item of parseT00Items(text)) {
          const k = String(item.marker || '').toLowerCase();
          if (!k || emitted.has(k)) continue;
          emitted.add(k);
          partial.push(item);
          send({type: 't00_item_partial', item, order: item.order, marker: item.marker});
          if (partial.length === 1) {
            send({type: 't00_partial_ready', count: 1});
            console.log('[t00] primeiro item ms=' + (Date.now() - startedAt) + ' marker=' + item.marker);
          }
        }
      };

      const systemPrompt = mode === 'amparo' ? `${prompts.t00}\n\n${prompts.supportT00 || ''}` : prompts.t00;
      let result = null;
      let lastError = null;
      const maxAttempts = Number(process.env.AI_MAX_RETRIES || 3);
      for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
        try {
          result = await gemini.callTextStream({
            systemPrompt,
            userPayload,
            maxTokens: attempt === 1 ? 24576 : 32768,
            temperature: 0.2,
            onModelChosen: (m) => { chosenModel = m; sendStart(); },
            onTextDelta: (_d, rawText) => { emitProfile(rawText); emitItems(rawText); },
          });
          break;
        } catch (error) {
          lastError = error;
          console.warn('[T00_STREAM_ATTEMPT_FAILED]', JSON.stringify({attempt, maxAttempts, code: fatalCode(error), error: String(error?.message || error).slice(0, 180)}));
          if (attempt < maxAttempts) await new Promise((resolve) => setTimeout(resolve, 1000 * attempt));
        }
      }
      if (!result) throw lastError || new Error('T00_STREAM_FAILED');
      const raw = result.raw ?? String(result || '');
      if (result.finishReason === 'MAX_TOKENS') console.warn('[T00_TRUNCATED_RETRY_EXHAUSTED]', JSON.stringify({model: result.modelUsed, chars: raw.length}));

      const profile = extractBlock(raw, 'PROFILE');
      const curriculumRaw = extractBlock(raw, 'CURRICULUM');
      const qualityRaw = extractBlock(raw, 'QUALITY_CHECK');
      const endRaw = extractBlock(raw, 'END');
      const missing = {profile: !profile, curriculum: !curriculumRaw, qualityCheck: !qualityRaw, end: endRaw !== 'T00_COMPLETE'};
      if (missing.profile || missing.curriculum || missing.qualityCheck || missing.end) {
        send({type: 'fatal', code: 'T00_INCOMPLETE_CONTRACT', error: 'T00_INCOMPLETE_CONTRACT', missing, model: result.modelUsed || chosenModel || null, prompt_sha: prompts.sha?.t00 || null});
        return res.end();
      }
      const items = parseT00Items(curriculumRaw);
      if (!items.length) {
        send({type: 'fatal', code: 'T00_EMPTY_CURRICULUM', error: 'T00_EMPTY_CURRICULUM', detail: 'Modelo respondeu sem itens validos no formato esperado.', rawChars: String(raw || '').length});
        return res.end();
      }
      if (!profileEmitted) emitProfile(raw);
      send({type: 't00_quality_check', quality_check: {raw: qualityRaw}});
      for (const item of items) {
        const k = String(item.marker || '').toLowerCase();
        if (emitted.has(k)) continue;
        send({type: 't00_item_partial', item, order: item.order, marker: item.marker});
      }
      send({type: 't00_final', curriculo: items, curriculum: items, profile, raw_complete: true, model: result.modelUsed || chosenModel || null, prompt_sha: prompts.sha?.t00 || null});
      send({type: 'done', ok: true});
      res.end();
    } catch (e) {
      send({type: 'fatal', code: fatalCode(e), error: e.message || String(e), prompt_sha: prompts.sha?.t00 || null, model: chosenModel || null});
      res.end();
    } finally {
      closed = true;
      clearInterval(hb);
    }
  };
}

module.exports = {createBootstrapController, fatalCode};

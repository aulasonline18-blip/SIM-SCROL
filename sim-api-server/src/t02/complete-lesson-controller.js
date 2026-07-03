const {normalizeVisualTrigger} = require('./visual-trigger-normalizer');

function extractJson(text) {
  if (!text) return null;
  try { return JSON.parse(text); } catch (_) {}
  const fenced = String(text).match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fenced) { try { return JSON.parse(fenced[1]); } catch (_) {} }
  const match = String(text).match(/\{[\s\S]*\}/);
  if (!match) return null;
  try { return JSON.parse(match[0]); } catch (_) { return null; }
}

function contractError(message) {
  const e = new Error(message);
  e.code = 'T02_CONTRACT_INVALID';
  e.statusCode = 502;
  return e;
}

function normalizeLessonJson(raw, source) {
  const obj = extractJson(raw);
  if (!obj || typeof obj !== 'object') throw contractError('T02 retornou JSON invalido');
  const c = obj.conteudo && typeof obj.conteudo === 'object' ? obj.conteudo : obj;
  const explanation = String(c.explanation || c.explicacao || '').trim();
  if (!explanation) throw contractError('explanation ausente/vazia');
  const question = String(c.question || c.pergunta || '').trim();
  if (!question) throw contractError('question ausente/vazia');
  const options = c.options && typeof c.options === 'object' ? c.options : null;
  if (!options) throw contractError('options ausente');
  const normalizedOptions = {A: String(options.A || options.a || '').trim(), B: String(options.B || options.b || '').trim(), C: String(options.C || options.c || '').trim()};
  for (const key of ['A', 'B', 'C']) if (!normalizedOptions[key]) throw contractError(`options.${key} ausente/vazia`);
  if ('D' in options || 'd' in options) throw contractError('alternativa D proibida');
  const rawCorrect = c.correct_answer ?? c.correctAnswer;
  const correct = rawCorrect == null || rawCorrect === '' ? null : String(rawCorrect).toUpperCase();
  if (!['A', 'B', 'C'].includes(correct)) throw contractError('correct_answer invalido');
  return {
    conteudo: {
      explanation,
      question,
      options: normalizedOptions,
      correct_answer: correct,
      why_correct: String(c.why_correct || c.whyCorrect || '').trim(),
      why_wrong: c.why_wrong || c.whyWrong || {},
      visual_trigger: normalizeVisualTrigger(c.visual_trigger || c.visualTrigger || null),
      source,
    },
  };
}

function buildT02Payload(data, kind) {
  const doubtImage = data.doubt_image && typeof data.doubt_image === 'object' ? {name: data.doubt_image.name || null, type: data.doubt_image.type || null, size: data.doubt_image.size || null, hasImageData: Boolean(data.doubt_image.dataUrl)} : null;
  const recentErrors = Array.isArray(data.recent_errors) ? data.recent_errors.slice(-8) : Array.isArray(data.recentErrors) ? data.recentErrors.slice(-8) : null;
  const conquestHistory = Array.isArray(data.conquest_history) ? data.conquest_history.slice(-10) : Array.isArray(data.history) ? data.history.slice(-10) : [];
  const questionContext = data.question_context && typeof data.question_context === 'object' ? data.question_context : {};
  return JSON.stringify({
    mode: data.mode || kind,
    aux_mode: kind === 'lesson' || kind === 'placement' ? undefined : kind,
    output_contract: kind === 'doubt' || data.mode === 'amparo' || data.mode === 'support' ? 'reduced' : 'complete',
    lessonLocalId: data.lessonLocalId || null,
    item: data.item || data.target_topic || '',
    marker: data.marker || null,
    target_topic: data.target_topic || data.item || null,
    layer: data.layer || 1,
    err_count: data.err_count || 0,
    lesson_mode: data.lesson_mode || data.mode || 'session',
    conquest_history: conquestHistory,
    history: conquestHistory,
    signal: data.signal || null,
    stable_lang: data.stable_lang || data.stableLang || data.lang || 'Portuguese',
    language: data.language || data.stable_lang || data.stableLang || data.lang || 'Portuguese',
    preferred_name: data.preferred_name || null,
    student_age: data.student_age || null,
    age_range: data.age_range || null,
    school_year: data.school_year || null,
    academic_level: data.academic_level || data.academic || null,
    country_or_curriculum: data.country_or_curriculum || null,
    subject: data.subject || null,
    learning_goal: data.learning_goal || null,
    session_goal: data.session_goal || null,
    geographic_zone: data.geographic_zone || null,
    original_text_preserved: data.original_text_preserved || null,
    exam_goal: data.exam_goal || null,
    real_use_goal: data.real_use_goal || null,
    prior_knowledge: data.prior_knowledge || null,
    known_weaknesses: data.known_weaknesses || null,
    recent_errors: recentErrors,
    confidence_pattern: data.confidence_pattern || null,
    attention_profile: data.attention_profile || null,
    motivation_profile: data.motivation_profile || null,
    reading_level: data.reading_level || null,
    calculation_level: data.calculation_level || null,
    learning_care_notes: data.learning_care_notes || null,
    student_profile_notes: data.student_profile_notes || null,
    student_profile_internal: data.student_profile_internal || null,
    guidance_for_T02: data.guidance_for_T02 || data.addendum || null,
    interpreted_fields: data.interpreted_fields || null,
    source_status: data.source_status || null,
    visual_policy: data.visual_policy || null,
    student_doubt: data.student_doubt || null,
    question_context: kind === 'doubt' ? {
      original_question: data.original_question || questionContext.original_question || data.question || null,
      original_options: data.original_options || questionContext.original_options || data.options || null,
      correct_answer: data.correct_answer || questionContext.correct_answer || null,
      student_answer: data.student_answer || questionContext.student_answer || null,
    } : null,
    doubt_image: doubtImage,
    current_content: data.current_content || null,
  }, null, 2);
}

function extractDoubtInlineData(data, maxMb = 2) {
  const image = data?.doubt_image;
  if (!image || typeof image !== 'object') return null;
  const dataUrl = String(image.dataUrl || '');
  const match = /^data:(image\/(?:jpeg|png|webp));base64,([A-Za-z0-9+/=]+)$/i.exec(dataUrl);
  if (!match) {
    const e = new Error('unsupported_mime');
    e.statusCode = 400;
    throw e;
  }
  const bytes = Buffer.from(match[2], 'base64');
  if (bytes.length > maxMb * 1024 * 1024) {
    const e = new Error('compressão obrigatória');
    e.statusCode = 413;
    e.maxBytes = maxMb * 1024 * 1024;
    throw e;
  }
  return {mime_type: match[1].toLowerCase(), data: match[2]};
}

function createCompleteLessonController({gemini, prompts, readJson, sendJson, assertRequestResourceOwners, config = {}}) {
  async function completeLesson(data, kind) {
    const startedAt = Date.now();
    const payload = buildT02Payload(data, kind);
    try {
      console.log('[t02]', JSON.stringify({kind, marker: data?.marker || null, lessonLocalId: String(data?.lessonLocalId || '').slice(0, 16), layer: data?.layer || null, mode: data?.mode || data?.modo || null, prompt_sha: prompts.sha?.t02 || null, payloadKeys: Object.keys(JSON.parse(payload)), historyCount: JSON.parse(payload).conquest_history?.length || 0}));
    } catch (_) {}
    const mode = String(data?.modo || data?.mode || '').toLowerCase();
    const addon = (mode === 'amparo' || mode === 'support') ? (prompts.supportT02 || '') : kind === 'doubt' ? (prompts.doubt || '') : kind === 'review' ? (prompts.review || '') : kind === 'recovery' ? (prompts.recovery || '') : '';
    const inlineData = kind === 'doubt' ? extractDoubtInlineData(data, Number(config.MAX_DOUBT_IMAGE_MB || process.env.MAX_DOUBT_IMAGE_MB || 8)) : null;
    let lastError = null;
    for (let attempt = 1; attempt <= 3; attempt += 1) {
      try {
        console.log('[t02] attempt', JSON.stringify({kind, attempt, maxAttempts: 3}));
        const raw = await gemini.callText({systemPrompt: addon ? `${prompts.t02}\n\n${addon}` : prompts.t02, userPayload: payload, inlineData, json: true, maxTokens: 8192, temperature: 0.2});
        const normalized = normalizeLessonJson(raw, `sim-api-${kind}`);
        if (kind === 'doubt') {
          console.log('[T02_DOUBT]', JSON.stringify({
            ms: Date.now() - startedAt,
            chars_in: payload.length,
            chars_out: JSON.stringify(normalized).length,
            has_image: Boolean(inlineData),
          }));
        }
        return normalized;
      } catch (error) {
        lastError = error;
        const retryable = error?.code === 'T02_CONTRACT_INVALID';
        console.warn('[t02] attempt failed', JSON.stringify({kind, attempt, retryable, error: error?.message || String(error)}));
        if (!retryable) throw error;
        if (attempt === 3) break;
      }
    }
    throw contractError(`T02 contrato invalido apos 3 tentativas: ${lastError?.message || 'erro desconhecido'}`);
  }

  async function handle(req, res, kind = 'lesson') {
    const data = await readJson(req);
    assertRequestResourceOwners(req.auth, data, kind === 'lesson' ? 'lesson' : kind);
    try {
      sendJson(res, 200, await completeLesson(data, kind));
    } catch (error) {
      sendJson(res, error.statusCode || 500, {error: error.message || String(error), code: error.code || 'T02_ERROR'});
    }
  }

  return {completeLesson, handle, buildT02Payload};
}

module.exports = {createCompleteLessonController, buildT02Payload, normalizeLessonJson, extractJson, extractDoubtInlineData};

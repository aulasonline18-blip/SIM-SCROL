const assert = require('assert');
const crypto = require('crypto');
const http = require('http');

process.env.SUPABASE_URL = '';
process.env.SUPABASE_ANON_KEY = '';
process.env.SUPABASE_JWT_SECRET = '';
process.env.LAB_TRUST_SUPABASE_JWT_CLAIMS = 'true';
process.env.TEST_CREDIT_EMAILS = 'aulasonline18@gmail.com';
process.env.RATE_LIMIT_IP_MAX_REQUESTS = '1000';
process.env.RATE_LIMIT_AI_MAX_REQUESTS = '1000';

const {router} = require('../src/app/router');
const {createJwtVerifier} = require('../src/auth/jwt-verifier');
const {parseT00Items, buildT00UserPayload, extractProfileValue} = require('../src/t00/t00-parser');
const {
      buildT02Payload,
      createCompleteLessonController,
      extractDoubtInlineData,
      normalizeLessonJson,
} = require('../src/t02/complete-lesson-controller');
const {createImageController, normalizeAspectRatio} = require('../src/media/image-controller');
const {createAudioController, voiceByLang} = require('../src/media/audio-controller');
const {createVisualRouteController} = require('../src/media/visual-route-controller');
const {createCreditsStore} = require('../src/credits/credits-store');
const {createAttachmentProcessor} = require('../src/attachments/attachment-processor');

function b64url(value) {
  return Buffer.from(JSON.stringify(value))
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function b64urlBuffer(value) {
  return Buffer.from(value)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function fakeToken(payload = {}) {
  return [
    b64url({alg: 'none', typ: 'JWT'}),
    b64url({
      sub: '11111111-1111-4111-8111-111111111111',
      email: 'student@example.com',
      exp: Math.floor(Date.now() / 1000) + 3600,
      ...payload,
    }),
    'signature',
  ].join('.');
}

function hsToken(secret, payload = {}) {
  const header = b64url({alg: 'HS256', typ: 'JWT'});
  const body = b64url({
    sub: '33333333-3333-4333-8333-333333333333',
    email: 'student@example.com',
    exp: Math.floor(Date.now() / 1000) + 3600,
    ...payload,
  });
  const signingInput = `${header}.${body}`;
  const signature = b64urlBuffer(crypto.createHmac('sha256', secret).update(signingInput).digest());
  return `${signingInput}.${signature}`;
}

function fakeResponse() {
  return {
    status: 0,
    body: null,
    writeHead(status) { this.status = status; },
    end(text) { this.body = text ? JSON.parse(text) : null; },
  };
}

function fakeCredits() {
  let reserved = 0;
  let captured = 0;
  let released = 0;
  return {
    get reserved() { return reserved; },
    get captured() { return captured; },
    get released() { return released; },
    reserveCredit() { reserved += 1; return {reservationId: `r-${reserved}`}; },
    captureCredit() { captured += 1; },
    releaseCredit() { released += 1; },
  };
}

function listen() {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => router(req, res));
    server.listen(0, '127.0.0.1', () => {
      resolve({server, port: server.address().port});
    });
  });
}

async function request(port, path, {method = 'GET', token, body, requestId} = {}) {
  const headers = {'content-type': 'application/json'};
  if (token) headers.authorization = `Bearer ${token}`;
  if (requestId) headers['x-request-id'] = requestId;
  const response = await fetch(`http://127.0.0.1:${port}${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  let json = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch (_) {}
  return {status: response.status, text, json};
}

async function main() {
  const authLogs = [];
  const auth = createJwtVerifier(
    {SUPABASE_URL: '', SUPABASE_ANON_KEY: '', SUPABASE_JWT_SECRET: 'test-secret', LAB_TRUST_SUPABASE_JWT_CLAIMS: false},
    (_type, _req, details) => authLogs.push(details),
  );
  const validAuthReq = {headers: {authorization: `Bearer ${hsToken('test-secret', {email: 'aulasonline18@gmail.com'})}`}, socket: {remoteAddress: '127.0.0.1'}};
  const validAuth = await auth.requireAuth(validAuthReq);
  assert.equal(validAuth.email, 'aulasonline18@gmail.com');

  const badLengthToken = [
    b64url({alg: 'HS256', typ: 'JWT'}),
    b64url({
      sub: '11111111-1111-4111-8111-111111111111',
      email: 'student@example.com',
      exp: Math.floor(Date.now() / 1000) + 3600,
    }),
    'bad',
  ].join('.');
  const badLengthReq = {headers: {authorization: `Bearer ${badLengthToken}`, 'x-request-id': 'req-bad-length'}, socket: {remoteAddress: '127.0.0.1'}, url: '/api/credits/me'};
  await assert.rejects(() => auth.requireAuth(badLengthReq), /Unauthorized/);
  assert.equal(authLogs.at(-1).reason, 'JWT_BAD_SIGNATURE_LENGTH');

  const {server, port} = await listen();
  try {
    const health = await request(port, '/api/health');
    assert.equal(health.status, 200);
    assert.equal(health.json.status, 'ok');
    assert.equal(typeof health.json.auth.jwt, 'boolean');
    assert.equal(typeof health.json.auth.jwks, 'boolean');
    assert.equal(typeof health.json.env.geminiConfigured, 'boolean');
    assert(!('GEMINI_API_KEY' in health.json.env));
    assert(!('SUPABASE_JWT_SECRET' in health.json.auth));

    const noToken = await request(port, '/api/bootstrap-t00', {
      method: 'POST',
      requestId: 'req-no-token',
      body: {ficha: {free_text: 'Aprender fracoes equivalentes'}},
    });
    assert.equal(noToken.status, 401);
    assert.equal(noToken.json.error, 'Unauthorized');
    assert.equal(noToken.json.requestId, 'req-no-token');

    const badToken = await request(port, '/api/bootstrap-t00', {
      method: 'POST',
      token: 'invalid.token.value',
      requestId: 'req-bad-token',
      body: {ficha: {free_text: 'Aprender fracoes equivalentes'}},
    });
    assert.equal(badToken.status, 401);
    assert.equal(badToken.json.requestId, 'req-bad-token');

    const validToken = await request(port, '/api/bootstrap-t00', {
      method: 'POST',
      token: fakeToken(),
      requestId: 'req-valid-token',
      body: {ficha: {free_text: 'curto'}},
    });
    assert.equal(validToken.status, 400);
    assert.equal(validToken.json.error, 'ficha.free_text precisa de ao menos 10 caracteres');
    assert.equal(validToken.json.requestId, 'req-valid-token');

    const testCredits = await request(port, '/api/credits/me', {
      method: 'POST',
      token: fakeToken({email: 'aulasonline18@gmail.com'}),
      requestId: 'req-test-credits',
    });
    assert.equal(testCredits.status, 200);
    assert.equal(testCredits.json.balance, 999999);
    assert.equal(testCredits.json.testCreditMode, true);

    const normalCredits = await request(port, '/api/credits/me', {
      method: 'POST',
      token: fakeToken({
        sub: '22222222-2222-4222-8222-222222222222',
        email: 'normal.student@example.com',
      }),
      requestId: 'req-normal-credits',
    });
    assert.equal(normalCredits.status, 200);
    assert.equal(normalCredits.json.balance, 0);
    assert.equal(normalCredits.json.testCreditMode, false);

    const syncLessonId = `sync-lesson-${Date.now()}`;
    const statePayload = {
      lessonLocalId: syncLessonId,
      state: {
        stateVersion: 1,
        lessonLocalId: syncLessonId,
        userId: null,
        createdAt: 1,
        updatedAt: 100,
        profile: {objetivo: 'Frações', stableLang: 'pt-BR'},
        curriculum: {
          topic: 'Frações',
          totalItems: 2,
          generatedAt: 1,
          provisional: false,
          items: [{marker: 'M1', text: 'Metade'}, {marker: 'M2', text: 'Comparar'}],
        },
        current: {itemIdx: 1, marker: 'M2', layer: 2, amparoLvl: 0},
        progress: {itemIdx: 1, layer: 2, mainAdvances: 1, concluidos: ['M1'], totalItems: 2, pctAvanco: 50},
        attempts: [{marker: 'M1', layer: 1, letra: 'A', sinal: 2, correct: true, ts: 10}],
        events: [],
      },
      clientUpdatedAt: 100,
      clientScore: 1012,
      schemaVersion: 1,
    };
    const persisted = await request(port, '/api/student-state/persist', {
      method: 'POST',
      token: fakeToken(),
      requestId: 'req-state-persist',
      body: statePayload,
    });
    assert.equal(persisted.status, 200);
    assert.equal(persisted.json.lessonLocalId, syncLessonId);

    const regression = await request(port, '/api/student-state/persist', {
      method: 'POST',
      token: fakeToken(),
      requestId: 'req-state-regression',
      body: {...statePayload, clientScore: 1, clientUpdatedAt: 1},
    });
    assert.equal(regression.status, 409);
    assert.equal(regression.json.rejected, true);
    assert.equal(regression.json.remoteState.current.marker, 'M2');

    const loaded = await request(port, '/api/student-state/get', {
      method: 'POST',
      token: fakeToken(),
      requestId: 'req-state-get',
      body: {lessonLocalId: syncLessonId},
    });
    assert.equal(loaded.status, 200);
    assert.equal(loaded.json.state.progress.layer, 2);

    const summaries = await request(port, '/api/student-state/summaries', {
      method: 'POST',
      token: fakeToken(),
      requestId: 'req-state-summaries',
      body: {},
    });
    assert.equal(summaries.status, 200);
    assert(summaries.json.rows.some((row) => row.lessonLocalId === syncLessonId && row.markerAtual === 'M2'));

    const deleted = await request(port, '/api/student-state/delete', {
      method: 'POST',
      token: fakeToken(),
      requestId: 'req-state-delete',
      body: {lessonLocalId: syncLessonId},
    });
    assert.equal(deleted.status, 200);
    assert.equal(deleted.json.ok, true);

    const deleteUserId = `22222222-2222-4222-8222-${String(Date.now()).slice(-12).padStart(12, '2')}`;
    const deleteUserToken = fakeToken({
      sub: deleteUserId,
      email: 'aulasonline18@gmail.com',
    });
    const accountLessonId = `lesson-account-delete-${Date.now()}`;
    const accountPersisted = await request(port, '/api/student-state/persist', {
      method: 'POST',
      token: deleteUserToken,
      requestId: 'req-account-state-persist',
      body: {
        lessonLocalId: accountLessonId,
        state: {
          lessonLocalId: accountLessonId,
          profile: {objetivo: 'Excluir depois'},
          curriculum: {items: [{marker: 'M1', text: 'Item'}]},
          progress: {itemIdx: 0, layer: 1, mainAdvances: 0},
        },
        clientUpdatedAt: 100,
        clientScore: 1,
        schemaVersion: 1,
      },
    });
    assert.equal(accountPersisted.status, 200);
    const beforeDeletionCredits = await request(port, '/api/credits/me', {
      method: 'POST',
      token: deleteUserToken,
      requestId: 'req-account-credits-before',
      body: {},
    });
    assert.equal(beforeDeletionCredits.status, 200);
    assert.equal(beforeDeletionCredits.json.balance, 999999);

    const missingConfirmation = await request(port, '/api/account/request-deletion', {
      method: 'POST',
      token: deleteUserToken,
      requestId: 'req-account-delete-missing-confirmation',
      body: {confirmation: 'deletar'},
    });
    assert.equal(missingConfirmation.status, 400);

    const mismatchDeletion = await request(port, '/api/account/request-deletion', {
      method: 'POST',
      token: deleteUserToken,
      requestId: 'req-account-delete-mismatch',
      body: {confirmation: 'DELETAR', userId: '11111111-1111-4111-8111-111111111111'},
    });
    assert.equal(mismatchDeletion.status, 403);

    const accountDeleted = await request(port, '/api/account/request-deletion', {
      method: 'POST',
      token: deleteUserToken,
      requestId: 'req-account-delete',
      body: {confirmation: 'DELETAR', userId: deleteUserId},
    });
    assert.equal(accountDeleted.status, 200);
    assert.equal(accountDeleted.json.ok, true);
    assert.equal(accountDeleted.json.deletedLessons, 1);

    const deletedAccountLesson = await request(port, '/api/student-state/get', {
      method: 'POST',
      token: deleteUserToken,
      requestId: 'req-account-state-after-delete',
      body: {lessonLocalId: accountLessonId},
    });
    assert.equal(deletedAccountLesson.status, 200);
    assert.equal(deletedAccountLesson.json.state, null);

    const afterDeletionCredits = await request(port, '/api/credits/me', {
      method: 'POST',
      token: deleteUserToken,
      requestId: 'req-account-credits-after',
      body: {},
    });
    assert.equal(afterDeletionCredits.status, 200);
    assert.equal(afterDeletionCredits.json.balance, 0);

    const items = parseT00Items(`
[1] marker: M1 | title: Fracoes | purpose: Reconhecer metade
[2] marker: M2 | title: Comparacao | purpose: Comparar denominadores iguais
`);
    assert.equal(items.length, 2);
    assert.equal(items[0].marker, 'M1');
    assert.equal(items[0].microitem_for_teacher, 'Reconhecer metade');

    const fallbackItems = parseT00Items(`
[0001] MI-01 | Somar frações | Ensinar soma com denominadores iguais
`);
    assert.equal(fallbackItems.length, 1);
    assert.equal(fallbackItems[0].marker, 'MI-01');

    assert.equal(
      extractProfileValue('RECOVERY_STRATEGY: linha1\nlinha2\nlinha3\nNEXT_LABEL: fim', ['RECOVERY_STRATEGY']),
      'linha1\nlinha2\nlinha3',
    );

    const t00Payload = buildT00UserPayload({
      free_text: 'Aprender parábolas com base no currículo oficial.',
      STABLE_LANG: 'PT-BR',
      nivel: '9º ano',
      official_curriculum_reference: 'BNCC EF09MA',
      prior_knowledge: 'função linear',
      known_weaknesses: 'não identifica intercepto',
      disciplina: 'matemática',
      interpreted_fields: {t00_profile: {ok: true}, lixo: 'remover'},
    });
    assert(t00Payload.includes('MIN_ITEMS_HINT: 20'));
    assert(t00Payload.includes('"language":"pt-br"'));
    assert(t00Payload.includes('"nivel":"9º ano"'));
    assert(t00Payload.includes('"official_curriculum_reference":"BNCC EF09MA"'));
    assert(t00Payload.includes('"prior_knowledge":"função linear"'));
    assert(t00Payload.includes('"known_weaknesses":"não identifica intercepto"'));
    assert(t00Payload.includes('"subject":"matemática"'));
    assert(!t00Payload.includes('lixo'));

    const payload = JSON.parse(
      buildT02Payload(
        {
          lessonLocalId: 'lesson-1',
          item: 'Reconhecer metade',
          marker: 'M1',
          layer: 1,
          stable_lang: 'pt-BR',
          academic_level: 'fundamental',
          preferred_name: 'Ana',
          student_profile_internal: {pace: 'visual'},
          guidance_for_T02: 'Use exemplo concreto.',
          history: ['h1'],
          session_goal: 'dominar metade',
          geographic_zone: 'BR',
          original_text_preserved: 'texto original',
        },
        'lesson',
      ),
    );
    assert.equal(payload.item, 'Reconhecer metade');
    assert.equal(payload.marker, 'M1');
    assert.equal(payload.layer, 1);
    assert.equal(payload.stable_lang, 'pt-BR');
    assert.equal(payload.academic_level, 'fundamental');
    assert.deepEqual(payload.student_profile_internal, {pace: 'visual'});
    assert.equal(payload.guidance_for_T02, 'Use exemplo concreto.');
    assert.deepEqual(payload.conquest_history, ['h1']);
    assert.deepEqual(payload.history, ['h1']);
    assert.equal(payload.session_goal, 'dominar metade');
    assert.equal(payload.geographic_zone, 'BR');
    assert.equal(payload.original_text_preserved, 'texto original');
    assert.deepEqual(JSON.parse(buildT02Payload({
      item: 'Duvida',
      question_context: {
        original_question: 'Quanto é 2+2?',
        original_options: {A: '3', B: '4', C: '5'},
        correct_answer: 'B',
        student_answer: 'A',
      },
    }, 'doubt')).question_context, {
      original_question: 'Quanto é 2+2?',
      original_options: {A: '3', B: '4', C: '5'},
      correct_answer: 'B',
      student_answer: 'A',
    });

    const material = normalizeLessonJson(
      JSON.stringify({
        explanation: 'Explicacao',
        question: 'Pergunta?',
        options: {A: 'A', B: 'B', C: 'C'},
        correct_answer: 'A',
        why_correct: 'Porque A',
      }),
      'test',
    );
    assert.equal(material.conteudo.explanation, 'Explicacao');
    assert.equal(material.conteudo.question, 'Pergunta?');
    assert.equal(material.conteudo.options.A, 'A');
    assert.equal(material.conteudo.correct_answer, 'A');
    assert.equal(material.conteudo.source, 'test');

    for (const visualType of [
      'timeline',
      'table',
      'cycle',
      'flowchart',
      'circuit',
      'force',
      'syntax_tree',
      'food_chain',
      'concept_map',
    ]) {
      const visualMaterial = normalizeLessonJson(
        JSON.stringify({
          explanation: 'Explicacao',
          question: 'Pergunta?',
          options: {A: 'A', B: 'B', C: 'C'},
          correct_answer: 'A',
          visual_trigger: {
            needs_image: true,
            pedagogical_need: 'important',
            render_strategy: 'software',
            visual_type: visualType,
            topic: `visual ${visualType}`,
            image_prompt: `desenhe ${visualType}`,
          },
        }),
        'test',
      );
      assert.equal(visualMaterial.conteudo.visual_trigger.visual_type, visualType);
      assert.equal(visualMaterial.conteudo.visual_trigger.needs_image, true);
    }

    assert.throws(
      () => normalizeLessonJson(
        JSON.stringify({
          explanation: '',
          question: 'Pergunta?',
          options: {A: 'A', B: 'B', C: 'C'},
          correct_answer: 'A',
        }),
        'test',
      ),
      /explanation ausente\/vazia/,
    );
    assert.throws(
      () => normalizeLessonJson(
        JSON.stringify({
          explanation: 'Explicacao',
          question: 'Pergunta?',
          options: {A: 'A', B: 'B', C: 'C'},
          correct_answer: 'D',
        }),
        'test',
      ),
      /correct_answer invalido/,
    );
    assert.throws(
      () => normalizeLessonJson(
        JSON.stringify({
          explanation: 'Explicacao',
          question: 'Pergunta?',
          options: {A: 'A', B: 'B', C: 'C'},
        }),
        'test',
      ),
      /correct_answer invalido/,
    );
    assert.throws(
      () => normalizeLessonJson(
        JSON.stringify({
          explanation: 'Explicacao',
          question: 'Pergunta?',
          options: {A: 'A', B: '', C: 'C'},
          correct_answer: 'A',
        }),
        'test',
      ),
      /options.B ausente\/vazia/,
    );

    const retryPrompts = {t02: 'T02', doubt: 'D', review: 'R', recovery: 'RC', supportT02: 'S'};
    const retryCalls = [];
    const retryController = createCompleteLessonController({
      prompts: retryPrompts,
      gemini: {
        async callText(args) {
          retryCalls.push(args);
          if (retryCalls.length === 1) {
            return '{"explanation":"","question":"Q?","options":{"A":"A","B":"B","C":"C"},"correct_answer":"A"}';
          }
          return '{"explanation":"Exp","question":"Q?","options":{"A":"A","B":"B","C":"C"},"correct_answer":"B"}';
        },
      },
      readJson: async (req) => req.body,
      sendJson: (res, status, body) => {
        res.writeHead(status, {'content-type': 'application/json'});
        res.end(JSON.stringify(body));
      },
      assertRequestResourceOwners: () => {},
    });
    const retryRes = fakeResponse();
    await retryController.handle({
      auth: {authenticated: true, userId: 'u1'},
      body: {lessonLocalId: 'l-retry', item: 'Item', marker: 'M1', layer: 1},
    }, retryRes, 'lesson');
    assert.equal(retryRes.status, 200);
    assert.equal(retryRes.body.conteudo.correct_answer, 'B');
    assert.equal(retryCalls.length, 2);

    const imageInlineCalls = [];
    const doubtController = createCompleteLessonController({
      prompts: retryPrompts,
      gemini: {
        async callText(args) {
          imageInlineCalls.push(args.inlineData);
          return '{"explanation":"Exp duvida","question":"Q?","options":{"A":"A","B":"B","C":"C"},"correct_answer":"A"}';
        },
      },
      readJson: async (req) => req.body,
      sendJson: (res, status, body) => {
        res.writeHead(status, {'content-type': 'application/json'});
        res.end(JSON.stringify(body));
      },
      assertRequestResourceOwners: () => {},
    });
    const doubtRes = fakeResponse();
    await doubtController.handle({
      auth: {authenticated: true, userId: 'u1'},
      body: {
        lessonLocalId: 'l-doubt',
        item: 'Item',
        marker: 'M1',
        layer: 1,
        doubt_image: {
          name: 'foto.png',
          type: 'image/png',
          size: 3,
          dataUrl: 'data:image/png;base64,QUJD',
        },
      },
    }, doubtRes, 'doubt');
    assert.equal(doubtRes.status, 200);
    assert.deepEqual(imageInlineCalls[0], {mime_type: 'image/png', data: 'QUJD'});
    assert.throws(() => extractDoubtInlineData({
      doubt_image: {dataUrl: 'data:application/pdf;base64,QUJD'},
    }), /unsupported_mime/);
    assert.throws(() => extractDoubtInlineData({
      doubt_image: {dataUrl: `data:image/png;base64,${Buffer.alloc(3 * 1024 * 1024).toString('base64')}`},
    }, 2), /compressão obrigatória/);

    const visualRoute = createVisualRouteController({
      config: {GEMINI_VISUAL_ROUTER_MODEL: 'test-lite'},
      gemini: {
        async callText(args) {
          assert.equal(args.model, 'test-lite');
          const payload = JSON.parse(args.userPayload);
          assert.equal(payload.contractVersion, 'n3_pedagogical_v1');
          assert.equal(payload.n2.reason, 'N2_KEYWORDS_SVG');
          assert.deepEqual(payload.keyElements, ['eixo x', 'eixo y']);
          assert.equal(payload.pedagogicalNeed, 'important');
          assert.equal(payload.highlightFocus, 'inclinação da reta');
          assert.equal(payload.stableLang, 'pt-BR');
          return JSON.stringify({
            verdict: 'svg',
            reason: 'TEST_SVG',
            confidence: 0.93,
            pedagogicalRole: 'graph_reasoning',
            svg: '<svg width="120" height="80"><text x="10" y="20">Graph</text></svg>',
          });
        },
      },
      readJson: async (req) => req.body,
      sendJson: (res, status, body) => {
        res.writeHead(status, {'content-type': 'application/json'});
        res.end(JSON.stringify(body));
      },
    });
    const visualRes = fakeResponse();
    await visualRoute({
      auth: {authenticated: true, userId: 'u1'},
      body: {
        topic: 'funcao linear',
        visualType: 'graph',
        imagePrompt: 'grafico de uma reta',
        hint: 'ambiguous',
        contractVersion: 'n3_pedagogical_v1',
        n2: {
          verdict: 'svg',
          reason: 'N2_KEYWORDS_SVG',
          matched: ['graph'],
          confidence: 0.78,
          pedagogicalRole: 'graph_reasoning',
        },
        keyElements: ['eixo x', 'eixo y'],
        pedagogicalNeed: 'important',
        highlightFocus: 'inclinação da reta',
        stableLang: 'pt-BR',
      },
    }, visualRes);
    assert.equal(visualRes.status, 200);
    assert.equal(visualRes.body.verdict, 'svg');
    assert.equal(visualRes.body.reason, 'TEST_SVG');
    assert.equal(visualRes.body.confidence, 0.93);
    assert.equal(visualRes.body.pedagogicalRole, 'graph_reasoning');
    assert.match(visualRes.body.svgDataUrl, /^data:image\/svg\+xml;utf8,/);

    const visualNoImage = createVisualRouteController({
      config: {GEMINI_VISUAL_ROUTER_MODEL: 'test-lite'},
      gemini: {
        async callText() {
          return JSON.stringify({
            verdict: 'no_image',
            reason: 'TEST_NO_IMAGE',
            confidence: 0.82,
            pedagogicalRole: 'concept_anchor',
            svg: null,
          });
        },
      },
      readJson: async (req) => req.body,
      sendJson: (res, status, body) => {
        res.writeHead(status, {'content-type': 'application/json'});
        res.end(JSON.stringify(body));
      },
    });
    const noImageRes = fakeResponse();
    await visualNoImage({
      auth: {authenticated: true, userId: 'u1'},
      body: {topic: 'visual decorativo sem função', hint: 'ambiguous'},
    }, noImageRes);
    assert.equal(noImageRes.status, 200);
    assert.equal(noImageRes.body.verdict, 'no_image');
    assert.equal(noImageRes.body.reason, 'TEST_NO_IMAGE');
    assert.equal(noImageRes.body.confidence, 0.82);

    const visualFallback = createVisualRouteController({
      config: {GEMINI_VISUAL_ROUTER_MODEL: 'test-lite'},
      gemini: {async callText() { throw new Error('provider down'); }},
      readJson: async (req) => req.body,
      sendJson: (res, status, body) => {
        res.writeHead(status, {'content-type': 'application/json'});
        res.end(JSON.stringify(body));
      },
    });
    const fallbackRes = fakeResponse();
    await visualFallback({
      auth: {authenticated: true, userId: 'u1'},
      body: {topic: 'ambiguous visual', hint: 'ambiguous'},
    }, fallbackRes);
    assert.equal(fallbackRes.status, 200);
    assert.equal(fallbackRes.body.verdict, 'ai');
    assert.equal(fallbackRes.body.reason, 'VISUAL_ROUTE_PROVIDER_FAILED');
    assert.equal(normalizeAspectRatio('portrait'), '1:1');
    assert.equal(normalizeAspectRatio('16:9'), '16:9');

    const noOffer = await request(port, '/api/generate-lesson-image', {
      method: 'POST',
      token: fakeToken(),
      requestId: 'req-image-no-offer',
      body: {
        prompt: 'Imagem didatica sobre funcao linear',
        lessonKey: 'lesson-image-1',
      },
    });
    assert.equal(noOffer.status, 409);
    assert.equal(noOffer.json.error, 'acceptedOfferId obrigatório para imagem paga');
    assert.equal(noOffer.json.requestId, 'req-image-no-offer');

    const credits = fakeCredits();
    let mediaCalls = 0;
    const controller = createImageController({
      config: {IMAGE_CREDIT_COST: 1, GEMINI_IMAGE_MODEL: 'test-image'},
      gemini: {
        async callMedia() {
          mediaCalls += 1;
          return {
            candidates: [{
              content: {
                parts: [{inlineData: {mimeType: 'image/png', data: 'AAAA'}}],
              },
            }],
          };
        },
      },
      credits,
      cache: new Map(),
      readJson: async (req) => req.body,
      sendJson: (res, status, body) => {
        res.writeHead(status, {'content-type': 'application/json'});
        res.end(JSON.stringify(body));
      },
      hashKey: (value) => `h${String(value).length}`,
      assertResourceOwner: () => {},
    });
    const imageReq = {
      auth: {authenticated: true, userId: 'u1'},
      headers: {'x-request-id': 'req-image-ok'},
      body: {
        prompt: 'Imagem didatica sobre funcao linear',
        lessonKey: 'lesson-image-1',
        acceptedOfferId: 'offer-123',
        idempotencyKey: 'offer-123',
      },
    };
    const imageRes = fakeResponse();
    await controller(imageReq, imageRes);
    assert.equal(imageRes.status, 200);
    assert.equal(imageRes.body.charged, true);
    assert.equal(mediaCalls, 1);
    assert.equal(credits.reserved, 1);
    assert.equal(credits.captured, 1);
    assert.equal(imageRes.body.aspect_ratio, '1:1');
    assert.equal(imageRes.body.image_data_url, imageRes.body.dataUrl);

    const replayRes = fakeResponse();
    await controller(imageReq, replayRes);
    assert.equal(replayRes.status, 200);
    assert.equal(Boolean(replayRes.body.idempotent_replay || replayRes.body.cache_hit), true);
    assert.equal(replayRes.body.charged, false);
    assert.equal(mediaCalls, 1);
    assert.equal(credits.reserved, 1);

    const failingCredits = fakeCredits();
    const failing = createImageController({
      config: {IMAGE_CREDIT_COST: 1, GEMINI_IMAGE_MODEL: 'test-image'},
      gemini: {async callMedia() { throw new Error('provider down secret-token'); }},
      credits: failingCredits,
      cache: new Map(),
      readJson: async (req) => req.body,
      sendJson: (res, status, body) => {
        res.writeHead(status, {'content-type': 'application/json'});
        res.end(JSON.stringify(body));
      },
      hashKey: (value) => `h${String(value).length}`,
      assertResourceOwner: () => {},
    });
    const failRes = fakeResponse();
    await failing({
      auth: {authenticated: true, userId: 'u1'},
      headers: {'x-request-id': 'req-image-fail'},
      body: {
        prompt: 'Imagem didatica sobre anatomia realista',
        lessonKey: 'lesson-image-2',
        acceptedOfferId: 'offer-456',
      },
    }, failRes);
    assert.equal(failRes.status, 502);
    assert.equal(failRes.body.refunded, true);
    assert.equal(failRes.body.charged, false);
    assert.equal(failRes.body.error, 'Não foi possível gerar a imagem da aula agora.');
    assert.equal(failingCredits.released, 1);

    const paidDisabled = fakeResponse();
    await controller({
      auth: {authenticated: true, userId: 'u1'},
      headers: {'x-request-id': 'req-paid-disabled'},
      body: {
        prompt: 'Imagem didatica sobre funcao linear',
        lessonKey: 'lesson-image-3',
        acceptedOfferId: 'offer-789',
        allow_paid: false,
      },
    }, paidDisabled);
    assert.equal(paidDisabled.status, 403);
    assert.equal(paidDisabled.body.error, 'paid_images_disabled');

    let transientCalls = 0;
    const retrying = createImageController({
      config: {IMAGE_CREDIT_COST: 1, GEMINI_IMAGE_MODEL: 'test-image'},
      gemini: {
        async callMedia() {
          transientCalls += 1;
          if (transientCalls === 1) {
            const e = new Error('temporary 503');
            e.statusCode = 503;
            throw e;
          }
          return {
            candidates: [{
              content: {parts: [{inlineData: {mimeType: 'image/png', data: 'BBBB'}}]},
            }],
          };
        },
      },
      credits: fakeCredits(),
      cache: new Map(),
      readJson: async (req) => req.body,
      sendJson: (res, status, body) => {
        res.writeHead(status, {'content-type': 'application/json'});
        res.end(JSON.stringify(body));
      },
      hashKey: (value) => `h${String(value).length}`,
      assertResourceOwner: () => {},
    });
    const retryImageRes = fakeResponse();
    await retrying({
      auth: {authenticated: true, userId: 'u2'},
      headers: {'x-request-id': 'req-image-retry'},
      body: {
        prompt: 'Imagem didatica sobre funcao quadratica',
        lessonKey: 'lesson-image-4',
        aspectRatio: 'portrait',
        acceptedOfferId: 'offer-retry',
      },
    }, retryImageRes);
    assert.equal(retryImageRes.status, 200);
    assert.equal(transientCalls, 2);
    assert.equal(retryImageRes.body.aspect_ratio, '1:1');

    assert.equal(voiceByLang('pt-BR'), 'Charon');
    assert.equal(voiceByLang('en-US'), 'Charon');
    assert.equal(voiceByLang('es'), 'Fenrir');

    const audioCredits = fakeCredits();
    let audioCalls = 0;
    let audioVoice = null;
    const audioController = createAudioController({
      config: {AUDIO_CREDIT_COST: 0, GEMINI_TTS_MODEL: 'test-tts'},
      gemini: {
        async callMedia(args) {
          audioCalls += 1;
          audioVoice = args.body.generationConfig.speechConfig.voiceConfig.prebuiltVoiceConfig.voiceName;
          return {
            candidates: [{
              content: {
                parts: [{inlineData: {mimeType: 'audio/wav', data: 'AAAA'}}],
              },
            }],
          };
        },
      },
      credits: audioCredits,
      cache: new Map(),
      readJson: async (req) => req.body,
      sendJson: (res, status, body) => {
        res.writeHead(status, {'content-type': 'application/json'});
        res.end(JSON.stringify(body));
      },
      hashKey: (value) => `h${String(value).length}`,
      assertResourceOwner: () => {},
    });
    const audioReq = {
      auth: {authenticated: true, userId: 'u1'},
      body: {
        text: 'Explique metade de forma curta.',
        lang: 'es',
        lessonKey: 'lesson-audio-1',
      },
    };
    const audioRes = fakeResponse();
    await audioController(audioReq, audioRes);
    assert.equal(audioRes.status, 200);
    assert.equal(audioRes.body.voice, 'Fenrir');
    assert.equal(audioVoice, 'Fenrir');
    assert.equal(audioCalls, 1);
    assert.equal(audioCredits.reserved, 0);
    assert.equal(audioCredits.captured, 0);
    assert.equal(audioRes.body.charged, false);

    const audioReplay = fakeResponse();
    await audioController(audioReq, audioReplay);
    assert.equal(audioReplay.status, 200);
    assert.equal(audioReplay.body.cache_hit, true);
    assert.equal(audioReplay.body.charged, false);
    assert.equal(audioCalls, 1);

    const longAudioController = createAudioController({
      config: {AUDIO_CREDIT_COST: 0, GEMINI_TTS_MODEL: 'test-tts', AUDIO_TEXT_MAX_CHARS: 16},
      gemini: {
        async callMedia(args) {
          assert(args.body.contents[0].parts[0].text.includes('Texto: 1234567890123456'));
          assert(!args.body.contents[0].parts[0].text.includes('7890EXTRA'));
          return {
            candidates: [{
              content: {parts: [{inlineData: {mimeType: 'audio/wav', data: 'AAAA'}}]},
            }],
          };
        },
      },
      credits: fakeCredits(),
      cache: new Map(),
      readJson: async (req) => req.body,
      sendJson: (res, status, body) => {
        res.writeHead(status, {'content-type': 'application/json'});
        res.end(JSON.stringify(body));
      },
      hashKey: (value) => `h${String(value).length}`,
      assertResourceOwner: () => {},
    });
    const longAudioRes = fakeResponse();
    await longAudioController({
      auth: {authenticated: true, userId: 'u3'},
      headers: {},
      body: {
        text: '12345678901234567890EXTRA',
        language: 'pt-BR',
        speed: 0.9,
        voice: 'Charon',
        lessonKey: 'lesson-audio-long',
      },
    }, longAudioRes);
    assert.equal(longAudioRes.status, 200);
    assert.equal(longAudioRes.body.language, 'pt-BR');
    assert.equal(longAudioRes.body.speed, 0.9);

    function multipartBody({filename, mime, data}) {
      const boundary = '----sim-boundary-test';
      const head = `--${boundary}
Content-Disposition: form-data; name="file"; filename="${filename}"
Content-Type: ${mime}

`;
      const tail = `
--${boundary}--
`;
      return {
        boundary,
        buffer: Buffer.concat([Buffer.from(head, 'utf8'), Buffer.from(data), Buffer.from(tail, 'utf8')]),
      };
    }
    const attachmentCalls = [];
    const attachmentProcessor = createAttachmentProcessor({
      readBody: async (req) => req.body,
      sendJson: (res, status, body) => {
        res.writeHead(status, {'content-type': 'application/json'});
        res.end(JSON.stringify(body));
      },
      gemini: {
        callText: async (input) => {
          attachmentCalls.push(input.inlineData.mimeType);
          return `conteudo extraido de ${input.inlineData.mimeType}`;
        },
      },
    });
    const imageMultipart = multipartBody({filename: 'foto.png', mime: 'image/png', data: Buffer.from([1, 2, 3])});
    const imageAttachmentRes = fakeResponse();
    await attachmentProcessor({headers: {'content-type': `multipart/form-data; boundary=${imageMultipart.boundary}`}, body: imageMultipart.buffer}, imageAttachmentRes);
    assert.equal(imageAttachmentRes.status, 200);
    assert.equal(imageAttachmentRes.body.attachment.kind, 'image');
    assert.equal(imageAttachmentRes.body.method, 'gemini-vision');
    const pdfMultipart = multipartBody({filename: 'lista.pdf', mime: 'application/pdf', data: Buffer.from('%PDF-1.4')});
    const pdfAttachmentRes = fakeResponse();
    await attachmentProcessor({headers: {'content-type': `multipart/form-data; boundary=${pdfMultipart.boundary}`}, body: pdfMultipart.buffer}, pdfAttachmentRes);
    assert.equal(pdfAttachmentRes.status, 200);
    assert.equal(pdfAttachmentRes.body.attachment.kind, 'pdf');
    assert.equal(pdfAttachmentRes.body.method, 'gemini-pdf');
    assert.deepEqual(attachmentCalls, ['image/png', 'application/pdf']);

    const store = createCreditsStore({
      TEST_CREDIT_EMAILS: new Set(),
      TEST_CREDIT_BALANCE: 999999,
    });
    store.getCreditAccount('u-credit').balance = 20;
    const r1 = store.reserveCredit('u-credit', 3, 'lesson', 'lesson-local-1');
    const r2 = store.reserveCredit('u-credit', 3, 'lesson', 'lesson-local-1');
    assert.equal(r1.reservationId, r2.reservationId);
    store.captureCredit('u-credit', r1.reservationId);
    const r3 = store.reserveCredit('u-credit', 3, 'lesson', 'lesson-local-1');
    assert.equal(r3.alreadyCaptured, true);
    assert.equal(store.getCreditAccount('u-credit').balance, 17);

    console.log('server contract tests passed');
  } finally {
    server.close();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

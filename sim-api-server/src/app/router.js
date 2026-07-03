const path = require('path');
const crypto = require('crypto');
const {loadEnv, readConfig} = require('../config/env');
const {loadPrompts} = require('../prompts/prompt-loader');
const {createHttpUtils} = require('../http/http-utils');
const {securityLog, requestLogger, clientIp} = require('../logs/request-logger');
const {createResourceOwners} = require('../security/resource-owners');
const {createJwtVerifier} = require('../auth/jwt-verifier');
const {createCreditsStore} = require('../credits/credits-store');
const {createCreditsController} = require('../credits/credits-controller');
const {createPaymentsController} = require('../payments/payments-controller');
const {createGeminiClient} = require('../ai/gemini-client');
const {createMediaCache} = require('./media-cache');
const {createHealthController} = require('../health/health-controller');
const {createBootstrapController} = require('../t00/bootstrap-controller');
const {createCompleteLessonController} = require('../t02/complete-lesson-controller');
const {createDoubtController} = require('../doubt/doubt-controller');
const {createReviewController} = require('../review/review-controller');
const {createRecoveryController} = require('../recovery/recovery-controller');
const {createImageController} = require('../media/image-controller');
const {createAudioController} = require('../media/audio-controller');
const {createVisualRouteController} = require('../media/visual-route-controller');
const {createAttachmentProcessor} = require('../attachments/attachment-processor');
const {createStudentStateController} = require('../student-state/student-state-controller');
const {createAccountDeletionController} = require('../account/account-deletion-controller');

loadEnv();
const config = readConfig();
const prompts = loadPrompts(config.ROOT);
const http = createHttpUtils(config);
const owners = createResourceOwners(config, securityLog);
const auth = createJwtVerifier(config, securityLog);
const credits = createCreditsStore(config);
const creditsController = createCreditsController({readJson: http.readJson, sendJson: http.sendJson, credits});
const paymentsController = createPaymentsController({config, readJson: http.readJson, sendJson: http.sendJson, credits});
const gemini = createGeminiClient(config);
const mediaCache = createMediaCache(config.MEDIA_CACHE_LIMIT);
const health = createHealthController({config, prompts, sendJson: http.sendJson});
const t00 = createBootstrapController({prompts, gemini, readJson: http.readJson, sendJson: http.sendJson, cors: http.cors, assertRequestResourceOwners: owners.assertRequestResourceOwners});
const t02 = createCompleteLessonController({gemini, prompts, readJson: http.readJson, sendJson: http.sendJson, assertRequestResourceOwners: owners.assertRequestResourceOwners, config});
const doubt = createDoubtController(t02);
const review = createReviewController(t02);
const recovery = createRecoveryController(t02);
const image = createImageController({config, gemini, credits, cache: mediaCache, readJson: http.readJson, sendJson: http.sendJson, hashKey: owners.hashKey, assertResourceOwner: owners.assertResourceOwner});
const audio = createAudioController({config, gemini, credits, cache: mediaCache, readJson: http.readJson, sendJson: http.sendJson, hashKey: owners.hashKey, assertResourceOwner: owners.assertResourceOwner});
const visualRoute = createVisualRouteController({config, gemini, readJson: http.readJson, sendJson: http.sendJson});
const attachments = createAttachmentProcessor({readBody: http.readBody, sendJson: http.sendJson, gemini});
const studentState = createStudentStateController({config, readJson: http.readJson, sendJson: http.sendJson, securityLog});
const accountDeletion = createAccountDeletionController({config, readJson: http.readJson, sendJson: http.sendJson, credits, studentState, securityLog});

function assertProductionConfig() {
  if (!config.IS_PRODUCTION) return;
  if (config.LAB_TRUST_SUPABASE_JWT_CLAIMS || (!config.SUPABASE_URL && !config.SUPABASE_JWT_SECRET)) {
    throw new Error('Production auth requires SUPABASE_URL/JWKS or SUPABASE_JWT_SECRET; LAB_TRUST_SUPABASE_JWT_CLAIMS cannot protect production.');
  }
}
assertProductionConfig();

function assertRateLimit(key, maxRequests, windowMs = config.RATE_LIMIT_WINDOW_MS) {
  router.buckets ||= new Map(); router.rateLimitRequests = (router.rateLimitRequests || 0) + 1; const now = Date.now();
  if (router.rateLimitRequests % 100 === 0) for (const [bucketKey, value] of router.buckets.entries()) if (now - value.start > 5 * windowMs) router.buckets.delete(bucketKey);
  const bucket = router.buckets.get(key) || {start: now, count: 0};
  if (now - bucket.start > windowMs) { bucket.start = now; bucket.count = 0; }
  bucket.count += 1; router.buckets.set(key, bucket); if (bucket.count > maxRequests) { const e = new Error('Too Many Requests'); e.statusCode = 429; e.retryAfter = Math.max(1, Math.ceil((bucket.start + windowMs - now) / 1000)); throw e; }
}
async function protect(req, url) {
  const protectedRoutes = {'/api/bootstrap-t00':'ai','/api/complete-lesson':'ai','/api/doubt':'ai','/api/review':'ai','/api/recovery':'ai','/api/visual-route':'ai','/api/generate-lesson-image':'image','/api/generate-lesson-audio':'audio','/api/process-attachment':'ai','/api/credits/me':'common','/api/credits/reserve':'common','/api/credits/capture':'common','/api/credits/refund':'common','/api/credits/transactions':'common','/api/payments/create-credits-checkout-hosted':'common','/api/payments/create-credits-checkout':'common','/api/payments/checkout-status':'common','/api/student-state/persist':'common','/api/student-state/list':'common','/api/student-state/summaries':'common','/api/student-state/get':'common','/api/student-state/delete':'common','/api/account/request-deletion':'common'};
  const routeClass = protectedRoutes[url.pathname]; if (!routeClass) return;
  req.auth = await auth.requireAuth(req); const max = routeClass === 'image' ? config.RATE_LIMIT_MEDIA_MAX_REQUESTS : routeClass === 'audio' ? Number(config.AUDIO_RATE_LIMIT_PER_MINUTE || 20) : config.RATE_LIMIT_AI_MAX_REQUESTS; assertRateLimit(`user:${routeClass}:${req.auth.userId}`, max, config.RATE_LIMIT_WINDOW_MS);
}
async function router(req, res) {
  requestLogger(req, res); res._corsHeaders = http.corsForRequest(req); const origin = String(req.headers.origin || '');
  const requestId = String(req.headers['x-request-id'] || crypto.randomUUID());
  res._requestId = requestId;
  const errorBody = (error) => requestId ? {error, requestId} : {error};
  if (origin && !http.isAllowedOrigin(origin)) return http.sendJson(res, 403, {error: 'Origin not allowed'});
  if (req.method === 'OPTIONS') { res.writeHead(200, http.cors({}, res)); return res.end(); }
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  try {
    assertRateLimit(`ip:${clientIp(req)}:${url.pathname}`, config.RATE_LIMIT_IP_MAX_REQUESTS, config.RATE_LIMIT_WINDOW_MS);
    if (req.method === 'GET' && (url.pathname === '/api/health' || url.pathname === '/health')) return health(req, res);
    if ((req.method === 'GET' || req.method === 'HEAD') && url.pathname === '/downloads/sim-production-latest.apk') return http.sendApkDownload(res, path.join(config.ROOT, 'downloads', 'sim-production-latest.apk'), req.method === 'HEAD');
    await protect(req, url); req.requireAuth = auth.requireAuth;
    if (req.method === 'POST' && url.pathname === '/api/bootstrap-t00') return t00(req, res);
    if (req.method === 'POST' && url.pathname === '/api/credits/me') return creditsController.me(req, res);
    if (req.method === 'POST' && url.pathname === '/api/credits/reserve') return creditsController.reserve(req, res);
    if (req.method === 'POST' && url.pathname === '/api/credits/capture') return creditsController.capture(req, res);
    if (req.method === 'POST' && url.pathname === '/api/credits/refund') return creditsController.refund(req, res);
    if (req.method === 'POST' && url.pathname === '/api/credits/transactions') return creditsController.transactions(req, res);
    if (req.method === 'POST' && url.pathname === '/api/payments/create-credits-checkout-hosted') return paymentsController.createHosted(req, res);
    if (req.method === 'POST' && url.pathname === '/api/payments/create-credits-checkout') return paymentsController.createEmbedded(req, res);
    if (req.method === 'POST' && url.pathname === '/api/payments/checkout-status') return paymentsController.checkoutStatus(req, res);
    if (req.method === 'POST' && url.pathname === '/api/student-state/persist') return studentState.persist(req, res);
    if (req.method === 'POST' && url.pathname === '/api/student-state/list') return studentState.list(req, res);
    if (req.method === 'POST' && url.pathname === '/api/student-state/summaries') return studentState.summaries(req, res);
    if (req.method === 'POST' && url.pathname === '/api/student-state/get') return studentState.get(req, res);
    if (req.method === 'POST' && url.pathname === '/api/student-state/delete') return studentState.remove(req, res);
    if (req.method === 'POST' && url.pathname === '/api/account/request-deletion') return accountDeletion.requestDeletion(req, res);
    if (req.method === 'POST' && url.pathname === '/api/process-attachment') return attachments(req, res);
    if (req.method === 'POST' && url.pathname === '/api/complete-lesson') return t02.handle(req, res, 'lesson');
    if (req.method === 'POST' && url.pathname === '/api/doubt') return doubt.handle(req, res);
    if (req.method === 'POST' && url.pathname === '/api/review') return review.handle(req, res);
    if (req.method === 'POST' && url.pathname === '/api/recovery') return recovery.handle(req, res);
    if (req.method === 'POST' && url.pathname === '/api/visual-route') return visualRoute(req, res);
    if (req.method === 'POST' && url.pathname === '/api/generate-lesson-image') return image(req, res);
    if (req.method === 'POST' && url.pathname === '/api/generate-lesson-audio') return audio(req, res);
    return http.sendJson(res, 404, {error: 'Not found'});
  } catch (error) {
    if (error?.statusCode === 401) return http.sendJson(res, 401, errorBody('Unauthorized'));
    if (error?.statusCode === 403) return http.sendJson(res, 403, errorBody('Forbidden'));
    if (error?.statusCode === 429) {
      if (error.retryAfter) res._extraHeaders = {...(res._extraHeaders || {}), 'Retry-After': String(error.retryAfter)};
      return http.sendJson(res, 429, errorBody('Too Many Requests'));
    }
    return http.sendJson(res, error.statusCode || 500, errorBody(error.message || String(error)));
  }
}
module.exports = {router, isGeminiConfigured: () => Boolean(config.GEMINI_API_KEY)};

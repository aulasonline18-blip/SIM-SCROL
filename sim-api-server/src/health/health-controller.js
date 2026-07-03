function createHealthController({config, prompts, sendJson}) {
  return function health(req, res) {
    if (config.IS_PRODUCTION) return sendJson(res, 200, {status: 'ok', service: 'sim-api'});
    sendJson(res, 200, {status: 'ok', service: 'sim-api', env: {geminiConfigured: Boolean(config.GEMINI_API_KEY), mediaCacheLimit: config.MEDIA_CACHE_LIMIT, rateLimitWindowMs: config.RATE_LIMIT_WINDOW_MS}, prompts: Object.fromEntries(Object.entries(prompts).map(([k, v]) => [k, v.length > 0])), auth: {jwt: Boolean(config.SUPABASE_URL || config.SUPABASE_JWT_SECRET), jwks: Boolean(config.SUPABASE_URL), hs256: Boolean(config.SUPABASE_JWT_SECRET), labTrustClaims: Boolean(config.LAB_TRUST_SUPABASE_JWT_CLAIMS)}});
  };
}
module.exports = {createHealthController};

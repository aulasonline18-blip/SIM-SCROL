const fs = require('fs');
const path = require('path');
const ROOT = path.resolve(__dirname, '..', '..');
function loadEnv(file = path.join(ROOT, '.env')) {
  if (!fs.existsSync(file)) return;
  for (const line of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    const clean = line.trim();
    if (!clean || clean.startsWith('#')) continue;
    const idx = clean.indexOf('=');
    if (idx <= 0) continue;
    const key = clean.slice(0, idx).trim();
    const value = clean.slice(idx + 1).trim().replace(/^[']|[']$/g, '');
    if (!(key in process.env)) process.env[key] = value;
  }
}
function readConfig() {
  const port = Number(process.env.PORT || 3000);
  const appMode = process.env.APP_MODE || process.env.NODE_ENV || 'development';
  const isProduction = appMode === 'production';
  return {
    ROOT, DATA_DIR: path.join(ROOT, '.data'), RESOURCE_OWNERS_FILE: path.join(ROOT, '.data', 'resource-owners.json'), PORT: port, APP_MODE: appMode, IS_PRODUCTION: isProduction,
    GEMINI_API_KEY: process.env.GEMINI_API_KEY || '', GEMINI_MODEL: process.env.GEMINI_MODEL || 'gemini-2.5-flash',
    GEMINI_TEXT_MODELS: Array.from(new Set([process.env.GEMINI_MODEL || 'gemini-2.5-flash', ...(process.env.GEMINI_FALLBACK_MODELS || 'gemini-2.5-flash,gemini-flash-latest').split(',').map((m) => m.trim()).filter(Boolean)])),
    GEMINI_IMAGE_MODEL: process.env.GEMINI_IMAGE_MODEL || 'gemini-3.1-flash-image', GEMINI_TTS_MODEL: process.env.GEMINI_TTS_MODEL || 'gemini-2.5-flash-preview-tts',
    GEMINI_VISUAL_ROUTER_MODEL: process.env.GEMINI_VISUAL_ROUTER_MODEL || 'gemini-2.5-flash-lite',
    IMAGE_CREDIT_COST: Number(process.env.IMAGE_CREDIT_COST || 10), AUDIO_CREDIT_COST: Number(process.env.AUDIO_CREDIT_COST || 0),
    TEST_CREDIT_EMAILS: new Set((process.env.TEST_CREDIT_EMAILS || '').split(',').map((e) => e.trim().toLowerCase()).filter(Boolean)), TEST_CREDIT_BALANCE: Number(process.env.TEST_CREDIT_BALANCE || 999999),
    MAX_BODY: 25 * 1024 * 1024, MEDIA_CACHE_LIMIT: Number(process.env.MEDIA_CACHE_LIMIT || 32),
    MAX_DOUBT_IMAGE_MB: Number(process.env.MAX_DOUBT_IMAGE_MB || 2),
    AUDIO_TEXT_MAX_CHARS: Number(process.env.AUDIO_TEXT_MAX_CHARS || 4096),
    SUPABASE_URL: (process.env.SUPABASE_URL || '').replace(/\/$/, ''), SUPABASE_ANON_KEY: process.env.SUPABASE_ANON_KEY || '', SUPABASE_JWT_SECRET: process.env.SUPABASE_JWT_SECRET || '', LAB_TRUST_SUPABASE_JWT_CLAIMS: isProduction ? String(process.env.LAB_TRUST_SUPABASE_JWT_CLAIMS || 'false').toLowerCase() === 'true' : String(process.env.LAB_TRUST_SUPABASE_JWT_CLAIMS || 'true').toLowerCase() !== 'false',
    STRIPE_SECRET_KEY: process.env.STRIPE_SECRET_KEY || '', STRIPE_SECRET_KEY_SANDBOX: process.env.STRIPE_SECRET_KEY_SANDBOX || '', STRIPE_SECRET_KEY_LIVE: process.env.STRIPE_SECRET_KEY_LIVE || '', STRIPE_API_BASE: process.env.STRIPE_API_BASE || 'https://api.stripe.com/v1',
    CORS_ALLOWED_ORIGINS: (process.env.CORS_ALLOWED_ORIGINS || ['http://localhost:3000', 'http://127.0.0.1:3000', 'https://gemini-aid-pal.lovable.app'].join(',')).split(',').map((o) => o.trim()).filter(Boolean),
    RATE_LIMIT_WINDOW_MS: Number(process.env.RATE_LIMIT_WINDOW_MS || 60 * 1000), RATE_LIMIT_IP_MAX_REQUESTS: Number(process.env.RATE_LIMIT_IP_MAX_REQUESTS || process.env.RATE_LIMIT_MAX_REQUESTS || 100), RATE_LIMIT_AI_MAX_REQUESTS: Number(process.env.RATE_LIMIT_AI_MAX_REQUESTS || 60), RATE_LIMIT_MEDIA_MAX_REQUESTS: Number(process.env.RATE_LIMIT_MEDIA_MAX_REQUESTS || 5),
  };
}
module.exports = {ROOT, loadEnv, readConfig};

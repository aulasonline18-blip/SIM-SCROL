const crypto = require('crypto');
const {fetchJson, fetchSupabaseUser} = require('./supabase-user');
function decodeBase64Url(input) { const n = String(input || '').replace(/-/g, '+').replace(/_/g, '/'); const p = n + '='.repeat((4 - (n.length % 4)) % 4); return Buffer.from(p, 'base64').toString('utf8'); }
function getBearerToken(req) { const auth = String(req.headers.authorization || ''); return auth.startsWith('Bearer ') ? auth.slice(7).trim() : ''; }
function decodeJwtParts(token) { const parts = String(token || '').split('.'); if (parts.length !== 3) throw new Error('JWT_MALFORMED'); return {header: JSON.parse(decodeBase64Url(parts[0])), payload: JSON.parse(decodeBase64Url(parts[1])), signingInput: `${parts[0]}.${parts[1]}`, signature: Buffer.from(parts[2].replace(/-/g, '+').replace(/_/g, '/'), 'base64')}; }
function normalizeEmail(v) { return String(v || '').trim().toLowerCase(); }
function extractAuthEmail(payload = {}) { return normalizeEmail(payload.email || payload.user_metadata?.email || payload.app_metadata?.email); }
function looksLikeUuid(v) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(String(v || '')); }
function createJwtVerifier(config, securityLog) {
  let jwksCache = {ts: 0, keys: []};
  async function getSupabaseJwks() { if (!config.SUPABASE_URL) return []; if (Date.now() - jwksCache.ts < 10 * 60 * 1000) return jwksCache.keys; const json = await fetchJson(`${config.SUPABASE_URL}/auth/v1/.well-known/jwks.json`); jwksCache = {ts: Date.now(), keys: json.keys || []}; return jwksCache.keys; }
  function verifyHs256(parts, secret) {
    const expected = crypto.createHmac('sha256', secret).update(parts.signingInput).digest();
    if (expected.length !== parts.signature.length) throw new Error('JWT_BAD_SIGNATURE_LENGTH');
    if (!crypto.timingSafeEqual(expected, parts.signature)) throw new Error('JWT_BAD_SIGNATURE');
  }
  async function verifyJwks(parts) { const keys = await getSupabaseJwks(); const jwk = keys.find((k) => k.kid === parts.header.kid); if (!jwk) throw new Error('JWT_KID_NOT_FOUND'); const key = crypto.createPublicKey({key: jwk, format: 'jwk'}); const ok = crypto.verify('RSA-SHA256', Buffer.from(parts.signingInput), key, parts.signature); if (!ok) throw new Error('JWT_BAD_SIGNATURE'); }
  async function verifySupabaseAuthServer(token, parts) { if (!config.SUPABASE_URL || !config.SUPABASE_ANON_KEY) return null; const user = await fetchSupabaseUser(config, token); if (!user?.id) return null; return {userId: String(user.id), email: normalizeEmail(user.email || extractAuthEmail(parts.payload)), authenticated: true, claims: parts.payload}; }
  function verifyLabSupabaseClaims(parts) { const p = parts.payload || {}; const sub = String(p.sub || p.user_id || ''); if (!looksLikeUuid(sub)) throw new Error('JWT_SUB_INVALID'); const exp = Number(p.exp || 0); if (exp && exp * 1000 < Date.now()) throw new Error('JWT_EXPIRED'); return {userId: sub, email: extractAuthEmail(p), authenticated: true, claims: p}; }
  async function requireAuth(req) {
    const token = getBearerToken(req);
    if (!token) { const e = new Error('Unauthorized'); e.statusCode = 401; throw e; }
    try {
      const parts = decodeJwtParts(token);
      const failures = [];
      let auth = null;
      const alg = String(parts.header.alg || '').toUpperCase();
      if (config.SUPABASE_JWT_SECRET && (!alg || alg.startsWith('HS'))) {
        try {
          verifyHs256(parts, config.SUPABASE_JWT_SECRET);
          auth = {userId: String(parts.payload.sub), email: extractAuthEmail(parts.payload), authenticated: true, claims: parts.payload};
        } catch (e) {
          failures.push(e.message);
        }
      }
      if (!auth && config.SUPABASE_URL) {
        try {
          await verifyJwks(parts);
          auth = {userId: String(parts.payload.sub), email: extractAuthEmail(parts.payload), authenticated: true, claims: parts.payload};
        } catch (e) {
          failures.push(e.message);
          try { auth = await verifySupabaseAuthServer(token, parts); }
          catch (serverError) { failures.push(serverError.message); auth = null; }
        }
      }
      if (!auth && config.LAB_TRUST_SUPABASE_JWT_CLAIMS && !config.SUPABASE_URL && !config.SUPABASE_JWT_SECRET) auth = verifyLabSupabaseClaims(parts);
      if (!auth?.userId) throw new Error(failures[0] || 'JWT_NO_USER');
      req.auth = auth;
      return auth;
    } catch (error) {
      securityLog('AUTH_FAILED', req, {reason: error.message});
      const e = new Error('Unauthorized');
      e.statusCode = 401;
      throw e;
    }
  }
  return {requireAuth, decodeJwtParts, getBearerToken, normalizeEmail, extractAuthEmail};
}
module.exports = {createJwtVerifier, decodeBase64Url, getBearerToken, normalizeEmail, extractAuthEmail};

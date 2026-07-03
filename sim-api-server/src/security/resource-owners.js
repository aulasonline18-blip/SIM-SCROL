const fs = require('fs');
const crypto = require('crypto');
function stableJson(value) { if (value === null || typeof value !== 'object') return JSON.stringify(value); if (Array.isArray(value)) return '[' + value.map(stableJson).join(',') + ']'; return '{' + Object.keys(value).sort().map((k) => JSON.stringify(k) + ':' + stableJson(value[k])).join(',') + '}'; }
function hashKey(value) { return crypto.createHash('sha256').update(String(value || '')).digest('hex').slice(0, 24); }
function normalizeResourceId(value) { return String(value || '').trim().slice(0, 240); }
function createResourceOwners(config, securityLog) {
  function empty() { return {lessons: {}, media: {}, attachments: {}, doubts: {}, credits: {}, snapshots: {}}; }
  function load() { try { if (!fs.existsSync(config.RESOURCE_OWNERS_FILE)) return empty(); const p = JSON.parse(fs.readFileSync(config.RESOURCE_OWNERS_FILE, 'utf8')); return {lessons: p.lessons || {}, media: p.media || {}, attachments: p.attachments || {}, doubts: p.doubts || {}, credits: p.credits || {}, snapshots: p.snapshots || {}}; } catch (e) { console.warn('[security]', JSON.stringify({type: 'RESOURCE_OWNER_LOAD_FAILED', ts: new Date().toISOString(), reason: e.message})); return empty(); } }
  const resourceOwners = load();
  function save() { fs.mkdirSync(config.DATA_DIR, {recursive: true}); const tmp = `${config.RESOURCE_OWNERS_FILE}.tmp`; fs.writeFileSync(tmp, JSON.stringify(resourceOwners, null, 2)); fs.renameSync(tmp, config.RESOURCE_OWNERS_FILE); }
  function bucket(kind) { if (!resourceOwners[kind]) resourceOwners[kind] = {}; return resourceOwners[kind]; }
  function assertResourceOwner(auth, kind, id, {create = false, metadata = {}} = {}) { const key = normalizeResourceId(id); if (!key) return; const b = bucket(kind); const owner = b[key]; if (!owner && create) { b[key] = {userId: auth.userId, createdAt: new Date().toISOString(), metadata}; save(); return; } if (owner && owner.userId !== auth.userId) { const err = new Error('Forbidden'); err.statusCode = 403; throw err; } }
  function lessonResourceId(data) { return normalizeResourceId(data?.lessonLocalId || data?.lessonId || data?.lessonKey || data?.cacheKey || data?.id); }
  function mediaResourceId(data, prefix) { return normalizeResourceId(data?.lessonKey || data?.cacheKey || [prefix, data?.lessonLocalId, data?.marker, data?.layer, data?.lang || data?.idioma || data?.stable_lang].filter(Boolean).join(':') || stableJson(data)); }
  function assertRequestResourceOwners(auth, data, kind) { if (kind === 'lesson' || kind === 'bootstrap-t00') { const id = lessonResourceId(data) || lessonResourceId(data?.ficha); if (id) assertResourceOwner(auth, 'lessons', id, {create: true, metadata: {kind}}); } if (kind === 'media') assertResourceOwner(auth, 'media', mediaResourceId(data, kind), {create: true, metadata: {kind}}); if (kind === 'doubt') { const id = normalizeResourceId(data?.doubtId || data?.requestId || data?.student_doubt); if (id) assertResourceOwner(auth, 'doubts', hashKey(id), {create: true, metadata: {lessonLocalId: lessonResourceId(data) || null}}); } }
  return {resourceOwners, saveResourceOwners: save, assertResourceOwner, assertRequestResourceOwners, stableJson, hashKey, normalizeResourceId, lessonResourceId, mediaResourceId};
}
module.exports = {createResourceOwners, stableJson, hashKey, normalizeResourceId};

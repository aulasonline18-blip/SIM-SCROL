const https = require('https');
function fetchJson(url) { return new Promise((resolve, reject) => { https.get(url, {timeout: 10000}, (r) => { let data = ''; r.on('data', (c) => data += c); r.on('end', () => { try { if (r.statusCode < 200 || r.statusCode >= 300) return reject(new Error(`HTTP ${r.statusCode}`)); resolve(JSON.parse(data || '{}')); } catch (e) { reject(e); } }); }).on('error', reject); }); }
async function fetchSupabaseUser(config, token) {
  if (!config.SUPABASE_URL || !config.SUPABASE_ANON_KEY) return null;
  return new Promise((resolve, reject) => { const req = https.request(`${config.SUPABASE_URL}/auth/v1/user`, {method: 'GET', headers: {apikey: config.SUPABASE_ANON_KEY, authorization: `Bearer ${token}`}, timeout: 10000}, (r) => { let data = ''; r.on('data', (c) => data += c); r.on('end', () => { try { if (r.statusCode < 200 || r.statusCode >= 300) return resolve(null); resolve(JSON.parse(data || '{}')); } catch (e) { reject(e); } }); }); req.on('timeout', () => req.destroy(new Error('Supabase user timeout'))); req.on('error', reject); req.end(); });
}
module.exports = {fetchJson, fetchSupabaseUser};

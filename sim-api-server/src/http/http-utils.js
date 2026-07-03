const fs = require('fs');
const path = require('path');
const {clientIp} = require('../logs/request-logger');
function createHttpUtils(config) {
  function isAllowedOrigin(origin) { return !origin || config.CORS_ALLOWED_ORIGINS.includes(origin); }
  function corsForRequest(req) { const origin = String(req.headers.origin || ''); const headers = {'access-control-allow-headers': 'Content-Type, Authorization, X-Request-Id', 'access-control-allow-methods': 'GET, POST, OPTIONS', vary: 'Origin'}; if (origin && isAllowedOrigin(origin)) headers['access-control-allow-origin'] = origin; return headers; }
  function cors(headers = {}, res = null) { return {...(res?._corsHeaders || {}), ...headers}; }
  function sendJson(res, status, body) { const requestId = String(res?._requestId || ''); const responseBody = status >= 400 && requestId && body && typeof body === 'object' && !Array.isArray(body) && !body.requestId ? {...body, requestId} : body; const requestHeaders = requestId ? {'X-Request-Id': requestId} : {}; res.writeHead(status, cors({'content-type': 'application/json; charset=utf-8', ...requestHeaders, ...(res?._extraHeaders || {})}, res)); res.end(JSON.stringify(responseBody)); }
  function sendApkDownload(res, file, head = false) { const stat = fs.statSync(file); res.writeHead(200, {'content-type': 'application/vnd.android.package-archive', 'content-length': stat.size, 'content-disposition': `attachment; filename=${path.basename(file)}`, 'cache-control': 'no-store'}); if (head) return res.end(); fs.createReadStream(file).pipe(res); }
  function readBody(req, maxBody = config.MAX_BODY) { return new Promise((resolve, reject) => { const chunks = []; let total = 0; req.on('data', (chunk) => { total += chunk.length; if (total > maxBody) reject(Object.assign(new Error('Payload too large'), {statusCode: 413})); else chunks.push(chunk); }); req.on('end', () => resolve(Buffer.concat(chunks))); req.on('error', reject); }); }
  async function readJson(req) { const buf = await readBody(req); if (!buf.length) return {}; return JSON.parse(buf.toString('utf8')); }
  return {clientIp, isAllowedOrigin, corsForRequest, cors, sendJson, sendApkDownload, readBody, readJson};
}
module.exports = {createHttpUtils};

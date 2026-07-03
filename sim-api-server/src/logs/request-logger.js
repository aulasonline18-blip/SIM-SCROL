function clientIp(req) { const forwarded = String(req?.headers?.['x-forwarded-for'] || '').split(',')[0].trim(); return forwarded || req?.socket?.remoteAddress || 'unknown'; }
function securityLog(type, req, details = {}) {
  const safe = {type, ts: new Date().toISOString(), path: req?.url || null, ip: clientIp(req), userId: req?.auth?.userId || details.userId || null, userAgent: req?.headers?.['user-agent'] || null, requestId: req?.headers?.['x-request-id'] || null, ...details};
  delete safe.token; delete safe.authorization; console.warn('[security]', JSON.stringify(safe));
}
function requestLogger(req, res) {
  const startedAt = Date.now();
  console.log('[REQUEST_START]', JSON.stringify({method: req.method, path: req.url, ip: clientIp(req), requestId: req?.headers?.['x-request-id'] || null}));
  if (res?.on) {
    res.on('finish', () => {
      console.log('[REQUEST_END]', JSON.stringify({method: req.method, path: req.url, status: res.statusCode, ms: Date.now() - startedAt, requestId: req?.headers?.['x-request-id'] || null}));
    });
  }
}
module.exports = {clientIp, securityLog, requestLogger};

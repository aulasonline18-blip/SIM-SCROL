function createCreditsController({readJson, sendJson, credits}) {
  function sendError(res, error) {
    sendJson(res, error.statusCode || 400, {error: error.message || String(error)});
  }

  async function me(req, res) {
    sendJson(res, 200, credits.creditSnapshot(req.auth));
  }

  async function reserve(req, res) {
    try {
      const data = await readJson(req);
      sendJson(res, 200, credits.reserveCredit(
        req.auth.userId,
        data.cost,
        String(data.reason || 'manual'),
        data.operationId,
        req.auth.email || '',
      ));
    } catch (error) {
      sendError(res, error);
    }
  }

  async function capture(req, res) {
    try {
      const data = await readJson(req);
      credits.captureCredit(req.auth.userId, data.reservationId);
      sendJson(res, 200, {ok: true});
    } catch (error) {
      sendError(res, error);
    }
  }

  async function refund(req, res) {
    try {
      const data = await readJson(req);
      credits.releaseCredit(req.auth.userId, data.reservationId);
      sendJson(res, 200, {ok: true});
    } catch (error) {
      sendError(res, error);
    }
  }

  async function transactions(req, res) {
    const account = credits.getCreditAccount(req.auth.userId, req.auth.email);
    sendJson(res, 200, {transactions: account.transactions || []});
  }

  return {me, reserve, capture, refund, transactions};
}
module.exports = {createCreditsController};

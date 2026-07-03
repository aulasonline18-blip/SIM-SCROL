const fs = require('fs');
const path = require('path');

function createAccountDeletionController({config, readJson, sendJson, credits, studentState, securityLog}) {
  const file = path.join(config.DATA_DIR, 'account-deletion-requests.json');

  function load() {
    try {
      if (!fs.existsSync(file)) return {requests: {}};
      const parsed = JSON.parse(fs.readFileSync(file, 'utf8'));
      return parsed && typeof parsed === 'object' ? {requests: parsed.requests || {}} : {requests: {}};
    } catch (_) {
      return {requests: {}};
    }
  }

  function save(data) {
    fs.mkdirSync(config.DATA_DIR, {recursive: true});
    const tmp = `${file}.tmp`;
    fs.writeFileSync(tmp, JSON.stringify(data, null, 2));
    fs.renameSync(tmp, file);
  }

  function sanitizeReason(value) {
    const clean = String(value || 'user_requested_account_deletion').trim();
    return clean.slice(0, 120) || 'user_requested_account_deletion';
  }

  async function requestDeletion(req, res) {
    const body = await readJson(req);
    if (String(body.confirmation || '').trim() !== 'DELETAR') {
      return sendJson(res, 400, {error: 'confirmation_required'});
    }
    const requestedUserId = String(body.userId || '').trim();
    if (requestedUserId && requestedUserId !== req.auth.userId) {
      securityLog('ACCOUNT_DELETION_USER_MISMATCH', req, {requestedUserId});
      return sendJson(res, 403, {error: 'forbidden_user'});
    }

    const now = new Date().toISOString();
    const reason = sanitizeReason(body.reason);
    const stateResult = studentState.deleteUserStates(req.auth.userId);
    const creditResult = credits.anonymizeAccountForDeletion(req.auth.userId, {
      email: req.auth.email || '',
      reason,
    });
    const data = load();
    data.requests[req.auth.userId] = {
      userId: req.auth.userId,
      emailHash: req.auth.email ? hashEmail(req.auth.email) : null,
      requestedAt: now,
      completedAt: now,
      reason,
      deletedLessons: stateResult.deletedLessons,
      credits: {
        hadAccount: creditResult.hadAccount,
        balanceBefore: creditResult.balanceBefore,
        transactionsPreserved: creditResult.transactionsPreserved,
      },
      status: 'completed',
    };
    save(data);
    securityLog('ACCOUNT_DELETION_COMPLETED', req, {
      deletedLessons: stateResult.deletedLessons,
      transactionsPreserved: creditResult.transactionsPreserved,
    });
    return sendJson(res, 200, {
      ok: true,
      status: 'completed',
      deletedLessons: stateResult.deletedLessons,
      transactionsPreserved: creditResult.transactionsPreserved,
      completedAt: now,
    });
  }

  return {requestDeletion};
}

function hashEmail(email) {
  const crypto = require('crypto');
  return crypto.createHash('sha256').update(String(email || '').trim().toLowerCase()).digest('hex');
}

module.exports = {createAccountDeletionController};

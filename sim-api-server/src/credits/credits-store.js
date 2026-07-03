const fs = require('fs');
const path = require('path');

function createCreditsStore(config) {
  const persistent = Boolean(config.DATA_DIR || config.ROOT);
  const root = config.ROOT || process.cwd();
  const file = persistent ? path.join(config.DATA_DIR || path.join(root, '.data'), 'credits-ledger.json') : null;
  const testCreditUserIds = new Set();
  let state = load();

  function load() {
    try {
      if (!file || !fs.existsSync(file)) return {accounts: {}};
      const parsed = JSON.parse(fs.readFileSync(file, 'utf8'));
      return parsed && typeof parsed === 'object' ? {accounts: parsed.accounts || {}} : {accounts: {}};
    } catch (_) {
      return {accounts: {}};
    }
  }

  function save() {
    if (!file) return;
    fs.mkdirSync(path.dirname(file), {recursive: true});
    const tmp = `${file}.tmp`;
    fs.writeFileSync(tmp, JSON.stringify(state, null, 2));
    fs.renameSync(tmp, file);
  }

  function hasTestCredits(email) {
    return config.TEST_CREDIT_EMAILS.has(String(email || '').toLowerCase());
  }

  function normalizeAccount(raw = {}, userId, email = '') {
    const testMode = hasTestCredits(email) || testCreditUserIds.has(userId);
    return {
      balance: Number.isFinite(Number(raw.balance)) ? Number(raw.balance) : testMode ? config.TEST_CREDIT_BALANCE : 0,
      reservations: raw.reservations && typeof raw.reservations === 'object' ? raw.reservations : {},
      transactions: Array.isArray(raw.transactions) ? raw.transactions : [],
      operationIndex: raw.operationIndex && typeof raw.operationIndex === 'object' ? raw.operationIndex : {},
      purchaseIndex: raw.purchaseIndex && typeof raw.purchaseIndex === 'object' ? raw.purchaseIndex : {},
    };
  }

  function getCreditAccount(userId, email = '') {
    const id = String(userId || '').trim();
    if (!id) throw Object.assign(new Error('userId obrigatorio'), {statusCode: 400});
    const account = normalizeAccount(state.accounts[id], id, email);
    state.accounts[id] = account;
    return {
      get balance() { return account.balance; },
      set balance(value) { account.balance = Number(value); save(); },
      get reservations() { return new Map(Object.entries(account.reservations)); },
      get transactions() { return account.transactions; },
      get operationIndex() { return new Map(Object.entries(account.operationIndex)); },
      _raw: account,
    };
  }

  function rawAccount(userId, email = '') {
    getCreditAccount(userId, email);
    return state.accounts[String(userId)];
  }

  function logCredit(event) {
    console.warn('[CREDITS]', JSON.stringify(event));
  }

  function assertPositiveCost(cost) {
    const n = Number(cost);
    if (!Number.isInteger(n) || n <= 0 || n > 1000000) {
      const e = new Error('cost deve ser inteiro positivo');
      e.statusCode = 400;
      throw e;
    }
    return n;
  }

  function reserveCredit(userId, cost, reason, operationId, email = '') {
    const positiveCost = assertPositiveCost(cost);
    const account = rawAccount(userId, email);
    const opKey = String(operationId || '').trim();
    if (!opKey) {
      const e = new Error('operationId obrigatorio');
      e.statusCode = 400;
      throw e;
    }
    const existing = account.operationIndex[opKey];
    if (existing?.reservationId && account.reservations[existing.reservationId]) {
      return {reservationId: existing.reservationId, balance: account.balance, idempotent: true};
    }
    if (existing?.captured) {
      return {reservationId: null, balance: account.balance, idempotent: true, alreadyCaptured: true};
    }
    if (account.balance < positiveCost) {
      const e = new Error('Creditos insuficientes.');
      e.statusCode = 402;
      throw e;
    }
    const before = account.balance;
    const reservationId = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
    account.balance -= positiveCost;
    account.reservations[reservationId] = {cost: positiveCost, reason, operationId: opKey, ts: Date.now()};
    account.operationIndex[opKey] = {reservationId, captured: false};
    logCredit({event: 'reserve', userId, cost: positiveCost, before, after: account.balance, operationId: opKey, reason});
    save();
    return {reservationId, balance: account.balance};
  }

  function captureCredit(userId, reservationId) {
    const id = String(reservationId || '').trim();
    if (!id) throw Object.assign(new Error('reservationId obrigatorio'), {statusCode: 400});
    const account = rawAccount(userId);
    const entry = account.reservations[id];
    if (!entry) throw Object.assign(new Error('reservationId inexistente'), {statusCode: 404});
    delete account.reservations[id];
    if (entry.operationId) account.operationIndex[entry.operationId] = {reservationId: id, captured: true};
    account.transactions.push({...entry, type: 'capture', reservationId: id});
    logCredit({event: 'capture', userId, cost: entry.cost, before: account.balance, after: account.balance, operationId: entry.operationId || null});
    save();
  }

  function releaseCredit(userId, reservationId) {
    const id = String(reservationId || '').trim();
    if (!id) throw Object.assign(new Error('reservationId obrigatorio'), {statusCode: 400});
    const account = rawAccount(userId);
    const entry = account.reservations[id];
    if (!entry) throw Object.assign(new Error('reservationId inexistente'), {statusCode: 404});
    const before = account.balance;
    account.balance += entry.cost;
    delete account.reservations[id];
    if (entry.operationId) delete account.operationIndex[entry.operationId];
    account.transactions.push({...entry, type: 'refund', reservationId: id});
    logCredit({event: 'refund', userId, cost: entry.cost, before, after: account.balance, operationId: entry.operationId || null});
    save();
  }

  function grantPurchasedCredits(userId, {sessionId, packId, credits, email = ''}) {
    const sid = String(sessionId || '').trim();
    const delta = Number(credits);
    if (!sid) throw Object.assign(new Error('sessionId obrigatorio'), {statusCode: 400});
    if (!Number.isInteger(delta) || delta <= 0) throw Object.assign(new Error('credits invalidos'), {statusCode: 400});
    const account = rawAccount(userId, email);
    const existing = account.purchaseIndex[sid];
    if (existing) return {balance: account.balance, credits: existing.credits, idempotent: true};
    const before = account.balance;
    account.balance += delta;
    account.purchaseIndex[sid] = {credits: delta, packId, ts: Date.now()};
    account.transactions.push({type: 'purchase', sessionId: sid, packId, credits: delta, before, after: account.balance, ts: Date.now()});
    logCredit({event: 'purchase', userId, credits: delta, before, after: account.balance, sessionId: sid, packId});
    save();
    return {balance: account.balance, credits: delta};
  }

  function creditSnapshot(auth) {
    const a = rawAccount(auth.userId, auth.email);
    return {
      userId: auth.userId,
      balance: a.balance,
      reservations: Object.keys(a.reservations).length,
      transactions: a.transactions.length,
      testCreditMode: hasTestCredits(auth.email) || testCreditUserIds.has(auth.userId),
    };
  }

  function anonymizeAccountForDeletion(userId, {email = '', reason = 'account_deletion'} = {}) {
    const id = String(userId || '').trim();
    if (!id) throw Object.assign(new Error('userId obrigatorio'), {statusCode: 400});
    const existing = state.accounts[id];
    if (!existing) {
      save();
      return {hadAccount: false, transactionsPreserved: 0, balanceBefore: 0};
    }
    const account = normalizeAccount(existing, id, email);
    const transactions = Array.isArray(account.transactions)
      ? account.transactions.map((tx) => ({
        type: tx.type,
        packId: tx.packId || undefined,
        credits: tx.credits,
        cost: tx.cost,
        reason: tx.reason,
        ts: tx.ts,
        retainedFor: 'financial_legal_obligation',
      }))
      : [];
    const balanceBefore = Number(account.balance || 0);
    state.accounts[id] = {
      deletedAt: Date.now(),
      deletionReason: reason,
      balance: 0,
      reservations: {},
      operationIndex: {},
      purchaseIndex: {},
      transactions,
    };
    logCredit({event: 'account_delete_anonymize', userId, balanceBefore, transactionsPreserved: transactions.length});
    save();
    return {hadAccount: true, transactionsPreserved: transactions.length, balanceBefore};
  }

  return {getCreditAccount, reserveCredit, captureCredit, releaseCredit, grantPurchasedCredits, creditSnapshot, anonymizeAccountForDeletion};
}

module.exports = {createCreditsStore};

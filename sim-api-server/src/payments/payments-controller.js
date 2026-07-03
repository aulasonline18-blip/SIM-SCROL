const {getCreditPackOrThrow, SIM_PRICING} = require('./pricing');

function createPaymentsController({config, readJson, sendJson, credits}) {
  const apiBase = config.STRIPE_API_BASE || 'https://api.stripe.com/v1';

  function stripeSecret(environment) {
    if (environment === 'live') return config.STRIPE_SECRET_KEY_LIVE || config.STRIPE_SECRET_KEY || '';
    return config.STRIPE_SECRET_KEY_SANDBOX || config.STRIPE_SECRET_KEY || '';
  }

  function configured(environment) {
    return Boolean(stripeSecret(environment));
  }

  function form(entries) {
    const body = new URLSearchParams();
    for (const [key, value] of Object.entries(entries)) {
      if (value !== undefined && value !== null && value !== '') body.set(key, String(value));
    }
    return body;
  }

  async function stripeGet(path, environment) {
    const secret = stripeSecret(environment);
    const response = await fetch(`${apiBase}${path}`, {
      method: 'GET',
      headers: {authorization: `Bearer ${secret}`},
    });
    const json = await response.json().catch(() => ({}));
    if (!response.ok) {
      const error = new Error(json?.error?.message || 'stripe_error');
      error.statusCode = response.status;
      throw error;
    }
    return json;
  }

  async function stripePost(path, environment, body) {
    const secret = stripeSecret(environment);
    const response = await fetch(`${apiBase}${path}`, {
      method: 'POST',
      headers: {
        authorization: `Bearer ${secret}`,
        'content-type': 'application/x-www-form-urlencoded',
      },
      body,
    });
    const json = await response.json().catch(() => ({}));
    if (!response.ok) {
      const error = new Error(json?.error?.message || 'stripe_error');
      error.statusCode = response.status;
      throw error;
    }
    return json;
  }

  async function resolvePrice(pack, environment) {
    const data = await stripeGet(`/prices?active=true&limit=1&lookup_keys[]=${encodeURIComponent(pack.lookupKey)}`, environment);
    const price = Array.isArray(data.data) ? data.data[0] : null;
    if (!price) throw Object.assign(new Error('price_not_found'), {statusCode: 502});
    if (String(price.currency || '').toLowerCase() !== SIM_PRICING.currency || Number(price.unit_amount) !== pack.amountCents) {
      throw Object.assign(new Error('price_mismatch'), {statusCode: 502});
    }
    return price.id;
  }

  function assertUrl(value, name) {
    const raw = String(value || '');
    if (!/^https?:\/\//i.test(raw)) throw Object.assign(new Error(`${name}_invalid`), {statusCode: 400});
    return raw;
  }

  async function createHosted(req, res) {
    const data = await readJson(req);
    const environment = data.environment === 'live' ? 'live' : 'sandbox';
    if (!configured(environment)) return sendJson(res, 200, {error: 'payments_not_configured'});
    const pack = getCreditPackOrThrow(data.packId);
    const price = await resolvePrice(pack, environment);
    const session = await stripePost('/checkout/sessions', environment, form({
      mode: 'payment',
      success_url: assertUrl(data.successUrl, 'successUrl'),
      cancel_url: assertUrl(data.cancelUrl, 'cancelUrl'),
      'line_items[0][price]': price,
      'line_items[0][quantity]': 1,
      customer_email: req.auth.email || undefined,
      'metadata[userId]': req.auth.userId,
      'metadata[packId]': pack.id,
      'metadata[credits]': pack.credits,
      'metadata[baseCurrency]': SIM_PRICING.currency,
    }));
    sendJson(res, 200, {url: session.url, sessionId: session.id});
  }

  async function createEmbedded(req, res) {
    const data = await readJson(req);
    const environment = data.environment === 'live' ? 'live' : 'sandbox';
    if (!configured(environment)) return sendJson(res, 200, {error: 'payments_not_configured'});
    const pack = getCreditPackOrThrow(data.packId);
    const price = await resolvePrice(pack, environment);
    const session = await stripePost('/checkout/sessions', environment, form({
      mode: 'payment',
      ui_mode: 'embedded',
      return_url: assertUrl(data.returnUrl, 'returnUrl'),
      'line_items[0][price]': price,
      'line_items[0][quantity]': 1,
      customer_email: req.auth.email || undefined,
      'metadata[userId]': req.auth.userId,
      'metadata[packId]': pack.id,
      'metadata[credits]': pack.credits,
      'metadata[baseCurrency]': SIM_PRICING.currency,
    }));
    sendJson(res, 200, {clientSecret: session.client_secret, sessionId: session.id});
  }

  async function checkoutStatus(req, res) {
    const data = await readJson(req);
    const sessionId = String(data.sessionId || '').trim();
    const environment = data.environment === 'live' ? 'live' : 'sandbox';
    if (!/^[a-zA-Z0-9_-]+$/.test(sessionId)) return sendJson(res, 400, {error: 'invalid_session_id'});
    if (!configured(environment)) return sendJson(res, 200, {error: 'payments_not_configured'});
    const session = await stripeGet(`/checkout/sessions/${encodeURIComponent(sessionId)}`, environment);
    if (session.metadata?.userId !== req.auth.userId) return sendJson(res, 403, {error: 'forbidden_session'});
    const pack = getCreditPackOrThrow(session.metadata?.packId);
    if (session.status === 'expired') return sendJson(res, 200, {status: 'expired'});
    if (session.status !== 'complete' || session.payment_status !== 'paid') return sendJson(res, 200, {status: 'pending'});
    const grant = credits.grantPurchasedCredits(req.auth.userId, {
      sessionId: session.id,
      packId: pack.id,
      credits: pack.credits,
      email: req.auth.email || '',
    });
    res._extraHeaders = {...(res._extraHeaders || {}), 'X-Credits-Balance': String(grant.balance)};
    sendJson(res, 200, {status: 'complete', credits: pack.credits, balance: grant.balance});
  }

  return {createHosted, createEmbedded, checkoutStatus};
}

module.exports = {createPaymentsController};

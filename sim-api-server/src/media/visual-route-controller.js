function sanitizeAndEncodeSvg(raw) {
  if (typeof raw !== 'string') return null;
  const svg = raw.trim();
  if (!svg || svg.length > 100000) return null;
  const lower = svg.toLowerCase();
  if (!lower.startsWith('<svg') || !lower.includes('</svg>')) return null;
  if (lower.includes('<script')) return null;
  if (/\son[a-z]+\s*=/.test(lower)) return null;
  if (/javascript\s*:/i.test(svg)) return null;
  if (/<foreignobject/i.test(lower)) return null;
  return `data:image/svg+xml;utf8,${encodeURIComponent(svg).replace(/'/g, '%27').replace(/"/g, '%22')}`;
}

function extractSvg(value) {
  const text = String(value || '');
  const match = text.match(/<svg[\s\S]*?<\/svg>/i);
  return match ? match[0] : '';
}

function parseRouterJson(raw) {
  const text = String(raw || '').trim();
  try {
    return JSON.parse(text);
  } catch (_) {
    const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
    if (fenced) {
      try {
        return JSON.parse(fenced[1]);
      } catch (_) {}
    }
  }
  return {};
}

function cleanInput(value, max = 1200) {
  return String(value || '').replace(/\s+/g, ' ').trim().slice(0, max);
}

function cleanList(value, maxItems = 8, maxItemChars = 80) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => cleanInput(item, maxItemChars))
    .filter(Boolean)
    .slice(0, maxItems);
}

function cleanN2(value) {
  if (!value || typeof value !== 'object') return {};
  return {
    verdict: cleanInput(value.verdict, 24),
    reason: cleanInput(value.reason, 80),
    matched: cleanList(value.matched, 10, 60),
    confidence: Number.isFinite(Number(value.confidence)) ? Number(value.confidence) : undefined,
    pedagogicalRole: cleanInput(value.pedagogicalRole || value.pedagogical_role, 60),
  };
}

function buildVisualRoutePayload(data) {
  return {
    contractVersion: cleanInput(data.contractVersion || data.contract_version, 60),
    topic: cleanInput(data.topic),
    visualType: cleanInput(data.visualType || data.visual_type, 120),
    imagePrompt: cleanInput(data.imagePrompt || data.image_prompt),
    hint: cleanInput(data.hint, 40),
    n2: cleanN2(data.n2),
    keyElements: cleanList(data.keyElements || data.key_elements, 12, 90),
    pedagogicalNeed: cleanInput(data.pedagogicalNeed || data.pedagogical_need, 60),
    highlightFocus: cleanInput(data.highlightFocus || data.highlight_focus, 160),
    complexity: cleanInput(data.complexity, 40),
    stableLang: cleanInput(data.stableLang || data.stable_lang || data.language || data.lang, 40),
  };
}

function createVisualRouteController({config, gemini, readJson, sendJson}) {
  const systemPrompt = [
    'You are the SIM N3 pedagogical visual judge.',
    'Your job is to save every honest software-drawable educational visual as SVG before paid AI is offered.',
    'Do not be lazy. Try hard to produce a clean didactic SVG when the visual is a diagram, graph, table, timeline, cycle, grammar structure, geometry, math, physics schematic, comparison, process flow, concept map, syntax tree, food chain, or simple circuit.',
    'Return ai only when the student truly needs photorealism, anatomy/photo detail, realistic people/objects/scenes, a physical map, artwork, or natural imagery.',
    'Return no_image when the visual would not help, would confuse, or would give away the answer without reasoning.',
    'Use the provided N2 decision, confidence, pedagogicalRole, keyElements, pedagogicalNeed, highlightFocus, complexity and stableLang.',
    'SVG rules: white background, viewBox, no scripts, no event handlers, no external hrefs, no foreignObject, minimal labels, readable on mobile, no long text blocks.',
    'Return strict JSON only: {"verdict":"svg|ai|no_image","reason":"short_code","confidence":0.0-1.0,"pedagogicalRole":"role_id","svg":"<svg ...>...</svg>|null"}.',
  ].join('\n');

  return async function handle(req, res) {
    if (!req.auth?.authenticated || !req.auth.userId) {
      return sendJson(res, 401, {error: 'Unauthorized'});
    }
    const data = await readJson(req);
    const payload = buildVisualRoutePayload(data);
    const bag = `${payload.topic} ${payload.visualType} ${payload.imagePrompt}`.trim();
    if (bag.length < 3) {
      return sendJson(res, 200, {
        verdict: 'ai',
        reason: 'VISUAL_ROUTE_EMPTY_INPUT',
        svgDataUrl: null,
        requestId: res?._requestId || undefined,
      });
    }

    const userPayload = JSON.stringify(payload);
    let raw;
    try {
      raw = await gemini.callText({
        model: config.GEMINI_VISUAL_ROUTER_MODEL,
        systemPrompt,
        userPayload,
        json: true,
        maxTokens: 4096,
        temperature: 0.1,
      });
    } catch (error) {
      return sendJson(res, 200, {
        verdict: 'ai',
        reason: 'VISUAL_ROUTE_PROVIDER_FAILED',
        svgDataUrl: null,
        requestId: res?._requestId || undefined,
        retryable: true,
      });
    }

    const parsed = parseRouterJson(raw);
    const rawVerdict = String(parsed.verdict || '').toLowerCase();
    const verdict = rawVerdict === 'svg' ? 'svg' : rawVerdict === 'no_image' ? 'no_image' : 'ai';
    const reason = cleanInput(parsed.reason || (verdict === 'svg' ? 'VISUAL_ROUTE_SVG' : verdict === 'no_image' ? 'VISUAL_ROUTE_NO_IMAGE' : 'VISUAL_ROUTE_AI'), 180);
    const confidence = Number.isFinite(Number(parsed.confidence)) ? Math.max(0, Math.min(1, Number(parsed.confidence))) : undefined;
    const pedagogicalRole = cleanInput(parsed.pedagogicalRole || parsed.pedagogical_role || payload.n2.pedagogicalRole, 80);
    if (verdict === 'no_image') {
      return sendJson(res, 200, {
        verdict: 'no_image',
        reason,
        svgDataUrl: null,
        requestId: res?._requestId || undefined,
        confidence,
        pedagogicalRole: pedagogicalRole || undefined,
      });
    }
    if (verdict !== 'svg') {
      return sendJson(res, 200, {
        verdict: 'ai',
        reason,
        svgDataUrl: null,
        requestId: res?._requestId || undefined,
        confidence,
        pedagogicalRole: pedagogicalRole || undefined,
      });
    }

    const svg = parsed.svg || parsed.svgData || extractSvg(raw);
    const svgDataUrl = sanitizeAndEncodeSvg(svg);
    if (!svgDataUrl) {
      return sendJson(res, 200, {
        verdict: 'ai',
        reason: 'VISUAL_ROUTE_SVG_INVALID',
        svgDataUrl: null,
        requestId: res?._requestId || undefined,
        confidence,
        pedagogicalRole: pedagogicalRole || undefined,
      });
    }
    return sendJson(res, 200, {
      verdict: 'svg',
      reason,
      svgDataUrl,
      requestId: res?._requestId || undefined,
      confidence,
      pedagogicalRole: pedagogicalRole || undefined,
    });
  };
}

module.exports = {createVisualRouteController, sanitizeAndEncodeSvg, buildVisualRoutePayload};

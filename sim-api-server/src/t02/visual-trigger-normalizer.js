function normalizePedagogicalNeed(value) {
  const v = String(value || '').toLowerCase();
  return ['none', 'helpful', 'important', 'essential'].includes(v) ? v : null;
}

function normalizeRenderStrategy(value) {
  const v = String(value || '').toLowerCase();
  return ['software', 'ai'].includes(v) ? v : null;
}

function normalizeVisualType(value) {
  const v = String(value || '').toLowerCase();
  return [
    'none',
    'diagram',
    'process',
    'flowchart',
    'comparison',
    'spatial',
    'anatomy',
    'geometry',
    'graph',
    'map',
    'structure',
    'timeline',
    'table',
    'cycle',
    'circuit',
    'force',
    'syntax_tree',
    'food_chain',
    'concept_map',
    'experiment',
  ].includes(v) ? v : null;
}

function normalizeComplexity(value) {
  const v = String(value || '').toLowerCase();
  return ['simple', 'moderate', 'technical'].includes(v) ? v : null;
}

function stringList(value) {
  return Array.isArray(value) ? value.map((x) => String(x || '').trim()).filter(Boolean).slice(0, 12) : undefined;
}

function normalizeVisualTrigger(value) {
  if (value == null) return null;
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const vt = value;
  const needsImage = vt.needs_image === true || vt.needsImage === true;
  const result = {needs_image: needsImage};
  const pedagogicalNeed = normalizePedagogicalNeed(vt.pedagogical_need ?? vt.pedagogicalNeed);
  const renderStrategy = normalizeRenderStrategy(vt.render_strategy ?? vt.renderStrategy);
  const visualType = normalizeVisualType(vt.visual_type ?? vt.visualType);
  const complexity = normalizeComplexity(vt.complexity);
  if (pedagogicalNeed) result.pedagogical_need = pedagogicalNeed;
  if (renderStrategy) result.render_strategy = renderStrategy;
  if (visualType) result.visual_type = visualType;
  if (complexity) result.complexity = complexity;
  for (const [from, to] of [['topic', 'topic'], ['image_prompt', 'image_prompt'], ['teacher_prompt', 'image_prompt'], ['prompt', 'image_prompt'], ['highlight_focus', 'highlight_focus'], ['svg_payload', 'svg_payload']]) {
    const raw = vt[from];
    if (typeof raw === 'string' && raw.trim()) result[to] = raw.trim().slice(0, to === 'svg_payload' ? 100000 : 4000);
  }
  const keyElements = stringList(vt.key_elements ?? vt.keyElements);
  if (keyElements?.length) result.key_elements = keyElements;
  if (Array.isArray(vt.color_legend)) result.color_legend = vt.color_legend.slice(0, 8);
  if (vt.math_template && typeof vt.math_template === 'object' && !Array.isArray(vt.math_template)) result.math_template = vt.math_template;
  return result;
}

module.exports = {normalizeVisualTrigger, normalizePedagogicalNeed, normalizeComplexity, normalizeRenderStrategy, normalizeVisualType};

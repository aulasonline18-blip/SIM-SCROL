const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
function readPrompt(root, name) {
  const file = path.join(root, 'prompts', name);
  if (!fs.existsSync(file)) throw new Error(`Prompt ausente: ${name}`);
  return fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '');
}
function readOptionalPrompt(root, name) {
  const file = path.join(root, 'prompts', name);
  if (!fs.existsSync(file)) { console.warn(`[PROMPTS] adendo ausente: ${name}`); return null; }
  return fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '');
}
function sha1(text) { return crypto.createHash('sha1').update(String(text || '')).digest('hex'); }
function loadPrompts(root) {
  const prompts = {t00: readPrompt(root, 't00.txt'), t02: readPrompt(root, 't02.txt'), doubt: readOptionalPrompt(root, 'adendo_doubt.txt'), review: readOptionalPrompt(root, 'adendo_revision.txt'), recovery: readOptionalPrompt(root, 'adendo_recovery.txt'), supportT00: readOptionalPrompt(root, 'adendo_amparo_t00.txt'), supportT02: readOptionalPrompt(root, 'adendo_amparo_t02.txt')};
  prompts.sha = {t00: sha1(prompts.t00), t02: sha1(prompts.t02), doubt: sha1(prompts.doubt || ''), review: sha1(prompts.review || ''), recovery: sha1(prompts.recovery || ''), supportT00: sha1(prompts.supportT00 || ''), supportT02: sha1(prompts.supportT02 || '')};
  console.log('[PROMPTS_LOADED]', JSON.stringify({t00_sha: prompts.sha.t00, t02_sha: prompts.sha.t02, chars: {t00: prompts.t00.length, t02: prompts.t02.length}}));
  return prompts;
}
module.exports = {loadPrompts, readPrompt, readOptionalPrompt, sha1};

const fs = require('fs');
const path = require('path');

function createStudentStateController({config, readJson, sendJson, securityLog}) {
  const file = path.join(config.DATA_DIR, 'student-states.json');

  function load() {
    try {
      if (!fs.existsSync(file)) return {users: {}};
      const parsed = JSON.parse(fs.readFileSync(file, 'utf8'));
      return parsed && typeof parsed === 'object' ? parsed : {users: {}};
    } catch (error) {
      return {users: {}};
    }
  }

  function save(data) {
    fs.mkdirSync(config.DATA_DIR, {recursive: true});
    const tmp = `${file}.tmp`;
    fs.writeFileSync(tmp, JSON.stringify(data, null, 2));
    fs.renameSync(tmp, file);
  }

  function deleteUserStates(userId) {
    const data = load();
    const id = String(userId || '').trim();
    const existing = data.users?.[id] || {};
    const deletedLessons = Object.keys(existing).length;
    if (data.users) delete data.users[id];
    save(data);
    return {deletedLessons};
  }

  function userBag(data, userId) {
    data.users ||= {};
    data.users[userId] ||= {};
    return data.users[userId];
  }

  function safeLessonLocalId(value) {
    const id = String(value || '').trim();
    if (id.length < 2 || id.length > 160) {
      const e = new Error('lessonLocalId obrigatorio');
      e.statusCode = 400;
      throw e;
    }
    return id;
  }

  function highWaterMarkOf(state) {
    const progress = state?.progress || {};
    const layer = Number(progress.layer || state?.current?.layer || 1);
    return Number(progress.mainAdvances || 0) * 1000 +
      Number(progress.itemIdx || state?.current?.itemIdx || 0) * 10 +
      layer;
  }

  function summary(lessonLocalId, row) {
    const state = row.state || {};
    const profile = state.profile || {};
    const curriculum = state.curriculum || {};
    const progress = state.progress || {};
    const current = state.current || {};
    const items = Array.isArray(curriculum.items) ? curriculum.items : [];
    const itemIdx = Number(progress.itemIdx ?? current.itemIdx ?? 0);
    return {
      lessonLocalId,
      lessonCloudId: state.lessonCloudId || null,
      tema: profile.objetivo || curriculum.topic || 'Aula SIM',
      idioma: profile.language || profile.stableLang || '',
      nivel: profile.nivel || profile.academicLevel || 'incerto',
      createdAt: state.createdAt ? new Date(Number(state.createdAt)).toISOString() : null,
      updatedAt: row.updatedAt || null,
      totalItens: Math.max(items.length, Number(progress.totalItems || 0)),
      itemIdx: itemIdx < 0 ? 0 : itemIdx,
      layer: Number(progress.layer || current.layer || 1),
      concluidos: Math.max(Number(progress.mainAdvances || 0), Array.isArray(progress.concluidos) ? progress.concluidos.length : 0),
      finalizada: state.extra?.finalizada === true || state.finalizada === true,
      markerAtual: current.marker || items[itemIdx]?.marker || null,
      deleted: Boolean(state.deletedAt || state.syncInfo?.deletedAt || state.deletedAt),
    };
  }

  async function persist(req, res) {
    const body = await readJson(req);
    const lessonLocalId = safeLessonLocalId(body.lessonLocalId);
    const state = body.state;
    if (!state || typeof state !== 'object') return sendJson(res, 400, {error: 'state obrigatorio'});
    const clientScore = Number(body.clientScore ?? highWaterMarkOf(state));
    const clientUpdatedAt = Number(body.clientUpdatedAt ?? state.updatedAt ?? Date.now());
    const data = load();
    const bag = userBag(data, req.auth.userId);
    const existing = bag[lessonLocalId];
    if (existing && Number(existing.highWaterMark || 0) > clientScore) {
      securityLog('STUDENT_STATE_REGRESSION_REJECTED', req, {lessonLocalId});
      return sendJson(res, 409, {
        rejected: true,
        remoteState: existing.state,
        remoteHighWaterMark: Number(existing.highWaterMark || 0),
        remoteUpdatedAt: existing.updatedAt || null,
      });
    }
    const updatedAt = new Date(Math.max(clientUpdatedAt, Date.now())).toISOString();
    bag[lessonLocalId] = {
      lessonLocalId,
      state: {...state, lessonLocalId, userId: state.userId || req.auth.userId},
      highWaterMark: clientScore,
      schemaVersion: Number(body.schemaVersion || state.stateVersion || 1),
      updatedAt,
    };
    save(data);
    securityLog('STUDENT_STATE_PERSISTED', req, {lessonLocalId});
    return sendJson(res, 200, {
      lessonLocalId,
      highWaterMark: clientScore,
      schemaVersion: bag[lessonLocalId].schemaVersion,
      updatedAt,
    });
  }

  async function get(req, res) {
    const body = await readJson(req);
    const lessonLocalId = safeLessonLocalId(body.lessonLocalId);
    const row = userBag(load(), req.auth.userId)[lessonLocalId];
    return sendJson(res, 200, row || {state: null});
  }

  async function list(req, res) {
    const rows = Object.values(userBag(load(), req.auth.userId));
    return sendJson(res, 200, {rows});
  }

  async function summaries(req, res) {
    const bag = userBag(load(), req.auth.userId);
    return sendJson(res, 200, {
      rows: Object.entries(bag).map(([lessonLocalId, row]) => summary(lessonLocalId, row)),
    });
  }

  async function remove(req, res) {
    const body = await readJson(req);
    const lessonLocalId = safeLessonLocalId(body.lessonLocalId);
    const data = load();
    const bag = userBag(data, req.auth.userId);
    const existing = bag[lessonLocalId];
    const now = Date.now();
    bag[lessonLocalId] = {
      ...(existing || {lessonLocalId, state: {lessonLocalId}}),
      state: {
        ...((existing && existing.state) || {lessonLocalId}),
        deletedAt: now,
        syncInfo: {
          ...(((existing && existing.state && existing.state.syncInfo) || {})),
          deletedAt: now,
          operation: 'tombstone',
        },
      },
      highWaterMark: Math.max(Number(existing?.highWaterMark || 0), now),
      updatedAt: new Date(now).toISOString(),
    };
    save(data);
    securityLog('STUDENT_STATE_TOMBSTONED', req, {lessonLocalId});
    return sendJson(res, 200, {ok: true, lessonLocalId, deletedAt: now});
  }

  return {persist, get, list, summaries, remove, deleteUserStates};
}

module.exports = {createStudentStateController};

function createMediaCache(limit = 12) { const map = new Map(); return {get: (k) => map.get(k), set: (k, v) => { if (map.has(k)) map.delete(k); map.set(k, v); while (map.size > limit) map.delete(map.keys().next().value); }, size: () => map.size}; }
module.exports = {createMediaCache};

// Bulk Exercises API
// Returns the full exercise library (or a filtered/searched subset).
//
// Query params (all optional):
//   q            substring match against name (case-insensitive)
//   muscle       filter by primary muscle (e.g. 'chest', 'biceps')
//   equipment    filter by equipment (e.g. 'barbell', 'body only')
//   category     filter by category (e.g. 'strength', 'cardio')
//   level        filter by level ('beginner', 'intermediate', 'expert')
//   limit        max results (default 50, max 1000)
//   offset       pagination offset (default 0)
//
// Response:
//   { total: number, count: number, exercises: [...] }

const fs = require('fs');
const path = require('path');
const { applyCors } = require('../lib/security');

let _localDB = null;
function loadLocalDB() {
  if (_localDB) return _localDB;
  try {
    const p = path.join(process.cwd(), 'data', 'exercises.json');
    _localDB = JSON.parse(fs.readFileSync(p, 'utf8'));
  } catch (e) {
    console.error('Failed to load local exercises.json:', e.message);
    _localDB = [];
  }
  return _localDB;
}

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'GET, OPTIONS' })) return;

  const db = loadLocalDB();

  const q          = lower(req.query.q);
  const muscle     = lower(req.query.muscle);
  const equipment  = lower(req.query.equipment);
  const category   = lower(req.query.category);
  const level      = lower(req.query.level);
  const limit      = clamp(parseInt(req.query.limit, 10) || 50, 1, 1000);
  const offset     = Math.max(0, parseInt(req.query.offset, 10) || 0);

  let filtered = db;

  if (muscle) {
    filtered = filtered.filter(ex =>
      (ex.primaryMuscles || []).some(m => lower(m) === muscle) ||
      (ex.secondaryMuscles || []).some(m => lower(m) === muscle)
    );
  }
  if (equipment) {
    filtered = filtered.filter(ex => lower(ex.equipment) === equipment);
  }
  if (category) {
    filtered = filtered.filter(ex => lower(ex.category) === category);
  }
  if (level) {
    filtered = filtered.filter(ex => lower(ex.level) === level);
  }
  if (q) {
    filtered = filtered.filter(ex => lower(ex.name).includes(q));
  }

  const total = filtered.length;
  const page = filtered.slice(offset, offset + limit);

  res.setHeader('Cache-Control', 's-maxage=86400, stale-while-revalidate=604800');
  return res.status(200).json({
    total,
    count: page.length,
    offset,
    limit,
    exercises: page,
  });
};

function lower(v) { return (v || '').toString().toLowerCase().trim(); }
function clamp(n, lo, hi) { return Math.max(lo, Math.min(hi, n)); }

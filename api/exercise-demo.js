// Exercise Demo API
// Primary source: local /data/exercises.json (873 exercises, free-exercise-db)
// Fallback: RapidAPI ExerciseDB (only if EXERCISEDB_API_KEY is set AND local lookup fails)
//
// Returns a normalized exercise record:
//   { name, gifUrl, target, bodyPart, equipment, secondaryMuscles, instructions }

const fs = require('fs');
const path = require('path');

const RAPIDAPI_KEY = process.env.EXERCISEDB_API_KEY;
const RAPIDAPI_BASE = 'https://exercisedb.p.rapidapi.com';

// Lazy-load + cache the local DB across warm invocations
let _localDB = null;
function loadLocalDB() {
  if (_localDB) return _localDB;
  try {
    const p = path.join(process.cwd(), 'data', 'exercises.json');
    const raw = fs.readFileSync(p, 'utf8');
    _localDB = JSON.parse(raw);
  } catch (e) {
    console.error('Failed to load local exercises.json:', e.message);
    _localDB = [];
  }
  return _localDB;
}

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();

  const name = (req.query.name || '').trim().toLowerCase();
  if (!name) {
    return res.status(400).json({ error: 'Missing exercise name' });
  }

  // 1) Try local DB first (fast, free, always works)
  const local = lookupLocal(name);
  if (local) {
    res.setHeader('X-Source', 'local');
    res.setHeader('Cache-Control', 's-maxage=86400, stale-while-revalidate=604800');
    return res.status(200).json(local);
  }

  // 2) Fall back to RapidAPI if a key is configured
  if (RAPIDAPI_KEY) {
    try {
      const rapid = await lookupRapidAPI(name);
      if (rapid) {
        res.setHeader('X-Source', 'rapidapi');
        res.setHeader('Cache-Control', 's-maxage=86400');
        return res.status(200).json(rapid);
      }
    } catch (err) {
      console.error('RapidAPI lookup failed:', err.message);
    }
  }

  return res.status(404).json({ error: 'Exercise not found', query: name });
};

// ─────────────────────────────────────────────────────────────
// Local lookup (fuzzy match against bundled JSON)
// ─────────────────────────────────────────────────────────────
// Words too generic to count toward a fuzzy match
const STOP_WORDS = new Set(['exercise', 'workout', 'movement', 'the', 'a', 'an', 'and', 'or', 'with']);

function lookupLocal(query) {
  const db = loadLocalDB();
  if (!db.length) return null;

  const q = normalize(query);
  const qWords = q.split(/\s+/).filter(Boolean);
  // Score-eligible words: skip stop words and very short words
  const scoreWords = qWords.filter(w => w.length >= 3 && !STOP_WORDS.has(w));
  if (!scoreWords.length) return null;

  // Max possible score from word overlap (used to compute a min threshold)
  const maxWordScore = scoreWords.reduce((s, w) => s + w.length, 0);
  const MIN_RATIO = 0.5; // require at least half the query's meaningful chars to match

  let best = null;
  let bestScore = 0;

  for (const ex of db) {
    const eName = normalize(ex.name);

    // Exact match wins immediately
    if (eName === q) return formatLocal(ex);

    let score = 0;
    let wordsMatched = 0;
    for (const w of scoreWords) {
      if (eName.includes(w)) { score += w.length; wordsMatched++; }
    }
    // Big bonus for matching ALL query words (better than partial)
    if (wordsMatched === scoreWords.length) score += 20;
    // Smaller bonus when the result starts with the query's first scoring word
    if (scoreWords[0] && eName.startsWith(scoreWords[0])) score += 3;
    // Prefer shorter (more specific) names when scores are otherwise equal
    score -= Math.floor(eName.length / 30);

    if (score > bestScore) {
      bestScore = score;
      best = ex;
    }
  }

  // Reject low-confidence matches so garbage queries return 404
  if (!best || bestScore < maxWordScore * MIN_RATIO) return null;
  return formatLocal(best);
}

function formatLocal(ex) {
  const primary = (ex.primaryMuscles && ex.primaryMuscles[0]) || '';
  return {
    name: ex.name,
    gifUrl: (ex.images && ex.images[0]) || '',          // first frame as static "demo"
    images: ex.images || [],                            // full frame list (web can animate)
    target: primary,
    bodyPart: primary,                                  // map for back-compat with old shape
    equipment: ex.equipment,
    secondaryMuscles: ex.secondaryMuscles || [],
    instructions: ex.instructions || [],
    level: ex.level,
    force: ex.force,
    mechanic: ex.mechanic,
    category: ex.category,
    source: 'local',
  };
}

function normalize(s) {
  return (s || '').toLowerCase().replace(/[^a-z0-9 ]/g, ' ').replace(/\s+/g, ' ').trim();
}

// ─────────────────────────────────────────────────────────────
// RapidAPI fallback (legacy path, only if EXERCISEDB_API_KEY set)
// ─────────────────────────────────────────────────────────────
async function lookupRapidAPI(name) {
  const url = `${RAPIDAPI_BASE}/api/v1/exercises/name/${encodeURIComponent(name)}?limit=10&offset=0`;
  const resp = await fetch(url, {
    headers: {
      'x-rapidapi-key': RAPIDAPI_KEY,
      'x-rapidapi-host': 'exercisedb.p.rapidapi.com',
    },
  });
  if (!resp.ok) return null;
  const data = await resp.json();
  if (!data || !data.length) return null;
  const match = findBestMatch(name, data) || data[0];
  return {
    name: match.name,
    gifUrl: match.gifUrl,
    images: match.gifUrl ? [match.gifUrl] : [],
    target: match.target,
    bodyPart: match.bodyPart,
    equipment: match.equipment,
    secondaryMuscles: match.secondaryMuscles || [],
    instructions: match.instructions || [],
    source: 'rapidapi',
  };
}

function findBestMatch(query, exercises) {
  const q = normalize(query);
  const qWords = q.split(/\s+/);
  let best = null, bestScore = -1;
  for (const ex of exercises) {
    const eName = normalize(ex.name);
    if (eName === q) return ex;
    let score = 0;
    for (const w of qWords) if (eName.includes(w)) score += w.length;
    if (eName.startsWith(qWords[0])) score += 5;
    if (score > bestScore) { bestScore = score; best = ex; }
  }
  return best;
}

// Exercise Demo API — proxies to ExerciseDB on RapidAPI
// Returns animated GIF URL + muscle targets for a given exercise name

const RAPIDAPI_KEY = process.env.EXERCISEDB_API_KEY;
const BASE_URL = 'https://exercisedb.p.rapidapi.com';

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();

  const name = (req.query.name || '').trim().toLowerCase();
  if (!name) {
    return res.status(400).json({ error: 'Missing exercise name' });
  }

  if (!RAPIDAPI_KEY) {
    return res.status(500).json({ error: 'Missing EXERCISEDB_API_KEY env var' });
  }

  try {
    // Search by exercise name
    const url = `${BASE_URL}/api/v1/exercises/name/${encodeURIComponent(name)}?limit=5&offset=0`;
    const resp = await fetch(url, {
      headers: {
        'x-rapidapi-key': RAPIDAPI_KEY,
        'x-rapidapi-host': 'exercisedb.p.rapidapi.com'
      }
    });

    if (!resp.ok) {
      // If exact search fails, try partial match
      const partialUrl = `${BASE_URL}/api/v1/exercises/name/${encodeURIComponent(name.split(' ')[0])}?limit=10&offset=0`;
      const partialResp = await fetch(partialUrl, {
        headers: {
          'x-rapidapi-key': RAPIDAPI_KEY,
          'x-rapidapi-host': 'exercisedb.p.rapidapi.com'
        }
      });
      if (!partialResp.ok) {
        return res.status(404).json({ error: 'Exercise not found' });
      }
      const partialData = await partialResp.json();
      const match = findBestMatch(name, partialData);
      if (match) {
        return res.status(200).json(formatExercise(match));
      }
      return res.status(404).json({ error: 'Exercise not found' });
    }

    const data = await resp.json();
    if (!data || data.length === 0) {
      // Try first word as fallback
      const firstWord = name.split(' ')[0];
      if (firstWord !== name) {
        const fallbackUrl = `${BASE_URL}/api/v1/exercises/name/${encodeURIComponent(firstWord)}?limit=10&offset=0`;
        const fallbackResp = await fetch(fallbackUrl, {
          headers: {
            'x-rapidapi-key': RAPIDAPI_KEY,
            'x-rapidapi-host': 'exercisedb.p.rapidapi.com'
          }
        });
        if (fallbackResp.ok) {
          const fallbackData = await fallbackResp.json();
          const match = findBestMatch(name, fallbackData);
          if (match) {
            return res.status(200).json(formatExercise(match));
          }
        }
      }
      return res.status(404).json({ error: 'Exercise not found' });
    }

    // Find best match from results
    const match = findBestMatch(name, data);
    return res.status(200).json(formatExercise(match || data[0]));

  } catch (err) {
    console.error('ExerciseDB error:', err);
    return res.status(500).json({ error: err.message });
  }
};

function findBestMatch(query, exercises) {
  if (!exercises || exercises.length === 0) return null;

  const q = query.toLowerCase().replace(/[^a-z0-9 ]/g, '');
  const qWords = q.split(/\s+/);

  let best = null;
  let bestScore = -1;

  for (const ex of exercises) {
    const eName = (ex.name || '').toLowerCase().replace(/[^a-z0-9 ]/g, '');

    // Exact match
    if (eName === q) return ex;

    // Word overlap score
    let score = 0;
    for (const w of qWords) {
      if (eName.includes(w)) score += w.length;
    }

    // Bonus for name starting with same word
    if (eName.startsWith(qWords[0])) score += 5;

    if (score > bestScore) {
      bestScore = score;
      best = ex;
    }
  }

  return best;
}

function formatExercise(ex) {
  return {
    name: ex.name,
    gifUrl: ex.gifUrl,
    target: ex.target,
    bodyPart: ex.bodyPart,
    equipment: ex.equipment,
    secondaryMuscles: ex.secondaryMuscles || [],
    instructions: ex.instructions || []
  };
}

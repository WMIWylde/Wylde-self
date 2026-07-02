const { applyCors } = require('../lib/security');

const BASE = 'https://oss.exercisedb.dev/api/v1';

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'GET, OPTIONS' })) return;
  if (req.method !== 'GET') return res.status(405).json({ error: 'GET only' });

  const { q, bodyPart, equipment, muscle, limit = '20', offset = '0' } = req.query;

  try {
    let url;
    const params = `limit=${Math.min(parseInt(limit), 50)}&offset=${offset}`;

    if (q) {
      // Search by name
      url = `${BASE}/exercises?search=${encodeURIComponent(q)}&${params}`;
    } else if (bodyPart) {
      url = `${BASE}/exercises?bodyPart=${encodeURIComponent(bodyPart)}&${params}`;
    } else if (equipment) {
      url = `${BASE}/exercises?equipment=${encodeURIComponent(equipment)}&${params}`;
    } else if (muscle) {
      url = `${BASE}/exercises?muscle=${encodeURIComponent(muscle)}&${params}`;
    } else {
      url = `${BASE}/exercises?${params}`;
    }

    const resp = await fetch(url, { signal: AbortSignal.timeout(8000) });
    if (!resp.ok) {
      return res.status(resp.status).json({ error: 'ExerciseDB unavailable' });
    }

    const data = await resp.json();

    // Normalize to our format
    const exercises = (data.data || []).map(e => ({
      id: e.exerciseId,
      name: e.name,
      gifUrl: e.gifUrl,
      bodyParts: e.bodyParts || [],
      equipment: (e.equipments || [])[0] || 'body weight',
      targetMuscles: e.targetMuscles || [],
      secondaryMuscles: e.secondaryMuscles || [],
      instructions: (e.instructions || []).map(s => s.replace(/^Step:\d+\s*/, '')),
    }));

    return res.status(200).json({
      exercises,
      total: data.meta?.total || exercises.length,
      hasMore: data.meta?.hasNextPage || false,
    });
  } catch (e) {
    console.error('[exercises-search] Error:', e.message);
    return res.status(500).json({ error: 'Exercise search failed' });
  }
};

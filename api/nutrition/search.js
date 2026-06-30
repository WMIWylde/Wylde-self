const { applyCors } = require('../../lib/security');
const { getSupabaseAdmin } = require('../../lib/supabase-admin');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'GET, OPTIONS' })) return;
  if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

  const { q, barcode } = req.query;
  if (!q && !barcode) return res.status(400).json({ error: 'q or barcode required' });

  let supabase;
  try { supabase = getSupabaseAdmin(); } catch (e) { supabase = null; }
  const results = [];

  // 1. Search local cache first
  if (supabase) {
    try {
      if (barcode) {
        const { data } = await supabase
          .from('foods')
          .select('*')
          .eq('barcode', barcode)
          .limit(1);
        if (data?.length) {
          supabase.from('foods').update({ search_count: (data[0].search_count || 0) + 1 }).eq('id', data[0].id).then(() => {});
          return res.status(200).json({ foods: data, source: 'cache' });
        }
      } else if (q) {
        const { data } = await supabase
          .from('foods')
          .select('*')
          .ilike('name', `%${q}%`)
          .order('search_count', { ascending: false })
          .limit(10);
        if (data?.length >= 3) {
          return res.status(200).json({ foods: data, source: 'cache' });
        }
        if (data?.length) results.push(...data);
      }
    } catch (e) {
      console.log('[nutrition] cache lookup failed (table may not exist):', e.message);
    }
  }

  // 2. Search USDA FoodData Central
  try {
    const usdaKey = process.env.USDA_API_KEY || 'DEMO_KEY';
    let usdaUrl;

    if (barcode) {
      usdaUrl = `https://api.nal.usda.gov/fdc/v1/foods/search?api_key=${usdaKey}&query=${barcode}&dataType=Branded&pageSize=5`;
    } else {
      usdaUrl = `https://api.nal.usda.gov/fdc/v1/foods/search?api_key=${usdaKey}&query=${encodeURIComponent(q)}&pageSize=20&dataType=Foundation,SR Legacy,Branded`;
    }

    const usdaResp = await fetch(usdaUrl, { signal: AbortSignal.timeout(8000) });
    if (usdaResp.ok) {
      const usdaData = await usdaResp.json();
      const usdaFoods = (usdaData.foods || []).map(f => normalizeUSDA(f));
      results.push(...usdaFoods);

      // Cache in background (don't block response)
      if (supabase) {
        cacheResults(supabase, usdaFoods).catch(e => console.log('[nutrition] cache write error:', e.message));
      }
    } else {
      console.log('[nutrition] USDA returned', usdaResp.status);
    }
  } catch (e) {
    console.error('[nutrition] USDA error:', e.message);
  }

  // 3. Search Open Food Facts (for both barcode AND text — it has great branded coverage)
  try {
    let offUrl;
    if (barcode) {
      offUrl = `https://world.openfoodfacts.org/api/v0/product/${barcode}.json`;
      const offResp = await fetch(offUrl, { signal: AbortSignal.timeout(5000) });
      if (offResp.ok) {
        const offData = await offResp.json();
        if (offData.status === 1 && offData.product) {
          const food = normalizeOFF(offData.product, barcode);
          results.push(food);
        }
      }
    } else if (q && results.length < 10) {
      // Text search on Open Food Facts — good for branded products
      offUrl = `https://world.openfoodfacts.org/cgi/search.pl?search_terms=${encodeURIComponent(q)}&search_simple=1&action=process&json=1&page_size=10&fields=product_name,brands,nutriments,serving_quantity,code,image_url`;
      const offResp = await fetch(offUrl, { signal: AbortSignal.timeout(5000) });
      if (offResp.ok) {
        const offData = await offResp.json();
        const offFoods = (offData.products || [])
          .filter(p => p.product_name && p.nutriments)
          .map(p => normalizeOFF(p, p.code || null));
        results.push(...offFoods);
      }
    }
  } catch (e) {
    console.error('[nutrition] OFF error:', e.message);
  }

  // 4. If still low on results and not a barcode search, use AI as last resort
  if (!barcode && results.length < 5 && q && process.env.OPENAI_API_KEY) {
    try {
      const aiFood = await aiLookup(q);
      if (aiFood) results.push(aiFood);
    } catch (e) {
      console.log('[nutrition] AI lookup failed:', e.message);
    }
  }

  // Deduplicate by normalized name
  const seen = new Set();
  const deduped = results.filter(f => {
    if (!f.name || f.name === 'Unknown') return false;
    const key = (f.name || '').toLowerCase().replace(/[^a-z0-9]/g, '').trim();
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });

  // Sort: items with calories first, then by search_count
  deduped.sort((a, b) => {
    if ((a.calories || 0) > 0 && (b.calories || 0) === 0) return -1;
    if ((a.calories || 0) === 0 && (b.calories || 0) > 0) return 1;
    return (b.search_count || 0) - (a.search_count || 0);
  });

  return res.status(200).json({
    foods: deduped.slice(0, 25),
    source: deduped.length > 0 ? 'multi' : 'none',
    count: deduped.length,
  });
};

// Background cache — fire and forget
async function cacheResults(supabase, foods) {
  for (const food of foods) {
    try {
      await supabase
        .from('foods')
        .upsert(food, { onConflict: 'provider,provider_food_id', ignoreDuplicates: true });
    } catch (e) { /* ignore individual cache failures */ }
  }
}

// AI-powered food lookup for common foods the databases miss
async function aiLookup(query) {
  const resp = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: 'Return nutrition data for a food item as JSON only. Format: {"name":"Food Name","serving_size":100,"serving_unit":"g","calories":200,"protein":10,"carbs":25,"fat":8}' },
        { role: 'user', content: `Nutrition facts for: ${query}` },
      ],
      temperature: 0.2,
      max_tokens: 200,
    }),
    signal: AbortSignal.timeout(5000),
  });

  if (!resp.ok) return null;
  const data = await resp.json();
  const content = data.choices?.[0]?.message?.content || '';
  const jsonStart = content.indexOf('{');
  const jsonEnd = content.lastIndexOf('}');
  if (jsonStart === -1) return null;

  const parsed = JSON.parse(content.slice(jsonStart, jsonEnd + 1));
  return {
    provider: 'ai',
    provider_food_id: `ai_${query.toLowerCase().replace(/[^a-z0-9]/g, '_')}`,
    name: parsed.name || query,
    brand: null,
    serving_size: parsed.serving_size || 100,
    serving_unit: parsed.serving_unit || 'g',
    calories: Math.round(parsed.calories || 0),
    protein: parsed.protein || null,
    carbs: parsed.carbs || null,
    fat: parsed.fat || null,
    verified: false,
  };
}

function normalizeUSDA(f) {
  const getNutrient = (nutrients, id) => {
    const n = (nutrients || []).find(n => n.nutrientId === id || n.nutrientNumber === String(id));
    return n ? Math.round(n.value * 100) / 100 : null;
  };

  const nutrients = f.foodNutrients || [];

  return {
    provider: 'usda',
    provider_food_id: String(f.fdcId),
    name: f.description || f.lowercaseDescription || 'Unknown',
    brand: f.brandName || f.brandOwner || null,
    serving_size: f.servingSize || 100,
    serving_unit: f.servingSizeUnit || 'g',
    calories: Math.round(getNutrient(nutrients, 1008) || 0),
    protein: getNutrient(nutrients, 1003),
    carbs: getNutrient(nutrients, 1005),
    fat: getNutrient(nutrients, 1004),
    fiber: getNutrient(nutrients, 1079),
    sugar: getNutrient(nutrients, 2000),
    sodium: getNutrient(nutrients, 1093),
    barcode: f.gtinUpc || null,
    verified: true,
  };
}

function normalizeOFF(p, barcode) {
  const n = p.nutriments || {};
  return {
    provider: 'openfoodfacts',
    provider_food_id: barcode || p.code || `off_${Date.now()}`,
    name: p.product_name || 'Unknown',
    brand: p.brands || null,
    serving_size: p.serving_quantity || 100,
    serving_unit: 'g',
    calories: Math.round(n['energy-kcal_100g'] || n['energy-kcal'] || 0),
    protein: n.proteins_100g || null,
    carbs: n.carbohydrates_100g || null,
    fat: n.fat_100g || null,
    fiber: n.fiber_100g || null,
    sugar: n.sugars_100g || null,
    sodium: n.sodium_100g ? Math.round(n.sodium_100g * 1000) : null,
    barcode: barcode || p.code || null,
    image_url: p.image_url || null,
    verified: true,
  };
}

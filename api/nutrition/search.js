const { applyCors } = require('../../lib/security');
const { getSupabaseAdmin } = require('../../lib/supabase-admin');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'GET, OPTIONS' })) return;
  if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

  const { q, barcode } = req.query;
  if (!q && !barcode) return res.status(400).json({ error: 'q or barcode required' });

  const supabase = getSupabaseAdmin();
  const results = [];

  // 1. Search local cache first
  if (barcode) {
    const { data } = await supabase
      .from('foods')
      .select('*')
      .eq('barcode', barcode)
      .limit(1);
    if (data?.length) {
      await supabase.from('foods').update({ search_count: data[0].search_count + 1 }).eq('id', data[0].id);
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

  // 2. Search USDA FoodData Central
  try {
    const usdaKey = process.env.USDA_API_KEY || 'DEMO_KEY';
    let usdaUrl;

    if (barcode) {
      usdaUrl = `https://api.nal.usda.gov/fdc/v1/foods/search?api_key=${usdaKey}&query=${barcode}&dataType=Branded&pageSize=3`;
    } else {
      usdaUrl = `https://api.nal.usda.gov/fdc/v1/foods/search?api_key=${usdaKey}&query=${encodeURIComponent(q)}&pageSize=15&dataType=Foundation,SR Legacy,Branded`;
    }

    const usdaResp = await fetch(usdaUrl);
    if (usdaResp.ok) {
      const usdaData = await usdaResp.json();
      const usdaFoods = (usdaData.foods || []).map(f => normalizeUSDA(f));

      // Cache results
      for (const food of usdaFoods) {
        const { error } = await supabase
          .from('foods')
          .upsert(food, { onConflict: 'provider,provider_food_id', ignoreDuplicates: true });
        if (error) console.log('[nutrition] cache error:', error.message);
      }

      results.push(...usdaFoods);
    }
  } catch (e) {
    console.error('[nutrition] USDA error:', e.message);
  }

  // 3. If barcode and still no results, try Open Food Facts
  if (barcode && results.length === 0) {
    try {
      const offResp = await fetch(`https://world.openfoodfacts.org/api/v0/product/${barcode}.json`);
      if (offResp.ok) {
        const offData = await offResp.json();
        if (offData.status === 1 && offData.product) {
          const food = normalizeOFF(offData.product, barcode);
          await supabase.from('foods').upsert(food, { onConflict: 'provider,provider_food_id', ignoreDuplicates: true });
          results.push(food);
        }
      }
    } catch (e) {
      console.error('[nutrition] OFF error:', e.message);
    }
  }

  // Deduplicate by name
  const seen = new Set();
  const deduped = results.filter(f => {
    const key = (f.name || '').toLowerCase().trim();
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });

  return res.status(200).json({ foods: deduped.slice(0, 20), source: results.length > 0 ? 'usda' : 'none' });
};

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
    provider_food_id: barcode,
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
    sodium: n.sodium_100g ? n.sodium_100g * 1000 : null,
    barcode,
    image_url: p.image_url || null,
    verified: true,
  };
}

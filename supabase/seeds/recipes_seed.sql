-- ════════════════════════════════════════════════════════════════════
--  Wylde Self — Built-in Recipe Seed Data
--  76 recipes: 20 breakfast, 20 lunch, 20 dinner, 16 snacks
--  Mirrors RecipeBookService.swift built-in recipe list.
--
--  Idempotent — uses ON CONFLICT to skip duplicates.
-- ════════════════════════════════════════════════════════════════════

INSERT INTO recipes (user_id, source, meal_type, name, description, ingredients, instructions, prep_time, calories, protein, carbs, fat, tags)
VALUES

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- BREAKFASTS (20)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

(NULL, 'builtin', 'breakfast', 'Scrambled Eggs & Avocado Toast', 'Classic high-protein start',
 '["3 eggs","1 avocado","2 slices sourdough","salt & pepper","everything bagel seasoning"]'::jsonb,
 '["Scramble eggs over medium heat","Toast bread","Mash avocado on toast","Top with eggs and seasoning"]'::jsonb,
 8, 520, 28, 32, 32, '{quick,high-protein}'),

(NULL, 'builtin', 'breakfast', 'Protein Oatmeal Bowl', 'Creamy oats with whey and berries',
 '["1 cup rolled oats","1 scoop whey protein","1/2 cup blueberries","1 tbsp almond butter","1 cup almond milk"]'::jsonb,
 '["Cook oats with almond milk","Stir in protein powder","Top with berries and almond butter"]'::jsonb,
 7, 480, 35, 52, 16, '{high-protein,meal-prep}'),

(NULL, 'builtin', 'breakfast', 'Greek Yogurt Parfait', 'Layered yogurt with granola and fruit',
 '["1.5 cups Greek yogurt","1/3 cup granola","1/2 cup strawberries","1 tbsp honey","1 tbsp chia seeds"]'::jsonb,
 '["Layer yogurt, granola, and fruit","Drizzle with honey","Top with chia seeds"]'::jsonb,
 5, 420, 32, 48, 12, '{quick,no-cook}'),

(NULL, 'builtin', 'breakfast', 'Turkey Sausage & Egg Wrap', 'Savory breakfast wrap',
 '["2 turkey sausage links","3 eggs","1 whole wheat tortilla","1/4 cup shredded cheese","hot sauce"]'::jsonb,
 '["Cook sausage and slice","Scramble eggs","Warm tortilla, fill with eggs, sausage, cheese","Roll and serve with hot sauce"]'::jsonb,
 10, 490, 38, 28, 24, '{high-protein,portable}'),

(NULL, 'builtin', 'breakfast', 'Banana Protein Pancakes', 'Fluffy pancakes packed with protein',
 '["1 banana","2 eggs","1 scoop protein powder","1/4 cup oats","1 tsp cinnamon","maple syrup"]'::jsonb,
 '["Blend banana, eggs, protein powder, oats","Cook on medium griddle 2 min each side","Stack and top with syrup"]'::jsonb,
 12, 440, 34, 46, 14, '{high-protein}'),

(NULL, 'builtin', 'breakfast', 'Smoked Salmon & Cream Cheese Bagel', 'Lox bagel with capers',
 '["1 everything bagel","3 oz smoked salmon","2 tbsp cream cheese","capers","red onion slices","lemon wedge"]'::jsonb,
 '["Toast bagel","Spread cream cheese","Layer salmon, capers, onion","Squeeze lemon over top"]'::jsonb,
 5, 460, 28, 42, 20, '{quick,no-cook}'),

(NULL, 'builtin', 'breakfast', 'Veggie Egg Scramble', 'Loaded vegetable scramble',
 '["3 eggs","1/2 cup spinach","1/4 cup bell peppers diced","1/4 cup mushrooms","1 oz feta cheese","olive oil"]'::jsonb,
 '["Sauté veggies in olive oil 3 min","Add beaten eggs","Scramble until set","Top with crumbled feta"]'::jsonb,
 8, 380, 26, 8, 28, '{low-carb,vegetarian}'),

(NULL, 'builtin', 'breakfast', 'Overnight Oats', 'Prep the night before, grab and go',
 '["1 cup rolled oats","1 cup milk","1 scoop protein powder","1 tbsp peanut butter","1/2 banana sliced"]'::jsonb,
 '["Mix oats, milk, and protein powder in jar","Refrigerate overnight","Top with peanut butter and banana in the morning"]'::jsonb,
 5, 500, 36, 56, 16, '{meal-prep,no-cook}'),

(NULL, 'builtin', 'breakfast', 'Shakshuka', 'Eggs poached in spiced tomato sauce',
 '["3 eggs","1 can diced tomatoes","1/2 onion diced","2 cloves garlic","1 tsp cumin","1 tsp paprika","olive oil","crusty bread"]'::jsonb,
 '["Sauté onion and garlic in olive oil","Add tomatoes, cumin, paprika, simmer 10 min","Make wells, crack eggs in","Cover and cook 5 min until set","Serve with bread"]'::jsonb,
 20, 420, 22, 36, 22, '{mediterranean,vegetarian}'),

(NULL, 'builtin', 'breakfast', 'Acai Bowl', 'Thick smoothie bowl with toppings',
 '["1 packet frozen acai","1/2 banana","1/2 cup frozen berries","1/4 cup almond milk","granola","sliced banana","coconut flakes","honey"]'::jsonb,
 '["Blend acai, frozen banana, berries, and almond milk until thick","Pour into bowl","Top with granola, banana, coconut, and honey"]'::jsonb,
 8, 380, 8, 62, 14, '{vegan,no-cook,antioxidant}'),

(NULL, 'builtin', 'breakfast', 'Egg & Cheese Muffin Cups', 'Meal-prep friendly baked egg cups',
 '["6 eggs","1/4 cup cheddar cheese","1/4 cup bell peppers","2 slices turkey bacon","salt & pepper"]'::jsonb,
 '["Preheat oven to 375F","Grease muffin tin","Whisk eggs, add cheese, peppers, diced bacon","Pour into 6 cups","Bake 18 min"]'::jsonb,
 25, 350, 28, 4, 24, '{meal-prep,low-carb,high-protein}'),

(NULL, 'builtin', 'breakfast', 'Sweet Potato & Black Bean Hash', 'Hearty plant-forward hash',
 '["1 large sweet potato diced","1/2 cup black beans","1/2 bell pepper diced","1/4 onion diced","2 eggs","cumin","olive oil","cilantro"]'::jsonb,
 '["Sauté sweet potato in olive oil 8 min","Add pepper, onion, cumin, cook 3 min","Add black beans, warm through","Fry eggs, serve on top","Garnish with cilantro"]'::jsonb,
 18, 460, 22, 52, 18, '{high-fiber,vegetarian}'),

(NULL, 'builtin', 'breakfast', 'Chia Pudding', 'Creamy make-ahead pudding',
 '["3 tbsp chia seeds","1 cup coconut milk","1 tbsp maple syrup","1/2 tsp vanilla","mango slices","coconut flakes"]'::jsonb,
 '["Mix chia seeds, coconut milk, maple syrup, vanilla","Refrigerate 4 hours or overnight","Top with mango and coconut"]'::jsonb,
 5, 340, 8, 34, 20, '{vegan,no-cook,meal-prep}'),

(NULL, 'builtin', 'breakfast', 'Breakfast Quesadilla', 'Crispy tortilla with eggs and cheese',
 '["2 eggs scrambled","1 flour tortilla","1/4 cup shredded cheese","2 tbsp salsa","1/4 avocado"]'::jsonb,
 '["Scramble eggs","Place tortilla in pan, add cheese on half","Add eggs, fold, cook 2 min each side","Serve with salsa and avocado"]'::jsonb,
 8, 440, 24, 30, 26, '{quick,portable}'),

(NULL, 'builtin', 'breakfast', 'Tofu Scramble', 'Plant-based egg alternative',
 '["1 block firm tofu crumbled","1/2 cup spinach","1/4 cup bell pepper","1/4 tsp turmeric","nutritional yeast","olive oil","salt & pepper"]'::jsonb,
 '["Press and crumble tofu","Sauté in olive oil with turmeric 5 min","Add veggies, cook 3 min","Season with nutritional yeast, salt, pepper"]'::jsonb,
 12, 280, 22, 8, 18, '{vegan,high-protein,low-carb}'),

(NULL, 'builtin', 'breakfast', 'Cottage Cheese Toast', 'High-protein savory toast',
 '["2 slices whole grain bread","1 cup cottage cheese","1/2 avocado","everything bagel seasoning","red pepper flakes"]'::jsonb,
 '["Toast bread","Spread cottage cheese on each slice","Top with avocado slices","Sprinkle seasoning and pepper flakes"]'::jsonb,
 5, 420, 30, 34, 18, '{quick,high-protein,no-cook}'),

(NULL, 'builtin', 'breakfast', 'Korean Rice Bowl (Bibimbap Breakfast)', 'Rice with veggies, egg, and gochujang',
 '["1 cup rice cooked","1 fried egg","1/2 cup kimchi","1/4 cup spinach sautéed","1/4 cup shredded carrot","gochujang","sesame oil","sesame seeds"]'::jsonb,
 '["Warm rice in bowl","Arrange veggies and kimchi around rice","Top with fried egg","Drizzle gochujang and sesame oil","Sprinkle sesame seeds"]'::jsonb,
 12, 440, 16, 58, 16, '{korean,vegetarian}'),

(NULL, 'builtin', 'breakfast', 'Egg White & Spinach Omelette', 'Light and clean protein-focused omelette',
 '["5 egg whites","1 cup spinach","1/4 cup mushrooms","1 oz goat cheese","salt & pepper"]'::jsonb,
 '["Whisk egg whites","Sauté spinach and mushrooms","Pour egg whites in pan, cook 3 min","Add veggies and goat cheese, fold","Cook 1 more min"]'::jsonb,
 10, 220, 28, 4, 10, '{low-calorie,high-protein,low-carb}'),

(NULL, 'builtin', 'breakfast', 'Avocado & Black Bean Breakfast Bowl', 'Mexican-inspired plant-based bowl',
 '["1/2 cup black beans","1/2 avocado","1/4 cup corn","salsa","1 tbsp lime juice","cilantro","1 corn tortilla"]'::jsonb,
 '["Warm beans and corn","Mash avocado with lime juice","Layer beans, corn, avocado in bowl","Top with salsa and cilantro","Serve with toasted tortilla"]'::jsonb,
 8, 380, 14, 48, 16, '{vegan,high-fiber,mexican}'),

(NULL, 'builtin', 'breakfast', 'PB & J Protein Smoothie', 'Tastes like a classic PB&J',
 '["1 scoop vanilla protein","1 cup milk","1 tbsp peanut butter","1/2 cup frozen strawberries","1/2 banana","ice"]'::jsonb,
 '["Blend all ingredients until smooth"]'::jsonb,
 3, 400, 32, 40, 14, '{quick,post-workout,high-protein}'),

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- LUNCHES (20)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

(NULL, 'builtin', 'lunch', 'Grilled Chicken Caesar Salad', 'Classic caesar with grilled chicken',
 '["6 oz chicken breast","romaine lettuce","2 tbsp caesar dressing","1/4 cup parmesan","croutons"]'::jsonb,
 '["Grill chicken 6 min each side","Chop romaine","Slice chicken over greens","Dress and top with parmesan and croutons"]'::jsonb,
 15, 480, 44, 16, 26, '{high-protein,classic}'),

(NULL, 'builtin', 'lunch', 'Turkey & Avocado Wrap', 'Clean wrap with lean turkey',
 '["5 oz sliced turkey breast","1 whole wheat tortilla","1/2 avocado","lettuce","tomato","mustard"]'::jsonb,
 '["Layer turkey, avocado, lettuce, tomato on tortilla","Drizzle mustard","Roll tight and cut in half"]'::jsonb,
 5, 440, 36, 30, 20, '{quick,portable,meal-prep}'),

(NULL, 'builtin', 'lunch', 'Salmon Poke Bowl', 'Fresh poke bowl with sushi rice',
 '["5 oz sushi-grade salmon diced","1 cup sushi rice cooked","1/2 avocado","edamame","cucumber","soy sauce","sesame seeds"]'::jsonb,
 '["Cook and cool sushi rice","Dice salmon","Arrange rice, salmon, avocado, edamame, cucumber","Drizzle soy sauce and sesame seeds"]'::jsonb,
 15, 540, 38, 48, 22, '{japanese,high-protein}'),

(NULL, 'builtin', 'lunch', 'Chicken Burrito Bowl', 'Chipotle-style bowl at home',
 '["6 oz chicken thigh","1 cup brown rice","1/2 cup black beans","salsa","1/4 avocado","lime","cilantro"]'::jsonb,
 '["Season and cook chicken 5 min each side","Warm rice and beans","Slice chicken and build bowl","Top with salsa, avocado, cilantro, lime"]'::jsonb,
 18, 580, 42, 56, 18, '{meal-prep,high-protein,mexican}'),

(NULL, 'builtin', 'lunch', 'Tuna Stuffed Sweet Potato', 'Loaded sweet potato with tuna salad',
 '["1 large sweet potato","1 can tuna","2 tbsp Greek yogurt","celery diced","red onion","salt & pepper"]'::jsonb,
 '["Bake sweet potato 45 min at 400F (or microwave 8 min)","Mix tuna with yogurt, celery, onion","Split potato and fill with tuna mix"]'::jsonb,
 12, 420, 36, 46, 8, '{low-fat,meal-prep}'),

(NULL, 'builtin', 'lunch', 'Steak & Arugula Salad', 'Peppery arugula with sliced steak',
 '["5 oz flank steak","arugula","cherry tomatoes","shaved parmesan","balsamic vinaigrette","red onion"]'::jsonb,
 '["Season steak, sear 4 min each side for medium","Rest 5 min, slice thin","Toss arugula, tomatoes, onion with vinaigrette","Top with steak and parmesan"]'::jsonb,
 15, 460, 38, 12, 28, '{high-protein,low-carb}'),

(NULL, 'builtin', 'lunch', 'Mediterranean Chicken Pita', 'Grilled chicken in warm pita',
 '["5 oz chicken breast","1 whole wheat pita","hummus","cucumber","tomato","red onion","feta"]'::jsonb,
 '["Grill chicken with Mediterranean seasoning","Warm pita","Spread hummus in pita","Fill with sliced chicken, veggies, feta"]'::jsonb,
 15, 490, 40, 38, 18, '{mediterranean}'),

(NULL, 'builtin', 'lunch', 'Shrimp Stir-Fry', 'Quick shrimp and veggie stir-fry',
 '["6 oz shrimp peeled","1 cup broccoli florets","1/2 cup snap peas","1 cup jasmine rice","soy sauce","garlic","sesame oil"]'::jsonb,
 '["Cook rice","Sauté garlic in sesame oil","Add shrimp, cook 2 min each side","Add veggies, stir-fry 3 min","Splash soy sauce, serve over rice"]'::jsonb,
 15, 480, 36, 52, 12, '{quick,high-protein,asian}'),

(NULL, 'builtin', 'lunch', 'Thai Peanut Chicken Lettuce Wraps', 'Crunchy wraps with peanut sauce',
 '["5 oz chicken breast diced","butter lettuce leaves","1/4 cup shredded carrot","cucumber sliced","peanuts chopped","2 tbsp peanut butter","1 tbsp soy sauce","lime juice","sriracha"]'::jsonb,
 '["Cook diced chicken 5 min","Mix peanut butter, soy sauce, lime, sriracha for sauce","Fill lettuce cups with chicken, carrot, cucumber","Drizzle peanut sauce, top with peanuts"]'::jsonb,
 12, 420, 38, 16, 24, '{thai,low-carb,high-protein}'),

(NULL, 'builtin', 'lunch', 'Lentil Soup', 'Hearty one-pot lentil soup',
 '["1 cup red lentils","1 can diced tomatoes","1 carrot diced","1 onion diced","2 cloves garlic","1 tsp cumin","4 cups vegetable broth","olive oil","lemon"]'::jsonb,
 '["Sauté onion, carrot, garlic in olive oil 5 min","Add lentils, tomatoes, broth, cumin","Simmer 20 min until lentils are soft","Squeeze lemon, season to taste"]'::jsonb,
 30, 380, 22, 56, 6, '{vegan,high-fiber,one-pot,meal-prep}'),

(NULL, 'builtin', 'lunch', 'Chicken Shawarma Bowl', 'Middle Eastern spiced chicken with tahini',
 '["6 oz chicken thigh","1 cup basmati rice","cucumber","tomato","pickled onion","tahini","cumin","paprika","garlic powder","olive oil"]'::jsonb,
 '["Season chicken with cumin, paprika, garlic powder","Cook chicken 5 min each side, slice","Cook rice","Build bowl with rice, chicken, veggies","Drizzle tahini"]'::jsonb,
 20, 560, 40, 52, 20, '{middle-eastern,high-protein,meal-prep}'),

(NULL, 'builtin', 'lunch', 'Veggie Buddha Bowl', 'Colorful grain bowl with tahini dressing',
 '["1 cup quinoa cooked","1/2 cup roasted sweet potato","1/2 cup chickpeas","1/2 avocado","1/2 cup kale massaged","tahini","lemon juice"]'::jsonb,
 '["Cook quinoa","Roast sweet potato cubes at 400F 20 min","Warm chickpeas","Arrange all in bowl","Drizzle tahini and lemon"]'::jsonb,
 25, 520, 18, 64, 22, '{vegan,high-fiber,mediterranean}'),

(NULL, 'builtin', 'lunch', 'Japanese Teriyaki Salmon Bowl', 'Glazed salmon over rice with pickled ginger',
 '["5 oz salmon fillet","1 cup sushi rice","teriyaki sauce","edamame","pickled ginger","nori strips","sesame seeds"]'::jsonb,
 '["Cook rice","Brush salmon with teriyaki, pan-sear 4 min each side","Arrange rice, salmon, edamame in bowl","Top with ginger, nori, sesame seeds"]'::jsonb,
 18, 540, 36, 52, 18, '{japanese,high-protein}'),

(NULL, 'builtin', 'lunch', 'Black Bean & Corn Salad', 'Bright Tex-Mex salad with lime dressing',
 '["1 can black beans drained","1 cup corn","1 bell pepper diced","1/4 red onion diced","cilantro","lime juice","olive oil","cumin","1/4 avocado"]'::jsonb,
 '["Combine beans, corn, pepper, onion, cilantro","Whisk lime juice, olive oil, cumin","Toss salad with dressing","Top with avocado"]'::jsonb,
 10, 380, 16, 52, 14, '{vegan,no-cook,high-fiber,mexican}'),

(NULL, 'builtin', 'lunch', 'Grilled Chicken Grain Bowl', 'Farro, greens, and grilled chicken',
 '["5 oz chicken breast","1 cup farro cooked","mixed greens","roasted beets","goat cheese","walnuts","balsamic glaze"]'::jsonb,
 '["Grill chicken, slice","Cook farro","Arrange greens, farro, beets in bowl","Top with chicken, goat cheese, walnuts","Drizzle balsamic glaze"]'::jsonb,
 20, 520, 38, 46, 20, '{high-protein,whole-grain}'),

(NULL, 'builtin', 'lunch', 'Vietnamese Banh Mi Bowl', 'Deconstructed banh mi without the bread',
 '["5 oz pork tenderloin","pickled carrots and daikon","cucumber","jalapeño","cilantro","1 cup jasmine rice","soy sauce","lime","sriracha mayo"]'::jsonb,
 '["Season and sear pork 4 min each side, slice","Cook rice","Arrange rice, pork, pickled veggies, cucumber","Top with jalapeño, cilantro, sriracha mayo"]'::jsonb,
 18, 480, 34, 50, 14, '{vietnamese,high-protein}'),

(NULL, 'builtin', 'lunch', 'Caprese Chicken Salad', 'Italian-inspired with fresh mozzarella',
 '["5 oz chicken breast grilled","fresh mozzarella","cherry tomatoes","fresh basil","mixed greens","balsamic glaze","olive oil"]'::jsonb,
 '["Grill and slice chicken","Arrange greens, tomatoes, mozzarella","Top with chicken and basil","Drizzle olive oil and balsamic glaze"]'::jsonb,
 15, 460, 42, 10, 28, '{italian,low-carb,high-protein}'),

(NULL, 'builtin', 'lunch', 'Chickpea Curry Wrap', 'Spiced chickpeas in a warm tortilla',
 '["1 can chickpeas drained","1/2 onion diced","1 tsp curry powder","1/4 cup coconut milk","spinach","1 whole wheat tortilla","olive oil"]'::jsonb,
 '["Sauté onion in olive oil 3 min","Add chickpeas and curry powder, cook 3 min","Add coconut milk, simmer 5 min, mash slightly","Add spinach, wilt","Fill tortilla and roll"]'::jsonb,
 15, 440, 18, 54, 18, '{vegan,indian,portable}'),

(NULL, 'builtin', 'lunch', 'Egg Fried Rice', 'Quick weekday lunch staple',
 '["2 cups cold cooked rice","2 eggs","1/2 cup frozen peas and carrots","2 green onions sliced","soy sauce","sesame oil","garlic"]'::jsonb,
 '["Heat sesame oil, sauté garlic","Push to side, scramble eggs","Add cold rice, stir-fry on high 3 min","Add veggies, soy sauce, toss","Top with green onions"]'::jsonb,
 10, 420, 16, 58, 14, '{quick,asian,budget}'),

(NULL, 'builtin', 'lunch', 'Greek Salad with Grilled Halloumi', 'Salty cheese over a classic Greek salad',
 '["4 oz halloumi cheese","cucumber","cherry tomatoes","red onion","kalamata olives","olive oil","oregano","lemon juice"]'::jsonb,
 '["Slice and grill halloumi 2 min each side","Chop cucumber, tomatoes, onion","Toss with olives, olive oil, lemon, oregano","Top with halloumi"]'::jsonb,
 12, 420, 22, 14, 32, '{mediterranean,vegetarian,low-carb}'),

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- DINNERS (20)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

(NULL, 'builtin', 'dinner', 'Pan-Seared Salmon & Asparagus', 'Crispy salmon with roasted asparagus',
 '["6 oz salmon fillet","1 bunch asparagus","1 tbsp olive oil","lemon","garlic","salt & pepper"]'::jsonb,
 '["Season salmon with salt, pepper, garlic","Pan-sear skin-side down 4 min, flip 3 min","Roast asparagus at 425F with olive oil 12 min","Squeeze lemon over everything"]'::jsonb,
 18, 480, 42, 10, 30, '{high-protein,low-carb}'),

(NULL, 'builtin', 'dinner', 'Chicken Stir-Fry with Rice', 'Teriyaki chicken with vegetables',
 '["6 oz chicken breast","1 cup jasmine rice","broccoli","bell peppers","teriyaki sauce","sesame oil","green onions"]'::jsonb,
 '["Cook rice","Slice chicken, stir-fry in sesame oil 5 min","Add veggies, cook 3 min","Add teriyaki sauce, toss","Serve over rice with green onions"]'::jsonb,
 20, 560, 40, 58, 16, '{meal-prep,asian}'),

(NULL, 'builtin', 'dinner', 'Grass-Fed Beef Tacos', 'Simple beef tacos with fresh toppings',
 '["6 oz ground beef (90/10)","3 corn tortillas","1/4 avocado","salsa","cilantro","lime","shredded lettuce"]'::jsonb,
 '["Brown beef with taco seasoning","Warm tortillas","Build tacos with beef, lettuce, salsa, avocado","Finish with cilantro and lime"]'::jsonb,
 15, 520, 36, 34, 26, '{quick,mexican}'),

(NULL, 'builtin', 'dinner', 'Baked Cod with Quinoa', 'Light white fish with herbed quinoa',
 '["6 oz cod fillet","1 cup quinoa cooked","lemon","cherry tomatoes","olive oil","fresh herbs","capers"]'::jsonb,
 '["Bake cod at 400F for 12 min with lemon and herbs","Cook quinoa","Halve tomatoes, toss with olive oil and capers","Plate cod over quinoa with tomato salad"]'::jsonb,
 20, 440, 38, 40, 14, '{light,high-protein,mediterranean}'),

(NULL, 'builtin', 'dinner', 'Turkey Meatball Pasta', 'Lean turkey meatballs with marinara',
 '["6 oz ground turkey","2 oz whole wheat pasta","marinara sauce","parmesan","garlic","Italian seasoning","egg"]'::jsonb,
 '["Mix turkey with egg, garlic, Italian seasoning, form balls","Bake meatballs at 400F 15 min","Cook pasta","Simmer meatballs in marinara","Serve over pasta with parmesan"]'::jsonb,
 25, 540, 42, 48, 18, '{meal-prep,italian}'),

(NULL, 'builtin', 'dinner', 'Grilled Steak & Sweet Potato', 'Seared steak with roasted sweet potato',
 '["6 oz sirloin steak","1 large sweet potato","1 tbsp butter","rosemary","salt & pepper","steamed broccoli"]'::jsonb,
 '["Season steak, sear 4 min each side","Rest 5 min","Cube and roast sweet potato at 425F 25 min","Steam broccoli","Plate with butter on steak"]'::jsonb,
 30, 580, 44, 42, 24, '{high-protein}'),

(NULL, 'builtin', 'dinner', 'Shrimp & Zucchini Noodles', 'Low-carb garlic shrimp over zoodles',
 '["6 oz shrimp","2 zucchinis spiralized","garlic","olive oil","cherry tomatoes","red pepper flakes","parmesan"]'::jsonb,
 '["Sauté garlic in olive oil","Add shrimp, cook 2 min each side","Add zucchini noodles, toss 2 min","Add halved tomatoes and pepper flakes","Top with parmesan"]'::jsonb,
 12, 360, 36, 14, 18, '{low-carb,quick,keto}'),

(NULL, 'builtin', 'dinner', 'Chicken & Black Bean Bowl', 'Southwest-style protein bowl',
 '["6 oz chicken breast","1/2 cup black beans","1 cup brown rice","corn","salsa","lime","cilantro","sour cream"]'::jsonb,
 '["Season and grill chicken","Warm rice, beans, and corn","Build bowl","Top with salsa, sour cream, cilantro, lime"]'::jsonb,
 20, 560, 44, 56, 14, '{meal-prep,high-protein,mexican}'),

(NULL, 'builtin', 'dinner', 'Thai Green Curry', 'Coconut curry with chicken and vegetables',
 '["6 oz chicken thigh diced","1 can coconut milk","2 tbsp green curry paste","1 cup broccoli","1/2 cup bell pepper","basil leaves","1 cup jasmine rice","fish sauce"]'::jsonb,
 '["Cook rice","Sauté curry paste in oil 1 min","Add coconut milk, bring to simmer","Add chicken, cook 6 min","Add veggies, cook 3 min","Season with fish sauce, top with basil"]'::jsonb,
 22, 580, 36, 48, 28, '{thai,one-pot}'),

(NULL, 'builtin', 'dinner', 'Sheet Pan Chicken Fajitas', 'Everything on one pan',
 '["6 oz chicken breast sliced","2 bell peppers sliced","1 onion sliced","fajita seasoning","olive oil","tortillas","lime","sour cream"]'::jsonb,
 '["Toss chicken, peppers, onion with seasoning and oil","Spread on sheet pan","Bake at 425F for 18 min","Serve in warm tortillas with lime and sour cream"]'::jsonb,
 25, 520, 38, 42, 20, '{sheet-pan,meal-prep,mexican}'),

(NULL, 'builtin', 'dinner', 'Lemon Herb Chicken Thighs', 'Juicy baked chicken thighs with herbs',
 '["2 bone-in chicken thighs","lemon","garlic","rosemary","thyme","olive oil","roasted potatoes","green beans"]'::jsonb,
 '["Season thighs with lemon, garlic, herbs, oil","Place on baking sheet with potatoes","Bake at 425F for 35 min","Steam green beans last 5 min","Serve together"]'::jsonb,
 40, 560, 40, 36, 28, '{mediterranean,one-pan}'),

(NULL, 'builtin', 'dinner', 'Tofu Pad Thai', 'Classic Thai noodle dish, plant-based',
 '["1 block firm tofu cubed","4 oz rice noodles","1 egg","bean sprouts","green onion","peanuts chopped","2 tbsp pad thai sauce","lime","sriracha"]'::jsonb,
 '["Press and cube tofu, pan-fry until golden","Cook rice noodles per package","Scramble egg in pan","Add noodles, sauce, toss together","Top with sprouts, peanuts, green onion, lime"]'::jsonb,
 20, 480, 24, 54, 20, '{thai,vegetarian}'),

(NULL, 'builtin', 'dinner', 'Lamb Kofta with Tzatziki', 'Spiced lamb patties with cool yogurt sauce',
 '["6 oz ground lamb","1/4 onion grated","cumin","coriander","parsley","1/2 cup Greek yogurt","cucumber grated","garlic","pita bread","mixed greens"]'::jsonb,
 '["Mix lamb with onion, cumin, coriander, parsley","Form into oval patties","Grill or pan-fry 4 min each side","Mix yogurt, cucumber, garlic for tzatziki","Serve kofta with pita, greens, tzatziki"]'::jsonb,
 20, 520, 36, 30, 28, '{middle-eastern,high-protein}'),

(NULL, 'builtin', 'dinner', 'Stuffed Bell Peppers', 'Peppers filled with rice, beef, and cheese',
 '["2 large bell peppers halved","4 oz ground beef","1/2 cup rice cooked","1/2 cup tomato sauce","1/4 cup shredded cheese","Italian seasoning"]'::jsonb,
 '["Brown beef with Italian seasoning","Mix with rice and tomato sauce","Stuff pepper halves","Top with cheese","Bake at 375F for 25 min"]'::jsonb,
 35, 480, 32, 38, 22, '{meal-prep,comfort}'),

(NULL, 'builtin', 'dinner', 'Miso Glazed Cod', 'Japanese-style glazed white fish',
 '["6 oz cod fillet","2 tbsp white miso paste","1 tbsp mirin","1 tsp sesame oil","1 cup rice","steamed bok choy","sesame seeds"]'::jsonb,
 '["Mix miso, mirin, sesame oil","Marinate cod 30 min (or brush generously)","Broil 6-8 min until caramelized","Serve over rice with bok choy","Sprinkle sesame seeds"]'::jsonb,
 15, 440, 36, 48, 10, '{japanese,high-protein,light}'),

(NULL, 'builtin', 'dinner', 'Chicken Tikka Masala', 'Indian-spiced chicken in creamy tomato sauce',
 '["6 oz chicken breast cubed","1/2 cup plain yogurt","1 can tomato sauce","1/4 cup heavy cream","garam masala","turmeric","garlic","ginger","1 cup basmati rice","cilantro"]'::jsonb,
 '["Marinate chicken in yogurt, garam masala, turmeric 15 min","Cook chicken in pan 5 min","Add tomato sauce, garlic, ginger, simmer 10 min","Stir in cream","Serve over rice with cilantro"]'::jsonb,
 30, 560, 40, 52, 20, '{indian,comfort}'),

(NULL, 'builtin', 'dinner', 'One-Pan Sausage & Vegetables', 'Italian sausage with roasted veggies',
 '["2 Italian chicken sausage links","1 cup broccoli","1 cup sweet potato cubed","1/2 cup bell pepper","olive oil","Italian seasoning","garlic powder"]'::jsonb,
 '["Cut sausage into rounds","Toss all with olive oil and seasonings","Spread on sheet pan","Bake at 400F for 22 min"]'::jsonb,
 28, 460, 30, 36, 22, '{sheet-pan,meal-prep,one-pan}'),

(NULL, 'builtin', 'dinner', 'Black Bean Enchiladas', 'Vegetarian enchiladas with red sauce',
 '["1 can black beans","1/2 cup corn","1/2 cup shredded cheese","4 corn tortillas","enchilada sauce","sour cream","cilantro","1/4 avocado"]'::jsonb,
 '["Mix beans, corn, half the cheese","Fill tortillas, roll, place in baking dish","Pour enchilada sauce over top","Sprinkle remaining cheese","Bake at 375F 20 min","Top with sour cream, cilantro, avocado"]'::jsonb,
 30, 520, 22, 62, 22, '{vegetarian,mexican,comfort}'),

(NULL, 'builtin', 'dinner', 'Grilled Mahi-Mahi with Mango Salsa', 'Light fish with tropical fruit salsa',
 '["6 oz mahi-mahi fillet","1/2 mango diced","1/4 red onion diced","jalapeño minced","cilantro","lime juice","1 cup coconut rice","olive oil"]'::jsonb,
 '["Season fish, grill 4 min each side","Mix mango, onion, jalapeño, cilantro, lime for salsa","Cook rice with splash of coconut milk","Plate fish over rice, top with salsa"]'::jsonb,
 18, 460, 36, 48, 12, '{light,tropical,high-protein}'),

(NULL, 'builtin', 'dinner', 'Korean Beef Bulgogi Bowl', 'Sweet-savory marinated beef over rice',
 '["6 oz beef sirloin sliced thin","soy sauce","sesame oil","brown sugar","garlic","ginger","1 cup rice","kimchi","steamed spinach","fried egg","sesame seeds"]'::jsonb,
 '["Marinate beef in soy sauce, sesame oil, sugar, garlic, ginger 15 min","Stir-fry beef on high heat 3 min","Cook rice","Build bowl: rice, beef, spinach, kimchi","Top with fried egg and sesame seeds"]'::jsonb,
 25, 580, 40, 54, 22, '{korean,high-protein}'),

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SNACKS (16)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

(NULL, 'builtin', 'snack', 'Protein Shake', 'Classic whey shake with banana',
 '["1 scoop whey protein","1 banana","1 cup almond milk","ice","1 tbsp peanut butter"]'::jsonb,
 '["Blend all ingredients until smooth"]'::jsonb,
 3, 340, 30, 32, 12, '{quick,post-workout}'),

(NULL, 'builtin', 'snack', 'Greek Yogurt & Berries', 'High-protein snack',
 '["1 cup Greek yogurt","1/2 cup mixed berries","1 tbsp honey"]'::jsonb,
 '["Combine and eat"]'::jsonb,
 2, 220, 20, 28, 4, '{quick,no-cook}'),

(NULL, 'builtin', 'snack', 'Apple & Almond Butter', 'Simple clean snack',
 '["1 large apple","2 tbsp almond butter"]'::jsonb,
 '["Slice apple","Dip in almond butter"]'::jsonb,
 2, 280, 6, 32, 16, '{quick,no-cook}'),

(NULL, 'builtin', 'snack', 'Cottage Cheese & Pineapple', 'High-protein, sweet and savory',
 '["1 cup cottage cheese","1/2 cup pineapple chunks","pinch of cinnamon"]'::jsonb,
 '["Top cottage cheese with pineapple and cinnamon"]'::jsonb,
 2, 240, 26, 22, 4, '{quick,no-cook,high-protein}'),

(NULL, 'builtin', 'snack', 'Trail Mix & Protein Bar', 'Grab-and-go energy',
 '["1 protein bar","1/4 cup mixed nuts"]'::jsonb,
 '["Unwrap and eat"]'::jsonb,
 1, 350, 24, 28, 16, '{quick,portable}'),

(NULL, 'builtin', 'snack', 'Chocolate Protein Smoothie', 'Thick and rich chocolate shake',
 '["1 scoop chocolate whey","1 cup milk","1/2 banana","1 tbsp cocoa powder","ice"]'::jsonb,
 '["Blend all ingredients until smooth"]'::jsonb,
 3, 300, 28, 30, 8, '{quick,post-workout}'),

(NULL, 'builtin', 'snack', 'Hard Boiled Eggs & Hummus', 'Savory high-protein snack',
 '["2 hard boiled eggs","2 tbsp hummus","carrot sticks"]'::jsonb,
 '["Peel eggs","Dip in hummus with carrot sticks"]'::jsonb,
 2, 240, 16, 12, 14, '{meal-prep,high-protein}'),

(NULL, 'builtin', 'snack', 'Rice Cakes with PB & Banana', 'Light crunchy snack',
 '["2 rice cakes","1 tbsp peanut butter","1/2 banana sliced"]'::jsonb,
 '["Spread peanut butter on rice cakes","Top with banana slices"]'::jsonb,
 2, 260, 8, 38, 10, '{quick,no-cook}'),

(NULL, 'builtin', 'snack', 'Edamame with Sea Salt', 'Steamed soybeans with flaky salt',
 '["1 cup edamame in shell","sea salt"]'::jsonb,
 '["Steam or microwave edamame 3 min","Sprinkle with sea salt"]'::jsonb,
 4, 190, 17, 14, 8, '{vegan,quick,high-protein}'),

(NULL, 'builtin', 'snack', 'Turkey Roll-Ups', 'Deli turkey with cheese and mustard',
 '["4 oz sliced turkey breast","2 slices Swiss cheese","mustard","pickle spear"]'::jsonb,
 '["Lay turkey slices flat","Place cheese and mustard on each","Roll up tight","Serve with pickle"]'::jsonb,
 3, 220, 28, 4, 10, '{low-carb,high-protein,no-cook,keto}'),

(NULL, 'builtin', 'snack', 'Mango Lassi Smoothie', 'Indian-inspired yogurt drink',
 '["1/2 cup mango frozen","1/2 cup Greek yogurt","1/2 cup milk","1 tsp honey","pinch of cardamom"]'::jsonb,
 '["Blend all ingredients until smooth"]'::jsonb,
 3, 240, 14, 36, 4, '{quick,indian}'),

(NULL, 'builtin', 'snack', 'Cucumber & Cream Cheese Bites', 'Cool, crunchy, and satisfying',
 '["1 cucumber sliced","2 oz cream cheese","everything bagel seasoning","smoked salmon (optional)"]'::jsonb,
 '["Spread cream cheese on cucumber rounds","Sprinkle with seasoning","Top with salmon if desired"]'::jsonb,
 5, 180, 8, 6, 14, '{low-carb,no-cook,keto}'),

(NULL, 'builtin', 'snack', 'Energy Balls', 'No-bake oat and nut butter bites',
 '["1 cup rolled oats","1/2 cup peanut butter","1/4 cup honey","2 tbsp chocolate chips","1 tbsp chia seeds"]'::jsonb,
 '["Mix all ingredients in bowl","Refrigerate 20 min","Roll into 10 balls","Store in fridge up to 5 days"]'::jsonb,
 10, 280, 10, 32, 14, '{meal-prep,portable,no-cook}'),

(NULL, 'builtin', 'snack', 'Roasted Chickpeas', 'Crunchy, spiced snack',
 '["1 can chickpeas drained","1 tbsp olive oil","1/2 tsp cumin","1/2 tsp paprika","salt"]'::jsonb,
 '["Pat chickpeas dry","Toss with oil and spices","Bake at 400F for 25 min, stirring halfway","Cool before eating"]'::jsonb,
 30, 240, 12, 30, 8, '{vegan,high-fiber,meal-prep}'),

(NULL, 'builtin', 'snack', 'Tuna Salad Lettuce Cups', 'Protein-packed low-carb cups',
 '["1 can tuna drained","1 tbsp mayo","celery diced","lemon juice","salt & pepper","butter lettuce leaves"]'::jsonb,
 '["Mix tuna, mayo, celery, lemon","Spoon into lettuce cups"]'::jsonb,
 5, 200, 26, 2, 10, '{low-carb,high-protein,no-cook,keto}'),

(NULL, 'builtin', 'snack', 'Frozen Yogurt Bark', 'Sweet frozen treat with toppings',
 '["2 cups Greek yogurt","2 tbsp honey","1/4 cup berries","2 tbsp dark chocolate chips","2 tbsp granola"]'::jsonb,
 '["Mix yogurt and honey","Spread on parchment-lined sheet pan","Top with berries, chocolate, granola","Freeze 2 hours","Break into pieces"]'::jsonb,
 10, 260, 18, 34, 8, '{meal-prep,dessert}')

ON CONFLICT DO NOTHING;

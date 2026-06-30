# Exercise Images

This folder holds two stills per exercise (start position + end position) used by the workout flow.

## Structure
\`\`\`
exercise-images/
  Barbell_Squat/
    0.jpg   ← start position
    1.jpg   ← end position
  Barbell_Bench_Press_-_Medium_Grip/
    0.jpg
    1.jpg
  ...
\`\`\`

## How to add a new one
1. Generate two stills (start + end) using \`grok-prompts.md\` in the repo root for prompts.
2. Save them as \`0.jpg\` and \`1.jpg\` inside the matching exercise folder.
3. Commit + push. Vercel serves them at \`/exercise-images/{id}/{0|1}.jpg\`.

## Naming
The exercise folder name MUST match the id in \`exercise-library-v1.json\` exactly (case + underscores). The workout flow looks up the image by id.

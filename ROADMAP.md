# Wylde Self — Upgrade Backlog (bigger builds)

## Guided Programs (premium candidate)
21-day structured identity programs: each day pairs a specific journal prompt +
meditation + movement focus (tester-requested, modeled on multi-day challenges).
Positioning: add-on subscription or one-time unlock. Needs: program content
authoring, day-state machine, program picker, completion ceremony.

## Rewards economy — phase 2
- Real partner deals (supplements / peptides / providers) replacing seed catalog
- Fraud hardening: move all earning server-side (currently client-inserted, capped +200/event)
- Levels as identity ranks (Wylde voice, not gamer levels) driven by lifetime points
- Redemption codes wired to partner checkout / Decoda billing

## iOS badge system parity
Port WYLDE_BADGES definitions + stat gathering to iOS, with the same +100
bonus and a native ceremony moment (video overlay or particle animation).
Web badge system is the reference implementation.

## Automatic weekly re-periodization
The "Adapt to my progress" flow, on a schedule (cron) with a "your program
evolved" notification instead of a button.

## Warmup videos v2
User films new warmup set -> motion-transfer pipeline (proven with Qi Gong).

## Coach memory + daily check-in — iOS parity
Web has coach_memory (fact extraction every 3 turns, injected into prompt)
and the daily check-in popup (personalized question, opens chat pre-seeded).
Port to CoachService/CoachChatView + a Today-screen check-in card.

## Bring-your-own-AI (power users)
Users plug in their own Anthropic/OpenAI API key for unlimited coach usage.
SECURITY RULE: key stored ON DEVICE ONLY (Keychain / localStorage), sent
directly from client to provider, NEVER stored server-side. Settings toggle
"Use my own AI key". Positioning: power-user feature, after clinic billing.

## Per-clinic pharmacy connections
Each clinic connects their own supplier/pharmacy catalog (as founder did with
DirectRX): import catalog -> cost basis -> clinic sets client pricing/margins.
clinic_products already per-clinician; needs a generic importer (CSV upload
first, per-vendor API adapters as demand appears). Bulk pricing rules
(category x multiplier) belong here too.

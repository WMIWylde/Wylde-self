HANDOFF — Coach feature work
Last updated: Tuesday, May 5, 2026 (laptop session)
Next pickup: Mac mini

TL;DR
A six-step plan for porting the web's chat experience into native iOS as a CoachView is ready to execute. Do not start executing yet — there is an unresolved strategic question that determines how Step 4 and Step 5 should be implemented. Resolve that first, then proceed.

⚠️ Open strategic question (resolve BEFORE executing)
The plan as drafted adds a dedicated Coach tab to MainTabView and ports a chat UI as a peer destination in the bottom navigation.
This is in tension with the direction documented in CLAUDE.md:

"There is one unified AI guide. Not multiple coaches. Not a character with a name and personality."
"The AI should NOT: ... Feel like a chatbot ... Be gimmicky, chatty, or overly conversational"

And the target IA in CLAUDE.md:
Today | Future Self | Library | Profile
— there is no Coach tab in the target IA.
So executing the plan as-is would build a feature this week that's likely to refactor or be removed within a few weeks as IA collapses to Today as the primary surface.
Three paths to choose from:
Path A — Pause Coach work, finish the strategic refactor first
Don't build CoachView yet. Instead:

Resolve the onboarding routing bug (still open — see "Pending bug" below)
Wave 1 refactor on web: hide identity_archetype and coaching_style from user-facing UI
IA restructure on iOS: collapse Coach tab into Today
Then revisit whether a chat UI is needed and what shape it takes

Path B — Build chat UI inside Today, not as a separate tab (recommended)

Steps 1, 2, 3 of the plan: execute as drafted (infrastructure that's reusable regardless of UI shape)
Step 4: reshape — build CoachSheet or CoachInline component that surfaces inside the Today screen, contextually, not as a top-level destination. Same chat UX, same persistence, same backend, smaller and on-strategy.
Step 5: do NOT replace the Coach tab content. Plan a follow-up task to collapse the Coach tab entirely (it won't exist in target IA).
Step 6: adjust test plan to test the new integration point inside Today.

Path C — Ship the Coach tab as planned, accept the trade-off
Build it knowing it's short-term and will likely refactor or be removed when IA collapses. If choosing this path: update CLAUDE.md "Active Direction" section to acknowledge the Coach tab is being built short-term and is expected to refactor.

The six-step plan (from laptop session)
Step 1 — Foundation: networking + reusable styles (~15 min)
Create:

Services/WyldeAPI.swift — generic POST/GET handling JSON encode + decode + errors
Utilities/WyldeStyles.swift — WyldeCard modifier and WyldePrimaryButton style extracted from existing TodayView/StartTodayFlow patterns

No UI changes. No tab changes. App behaves identically.
Audit: brace balance + existing app still compiles unchanged.
Step 2 — Data models (~10 min)
Create Models/CoachModels.swift with ChatMessage, AnthropicRequest, AnthropicResponse, APIError, CoachUserContext. Pure data structures.
The ChatMessage decoder must handle BOTH:

iOS-rich form (with id + timestamp)
Web's leaner form (just role + content)

So the same wylde_coach_chat UserDefaults blob round-trips between web and iOS without breaking either side.
Audit: Codable round-trip — encode a message, decode the JSON back, assert equality.
Step 3 — Coach system prompt (~10 min)
Create Utilities/CoachSystemPrompt.swift containing the exact voice rules from app.html:9024. Verbatim port. Same VOICE / FORMAT / CONTEXT / COACHING RULES / QUICK ACTIONS sections.
Single function: CoachSystemPrompt.build(name:phase:idPhrase:context:) -> String
Audit: side-by-side diff of Swift constant against the web JS string. Word for word.
Step 4 — CoachView (~45 min) — THE BIG ONE — REVIEW PATH CHOICE FIRST
Create Views/CoachView.swift (or CoachSheet.swift if Path B).
Screen contents:

Header with "Future {firstName}" or "Future Self"
Greeting bubble visible only when chat history is empty
Four quick-action chips: "Motivate me" / "Fix my plan" / "I'm off track" / "Optimize everything"
Scrollable list of message bubbles (user right-aligned gold tint, AI left-aligned cream)
Typing indicator (three pulsing dots) while waiting for the API
Input row at bottom: text field + gold send button
Calm error banner if API call fails

State flow:

View appears → load wylde_coach_chat from UserDefaults
User taps chip or types + sends → append user message → save → show typing indicator
Build context from appState + JourneyPhase.forDay() + getIdentityPhrase-style local helper
POST to /api/anthropic via WyldeAPI.shared.post
On response → append assistant message → save → hide typing indicator → scroll to bottom
On error → show banner, restore input text so user can retry

Audit: walk through each state branch, verify scroll behavior, verify persistence triggers on every push, verify the prompt context slice matches web (last 8 minus current + current).
Step 5 — Wire Coach into MainTabView (~2 min) — REVIEW PATH CHOICE FIRST
Path A or B: skip this step.
Path C: one-line change in Views/MainTabView.swift:
swifttabContent(.coach) { WebViewScreen(path: "#coach") }
becomes:
swifttabContent(.coach) { CoachView() }
Audit: confirm no other file references path: "#coach". Confirm appState.selectedTab = .coach (used in StartTodayFlow Step 5) still works without change. Confirm hamburger overlay still appears over the new native Coach view.
Step 6 — Test plan (~10 min)
Checklist to run in simulator + on device:

Build green
Open Coach surface — greeting visible
Tap "Motivate me" — response renders
Type custom message — response renders
Force-quit + relaunch — history restored
Web → iOS continuity check (open wyldeself.com while logged in, send message, return to iOS, see it appear)
Airplane mode — graceful error
StartTodayFlow Step 5 → "Talk to your future self" → lands on native coach (not WebView)
Tab switching mid-typing — typing indicator survives
~12 more edge cases


Pending bug (separate from Coach work)
Onboarding routing bug — web app at ~/Projects/Wylde-self/
State: under investigation. Original premise (onboarding routes to wrong screen) is in question. Diagnosis from Claude Code on Mac mini found:

completeOnboard() at app.html ~line 6975 already calls showScreen('overview') correctly
The two showScreen definitions (line 3980 wrapper and line 6575 function) — the wrapper at 3980 is dead code (its if (typeof origShowScreen === 'function') guard fails because the function isn't installed yet at that point in script execution); only the live function at 6575 runs
The dead wrapper means ovSyncData, ovSyncHeroImage, completeDayInit never fire when entering Today (they only fire from the dead wrapper). This is a separate bug worth fixing later.

Next step on the bug: verify whether the bug actually reproduces on a fresh state. Start the dev server (npm run dev), clear localStorage, run through onboarding, observe what screen you land on.

If you land on Today → bug only affects returning users; trace wylde_last_screen writes
If you land elsewhere → source analysis missed something; deeper investigation needed


Side findings (deferred — fix later, not now)

Dead wrapper at app.html:3980 — never executes due to script-tag ordering. Should be deleted; the setTimeout calls inside (ovSyncData, ovSyncHeroImage, completeDayInit) should be moved into the live showScreen function's 'overview' branch.
Two showScreen definitions is a code-smell from rapid iteration. Consolidate into one canonical implementation when there's a calm moment.
identity_archetype and coaching_style are user-facing today — flagged in audit, need to be hidden from UI per CLAUDE.md direction.


Resume on Mac mini
When picking this up:
bashcd ~/Projects/Wylde-self    # adjust if iOS repo is elsewhere
git pull
cat HANDOFF.md
Then in Claude Code:

"Read HANDOFF.md. Walk me through the open strategic question (Path A/B/C). Don't execute anything yet."

Make the path decision first. Then proceed with the chosen path's adjusted plan.

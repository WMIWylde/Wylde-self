# Decoda Health Integration

Wylde Self ⇄ Decoda EMR. Wylde is the patient-side adherence layer; Decoda is the clinic system of record.

## Env vars (Vercel → Settings → Environment Variables)

| Var | What |
|---|---|
| `DECODA_API_KEY` | Your Decoda API key (never in client code) |
| `DECODA_TENANT` | Your tenant identifier |
| `DECODA_CREATOR_ID` | Decoda provider/user id used as author of adherence notes |
| `DECODA_WEBHOOK_SECRET` | Secret for webhook signature verification |

## Endpoints

- `GET /api/decoda/status` — configured + reachable check (auth required)
- `POST /api/decoda/link-patient` — creates Decoda patient with `external_id` = Wylde user id, stores mapping
- `POST /api/decoda/push-adherence` — writes 7-day adherence summary to the patient's Decoda chart as a quick note
- `POST /api/decoda/webhook` — receives `PATIENT_CREATED`/`PATIENT_UPDATED`, auto-links by email

## Setup

1. Add env vars, run `supabase/migrations/20260717_decoda_integration.sql` in Supabase SQL editor
2. Deploy: `vercel --prod`
3. Smoke test: open the app signed in, hit `/api/decoda/status` → `{ configured: true, connected: true }`
4. In Decoda, register webhook → `https://wyldeself.com/api/decoda/webhook` with the same secret

## Partnership demo flow

Patient signs up in Wylde → link-patient creates them in Decoda → patient trains all week in Wylde → push-adherence drops the summary into their Decoda chart → clinician sees adherence where they already work.

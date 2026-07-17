// lib/decoda.js — server-side Decoda Health API client.
// Docs: https://docs.decodahealth.com/api-reference/introduction
// Auth: API-KEY + TENANT headers. Keys live in Vercel env vars ONLY.

const BASE_URL = 'https://api.decodahealth.com';

function isConfigured() {
  return Boolean(process.env.DECODA_API_KEY && process.env.DECODA_TENANT);
}

async function decodaFetch(path, { method = 'GET', body, query } = {}) {
  if (!isConfigured()) {
    const err = new Error('Decoda not configured (DECODA_API_KEY / DECODA_TENANT missing)');
    err.code = 'DECODA_NOT_CONFIGURED';
    throw err;
  }
  const url = new URL(BASE_URL + path);
  if (query) Object.entries(query).forEach(([k, v]) => v != null && url.searchParams.set(k, v));

  const resp = await fetch(url.toString(), {
    method,
    headers: {
      'API-KEY': process.env.DECODA_API_KEY,
      'TENANT': process.env.DECODA_TENANT,
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  const text = await resp.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch { /* non-JSON body */ }

  if (!resp.ok) {
    const err = new Error(`Decoda ${resp.status}: ${(json && json.detail) || text || 'request failed'}`);
    err.status = resp.status;
    err.body = json;
    throw err;
  }
  return json;
}

// ── Endpoints we use ────────────────────────────────────────────────

// Connectivity / tenant info smoke test
function getTenantPublic() {
  return decodaFetch('/tenant/public');
}

// Create (or link) a patient. external_id ties the Decoda patient to a Wylde user id.
function createPatient({ firstName, lastName, email, phoneNumber, dateOfBirth, externalId }) {
  return decodaFetch('/user/patient/create', {
    method: 'POST',
    body: {
      first_name: firstName,
      last_name: lastName,
      email,
      ...(phoneNumber ? { phone_number: phoneNumber } : {}),
      ...(dateOfBirth ? { date_of_birth: dateOfBirth } : {}),
      ...(externalId ? { external_id: externalId } : {}),
    },
  });
}

// Push a quick note onto the patient's Decoda chart.
// creatorId must be a Decoda provider/user id (env DECODA_CREATOR_ID by default).
function createQuickNote({ patientId, note, creatorId }) {
  return decodaFetch('/user/patient/quick-note/create', {
    method: 'POST',
    body: {
      patientId,
      note,
      creatorId: creatorId || process.env.DECODA_CREATOR_ID,
    },
  });
}

module.exports = { decodaFetch, isConfigured, getTenantPublic, createPatient, createQuickNote };

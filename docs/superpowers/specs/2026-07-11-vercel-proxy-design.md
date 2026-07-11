# Vercel CORS-proxy — design spec

Date: 2026-07-11
Status: approved, pending write-up into the task plan (Task 15b)

## Why this exists

`docs/SPEC.md`'s "API access strategy" section (`docs/SPEC.md:67-111`)
requires this app's web build to call a Vercel-hosted proxy — a browser tab
is CORS-subject regardless of launch method, so a direct VINCUE call from
`flutter run -d web-server` is a non-starter. Task 15 built the client-side
wiring that *consumes* a configured `API_BASE_URL`, but explicitly deferred
building the proxy server itself (needed JP's Vercel login + the real API
key, unavailable mid-task-loop). Reusing the reference React app's deployed
proxy was tried and reverted during Task 10: that proxy sets no CORS headers
at all, because it's only ever called same-origin by that app — a
cross-origin call from this app's own web build is rejected outright
(verified via `curl` showing no `Access-Control-Allow-Origin` on its
response). SPEC.md is explicit that this app needs **its own** deployment of
an equivalent function, not a literal reuse of that URL.

Net effect: without this, the web build can never show real inventory data,
locally or deployed — native Android already works today without a proxy at
all (direct VINCUE call, CORS is a browser-only concern).

## Scope decision

Build a proxy function that mirrors the reference app's
`api/_inventoryHandler.ts` pattern almost exactly, with one substantive
addition: CORS headers, since this proxy — unlike the reference one — is
called cross-origin.

Explicitly out of scope: any change to `InventoryApiClient` or
`lib/config.dart` (Task 4/15's client-side code is already correct and
platform-agnostic about what serves `API_BASE_URL`); any new client-side
auth/key handling (the web build already sends no client-side key by
design — that's the whole point of the proxy); an `OPTIONS`/preflight
handler (see Behavior below for why it's not needed).

## Architecture

- **`api/inventory.ts`** — Vercel serverless function entry point at the
  `flutterinventory` repo root, zero-config auto-detected from its location
  under `/api`, same as the reference app.
- **`api/_inventoryHandler.ts`** — the actual handler logic, kept separate
  from the entry point for the same reason the reference app does it
  (testable in isolation from the Vercel request/response types).
- **`package.json`** (new, repo root) — declares `vitest` as a dev
  dependency only. No runtime dependency: the handler uses `node:http`
  types and the global `fetch`, exactly like the reference implementation.
- No `vercel.json` is expected to be needed — the reference app doesn't use
  one either, and Vercel's zero-config detection of a bare `/api` folder
  with no frontend build step should apply cleanly. Confirm this holds
  during the first `vercel dev`/deploy; if Vercel's auto-detection tries to
  do something Flutter-aware (it shouldn't — there's no `package.json` at
  the root today attached to a recognized frontend framework), add a
  minimal `vercel.json` at that point rather than pre-guessing its shape.

## Behavior

Mirrors `_inventoryHandler.ts` from the reference repo:

1. Read `VINCUE_API_KEY` from `process.env`. Missing → `500` +
   `{ "error": "Server misconfigured: VINCUE_API_KEY is not set" }`.
2. Server-to-server `fetch` to
   `https://pro.vincue.com/api/Inventory/ActiveInventory?dealerID=54222`
   with header `x-api-key: <key>`.
3. Relay the upstream status code and body verbatim.
4. Upstream `fetch` throws → `502` + `{ "error": "Failed to reach upstream
   inventory API" }`.

**Addition: CORS.** Every response (all four cases above) sets
`Access-Control-Allow-Origin: *`. The inventory data behind this proxy is
public read-only dealer inventory — no auth, no user data — so an open
origin policy matches the trust level of the underlying VINCUE endpoint
once the key is server-side, and avoids a config knob that would need
updating every time the calling origin changes (local dev port, eventual
prod domain). No `OPTIONS` preflight handling is needed: the Flutter web
client sends a plain `GET` with no custom headers, which qualifies as a
CORS "simple request" and never triggers a preflight.

## Secrets handling

- **Local (`vercel dev`):** `.env` at repo root (gitignored,
  `.env.example` committed with a placeholder value) containing
  `VINCUE_API_KEY=...`. `vercel dev` reads it automatically.
- **Production:** JP runs `vercel env add VINCUE_API_KEY production`
  himself and pastes the real key when prompted — the actual key value is
  never requested by or passed through the assistant.
- **Vercel project/org:** new project, linked via `vercel link` under the
  existing team (`team_OQadPvIU6eFYG0SwrLmDwN3t`) already used for the
  reference app's `vincue-inventory-challenge` deployment.

## Testing (TDD, Vitest — no exception)

Unlike Task 1's scaffolding exception, this function has real testable
logic, so the project's standard test-first policy applies. Mock `fetch`
and a minimal `res` double (`statusCode`, `setHeader`, `end` recorded, no
real Vercel/Node runtime needed) for `handleInventoryRequest`:

1. Missing `VINCUE_API_KEY` → `500`, error JSON body, CORS header still
   present.
2. Successful upstream fetch → relays upstream status + body verbatim,
   CORS header present.
3. Upstream `fetch` throws → `502`, error JSON body, CORS header present.

## Verification order

1. `npm test` (vitest) green for all three cases above.
2. `vercel dev` locally with a real key in `.env` — `curl` the local
   endpoint directly (confirm CORS header + real data), then point the
   Flutter web-server build's `API_BASE_URL` dart-define at the local
   `vercel dev` URL and confirm real inventory renders in the browser at
   `http://localhost:8765`.
3. `vercel deploy --prod` under the existing team — repeat both checks
   (direct `curl`, then Flutter web-server pointed at the real URL) against
   the production deployment.
4. Record the production URL for Task 16's README write-up (build-
   architecture decision section).

## Plan placement

Inserted as **Task 15b** in
`docs/superpowers/plans/vincue-mobile-implementation.md`, immediately after
Task 15 (letter-suffix convention already established by 14a/14b/14c —
avoids renumbering downstream tasks). Task 16 (README/submission note)
stays last, and can now accurately document a finished proxy-vs-direct
decision instead of an aspirational one.

## Out of scope

- Any change to Dart/Flutter code — this task is entirely the proxy
  function plus its deployment.
- `OPTIONS`/preflight handling (see Behavior above).
- Origin allow-listing (see Behavior above — open CORS chosen instead).
- iOS — not requested anywhere in SPEC.md or the original request; native
  builds are Android-only, and this task doesn't change that.

# Deploy the Flutter web app to Vercel — design spec

Date: 2026-07-12
Status: approved, pending write-up into the task plan

## Why this exists

Not required scope — checked `docs/context/original-request.md` (the
hiring contact's actual emails): the described submission mechanism is
repo access plus a live review call with the mobile lead, not a required
public deployment. JP explicitly asked for it anyway, as a deliberate
above-and-beyond addition, for two concrete reasons decided in
conversation: (1) a real shareable link is nicer for review than "clone
this and run `flutter run`"; (2) it's the only way to see the app on
Apple hardware, since there's no way to build a native iOS app on this
Windows machine — Safari on an iPhone hitting a real URL is the only path
there. (Real Android-phone testing, by contrast, does *not* need this —
that goes through a native `.apk` install via USB/ADB, calling VINCUE
directly with no proxy involved at all, unrelated to this deployment.)

Only the proxy (`api/inventory.ts`) is currently deployed
(`https://flutterinventory.vercel.app/api/inventory`, Task 15b). The
Flutter app itself has only ever run locally via `flutter run -d
web-server`.

## Scope decision

Same Vercel project as the proxy, not a separate one. Vercel natively
serves static files + `api/` functions together from one project — the
proxy's very first deploy log already showed its zero-config default
(`"Output Directory: public if it exists, or ."`), which is exactly the
mechanism this needs: put the built Flutter app in `public/` at the repo
root, and the existing `api/` functions keep deploying alongside it in
the same `vercel deploy --prod`, no new `vercel.json` required (confirm
this holds at actual deploy time, same "verify the zero-config
assumption empirically" approach Task 15b's own design used).

Building Flutter *inside* Vercel's build container was explicitly
considered and rejected: Vercel's build image has no Flutter SDK and
Flutter isn't a recognized framework preset, so getting `flutter build
web` to run there would mean installing the SDK inside an ephemeral,
Node-oriented container on every build — fragile, slow, and not
officially supported. Building locally (where Flutter already works) and
deploying the static output is the robust path, same pattern as
deploying any static site.

Explicitly out of scope:
- Any change to `api/_inventoryHandler.ts`/`api/inventory.ts` — the
  proxy's behavior is unaffected by this task.
- Any change to `lib/config.dart`/`resolveApiBuildConfig` — Task 15's
  build-time `--dart-define` wiring already handles whatever
  `API_BASE_URL` value this build supplies; no new Dart code needed.
- CI/auto-deploy-on-push for the Flutter side — this is a manually-run
  deploy script, not a pipeline. Not requested, and real CI would need
  the same "install Flutter in the build environment" problem just
  rejected above, solved differently (a GitHub Actions runner with
  Flutter preinstalled via `subosito/flutter-action` or similar) — a
  separate, bigger decision to make later if ever wanted.

## Implementation

**Build command** (release mode, matching the confirmed debug-vs-release
latency finding from the prior session):

```
flutter build web --release --dart-define=API_BASE_URL=/api/inventory
```

`API_BASE_URL` is a **relative** path (`/api/inventory`), not the full
`https://flutterinventory.vercel.app/api/inventory` — the app and proxy
are same-origin once both are served from this one Vercel project, so a
relative path resolves correctly (Flutter web's `http` client runs
through the browser's own `fetch`, which resolves relative URLs against
the current page origin) and doesn't hardcode the domain into the build
artifact.

**Deploy script** — new `deploy` entry in the existing root
`package.json` (already used for the proxy's `vitest` tooling):

```json
"scripts": {
  "test": "vitest run",
  "deploy": "flutter build web --release --dart-define=API_BASE_URL=/api/inventory && rm -rf public && cp -r build/web public && vercel deploy --prod"
}
```

Chains: build → replace `public/` with a fresh copy of `build/web` →
deploy. Makes redeploys a single `npm run deploy` instead of a
manually-remembered multi-step process.

**Housekeeping:** add `public/` to `.gitignore` — it's a generated copy
of `build/web` (itself already gitignored by Flutter's default), not
something to commit. `build/web` itself is never committed either; the
copy step regenerates `public/` fresh on every deploy.

## Testing

No new Dart code, so no TDD in the traditional sense — same category as
Task 15b Half A's `package.json`/tooling additions (config/scripting, no
testable application logic). Verification is functional, not unit-level:

1. Run `npm run deploy`.
2. Load the resulting production URL in a browser directly (not just via
   `curl`) — confirm the SRP renders real inventory data, filters/paging
   work, VDP is reachable, and the dealer name shows in the header
   (regression check against the fix from the prior session).
3. Confirm the app's own network calls to `/api/inventory` are
   same-origin in the browser's network tab (no CORS preflight/error) —
   the concrete proof the relative-URL decision above was correct.

## Out of scope

- CI/auto-deploy pipeline (see Scope decision above).
- Any visual/design changes — this is purely "make the existing app
  reachable at a URL," not a redesign.
- iPhone/Android real-device verification — separate, JP does this
  himself once the URL exists; not part of this task's own verification.

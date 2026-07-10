# Original request — verbatim, both emails

## Email 1 — the original web challenge (Brian Kellogg)

> Hey JP!
> Cool work on the VIN aggregator. I have a similar challenge. Using our AP
> here: https://pro.vincue.com/api/swagger/index.html and this key:
> [REDACTED — see .env, never paste the real key into this file] use the
> Inventory endpoint to get data for dealerID 54222 and create two things
> using React as the frontend:
> A listing grid, "SRP" (search result page), based on this data that you
> will receive from the API, and a "VDP" (vehicle details page) that shows
> all the details you receive about a vehicle. The grid can display simple
> bits of information about the vehicle and the details page can have more
> rich data. If you want to get super fancy, include some sort of caching
> on the API call, paging, or some sort of filtering.
> Appreciate you taking this on.

## Email 2 — the Flutter follow-up (Brian Kellogg)

> Do you have any interest in learning mobile development at all? We do
> have a need for mobile, and if you remember we talked slightly about us
> using the Flutter framework here. What would be incredible is if you
> were to spin up a Flutter app that did the same thing you did here with
> this endpoint. A basic SRP view and a VDP view. If you want to do this,
> I have our mobile lead lined up ready to review it as well. He would be
> available to chat with on Tuesday/Wednesday next week if we were to
> advance.

## Scope interpretation (decided in planning conversation, not stated in the emails)

- "Did the same thing you did here" is read as including the full scope of
  the finished web app — caching, paging, and filtering — not just the two
  base screens. "Basic SRP view and VDP view" is read as naming the two
  screens, not capping feature depth.
- Target: full parity with the finished React app's functional scope
  (caching, paging, filtering) plus an attempt to match or improve on its
  design-polish decisions (dark mode, accessibility, resilience UX) where
  Flutter's own idioms make that achievable — see flutter-handoff.md and
  the corrected SPEC.md for what those decisions actually were.
- If timeline pressure forces a cut before Tuesday, cut from the stretch
  goals in this order: filtering first, then design-polish depth, then
  paging — caching is structural to the architecture either way and isn't
  really optional to cut.

## Dev environment constraint (decided in planning conversation)

- Development machine: Windows, 7.85GB total RAM, ~1GB free at time of
  planning — below Android Studio's stated minimum for comfortable
  emulator use. **No Android emulator will be used for iterative
  development.**
- Primary dev target during the build: `flutter run -d chrome` (Flutter
  Web). This is CORS-subject exactly like the original React app was —
  reuse the existing Vercel proxy from the web project's `api/inventory.ts`
  as the data source during Chrome-based development, not a direct call to
  VINCUE's endpoint, since the same malformed
  `Access-Control-Allow-Origin: *, *` header that blocked the web app's
  direct browser calls applies equally here.
- Native Android does *not* have this CORS restriction (CORS is
  browser-only enforcement) — the native build should call VINCUE directly,
  not through the proxy. This needs a build-time or environment-based
  switch between the two base URLs, not two separate codepaths.
- A final verification pass on a real Android device (borrowed physical
  phone, not an emulator) happens once, near the end, before the mobile
  lead review — to catch native-build errors, platform-specific rendering,
  and real touch/gesture behavior that Chrome-based development can't
  surface. This is not the primary dev loop, just a pre-review check.

# SPEC.md vs. Implementation Verification — Flutter Rewrite Handoff

## Context

`docs/SPEC.md` is the source of truth for a Flutter rewrite of this app. Before porting, the spec needs to accurately describe every business rule and behavior the current code implements — an implementer working from the spec alone (not the TS source) must arrive at equivalent logic. This document checks every falsifiable claim in SPEC.md against the actual code (transform logic, SRP/VDP components, architecture, accessibility, and tests) to find:
1. Places the spec says something the code doesn't do (spec is wrong)
2. Places the code does something the spec doesn't mention (spec is incomplete)

**Bottom line: no contradictions found.** Every explicit spec claim matches the code. There is one wording ambiguity that could mislead a from-scratch reimplementation, plus a list of undocumented-but-real behaviors worth adding to SPEC.md before it's used as the Flutter build's sole reference.

---

## The one thing to fix before porting: "price range" is two selects, not one

SPEC.md (SRP scope) lists filters as "make, normalized body style, price range" alongside "Dropdowns/selects" — phrased as if price range is a single control. The actual implementation (`SearchResultsPage.tsx:89-119`) uses **two independent `<select>` elements** — Min price and Max price — each populated from a fixed list `PRICE_THRESHOLDS = [10_000, 15_000, 20_000, 25_000, 30_000, 40_000, 50_000, 75_000, 100_000]` (`src/lib/filterVehicles.ts:42-44`), and each list is dynamically pruned by the other's current selection (min options capped to ≤ maxPrice, max options floored to ≥ minPrice).

A Flutter implementer following the spec literally could build a single range slider instead of two dropdowns. **Recommend amending SPEC.md's SRP filtering bullet to say "price range via two selects (min/max), each populated from a fixed threshold list, each constrained by the other's value" — and include the actual threshold array.**

Related, also undocumented: vehicles with `price === null` ("Call for price") are silently excluded from results whenever *either* price filter is active (`filterVehicles.ts:15-19`). Worth stating explicitly since it's a real UX rule, not an incidental implementation detail.

---

## Confirmed matches (no action needed)

Everything below was checked line-by-line against code and/or tests and matches the spec's claim exactly:

**Transform (`src/lib/transformVehicle.ts` + test):**
- `sellingPrice` → `price`: `$500` floor (`MIN_PLAUSIBLE_PRICE`), catching `""`, `"0.00"`, and the `$1` Porsche sentinel alike — exact match, code comment even cites the Porsche/wholesalePrice reasoning.
- `body` → `bodyStyle`: all 8 `BodyCategory` values reachable; `"S-AWC"`/`"SH-AWD"`/`"4dr AWD"` correctly fall through to `Other`.
- `description` sanitization: strip literal `\n` → `DOMParser`/`textContent` → collapse whitespace, in that exact order.
- `features`: trimmed + deduped via `Set`, order-preserving.
- Numeric fields: `Number()` + `Number.isFinite` guard (not `parseInt`/`parseFloat`).
- `isCertified` (`'Y'` → true) and `isNew` (`'N'` → true) map correctly, `isNew` confirmed by test.
- `RawVehicle`/`Vehicle` interfaces match SPEC.md's TypeScript field-for-field (no `src` field exists anywhere — photos field is `photos`/`vehiclePhotos`).
- Test coverage matches the spec's claimed scope (price nulling, body normalization, features dedup) and exceeds it (also covers photos passthrough, isNew, description sanitization).

**SRP (`SearchResultsPage.tsx`, `VehicleCard.tsx`, `paginate.ts`, `srpSearchParams.ts`):**
- Card fields (photo/placeholder, year/make/model/trim, mileage, price/"Call for price", body style) — exact match.
- Pagination: `PAGE_SIZE = 12`, pure client-side slice over the full cached array.
- URL sync: `make`, `body`, `minPrice`, `maxPrice`, `page` all round-trip through search params; page resets to 1 on filter change; `page` omitted from URL at page 1 (undocumented but harmless).

**VDP (`VehicleDetailsPage.tsx`, `PhotoCarousel.tsx`, `FeatureList.tsx`):**
- Photo carousel: custom-built, `nextIndex`/`prevIndex` clamp (not wrap) confirmed by dedicated tests; "X of Y" counter; per-index failure tracking (`failedIndex === index`) confirmed exactly as spec describes, with a test for "recovers when navigating away from a failed photo."
- Header, spec table (all 6 fields), and features bounding (`BOUND = 10`, exact button text `Show all (N)`/`Show less`, no button at ≤10) all match precisely.
- Routing/cache reuse: VDP calls the same `useInventory()` React Query key as SRP — genuinely no second fetch — and does a local `.find()` by `id`.
- All four states (loading, error, not-found, loaded) present and distinct; error state literally reuses the same `<InventoryError>` component as SRP (stronger guarantee than spec's "same message" wording).

**Architecture:**
- `api/inventory.ts` and `vite.config.ts` middleware both import the *same* shared function (`api/_inventoryHandler.ts`) — genuinely shared, not duplicated. This file isn't named in SPEC.md; worth naming it since it's the actual shared logic the spec describes.
- `useInventory()` returns `{ vehicles, dealerName }` exactly as specified; `dealerName` derived once per fetch.
- Routes: `/` and `/vehicle/:id` — exact match.

**Dark mode / accessibility / resilience / visual design** — all 13 remaining checked claims (theme.ts + inline script duplication, ThemeToggle, Tailwind `@custom-variant`, `FOCUS_RING`/`FOCUS_LINK`, `useFocusOnRouteChange`'s `previousPathname` ref, `motion-reduce:` on all 4 named surfaces, `useDocumentTitle`/`getVdpTitle` format, skip link, `ErrorBoundary` class-component placement, skeleton states, "Clear filters", `getDealerName` fallback/usage, custom select chevron styling, `tabular-nums` usage) matched exactly, often with code comments mirroring the spec prose.

---

## Undocumented-but-real behaviors worth adding to SPEC.md

None of these contradict the spec — they're real business rules the code enforces that a Flutter port would silently miss if built from the current spec text alone:

1. **mpg gating**: `mpgCity`/`mpgHwy` are nulled not just when unparseable but when parsed value is `≤ 0` (`transformVehicle.ts`) — spec's numeric-fields bullet only says "parse and validate."
2. **year/mileage fallback**: if parsing fails, `year` and `mileage` fall back to `0` (not `null`) — consistent with their non-nullable `number` type in the `Vehicle` interface, but not stated anywhere.
3. **Empty features hides the whole section**: `VehicleDetailsPage.tsx` omits the Features heading entirely (not just the button) when `features.length === 0`. Spec only discusses the 10-feature boundary.
4. **`dedupeFeatures` drops empty-after-trim entries**, not just duplicates.
5. **Price-filter null exclusion** (see above, bundled with the price-range fix).
6. **`useDealerName()` convenience hook** is the actual mechanism feeding header/SRP/VDP — spec describes `dealerName` as part of `useInventory()`'s return but doesn't mention this derived hook.
7. **`getVdpTitle` has three distinct title branches** (loaded/not-found/loading) — spec's one example only shows the loaded-vehicle case.
8. **`api/_inventoryHandler.ts`** is the actual shared-logic file (see Architecture above).

---

## Recommendation

Given this spec is the sole reference for a ground-up Flutter rewrite (no source TS to fall back on), amend SPEC.md with:
- The price-range-is-two-selects correction (highest priority — this one could produce a materially different UI).
- The 8 undocumented behaviors above, folded into their relevant existing sections (data quirks, SRP scope, VDP scope, dealer name).

No code changes are implied by this report — it's a documentation-accuracy pass on SPEC.md only.

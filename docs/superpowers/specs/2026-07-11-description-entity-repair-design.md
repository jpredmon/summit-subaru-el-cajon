# Malformed description entity-tag repair — design spec

Date: 2026-07-11
Status: approved, pending write-up into the task plan

## Why this exists

Real VINCUE data from Summit Subaru El Cajon contains marketing
descriptions with a broken opening template — confirmed on at least two
listings so far (stock `RH801775`, 2024 Honda CR-V Hybrid Sport-L; stock
`PLE17159`, 2023 Ford Ranger XLT), both starting
`"description":"&ltb>Why BUY from Summit Subaru El Cajon?&lt/b>\n\n..."`.
The intended markup was `<b>...</b>`, but the dealer's authoring tool
entity-encoded only the opening `<` (and did so without the required
trailing semicolon: `&lt` instead of `&lt;`), leaving the closing `>`
completely unescaped.

`stripDescription` (`lib/models/transform_vehicle.dart`) already parses
descriptions with `package:html` (a real WHATWG-spec HTML5 parser) and
strips genuine tags via `.body?.text` — confirmed correct by directly
running it against the captured raw string: real literal tags later in the
same description (`<b>OTHER NOTABLE FEATURES...</b>`, `<h4>`, `<ul>`,
`<li>`) are parsed and stripped exactly as intended. The malformed
`&ltb>`/`&lt/b>` sequences are not real tags, so the parser correctly
treats them as literal text — decoding `&lt` to a literal `<` character
(entity decoding), which then stays as plain text rather than
retroactively becoming a new tag (HTML5 tokenization recognizes tags from
raw un-encoded `<` in the source stream, not from characters produced by
decoding an entity). The result: `<b>Why BUY...</b>` literally visible
on-screen, character for character.

This is **not a bug** in `stripDescription` — it is behaving exactly as
specified, and the reference React app (same `DOMParser`/`textContent`
approach, same WHATWG parsing rules) would show the identical artifact for
these same two listings. This spec is therefore an intentional
**deviation from strict parity**, added because it measurably improves the
submission's polish for a hiring-challenge audience, not because SPEC.md
or the reference app require it.

## Scope decision

Repair the general shape of the malformation — `&lt` immediately followed
by an optional `/` and one-or-more letters, then a literal `>` — rather
than hardcoding just the two tags observed (`b`, `i`). Confirmed on a
second listing (different vehicle, same dealer, same broken template) that
this is a systemic issue with Summit Subaru's description-authoring tool,
not a one-off typo on a single listing; a tag-specific fix would miss the
same malformation if it recurs with a different tag name elsewhere in the
feed (e.g. `strong`, `em`, `p`).

Explicitly out of scope:
- Repairing a hypothetical equivalent malformation of the *closing*
  bracket (e.g. `<b&gt;`) — not observed in any real data, and inventing a
  fix for an unobserved pattern is speculative over-engineering.
- Any change to how genuinely well-formed entities (`&lt;`, `&amp;`, etc.)
  are handled — the repair pattern requires the *absence* of the
  semicolon that a correctly-encoded entity would have, so real entities
  are never touched by this fix.
- Any change to `RawVehicle`, `InventoryApiClient`, or anything upstream
  of `transformVehicle` — this is purely a text-cleanup addition inside
  the existing sanitization pipeline.

## Implementation

New private helper in `lib/models/transform_vehicle.dart`, called at the
top of `stripDescription`, before the existing `\n`-stripping step:

```dart
/// Repairs a dealer-side authoring-tool bug seen in real Summit Subaru El
/// Cajon listings: only the opening `<` of a tag gets entity-encoded (and
/// without its required semicolon -- `&lt` instead of `&lt;`), while the
/// closing `>` is left as a literal character. A spec-compliant HTML
/// parser correctly treats the decoded `&lt` as literal text (not a new
/// tag), so without this repair the mangled tag survives as visible
/// on-screen text (e.g. `<b>Why BUY...</b>`) instead of being stripped
/// like the description's other, well-formed tags. Deliberately requires
/// no semicolon between `&lt` and the tag name, so genuinely well-formed
/// `&lt;` entities are left untouched.
String _repairMangledEntityTags(String text) =>
    text.replaceAll(RegExp(r'&lt(/?[A-Za-z]+)>'), '<\$1>');
```

`stripDescription` becomes:

```dart
String stripDescription(String raw) {
  final repaired = _repairMangledEntityTags(raw);
  final withoutEscapedNewlines = repaired.replaceAll(r'\n', ' ');
  final text = html.parse(withoutEscapedNewlines).body?.text ?? '';
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}
```

The repaired text flows through the existing `html.parse(...).body?.text`
step exactly like already-well-formed tags do, so it gets stripped the
same way — no change to the parsing/stripping logic itself, only to what
text it receives.

## Testing (TDD)

One new test in `test/models/transform_vehicle_test.dart`'s existing
"description sanitization" `group`, using the file's existing
`_raw(description: ...)` override helper (no fixture-file changes needed):

```dart
test('repairs a mangled entity-encoded tag (dealer authoring-tool bug) before stripping', () {
  final v = transformVehicle(
    _raw(description: r'&ltb>Why BUY from Summit Subaru El Cajon?&lt/b> Great car!'),
  );
  expect(v.description, 'Why BUY from Summit Subaru El Cajon? Great car!');
});
```

Mirrors the existing "strips tags and literal backslash-n from a real
description" test's assertion style (exact expected string, since the
input here is a controlled literal rather than a captured fixture).

## Docs

A short bullet added to `docs/SPEC.md`'s description-sanitization
section, documenting this as a deliberate, intentional deviation from
strict reference-app parity — so a future reader (or a reviewer diffing
behavior against the reference app) sees a documented choice, not an
overlooked inconsistency.

## Out of scope

- Closing-bracket entity mangling (unobserved).
- Any tag-name allowlist/denylist beyond "letters only" (already the
  narrowest pattern that covers all observed and plausible-future cases
  from this same dealer bug).
- Fixing this anywhere other than `stripDescription` — features, spec
  fields, and other string fields are not known to have this issue.

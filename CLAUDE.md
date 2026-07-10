# Workflow addendum — append to this project's CLAUDE.md

(This is project-specific, in addition to whatever the global ~/.claude/CLAUDE.md
already covers — communication style, commit conventions, etc. Don't duplicate
those here; this section is only the parts specific to this Flutter build.)

## Workflow: Spec → Plan → Task Loop → TDD → Dual Review

This project follows a strict per-task loop. Do not skip steps or shortcut them
under time pressure — ask me first if the timeline seems to require cutting a
step, don't cut it silently.

### 1. Spec verification (do this before anything else)

- `docs/SPEC.md` is the single source of truth for what to build.
- Before planning, cross-check SPEC.md against `docs/context/flutter-handoff.md`
  (the verified-against-code findings from the web version) and
  `docs/context/original-request.md` (the hiring contact's actual email
  instructions, verbatim). Fold in every correction from the handoff doc —
  the price-range-is-two-selects fix and all 8 undocumented behaviors it
  lists — before treating SPEC.md as final.
- Flag and resolve any contradiction between these three documents before
  moving to planning. Do not silently pick one source over another.

### 2. Implementation plan

- Written to `docs/superpowers/plans/<name>.md` — numbered tasks, each one
  independently completable and independently testable.

### 3. Per-task execution (TDD, no exceptions)

- Write the failing test first. Confirm it fails for the *expected* reason
  (not a typo or setup error) before writing any implementation.
- Implement the minimum needed to pass the test.
- Confirm the test passes, then move to confidence scoring below.
- Do not write implementation code before its test exists.

### 4. Confidence score (after implementation, not before)

- Once a task's implementation passes its own tests, write a confidence
  score (1–100) grounded in what actually happened during implementation —
  not a speculative pre-estimate. Cover:
  - What's uncertain about this specific implementation
  - What could fail downstream if something here is wrong
  - How that uncertainty could be verified
- **If confidence is below 90:** iterate on the actual implementation — fix
  the specific uncertain part, re-verify, re-score. **Maximum 3 iteration
  passes per task.** If still below 90 after 3 passes, stop and ask me
  directly — do not keep looping, and do not silently proceed anyway. Some
  uncertainty is a "new to this framework" problem, not a "try harder"
  problem, and needs a human decision.
- This writeup carries forward into the review stage below — it's a risk
  map telling the reviewer where to look hardest, not just a number.

### 5. Per-task review (two stages, after every single task)

- **Stage 1 — Spec compliance:** does the implementation match SPEC.md
  exactly? Flag drift in either direction — spec says X but code does Y,
  *or* code does something spec never mentioned (which then needs to be
  added back to SPEC.md, not just left undocumented).
- **Stage 2 — Code quality:** idiomatic Dart/Flutter conventions, naming,
  widget composition, avoiding unnecessary rebuilds, no dead code.
- Both stages read the task's confidence writeup and scrutinize whatever it
  flagged as uncertain most closely. **Either stage can independently lower
  a self-reported confidence score it disagrees with** — the score is a
  starting point for review attention, not something to rubber-stamp.
- Both stages produce a pass/fail with specific, named findings — never
  just "looks good" with no detail.

### 6. Learning-as-you-go (I'm new to Dart/Flutter — build this in, don't bolt it on)

- When a task introduces a concept I haven't used yet in this project (a new
  widget type, a Riverpod pattern, a Dart language feature, null safety
  syntax, etc.), add a short "New concept" note to that task's writeup —
  2–4 plain-language sentences, not a full tutorial.
- Append every one of these to `docs/LEARNING.md` as a running, dated log —
  don't just mention it once in a task and let it disappear. This becomes
  my actual reference material afterward.

### 7. Commit (last step, once the task is fully closed out)

- Per the global CLAUDE.md's Version Control section: `git init` is step
  zero for any project, and commits at each completed task are
  pre-authorized — don't ask each time.
- Commit once TDD + confidence score + both review stages + the LEARNING.md
  note are all done. One commit per task, message states what the task
  implemented and its confidence score.
- If a confidence-ideation pass (see the confidence score step above) adds
  tests or fixes after the task's initial commit, that's a separate
  follow-up commit — don't fold it into the original one after the fact.

### Scope discipline

- Only the tasks in the currently-approved implementation plan are in scope.
- Scope is full parity with the finished web app — SRP, VDP, caching,
  paging, and filtering — per `docs/context/original-request.md`'s scope
  decision and the approved `docs/SPEC.md`. None of these are deferred or
  optional; all of them are in scope for this build.
- The full weight of this process (TDD + dual review + confidence scoring)
  applies to all of the above, not a subset. If scope ever expands beyond
  what's in SPEC.md, say so explicitly rather than quietly absorbing more
  work into the same loop.

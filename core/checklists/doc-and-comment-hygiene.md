# Checklist: doc-and-comment-hygiene

Content-quality standard for comments and docstrings — distinct from `../auditors/*.md`, which
judge the *code*; this judges what the *prose about the code* claims. Tool-agnostic. Invoked by
`build` (self-check before handback), `build-audit`, `review`, and `review-audit` whenever the
artifact touches comments, docstrings, or repository documentation (`README.md`, `docs/*.md`), and
by `plan`/`plan-audit` for Tier 3 only — a plan
document has no code comments for Tier 1/2 to check, but is prose subject to the same Tier 3
judgment failures.

## Tier 1 — mechanical, hard-fail unless justified in writing

Run against changed lines only, on comment lines (`#…`), docstrings, and prose in
`README.md`/`docs/*.md`. Plain `grep` — every
environment running these roles already holds that tool grant, including CI's read-only `review`
(confirmed against its actual `--allowedTools` grant, which has `Bash(grep:*)` but no general Bash
or Python interpreter — a script would not run there, these commands will).

| Check | Command | Why | Verified against |
|---|---|---|---|
| Internal planning-doc reference | `grep -nE '\bplan-[0-9]+\b'` | Points outside the repo. | 4/4 known hits reproduced by two independent tools + plain grep. |
| Planning-unit jargon | `grep -nE '\bSlice [0-9]+\b'` (capital S only — lowercase "a top-k slice" is ordinary vocabulary) | Same. | 0 false positives on the one adversarial case in this repo (a review-prompt's own `"Slice 1, 2, 3"` example, confirmed to live in a YAML block-scalar, not a `#` comment — a whole-file, non-comment-scoped grep *does* false-positive on it, which is why scoping matters). |
| PR number | `grep -nE '\bPR ?#[0-9]+\b'` | Process narration, not a reason. | 2/2 known hits reproduced. |
| Em dash in a comment/docstring | `grep -n '—'` | This project's convention is ASCII `--` in code comments; **does not apply to `.md` files by default — see note below**. | 22/22 hits reproduced by two independent methods, after a first attempt under-counted this to 2 and the error was traced and fixed. |
| TODO/FIXME | `grep -nE '\b(TODO\|FIXME)\b'` | Take it to a tracked issue. | 0/0, no false positives possible on an absent pattern. |
| Commented-out code | `grep -nE '^\s*#\s*(import \|from \S+ import\|def \w+\(\|class \w+[:(]\|return[ (])'` | Dead code as a comment is never a comment. | 0/0 in the source case; kept as a standing check. |

**"clause N"** (`grep -nE '\bclause [0-9]+\b'`) is **flag-only**: might be defined nearby. Object
only if `grep -rn` for the term elsewhere in the tracked repo also comes up empty.

**Em dash in `README.md`/`docs/*.md` is not checked by default.** Documentation prose commonly has
its own em-dash convention, distinct from the ASCII-`--` convention above for code comments —
verified: this repo's own `README.md` (13 em dashes) and `core/README.md` (9 em dashes), and a
target repo's own `README.md` (14 em dashes) and `docs/design-notes.md` (37 em dashes), all use em
dash as the dominant prose style, with only one incidental ASCII `--` in `design-notes.md` against
its 37 em dashes — a single outlier, not a competing convention. Before applying this
check to a target repo's `.md` files, check that repo's own documented or observed doc convention
first; don't assume it must match the code-comment convention. Every other Tier 1 check above, and
all of Tier 2 and Tier 3 below, applies to `.md` prose exactly as it does to code comments — only
this em-dash check is carved out for docs.

## Tier 2 — flag-only, curated list required (do NOT ship a generic suffix pattern)

**US-spelling** and **ALL-CAPS emphasis** checks are real but broke twice under testing before a
working version was found:
- A `[sz]`-wildcard spelling pattern flagged `optimisation`/`tokeniser`/`initialised` — all
  **correct UK spelling** — as errors.
- A tightened `-iz-`-only pattern then flagged `synchronize`/`finalize` inside a GitHub Actions
  workflow file, where those are the **literal, unrespellable event/job-name vocabulary**, not
  prose, plus non-dual-spelling words like `oversized`/`sized` that happen to contain "iz".

**What worked, tested clean on every case above:** a finite, explicitly-named list of known
dual-spelling roots (`normali-`, `optimi-`, `tokeni-`, `initiali-`, `seriali-`, `categori-`,
`priorit-`, `summari-`, `characteri-`, `emphasi-`, `minimi-`, `maximi-`, `criticis/z-`, `apologi-`,
`customi-`, `reali-`, `recogni-`, `utili-` + `z\w*`), **excluding anything inside a backtick code
span** (`` `identifier` `` is a reference, not a spelling choice). Maintain the list per-repo — a
project's own domain vocabulary or CI-tool vocabulary can legitimately overlap with these roots
(as `synchronize`/`finalize` did here), and only a human/LLM read catches that, a regex can't.

**ALL-CAPS emphasis** (`\b[A-Z]{3,}\b` excluding an explicit SQL-keyword/acronym allowlist) is
lower-precision for the same reason — build the allowlist from what's actually in the target repo
first (SQL keywords, HTTP/API/CMS-style acronyms, named constants), not from a generic guess.

**Treat both as flag-only**: a hit gets a human/LLM read before any edit, never an automatic fix.

## Tier 3 — judgment-only, no mechanical check exists

- **Every factual claim in a changed comment**: read the code it describes and confirm — don't
  take the comment's word for its own accuracy.
- **"See X for why/what" pointers**: read the target. A pointer whose target only has *what*, when
  the pointer promises *why* (or vice versa), is broken even though the target file is real.
- **Cross-file `file:line` citations**: a citation can point at a range that *exists* and is
  *superficially relevant* while still misdirecting a reader — a pure existence check is not
  enough (confirmed on a real case: a citation to a 3-line range that included the right decorator
  at its very edge, while the citation's own justifying words actually matched two *different*,
  uncited lines). Read both ends and compare meaning, don't just check the range resolves.
- **Deduplicating a repeated explanation**: check whether the "duplicate" is independently required
  first — e.g. a Pydantic model's docstring can be served in a live `/openapi.json` schema even
  though it reads like a plain internal comment.
- **The epistemic-marker trap** ("verified", "measured", "confirmed"): never strip on sight. Ask:
  is the sentence it modifies reconstructible by reading the code (safe to soften), or the *only
  record* of an empirical/mutation-test result (must be kept)?
- **Verbosity**: trim prose fat, never a distinct fact or caveat.

## How each role uses this

- **`build`**: self-check Tier 1 (and Tier 2 if touching CI/config files) against your own diff
  before handing back.
- **`build-audit` / `review` / `review-audit`**: run Tier 1 independently, walk Tier 2 and Tier 3
  against every changed comment, docstring, or documentation file, cite `file:line` + checklist item.
- **`plan` / `plan-audit`**: Tier 3 only — no code comments in a plan document, so Tier 1's
  mechanical greps and Tier 2's spelling/ALL-CAPS lists don't apply. `plan` self-checks Tier 3
  against its own document before handing back; `plan-audit` walks Tier 3 independently.

## Loop

No new loop — findings here are ordinary `REVISE` objections inside `../shared/audit-loop.md`.

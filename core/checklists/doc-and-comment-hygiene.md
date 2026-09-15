# Checklist: doc-and-comment-hygiene

Content-quality standard for comments and docstrings — distinct from `../auditors/*.md`, which
judge the *code*; this judges what the *prose about the code* claims. Tool-agnostic. Invoked by
`build` (self-check before handback), `build-audit`, `review`, and `review-audit` whenever the
artifact touches comments, docstrings, or repository documentation (commonly `README.md`/`docs/*.md`,
but check the target repo's own layout first — e.g. this repo alone has 5 files named `README.md`
(root, `core/`, `mcp/`, `adapters/`, `adapters/claude-code/`) and no `docs/` directory at all, so a
literal `README.md`/`docs/*.md` pattern misses most of its own documentation), and
by `plan`/`plan-audit` for Tier 3 only — a plan
document has no code comments for Tier 1/2 to check, but is prose subject to the same Tier 3
judgment failures.

## Tier 1 — mechanical, hard-fail unless justified in writing

Run against the target repo's tracked source files, using its own language extensions (adjust the
`--include=` globs below — e.g. this repo's tracked types are `.md` (31 files), `.sh` (8), and
`.yml` (2) — zero `.py`). Plain `grep`
— every environment running these roles already holds that tool grant, including CI's read-only
`review` (confirmed against its actual `--allowedTools` grant, which has `Bash(grep:*)` but no
general Bash or Python interpreter). Each command needs a path/include argument to actually search
the repo — e.g. `grep -rnE '\bplan-[0-9]+\b' --include='*.md' --include='*.sh' --include='*.yml' .`
— the bare pattern-only form in the table below reads stdin, not the repository, if copied as-is.
"Changed lines only" IS achievable: `Bash(git diff:*)` and `Bash(grep:*)` are both granted
separately, and this harness checks each pipeline segment against the allowlist independently —
verified live in CI by piping `git diff <base> <head> | grep -nE 'pattern'`, which succeeded, while
a pipeline containing an ungranted command (e.g. `sed`) was refused naming specifically that
segment, not the pipe itself. Example: `git diff <base> <head> | grep -nE '\bplan-[0-9]+\b'` —
filter by pathspec only if you already know which file types changed (e.g. `-- '*.md'`); the bare
form works regardless of what changed. (Based on two live CI observations, not on reading the
harness's own permission-parsing source code, which is outside this repository.)

| Check | Command | Why | Verified against |
|---|---|---|---|
| Internal planning-doc reference | `grep -nE '\bplan-[0-9]+\b'` | Points outside the repo. | 4/4 known hits (unverified from this checkout, per `../shared/verify.md`) in `crop-cms-backend@0d69c51` (that repo's pre-cleanup main — its own comment-hygiene cleanup, merged as commit `59f01ab` on 2026-09-14, has since cleaned this up, so re-running these greps against its *current* main now returns 0, not these numbers) reproduced by two independent tools + plain grep. |
| Planning-unit jargon | `grep -nE '\bSlice [0-9]+\b'` (capital S only — lowercase "a top-k slice" is ordinary vocabulary) | Same. | Adversarial case (unverified, same as above) in the sibling `crop-cms-backend@0d69c51` project's review-prompt (pinned, see above; NOT this repo — `agentic-workflow` has no numbered-slice example anywhere, confirmed via `grep -rn 'Slice [0-9]' .` (returns only this line's own citation)): its `"Slice 1, 2, 3"` example lives in a YAML block-scalar, not a `#` comment, so a comment-scoped check correctly skips it while a whole-file grep does not — which is why scoping matters, even though this repo has no live example of that specific case. |
| PR number | `grep -nE '\bPR ?#[0-9]+\b'` | Process narration, not a reason. | 2/2 known hits (pinned, unverified — same as above) reproduced. |
| Em dash in a comment/docstring | `grep -n '^\s*#.*—'` | Check the target repo's own convention first — see note below (this check must not be applied blind). **Does not apply to `.md` files by default — see note below**. | 22/22 hits (pinned, unverified — same as above) reproduced by two independent methods, after a first attempt under-counted this to 2 and the error was traced and fixed. |
| TODO/FIXME | `grep -n -e TODO -e FIXME` | Take it to a tracked issue. | 0/0, no false positives possible on an absent pattern. |
| Commented-out code | `grep -nE -e '^\s*#\s*import ' -e '^\s*#\s*from \S+ import' -e '^\s*#\s*def \w+\(' -e '^\s*#\s*class \w+[:(]' -e '^\s*#\s*return[ (]'` | Dead code as a comment is never a comment. | 0/0 in the source case; kept as a standing check. |

**The `plan-N`/`PR#`/`Slice` rows above share the same lack of comment-anchoring as the em-dash row
did before the fix** — none of their regexes require a `#` prefix either. Verified: in this repo,
`--include='*.sh' --include='*.yml'` hits for each of `\bplan-[0-9]+\b`, `\bPR ?#[0-9]+\b`, and
`\bSlice [0-9]+\b` are all zero whether or not the pattern is comment-scoped, so only the em-dash
row needs the fix now — but a repo where one of these strings appears outside a comment (e.g. in a
string literal) would expose the same latent gap.

**Every `crop-cms-backend` citation in this table is pinned to `crop-cms-backend@0d69c51`** (that
repo's pre-cleanup main — see the "Internal planning-doc reference" row above for the full context
on why it's pinned, not left as a bare `main` reference).

**"clause N"** (`grep -nE '\bclause [0-9]+\b'`) is **flag-only**: might be defined nearby. Object
only if `grep -rn` for the term elsewhere in the tracked repo also comes up empty.

**Em dash in `README.md`/`docs/*.md` is not checked by default.** Documentation prose commonly has
its own em-dash convention, distinct from the ASCII-`--` convention above for code comments —
verified: this repo's own `README.md` (16 em-dash characters across 13 lines that contain at least
one — `grep -c` counts matching lines, `grep -o PATTERN file | wc -l` counts true occurrences; use
the latter when precision matters) and `core/README.md` (9, both methods agree there), and
`crop-cms-backend@0d69c51`'s own `README.md` (16 em-dash occurrences across 14 lines) and
`docs/design-notes.md` (39 em-dash occurrences across 37 lines) (pinned, unverified — same as above), all use em dash
as the dominant prose style, with only one incidental ASCII `--` in `design-notes.md` against
its 39 em dashes — a single outlier, not a competing convention. Before applying this
check to a target repo's `.md` files, check that repo's own documented or observed doc convention
first; don't assume it must match the code-comment convention. Every other Tier 1 check above, and
all of Tier 2 and Tier 3 below, applies to `.md` prose exactly as it does to code comments — only
this em-dash check is carved out for docs.

**The same caution applies to code comments, not only `.md` prose.** `crop-cms-backend`'s
(pinned, unverified — same as above) code comments use ASCII `--` (this checklist's origin). This repo's own code comments
(`agentic-workflow`) use the *opposite* convention — em dash outnumbers ASCII `--` 47:13 in its
`.sh`/`.yml` files (`grep -rn '^\s*#.*—' --include='*.sh' --include='*.yml' .` vs the same pattern
with ` -- ` in place of `—`). Applying this check to a repo without first confirming its real
convention will hard-fail dozens of pre-existing, correct lines. Read a sample of the target
repo's own comments before applying this row at all.

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
`prioriti-`, `summari-`, `characteri-`, `emphasi-`, `minimi-`, `maximi-`, `critici-`, `apologi-`,
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

- **`build`**: self-check Tier 1 against your own diff before handing back.
- **`build-audit` / `review` / `review-audit`**: run Tier 1 independently, walk Tier 2 and Tier 3
  against every changed comment, docstring, or documentation file, cite `file:line` + checklist item.
- **`plan` / `plan-audit`**: Tier 3 only — no code comments in a plan document, so Tier 1's
  mechanical greps and Tier 2's spelling/ALL-CAPS lists don't apply. `plan` self-checks Tier 3
  against its own document before handing back; `plan-audit` walks Tier 3 independently.

## Loop

No new loop — findings here are ordinary `REVISE` objections inside `../shared/audit-loop.md`.

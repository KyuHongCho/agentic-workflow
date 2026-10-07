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
judgment failures. `build` also applies the Comment budget below *while writing*, not only when
it self-checks.

## Comment budget — the default is no comment

A comment earns its place only by saying **why**: a reason the code cannot show (a constraint, a trap,
a lock or ordering requirement, a security or timing concern, a non-obvious decision). Anything else
is deleted, not trimmed.

- **No comment is the default.** Names, small functions and tests say *what*. Do not narrate steps,
  restate a name, list the order of checks the code already shows, or explain a line to a reader who
  can read it.
- **One line is the norm; 2-3 lines is the hard maximum** for a comment or a docstring body. A reason
  that needs more belongs in the plan, the PR description or a test name; the code is likely doing too much.
- **Docstrings:** a one-line summary of what the unit is for, plus the why only if it is not obvious,
  inside the same cap. A docstring that FastAPI or pydantic serves in the OpenAPI schema is product
  text: keep it, but keep it short.
- **Existing comments are not a style to match.** "Match existing style" covers naming and structure,
  never comment length or density: a codebase full of long comments does not license another one.
- **No process or history** (who, when, which plan or PR, "added for", "previously").
- **A result worth keeping** (a measurement, a mutation outcome) goes in a test name, an assertion
  message or the PR description; a comment holds it only within the 3-line cap.
- **Exempt, neither counted nor deleted:** tool directives and pragmas (`# noqa`, `# type:`,
  `# pragma`, `eslint-disable`, `# fmt: off`), shebang and encoding lines, licence headers, and
  generated files.

## Tier 1 — mechanical, hard-fail unless justified in writing

Run against the target repo's tracked source files, using its own language extensions (adjust the
`--include=` globs below — e.g. this repo's tracked types are `.md`, `.sh` and `.yml` — zero
`.py`). Plain `grep`
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
| Em dash in a comment/docstring | `grep -n '^\s*#.*—'` | Check the target repo's own convention first — see note below (this check must not be applied blind). **Does not apply to `.md` files by default — see note below**. | 22/22 hits (pinned, unverified — same as above) reproduced by two independent methods. |
| TODO/FIXME | `grep -n -e TODO -e FIXME` | Take it to a tracked issue. | 0/0, no false positives possible on an absent pattern. |
| Commented-out code | `grep -nE -e '^\s*#\s*import ' -e '^\s*#\s*from \S+ import' -e '^\s*#\s*def \w+\(' -e '^\s*#\s*class \w+[:(]' -e '^\s*#\s*return[ (]'` | Dead code as a comment is never a comment. | 0/0 in the source case; kept as a standing check. |
| Comment block over 3 lines | The two commands below the table. | Over the Comment budget: `REVISE` for `build-audit`, a `(nit)` for `review`. | GNU grep 3.12 in an `ubuntu` container, fixtures (header, directives, 3 vs 4 lines, EOF, CRLF, grown comment), each command run in a bare `sh -c`. Not run in CI. |

```sh
# diff (default for a PR): blocks whose every line was added
git diff <base> <head> -U0 | grep -Pzo '(?m)(^\+[ \t]*#(?!!|[ \t]*(?:noqa|type:|pragma|fmt:|pylint|isort|mypy|-\*-|coding[:=]|vim?:|eslint|prettier|@ts-|istanbul|nolint))[^\r\n]*\r?(?:\n|\z)){4,}'
# whole file (secondary): one changed file, never `-r .`
grep -Pzo '(?m)\A(?=(?:[ \t]*#[^\n]*\n)*?[ \t]*#[^\n]*(?:Copyright|Licen[sc]e|SPDX))(?:[ \t]*#[^\n]*\n)+(*SKIP)(*F)|(^[ \t]*#(?!!|[ \t]*(?:noqa|type:|pragma|fmt:|pylint|isort|mypy|-\*-|coding[:=]|vim?:|eslint|prettier|@ts-|istanbul|nolint))[^\r\n]*\r?(?:\n|\z)){4,}' path/to/changed.py
```

Each is one self-contained invocation (no shell variable: an empty one makes the lookahead
never match, a silent false negative), so it fits `Bash(git diff:*)` / `Bash(grep:*)`. Needs GNU
`grep -P`; macOS's BSD grep rejects it. `-z` prints the block, not a line number: locate it with
`grep -nF '<its first line>' <file>`. For `//` comments replace `#` with `//`. Not covered:
`/* */`, `--`, `<!-- -->` (read them). Directive lines (`noqa`, `type:`, shebang, ...) end a block,
so a directive inside a long comment splits it and evades the check. The whole-file form skips a
leading block only if it contains Copyright, License, Licence or SPDX; any other leading block is
checked. False positives: a `#` block inside a string or docstring, a 4+ line `# ----` banner, and
in the diff form a newly added licence header (skip it by eye). The diff form misses a comment that *grew* past 3 lines (old lines are context): use the whole-file form.

The block check counts **length only**. A 1-3 line comment that merely restates the code passes it,
and is caught by the "Why-only" item in Tier 3. Docstring length has **no reliable grep**: a regex
that pairs `"""` delimiters matched a closing delimiter with the next docstring's opening one (tested:
two one-line docstrings with five code lines between them were reported as one block), so read the
docstrings. "Docstring" here means any doc comment (Python `"""`, JSDoc `/** */`, Rust `///`).

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
first; don't assume it must match the code-comment convention. Every other Tier 1 check above
except the comment-block row, and all of Tier 2 and Tier 3 below, applies to `.md` prose exactly as
it does to code comments — only the em-dash and comment-block checks are carved out for docs (a `#`
there is a heading or a code-fence comment).

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
  record* of an empirical/mutation-test result (must be kept, within the Comment budget's
  3-line cap or in a test name or the PR description)?
- **Why-only** (code comments and docstrings): for every changed comment ask *if I delete it, does a
  reader of the code lose a reason?* If not, it is a finding, whatever its length: a 1-line comment
  that restates the next line, a step-by-step narration, a comment that repeats a name. A comment
  over 3 lines is a finding even when every sentence is true. Cite `file:line` and quote the line.
- **Verbosity in documentation prose**: trim prose fat, never a distinct fact or caveat. (Code
  comments follow the Comment budget, which is stricter.)

## How each role uses this

- **`build`**: write to the Comment budget (default: no comment), and self-check Tier 1, including
  the comment-block row, against your own diff before handing back.
- **`build-audit` / `review` / `review-audit`**: run Tier 1 independently, walk Tier 2 and Tier 3
  against every changed comment, docstring, or documentation file, cite `file:line` + checklist item.
  Every comment over the budget or not why-only is an objection (`build-audit`) or a nit finding
  (`review`); `review-audit` lists one the review missed under *Missed by the review*.
- **`plan` / `plan-audit`**: Tier 3 only — no code comments in a plan document, so Tier 1's
  mechanical greps and Tier 2's spelling/ALL-CAPS lists don't apply. `plan` self-checks Tier 3
  against its own document before handing back; `plan-audit` walks Tier 3 independently.

## Loop

No new loop — findings here are ordinary `REVISE` objections inside `../shared/audit-loop.md`.

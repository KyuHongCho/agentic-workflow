# Skill: explain-codes

**One-line:** Explain a change, file, or feature in plain language for a novice or non-developer
reader — verified against the live code, with visual aids and background on the tools involved.

## When to use
- The human runs `/explain-codes`, or asks in any words to have code, a change, or a feature
  explained — especially "for a novice," "for someone non-technical," "walk me through," "how do
  these files work together."
- **If the human already named an explicit, unambiguous target** — a specific file, folder,
  function, PR, or feature — use it directly; that naming *is* the confirmation, so step 0 below is
  not needed.
- **If no target was named, never pick one silently — always confirm it with the human first**, per
  step 0 below. A likely default (the current uncommitted change, or the most recent commit/PR if
  the tree is clean) is a *candidate to offer*, not a choice to make on the human's behalf.
- If the environment offers no repository or file access at all, and no code has been pasted into
  the conversation, ask the human to paste the relevant code or name the exact file(s) — never
  invent a target.

## Inputs
- The target — either named explicitly by the human, or confirmed with them in step 0 below.
- Read/search access to the repository, and — where the environment offers one — a way to run
  commands (tests, a REPL, a linter) and to check external documentation. Degrade gracefully where
  any of these is missing (see *When to use*'s last bullet).

## Process

0. **Identify candidates and confirm the target — mandatory whenever none was explicitly named.**
   Look at the repository's current state cheaply (e.g. is there an uncommitted diff; what was the
   most recent commit or open PR; what files does that touch) to build 2–4 concrete, named
   candidates — for example "the current uncommitted change (touches `x.py`, `y.py`)," "the most
   recent commit/PR (`<title>`)," or a specific file/feature visible in that state. **Present these
   to the human as a structured choice**, using whatever the environment provides for one (a
   multiple-choice prompt is preferred; clearly labelled numbered options in plain text if no such
   mechanism exists). Mark the most likely candidate as recommended, but **wait for the human's
   actual answer before scanning or explaining anything** — a computed default is an option to
   offer, never a choice to make silently on the human's behalf. Skip this step only when the human
   already named an explicit, unambiguous target in their request (see *When to use*).

   **Whole repository or a broad target** (the whole repo, or more features than one answer can
   cover at full depth): do not start explaining it in one pass. Ask which shape they want, as
   another structured choice — for example **feature by feature** (one feature per answer, in an
   order they pick), **a layered architecture map** (how the parts connect, no line-level detail),
   or **a one-page summary of the whole repo**. Then continue from the chosen shape; a feature
   picked from the list is an ordinary target.

   **Depth.** Ask it in the same prompt as the target, whenever step 0 runs: **overview**
   (what each part is for), **per-file walkthrough**, or **line by line** (step 2 as written).
   **Line by line is the default** and is marked recommended; a lighter depth applies only when the
   human picks it (or asks for it in their own words), and then step 2 is scaled to it while the
   file paths, line numbers, and step 5's grounding rules still apply to everything stated. When
   the human named the target explicitly, step 0 is skipped and the depth is line by line unless
   they said otherwise.

1. **Scan fresh, every time.** Before writing a word of explanation, re-read the actual current
   state of every file in the confirmed target, using whatever the environment provides for it (a
   file-read/search capability, a repository browser, a shell). Never rely on a memory of the file
   from earlier in the conversation, from training data, or from an earlier run of this skill — code
   changes, and your last look at it may not be the current one. If the target is a change, get the
   actual diff and the actual current contents on both sides — not a paraphrase of either. Where the
   environment can run something (tests, a script) and a claim you're about to make is checkable
   that way, check it — see `../shared/verify.md`'s standard: evidence over reasoning. Note the real
   current date/time from the environment before calling anything "recent" or "current."

2. **Explain each file in scope, line-by-line, with file paths and line numbers — the default
   depth; mandatory unless the human chose a lighter one in step 0.** For every file:
   - State its path and whether it is new, modified, or unchanged-but-referenced (context the reader
     needs but that isn't itself part of the change).
   - Give its one-line job in plain English, then a short analogy for a non-technical reader.
   - **New or modified files: go through every substantive line, in order, line-by-line.** Group only
     lines that form one atomic statement (e.g. a multi-line function call or a single `if` block) —
     never silently skip a line that does real work just to save space. **Every line-level claim must
     cite that exact file's path and exact line number(s)** — never describe "the code" or "this
     function" without pinning it to a path and a line (or line range) you just read in step 1.
   - **Unchanged-but-referenced files: the same path+line-number rule applies to whatever excerpt you
     quote** — full line-by-line coverage of the whole file is not required here, only of the part you
     cite.
   - **Every new or modified file must carry a before/after comparison — code blocks with file path
     and line numbers on both sides, reconstructed from a real diff, never remembered or guessed —
     plus a plain-language sentence stating what changed and why it matters.** Two code blocks with
     no stated explanation of the difference does not satisfy this; the reader must never be left to
     spot the diff themselves. If the "before" state no longer exists at those same line numbers (the
     file has grown or shrunk since), say so rather than presenting a stale line number as current.
   - Define every piece of jargon the first time it appears — a technical term, an acronym, a
     pattern — with a plain-language analogy. Assume the reader may be a complete non-developer, and
     assume nothing explained earlier in the conversation is still remembered: this skill's output
     should stand alone.

3. **Show how the files work together, visually.** Describe the actual end-to-end sequence (a
   request, a command, a build step) in the order it really executes, and produce at least one
   visual aid in plain text/Markdown only — a table, or a box-and-arrow / tree diagram built from
   ASCII or Unicode box-drawing characters. Never an image file or a diagramming syntax the reader's
   tool may not render. Pick whichever of these actually fits the material — do not force one where
   the material has no such structure:
   - A **summary table**: file → new/modified → one-line job → analogy.
   - A **sequence diagram**: which file calls into which, in order.
   - A **structure/relationship diagram**: e.g. how data records relate, a directory map, a layered
     architecture.
   - A **before/after comparison table** where an old approach was replaced by a new one.

4. **Explain the tools and technology stack involved.** For every named tool, library, language
   feature, protocol, or platform the code in scope actually uses:
   - What it is, in one or two plain sentences, and what concrete problem it solves ("without this,
     you'd have to ___").
   - A plain-language analogy.
   - **How it concretely shows up in this codebase** — a real file and line reference, not a generic
     description disconnected from the actual code in scope.
   - Where three or more tools sit layered on top of one another, prefer a layered "stack" diagram
     (step 3) so the reader sees where each one fits.

5. **Ground every claim.**
   - A claim about what *this repository's own code* does: verified in step 1 (you read it, or ran
     it) — cite the file and line.
   - A claim about a *third-party tool or library's* general behaviour: prefer checking it against
     that tool's own published metadata or official documentation where the environment can reach
     it; otherwise say plainly that it rests on general knowledge, and rate your confidence
     (Accuracy: High / Medium / Low) rather than stating it as flatly certain.
   - Never state a specific version, exact behaviour, or line number you have not just re-read or
     reproduced. If unsure, say so — do not fill the gap with a plausible-sounding guess.
   - If verifying something required a temporary file, script, or code change: remove or revert it
     before finishing, and say in the final output what you created/changed and that it was cleaned
     up — per `../shared/verify.md`.

6. **Four mandatory closing checks, run explicitly, in order, before submitting.** Do not skip these
   and do not silently apply corrections without saying so:
   1. **Fact-check and proofread the explanation again.** Re-open every file you cited once more and
      confirm the line numbers, quoted code, and claims still match exactly what's on disk right
      now — not what you drafted earlier in this same response. Fix anything wrong.
   2. **Double-check whether anything is missing.** Every file in scope covered, at the chosen depth
      (line-by-line unless the human picked a lighter one), with a
      path and line number(s) on every line-level claim (step 2)? Every new or modified file carrying
      both a before/after comparison *and* a stated explanation of what changed, not just two code
      blocks? Every tool named in the code explained? Any jargon used but never defined? Any visible
      relationship (a foreign key, a call, a dependency) the explanation skips? Add whatever's missing.
   3. **If nothing needed correcting in checks 1–2, say so explicitly** in the final output (e.g.
      "Re-checked against the current files — no corrections needed") — don't stay silent about
      having checked, and don't manufacture a change just to look like you did something.
   4. **Make sure every explanation's status is correct, up to date, and current.** Anything
      described as "not yet built," "in progress," "the current behaviour," or "as of now" must
      reflect what step 1's fresh scan actually showed, not an assumption carried from earlier in
      the conversation or from how the code "usually" looks. If time has passed since step 1 (a long
      response, or other work ran in between), re-confirm anything time-sensitive before finalizing.

## Produces
A plain-Markdown explanation: headings, tables, and text-based diagrams as in step 3 — no
dependency on image rendering, a specific chat UI, or a diagramming extension, so it reads correctly
in a terminal, an editor's chat panel, or a browser. Plain language throughout — a working
non-developer should follow the whole thing without looking anything up.

## Cross-cutting (shared skills)
- **Ground every claim empirically per `../shared/verify.md`** — see step 5 above.
- This skill does not change code and is not a role or an auditor — it does not enter the
  `plan ↔ plan-audit` / `build ↔ build-audit` / `review ↔ review-audit` loop, and produces no
  handoff record.

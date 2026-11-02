---
name: playtest
description: Use when Jarrad reports how something played, felt or broke (playtest notes, bugs, "the radar is too small", "missiles feel weak"), including rough notes typed from his phone.
---

# Process playtest notes

1. Sort each note into one of:
   - **Bug** — behaviour contradicts the spec. Fix it on the current branch (follow the `milestone` skill's build steps, including a regression test where the logic is testable).
   - **Tuning** — a number feels wrong. Change the JSON data only, never code, and say which file and value changed and by how much. Hot-reload (D8) means Jarrad can retest without restarting.
   - **Design change** — the spec itself should change. Do not implement yet; hand over to the `design` skill and confirm with Jarrad.
2. Repeat back the sorted list before acting if any note is ambiguous.
   - Fix the quick notes first and commit them.
   - If a note turns out not to be quick, follow the check-in rule in the `start` skill's standing behaviours. That is, a note taking more than about 30–45 minutes, a second failed approach, or a cause that's a design constraint rather than a bug. Stop and offer Jarrad fix now, polish pass or a different approach, with a recommendation, instead of iterating silently.
3. Log the session in `docs/devlog.md` under today's date: notes received, what was fixed/tuned, what became a spec change.
4. When Jarrad says the milestone is good: run `python tools/check.py`, merge the branch into `main` with a merge commit, push, and tick the milestone in the current phase's spec (`docs/phase2-spec.md`).

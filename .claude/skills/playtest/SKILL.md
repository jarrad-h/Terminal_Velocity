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
3. Log the session in `docs/devlog.md` under today's date: notes received, what was fixed/tuned, what became a spec change.
4. When Jarrad says the milestone is good: run `python tools/check.py`, merge the branch into `main` with a merge commit, push, and tick the milestone in `docs/spec.md`.

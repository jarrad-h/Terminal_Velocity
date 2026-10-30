---
name: design
description: Use when Jarrad wants to discuss, change or add game design (new features, requirement changes, scope questions) for Terminal Velocity, before any code is written.
---

# Design session

Design lives in the current phase's spec: `docs/phase2-spec.md` (Phase 2), with `docs/spec.md` holding the Phase 1 requirements it builds on. Decisions live in `docs/decisions.md`. This skill replaces the old "discuss in claude.ai, paste into Claude Code" loop.

1. Read `docs/phase2-spec.md`, `docs/spec.md` and `docs/decisions.md` in full before answering.
2. Talk it through. Offer options with trade-offs when the choice is genuinely open; recommend one. Reference EV Nova behaviour where it helps, but Terminal Velocity is not a 1:1 copy.
3. Do not edit code in this skill. If the conversation drifts into implementation, finish the design point first.
4. When Jarrad agrees to a change:
   - Edit the spec that owns the requirement: Phase 2 groups (TR, TM, PS, SV, EC, OF, MS, PR, and D11 onward) in `docs/phase2-spec.md`; Phase 1 groups (F, B, L, C, A, G, S, H, V, D1–D10) in `docs/spec.md`. Use the existing ID scheme. New IDs take the next number in their group. Never renumber or reuse an ID; mark dropped ones `~~D7~~ (dropped YYYY-MM-DD: reason)`.
   - If it moves work between milestones, update the Milestones section.
   - Append an entry to `docs/decisions.md` (date, decision, why, alternatives rejected).
5. Show a short diff summary of what changed in the spec, then commit with message `spec: <summary>`.

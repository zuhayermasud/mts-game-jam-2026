# CLAUDE.md

Godot 4 jam game for MTS Game Jam 2026 (theme "Borrowed Time"). Deadline **2026-10-30**. Solo dev (a graphic designer who does all the art) + Claude (all code and audio).

## Read when relevant
- `SPEC.md`: the full game design (rules, numbers, layout, art pipeline, status). **Read it before any gameplay, UI or art work.**
- `ASSETS.md`: art and audio checklist and naming.
- `README.md`: jam brief and judging criteria.

## Tech
- Godot 4, 2D, **GDScript only** (web export). **720×900 (4:5)**, embedded at 640×800 on itch. HTML5 build for itch.io, mouse only.
- Gameplay numbers live in one config resource, never hard-coded.
- Art goes in `assets/` as 2× PNG with snake_case names and replaces grey-box placeholders that have the same name.

## Working rules
- Execution over ambition. If a feature threatens the deadline, cut it.
- Feature freeze at the **end of 2026-10-27**. After that: polish, playtesting, bugs and submission only.
- **Tint in code, don't redraw:** greyscale sprites coloured with `modulate`.
- **Juice in code:** tweens for squash and stretch, bobbing and shake.
- One shared Godot `Theme` for all UI.
- Animations never block input.

## Patterns that win
1. **The theme *is* the verb.** It's something the player does every few seconds, not a HUD timer.
2. **Execution beats literalness.** Overall winners were #1 in presentation, audio and fun, not in Theme.
3. **Pressure that causes mistakes > pressure that just ends the game.**
4. **Trade-offs are the hook:** spend now, pay later (time-as-health, time-as-currency, borrowing with interest).
5. **Reinterpreting the word stands out.**
6. **Presentation counts.** A browser build, a nice itch page and a clean square game frame.

## Patterns that fail
- Generic countdown timer + regular game. It's the most common time-theme submission.
- Rewind or time travel with no twist. It's common and bug-prone (you have to record and restore state).
- Story-only games with weak gameplay. They score low on Fun and Repeatability.
- Too many mechanics (time-stop + rewind + slow-mo means none of them gets polished).
- Unclear punishment. If players don't know *why* they lost time, the trade-off doesn't land.
- No audio. Sound Design is 1 of 10 criteria.

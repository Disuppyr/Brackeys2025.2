# Frontier Fortuna / "Risk It for the Biscuit"

Godot 4.4.1 project, originally built for Brackeys Game Jam 2025.2 (theme: "Risk it for the biscuit"). The jam build is complete; current work is post-jam expansion (deepen core systems, add levels, polish, prep for release).

## Read these first, in order

1. **[docs/GDD.md](docs/GDD.md)** — the living design doc. Every system section has an "Implemented" note describing what's actually in code (not just designed), updated as work lands. Has a list of open design questions still unresolved. **This is the source of truth for what's real vs. planned.**
2. **[docs/TUNING.md](docs/TUNING.md)** — every tunable value in the project (movement, combat, dash, per-character/per-enemy stats, Stardom/Reputation constants, HUD colors, Stage Fortune magnitudes) with a description of what it controls and which file to edit. Also documents a few pre-existing bugs it surfaced along the way (not all fixed — see below).
3. The phase/round plan docs, in the order the work happened: **[docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md)** (Phases 0–5: Stardom, Reputation Actions, Results/Endings, manual combat, branching missions) → **[docs/POLISH_PLAN.md](docs/POLISH_PLAN.md)** (first playtest pass: hit feedback, HUD, AI) → **[docs/COMBAT_REWORK_PLAN.md](docs/COMBAT_REWORK_PLAN.md)** (second playtest pass: dash, Bonnie's lasso rework, particle bullets, standalone-testing fix). Each is marked done/status at the top. Mostly useful for *why* a decision was made, not just *what* — TUNING.md and GDD.md are the faster references for *what exists now*.

## Current state (as of this session)

**Working end-to-end:** Main Menu → Character Select → Camp (Fortune Cookies, Reputation Actions, Gravy) → Stage (Desert/Train/County Jail, branching via drawn Stage Fortune) → Results → loop back to Camp or a Wish Granted/Defeat/Jail ending. Manual combat (Attack/Special/Heal/Item/Dash) for the player; allies and enemies have their own AI (targeting, retreat/flee, ability use, reactive dash, separation).

**Explicitly NOT done, don't assume otherwise:**
- Train, County Jail, and the Witches enemy are **placeholder art** (flat-color backgrounds with an on-screen "PLACEHOLDER" label; Witches uses a tinted placeholder shape) — functional and headless-verified, but not real assets. Reskin-ready per the notes in `docs/IMPLEMENTATION_PLAN.md` Phase 5.
- Ally healing only targets **self**, never other party members — no ally-targeting detection exists yet.
- No invincibility frames on Dash — it's repositioning-only, by explicit choice, not an oversight. Revisit if it doesn't read as a real "dodge" in play.
- Two known-but-unfixed pre-existing issues, documented in `docs/TUNING.md` rather than fixed (out of scope when found): `EntityAttributes.attack_power` is set on every character/enemy but never actually read when damage is calculated; Lawman's `follow_range` is unset (defaults to `0.0`), so it can only attack from nearly point-blank.
- Phase 6 (tutorials, main menu polish, settings, save/load, remaining music/SFX) — not started at all.

**Bonnie's lasso** went through several iterations this session (broken rope → invisible due to a z-index bug → left-facing offset bug → wrong size/position). All fixed and documented in `docs/TUNING.md`'s Bonnie's rope/loop sections — worth reading those two entries specifically before touching that attack again, since the fixes are subtle (world-space-vs-local-space offset ordering, sibling draw order vs. z_index).

## Uncommitted work

**Nothing from this session has been committed.** `git status` will show ~30 modified files and ~11 new files (new scripts: `camera_shake.gd`, `damage_number.gd`; new scenes: `witch.tscn`, `rose_attack.tscn`, `train_stage.tscn`, `county_jail_stage.tscn`, `TrainBackground.tscn`, `CountyJailBackground.tscn`, `damage_number.tscn`; the `docs/` folder itself; this `CLAUDE.md`). All of it is headless-verified (`godot.exe --headless --path . res://<scene> --quit`, no script errors) but **not manually playtested for this exact final state** — the last hands-on playtest was mid-way through the Bonnie lasso fixes.

If picking this up fresh: check `git diff`/`git status` first, or just ask the user whether to commit before doing anything else.

## A note on testing

There's no automated test suite (no GUT/gdUnit4). Verification throughout this session has been: (1) headless scene loads via `godot.exe --headless --path . res://<scene> --quit`, checking for script/parse errors, and (2) the user manually playtesting and reporting back. Headless loading catches compile errors but **not** rendering/visual/feel issues — several bugs this session (the invisible rope, the offset flip, the wrong scale) only surfaced through actual playtesting. Don't claim something "works" from a clean headless load alone.

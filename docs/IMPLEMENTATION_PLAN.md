# Risk It for the Biscuit — Implementation Roadmap

**Status: Phases 0–5 implemented and headless-verified, using placeholder art for Train/County Jail/Witches per your call. A separate Combat/UI/AI polish pass (see `docs/POLISH_PLAN.md`) followed after your first playtest. Phase 6 not started.**

## Context

The jam build (`Brackeys2025.2`, Godot 4.4.1) is playable end-to-end (Menu → Character Select → Camp → Level 1 → End) but several systems the GDD (`docs/GDD.md`) treats as core are either stubbed, dead code, or entirely missing. Confirmed by reading the actual scripts (not just the checklist):

| System | GDD says | Code actually does |
|---|---|---|
| Stardom | Per-character score objective, drives win condition | `stardom:int=0` field exists on `CharacterAttributes`, **never read or written anywhere** |
| Reputation Actions (Conspire/Persuade/Fight/Defamation/Commendation/Boast) | The sabotage layer | **Zero code.** Camp interact menu (`character_interact_ui.gd`) only has "Use Fortune Cookie" and flavor-only "Chat" |
| Branching missions | Foretelling picks the next target | Only `level1.tscn` exists; Gravy's "Start Mission" hardcodes it. `GlobalVars.advance_scene()`/`stage_index` machinery is written but **never called** (dead code) |
| Results/Endings | Wish Granted / Defeat / Jail | `end.gd` is a **completely empty script** |
| Combat controls | You confirmed: fully manual, no auto-attack | Input map only defines movement + interact. **No Attack/Special/Item action exists at all** — player, allies, and enemies all auto-fire on a cooldown |
| Special/Heal in combat | Activated special, item use, ally heal/hurt | `special_attack`/`special_cost`/`heal_amount`/`heal_cost`/energy bar exist as data+UI but are **never spent** |

One bug also found and fixed:
- `enemy.gd:143` — `TARGET_STARDOM` enemy AI compared `stardom < starriest.current_hp` (wrong field on the RHS). Fixed to compare `stardom > starriest.stardom` (enemies now correctly target whoever's closest to their bounty).

Correction during implementation: this plan originally also flagged `camp.gd` refilling HP without clearing `.incapacitated` as a bug. On closer look it isn't — `incapacitated` is meant to persist across a Camp visit until deliberately cleared (via "Use Fortune Cookie" on that ally), which is what actually gates whether they're benched for the next Stage. "Fixing" it would have silently defeated both the revive-cost mechanic and the new Fight action below. Left as-is; only the per-phase Reputation Action flags (see Phase 2) get reset in `camp.gd`.

Goal of this roadmap: close the gap between the GDD and the code, in dependency order, without breaking the currently-playable loop. This session's implementation covers **Phases 0–3** (the missing mechanical core — no new art/scenes required). Phases 4–6 are scoped here for visibility but are follow-up work (Phase 4 touches core controls and deserves its own testing pass; Phases 5–6 are content/asset-heavy and depend on you supplying levels/art/audio).

---

## Phase 0 — Bug fixes (foundation for Phase 1)

- `scripts/enemy.gd`: fix `TARGET_STARDOM` to compare `GlobalVars.character_attributes[v].stardom < GlobalVars.character_attributes[starriest].stardom`.
- `scripts/camp.gd`: when refilling HP in `_ready()`, also set `attributes.incapacitated = false` so state can't desync.

## Phase 1 — Stardom

Add a small `stardom_config.gd` (autoload-accessible constants, or consts directly in `GlobalVars`) defining:
- `STARDOM_TARGET := 100` (tunable win threshold per character)
- `STARDOM_PER_KO := 1` (already mirrors `GlobalVars.KO_count`, but stored per-character on `CharacterAttributes.stardom` so it can be spent/transferred by Reputation Actions)
- `STARDOM_STAGE_CLEAR_BONUS := 10` (awarded to the character with the most kills that stage — reuse `GlobalVars.last_KO`/`KO_count` already tracked)

Wire-up:
- `scripts/enemy.gd` (`_on_area_entered`, where `KO_count[attack_area.source] += 1` already happens) and `scripts/combat_npc_controller.gd`/`scripts/combat_player_controller.gd` equivalents: also do `GlobalVars.character_attributes[attack_area.source].stardom += STARDOM_PER_KO`.
- `scripts/stage_manager.gd` (`spawn_next_wave`, "Last wave finished" branch): before changing scene, award `STARDOM_STAGE_CLEAR_BONUS` to the character with the highest `KO_count` this stage.
- Add a `GlobalVars.check_stardom_winner() -> int` (-1 if none) helper that returns the first character whose `stardom >= STARDOM_TARGET`, for Phase 3 to call.

## Phase 2 — Reputation Actions (sabotage layer)

Extend `nodes/ui/character_interact_ui.tscn` + `scripts/character_interact_ui.gd` from its current 3 buttons (Use Fortune Cookie / Chat / Leave) to also expose the 6 named actions, each a method following the existing `use_fortune_cookie()`/`chat()` pattern:

| Action | Cost | Effect |
|---|---|---|
| Conspire | Free, once per Camp Prep per ally | Sets a per-ally `allied_with_player` flag for the next Stage; that ally's kills grant Stardom to the acting character instead of themselves |
| Persuade | Free | Toggles a per-ally `sitting_out` flag controlling whether they spawn as a party NPC next Stage (`stage_manager._spawn_unselected_npcs_level1` already looks up `GlobalVars.unselected_character_scenes` — filter by this flag) |
| Fight | Costs 1 fortune cookie | Sets target `incapacitated = true` immediately (reuses the existing incapacitated pathway `character_interact_ui.gd` already toggles off) |
| Defamation | Requires target `stardom >= 10` | Transfers 10 Stardom from target to acting character |
| Commendation | Requires acting character `stardom >= 10` | Transfers 10 Stardom from acting character to target |
| Boast | Free, once per Camp Prep per character | +2 Stardom flat to the acting character |

These constants (10-point transfer, +2 Boast, once-per-phase limits) are proposed defaults — easy to retune later since they're isolated in one script.

New per-character transient state (`once_per_phase` flags, `allied_with_player`, `sitting_out`) lives on `CharacterAttributes`, reset at the top of `camp.gd:_ready()` alongside the existing HP refill.

## Phase 3 — Results & Endings

Flesh out `scripts/end.gd` (currently empty) and `scenes/end.tscn`:
- On load, call `GlobalVars.check_stardom_winner()`.
- If the **player's** character won → Victory / Wish Granted branch (reuse the per-character wish text now documented in `docs/GDD.md` §7 as the source of truth for copy).
- If a **different** character won → Defeat branch.
- If no one has hit target and stages remain → route back to Camp (finally wiring `GlobalVars.advance_scene()`, which exists but is currently dead code, into `stage_manager.gd`'s "last wave finished" branch instead of the hardcoded `res://scenes/end.tscn`).
- If stages are exhausted with no winner → "Everyone in Jail" branch.

**As implemented:** `end.tscn` still shows after every Stage clear (it's the Results beat from the GDD's loop, not just a final screen) — `stage_manager.gd` keeps transitioning there, now also awarding the stage-clear Stardom bonus first. `end.gd` computes the outcome and its Continue button either calls `GlobalVars.advance_scene()` (stage-clear, run continues → Camp) or goes to `main_menu.tscn` (Wish Granted / Defeat / Jail — run over). `advance_scene()` itself was dead code (its `stage_level` flag was never set `true` anywhere, and its Stage-path pattern `stage_N.tscn` didn't match any real file) — fixed by setting `stage_level = true` in `stage_manager.gd:_ready()` and pointing the Stage branch at `level1.tscn` as a placeholder until Phase 5 adds real branching content. Added `GlobalVars.MAX_STAGES = 5` as the "stages exhausted" threshold for the Jail ending, since no real stage count existed to check against yet.

Also (Phase 2 dependency): `stage_manager.gd`'s `_spawn_unselected_npcs_level1()` previously ignored `incapacitated` entirely when deciding which allies show up in a Stage — a dead sibling function had that check but wasn't the one actually called. Wired the check (plus the new `sitting_out` flag from Persuade) into the function that's actually used.

This is the minimum needed to make Camp ⇄ Stage a real repeatable loop instead of a one-shot demo, without yet requiring multiple distinct level scenes (Phase 5 adds those; until then `advance_scene()` will keep reusing `level1.tscn`).

---

## Phase 4 — Manual combat rework ✅ Done

Your confirmed direction: fully manual, no auto-attack. Two design gaps came up during implementation that weren't resolved by the original plan text and needed your call:

- **Item had no inventory to hook into** (Hard Tack was an instant-use world pickup, nothing was ever "held"). You chose a minimal carry-one inventory: `GlobalVars.held_item` (`ItemType` enum, currently just `HARD_TACK`), with a `held_item_changed` signal driving a new label on the Stage HUD (`nodes/ui/stage_ui.tscn`). Picking up a second item while holding one **replaces** it — no stacking. `hard_tack.gd` now calls `GlobalVars.pick_up_item()` instead of healing instantly; `GlobalVars.use_held_item()` applies the effect and clears the slot.
- **Heal had no ally-targeting** (`CombatNPC` isn't wired into the `Interactable` system Camp uses, and building that was real scope). You chose **self-heal only** for this pass.

As implemented:
- `project.godot`: added `attack` (J / joypad button 0), `special` (K / joypad button 1), `heal` (H / joypad button 5), `item` (L / joypad button 4).
- `scripts/combat_player_controller.gd`: the old unconditional auto-fire block is gone. Attack now requires `Input.is_action_pressed("attack")` held, still cooldown-gated — same rate-of-fire, but nothing fires without input. Added `try_use_special()` (spends `special_cost` energy, instantiates `special_attack`) and `try_self_heal()` (spends `heal_cost`, restores `heal_amount`). Extracted the position/face-left/add_child boilerplate shared by Attack and Special into `position_and_spawn_attack()`.
- All 4 characters had a `special_attack` **scene already sitting on disk** (`nodes/objects/attacks/specials/*_special_projectile.tscn`) that was never assigned in their `data/*_default.tres` — wired those in, since `special_cost` (== `max_energy` for all 4) was already tuned and waiting for it.
- Deliberately did **not** touch `combat_npc_controller.gd`/`enemy.gd` auto-fire — that's correct AI behavior, not the player auto-attack that was removed.

Not done, left as explicit gaps: ally healing/targeting, and a real multi-slot or stacking inventory if one Hard Tack at a time turns out to feel bad in practice.

## Phase 5 — Branching missions & content (partially done — blocked on art for the rest)

**Done, no art required:**
- Gravy's "Start Mission" and `advance_scene()` both now resolve the next Stage through `GlobalVars.get_next_stage_scene()`, which maps the drawn `StageFortune` type to a scene path (`STAGE_SCENE_BY_FORTUNE`). Every entry currently points at `level1.tscn` since it's the only Stage that exists, but the mechanism itself is real — adding Train/County Jail is filling in a dictionary, not touching call sites.
- Reconciled the enemy naming mismatch: confirmed via full asset search that there is no Sheriff, Bounty Hunter, or Witch art or scene anywhere in the project. The real roster is Gunslinger/Banker/Lawman (see `docs/GDD.md` §8 for their actual stats). Updated the GDD rather than the code — nothing to rename in scripts since the code was already right.

**Then scaffolded with placeholder art, per your call:**
- `nodes/objects/scenery/TrainBackground.tscn` / `CountyJailBackground.tscn` — flat `ColorRect` sky/ground stand-ins (Jail's adds a few bars for a little visual identity) with an on-screen "PLACEHOLDER BG" label, so nobody mistakes them for finished art in playtesting. Reskin by swapping these nodes for real parallax layers (same pattern as `DesertBackground.tscn`) — no other file needs to change.
- `nodes/entities/npcs/combat/enemy/witch.tscn` — a real `Enemy` (same `enemy.gd`, same AnimationTree/state-machine shape required by that script) using a tinted placeholder triangle (`sprites/placeholder/placeholder_triangle1.png`, purple `self_modulate`) instead of bespoke art. Given `EnemyBehavior.TARGET_STARDOM` (hunts whoever's closest to their bounty) for a real mechanical identity independent of its look. Reskin by swapping the `SpriteFrames` textures; stats/AI/collision don't need to change.
- `scenes/train_stage.tscn` / `county_jail_stage.tscn` — full `StageManager` scenes, same skeleton as `level1.tscn` (Camera2D, StageUI, NPC spawns, floor colliders, wave timer). Train runs Gunslinger/Banker/Witch; County Jail runs Lawman/Banker/Witch tuned tougher (fewer, stronger enemies, longer wave delays).
- `GlobalVars.STAGE_SCENE_BY_FORTUNE` now actually branches: Bounty Frenzy/Chicken Party (loot-flavored) → Train, Chaotic Rave/Darwin's Stage (danger-flavored) → County Jail, the rest → Desert. Foretelling genuinely picks your target now, not just a modifier.

All new/touched scenes headless-verified clean (no script errors on load).

## Phase 6 — Polish & release prep (follow-up)

Tutorials, main menu polish, ability-select menu, bounty poster/pop-up banner UI, remaining music tracks (only `westsong.wav` exists today) and SFX, settings/save system. Matches `docs/GDD.md` §10–11 checklist as-is.

---

## Verification

- After Phase 0–1: open the project in the Godot editor (`godot.exe` at the project root), play `level1.tscn` directly, kill a few enemies, and confirm `character_attributes[...].stardom` increments (temporary `print()` or the debugger watch) and the stage-clear bonus fires when the last wave dies.
- After Phase 2: play through Camp, interact with a party NPC, and exercise each new button once to confirm no script errors and that Stardom/incapacitated state changes as expected.
- After Phase 3: manually set a character's `stardom` above `STARDOM_TARGET` (debugger or a temporary cheat key) and confirm `end.tscn` branches correctly to Victory/Defeat, and that a non-winning run routes back to Camp via `advance_scene()` instead of dead-ending.
- No automated test suite exists in this repo (GDScript, no GUT/gdUnit4 installed) — verification is manual in-editor play per above.

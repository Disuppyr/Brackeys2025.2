# Combat, UI & AI Polish Pass

**Status: Done, headless-verified. See `docs/GDD.md` §5 Combat for the summary of what shipped from this pass. Numbers here (cooldowns, shake amount, flee threshold, HP flash colors) are first-pass tuning — expect to hand-tune further after playing it.**

## Context

You playtested the build after Phases 0–5 (Stardom, Reputation Actions, Results/Endings, manual combat, branching missions) and flagged that nothing's *broken*, but several systems need real polish before this is fun to play: combat feels clunky, the HP/energy HUD is uninformative, enemy/ally AI is too simple, and enemies have no health bar at all. You confirmed specifics via a clarifying round:

- **Combat clunkiness:** can't move while attacking, attack pacing feels off, no hit impact/feedback, movement itself feels floaty/stiff.
- **UI problems:** no numbers on HP/energy bars, no feedback when hit or healed, no at-a-glance status (low HP, who's down, is Special ready).
- **AI direction:** smarter positioning, allies/enemies actually using abilities (not just auto-fire), reactive behavior (HP thresholds, better targeting) — but kept low-effort, not a full behavior-tree rewrite.

This is a cross-cutting pass, not a new system, so it's organized by symptom rather than by phase number.

---

## 1. Movement & attack feel (`scripts/player_controller.gd`, `scripts/combat_player_controller.gd`)

- **Can't move while attacking:** `player_controller.gd:_physics_process` currently zeroes `velocity` for the whole `shoot_frame_duration` whenever `is_shooting` is true. Restructure so the shoot-animation timer still counts down (driving the "Shoot" animation via `_update_animations()`) but no longer blocks movement — movement and firing become independent, matching "no auto-attack, just don't lock the player in place" manual-combat spirit from Phase 4.
- **Attack pacing:** default `attack_cooldown` is `1.0s` for all 4 characters (`data/*_default.tres`) — slow for a hold-to-fire action shooter. Lowering to `~0.35s` across the board for a snappier rhythm; flagged as an easy tunable if it needs per-character differentiation later (e.g. Bonnie heavier/slower vs. Pearl faster).
- **Floaty/stiff movement:** `walk_acceleration=60` / `slowdown_multiplier=0.7` in `player_controller.gd` are applied per-physics-tick (not delta-scaled), so on a fixed 60Hz physics step this is consistent but the exponential-decay stop (`velocity *= 0.7` every tick) reads as sliding. Tightening `slowdown_multiplier` down (faster stop) and nudging `walk_acceleration` up slightly (faster start) for a snappier default — genuinely a feel/tuning change, expect to hand-tune further after playtest.

## 2. Hit feedback / juice (`scripts/attack.gd`, new small additions)

Centralizing all impact feedback in `Attack.hit()` (`scripts/attack.gd`) since every attack — player, ally, or enemy — already funnels through it. Adding, from that single call site:
- **Hitstop:** a very brief (~0.04s) `Engine.time_scale` freeze on any successful hit, restored via an unscaled timer (`get_tree().create_timer(t, true, false, true)` with `ignore_time_scale=true` so the restore isn't itself frozen). Implemented as `GlobalVars.hitstop()` so it's one small reusable function, not duplicated per controller.
- **Screen shake:** a small reusable `camera_shake.gd` script attached to each Stage's `Camera2D` (`level1.tscn`, `train_stage.tscn`, `county_jail_stage.tscn`), exposing `shake(amount, duration)`; triggered via `get_viewport().get_camera_2d().shake(...)` from `Attack.hit()` when the target is the player or an ally (skip shaking on every single enemy hit during a big wave — would feel like nonstop noise).
- **Floating damage numbers:** a tiny new `damage_number.tscn`/`.gd` (a `Label` that spawns at the hit position, tweens upward, fades, `queue_free()`s) instantiated from `Attack.hit()`. This directly addresses both "no hit impact" and "no feedback when hit" in world-space, independent of the HUD changes below.

## 3. HUD improvements (`scripts/stage_ui.gd`, `nodes/ui/stage_ui.tscn`)

- Add numeric `HP: x/y` / energy `x/y` Labels per character row (currently bars only).
- Flash the bar (brief bright pulse via `Tween`) on any HP/energy change — green-ish on gain, red-ish on loss — driven from the existing `attributes.changed` signal connection already wired in `stage_ui.gd:_ready()`.
- Low-HP cue: pulse or recolor a character's row when `current_hp` drops below ~25%.
- Incapacitated characters currently just vanish (`stats_uis[...].visible = false`) — instead grey them out/dim in place so it's clear *who* went down, not just that a row disappeared.
- Special-ready cue: recolor/highlight the energy bar once `current_energy >= special_cost` so it's obvious Special is usable.

## 4. Enemy health bars (`scripts/enemy.gd`, all 4 enemy scenes)

Add a small floating health bar (2 `ColorRect`s: background + fill, same visual pattern as the player HUD bars) as a child of each enemy scene (`gunslinger.tscn`, `banker.tscn`, `lawman.tscn`, `witch.tscn`), positioned above the sprite. Updated from `enemy.gd`'s existing `_process()` — no new signal needed, since enemies are short-lived and a per-frame width update is cheap. One script change (`enemy.gd`) covers all 4 scenes once the two `ColorRect` nodes exist in each.

## 5. AI enhancements (`scripts/enemy.gd`, `scripts/combat_npc_controller.gd`)

Kept intentionally scoped (per your "low effort" signal) — meaningful behavior changes, not a rewrite:

- **Positioning:** add a small separation nudge — when `MOVING`, offset the move target slightly away from other nearby same-group entities (other enemies for `Enemy`, other party members for `CombatNPC`) so they stop stacking on the exact same spot. Cheap distance check against `get_tree().get_nodes_in_group(...)`, no pathfinding.
- **Allies actually use abilities:** `combat_npc_controller.gd` gets the same energy-gated logic as the player controller from Phase 4 — when `current_energy >= special_cost` and off cooldown, fire `special_attack` instead of the basic attack; when own `current_hp` drops low and `current_energy >= heal_cost`, self-heal instead of attacking that tick. (Ally energy already fills correctly today — kills route through `attack_area.source`, which reflects the attacking character regardless of whether they're player- or AI-controlled, so no new plumbing needed there.)
- **Reactive enemies:** enemies gain a simple low-HP "flee" reaction — below a threshold, move away from their target instead of planting and shooting, for a few seconds before resuming normal behavior. Also re-evaluate `assign_target()` periodically instead of only when the current target becomes invalid, so enemies aren't locked onto one character all fight.
- **Explicitly out of scope this pass:** true projectile-dodging/juking. Flagging it as a bigger future item rather than half-implementing something unconvincing.

---

## Verification

- Headless-load every touched/new scene (`godot.exe --headless --path Brackeys2025.2 res://<scene> --quit`) after each group of changes, same pattern used in Phases 0–5, checking for script/parse errors.
- Manually sanity-check the hitstop/screen-shake numbers are small enough not to feel like a bug (short duration, small magnitude) — these are the two riskiest additions since they touch global `Engine.time_scale` and camera state shared across the whole scene.
- Re-check `project.godot` and any `.import`/`.clip` files after each headless run for incidental engine side-effects (has happened before this session) and revert anything unintended.
- This is a feel/tuning pass — flag in the wrap-up that final numbers (cooldowns, shake amount, flee threshold, etc.) are a first pass meant to be hand-tuned further after you play it, not treated as final balance.

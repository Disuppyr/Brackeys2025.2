# Combat Rework, Dash, and Variable Reference Doc

**Status: Done, headless-verified. See `docs/TUNING.md` for every tunable value this touched (and a few pre-existing ones it surfaced along the way, like Lawman's unset follow_range).**

## Context

Second playtest round. Three concrete asks plus one documentation ask:

1. **"UI for player/allies is nonexistent on other levels"** — diagnosed via your own answer: you were likely testing `train_stage.tscn`/`county_jail_stage.tscn` directly in the editor (F6 "run current scene"), bypassing Character Select. `GlobalVars.unselected_character_scenes` defaults to an **empty array**, so `stage_manager.gd:_spawn_unselected_npcs_level1()` spawns zero ally NPCs when that path is skipped — allies are genuinely absent from the world, not just their UI. The HP/energy HUD itself (`stage_ui.tscn`) is structurally identical across all three stage scenes, so it isn't a stage-specific bug.
2. **Projectiles feel unnatural, especially Bonnie's lasso.** Found the actual cause: `bonnie_projectile_attack.tscn`'s trailing-rope `AtlasTexture` region is `Rect2(40, 0, 200, 0)` — **zero height**. The rope segment is effectively invisible, so what you see is just the loop sprite flying through the air with nothing visibly connecting it back to Bonnie — reads exactly like "a generic bullet wearing a lasso texture," which is what you said. Jane/Pearl/Rose have no bespoke visual treatment at all — all three are a static sprite on the same straight-line `Path2D`/`PathFollow2D` travel every other attack uses, just with a different texture. Confirmed via `nodes/objects/attacks/*_attack.tscn` and `*_projectile_attack.tscn`.
3. **Dash for player and allies**, dodging via repositioning (not invincibility — you didn't select i-frames), gated by its own cooldown (not shared energy, since energy already gates Special/Heal), and allies should trigger it reactively, not just the human player.
4. **A separate tuning-reference doc** cataloguing every customizable variable with a description, so you can retune without digging through scripts.

---

## 1. Fix the standalone-stage-testing gap

`scripts/data/global_vars.gd`: give `unselected_character_scenes` a non-empty default (Pearl/Rose/Jane, mirroring `selected_character_scene`'s existing Bonnie default) instead of `[]`. `character_select.gd` already overwrites this array on the normal flow, so this only changes behavior when a stage scene is opened directly, which is exactly the gap you hit.

## 2. Bonnie's lasso — replace the broken rope with a `Line2D`

`nodes/objects/attacks/bonnie_projectile_attack.tscn` / `scripts/bonnie_projectile_attack.gd`:
- Remove the `TextureRect` + zero-height `AtlasTexture` (the actual bug).
- Add a `Line2D` from the Path2D's origin `(0,0)` to the live `PathFollow2D` position, updated each `_physics_process` (already overridden there for the old `TextureRect.size.x` line — same call site, just setting `line.points = [Vector2.ZERO, $PathFollow2D.position]` instead). A `Line2D` always visually connects both ends by construction, which is more robust than a cropped, stretched `TextureRect` and directly solves "loop and rope should connect naturally." Apply `rope.png` as the `Line2D`'s texture (tiled) so it still reads as a rope, not a flat color line.
- Leave the loop sprite (`lasso.png` on the `GenericAttack`/`Sprite2D`) as-is — that part already reads fine, it's specifically the trailing connection that's broken.

## 3. Particle accents on Jane/Pearl/Rose's bullets

Per the `particles-vfx` skill: add a small `GPUParticles2D` trail (short lifetime, low amount, `local_coords=false` so it leaves a trail in world space as the projectile moves) to each of `jane_attack.tscn`, `pearl_attack.tscn`, and the shared `generic_attack.tscn` if Rose also resolves to it — as a child of the existing `GenericAttack`/`Attack` node, not replacing the sprite. This gives the bullets visual presence/impact without touching the underlying straight-line motion system (`projectile_attack.gd`), which is lower-risk than reworking projectile travel itself and wasn't what you flagged as broken. Emission: `one_shot=false`, `amount` ~8–12, short `lifetime` (~0.2s), a `color_ramp` fading to transparent, sized to read as a small trail/spark rather than a big burst.

## 4. Dash

New `dash` input action (`project.godot`) — Left Shift + joypad button 3 (Y/Triangle), the last unused face button.

**Player (`scripts/combat_player_controller.gd`):** on `Input.is_action_just_pressed("dash")`, if `dash_cooldown_timer <= 0`, burst `square_velocity` to `dash_speed` in the current movement-input direction (or facing direction if no input held) for `dash_duration` (~0.15s), then let existing deceleration resume normally; start `dash_cooldown_timer` (~1.2s, exported so it's tunable). **No invincibility** — this is repositioning-only, per your choice; noting here so it's an explicit, revisitable decision if it doesn't feel like a real "dodge" once you've played it.

**Allies (`scripts/combat_npc_controller.gd`):** same core burst/cooldown mechanic, adapted to `CombatNPC`'s `position +=` movement model (it isn't a `CharacterBody2D`, so it can't reuse the player's `velocity`/`move_and_slide` approach directly). Reactive trigger: each `_process` tick (throttled, only checked when off cooldown), scan `get_tree().get_nodes_in_group("attack")` for enemy-sourced (`source == Attack.AttackSource.ENEMY`) attacks within a danger radius (~70px); if found, dash directly away from that attack's position. This is a proximity heuristic, not true trajectory prediction — matches the "low effort but real" bar from the AI work last round, not a full dodge-prediction system.

## 5. Tuning reference doc

New `docs/TUNING.md`: every `@export`/tunable constant across the scripts touched this session and earlier phases, grouped by system (Movement, Combat/Attack, Dash, Character Stats per `data/*_default.tres`, Enemy Stats per enemy scene, Stardom/Reputation constants in `global_vars.gd`, Stage Fortune effects, AI thresholds, UI thresholds/colors). Each entry: file path, variable name, current default, one-line description of what it actually controls. Pure documentation, no code changes — generated by reading the scripts, not guessed.

---

## Verification

- Headless-load every touched/new scene, same pattern as prior phases (`godot.exe --headless --path Brackeys2025.2 res://<scene> --quit`), checking for script/parse errors.
- Specifically test opening `train_stage.tscn`/`county_jail_stage.tscn` directly (not through Character Select) after the `unselected_character_scenes` default fix, to confirm allies now spawn — this is the actual repro case for the "UI nonexistent" report.
- Re-check `project.godot` after adding the `dash` input action for incidental engine side-effects (established pattern this session) and revert anything unintended.
- This is still a feel/tuning pass on top of a rework — dash timing, particle amount/lifetime, and the ally danger radius are first-pass numbers meant to be hand-tuned further after you play it.

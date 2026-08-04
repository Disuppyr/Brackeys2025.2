# Tuning Reference

Every customizable value in the project, grouped by system, with what it actually controls. "First pass" numbers throughout — most of this has not been hand-tuned against real playtesting yet.

Two kinds of entries:
- **`@export`** — set per-scene-instance in the `.tscn`/`.tres` file listed, or in the Godot Inspector. Changing the script's default only changes new/unset instances.
- **`const`** — set once in the script, applies everywhere that script runs. Edit the script to change it.

---

## Movement (`scripts/player_controller.gd`)

Base class for both the player and (indirectly, via its own model) allies/enemies.

| Variable | Default | Controls |
|---|---|---|
| `walk_acceleration` | `90.0` | How fast the character speeds up per physics tick while a movement key is held. Higher = snappier start. |
| `max_walk_speed` | `300.0` | Top movement speed, px/sec. |
| `slowdown_multiplier` | `0.55` | Fraction of current speed kept each physics tick when no input is held (0 = instant stop, 1 = frictionless). Lower = snappier stop. |
| `spawn_position` | `(0,0)` | Unused (dead export — `_enter_tree` sets it but the line is commented out). |

## Combat — Player (`scripts/combat_player_controller.gd`)

| Variable | Default | Controls |
|---|---|---|
| `auto_attack_cooldown` | `0.35` | Minimum seconds between basic Attack shots while the `attack` input is held. This is the actual player fire-rate — separate from (and overrides for the player) `CharacterAttributes.attack_cooldown` below, which allies/enemies use instead. |
| `dash_speed` | `700.0` | Dash burst speed, px/sec. |
| `dash_duration` | `0.15` | How long the dash burst lasts, seconds. |
| `dash_cooldown_max` | `1.2` | Seconds before Dash can be used again. Own resource — doesn't touch energy. |

**Dash has no invincibility frames** — it's repositioning-only, by request. If it doesn't read as a real "dodge" once played, that's the first thing to reconsider (add an `invulnerability` window during `dash_timer`, mirroring the existing hurt-invuln pattern already used on hit).

## Combat — Allies (`scripts/combat_npc_controller.gd`)

| Variable | Default | Controls |
|---|---|---|
| `follow_range` | scene-specific | Preferred standoff distance from their target before attacking. |
| `dash_speed` / `dash_duration` / `dash_cooldown_max` | `650.0` / `0.15` / `1.5` | Same as player dash, tuned slightly weaker/slower to cooldown. |
| `dash_danger_radius` | `70.0` | How close an enemy-sourced attack must be before this ally reactively dashes away. It's a proximity check, not trajectory prediction — a fast projectile can still tag them before the radius trips. |
| *(inline, not exported)* self-heal threshold | `0.3` (30% HP) | In `_act()`: below this HP fraction, and if they can afford `heal_cost`, an ally self-heals that tick instead of attacking. |
| *(inline)* separation trigger distance | `40.0` px | In `_apply_separation()`: how close another party member needs to be before this ally's move target gets nudged away from them. |

## Combat — Enemies (`scripts/enemy.gd`)

| Variable | Default | Controls |
|---|---|---|
| `behavior` | `TARGET_RANDOM` | Targeting mode: `TARGET_RANDOM`, `TARGET_WEAKEST` (lowest current HP), `TARGET_STARDOM` (highest Stardom — hunts the front-runner), `MIXED` (rolls one of the first three each retarget). Set per enemy scene; currently only `witch.tscn` uses `TARGET_STARDOM` (value `2`), the rest default to random. |
| `follow_range` | scene-specific | Preferred distance from target before attacking. |
| `FLEE_HP_THRESHOLD` (const) | `0.3` (30% HP) | Below this fraction, an enemy flees instead of fighting. |
| `FLEE_DURATION` (const) | `2.5` sec | How long the flee reaction lasts before resuming normal behavior. |
| *(inline)* retarget interval | `randf_range(4.0, 7.0)` sec | How often an enemy re-rolls its target instead of sticking with one character all fight. |
| *(inline)* separation trigger distance | `40.0` px | Same pattern as allies — keeps enemies from stacking on one spot. |

## Attacks (`scripts/attack.gd`, per-attack `.tscn`)

Base fields on every `Attack` node (`GenericAttack` in each `*_attack.tscn`):

| Field | Controls |
|---|---|
| `power` | Damage dealt per hit. |
| `pierce` | How many targets it can hit before disappearing. |
| `knockback` | Push force applied on hit. |
| `duration` | Lifetime in seconds before it fades out (also caps projectile travel time — see below). |
| `sprite` | The attack's texture. |

Current per-character values (`nodes/objects/attacks/*_attack.tscn`):

| Character | power | pierce | knockback | duration |
|---|---|---|---|---|
| Bonnie (lasso loop) | 1 | 1 (3 as fired via projectile) | 20.0 (-20.0 as fired) | 0.5 |
| Jane | 1 | 2 | 20.0 | 0.2 |
| Pearl | 1 | 1 | 80.0 | 0.5 |
| Rose | 1 | 1 | 20.0 | 0.5 |
| Generic (enemies) | 1 | 1 | 20.0 | 0.5 |

Projectile travel (`*_projectile_attack.tscn`, `Curve2D` length = travel distance, covered over `duration`):

| Character | Distance | Effective speed |
|---|---|---|
| Bonnie | 320px | 640 px/sec |
| Jane | 320px | 1600 px/sec |
| Pearl | 200px | 400 px/sec |
| Rose | 800px | 1600 px/sec |

**Bonnie's lasso loop (`bonnie_attack.tscn`):** spawn offset `Sprite2D.position = (0, -40)` (was `-63`, which put it up at face height rather than hand height — this was pre-existing, just not visible/obvious until the rope started rendering correctly; later nudged from `-30` to `-40` because the lasso was still reading as emerging a bit too low) and `scale = 0.15` (was `~0.09`, read as too small). The `fade` animation's shrink-out endpoint scales proportionally (`(0.05, 0.15)`, preserving the original "closes horizontally as it vanishes" look at the new base size). Both the `RESET` and `fade` animation tracks had to be updated alongside the base `Sprite2D` values — Godot auto-applies `RESET` on ready, so it would otherwise silently snap back to the old scale.

**Bonnie's rope (`scripts/bonnie_projectile_attack.gd`, `bonnie_projectile_attack.tscn`):**
- `ROPE_Y_OFFSET = -40.0` — must always match the loop's `Sprite2D.position.y` above, or the two ends stop lining up with the loop/hand.
- `Line2D.width = 5.0`, textured with `rope.png` (tiled, `texture_mode = 1`, untinted `default_color = white` so it shows the art's native color rather than a guessed tint) — matches the loop's own `lasso.png` coloring by using the actual paired asset instead of hand-picking a color.
- Draws behind the loop sprite via **sibling order** (it's the first child of `Path2D`, `PathFollow2D` comes after) rather than `z_index` — an earlier version used `z_index = -1` intending "behind the loop," but `z_index` is relative to the whole canvas layer, not scoped to siblings, so it actually sank the rope behind the Stage's background layer and made it fully invisible. That was the actual cause of the first report that the rope "wasn't there."
- The rope's hand-end tracks whoever fired it (`set_source_node()`, called from both `combat_player_controller.gd:position_and_spawn_attack()` and `combat_npc_controller.gd:_spawn_attack()` whenever the spawned attack has that method) rather than staying pinned to the position they were standing at when they threw it. The offset has to be added in **world space before** converting to the rope's local space (`to_local(source_node.global_position + Vector2(0, ROPE_Y_OFFSET))`) — adding it after `to_local()` means the offset inherits this node's own rotation, so it silently flips from "above" to "below" whenever `face_left()` rotates the whole `Path2D` 180°. That was the cause of "works fine facing right, off facing left."
- The **loop-end** of the rope had the exact same bug, just missed in the first pass: it was built as `Vector2($PathFollow2D.position.x, ROPE_Y_OFFSET)`, a raw local-space point that skipped `to_local(global_position + offset)` entirely. Since the loop itself doesn't actually drift (its own rotation cancels out via `PathFollow2D.rotation = -PI` offsetting `Path2D.rotation = PI`, per `face_left()` in `projectile_attack.gd`), only the rope endpoint was wrong — but because it's a straight 2-point `Line2D`, that made the whole rope visibly sag/droop when facing left, reading as "the projectile drifts down." Fixed the same way as the hand-end: `to_local($PathFollow2D.global_position + Vector2(0, ROPE_Y_OFFSET))`.
- **Single-instance gating:** Bonnie can't throw another lasso until the current one is gone (faded/freed) — tracked via `active_single_instance_attack` on both `combat_player_controller.gd` and `combat_npc_controller.gd`, set whenever a spawned attack has `set_source_node()` (currently only Bonnie's). Every other character's attack never sets this, so normal cooldown-only firing is unaffected.

**Particle trails (Jane/Pearl/Rose, `*_attack.tscn`):** each has a `Trail` `GPUParticles2D` — `amount=10`, `lifetime=0.25`, initial velocity `0–15`, scale `0.4–0.8`, color fades to transparent via each scene's `Gradient` sub-resource (Jane: warm gold; Pearl: pink/magenta; Rose: dark red). Tune per-scene since each has its own `Gradient`/`ParticleProcessMaterial`.

## Character Stats (`data/*_default.tres`, `scripts/data/character_attributes.gd`)

All 4 characters currently share identical values:

| Field | Default | Controls |
|---|---|---|
| `max_hp` | `40` | Max health. |
| `max_energy` | `50` | Max energy (fills from kills, spent on Special/Heal). |
| `special_cost` | `50` | Energy required to use Special — currently == `max_energy`, i.e. Special requires a full bar. |
| `heal_amount` | `10` | HP restored by Heal (self-only currently) or an ally's reactive self-heal. |
| `heal_cost` | `15` | Energy spent per Heal use. |
| `attack_power` | `5` | Damage of the character's basic attack (separate from the `Attack` node's own `power=1` — this is the value actually applied; see `attack_power` usage note below). |
| `attack_cooldown` | `0.35` | Used by allies/enemies as their attack rate. **Not** used by the human player, who instead uses `combat_player_controller.gd`'s `auto_attack_cooldown`. |
| `movement_speed` | `300.0` | Used by allies (their own movement); the player instead uses `player_controller.gd`'s `max_walk_speed`. |
| `energy_dropped` | `5` | Energy granted to whoever lands a kill. |
| `stardom` / `rapport` | `0` | Runtime state, not really a "tuning" value — starting Stardom/Rapport for a fresh run. |

> **Known gap, not fixed this pass:** `EntityAttributes.attack_power` is defined and exported but nothing in `enemy.gd`/`combat_player_controller.gd`/`combat_npc_controller.gd` actually reads it when spawning an attack — the `Attack` node's own hardcoded `power` field (in each `*_attack.tscn`, see table above) is what's actually used. There's a `# TODO set attack power here` comment marking this in both `enemy.gd` and `combat_npc_controller.gd`. Worth fixing if per-character damage scaling ever matters.

## Enemy Stats (per `nodes/entities/npcs/combat/enemy/*.tscn`)

| Enemy | max_hp | attack_power | attack_cooldown | movement_speed | follow_range | behavior |
|---|---|---|---|---|---|---|
| Gunslinger | 15 | 5 | 1.5 | 250 | 320 | Random |
| Banker | 10 | 5 | 1.5 | 200 | 150 | Random |
| Lawman | 30 | 5 | 0.8 | 150 | **0.0 (unset — likely a bug, see below)** | Random |
| Witch | 20 | 6 | 1.8 | 170 | 280 | **Stardom** (hunts front-runner) |

**Lawman's `follow_range` isn't set in `lawman.tscn`**, so it uses the class default (`0.0`). Combined with `enemy.gd`'s attack-range check (`abs(dx) <= follow_range and abs(dy) <= 32.0`), this means Lawman can only ever attack from almost exactly on top of its target — likely unintentional given the other three enemies all have an explicit, sensible `follow_range`. Not fixed this pass since it wasn't part of what was reported broken, but flagging it here since it's the kind of thing this doc exists to surface.

## Stardom & Reputation Actions (`scripts/data/global_vars.gd`)

| Constant | Default | Controls |
|---|---|---|
| `STARDOM_TARGET` | `100` | Stardom needed to win (trigger Wish Granted). |
| `STARDOM_PER_KO` | `1` | Stardom gained per personal kill. |
| `STARDOM_STAGE_CLEAR_BONUS` | `10` | Bonus Stardom to whoever landed the last kill of a Stage. |
| `REPUTATION_TRANSFER_AMOUNT` | `10` | Stardom moved by Defamation/Commendation. |
| `BOAST_AMOUNT` | `2` | Flat Stardom gained from Boast. |
| `MAX_STAGES` | `5` | Stages playable before an unresolved run ends in "Everyone in Jail." Safety valve until more Stage content exists. |
| *(inline, `character_interact_ui.gd`)* Fight cost | 1 fortune cookie | Not a named constant — hardcoded via `GlobalVars.fortune_cookies -= 1` in the `fight()` function. |
| *(inline)* Defamation/Commendation gate | source needs `>= REPUTATION_TRANSFER_AMOUNT` | Can't drain a character below the transfer amount into negative Stardom. |

## Hit Feedback (`scripts/data/global_vars.gd`, `scripts/attack.gd`, `scripts/camera_shake.gd`, `scripts/damage_number.gd`)

| Value | Default | Controls |
|---|---|---|
| `GlobalVars.hitstop()` `duration` | `0.04` sec | How long `Engine.time_scale` stays frozen on any hit. |
| `GlobalVars.hitstop()` `scale` | `0.05` | How slow time gets during hitstop (5% speed, not a full freeze). |
| Camera shake amount/duration (`attack.gd:hit()`) | `4.0` / `0.15` sec | Shake magnitude and duration, triggered only when the player/an ally takes the hit (not on every enemy hit). |
| Damage number move distance/duration (`damage_number.gd`) | `40px` up / `0.6` sec | How far and how long the floating damage/heal number travels before being freed. |
| Damage number fade delay/duration | `0.3` sec delay, `0.3` sec fade | When the number starts fading and how long the fade takes. |

## HUD (`scripts/stage_ui.gd`)

| Constant | Default | Controls |
|---|---|---|
| `HP_COLOR` / `ENERGY_COLOR` | green / cyan | Normal bar colors. |
| `HP_LOW_COLOR` | red | Bar color once HP fraction drops to/below `LOW_HP_THRESHOLD`. |
| `ENERGY_READY_COLOR` | gold | Energy bar color once `current_energy >= special_cost` (Special is usable). |
| `FLASH_COLOR` | white | Flash color shown for one tween cycle on any HP/energy change. |
| `LOW_HP_THRESHOLD` | `0.25` (25%) | HP fraction that triggers the low-HP color. |
| `INCAPACITATED_ALPHA` | `0.35` | Opacity of a character's HUD row while they're incapacitated (dimmed in place, not hidden). |

## Stage Fortune effects (`scripts/stage_manager.gd:apply_stage_fortune()`)

Magnitudes are all inline, not named constants:

| Fortune | Effect |
|---|---|
| Tiny Land | Doubles enemy count (waves with >1 enemy), halves spawn interval, `scale_multiplier = 0.6` (smaller enemies, faster). |
| Giant Land | Halves enemy count, doubles spawn interval, `scale_multiplier = 1.6` (bigger enemies, slower). |
| Chicken Party | Item drop rate ×3 (capped at 100%). |
| Chaotic Rave | Enemies explode on death (`do_explosions`). |
| Skate Park | All characters' `movement_speed` set to `500.0` for the stage. |
| Biscuit Rush | Enemies drop 1.6× energy on death. |
| Darwin's Stage | Enemies deal 1.6× attack power. |

## Fortune effect hooks that exist but are only partially wired

- `CharacterFortune` types with real gameplay effects: **BUBBLE** (25% damage reduction, `* 0.75` inline in each hurt handler), **JINXED** (half HP at Stage start), **JAMMED** (20% chance an ally's attack whiffs, `randf() < 0.8` inline). The other 5 (Lucky Clover, Skilled, Baking Soda, Training Arc, Black Cat) have flavor text only, no coded effect.

## Items (`scripts/data/global_vars.gd:use_held_item()`, `scripts/hard_tack.gd`)

| Value | Default | Controls |
|---|---|---|
| Hard Tack heal amount | `20` HP | Hardcoded in `use_held_item()`'s `ItemType.HARD_TACK` branch, applied to every non-incapacitated character. |

---

*Generated by reading the current scripts/scenes directly, not from memory — should stay accurate as long as it's kept in sync with future edits to these files.*

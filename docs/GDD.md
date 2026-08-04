# Risk It for the Biscuit — Game Design Document

**Godot 4.4.1 · 2D Sidescroller · Brackeys Jam 2025.2 ("Risk it for the biscuit")**
**Status: Jam build complete — now expanding**

---

## 1. Logline

You're one of four outlaw magical girls sent on a bounty mission — but the reward only splits so many ways. Fortune cookies foretell what's coming and hand you an edge; whether you use that edge to help your team or sabotage them is what decides who actually gets their wish.

*Sections marked **Open Design Question** are things that still need a decision before implementation — everything else reflects confirmed direction.*

---

## 2. Current Status & Direction

The jam version is complete and playable. This document scopes the **post-jam expansion**, which covers all four of the following in parallel:

- Deepen & rework core systems
- Add levels / content
- Polish & fix
- Public release prep

Practically: the systems below (Stardom, Reputation Actions, Fortune Cookies) existed in a jam-scoped form and need fuller rules; the world needs the Train and County Jail stages plus Witch enemies; and eventually a release needs full menus, settings, and a save system.

**Progress:** see `docs/IMPLEMENTATION_PLAN.md`. Phases 0–4 (Stardom, Reputation Actions, Results/Endings, and the manual-combat rework) are implemented in code. Phases 5–6 (branching mission content, polish, release prep) are not yet started.

---

## 3. Setting & Premise

You are part of a crew of outlaw magical girls in a weird-west setting, sent on a mission whose reward can only be split so many ways. Fortune cookies let you divine what's coming and gain an edge over your own would-be allies. You can risk it for the biscuit by sabotaging your teammates — but don't bite off more than you can chew, lest you discover firsthand the way the cookie crumbles.

---

## 4. Core Gameplay Loop

**1. Foretelling → 2. Camp Prep → 3. Stage → 4. Results → (repeat)**

### 1 · Foretelling
- Crack a Fortune Cookie: it rolls a random stat/status modifier that will apply during the next Stage, *and* surfaces a fortune — flavor text that hints at what that modifier is/does, without stating it outright.
- Which target/mission comes next branches based on the foretelling — this is not a fixed level order (see §7).

### 2 · Camp Prep
- Spend cookies and Reputation Actions on yourself or teammates: buff, debuff, resurrect a downed ally, or maneuver the social layer (Conspire / Persuade / Fight / Defamation / Commendation / Boast — see §6).
- Decide who deploys. Everyone not currently downed is eligible for the party.
- Gravy Crockett (vendor NPC) is here — grants 3 fresh fortune cookies per Camp Prep phase; cookies do not carry over between phases.

### 3 · Stage
- Sidescrolling combat level with the modifier(s) rolled during Foretelling active.
- Win condition: clear the stage → earn rewards toward Stardom. Lose condition: your character goes down.

### 4 · Results
- **Victory:** a character's Stardom target is reached → that character's Wish Granted scene plays.
- **Defeat:** a rival character reaches their Stardom target first.
- **Total loss:** all levels are exhausted with no one reaching their target → "Everyone in Jail" ending.

---

## 5. Core Systems

### Fortune Cookies
Cracking a cookie rolls a random entry from the Modifier Pool as a temporary stat/status effect for the upcoming Stage, and generates a fortune — a piece of flavor text that *hints at* the rolled effect rather than naming it. Reading the fortune correctly is how a player anticipates what they're walking into.

### Modifier Pool *(non-exhaustive — open to expansion)*
Projectile count · Range · Fire rate · Piercing · Dynamite · Splitting projectile · Knockback · Lifesteal · Damage over time · AoE · Stun duration · Burst · Turn (flee) · Projectile speed

> **Open Design Question:** What other modifiers round out the pool, and do any need to be flagged as strictly-negative vs. strictly-positive vs. situational (since a fortune has to hint at good *or* bad outcomes)?

### Stardom
Stardom is flavored as a bounty, but functions as a **score objective** per character — a target number to reach, not a currency you spend turn-to-turn. Reaching your target triggers your Wish Granted ending.

**Implemented (`scripts/data/global_vars.gd`):** +1 Stardom per personal kill (`STARDOM_PER_KO`), +10 to whoever landed the last kill when a Stage's final wave clears (`STARDOM_STAGE_CLEAR_BONUS`), target is 100 (`STARDOM_TARGET`). These are tunable constants, not final balance — retune freely once playtested.

### Reputation Actions — the Sabotage Layer
These are how you help your own Stardom push and/or hinder a rival's, during Camp Prep. Proposed mechanical read below — flag anything that should work differently:

| Action | Target | Proposed effect |
|---|---|---|
| **Divine** | Self | Crack a Fortune Cookie (see above). |
| **Conspire** | Ally | Align a teammate with you — they stop competing for Stardom this phase and their actions favor your push instead. |
| **Persuade** | Ally | Warn or encourage a teammate about deploying — sway whether they go on the next Stage or sit out. |
| **Fight** | Ally | Preemptively incapacitate a rival — puts them in the Downed state before the Stage even starts, removing them as competition. |
| **Defamation** | Ally | Steal Stardom progress directly from a rival, transferring it toward your own target. |
| **Commendation** | Ally | Give Stardom progress to an ally — costs you ground, builds goodwill (sets up a later Conspire, or just plays nice). |
| **Boast** | Self | Claim/allocate your own earned Stardom rather than leaving it contested — a "lock in my gains" action. |

**Implemented (`scripts/character_interact_ui.gd`):** Conspire and Boast are free but once per Camp Prep phase per character; Fight costs 1 fortune cookie; Defamation/Commendation move a flat 10 Stardom (`REPUTATION_TRANSFER_AMOUNT`) and require the source to have that much; Boast grants a flat +2 (`BOAST_AMOUNT`). None can currently be resisted/countered by the target — that's still open if it turns out to matter once playtested.

### Combat
Fully manual action combat — no auto-attacking. Sidescrolling, player-controlled movement.

- **Player controls:** Attack, Special (activated ability), Item use, Interact with party member (Heal / Hurt).
- **Party interaction:** ability frequency, buffs/debuffs, healing/resuscitation, engagement/personality/targeting style, friendly fire, and adding/removing abilities mid-run.
- **Luck-based abilities:** weighted by how rewards/modifiers have been allocated coming out of Foretelling.
- **Downed state:** a downed character is temporarily out — sits out combat/missions until revived (e.g. via a cookie or camp action). It does not end the run by itself.

**Implemented (`scripts/combat_player_controller.gd`, `project.godot` input map):** Attack (J / left joypad face button, held) fires on the existing cooldown but only while pressed — no more auto-fire when an enemy wanders into range. Special (K / joypad button 1) spends the full energy bar (`special_cost`, currently == `max_energy` for all 4 characters) and fires each character's previously-unused special projectile scene, now wired into their `.tres` data. Heal (H / joypad button 5) is **self-heal only for now** — spends `heal_cost` energy to restore `heal_amount` HP to whoever you're playing; ally healing was explicitly deferred rather than half-built without real ally-targeting detection. Item (L / joypad button 4) consumes a single-slot held item (see below). Ally/enemy AI auto-fire is unchanged on purpose — that's correct AI behavior, not the player auto-attack that was removed.

**Polish pass (post-playtest, see `docs/POLISH_PLAN.md`):**
- You can now move while attacking — the shoot animation no longer locks velocity to zero (`player_controller.gd`). Attack cooldown dropped from 1.0s to 0.35s (`data/*_default.tres`, `combat_player_controller.gd`) for a snappier rhythm. Movement acceleration/deceleration tightened (`walk_acceleration` 60→90, `slowdown_multiplier` 0.7→0.55) for a less floaty stop/start. All of these are first-pass tuning numbers, not final balance.
- Every hit now triggers a brief hitstop (`GlobalVars.hitstop()`), a floating damage number (`nodes/ui/damage_number.tscn`), and — when the player or an ally is the one taking the hit — a small camera shake (`scripts/camera_shake.gd`, attached to each Stage's Camera2D). All centralized in `Attack.hit()` so every attack source gets it for free.
- Enemies now have a floating health bar (`HealthBarBg`/`HealthBarFill` on all 4 enemy scenes, driven by `enemy.gd`).
- Enemy AI: periodically re-targets (every 4–7s) instead of locking onto one character all fight, flees for ~2.5s when dropping below 30% HP, and nudges away from other enemies standing too close (no more stacking on one spot).
- Ally AI: self-heals when below 30% HP and able to afford it, uses their special attack once charged, otherwise falls back to the basic attack — same separation nudge against other party members.

**Still not done after the polish pass:** true ally healing/targeting of *other* characters (self-heal only), and any form of dodge/juke reaction to incoming attacks — both explicitly scoped out of that pass rather than half-built. The dodge gap is now addressed by Dash below.

**Combat rework round 2 (see `docs/COMBAT_REWORK_PLAN.md`):**
- **Dash** (Left Shift / joypad button 3): a cooldown-gated repositioning burst for both the player and allies. **No invincibility frames** — this is pure repositioning, by request, so it dodges by moving you out of the way rather than making you immune. Allies dash reactively: each checks nearby enemy-sourced attacks every frame and bursts away from anything within `dash_danger_radius` — a proximity heuristic, not real trajectory prediction.
- **Bonnie's lasso rope was actually broken**, not just "feeling" wrong: the trailing rope's `AtlasTexture` crop had a height of `0`, so it was rendering nothing — the loop sprite was flying through the air with no visible connection back to Bonnie, reading exactly like "a generic bullet wearing a lasso texture." Replaced with a `Line2D` stretched live from Bonnie's hand to the loop's current position each frame, which connects both ends by construction rather than by a fragile texture crop.
- **Jane, Pearl, and Rose's bullets now have a small particle trail** (`GPUParticles2D`, per-character tinted) instead of being a bare sprite flying in a straight line. Rose previously shared the same `generic_attack.tscn` as several enemies; she now has her own `rose_attack.tscn` so her trail doesn't leak onto enemy bullets.
- **Fixed a standalone-testing gap:** `GlobalVars.unselected_character_scenes` defaulted to an empty array, so opening a Stage scene directly in the editor (skipping Character Select) spawned zero allies — not a UI bug, allies were genuinely absent from the world. Now defaults to the rest of the roster, matching how the normal flow already behaves.
- **`docs/TUNING.md`** now catalogues every tunable value in the project (movement, combat, dash, per-character/per-enemy stats, Stardom/Reputation constants, Stage Fortune magnitudes, HUD colors/thresholds) with descriptions, including a couple of pre-existing issues it surfaced in passing: `EntityAttributes.attack_power` is set but never actually read when dealing damage, and Lawman's `follow_range` is unset (defaults to `0.0`), likely why it wasn't flagged as behaviorally distinct earlier.

**Held item (new, minimal):** there was no inventory system at all before this — field pickups like the Holy Hard Tack instantly applied their effect on touch. Now picking one up stores it in a single `GlobalVars.held_item` slot (shown in the Stage HUD) instead, and pressing Item consumes it. Picking up a second item while already holding one **replaces** the held item (no stacking, no multiple slots) — simplest behavior for a one-slot system, revisit if it feels bad in play.

---

## 6. Level & World Structure

Mission order branches: the Foretelling step is what selects the next target/Stage, so the sequence of levels can vary between playthroughs rather than following one fixed story order.

- ✅ Camp (built)
- ✅ Desert (built)
- 🟡 Train (scaffolded — **placeholder art**, see below)
- 🟡 County Jail (scaffolded — **placeholder art**, see below)

**Implemented (`scripts/data/global_vars.gd`):** `GlobalVars.get_next_stage_scene()` maps the drawn `StageFortune` type to a target Stage scene, and both Gravy's "Start Mission" and the Camp⇄Stage loop (`advance_scene()`) go through it. Foretelling now genuinely branches: loot-flavored fortunes (Bounty Frenzy, Chicken Party) send you to the Train, danger-flavored fortunes (Chaotic Rave, Darwin's Stage) send you to the County Jail, everything else defaults to the Desert.

**Train and County Jail are real, playable Stages with placeholder art** (`scenes/train_stage.tscn`, `scenes/county_jail_stage.tscn`) — same `StageManager` structure as the Desert, with their own enemy wave compositions (Train: Gunslinger/Banker/Witch; County Jail: Lawman/Banker/Witch, tuned tougher). Their backgrounds (`nodes/objects/scenery/TrainBackground.tscn`, `CountyJailBackground.tscn`) are flat-color stand-ins with an on-screen "PLACEHOLDER BG" label so nobody mistakes them for finished art — reskin by swapping the `ColorRect`/`Label` nodes for real parallax layers once art exists, no other changes needed.

---

## 7. Characters

### Cattledriver Bonnie
*Impoverished rancher turned cattle driver, out of need*
- **Accessory:** Lasso
- **Themes:** Famine, cattle
- **Wish:** To end her family's hunger for good — lasting abundance and security, so she and her kin never starve again.

### Calamity Pearl
*Adrenaline-junkie train/bank robber, does it for the thrill*
- **Accessory:** Fan
- **Themes:** Greed, opulence
- **Wish:** One score to retire on — enough to finally stop. Whether she actually wants to stop is another matter.

### Rose the Reaper
*Hardened killer, outlawed for avenging her parents*
- **Accessory:** Revolver
- **Themes:** Death, crows
- **Wish:** Peace, now that the revenge is done. Having lived only for it, she wants to feel something else before it's over.

### Deputy Jane
*Sheriff's daughter, outlawed after being framed by a corrupt mayor*
- **Accessory:** Deputy badge
- **Themes:** Justice, scales
- **Wish:** To restore justice to the town — fix the corruption itself, so what happened to her can't happen to anyone else.

### Gravy Crockett
Crackpot merchant NPC. Not playable. Fortune Cookie dispenser: hands out 3 cookies at the start of every Camp Prep phase; unused cookies don't carry over.

---

## 8. Enemies

**Naming note:** "Sheriff" and "Bounty Hunter" from the original brainstorm doc were renamed during implementation to **Lawman** and **Gunslinger** respectively — same characters, not missing assets. **Banker** was added during implementation with no brainstorm-doc equivalent. **Witches** is the only enemy still without real art (placeholder tinted-triangle sprite).

| Enemy | Status | HP | Move Speed | Follow Range |
|---|---|---|---|---|
| Gunslinger | Implemented | 15 | 250 | 320 (long-range harasser) |
| Banker | Implemented | 10 | 200 | 150 (closer-range) |
| Lawman | Implemented | 30 | 150 | default (tankiest, slowest) |
| Witches | Scaffolded — **placeholder sprite** (tinted triangle), real AI | 20 | 170 | 280 |

Roster is a **mix**: Gunslinger/Banker/Lawman all share the default AI (`EnemyBehavior.TARGET_RANDOM`) and differ only by stats/attack projectile. Witches (`nodes/entities/npcs/combat/enemy/witch.tscn`) is mechanically distinct on purpose — it uses `EnemyBehavior.TARGET_STARDOM`, so it hunts down whoever's closest to their bounty rather than picking randomly, giving it a real "hex the front-runner" identity even with placeholder art. Swap its `AnimatedSprite2D`'s texture/frames for real art whenever it's ready; the AI and stats don't need to change.

---

## 9. Endings

- **Victory — Wish Granted:** your character's Stardom target is reached; their Wish Granted scene plays (see §7 for each character's wish).
- **Defeat:** a rival party member reaches their own Stardom target first.
- **Everyone in Jail:** all levels are finished with no one reaching their Stardom target.

---

## 10. Asset & Feature Checklist

**Story Scenes**
- [ ] Game start cutscene
- [ ] Level Won
- [ ] Level Lost
- [ ] Wish Granted

**Characters — Player**
- [x] Cattledriver Bonnie — Phase 1
- [x] Cattledriver Bonnie — Phase 2
- [x] Cattledriver Bonnie — Transformation
- [x] Calamity Pearl — Phase 1
- [x] Calamity Pearl — Phase 2
- [x] Calamity Pearl — Transformation
- [x] Rose the Reaper — Phase 1
- [x] Rose the Reaper — Phase 2
- [x] Rose the Reaper — Transformation
- [x] Deputy Jane — Phase 1
- [x] Deputy Jane — Phase 2
- [x] Deputy Jane — Transformation

**Characters — Enemy / Other**
- [x] Lawman *(was "Sheriff" in early brainstorm)*
- [x] Gunslinger *(was "Bounty Hunter" in early brainstorm)*
- [x] Banker
- [ ] Witches
- [x] Gravy Crockett

**Items**
- [x] Fortune Cookie
- [x] The Holy Hard Tack
- [x] Ginger Snap

**Environment**
- [x] Camp
- [x] Desert
- [ ] Train
- [ ] County Jail

**UI**
- [ ] Main Menu
- [ ] Tutorials — Movement
- [ ] Tutorials — Skill/item use/collection
- [ ] Tutorials — Combat
- [ ] Tutorials — Party interaction
- [ ] Tutorials — Stardom
- [ ] Tutorials — Revive
- [ ] Ability Select Menu
- [ ] Pop-up banner
- [ ] Bounty Poster

**Gameplay Features**
- [x] Enemy AI
- [ ] Teammate AI
- [ ] Stage results
- [ ] Combat interactions
- [ ] Items
- [ ] Fortune effects
- [ ] Character selection
- [ ] Tutorials

---

## 11. Music & SFX Direction

Reference points: dark classic country (Johnny Cash, Colter Wall — e.g. "Nothin'" by Colter Wall) and the Madoka Magica score, bridged with rock elements. Strings, acoustic guitar, violin, harmonica. Simple percussion evoking plodding through the desert at night; discordant, aria-like "vocals." Main theme leans slower old-country, shifting toward rock/Madoka-esque intensity as stakes rise.

**Music**
- [ ] Main theme — piano + violin + percussion
- [ ] Camp Prep BGM — banjo + harmonica
- [ ] Stage BGM — ragtime variant
- [ ] Stage BGM — "violin violence"
- [ ] Stage BGM — train whistle motif
- [ ] Stage BGM — brassy variant

**SFX**
- [ ] Open fortune cookie
- [ ] Gun

---

*Cleaned up from the original brainstorm doc for build purposes. Retained but not reproduced here: the early theme/story/joke brainstorm list that preceded the "Game design time!" section — worth keeping in the source doc as an idea archive, not as active spec.*

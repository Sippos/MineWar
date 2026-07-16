# Hero Animation Baseline

This file records the reviewed local animation state that must remain stable before gameplay polishing resumes.

## Authoritative source sheets

- Dwarf walk: `assets/sprites/characters/dwarf/dwarf_walk_highres_spritesheet.png`
- Dwarf attack: `assets/sprites/characters/dwarf/dwarf_attack_pixelart_spritesheet.png`
- Shaman walk: `character_sprites/shaman_walk_spritesheet_25d.png`
  - Uses the approved Druid-derived full-body gait for the legs and torso while stabilizing the left staff arm, removing the former raised-shoulder and arm-flailing cycle.
- Shaman attack: `character_sprites/shaman_attack_spritesheet_25d.png`
  - Uses the Druid staff strike transferred to the Shaman's actual staff hand (`hand.L`). It shares the walk sheet's model, camera, lighting, foot line, and direction-row order.
- Nerubian walk: `character_sprites/nerubian_walk_spritesheet_25d.png`
  - Uses the compact production gait rendered from the same source rig as the attack sheet.
- Nerubian attack: `character_sprites/nerubian_attack_spritesheet_25d.png`
  - Uses the matching production action render, with the same model, center, exposure, and frame envelope as walking.
- Druid humanoid walk: `character_sprites/druid_walk_spritesheet_25d.png`
  - Uses the real-motion revision with corrected exposure and safe per-frame margins.
- Druid humanoid attack: `character_sprites/druid_humanoid_staff_swing_spritesheet_25d.png`
- Druid Mole crawl: `character_sprites/druid_mole_crawl_spritesheet_25d.png`
  - Uses the bright restored crawl revision rather than the earlier dark render.
- Druid Mole attack: `character_sprites/druid_mole_attack_spritesheet_25d.png`
  - Uses the matching bright action revision as a separate digging/attack state.
- Undead minion walk: `character_sprites/undead_minion_walk_spritesheet_25d.png`
  - Rerendered from the original `undeadMinion` Blender rig and `UndeadMinion_Walk` action using the complete animation envelope. All 64 frames retain safe transparent margins.

All reviewed animation sheets remain 1024×1024 images arranged as eight direction rows by eight animation frames.

## Runtime rules

- Direction selection is updated before the final animation state is chosen.
- The walk, action, or Mole texture is selected before frame advancement.
- Dwarf attack uses an independent scale and baseline so the character does not shrink during the hammer swing.
- Shaman walk and attack use the same direction row with no horizontal mirroring. The matching atlases use one grounded fit, removing the former shoulder/spacing jump and wrong-hand remapping.
- Nerubian ordinary melee and brood casting both activate the matching action sheet.
- Druid humanoid movement always switches back to the humanoid walk sheet before advancing walk frames.
- Mole movement uses the restored crawl sheet; digging and attacking use the separate reviewed Mole action sheet.
- Action cycles loop through the full sheet instead of being reset on every damage tick.
- The Undead minion keeps its existing movement logic and eight-direction row mapping; only the source atlas and sprite fit changed.

## Current fitted visuals

- Dwarf: walk scale `0.85`; attack scale `1.12`; attack baseline raised slightly.
- Shaman: walk and action scale `0.64`; shared sprite position `(0, -5)`.
- Nerubian: walk and action scale `0.46`; shared sprite position `(0, -9)`.
- Druid humanoid: walk scale `0.50` at `(0, -7)`; attack scale `0.62` at `(0, -4)`.
- Druid Mole: scale `0.70`; sprite position `(0, -10)`.
- Undead minion: scale `0.56`; sprite position `(0, -8)`.

## Regression coverage

`tests/test_hero_animation_baseline.gd` verifies:

- all reviewed sheets exist, import, and retain the expected 8×8 layout;
- Dwarf attack has its independent corrective fit;
- Shaman action uses the same facing row without mirroring and retains the shared grounded fit;
- Shaman and Nerubian walk sheets contain substantial full-body motion between stride frames;
- Nerubian movement and action use the matching production paths and identical fit;
- Nerubian melee and brood casting select the action state;
- Druid humanoid movement selects and advances the walk sheet;
- Mole crawl and action states use their intended textures;
- the Undead minion scene uses the safe-margin atlas fit and its walk frames still advance.

The baseline was accepted after a clean Godot headless parser/import check, a 26/26 automated test pass, and an animated review using the exact current production assets and runtime fits. That review confirmed grounded matching Shaman walk/action silhouettes, matched uncropped Nerubian movement/action silhouettes, and clean Undead-minion rendering in right, diagonal, down, and left directions.
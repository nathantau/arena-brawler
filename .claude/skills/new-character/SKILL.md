---
name: new-character
description: Add a new playable character to Brawlbit — procedural pixel-art sprite sheet (tools/sprites/generate.py), CharacterData .tres, tests, preview. Use when asked to make, design, draw or add a character/hero/fighter, or to redesign an existing character's sprite.
---

# New character

Characters are drawn in code by `tools/sprites/generate.py` (Pillow, project venv) and loaded by
`CharacterCatalog` from `data/characters/*.tres`. Adding one touches four places: generator,
`.tres`, the catalog test, CLAUDE.md Status.

## Rules

- **Original art only** (CLAUDE.md rule). Public-domain myth/folklore figures are fine; never copy a
  specific game/anime design, costume or signature item. Name the inspiration loosely, then make it ours.
- 64x64 frame, facing **right**, palette colours only (`palette.py`, 16 colours — do not add colours
  without asking), hard alpha, nothing touching the frame edge. `check()` enforces this.
- House style (keep characters consistent):
  - Chibi: head ~ half the height, stubby `legs()`; upper body is composited `UPPER_DY` px down.
  - Eyes via `big_eyes(c, y, (x, x + 10), iris)` — **6 px gap, always `x` and `x + 10`**.
  - `face(c, (left_x, right_x, y), mouth)` for blush (+ optional mouth) under the eyes.
  - Build from `part()` (auto-shaded + inner line), `flat()` for details, `dot()` for single pixels.
    Overlapping blobs that should read as one shape go in **one** `part()` (a lambda drawing several
    shapes), otherwise each gets its own highlight streak.
  - Draw back-to-front: tail/back items, body, hands, head, face, then front accessories.
  - One readable signature silhouette element (hat, plume, shield, feathers...).
- Leg details must use the `(x, dy)` list `legs()` returns, so they follow the walk cycle.
- No hands on the sheet: add the character's glove/skin colour to `HANDS` and set `hand_sprite` in the `.tres`
  (`res://assets/sprites/<id>_hand.png`); the game draws hands on the held weapon.

## Steps

1. Write `def <id>(step=None, t=0)` in generate.py next to the others, returning `(low, up)` canvases.
   `step` = walk frame (legs), `t` = frame tick (idle 0-3, walk 0-7). Give every character at least
   one small loop driven by `SWAY[t % 4]` (fluttering cloth, swaying feather/tail) or a `t % 4 == 0`
   glint. For effects around the body (smoke, clouds, sparks) add `def <id>_<fx>(i) -> Canvas` and
   register it in `AURAS`; it is drawn behind the character. Keep loops period 4 so idle and walk both loop.
2. Register in `CHARACTERS`, run `tools/sprites/.venv/bin/python tools/sprites/generate.py`.
3. **Look at it.** Paste the sheet on a dark background, scale x8 with NEAREST, save to the
   scratchpad and Read the PNG. Iterate until it reads at a glance (silhouette, face, signature item).
   Also check the walk frames (6-13) as a GIF and that loops are smooth.
4. Create `data/characters/<id>.tres` (copy an existing one): `id`, `display_name`, `skill_name`,
   stats, `skill` (existing `SkillKind` only — a new skill kind is gameplay work, ask first),
   `sprite_sheet = ExtResource(...)` pointing at `res://assets/sprites/<id>.png`, `weapon_tags` (own id + 2-3
   weapon classes, so every pickup stays shared by 2+ characters) and `signature_weapon`.
   Signature weapon: draw it in `WEAPONS` (48x24, pointing right, grip at `GRIP`), add
   `data/weapons/<id>_<weapon>.tres` with `pickup = false`, `energy_cost = 0`, `tags = [&"<id>"]`, and give it one
   distinct behaviour (existing fields: pierce, bounces, splash, melee slam/thrust, reflects).
5. Update the character count in `tests/test_skills_and_movement.gd`
   (`test_catalog_covers_every_skill_kind`).
6. `godot --headless --import`, then run GUT (all must pass).
7. In-game check: `godot --path . --write-movie <scratch>/f.png --fixed-fps 30 --quit-after 120 -- --offline --autopilot --touch --character <id>`
   and Read a frame.
8. Add the character to the Pixel-art sprites entry in CLAUDE.md Status, commit.
9. Send the user the zoomed sheet / GIF and an in-game frame.

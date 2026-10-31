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
- 64x64 frame, facing **right**, palette colours only (`palette.py`, 18 colours — do not add colours
  without asking), hard alpha, nothing touching the frame edge. `check()` enforces this.
- House style (keep characters consistent):
  - Chibi: head ~ half the height, stubby `legs()`; upper body is composited `UPPER_DY` px down.
  - **One shared base for everyone, modelled on Apex's face:** `up.part(RR(FACE, FACE_R), <skin>)` for the face,
    `RR(BODY, 3)` for the torso, `big_eyes(c, EYES_Y, EYES_X, iris)` for the eyes, `face(c, BLUSH, MOUTH)` for blush
    and mouth. The face sits right of centre (turned right); hair or a back-of-head filling `HEAD` keeps the
    head centred over the body, or it looks like a crooked neck. Never a custom face size or eye spot: personality comes from hair, hats, masks, outfits, iris colour.
  - Build from `part()` (auto-shaded + inner line), `flat()` for details, `dot()` for single pixels.
    Overlapping blobs that should read as one shape go in **one** `part()` (a lambda drawing several
    shapes), otherwise each gets its own highlight streak.
  - Draw back-to-front: tail/back items, body, hands, head, face, then front accessories.
  - One readable signature silhouette element (hat, plume, shield, feathers...).
- Design decisions from the user (keep to them):
  - **Same shape for everyone.** Faces are rounded squares (`FACE_R`), never ovals; same size and spot for every
    character. Only hair, headwear, masks, outfits and colours differ.
  - **No stray inner lines.** `part()` outlines every edge that lands on something already drawn, so a bang,
    curtain or lock drawn as its own shape over the hair or face gets a dark seam. Shapes that should read as one
    mass (a curtain and the lock under it, a molten head and face) go in one `part()`; a top edge buried in the
    hair either sits outside it or uses `line=False`. Zoom x6 and look for lines across foreheads and hair.
  - **Symmetry where it's meant.** Middle parts, curtains and side locks are mirrored about the face's centre
    (`(FACE[0] + FACE[2]) // 2`): build one side's points and mirror them, don't hand-place both.
  - **Hair and accessories never cover the eyes.** Bangs stop above `EYES_Y`, locks stay outside the face's sides,
    masks start below the eyes. Lashes flick out from the *outer* corners (inner-corner pixels read as angry).
  - **Girls read as girls at a glance:** long hair (ponytail / long locks), lashes, a softer outfit line.
  - **Wind / flow:** hair and loose cloth move in a wave: `wave(lag, amp)` on `HAIR_FLOW` (see `sakura`), points
    further from where the thing is held lag a step and swing wider. Period 4 so it loops in idle and walk; keep
    swings to a few px or it jitters at game size.
  - **Fire / flames** (`flame()`, `CROWNS`): no wider than the head, centred on it, or side tongues read as horns.
  - **Show before you change a look.** For a redesign or fix the user asked to see, render before/after into the
    scratchpad and wait for their okay before committing or installing.
- Death frames are generated automatically from the standing pose. Eyes must come from `big_eyes()`; custom
  eyes need an `if KO: x_eye(...)` branch (see Warden / Great Ape) so the knocked-out frames get X eyes.
- Leg details must use the `(x, dy)` list `legs()` returns, so they follow the walk cycle.
- No hands or arms holding things: weapons float at the chest (the game draws them). Sleeves that hang from the
  shoulders (kimono, cape) are fine on the sheet.

## Steps

1. Write `def <id>(step=None, t=0)` in generate.py next to the others, returning `(low, up)` canvases.
   `step` = walk frame (legs), `t` = frame tick (idle 0-3, walk 0-7). Give every character at least
   one small loop driven by `SWAY[t % 4]` or the `HAIR_FLOW` wave (fluttering cloth, flowing hair, swaying
   feather/tail) or a `t % 4 == 0` glint. Walk plays at the idle pace (`SPRITE_WALK_FPS = SPRITE_IDLE_FPS`), so
   every frame is seen. For effects around the body (smoke, clouds, sparks) add `def <id>_<fx>(i) -> Canvas` and
   register it in `AURAS`; it is drawn behind the character. Keep loops period 4 so idle and walk both loop.
2. Register in `CHARACTERS`, run `tools/sprites/.venv/bin/python tools/sprites/generate.py`.
3. **Look at it.** Paste the sheet on a dark background, scale x8 with NEAREST, save to the
   scratchpad and Read the PNG. Iterate until it reads at a glance (silhouette, face, signature item).
   Also check the walk frames (6-13) as a GIF and that loops are smooth.
4. Create `data/characters/<id>.tres` (copy an existing one): `id`, `display_name`, stats,
   optional `signature_skill` (a `data/skills/*.tres` tagged with the character's id; reuse an existing
   `SkillData.Kind` — a new kind is gameplay work, ask first; TRANSFORM forms go in generate.py `FORMS`),
   `sprite_sheet = ExtResource(...)` pointing at `res://assets/sprites/<id>.png`, `weapon_tags` (own id + 2-3
   weapon classes, so every pickup stays shared by 2+ characters) and `signature_weapon`.
   Signature weapon: draw it in `WEAPONS` (48x24, pointing right, grip at `GRIP`), add
   `data/weapons/<id>_<weapon>.tres` with `pickup = false`, `energy_cost = 0`, `tags = [&"<id>"]`, and give it one
   distinct behaviour (existing fields: pierce, bounces, splash, melee slam/thrust, reflects).
5. Update the character count in `tests/test_skills_and_movement.gd` (`test_catalog_and_skills`).
6. `godot --headless --import`, then run GUT (all must pass).
7. In-game check: `godot --path . --write-movie <scratch>/f.png --fixed-fps 30 --quit-after 120 -- --offline --autopilot --touch --character <id>`
   and Read a frame.
8. Add the character to the Pixel-art sprites entry in CLAUDE.md Status, commit.
9. Send the user the zoomed sheet / GIF and an in-game frame.

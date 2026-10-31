---
name: transform-morph
description: Make the transition animation for a TRANSFORM special in BrawlBits (character morphing into its form and back, like Wukong -> Great Ape) — generate.py morph strip, SkillData.form_morph, preview GIF. Use when adding a transformation, or asked for frames transitioning a character into its form.
---

# Transformation morph

A TRANSFORM `SkillData` swaps the player's sprite to `form_sprite_sheet` (drawn x `form_scale`).
`form_morph` is an optional strip that `SpecialFx` plays over ~0.55 s (`MORPH_TIME`) when the form
starts — at the normal sprite scale with the growth to `form_scale` drawn into its 96 px frames, real sprite
hidden (`Player` uses `is_morphing()`) — and backwards when it ends. Purely cosmetic: stats switch instantly.

## Steps

1. The form itself must exist first: `def <id>_<form>(step=None, t=0)` in generate.py `FORMS`
   (+ optional aura in `AURAS`), same rules as the `new-character` skill.
2. Write `def <form>_morph(t, scale) -> Image.Image` next to `ape_morph` (copy it): an in-between creature
   `t` of the way from character to form, drawn **crisp at `scale`** into a CELL frame (map art points with its
   `pt`/`pts`/`box` helpers, never resize art). Interpolate every body part's shape between the two designs
   (same point count both sides), sprout new parts (arms, fists) from where they'd grow, shrink away
   character-only bits (feathers, collar), and **stagger** colour switches (fur first, then face/eyes/chest)
   so no single frame changes everything. The user wants to see the body stretching and morphing — not a
   crossfade, not white silhouettes, not a scaled-up copy of the sprite.
3. Add the strip to `FX` in generate.py:
   ```python
   "<id>_<form>_morph": lambda: strip(morph_frames(frames(<id>, AURAS.get("<id>"))[0],
                                                   frames(<id>_<form>, AURAS.get("<id>_<form>"))[0],
                                                   <form_scale>, <form>_morph)),
   ```
   `<form_scale>` must match the skill's `form_scale`. Frames: the character, six in-betweens (t 0.15-0.9,
   growing, gold sparks), the form. Run the generator and Read a x3 NEAREST preview; iterate until each
   step changes a little and the first and last in-betweens still read as their neighbours.
4. In `data/skills/<skill>.tres` add an `ext_resource` for `res://assets/fx/<id>_<form>_morph.png` and
   `form_morph = ExtResource("...")`.
5. `godot --headless --import`, run GUT.
6. Preview both directions with the `pixel-fx` skill's movie recipe (`--character <id> --special <skill>`):
   start ≈ movie frames 200-270, end ≈ 30 × (7 + duration) ± 15. Check: lightning, morph grows,
   cloud bursts on the player at `MORPH_POOF_AT`, then the form; at the end a dark puff and the morph
   reversed. Send the user both GIFs; update CLAUDE.md Status; commit.

---
name: transform-morph
description: Make the transition animation for a TRANSFORM special in Brawlbit (character morphing into its form and back, like Wukong -> Great Ape) — generate.py morph strip, SkillData.form_morph, preview GIF. Use when adding a transformation, or asked for frames transitioning a character into its form.
---

# Transformation morph

A TRANSFORM `SkillData` swaps the player's sprite to `form_sprite_sheet` (drawn x `form_scale`).
`form_morph` is an optional strip that `SpecialFx` plays over ~0.55 s (`MORPH_TIME`) when the form
starts — growing from scale 1 to `form_scale`, real sprite hidden (`Player` uses `is_morphing()`) — and
backwards when it ends. Purely cosmetic: stats switch instantly.

## Steps

1. The form itself must exist first: `def <id>_<form>(step=None, t=0)` in generate.py `FORMS`
   (+ optional aura in `AURAS`), same rules as the `new-character` skill.
2. Add the strip to `FX` in generate.py:
   ```python
   "<id>_<form>_morph": lambda: strip(morph_frames(frames(<id>, AURAS.get("<id>"))[0],
                                                   frames(<id>_<form>, AURAS.get("<id>_<form>"))[0])),
   ```
   `morph_frames(a, b)` gives 8 frames: a → 6 full-colour ordered-dither crossfades with gold spark
   crackles → b. No white silhouettes (the user didn't like them). Tweak the
   spark colour / count there if the form has a different theme (keep it generic; pass a parameter
   rather than forking the function).
3. Run the generator; Read a x4 NEAREST preview. Each middle frame should still show both outlines
   (if it turns into a shapeless blob, the sprites are being unioned instead of picked per pixel).
4. In `data/skills/<skill>.tres` add an `ext_resource` for `res://assets/fx/<id>_<form>_morph.png` and
   `form_morph = ExtResource("...")`.
5. `godot --headless --import`, run GUT.
6. Preview both directions with the `pixel-fx` skill's movie recipe (`--character <id> --special <skill>`):
   start ≈ movie frames 200-270, end ≈ 30 × (7 + duration) ± 15. Check: lightning, morph grows,
   cloud bursts on the player at `MORPH_POOF_AT`, then the form; at the end a dark puff and the morph
   reversed. Send the user both GIFs; update CLAUDE.md Status; commit.

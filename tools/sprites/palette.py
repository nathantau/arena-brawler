"""Shared 16-colour palette for all generated sprites (RGB). Index 0 is the outline colour."""

OUTLINE = (27, 26, 46)
SHADOW = (58, 58, 92)
STEEL_D = (93, 107, 138)
STEEL = (154, 167, 194)
WHITE = (242, 240, 230)
SKIN_D = (184, 117, 79)
SKIN = (240, 193, 154)
RED = (217, 71, 75)
ORANGE = (240, 138, 62)
YELLOW = (245, 210, 86)
GREEN = (91, 184, 93)
TEAL = (47, 158, 147)
TEAL_L = (126, 224, 207)
BLUE = (60, 111, 209)
NAVY = (43, 58, 107)
BROWN = (110, 70, 48)

PALETTE = [OUTLINE, SHADOW, STEEL_D, STEEL, WHITE, SKIN_D, SKIN, RED,
           ORANGE, YELLOW, GREEN, TEAL, TEAL_L, BLUE, NAVY, BROWN]
assert len(set(PALETTE)) == 16

# One step lighter for each colour: used for the second hit-flash frame.
LIGHTER = {
    OUTLINE: OUTLINE, SHADOW: STEEL_D, STEEL_D: STEEL, STEEL: WHITE, WHITE: WHITE,
    SKIN_D: SKIN, SKIN: WHITE, RED: ORANGE, ORANGE: YELLOW, YELLOW: WHITE,
    GREEN: TEAL_L, TEAL: TEAL_L, TEAL_L: WHITE, BLUE: STEEL, NAVY: BLUE, BROWN: SKIN_D,
}
assert set(LIGHTER) == set(PALETTE) and set(LIGHTER.values()) <= set(PALETTE)

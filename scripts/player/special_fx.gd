class_name SpecialFx
extends Node2D
## Cosmetic, on every peer: the smoke cloud, shadow clones and eruption crack of a player's special, rebuilt each
## frame from the synced skill state (Player calls sync()). Clones copy the owner's sprite,
## walk animation, weapon and hand so they're hard to tell apart.
## Start / end flourishes are detected from state changes (so remote players get them too):
## each clone appears from its own cloud poof around the player and vanishes in one; a transformation morphs into
## the form (SkillData.form_morph) and morphs back when it ends (no cloud drawn over the ape); the Blossom Ward's
## petals burst out into a ring that follows the player, scatter when it ends and pop where it catches a shot.
## Grapple Kunai: the kunai flies out trailing its chain, sparks where it bites and she zips along it in her own
## pose with speed lines; a miss (seen as the short cooldown appearing) flies out to full range and snaps back.
## An eruption's crack gives way to its pillar of fire. All pixel-art strips from
## tools/sprites/generate.py (assets/fx), drawn at the characters' pixel scale.
## Vine Swing: the owner's sprite is hidden while his swing pose is drawn raised along the arc, hanging by one fist
## from a vine whose pivot is above the arc's midpoint; leaves burst at takeoff, dust puffs on landing, then the
## vine swings on and pulls up. Progress comes from where the body is drawn along the takeoff -> landing line, so
## interpolated remote players (whose skill state runs ahead of their drawn position) stay in step.
## Blossom Snare: whoever it hits gets pink vines coiled round their feet for as long as their synced slow lasts, and
## a burst of petals when it lands (from the slow time jumping up, so every peer sees both).

const FX_DIR: String = "res://assets/fx/"
const POOF_BIG: Texture2D = preload(FX_DIR + "poof.png")
const POOF_SMALL: Texture2D = preload(FX_DIR + "poof_small.png")
const SMOKE_ART: Texture2D = preload(FX_DIR + "smoke.png")
const WARD_ART: Texture2D = preload(FX_DIR + "blossom_ward.png")
const WARD_OPEN_ART: Texture2D = preload(FX_DIR + "blossom_ward_open.png")
const WARD_CLOSE_ART: Texture2D = preload(FX_DIR + "blossom_ward_close.png")
const PETAL_POP_ART: Texture2D = preload(FX_DIR + "petal_pop.png")
## The ward strips are drawn for this radius (generate.py WARD_R art px x SPRITE_SCALE); other radii scale them.
const WARD_ART_RADIUS: float = 69.0
const WARD_FPS: float = 20.0
const WARD_OPEN_TIME: float = 0.3
const WARD_CLOSE_TIME: float = 0.5
const PETAL_POP_TIME: float = 0.3
const SNARE_ART: Texture2D = preload(FX_DIR + "snare_vines.png")
const SNARE_BURST_ART: Texture2D = preload(FX_DIR + "snare_burst.png")
## A jump in the synced snare time bigger than this is a new hit (the time only ticks down between snapshots).
const SNARE_NEW_MARGIN: float = 0.2
const SNARE_FPS: float = 16.0
const SNARE_BURST_TIME: float = 0.5
## Row of snare_vines.png the ground ring is centred on (generate.py SNARE_BASE_Y), put on the owner's feet.
const SNARE_BASE_Y: float = 26.0
const SAPLING_GROW_ART: Texture2D = preload(FX_DIR + "sapling_grow.png")
const SAPLING_IDLE_ART: Texture2D = preload(FX_DIR + "sapling_idle.png")
const SAPLING_FIRE_ART: Texture2D = preload(FX_DIR + "sapling_fire.png")
const SAPLING_WILT_ART: Texture2D = preload(FX_DIR + "sapling_wilt.png")
## Row of the sapling strips the trunk stands on (generate.py SAPLING_BASE): it sits on the planting spot.
const SAPLING_BASE_Y: float = 56.0
const SAPLING_FPS: float = 24.0
const SAPLING_IDLE_FPS: float = 10.0
const SAPLING_FIRE_FPS: float = 32.0
const CRACK_ART: Texture2D = preload(FX_DIR + "eruption_crack.png")
const ERUPTION_ART: Texture2D = preload(FX_DIR + "eruption.png")
## Ease-in times (s) so floor marks and loops don't pop on, and the ward's floor glow colour.
const CRACK_EASE_IN: float = 0.15
const RING_EASE_IN: float = 0.1
const SMOKE_EASE_IN: float = 0.12
const OD_DOUBLE_ALPHA: float = 0.6  # a second, out-of-step crackle frame: the 1 px arcs were too faint alone
const WARD_GLOW: Color = Color(1.0, 0.72, 0.86)
const WARD_GLOW_ALPHA: float = 0.14
const WARD_RING_ALPHA: float = 0.45
const CRACK_FPS: float = 24.0  # 16-frame loop (was 8 at 12)
## The crack's ring of embers is drawn for this blast radius (generate.py ERUPT_R); other radii scale it.
const ERUPTION_ART_RADIUS: float = 80.0
## Row of eruption.png the pillar rises from (generate.py ERUPT_BASE): it sits on the marked spot.
const ERUPTION_BASE_Y: float = 204.0
## The eruption strip: ERUPTION_FRAMES (generate.py ERUPT_FRAMES) at ERUPTION_FPS, the burst landing on frame ERUPTION_BLAST_FRAME.
const ERUPTION_FRAMES: float = 39.0
const ERUPTION_FPS: float = 22.5  # 39 frames (was 26 at 15): same 1.73 s
const ERUPTION_BLAST_FRAME: float = 6.0
const ERUPTION_TIME: float = ERUPTION_FRAMES / ERUPTION_FPS
## The strip starts this long before the blast lands, so its first frames (the floor bulging) lead into the burst.
const ERUPTION_LEAD: float = ERUPTION_BLAST_FRAME / ERUPTION_FPS
const POOF_TIME: float = 0.5
const SMOKE_FPS: float = 10.0
## The cloud swells in when thrown and fades out at the end instead of popping.
const SMOKE_SWELL_TIME: float = 0.25
const SMOKE_SWELL_FROM: float = 0.4
## smoke.png is drawn for this radius; other radii scale it.
const SMOKE_ART_RADIUS: float = 90.0
const SMOKE_ALPHA: float = 0.9
const FADE_TIME: float = 0.4
## Clones fade in inside their cloud while it's at its fullest (it plays slower than other poofs).
const APPEAR_DELAY: float = 0.08
const APPEAR_TIME: float = 0.2
const CLONE_POOF_TIME: float = 0.7
const MORPH_TIME: float = 1.0
const ZIP_ART: Texture2D = preload(FX_DIR + "flicker_zip.png")
const SPARK_ART: Texture2D = preload(FX_DIR + "grapple_spark.png")
const CHAIN_ART: Texture2D = preload(FX_DIR + "grapple_chain.png")
const THROW_ART: Texture2D = preload(FX_DIR + "grapple_throw.png")
const LAND_ART: Texture2D = preload(FX_DIR + "grapple_land.png")
const KUNAI_ART: Texture2D = preload("res://assets/sprites/projectiles/flicker_kunai.png")
const ZIP_FPS: float = 24.0  # 8-frame loop (was 4 at 12): same cycle time
const CHAIN_FPS: float = 16.0
const THROW_TIME: float = 0.2
const LAND_TIME: float = 0.25
## The landing strip's floor line is 12 art px below its cell centre; her soles are this far below her centre (world px).
const LAND_FEET_Y: float = 26.0
## Staff Whirl: the spin pose and the ring on the floor loop at WHIRL_FPS; the ring art is drawn for this radius
## (generate.py WHIRL_R art px x SPRITE_SCALE), other radii scale it. Sparks fly off the rim on every damage tick.
const WHIRL_ART: Texture2D = preload(FX_DIR + "wukong_whirl.png")
const WHIRL_RING_ART: Texture2D = preload(FX_DIR + "whirl_ring.png")
const WHIRL_SPARK_ART: Texture2D = preload(FX_DIR + "whirl_spark.png")
const WHIRL_FPS: float = 24.0  # 12-frame loops (generate.py WHIRL_FRAMES): same spin speed as 8 frames at 16
const WHIRL_ART_RADIUS: float = 69.0
const WHIRL_SPARK_TIME: float = 0.25
## The start / end dust is a small poof at his feet, shrunk so it does not hide him.
const WHIRL_DUST_SCALE: float = 0.6
## Where the sparks sit on the rim, as a fraction of the radius (the ring is squashed like the art).
const WHIRL_SPARK_REACH: float = 0.9
const WHIRL_RING_SQUASH: float = 0.8
## Sky Pillar: his plant / slam pose and the pillar along the stored line (generate.py PILLAR_*: frames of PILLAR_W art px,
## the staff's base PILLAR_BASE_X px in; the line is drawn cropped to its length, never stretched).
const PILLAR_POSE_ART: Texture2D = preload(FX_DIR + "wukong_pillar.png")
const PILLAR_ART: Texture2D = preload(FX_DIR + "sky_pillar.png")
const PILLAR_FRAME_W: float = 228.0
const PILLAR_BASE_X: float = 8.0
## Flare Burst: his charge pose strip (generate.py FLARE_CHARGE_FRAMES CELL frames over `nova_charge`), then the ring of fire
## (FLARE_FRAMES square frames, centred on his feet, its reach FLARE_ART_RADIUS art px = the blast's radius / SPRITE_SCALE).
const FLARE_CHARGE_ART: Texture2D = preload(FX_DIR + "flint_flare.png")
const FLARE_RING_ART: Texture2D = preload(FX_DIR + "flare_ring.png")
const FLARE_RING_FLOOR_ART: Texture2D = preload(FX_DIR + "flare_ring_floor.png")  # its scorch and glow, under the players
const FLARE_RING_TIME: float = 0.7
const FLARE_ART_RADIUS: float = 80.0
## Supernova (VOLLEY of 16 fireballs, generate.py SUPERNOVA_*): a burst of fire and sparks centred on him the step it goes off.
const SUPERNOVA_ART: Texture2D = preload(FX_DIR + "supernova_burst.png")
const SUPERNOVA_TIME: float = 0.55
## Storm Cloud (generate.py STORM_*): the cloud forms (STORM_FRAMES at STORM_FPS), loops while it rains, disperses; its
## art is STORM_SIZE px square with the spot on the floor at row STORM_FLOOR_Y and the cloud's underside at row
## STORM_BASE_Y. Bolts (BOLT_W x BOLT_H art px per frame, ending BOLT_END_Y rows down) are cropped to length, never stretched.
const STORM_ART: Texture2D = preload(FX_DIR + "storm_cloud.png")
const STORM_FORM_ART: Texture2D = preload(FX_DIR + "storm_cloud_form.png")
const STORM_END_ART: Texture2D = preload(FX_DIR + "storm_cloud_end.png")
const STORM_SPARK_ART: Texture2D = preload(FX_DIR + "storm_spark.png")
## The cloud's floor shadow and a strike's scorch are their own strips (same frames), drawn on the floor layer.
const STORM_FLOOR_ART: Texture2D = preload(FX_DIR + "storm_floor.png")
const STORM_FLOOR_FORM_ART: Texture2D = preload(FX_DIR + "storm_floor_form.png")
const STORM_FLOOR_END_ART: Texture2D = preload(FX_DIR + "storm_floor_end.png")
const STORM_SCORCH_ART: Texture2D = preload(FX_DIR + "storm_scorch.png")
const STORM_BOLT_ART: Texture2D = preload(FX_DIR + "storm_bolt.png")
const STORM_SIZE: float = 136.0
const STORM_FLOOR_Y: float = 112.0
const STORM_BASE_Y: float = 62.0
const STORM_FPS: float = 15.0  # the 12-frame raining loop (generate.py STORM_LOOP): same period as 8 frames at 10
const STORM_FRAME_COUNT: int = 8
const STORM_LOOP_COUNT: int = 12
const STORM_FORM_TIME: float = STORM_FRAME_COUNT / 12.0
const STORM_END_TIME: float = 0.6
const BOLT_W: float = 36.0
const BOLT_END_Y: float = 136.0
const BOLT_FPS: float = 20.0
const BOLT_TIME: float = 0.25
const BOLT_MIN_LENGTH: float = 16.0
const STORM_SPARK_TIME: float = 0.35
## Her outstretched hand in the zip pose (generate.py flicker_zip), from the sprite's centre, facing right.
const ZIP_HAND: Vector2 = Vector2(35, 14)
## Art px from the kunai sprite's centre to its tip and to its ring (generate.py kunai).
const KUNAI_TIP: float = 7.0
const KUNAI_RING: float = 6.0
## Art px between chain links (each link is 6 long, so they overlap like a chain).
const CHAIN_LINK_STEP: float = 4.0
const SPARK_TIME: float = 0.3
## A miss: out to full range, then snapped back faster.
const MISS_OUT_TIME: float = 0.14
const MISS_BACK_TIME: float = 0.1
const SPEED_LINES: int = 5
const SPEED_LINE_GAP: float = 12.0
const SPEED_LINE_LEN: float = 26.0
const SPEED_LINE_SCROLL: float = 900.0
const SPEED_LINE_SPAN: float = 70.0
const SPEED_LINE_COLORS: Array[Color] = [Color("f2f0e6"), Color("9aa7c2")]  # palette WHITE, STEEL
const SWING_ART: Texture2D = preload(FX_DIR + "wukong_swing.png")
const VINE_ART: Texture2D = preload(FX_DIR + "vine.png")
const VINE_TOP: Texture2D = preload(FX_DIR + "vine_top.png")
const LEAF_BURST: Texture2D = preload(FX_DIR + "leaf_burst.png")
const SWING_DUST: Texture2D = preload(FX_DIR + "swing_dust.png")
## The gripping fist in a swing frame (cell px; generate.py SWING_HAND): the vine ends there.
const SWING_HAND: Vector2 = Vector2(65, 13)
## How high he rises off the floor mid-swing, and how high above the arc's midpoint the vine hangs from.
const SWING_LIFT_PX: float = 56.0
const VINE_PIVOT_HEIGHT: float = 230.0
## Keep drawing the swing this long after it ends in the synced state, until the drawn body reaches the landing.
const SWING_LINGER: float = 0.25
const VINE_RETRACT_TIME: float = 0.35
## The vine swings on past the landing by this much (radians) while it pulls up.
const VINE_OVERSHOOT: float = 0.6
const LEAF_TIME: float = 0.45
const DUST_TIME: float = 0.4
## Takeoff leaves and landing dust sit at his feet, not his middle.
const SWING_FEET_Y: float = 26.0
## Blaze Run: burning ground stamped along the trail (generate.py BLAZE_*), an ignition flare at takeoff, the fire dying
## out over the last BLAZE_DIE_TIME (stamp by stamp from the start), and a streak of flame on the runner while he dashes.
const BLAZE_FLAMES_ART: Texture2D = preload(FX_DIR + "blaze_run_flames.png")
const BLAZE_IGNITE_ART: Texture2D = preload(FX_DIR + "blaze_run_ignite.png")
const BLAZE_STREAK_ART: Texture2D = preload(FX_DIR + "blaze_run_streak.png")
const BLAZE_FPS: float = 10.0
const BLAZE_STREAK_FPS: float = 48.0  # 16-frame loop (was 8 at 24): same cycle time
## Flame spacing along the run: close on horizontal runs so the trail reads continuous, wider on vertical ones (flames
## are tall, so they'd stack into a column), each jittered by up to BLAZE_JITTER of a step and pushed off the line by up
## to the sideways reach.
const BLAZE_FLAME_STEP_H: float = 42.0
const BLAZE_FLAME_STEP_V: float = 72.0
const BLAZE_JITTER: float = 0.3
const BLAZE_SIDE_H: float = 6.0
const BLAZE_SIDE_V: float = 12.0
## The ember line joining the flames is plotted in art pixels (palette colours): hot spots run along it, loose sparks rise
## off it, and while dying it cools ORANGE, RED, dark cracks (dithered away) over BLAZE_DIE_FRAME_TIME.
const BLAZE_LINE_YELLOW := Color("f5d256")
const BLAZE_LINE_ORANGE := Color("f08a3e")
const BLAZE_LINE_RED := Color("d9474b")
const BLAZE_LINE_MAROON := Color("7a2e38")
const BLAZE_LINE_CHAR := Color("3a3a5c")
const BLAZE_LINE_COOL: Array[Color] = [BLAZE_LINE_ORANGE, BLAZE_LINE_RED, BLAZE_LINE_MAROON, BLAZE_LINE_MAROON]
## Strip layout (generate.py BLAZE_FLAME_*): flame frames are BLAZE_FLAME_LOOP loop frames per variant, then BLAZE_FLAME_DIES per variant.
const BLAZE_FLAME_VARIANTS: int = 4
const BLAZE_FLAME_LOOP: int = 16
const BLAZE_FLAME_FPS: float = 40.0  # 16-frame loops (was 8 at 20)
const BLAZE_FLAME_DIES: int = 10
## Row of a stamp cell the floor spot sits on (generate.py BLAZE_FLOOR_Y); the cell's centre column is the spot's x.
const BLAZE_FLOOR_Y: float = 36.0
## From the body's centre to the feet (where the fire burns), in px.
const BLAZE_FEET_Y: float = 26.0
const BLAZE_DIE_TIME: float = 1.0
const BLAZE_DIE_FRAME_TIME: float = 0.6
const BLAZE_IGNITE_TIME: float = 0.5
const BLAZE_STREAK_FADE: float = 0.1
## Petal Drift: her sprite breaks into petals (dissolve strip), the swirl loop is drawn instead while she glides, and
## the reform strip gathers her back (the dissolve backwards). All 96 px cells like her sheet, 16 frames at DRIFT_FPS.
const DRIFT_ART: Texture2D = preload(FX_DIR + "sakura_drift.png")
const DISSOLVE_ART: Texture2D = preload(FX_DIR + "sakura_dissolve.png")
const REFORM_ART: Texture2D = preload(FX_DIR + "sakura_reform.png")
const DRIFT_FPS: float = 48.0
const DRIFT_STRIP_FRAMES: int = 16
const DISSOLVE_TIME: float = DRIFT_STRIP_FRAMES / DRIFT_FPS
## How much of her motion's slope (radians) the swirl leans with.
const DRIFT_LEAN: float = 0.4
## Speed under which the swirl keeps its last heading.
const DRIFT_MIN_SPEED: float = 20.0
## Eden's specials (all from synced skill state): Bark Skin plates slam onto her (96 px cells like her sheet), loop while it
## lasts and shed over the last strip's length; Verdant Bloom's moss patch grows, loops and wilts on the floor layer, with
## healing motes over her while she stands in it; Leaf Gust is a cone of leaves along the aim (frames GUST_SIZE px, the
## apex GUST_ORIGIN_X art px in, half way down), drawn from the active time.
const BARK_ART: Texture2D = preload(FX_DIR + "eden_bark.png")
const BARK_ON_ART: Texture2D = preload(FX_DIR + "eden_bark_on.png")
const BARK_OFF_ART: Texture2D = preload(FX_DIR + "eden_bark_off.png")
const BARK_FPS: float = 12.0
const BARK_STRIP_FPS: float = 30.0
const MOSS_GROW_ART: Texture2D = preload(FX_DIR + "eden_moss_grow.png")
const MOSS_ART: Texture2D = preload(FX_DIR + "eden_moss.png")
const MOSS_WILT_ART: Texture2D = preload(FX_DIR + "eden_moss_wilt.png")
const HEAL_ART: Texture2D = preload(FX_DIR + "eden_heal.png")
## Art px from the patch's centre to its edge (generate.py MOSS_R): scaled to the skill's radius.
const MOSS_ART_RADIUS: float = 46.0
const MOSS_FPS: float = 8.0
const MOSS_STRIP_FPS: float = 24.0
const HEAL_FPS: float = 12.0
const GUST_ART: Texture2D = preload(FX_DIR + "eden_gust.png")
const GUST_SIZE: float = 128.0
const GUST_ORIGIN_X: float = 8.0
## Art px the cone reaches (generate.py GUST_R): scaled to the skill's range.
const GUST_ART_RANGE: float = 100.0
## Bolt's Overdrive (from synced skill state on every peer): a crack of lightning when it starts, a crackling loop over
## him while it lasts, electric afterimages dragged behind (under him) and arcs popping off him while he moves, and a
## fizzle when it ends. All 96 px sheet cells except the 128 px crack and the 48 px spark.
const OD_ART: Texture2D = preload(FX_DIR + "bolt_overdrive.png")
const OD_GHOST_ART: Texture2D = preload(FX_DIR + "bolt_ghost.png")
const OD_CRACK_ART: Texture2D = preload(FX_DIR + "bolt_crack.png")
const OD_FIZZLE_ART: Texture2D = preload(FX_DIR + "bolt_fizzle.png")
const OD_SPARK_ART: Texture2D = preload(FX_DIR + "bolt_spark.png")
const OD_FPS: float = 20.0
const OD_CRACK_TIME: float = 0.47
const OD_FIZZLE_TIME: float = 0.4
const OD_SPARK_TIME: float = 0.16
const OD_SPARK_INTERVAL: float = 0.07
const OD_SPARK_REACH: Vector2 = Vector2(26.0, 30.0)
## Afterimages: one every OD_GHOST_STEP seconds, OD_GHOST_ALPHAS from the newest, skipped while closer than OD_GHOST_MIN.
const OD_GHOST_STEP: float = 0.045
const OD_GHOST_ALPHAS: Array[float] = [0.75, 0.6, 0.45, 0.3, 0.18]
const OD_GHOST_MIN: float = 10.0
const OD_MIN_SPEED: float = 60.0


class Poof:
	var pos: Vector2 = Vector2.ZERO
	var art: Texture2D
	var t: float = 0.0
	var duration: float = POOF_TIME
	var scale: float = 1.0
	var on_floor: bool = false  # drawn on the floor layer, under the players


var _clones: Array[AnimatedSprite2D] = []
var _points := PackedVector2Array()
var _owner: Player
var _smoke_t: float = -1.0
var _smoke: CharacterSkill
var _poofs: Array[Poof] = []
var _was_cloning: bool = false
var _was_transformed: bool = false
var _erupt_started: bool = false
## Cherry Sapling: the slot while its tree stands (else null), and seconds into the firing flourish (-1 = none).
var _sapling: CharacterSkill
var _sapling_shots: int = 0
var _sapling_fire_t: float = -1.0
## The eruption slot while its crack shows (else null).
var _crack: CharacterSkill
var _last_points := PackedVector2Array()
var _rng := RandomNumberGenerator.new()
## Seconds into the transformation morph (-1 = none); `_morph_back` plays it in reverse.
var _morph_t: float = -1.0
var _morph_back: bool = false
var _morph_art: Texture2D
var _morph_at: Vector2 = Vector2.ZERO
var _morph_flip: bool = false
## Seconds the ward has been up (-1 = down), its radius and where it's drawn (the owner, as drawn).
var _ward_t: float = -1.0
var _ward_radius: float = 0.0
var _ward_at: Vector2 = Vector2.ZERO
## Staff Whirl: seconds spinning (-1 = not), its radius, where he's drawn, which way he faces, damage ticks seen.
var _whirl_t: float = -1.0
var _whirl_radius: float = 0.0
var _whirl_at: Vector2 = Vector2.ZERO
var _whirl_flip: bool = false
var _whirl_ticks: int = 0
var _grapple: CharacterSkill
## Sky Pillar while it plays (null = not): the slot, and where he is drawn.
var _pillar: CharacterSkill
var _pillar_at: Vector2 = Vector2.ZERO
## Flare Burst while he charges (null = not), where he is drawn, and whether he was charging last sync.
var _flare: CharacterSkill
var _flare_at: Vector2 = Vector2.ZERO
var _flare_flip: bool = false
## Whether his Supernova was going off at the last sync (the burst plays on the rising edge).
var _supernova_was: bool = false
var _grapple_at: Vector2 = Vector2.ZERO
var _grapple_bit: bool = false
var _grapple_cd: float = 0.0
## Seconds into a missed throw (-1 = none), and its direction.
var _miss_t: float = -1.0
var _miss_dir: Vector2 = Vector2.RIGHT
var _time: float = 0.0
## Seconds of snare left as last synced (the vines show while > 0), where they are drawn.
var _snare_left: float = 0.0
var _snare_at: Vector2 = Vector2.ZERO
var _was_swinging: bool = false
## Drawing a swing from _swing_from to _swing_to, _swing_u of the way along; _vine_t >= 0: the vine pulling up after.
var _swing_on: bool = false
var _swing_from: Vector2 = Vector2.ZERO
var _swing_to: Vector2 = Vector2.ZERO
var _swing_u: float = 0.0
var _swing_ground: Vector2 = Vector2.ZERO
var _swing_linger: float = 0.0
var _swing_hand: Vector2 = Vector2.ZERO
var _vine_t: float = -1.0
## The Blaze Run slot while its trail burns (else null), and where the owner is drawn.
var _blaze: CharacterSkill
var _blaze_at: Vector2 = Vector2.ZERO
## Petal Drift: seconds drifting (-1 = not), seconds into the reform (-1 = none), where she's drawn, her heading.
var _drift_t: float = -1.0
var _reform_t: float = -1.0
var _drift_at: Vector2 = Vector2.ZERO
var _drift_flip: bool = false
var _drift_lean: float = 0.0
var _face_flip: bool = false
## Overdrive: seconds in (-1 = off), where he is drawn, afterimage positions (newest first) with their mirroring.
var _od_t: float = -1.0
var _od_at: Vector2 = Vector2.ZERO
var _od_ghosts: Array[Vector2] = []
var _od_flips: Array[bool] = []
var _od_flip: bool = false
var _od_ghost_clock: float = 0.0
var _od_spark_clock: float = 0.0
## Storm Cloud while it rains (null = not): the slot, strikes seen, and the bolts in flight (position they land + age).
var _storm: CharacterSkill
var _storm_spot: Vector2 = Vector2.ZERO
var _storm_ticks: int = 0
var _bolts: Array[Poof] = []
## Eden: the slots while Bark Skin / Verdant Bloom / Leaf Gust last (null = not), where she is drawn, and whether she
## stands in her moss.
var _bark: CharacterSkill
var _bloom: CharacterSkill
var _gust: CharacterSkill
var _eden_at: Vector2 = Vector2.ZERO
var _in_moss: bool = false


## Marks on the floor (the cloud's shadow, a strike's scorch) draw here: above the arena floor, under the players.
var _floor := Node2D.new()


func _init() -> void:
	top_level = true
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_floor.z_as_relative = false
	_floor.z_index = Effects.GROUND_Z
	_floor.draw.connect(_draw_floor)
	add_child(_floor)


func sync(p: Player) -> void:
	_owner = p
	_points = p.clone_points()
	var clones: CharacterSkill = _slot(p, SkillData.Kind.CLONES)
	var smoke: CharacterSkill = _slot(p, SkillData.Kind.SMOKE)
	_smoke = smoke
	var cloning: bool = clones != null and clones.is_cloning()
	if cloning and not _was_cloning:
		for at: Vector2 in _points:
			_poof(at, POOF_BIG, CLONE_POOF_TIME)
	elif _was_cloning and not cloning:
		for at: Vector2 in _last_points:
			_poof(at, POOF_SMALL)
	_was_cloning = cloning
	if cloning:
		_last_points = _points
	var transformed: bool = p.is_transformed()
	if transformed and not _was_transformed:
		_start_morph(p, false)
		if _morph_t < 0.0:
			_poof(p.global_position, POOF_BIG)
	elif _was_transformed and not transformed and not p.dead:
		_start_morph(p, true)
	_was_transformed = transformed
	var ward: CharacterSkill = _slot(p, SkillData.Kind.WARD)
	var warding: bool = ward != null and ward.is_warding() and not p.dead
	_ward_at = p.global_position + p.visual_offset
	if warding:
		_ward_radius = ward.data.ward_radius
	elif _ward_t >= 0.0 and not p.dead:
		_poof(_ward_at, WARD_CLOSE_ART, WARD_CLOSE_TIME, _ward_scale())
	_ward_t = ward.elapsed() if warding else -1.0
	if p.dead:
		_morph_t = -1.0
	_morph_at = p.global_position + p.visual_offset
	_sync_whirl(p)
	var pillar: CharacterSkill = _slot(p, SkillData.Kind.PILLAR)
	_pillar = pillar if pillar != null and pillar.is_active() and not p.dead else null
	_pillar_at = p.global_position + p.visual_offset
	var nova: CharacterSkill = _slot(p, SkillData.Kind.NOVA)
	var charging: bool = nova != null and nova.nova_charging() and not p.dead
	if _flare != null and not charging and nova != null and nova.is_active() and not p.dead:  # the ring goes off
		var k: float = nova.data.nova_blast.splash_radius / (FLARE_ART_RADIUS * Constants.SPRITE_SCALE)
		var at: Vector2 = p.global_position + p.visual_offset + Vector2(0.0, Player.FOOT_RING_Y)
		_poof(at, FLARE_RING_ART, FLARE_RING_TIME, k)
		_poof(at, FLARE_RING_FLOOR_ART, FLARE_RING_TIME, k, true)
	_flare = nova if charging else null
	var supernova: CharacterSkill = _slot_id(p, &"supernova")
	var bursting: bool = supernova != null and supernova.is_active() and not p.dead
	if bursting and not _supernova_was:
		_poof(p.global_position + p.visual_offset, SUPERNOVA_ART, SUPERNOVA_TIME)
	_supernova_was = bursting
	_flare_at = p.global_position + p.visual_offset
	_flare_flip = p.facing.x < 0.0
	_sync_swing(p)
	_sync_drift(p)
	_sync_overdrive(p)
	_sync_sapling(p)
	_sync_storm(p)
	_sync_eden(p)
	var slow: float = 0.0 if p.dead else p.stats.slow_remaining
	if slow > _snare_left + SNARE_NEW_MARGIN:  # a snare landed (or was refreshed): petals burst
		_poof(p.global_position + p.visual_offset, SNARE_BURST_ART, SNARE_BURST_TIME)
	_snare_left = slow
	_snare_at = p.global_position + p.visual_offset + Vector2(0.0, Player.FOOT_RING_Y)
	_morph_flip = p.facing.x < 0.0
	var frames: SpriteFrames = p.character.sprite_frames()
	while _clones.size() < _points.size():
		var c := AnimatedSprite2D.new()
		c.scale = Vector2.ONE * Constants.SPRITE_SCALE
		c.show_behind_parent = true
		add_child(c)
		_clones.append(c)
	var alpha: float = 0.0
	if cloning:
		alpha = minf(clampf(clones.active_remaining / FADE_TIME, 0.0, 1.0),
			clampf((clones.elapsed() - APPEAR_DELAY) / APPEAR_TIME, 0.0, 1.0))
	for i: int in _clones.size():
		var c: AnimatedSprite2D = _clones[i]
		c.visible = i < _points.size()
		if not c.visible:
			continue
		if c.sprite_frames != frames:
			c.sprite_frames = frames
		if c.animation != &"walk" or not c.is_playing():
			c.play(&"walk")
		c.position = _points[i]
		c.flip_h = _points[i].x < clones.anchor.x
		c.modulate.a = alpha
	_smoke_t = smoke.elapsed() if smoke != null and smoke.is_smoking() else -1.0
	_sync_grapple(p)
	_sync_blaze(p)
	var eruption: CharacterSkill = _slot(p, SkillData.Kind.ERUPTION)
	var erupting: bool = eruption != null and eruption.is_active() and not p.dead
	if erupting and not _erupt_started and eruption.active_remaining <= ERUPTION_LEAD:  # the pillar comes up
		var lift: float = (ERUPTION_ART.get_height() * 0.5 - ERUPTION_BASE_Y) * Constants.SPRITE_SCALE
		_poof(eruption.anchor + Vector2(0.0, lift), ERUPTION_ART, ERUPTION_TIME)
	_erupt_started = erupting and (_erupt_started or eruption.active_remaining <= ERUPTION_LEAD)
	_crack = eruption if erupting and eruption.active_remaining > ERUPTION_LEAD else null
	queue_redraw()
	_floor.queue_redraw()


func _sync_eden(p: Player) -> void:
	var bark: CharacterSkill = _slot(p, SkillData.Kind.BARK_SKIN)
	_bark = bark if bark != null and bark.is_barked() and not p.dead else null
	var bloom: CharacterSkill = _slot(p, SkillData.Kind.BLOOM)
	_bloom = bloom if bloom != null and bloom.is_active() and not p.dead else null
	var gust: CharacterSkill = _slot(p, SkillData.Kind.GUST)
	_gust = gust if gust != null and gust.is_gusting() and not p.dead else null
	_eden_at = p.global_position + p.visual_offset
	_in_moss = _bloom != null and (p.global_position + Vector2(0.0, Player.FOOT_RING_Y)).distance_to(_bloom.anchor) \
		<= _bloom.data.bloom_radius


## The plates over her: slam on, loop, shed over the last strip's length.
func _draw_bark() -> void:
	if _bark == null:
		return
	var t: float = _bark.elapsed()
	var art: Texture2D = BARK_ART
	var frame: int = int(t * BARK_FPS)
	var on_time: float = BARK_ON_ART.get_width() / BARK_ON_ART.get_height() / BARK_STRIP_FPS
	var off_time: float = BARK_OFF_ART.get_width() / BARK_OFF_ART.get_height() / BARK_STRIP_FPS
	if t < on_time:
		art = BARK_ON_ART
		frame = int(t * BARK_STRIP_FPS)
	elif _bark.active_remaining < off_time:
		art = BARK_OFF_ART
		frame = int((off_time - _bark.active_remaining) * BARK_STRIP_FPS)
	var n: int = art.get_width() / art.get_height()
	_draw_frame(art, mini(frame, n - 1) if art != BARK_ART else frame % n, art.get_height(), _eden_at, Constants.SPRITE_SCALE)


## The cone of leaves, over the whole `duration`, apex on her.
func _draw_gust() -> void:
	if _gust == null:
		return
	var n: int = GUST_ART.get_width() / GUST_ART.get_height()
	var frame: int = mini(int(_gust.elapsed() / _gust.data.duration * n), n - 1)
	var k: float = _gust.data.gust_range / (GUST_ART_RANGE * Constants.SPRITE_SCALE)
	var px: float = Constants.SPRITE_SCALE * k
	draw_set_transform(_eden_at, _gust.direction.angle(), Vector2.ONE)
	_draw_frame(GUST_ART, frame, GUST_SIZE, Vector2((GUST_SIZE * 0.5 - GUST_ORIGIN_X) * px, 0.0), px)
	draw_set_transform(Vector2.ZERO)


## Healing motes over her while she stands in the moss.
func _draw_heal() -> void:
	if not _in_moss:
		return
	var n: int = HEAL_ART.get_width() / HEAL_ART.get_height()
	_draw_frame(HEAL_ART, int(_time * HEAL_FPS) % n, HEAL_ART.get_height(), _eden_at, Constants.SPRITE_SCALE)


## The moss patch on the floor: grows, loops (sprouts swaying), wilts over the last strip's length.
func _draw_moss() -> void:
	if _bloom == null:
		return
	var t: float = _bloom.elapsed()
	var art: Texture2D = MOSS_ART
	var frame: int = int(t * MOSS_FPS)
	var grow_time: float = MOSS_GROW_ART.get_width() / MOSS_GROW_ART.get_height() / MOSS_STRIP_FPS
	var wilt_time: float = MOSS_WILT_ART.get_width() / MOSS_WILT_ART.get_height() / MOSS_STRIP_FPS
	if t < grow_time:
		art = MOSS_GROW_ART
		frame = int(t * MOSS_STRIP_FPS)
	elif _bloom.active_remaining < wilt_time:
		art = MOSS_WILT_ART
		frame = int((wilt_time - _bloom.active_remaining) * MOSS_STRIP_FPS)
	var n: int = art.get_width() / art.get_height()
	var k: float = _bloom.data.bloom_radius / (MOSS_ART_RADIUS * Constants.SPRITE_SCALE)
	_draw_frame(art, mini(frame, n - 1) if art != MOSS_ART else frame % n, art.get_height(), _bloom.anchor,
		Constants.SPRITE_SCALE * k, 1.0, _floor)


## The tree is drawn from the synced skill time (grow, idle loop, wilt over the last strip's length); a flourish
## plays each time a shot falls due.
func _sync_sapling(p: Player) -> void:
	var slot: CharacterSkill = _slot(p, SkillData.Kind.SAPLING)
	_sapling = slot if slot != null and slot.is_active() and not p.dead else null
	if _sapling == null:
		_sapling_shots = 0
		_sapling_fire_t = -1.0
		return
	var shots: int = floori((_sapling.elapsed() + CharacterSkill.WHIRL_EPSILON) / _sapling.data.sapling_interval)
	if shots > _sapling_shots:
		_sapling_fire_t = 0.0
	_sapling_shots = shots


## Storm Cloud: puff and dispersal from the synced active state, a bolt on every strike tick (every peer sees the same
## times; the targets are whoever stands within the radius on this peer's view, else the cloud's own spot).
func _sync_storm(p: Player) -> void:
	var slot: CharacterSkill = _slot(p, SkillData.Kind.STORM)
	var raining: CharacterSkill = slot if slot != null and slot.is_active() and not p.dead else null
	if raining != null:
		var ticks: int = floori(raining.elapsed() / raining.data.storm_interval)
		if _storm != null and ticks > _storm_ticks:
			_strike(p, raining)
		_storm_ticks = ticks
		_storm_spot = raining.anchor
	elif _storm != null and not p.dead:
		_poof(_storm_art_centre(_storm_spot), STORM_END_ART, STORM_END_TIME)
		_poof(_storm_art_centre(_storm_spot), STORM_FLOOR_END_ART, STORM_END_TIME, 1.0, true)
	_storm = raining


func _storm_art_centre(spot: Vector2) -> Vector2:
	return spot + Vector2(0.0, (STORM_SIZE * 0.5 - STORM_FLOOR_Y) * Constants.SPRITE_SCALE)


func _strike(p: Player, slot: CharacterSkill) -> void:
	var hit: bool = false
	# Same sight rule as the damage (ProjectilePool.strike): no bolt falls on someone the wall shields.
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.new()
	for node: Node in p.get_parent().get_children():
		var target := node as Player
		if target != null and target != p and not target.dead \
				and target.global_position.distance_to(slot.anchor) <= slot.data.storm_radius \
				and AutoAim.has_line_of_sight(space, query, slot.anchor, target.global_position):
			_bolt(target.global_position + target.visual_offset, target.global_position + target.visual_offset
				+ Vector2(0.0, Player.FOOT_RING_Y))
			hit = true
	if not hit:
		_bolt(slot.anchor, slot.anchor)


func _bolt(at: Vector2, ground: Vector2) -> void:
	var b := Poof.new()
	b.pos = at
	b.duration = BOLT_TIME
	_bolts.append(b)
	_poof(ground, STORM_SPARK_ART, STORM_SPARK_TIME)
	_poof(ground, STORM_SCORCH_ART, STORM_SPARK_TIME, 1.0, true)


func _sync_overdrive(p: Player) -> void:
	var slot: CharacterSkill = _slot(p, SkillData.Kind.OVERDRIVE)
	var on: bool = slot != null and slot.is_overdriving() and not p.dead
	_od_at = p.global_position + p.visual_offset
	if on and _od_t < 0.0:
		_poof(_od_at, OD_CRACK_ART, OD_CRACK_TIME)
	elif not on and _od_t >= 0.0 and not p.dead:
		_poof(_od_at, OD_FIZZLE_ART, OD_FIZZLE_TIME)
	_od_t = slot.elapsed() if on else -1.0
	if not on:
		_od_ghosts.clear()
		_od_flips.clear()
		return
	var moving: bool = p.velocity.length() > OD_MIN_SPEED
	if moving:
		_od_flip = p.velocity.x < 0.0
	var dt: float = get_process_delta_time()
	_od_ghost_clock += dt
	if _od_ghost_clock >= OD_GHOST_STEP:
		_od_ghost_clock = 0.0
		_od_ghosts.push_front(_od_at)
		_od_flips.push_front(_od_flip)
		if _od_ghosts.size() > OD_GHOST_ALPHAS.size():
			_od_ghosts.pop_back()
			_od_flips.pop_back()
	_od_spark_clock += dt
	if moving and _od_spark_clock >= OD_SPARK_INTERVAL:  # arcs popping off him as he runs
		_od_spark_clock = 0.0
		_poof(_od_at + Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 0.8)) * OD_SPARK_REACH,
			OD_SPARK_ART, OD_SPARK_TIME, -1.0 if _rng.randf() < 0.5 else 1.0)


## Afterimages, under him.
func _draw_overdrive_floor() -> void:
	var px: float = Constants.SPRITE_SCALE
	var cell: float = OD_GHOST_ART.get_height()
	var frames: int = OD_GHOST_ART.get_width() / OD_GHOST_ART.get_height()
	for i: int in _od_ghosts.size():
		if _od_ghosts[i].distance_to(_od_at) < OD_GHOST_MIN * (i + 1):
			continue
		_floor.draw_set_transform(_od_ghosts[i], 0.0, Vector2(-1.0 if _od_flips[i] else 1.0, 1.0))
		_draw_frame(OD_GHOST_ART, (int(_time * OD_FPS) + i) % frames, cell, Vector2.ZERO, px, OD_GHOST_ALPHAS[i], _floor)
	_floor.draw_set_transform(Vector2.ZERO)


## The crackle over him.
func _draw_overdrive() -> void:
	if _od_t < 0.0:
		return
	var n: int = OD_ART.get_width() / OD_ART.get_height()
	var a: float = clampf(_od_t / RING_EASE_IN, 0.0, 1.0)
	_draw_frame(OD_ART, int(_od_t * OD_FPS) % n, OD_ART.get_height(), _od_at, Constants.SPRITE_SCALE, a)
	_draw_frame(OD_ART, (int(_od_t * OD_FPS) + 3) % n, OD_ART.get_height(), _od_at, Constants.SPRITE_SCALE, a * OD_DOUBLE_ALPHA)


func _sync_drift(p: Player) -> void:
	var slot: CharacterSkill = _slot(p, SkillData.Kind.DRIFT)
	var on: bool = slot != null and slot.is_drifting() and not p.dead
	_drift_at = p.global_position + p.visual_offset
	_face_flip = p.facing.x < 0.0
	if on and p.velocity.length() > DRIFT_MIN_SPEED:
		_drift_flip = p.velocity.x < 0.0
		_drift_lean = atan2(p.velocity.y, absf(p.velocity.x)) * DRIFT_LEAN * (-1.0 if _drift_flip else 1.0)
	if _drift_t >= 0.0 and not on and not p.dead:  # gathers back with a little burst of petals
		_reform_t = 0.0
		petal_pop(_drift_at)
	if p.dead:
		_reform_t = -1.0
	_drift_t = slot.elapsed() if on else -1.0


## The owner's sprite and held weapon stay hidden while she is petals or gathering back (Player).
func is_flaring() -> bool:
	return _flare != null


func is_petals() -> bool:
	return _drift_t >= 0.0 or _reform_t >= 0.0


func _sync_blaze(p: Player) -> void:
	var slot: CharacterSkill = _slot(p, SkillData.Kind.TRAIL)
	var burning: CharacterSkill = slot if slot != null and slot.is_active() and not p.dead else null
	if burning != null and _blaze == null:  # the fire catches where he took off
		_poof(_blaze_floor(burning.anchor), BLAZE_IGNITE_ART, BLAZE_IGNITE_TIME)
	_blaze = burning
	_blaze_at = p.global_position + p.visual_offset


## Offset from a flame cell's centre to its floor spot.
func _blaze_ground_off(px: float) -> Vector2:
	return Vector2(0.0, (BLAZE_FLOOR_Y - BLAZE_FLAMES_ART.get_height() * 0.5) * px)


## The cell centre that puts a stamp's floor spot under the body at `at`.
func _blaze_floor(at: Vector2) -> Vector2:
	return at + Vector2(0.0, BLAZE_FEET_Y - (BLAZE_FLOOR_Y - BLAZE_IGNITE_ART.get_height() * 0.5) * Constants.SPRITE_SCALE)


func _sync_grapple(p: Player) -> void:
	var g: CharacterSkill = _slot(p, SkillData.Kind.GRAPPLE)
	var was: CharacterSkill = _grapple
	_grapple = g if g != null and g.is_active() and not p.dead else null
	_grapple_at = p.global_position + p.visual_offset
	if was != null and _grapple == null and _grapple_bit and not p.dead:  # the zip ended: she lands
		_poof(_grapple_at + Vector2(0.0, LAND_FEET_Y - 12.0 * Constants.SPRITE_SCALE), LAND_ART, LAND_TIME)
	if g == null:
		return
	if _grapple != null and was == null:
		_grapple_bit = false
		var flip0: bool = _grapple.direction.x < 0.0
		_poof(_grapple_at + Vector2(-ZIP_HAND.x if flip0 else ZIP_HAND.x, ZIP_HAND.y), THROW_ART, THROW_TIME,
			-1.0 if flip0 else 1.0)
	elif _grapple == null and not p.dead and g.cooldown_remaining > _grapple_cd + 0.01 \
			and g.cooldown_remaining <= g.data.grapple_miss_cooldown:  # a fresh miss (a bite charges the full cooldown)
		_miss_t = 0.0
		_miss_dir = g.direction
	_grapple_cd = g.cooldown_remaining
	if _grapple != null and not _grapple_bit and _grapple.elapsed() >= _grapple.data.grapple_bite_time:
		_grapple_bit = true
		_poof(_bite_point(), SPARK_ART, SPARK_TIME)


func _process(delta: float) -> void:
	for pf: Poof in _poofs:
		pf.t += delta
	for b: Poof in _bolts:
		b.t += delta
	_bolts = _bolts.filter(func(b: Poof) -> bool: return b.t < b.duration)
	_poofs = _poofs.filter(func(pf: Poof) -> bool: return pf.t < pf.duration)
	_time += delta
	if _miss_t >= 0.0:
		_miss_t += delta
		if _miss_t > MISS_OUT_TIME + MISS_BACK_TIME:
			_miss_t = -1.0
	if _morph_t >= 0.0:
		_morph_t += delta
		if _morph_t > MORPH_TIME:
			_morph_t = -1.0
	if _reform_t >= 0.0:
		_reform_t += delta
		if _reform_t > DRIFT_STRIP_FRAMES / DRIFT_FPS:
			_reform_t = -1.0
	if _sapling_fire_t >= 0.0:
		_sapling_fire_t += delta
		if _sapling_fire_t > SAPLING_FIRE_ART.get_width() / SAPLING_FIRE_ART.get_height() / SAPLING_FIRE_FPS:
			_sapling_fire_t = -1.0
	if _vine_t >= 0.0:
		_vine_t += delta
		if _vine_t > VINE_RETRACT_TIME:
			_vine_t = -1.0


## The owner's first skill slot of `kind` (active or not), or null.
static func _slot_id(p: Player, id: StringName) -> CharacterSkill:
	for slot: CharacterSkill in p.skills:
		if slot.data.id == id:
			return slot
	return null


static func _slot(p: Player, kind: SkillData.Kind) -> CharacterSkill:
	for slot: CharacterSkill in p.skills:
		if slot.data.kind == kind:
			return slot
	return null


## The owner's sprite is hidden while a morph or the grapple zip pose plays (Player).
func hides_owner() -> bool:
	return _morph_t >= 0.0 or _grapple != null or _whirl_t >= 0.0 or is_petals() or _pillar != null or _flare != null


## The owner's sprite is hidden while the swing pose is drawn instead (Player).
func is_swinging() -> bool:
	return _swing_on


## Staff Whirl: dust at his feet as it starts and ends, sparks off the rim on each damage tick (from synced state).
func _sync_whirl(p: Player) -> void:
	var whirl: CharacterSkill = _slot(p, SkillData.Kind.WHIRL)
	var on: bool = whirl != null and whirl.is_whirling() and not p.dead
	_whirl_at = p.global_position + p.visual_offset
	_whirl_flip = p.facing.x < 0.0
	if on:
		_whirl_radius = whirl.data.whirl_radius
		var ticks: int = floori(whirl.elapsed() / whirl.data.whirl_interval)
		if _whirl_t < 0.0:
			_poof(_whirl_at + Vector2(0.0, SWING_FEET_Y), POOF_SMALL, POOF_TIME, WHIRL_DUST_SCALE)
		elif ticks != _whirl_ticks:
			for side: float in [-1.0, 1.0]:  # two opposite spots, turning a quarter each tick
				var a: float = ticks * PI * 0.5 + (0.0 if side < 0.0 else PI)
				_poof(_whirl_at + Vector2(cos(a), sin(a) * WHIRL_RING_SQUASH) * _whirl_radius * WHIRL_SPARK_REACH,
					WHIRL_SPARK_ART, WHIRL_SPARK_TIME)
		_whirl_ticks = ticks
	elif _whirl_t >= 0.0 and not p.dead:
		_poof(_whirl_at + Vector2(0.0, SWING_FEET_Y), POOF_SMALL, POOF_TIME, WHIRL_DUST_SCALE)
	_whirl_t = whirl.elapsed() if on else -1.0


func _sync_swing(p: Player) -> void:
	var swing: CharacterSkill = _slot(p, SkillData.Kind.SWING)
	var active: bool = swing != null and swing.is_active()
	if active and not _was_swinging:
		_swing_on = true
		_swing_from = swing.anchor
		_swing_to = swing.anchor + swing.direction
		_swing_linger = 0.0
		_vine_t = -1.0
		_poof(_swing_from + Vector2(0.0, SWING_FEET_Y), LEAF_BURST, LEAF_TIME)
	_was_swinging = active
	if not _swing_on:
		return
	var chord: Vector2 = _swing_to - _swing_from
	_swing_u = clampf((p.global_position - _swing_from).dot(chord) / maxf(chord.length_squared(), 1.0), 0.0, 1.0)
	_swing_ground = p.global_position + p.visual_offset
	if not active:
		_swing_linger += get_process_delta_time()
	if p.dead:
		_swing_on = false
	elif not active and (_swing_u >= 0.999 or _swing_linger > SWING_LINGER):
		_swing_on = false
		_vine_t = 0.0
		_poof(_swing_to + Vector2(0.0, SWING_FEET_Y), SWING_DUST, DUST_TIME)


func _start_morph(p: Player, back: bool) -> void:
	var form: CharacterSkill = _slot(p, SkillData.Kind.TRANSFORM)
	_morph_art = form.data.form_morph if form != null else null
	if _morph_art == null:
		return
	_morph_back = back
	_morph_t = 0.0


func _poof(at: Vector2, art: Texture2D, duration: float = POOF_TIME, scale: float = 1.0, on_floor: bool = false) -> void:
	var pf := Poof.new()
	pf.pos = at
	pf.art = art
	pf.duration = duration
	pf.scale = scale
	pf.on_floor = on_floor
	_poofs.append(pf)


## A shot caught on the ward (ShieldWall.caught, on every peer).
func petal_pop(at: Vector2) -> void:
	_poof(at, PETAL_POP_ART, PETAL_POP_TIME)


func _ward_scale() -> float:
	return _ward_radius / WARD_ART_RADIUS


## Frame `frame` of a horizontal strip of square frames, centred on `at`, at the sprite scale.
func _draw_frame(art: Texture2D, frame: int, frame_w: float, at: Vector2, scale_px: float, alpha: float = 1.0,
		on: CanvasItem = self) -> void:
	var h: float = art.get_height()
	var size := Vector2(frame_w, h) * scale_px
	on.draw_texture_rect_region(art, Rect2(at - size * 0.5, size), Rect2(frame * frame_w, 0, frame_w, h),
		Color(1, 1, 1, alpha))


func _draw() -> void:
	_draw_grapple()
	_draw_morph()
	_draw_ward()
	_draw_whirl()
	_draw_pillar()
	_draw_flare()
	_draw_swing()
	_draw_drift()
	_draw_overdrive()
	_draw_bark()
	_draw_heal()
	_draw_gust()
	_draw_snare()
	_draw_sapling()
	_draw_blaze()
	_draw_storm()
	_draw_flourishes()
	if _owner == null:
		return
	for i: int in _points.size():
		_draw_clone_weapon(_points[i], Vector2.LEFT if _clones[i].flip_h else Vector2.RIGHT, _clones[i].modulate.a)
	if _smoke_t >= 0.0:
		var frame: int = int(_smoke_t * SMOKE_FPS) % (SMOKE_ART.get_width() / SMOKE_ART.get_height())
		var swell: float = lerpf(SMOKE_SWELL_FROM, 1.0, clampf(_smoke_t / SMOKE_SWELL_TIME, 0.0, 1.0))
		var k: float = _smoke.data.smoke_radius / SMOKE_ART_RADIUS * swell
		var fade: float = clampf(_smoke.active_remaining / FADE_TIME, 0.0, 1.0)
		_draw_frame(SMOKE_ART, frame, SMOKE_ART.get_height(), _smoke.anchor, Constants.SPRITE_SCALE * k,
			SMOKE_ALPHA * fade * clampf(_smoke_t / SMOKE_EASE_IN, 0.0, 1.0))


func _draw_floor() -> void:
	var px: float = Constants.SPRITE_SCALE
	if _crack != null:
		var n: int = CRACK_ART.get_width() / CRACK_ART.get_height()
		var k: float = _crack.data.eruption_blast.splash_radius / ERUPTION_ART_RADIUS
		var ct: float = _crack.elapsed()
		var heat: float = clampf(ct / maxf(_crack.data.duration, 0.01), 0.0, 1.0)
		_floor.modulate = Color(1.0 + 0.35 * heat, 1.0 + 0.1 * heat, 1.0, 1.0)  # glows hotter as it nears the blast
		_draw_frame(CRACK_ART, int(ct * CRACK_FPS) % n, CRACK_ART.get_height(), _crack.anchor,
			px * k * lerpf(0.9, 1.0, minf(ct / CRACK_EASE_IN, 1.0)), clampf(ct / CRACK_EASE_IN, 0.0, 1.0), _floor)
	else:
		_floor.modulate = Color.WHITE
	if _whirl_t >= 0.0:
		_draw_frame(WHIRL_RING_ART, int(_whirl_t * WHIRL_FPS) % (WHIRL_RING_ART.get_width() / WHIRL_RING_ART.get_height()),
			WHIRL_RING_ART.get_height(), _whirl_at, px * _whirl_radius / WHIRL_ART_RADIUS,
			clampf(_whirl_t / RING_EASE_IN, 0.0, 1.0), _floor)
	if _storm != null:  # the cloud's shadow and rain splashes, same frames as the cloud itself
		var t: float = _storm.elapsed()
		var centre: Vector2 = _storm_art_centre(_storm.anchor)
		if t < STORM_FORM_TIME:
			_draw_frame(STORM_FLOOR_FORM_ART, mini(int(t / STORM_FORM_TIME * STORM_FRAME_COUNT), STORM_FRAME_COUNT - 1),
				STORM_SIZE, centre, px, 1.0, _floor)
		else:
			_draw_frame(STORM_FLOOR_ART, int(t * STORM_FPS) % STORM_LOOP_COUNT, STORM_SIZE, centre, px, 1.0, _floor)
	if _ward_t >= 0.0:  # a soft pool of petal light on the floor so the ward's reach reads under the players
		var glow: float = clampf(_ward_t / WARD_OPEN_TIME, 0.0, 1.0)
		_floor.draw_circle(_ward_at, _ward_radius, Color(WARD_GLOW, WARD_GLOW_ALPHA * glow))
		_floor.draw_arc(_ward_at, _ward_radius, 0.0, TAU, 48, Color(WARD_GLOW, WARD_RING_ALPHA * glow), 2.0)
	_draw_overdrive_floor()
	_draw_moss()
	for pf: Poof in _poofs:
		if pf.on_floor:
			var n: int = pf.art.get_width() / pf.art.get_height()
			_draw_frame(pf.art, mini(int(pf.t / pf.duration * n), n - 1), pf.art.get_height(), pf.pos, px * pf.scale,
				1.0, _floor)


## The clone holds the owner's current weapon (and hand), pointing the way it runs.
func _draw_clone_weapon(at: Vector2, dir: Vector2, alpha: float) -> void:
	var w: WeaponData = _owner.held_weapon().data
	if w.sprite == null or not w.held_art:
		return
	var flip_v: float = -1.0 if dir.x < 0.0 else 1.0
	var s: float = Constants.SPRITE_SCALE
	if w.upright:
		draw_set_transform(at + Player.hand_offset(dir), 0.0, Vector2(s * flip_v, s))
	else:
		draw_set_transform(at + Player.hand_offset(dir), dir.angle(), Vector2(s, s * flip_v))
	var tint := Color(1, 1, 1, alpha)
	w.draw_held(self, Player.WEAPON_GRIP, tint)
	draw_set_transform(Vector2.ZERO)


## Frame by frame from the character into the form (or back). The strip has the growth baked in.
func _draw_morph() -> void:
	if _morph_t < 0.0:
		return
	var n: int = _morph_art.get_width() / _morph_art.get_height()
	var k: int = mini(int(_morph_t / MORPH_TIME * n), n - 1)
	if _morph_back:
		k = n - 1 - k
	draw_set_transform(_morph_at, 0.0, Vector2(-1.0 if _morph_flip else 1.0, 1.0))
	_draw_frame(_morph_art, k, _morph_art.get_height(), Vector2.ZERO, Constants.SPRITE_SCALE)
	draw_set_transform(Vector2.ZERO)


## The ring opens in a bloom (its last frame is the loop's first), then loops while it's up.
func _draw_ward() -> void:
	if _ward_t < 0.0:
		return
	var px: float = Constants.SPRITE_SCALE * _ward_scale()
	if _ward_t < WARD_OPEN_TIME:
		var n: int = WARD_OPEN_ART.get_width() / WARD_OPEN_ART.get_height()
		_draw_frame(WARD_OPEN_ART, mini(int(_ward_t / WARD_OPEN_TIME * n), n - 1), WARD_OPEN_ART.get_height(),
			_ward_at, px)
		return
	var frame: int = int((_ward_t - WARD_OPEN_TIME) * WARD_FPS) % (WARD_ART.get_width() / WARD_ART.get_height())
	_draw_frame(WARD_ART, frame, WARD_ART.get_height(), _ward_at, px)


func _draw_sapling() -> void:
	if _sapling == null:
		return
	var art: Texture2D = SAPLING_IDLE_ART
	var frame: int = int(_time * SAPLING_IDLE_FPS)
	var t: float = _sapling.elapsed()
	var grow_time: float = SAPLING_GROW_ART.get_width() / SAPLING_GROW_ART.get_height() / SAPLING_FPS
	var wilt_time: float = SAPLING_WILT_ART.get_width() / SAPLING_WILT_ART.get_height() / SAPLING_FPS
	if t < grow_time:
		art = SAPLING_GROW_ART
		frame = int(t * SAPLING_FPS)
	elif _sapling.active_remaining < wilt_time:
		art = SAPLING_WILT_ART
		frame = int((wilt_time - _sapling.active_remaining) * SAPLING_FPS)
	elif _sapling_fire_t >= 0.0:
		art = SAPLING_FIRE_ART
		frame = int(_sapling_fire_t * SAPLING_FIRE_FPS)
	var n: int = art.get_width() / art.get_height()
	var px: float = Constants.SPRITE_SCALE
	var up: float = (art.get_height() * 0.5 - SAPLING_BASE_Y) * px
	_draw_frame(art, mini(frame, n - 1) if art != SAPLING_IDLE_ART else frame % n, art.get_height(),
		_sapling.anchor + Vector2(0.0, up), px)


## Vines coiled round the snared player's feet, looping while the slow lasts.
func _draw_snare() -> void:
	if _snare_left <= 0.0:
		return
	var n: int = SNARE_ART.get_width() / SNARE_ART.get_height()
	var px: float = Constants.SPRITE_SCALE
	var up: float = (SNARE_ART.get_height() * 0.5 - SNARE_BASE_Y) * px
	_draw_frame(SNARE_ART, int(_time * SNARE_FPS) % n, SNARE_ART.get_height(), _snare_at + Vector2(0.0, up), px,
		clampf(_snare_left / FADE_TIME, 0.0, 1.0))


## Poofs play their strip once.
## The cloud over its spot (forming, then looping), the bolts falling from its underside to where they landed.
func _draw_storm() -> void:
	var px: float = Constants.SPRITE_SCALE
	if _storm != null:
		var t: float = _storm.elapsed()
		var centre: Vector2 = _storm_art_centre(_storm.anchor)
		if t < STORM_FORM_TIME:
			_draw_frame(STORM_FORM_ART, mini(int(t / STORM_FORM_TIME * STORM_FRAME_COUNT), STORM_FRAME_COUNT - 1),
				STORM_SIZE, centre, px)
		else:
			_draw_frame(STORM_ART, int(t * STORM_FPS) % STORM_LOOP_COUNT, STORM_SIZE, centre, px)
	var h: float = STORM_BOLT_ART.get_height()
	var frames: int = int(STORM_BOLT_ART.get_width() / BOLT_W)
	for b: Poof in _bolts:
		var base: float = _storm_spot.y + (STORM_BASE_Y - STORM_FLOOR_Y) * px
		var length: float = clampf((b.pos.y - base) / px, BOLT_MIN_LENGTH, BOLT_END_Y - 8.0)
		var frame: int = mini(int(b.t / BOLT_TIME * frames), frames - 1)
		draw_texture_rect_region(STORM_BOLT_ART, Rect2(Vector2(b.pos.x - BOLT_W * 0.5 * px, b.pos.y - length * px),
			Vector2(BOLT_W, length) * px), Rect2(frame * BOLT_W, BOLT_END_Y - length, BOLT_W, length))


func _draw_flourishes() -> void:
	var px: float = Constants.SPRITE_SCALE
	for pf: Poof in _poofs:
		if pf.on_floor:
			continue
		var n: int = pf.art.get_width() / pf.art.get_height()
		var frame: int = mini(int(pf.t / pf.duration * n), n - 1)
		if pf.scale < 0.0:  # a negative scale mirrors the strip (faces left)
			draw_set_transform(pf.pos, 0.0, Vector2(-1.0, 1.0))
			_draw_frame(pf.art, frame, pf.art.get_height(), Vector2.ZERO, px * -pf.scale)
			draw_set_transform(Vector2.ZERO)
		else:
			_draw_frame(pf.art, frame, pf.art.get_height(), pf.pos, px * pf.scale)


## Where the kunai bit: the stop point is a player radius short of the feet-level wall; the wall itself is drawn
## WALL_FEET_STRIP lower.
func _bite_point() -> Vector2:
	return _grapple.anchor + _grapple.direction * (Constants.PLAYER_RADIUS + Constants.GRAPPLE_STANDOFF) \
		+ Vector2(0.0, Constants.WALL_FEET_STRIP)


func _draw_grapple() -> void:
	if _owner == null:
		return
	var s: float = Constants.SPRITE_SCALE
	if _miss_t >= 0.0:
		var hand: Vector2 = _grapple_at + Player.hand_offset(_miss_dir)
		var out: float = _miss_t / MISS_OUT_TIME if _miss_t < MISS_OUT_TIME \
			else 1.0 - (_miss_t - MISS_OUT_TIME) / MISS_BACK_TIME
		var range_px: float = _slot(_owner, SkillData.Kind.GRAPPLE).data.grapple_range
		_draw_chain(hand, hand + _miss_dir * range_px * clampf(out, 0.0, 1.0))
	if _grapple == null:
		return
	var flip: bool = _grapple.direction.x < 0.0
	var hand: Vector2 = _grapple_at + Vector2(-ZIP_HAND.x if flip else ZIP_HAND.x, ZIP_HAND.y)
	var bite: Vector2 = _bite_point()
	var throw: float = clampf(_grapple.elapsed() / _grapple.data.grapple_bite_time, 0.0, 1.0)
	if throw >= 1.0:  # speed lines streaming off behind her while she's pulled
		var dir: Vector2 = _grapple.direction
		for k: int in SPEED_LINES:
			var side: float = (k - (SPEED_LINES - 1) * 0.5) * SPEED_LINE_GAP
			var back: float = fposmod(_time * SPEED_LINE_SCROLL + k * 37.0, SPEED_LINE_SPAN) + Constants.PLAYER_RADIUS
			var a: Vector2 = (_grapple_at + dir.orthogonal() * side - dir * back).snapped(Vector2.ONE * s)
			draw_line(a, a - dir * SPEED_LINE_LEN, SPEED_LINE_COLORS[k % 2], s)
	_draw_chain(hand, hand.lerp(bite, throw))
	draw_set_transform(_grapple_at, 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
	var n: int = ZIP_ART.get_width() / ZIP_ART.get_height()
	_draw_frame(ZIP_ART, int(_time * ZIP_FPS) % n, ZIP_ART.get_height(), Vector2.ZERO, s)
	draw_set_transform(Vector2.ZERO)


## The kunai with its tip at `tip`, its chain of links trailing back to `hand`.
func _draw_chain(hand: Vector2, tip: Vector2) -> void:
	var s: float = Constants.SPRITE_SCALE
	var dir: Vector2 = (tip - hand).normalized() if tip != hand else Vector2.RIGHT
	var ring: Vector2 = tip - dir * (KUNAI_TIP + KUNAI_RING) * s
	var links: int = int(maxf(0.0, (ring - hand).dot(dir)) / (CHAIN_LINK_STEP * s))
	var link: float = CHAIN_ART.get_height()
	var chain_n: int = CHAIN_ART.get_width() / CHAIN_ART.get_height()
	for i: int in links:
		draw_set_transform(hand + dir * (i + 0.5) * CHAIN_LINK_STEP * s, dir.angle(), Vector2(s, s))
		draw_texture_rect_region(CHAIN_ART, Rect2(-link * 0.5, -link * 0.5, link, link), Rect2((i + int(_time * CHAIN_FPS)) % chain_n * link, 0, link, link))
	var kh: float = KUNAI_ART.get_height()
	draw_set_transform(tip - dir * KUNAI_TIP * s, dir.angle(), Vector2(s, s))
	draw_texture_rect_region(KUNAI_ART, Rect2(-kh * 0.5, -kh * 0.5, kh, kh), Rect2(0, 0, kh, kh))
	draw_set_transform(Vector2.ZERO)


func _draw_whirl() -> void:
	if _whirl_t < 0.0:
		return
	var px: float = Constants.SPRITE_SCALE
	draw_set_transform(_whirl_at, 0.0, Vector2(-1.0 if _whirl_flip else 1.0, 1.0))
	_draw_frame(WHIRL_ART, int(_whirl_t * WHIRL_FPS) % (WHIRL_ART.get_width() / WHIRL_ART.get_height()),
		WHIRL_ART.get_height(), Vector2.ZERO, px)
	draw_set_transform(Vector2.ZERO)


func _draw_drift() -> void:
	var px: float = Constants.SPRITE_SCALE
	var cell: float = DRIFT_ART.get_height()
	var frame: int = 0
	var art: Texture2D = REFORM_ART
	var flip: bool = _face_flip
	if _drift_t >= DISSOLVE_TIME:  # the swirl, leaning with her motion
		draw_set_transform(_drift_at, _drift_lean, Vector2(-1.0 if _drift_flip else 1.0, 1.0))
		_draw_frame(DRIFT_ART, int(_drift_t * DRIFT_FPS) % DRIFT_STRIP_FRAMES, cell, Vector2.ZERO, px)
		draw_set_transform(Vector2.ZERO)
		return
	if _drift_t >= 0.0:
		art = DISSOLVE_ART
		frame = int(_drift_t * DRIFT_FPS)
	elif _reform_t >= 0.0:
		frame = int(_reform_t * DRIFT_FPS)
	else:
		return
	draw_set_transform(_drift_at, 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
	_draw_frame(art, mini(frame, DRIFT_STRIP_FRAMES - 1), cell, Vector2.ZERO, px)
	draw_set_transform(Vector2.ZERO)


## The pillar flies out along the line and slams down (12 frames over the skill's duration), with his pose over it.
func _draw_pillar() -> void:
	if _pillar == null:
		return
	var px: float = Constants.SPRITE_SCALE
	var u: float = clampf(_pillar.elapsed() / _pillar.data.duration, 0.0, 0.999)
	var frames: int = int(PILLAR_ART.get_width() / PILLAR_FRAME_W)
	var h: float = PILLAR_ART.get_height()
	var reach: float = minf(PILLAR_FRAME_W, PILLAR_BASE_X + _pillar.direction.length() / px)
	draw_set_transform(_pillar.anchor, _pillar.direction.angle(), Vector2.ONE)
	draw_texture_rect_region(PILLAR_ART, Rect2(Vector2(-PILLAR_BASE_X, -h * 0.5) * px, Vector2(reach, h) * px),
		Rect2(int(u * frames) * PILLAR_FRAME_W, 0.0, reach, h))
	draw_set_transform(_pillar_at, 0.0, Vector2(-1.0 if _pillar.direction.x < 0.0 else 1.0, 1.0))
	var cell: float = PILLAR_POSE_ART.get_height()
	_draw_frame(PILLAR_POSE_ART, int(u * (PILLAR_POSE_ART.get_width() / cell)), cell, Vector2.ZERO, px)
	draw_set_transform(Vector2.ZERO)


## His flames swell and brighten over the charge (the strip, spread over `nova_charge`), in place of his sprite.
func _draw_flare() -> void:
	if _flare == null:
		return
	var cell: float = FLARE_CHARGE_ART.get_height()
	var n: int = int(FLARE_CHARGE_ART.get_width() / cell)
	var frame: int = mini(int(_flare.elapsed() / _flare.data.nova_charge * n), n - 1)
	draw_set_transform(_flare_at, 0.0, Vector2(-1.0 if _flare_flip else 1.0, 1.0))
	_draw_frame(FLARE_CHARGE_ART, frame, cell, Vector2.ZERO, Constants.SPRITE_SCALE)
	draw_set_transform(Vector2.ZERO)


func _draw_swing() -> void:
	var pivot: Vector2 = (_swing_from + _swing_to) * 0.5 + Vector2(0.0, -VINE_PIVOT_HEIGHT)
	var px: float = Constants.SPRITE_SCALE
	var rightward: bool = _swing_to.x >= _swing_from.x
	if _swing_on:
		var body: Vector2 = _swing_ground + Vector2(0.0, -sin(PI * _swing_u) * SWING_LIFT_PX)
		var mirror := Vector2(1.0 if rightward else -1.0, 1.0)
		var cell: float = SWING_ART.get_height()
		_swing_hand = body + (SWING_HAND - Vector2(cell, cell) * 0.5) * mirror * px
		_draw_vine(pivot, _swing_hand)
		var n: int = SWING_ART.get_width() / SWING_ART.get_height()
		draw_set_transform(body, 0.0, mirror)
		_draw_frame(SWING_ART, mini(int(_swing_u * n), n - 1), cell, Vector2.ZERO, px)
		draw_set_transform(Vector2.ZERO)
	elif _vine_t >= 0.0:  # let go: the vine swings on and pulls back up
		var k: float = _vine_t / VINE_RETRACT_TIME
		var spin: float = VINE_OVERSHOOT * k * (-1.0 if rightward else 1.0)
		_draw_vine(pivot, pivot + (_swing_hand - pivot).rotated(spin) * (1.0 - k))


## A cheap deterministic hash (cosmetic only), so every client lays the same ground and flames for a run.
func _blaze_hash(n: int) -> int:
	n = ((n >> 16) ^ n) * 0x45d9f3b & 0x7fffffff
	n = ((n >> 16) ^ n) * 0x45d9f3b & 0x7fffffff
	return (n >> 16) ^ n


## The trail: flames (each on its own small scorch mark, baked into the strip) joined by a thin jagged glowing line on
## the floor from takeoff to where he stopped, laid down as he runs and cooling in turn. Far flames are drawn first.
func _draw_blaze() -> void:
	if _blaze == null:
		return
	var d: SkillData = _blaze.data
	var px: float = Constants.SPRITE_SCALE
	var length: float = _blaze.direction.length()
	var run: float = length * _blaze.trail_progress()
	var dir: Vector2 = _blaze.direction.normalized() if _blaze.direction != Vector2.ZERO else Vector2.RIGHT
	var dying: float = BLAZE_DIE_TIME - _blaze.active_remaining
	var spread: float = BLAZE_DIE_TIME - BLAZE_DIE_FRAME_TIME
	var loop: int = int(_blaze.elapsed() * BLAZE_FPS)
	var flame_loop: int = int(_blaze.elapsed() * BLAZE_FLAME_FPS)
	var seed: int = _blaze_hash(int(_blaze.anchor.x) * 73856093 ^ int(_blaze.anchor.y) * 19349663)
	var vertical: float = absf(dir.y)
	var step: float = lerpf(BLAZE_FLAME_STEP_H, BLAZE_FLAME_STEP_V, vertical)
	var side: float = lerpf(BLAZE_SIDE_H, BLAZE_SIDE_V, vertical)
	var flames: Array[Dictionary] = []
	var nodes: Array[Dictionary] = [{"along": 0.0, "at": _blaze_floor(_blaze.anchor) + _blaze_ground_off(px)}]
	for i: int in int(length / step) + 1:
		var r: int = _blaze_hash(seed + i * 3)
		var along: float = maxf(i * step + ((r >> 8) % 1000 / 1000.0 - 0.5) * 2.0 * BLAZE_JITTER * step, 0.0)
		if along > run:
			continue
		var off: float = (0.5 + 0.5 * ((r >> 12) % 1000 / 1000.0)) * side * (1.0 if i % 2 == 0 else -1.0)
		var at: Vector2 = _blaze_floor(_blaze.anchor + dir * along + dir.orthogonal() * off)
		nodes.append({"along": along, "at": at + _blaze_ground_off(px)})
		var v: int = r % BLAZE_FLAME_VARIANTS
		var local: float = dying - along / maxf(length, 1.0) * spread
		var frame: int = v * BLAZE_FLAME_LOOP + (flame_loop + (r >> 4)) % BLAZE_FLAME_LOOP
		if local >= 0.0:
			var die: int = int(local / BLAZE_DIE_FRAME_TIME * (BLAZE_FLAME_DIES + 1))
			if die >= BLAZE_FLAME_DIES:
				continue
			frame = BLAZE_FLAME_VARIANTS * BLAZE_FLAME_LOOP + v * BLAZE_FLAME_DIES + die
		flames.append({"at": at, "frame": frame})
	nodes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.along < b.along)
	nodes.append({"along": run, "at": _blaze_floor(_blaze.anchor + dir * run) + _blaze_ground_off(px)})
	flames.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.at.y < b.at.y)  # nearer the camera on top
	var fsize: float = BLAZE_FLAMES_ART.get_height()
	for fl: Dictionary in flames:
		_draw_frame(BLAZE_FLAMES_ART, fl.frame, fsize, fl.at, px)
	_draw_blaze_line(nodes, seed, length, dying, spread, loop, px)
	var dashing: float = d.trail_dash_time - _blaze.elapsed()
	if dashing > -BLAZE_STREAK_FADE:  # flame streaming off him, fading once he's stopped
		var cell: float = BLAZE_STREAK_ART.get_height()
		draw_set_transform(_blaze_at, dir.angle(), Vector2.ONE)
		_draw_frame(BLAZE_STREAK_ART, int(_time * BLAZE_STREAK_FPS) % BLAZE_FLAME_LOOP, cell, Vector2.ZERO, px,
			clampf((dashing + BLAZE_STREAK_FADE) / BLAZE_STREAK_FADE, 0.0, 1.0) if dashing < 0.0 else 1.0)
		draw_set_transform(Vector2.ZERO)


## The glowing crack along the polyline `nodes` ({along, at}): 1 art px wide (2 now and then), jagged by up to 1 px,
## hot spots running along it, a charred pixel under it, a few sparks rising off it.
func _draw_blaze_line(nodes: Array[Dictionary], seed: int, length: float, dying: float, spread: float, loop: int,
		px: float) -> void:
	var q: int = 0
	var cell := Vector2(px, px)
	for n: int in nodes.size() - 1:
		var a: Vector2 = nodes[n].at
		var seg: Vector2 = nodes[n + 1].at - a
		var steps: int = ceili(seg.length() / px)
		if steps == 0:
			continue
		var norm: Vector2 = seg.orthogonal().normalized()
		var flat: bool = absf(seg.x) >= absf(seg.y)
		for s: int in steps + 1:
			q += 1
			var t: float = float(s) / steps
			var h: int = _blaze_hash(seed + (q / 3) * 5 + 11)  # one kink per 3 px
			var jag: float = 0.0 if s < 2 or s > steps - 2 else float(h % 3 - 1) * px
			var at: Vector2 = a + seg * t + norm * jag
			at = (at / px).floor() * px
			var along: float = lerpf(nodes[n].along, nodes[n + 1].along, t)
			var local: float = dying - along / maxf(length, 1.0) * spread
			var col: Color = BLAZE_LINE_ORANGE
			if local < 0.0:
				if (q / 2 - loop) % 7 == 0:
					col = BLAZE_LINE_YELLOW
				elif (q + loop) % 5 == 0:
					col = BLAZE_LINE_RED
				if h % 29 == 0:  # a loose spark lifting off the line
					var rise: int = (loop + q) % 4
					draw_rect(Rect2(at + Vector2(0.0, -(2 + rise * 2) * px), cell),
						[BLAZE_LINE_YELLOW, BLAZE_LINE_ORANGE, BLAZE_LINE_RED, BLAZE_LINE_MAROON][rise])
			else:
				var die: int = int(local / BLAZE_DIE_FRAME_TIME * BLAZE_LINE_COOL.size())
				if die >= BLAZE_LINE_COOL.size() or (die == BLAZE_LINE_COOL.size() - 1 and q % 2 == 0):  # gone / fading
					continue
				col = BLAZE_LINE_COOL[die]
			draw_rect(Rect2(at + Vector2(0.0, px), cell), BLAZE_LINE_CHAR)
			draw_rect(Rect2(at, cell), col)
			if h % 3 == 0:  # now and then 2 px wide
				draw_rect(Rect2(at + (Vector2(0.0, -px) if flat else Vector2(px, 0.0)), cell), col)


## The vine hanging from `top` down to `end` (cropped to length, never stretched), under its leafy clump.
func _draw_vine(top: Vector2, end: Vector2) -> void:
	var v: Vector2 = end - top
	var px: float = Constants.SPRITE_SCALE
	var w: float = VINE_ART.get_width()
	var h: float = minf(v.length() / px, VINE_ART.get_height())
	if h >= 1.0:
		draw_set_transform(top, v.angle() - PI * 0.5, Vector2(px, px))
		draw_texture_rect_region(VINE_ART, Rect2(-w * 0.5, 0.0, w, h), Rect2(0.0, 0.0, w, h))
		draw_set_transform(Vector2.ZERO)
	_draw_frame(VINE_TOP, 0, VINE_TOP.get_width(), top, px)

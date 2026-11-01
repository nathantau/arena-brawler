class_name Constants
extends RefCounted
## Gameplay tunables shared by client and server simulation.

# --- Physics layers (bit values) ---
const LAYER_WALLS: int = 1
const LAYER_PLAYERS: int = 2
## Warden barriers: only projectiles collide with them.
const LAYER_SHIELDS: int = 4
## Destructible crates. They also sit on LAYER_WALLS so movement and line of sight treat
## them as walls; this extra bit lets projectiles tell them apart.
const LAYER_CRATES: int = 8
## Players move against a copy of every wall / crate shifted up by WALL_FEET_STRIP (and not against the walls
## themselves): their feet are drawn that far below the collision circle's edge, so this is colliding by the feet
## (3/4 view): feet stop at a wall's top, the head may overlap the wall above, and a one-tile gap fits.
const LAYER_WALL_FEET: int = 16

# --- Arena ---
const TILE_SIZE: float = 48.0
const CRATE_HP: int = 60

# --- Player movement ---
## Per-character move speed, HP etc. live in data/characters/*.tres.
const PLAYER_RADIUS: float = 18.0
## Feet (Player.FOOT_RING_Y = 40) minus PLAYER_RADIUS.
const WALL_FEET_STRIP: float = 22.0
## Grapple Kunai stops this far past touching distance from the wall it bit.
const GRAPPLE_STANDOFF: float = 2.0
const PLAYER_ACCEL: float = 2600.0
const PLAYER_DECEL: float = 2200.0
## Used when above normal max speed (after dash / knockback) so overspeed bleeds off fast.
const PLAYER_OVERSPEED_DECEL: float = 6000.0
const INPUT_DEADZONE: float = 0.15

# --- Player stats (defaults; characters override) ---
const PLAYER_MAX_HP: int = 100
const PLAYER_MAX_ARMOR: int = 50
const PLAYER_MAX_ENERGY: int = 200
const ARMOR_REGEN_DELAY: float = 3.0
const ARMOR_REGEN_PER_SEC: float = 25.0
const RESPAWN_DELAY: float = 2.0
## Spawn protection (server-side, synced): untouchable this long after (re)spawning, or until the first shot.
const RESPAWN_IFRAME_TIME: float = 1.5
## Energy pickups ("E" in a layout): +amount, back after PICKUP_RESPAWN s, picked up within PICKUP_RADIUS px.
const ENERGY_PICKUP_AMOUNT: int = 80
const PICKUP_RESPAWN: float = 12.0
const PICKUP_RADIUS: float = 34.0
## Weapon shots spend energy; it refills at this rate.
const ENERGY_REGEN_PER_SEC: float = 60.0
## A snare slows move speed to a fraction for a while (PlayerStats.slow_*): one at a time, a new one refreshes it.
## Special slots each fighter equips (slot 0 = skill button, slot 1 = special button).
const SKILL_SLOTS: int = 2

# --- Skills (per-character tunables are in data/characters/*.tres) ---
const SHIELD_THICKNESS: float = 10.0
## Vine Swing tries landing spots this far apart, from its full range inwards.
const SWING_SAMPLE_STEP: float = 8.0

# --- Aiming ---
const AUTO_AIM_RANGE: float = 560.0
const DRAG_AIM_DEADZONE_PX: float = 24.0
const MUZZLE_OFFSET: float = 6.0

# --- Projectiles ---
const PROJECTILE_POOL_SIZE: int = 512
## A reflected projectile flies at least this long after a sword swing.
const REFLECT_MIN_LIFE: float = 0.6
## Nudge off a wall after a bounce so the next raycast doesn't start inside it.
const BOUNCE_EPSILON: float = 0.5
## How many invulnerable/owner bodies a single projectile step may pass through.
const PROJECTILE_MAX_PASS_THROUGH: int = 3

# --- Bots (M1 dummies) ---
const BOT_COUNT: int = 3
const BOT_DECISION_MIN: float = 0.6
const BOT_DECISION_MAX: float = 1.6
const BOT_MOVE_SCALE: float = 0.7
const BOT_PREFERRED_DISTANCE: float = 300.0
const BOT_RADIAL_WEIGHT: float = 0.6
const BOT_STRAFE_WEIGHT: float = 0.8
const BOT_AIM_ERROR_DEG: float = 10.0
## Bots keep facing a target this long after losing sight of it (no flip-flopping at wall edges).
const BOT_TARGET_MEMORY: float = 0.5
const BOT_SIGHT_RANGE: float = 600.0
const BOT_SKILL_CHANCE_PER_SEC: float = 0.4
const BOT_SPECIAL_CHANCE_PER_SEC: float = 0.15
## Eden's specials: a bot casts Leaf Gust within this share of its range, Verdant Bloom under this share of its max hp,
## Bark Skin with an enemy this close.
## Verdant Bloom's "+N" starts this far above the player's centre.
const HEAL_NUMBER_RISE: float = 40.0
const BOT_GUST_REACH_SCALE: float = 0.9
const BOT_BLOOM_HP_FRACTION: float = 0.85
const BOT_BARK_ENGAGE_DISTANCE: float = 320.0

# --- Feedback ---
const HIT_FLASH_TIME: float = 0.08
## Character sprite sheets (tools/sprites/generate.py): 96 px cells: idle, then hit flash, then walk (64 px body
## box centred in the cell, with room above for tall hair / flames), then the death fall.
const SPRITE_CELL_SIZE: int = 96
## Part of a cell shown in menus (CharacterData.portrait): the 64 px body box plus headroom above.
const SPRITE_PORTRAIT_RECT: Rect2 = Rect2(12, 4, 72, 72)
const SPRITE_DIE_FRAMES: int = 8
const SPRITE_DIE_FPS: float = 9.0
## Optional melee "attack" strip after the death frames (Great Ape: fists up, smash down in front on frame 3 =
## ape_fists windup 0.3 s, settle back; 0.7 s = its fire interval).
const SPRITE_ATTACK_FRAMES: int = 7
const SPRITE_ATTACK_FPS: float = 10.0
const SPRITE_IDLE_FRAMES: int = 4
const SPRITE_HIT_FRAMES: int = 2
const SPRITE_IDLE_FPS: float = 6.0
const SPRITE_WALK_FRAMES: int = 8
const SPRITE_WALK_FPS: float = SPRITE_IDLE_FPS  # same pace as idle, so the walk frames read clearly
## Below this speed (px/s) a player shows the idle bob instead of the walk cycle.
const SPRITE_WALK_MIN_SPEED: float = 40.0
## On-screen size of a sprite pixel (64 px art -> 96 px tall on a 720 px-high view).
const SPRITE_SCALE: float = 1.5
const HAPTIC_HIT_MS: int = 30
const HAPTIC_KILL_MS: int = 60
const HAPTIC_DEALT_MS: int = 20
const HAPTIC_EXPLOSION_MS: int = 45
## World-to-screen zoom; >1 trades arena view for bigger characters on phone screens.
const CAMERA_ZOOM: float = 1.4
const CAMERA_LOOKAHEAD: float = 60.0
const CAMERA_SMOOTHING: float = 10.0

# --- Match ---
const DEFAULT_MATCH_SEED: int = 1337
const BOT_ID_BASE: int = 10
const MATCH_MIN_PLAYERS: int = 2
const DUEL_PLAYERS: int = 2
const FFA_MAX_PLAYERS: int = 4
const DUEL_KILL_TARGET: int = 5
const FFA_KILL_TARGET: int = 10
const MATCH_TIME_LIMIT: float = 180.0
const MATCH_COUNTDOWN: float = 3.0
const MATCH_RESULTS_TIME: float = 10.0

# --- Simulation timing ---
## Fixed sim step on both client and server; every InputFrame advances the sim by exactly this.
const PHYSICS_FPS: int = 60
const PHYSICS_DT: float = 1.0 / PHYSICS_FPS

# --- Networking ---
const DEFAULT_PORT: int = 7777
const MAX_CLIENTS: int = 4
## Channel count is set by the client only: Godot 4.7's create_server() passes its channel
## argument into ENet's *incoming bandwidth* slot, so the server would advertise ~7 B/s and
## clients would throttle away most of their unreliable input packets.
const NET_CHANNEL_COUNT: int = 5
## ENet's packet throttle also drops unreliable packets on RTT jitter. Inputs carry their own
## redundancy and snapshots are stateless, so deceleration 0 keeps it at "send everything".
const ENET_THROTTLE_INTERVAL_MS: int = 5000
const ENET_THROTTLE_ACCELERATION: int = 2
const ENET_THROTTLE_DECELERATION: int = 0
## Network tick = PHYSICS_FPS / SNAPSHOT_INTERVAL_TICKS = 30 Hz.
const SNAPSHOT_INTERVAL_TICKS: int = 2
const INPUT_SEND_INTERVAL_TICKS: int = 2
## Each input packet re-sends this many recent frames so a few lost packets cost nothing.
const INPUT_REDUNDANCY: int = 6
## Reject input packets carrying more frames than this.
const INPUT_BATCH_MAX: int = 16
## Server-side per-player input buffer; beyond this the oldest frames are dropped.
const INPUT_BUFFER_MAX: int = 16
## Max inputs the server may bank to catch up after a hitch (~133 ms). Bounds speed-hacking.
const INPUT_CATCHUP_MAX: float = 8.0
## Client keeps unacked inputs for replay. 3 s at 60 Hz.
const INPUT_HISTORY_MAX: int = 180
## ~100 ms interpolation delay for remote entities.
const INTERP_DELAY_TICKS: float = 6.0
const INTERP_BUFFER_SIZE: int = 32
const CLOCK_SNAP_TICKS: float = 30.0
const CLOCK_CORRECTION: float = 0.05
## Snapshot-to-snapshot jumps larger than this are teleports (respawn): no lerp.
const TELEPORT_DISTANCE: float = 200.0
## Reconciliation errors up to this are smoothed visually; larger ones snap.
const CORRECTION_SMOOTH_MAX: float = 64.0
const CORRECTION_DECAY: float = 15.0
const SERVER_MAX_FPS: int = 60
const NET_DEBUG_INTERVAL: float = 1.0
const AUTOPILOT_TURN_PER_FRAME: float = 0.03
const AUTOPILOT_STEER_DIRECTIONS: int = 16
const AUTOPILOT_PROBE_DISTANCE: float = 70.0
const AUTOPILOT_SKILL_EVERY_FRAMES: int = 150
const AUTOPILOT_SPECIAL_EVERY_FRAMES: int = 420

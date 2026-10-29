class_name Constants
extends RefCounted
## Gameplay tunables shared by client and server simulation.

# --- Physics layers (bit values) ---
const LAYER_WALLS: int = 1
const LAYER_PLAYERS: int = 2

# --- Arena ---
const TILE_SIZE: float = 48.0

# --- Player movement ---
const PLAYER_RADIUS: float = 18.0
const PLAYER_MOVE_SPEED: float = 270.0
const PLAYER_ACCEL: float = 2600.0
const PLAYER_DECEL: float = 2200.0
## Used when above normal max speed (after dash / knockback) so overspeed bleeds off fast.
const PLAYER_OVERSPEED_DECEL: float = 6000.0
const INPUT_DEADZONE: float = 0.15

# --- Player stats ---
const PLAYER_MAX_HP: int = 100
const PLAYER_MAX_ARMOR: int = 50
const PLAYER_MAX_ENERGY: int = 200
const ARMOR_REGEN_DELAY: float = 3.0
const ARMOR_REGEN_PER_SEC: float = 25.0
const RESPAWN_DELAY: float = 2.0
const RESPAWN_IFRAME_TIME: float = 1.0
const LOADOUT_SLOTS: int = 2

# --- Dash skill ---
const DASH_SPEED: float = 950.0
const DASH_DURATION: float = 0.16
const DASH_IFRAME_TIME: float = 0.22
const DASH_COOLDOWN: float = 1.8

# --- Aiming ---
const AUTO_AIM_RANGE: float = 560.0
const DRAG_AIM_DEADZONE_PX: float = 24.0
const MUZZLE_OFFSET: float = 6.0

# --- Projectiles ---
const PROJECTILE_POOL_SIZE: int = 512
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
const BOT_SIGHT_RANGE: float = 600.0

# --- Feedback ---
const HIT_FLASH_TIME: float = 0.08
const HAPTIC_HIT_MS: int = 30
const CAMERA_LOOKAHEAD: float = 60.0
const CAMERA_SMOOTHING: float = 10.0

# --- Match (seed for shared sim RNG) ---
const DEFAULT_MATCH_SEED: int = 1337
const BOT_ID_BASE: int = 10

# --- Simulation timing ---
## Fixed sim step on both client and server; every InputFrame advances the sim by exactly this.
const PHYSICS_FPS: int = 60
const PHYSICS_DT: float = 1.0 / PHYSICS_FPS

# --- Networking ---
const DEFAULT_PORT: int = 7777
const MAX_CLIENTS: int = 4
const NET_CHANNEL_COUNT: int = 5
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

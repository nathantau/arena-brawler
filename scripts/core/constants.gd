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

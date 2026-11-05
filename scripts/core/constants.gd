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
## Special slots each fighter equips (slot 0 = skill button, slot 1 = special button, slot 2 = third special button).
const SKILL_SLOTS: int = 3
## Slots 0..PICKED_SLOTS-1 are chosen in the loading room; the last slot is the fighter's fixed ultimate.
const PICKED_SLOTS: int = 2
const ULT_SLOT: int = 2
## Ultimate charge (0..1): full after ULT_PASSIVE_SECONDS on its own, or after ULT_DAMAGE_PER_CHARGE damage dealt to enemies.
const ULT_PASSIVE_SECONDS: float = 60.0
const ULT_DAMAGE_PER_CHARGE: float = 300.0

# --- Skills (per-character tunables are in data/characters/*.tres) ---
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
## Fighters whose bots rotate through their whole tagged kit of specials (others always use the one in slot 1).
const KIT_ROTATORS: Array[StringName] = [&"flicker", &"bolt"]

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
const HAPTIC_ULT_MS: int = 80  # the ultimate becomes ready
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
## Teams 3v3: round wins needed to take the match, players per team, the respawn wait (unlimited respawns), round
## clock, and the pause between rounds (everyone is reset at their team's spawns).
const TEAMS_ROUND_TARGET: int = 5
const TEAM_SIZE: int = 3
const TEAMS_MAX_PLAYERS: int = TEAM_SIZE * 2
const TEAMS_RESPAWN_DELAY: float = 8.0
const TEAMS_ROUND_TIME: float = 120.0
const TEAMS_INTERMISSION: float = 3.0
## Teams: everyone's max HP is multiplied by this (Duel / FFA stay as they are).
const TEAMS_HP_SCALE: float = 1.5
## Capture the flag: touch range of a flag / base pad, how long a dropped flag lies before it flies home, and the
## carrier's move speed multiplier.
const FLAG_TOUCH_RADIUS: float = 56.0
const FLAG_RETURN_TIME: float = 8.0
const FLAG_CARRIER_SPEED_SCALE: float = 0.85
## Bots: how near a lying flag must be for them to fetch it, how near the carrier's pursuers stop closing in, how much
## likelier an enemy flag carrier is to be picked as the target (score multiplier), and which bots raid (id + round) % N == 0.
const BOT_FLAG_RANGE: float = 700.0
const BOT_CARRIER_CLOSE: float = 200.0
const BOT_CARRIER_TARGET_WEIGHT: float = 0.2
const BOT_RAID_EVERY: int = 3
const MATCH_TIME_LIMIT: float = 180.0
const MATCH_COUNTDOWN: float = 3.0
const MATCH_RESULTS_TIME: float = 10.0

# --- Simulation timing ---
## Fixed sim step on both client and server; every InputFrame advances the sim by exactly this.
const PHYSICS_FPS: int = 60
const PHYSICS_DT: float = 1.0 / PHYSICS_FPS

# --- Networking ---
const DEFAULT_PORT: int = 7777
const MAX_CLIENTS: int = 6
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
## A player's state is ~440 bytes and ENet's MTU is ~1392, so a snapshot goes out as one packet per this many players:
## one packet for everybody (1.8 KB at 4 players) is fragmented, and losing any fragment loses the whole snapshot.
const SNAPSHOT_PLAYERS_PER_PACKET: int = 2
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
const AUTOPILOT_SPECIAL2_EVERY_FRAMES: int = 510

## Backstab: the shot must travel within this angle of the target's facing.
const BACKSTAB_ANGLE_DEG: float = 60.0
## Split shards (Seed Sling): spread across this fan, fly this far, and are this fraction of the parent's radius.
const SPLIT_FAN_DEG: float = 50.0
const SPLIT_RANGE: float = 200.0
const SPLIT_RADIUS_SCALE: float = 0.6
## Shard pellet keys start here (parent pellet + this * (i + 1)) so they never match a normal pellet.
const SPLIT_PELLET_BASE: int = 100
## Soaked targets move at this x speed (and cannot burn).
const SOAK_SLOW: float = 0.8
## The Snowball Cannon's slow factor: shown as an icy wash instead of the Blossom Snare's pink vines.
const CHILL_SLOW: float = 0.7
## A bee circles its target at this turn rate (rad/s) once it is within BEE_ORBIT_RADIUS px.
const BEE_ORBIT_RATE: float = 7.0
const BEE_ORBIT_RADIUS: float = 60.0
## ...then dives at its target this much faster.
const BEE_DIVE_SCALE: float = 1.3
## A beam's ramp survives this long between ticks that touch the same target.
const BEAM_RAMP_GRACE: float = 0.3
## Spin-up resets after the trigger is released this long.
const FIRE_STREAK_GRACE: float = 0.2
## Boomerang spin (rad/s).
const BOOMERANG_SPIN: float = 22.0
## A boomerang is drawn this much bigger than a bullet, trailed by BOOMERANG_GHOSTS afterimages BOOMERANG_GHOST_GAP s apart.
const BOOMERANG_SCALE: float = 1.6
const BOOMERANG_GHOSTS: int = 3
const BOOMERANG_GHOST_GAP: float = 0.012
const BOOMERANG_GHOST_ALPHA: float = 0.45
## A returning boomerang flies this long at most; a consecutive-shot streak (Pocket Blaster) resets after this long idle.
const BOOMERANG_RETURN_LIFE: float = 4.0
const STREAK_RESET: float = 1.0
## Damage multiplier by WeaponData / SkillData.rarity (common, rare, epic): better items hit slightly harder.
const RARITY_DAMAGE_MULT: Array[float] = [1.0, 1.05, 1.10]
## Every attack's damage (weapons, abilities, ultimates) x this, applied by `CombatRules.scaled` with the rarity bonus.
const DAMAGE_MULT: float = 1.15
## Extra factor on every hit an ultimate deals (its own skill, or the weapon fired while its form runs).
const ULT_DAMAGE_MULT: float = 1.3

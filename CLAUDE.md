# CLAUDE.md — Arena Brawler (working title)

## What we're building
A mobile real-time PvP arena shooter. Combat feel is inspired by top-down roguelike shooters like Soul Knight: twin-stick movement + aim, auto-aim assist, a wide variety of weapons, energy/mana for weapons, a dodge/skill per character, fast and punchy. Instead of dungeon runs, players are matched into small arenas against other real players.

- Platforms: **iOS first**, Android second. Same codebase.
- All art, names, characters and weapons must be **original** — do not copy Soul Knight assets, names or UI.
- Portrait-locked? No — **landscape** only.

## Tech stack (do not change without asking)
- **Engine:** Godot 4.x (latest stable), **GDScript** with static typing everywhere.
- **Networking:** Authoritative dedicated server = the same Godot project exported **headless** (`--headless`). Clients send inputs only; server simulates and broadcasts state.
  - Transport: ENet (UDP) via Godot high-level multiplayer (`ENetMultiplayerPeer`).
  - Client-side prediction for own movement + server reconciliation; interpolation (~100 ms buffer) for other players and projectiles.
  - Server tick 30 Hz, client sends inputs every physics frame (60 Hz) batched per tick.
- **Matchmaking/accounts (later phase):** Nakama (self-hosted via Docker). Until then, a simple lobby server/direct IP connect for dev.
- **Builds:** Godot export templates → Xcode for iOS; Gradle build for Android.
- **Tests:** GUT (Godot Unit Test) for game logic.

## Game design (MVP scope)
**Modes:** 1v1 Duel and 4-player Free-For-All. First to N kills or highest kills when 3-minute timer ends.
**Arenas:** 2 small hand-built tilemap arenas with cover walls, a few destructible crates, weapon/energy pickups on respawn timers.
**Player:**
- HP + Armor (armor regenerates after 3 s of not taking damage, HP does not).
- Energy pool consumed by weapons; restored by pickups.
- Carry 2 weapons, tap to swap.
- 1 character skill on cooldown (MVP characters: Dash-dodge with i-frames; Deployable shield; Dual-wield burst).
**Weapons (MVP set of ~8, plus one signature weapon per character):** pistol (free, 0 energy), SMG, shotgun, sniper, rocket (splash), laser beam, melee sword (reflects bullets on swing), bouncing grenade launcher. All data-driven via `Resource` files (`WeaponData.tres`): damage, fire rate, spread, projectile speed, energy cost, crit chance, knockback.
**Controls (mobile):** left virtual joystick = move; right side = attack button with **auto-aim to nearest visible enemy**, optional drag-to-aim on the attack button; skill button; weapon swap button. Haptics on hit.

## Project structure
```
/project.godot
/scenes/        main menu, lobby, arena, hud
/scripts/
  /core/        game state, match rules, constants
  /net/         server.gd, client.gd, prediction, interpolation, rpc schemas
  /player/      player controller, input, stats, skills
  /weapons/     weapon base, projectile, weapon_data resources
  /arena/       spawns, pickups, destructibles
  /ui/          hud, joystick, menus
/data/weapons/  *.tres weapon definitions
/data/characters/
/assets/        placeholder art (simple shapes/colors until real art)
/tests/         GUT tests
/server/        headless export preset, Dockerfile, run scripts
```

## Rules for Claude Code
1. **Server-authoritative always.** Never trust client damage, position, ammo or cooldowns. Clients send `{seq, move_vec, aim_vec, fire, skill, swap}` only.
2. Keep simulation logic (movement, projectiles, damage) in plain deterministic-ish functions that both client prediction and server can call. No `randf()` in shared sim without a seeded RNG.
3. Static types in all GDScript. No magic numbers — put tunables in `scripts/core/constants.gd` or weapon/character `.tres` resources.
4. Edit `.tscn` files as text carefully; prefer building nodes in code for anything dynamic.
5. Use placeholder art (colored shapes) — don't block on art.
6. Every gameplay rule (damage calc, armor regen, energy cost, kill scoring) gets a GUT test.
7. Mobile performance: target 60 fps on iPhone 11. Pool projectiles; avoid per-frame allocations; keep draw calls low.
8. After each milestone, update the **Status** section below and commit with a clear message.
9. Ask before adding new dependencies or changing the stack.

## Milestones
1. **M1 – Local combat feel (single player vs dummy bots):** movement, joystick, auto-aim, 3 weapons, energy, HP/armor, dash skill, one arena. Make it *feel good* before networking.
2. **M2 – Networking:** headless server, 2 clients on LAN, prediction + reconciliation + interpolation, server-side hit detection.
3. **M3 – Match loop:** lobby, 1v1 + FFA modes, timer, scoring, respawns, pickups, results screen.
4. **M4 – Content:** all 8 weapons, 3 characters, 2 arenas, juice (screenshake, hit flash, particles, haptics, SFX).
5. **M5 – iOS build:** export to Xcode, TestFlight build, test on real device over internet against a cloud-hosted server (Docker).
6. **M6 – Online services:** Nakama accounts, matchmaking queue, basic MMR.
7. **M7 – Android build** + device testing.

## Commands
- Run client (menu: offline vs bots / join by IP): `godot --path . `
- Skip the menu: `godot --path . -- --offline` or `godot --path . -- --connect 192.168.1.20:7777`
- Run client with touch controls on desktop (mouse emulates touch): `godot --path . -- --touch`
- Run headless server: `godot --path . --headless -- --server --port 7777` (add `--bots N` for server-side bots)
- Match options (server / offline): `--mode duel|ffa` (starting mode; players can switch it in the lobby),
  `--arena N` (0 = Pit, 1 = Foundry), `--time-limit S` (shorter matches for testing)
- Pick a character (client / offline): `--character flicker|warden|twinshot`
- Render frames to check visuals without a screen: `godot --path . --write-movie /tmp/f.png --fixed-fps 30 --quit-after 300 -- --offline --autopilot --touch`
- Net debugging: add `--net-debug` (prints server/client net stats every second, logs reconciliation corrections);
  `--autopilot` makes a client drive + fire on its own, e.g. two headless autopilot clients for soak tests:
  `godot --path . --headless --quit-after 4000 -- --connect 127.0.0.1:7777 --autopilot --net-debug`
- Tests: `godot --path . --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
- iOS export (needs `app_store_team_id` in `export_presets.cfg`): `godot --path . --headless --export-release "iOS" build/ios/ArenaBrawler.xcodeproj`
  - Compile check without signing: `xcodebuild -project build/ios/ArenaBrawler.xcodeproj -scheme ArenaBrawler -sdk iphoneos -configuration Release -derivedDataPath build/ios-dd CODE_SIGNING_ALLOWED=NO build`
- Install on a USB/Wi-Fi-paired iPhone (dev-signed; after an iOS export): `xcodebuild -project build/ios/ArenaBrawler.xcodeproj -scheme ArenaBrawler -configuration Release -destination id=<UDID> -derivedDataPath build/ios-dev -allowProvisioningUpdates <ASC key flags as in tools/release/release_ios.sh> CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY="Apple Development" build`
  then `xcrun devicectl device install app --device <UDID> build/ios-dev/Build/Products/Release-iphoneos/ArenaBrawler.app` (`xcrun devicectl list devices` for the UDID)
- TestFlight: `ASC_KEY_ID=... ASC_ISSUER_ID=... tools/release/release_ios.sh` (needs the app record in App Store Connect)
- Server Docker image: `server/build.sh` (exports Linux x86_64 + arm64 binaries, builds for this machine's arch;
  `PLATFORM=linux/amd64 server/build.sh` for an x86 cloud VM). Run: `docker run --rm -p 7777:7777/udp arena-brawler-server --bots 2`
- Regenerate sprites + app icon: `tools/sprites/.venv/bin/python tools/sprites/generate.py`
  (first time: `python3 -m venv tools/sprites/.venv && tools/sprites/.venv/bin/pip install -r tools/sprites/requirements.txt`),
  then `godot --path . --headless --import`

## Status
- [~] **M1 – implemented, needs a hands-on feel pass** (2026-10-28)
  - Done: floating joystick + FIRE (auto-aim, drag-to-aim) / DASH / SWAP touch buttons; WASD + mouse/J/Space/Q on desktop;
    auto-aim to nearest visible enemy with target ring; Pocket Blaster (free), Buzzsaw SMG, Scattercannon;
    energy; HP + armor regen; dash with i-frames; 3 dummy bots; kill/death tally; respawn at safest spawn; one arena ("Pit").
  - Sim lives in pure classes (`PlayerStats`, `WeaponState`, `Loadout`, `DashSkill`, `MovementSim`, `CombatRules`, `AutoAim`)
    driven by `Player.simulate(InputFrame, delta)`.
  - Projectiles: fixed 512-slot pool, raycast per step, one `_draw` for all bullets.
  - Temporary M1 shortcut: arena is an ASCII layout (`scripts/arena/arena_layouts.gd`) rather than a TileMap.
    (Dev weapon cycling was removed in M3 now that pickups exist.)
- [x] **M2 – Networking** (2026-10-28). Verified: headless server + 2 autopilot clients on loopback, with hits, a kill,
  respawn and matching scoreboards on both clients; 0 px prediction error when nobody is getting hit.
  - **Tick model:** sim runs at a fixed 60 Hz on server and client (every InputFrame = one `PHYSICS_DT` step, which is
    what `move_and_slide` uses anyway). "Server tick 30 Hz" = the *network* tick: snapshots go out every 2nd frame;
    clients send inputs every 2nd frame (each packet re-sends the last 6 for loss tolerance).
  - **Server** (`net/server.gd`): one `NetInputQueue` per peer, credit-limited (1 input/frame, up to 8 banked to catch up
    after hitches, so no speed hacks and no dropped inputs); owns damage, kills, respawns. Channels: snapshots and shots
    unreliable_ordered, join/leave/kill reliable.
  - **Client** (`net/client.gd`): predicts own player, reconciles = apply server state for the last acked seq + replay
    unacked inputs (`simulate(..., replay=true)` changes state but spawns nothing); corrections ≤ 64 px are
    smoothed via `visual_offset`. Others are interpolated 6 ticks (100 ms) behind (`SnapshotBuffer` + `RenderClock`).
  - **Shots:** per-shot seed = f(match_seed, owner, seq), so a shot event is a single message and every peer rebuilds the
    exact same pellets/crit. Client projectile pools are cosmetic; server sends hit events keyed by
    (owner, seq, pellet) to remove the matching bullet + flash the victim.
  - Players don't collide with each other (walls only), which keeps prediction exact.
  - All RPCs live on `NetSession` at `/root/Main/Session` (Godot requires the same path + RPC list on all peers).
  - Known M2 limitations: no lag compensation, so with real latency you'll sometimes see your bullet hit an
    interpolated (100 ms old) enemy that the server counts as a miss, and remote players' bullets appear
    from where they actually are, a little ahead of their drawn body. Knockback/damage on yourself shows up
    as a small smoothed correction. No server Dockerfile yet (planned for M5).
  - 82 GUT tests passing (incl. replay-matches-server determinism against walls, input queue anti-speed-hack).
  - **Fixed in M3:** M2 was silently losing most client inputs for the first several seconds of every connection.
    Godot 4.7's `ENetMultiplayerPeer.create_server(port, clients, channels)` passes the channel count into ENet's
    *incoming bandwidth* slot, so the server advertised ~7 B/s and clients' ENet throttled away ~80% of unreliable
    packets. The server now calls `create_server(port, clients)` (clients request the channels) and both sides set
    ENet throttle deceleration to 0. The M2 soak only measured after things settled, which hid it.
- [x] **M3 – Match loop** (2026-10-29). Verified: server + 2 autopilot clients + 1 bot ran 3 full FFA cycles
  (lobby → countdown → match → results → lobby) with kills, pickups and no errors; offline duel/FFA render-checked
  via `--write-movie` frames (lobby panel, countdown, match clock, results, pickups).
  - **Flow** (`core/match_controller.gd`, authoritative): LOBBY = warm-up in the arena with a lobby panel (roster,
    mode toggle, Ready) → all humans ready → COUNTDOWN 3 s (inputs frozen, scores reset, participants placed at
    spread spawns, pickups reset) → PLAYING (first to 5 kills in Duel / 10 in FFA, or 3:00 timer) → RESULTS 10 s
    (frozen, standings) → LOBBY. Ranking: kills, then fewest deaths; tied top two = draw.
  - **Participants** fixed at countdown: humans first, bots fill to the mode's size (Duel 2, FFA 4). Everyone else
    sits out (invisible, no death counted) and spectates; late joiners spectate until the next lobby. A match that
    drops below 2 participants ends immediately.
  - **Pure rules** in `MatchRules` (participants, start blocker, rank, winner, kill target) and `MatchState`
    (synced whole, reliably, on every change via `rpc_match_state`; clients only count the clock down locally).
    Lobby requests are `rpc_set_ready` / `rpc_request_mode` (any player may switch mode in the lobby for now).
  - **Pickups** (`arena/pickup_field.gd`): layout chars `E` (energy +80, 12 s respawn) and `W` (weapon from
    SMG/Scattercannon, 18 s). Server-authoritative; availability sent as a small reliable array on change.
    Everyone starts with only their sidearm (now the character's signature weapon); slot 0 is a permanent sidearm, weapon pickups fill/replace
    slot 2; dying resets your loadout. Energy pickups are skipped when full, weapon pickups when already carried.
  - Players have placeholder names from their colour ("Blue", "Red bot") until accounts in M6.
  - Also fixed: full-screen UI controls (HUD, touch controls, menu) never resized to the screen (anchors without
    offsets); the HUD's centre text and the touch controls were drawn in a tiny top-left box since M1.
  - Known M3 limitations: the freeze/unfreeze at countdown/results causes one small smoothed correction (~2–13 px)
    since the phase change isn't tied to an input seq; no destructible crates yet (arena work in M4); bots grab
    pickups too and only ever target humans; no rematch vote / host role — anyone can toggle the mode.
  - 109 GUT tests passing (match rules/flow, state sync validation, pickup effects + loadout rules, frozen input,
    countdown seating/benching).
- [x] **M4 – Content** (2026-10-29). Verified: 132 GUT tests; server + Warden/Twinshot autopilot clients + bots on
  Foundry with kills, pickups, skills and match cycles and no errors; offline frames rendered and checked.
  - **8 weapons** (`data/weapons/*.tres`, all data-driven via new `WeaponData` fields `kind`, splash, bounce, drag,
    melee): Pocket Blaster (free sidearm), Buzzsaw SMG, Scattercannon, Needle Rifle (sniper), Boomtube (rocket,
    splash), Prism Lance (hitscan beam), Arc Blade (sword: arc hit + reflects enemy projectiles), Hopper (bouncing
    grenade, fuse + splash). Splash: linear falloff, needs line of sight, no self-damage (keeps prediction simple).
  - `ProjectilePool` handles all three kinds. Each pellet keeps its (owner, seq, pellet) key; `attacker_id` changes
    when reflected so server hit events still match the client's cosmetic copy.
  - **3 characters** (`data/characters/*.tres`, `CharacterData` + `CharacterSkill` replacing `DashSkill`):
    Flicker (Dash, i-frames), Warden (Barrier: a wall on `LAYER_SHIELDS` that stops enemy projectiles, 3 s),
    Twinshot (Dual wield: every shot fires a second offset volley for 4 s; pellet keys offset by 64). Characters
    differ in HP/armor/energy/speed. Skill state + character id are in snapshots, so others' barriers and dual guns
    show on every client and replay is exact (tested for all three). Picked in the lobby (`rpc_select_character`).
  - **2 arenas**: Pit and Foundry (`ArenaLayouts`, 180°-symmetric, tested). Chosen in the lobby (`MatchState.arena_index`,
    `rpc_request_arena`); switching rebuilds walls/crates/pickups and respawns everyone.
  - **Destructible crates** (`C` in layouts, `arena/crate.gd`): block movement + sight (on LAYER_WALLS), 60 hp,
    damaged by bullets/beams/blades/blasts, reset each match; hp mirrored to clients via `rpc_crates`.
  - **Juice** (local view only, never on the server): `fx/effects.gd` (pooled particles, damage numbers with crits,
    beam lines, sword arcs, blast rings), camera zoomed 1.4x (`CAMERA_ZOOM`, bigger characters on phones), camera shake (trauma model: own heavy shots, getting hit, nearby blasts),
    haptics (hit, kill, nearby blast), character emblems, dual-gun / barrier visuals. `fx/sfx.gd` synthesizes all
    sounds at startup from a small recipe table (no audio assets), distance-attenuated.
  - Bots get varied characters and use their skill occasionally; autopilot uses its skill every 2.5 s.
  - Known M4 limitations: crates are still part of the ASCII layouts (no TileMap yet); bots don't pick weapons
    deliberately or use melee well; damage from blasts/knockback on yourself shows as a smoothed correction
    (up to ~50 px with rockets); SFX are placeholder synth blips — real sounds/art later; balance is untuned.
- **Pixel-art sprites** (2026-10-30): original 64x64 characters generated by `tools/sprites/generate.py` (Pillow,
  shared 16-colour `palette.py`, auto 1 px outline, self-check for palette/alpha/edges) into `assets/sprites/<id>.png`:
  horizontal sheets of 4 idle-bob frames + 2 hit-flash frames + 8 walk frames (16 fps, shown above 40 px/s); scarves/feathers/plumes sway and Warden's gem glints via the `t` tick. Flicker (hooded scout, scarf), Warden (knight, plume,
  tower shield), Twinshot (wide-brim gunslinger, two holsters), Wukong (monkey king, cloud puffs via `AURAS`, Dash). New characters: `.claude/skills/new-character`. `CharacterData.sprite_sheet` → `sprite_frames()`
  builds a shared SpriteFrames ("idle", "hit", "walk"); the Player has an `AnimatedSprite2D` (Nearest, x1.5) plus an overlay
  node for the front gun and bars. Player colour = foot ring only (sheets aren't recoloured).
  The script also writes `assets/icon.png` and one 48x24 image per weapon (`assets/sprites/weapons/<id>.png`).
- **Character weapons** (2026-10-30): many-to-many via tags. `WeaponData.tags` (e.g. `blade`, `light`, `heavy`,
  `precision`, `explosive`, `arcane`; empty = anyone) vs `CharacterData.weapon_tags`; `can_use()` = any shared tag.
  Pickups a character can't use stay on the floor and are drawn faded for the local player. Each character has a
  free **signature weapon** (`signature_weapon`, tagged with the character's id, not a pickup) as its permanent
  slot-0 sidearm (bots keep the Dummy Blaster): Flicker's Ripple Kunai (3-knife fan, `pierce` = passes through
  1 player), Warden's Oath Hammer (melee slam: one blast at the tip of the reach, not behind walls), Twinshot's
  Ricochet Six (bullets bounce off walls twice and still hit), Wukong's Cloud Staff (`thrust`: long narrow stab).
  Weapons are drawn from their sprite at the character's pixel scale, pivoting on the grip at hand height: guns
  kick back and up, melee sweeps the arc from a raised guard, thrusts stab out and back (`Player._draw_gun`).
  Clients don't stop piercing pellets on server hit events. Not done: bots don't prefer usable pickups; no
  per-weapon projectile sprites (still circles); the HUD doesn't say why a pickup was refused.
- [~] **M5 – iOS build + cloud server: local half done, blocked on accounts/hosting** (2026-10-30)
  - Done: `export_presets.cfg` with "Linux Server x86_64"/"Linux Server arm64" (dedicated-server exports, tests
    and GUT excluded) and "iOS" (bundle `com.nathantau.arenabrawler`, landscape, Xcode project only).
    `server/Dockerfile` (debian-slim, non-root, UDP 7777, extra args pass through) + `server/build.sh`.
    Verified: container on Docker Desktop (arm64) ran a full match with 2 autopilot clients + 1 bot, no errors.
    iOS: enabled ETC2/ASTC (required for mobile export); with a placeholder team ID the export produces an
    Xcode project that compiles (`BUILD SUCCEEDED`, unsigned). App icon (`assets/icon.png`, 1024 px, no alpha)
    generated from the Flicker sprite by `tools/sprites/generate.py`.
  - Still needed: Apple Team ID (+ signing) → archive + TestFlight upload; a cloud host with a public UDP port;
    a default server address in the client (currently join-by-IP in the menu); test on a real device over the internet.
- [ ] M6 not started

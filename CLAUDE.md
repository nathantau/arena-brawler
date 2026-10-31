# CLAUDE.md — BrawlBits (repo and Xcode project still named arena-brawler / ArenaBrawler)

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
- Energy pool consumed by weapon shots; refills over time.
- One weapon, picked before the match (signature or a shared weapon the fighter can use).
- 2 specials on cooldown, picked from the fighter's own plus generic ones (Dash, Barrier).
**Weapons (MVP set of ~8, plus one signature weapon per character):** pistol (free, 0 energy), SMG, shotgun, sniper, rocket (splash), laser beam, melee sword (reflects bullets on swing), bouncing grenade launcher. All data-driven via `Resource` files (`WeaponData.tres`): damage, fire rate, spread, projectile speed, energy cost, crit chance, knockback.
**Controls (mobile):** left virtual joystick = move; right side = attack button with **auto-aim to nearest visible enemy**, optional drag-to-aim on the attack button; two special buttons. Haptics on hit.

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
1. **Server-authoritative always.** Never trust client damage, position, ammo or cooldowns. Clients send `{seq, move_vec, aim_vec, fire, skill, special}` only.
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
- Host from a device (what the menu's HOST button does; listen server, you play too, LAN IP:port shown in the loading room): `godot --path . -- --host [--port 7777]`
  (headless e2e: `--headless -- --host --autopilot` + a `--connect 127.0.0.1:7777 --autopilot` client)
- Run headless server: `godot --path . --headless -- --server --port 7777` (add `--bots N` for server-side bots)
- Match options (server / offline): `--mode duel|ffa` (starting mode; players can switch it in the lobby),
  `--arena N` (0 = Pit, 1 = Foundry), `--time-limit S` (shorter matches for testing)
- Pick a character (client / offline): `--character flicker|warden|twinshot|wukong|flint|sakura`
  (ids; shown as Shade / Warden / Gunnar / Apex / Flint / Sakura: `display_name` only, ids, files and art keep the old names)
- Render frames to check visuals without a screen: `godot --path . --write-movie /tmp/f.png --fixed-fps 30 --quit-after 300 -- --offline --autopilot --touch`
- Net debugging: add `--net-debug` (prints server/client net stats every second, logs reconciliation corrections);
  `--autopilot` makes a client drive + fire on its own, e.g. two headless autopilot clients for soak tests:
  `godot --path . --headless --quit-after 4000 -- --connect 127.0.0.1:7777 --autopilot --net-debug`
- Tests: `godot --path . --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
- Smoke test (every fighter x special x weapon in a live arena, drawing included; run before every push/release), without stealing focus:
  write `override.cfg` with `[display]` `window/size/no_focus=true`, `window/size/initial_position_type=0`,
  `window/size/initial_position=Vector2i(-4000, -4000)`, then
  `open -g -W -n -a /Applications/Godot.app --args --path "$PWD" --log-file <log> -s tools/smoke_specials.gd`,
  delete `override.cfg`; `grep -c "SCRIPT ERROR" <log>` must be 0 and the log ends with `smoke done <n> combos`.
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
  - Done: floating joystick + FIRE (auto-aim, drag-to-aim measured from where the thumb lands, so an off-centre press still auto-aims) / DASH / SWAP touch buttons; WASD + mouse/J/Space/Q on desktop;
    auto-aim to nearest visible enemy (`AutoAim.visible_point`: sight from the shooter's hand to the target's centre or lower hitbox, since feet-based collision puts a player under a wall with its centre inside it; `Player.aim_at`: searches angles for the shot line from the hand that passes through the target; bots too); Pocket Blaster (free), Buzzsaw SMG, Scattercannon;
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
    Flicker, Warden (Barrier: a wall on `LAYER_SHIELDS` that stops enemy projectiles, 3 s),
    Twinshot. Characters
    differ in HP/armor/energy/speed. Skill state + character id are in snapshots, so others' barriers
    show on every client and replay is exact (tested for all three). Picked in the lobby (`rpc_select_character`).
  - **2 arenas**: Pit and Foundry (`ArenaLayouts`, 180°-symmetric, tested). Chosen in the lobby (`MatchState.arena_index`,
    `rpc_request_arena`); switching rebuilds walls/crates/pickups and respawns everyone.
  - **Destructible crates** (`C` in layouts, `arena/crate.gd`): block movement + sight (on LAYER_WALLS), 60 hp,
    damaged by bullets/beams/blades/blasts, reset each match; hp mirrored to clients via `rpc_crates`.
  - **Juice** (local view only, never on the server): `fx/effects.gd` (pooled particles, damage numbers with crits,
    beam lines, sword arcs, blast rings), camera zoomed 1.4x (`CAMERA_ZOOM`, bigger characters on phones), camera shake (trauma model: own heavy shots, getting hit, nearby blasts),
    haptics (hit, kill, nearby blast), character emblems, barrier visuals. `fx/sfx.gd` synthesizes all
    sounds at startup from a small recipe table (no audio assets), distance-attenuated.
  - Bots get varied characters and use their skill occasionally; autopilot uses its skill every 2.5 s.
  - Known M4 limitations: crates are still part of the ASCII layouts (no TileMap yet); bots don't pick weapons
    deliberately or use melee well; damage from blasts/knockback on yourself shows as a smoothed correction
    (up to ~50 px with rockets); SFX are placeholder synth blips — real sounds/art later; balance is untuned.
- **Pixel-art sprites** (2026-10-30): original 64x64 characters generated by `tools/sprites/generate.py` (Pillow,
  shared 18-colour `palette.py` (pinks added for Sakura), auto 1 px outline, self-check for palette/alpha/edges) into `assets/sprites/<id>.png`:
  horizontal sheets of 4 idle-bob frames + 2 hit-flash frames + 8 walk frames (16 fps, shown above 40 px/s) + 8 death
  frames (generated for every character and form: white flash, pop, topple backwards, X eyes via the `KO` flag in the eye
  helpers, dizzy stars, dither dissolve; 9 fps). Sheet cells are 96 px (`SPRITE_CELL_SIZE`) so the fall and art above the 64 px
  body box (`CROWNS`) fit; all animations use whole cells, menus use `CharacterData.portrait()` (`SPRITE_PORTRAIT_RECT`). On a real death `Player._spawn_corpse()` plays "die" on every peer; scarves/feathers/plumes sway and Warden's gem glints via the `t` tick. Flicker (kunoichi: jagged bob, spiky topknot with red ribbon tails, breastplate), Warden (knight, plume,
  tower shield), Twinshot (wide-brim gunslinger, two holsters), Wukong (monkey king, cloud puffs via `AURAS`, Dash). Flint (fire elemental, squared-off head (flat top, tight corners, rounded jaw) crowned with 6 flickering flame tufts plus an inner out-of-step layer and tiny rising embers, drawn above the body box via generate.py `CROWNS` (`flint_crown`; Inferno: more, taller tufts), a scorched dark suit burning up from a ragged hem (generate.py `flint_burn`; heat burns it off, gone in Inferno) over a glowing molten body and legs, flames on his feet, wisps breaking off, fists of fire, rising sparks (`flint_embers` aura); Ember Palm: a held fireball, animated and drawn upright so its flames rise (`WeaponData.upright`, `held_frames`, generate.py `WEAPON_ANIMS`: a strip looped in-world, the HUD keeps the still `sprite`), short-range piercing fireballs from its front with drag; signature **Inferno**: TRANSFORM into `flint_inferno` (generate.py `flint(heat=1)`: wide flame tongues sweeping out and curling up behind him (`tongue()`), flames curling up his front, white-hot body, blazing eyes, taller crown; morph strip = heat rising) for 5 s, FIRE = `inferno_beam` (wide fire BEAM, held: `WeaponData.held_beam` makes `Effects.hold_beam` draw it every frame from his fist along his aim, renewed by each damage tick, surging fire layers, sparks and flame wisps peeling off and rising; from his fist: `muzzle_x` set, or a sprite-less weapon starts 40 px out like a volley); Supernova (VOLLEY of 16 fireballs) is still pickable). Gunnar (twinshot) and Warden are benched (`CharacterData.in_rotation = false`: not in menus, loading room or bots; still load by id). All characters share one base modelled on Apex's face (generate.py `FACE`, `FACE_R`, `BODY`, `EYES_X/Y`, `BLUSH`, `MOUTH`). Sakura (pink-haired girl in a white kimono, red obi bow, middle-parted hair with mirrored curtains and a long ponytail tied with a cherry blossom; Blossom Fan: 5 bouncing petals with drag; Petal Storm: VOLLEY of 40 homing petals (`WeaponData.homing`: turn rate toward the nearest hittable enemy) that sweep round in a wave; uses the palette's PINK / PINK_L). New characters: `.claude/skills/new-character`. `CharacterData.sprite_sheet` → `sprite_frames()`
  builds a shared SpriteFrames ("idle", "hit", "walk"); the Player has an `AnimatedSprite2D` (Nearest, x1.5) plus an overlay
  node for the front weapon and bars. No rings under the feet, just a shadow; player colour shows in the scoreboard and effects (sheets aren't recoloured).
  The script also writes `assets/icon.png` and one 48x24 image per weapon (`assets/sprites/weapons/<id>.png`).
- **Character weapons** (2026-10-30): many-to-many via tags. `WeaponData.tags` (e.g. `blade`, `light`, `heavy`,
  `precision`, `explosive`, `arcane`; empty = anyone) vs `CharacterData.weapon_tags`; `can_use()` = any shared tag.
  Pickups a character can't use stay on the floor and are drawn faded for the local player. Each character has a
  free **signature weapon** (`signature_weapon`, tagged with the character's id, not a pickup) as its permanent
  slot-0 sidearm (bots keep the Dummy Blaster): Flicker's Ripple Kunai (3-knife fan, `pierce` = passes through
  1 player), Warden's Oath Hammer (melee slam: one blast at the tip of the reach, not behind walls), Twinshot's
  Ricochet Six (bullets bounce off walls twice and still hit), Wukong's Cloud Staff (`thrust`: long narrow stab).
  Arms and hands are small and part of each sprite's art (generate.py `arm()`, `ARM_X`; Sakura's small kimono sleeves,
  Flint's fire fists); a weapon's grip sits on the front hand, on the aim side (`Player.WEAPON_HAND`, `hand_offset()`), drawn over the body
  but behind the head (the frame's head rows, `Player.SPRITE_HEAD_ROWS`, are redrawn over it) and follows the aim; shots start from there (`shot_origin`, `muzzle_distance`).
  Weapons are drawn from their sprite at the character's pixel scale, pivoting on the grip: guns
  kick back and up, melee sweeps the arc from a raised guard, thrusts stab out and back (`Player._draw_gun`).
  Clients don't stop piercing pellets on server hit events.
  **Loading room** (`ui/lobby_panel.gd`, full screen in the lobby phase; steps 1 fighter / 2 weapon down the left, 3 special
  on the right; fighter cards play the idle loop from the sheet's whole cell so everyone stands in the same spot; the
  font's "fi" ligature is off, `UiStyle._no_ligatures`): pick a character card, then a starting
  weapon card (pickup weapons the character can use; signature shown as always carried), then Ready (disabled
  until a weapon is picked; the server doesn't require one, so autopilot/bots are unaffected). The pick is
  server-validated (`Arena.select_weapon`, `rpc_select_weapon`; lobby only, usable pickup weapon) and becomes
  slot 1 of the respawn loadout; switching to a character that can't use it drops it. `--weapon ID` picks one
  from the command line (offline / client).
- **Arena art + Gym** (2026-10-30): arenas are pixel art at the characters' scale (32 art px per 48 px tile),
  generated by `tools/sprites/generate.py` into `assets/arenas/`: per theme a tile row (`ArenaFloor.Tile`: two
  floor variants, floor shadowed under walls, wall top, wall with a front face where floor is below for a 3/4 look,
  crate + damaged crate), optional full-arena decal (`gym_decal.png`: court lines), shared pickup pad + energy
  crystal. `arena/arena_floor.gd` draws floors → decal → walls (Nearest); crates draw their frame from the same
  sheet. Themes per layout in `ArenaLayouts.THEMES`: Pit (stone), Foundry (steel plates, brick, hazard crates),
  **Gym** (new 3rd layout: hardwood court, keys, arcs, hoops on the end-wall stanchions, scorer's tables, ball carts).
  New arena = layout in `ArenaLayouts` + theme in generate.py `THEMES` (+ optional `DECALS`, sized 40x24 tiles).
- **UI polish** (2026-10-30): `ui/ui_style.gd` is the shared look. Font: **Pixelify Sans** (OFL, `assets/fonts/`,
  bold via a FontVariation), installed into Godot's default theme + `ThemeDB.fallback_font` by `UiStyle.install()`
  (our UI hangs off Nodes/CanvasLayers, which don't inherit a Window theme). Pixel UI kit generated into
  `assets/ui/` (9-slices pre-scaled x2: panel, card / selected / gold, button / pressed / primary / disabled,
  field; round touch buttons, joystick, icons for hp/armor/energy/kills/deaths/clock/fire/swap/skills/trophy).
  Theme variations: PrimaryButton, Card*, HeaderLabel, DimLabel. Text sizes: 18 is the floor (~10 pt on a phone).
  Every screen keeps clear of the notch / Dynamic Island / home bar via `UiStyle.safe_insets` (`--notch` fakes
  iPhone insets on desktop). Redone: HUD (icon bars, weapon slots with sprites + cost, kills/deaths pill, clock),
  touch controls (pixel buttons, skill icon + cooldown, swap shows the other weapon), title screen (tiled court,
  logo, idling roster), loading room, results (trophy, portraits). Damage numbers / pickup labels outlined.
  Players move against a players-only copy of every wall and crate shifted up by `WALL_FEET_STRIP` (`LAYER_WALL_FEET`,
  `Arena.feet_strip`), not the walls themselves: that's colliding by the feet, drawn below the collision circle, so
  feet stop at a wall's top, the head can overlap the wall above and one-tile gaps fit (bullets ignore it).
  Pause menu (`PauseMenu`, II button top-right in a match, Esc on desktop): Resume / Restart (offline, keeps the
  character) / Leave match; offline it pauses the tree, online the match keeps running (`Arena.leave_requested`).
  iOS Simulator: Godot's simulator lib is x86_64 only, so build with `ARCHS=x86_64` (runs under Rosetta). iOS 27 simulators
  refuse x86_64 apps: use an iOS 18 one (e.g. iPhone 16 Pro): `xcodebuild ... -sdk iphonesimulator -destination id=<SIM>
  -derivedDataPath build/ios-sim ARCHS=x86_64 ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build`, then `xcrun simctl install/launch`.
- **Skills as data: Dash + 1 special** (2026-10-30): `SkillData` resources in `data/skills/` (kind DASH / SHIELD /
  TRANSFORM / ..., cooldown, duration, icon, blurb, tags like weapons; `special = false` for Dash).
  `SkillCatalog.shared()`; `CharacterData.signature_skill` + `can_use_skill()` (same tag list as weapons).
  Every player has `dash` (shared, own button / Space / InputFrame `skill`) and `special` (picked in the loading
  room, second button / E / InputFrame `special` flag 8). Specials: Barrier (heavy: Warden, Twinshot)
  (Dual Wield was removed 2026-10-31: too close to another game's signature mechanic), **Great Ape** (Wukong signature, TRANSFORM: 6 s as a big dark-red ape drawn x1.35
  from `assets/sprites/wukong_ape.png` (generate.py `FORMS`), half damage taken, 0.9 speed, FIRE uses
  `ape_fists` (melee slam) instead of the loadout, each slam playing the sheet's "attack" strip (generate.py `ATTACKS`/`APE_POSES`: he crouches, leaps (per-frame `hop`, knees tucked) with fists up beside his head, lands wide in a puff of dust as they smash down in front where the slam lands, back to the knuckle-walk; the hit waits for the smash frame: `WeaponData.windup` 0.3 s, `Player._windup_left`, remote peers start the strip at the impact via `play_recoil(skip)`); form weapon cooldown is in the snapshot). Snapshots carry both
  slots (`DASH_*`, `SPECIAL_ID/…`); server validates `rpc_select_special`; `--special ID` CLI. The loading room is
  fighter cards with a special column beside them, then weapons. Removed per-character skill fields (Wukong's
  longer Somersault dash is gone: everyone shares one Dash).
- **Balance pass** (2026-10-31, numbers only, untested in real matches): reference sustained DPS vs ~140 HP+armor.
  Sakura fan 5 -> 4 dmg; Ember Palm interval 0.12 -> 0.14 s; SMG 7 -> 6; Arc Blade 34 -> 30; Boomtube rocket 40 -> 50;
  Inferno beam 7 -> 5 dmg/tick; Petal Storm 3 -> 2 dmg per petal, cooldown 8 -> 9 s.
- **Flicker is the ninja** (2026-10-30): navy shroud, steel breastplate, mask peaking at the nose, steel forehead plate, choppy
  bob with a big spiky topknot (drawn above the art box: generate.py `CROWNS`, kept on KO via `KO_CROWNS`), its red
  tie behind her hair, ribbon tails that sway in idle; bare hands. Clothes shading (2026-10-31): light from the top left; breastplate specular + dithered shaded lower half, two-tone sash, shroud creases with lit ridges, sleeve/shin wraps (generate.py `sleeve_detail`). Four Flicker-only specials (tag `flicker`): **Shadow Clones** (signature, CLONES: 3 decoys run out from
  where you stood; positions are a pure function of the synced special state + walls (`Player.clone_points()`, raycast against the
  feet-level walls players move in, so casting from under a wall can't send them through it),
  drawn by `player/special_fx.gd` with the owner's sprite/weapon; harmless and bullets pass through, but enemy
  auto-aim and bots target them), (Blink was cut 2026-10-31: Dash and Grapple Kunai cover it),
  **Smoke Bomb** (SMOKE: cloud at your feet; while inside it `is_hidden()` and enemy auto-aim / bots skip you),
  **Fan of Blades** (VOLLEY: fires `blade_fan`, 12 piercing kunai in a ring, through the normal shot pipeline
  with seq + `VOLLEY_SEQ_OFFSET`), **Grapple Kunai** (GRAPPLE = 8, 2026-10-31: a chained kunai along the aim, cast
  once at activation against `LAYER_WALL_FEET` up to `grapple_range` 420; a bite stores the stop point (a player radius +
  `GRAPPLE_STANDOFF` short of the wall) in the slot's `anchor`, she's held still for `grapple_bite_time` 0.08 s, then
  `Player._pull` drags her straight there at `grapple_speed` 1100 px/s with `move_and_collide` (walls on the way stop
  her; no firing meanwhile); a miss doesn't move her and charges `grapple_miss_cooldown` 1.5 s instead of 6 s.
  `SpecialFx` draws the kunai + chain links, a bite spark, her zip pose (generate.py `flicker_zip`: leaning, arm out,
  ribbons streaming; sprite hidden via `hides_owner()`) and speed lines; a miss (seen as the short cooldown appearing)
  flies out and snaps back). Polished 2026-10-31: 8-frame zip (ghost trail, speed streaks, snapping ribbons), 8-frame
  `grapple_chain` glint cycle, 6-frame `grapple_throw` at the hand, 8-frame `grapple_spark` (star, shock ring, trailing sparks, chips),
  6-frame `grapple_land` dust when the zip ends after a bite.
  Flourishes (`SpecialFx`, detected from synced state changes so remote players show them too): clones appear in
  their own cloud poof in a ring around the player (`CLONE_START_DISTANCE`), fade in, and vanish in poofs; the Great Ape transformation morphs
  (`SkillData.form_morph`: 12-frame 96 px strip, full colour: Wukong, ten in-between creatures
  drawn by generate.py `ape_morph(t, scale)` (every body part's shape interpolated, arms/fists sprout, feathers and
  collar retract, colours switch in stages, growing; both ends' details ride their parts: Wukong's fringe, wraps, sash
  fade out, the ape's toes, thumbs, knuckles, nostrils come in; the gold armour cracks and breaks away in chunks
  (`APE_ARMOUR_BREAKS`) and red rises up his face from the chin, dithered), the ape; drawn at the normal sprite scale while the real
  sprite is hidden; his storm clouds live in the sheets, no cloud is drawn over him),
  and morphs back when it ends. These and the Smoke Bomb cloud are pixel-art strips generated into `assets/fx/`
  (generate.py `FX`: poof / poof_small 20 frames (swell with a swirl, shadow layer, then burst into wisps and sparkles), wukong_ape_morph, smoke 12-frame loop (edge highlights, inner billows, swirls, rising wisps; swells in and fades out in `SpecialFx`); `Canvas(size)`
  now takes any size). `Effects` is pixel art too: explosions play `blast` (fireball → smoke + embers), melee slams `slam` (dust ring + floor cracks; `exploded(..., slam)`), sword swings `slash` (crescent smear tinted to the weapon), all sized to the radius / reach; beams and particles are hard-edged, snapped to art pixels and shrink instead of fading. Preview all effects: `tools/fx_preview.gd`. Bullets are per-weapon pixel art (`WeaponData.projectile_sprite`, generate.py `PROJECTILES` → `assets/sprites/projectiles/`: energy bolts, lead pellets, sniper tracer, rocket with flickering exhaust, rolling grenade, kunai, brass round, plasma), rotated to the flight direction with a 2-frame flicker and a pixel trail; crits are drawn x1.35, flash and leave gold sparkles; wall hits pop as four pixel sparks. Not done: bots don't prefer usable pickups; the HUD doesn't say why a pickup was refused.
- **One weapon + 2 specials** (2026-10-31): replaces the 2-slot loadout, swap button, and weapon/energy pickups
  (`Loadout`, `PickupField` deleted; map `W`/`E` chars are ignored). Each fighter fights with ONE weapon picked in the
  loading room from `Arena.weapons_for(c)` (signature first, then tag-usable shared weapons; `select_weapon` validates).
  Every carried weapon costs energy per shot (~100 × fire_interval: kunai 42, SMG 8, sniper 110...; form/volley
  weapons free) and energy refills at `ENERGY_REGEN_PER_SEC` 60 (`PlayerStats.energy_accum`, in snapshots).
  `Player.skills` holds `SKILL_SLOTS` = 2 specials: slot 0 on the skill button (Space, InputFrame `skill`), slot 1 on
  the special button (E, `special`). Defaults: Dash + the signature special. Dash and Barrier are generic specials
  (`special = true`, no tags). `select_special(p, slot, id)` / `rpc_select_special(slot, id)`; `set_skill` swaps if the
  other slot already has it; `active_skill(kind)` finds the running TRANSFORM / CLONES / SMOKE / DASH. Loading room:
  pick 2 specials (badges 1/2, a new pick replaces the least recently set slot). Bots fight with their signature.
  `--special ID` sets slot 1. Energy numbers are a first guess, untested in real matches.
- **Blossom Ward** (2026-10-31, Sakura special, `blossom_ward`, kind WARD = 10): 3 s ring of petals (radius
  `ward_radius` 69 px, cooldown 10 s) that follows her and catches enemy projectiles; her own shots, beams and melee
  pass. Reuses Barrier's path: a second `ShieldWall` (`is_ward`: a circle on LAYER_SHIELDS, a child of the Player so it
  moves with her, also for interpolated remote players) that `ProjectilePool` rays stop on, on server and client alike;
  shots that reach her inside the ring (fired from within it, or the ring moved onto them) are caught too
  (`Player.ward()`). Caught shots pop without their blast (rockets fizzle) and emit `ShieldWall.caught` → a petal pop
  (`SpecialFx.petal_pop`, every peer). Art (generate.py `blossom_ward*`, `petal_pop`, `icon_blossom_ward`): period-4
  ring loop (16 orbiting petals that wobble and turn over pink/white, an inner band turning the other way, drifters
  peeling off; seamless because petal i's look is a function of 4i + k), 8-frame opening bloom, 8-frame scatter on end.
- **Vine Swing** (2026-10-31, Apex special, `vine_swing`, kind SWING = 7): swings along the aim to the farthest spot up
  to `swing_range` 360 px where a player fits on the floor (`Player.swing_landing`: circle queries on `LAYER_WALL_FEET`
  every `SWING_SAMPLE_STEP` 8 px from full range inwards, inside `Player.arena_bounds` = `Arena.play_area()`), over any
  walls/crates in between; nothing past `swing_min_range` 80 px = no swing, no cooldown. 0.5 s in the air (position =
  `anchor + direction * swing_progress()`, a cosine ease; `direction` holds the whole takeoff→landing vector so both
  ends are in the snapshot; no move_and_slide, no other special meanwhile), i-frames only at takeoff (0.15 s), no
  damage, cooldown 7 s. `SpecialFx` hides his sprite and draws the swing pose (generate.py `wukong_swing_frame`: fist up
  on the vine, knees tucked, tail curled, body pivoting on the fist) raised along the arc, hanging from a pixel vine
  (`vine`, cropped to length, never stretched) whose leafy clump (`vine_top`) sits above the arc's midpoint; leaf burst
  at takeoff, dust puff on landing, then the vine swings on and pulls up. Progress is read from the drawn position on
  the takeoff→landing line, so interpolated remote players stay in step.
- **Eruption** (2026-10-31, Flint special, `eruption`, kind ERUPTION = 9): marks a floor spot 260 px ahead along the
  aim (from the feet, so standing under a wall can't put it beyond; pulled back 8 px off the first `LAYER_WALLS` hit:
  `Player.eruption_spot`, stored in the synced `anchor`); after a 0.6 s telegraph (`duration`) a pillar of fire goes off
  there: `eruption_blast` (`WeaponData.blast`: a splash "shot" that goes off where it's fired, 40 dmg, 80 px, falloff to
  0.4, needs sight, no self-damage, 300 knockback away from the spot, so up-ish) through `fire_shot` / `shot_fired` with
  seq + `ERUPTION_SEQ_OFFSET`; replay fires nothing; cooldown 8 s. `exploded(..., art)` is false for blasts (the pillar is
  the art; sound, sparks, shake stay). Art (volcano, reworked 2026-10-31; generate.py `eruption_crack` = 8-frame telegraph loop at 12 fps: cracked scorched floor, a rocky mound with lava pulsing in its cracks, hopping rocks, dust, ring of embers at the blast's reach; `eruption` = 26-frame 256 px strip at 15 fps (`ERUPTION_FPS`, 1.73 s) started `ERUPTION_LEAD` (4 frames) before the blast: the mound heaves and splits, then a volcanic cone bursts into a ~125 px fountain of lava and fire (`fire_column`, Flint's flowing bonfire tongues), dust ring, lava bombs arcing out and splatting, a dark ash plume, a magma pool; then it cools: cone crumbles, lava darkens to crust, embers fade, smoke drifts off. Heights/timings are the `FIRE_H`/`ERUPT_*` constants; `icon_eruption`; `flame_tongue()` is Flint's tongue helper), played by `SpecialFx` from synced state.
- **Blossom Snare** (2026-10-31, Sakura special, `blossom_snare`, kind SNARE = 13): throws one big spinning blossom along the
  aim (`blossom_snare` weapon via `volley_weapon`, seq + `VOLLEY_SEQ_OFFSET`, 650 px/s, 640 px range, radius 9); the first
  enemy hit takes 10 dmg and is snared: move speed x0.45 for 2 s (`WeaponData.snare_time/snare_factor`, applied in
  `ProjectilePool._damage_player` on the authority only; own shots never hit their owner). Cooldown 9 s. Minimal slow status:
  `PlayerStats.slow_remaining/slow_factor` (one at a time, a new snare refreshes it, ticks down in `stats.tick`, cleared by
  `reset()` on respawn, multiplies speed in `Player.simulate`; dash isn't slowed), synced as `StateField.SLOW_REMAINING/FACTOR`
  and covered by the replay test. `SpecialFx` draws, from the synced slow state on every peer, a petal burst when it jumps up
  and looping pink vines round the victim's feet while it lasts. Art (generate.py `blossom_shot` 4-frame projectile (the pool now
  reads any frame count from the strip), `snare_vines` period 4, `snare_burst` 8 frames, `icon_blossom_snare`).
- **Staff Whirl** (2026-10-31, Apex special, `staff_whirl`, kind WHIRL = 11): spins the Cloud Staff round him for
  `duration` 1.5 s (cooldown 9 s): every `whirl_interval` 0.25 s (first tick on the press; `CharacterSkill.whirl_tick_due`
  from the synced active time, no new synced field) enemies and crates within `whirl_radius` 70 px with line of sight take
  `whirl_damage` 8, pushed outward `whirl_knockback` 120; enemy projectiles touching the spin are sent back outward and
  become his (`ProjectilePool.whirl`, same attacker swap as the Arc Blade); he moves at `whirl_speed_scale` 0.75 and
  can't fire. Only the authoritative pool damages and replay does nothing (`Player._whirl`, key seq + `WHIRL_SEQ_OFFSET`);
  reflection runs on the owner's own peer only (remote players on clients are interpolated, not simulated), the server's
  hit events stay the truth. Art (generate.py `wukong_whirl_frame`, `whirl_ring_frame`, `whirl_spark_frame`,
  `icon_staff_whirl`): 8-frame spin pose (staff a blur with ghosts, body twisting, circlet tails flying), 8-frame loop
  ring of motion arcs and dust puffs, 5-frame sparks off the rim on each tick; `SpecialFx` hides his sprite + held staff
  meanwhile and draws them from synced state.
- **Blaze Run** (2026-10-31, Flint special, `blaze_run`, kind TRAIL = 12): dashes 300 px (`trail_distance`) along the aim in
  0.3 s (`trail_dash_time`) and leaves a trail of fire from the takeoff point to where he ended up. Both ends are
  fixed at activation (`Player._activate` measures the run with a test-only `move_and_collide`, so walls stop it) and
  live in the synced skill state like Vine Swing: `anchor` = takeoff, `direction` = the whole takeoff->end vector;
  the dash is `anchor + direction * trail_progress()` (no move_and_slide meanwhile). The trail burns for `duration` 3 s
  (cooldown 8 s): every `trail_tick` 0.3 s (derived from the skill's elapsed time, `Player._burn_trail`)
  `ProjectilePool.burn_segment` hits every other player within `trail_radius` 22 px of the segment for `trail_damage` 6
  (authoritative only, replay does nothing, no self-damage, no i-frames, no knockback; keyed `seq + TRAIL_SEQ_OFFSET`).
  Art (generate.py `blaze_*`, `icon_blaze_run`, reworked 2026-10-31): no ground band (round blobs read as odd circles
  where no flame sat on them). The flames are the trail (`blaze_run_flames`: 4 cluster variants x 4 loop frames + 4 die-out
  frames, each with a small flat ragged scorch mark baked in under it, shrinking with the flame), placed by
  `SpecialFx._draw_blaze` from a deterministic per-run hash (close on horizontal runs, wider/offset on vertical, sorted by y)
  and joined by a thin jagged ember line plotted in art pixels (`_draw_blaze_line`: 1-2 px, hot spots running along it, loose
  sparks, charred pixel under it; cools ORANGE, RED, dark cracks, dithered away after the flames), plus an 8-frame ignition
  at takeoff and a flame streak behind him while he dashes. Preview: `tools/blaze_preview.gd` (runs in set directions).
- **Petal Drift** (2026-10-31, Sakura special, `petal_drift`, kind DRIFT = 15): she dissolves into petals for `duration` 0.8 s
  (cooldown 7 s) and glides at `drift_speed_scale` 1.6 x her speed along the stick (else the direction fixed at the press:
  move, else aim), steerable, through the normal `move_and_slide` path (walls stop her). `try_activate` gives i-frames for
  the whole duration (`stats.invulnerable_time`), `Player.is_hidden()` is true meanwhile (enemy auto-aim and bots skip her,
  like smoke) and she can't fire; no new synced state (active time + direction in the skill snapshot). `SpecialFx` hides her
  sprite + weapon (`is_petals()`): 8-frame dissolve (her idle frame breaking into petals, generate.py `drift_dissolve_frame`),
  swirl loop (`drift_swirl_frame`, period 8, mirrored and tilted with her velocity, petals streaming behind), reform strip
  (the dissolve backwards + sparkles) and a petal burst (`petal_pop`) as she gathers; `icon_petal_drift`.
- **Sky Pillar** (2026-10-31, Apex special, `sky_pillar`, kind PILLAR = 14): he plants the Cloud Staff and it shoots out along
  the aim; after `pillar_windup` 0.25 s (he can't move or fire) it slams down on a line `pillar_length` 320 px x `pillar_width`
  36 px: every other player whose centre is within half the width of it takes `pillar_damage` 30 and is thrown
  `pillar_knockback` 260 sideways (away from the line), and crates on it take the damage too. Cooldown 8 s, `duration` 0.75 s
  (the whole animation). The line is fixed at activation (`Player._activate`: ray on `LAYER_WALLS` from his centre, so the first
  wall or crate shortens it) and stored in the synced skill state like Blaze Run (`anchor` = start, `direction` = the whole
  vector). The hit lands in the step the active time crosses the windup (`CharacterSkill.pillar_slammed`), authoritative only,
  replay does nothing: `ProjectilePool.line_hit` (= `burn_segment`, which gained a `knockback` arg, + a rectangle query for
  crates), keyed `seq + PILLAR_SEQ_OFFSET` (1 << 28). Art (generate.py `wukong_pillar_frame` 6-frame plant/thrust pose,
  `sky_pillar_frame` 12 frames of 228x64 art px (a gold-banded red staff growing from his hand, lifted, slamming flat with a flash,
  dust and floor cracks along the line, then shrinking away), `icon_sky_pillar`): `SpecialFx` draws the pillar rotated along the
  line and cropped (never stretched) to its length, with his pose over it (his sprite and held staff hidden meanwhile).
- **Flare Burst** (2026-10-31, Flint special, `flare_burst`, kind NOVA = 17): he flares up for `nova_charge` 0.25 s (can't move or
  fire: `Player` roots him like the Sky Pillar windup), then `nova_blast` (`flare_burst_blast.tres`, a `blast` weapon with the new
  `WeaponData.destroys_shots`) goes off on him: every other player within 120 px with line of sight takes 25 (no falloff) and is
  thrown 420 away from him, and enemy projectiles in range are destroyed (`ProjectilePool._destroy_shots`, run by `fire_shot` on
  every peer so cosmetic copies vanish too). Goes through `fire_shot` / `shot_fired` with seq + `NOVA_SEQ_OFFSET` (1 << 30) in the
  step the active time crosses the charge (`CharacterSkill.nova_burst`); authoritative only, replay does nothing. Cooldown 9 s,
  `duration` 0.4 s. Art (generate.py `flint_flare_frame` 6-frame charge pose = his idle with heat rising and a white-hot heart,
  `flare_ring_frame` 12 frames of 192 px: flash, a ring of flame tongues racing out along the floor over a scorched band, then
  embers and smoke, `icon_flare_burst`): `SpecialFx` hides his sprite and draws the charge pose, then plays the ring as a poof at
  his feet scaled to the blast radius.
  Sakura's **Cherry Sapling** (`SkillData.Kind.SAPLING = 18`, `cherry_sapling.tres`, 12 s cooldown, 6 s tree): plants a tree at her
  feet (`anchor`, no new synced state); every `sapling_interval` (0.5 s, `CharacterSkill.sapling_shot_due`) `Player._sapling_shoot`
  fires `cherry_petal` (5 dmg) from the canopy at the nearest visible enemy within 360 px (shadow clones count, smoked/dead skipped,
  ties go to the earlier player; wall line-of-sight checked), keyed `seq + SAPLING_SEQ_OFFSET` (1 << 22) and relayed via
  `shot_fired`. Authoritative/non-replay only; the tree isn't hittable and `_die` ends it. Art (generate.py `SAPLING_*`): 64 px
  square strips `sapling_grow` (8) / `sapling_idle` (4, loop) / `sapling_fire` (4) / `sapling_wilt` (8) + `icon_cherry_sapling`;
  `SpecialFx._draw_sapling` picks the strip from the synced skill time (grow first, wilt over the last 0.67 s; the firing flourish
  plays when a shot falls due, even if nothing was in range).
- **Storm Cloud** (2026-10-31, Apex special, `storm_cloud`, kind STORM = 16): summons a dark thundercloud at a spot
  `storm_distance` 240 px ahead along the aim (`Player.storm_spot` = `spot_ahead`, the same wall-shortened ray as
  `eruption_spot`; stored in the synced `anchor`). For `duration` 3.1 s (cooldown 10 s) every `storm_interval` 0.6 s (the first
  one interval after the press; `CharacterSkill.storm_tick_due(before)` from the synced active time, no new synced field,
  the last step counts) `ProjectilePool.strike` hits every other player within `storm_radius` 90 px of the spot with line of
  sight from it for `storm_damage` 12, pushed `storm_knockback` 80 away from the spot, no stun. Authoritative only, replay
  does nothing, no self-damage, keyed `seq + STORM_SEQ_OFFSET` (1 << 29); blurb "Lightning cloud" (<= 20 chars: the loading-room row
  cuts longer ones). Art (generate.py `storm_*`, `icon_storm_cloud`): `storm_cloud` period-8 loop (navy-grey lumps churning,
  gold light flickering inside, rain streaks, dithered floor shadow), `storm_cloud_form` / `storm_cloud_end` 8 frames, `storm_bolt`
  5-frame bolt strip (36x144 art px, bottom-anchored and cropped to length), `storm_spark` 6-frame flash + scorch. `SpecialFx._sync_storm`
  draws all of it from the synced active time on every peer: a bolt per tick at each enemy within the radius on the local view
  (else at the cloud's spot).
- **Apex FX polish** (2026-10-31, art only): Vine Swing pose 12 frames (vine wrap + leaf on the fist, streaming tails, wind streaks), `leaf_burst` 14 / `swing_dust` 12, lit knotted `vine` with berries; Staff Whirl pose + `whirl_ring` 12-frame loops (`WHIRL_FPS` 24), shaded staff with dithered motion-blur wedge, `whirl_spark` 7; Sky Pillar `wukong_pillar` 9 poses, `sky_pillar` 18 frames (slam on frame 6 = u 1/3), shock ring, glowing cracks, flying chips; Storm Cloud merged lit/shaded cloud mass, 12-frame loop (`STORM_LOOP`, `STORM_FPS` 15), gold flashes inside, 8-frame bolt with forks, 8-frame spark. `SpecialFx._strike` only draws a bolt on enemies in line of sight of the cloud (same rule as the damage), so bolts no longer fall on players a wall shields.
- [~] **M5 – iOS build + cloud server: local half done, blocked on accounts/hosting** (2026-10-30)
  - Done: `export_presets.cfg` with "Linux Server x86_64"/"Linux Server arm64" (dedicated-server exports, tests
    and GUT excluded) and "iOS" (bundle `com.nabot.brawlbit`, landscape, Xcode project only).
    `server/Dockerfile` (debian-slim, non-root, UDP 7777, extra args pass through) + `server/build.sh`.
    Verified: container on Docker Desktop (arm64) ran a full match with 2 autopilot clients + 1 bot, no errors.
    iOS: enabled ETC2/ASTC (required for mobile export); with a placeholder team ID the export produces an
    Xcode project that compiles (`BUILD SUCCEEDED`, unsigned). App icon (`assets/icon.png`, 1024 px, no alpha)
    generated from the Flicker sprite by `tools/sprites/generate.py`.
  - Still needed: Apple Team ID (+ signing) → archive + TestFlight upload; a cloud host with a public UDP port;
    a default server address in the client (currently join-by-IP in the menu); test on a real device over the internet.
- **LAN host** (2026-10-31): main-menu HOST button / `--host` makes the device a listen server: the same `NetServer` as `--server`
  (Arena.Mode.SERVER) plus the host plays as peer `NetSession.HOST_ID` (1, the server's own id) through a `LocalInput` + local view,
  exactly like offline, so no second client/peer; clients see the host as a normal remote player. `Arena.host_address`
  ("192.168.x.x:7777", `LanAddress.local()` = first private IPv4 from `IP.get_local_addresses()`) shows in the loading room header.
  Pause-menu Leave as host -> `Main._on_host_leave`: `session.stop()` closes the ENet peer (clients get the normal "Disconnected from
  server") and returns to the menu. iOS Info.plist `NSLocalNetworkUsageDescription` set via `application/additional_plist_content`
  in export_presets.cfg. Limits: LAN only (no NAT traversal), no Bonjour discovery (type the IP), host's sim and render share one
  device. Leave buttons in the loading room and results panel (same `leave_requested` path as the pause menu).
- [ ] M6 not started
- **Sakura FX polish** (2026-10-31): Blossom Ward / Snare / Petal Drift / Cherry Sapling strips doubled in frames at the
  same durations (ward loop 8 + open/close 12, snare vines 8 + burst 12, drift dissolve/reform/swirl 16, sapling grow/wilt
  16 + idle/fire 8; `SpecialFx` *_FPS constants doubled to match). `ward_petal` now has a crease and a sheen (also in the
  snare projectile and drift icon); Petal Drift dissolves along a spiral into the swirl's own petal slots.
- **Flint FX polish** (2026-10-31, art + `SpecialFx` constants only, no gameplay numbers): shared fire-spark helpers in generate.py
  (`ember_spark` / `spark_cloud`: 1-2 px white/yellow heads cooling to orange/red with trails, drawn on a canvas AFTER `outline()`
  via `finish()`, so they stay bright and clear of the frame-edge check). Flare Burst: `flint_flare` 10 frames (halo + embers streaming
  into the white-hot heart), `flare_ring` 30 frames (uneven wall: `flare_tongues()` varies spacing, height, width, lean, when each
  catches/burns out, plus a low flame bed and tip embers; spark spray); Blaze Run: flame loops 16 (`BLAZE_FLAME_LOOP`, FPS 40, dies 10),
  streak 16 (FPS 48), ignite 20, small licks leaning on the tall tongues, sparks; Eruption: telegraph `eruption_crack` 16 frames
  (`CRACK_FPS` 24, firelight halo, sparks off the cracks), `eruption` 39 frames at `ERUPTION_FPS` 22.5 (burst on frame 6), a fine
  spark spray off the fountain, glowing embers with trails, lava glow on the floor; Supernova (VOLLEY, no charge since its duration is
  0.1 s) gets `supernova_burst` (16 frames: embers rush in, white core, ring of 16 flame spokes + sparks) played by `SpecialFx` as a
  poof on the rising edge of the slot (`_slot_id`); Inferno: `flint_inferno_aura` (flames licking up beside him + sparks, period 4) on
  the form sheet, morph 24 frames (flames build, spark burst at the end).

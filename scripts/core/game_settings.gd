class_name GameSettings
extends RefCounted
## Player preferences, saved to user://settings.cfg: music + SFX volume (0..1), haptics, and whether the
## first-launch controls overlay has been shown. Static so Sfx, Music and the UI all read one copy.

const PATH: String = "user://settings.cfg"
const SILENT_DB: float = -80.0

static var music: float = 0.7
static var sfx: float = 1.0
static var haptics: bool = true
## Auto-aim at the nearest enemy when not dragging. Off = shoot along the last manual aim / facing (the skill-based option).
static var aim_assist: bool = true
static var howto_seen: bool = false
## The first-launch Training match was finished or skipped (Play then goes straight to a normal match).
static var tutorial_done: bool = false
## The game mode picked on the home screen (a `MatchRules.Mode`), kept between launches.
static var mode: MatchRules.Mode = MatchRules.Mode.FFA
static var _loaded: bool = false


static func ensure_loaded() -> void:
	if not _loaded:
		load_from(PATH)


## Missing file or keys keep the defaults; values are clamped so a hand-edited file can't break audio.
static func load_from(path: String) -> void:
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	music = clampf(float(cfg.get_value("audio", "music", music)), 0.0, 1.0)
	sfx = clampf(float(cfg.get_value("audio", "sfx", sfx)), 0.0, 1.0)
	haptics = bool(cfg.get_value("input", "haptics", haptics))
	aim_assist = bool(cfg.get_value("input", "aim_assist", aim_assist))
	howto_seen = bool(cfg.get_value("ui", "howto_seen", howto_seen))
	tutorial_done = bool(cfg.get_value("ui", "tutorial_done", tutorial_done))
	mode = clampi(int(cfg.get_value("ui", "mode", mode)), 0, MatchRules.Mode.size() - 1) as MatchRules.Mode


static func save_to(path: String) -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("input", "haptics", haptics)
	cfg.set_value("input", "aim_assist", aim_assist)
	cfg.set_value("ui", "howto_seen", howto_seen)
	cfg.set_value("ui", "tutorial_done", tutorial_done)
	cfg.set_value("ui", "mode", mode)
	return cfg.save(path)


static func save() -> void:
	if save_to(PATH) != OK:
		push_warning("Could not save settings")


## Slider position (0..1) to decibels; 0 is silent.
static func to_db(volume: float) -> float:
	return SILENT_DB if volume <= 0.001 else maxf(linear_to_db(volume), SILENT_DB)


static func vibrate(ms: int) -> void:
	ensure_loaded()
	if haptics:
		Input.vibrate_handheld(ms)

class_name Sfx
extends Node
## Placeholder sound effects, synthesized at startup from the small recipe table below
## (tone sweep + filtered noise + envelope), so there are no audio assets to license.
## Played through a round-robin pool of players; volume falls off with distance from the
## local player.

const SAMPLE_RATE: int = 22050
const VOICES: int = 12
const FALLOFF_DISTANCE: float = 900.0
const FALLOFF_DB: float = -24.0
const PITCH_JITTER: float = 0.06
const MASTER_DB: float = -6.0

enum Wave { SINE, SQUARE, SAW, NOISE }
## Recipe fields: duration s, start Hz, end Hz, wave, noise mix 0..1, noise smoothing 0..1
## (higher = duller), attack s, decay rate (1/s), volume 0..1.
enum R { DURATION, F_START, F_END, WAVE, NOISE, NOISE_SMOOTH, ATTACK, DECAY, VOLUME }

const RECIPES: Dictionary[StringName, Array] = {
	&"shot_light": [0.09, 900.0, 300.0, Wave.SQUARE, 0.35, 0.3, 0.002, 38.0, 0.35],
	&"shot_heavy": [0.25, 220.0, 60.0, Wave.SAW, 0.7, 0.6, 0.002, 14.0, 0.6],
	&"shot_sniper": [0.35, 1400.0, 120.0, Wave.SAW, 0.5, 0.2, 0.001, 10.0, 0.55],
	&"shot_rocket": [0.4, 160.0, 90.0, Wave.SAW, 0.8, 0.8, 0.01, 6.0, 0.5],
	&"shot_launcher": [0.16, 300.0, 140.0, Wave.SINE, 0.4, 0.7, 0.002, 18.0, 0.5],
	&"laser": [0.08, 1800.0, 1500.0, Wave.SINE, 0.05, 0.1, 0.002, 20.0, 0.22],
	&"swing": [0.16, 500.0, 200.0, Wave.NOISE, 1.0, 0.45, 0.02, 16.0, 0.45],
	&"explosion": [0.7, 90.0, 30.0, Wave.SINE, 0.85, 0.85, 0.003, 5.0, 0.9],
	&"hit": [0.06, 1200.0, 700.0, Wave.SQUARE, 0.3, 0.2, 0.001, 50.0, 0.3],
	&"crit": [0.12, 1800.0, 900.0, Wave.SQUARE, 0.2, 0.1, 0.001, 22.0, 0.4],
	&"hurt": [0.15, 260.0, 120.0, Wave.SQUARE, 0.4, 0.5, 0.002, 18.0, 0.5],
	&"death": [0.5, 400.0, 60.0, Wave.SAW, 0.5, 0.6, 0.002, 6.0, 0.55],
	&"pickup": [0.18, 600.0, 1400.0, Wave.SINE, 0.0, 0.0, 0.004, 12.0, 0.4],
	&"crate": [0.3, 140.0, 70.0, Wave.NOISE, 1.0, 0.75, 0.002, 12.0, 0.6],
	&"dash": [0.14, 300.0, 900.0, Wave.NOISE, 0.9, 0.3, 0.01, 18.0, 0.35],
	&"shield": [0.35, 220.0, 440.0, Wave.SINE, 0.15, 0.5, 0.02, 7.0, 0.45],
	&"dual": [0.3, 440.0, 880.0, Wave.SQUARE, 0.1, 0.3, 0.01, 8.0, 0.35],
	&"transform": [0.6, 110.0, 55.0, Wave.SAW, 0.6, 0.7, 0.02, 4.0, 0.6],
	&"countdown": [0.12, 660.0, 660.0, Wave.SQUARE, 0.0, 0.0, 0.003, 16.0, 0.35],
	&"go": [0.4, 880.0, 1320.0, Wave.SQUARE, 0.0, 0.0, 0.003, 6.0, 0.4],
	&"results": [0.6, 520.0, 780.0, Wave.SINE, 0.0, 0.0, 0.01, 4.0, 0.4],
}

var listener: Node2D

var _streams: Dictionary[StringName, AudioStreamWAV] = {}
var _voices: Array[AudioStreamPlayer] = []
var _next: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	for id: StringName in RECIPES:
		_streams[id] = synthesize(RECIPES[id], _rng)
	for i: int in VOICES:
		var v := AudioStreamPlayer.new()
		add_child(v)
		_voices.append(v)


## Plays `id`, quieter the farther `at` is from the listener. INF = non-positional.
func play(id: StringName, at: Vector2 = Vector2.INF) -> void:
	var stream: AudioStreamWAV = _streams.get(id)
	if stream == null:
		return
	var db: float = MASTER_DB
	if at != Vector2.INF and listener != null and is_instance_valid(listener):
		var d: float = listener.global_position.distance_to(at)
		if d > FALLOFF_DISTANCE:
			return
		db += FALLOFF_DB * d / FALLOFF_DISTANCE
	var v: AudioStreamPlayer = _voices[_next]
	_next = (_next + 1) % _voices.size()
	v.stream = stream
	v.volume_db = db
	v.pitch_scale = 1.0 + _rng.randf_range(-PITCH_JITTER, PITCH_JITTER)
	v.play()


static func synthesize(r: Array, rng: RandomNumberGenerator) -> AudioStreamWAV:
	var duration: float = r[R.DURATION]
	var samples: int = int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase: float = 0.0
	var noise: float = 0.0
	var wave: Wave = r[R.WAVE]
	for i: int in samples:
		var t: float = float(i) / SAMPLE_RATE
		var k: float = t / duration
		# Exponential sweep sounds natural for pitch drops.
		var freq: float = r[R.F_START] * pow(r[R.F_END] / r[R.F_START], k)
		phase = fmod(phase + freq / SAMPLE_RATE, 1.0)
		var tone: float
		match wave:
			Wave.SINE:
				tone = sin(phase * TAU)
			Wave.SQUARE:
				tone = 1.0 if phase < 0.5 else -1.0
			Wave.SAW:
				tone = phase * 2.0 - 1.0
			_:
				tone = 0.0
		noise = lerpf(rng.randf_range(-1.0, 1.0), noise, r[R.NOISE_SMOOTH])
		var mix: float = 1.0 if wave == Wave.NOISE else r[R.NOISE]
		var env: float = minf(1.0, t / r[R.ATTACK]) * exp(-t * r[R.DECAY])
		var v: float = (tone * (1.0 - mix) + noise * mix) * env * r[R.VOLUME]
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav

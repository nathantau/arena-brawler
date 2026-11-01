class_name Music
extends AudioStreamPlayer
## Background loop, synthesized once at startup (no audio assets): a soft kick, a bass line and a plucked
## arpeggio over Am - F - C - G. Volume follows GameSettings.music; keeps playing while the tree is paused.

const SAMPLE_RATE: int = 11025
const BPM: float = 104.0
const BASE_DB: float = -14.0
## Chord roots (Hz) and their triad intervals in semitones; one chord per bar of 4 beats.
const ROOTS: Array[float] = [110.0, 87.31, 130.81, 98.0]
const TRIAD: Array[int] = [0, 7, 12, 16, 12, 7]
const MINOR_THIRD_ROOT: int = 0  # the first chord (Am) uses a minor third in the arpeggio


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"music")
	stream = synthesize()
	apply_volume()
	if GameSettings.music > 0.0:
		play()


func apply_volume() -> void:
	volume_db = BASE_DB + GameSettings.to_db(GameSettings.music)
	if GameSettings.music <= 0.0:
		stop()
	elif not playing and stream != null and is_inside_tree():
		play()


static func synthesize() -> AudioStreamWAV:
	var beat: float = 60.0 / BPM
	var bar: float = beat * 4.0
	var total: int = int(bar * ROOTS.size() * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(total * 2)
	var bass_phase: float = 0.0
	var arp_phase: float = 0.0
	for i: int in total:
		var t: float = float(i) / SAMPLE_RATE
		var chord: int = int(t / bar) % ROOTS.size()
		var root: float = ROOTS[chord]
		var in_beat: float = fmod(t, beat)
		# Kick on every beat: a falling sine.
		var kick: float = sin(TAU * (45.0 * in_beat + 75.0 * (1.0 - exp(-in_beat * 25.0)) / 25.0)) * exp(-in_beat * 18.0) * 0.5
		# Bass: root an octave down, square-ish, on every half beat with a short decay.
		var in_half: float = fmod(t, beat * 0.5)
		bass_phase = fmod(bass_phase + root * 0.5 / SAMPLE_RATE, 1.0)
		var bass: float = (1.0 if bass_phase < 0.5 else -1.0) * exp(-in_half * 7.0) * 0.16
		# Arpeggio: eighth notes up the triad, sine pluck.
		var step: int = int(t / (beat * 0.5)) % TRIAD.size()
		var semis: int = TRIAD[step]
		if semis == 16 and chord == MINOR_THIRD_ROOT:
			semis = 15
		var f: float = root * 2.0 * pow(2.0, semis / 12.0)
		arp_phase = fmod(arp_phase + f / SAMPLE_RATE, 1.0)
		var arp: float = sin(arp_phase * TAU) * exp(-in_half * 9.0) * 0.18
		var v: float = clampf(kick + bass + arp, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32767.0 * 0.8))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = total
	return wav

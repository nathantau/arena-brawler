class_name TutorialFlow
extends RefCounted
## The Training match's step state machine (pure logic, no nodes): move, shoot, ability, ultimate, defeat the bot, done.
## Each step advances when the player really does the action (fed by `TutorialOverlay`); `skip()` and `finish()` both
## mark `GameSettings.tutorial_done` (the overlay saves it) and emit `finished`.

signal step_changed(step: Step)
signal finished(skipped: bool)

enum Step { MOVE, SHOOT, ABILITY, ULTIMATE, DEFEAT, DONE }

## Joystick travel needed for the first step, in world px.
const MOVE_GOAL: float = 150.0
## Hits the player must land on the bot in the shoot step.
const HIT_GOAL: int = 3
## Slots 0 and 1 are the ability step; slot 2 is the ultimate.
const ULTIMATE_SLOT: int = 2
## Difficulty of the single training bot (`BotBrain.skill`) and the hp the player can never be hit below.
const BOT_SKILL: float = 0.15
const MIN_HP: int = 1

const PROMPTS: Array[String] = [
	"Drag the left stick to move",
	"Tap FIRE: it aims for you. Hit the bot 3 times",
	"Use an ability: press a round button",
	"Your ultimate charges over time and from damage. When it glows, use it!",
	"Defeat the bot!",
	"You're ready!",
]
## Same steps for a desktop keyboard (no touch controls).
const PROMPTS_KEYS: Array[String] = [
	"Move with W A S D",
	"Hold J or click to fire: it aims for you. Hit the bot 3 times",
	"Use an ability: Space or E",
	"Your ultimate charges over time and from damage. When it glows, press Q!",
	"Defeat the bot!",
	"You're ready!",
]

var step: Step = Step.MOVE
var travelled: float = 0.0
var hits: int = 0
var skipped: bool = false
var is_finished: bool = false


static func prompt(s: Step, touch: bool) -> String:
	return (PROMPTS if touch else PROMPTS_KEYS)[s]


## "80 / 150 px" style progress for the steps that count something, else "".
func progress_text() -> String:
	match step:
		Step.MOVE:
			return "%d / %d" % [mini(roundi(travelled), roundi(MOVE_GOAL)), roundi(MOVE_GOAL)]
		Step.SHOOT:
			return "%d / %d hits" % [hits, HIT_GOAL]
	return ""


func add_travel(px: float) -> void:
	if step == Step.MOVE and px > 0.0:
		travelled += px
		if travelled >= MOVE_GOAL:
			_go(Step.SHOOT)


func add_hit() -> void:
	if step == Step.SHOOT:
		hits += 1
		if hits >= HIT_GOAL:
			_go(Step.ABILITY)


## The player pressed ability button `slot` (0..2).
func slot_pressed(slot: int) -> void:
	if step == Step.ABILITY and slot != ULTIMATE_SLOT:
		_go(Step.ULTIMATE)
	elif step == Step.ULTIMATE and slot == ULTIMATE_SLOT:
		_go(Step.DEFEAT)


func bot_defeated() -> void:
	if step == Step.DEFEAT:
		_go(Step.DONE)


## The Skip button, any time: leaves the tutorial and counts it as done.
func skip() -> void:
	if not is_finished:
		skipped = true
		_finish()


## The "back to menu" button on the last step.
func finish() -> void:
	if step == Step.DONE and not is_finished:
		_finish()


func _finish() -> void:
	is_finished = true
	GameSettings.tutorial_done = true
	finished.emit(skipped)


func _go(next: Step) -> void:
	if is_finished:
		return
	step = next
	step_changed.emit(next)

class_name InputSetup
extends RefCounted
## Registers keyboard/mouse actions for desktop dev play. Touch is handled by TouchControls.


static func ensure_actions() -> void:
	_add_keys(&"move_left", [KEY_A, KEY_LEFT])
	_add_keys(&"move_right", [KEY_D, KEY_RIGHT])
	_add_keys(&"move_up", [KEY_W, KEY_UP])
	_add_keys(&"move_down", [KEY_S, KEY_DOWN])
	_add_keys(&"fire_auto", [KEY_J, KEY_K])
	_add_keys(&"skill", [KEY_SPACE, KEY_SHIFT])
	_add_keys(&"swap", [KEY_Q, KEY_TAB])
	_add_keys(&"dev_cycle_weapon", [KEY_R])
	_add_mouse(&"fire_mouse", MOUSE_BUTTON_LEFT)


static func _add_keys(action: StringName, keys: Array[Key]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key: Key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)


static func _add_mouse(action: StringName, button: MouseButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)

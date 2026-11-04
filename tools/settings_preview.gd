extends SceneTree
## Preview: the settings panel (with the "Enter code" row, before and after a wrong code) as PNGs. Needs a window; run it
## without stealing focus (override.cfg as in CLAUDE.md Commands):
##   open -g -W -n -a /Applications/Godot.app --args --path "$PWD" --log-file /tmp/settings.log -s tools/settings_preview.gd \
##       -- --touch out=/tmp/settings_preview
## Writes <out>/<W>x<H>_settings.png. Never touches the real profile or settings.

var out: String = "/tmp/settings_preview"


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=")
		if kv.size() == 2 and kv[0] == "out":
			out = kv[1]
	DirAccess.make_dir_recursive_absolute(out)
	UiStyle.install()
	UiStyle.install_scaling(root)
	PlayerProfile.path = "user://settings_preview.cfg"
	run.call_deferred()


func run() -> void:
	var panel := SettingsPanel.new()
	root.add_child(panel)
	for i: int in 10:
		await process_frame
	panel._code.text = "nope"
	panel._redeem()
	for i: int in 5:
		await process_frame
	var win: Vector2i = root.size
	root.get_viewport().get_texture().get_image().save_png("%s/%dx%d_settings.png" % [out, win.x, win.y])
	quit()

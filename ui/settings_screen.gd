extends Screen
# Buttons instead of a slider or switches: the default grabbers and toggles are too small to tap.

const STEP := 0.1


func _ready() -> void:
	super()
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	var col := VBoxContainer.new()
	add_child(col)
	col.add_child(Screen.heading("Settings"))

	col.add_child(Screen.label("Text size: %d%%" % roundi(Settings.text_scale * 100)))
	var sizes := HBoxContainer.new()
	col.add_child(sizes)
	var smaller := Screen.button("Smaller", _change_text.bind(-STEP))
	smaller.disabled = Settings.text_scale <= 1.0
	sizes.add_child(smaller)
	var bigger := Screen.button("Bigger", _change_text.bind(STEP))
	bigger.disabled = Settings.text_scale >= 2.0
	sizes.add_child(bigger)

	col.add_child(_toggle("High contrast", "high_contrast"))
	col.add_child(_toggle("Reduce motion", "reduce_motion"))
	col.add_child(_toggle("Sound", "sound"))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	col.add_child(Screen.button("Back", get_tree().change_scene_to_file.bind("res://ui/home.tscn"), "Ruby"))


func _toggle(title: String, key: String) -> Button:
	return Screen.button("%s: %s" % [title, "On" if Settings.get(key) else "Off"], func():
		Settings.set(key, not Settings.get(key))
		_apply(), "Gold" if Settings.get(key) else "")


func _change_text(delta: float) -> void:
	Settings.text_scale = snappedf(Settings.text_scale + delta, STEP)
	_apply()


func _apply() -> void:
	Settings.apply()
	# Rebuild so labels with explicit sizes and the button text pick up the new values.
	_build.call_deferred()

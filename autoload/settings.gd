extends Node
## Player settings shared by every game. Change a value, then call apply().

signal changed

const PATH := "user://settings.cfg"

var text_scale := 1.0  # 1.0 to 2.0; Apple asks for text that can grow to 200%
var high_contrast := false
var reduce_motion := false
var sound := true


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		text_scale = clampf(cfg.get_value("ui", "text_scale", 1.0), 1.0, 2.0)
		high_contrast = cfg.get_value("ui", "high_contrast", false)
		reduce_motion = cfg.get_value("ui", "reduce_motion", false)
		sound = cfg.get_value("audio", "sound", true)
	apply()


func apply() -> void:
	text_scale = clampf(text_scale, 1.0, 2.0)
	get_tree().root.theme = AppTheme.build(text_scale, high_contrast)
	RenderingServer.set_default_clear_color(AppTheme.BG_HC if high_contrast else AppTheme.FELT_EDGE)
	AudioServer.set_bus_mute(0, not sound)
	var cfg := ConfigFile.new()
	cfg.set_value("ui", "text_scale", text_scale)
	cfg.set_value("ui", "high_contrast", high_contrast)
	cfg.set_value("ui", "reduce_motion", reduce_motion)
	cfg.set_value("audio", "sound", sound)
	cfg.save(PATH)
	changed.emit()

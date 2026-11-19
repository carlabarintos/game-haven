extends Node
## Owns the Remove Ads state. Games and ad code only read ads_removed.
# shortcut: local flag only, no StoreKit yet; wire godot-iap here in Phase 4.

signal changed

const PATH := "user://purchases.cfg"

var ads_removed := false


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		ads_removed = cfg.get_value("iap", "ads_removed", false)


func set_ads_removed(value: bool) -> void:
	ads_removed = value
	var cfg := ConfigFile.new()
	cfg.set_value("iap", "ads_removed", value)
	cfg.save(PATH)
	changed.emit()

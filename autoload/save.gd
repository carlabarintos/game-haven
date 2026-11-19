extends Node
## Auto-save per game, so players can leave mid-game and resume with no penalty.

const DIR := "user://saves"


func store(game_id: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	# Write to a temp file then rename, so a crash mid-write can't corrupt the save.
	var tmp := _path(game_id) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Save failed for %s: %s" % [game_id, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(data))
	f.close()
	DirAccess.rename_absolute(tmp, _path(game_id))


## Returns {} when there is no save or it can't be read.
func load_game(game_id: String) -> Dictionary:
	if not FileAccess.file_exists(_path(game_id)):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(_path(game_id)))
	return parsed if parsed is Dictionary else {}


func clear(game_id: String) -> void:
	DirAccess.remove_absolute(_path(game_id))


func _path(game_id: String) -> String:
	return "%s/%s.json" % [DIR, game_id]

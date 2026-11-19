extends SceneTree
## Headless self-checks. Run: godot --headless --path . -s tests/run.gd


func _init() -> void:
	var save = preload("res://autoload/save.gd").new()
	save.store("_test", {score = 3, grid = [1, 2]})
	assert(save.load_game("_test") == {score = 3.0, grid = [1.0, 2.0]}, "save round trip")
	save.clear("_test")
	assert(save.load_game("_test") == {}, "cleared save loads empty")
	save.free()

	assert(AppTheme.build(1.0, false).default_font_size == 34, "base font")
	assert(AppTheme.build(2.0, true).default_font_size == 68, "200% font")

	for level in SudokuLogic.CLUES:
		var start := Time.get_ticks_msec()
		var g := SudokuLogic.generate(SudokuLogic.CLUES[level], 42)
		var clues: int = 81 - g.puzzle.count(0)
		print("Sudoku %s: %d clues in %d ms" % [level, clues, Time.get_ticks_msec() - start])
		for i in 81:
			assert(g.solution[i] in range(1, 10), "solution filled")
			assert(g.puzzle[i] in [0, g.solution[i]], "puzzle matches solution")
			for p in SudokuLogic.PEERS[i]:
				assert(g.solution[p] != g.solution[i], "solution obeys rules")
		assert(clues >= SudokuLogic.CLUES[level] and clues <= SudokuLogic.CLUES[level] + 6, "clue count")
		assert(SudokuLogic.count_solutions(g.puzzle) == 1, "unique solution")
	assert(SudokuLogic.PEERS[0].size() == 20 and SudokuLogic.PEERS[80].size() == 20, "peers")

	print("All checks passed")
	quit()

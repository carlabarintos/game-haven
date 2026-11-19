extends Screen
## Sudoku: tap a square, then tap a number. No timer; unlimited undo and hints; saves after every move.

const ID := "sudoku"
const HOME := "res://ui/home.tscn"
# Dark ink on ivory paper: the highest-contrast surface in the theme, so high contrast mode needs no change.
const INK := Color("2a1a00")
const PLAYER_INK := Color("1f3a93")
const WRONG := Color("b00020")
const PEER := Color("f3e3b0")
const SAME_DIGIT := Color("ecd07a")

var puzzle := []
var solution := []
var board := []
var history := []  # [square, previous digit] per move, for unlimited undo
var difficulty := ""
var selected := -1
var _board: Control


func _ready() -> void:
	super()
	var data := Save.load_game(ID)
	if data.has("board"):
		puzzle = _ints(data.puzzle)
		solution = _ints(data.solution)
		board = _ints(data.board)
		history = data.history.map(func(h): return [int(h[0]), int(h[1])])
		difficulty = data.difficulty
		_show_board()
	else:
		_show_menu()


## Doubles as the one-screen "how to play".
func _show_menu() -> void:
	var col := _clear()
	col.add_child(Screen.heading("Sudoku"))
	col.add_child(Screen.label("Fill every row, column and 3×3 box with the numbers 1 to 9, each used once.\n\nTap a square, then tap a number. A wrong number turns red and is underlined.\n\nThere is no timer. Take your time."))
	for d in [["Easy", "Gold"], ["Medium", "Sapphire"], ["Hard", "Ruby"]]:
		col.add_child(Screen.button(d[0], _start.bind(d[0]), d[1]))
	col.add_child(_spacer())
	col.add_child(Screen.button("Back", _show_board if board else _home, "Onyx"))


func _start(level: String) -> void:
	var g := SudokuLogic.generate(SudokuLogic.CLUES[level], randi())
	puzzle = g.puzzle
	solution = g.solution
	board = puzzle.duplicate()
	history = []
	difficulty = level
	selected = -1
	_save()
	_show_board()


func _show_board() -> void:
	var col := _clear()
	col.add_child(_row([["Menu", _home, "Onyx"], ["New puzzle", _show_menu, "Sapphire"]]))

	_board = Control.new()
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.custom_minimum_size = Vector2(0, 300)
	_board.draw.connect(_draw_board)
	_board.gui_input.connect(_board_input)
	col.add_child(_board)

	for digits in [[1, 2, 3, 4, 5], [6, 7, 8, 9]]:
		col.add_child(_row(digits.map(func(d): return [str(d), _place.bind(d), "Ivory"]), 1.4))
	col.add_child(_row([["Erase", _place.bind(0), "Onyx"], ["Undo", _undo, "Amethyst"], ["Hint", _hint, "Gold"]]))


func _won() -> void:
	Save.clear(ID)
	board = []
	var col := _clear()
	col.add_child(Screen.heading("Well done!"))
	col.add_child(Screen.label("You solved the %s puzzle." % difficulty.to_lower()))
	col.add_child(_spacer())
	col.add_child(Screen.button("New puzzle", _show_menu, "Gold"))
	col.add_child(Screen.button("Menu", _home, "Onyx"))


func _place(d: int) -> void:
	if selected < 0 or puzzle[selected] != 0 or board[selected] == d:
		return
	history.append([selected, board[selected]])
	board[selected] = d
	_after_move()


func _undo() -> void:
	if history.is_empty():
		return
	var h: Array = history.pop_back()
	board[h[0]] = h[1]
	selected = h[0]
	_after_move()


## Fixes the selected square if it's empty or wrong, otherwise the first square that is.
func _hint() -> void:
	if selected < 0 or board[selected] == solution[selected]:
		selected = range(81).filter(func(i): return board[i] != solution[i]).front()
	_place(solution[selected])


func _after_move() -> void:
	_save()
	if board == solution:
		_won()
	else:
		_board.queue_redraw()


func _save() -> void:
	Save.store(ID, {puzzle = puzzle, solution = solution, board = board, history = history, difficulty = difficulty})


## The square board area, centred in whatever space the buttons leave.
func _board_rect() -> Rect2:
	var side := minf(_board.size.x, _board.size.y)
	return Rect2((_board.size - Vector2(side, side)) / 2, Vector2(side, side))


func _board_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var r := _board_rect()
		var p: Vector2 = (e.position - r.position) / (r.size.x / 9)
		if p.x >= 0 and p.y >= 0 and p.x < 9 and p.y < 9:
			selected = int(p.y) * 9 + int(p.x)
			_board.queue_redraw()


func _draw_board() -> void:
	var r := _board_rect()
	var cell := r.size.x / 9
	var font := _board.get_theme_default_font()
	var fsize := roundi(cell * 0.7)
	var sel_digit: int = board[selected] if selected >= 0 else 0
	_board.draw_rect(r, AppTheme.IVORY)
	for i in 81:
		var sq := Rect2(r.position + Vector2(i % 9, i / 9) * cell, Vector2(cell, cell))
		if selected >= 0 and i != selected:
			if sel_digit and board[i] == sel_digit:
				_board.draw_rect(sq, SAME_DIGIT)
			elif i in SudokuLogic.PEERS[selected]:
				_board.draw_rect(sq, PEER)
		if i == selected:
			_board.draw_rect(sq, AppTheme.GOLD)
		if board[i]:
			var wrong: bool = board[i] != solution[i]
			var color := INK if puzzle[i] else (WRONG if wrong else PLAYER_INK)
			var baseline := sq.position.y + (cell + font.get_ascent(fsize) - font.get_descent(fsize)) / 2
			_board.draw_string(font, Vector2(sq.position.x, baseline), str(board[i]), HORIZONTAL_ALIGNMENT_CENTER, cell, fsize, color)
			if wrong:  # an underline too, so mistakes don't rely on colour alone
				_board.draw_line(sq.position + Vector2(0.25, 0.88) * cell, sq.position + Vector2(0.75, 0.88) * cell, WRONG, maxf(3, cell * 0.07))
	for k in 10:
		var w := 6.0 if k % 3 == 0 else 2.0
		_board.draw_line(r.position + Vector2(k * cell, 0), r.position + Vector2(k * cell, r.size.y), INK, w)
		_board.draw_line(r.position + Vector2(0, k * cell), r.position + Vector2(r.size.x, k * cell), INK, w)
	if selected >= 0:  # outline as well as fill, again not colour alone
		var sq := Rect2(r.position + Vector2(selected % 9, selected / 9) * cell, Vector2(cell, cell))
		_board.draw_rect(sq.grow(-3), PLAYER_INK, false, 6)


## Empties the screen now (not deferred, so old and new layouts never overlap) and returns a fresh column.
func _clear() -> VBoxContainer:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var col := VBoxContainer.new()
	add_child(col)
	return col


## A row of equal-width buttons from [text, callable, variation] triples.
## Text stops growing at 140%: beyond that the buttons squeeze the board, whose digits already scale with it.
func _row(items: Array, size_mult := 1.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for it in items:
		var b := Screen.button(it[0], it[1], it[2])
		b.add_theme_font_size_override("font_size", roundi(AppTheme.BASE_FONT * minf(Settings.text_scale, 1.4) * size_mult))
		row.add_child(b)
	return row


func _spacer() -> Control:
	var s := Control.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s


func _home() -> void:
	get_tree().change_scene_to_file(HOME)


static func _ints(a: Array) -> Array:
	return a.map(func(v): return int(v))  # JSON loads numbers as floats

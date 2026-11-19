extends Screen

# A game with an empty scene shows as "coming soon" until it's built.
const GAMES := [
	{name = "Sudoku", scene = "res://games/sudoku/sudoku.tscn", color = "Gold"},
	{name = "Solitaire", scene = "", color = "Ruby"},
	{name = "Word Search", scene = "", color = "Sapphire"},
	{name = "Mahjong", scene = "", color = "Ivory"},
	{name = "Dominoes", scene = "", color = "Amethyst"},
	{name = "Jigsaw", scene = "", color = "Onyx"},
]


func _ready() -> void:
	super()
	var col := VBoxContainer.new()
	add_child(col)
	col.add_child(Screen.heading("Game Haven"))

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var pad := MarginContainer.new()  # room for the tiles' shadows, which the scroll area would clip
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 16)
	scroll.add_child(pad)
	var grid := GridContainer.new()
	grid.columns = 1 if Settings.text_scale > 1.4 else 2  # two columns of large text won't fit
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad.add_child(grid)
	for g in GAMES:
		var b := Screen.button(g.name if g.scene else "%s\n(coming soon)" % g.name, _open.bind(g.scene), g.color)
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.disabled = g.scene == ""
		grid.add_child(b)

	col.add_child(Screen.button("Settings", _open.bind("res://ui/settings_screen.tscn"), "Onyx"))


func _open(scene: String) -> void:
	get_tree().change_scene_to_file(scene)

class_name Screen
extends MarginContainer
## Base for full-page screens: keeps content clear of the notch and home bar.


func _ready() -> void:
	var top := 0.0
	var bottom := 0.0
	if OS.has_feature("mobile"):  # desktop safe areas are in screen space and don't apply
		var win := DisplayServer.window_get_size()
		var safe := DisplayServer.get_display_safe_area()
		var px_per_unit := get_viewport_rect().size.x / maxf(win.x, 1)
		top = maxf(safe.position.y * px_per_unit, 0)
		bottom = maxf((win.y - safe.end.y) * px_per_unit, 0)
	add_theme_constant_override("margin_left", 32)
	add_theme_constant_override("margin_right", 32)
	add_theme_constant_override("margin_top", 32 + top)
	add_theme_constant_override("margin_bottom", 32 + bottom)
	_background = AppTheme.background(Settings.high_contrast)


var _background: Texture2D


func _draw() -> void:
	draw_texture_rect(_background, Rect2(Vector2.ZERO, size), false)


static func label(text: String, size_mult := 1.0) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if size_mult != 1.0:
		l.add_theme_font_size_override("font_size", roundi(AppTheme.BASE_FONT * Settings.text_scale * size_mult))
	return l


## Screen heading: big gold serif capitals over a row of card suits.
static func heading(text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	for line in [[text.to_upper(), 1.8], ["♠   ♥   ♦   ♣", 1.0]]:
		var l := label(line[0], line[1])
		l.theme_type_variation = "Heading"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	return box


static func button(text: String, on_press: Callable, variation := "") -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(on_press)
	return b

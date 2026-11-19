class_name AppTheme
## Builds the one shared Theme (card-table look: green felt, gold trim, jewel-tone buttons).
## Every size here is multiplied by the player's text scale, so games never handle text size themselves.

const BASE_FONT := 34  # px at the 720-wide base viewport: about 18 pt on iPhone

const FELT_CENTER := Color("177045")  # ivory text on this is 4.9:1, the lightest spot
const FELT_EDGE := Color("093824")
const GOLD := Color("e2bd4f")
const IVORY := Color("fff6e0")
const BG_HC := Color.BLACK
# Button colours as theme variations: [fill, text]. Every pair is at least 7:1 contrast.
const VARIATIONS := {
	"Ruby": [Color("9b1b30"), IVORY],
	"Sapphire": [Color("1f3a93"), IVORY],
	"Amethyst": [Color("5b2a86"), IVORY],
	"Onyx": [Color("161616"), IVORY],
	"Gold": [GOLD, Color("2a1a00")],
	"Ivory": [IVORY, Color("2a1a00")],
}


static func build(text_scale: float, high_contrast: bool) -> Theme:
	var t := Theme.new()
	t.default_font = _font(["Helvetica Neue", "Arial", "sans-serif"], 0.5)
	t.default_font_size = roundi(BASE_FONT * text_scale)
	t.set_color("font_color", "Label", Color.WHITE if high_contrast else IVORY)

	t.set_type_variation("Heading", "Label")
	t.set_font("font", "Heading", _font(["Georgia", "Times New Roman", "serif"], 0.6))
	t.set_color("font_color", "Heading", GOLD)

	_button("Button", t, VARIATIONS.Onyx[0], IVORY, high_contrast)
	for name in VARIATIONS:
		_button(name, t, VARIATIONS[name][0], VARIATIONS[name][1], high_contrast)

	t.set_constant("separation", "BoxContainer", 28)
	t.set_constant("h_separation", "GridContainer", 28)
	t.set_constant("v_separation", "GridContainer", 28)
	return t


## Felt background: lighter in the middle like a lit card table. Flat black in high contrast.
static func background(high_contrast: bool) -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, BG_HC if high_contrast else FELT_CENTER)
	g.set_color(1, BG_HC if high_contrast else FELT_EDGE)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.4)
	tex.fill_to = Vector2(1.2, 1.1)
	return tex


static func _font(names: Array, embolden: float) -> Font:
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(names)
	# Synthetic bold: Godot doesn't reliably pick bold faces out of system font collections.
	var font := FontVariation.new()
	font.base_font = sys
	font.variation_embolden = embolden
	return font


static func _button(type: String, t: Theme, fill: Color, text: Color, high_contrast: bool) -> void:
	if type != "Button":
		t.set_type_variation(type, "Button")
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = fill
		box.set_corner_radius_all(20)
		box.set_border_width_all(5)
		box.border_color = Color.WHITE if high_contrast else GOLD
		# 28 + 28 + text line gives ~100 px tall: about 54 pt on a 390 pt-wide iPhone (Apple minimum 44)
		box.content_margin_top = 28
		box.content_margin_bottom = 28
		box.content_margin_left = 24
		box.content_margin_right = 24
		box.shadow_color = Color(0, 0, 0, 0.45)
		box.shadow_size = 10
		box.shadow_offset = Vector2(0, 6)
		match state:
			"pressed", "hover_pressed":
				box.bg_color = fill.darkened(0.2)
				box.shadow_size = 3
				box.shadow_offset = Vector2(0, 2)
			"focus":
				box.draw_center = false
				box.shadow_size = 0
				box.border_color = IVORY
				box.set_expand_margin_all(9)
			"disabled":
				box.border_color = box.border_color.darkened(0.45)
				box.shadow_size = 0
		t.set_stylebox(state, type, box)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		t.set_color(key, type, text)

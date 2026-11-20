extends Button
## Small button of the main menu opening the MODS screen, with how many mods are on

const MODS_SCREEN_PATH := "res://mods/loader/ui/mods_screen.tscn"
const ACCENT := Color(0.5882353, 0.078431375, 0.21960784)


func _ready() -> void:
	var active: int = ModLoader.active_mods.size()
	text = "MODS · %d" % active if active > 0 else "MODS"
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.9) if state != "pressed" else Color(0.85, 0.85, 0.85)
		style.set_corner_radius_all(8)
		style.set_content_margin_all(6)
		if state == "focus":
			style.draw_center = false
		add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		add_theme_color_override(state, ACCENT)


func _pressed() -> void:
	get_tree().change_scene_to_file(MODS_SCREEN_PATH)

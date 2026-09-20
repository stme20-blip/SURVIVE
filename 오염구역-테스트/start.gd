extends Control


func _ready() -> void:
	_create_ui()


func _create_ui() -> void:
	# 전체 배경
	var background := ColorRect.new()
	add_child(background)

	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	background.color = Color(
		0.035,
		0.045,
		0.055,
		1.0
	)


	# 가운데 UI
	var center := CenterContainer.new()
	add_child(center)

	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)


	var menu := VBoxContainer.new()
	center.add_child(menu)

	menu.custom_minimum_size = Vector2(420, 0)

	menu.add_theme_constant_override(
		"separation",
		18
	)


	# 제목
	var title := Label.new()
	menu.add_child(title)

	title.text = "UNTITLED"

	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title.add_theme_font_size_override(
		"font_size",
		46
	)


	# 임시 부제
	var subtitle := Label.new()
	menu.add_child(subtitle)

	subtitle.text = "당신은 이곳에서 살아남아야 한다."

	subtitle.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	subtitle.modulate = Color(
		0.75,
		0.78,
		0.82,
		1.0
	)

	subtitle.add_theme_font_size_override(
		"font_size",
		16
	)


	# 여백
	var spacer := Control.new()
	menu.add_child(spacer)

	spacer.custom_minimum_size.y = 35


	# 새 게임
	var start_button := Button.new()
	menu.add_child(start_button)

	start_button.text = "새 게임"
	start_button.custom_minimum_size = Vector2(420, 54)

	start_button.pressed.connect(
		_on_start_pressed
	)


	# 종료
	var quit_button := Button.new()
	menu.add_child(quit_button)

	quit_button.text = "종료"
	quit_button.custom_minimum_size = Vector2(420, 54)

	quit_button.pressed.connect(
		_on_quit_pressed
	)


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(
		"res://room_menu.tscn"
	)


func _on_quit_pressed() -> void:
	get_tree().quit()

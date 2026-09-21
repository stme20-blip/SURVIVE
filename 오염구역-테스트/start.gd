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
	var game_buttons := HBoxContainer.new()
	game_buttons.add_theme_constant_override("separation", 12)
	menu.add_child(game_buttons)
	var start_button := Button.new()
	game_buttons.add_child(start_button)

	start_button.text = "새 게임"
	start_button.custom_minimum_size = Vector2(0, 54)
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	start_button.pressed.connect(
		_on_start_pressed
	)
	var load_button := Button.new()
	game_buttons.add_child(load_button)
	load_button.text = "불러오기"
	load_button.custom_minimum_size = Vector2(0, 54)
	load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_button.pressed.connect(_on_load_pressed)

	var invite_notice := AcceptDialog.new()
	invite_notice.title = "초대 코드"
	invite_notice.dialog_text = "초대 코드 기능은 준비 중입니다."
	invite_notice.ok_button_text = "확인"
	add_child(invite_notice)

	var invite_link := LinkButton.new()
	invite_link.text = "초대 코드 입력 >"
	invite_link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	invite_link.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	invite_link.pressed.connect(func() -> void:
		# Connect the invitation page here when the feature is available.
		invite_notice.popup_centered()
	)
	menu.add_child(invite_link)




func _on_start_pressed() -> void:
	get_tree().set_meta("room_menu_show_saved", false)
	get_tree().change_scene_to_file(
		"res://room_menu.tscn"
	)


func _on_load_pressed() -> void:
	get_tree().set_meta("room_menu_show_saved", true)
	get_tree().change_scene_to_file("res://room_menu.tscn")

extends Control


var panel: Panel

var title_label: Label
var new_room_title: Label

var room_name_label: Label
var room_name_input: LineEdit

var player_label: Label
var player_count_option: OptionButton

var create_button: Button

var separator: HSeparator
var saved_title: Label
var saved_scroll: ScrollContainer
var saved_rooms_container: VBoxContainer

var status_label: Label

var delete_confirm_dialog: ConfirmationDialog
var pending_delete_room_id: String = ""


func _ready() -> void:

	_create_ui()

	ScreenLayout.layout_changed.connect(
		_on_layout_changed
	)

	call_deferred(
		"_apply_layout"
	)

	_refresh_saved_rooms()


func _on_layout_changed() -> void:

	call_deferred(
		"_apply_layout"
	)


func _create_ui() -> void:

	var background := ColorRect.new()

	add_child(
		background
	)

	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	background.color = Color(
		0.025,
		0.030,
		0.035,
		1.0
	)


	panel = Panel.new()

	add_child(
		panel
	)


	var panel_style := StyleBoxFlat.new()

	panel_style.bg_color = Color(
		0.055,
		0.058,
		0.065,
		1.0
	)

	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4


	panel.add_theme_stylebox_override(
		"panel",
		panel_style
	)


	title_label = Label.new()

	panel.add_child(
		title_label
	)

	title_label.text = "게임 방"

	title_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	new_room_title = Label.new()

	panel.add_child(
		new_room_title
	)

	new_room_title.text = (
		"새 방 만들기"
	)


	room_name_label = Label.new()

	panel.add_child(
		room_name_label
	)

	room_name_label.text = "방 이름"


	room_name_input = LineEdit.new()

	panel.add_child(
		room_name_input
	)

	room_name_input.placeholder_text = (
		"예: 첫 번째 플레이"
	)


	player_label = Label.new()

	panel.add_child(
		player_label
	)

	player_label.text = "최대 인원"


	player_count_option = OptionButton.new()

	panel.add_child(
		player_count_option
	)

	player_count_option.add_item(
		"1인",
		1
	)

	player_count_option.add_item(
		"2인",
		2
	)

	player_count_option.add_item(
		"3인",
		3
	)


	create_button = Button.new()

	panel.add_child(
		create_button
	)

	create_button.text = "방 만들기"

	create_button.pressed.connect(
		_on_create_room_pressed
	)


	separator = HSeparator.new()

	panel.add_child(
		separator
	)


	saved_title = Label.new()

	panel.add_child(
		saved_title
	)

	saved_title.text = (
		"저장된 방"
	)


	saved_scroll = ScrollContainer.new()

	panel.add_child(
		saved_scroll
	)


	saved_rooms_container = VBoxContainer.new()

	saved_scroll.add_child(
		saved_rooms_container
	)

	saved_rooms_container.add_theme_constant_override(
		"separation",
		8
	)


	status_label = Label.new()

	panel.add_child(
		status_label
	)

	status_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	delete_confirm_dialog = ConfirmationDialog.new()

	add_child(
		delete_confirm_dialog
	)

	delete_confirm_dialog.title = (
		"방 삭제"
	)

	delete_confirm_dialog.ok_button_text = (
		"삭제"
	)

	delete_confirm_dialog.cancel_button_text = (
		"취소"
	)

	delete_confirm_dialog.confirmed.connect(
		_on_delete_room_confirmed
	)


func _apply_layout() -> void:

	var viewport_size := (
		get_viewport_rect().size
	)


	# =====================================================
	# 모바일
	# =====================================================

	if ScreenLayout.is_mobile_portrait():

		panel.size = Vector2(
			640,
			800
		)

		panel.position = Vector2(
			(
				viewport_size.x
				- panel.size.x
			) / 2.0,
			55
		)


		title_label.position = Vector2(
			30,
			24
		)

		title_label.size = Vector2(
			580,
			52
		)

		title_label.add_theme_font_size_override(
			"font_size",
			32
		)


		new_room_title.position = Vector2(
			35,
			105
		)

		new_room_title.size = Vector2(
			300,
			42
		)

		new_room_title.add_theme_font_size_override(
			"font_size",
			25
		)


		room_name_label.position = Vector2(
			35,
			165
		)

		room_name_label.size = Vector2(
			120,
			52
		)

		room_name_label.add_theme_font_size_override(
			"font_size",
			20
		)


		room_name_input.position = Vector2(
			160,
			165
		)

		room_name_input.size = Vector2(
			440,
			52
		)

		room_name_input.add_theme_font_size_override(
			"font_size",
			20
		)


		player_label.position = Vector2(
			35,
			235
		)

		player_label.size = Vector2(
			120,
			52
		)

		player_label.add_theme_font_size_override(
			"font_size",
			20
		)


		player_count_option.position = Vector2(
			160,
			235
		)

		player_count_option.size = Vector2(
			150,
			52
		)

		player_count_option.add_theme_font_size_override(
			"font_size",
			20
		)


		create_button.position = Vector2(
			340,
			235
		)

		create_button.size = Vector2(
			260,
			52
		)

		create_button.add_theme_font_size_override(
			"font_size",
			20
		)


		separator.position = Vector2(
			35,
			320
		)

		separator.size = Vector2(
			565,
			4
		)


		saved_title.position = Vector2(
			35,
			345
		)

		saved_title.size = Vector2(
			300,
			42
		)

		saved_title.add_theme_font_size_override(
			"font_size",
			25
		)


		saved_scroll.position = Vector2(
			35,
			400
		)

		saved_scroll.size = Vector2(
			565,
			290
		)


		saved_rooms_container.custom_minimum_size = Vector2(
			540,
			0
		)


		status_label.position = Vector2(
			35,
			715
		)

		status_label.size = Vector2(
			565,
			42
		)

		status_label.add_theme_font_size_override(
			"font_size",
			18
		)


	# =====================================================
	# PC
	# =====================================================

	else:

		panel.size = Vector2(
			500,
			510
		)

		panel.position = Vector2(
			(
				viewport_size.x
				- panel.size.x
			) / 2.0,
			70
		)


		title_label.position = Vector2(
			30,
			20
		)

		title_label.size = Vector2(
			440,
			45
		)

		title_label.add_theme_font_size_override(
			"font_size",
			26
		)


		new_room_title.position = Vector2(
			30,
			82
		)

		new_room_title.size = Vector2(
			200,
			30
		)

		new_room_title.add_theme_font_size_override(
			"font_size",
			18
		)


		room_name_label.position = Vector2(
			30,
			125
		)

		room_name_label.size = Vector2(
			90,
			34
		)

		room_name_label.add_theme_font_size_override(
			"font_size",
			16
		)


		room_name_input.position = Vector2(
			130,
			125
		)

		room_name_input.size = Vector2(
			340,
			34
		)

		room_name_input.add_theme_font_size_override(
			"font_size",
			16
		)


		player_label.position = Vector2(
			30,
			170
		)

		player_label.size = Vector2(
			90,
			36
		)

		player_label.add_theme_font_size_override(
			"font_size",
			16
		)


		player_count_option.position = Vector2(
			130,
			170
		)

		player_count_option.size = Vector2(
			120,
			36
		)

		player_count_option.add_theme_font_size_override(
			"font_size",
			16
		)


		create_button.position = Vector2(
			300,
			170
		)

		create_button.size = Vector2(
			170,
			36
		)

		create_button.add_theme_font_size_override(
			"font_size",
			16
		)


		separator.position = Vector2(
			30,
			225
		)

		separator.size = Vector2(
			440,
			4
		)


		saved_title.position = Vector2(
			30,
			245
		)

		saved_title.size = Vector2(
			200,
			30
		)

		saved_title.add_theme_font_size_override(
			"font_size",
			18
		)


		saved_scroll.position = Vector2(
			30,
			285
		)

		saved_scroll.size = Vector2(
			440,
			150
		)


		saved_rooms_container.custom_minimum_size = Vector2(
			420,
			0
		)


		status_label.position = Vector2(
			30,
			450
		)

		status_label.size = Vector2(
			440,
			30
		)

		status_label.add_theme_font_size_override(
			"font_size",
			16
		)


	_refresh_saved_rooms()


func _on_create_room_pressed() -> void:

	var room_name := (
		room_name_input.text.strip_edges()
	)


	if room_name.is_empty():

		room_name = "새 플레이"


	var max_players := (
		player_count_option.get_selected_id()
	)


	RoomManager.create_room(
		room_name,
		max_players
	)


	RoomManager.get_tree().change_scene_to_file(
		"res://prologue.tscn"
	)


func _refresh_saved_rooms() -> void:

	if saved_rooms_container == null:
		return


	for child in saved_rooms_container.get_children():

		child.queue_free()


	var rooms := (
		RoomManager.get_saved_rooms()
	)


	if rooms.is_empty():

		var empty_label := Label.new()

		empty_label.text = (
			"저장된 방이 없습니다."
		)

		saved_rooms_container.add_child(
			empty_label
		)

		return


	for room in rooms:

		var row := HBoxContainer.new()

		row.add_theme_constant_override(
			"separation",
			8
		)

		saved_rooms_container.add_child(
			row
		)


		var room_name := str(
			room.get(
				"room_name",
				"이름 없는 방"
			)
		)

		var max_players := int(
			room.get(
				"max_players",
				1
			)
		)

		var updated_at := str(
			room.get(
				"updated_at",
				""
			)
		)

		var room_id := str(
			room.get(
				"room_id",
				""
			)
		)


		var room_button := Button.new()

		room_button.text = (
			room_name
			+ " · "
			+ str(max_players)
			+ "인 · "
			+ updated_at
		)

		room_button.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)


		if ScreenLayout.is_mobile_portrait():

			room_button.custom_minimum_size.y = (
				54
			)

			room_button.add_theme_font_size_override(
				"font_size",
				18
			)

		else:

			room_button.custom_minimum_size.y = (
				42
			)


		room_button.pressed.connect(
			_on_saved_room_pressed.bind(
				room_id
			)
		)


		row.add_child(
			room_button
		)


		var delete_button := Button.new()

		delete_button.text = "삭제"


		if ScreenLayout.is_mobile_portrait():

			delete_button.custom_minimum_size = Vector2(
				90,
				54
			)

		else:

			delete_button.custom_minimum_size = Vector2(
				62,
				42
			)


		delete_button.pressed.connect(
			_on_delete_room_pressed.bind(
				room_id,
				room_name
			)
		)


		row.add_child(
			delete_button
		)


func _on_saved_room_pressed(
	room_id: String
) -> void:

	if not RoomManager.load_room(
		room_id
	):
		return


	var state: Dictionary = (
		RoomManager.get_game_state()
	)


	var character_id := int(
		state.get(
			"selected_character_id",
			0
		)
	)


	if character_id <= 0:

		RoomManager.get_tree().change_scene_to_file(
			"res://prologue.tscn"
		)

		return


	var member: Dictionary = (
		RoomManager.get_local_member()
	)


	GameData.selected_character_id = int(
		member.get(
			"character_id",
			character_id
		)
	)

	GameData.selected_name = str(
		member.get(
			"character_name",
			"캐릭터 " + str(character_id)
		)
	)

	GameData.selected_portrait_path = str(
		member.get(
			"portrait_path",
			"res://player_portrait.png"
		)
	)

	GameData.selected_personality = str(
		member.get(
			"personality",
			""
		)
	)


	var scene_file := str(
		state.get(
			"scene_file",
			"res://main.tscn"
		)
	)


	RoomManager.get_tree().change_scene_to_file(
		scene_file
	)


func _on_delete_room_pressed(
	room_id: String,
	room_name: String
) -> void:

	pending_delete_room_id = (
		room_id
	)


	delete_confirm_dialog.dialog_text = (
		"'"
		+ room_name
		+ "' 방을 삭제하시겠습니까?\n\n"
		+ "삭제한 플레이 기록은 복구할 수 없습니다."
	)


	delete_confirm_dialog.popup_centered(
		Vector2i(
			430,
			190
		)
	)


func _on_delete_room_confirmed() -> void:

	if pending_delete_room_id.is_empty():
		return


	var success := (
		RoomManager.delete_room(
			pending_delete_room_id
		)
	)


	if success:

		status_label.text = (
			"방을 삭제했습니다."
		)

	else:

		status_label.text = (
			"방을 삭제하지 못했습니다."
		)


	pending_delete_room_id = ""

	_refresh_saved_rooms()

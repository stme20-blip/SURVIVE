extends Control

var room_name_input: LineEdit
var saved_rooms_container: VBoxContainer
var saved_scroll: ScrollContainer
var status_label: Label
var delete_confirm_dialog: ConfirmationDialog
var _delete_message: Label
var pending_delete_room_id: String = ""
var show_saved: bool = false
var _margin: MarginContainer
var _heading: Label
var _buttons: Array[Button] = []
var _back_button: Button
var _rename_dialog: ConfirmationDialog
var _rename_input: LineEdit
var _rename_error: Label
var _pending_rename_id: String = ""
var _room_service: Node
var _creating := false
var _created := false
var _create_button: Button
var _continue_button: Button


func _ready() -> void:
	_room_service = preload("res://RoomService.gd").new()
	add_child(_room_service)
	show_saved = bool(get_tree().get_meta("room_menu_show_saved", false))
	if get_tree().has_meta("room_menu_show_saved"):
		get_tree().remove_meta("room_menu_show_saved")
	_create_ui()
	ScreenLayout.layout_changed.connect(_on_layout_changed)
	resized.connect(_on_layout_changed)
	_apply_layout()


func _on_layout_changed() -> void:
	call_deferred("_apply_layout")


func _create_ui() -> void:
	theme = Theme.new()
	theme.default_font = preload("res://fonts/Pretendard-Regular.otf")
	var background := ColorRect.new()
	background.color = Color(0.025, 0.030, 0.035, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margin = MarginContainer.new()
	_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_margin)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 18)
	_margin.add_child(column)

	_heading = Label.new()
	_heading.text = "저장된 서버" if show_saved else "신규 서버 생성"
	column.add_child(_heading)

	if show_saved:
		var saved_box := PanelContainer.new()
		var box_style := StyleBoxFlat.new()
		box_style.bg_color = Color(0.0, 0.0, 0.0, 0.45)
		box_style.border_color = Color(1.0, 1.0, 1.0, 0.25)
		box_style.set_border_width_all(1)
		box_style.content_margin_left = 16
		box_style.content_margin_right = 16
		box_style.content_margin_top = 16
		box_style.content_margin_bottom = 16
		saved_box.add_theme_stylebox_override("panel", box_style)
		column.add_child(saved_box)
		saved_scroll = ScrollContainer.new()
		saved_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		saved_scroll.follow_focus = true
		saved_box.add_child(saved_scroll)
		saved_rooms_container = VBoxContainer.new()
		saved_rooms_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		saved_rooms_container.add_theme_constant_override("separation", 8)
		saved_scroll.add_child(saved_rooms_container)
	else:
		var name_label := Label.new()
		name_label.text = "서버 이름"
		column.add_child(name_label)
		room_name_input = LineEdit.new()
		room_name_input.placeholder_text = "예: 첫 번째 플레이"
		room_name_input.expand_to_text_length = false
		column.add_child(room_name_input)
		var create_button := Button.new()
		_create_button = create_button
		create_button.text = "새로운 서버 만들기"
		create_button.pressed.connect(_on_create_room_pressed)
		column.add_child(create_button)
		_buttons.append(create_button)
		var notice := Label.new()
		notice.text = "※ 서버 생성 시 초대 코드가 지급됩니다. 최대 4명 참가 기능은 준비 중입니다. 서버 이름과 플레이 기록은 현재 기기에 저장됩니다."
		notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		notice.add_theme_color_override("font_color", Color("#acb7c5"))
		column.add_child(notice)

	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation", 6 if show_saved else 18)
	column.add_child(footer)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(status_label)
	_continue_button = Button.new()
	_continue_button.text = "계속"
	_continue_button.hide()
	_continue_button.pressed.connect(_on_continue_pressed)
	footer.add_child(_continue_button)
	_buttons.append(_continue_button)
	var back_button := Button.new()
	back_button.text = "← 이전"
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_back_button = back_button
	back_button.pressed.connect(_on_back_pressed)
	footer.add_child(back_button)
	_buttons.append(back_button)

	delete_confirm_dialog = ConfirmationDialog.new()
	delete_confirm_dialog.title = "서버 삭제"
	delete_confirm_dialog.borderless = true
	delete_confirm_dialog.confirmed.connect(_on_delete_room_confirmed)
	add_child(delete_confirm_dialog)
	delete_confirm_dialog.get_ok_button().hide()
	delete_confirm_dialog.get_cancel_button().hide()
	delete_confirm_dialog.get_label().hide()
	var delete_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		delete_margin.add_theme_constant_override("margin_" + side, 24)
	delete_confirm_dialog.add_child(delete_margin)
	var delete_content := VBoxContainer.new()
	delete_content.add_theme_constant_override("separation", 18)
	delete_margin.add_child(delete_content)
	var delete_heading := Label.new()
	delete_heading.text = "서버 삭제"
	delete_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	delete_heading.add_theme_font_size_override("font_size", 26)
	var heading_font := FontVariation.new()
	heading_font.base_font = preload("res://fonts/Pretendard-Regular.otf")
	heading_font.variation_embolden = 0.8
	delete_heading.add_theme_font_override("font", heading_font)
	delete_content.add_child(delete_heading)
	_delete_message = Label.new()
	_delete_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_delete_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_delete_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_delete_message.custom_minimum_size = Vector2(384, 76)
	_delete_message.add_theme_font_size_override("font_size", 18)
	_delete_message.add_theme_constant_override("line_spacing", 0)
	delete_content.add_child(_delete_message)
	var delete_actions := HBoxContainer.new()
	delete_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	delete_actions.add_theme_constant_override("separation", 12)
	delete_content.add_child(delete_actions)
	var confirm_delete := Button.new()
	confirm_delete.text = "삭제"
	confirm_delete.custom_minimum_size = Vector2(132, 48)
	confirm_delete.add_theme_font_size_override("font_size", 20)
	confirm_delete.pressed.connect(func() -> void:
		delete_confirm_dialog.hide()
		delete_confirm_dialog.confirmed.emit()
	)
	delete_actions.add_child(confirm_delete)
	var cancel_delete := Button.new()
	cancel_delete.text = "취소"
	cancel_delete.custom_minimum_size = Vector2(132, 48)
	cancel_delete.add_theme_font_size_override("font_size", 20)
	cancel_delete.pressed.connect(delete_confirm_dialog.hide)
	delete_actions.add_child(cancel_delete)
	_rename_dialog = ConfirmationDialog.new()
	_rename_dialog.title = "서버 이름 변경"
	_rename_dialog.ok_button_text = "변경"
	_rename_dialog.cancel_button_text = "취소"
	_rename_dialog.dialog_hide_on_ok = false
	_rename_dialog.confirmed.connect(_on_rename_confirmed)
	add_child(_rename_dialog)
	var rename_fields := VBoxContainer.new()
	_rename_dialog.add_child(rename_fields)
	var rename_label := Label.new()
	rename_label.text = "새 서버 이름"
	rename_fields.add_child(rename_label)
	_rename_input = LineEdit.new()
	_rename_input.expand_to_text_length = false
	_rename_input.text_submitted.connect(_on_rename_submitted)
	rename_fields.add_child(_rename_input)
	_rename_error = Label.new()
	_rename_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rename_error.add_theme_color_override("font_color", Color("#eac88b"))
	rename_fields.add_child(_rename_error)


func _apply_layout() -> void:
	if not is_instance_valid(_margin):
		return
	var mobile: bool = ScreenLayout.is_mobile_portrait()
	var target_width := 640.0 if mobile else 700.0
	var side := int(maxf(24.0, (size.x - target_width) / 2.0))
	_margin.add_theme_constant_override("margin_left", side)
	_margin.add_theme_constant_override("margin_right", side)
	_margin.add_theme_constant_override("margin_top", 55 if mobile else 60)
	_margin.add_theme_constant_override("margin_bottom", 24)
	theme.default_font_size = 26 if mobile else 18
	_heading.add_theme_font_size_override("font_size", 34 if mobile else 28)
	for button in _buttons:
		button.custom_minimum_size.y = 64 if mobile else 46
	_back_button.custom_minimum_size.x = 150 if mobile else 110
	if is_instance_valid(room_name_input):
		room_name_input.custom_minimum_size.y = 64 if mobile else 46
	if is_instance_valid(saved_scroll):
		saved_scroll.custom_minimum_size.y = 640 if mobile else 330
	_refresh_saved_rooms()


func _on_back_pressed() -> void:
	if _creating:
		return
	get_tree().change_scene_to_file("res://start.tscn")


func _format_saved_time(value: String) -> String:
	# Existing saves contain local system time; only change its presentation.
	var parts := value.replace(" ", "T").split("T")
	if parts.size() != 2:
		return "저장 시간 없음"
	var date := parts[0].split("-")
	var clock := parts[1].split(":")
	if date.size() != 3 or clock.size() < 2:
		return "저장 시간 없음"
	for number in [date[0], date[1], date[2], clock[0], clock[1]]:
		if not number.is_valid_int():
			return "저장 시간 없음"
	var hour := int(clock[0])
	var period := "오전" if hour < 12 else "오후"
	var display_hour := hour % 12
	if display_hour == 0:
		display_hour = 12
	return "%d년 %d월 %d일 %s %d시 %d분" % [
		int(date[0]), int(date[1]), int(date[2]),
		period, display_hour, int(clock[1])
	]

func _on_create_room_pressed() -> void:
	if _creating or _created:
		return
	_creating = true
	_create_button.disabled = true
	_back_button.disabled = true
	room_name_input.editable = false
	status_label.text = "서버 생성 중입니다..."
	var room_name := room_name_input.text.strip_edges()
	if room_name.is_empty():
		room_name = "새 플레이"
	var result: Dictionary = await _room_service.create_room()
	_creating = false
	_back_button.disabled = false
	if result.has("error"):
		status_label.text = str(result.get("message", "서버 생성에 실패했습니다."))
		_create_button.disabled = false
		room_name_input.editable = true
		return
	var online: Dictionary = result.data.duplicate(true)
	online["host_user_id"] = AuthManager.user_id
	online["is_host"] = true
	RoomManager.create_room(room_name, 4, online)
	_created = true
	_create_button.text = "서버 생성 완료"
	status_label.text = "서버가 생성되었습니다. 초대 코드: %s\n코드로 참가하는 기능은 준비 중입니다." % online.invite_code
	_continue_button.show()
	if not RoomManager.save_current_room():
		status_label.text += "\n로컬 저장에 실패했습니다. 저장 공간을 확인한 뒤 계속을 눌러 다시 저장해 주세요."


func _on_continue_pressed() -> void:
	if not _created:
		return
	if not RoomManager.save_current_room():
		status_label.text = "로컬 저장에 실패했습니다. 저장 공간을 확인해 주세요. 초대 코드: " + str(RoomManager.current_room.get("online_room", {}).get("invite_code", ""))
		return
	var error := get_tree().change_scene_to_file("res://prologue.tscn")
	if error != OK:
		status_label.text = "다음 화면을 열지 못했습니다. 다시 계속을 눌러 주세요."


func _refresh_saved_rooms() -> void:

	if saved_rooms_container == null:
		return


	for child in saved_rooms_container.get_children():

		saved_rooms_container.remove_child(child)
		child.queue_free()


	var rooms := (
		RoomManager.get_saved_rooms()
	)


	if rooms.is_empty():

		var empty_label := Label.new()

		empty_label.text = (
			"저장된 서버가 없습니다."
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
				"이름 없는 서버"
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

		room_button.text = room_name + " · " + _format_saved_time(updated_at)
		var online = room.get("online_room", {})
		if online is Dictionary and not str(online.get("invite_code", "")).is_empty():
			room_button.text += "\n초대 코드: " + str(online.invite_code)
		room_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

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


		var rename_button := Button.new()
		rename_button.text = "이름 변경"
		rename_button.custom_minimum_size = Vector2(120, 54) if ScreenLayout.is_mobile_portrait() else Vector2(90, 42)
		rename_button.add_theme_font_size_override("font_size", 20 if ScreenLayout.is_mobile_portrait() else 16)
		rename_button.pressed.connect(_on_rename_pressed.bind(room_id, room_name))
		row.add_child(rename_button)
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


func _on_rename_pressed(room_id: String, room_name: String) -> void:
	_pending_rename_id = room_id
	_rename_input.text = room_name
	_rename_error.text = ""
	_rename_dialog.popup_centered(Vector2i(560, 220) if ScreenLayout.is_mobile_portrait() else Vector2i(430, 180))
	_rename_input.grab_focus()
	_rename_input.select_all()


func _on_rename_submitted(_text: String) -> void:
	_on_rename_confirmed()


func _on_rename_confirmed() -> void:
	var new_name := _rename_input.text.strip_edges()
	if new_name.is_empty():
		_rename_error.text = "서버 이름을 입력해 주세요."
		return
	if not RoomManager.rename_room(_pending_rename_id, new_name):
		_rename_error.text = "이름을 변경하지 못했습니다. 다시 시도해 주세요."
		return
	_pending_rename_id = ""
	_rename_dialog.hide()
	status_label.text = "서버 이름을 변경했습니다."
	_refresh_saved_rooms()


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


	_delete_message.text = (
		"'"
		+ room_name
		+ "' 서버를 삭제하시겠습니까?\n"
		+ "삭제한 플레이 기록은 복구할 수 없습니다."
	)


	delete_confirm_dialog.popup_centered(
		Vector2i(
			540 if ScreenLayout.is_mobile_portrait() else 480,
			270
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
			"서버를 삭제했습니다."
		)

	else:

		status_label.text = (
			"서버를 삭제하지 못했습니다."
		)


	pending_delete_room_id = ""

	_refresh_saved_rooms()

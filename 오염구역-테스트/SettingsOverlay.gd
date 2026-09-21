extends CanvasLayer

const TRAITS := preload("res://personality_select.gd").PERSONALITIES
const PORTRAIT_PICKER := preload("res://custom_character.gd")

var _root: Control
var _gear: Button
var _members_button: Button
var _members_dialog: Panel
var _members_list: VBoxContainer
var _members_list_panel: PanelContainer
var _members_action: Button
var _members_return: Button
var _members_status: Label
var _members_invite_code: Label
var _room_service: Node
var _members_action_armed := false
var _membership_closed := false
var _closed_membership_room_id := ""
var _closed_membership_session_id := ""
var _members_dragging := false
var _members_drag_offset := Vector2.ZERO
var _modal: ColorRect
var _margin: MarginContainer
var _form: VBoxContainer
var _name: LineEdit
var _portrait: TextureRect
var _portrait_button: Button
var _picker: Control
var _traits: OptionButton
var _description: Label
var _limit: Label
var _status: Label
var _save_button: Button
var _cancel_button: Button
var _settings_return_button: Button
var _settings_return_underline: ColorRect
var _pending_portrait: Image
var _room_id: String = ""
var _was_paused: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = Theme.new()
	_root.theme.default_font = preload("res://fonts/Pretendard-Regular.otf")
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gear = Button.new()
	_gear.hide()
	_gear.icon = preload("res://settings_gear.svg")
	_gear.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gear.add_theme_constant_override("icon_max_width", 20)
	var gear_focus := StyleBoxFlat.new()
	gear_focus.draw_center = false
	gear_focus.border_color = Color(1, 1, 1, 0.35)
	gear_focus.set_border_width_all(1)
	_gear.add_theme_stylebox_override("focus", gear_focus)
	_gear.tooltip_text = "설정"
	_gear.pressed.connect(open_settings)
	_root.add_child(_gear)
	_gear.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_members_button = Button.new()
	_members_button.hide()
	_members_button.icon = preload("res://members_icon.svg")
	_members_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_members_button.tooltip_text = "참가자"
	_members_button.pressed.connect(_open_members)
	_root.add_child(_members_button)
	_members_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_room_service = preload("res://RoomService.gd").new()
	add_child(_room_service)
	_create_members_dialog()
	_create_modal()
	ScreenLayout.layout_changed.connect(_layout)
	_root.resized.connect(_layout)
	get_tree().scene_changed.connect(_layout)
	_layout()


func _create_members_dialog() -> void:
	_members_dialog = Panel.new()
	_members_dialog.hide()
	_members_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	var dialog_style := StyleBoxFlat.new()
	dialog_style.bg_color = Color("#202225")
	dialog_style.set_border_width_all(0)
	dialog_style.border_color = Color("#000000")
	dialog_style.set_corner_radius_all(12)
	dialog_style.set_content_margin_all(22)
	_members_dialog.add_theme_stylebox_override("panel", dialog_style)
	_members_dialog.gui_input.connect(_on_members_dialog_gui_input)
	_root.add_child(_members_dialog)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_members_dialog.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.flat = true
	close_button.tooltip_text = "닫기"
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close_button.offset_left = -40
	close_button.offset_top = 4
	close_button.offset_right = -4
	close_button.offset_bottom = 40
	close_button.pressed.connect(_members_dialog.hide)
	_members_dialog.add_child(close_button)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	_members_status = Label.new()
	_members_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_members_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_members_status)
	_members_invite_code = Label.new()
	_members_invite_code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_members_invite_code.add_theme_color_override("font_color", Color("#c8c8c8"))
	content.add_child(_members_invite_code)
	_members_list_panel = PanelContainer.new()
	var list_style := StyleBoxFlat.new()
	list_style.bg_color = Color(0, 0, 0, 0.55)
	list_style.set_border_width_all(0)
	list_style.set_content_margin_all(12)
	_members_list_panel.add_theme_stylebox_override("panel", list_style)
	# Four players plus one spare row keep the list stable without making the popup tall.
	_members_list_panel.custom_minimum_size.y = 140
	_members_list_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	content.add_child(_members_list_panel)
	_members_list = VBoxContainer.new()
	_members_list.add_theme_constant_override("separation", 8)
	_members_list_panel.add_child(_members_list)
	content.move_child(_members_invite_code, content.get_child_count() - 1)
	_members_action = Button.new()
	_members_action.pressed.connect(_confirm_members_action)
	_members_action.custom_minimum_size = Vector2(0, 42)
	content.add_child(_members_action)
	var bottom_space := Control.new()
	bottom_space.custom_minimum_size.y = 10
	bottom_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(bottom_space)
	_members_return = Button.new()
	_members_return.text = "메인 화면으로 돌아가기"
	_members_return.custom_minimum_size = Vector2(0, 42)
	_members_return.pressed.connect(_return_to_start)
	_members_return.hide()
	content.add_child(_members_return)


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_form.add_child(label)
	return label


func _create_modal() -> void:
	_modal = ColorRect.new()
	_modal.color = Color(0, 0, 0, 0.96)
	_root.add_child(_modal)
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_modal.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margin = MarginContainer.new()
	_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_margin)
	_form = VBoxContainer.new()
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_form.add_theme_constant_override("separation", 5)
	_margin.add_child(_form)
	var heading := _label("캐릭터 설정")
	heading.add_theme_font_size_override("font_size", 30)
	var portrait_row := VBoxContainer.new()
	portrait_row.add_theme_constant_override("separation", 10)
	_form.add_child(portrait_row)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait_row.add_child(_portrait)
	_portrait_button = Button.new()
	_portrait_button.text = "초상화 변경"
	_portrait_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_portrait_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_portrait_button.pressed.connect(_open_portrait_picker)
	portrait_row.add_child(_portrait_button)
	_picker = PORTRAIT_PICKER.new()
	_picker.portrait_picker_only = true
	_picker.custom_minimum_size.y = 24
	_picker.portrait_image_selected.connect(_on_portrait_selected)
	_form.add_child(_picker)
	_label("이름")
	_name = LineEdit.new()
	_name.max_length = 20
	_name.expand_to_text_length = false
	_form.add_child(_name)
	_label("특성")
	_traits = OptionButton.new()
	for personality_data in TRAITS:
		_traits.add_item(str(personality_data["name"]))
	_traits.item_selected.connect(_on_trait_selected)
	_form.add_child(_traits)
	_description = _label("")
	var limit_margin := MarginContainer.new()
	limit_margin.add_theme_constant_override("margin_top", 10)
	_form.add_child(limit_margin)
	_limit = Label.new()
	_limit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	limit_margin.add_child(_limit)
	_limit.add_theme_color_override("font_color", Color("#c1c1c1"))
	_status = _label("")
	_status.add_theme_color_override("font_color", Color("#eac88b"))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	_form.add_child(actions)
	_cancel_button = Button.new()
	_cancel_button.text = "취소"
	_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel_button.pressed.connect(close_settings)
	actions.add_child(_cancel_button)
	_save_button = Button.new()
	_save_button.text = "변경 저장"
	_save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_button.pressed.connect(_save)
	actions.add_child(_save_button)
	actions.move_child(_save_button, 0)
	var return_margin := MarginContainer.new()
	return_margin.add_theme_constant_override("margin_top", 12)
	_form.add_child(return_margin)
	_settings_return_button = Button.new()
	_settings_return_button.text = "> 진행 상황 저장 및 게임 종료"
	_settings_return_button.flat = true
	_settings_return_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_settings_return_button.custom_minimum_size.y = 30
	_settings_return_underline = ColorRect.new()
	_settings_return_underline.color = Color(1, 1, 1, 0.75)
	_settings_return_underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_return_underline.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_settings_return_underline.offset_top = -1
	_settings_return_underline.hide()
	_settings_return_button.add_child(_settings_return_underline)
	_settings_return_button.mouse_entered.connect(_settings_return_underline.show)
	_settings_return_button.mouse_exited.connect(_settings_return_underline.hide)
	_settings_return_button.pressed.connect(_return_from_settings)
	return_margin.add_child(_settings_return_button)
	_modal.hide()


func _layout() -> void:
	if not is_instance_valid(_margin):
		return
	var mobile: bool = ScreenLayout.is_mobile_portrait()
	var button_size := 48 if mobile else 32
	_gear.add_theme_constant_override("icon_max_width", 26 if mobile else 20)
	var right_inset := 12.0
	var scene := get_tree().current_scene
	_gear.visible = scene != null and scene.scene_file_path == "res://main.tscn"
	_members_button.visible = _gear.visible and (RoomManager.has_active_online_room() or _membership_closed)
	if not _gear.visible and _modal.visible:
		close_settings()
	if scene != null and scene.scene_file_path == "res://main.tscn" and not mobile:
		right_inset += maxf(0.0, _root.size.x - 1152.0)
	_gear.offset_left = -button_size - right_inset
	_gear.offset_right = -right_inset
	_gear.offset_top = 12
	_gear.offset_bottom = button_size + 12
	_members_button.offset_left = -button_size * 2 - right_inset - 6
	_members_button.offset_right = -button_size - right_inset - 6
	_members_button.offset_top = 12
	_members_button.offset_bottom = button_size + 12
	_members_button.add_theme_constant_override("icon_max_width", 26 if mobile else 20)
	if _members_dialog.visible:
		_set_members_dialog_size(_membership_closed)
	_root.theme.default_font_size = 24 if mobile else 18
	var side := int(maxf(24, (_root.size.x - (640 if mobile else 580)) / 2.0))
	_margin.add_theme_constant_override("margin_left", side)
	_margin.add_theme_constant_override("margin_right", side)
	_margin.add_theme_constant_override("margin_top", 24)
	_margin.add_theme_constant_override("margin_bottom", 24)
	_form.add_theme_constant_override("separation", 8 if mobile else 5)
	_portrait.custom_minimum_size = Vector2(120, 120) if mobile else Vector2(84, 84)
	for control in [_name, _portrait_button, _traits, _save_button, _cancel_button]:
		control.custom_minimum_size.y = 60 if mobile else 40


func is_pointer_over_interactive_control(pointer_position: Vector2) -> bool:

	# main.gd의 전체 화면 클릭 스킵보다 우선해야 하는 오버레이 조작 영역이다.
	if _modal.visible or _members_dialog.visible:
		return true
	if _gear.visible and _gear.get_global_rect().has_point(pointer_position):
		return true
	return _members_button.visible and _members_button.get_global_rect().has_point(pointer_position)


func open_settings() -> void:
	if _modal.visible or not _gear.visible:
		return
	var member: Dictionary = RoomManager.get_local_member()
	var ready := int(member.get("character_id", 0)) > 0 and not str(member.get("personality", "")).is_empty()
	_room_id = RoomManager.get_current_room_id()
	_pending_portrait = null
	_name.text = str(member.get("character_name", "")) if ready else ""
	_name.editable = ready
	_portrait.texture = GameData.load_portrait_texture(str(member.get("portrait_path", ""))) if ready else null
	_portrait_button.disabled = not ready
	_save_button.disabled = not ready
	_traits.disabled = not ready or RoomManager.get_personality_changes_remaining() == 0
	_traits.select(-1)
	for index in range(TRAITS.size()):
		if TRAITS[index]["key"] == str(member.get("personality", "")):
			_traits.select(index)
	_description.text = ""
	if _traits.selected >= 0:
		_on_trait_selected(_traits.selected)
	_limit.text = "※ 특성 변경은 한 플레이(서버)당 최대 3회까지 가능합니다.\n변경한 정보는 다음 장면부터 적용됩니다. [현재 남은 횟수 : %d회]" % RoomManager.get_personality_changes_remaining()
	_status.text = "" if ready else "캐릭터와 특성을 먼저 설정한 뒤 변경할 수 있습니다."
	_settings_return_button.text = "> 서버 삭제 및 게임 종료" if _membership_closed else "> 진행 상황 저장 및 게임 종료"
	_picker.status_label.text = ""
	_was_paused = get_tree().paused
	get_tree().paused = true
	_modal.show()
	_cancel_button.grab_focus()


func close_settings() -> void:
	if not _modal.visible:
		return
	_picker.portrait_choice_dialog.hide()
	_picker.file_dialog.hide()
	_pending_portrait = null
	_modal.hide()
	get_tree().paused = _was_paused
	if _gear.has_focus():
		_gear.release_focus()


func _return_from_settings() -> void:
	if _membership_closed:
		RoomManager.delete_room(RoomManager.get_current_room_id())
		RoomManager.clear_current_room()
	elif RoomManager.has_room() and not RoomManager.save_current_room():
		_status.text = "진행 상황을 저장하지 못했습니다. 저장 공간을 확인해 주세요."
		return
	close_settings()
	var error := get_tree().change_scene_to_file("res://start.tscn")
	if error != OK:
		print("[settings] unable to return to start; error=", error)


func _open_members() -> void:
	var current_online: Dictionary = RoomManager.current_room.get("online_room", {})
	var current_room_id := str(current_online.get("room_id", ""))
	var current_session_id := str(current_online.get("membership_session_id", ""))
	# SettingsOverlay is retained while the player creates another server. A completed
	# state belongs only to the room that was deleted or left.
	if _membership_closed and not current_room_id.is_empty() and (current_room_id != _closed_membership_room_id or (not current_session_id.is_empty() and current_session_id != _closed_membership_session_id)):
		_membership_closed = false
		_closed_membership_room_id = ""
		_closed_membership_session_id = ""
	if not RoomManager.has_active_online_room() and not _membership_closed:
		print("[members] no active online room")
		return
	if not is_instance_valid(_members_dialog) or not _members_dialog.is_inside_tree() or not is_instance_valid(_members_status):
		print("[members] rebuilding popup")
		_create_members_dialog()
	if not is_instance_valid(_members_dialog) or not _members_dialog.is_inside_tree():
		print("[members] popup creation failed")
		return
	print("[members] opening popup")
	_set_members_dialog_size(false)
	_members_dialog.show()
	_members_status.text = "참가자 목록을 불러오는 중입니다..."
	_members_action.hide()
	_members_return.hide()
	_members_invite_code.show()
	_members_list_panel.show()
	_members_action_armed = false
	if _membership_closed:
		_show_membership_closed()
		return
	for child in _members_list.get_children():
		child.queue_free()
	var online: Dictionary = RoomManager.current_room.get("online_room", {})
	var result: Dictionary = await _room_service.get_members(str(online.get("room_id", "")))
	if result.has("error"):
		# If the host deletes the room, the participant's membership disappears
		# before this request. Present a useful terminal screen instead of 403.
		if str(result.get("error", "")) == "ROOM_ACCESS_DENIED":
			_membership_closed = true
			_closed_membership_room_id = str(online.get("room_id", ""))
			_closed_membership_session_id = str(online.get("membership_session_id", ""))
			_show_membership_unavailable("서버가 삭제되었습니다.\n생존 기록을 사용할 수 없습니다.")
			return
		_members_status.text = str(result.get("message", "참가자 목록을 불러오지 못했습니다."))
		return
	for member in result.data:
		var row := HBoxContainer.new()
		_members_list.add_child(row)
		var online_dot := ColorRect.new()
		online_dot.color = Color("#4edc8b")
		online_dot.custom_minimum_size = Vector2(8, 8)
		online_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(online_dot)
		var gap := Control.new()
		gap.custom_minimum_size.x = 8
		row.add_child(gap)
		var label := Label.new()
		var role := "호스트" if member.get("role") == "host" else "참가자"
		var name := str(member.get("display_name", "")).strip_edges()
		label.text = "%s · %s%s" % [role, name if not name.is_empty() else "참가자", " (나)" if member.get("user_id") == AuthManager.user_id else ""]
		row.add_child(label)
	_members_status.text = "참가자 %d / 4명" % result.data.size()
	_members_invite_code.text = "초대 코드 · " + str(online.get("invite_code", ""))
	_members_action.text = "서버 삭제하기" if bool(online.get("is_host", false)) else "서버 나가기"
	_members_action.disabled = false
	_members_action.show()


func _confirm_members_action() -> void:
	var online: Dictionary = RoomManager.current_room.get("online_room", {})
	var host := bool(online.get("is_host", false))
	if not _members_action_armed:
		_members_action_armed = true
		var confirm := ConfirmationDialog.new()
		confirm.title = "서버 삭제" if host else "서버 나가기"
		confirm.dialog_text = "서버를 삭제하시겠습니까?\n참가 중인 모든 플레이어가 서버에서 나가게 됩니다." if host else "이 서버에서 나가시겠습니까?"
		confirm.ok_button_text = "삭제" if host else "나가기"
		confirm.cancel_button_text = "취소"
		_root.add_child(confirm)
		confirm.confirmed.connect(func(): _confirm_members_action())
		confirm.canceled.connect(confirm.queue_free)
		# Leave a small breathing space below the action buttons.
		confirm.popup_centered(Vector2i(360, 205))
		return
	_members_action.disabled = true
	_members_status.text = "서버를 삭제하는 중입니다..." if host else "서버에서 나가는 중입니다..."
	# Deleting a room (or leaving it) can invalidate this client's membership before
	# the HTTP response reaches Godot. Switch the popup first so its next opening
	# always presents the completed state instead of the resulting permission error.
	_membership_closed = true
	var room_id := str(online.get("room_id", ""))
	_closed_membership_room_id = room_id
	_closed_membership_session_id = str(online.get("membership_session_id", ""))
	_show_membership_closed(host)
	var result: Dictionary = await (_room_service.delete_online_room(room_id) if host else _room_service.leave_room(room_id))
	if result.has("error"):
		print("[members] membership request ended after removal: ", result.get("error", "unknown"))
		return
	print("[members] server membership action completed")


func _show_membership_closed(host: bool = bool(RoomManager.current_room.get("online_room", {}).get("is_host", false))) -> void:
	_show_membership_unavailable("삭제 완료되었습니다.\n생존 기록을 사용할 수 없습니다." if host else "서버에서 나갔습니다.\n생존 기록을 사용할 수 없습니다.")


func _show_membership_unavailable(message: String) -> void:
	for child in _members_list.get_children():
		child.queue_free()
	_members_status.text = message
	_members_invite_code.hide()
	_members_list_panel.hide()
	_members_action.hide()
	_members_return.show()
	_set_members_dialog_size(true)


func _set_members_dialog_size(completed: bool) -> void:
	var available_width := maxf(220.0, _root.size.x - 16.0)
	var available_height := maxf(180.0, _root.size.y - 16.0)
	# The completed state contains only its message and return button. Keep its
	# bottom padding compact, while portrait mode gets room below the room action.
	var desired_height := (180.0 if ScreenLayout.is_mobile_portrait() else 160.0) if completed else (315.0 if ScreenLayout.is_mobile_portrait() else 300.0)
	_members_dialog.size = Vector2(minf(340.0, available_width), minf(desired_height, available_height))
	_position_members_dialog_near_icon()


func _position_members_dialog_near_icon() -> void:

	if not is_instance_valid(_members_button):
		return

	var viewport_padding := 8.0
	var icon_rect := _members_button.get_rect()
	var target_position := Vector2.ZERO
	if ScreenLayout.is_mobile_portrait():
		# 세로 화면은 아이콘 아래, 오른쪽을 맞춰 화면 안에 안정적으로 둔다.
		target_position.x = icon_rect.end.x - _members_dialog.size.x
	else:
		# PC는 기록 패널을 가리지 않도록 참가자 아이콘의 왼쪽에서 연다.
		target_position.x = icon_rect.position.x - _members_dialog.size.x - 10.0
	target_position.y = icon_rect.end.y + 8.0
	target_position.x = clampf(target_position.x, viewport_padding, maxf(viewport_padding, _root.size.x - _members_dialog.size.x - viewport_padding))
	target_position.y = clampf(target_position.y, viewport_padding, maxf(viewport_padding, _root.size.y - _members_dialog.size.y - viewport_padding))
	_members_dialog.position = target_position


func _return_to_start() -> void:
	if is_instance_valid(_members_dialog):
		_members_dialog.hide()
	RoomManager.delete_room(RoomManager.get_current_room_id())
	RoomManager.clear_current_room()
	var error := get_tree().change_scene_to_file("res://start.tscn")
	if error != OK:
		print("[members] unable to return to start; error=", error)


func _on_members_dialog_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.position.y <= 42:
			_members_dragging = true
			_members_drag_offset = event.position
			get_viewport().set_input_as_handled()
		elif not event.pressed:
			_members_dragging = false
	elif event is InputEventMouseMotion and _members_dragging:
		var next_position: Vector2 = _members_dialog.position + event.relative
		next_position.x = clampf(next_position.x, 0.0, maxf(0.0, _root.size.x - _members_dialog.size.x))
		next_position.y = clampf(next_position.y, 0.0, maxf(0.0, _root.size.y - _members_dialog.size.y))
		_members_dialog.position = next_position
		get_viewport().set_input_as_handled()




func _open_portrait_picker() -> void:
	_picker._on_image_button_pressed()


func _on_portrait_selected(image: Image) -> void:
	if not _modal.visible:
		return
	_pending_portrait = image
	_portrait.texture = ImageTexture.create_from_image(image)
	_picker.status_label.text = ""
	_status.text = "변경 저장 후 다음 장면부터 적용됩니다."


func _on_trait_selected(index: int) -> void:
	_description.text = str(TRAITS[index]["description"])


func _save() -> void:
	if _save_button.disabled:
		return
	if _room_id != RoomManager.get_current_room_id():
		_status.text = "플레이가 변경되었습니다. 설정을 다시 열어 주세요."
		return
	if _traits.selected < 0:
		_status.text = "특성을 선택해 주세요."
		return
	var key := str(TRAITS[_traits.selected]["key"])
	var changed := key != str(RoomManager.get_local_member().get("personality", ""))
	var error: String = RoomManager.apply_character_settings(_name.text, key, _pending_portrait)
	if not error.is_empty():
		_status.text = error
		return
	var member: Dictionary = RoomManager.get_local_member()
	GameData.selected_character_id = int(member.get("character_id", 0))
	GameData.selected_name = str(member.get("character_name", ""))
	GameData.selected_portrait_path = str(member.get("portrait_path", ""))
	GameData.selected_personality = str(member.get("personality", ""))
	GameData.character_settings_changed.emit(changed)
	close_settings()


func _unhandled_key_input(event: InputEvent) -> void:
	if _modal.visible and event.is_action_pressed("ui_cancel"):
		close_settings()
		get_viewport().set_input_as_handled()

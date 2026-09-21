extends Control

var _service: Node
var _busy := false
var _joined := false
var _margin: MarginContainer
var _form: VBoxContainer
var _code: LineEdit
var _join: Button
var _info: Label
var _members: VBoxContainer
var _status: Label
var _refresh: Button
var _continue: Button
var _back: Button


func _ready() -> void:
	_service = preload("res://RoomService.gd").new()
	add_child(_service)
	_build_ui()
	ScreenLayout.layout_changed.connect(_layout)
	resized.connect(_layout)
	_layout()
	var joining := bool(get_tree().get_meta("room_lobby_join", false))
	if get_tree().has_meta("room_lobby_join"):
		get_tree().remove_meta("room_lobby_join")
	if not joining and not RoomManager.current_room.get("online_room", {}).is_empty():
		await _update_profile_if_needed()
		_show_room()
		await _refresh_members()


func _build_ui() -> void:
	theme = Theme.new()
	theme.default_font = preload("res://fonts/Pretendard-Regular.otf")
	var background := ColorRect.new()
	background.color = Color("#080a0c")
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
	scroll.add_child(_margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	_margin.add_child(column)
	_form = VBoxContainer.new()
	_form.add_theme_constant_override("separation", 12)
	column.add_child(_form)
	var heading := Label.new()
	heading.text = "초대 코드 입력"
	_form.add_child(heading)
	_code = LineEdit.new()
	_code.placeholder_text = "예: K7M4XP"
	# Normalize pasted whitespace before enforcing the six-character limit.
	_code.text_changed.connect(_normalize_input)
	_code.text_submitted.connect(func(_value: String) -> void: _join_pressed())
	_form.add_child(_code)
	_join = Button.new()
	_join.text = "참가"
	_join.pressed.connect(_join_pressed)
	_form.add_child(_join)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_info)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.45)
	style.border_color = Color(1, 1, 1, 0.25)
	style.set_border_width_all(1)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	column.add_child(panel)
	_members = VBoxContainer.new()
	_members.add_theme_constant_override("separation", 12)
	panel.add_child(_members)
	var notice := Label.new()
	notice.text = "참가자 목록은 화면 진입 시 갱신됩니다.\n게임 진행·대사 동기화는 준비 중이며, 계속하면 각자의 로컬 플레이가 진행됩니다."
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(notice)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	_refresh = Button.new()
	_refresh.text = "참가자 새로고침"
	_refresh.hide()
	_refresh.pressed.connect(_refresh_members)
	column.add_child(_refresh)
	_continue = Button.new()
	_continue.text = "계속"
	_continue.hide()
	_continue.pressed.connect(_continue_pressed)
	column.add_child(_continue)
	_back = Button.new()
	_back.text = "← 이전"
	_back.size_flags_horizontal = Control.SIZE_SHRINK_END
	_back.pressed.connect(func() -> void:
		if not _busy:
			get_tree().change_scene_to_file("res://start.tscn")
	)
	column.add_child(_back)


func _layout() -> void:
	if not is_instance_valid(_margin):
		return
	var mobile: bool = ScreenLayout.is_mobile_portrait()
	var side := int(maxf(24, (size.x - (640 if mobile else 700)) / 2.0))
	_margin.add_theme_constant_override("margin_left", side)
	_margin.add_theme_constant_override("margin_right", side)
	_margin.add_theme_constant_override("margin_top", 40)
	_margin.add_theme_constant_override("margin_bottom", 24)
	theme.default_font_size = 26 if mobile else 18
	for button in [_join, _refresh, _continue, _back]:
		button.custom_minimum_size.y = 64 if mobile else 46
	_code.custom_minimum_size.y = 64 if mobile else 46
	_back.custom_minimum_size.x = 150 if mobile else 110


func _normalize_input(value: String) -> void:
	var normalized := value.strip_edges().to_upper().left(6)
	if normalized != value:
		var caret := _code.caret_column
		_code.text = normalized
		_code.caret_column = mini(caret, normalized.length())


func _set_busy(value: bool) -> void:
	_busy = value
	for button in [_join, _refresh, _continue, _back]:
		button.disabled = value
	_code.editable = not value


func _join_pressed() -> void:
	if _busy or _joined:
		return
	_set_busy(true)
	_status.text = "서버 참가 중입니다..."
	var result: Dictionary = await _service.join_room(_code.text.strip_edges().to_upper())
	_set_busy(false)
	if result.has("error"):
		_status.text = str(result.message)
		return
	var saved: bool = RoomManager.accept_joined_room(result.data, AuthManager.user_id)
	if not saved:
		_status.text = "로컬 저장에 실패했습니다. 저장 공간을 확인해 주세요."
		return
	get_tree().change_scene_to_file("res://episode_select.tscn")


func _update_profile_if_needed() -> void:
	var online: Dictionary = RoomManager.current_room.get("online_room", {})
	if not bool(online.get("needs_profile_setup", false)):
		return
	_status.text = "캐릭터 이름을 참가자 목록에 반영하는 중입니다..."
	var name := str(RoomManager.get_local_member().get("character_name", "")).strip_edges()
	var result: Dictionary = await _service.update_member_profile(str(online.get("room_id", "")), name)
	if result.has("error"):
		_status.text = str(result.get("message", "참가자 이름을 저장하지 못했습니다."))
		return
	online["needs_profile_setup"] = false
	RoomManager.current_room["online_room"] = online
	RoomManager.save_current_room()


func _show_room() -> void:
	_joined = true
	_form.hide()
	_refresh.show()
	_continue.show()
	var online: Dictionary = RoomManager.current_room.get("online_room", {})
	_info.text = "초대 코드: %s · %s\n참가자 목록 (최대 4명)" % [str(online.get("invite_code", "")), "방장" if bool(online.get("is_host", false)) else "참가자"]


func _refresh_members() -> void:
	if _busy or not _joined:
		return
	_set_busy(true)
	for child in _members.get_children():
		_members.remove_child(child)
		child.queue_free()
	_status.text = "참가자 목록을 불러오는 중입니다..."
	var online: Dictionary = RoomManager.current_room.get("online_room", {})
	var result: Dictionary = await _service.get_members(str(online.get("room_id", "")))
	_set_busy(false)
	if result.has("error"):
		_status.text = str(result.message)
		return
	var members: Array = result.data.duplicate(true)
	members.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.get("role") == "host" and b.get("role") != "host")
	for index in range(members.size()):
		var member: Dictionary = members[index]
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var role := "방장" if member.get("role") == "host" else "참가자 %d" % (index + 1)
		var display = member.get("display_name")
		var display_name: String = display.strip_edges() if display is String else ""
		label.text = role if display_name.is_empty() else "%s · %s" % [role, display_name.left(40)]
		if member.get("user_id") == AuthManager.user_id:
			label.text += " (나)"
		_members.add_child(label)
	_status.text = "참가자 %d / 4명" % members.size()


func _continue_pressed() -> void:
	if _busy or not _joined:
		return
	if not RoomManager.save_current_room():
		_status.text = "로컬 저장에 실패했습니다. 저장 공간을 확인하고 다시 시도해 주세요."
		return
	var state: Dictionary = RoomManager.get_game_state()
	var character_id := int(state.get("selected_character_id", 0))
	var scene := "res://episode_select.tscn"
	if character_id > 0:
		var member: Dictionary = RoomManager.get_local_member()
		GameData.selected_character_id = int(member.get("character_id", character_id))
		GameData.selected_name = str(member.get("character_name", ""))
		GameData.selected_portrait_path = str(member.get("portrait_path", ""))
		GameData.selected_personality = str(member.get("personality", ""))
		scene = str(state.get("scene_file", "res://main.tscn"))
	if get_tree().change_scene_to_file(scene) != OK:
		_status.text = "다음 화면을 열지 못했습니다. 다시 시도해 주세요."

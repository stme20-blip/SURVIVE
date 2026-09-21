extends Control

# Previous project Main Scene: uid://bvmk0k7hov8rd (res://start.tscn).
const ORIGINAL_START_SCENE := "res://start.tscn"
const PRETENDARD := preload("res://fonts/Pretendard-Regular.otf")

var _margin: MarginContainer
var _column: VBoxContainer
var _title: Label
var _subtitle: Label
var _notice: Label
var _status: Label
var _email: LineEdit
var _password: LineEdit
var _guest_button: Button
var _offline_button: Button
var _fields: Array[Control] = []
var _opening_game := false


func _ready() -> void:
	_create_ui()
	ScreenLayout.layout_changed.connect(_apply_layout)
	resized.connect(_apply_layout)
	_apply_layout()


func _create_ui() -> void:
	theme = Theme.new()
	theme.default_font = PRETENDARD
	theme.default_font_size = 18

	var background := ColorRect.new()
	background.color = Color("#090c10")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	scroll.name = "LoginScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_margin = MarginContainer.new()
	_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_margin)

	_column = VBoxContainer.new()
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_margin.add_child(_column)

	_title = _label("살아서 다시 만나자!")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle = _label("당신의 모든 선택이 생존을 결정하는 인터랙티브 스토리")
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_color_override("font_color", Color("#acb7c5"))

	_label("이메일")
	_email = LineEdit.new()
	_email.name = "EmailInput"
	_email.placeholder_text = "이메일 주소"
	_email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	_email.expand_to_text_length = false
	_column.add_child(_email)
	_fields.append(_email)

	_label("비밀번호")
	_password = LineEdit.new()
	_password.name = "PasswordInput"
	_password.placeholder_text = "비밀번호"
	_password.secret = true
	_password.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
	_password.expand_to_text_length = false
	_column.add_child(_password)
	_fields.append(_password)
	_email.text_submitted.connect(_on_email_submitted)
	_password.text_submitted.connect(_on_password_submitted)

	var auth_buttons := HBoxContainer.new()
	auth_buttons.add_theme_constant_override("separation", 12)
	_column.add_child(auth_buttons)
	_button("로그인", _on_login_pressed, auth_buttons)
	_button("회원가입", _on_signup_pressed, auth_buttons)

	var divider := HBoxContainer.new()
	_column.add_child(divider)
	for index in range(3):
		if index == 1:
			var or_label := Label.new()
			or_label.text = "또는"
			divider.add_child(or_label)
		else:
			var line := HSeparator.new()
			line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			divider.add_child(line)

	_guest_button = _button("비회원으로 플레이", _on_guest_pressed)
	_guest_button.name = "GuestButton"
	_status = _label("")
	_status.name = "Status"
	_status.add_theme_color_override("font_color", Color("#eac88b"))
	_offline_button = _button("로컬로만 플레이", _on_offline_pressed)
	_offline_button.hide()

	_notice = _label("")
	_notice.add_theme_color_override("font_color", Color("#acb7c5"))
	var storage_text := "※ 비회원 플레이 데이터는 현재 기기 및 브라우저에만 저장됩니다. 데이터가 삭제되거나 다른 기기를 사용할 경우 기존 데이터를 불러올 수 없습니다."
	_notice.text = storage_text + "\n\n※ 회원가입 후 플레이 데이터를 계정에 연동하여 안전하게 보관하고, PC와 모바일 등 다른 기기에서도 이어서 플레이할 수 있습니다. (비회원으로 플레이한 데이터도 계정 연동 가능)"


func _label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(label)
	return label


func _button(value: String, action: Callable, container: Container = null) -> Button:
	var button := Button.new()
	button.text = value
	button.pressed.connect(action)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if container != null:
		container.add_child(button)
	else:
		_column.add_child(button)
	_fields.append(button)
	return button


func _apply_layout() -> void:
	if not is_instance_valid(_column):
		return
	var mobile: bool = ScreenLayout.is_mobile_portrait()
	var target_width := 640.0 if mobile else 560.0
	var side_margin := int(maxf(24.0, (size.x - target_width) / 2.0))
	_margin.add_theme_constant_override("margin_left", side_margin)
	_margin.add_theme_constant_override("margin_right", side_margin)
	_margin.add_theme_constant_override("margin_top", 24)
	_margin.add_theme_constant_override("margin_bottom", 24)
	_column.add_theme_constant_override("separation", 14 if mobile else 8)
	theme.default_font_size = 28 if mobile else 18
	_title.add_theme_font_size_override("font_size", 52 if mobile else 36)
	_subtitle.add_theme_font_size_override("font_size", 24 if mobile else 16)
	_notice.add_theme_font_size_override("font_size", 24 if mobile else 16)
	_status.custom_minimum_size.y = 40 if mobile else 26
	for field in _fields:
		field.custom_minimum_size.y = 80 if mobile else 42


func _on_email_submitted(_text: String) -> void:
	_password.grab_focus()


func _on_password_submitted(_text: String) -> void:
	_on_login_pressed()


func _on_login_pressed() -> void:
	if _opening_game:
		return
	_status.text = AuthManager.sign_in(_email.text.strip_edges(), _password.text)
	_password.clear()


func _on_signup_pressed() -> void:
	if _opening_game:
		return
	_status.text = AuthManager.sign_up(_email.text.strip_edges(), _password.text)
	_password.clear()


func _on_guest_pressed() -> void:
	if _opening_game:
		return
	_opening_game = true
	_set_auth_busy(true)
	_offline_button.hide()
	_status.text = "비회원 인증 중입니다..."
	_password.clear()
	var auth_error: String = await AuthManager.enter_guest_mode()
	if not auth_error.is_empty():
		_opening_game = false
		_set_auth_busy(false)
		_status.text = auth_error
		_offline_button.show()
		return
	_open_start_scene()


func _on_offline_pressed() -> void:
	if _opening_game:
		return
	_opening_game = true
	AuthManager.enter_local_guest_mode()
	_open_start_scene()


func _set_auth_busy(busy: bool) -> void:
	for field in _fields:
		if field is Button:
			field.disabled = busy
		elif field is LineEdit:
			field.editable = not busy


func _open_start_scene() -> void:
	var error := get_tree().change_scene_to_file(ORIGINAL_START_SCENE)
	if error != OK:
		_opening_game = false
		_set_auth_busy(false)
		_status.text = "시작 화면을 열 수 없습니다. 다시 시도해 주세요."

extends CanvasLayer

const TRAITS := preload("res://personality_select.gd").PERSONALITIES
const PORTRAIT_PICKER := preload("res://custom_character.gd")

var _root: Control
var _gear: Button
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
	_create_modal()
	ScreenLayout.layout_changed.connect(_layout)
	_root.resized.connect(_layout)
	get_tree().scene_changed.connect(_layout)
	_layout()


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
	_form.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_form.add_theme_constant_override("separation", 10)
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
	if not _gear.visible and _modal.visible:
		close_settings()
	if scene != null and scene.scene_file_path == "res://main.tscn" and not mobile:
		right_inset += maxf(0.0, _root.size.x - 1152.0)
	_gear.offset_left = -button_size - right_inset
	_gear.offset_right = -right_inset
	_gear.offset_top = 12
	_gear.offset_bottom = button_size + 12
	_root.theme.default_font_size = 24 if mobile else 18
	var side := int(maxf(24, (_root.size.x - (640 if mobile else 580)) / 2.0))
	_margin.add_theme_constant_override("margin_left", side)
	_margin.add_theme_constant_override("margin_right", side)
	_margin.add_theme_constant_override("margin_top", 24)
	_margin.add_theme_constant_override("margin_bottom", 24)
	_portrait.custom_minimum_size = Vector2(120, 148) if mobile else Vector2(90, 112)
	for control in [_name, _portrait_button, _traits, _save_button, _cancel_button]:
		control.custom_minimum_size.y = 60 if mobile else 40


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
	_gear.grab_focus()


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

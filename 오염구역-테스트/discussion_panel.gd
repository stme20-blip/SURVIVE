extends Control


# =========================================================
# 토론 UI
# =========================================================

var panel: Panel

var feed_scroll: ScrollContainer
var feed_container: VBoxContainer

var message_input: LineEdit
var submit_button: Button
var download_button: Button

var editing_comment_id: String = ""


# =========================================================
# PC 오른쪽 고정 영역
# =========================================================

const PANEL_POSITION := Vector2(
	1152,
	0
)

const PANEL_SIZE := Vector2(
	384,
	648
)


# =========================================================
# 시작
# =========================================================

func _ready() -> void:

	z_index = 50

	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	_create_ui()
	apply_desktop_layout()

	if not RoomManager.feed_changed.is_connected(
		_on_feed_changed
	):

		RoomManager.feed_changed.connect(
			_on_feed_changed
		)

	_refresh_feed()


# =========================================================
# 댓글 데이터 변경
# =========================================================

func _on_feed_changed() -> void:

	# 댓글 목록은 2초마다 동기화된다. 편집 입력창을 다시 만들면 서버의
	# 기존 본문이 입력 중인 글을 덮어쓰므로, 편집이 끝날 때까지는 보류한다.
	if not editing_comment_id.is_empty():
		return

	_refresh_feed()


# =========================================================
# PC 배치
# =========================================================

func apply_desktop_layout() -> void:

	visible = true

	panel.position = (
		PANEL_POSITION
	)

	panel.size = (
		PANEL_SIZE
	)


# =========================================================
# UI
# =========================================================

func _create_ui() -> void:

	panel = Panel.new()
	add_child(panel)

	panel.position = PANEL_POSITION
	panel.size = PANEL_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.042, 0.05, 1.0)
	panel_style.border_color = Color(0.25, 0.30, 0.34, 1.0)
	panel_style.border_width_left = 2
	panel.add_theme_stylebox_override("panel", panel_style)

	var title := Label.new()
	panel.add_child(title)
	title.position = Vector2(20, 18)
	title.size = Vector2(344, 38)
	title.text = "생존 기록"
	title.add_theme_font_size_override("font_size", 22)

	download_button = Button.new()
	panel.add_child(download_button)
	download_button.position = Vector2(244, 16)
	download_button.size = Vector2(120, 34)
	download_button.text = "기록 다운로드"
	download_button.add_theme_font_size_override("font_size", 12)
	download_button.pressed.connect(_on_download_transcript_pressed)

	var subtitle := Label.new()
	panel.add_child(subtitle)
	subtitle.position = Vector2(20, 54)
	subtitle.size = Vector2(344, 25)
	subtitle.text = "서버에서 작성한 모든 댓글이 기록됩니다."
	subtitle.modulate = Color(0.65, 0.68, 0.72, 1.0)
	subtitle.add_theme_font_size_override("font_size", 12)

	var separator := HSeparator.new()
	panel.add_child(separator)
	separator.position = Vector2(20, 88)
	separator.size = Vector2(344, 4)

	feed_scroll = ScrollContainer.new()
	panel.add_child(feed_scroll)
	feed_scroll.position = Vector2(20, 105)
	feed_scroll.size = Vector2(344, 455)

	feed_container = VBoxContainer.new()
	feed_scroll.add_child(feed_container)
	feed_container.custom_minimum_size = Vector2(325, 0)
	feed_container.add_theme_constant_override("separation", 10)

	message_input = LineEdit.new()
	panel.add_child(message_input)
	# Web export uses an HTML input overlay on touch devices. Explicitly keep
	# the virtual keyboard enabled for the survival-record composer.
	message_input.virtual_keyboard_enabled = true
	message_input.virtual_keyboard_show_on_focus = true
	message_input.position = Vector2(20, 582)
	message_input.size = Vector2(270, 42)
	message_input.placeholder_text = "대사 또는 기록 입력"
	message_input.text_submitted.connect(_on_message_submitted)

	submit_button = Button.new()
	panel.add_child(submit_button)
	submit_button.position = Vector2(298, 582)
	submit_button.size = Vector2(66, 42)
	submit_button.text = "등록"
	submit_button.pressed.connect(_on_submit_button_pressed)


# =========================================================
# 새 댓글
# =========================================================

func _on_message_submitted(
	_text: String
) -> void:

	message_input.apply_ime()
	call_deferred("_submit_comment_after_ime")


func _on_submit_button_pressed() -> void:

	message_input.apply_ime()
	call_deferred("_submit_comment_after_ime")


func _submit_comment_after_ime() -> void:

	var message: String = (
		message_input.text.strip_edges()
	)

	if message.is_empty():
		return

	if not RoomManager.has_room():
		return

	message_input.clear()

	await CommentSync.submit(
		GameData.selected_name,
		message
	)

	message_input.grab_focus()


# =========================================================
# 댓글 새로고침
# =========================================================

func _refresh_feed() -> void:

	if feed_container == null:
		return

	for child in feed_container.get_children():
		feed_container.remove_child(child)
		child.queue_free()

	if not RoomManager.has_room():
		_add_empty_message("현재 방이 없습니다.")
		return

	var feed: Array = RoomManager.get_feed()

	if feed.is_empty():
		_add_empty_message("아직 작성한 기록이 없습니다.")
		return

	var previous_scene_title: String = ""

	for entry in feed:

		var scene_title: String = str(
			entry.get("scene_title", "")
		)

		if (
			not scene_title.is_empty()
			and scene_title != previous_scene_title
		):
			_add_scene_header(scene_title)
			previous_scene_title = scene_title

		_add_comment_entry(entry)

	if editing_comment_id.is_empty():
		call_deferred("_scroll_to_bottom")


func _scroll_to_bottom() -> void:

	await get_tree().process_frame

	if feed_scroll == null:
		return

	var scroll_bar := feed_scroll.get_v_scroll_bar()
	feed_scroll.scroll_vertical = int(scroll_bar.max_value)


# =========================================================
# 장면 제목
# =========================================================

func _add_scene_header(
	scene_title: String
) -> void:

	var label := Label.new()
	feed_container.add_child(label)

	label.text = "[ " + scene_title + " ]"
	label.add_theme_font_size_override("font_size", 13)
	label.modulate = Color(0.62, 0.70, 0.76, 1.0)


# =========================================================
# 댓글 하나
# =========================================================

func _add_comment_entry(
	entry: Dictionary
) -> void:

	var comment_id: String = str(
		entry.get("comment_id", "")
	)

	var speaker: String = str(
		entry.get("speaker", "")
	)

	var text: String = str(
		entry.get("text", "")
	)

	var box := VBoxContainer.new()
	feed_container.add_child(box)
	box.add_theme_constant_override("separation", 4)

	var header := HBoxContainer.new()
	box.add_child(header)

	var speaker_label := Label.new()
	header.add_child(speaker_label)
	speaker_label.text = speaker
	speaker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speaker_label.add_theme_font_size_override("font_size", 13)
	speaker_label.modulate = Color(0.78, 0.81, 0.84, 1.0)

	if (
		RoomManager.can_edit_comment(entry)
		and editing_comment_id != comment_id
	):
		var actions := HBoxContainer.new()
		header.add_child(actions)
		actions.add_theme_constant_override("separation", 0)
		actions.size_flags_horizontal = Control.SIZE_SHRINK_END

		var edit_button := Button.new()
		actions.add_child(edit_button)
		edit_button.text = "수정"
		edit_button.flat = true
		edit_button.custom_minimum_size = Vector2(30, 24)
		edit_button.add_theme_font_size_override("font_size", 11)
		edit_button.pressed.connect(
			_on_edit_pressed.bind(comment_id)
		)
		var delete_button := Button.new()
		actions.add_child(delete_button)
		delete_button.text = "삭제"
		delete_button.flat = true
		delete_button.custom_minimum_size = Vector2(30, 24)
		delete_button.add_theme_font_size_override("font_size", 11)
		delete_button.pressed.connect(_on_delete_pressed.bind(comment_id))

	if editing_comment_id == comment_id:
		var edit_input := LineEdit.new()
		box.add_child(edit_input)
		edit_input.virtual_keyboard_enabled = true
		edit_input.virtual_keyboard_show_on_focus = true
		edit_input.text = text
		edit_input.custom_minimum_size = Vector2(0, 38)
		edit_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit_input.expand_to_text_length = false
		var edit_style := StyleBoxFlat.new()
		edit_style.bg_color = Color("#121212")
		edit_style.border_color = Color(1, 1, 1, 0.35)
		edit_style.set_border_width_all(1)
		edit_style.content_margin_left = 8
		edit_style.content_margin_right = 8
		edit_input.add_theme_stylebox_override("normal", edit_style)
		var focus_style := edit_style.duplicate() as StyleBoxFlat
		focus_style.draw_center = false
		focus_style.border_color = Color(1, 1, 1, 0.7)
		edit_input.add_theme_stylebox_override("focus", focus_style)

		var button_row := HBoxContainer.new()
		box.add_child(button_row)
		button_row.alignment = BoxContainer.ALIGNMENT_END

		var save_button := Button.new()
		button_row.add_child(save_button)
		save_button.text = "저장"
		save_button.pressed.connect(
			_on_edit_save_pressed.bind(comment_id, edit_input)
		)

		var cancel_button := Button.new()
		button_row.add_child(cancel_button)
		cancel_button.text = "취소"
		cancel_button.pressed.connect(_on_edit_cancel_pressed)

		call_deferred("_focus_edit_input", edit_input)
		return

	var message_label := Label.new()
	box.add_child(message_label)
	message_label.text = text
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size.x = 315
	message_label.add_theme_font_size_override("font_size", 15)


# =========================================================
# 댓글 수정
# =========================================================

func _on_edit_pressed(
	comment_id: String
) -> void:

	editing_comment_id = comment_id
	_refresh_feed()


func _focus_edit_input(
	edit_input: LineEdit
) -> void:

	if not is_instance_valid(edit_input):
		return

	edit_input.grab_focus()
	# 기존 문장을 바로 이어 고칠 수 있도록 커서를 마지막에 둔다.
	edit_input.caret_column = edit_input.text.length()


func _on_edit_save_pressed(
	comment_id: String,
	edit_input: LineEdit
) -> void:

	if not is_instance_valid(edit_input):
		return

	edit_input.apply_ime()

	call_deferred(
		"_save_edit_after_ime",
		comment_id,
		edit_input
	)


func _save_edit_after_ime(
	comment_id: String,
	edit_input: LineEdit
) -> void:

	if not is_instance_valid(edit_input):
		return

	var new_text: String = edit_input.text.strip_edges()

	if new_text.is_empty():
		return

	editing_comment_id = ""

	await CommentSync.edit(
		comment_id,
		new_text
	)


func _on_edit_cancel_pressed() -> void:

	editing_comment_id = ""
	_refresh_feed()


func _on_delete_pressed(comment_id: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "기록 삭제"
	dialog.dialog_text = "기록을 삭제하시겠습니까?\n복구할 수 없습니다."
	dialog.ok_button_text = "삭제"
	dialog.cancel_button_text = "취소"
	dialog.min_size = Vector2(360, 170)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#202225")
	style.border_color = Color(1, 1, 1, 0.32)
	style.set_border_width_all(1)
	style.set_content_margin_all(20)
	dialog.add_theme_stylebox_override("panel", style)
	dialog.add_theme_font_size_override("title_font_size", 22)
	add_child(dialog)
	dialog.confirmed.connect(func(): CommentSync.delete_comment(comment_id))
	dialog.close_requested.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()


# =========================================================
# 플레이 기록 다운로드
# =========================================================

func _on_download_transcript_pressed() -> void:

	if not RoomManager.has_room():
		return


	var transcript_text: String = (
		RoomManager.build_transcript_text()
	)


	if transcript_text.is_empty():
		return


	var room_name: String = str(
		RoomManager.current_room.get(
			"room_name",
			"play"
		)
	)


	room_name = (
		_sanitize_download_file_name(
			room_name
		)
	)


	var file_name := (
		"오염구역_"
		+ room_name
		+ "_플레이기록.txt"
	)


	if OS.has_feature(
		"web"
	):

		JavaScriptBridge.download_buffer(
			transcript_text.to_utf8_buffer(),
			file_name,
			"text/plain;charset=utf-8"
		)

		return


	# PC에서 F5/F6로 테스트할 때는 기존 user://exports 저장 사용
	var saved_path: String = (
		RoomManager.export_transcript_txt()
	)


	if not saved_path.is_empty():

		print(
			"플레이 기록 저장: ",
			ProjectSettings.globalize_path(
				saved_path
			)
		)


func _sanitize_download_file_name(
	file_name: String
) -> String:

	var result := file_name


	var invalid_chars := [
		"\\",
		"/",
		":",
		"*",
		"?",
		"\"",
		"<",
		">",
		"|"
	]


	for invalid_char in invalid_chars:

		result = result.replace(
			invalid_char,
			"_"
		)


	if result.strip_edges().is_empty():
		return "play"


	return result.strip_edges()


# =========================================================
# 비어 있을 때
# =========================================================

func _add_empty_message(
	message: String
) -> void:

	var label := Label.new()
	feed_container.add_child(label)

	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(325, 80)
	label.modulate = Color(0.6, 0.63, 0.66, 1.0)

extends Control

signal portrait_image_selected(image: Image)
var portrait_picker_only: bool = false


# =========================================================
# 커스텀 초상화 저장 설정
# =========================================================

const PORTRAIT_DIR := (
	"user://custom_portraits/"
)

const MAX_IMAGE_SIDE := 1024

const MAX_WEB_FILE_SIZE := (
	8 * 1024 * 1024
)


# =========================================================
# 선택 데이터
# =========================================================

var selected_portrait_path: String = ""

var selected_portrait_texture: Texture2D = null


# =========================================================
# UI
# =========================================================

var main_box: VBoxContainer

var title_label: Label
var subtitle_label: Label

var portrait_center: CenterContainer
var portrait_panel: Panel
var portrait_texture: TextureRect

var image_button: Button
var portrait_choice_dialog: AcceptDialog

var name_title: Label
var name_input: LineEdit

var status_label: Label

var bottom_buttons: HBoxContainer

var back_button: Button
var next_button: Button


# =========================================================
# 데스크톱 파일 선택
# =========================================================

var file_dialog: FileDialog


# =========================================================
# Web 파일 선택
#
# 브라우저의 <input type="file"> 사용
# =========================================================

var web_file_input = null

var web_change_callback = null

var web_reader = null

var web_reader_callback = null


# =========================================================
# 시작
# =========================================================

func _ready() -> void:
	if portrait_picker_only:
		status_label = Label.new()
		status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(status_label)
		status_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_create_file_dialog()
		_create_portrait_choice_dialog()
		if OS.has_feature("web"):
			_setup_web_file_picker()
		return

	_create_ui()

	_create_file_dialog()
	_create_portrait_choice_dialog()


	if OS.has_feature(
		"web"
	):

		_setup_web_file_picker()


	if not ScreenLayout.layout_changed.is_connected(
		_on_layout_changed
	):

		ScreenLayout.layout_changed.connect(
			_on_layout_changed
		)


	call_deferred(
		"_apply_responsive_layout"
	)


# =========================================================
# 레이아웃 변경
# =========================================================

func _on_layout_changed() -> void:

	call_deferred(
		"_apply_responsive_layout"
	)


# =========================================================
# UI 생성
# =========================================================

func _create_ui() -> void:

	# =====================================================
	# 배경
	# =====================================================

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


	# =====================================================
	# 메인
	# =====================================================

	main_box = VBoxContainer.new()

	add_child(
		main_box
	)


	main_box.add_theme_constant_override(
		"separation",
		16
	)


	# =====================================================
	# 제목
	# =====================================================

	title_label = Label.new()

	main_box.add_child(
		title_label
	)


	title_label.text = (
		"당신의 이름은 무엇입니까?"
	)


	title_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	# =====================================================
	# 부제
	# =====================================================

	subtitle_label = Label.new()

	main_box.add_child(
		subtitle_label
	)


	subtitle_label.text = (
		"이름과 초상화를 직접 설정하세요."
	)


	subtitle_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	subtitle_label.modulate = Color(
		0.70,
		0.73,
		0.78,
		1.0
	)


	# =====================================================
	# 초상화 가운데 정렬
	# =====================================================

	portrait_center = CenterContainer.new()

	main_box.add_child(
		portrait_center
	)


	portrait_center.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)


	# =====================================================
	# 초상화 프레임
	# =====================================================

	portrait_panel = Panel.new()

	portrait_center.add_child(
		portrait_panel
	)


	var portrait_style := StyleBoxFlat.new()


	portrait_style.bg_color = Color(
		0.035,
		0.040,
		0.045,
		1.0
	)


	portrait_style.border_color = Color(
		0.28,
		0.31,
		0.34,
		1.0
	)


	portrait_style.border_width_left = 1
	portrait_style.border_width_top = 1
	portrait_style.border_width_right = 1
	portrait_style.border_width_bottom = 1


	portrait_style.corner_radius_top_left = 4
	portrait_style.corner_radius_top_right = 4
	portrait_style.corner_radius_bottom_left = 4
	portrait_style.corner_radius_bottom_right = 4


	portrait_panel.add_theme_stylebox_override(
		"panel",
		portrait_style
	)


	# =====================================================
	# 초상화 이미지
	# =====================================================

	portrait_texture = TextureRect.new()

	portrait_panel.add_child(
		portrait_texture
	)


	portrait_texture.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)


	portrait_texture.offset_left = 6
	portrait_texture.offset_top = 6
	portrait_texture.offset_right = -6
	portrait_texture.offset_bottom = -6


	portrait_texture.expand_mode = (
		TextureRect.EXPAND_IGNORE_SIZE
	)


	# 업로드한 이미지를 자르지 않음
	portrait_texture.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)


	portrait_texture.texture_filter = (
		CanvasItem.TEXTURE_FILTER_LINEAR
	)


	# =====================================================
	# 이미지 선택 버튼
	# =====================================================

	image_button = Button.new()
	image_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	main_box.add_child(
		image_button
	)


	image_button.text = (
		"초상화 이미지 선택"
	)


	image_button.pressed.connect(
		_on_image_button_pressed
	)


	# =====================================================
	# 이름
	# =====================================================

	name_title = Label.new()

	main_box.add_child(
		name_title
	)


	name_title.text = "이름"
	name_title.hide()


	name_input = LineEdit.new()

	main_box.add_child(
		name_input
	)


	name_input.placeholder_text = (
		"캐릭터 이름을 입력하세요."
	)


	name_input.max_length = 20


	name_input.text_changed.connect(
		_on_name_changed
	)


	# =====================================================
	# 상태
	# =====================================================

	status_label = Label.new()

	main_box.add_child(
		status_label
	)


	status_label.text = ""


	status_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	status_label.modulate = Color(
		0.68,
		0.71,
		0.75,
		1.0
	)


	# =====================================================
	# 하단
	# =====================================================

	bottom_buttons = HBoxContainer.new()

	main_box.add_child(
		bottom_buttons
	)


	bottom_buttons.add_theme_constant_override(
		"separation",
		12
	)


	# -----------------------------------------------------
	# 이전
	# -----------------------------------------------------

	back_button = Button.new()

	bottom_buttons.add_child(
		back_button
	)


	back_button.text = "이전"


	back_button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)


	back_button.pressed.connect(
		_on_back_pressed
	)


	# -----------------------------------------------------
	# 다음
	# -----------------------------------------------------

	next_button = Button.new()

	bottom_buttons.add_child(
		next_button
	)


	next_button.text = (
		"다음"
	)


	next_button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)


	next_button.disabled = true


	next_button.pressed.connect(
		_on_next_pressed
	)


# =========================================================
# 데스크톱 FileDialog
# =========================================================

func _create_file_dialog() -> void:

	file_dialog = FileDialog.new()

	add_child(
		file_dialog
	)


	file_dialog.file_mode = (
		FileDialog.FILE_MODE_OPEN_FILE
	)


	file_dialog.access = (
		FileDialog.ACCESS_FILESYSTEM
	)


	file_dialog.filters = PackedStringArray([
		"*.png,*.jpg,*.jpeg,*.webp ; 이미지 파일"
	])


	file_dialog.file_selected.connect(
		_on_desktop_file_selected
	)


# =========================================================
# 이미지 선택
# =========================================================

func _on_image_button_pressed() -> void:
	portrait_choice_dialog.popup_centered(
		Vector2i(440, 210) if ScreenLayout.is_mobile_portrait() else Vector2i(340, 170)
	)


func _create_portrait_choice_dialog() -> void:
	portrait_choice_dialog = AcceptDialog.new()
	portrait_choice_dialog.title = "초상화 선택"
	portrait_choice_dialog.ok_button_text = "취소"
	add_child(portrait_choice_dialog)
	var choices := VBoxContainer.new()
	choices.add_theme_constant_override("separation", 12)
	portrait_choice_dialog.add_child(choices)
	var upload_button := Button.new()
	upload_button.text = "파일 업로드"
	upload_button.custom_minimum_size.y = 56
	upload_button.pressed.connect(_on_upload_portrait_pressed)
	choices.add_child(upload_button)
	var without_portrait_button := Button.new()
	without_portrait_button.text = "초상화 미설정"
	without_portrait_button.custom_minimum_size.y = 56
	without_portrait_button.pressed.connect(_on_without_portrait_pressed)
	choices.add_child(without_portrait_button)


func _on_without_portrait_pressed() -> void:
	portrait_choice_dialog.hide()
	var image := preload("res://default_portrait.svg").get_image()
	_accept_portrait_image(image)


func _on_upload_portrait_pressed() -> void:
	portrait_choice_dialog.hide()

	# =====================================================
	# Web
	# =====================================================

	if OS.has_feature(
		"web"
	):

		if web_file_input == null:

			_setup_web_file_picker()


		if web_file_input == null:

			status_label.text = (
				"브라우저 이미지 선택기를 열 수 없습니다."
			)

			return


		# 같은 파일을 다시 선택해도
		# change 이벤트가 발생하도록 초기화
		web_file_input.value = ""

		web_file_input.click()

		return


	# =====================================================
	# Windows 등
	# =====================================================

	file_dialog.popup_centered_ratio(
		0.75
	)


# =========================================================
# Web 파일 선택기 준비
# =========================================================

func _setup_web_file_picker() -> void:

	if not OS.has_feature(
		"web"
	):
		return


	var document = (
		JavaScriptBridge.get_interface(
			"document"
		)
	)


	if document == null:
		return


	web_file_input = (
		document.createElement(
			"input"
		)
	)


	web_file_input.type = "file"


	web_file_input.accept = (
		"image/png,image/jpeg,image/webp"
	)


	web_change_callback = (
		JavaScriptBridge.create_callback(
			_on_web_file_changed
		)
	)


	web_file_input.addEventListener(
		"change",
		web_change_callback
	)


# =========================================================
# Web 파일 선택됨
# =========================================================

func _on_web_file_changed(
	_args: Array
) -> void:

	if web_file_input == null:
		return


	if int(
		web_file_input.files.length
	) <= 0:
		return


	var selected_file = (
		web_file_input.files[0]
	)


	if int(
		selected_file.size
	) > MAX_WEB_FILE_SIZE:

		status_label.text = (
			"이미지는 8MB 이하로 선택하세요."
		)

		return


	web_reader = (
		JavaScriptBridge.create_object(
			"FileReader"
		)
	)


	if web_reader == null:

		status_label.text = (
			"이미지를 읽을 수 없습니다."
		)

		return


	web_reader_callback = (
		JavaScriptBridge.create_callback(
			_on_web_reader_loaded
		)
	)


	web_reader.addEventListener(
		"load",
		web_reader_callback
	)


	web_reader.readAsArrayBuffer(
		selected_file
	)


	status_label.text = (
		"이미지를 불러오는 중..."
	)


# =========================================================
# Web 이미지 데이터 읽기 완료
# =========================================================

func _on_web_reader_loaded(
	_args: Array
) -> void:

	if web_reader == null:
		return


	var byte_array = (
		JavaScriptBridge.create_object(
			"Uint8Array",
			web_reader.result
		)
	)


	if byte_array == null:

		status_label.text = (
			"이미지 데이터를 읽지 못했습니다."
		)

		return


	var data_size := int(
		byte_array.length
	)


	var buffer := PackedByteArray()

	buffer.resize(
		data_size
	)


	for index in range(
		data_size
	):

		buffer[index] = int(
			byte_array[index]
		)


	var image := Image.new()

	var error := (
		ERR_FILE_UNRECOGNIZED
	)


	var mime_type := ""


	if (
		web_file_input != null
		and int(
			web_file_input.files.length
		) > 0
	):

		mime_type = str(
			web_file_input.files[0].type
		)


	match mime_type:

		"image/png":

			error = (
				image.load_png_from_buffer(
					buffer
				)
			)


		"image/jpeg":

			error = (
				image.load_jpg_from_buffer(
					buffer
				)
			)


		"image/webp":

			error = (
				image.load_webp_from_buffer(
					buffer
				)
			)


		_:

			# MIME이 없는 브라우저를 위한 순차 시도
			error = (
				image.load_png_from_buffer(
					buffer
				)
			)


			if error != OK:

				error = (
					image.load_jpg_from_buffer(
						buffer
					)
				)


			if error != OK:

				error = (
					image.load_webp_from_buffer(
						buffer
					)
				)


	if error != OK:

		status_label.text = (
			"지원하지 않는 이미지입니다."
		)

		return


	_accept_portrait_image(
		image
	)


# =========================================================
# PC 이미지 선택 완료
# =========================================================

func _on_desktop_file_selected(
	path: String
) -> void:

	var image := Image.load_from_file(
		path
	)


	if image == null:

		status_label.text = (
			"이미지를 불러오지 못했습니다."
		)

		return


	if image.is_empty():

		status_label.text = (
			"이미지를 불러오지 못했습니다."
		)

		return


	_accept_portrait_image(
		image
	)


# =========================================================
# 이미지 저장 / 미리보기
# =========================================================

func _accept_portrait_image(
	image: Image
) -> void:

	if image == null:
		return


	if image.is_empty():
		return
	if portrait_picker_only:
		portrait_image_selected.emit(image)
		return


	# =====================================================
	# 이미지 크기 확인
	# =====================================================

	var image_width: int = image.get_width()
	var image_height: int = image.get_height()

	var longest_side: int = 0


	if image_width >= image_height:

		longest_side = image_width

	else:

		longest_side = image_height


	# =====================================================
	# 너무 큰 이미지는 비율 유지해서 축소
	# =====================================================

	if longest_side > MAX_IMAGE_SIDE:

		var scale_ratio: float = (
			float(MAX_IMAGE_SIDE)
			/ float(longest_side)
		)


		var new_width: int = int(
			float(image_width)
			* scale_ratio
		)


		var new_height: int = int(
			float(image_height)
			* scale_ratio
		)


		if new_width < 1:
			new_width = 1


		if new_height < 1:
			new_height = 1


		image.resize(
			new_width,
			new_height,
			Image.INTERPOLATE_LANCZOS
		)


	# =====================================================
	# 저장 폴더 생성
	# =====================================================

	_ensure_portrait_directory()


	# =====================================================
	# 저장 파일명
	# =====================================================

	var room_id: String = (
		RoomManager.get_current_room_id()
	)


	if room_id.is_empty():

		room_id = str(
			int(
				Time.get_unix_time_from_system()
				* 1000.0
			)
		)


	var path: String = (
		PORTRAIT_DIR
		+ "custom_"
		+ room_id
		+ ".png"
	)


	# =====================================================
	# PNG 저장
	# =====================================================

	var error: Error = (
		image.save_png(
			path
		)
	)


	if error != OK:

		status_label.text = (
			"초상화 저장에 실패했습니다."
		)

		return


	# =====================================================
	# 선택 정보 저장
	# =====================================================

	selected_portrait_path = path


	selected_portrait_texture = (
		ImageTexture.create_from_image(
			image
		)
	)


	# =====================================================
	# 미리보기
	# =====================================================

	portrait_texture.texture = (
		selected_portrait_texture
	)


	status_label.text = (
		"초상화가 설정되었습니다."
	)


	_update_next_button()


# =========================================================
# 초상화 폴더
# =========================================================

func _ensure_portrait_directory() -> void:

	var absolute_path := (
		ProjectSettings.globalize_path(
			PORTRAIT_DIR
		)
	)


	if DirAccess.dir_exists_absolute(
		absolute_path
	):
		return


	DirAccess.make_dir_recursive_absolute(
		absolute_path
	)


# =========================================================
# 이름 변경
# =========================================================

func _on_name_changed(
	_text: String
) -> void:

	_update_next_button()


# =========================================================
# 다음 버튼 상태
# =========================================================

func _update_next_button() -> void:

	var has_name := (
		not name_input.text
			.strip_edges()
			.is_empty()
	)


	var has_portrait := (
		not selected_portrait_path.is_empty()
	)


	next_button.disabled = not (
		has_name
		and has_portrait
	)


# =========================================================
# 다음
# =========================================================

func _on_next_pressed() -> void:

	var character_name := (
		name_input.text.strip_edges()
	)


	if character_name.is_empty():
		return


	if selected_portrait_path.is_empty():
		return


	GameData.set_character_identity(
		GameData.CUSTOM_CHARACTER_ID,
		character_name,
		selected_portrait_path,
		true
	)


	get_tree().change_scene_to_file(
		"res://personality_select.tscn"
	)


# =========================================================
# 이전
# =========================================================

func _on_back_pressed() -> void:

	get_tree().change_scene_to_file(
		"res://character_select.tscn"
	)


# =========================================================
# 반응형
# =========================================================

func _apply_responsive_layout() -> void:

	var viewport_size := (
		get_viewport_rect().size
	)


	# =====================================================
	# 모바일
	# =====================================================

	if ScreenLayout.is_mobile_portrait():

		main_box.size = Vector2(
			viewport_size.x - 48,
			560
		)


		main_box.position = Vector2(
			24,
			40
		)


		title_label.add_theme_font_size_override(
			"font_size",
			32
		)


		subtitle_label.add_theme_font_size_override(
			"font_size",
			20
		)


		portrait_panel.custom_minimum_size = Vector2(
			150,
			190
		)


		image_button.custom_minimum_size = Vector2(
			240,
			56
		)


		image_button.add_theme_font_size_override(
			"font_size",
			19
		)


		name_title.add_theme_font_size_override(
			"font_size",
			18
		)


		name_input.custom_minimum_size = Vector2(
			0,
			56
		)


		name_input.add_theme_font_size_override(
			"font_size",
			20
		)


		status_label.add_theme_font_size_override(
			"font_size",
			17
		)


		back_button.custom_minimum_size = Vector2(
			0,
			58
		)


		next_button.custom_minimum_size = Vector2(
			0,
			58
		)


		back_button.add_theme_font_size_override(
			"font_size",
			19
		)


		next_button.add_theme_font_size_override(
			"font_size",
			19
		)


	# =====================================================
	# PC
	# =====================================================

	else:

		main_box.size = Vector2(
			620,
			520
		)


		main_box.position = Vector2(
			(
				viewport_size.x
				- main_box.size.x
			) / 2.0,
			55
		)


		title_label.add_theme_font_size_override(
			"font_size",
			30
		)


		subtitle_label.add_theme_font_size_override(
			"font_size",
			16
		)


		portrait_panel.custom_minimum_size = Vector2(
			145,
			180
		)


		image_button.custom_minimum_size = Vector2(
			200,
			48
		)


		image_button.add_theme_font_size_override(
			"font_size",
			16
		)


		name_title.add_theme_font_size_override(
			"font_size",
			15
		)


		name_input.custom_minimum_size = Vector2(
			0,
			48
		)


		name_input.add_theme_font_size_override(
			"font_size",
			17
		)


		status_label.add_theme_font_size_override(
			"font_size",
			14
		)


		back_button.custom_minimum_size = Vector2(
			0,
			50
		)


		next_button.custom_minimum_size = Vector2(
			0,
			50
		)


		back_button.add_theme_font_size_override(
			"font_size",
			16
		)


		next_button.add_theme_font_size_override(
			"font_size",
			16
		)

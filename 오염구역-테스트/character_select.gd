extends Control


# =========================================================
# 선택 상태
# =========================================================

var selected_index: int = -1

var character_buttons: Array[Button] = []
var portrait_nodes: Array[TextureRect] = []
var name_labels: Array[Label] = []

var main_box: VBoxContainer
var card_container: GridContainer

var title_label: Label
var subtitle_label: Label

var description_label: Label

var confirm_button: Button
var custom_button: Button


# =========================================================
# 다음 단계
# =========================================================

const PERSONALITY_SELECT_SCENE := (
	"res://personality_select.tscn"
)

const CUSTOM_CHARACTER_SCENE := (
	"res://custom_character.tscn"
)


# =========================================================
# 기본 캐릭터 12명
#
# PC
# 1  2  3  4  5  6
# 7  8  9 10 11 12
#
# 모바일
# 2열 × 6줄
# =========================================================

var characters := [

	{
		"id": 1,
		"name": "김솔음",
		"portrait": "res://kim_soleum_portrait.png"
	},

	{
		"id": 2,
		"name": "백사헌",
		"portrait": "res://baek_saheon_portrait.png"
	},

	{
		"id": 3,
		"name": "고영은",
		"portrait": "res://player_portrait.png"
	},

	{
		"id": 4,
		"name": "은하제",
		"portrait": "res://player_portrait.png"
	},

	{
		"id": 5,
		"name": "박민성",
		"portrait": "res://player_portrait.png"
	},

	{
		"id": 6,
		"name": "이자헌",
		"portrait": "res://player_portrait.png"
	},

	{
		"id": 7,
		"name": "이성해",
		"portrait": "res://player_portrait.png"
	},

	{
		"id": 8,
		"name": "진나솔",
		"portrait": "res://player_portrait.png"
	},

	{
		"id": 9,
		"name": "J3",
		"portrait": "res://player_portrait.png"
	},

	{
		"id": 10,
		"name": "곽제강",
		"portrait": "res://player_portrait.png"
	},

	{
		"id": 11,
		"name": "최 요원",
		"portrait": "res://player_portrait.png"
	},

	{
		"id": 12,
		"name": "류재관",
		"portrait": "res://player_portrait.png"
	}
]


# =========================================================
# 시작
# =========================================================

func _ready() -> void:

	_create_ui()


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
# 화면 변경
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
		10
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
	# 설명
	# =====================================================

	subtitle_label = Label.new()

	main_box.add_child(
		subtitle_label
	)


	subtitle_label.text = (
		"플레이할 인물을 선택하세요."
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
	# 캐릭터 Grid
	#
	# 스크롤 없음.
	# 카드 가로 최소폭 없음.
	# Grid가 자동으로 동일한 폭으로 나눔.
	# =====================================================

	card_container = GridContainer.new()

	main_box.add_child(
		card_container
	)


	card_container.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)


	card_container.add_theme_constant_override(
		"h_separation",
		10
	)


	card_container.add_theme_constant_override(
		"v_separation",
		10
	)


	for index in range(
		characters.size()
	):

		card_container.add_child(
			_create_character_card(
				index
			)
		)


	# =====================================================
	# 선택 안내
	# =====================================================

	description_label = Label.new()

	main_box.add_child(
		description_label
	)


	description_label.text = (
		"캐릭터를 선택하세요."
	)


	description_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	description_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)


	description_label.modulate = Color(
		0.78,
		0.80,
		0.84,
		1.0
	)


	# =====================================================
	# 선택
	# =====================================================

	confirm_button = Button.new()

	main_box.add_child(
		confirm_button
	)


	confirm_button.text = (
		"이 캐릭터 선택"
	)


	confirm_button.disabled = true


	confirm_button.pressed.connect(
		_on_confirm_pressed
	)


	# =====================================================
	# 커스텀
	# =====================================================

	custom_button = Button.new()

	main_box.add_child(
		custom_button
	)


	custom_button.text = (
		"+ 커스텀 캐릭터 만들기"
	)


	custom_button.pressed.connect(
		_on_custom_pressed
	)


	_create_custom_button_style()


# =========================================================
# 커스텀 버튼 스타일
# =========================================================

func _create_custom_button_style() -> void:

	var normal_style := StyleBoxFlat.new()


	normal_style.bg_color = Color(
		0.055,
		0.065,
		0.075,
		1.0
	)


	normal_style.border_color = Color(
		0.30,
		0.36,
		0.42,
		1.0
	)


	normal_style.border_width_left = 1
	normal_style.border_width_top = 1
	normal_style.border_width_right = 1
	normal_style.border_width_bottom = 1


	normal_style.corner_radius_top_left = 4
	normal_style.corner_radius_top_right = 4
	normal_style.corner_radius_bottom_left = 4
	normal_style.corner_radius_bottom_right = 4


	var hover_style := (
		normal_style.duplicate()
	)


	hover_style.bg_color = Color(
		0.075,
		0.085,
		0.095,
		1.0
	)


	var pressed_style := (
		normal_style.duplicate()
	)


	pressed_style.bg_color = Color(
		0.095,
		0.105,
		0.115,
		1.0
	)


	custom_button.add_theme_stylebox_override(
		"normal",
		normal_style
	)


	custom_button.add_theme_stylebox_override(
		"hover",
		hover_style
	)


	custom_button.add_theme_stylebox_override(
		"pressed",
		pressed_style
	)


# =========================================================
# 캐릭터 카드 생성
# =========================================================

func _create_character_card(
	index: int
) -> Button:

	var data: Dictionary = (
		characters[index]
	)


	var card := Button.new()


	card.toggle_mode = true


	# 중요:
	# 가로 최소폭을 절대 지정하지 않음.
	# Grid가 자동 분배.
	card.custom_minimum_size.x = 0


	card.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)


	card.size_flags_stretch_ratio = 1.0


	card.pressed.connect(
		_on_character_selected.bind(
			index
		)
	)


	character_buttons.append(
		card
	)


	# =====================================================
	# 내부
	# =====================================================

	var content := VBoxContainer.new()

	card.add_child(
		content
	)


	content.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)


	content.offset_left = 5
	content.offset_top = 5
	content.offset_right = -5
	content.offset_bottom = -5


	content.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	content.alignment = (
		BoxContainer.ALIGNMENT_CENTER
	)


	content.add_theme_constant_override(
		"separation",
		3
	)


	# =====================================================
	# 초상화 중앙 영역
	# =====================================================

	var portrait_center := CenterContainer.new()

	content.add_child(
		portrait_center
	)


	portrait_center.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)


	# =====================================================
	# 초상화 프레임
	# =====================================================

	var portrait_frame := Panel.new()

	portrait_center.add_child(
		portrait_frame
	)


	var portrait_frame_style := StyleBoxFlat.new()


	portrait_frame_style.bg_color = Color(
		0.035,
		0.040,
		0.045,
		1.0
	)


	portrait_frame_style.border_color = Color(
		0.22,
		0.25,
		0.28,
		1.0
	)


	portrait_frame_style.border_width_left = 1
	portrait_frame_style.border_width_top = 1
	portrait_frame_style.border_width_right = 1
	portrait_frame_style.border_width_bottom = 1


	portrait_frame_style.corner_radius_top_left = 3
	portrait_frame_style.corner_radius_top_right = 3
	portrait_frame_style.corner_radius_bottom_left = 3
	portrait_frame_style.corner_radius_bottom_right = 3


	portrait_frame.add_theme_stylebox_override(
		"panel",
		portrait_frame_style
	)


	# =====================================================
	# 초상화
	# =====================================================

	var portrait := TextureRect.new()

	portrait_frame.add_child(
		portrait
	)


	portrait.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)


	portrait.offset_left = 3
	portrait.offset_top = 3
	portrait.offset_right = -3
	portrait.offset_bottom = -3


	portrait.expand_mode = (
		TextureRect.EXPAND_IGNORE_SIZE
	)


	portrait.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)


	portrait.texture_filter = (
		CanvasItem.TEXTURE_FILTER_NEAREST
	)


	portrait.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	var portrait_path: String = str(
		data.get(
			"portrait",
			""
		)
	)


	if ResourceLoader.exists(
		portrait_path
	):

		portrait.texture = load(
			portrait_path
		)


	portrait_nodes.append(
		portrait
	)


	# =====================================================
	# 이름
	# =====================================================

	var name_label := Label.new()

	content.add_child(
		name_label
	)


	name_label.text = str(
		data.get(
			"name",
			"캐릭터"
		)
	)


	name_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	name_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)


	name_label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)


	name_labels.append(
		name_label
	)


	return card


# =========================================================
# 반응형
# =========================================================

func _apply_responsive_layout() -> void:

	var viewport_size := (
		get_viewport_rect().size
	)


	# =====================================================
	# 모바일
	#
	# 2열 × 6줄
	# =====================================================

	if ScreenLayout.is_mobile_portrait():

		main_box.position = Vector2(
			18,
			20
		)


		main_box.size = Vector2(
			viewport_size.x - 36,
			viewport_size.y - 40
		)


		# 정확히 2열
		card_container.columns = 2


		card_container.custom_minimum_size.x = 0


		title_label.add_theme_font_size_override(
			"font_size",
			30
		)


		subtitle_label.add_theme_font_size_override(
			"font_size",
			18
		)


		description_label.add_theme_font_size_override(
			"font_size",
			16
		)


		description_label.custom_minimum_size = Vector2(
			0,
			26
		)


		confirm_button.custom_minimum_size = Vector2(
			0,
			50
		)


		confirm_button.add_theme_font_size_override(
			"font_size",
			18
		)


		custom_button.custom_minimum_size = Vector2(
			0,
			50
		)


		custom_button.add_theme_font_size_override(
			"font_size",
			18
		)


		for index in range(
			character_buttons.size()
		):

			# 중요:
			# x값은 항상 0.
			# Grid가 두 칸으로 자동 분배한다.
			character_buttons[index].custom_minimum_size = Vector2(
				0,
				112
			)


			var portrait: TextureRect = (
				portrait_nodes[index]
			)


			var portrait_frame: Control = (
				portrait.get_parent()
			)


			# 정사각형 초상화 기준 프레임
			portrait_frame.custom_minimum_size = Vector2(
				68,
				68
			)


			name_labels[index].add_theme_font_size_override(
				"font_size",
				16
			)


	# =====================================================
	# PC
	#
	# 6열 × 2줄
	# =====================================================

	else:

		main_box.size = Vector2(
			1180,
			590
		)


		main_box.position = Vector2(
			(
				viewport_size.x
				- main_box.size.x
			) / 2.0,
			24
		)


		# 정확히 6열
		card_container.columns = 6


		card_container.custom_minimum_size.x = 0


		title_label.add_theme_font_size_override(
			"font_size",
			29
		)


		subtitle_label.add_theme_font_size_override(
			"font_size",
			15
		)


		description_label.add_theme_font_size_override(
			"font_size",
			15
		)


		description_label.custom_minimum_size = Vector2(
			0,
			25
		)


		confirm_button.custom_minimum_size = Vector2(
			0,
			44
		)


		confirm_button.add_theme_font_size_override(
			"font_size",
			15
		)


		custom_button.custom_minimum_size = Vector2(
			0,
			44
		)


		custom_button.add_theme_font_size_override(
			"font_size",
			15
		)


		for index in range(
			character_buttons.size()
		):

			# 가로폭 강제하지 않음
			character_buttons[index].custom_minimum_size = Vector2(
				0,
				155
			)


			var portrait: TextureRect = (
				portrait_nodes[index]
			)


			var portrait_frame: Control = (
				portrait.get_parent()
			)


			portrait_frame.custom_minimum_size = Vector2(
				82,
				82
			)


			name_labels[index].add_theme_font_size_override(
				"font_size",
				16
			)


# =========================================================
# 캐릭터 선택
# =========================================================

func _on_character_selected(
	index: int
) -> void:

	selected_index = (
		index
	)


	for i in range(
		character_buttons.size()
	):

		character_buttons[i].button_pressed = (
			i == selected_index
		)


	var data: Dictionary = (
		characters[selected_index]
	)


	description_label.text = (
		str(
			data.get(
				"name",
				""
			)
		)
		+ " 선택됨 · 특성은 다음 단계에서 선택합니다."
	)


	confirm_button.disabled = false


# =========================================================
# 캐릭터 확정
# =========================================================

func _on_confirm_pressed() -> void:

	if selected_index < 0:
		return


	var data: Dictionary = (
		characters[selected_index]
	)


	GameData.set_character_identity(
		int(
			data.get(
				"id",
				0
			)
		),
		str(
			data.get(
				"name",
				""
			)
		),
		str(
			data.get(
				"portrait",
				""
			)
		),
		false
	)


	if ResourceLoader.exists(
		PERSONALITY_SELECT_SCENE
	):

		get_tree().change_scene_to_file(
			PERSONALITY_SELECT_SCENE
		)

	else:

		description_label.text = (
			"personality_select.tscn을 찾을 수 없습니다."
		)


# =========================================================
# 커스텀 캐릭터
# =========================================================

func _on_custom_pressed() -> void:

	selected_index = -1


	for button in character_buttons:

		button.button_pressed = false


	confirm_button.disabled = true


	if ResourceLoader.exists(
		CUSTOM_CHARACTER_SCENE
	):

		get_tree().change_scene_to_file(
			CUSTOM_CHARACTER_SCENE
		)

	else:

		description_label.text = (
			"커스텀 캐릭터 생성 화면은 다음 단계에서 연결합니다."
		)

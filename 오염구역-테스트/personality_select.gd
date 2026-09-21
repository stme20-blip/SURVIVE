extends Control


# =========================================================
# 특성 데이터
#
# key  = 내부 저장용
# name = 화면 표시용
#
# 지금은 테스트용 특성.
# 나중에 name / description은 자유롭게 변경 가능.
# =========================================================

const PERSONALITIES := [

	{
		"key": "CALM",
		"name": "차분함",
		"description": "감정에 휩쓸리지 않고 상황을 침착하게 바라봅니다."
	},

	{
		"key": "CAUTIOUS",
		"name": "신중함",
		"description": "행동하기 전에 위험 요소와 주변 상황을 먼저 확인합니다."
	},

	{
		"key": "CURIOUS",
		"name": "호기심",
		"description": "이상하거나 낯선 것을 그냥 지나치지 않고 확인하려 합니다."
	},

	{
		"key": "DIRECT",
		"name": "직선적",
		"description": "복잡하게 돌려 생각하기보다 빠르고 직접적으로 판단합니다."
	},

	{
		"key": "TIMID",
		"name": "겁이 많음",
		"description": "위험을 민감하게 느끼며 안전하지 않은 상황을 경계합니다."
	}
]


# =========================================================
# 선택 상태
# =========================================================

var selected_personality_index: int = -1

var personality_buttons: Array[Button] = []


# =========================================================
# UI
# =========================================================

var main_box: VBoxContainer

var title_label: Label
var subtitle_label: Label

var personality_container: GridContainer

var description_panel: Panel
var description_label: Label

var bottom_buttons: HBoxContainer

var back_button: Button
var confirm_button: Button


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
# 화면 크기 변경
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
	# 메인 영역
	# =====================================================

	main_box = VBoxContainer.new()

	add_child(
		main_box
	)


	main_box.add_theme_constant_override(
		"separation",
		22
	)


	# =====================================================
	# 제목
	# =====================================================

	title_label = Label.new()

	main_box.add_child(
		title_label
	)


	title_label.text = (
		"당신은 어떤 사람입니까?"
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
		"캐릭터의 성격 특성을 하나 선택하세요."
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
	# 특성 버튼 영역
	# =====================================================

	personality_container = GridContainer.new()

	main_box.add_child(
		personality_container
	)


	personality_container.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)


	personality_container.add_theme_constant_override(
		"h_separation",
		10
	)


	personality_container.add_theme_constant_override(
		"v_separation",
		10
	)


	for index in range(
		PERSONALITIES.size()
	):

		var button := (
			_create_personality_button(
				index
			)
		)


		personality_container.add_child(
			button
		)


	# =====================================================
	# 설명 패널
	# =====================================================

	description_panel = Panel.new()

	main_box.add_child(
		description_panel
	)


	var description_style := StyleBoxFlat.new()

	description_style.bg_color = Color(
		0.040,
		0.045,
		0.052,
		1.0
	)


	description_style.border_color = Color(
		0.14,
		0.16,
		0.18,
		1.0
	)


	description_style.border_width_left = 1
	description_style.border_width_top = 1
	description_style.border_width_right = 1
	description_style.border_width_bottom = 1


	description_panel.add_theme_stylebox_override(
		"panel",
		description_style
	)


	description_label = Label.new()

	description_panel.add_child(
		description_label
	)


	description_label.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)


	description_label.offset_left = 18
	description_label.offset_top = 10
	description_label.offset_right = -18
	description_label.offset_bottom = -10


	description_label.text = (
		"특성을 선택하면 설명이 표시됩니다."
	)


	description_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	description_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)


	description_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)


	description_label.modulate = Color(
		0.78,
		0.81,
		0.85,
		1.0
	)


	# =====================================================
	# 하단 버튼
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


	back_button.text = (
		"이전"
	)


	back_button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)


	back_button.pressed.connect(
		_on_back_pressed
	)


	# -----------------------------------------------------
	# 다음
	# -----------------------------------------------------

	confirm_button = Button.new()

	bottom_buttons.add_child(
		confirm_button
	)


	confirm_button.text = (
		"다음"
	)


	confirm_button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)


	confirm_button.disabled = true


	confirm_button.pressed.connect(
		_on_confirm_pressed
	)


# =========================================================
# 특성 버튼 생성
# =========================================================

func _create_personality_button(
	index: int
) -> Button:

	var data: Dictionary = (
		PERSONALITIES[index]
	)


	var button := Button.new()


	button.text = str(
		data.get(
			"name",
			"특성"
		)
	)


	button.toggle_mode = true


	button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)


	button.pressed.connect(
		_on_personality_selected.bind(
			index
		)
	)


	# =====================================================
	# 기본 스타일
	# =====================================================

	var normal_style := StyleBoxFlat.new()


	normal_style.bg_color = Color(
		0.050,
		0.055,
		0.062,
		1.0
	)


	normal_style.border_color = Color(
		0.16,
		0.18,
		0.20,
		1.0
	)


	normal_style.border_width_left = 1
	normal_style.border_width_top = 1
	normal_style.border_width_right = 1
	normal_style.border_width_bottom = 1


	normal_style.corner_radius_top_left = 3
	normal_style.corner_radius_top_right = 3
	normal_style.corner_radius_bottom_left = 3
	normal_style.corner_radius_bottom_right = 3


	# =====================================================
	# 마우스 오버
	# =====================================================

	var hover_style := (
		normal_style.duplicate()
	)


	hover_style.bg_color = Color(
		0.075,
		0.080,
		0.088,
		1.0
	)


	# =====================================================
	# 선택됨
	# =====================================================

	var pressed_style := (
		normal_style.duplicate()
	)


	pressed_style.bg_color = Color(
		0.10,
		0.115,
		0.13,
		1.0
	)


	pressed_style.border_color = Color(
		0.48,
		0.57,
		0.64,
		1.0
	)


	pressed_style.border_width_left = 2
	pressed_style.border_width_top = 2
	pressed_style.border_width_right = 2
	pressed_style.border_width_bottom = 2


	# =====================================================
	# 스타일 적용
	# =====================================================

	button.add_theme_stylebox_override(
		"normal",
		normal_style
	)


	button.add_theme_stylebox_override(
		"hover",
		hover_style
	)


	button.add_theme_stylebox_override(
		"pressed",
		pressed_style
	)


	personality_buttons.append(
		button
	)


	return button


# =========================================================
# 특성 선택
# =========================================================

func _on_personality_selected(
	index: int
) -> void:

	selected_personality_index = (
		index
	)


	# =====================================================
	# 반드시 하나만 선택
	# =====================================================

	for i in range(
		personality_buttons.size()
	):

		personality_buttons[i].button_pressed = (
			i == selected_personality_index
		)


	var data: Dictionary = (
		PERSONALITIES[
			selected_personality_index
		]
	)


	# =====================================================
	# 설명 변경
	# =====================================================

	description_label.text = (
		str(
			data.get(
				"name",
				""
			)
		)
		+ "\n"
		+ str(
			data.get(
				"description",
				""
			)
		)
	)


	confirm_button.disabled = false


# =========================================================
# 특성 확정
# =========================================================

func _on_confirm_pressed() -> void:

	if selected_personality_index < 0:
		return


	var data: Dictionary = (
		PERSONALITIES[
			selected_personality_index
		]
	)


	# =====================================================
	# 내부 KEY 저장
	#
	# CALM
	# CAUTIOUS
	# CURIOUS
	# DIRECT
	# TIMID
	# =====================================================

	var new_personality := str(
		data.get(
			"key",
			""
		)
	)


	# =====================================================
	# 최종 캐릭터 정보 저장
	# =====================================================

	if RoomManager.has_room():

		var saved: bool = RoomManager.set_selected_character(
			GameData.selected_character_id,
			GameData.selected_name,
			GameData.selected_portrait_path,
			new_personality
		)
		if not saved:
			description_label.text = "특성 변경은 한 플레이에 3회까지 가능합니다. 한도가 남아 있다면 저장 상태를 확인해 주세요."
			return
	GameData.selected_personality = new_personality


	# =====================================================
	# 에피소드 선택 화면으로 이동
	# =====================================================

	get_tree().change_scene_to_file(
		"res://episode_select.tscn"
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

		main_box.position = Vector2(
			24,
			40
		)


		main_box.size = Vector2(
			viewport_size.x - 48,
			viewport_size.y - 80
		)


		title_label.add_theme_font_size_override(
			"font_size",
			34
		)


		subtitle_label.add_theme_font_size_override(
			"font_size",
			21
		)


		# -------------------------------------------------
		# 모바일에서는 세로 1열
		# -------------------------------------------------

		personality_container.columns = 1


		for button in personality_buttons:

			button.custom_minimum_size = Vector2(
				0,
				68
			)


			button.add_theme_font_size_override(
				"font_size",
				21
			)


		description_panel.custom_minimum_size = Vector2(
			0,
			110
		)


		description_label.add_theme_font_size_override(
			"font_size",
			18
		)


		back_button.custom_minimum_size = Vector2(
			0,
			62
		)


		confirm_button.custom_minimum_size = Vector2(
			0,
			62
		)


		back_button.add_theme_font_size_override(
			"font_size",
			20
		)


		confirm_button.add_theme_font_size_override(
			"font_size",
			20
		)


	# =====================================================
	# PC
	# =====================================================

	else:

		main_box.size = Vector2(
			1000,
			390
		)


		main_box.position = Vector2(
			(
				viewport_size.x
				- main_box.size.x
			) / 2.0,
			90
		)


		title_label.add_theme_font_size_override(
			"font_size",
			30
		)


		subtitle_label.add_theme_font_size_override(
			"font_size",
			16
		)


		# -------------------------------------------------
		# PC에서는 5개 한 줄
		# -------------------------------------------------

		personality_container.columns = 5


		for button in personality_buttons:

			button.custom_minimum_size = Vector2(
				180,
				68
			)


			button.add_theme_font_size_override(
				"font_size",
				18
			)


		description_panel.custom_minimum_size = Vector2(
			0,
			85
		)


		description_label.add_theme_font_size_override(
			"font_size",
			16
		)


		back_button.custom_minimum_size = Vector2(
			0,
			52
		)


		confirm_button.custom_minimum_size = Vector2(
			0,
			52
		)


		back_button.add_theme_font_size_override(
			"font_size",
			16
		)


		confirm_button.add_theme_font_size_override(
			"font_size",
			16
		)

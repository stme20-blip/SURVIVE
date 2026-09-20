extends Control


# =========================================================
# 에피소드 데이터
#
# 나중에 에피소드를 추가할 때
# 이 배열에 항목만 추가하면 됨.
# =========================================================

const EPISODES := [

	{
		"id": "school",
		"title": "학교",
		"description": "존재하지 않아야 할 교실과 변해버린 학교.",
		"scene_id": "school_hallway",
		"scene_title": "학교 복도",

		# 현재 학교는 main.tscn의 DialogueBox에
		# 연결돼 있는 school_test.tres를 그대로 사용.
		"dialogue_file": "res://school_test.tres",

		"start_id": "START1",
		"scene_file": "res://main.tscn",
		"enabled": true
	},

	{
		"id": "hospital",
		"title": "병원",
		"description": "폐쇄된 병동에서 시작되는 오염 구역.",
		"scene_id": "hospital",
		"scene_title": "병원",

		# 병원 전용 Dialogue Nodes 파일
		"dialogue_file": "res://hospital_dialogue.tres",

		# 병원 파일에서 만든 Start Node의 ID
		"start_id": "START1",

		"scene_file": "res://main.tscn",
		"enabled": true
	},

	{
		"id": "theater",
		"title": "극장",
		"description": "공연이 끝난 뒤에도 아무도 나가지 못한 극장.",
		"scene_id": "theater",
		"scene_title": "극장",
		"dialogue_file": "",
		"start_id": "START",
		"scene_file": "res://main.tscn",
		"enabled": false
	},

	{
		"id": "casino",
		"title": "카지노",
		"description": "끝나지 않는 게임이 이어지는 오염 구역.",
		"scene_id": "casino",
		"scene_title": "카지노",
		"dialogue_file": "",
		"start_id": "START",
		"scene_file": "res://main.tscn",
		"enabled": false
	}
]


# =========================================================
# 선택 상태
# =========================================================

var selected_index: int = -1

var episode_buttons: Array[Button] = []


# =========================================================
# UI
# =========================================================

var main_box: VBoxContainer

var title_label: Label
var subtitle_label: Label

var episode_grid: GridContainer

var description_panel: Panel
var description_label: Label

var bottom_row: HBoxContainer

var back_button: Button
var start_button: Button


# =========================================================
# 시작
# =========================================================

func _ready() -> void:

	_create_ui()

	_create_episode_cards()


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
		0.018,
		0.020,
		0.023,
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
		18
	)


	# =====================================================
	# 제목
	# =====================================================

	title_label = Label.new()

	main_box.add_child(
		title_label
	)


	title_label.text = (
		"어디로 들어가시겠습니까?"
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
		"플레이할 에피소드를 선택하세요."
	)


	subtitle_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	subtitle_label.modulate = Color(
		0.68,
		0.71,
		0.75,
		1.0
	)


	# =====================================================
	# 에피소드 Grid
	# =====================================================

	episode_grid = GridContainer.new()

	main_box.add_child(
		episode_grid
	)


	episode_grid.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)


	episode_grid.add_theme_constant_override(
		"h_separation",
		12
	)


	episode_grid.add_theme_constant_override(
		"v_separation",
		12
	)


	# =====================================================
	# 선택 설명
	# =====================================================

	description_panel = Panel.new()

	main_box.add_child(
		description_panel
	)


	description_panel.custom_minimum_size = Vector2(
		0,
		90
	)


	var description_style := StyleBoxFlat.new()


	description_style.bg_color = Color(
		0.035,
		0.038,
		0.043,
		1.0
	)


	description_style.border_color = Color(
		0.18,
		0.20,
		0.23,
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
	description_label.offset_top = 12
	description_label.offset_right = -18
	description_label.offset_bottom = -12


	description_label.text = (
		"에피소드를 선택하면 이곳에 설명이 표시됩니다."
	)


	description_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)


	description_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)


	description_label.modulate = Color(
		0.78,
		0.80,
		0.82,
		1.0
	)


	# =====================================================
	# 하단 버튼
	# =====================================================

	bottom_row = HBoxContainer.new()

	main_box.add_child(
		bottom_row
	)


	bottom_row.add_theme_constant_override(
		"separation",
		12
	)


	back_button = Button.new()

	bottom_row.add_child(
		back_button
	)


	back_button.text = "이전"


	back_button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)


	back_button.pressed.connect(
		_on_back_pressed
	)


	start_button = Button.new()

	bottom_row.add_child(
		start_button
	)


	start_button.text = (
		"이 에피소드로 시작"
	)


	start_button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)


	start_button.disabled = true


	start_button.pressed.connect(
		_on_start_pressed
	)


# =========================================================
# 에피소드 카드 생성
# =========================================================

func _create_episode_cards() -> void:

	episode_buttons.clear()


	for index in range(
		EPISODES.size()
	):

		var episode: Dictionary = (
			EPISODES[index]
		)


		var button := Button.new()

		episode_grid.add_child(
			button
		)


		episode_buttons.append(
			button
		)


		button.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)


		button.toggle_mode = true


		var title: String = str(
			episode.get(
				"title",
				"에피소드"
			)
		)


		var enabled: bool = bool(
			episode.get(
				"enabled",
				false
			)
		)


		if enabled:

			button.text = (
				title
				+ "\n\nPLAY"
			)

		else:

			button.text = (
				title
				+ "\n\n준비 중"
			)


		button.disabled = not enabled


		button.pressed.connect(
			_on_episode_pressed.bind(
				index
			)
		)


		_apply_episode_button_style(
			button,
			enabled
		)


# =========================================================
# 카드 스타일
# =========================================================

func _apply_episode_button_style(
	button: Button,
	enabled: bool
) -> void:

	var normal := StyleBoxFlat.new()


	normal.bg_color = Color(
		0.040,
		0.043,
		0.048,
		1.0
	)


	normal.border_color = Color(
		0.18,
		0.20,
		0.23,
		1.0
	)


	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1


	normal.corner_radius_top_left = 3
	normal.corner_radius_top_right = 3
	normal.corner_radius_bottom_left = 3
	normal.corner_radius_bottom_right = 3


	var hover := normal.duplicate()


	hover.bg_color = Color(
		0.060,
		0.064,
		0.070,
		1.0
	)


	hover.border_color = Color(
		0.38,
		0.41,
		0.45,
		1.0
	)


	var pressed := normal.duplicate()


	pressed.bg_color = Color(
		0.085,
		0.090,
		0.100,
		1.0
	)


	pressed.border_color = Color(
		0.72,
		0.75,
		0.78,
		1.0
	)


	button.add_theme_stylebox_override(
		"normal",
		normal
	)


	button.add_theme_stylebox_override(
		"hover",
		hover
	)


	button.add_theme_stylebox_override(
		"pressed",
		pressed
	)


	button.add_theme_stylebox_override(
		"focus",
		pressed
	)


	if not enabled:

		button.modulate = Color(
			0.48,
			0.50,
			0.53,
			1.0
		)


# =========================================================
# 에피소드 선택
# =========================================================

func _on_episode_pressed(
	index: int
) -> void:

	if (
		index < 0
		or index >= EPISODES.size()
	):

		return


	var episode: Dictionary = (
		EPISODES[index]
	)


	if not bool(
		episode.get(
			"enabled",
			false
		)
	):

		return


	selected_index = index


	for button_index in range(
		episode_buttons.size()
	):

		episode_buttons[
			button_index
		].button_pressed = (
			button_index == selected_index
		)


	description_label.text = str(
		episode.get(
			"description",
			""
		)
	)


	start_button.disabled = false


# =========================================================
# 게임 시작
# =========================================================

func _on_start_pressed() -> void:

	if (
		selected_index < 0
		or selected_index >= EPISODES.size()
	):

		return


	var episode: Dictionary = (
		EPISODES[selected_index]
	)


	if not bool(
		episode.get(
			"enabled",
			false
		)
	):

		return


	var scene_id: String = str(
		episode.get(
			"scene_id",
			""
		)
	)


	var scene_title: String = str(
		episode.get(
			"scene_title",
			""
		)
	)


	var start_id: String = str(
		episode.get(
			"start_id",
			"START1"
		)
	)


	var scene_file: String = str(
		episode.get(
			"scene_file",
			"res://main.tscn"
		)
	)


	var dialogue_file: String = str(
		episode.get(
			"dialogue_file",
			""
		)
	).strip_edges()


	# =====================================================
	# 새 에피소드 시작
	#
	# 기존 에피소드의 선택/대사/상황/인사이트/
	# 플래그/인벤토리 진행은 초기화한다.
	# 토론 댓글과 캐릭터/특성은 유지한다.
	# =====================================================

	if RoomManager.has_room():

		RoomManager.start_new_episode(
			scene_id,
			scene_title,
			scene_file,
			start_id,
			dialogue_file
		)


	# =====================================================
	# 게임으로 이동
	# =====================================================

	get_tree().change_scene_to_file(
		scene_file
	)


# =========================================================
# 이전
# =========================================================

func _on_back_pressed() -> void:

	get_tree().change_scene_to_file(
		"res://personality_select.tscn"
	)


# =========================================================
# 화면 변경
# =========================================================

func _on_layout_changed() -> void:

	call_deferred(
		"_apply_responsive_layout"
	)


# =========================================================
# 반응형
# =========================================================

func _apply_responsive_layout() -> void:

	var viewport_size: Vector2 = (
		get_viewport_rect().size
	)


	# =====================================================
	# 모바일
	# =====================================================

	if ScreenLayout.is_mobile_portrait():

		episode_grid.columns = 2


		main_box.position = Vector2(
			22,
			38
		)


		main_box.size = Vector2(
			viewport_size.x - 44,
			viewport_size.y - 76
		)


		title_label.add_theme_font_size_override(
			"font_size",
			31
		)


		subtitle_label.add_theme_font_size_override(
			"font_size",
			19
		)


		description_label.add_theme_font_size_override(
			"font_size",
			18
		)


		for button in episode_buttons:

			button.custom_minimum_size = Vector2(
				0,
				170
			)


			button.add_theme_font_size_override(
				"font_size",
				20
			)


		back_button.custom_minimum_size = Vector2(
			0,
			58
		)


		start_button.custom_minimum_size = Vector2(
			0,
			58
		)


		back_button.add_theme_font_size_override(
			"font_size",
			19
		)


		start_button.add_theme_font_size_override(
			"font_size",
			19
		)


	# =====================================================
	# PC
	# =====================================================

	else:

		episode_grid.columns = 4


		main_box.size = Vector2(
			1180,
			560
		)


		main_box.position = Vector2(
			(
				viewport_size.x
				- main_box.size.x
			) / 2.0,
			42
		)


		title_label.add_theme_font_size_override(
			"font_size",
			30
		)


		subtitle_label.add_theme_font_size_override(
			"font_size",
			16
		)


		description_label.add_theme_font_size_override(
			"font_size",
			15
		)


		for button in episode_buttons:

			button.custom_minimum_size = Vector2(
				0,
				190
			)


			button.add_theme_font_size_override(
				"font_size",
				19
			)


		back_button.custom_minimum_size = Vector2(
			0,
			50
		)


		start_button.custom_minimum_size = Vector2(
			0,
			50
		)


		back_button.add_theme_font_size_override(
			"font_size",
			16
		)


		start_button.add_theme_font_size_override(
			"font_size",
			16
		)

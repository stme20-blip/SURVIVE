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


# 활성 에피소드 카드에만 사용하는 원본 배경 이미지다.
const SCHOOL_CARD_BACKGROUND := preload("res://school_hallway.png")
const HOSPITAL_CARD_BACKGROUND := preload("res://hospital_exterior.png")


# =========================================================
# 선택 상태
# =========================================================

var selected_index: int = -1

var episode_buttons: Array[Button] = []
var episode_card_labels: Array[Label] = []


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
	if _should_resume_after_character_setup():
		# The existing episode is resumed immediately after character setup. Cover
		# this transitional scene so its cards never flash for one frame.
		_show_transition_loading()
		call_deferred("_resume_episode_after_character_setup")
	else:
		call_deferred("_apply_host_episode_if_needed")


func _should_resume_after_character_setup() -> bool:
	var online: Dictionary = RoomManager.current_room.get("online_room", {})
	if not bool(online.get("awaiting_character_after_episode", false)):
		return false
	return int(RoomManager.get_game_state().get("selected_character_id", 0)) > 0


func _show_transition_loading() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color("#08090b")
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	center.add_child(row)
	var spinner := Label.new()
	spinner.text = "↻"
	spinner.add_theme_font_size_override("font_size", 24)
	spinner.custom_minimum_size = Vector2(24, 24)
	spinner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spinner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	spinner.pivot_offset = Vector2(12, 12)
	row.add_child(spinner)
	var label := Label.new()
	label.text = "진입 중"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	row.add_child(label)
	var spinner_tween := create_tween().set_loops()
	spinner_tween.tween_property(spinner, "rotation", TAU, 0.8).from(0.0)


func _apply_host_episode_if_needed() -> void:
	# A joining player never chooses an episode. The host's server-owned id is applied.
	if not RoomManager.has_active_online_room():
		return
	var online: Dictionary = RoomManager.current_room.get("online_room", {})
	if bool(online.get("is_host", false)) or not bool(online.get("needs_profile_setup", false)):
		return
	var wanted := str(online.get("episode_id", ""))
	for index in range(EPISODES.size()):
		if str(EPISODES[index].get("id", "")) == wanted and bool(EPISODES[index].get("enabled", false)):
			selected_index = index
			_on_start_pressed()
			return
	description_label.text = "방장이 정한 에피소드를 찾을 수 없습니다. 초대 코드를 다시 확인해 주세요."


func _resume_episode_after_character_setup() -> void:
	# Hosts choose the episode before character setup. On the return trip, resume
	# that one selected episode instead of asking for it again.
	var online: Dictionary = RoomManager.current_room.get("online_room", {})
	if not bool(online.get("awaiting_character_after_episode", false)):
		return
	var state: Dictionary = RoomManager.get_game_state()
	if int(state.get("selected_character_id", 0)) <= 0:
		return
	var wanted := str(online.get("episode_id", ""))
	for index in range(EPISODES.size()):
		if str(EPISODES[index].get("id", "")) == wanted and bool(EPISODES[index].get("enabled", false)):
			selected_index = index
			_on_start_pressed()
			return
	description_label.text = "선택한 에피소드를 찾을 수 없습니다. 다시 선택해 주세요."


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
	episode_card_labels.clear()


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


		if enabled:

			_add_episode_card_background(
				button,
				str(episode.get("id", ""))
			)


func _add_episode_card_background(
	button: Button,
	episode_id: String
) -> void:

	var background_texture: Texture2D

	match episode_id:
		"school":
			background_texture = SCHOOL_CARD_BACKGROUND
		"hospital":
			background_texture = HOSPITAL_CARD_BACKGROUND
		_:
			return


	# Button의 자식으로 그려야 화면 전체 배경 뒤로 밀려나지 않는다.
	# 글자는 별도 Label로 올려 이미지와 어두운 막보다 항상 앞에 둔다.
	button.clip_contents = true
	var image := TextureRect.new()
	image.texture = background_texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.offset_left = 1.0
	image.offset_top = 1.0
	image.offset_right = -1.0
	image.offset_bottom = -1.0
	button.add_child(image)

	# 이미지 원본은 유지한 채 글자가 충분히 읽히는 정도로만 어둡게 한다.
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.56)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.offset_left = 1.0
	shade.offset_top = 1.0
	shade.offset_right = -1.0
	shade.offset_bottom = -1.0
	button.add_child(shade)

	var label := Label.new()
	label.text = button.text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.text = ""
	button.add_child(label)
	episode_card_labels.append(label)


# =========================================================
# 카드 스타일
# =========================================================

func _apply_episode_button_style(
	button: Button,
	enabled: bool
) -> void:

	var normal := StyleBoxFlat.new()



	if enabled:
		# 카드 이미지 위에 얹히는 아주 얇은 색막이다.
		normal.bg_color = Color(0.040, 0.043, 0.048, 0.18)
	else:
		normal.bg_color = Color(0.040, 0.043, 0.048, 1.0)


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



	if enabled:
		hover.bg_color = Color(0.060, 0.064, 0.070, 0.10)
	else:
		hover.bg_color = Color(0.060, 0.064, 0.070, 1.0)


	hover.border_color = Color(
		0.38,
		0.41,
		0.45,
		1.0
	)


	var pressed := normal.duplicate()



	if enabled:
		pressed.bg_color = Color(0.085, 0.090, 0.100, 0.14)
	else:
		pressed.bg_color = Color(0.085, 0.090, 0.100, 1.0)


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

	var state: Dictionary = RoomManager.get_game_state()
	var selected_character_id := int(state.get("selected_character_id", 0))
	var online: Dictionary = RoomManager.current_room.get("online_room", {})
	if selected_character_id <= 0:
		if not online.is_empty():
			online["episode_id"] = str(episode.get("id", ""))
			online["awaiting_character_after_episode"] = true
			RoomManager.current_room["online_room"] = online
			RoomManager.save_current_room()
		get_tree().change_scene_to_file("res://character_select.tscn")
		return
	if bool(online.get("awaiting_character_after_episode", false)):
		online.erase("awaiting_character_after_episode")
		RoomManager.current_room["online_room"] = online
		RoomManager.save_current_room()

	# Host creation is intentionally delayed until character and episode setup is complete.
	if RoomManager.is_pending_online_host():
		start_button.disabled = true
		description_label.text = "서버를 생성하고 초대 코드를 발급하는 중입니다..."
		var service := preload("res://RoomService.gd").new()
		add_child(service)
		var display_name := str(RoomManager.get_local_member().get("character_name", "")).strip_edges()
		var result: Dictionary = await service.create_room(display_name, str(episode.get("id", "")))
		service.queue_free()
		if result.has("error") or not RoomManager.complete_online_host_room(result.get("data", {})):
			description_label.text = str(result.get("message", "서버 생성에 실패했습니다. 네트워크 연결을 확인한 뒤 다시 시도해 주세요."))
			start_button.disabled = false
			return
		get_tree().change_scene_to_file("res://room_lobby.tscn")
		return
	if RoomManager.has_active_online_room():
		get_tree().change_scene_to_file("res://room_lobby.tscn")
		return


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


		for label in episode_card_labels:

			label.add_theme_font_size_override(
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
			500
		)


		main_box.position = Vector2(
			(
				viewport_size.x
				- main_box.size.x
			) / 2.0,
			(
				viewport_size.y
				- main_box.size.y
			) / 2.0
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


		for label in episode_card_labels:

			label.add_theme_font_size_override(
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

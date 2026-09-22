extends Control


@onready var dialogue_box = $DialogueBox
@onready var school_background = $SchoolHallway_png

@onready var scene_background = (
	get_node_or_null("Background")
)

@onready var desktop_discussion = (
	get_node_or_null("DiscussionPanel")
)

const HOSPITAL_EXTERIOR_BACKGROUND := preload("res://hospital_exterior.png")


# =========================================================
# 플레이어
# =========================================================

var player_portrait: Texture2D
var player_name: String = "주인공"
var _settings_refresh_pending: bool = false

var is_restoring_dialogue: bool = false

# 이전 선택 복구 중 중복 입력 방지
var is_undoing_dialogue: bool = false

# 실제 선택지를 누르기 직전 상태
var pending_choice_snapshot: Dictionary = {}


# =========================================================
# 현재 대화
# =========================================================

var current_speaker_text: String = ""
var current_dialogue_text: String = ""
var current_options: Array = []

var current_has_choice: bool = false
var _first_dialogue_wait_reset_pending := true
var _rich_text_wait_effect: RichTextWait
var _dialogue_revision := 0

# PC 대사 높이 재계산 중복 예약 방지
var desktop_reflow_scheduled: bool = false


# =========================================================
# Insight
# =========================================================

var pending_insight_title: String = ""
var pending_insight_text: String = ""

var active_insight_title: String = ""
var active_insight_text: String = ""


# =========================================================
# 에피소드 Dialogue 데이터
#
# RoomManager에 dialogue_file이 저장돼 있으면
# main.tscn의 DialogueBox.data를 해당 .tres로 교체한다.
#
# dialogue_file이 비어 있으면
# main.tscn에 원래 연결된 기본 데이터(현재 학교)를 그대로 사용한다.
# =========================================================

func _load_episode_dialogue_data() -> void:

	if not RoomManager.has_room():
		return


	var dialogue_file: String = (
		RoomManager.get_dialogue_file()
			.strip_edges()
	)


	# 학교는 현재 main.tscn에 연결돼 있는
	# school_test.tres를 그대로 사용하므로 비워둘 수 있다.
	if dialogue_file.is_empty():
		return


	if not ResourceLoader.exists(
		dialogue_file
	):

		push_error(
			"에피소드 Dialogue 파일을 찾을 수 없습니다: "
			+ dialogue_file
		)

		return


	var loaded_resource: Resource = (
		ResourceLoader.load(
			dialogue_file
		)
	)


	if loaded_resource == null:

		push_error(
			"에피소드 Dialogue 파일 로드 실패: "
			+ dialogue_file
		)

		return


	if not loaded_resource is DialogueData:

		push_error(
			"DialogueData 형식이 아닌 파일입니다: "
			+ dialogue_file
		)

		return


	dialogue_box.data = (
		loaded_resource as DialogueData
	)


	print(
		"에피소드 Dialogue 로드: ",
		dialogue_file
	)
	_apply_episode_background(dialogue_file)


func _apply_episode_background(dialogue_file: String) -> void:
	# Dialogue 1 and 2 share main.tscn's background node. Replace only that
	# node's texture for the hospital episode; the graph itself remains unchanged.
	if dialogue_file != "res://hospital_dialogue.tres":
		return
	if school_background is Sprite2D:
		var background_sprite := school_background as Sprite2D
		background_sprite.texture = HOSPITAL_EXTERIOR_BACKGROUND
		# The hospital asset has a slightly different aspect ratio from the original
		# school image. Cover the whole PC game area to prevent a one-pixel top seam.
		var target_size := Vector2(1152.0, 648.0)
		var source_size := HOSPITAL_EXTERIOR_BACKGROUND.get_size()
		var cover_scale := maxf(target_size.x / source_size.x, target_size.y / source_size.y)
		background_sprite.scale = Vector2(cover_scale, cover_scale)
		background_sprite.position = target_size * 0.5
	elif school_background is TextureRect:
		(school_background as TextureRect).texture = HOSPITAL_EXTERIOR_BACKGROUND


# =========================================================
# PC 초상화
# =========================================================

var portrait_box: Panel
var portrait_texture: TextureRect

var name_plate: Panel
var name_label: Label


# =========================================================
# PC Insight
# =========================================================

var insight_panel: Panel
var insight_label: Label

# PC 이전 버튼
var desktop_undo_button: Button

# 에피소드 선택 화면으로 돌아가기
var episode_back_button: Button


# =========================================================
# 모바일 전체 UI
# =========================================================

var mobile_page_background: ColorRect
var mobile_background: TextureRect

var mobile_insight_panel: Panel
var mobile_insight_label: Label

var mobile_dialogue_panel: Panel

var mobile_portrait_panel: Panel
var mobile_portrait_texture: TextureRect

var mobile_speaker_label: Label
var mobile_dialogue_label: RichTextLabel

var mobile_options_container: VBoxContainer


# =========================================================
# 모바일 토론
# =========================================================

var mobile_discussion_panel: Panel

var mobile_discussion_title: Label
var mobile_discussion_subtitle: Label
var mobile_discussion_separator: HSeparator

var mobile_feed_scroll: ScrollContainer
var mobile_feed_container: VBoxContainer

var mobile_message_input: LineEdit
var mobile_submit_button: Button
var mobile_download_button: Button
var mobile_composer_back_button: Button

var mobile_editing_comment_id: String = ""

# Godot's experimental Web virtual keyboard can fail to initialize while a
# phone is already in portrait mode, and it drops some non-composition input.
# Keep a browser input bridge for the mobile survival-record fields instead.
var _mobile_web_input_bridge: JavaScriptObject
var _mobile_web_input_callback: JavaScriptObject
var _mobile_web_viewport_callback: JavaScriptObject
var _mobile_web_submit_callback: JavaScriptObject
var _mobile_web_cancel_callback: JavaScriptObject
var _mobile_web_active_input: LineEdit
var _mobile_keyboard_height_px := 0.0
var _mobile_keyboard_canvas_ratio := 0.0
var _mobile_comment_composer_mode := false


# =========================================================
# PC 위치
# =========================================================

const PORTRAIT_POSITION := Vector2(
	48,
	430
)

const PORTRAIT_SIZE := Vector2(
	140,
	170
)


const CHOICE_DIALOGUE_POSITION := Vector2(
	205,
	430
)

const CHOICE_DIALOGUE_SIZE := Vector2(
	900,
	170
)


const CHOICE_INSIGHT_POSITION := Vector2(
	205,
	384
)

const CHOICE_INSIGHT_SIZE := Vector2(
	900,
	38
)


const NORMAL_DIALOGUE_POSITION := Vector2(
	48,
	380
)

const NORMAL_DIALOGUE_SIZE := Vector2(
	1056,
	220
)


const NORMAL_INSIGHT_POSITION := Vector2(
	48,
	334
)

const NORMAL_INSIGHT_SIZE := Vector2(
	1056,
	38
)


const DESKTOP_OPTION_HEIGHT := 40

# PC 대화창은 아래쪽 기준선을 유지하고
# 내용이 많아질수록 위쪽으로 자동 확장한다.
const DESKTOP_DIALOGUE_BOTTOM := 620.0
const DESKTOP_DIALOGUE_MIN_HEIGHT := 150.0
const DESKTOP_CHOICE_DIALOGUE_MIN_HEIGHT := 132.0
const DESKTOP_DIALOGUE_MAX_HEIGHT := 380.0

# 대사 영역 자체는 이 높이까지만 자동 확장.
# 그보다 긴 글은 DialogueBox의 RichTextLabel 안에서 스크롤된다.
const DESKTOP_TEXT_MIN_HEIGHT := 44.0
const DESKTOP_TEXT_MAX_HEIGHT := 190.0

const DESKTOP_DIALOGUE_VERTICAL_PADDING := 14.0
const DESKTOP_INSIGHT_GAP := 8.0


# =========================================================
# 모바일
# =========================================================

const MOBILE_MARGIN := 14.0
const MOBILE_GAP := 10.0

const MOBILE_INSIGHT_HEIGHT := 54.0

const MOBILE_PORTRAIT_WIDTH := 82.0
const MOBILE_PORTRAIT_HEIGHT := 82.0

# 모바일 대사 행의 최소 높이.
# 실제 대사가 길면 이 값보다 자동으로 커진다.
const MOBILE_DIALOGUE_ROW_HEIGHT := 112.0
const MOBILE_DIALOGUE_TEXT_MIN_HEIGHT := 72.0
const MOBILE_DIALOGUE_TEXT_MAX_HEIGHT := 220.0

const MOBILE_OPTION_HEIGHT := 58.0
const MOBILE_OPTION_GAP := 8.0


# 원본 파일은 바꾸지 않고, 지정 기본 초상화가 게임에 표시될 때만 가장자리를 부드럽게 어둡게 한다.
const FEATURED_PORTRAIT_VIGNETTE_SHADER := """
shader_type canvas_item;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float distance_from_center = length(UV - vec2(0.5)) * 1.41421356;
	float vignette = smoothstep(0.44, 0.98, distance_from_center);
	color.rgb *= mix(1.0, 0.22, vignette);
	COLOR = color;
}
"""


# =========================================================
# 모바일 공통 색
#
# 판단과 선택지가 같은 색
# =========================================================

const MOBILE_CARD_BG := Color(
	0.055,
	0.058,
	0.063,
	1.0
)

const MOBILE_CARD_HOVER_BG := Color(
	0.075,
	0.078,
	0.084,
	1.0
)

const MOBILE_CARD_PRESSED_BG := Color(
	0.095,
	0.098,
	0.104,
	1.0
)

const MOBILE_SECTION_BG := Color(
	0.018,
	0.020,
	0.023,
	1.0
)


# =========================================================
# 시작
# =========================================================

func _ready() -> void:
	GameData.character_settings_changed.connect(_on_character_settings_changed)

	_load_selected_character()
	_load_episode_dialogue_data()

	_create_desktop_portrait()
	_create_desktop_insight()
	_create_desktop_undo_button()
	_create_episode_back_button()

	_create_mobile_ui()
	_update_portrait_vignettes()


	portrait_box.visible = false
	insight_panel.visible = false

	_set_mobile_ui_visible(
		false
	)


	dialogue_box.options_vertical = true


	# =====================================================
	# Dialogue 이벤트
	# =====================================================

	dialogue_box.dialogue_processed.connect(
		_on_dialogue_processed
	)

	dialogue_box.dialogue_signal.connect(
		_on_dialogue_signal
	)

	dialogue_box.option_selected.connect(
		_on_dialogue_option_selected
	)
	dialogue_box.gui_input.connect(_on_dialogue_box_gui_input)

	_connect_first_dialogue_wait_debug()


	# =====================================================
	# 반응형
	# =====================================================

	if not ScreenLayout.layout_changed.is_connected(
		_on_screen_layout_changed
	):

		ScreenLayout.layout_changed.connect(
			_on_screen_layout_changed
		)


	if not RoomManager.feed_changed.is_connected(
		_on_room_feed_changed
	):

		RoomManager.feed_changed.connect(
			_on_room_feed_changed
		)


	call_deferred(
		"_initial_setup"
	)


# =========================================================
# 댓글 변경
# =========================================================

func _on_room_feed_changed() -> void:

	if ScreenLayout.is_mobile_portrait():

		_refresh_mobile_feed()


func _on_dialogue_box_gui_input(event: InputEvent) -> void:
	_try_skip_dialogue_with_click(event)


func _input(event: InputEvent) -> void:
	# Receive clicks before UI controls consume them, matching DialogueBox's ESC path.
	_try_skip_dialogue_with_click(event)


func _try_skip_dialogue_with_click(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	# 설정/참가자 UI 클릭은 대사 스킵보다 먼저 보장한다.
	if SettingsOverlay.is_pointer_over_interactive_control(event.position):
		return
	if not dialogue_box.is_running() or _rich_text_wait_effect == null or _rich_text_wait_effect.finished:
		return
	# Never consume a press intended for an already-visible desktop option.
	if not ScreenLayout.is_mobile_portrait() and dialogue_box.options_container.visible:
		return
	if ScreenLayout.is_mobile_portrait() and _is_click_on_mobile_option(event.position):
		return
	_rich_text_wait_effect.skip = true
	get_viewport().set_input_as_handled()
	call_deferred("_finish_click_skip_after_frame")


func _finish_click_skip_after_frame() -> void:
	await get_tree().process_frame
	if current_has_choice and not dialogue_box.options_container.visible:
		dialogue_box.options_container.show()
		if dialogue_box.options_container.get_child_count() > 0:
			var first_option: Node = dialogue_box.options_container.get_child(0)
			if first_option is Button:
				(first_option as Button).grab_focus()


func _connect_first_dialogue_wait_debug() -> void:
	for effect in dialogue_box.custom_effects:
		if effect is RichTextWait:
			_rich_text_wait_effect = effect as RichTextWait
			if not _rich_text_wait_effect.wait_finished.is_connected(_on_first_dialogue_wait_finished):
				_rich_text_wait_effect.wait_finished.connect(_on_first_dialogue_wait_finished)
			return
	print("[first-dialogue] RichTextWait effect was not found")


func _prepare_first_dialogue_wait() -> void:
	if not _first_dialogue_wait_reset_pending:
		return
	_first_dialogue_wait_reset_pending = false
	if _rich_text_wait_effect == null:
		print("[first-dialogue] no RichTextWait state to reset")
		return
	print("[first-dialogue] reset wait; finished=", _rich_text_wait_effect.finished, "; displayed=", _rich_text_wait_effect.displayed.size(), "; options_visible=", dialogue_box.options_container.visible)
	_rich_text_wait_effect.finished = false
	_rich_text_wait_effect.skip = false
	_rich_text_wait_effect.displayed.clear()


func _on_first_dialogue_wait_finished() -> void:
	if not current_has_choice:
		return
	print("[first-dialogue] wait_finished; options_visible=", dialogue_box.options_container.visible)


# =========================================================
# 최초 설정
# =========================================================

func _initial_setup() -> void:

	await get_tree().process_frame

	_sync_root_size()

	# 먼저 실제 Dialogue를 시작/복원한다.
	# 이렇게 해야 DialogueBox의 에디터용 샘플 텍스트
	# (Speaker / Option 1...)가 화면에 남지 않는다.
	await _start_or_restore_dialogue()

	await get_tree().process_frame

	_apply_current_layout()


# =========================================================
# 화면 변경
# =========================================================

func _on_screen_layout_changed() -> void:

	call_deferred(
		"_apply_layout_deferred"
	)


func _apply_layout_deferred() -> void:

	await get_tree().process_frame

	_sync_root_size()

	_apply_current_layout()


# =========================================================
# 루트 크기
# =========================================================

func _sync_root_size() -> void:

	var viewport_size := (
		get_viewport_rect().size
	)


	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0

	position = Vector2.ZERO
	size = viewport_size


# =========================================================
# 현재 레이아웃
# =========================================================

func _apply_current_layout() -> void:

	if ScreenLayout.is_mobile_portrait():

		_apply_mobile_layout()

	else:

		_apply_desktop_layout()


# =========================================================
# 플레이어
# =========================================================

func _on_character_settings_changed(_personality_changed: bool) -> void:
	_settings_refresh_pending = true


func _refresh_character_settings() -> void:
	_settings_refresh_pending = false
	_load_selected_character()
	portrait_texture.texture = player_portrait
	mobile_portrait_texture.texture = player_portrait
	_update_portrait_vignettes()
	name_label.text = player_name


func _load_selected_character() -> void:

	if not GameData.selected_name.strip_edges().is_empty():

		player_name = (
			GameData.selected_name
		)


	player_portrait = (
		GameData.load_selected_portrait_texture()
	)


	# 초상화가 없거나 불러오기 실패 시
	# 임시 기본 이미지
	if player_portrait == null:

		if ResourceLoader.exists(
			"res://player_portrait.png"
		):

			player_portrait = load(
				"res://player_portrait.png"
			) as Texture2D


func _update_portrait_vignettes() -> void:

	if portrait_texture == null or mobile_portrait_texture == null:
		return

	var portrait_path := GameData.selected_portrait_path
	var use_vignette := portrait_path.ends_with("kim_soleum_portrait.png") or portrait_path.ends_with("baek_saheon_portrait.png")
	portrait_texture.material = _create_portrait_vignette_material() if use_vignette else null
	mobile_portrait_texture.material = _create_portrait_vignette_material() if use_vignette else null


func _create_portrait_vignette_material() -> ShaderMaterial:

	var shader := Shader.new()
	shader.code = FEATURED_PORTRAIT_VIGNETTE_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


# =========================================================
# PC 초상화
# =========================================================

func _create_desktop_portrait() -> void:

	portrait_box = Panel.new()

	add_child(
		portrait_box
	)
	portrait_box.clip_contents = true


	var frame_style := StyleBoxFlat.new()

	frame_style.bg_color = Color(
		0.05,
		0.06,
		0.07,
		0.94
	)

	frame_style.border_color = Color(
		0.0,
		0.0,
		0.0,
		1.0
	)

	frame_style.border_width_left = 2
	frame_style.border_width_top = 2
	frame_style.border_width_right = 2
	frame_style.border_width_bottom = 2


	portrait_box.add_theme_stylebox_override(
		"panel",
		frame_style
	)


	portrait_texture = TextureRect.new()

	portrait_box.add_child(
		portrait_texture
	)


	portrait_texture.position = Vector2(
		7,
		7
	)

	portrait_texture.size = Vector2(
		126,
		126
	)

	portrait_texture.texture = (
		player_portrait
	)

	portrait_texture.expand_mode = (
		TextureRect.EXPAND_IGNORE_SIZE
	)

	portrait_texture.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)

	portrait_texture.texture_filter = (
		CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	)
	var portrait_background := ColorRect.new()
	portrait_background.color = Color("#202224")
	portrait_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_background.show_behind_parent = true
	portrait_texture.add_child(portrait_background)
	portrait_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


	name_plate = Panel.new()

	portrait_box.add_child(
		name_plate
	)


	name_plate.position = Vector2(
		7,
		137
	)

	name_plate.size = Vector2(
		126,
		26
	)


	var name_style := StyleBoxFlat.new()

	name_style.bg_color = Color(
		0.10,
		0.11,
		0.12,
		0.96
	)

	name_style.border_color = Color(
		0.50,
		0.52,
		0.54,
		1.0
	)

	name_style.border_width_left = 1
	name_style.border_width_top = 1
	name_style.border_width_right = 1
	name_style.border_width_bottom = 1


	name_plate.add_theme_stylebox_override(
		"panel",
		name_style
	)


	name_label = Label.new()

	name_plate.add_child(
		name_label
	)


	name_label.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)


	name_label.text = (
		player_name
	)

	name_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	name_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	name_label.add_theme_font_size_override(
		"font_size",
		14
	)


# =========================================================
# PC Insight
# =========================================================

func _create_desktop_insight() -> void:

	insight_panel = Panel.new()

	add_child(
		insight_panel
	)


	var style := StyleBoxFlat.new()

	style.bg_color = Color(
		0.08,
		0.10,
		0.12,
		0.94
	)

	style.border_color = Color(
		0.38,
		0.48,
		0.52,
		0.95
	)

	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1


	insight_panel.add_theme_stylebox_override(
		"panel",
		style
	)


	insight_label = Label.new()

	insight_panel.add_child(
		insight_label
	)


	insight_label.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)


	insight_label.offset_left = 12
	insight_label.offset_right = -12

	insight_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	insight_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	insight_label.add_theme_font_size_override(
		"font_size",
		14
	)


# =========================================================
# PC 이전 버튼
# =========================================================

func _create_desktop_undo_button() -> void:

	desktop_undo_button = Button.new()

	add_child(
		desktop_undo_button
	)


	desktop_undo_button.z_index = 70

	desktop_undo_button.text = (
		"← 이전"
	)

	desktop_undo_button.visible = false


	desktop_undo_button.add_theme_font_size_override(
		"font_size",
		14
	)


	var normal_style := StyleBoxFlat.new()

	normal_style.bg_color = Color(
		0.045,
		0.050,
		0.056,
		0.96
	)

	normal_style.border_color = Color(
		0.30,
		0.34,
		0.38,
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


	var hover_style: StyleBoxFlat = (
		normal_style.duplicate()
	)

	hover_style.bg_color = Color(
		0.070,
		0.076,
		0.084,
		0.98
	)


	var pressed_style: StyleBoxFlat = (
		normal_style.duplicate()
	)

	pressed_style.bg_color = Color(
		0.095,
		0.102,
		0.112,
		1.0
	)


	desktop_undo_button.add_theme_stylebox_override(
		"normal",
		normal_style
	)

	desktop_undo_button.add_theme_stylebox_override(
		"hover",
		hover_style
	)

	desktop_undo_button.add_theme_stylebox_override(
		"pressed",
		pressed_style
	)


	desktop_undo_button.pressed.connect(
		_on_undo_dialogue_pressed
	)


func _can_show_undo_button() -> bool:

	if is_restoring_dialogue:
		return false


	if is_undoing_dialogue:
		return false


	if not RoomManager.has_room():
		return false


	return (
		RoomManager.can_undo_dialogue_selection()
	)


# =========================================================
# 에피소드 선택 화면으로 돌아가기 버튼
# =========================================================

func _create_episode_back_button() -> void:

	episode_back_button = Button.new()

	add_child(
		episode_back_button
	)


	episode_back_button.z_index = 70

	episode_back_button.text = (
		"에피소드 재선택"
	)

	episode_back_button.visible = false


	# PC의 "이전" 버튼과 같은 폰트 크기
	episode_back_button.add_theme_font_size_override(
		"font_size",
		14
	)


	# PC의 "이전" 버튼과 같은 디자인
	var normal_style := StyleBoxFlat.new()

	normal_style.bg_color = Color(
		0.045,
		0.050,
		0.056,
		0.96
	)

	normal_style.border_color = Color(
		0.30,
		0.34,
		0.38,
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


	var hover_style: StyleBoxFlat = (
		normal_style.duplicate()
	)

	hover_style.bg_color = Color(
		0.070,
		0.076,
		0.084,
		0.98
	)


	var pressed_style: StyleBoxFlat = (
		normal_style.duplicate()
	)

	pressed_style.bg_color = Color(
		0.095,
		0.102,
		0.112,
		1.0
	)


	episode_back_button.add_theme_stylebox_override(
		"normal",
		normal_style
	)

	episode_back_button.add_theme_stylebox_override(
		"hover",
		hover_style
	)

	episode_back_button.add_theme_stylebox_override(
		"pressed",
		pressed_style
	)


	episode_back_button.pressed.connect(
		_on_episode_back_pressed
	)


# =========================================================
# 에피소드 재선택 버튼 표시 조건
#
# - 실제 선택지가 화면에 떠 있음
# - 아직 실제 선택지를 한 번도 고르지 않음
#
# 빈 "계속" 버튼을 눌렀던 기록은 실제 선택으로 보지 않는다.
# =========================================================

func _can_show_episode_reselect_button() -> bool:

	if is_restoring_dialogue:
		return false


	if is_undoing_dialogue:
		return false


	if not RoomManager.has_room():
		return false


	if not current_has_choice:
		return false


	return not (
		RoomManager.can_undo_dialogue_selection()
	)


func _on_episode_back_pressed() -> void:

	if is_undoing_dialogue:
		return


	if dialogue_box.is_running():

		dialogue_box.stop()


	get_tree().change_scene_to_file(
		"res://episode_select.tscn"
	)


# =========================================================
# 모바일 UI 전체 생성
# =========================================================

func _create_mobile_ui() -> void:

	_create_mobile_page_background()
	_create_mobile_background()
	_create_mobile_insight()
	_create_mobile_dialogue()
	_create_mobile_discussion()


# =========================================================
# 모바일 전체 검은 배경
# =========================================================

func _create_mobile_page_background() -> void:

	mobile_page_background = ColorRect.new()

	add_child(
		mobile_page_background
	)


	mobile_page_background.z_index = 100


	mobile_page_background.color = (
		MOBILE_SECTION_BG
	)


	mobile_page_background.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


# =========================================================
# 모바일 학교 배경
# =========================================================

func _create_mobile_background() -> void:

	mobile_background = TextureRect.new()

	add_child(
		mobile_background
	)


	mobile_background.z_index = 110


	# =====================================================
	# 기존 학교 배경 텍스처 가져오기
	# =====================================================

	var bg_texture: Texture2D = null


	if school_background is TextureRect:

		bg_texture = (
			school_background as TextureRect
		).texture


	elif school_background is Sprite2D:

		bg_texture = (
			school_background as Sprite2D
		).texture


	else:

		for property_data in (
			school_background.get_property_list()
		):

			if str(
				property_data.get(
					"name",
					""
				)
			) == "texture":

				var possible_texture = (
					school_background.get(
						"texture"
					)
				)


				if possible_texture is Texture2D:

					bg_texture = (
						possible_texture
						as Texture2D
					)


				break


	# =====================================================
	# 텍스처 적용
	# =====================================================

	if bg_texture != null:

		mobile_background.texture = (
			bg_texture
		)

	else:

		push_error(
			"SchoolHallway_png에서 배경 텍스처를 찾지 못했습니다."
		)


	# =====================================================
	# 표시 설정
	# =====================================================

	mobile_background.expand_mode = (
		TextureRect.EXPAND_IGNORE_SIZE
	)


	# 이미지 전체 표시
	# 잘라내지 않음
	mobile_background.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)


	mobile_background.texture_filter = (
		CanvasItem.TEXTURE_FILTER_NEAREST
	)


	mobile_background.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

# =========================================================
# 모바일 판단 / 관찰 / 감지
# =========================================================

func _create_mobile_insight() -> void:

	mobile_insight_panel = Panel.new()

	add_child(
		mobile_insight_panel
	)


	mobile_insight_panel.z_index = 120


	var style := StyleBoxFlat.new()


	# 선택지와 같은 배경색
	style.bg_color = (
		MOBILE_CARD_BG
	)


	style.border_color = Color(
		0.10,
		0.11,
		0.12,
		1.0
	)


	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1


	mobile_insight_panel.add_theme_stylebox_override(
		"panel",
		style
	)


	mobile_insight_label = Label.new()

	mobile_insight_panel.add_child(
		mobile_insight_label
	)


	mobile_insight_label.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)


	mobile_insight_label.offset_left = 14
	mobile_insight_label.offset_right = -14


	mobile_insight_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)


	mobile_insight_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)


	mobile_insight_label.add_theme_font_size_override(
		"font_size",
		20
	)


# =========================================================
# 모바일 대화 / 선택지
# =========================================================

func _create_mobile_dialogue() -> void:

	mobile_dialogue_panel = Panel.new()

	add_child(
		mobile_dialogue_panel
	)


	mobile_dialogue_panel.z_index = 120


	var panel_style := StyleBoxFlat.new()


	panel_style.bg_color = (
		MOBILE_SECTION_BG
	)


	panel_style.border_color = Color(
		0.08,
		0.09,
		0.10,
		1.0
	)


	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1


	mobile_dialogue_panel.add_theme_stylebox_override(
		"panel",
		panel_style
	)


	# =====================================================
	# 초상화
	# =====================================================

	mobile_portrait_panel = Panel.new()

	mobile_dialogue_panel.add_child(
		mobile_portrait_panel
	)


	var portrait_style := StyleBoxFlat.new()


	portrait_style.bg_color = Color(
		0.04,
		0.045,
		0.05,
		1.0
	)


	portrait_style.border_color = Color(
		0.0,
		0.0,
		0.0,
		1.0
	)


	portrait_style.border_width_left = 1
	portrait_style.border_width_top = 1
	portrait_style.border_width_right = 1
	portrait_style.border_width_bottom = 1


	mobile_portrait_panel.add_theme_stylebox_override(
		"panel",
		portrait_style
	)


	mobile_portrait_texture = TextureRect.new()

	mobile_portrait_panel.add_child(
		mobile_portrait_texture
	)


	mobile_portrait_texture.position = Vector2(
		4,
		4
	)


	mobile_portrait_texture.size = Vector2(
		MOBILE_PORTRAIT_WIDTH - 8,
		MOBILE_PORTRAIT_HEIGHT - 8
	)


	mobile_portrait_texture.texture = (
		player_portrait
	)


	mobile_portrait_texture.expand_mode = (
		TextureRect.EXPAND_IGNORE_SIZE
	)


	mobile_portrait_texture.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)


	mobile_portrait_texture.texture_filter = (
		CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	)
	var portrait_background := ColorRect.new()
	portrait_background.color = Color("#202224")
	portrait_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_background.show_behind_parent = true
	mobile_portrait_texture.add_child(portrait_background)
	portrait_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


	# =====================================================
	# 화자
	# =====================================================

	mobile_speaker_label = Label.new()

	mobile_dialogue_panel.add_child(
		mobile_speaker_label
	)


	mobile_speaker_label.add_theme_font_size_override(
		"font_size",
		19
	)


	mobile_speaker_label.modulate = Color(
		0.82,
		0.84,
		0.86,
		1.0
	)


	# =====================================================
	# 대사
	# =====================================================

	mobile_dialogue_label = RichTextLabel.new()

	mobile_dialogue_panel.add_child(
		mobile_dialogue_label
	)


	mobile_dialogue_label.bbcode_enabled = true

	# 긴 상황문/대사는 일정 높이까지 자동 확장하고,
	# 그보다 길 경우 내부에서 스크롤할 수 있게 한다.
	mobile_dialogue_label.scroll_active = true


	mobile_dialogue_label.add_theme_font_size_override(
		"normal_font_size",
		22
	)


	# =====================================================
	# 선택지
	# =====================================================

	mobile_options_container = VBoxContainer.new()

	mobile_dialogue_panel.add_child(
		mobile_options_container
	)


	mobile_options_container.add_theme_constant_override(
		"separation",
		int(MOBILE_OPTION_GAP)
	)


# =========================================================
# 모바일 토론창
# =========================================================

func _create_mobile_discussion() -> void:

	mobile_discussion_panel = Panel.new()

	add_child(
		mobile_discussion_panel
	)


	mobile_discussion_panel.z_index = 120


	var style := StyleBoxFlat.new()


	style.bg_color = (
		MOBILE_SECTION_BG
	)


	style.border_color = Color(
		0.16,
		0.18,
		0.20,
		1.0
	)


	style.border_width_top = 2


	mobile_discussion_panel.add_theme_stylebox_override(
		"panel",
		style
	)


	# -----------------------------------------------------
	# 제목
	# -----------------------------------------------------

	mobile_discussion_title = Label.new()

	mobile_discussion_panel.add_child(
		mobile_discussion_title
	)


	mobile_discussion_title.text = (
		"생존 기록"
	)


	mobile_discussion_title.add_theme_font_size_override(
		"font_size",
		26
	)


	# -----------------------------------------------------
	# 설명
	# -----------------------------------------------------

	mobile_discussion_subtitle = Label.new()

	mobile_discussion_panel.add_child(
		mobile_discussion_subtitle
	)


	mobile_discussion_subtitle.text = (
		"서버에서 작성한 모든 댓글이 기록됩니다."
	)


	mobile_discussion_subtitle.modulate = Color(
		0.65,
		0.68,
		0.72,
		1.0
	)


	mobile_discussion_subtitle.add_theme_font_size_override(
		"font_size",
		16
	)


	# -----------------------------------------------------
	# 플레이 기록 다운로드
	# -----------------------------------------------------

	mobile_download_button = Button.new()

	mobile_discussion_panel.add_child(
		mobile_download_button
	)

	mobile_download_button.text = (
		"기록 다운로드"
	)

	mobile_download_button.add_theme_font_size_override(
		"font_size",
		16
	)

	mobile_download_button.pressed.connect(
		_on_download_transcript_pressed
	)

	# Shown only while the mobile keyboard is open. This lets the player leave
	# the composer without submitting a comment.
	mobile_composer_back_button = Button.new()
	mobile_discussion_panel.add_child(mobile_composer_back_button)
	mobile_composer_back_button.text = "뒤로가기"
	mobile_composer_back_button.add_theme_font_size_override("font_size", 16)
	mobile_composer_back_button.pressed.connect(_on_mobile_composer_back_pressed)
	mobile_composer_back_button.visible = false


	# -----------------------------------------------------
	# 선
	# -----------------------------------------------------

	mobile_discussion_separator = HSeparator.new()

	mobile_discussion_panel.add_child(
		mobile_discussion_separator
	)


	# -----------------------------------------------------
	# 댓글 목록
	# -----------------------------------------------------

	mobile_feed_scroll = ScrollContainer.new()

	mobile_discussion_panel.add_child(
		mobile_feed_scroll
	)


	mobile_feed_container = VBoxContainer.new()

	mobile_feed_scroll.add_child(
		mobile_feed_container
	)


	mobile_feed_container.add_theme_constant_override(
		"separation",
		10
	)


	# -----------------------------------------------------
	# 댓글 입력
	# -----------------------------------------------------

	mobile_message_input = LineEdit.new()

	mobile_discussion_panel.add_child(
		mobile_message_input
	)


	mobile_message_input.placeholder_text = (
		"대사 또는 기록 입력"
	)
	mobile_message_input.virtual_keyboard_enabled = false
	# The browser-owned field below is the only keyboard entry point on Web.
	# Do not let Godot focus this proxy LineEdit: Naver's in-app WebView
	# otherwise opens Godot's virtual keyboard and resizes the canvas.
	mobile_message_input.focus_mode = Control.FOCUS_NONE
	mobile_message_input.gui_input.connect(
		_on_mobile_comment_input_gui_input.bind(mobile_message_input)
	)


	mobile_message_input.add_theme_font_size_override(
		"font_size",
		19
	)


	mobile_message_input.text_submitted.connect(
		_on_mobile_message_submitted
	)

	_setup_mobile_web_input_bridge()


	# -----------------------------------------------------
	# 등록
	# -----------------------------------------------------

	mobile_submit_button = Button.new()

	mobile_discussion_panel.add_child(
		mobile_submit_button
	)


	mobile_submit_button.text = (
		"등록"
	)


	mobile_submit_button.add_theme_font_size_override(
		"font_size",
		18
	)


	mobile_submit_button.pressed.connect(
		_on_mobile_submit_pressed
	)


# =========================================================
# Mobile web text input bridge
# =========================================================

func _setup_mobile_web_input_bridge() -> void:

	if not OS.has_feature("web"):
		return

	if _mobile_web_input_bridge != null:
		return

	_mobile_web_input_callback = JavaScriptBridge.create_callback(
		_on_mobile_web_input_changed
	)
	_mobile_web_viewport_callback = JavaScriptBridge.create_callback(
		_on_mobile_web_viewport_changed
	)
	_mobile_web_submit_callback = JavaScriptBridge.create_callback(
		_on_mobile_web_composer_submitted
	)
	_mobile_web_cancel_callback = JavaScriptBridge.create_callback(
		_on_mobile_web_composer_cancelled
	)

	var browser_window := JavaScriptBridge.get_interface("window")
	browser_window.__surviveMobileTextChanged = _mobile_web_input_callback
	browser_window.__surviveMobileViewportChanged = _mobile_web_viewport_callback
	browser_window.__surviveMobileTextSubmit = _mobile_web_submit_callback
	browser_window.__surviveMobileTextCancel = _mobile_web_cancel_callback

	JavaScriptBridge.eval("""
		if (!window.surviveMobileText) {
			const composer = document.createElement('div');
			const card = document.createElement('div');
			const title = document.createElement('strong');
			const actions = document.createElement('div');
			const cancel = document.createElement('button');
			const submit = document.createElement('button');
			const field = document.createElement('textarea');
			field.id = 'survive-mobile-comment-input';
			field.inputMode = 'text';
			field.autocomplete = 'off';
			field.autocorrect = 'on';
			field.autocapitalize = 'sentences';
			field.spellcheck = false;
			field.rows = 3;
			title.textContent = '생존 기록';
			cancel.textContent = '닫기';
			submit.textContent = '등록';
			field.placeholder = '대사 또는 기록 입력 · 수정버전1';
			Object.assign(composer.style, {
				position: 'fixed', display: 'none', zIndex: '2147483647',
				background: 'rgba(0, 0, 0, 0.72)', boxSizing: 'border-box',
				padding: '12px', touchAction: 'auto'
			});
			Object.assign(card.style, {
				position: 'absolute', left: '12px', right: '12px', bottom: '12px',
				padding: '14px', background: '#18191c', border: '1px solid #33363d',
				borderRadius: '12px', color: '#f3f3f3', fontFamily: 'sans-serif',
				boxSizing: 'border-box', boxShadow: '0 8px 24px rgba(0,0,0,.4)'
			});
			Object.assign(field.style, {
				display: 'block', width: '100%', minHeight: '76px', resize: 'none',
				boxSizing: 'border-box', margin: '10px 0 12px', padding: '10px',
				fontSize: '16px', lineHeight: '1.4', color: '#f3f3f3', caretColor: '#fff',
				background: '#0d0e10', border: '2px solid #000', borderRadius: '7px', outline: 'none'
			});
			Object.assign(actions.style, { display: 'flex', gap: '8px', justifyContent: 'flex-end' });
			const placeholderStyle = document.createElement('style');
			placeholderStyle.textContent = '#survive-mobile-comment-input::placeholder { color: #8d9199; opacity: 1; }';
			document.head.appendChild(placeholderStyle);
			Object.assign(cancel.style, { minWidth: '88px', height: '40px', color: '#eee', background: '#292b30', border: '0', borderRadius: '6px', fontSize: '15px' });
			Object.assign(submit.style, { minWidth: '76px', height: '40px', color: '#111', background: '#f1f1f1', border: '0', borderRadius: '6px', fontSize: '15px', fontWeight: '700' });
			document.body.appendChild(composer);
			composer.appendChild(card);
			card.appendChild(title);
			card.appendChild(field);
			card.appendChild(actions);
			actions.appendChild(cancel);
			actions.appendChild(submit);
			const sendValue = () => {
				if (window.__surviveMobileTextChanged) window.__surviveMobileTextChanged(field.value);
			};
			field.addEventListener('input', sendValue);
			field.addEventListener('change', sendValue);
			field.addEventListener('compositionend', sendValue);
			cancel.addEventListener('click', () => {
				if (window.__surviveMobileTextCancel) window.__surviveMobileTextCancel();
			});
			submit.addEventListener('click', () => {
				sendValue();
				if (window.__surviveMobileTextSubmit) window.__surviveMobileTextSubmit(field.value);
			});
			const layoutComposer = () => {
				const viewport = window.visualViewport;
				const keyboard = navigator.virtualKeyboard && navigator.virtualKeyboard.boundingRect;
				const keyboardHeight = keyboard && keyboard.height ? keyboard.height : 0;
				const width = viewport ? viewport.width : window.innerWidth;
				const height = keyboardHeight > 0 ? window.innerHeight - keyboardHeight : (viewport ? viewport.height : window.innerHeight);
				composer.style.left = `${viewport ? viewport.offsetLeft : 0}px`;
				composer.style.top = `${viewport ? viewport.offsetTop : 0}px`;
				composer.style.width = `${width}px`;
				composer.style.height = `${Math.max(0, height)}px`;
			};
			window.surviveMobileText = {
				place(value) { field.value = value || ''; },
				open(value) {
					field.value = value || '';
					layoutComposer();
					composer.style.display = 'block';
					field.focus({ preventScroll: true });
					field.setSelectionRange(field.value.length, field.value.length);
				},
				read() { return field.value; },
				close() { field.blur(); composer.style.display = 'none'; }
			};
			if (window.visualViewport && !window.__surviveMobileViewportListener) {
				window.__surviveMobileViewportListener = () => {
					const keyboard = Math.max(0, window.innerHeight - window.visualViewport.height);
					const canvas = document.getElementById('canvas');
					const canvasHeight = canvas ? canvas.getBoundingClientRect().height : 0;
					if (window.__surviveMobileViewportChanged) window.__surviveMobileViewportChanged(keyboard, canvasHeight);
				};
				window.visualViewport.addEventListener('resize', window.__surviveMobileViewportListener);
				window.visualViewport.addEventListener('resize', layoutComposer);
				window.visualViewport.addEventListener('scroll', layoutComposer);
			}
			if (navigator.virtualKeyboard) navigator.virtualKeyboard.addEventListener('geometrychange', layoutComposer);
		}
	""", true)

	_mobile_web_input_bridge = JavaScriptBridge.get_interface("surviveMobileText")


func _on_mobile_comment_input_gui_input(
	event: InputEvent,
	input: LineEdit
) -> void:

	if event is InputEventScreenTouch and event.pressed:
		_open_mobile_web_input(input)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_mobile_web_input(input)


func _open_mobile_web_input(input: LineEdit) -> void:

	if not OS.has_feature("web"):
		return

	if not is_instance_valid(input):
		return

	_setup_mobile_web_input_bridge()

	if _mobile_web_input_bridge == null:
		return

	# The native browser composer is drawn above the canvas, so browser-specific
	# canvas resizing cannot make the text field tiny or hide it behind a keyboard.
	_mobile_comment_composer_mode = false
	SettingsOverlay.set_mobile_comment_composer_mode(true)
	_mobile_web_active_input = input
	_mobile_web_input_bridge.open(input.text)


func _place_mobile_web_input() -> void:

	if not OS.has_feature("web") or _mobile_web_input_bridge == null:
		return

	# The DOM composer positions itself from visualViewport. It must not be
	# repositioned from Godot's canvas coordinates while the keyboard is open.
	return

	if not is_instance_valid(_mobile_web_active_input) or not _mobile_web_active_input.is_visible_in_tree():
		_close_mobile_web_input()
		return

	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var rect := _mobile_web_active_input.get_global_rect()
	_mobile_web_input_bridge.place(
		_mobile_web_active_input.text,
		rect.position.x / viewport_size.x,
		rect.position.y / viewport_size.y,
		rect.size.x / viewport_size.x,
		rect.size.y / viewport_size.y
	)


func _on_mobile_web_input_changed(args: Array) -> void:

	if args.is_empty() or not is_instance_valid(_mobile_web_active_input):
		return

	_mobile_web_active_input.text = str(args[0])
	_mobile_web_active_input.caret_column = _mobile_web_active_input.text.length()


func _process(_delta: float) -> void:

	# Some Android WebViews emit no JavaScriptBridge callback while composing
	# Korean text. Poll the DOM field as a fallback so letters, spaces, digits,
	# and punctuation all reach the Godot input.
	if not OS.has_feature("web") or _mobile_web_input_bridge == null:
		return

	if not is_instance_valid(_mobile_web_active_input):
		return

	var web_text: Variant = _mobile_web_input_bridge.read()
	if web_text is String and _mobile_web_active_input.text != web_text:
		_mobile_web_active_input.text = web_text
		_mobile_web_active_input.caret_column = _mobile_web_active_input.text.length()


func _on_mobile_web_viewport_changed(args: Array) -> void:

	if args.is_empty():
		return

	_mobile_keyboard_height_px = maxf(0.0, float(args[0]))
	if args.size() >= 2 and float(args[1]) > 0.0:
		_mobile_keyboard_canvas_ratio = clampf(
			_mobile_keyboard_height_px / float(args[1]),
			0.0,
			0.9
		)

	if ScreenLayout.is_mobile_portrait():
		call_deferred("_apply_current_layout")


func _close_mobile_web_input() -> void:

	if _mobile_web_input_bridge != null:
		_mobile_web_input_bridge.close()

	_mobile_web_active_input = null


func _finish_mobile_comment_composer() -> void:

	_mobile_comment_composer_mode = false
	_mobile_keyboard_height_px = 0.0
	_mobile_keyboard_canvas_ratio = 0.0
	SettingsOverlay.set_mobile_comment_composer_mode(false)
	_close_mobile_web_input()
	_apply_current_layout()


func _on_mobile_web_composer_submitted(args: Array) -> void:

	_on_mobile_web_input_changed(args)
	var edit_comment_id := ""
	if is_instance_valid(_mobile_web_active_input) and _mobile_web_active_input.has_meta("mobile_comment_id"):
		edit_comment_id = str(_mobile_web_active_input.get_meta("mobile_comment_id"))
	var submitted_text := _mobile_web_active_input.text if is_instance_valid(_mobile_web_active_input) else ""
	_finish_mobile_comment_composer()
	if edit_comment_id.is_empty():
		call_deferred("_submit_mobile_comment_after_ime")
	else:
		call_deferred("_submit_mobile_edit_text", edit_comment_id, submitted_text)


func _on_mobile_web_composer_cancelled(_args: Array) -> void:

	_finish_mobile_comment_composer()


func _submit_mobile_edit_text(comment_id: String, submitted_text: String) -> void:

	var new_text := submitted_text.strip_edges()
	if new_text.is_empty():
		return

	mobile_editing_comment_id = ""
	await CommentSync.edit(comment_id, new_text)


func _on_mobile_composer_back_pressed() -> void:

	_finish_mobile_comment_composer()


func _sync_mobile_web_input_now() -> void:

	# The submit tap can arrive before a WebView dispatches its final `input`
	# callback. Read the browser field first, then close it.
	if _mobile_web_input_bridge == null or not is_instance_valid(_mobile_web_active_input):
		return

	var web_text: Variant = _mobile_web_input_bridge.read()
	if web_text is String:
		_mobile_web_active_input.text = web_text
		_mobile_web_active_input.caret_column = _mobile_web_active_input.text.length()


# =========================================================
# 모바일 UI 표시/숨김
# =========================================================

func _set_mobile_ui_visible(
	value: bool
) -> void:

	mobile_page_background.visible = value
	mobile_background.visible = value

	mobile_insight_panel.visible = false

	mobile_dialogue_panel.visible = value
	mobile_discussion_panel.visible = value

	if not value:
		_close_mobile_web_input()


# =========================================================
# 선택지 스타일
# =========================================================

func _make_mobile_choice_style(
	bg_color: Color
) -> StyleBoxFlat:

	var style := StyleBoxFlat.new()


	style.bg_color = (
		bg_color
	)


	style.border_color = Color(
		0.10,
		0.11,
		0.12,
		1.0
	)


	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1


	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2


	style.content_margin_left = 12
	style.content_margin_right = 12


	return style


# =========================================================
# Dialogue Signal
# =========================================================

func _normalize_personality_key(
	value: String
) -> String:

	var key: String = (
		value
			.strip_edges()
			.to_upper()
	)


	match key:

		"차분함", "차분":
			return "CALM"

		"신중함", "신중":
			return "CAUTIOUS"

		"호기심":
			return "CURIOUS"

		"직선적", "직선":
			return "DIRECT"

		"겁이 많음", "겁이많음", "겁많음":
			return "TIMID"


	return key


func _get_selected_personality_key() -> String:

	# =====================================================
	# 1순위: 현재 GameData
	# =====================================================

	var selected_key: String = (
		_normalize_personality_key(
			GameData.selected_personality
		)
	)


	if not selected_key.is_empty():
		return selected_key


	# =====================================================
	# 2순위: 저장된 방의 캐릭터 정보
	#
	# 웹 새로고침 / 저장방 복원 등으로
	# GameData가 비어 있는 경우를 대비한다.
	# =====================================================

	if RoomManager.has_room():

		var member: Dictionary = (
			RoomManager.get_local_member()
		)


		selected_key = (
			_normalize_personality_key(
				str(
					member.get(
						"personality",
						""
					)
				)
			)
		)


	return selected_key


func _on_dialogue_signal(
	value: String
) -> void:

	var clean_value: String = (
		value.strip_edges()
	)


	# =====================================================
	# 특성 전용 Insight만 처리
	#
	# 형식:
	# INSIGHT|특성KEY|분류|내용
	#
	# 예:
	# INSIGHT|CAUTIOUS|관찰|손잡이만 유난히 깨끗하다.
	#
	# 캐릭터 ID는 전혀 사용하지 않는다.
	# =====================================================

	if not clean_value.begins_with(
		"INSIGHT|"
	):

		return


	var parts := clean_value.split(
		"|",
		true,
		3
	)


	if parts.size() < 4:

		push_warning(
			"INSIGHT Signal 형식이 잘못되었습니다: "
			+ clean_value
		)

		return


	var signal_personality: String = (
		_normalize_personality_key(
			str(
				parts[1]
			)
		)
	)


	var selected_personality: String = (
		_get_selected_personality_key()
	)


	if selected_personality.is_empty():

		push_warning(
			"선택된 특성 KEY가 없습니다. "
			+ "Signal: "
			+ clean_value
		)

		return


	# =====================================================
	# 선택한 특성과 다른 Signal은 무시
	# =====================================================

	if signal_personality != selected_personality:
		return


	# =====================================================
	# 일치하는 특성의 Insight 저장
	# =====================================================

	pending_insight_title = str(
		parts[2]
	).strip_edges()


	pending_insight_text = str(
		parts[3]
	).strip_edges()


	# =====================================================
	# Dialogue Nodes의 Signal / dialogue_processed
	# 호출 순서는 상황에 따라 앞뒤가 달라질 수 있다.
	#
	# 따라서 Signal이 나중에 들어온 경우에도
	# 이번 화면에 바로 반영되도록 deferred 처리한다.
	# =====================================================

	call_deferred(
		"_flush_pending_insight_from_signal"
	)


func _flush_pending_insight_from_signal() -> void:

	if pending_insight_text.is_empty():
		return


	_consume_pending_insight()

	_apply_current_layout()


# =========================================================
# Dialogue 처리
# =========================================================

func _on_dialogue_processed(
	_speaker,
	_dialogue,
	options
) -> void:
	_dialogue_revision += 1
	if _settings_refresh_pending:
		_refresh_character_settings()

	# =====================================================
	# 기록
	# =====================================================

	if (
		not is_restoring_dialogue
		and RoomManager.has_room()
	):

		var transcript_speaker: String = str(
			dialogue_box.speaker_label.text
		).strip_edges()


		var transcript_text: String = str(
			_dialogue
		).strip_edges()


		if not transcript_text.is_empty():

			if (
				transcript_speaker == "상황"
				or transcript_speaker.is_empty()
			):

				RoomManager.record_situation(
					transcript_text
				)

			else:

				RoomManager.record_dialogue(
					transcript_speaker,
					transcript_text
				)


	# =====================================================
	# 현재 화면 정보
	# =====================================================

	current_speaker_text = str(
		dialogue_box.speaker_label.text
	).strip_edges()


	current_dialogue_text = str(
		_dialogue
	).replace(
		"[br]",
		"\n"
	)


	current_options = (
		options.duplicate()
	)


	current_has_choice = false


	for option in current_options:

		if not str(
			option
		).strip_edges().is_empty():

			current_has_choice = true
			break

	if current_has_choice:
		call_deferred("_repair_first_choice_options_after_wait", _dialogue_revision)


	# =====================================================
	# 새 Dialogue 화면이므로 이전 Insight는 우선 비운다.
	#
	# 같은 화면용 Signal이 이미 들어왔다면
	# 바로 아래 _consume_pending_insight()가 다시 채운다.
	# Signal이 dialogue_processed 뒤에 들어오는 경우에는
	# _flush_pending_insight_from_signal()이 다시 채운다.
	# =====================================================

	active_insight_title = ""
	active_insight_text = ""


	_consume_pending_insight()


	_apply_current_layout()


	if not ScreenLayout.is_mobile_portrait():

		call_deferred(
			"_refresh_desktop_choice_buttons"
		)


	# RichTextLabel의 실제 줄바꿈 높이는
	# 레이아웃이 한 프레임 처리된 뒤 가장 정확하다.
	_schedule_desktop_reflow()


func _repair_first_choice_options_after_wait(revision: int) -> void:
	# RichTextLabel can complete a wait while DialogueBox is still inside
	# _on_dialogue_processed(), before that method hides the option container.
	# This also covers a dialogue restored through the "previous" replay path.
	await get_tree().process_frame
	if revision != _dialogue_revision or not current_has_choice:
		return
	if _rich_text_wait_effect != null and not _rich_text_wait_effect.finished:
		# DialogueParser can calculate a final wait index that does not match the
		# RichTextLabel's index around line breaks. Wait for the normal reveal time
		# before recovering the first choice; this never reveals options immediately.
		var reveal_seconds := maxf(0.35, float(current_dialogue_text.length()) / 50.0 + 0.35)
		print("[first-dialogue] wait_finished missing; watching natural reveal for ", reveal_seconds, " seconds")
		await get_tree().create_timer(reveal_seconds).timeout
		if revision != _dialogue_revision or not current_has_choice:
			return
	if dialogue_box.options_container.visible:
		return
	print("[first-dialogue] restoring first options after natural reveal")
	dialogue_box.options_container.show()
	if dialogue_box.options_container.get_child_count() > 0:
		var first_option: Node = dialogue_box.options_container.get_child(0)
		if first_option is Button:
			(first_option as Button).grab_focus()


func _is_click_on_mobile_option(point: Vector2) -> bool:
	if mobile_options_container == null:
		return false
	for child in mobile_options_container.get_children():
		if child is Control and (child as Control).visible and (child as Control).get_global_rect().has_point(point):
			return true
	return false


# =========================================================
# PC 대화창 재측정 예약
# =========================================================

func _schedule_desktop_reflow() -> void:

	if ScreenLayout.is_mobile_portrait():
		return


	if desktop_reflow_scheduled:
		return


	desktop_reflow_scheduled = true


	call_deferred(
		"_reflow_desktop_after_frame"
	)


func _reflow_desktop_after_frame() -> void:

	await get_tree().process_frame


	desktop_reflow_scheduled = false


	if ScreenLayout.is_mobile_portrait():
		return


	_apply_desktop_layout()


# =========================================================
# Insight
# =========================================================

func _consume_pending_insight() -> void:

	# pending이 없다고 active를 여기서 지우지 않는다.
	# active 초기화는 dialogue_processed에서
	# "새 대화가 처리될 때" 명시적으로 담당한다.
	if pending_insight_text.is_empty():
		return


	active_insight_title = (
		pending_insight_title
	)

	active_insight_text = (
		pending_insight_text
	)


	if active_insight_title.is_empty():

		active_insight_title = "정보"


	if (
		not is_restoring_dialogue
		and RoomManager.has_room()
	):

		RoomManager.record_insight(
			GameData.selected_name,
			active_insight_title,
			active_insight_text
		)


	pending_insight_title = ""
	pending_insight_text = ""


# =========================================================
# 모바일 전체 배치
# =========================================================

func _apply_mobile_layout() -> void:

	_sync_root_size()


	var viewport_size := (
		get_viewport_rect().size
	)


	# =====================================================
	# 기존 씬 UI 전부 숨김
	# =====================================================

	school_background.visible = false

	dialogue_box.visible = false

	portrait_box.visible = false
	insight_panel.visible = false


	if scene_background is CanvasItem:

		scene_background.visible = false


	# 기존 DiscussionPanel도 모바일에서는 사용하지 않음
	if desktop_discussion is CanvasItem:

		desktop_discussion.visible = false


	if desktop_undo_button != null:

		desktop_undo_button.visible = false


	# PC용 에피소드 재선택 버튼은
	# 모바일에서는 직접 사용하지 않는다.
	if episode_back_button != null:

		episode_back_button.visible = false


	# =====================================================
	# 모바일 UI 표시
	# =====================================================

	_set_mobile_ui_visible(
		true
	)

	if _mobile_comment_composer_mode:
		mobile_background.visible = false
		mobile_insight_panel.visible = false
		mobile_dialogue_panel.visible = false
		mobile_portrait_panel.visible = false
		var available_composer_height := viewport_size.y * (1.0 - _mobile_keyboard_canvas_ratio)
		var composer_height := clampf(available_composer_height, 300.0, 460.0)
		# The visible area above the keyboard is wider than it is tall. Lay out
		# the record panel inside that area instead of scaling the full portrait
		# game canvas down into it.
		_layout_mobile_discussion(
			0.0,
			Vector2(viewport_size.x, composer_height)
		)
		return


	# =====================================================
	# 회색 공간이 보일 수 없도록
	# 화면 전체를 검정으로 덮음
	# =====================================================

	mobile_page_background.position = (
		Vector2.ZERO
	)

	mobile_page_background.size = (
		viewport_size
	)


	# =====================================================
	# 배경
	#
	# 현재 모바일 폭에 딱 맞춰 16:9
	# =====================================================

	var game_width: float = (
		viewport_size.x
	)


	var game_height: float = (
		game_width
		* 648.0
		/ 1152.0
	)


	mobile_background.position = (
		Vector2.ZERO
	)


	mobile_background.size = Vector2(
		game_width,
		game_height
	)


	var current_y: float = (
		game_height
		+ MOBILE_GAP
	)


	# =====================================================
	# 판단 / 관찰
	# =====================================================

	if not active_insight_text.is_empty():

		mobile_insight_panel.visible = true


		mobile_insight_panel.position = Vector2(
			MOBILE_MARGIN,
			current_y
		)


		mobile_insight_panel.size = Vector2(
			viewport_size.x
				- MOBILE_MARGIN * 2,
			MOBILE_INSIGHT_HEIGHT
		)


		mobile_insight_label.text = (
			"["
			+ active_insight_title
			+ "]  "
			+ active_insight_text
		)


		current_y += (
			MOBILE_INSIGHT_HEIGHT
			+ MOBILE_GAP
		)

	else:

		mobile_insight_panel.visible = false


	# =====================================================
	# 대사 + 선택지
	# =====================================================

	var dialogue_height: float = (
		_layout_mobile_dialogue(
			current_y,
			viewport_size.x
		)
	)


	current_y += (
		dialogue_height
		+ MOBILE_GAP
	)


	# =====================================================
	# 토론
	# =====================================================

	_layout_mobile_discussion(
		current_y,
		viewport_size
	)

	_raise_mobile_discussion_above_keyboard(viewport_size)


# =========================================================
# 모바일 대사/선택지
# =========================================================

func _layout_mobile_dialogue(
	top_y: float,
	screen_width: float
) -> float:

	mobile_dialogue_panel.visible = true


	# =====================================================
	# 이전 버튼 삭제
	# =====================================================

	for child in (
		mobile_options_container.get_children()
	):

		mobile_options_container.remove_child(
			child
		)

		child.queue_free()


	# =====================================================
	# 대사 행
	# =====================================================

	var text_left: float = (
		MOBILE_MARGIN
	)


	if current_has_choice:

		mobile_portrait_panel.visible = true


		mobile_portrait_panel.position = Vector2(
			MOBILE_MARGIN,
			MOBILE_MARGIN
		)


		mobile_portrait_panel.size = Vector2(
			MOBILE_PORTRAIT_WIDTH,
			MOBILE_PORTRAIT_HEIGHT
		)


		text_left = (
			MOBILE_MARGIN
			+ MOBILE_PORTRAIT_WIDTH
			+ 12
		)

	else:

		mobile_portrait_panel.visible = false


	var text_width: float = (
		screen_width
		- text_left
		- MOBILE_MARGIN
	)


	mobile_speaker_label.position = Vector2(
		text_left,
		MOBILE_MARGIN
	)


	mobile_speaker_label.size = Vector2(
		text_width,
		26
	)


	mobile_speaker_label.text = (
		current_speaker_text
	)


	mobile_dialogue_label.position = Vector2(
		text_left,
		MOBILE_MARGIN + 30
	)


	# =====================================================
	# 모바일 대사 높이 자동 측정
	#
	# 먼저 충분히 큰 높이를 주어 현재 폭 기준 줄바꿈을 계산한 뒤
	# 실제 내용 높이에 맞춰 다시 줄인다.
	# =====================================================

	mobile_dialogue_label.size = Vector2(
		text_width,
		MOBILE_DIALOGUE_TEXT_MAX_HEIGHT
	)


	mobile_dialogue_label.text = (
		current_dialogue_text
	)


	var mobile_text_height: float = float(
		mobile_dialogue_label.get_content_height()
	)


	mobile_text_height = clamp(
		mobile_text_height + 8.0,
		MOBILE_DIALOGUE_TEXT_MIN_HEIGHT,
		MOBILE_DIALOGUE_TEXT_MAX_HEIGHT
	)


	mobile_dialogue_label.size = Vector2(
		text_width,
		mobile_text_height
	)


	var mobile_dialogue_row_height: float = (
		30.0
		+ mobile_text_height
	)


	# 선택지가 있는 경우 초상화보다 대사 행이 작아지지 않게 한다.
	if current_has_choice:

		mobile_dialogue_row_height = max(
			mobile_dialogue_row_height,
			MOBILE_PORTRAIT_HEIGHT
		)


	mobile_dialogue_row_height = max(
		mobile_dialogue_row_height,
		MOBILE_DIALOGUE_ROW_HEIGHT
	)


	# =====================================================
	# 선택지
	#
	# 대사 내용이 길면 실제 대사 높이 아래에서 시작한다.
	# =====================================================

	var options_y: float = (
		MOBILE_MARGIN
		+ mobile_dialogue_row_height
		+ 8
	)


	mobile_options_container.position = Vector2(
		MOBILE_MARGIN,
		options_y
	)


	mobile_options_container.size = Vector2(
		screen_width
			- MOBILE_MARGIN * 2,
		0
	)


	var option_count: int = (
		current_options.size()
	)


	for idx in range(
		option_count
	):

		var option_text: String = str(
			current_options[idx]
		).replace(
			"[br]",
			"\n"
		)


		var button := Button.new()


		if option_text.strip_edges().is_empty():

			button.text = "계속"

		else:

			button.text = (
				option_text
			)


		button.custom_minimum_size = Vector2(
			0,
			MOBILE_OPTION_HEIGHT
		)


		button.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)


		button.alignment = (
			HORIZONTAL_ALIGNMENT_LEFT
		)


		button.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART
		)


		button.add_theme_font_size_override(
			"font_size",
			21
		)


		# 판단과 정확히 같은 배경
		button.add_theme_stylebox_override(
			"normal",
			_make_mobile_choice_style(
				MOBILE_CARD_BG
			)
		)


		button.add_theme_stylebox_override(
			"hover",
			_make_mobile_choice_style(
				MOBILE_CARD_HOVER_BG
			)
		)


		button.add_theme_stylebox_override(
			"pressed",
			_make_mobile_choice_style(
				MOBILE_CARD_PRESSED_BG
			)
		)


		button.pressed.connect(
			_on_mobile_option_pressed.bind(
				idx
			)
		)


		mobile_options_container.add_child(
			button
		)


	# =====================================================
	# 모바일 하단 보조 버튼
	#
	# 첫 실제 선택 화면:
	#     에피소드 재선택
	#
	# 실제 선택을 한 뒤:
	#     이전 선택으로 돌아가기
	#
	# 둘은 같은 위치 / 같은 디자인을 사용한다.
	# =====================================================

	var show_undo_button: bool = (
		_can_show_undo_button()
	)


	var show_episode_reselect_button: bool = (
		_can_show_episode_reselect_button()
	)


	if show_undo_button:

		var undo_button := Button.new()

		undo_button.text = (
			"← 이전 선택으로 돌아가기"
		)

		undo_button.custom_minimum_size = Vector2(
			0,
			MOBILE_OPTION_HEIGHT
		)

		undo_button.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)

		undo_button.alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)

		undo_button.add_theme_font_size_override(
			"font_size",
			19
		)

		undo_button.modulate = Color(
			0.82,
			0.84,
			0.87,
			1.0
		)

		undo_button.add_theme_stylebox_override(
			"normal",
			_make_mobile_choice_style(
				Color(
					0.035,
					0.038,
					0.043,
					1.0
				)
			)
		)

		undo_button.add_theme_stylebox_override(
			"hover",
			_make_mobile_choice_style(
				MOBILE_CARD_HOVER_BG
			)
		)

		undo_button.add_theme_stylebox_override(
			"pressed",
			_make_mobile_choice_style(
				MOBILE_CARD_PRESSED_BG
			)
		)

		undo_button.pressed.connect(
			_on_undo_dialogue_pressed
		)

		mobile_options_container.add_child(
			undo_button
		)


	elif show_episode_reselect_button:

		var reselect_button := Button.new()

		reselect_button.text = (
			"에피소드 재선택"
		)

		reselect_button.custom_minimum_size = Vector2(
			0,
			MOBILE_OPTION_HEIGHT
		)

		reselect_button.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)

		reselect_button.alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)

		reselect_button.add_theme_font_size_override(
			"font_size",
			19
		)

		reselect_button.modulate = Color(
			0.82,
			0.84,
			0.87,
			1.0
		)

		reselect_button.add_theme_stylebox_override(
			"normal",
			_make_mobile_choice_style(
				Color(
					0.035,
					0.038,
					0.043,
					1.0
				)
			)
		)

		reselect_button.add_theme_stylebox_override(
			"hover",
			_make_mobile_choice_style(
				MOBILE_CARD_HOVER_BG
			)
		)

		reselect_button.add_theme_stylebox_override(
			"pressed",
			_make_mobile_choice_style(
				MOBILE_CARD_PRESSED_BG
			)
		)

		reselect_button.pressed.connect(
			_on_episode_back_pressed
		)

		mobile_options_container.add_child(
			reselect_button
		)


	var auxiliary_button_count: int = 0


	if (
		show_undo_button
		or show_episode_reselect_button
	):

		auxiliary_button_count = 1


	var total_button_count: int = (
		option_count
		+ auxiliary_button_count
	)


	var options_height: float = 0.0


	if total_button_count > 0:

		options_height = (
			total_button_count
				* MOBILE_OPTION_HEIGHT
			+ max(
				total_button_count - 1,
				0
			)
				* MOBILE_OPTION_GAP
		)


	var panel_height: float = (
		options_y
		+ options_height
		+ MOBILE_MARGIN
	)


	panel_height = max(
		panel_height,
		150.0
	)


	mobile_dialogue_panel.position = Vector2(
		0,
		top_y
	)


	mobile_dialogue_panel.size = Vector2(
		screen_width,
		panel_height
	)


	return panel_height


# =========================================================
# 모바일 선택
# =========================================================

func _on_mobile_option_pressed(
	index: int
) -> void:

	if is_restoring_dialogue:
		return


	if not dialogue_box.is_running():
		return


	if RoomManager.has_room():

		pending_choice_snapshot = (
			RoomManager.create_dialogue_undo_snapshot()
		)


	dialogue_box.select_option(
		index
	)


# =========================================================
# 모바일 토론 위치
# =========================================================

func _layout_mobile_discussion(
	top_y: float,
	viewport_size: Vector2
) -> void:

	mobile_discussion_panel.visible = true


	mobile_discussion_panel.position = Vector2(
		0,
		top_y
	)


	var panel_height: float = (
		viewport_size.y
		- top_y
	)


	panel_height = max(
		panel_height,
		300.0
	)


	mobile_discussion_panel.size = Vector2(
		viewport_size.x,
		panel_height
	)


	var w: float = (
		mobile_discussion_panel.size.x
	)

	var h: float = (
		mobile_discussion_panel.size.y
	)


	# -----------------------------------------------------
	# 제목
	# -----------------------------------------------------

	mobile_discussion_title.position = Vector2(
		16,
		16
	)


	mobile_discussion_title.size = Vector2(
		w - 32,
		38
	)


	# -----------------------------------------------------
	# 설명
	# -----------------------------------------------------

	mobile_discussion_subtitle.position = Vector2(
		16,
		54
	)


	mobile_discussion_subtitle.size = Vector2(
		w - 32,
		28
	)


	# -----------------------------------------------------
	# 다운로드 버튼
	# -----------------------------------------------------

	mobile_download_button.position = Vector2(
		w - 156,
		14
	)

	mobile_download_button.size = Vector2(
		140,
		40
	)

	mobile_download_button.visible = not _mobile_comment_composer_mode
	mobile_composer_back_button.visible = _mobile_comment_composer_mode
	mobile_composer_back_button.position = Vector2(w - 132, 14)
	mobile_composer_back_button.size = Vector2(116, 40)


	# -----------------------------------------------------
	# 선
	# -----------------------------------------------------

	mobile_discussion_separator.position = Vector2(
		16,
		90
	)


	mobile_discussion_separator.size = Vector2(
		w - 32,
		4
	)


	# -----------------------------------------------------
	# 댓글 목록
	# -----------------------------------------------------

	mobile_feed_scroll.position = Vector2(
		16,
		106
	)


	mobile_feed_scroll.size = Vector2(
		w - 32,
		max(
			h - 184,
			100.0
		)
	)


	mobile_feed_container.custom_minimum_size = Vector2(
		w - 52,
		0
	)


	# -----------------------------------------------------
	# 입력
	# -----------------------------------------------------

	mobile_message_input.position = Vector2(
		16,
		h - 64
	)


	mobile_message_input.size = Vector2(
		w - 130,
		50
	)


	# -----------------------------------------------------
	# 등록
	# -----------------------------------------------------

	mobile_submit_button.position = Vector2(
		w - 100,
		h - 64
	)


	mobile_submit_button.size = Vector2(
		84,
		50
	)

	_place_mobile_web_input()

	_refresh_mobile_feed()


func _raise_mobile_discussion_above_keyboard(viewport_size: Vector2) -> void:

	if not ScreenLayout.is_mobile_portrait() or _mobile_keyboard_height_px <= 0.0:
		return

	var physical_height := float(DisplayServer.window_get_size().y)
	if physical_height <= 0.0:
		return

	var keyboard_height := _mobile_keyboard_height_px * viewport_size.y / physical_height
	var visible_bottom := viewport_size.y - keyboard_height - 12.0
	var input_bottom := mobile_message_input.get_global_rect().end.y
	var upward_shift := maxf(0.0, input_bottom - visible_bottom)

	if upward_shift <= 0.0:
		return

	mobile_discussion_panel.position.y -= upward_shift
	_place_mobile_web_input()


# =========================================================
# 모바일 댓글 Enter
# =========================================================

func _on_mobile_message_submitted(
	_text: String
) -> void:

	_sync_mobile_web_input_now()
	_finish_mobile_comment_composer()
	mobile_message_input.apply_ime()


	call_deferred(
		"_submit_mobile_comment_after_ime"
	)


# =========================================================
# 모바일 댓글 등록
# =========================================================

func _on_mobile_submit_pressed() -> void:

	_sync_mobile_web_input_now()
	_finish_mobile_comment_composer()
	mobile_message_input.apply_ime()


	call_deferred(
		"_submit_mobile_comment_after_ime"
	)


func _submit_mobile_comment_after_ime() -> void:

	var message: String = (
		mobile_message_input
			.text
			.strip_edges()
	)


	if message.is_empty():
		return


	if not RoomManager.has_room():
		return


	mobile_message_input.clear()
	_place_mobile_web_input()


	await CommentSync.submit(
		GameData.selected_name,
		message
	)


	# Do not focus Godot's proxy LineEdit on Web; the browser overlay retains
	# focus and avoids triggering the in-app browser's canvas keyboard path.


# =========================================================
# 모바일 댓글 새로고침
# =========================================================

func _refresh_mobile_feed() -> void:

	if mobile_feed_container == null:
		return


	for child in (
		mobile_feed_container.get_children()
	):

		mobile_feed_container.remove_child(
			child
		)

		child.queue_free()


	if not RoomManager.has_room():

		_add_mobile_empty_message(
			"현재 방이 없습니다."
		)

		return


	var feed: Array = (
		RoomManager.get_feed()
	)


	if feed.is_empty():

		_add_mobile_empty_message(
			"아직 작성한 기록이 없습니다."
		)

		return


	var previous_scene_title: String = ""


	for entry in feed:

		var scene_title: String = str(
			entry.get(
				"scene_title",
				""
			)
		)


		if (
			not scene_title.is_empty()
			and scene_title
			!= previous_scene_title
		):

			_add_mobile_scene_header(
				scene_title
			)

			previous_scene_title = (
				scene_title
			)


		_add_mobile_comment(
			entry
		)


	if mobile_editing_comment_id.is_empty():

		call_deferred(
			"_scroll_mobile_feed_to_bottom"
		)


func _scroll_mobile_feed_to_bottom() -> void:

	await get_tree().process_frame


	var scroll_bar := (
		mobile_feed_scroll.get_v_scroll_bar()
	)


	mobile_feed_scroll.scroll_vertical = int(
		scroll_bar.max_value
	)


# =========================================================
# 모바일 장면 제목
# =========================================================

func _add_mobile_scene_header(
	scene_title: String
) -> void:

	var label := Label.new()

	mobile_feed_container.add_child(
		label
	)


	label.text = (
		"[ "
		+ scene_title
		+ " ]"
	)


	label.add_theme_font_size_override(
		"font_size",
		18
	)


	label.modulate = Color(
		0.62,
		0.70,
		0.76,
		1.0
	)


# =========================================================
# 모바일 댓글
# =========================================================

func _add_mobile_comment(
	entry: Dictionary
) -> void:

	var comment_id: String = str(
		entry.get(
			"comment_id",
			""
		)
	)

	var speaker: String = str(
		entry.get(
			"speaker",
			""
		)
	)

	var text: String = str(
		entry.get(
			"text",
			""
		)
	)

	var box := VBoxContainer.new()
	mobile_feed_container.add_child(box)
	box.add_theme_constant_override("separation", 4)

	var header := HBoxContainer.new()
	box.add_child(header)

	var speaker_label := Label.new()
	header.add_child(speaker_label)
	speaker_label.text = speaker
	speaker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speaker_label.add_theme_font_size_override("font_size", 17)
	speaker_label.modulate = Color(0.78, 0.81, 0.84, 1.0)

	if (
		RoomManager.can_edit_comment(entry)
		and mobile_editing_comment_id != comment_id
	):
		var edit_button := Button.new()
		header.add_child(edit_button)
		edit_button.text = "수정"
		edit_button.flat = true
		edit_button.custom_minimum_size = Vector2(58, 30)
		edit_button.add_theme_font_size_override("font_size", 14)
		edit_button.pressed.connect(
			_on_mobile_edit_pressed.bind(comment_id)
		)
		var delete_button := Button.new()
		header.add_child(delete_button)
		delete_button.text = "삭제"
		delete_button.flat = true
		delete_button.custom_minimum_size = Vector2(58, 30)
		delete_button.add_theme_font_size_override("font_size", 14)
		delete_button.pressed.connect(_on_mobile_delete_pressed.bind(comment_id))

	if mobile_editing_comment_id == comment_id:
		var edit_input := LineEdit.new()
		box.add_child(edit_input)
		edit_input.virtual_keyboard_enabled = false
		edit_input.focus_mode = Control.FOCUS_NONE
		edit_input.gui_input.connect(
			_on_mobile_comment_input_gui_input.bind(edit_input)
		)
		edit_input.text = text
		edit_input.set_meta("mobile_comment_id", comment_id)
		edit_input.custom_minimum_size = Vector2(0, 48)
		edit_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit_input.add_theme_font_size_override("font_size", 19)
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
		save_button.custom_minimum_size = Vector2(76, 40)
		save_button.pressed.connect(
			_on_mobile_edit_save_pressed.bind(comment_id, edit_input)
		)

		var cancel_button := Button.new()
		button_row.add_child(cancel_button)
		cancel_button.text = "취소"
		cancel_button.custom_minimum_size = Vector2(76, 40)
		cancel_button.pressed.connect(
			_on_mobile_edit_cancel_pressed
		)

		call_deferred("_focus_mobile_edit_input", edit_input)
		return

	var message_label := Label.new()
	box.add_child(message_label)
	message_label.text = text
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.add_theme_font_size_override("font_size", 20)


# =========================================================
# 모바일 댓글 수정
# =========================================================

func _on_mobile_edit_pressed(
	comment_id: String
) -> void:

	mobile_editing_comment_id = comment_id
	_refresh_mobile_feed()


func _focus_mobile_edit_input(
	edit_input: LineEdit
) -> void:

	if not is_instance_valid(edit_input):
		return

	if not OS.has_feature("web"):
		edit_input.grab_focus()
		edit_input.caret_column = 0


func _on_mobile_edit_save_pressed(
	comment_id: String,
	edit_input: LineEdit
) -> void:

	if not is_instance_valid(edit_input):
		return

	_close_mobile_web_input()
	edit_input.apply_ime()
	call_deferred(
		"_save_mobile_edit_after_ime",
		comment_id,
		edit_input
	)


func _save_mobile_edit_after_ime(
	comment_id: String,
	edit_input: LineEdit
) -> void:

	if not is_instance_valid(edit_input):
		return

	var new_text: String = edit_input.text.strip_edges()

	if new_text.is_empty():
		return

	mobile_editing_comment_id = ""

	await CommentSync.edit(
		comment_id,
		new_text
	)


func _on_mobile_edit_cancel_pressed() -> void:

	mobile_editing_comment_id = ""
	_refresh_mobile_feed()


func _on_mobile_delete_pressed(comment_id: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "기록 삭제"
	dialog.dialog_text = "기록을 삭제하시겠습니까?\n복구할 수 없습니다."
	dialog.ok_button_text = "삭제"
	dialog.cancel_button_text = "취소"
	dialog.min_size = Vector2(440, 210)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#202225")
	style.border_color = Color(1, 1, 1, 0.32)
	style.set_border_width_all(1)
	style.set_content_margin_all(24)
	dialog.add_theme_stylebox_override("panel", style)
	dialog.add_theme_font_size_override("title_font_size", 26)
	add_child(dialog)
	dialog.confirmed.connect(func(): CommentSync.delete_comment(comment_id))
	dialog.popup_centered()


# =========================================================
# 모바일 댓글 없음
# =========================================================

func _add_mobile_empty_message(
	message: String
) -> void:

	var label := Label.new()

	mobile_feed_container.add_child(
		label
	)


	label.text = (
		message
	)


	label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)


	label.custom_minimum_size = Vector2(
		0,
		80
	)


	label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)


	label.add_theme_font_size_override(
		"font_size",
		18
	)


	label.modulate = Color(
		0.6,
		0.63,
		0.66,
		1.0
	)


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
# PC 레이아웃
# =========================================================

func _get_desktop_dialogue_text_height() -> float:

	if (
		dialogue_box == null
		or dialogue_box.dialogue_label == null
	):

		return DESKTOP_TEXT_MIN_HEIGHT


	var content_height: float = float(
		dialogue_box.dialogue_label.get_content_height()
	)


	if content_height <= 0.0:

		content_height = (
			DESKTOP_TEXT_MIN_HEIGHT
		)


	return clamp(
		content_height + 8.0,
		DESKTOP_TEXT_MIN_HEIGHT,
		DESKTOP_TEXT_MAX_HEIGHT
	)


func _get_desktop_options_height() -> float:

	var option_count: int = (
		current_options.size()
	)


	if option_count <= 0:
		return 0.0


	var separation: float = 4.0


	if dialogue_box.options_container != null:

		separation = float(
			dialogue_box.options_container.get_theme_constant(
				"separation"
			)
		)


	var result: float = 0.0


	for idx in range(
		option_count
	):

		var option_height: float = (
			DESKTOP_OPTION_HEIGHT
		)


		if (
			dialogue_box.options_container != null
			and idx
				< dialogue_box.options_container.get_child_count()
		):

			var child = (
				dialogue_box.options_container.get_child(
					idx
				)
			)


			if child is Button:

				var button := (
					child as Button
				)


				option_height = max(
					option_height,
					button.get_combined_minimum_size().y
				)


		result += option_height


	if option_count > 1:

		result += (
			float(option_count - 1)
			* separation
		)


	return result


func _get_desktop_dialogue_required_height() -> float:

	var speaker_height: float = 24.0


	if dialogue_box.speaker_label != null:

		speaker_height = max(
			speaker_height,
			dialogue_box.speaker_label.get_combined_minimum_size().y
		)


	var text_height: float = (
		_get_desktop_dialogue_text_height()
	)


	var options_height: float = (
		_get_desktop_options_height()
	)


	var required_height: float = (
		DESKTOP_DIALOGUE_VERTICAL_PADDING
		+ speaker_height
		+ text_height
		+ options_height
	)


	return clamp(
		required_height,
		DESKTOP_CHOICE_DIALOGUE_MIN_HEIGHT if current_has_choice else DESKTOP_DIALOGUE_MIN_HEIGHT,
		DESKTOP_DIALOGUE_MAX_HEIGHT
	)


func _apply_desktop_layout() -> void:

	_set_mobile_ui_visible(
		false
	)


	# =====================================================
	# 기존 씬 복원
	# =====================================================

	school_background.visible = true
	dialogue_box.visible = true


	if scene_background is CanvasItem:

		scene_background.visible = true


	if desktop_discussion is CanvasItem:

		desktop_discussion.visible = true


	# =====================================================
	# 현재 대화창 폭 먼저 적용
	#
	# RichTextLabel의 줄바꿈 높이를 현재 폭 기준으로 계산하기 위함.
	# =====================================================

	var dialogue_x: float = 0.0
	var dialogue_width: float = 0.0


	if current_has_choice:

		dialogue_x = (
			CHOICE_DIALOGUE_POSITION.x
		)

		dialogue_width = (
			CHOICE_DIALOGUE_SIZE.x
		)

	else:

		dialogue_x = (
			NORMAL_DIALOGUE_POSITION.x
		)

		dialogue_width = (
			NORMAL_DIALOGUE_SIZE.x
		)


	dialogue_box.size = Vector2(
		dialogue_width,
		DESKTOP_DIALOGUE_MAX_HEIGHT
	)


	# 선택지 텍스트가 길면 여러 줄로 표시 가능
	_refresh_desktop_choice_buttons()


	# =====================================================
	# 실제 내용에 맞춰 높이 자동 계산
	# =====================================================

	var dialogue_height: float = (
		_get_desktop_dialogue_required_height()
	)


	var dialogue_y: float = (
		DESKTOP_DIALOGUE_BOTTOM
		- dialogue_height
	)


	dialogue_box.position = Vector2(
		dialogue_x,
		dialogue_y
	)


	dialogue_box.size = Vector2(
		dialogue_width,
		dialogue_height
	)


	# RichTextLabel이 필요한 만큼 최소 공간을 확보.
	# 아주 긴 글은 최대 높이 이후 내부 스크롤.
	if dialogue_box.dialogue_label != null:

		var current_minimum_size: Vector2 = (
			dialogue_box.dialogue_label.custom_minimum_size
		)


		dialogue_box.dialogue_label.custom_minimum_size = Vector2(
			current_minimum_size.x,
			_get_desktop_dialogue_text_height()
		)


	# =====================================================
	# Insight
	#
	# 대화창이 위로 늘어나면 Insight도 같이 위로 이동.
	# =====================================================

	if active_insight_text.is_empty():

		insight_panel.visible = false

	else:

		insight_panel.visible = true


		insight_label.text = (
			"["
			+ active_insight_title
			+ "]  "
			+ active_insight_text
		)


		var insight_x: float = (
			CHOICE_INSIGHT_POSITION.x
			if current_has_choice
			else NORMAL_INSIGHT_POSITION.x
		)


		var insight_width: float = (
			CHOICE_INSIGHT_SIZE.x
			if current_has_choice
			else NORMAL_INSIGHT_SIZE.x
		)


		insight_panel.position = Vector2(
			insight_x,
			dialogue_y
				- CHOICE_INSIGHT_SIZE.y
				- DESKTOP_INSIGHT_GAP
		)


		insight_panel.size = Vector2(
			insight_width,
			CHOICE_INSIGHT_SIZE.y
		)


	# =====================================================
	# 초상화
	#
	# 대화창이 커져도 기존처럼 화면 하단에 고정.
	# =====================================================

	if current_has_choice:

		portrait_box.visible = true


		# 초상화 아래에 보조 버튼 공간을 항상 확보한다.
		# 버튼의 바닥선이 선택지 대화창 바닥선과 정확히 맞도록 배치.
		portrait_box.position = Vector2(
			PORTRAIT_POSITION.x,
			DESKTOP_DIALOGUE_BOTTOM
				- 38.0
				- 10.0
				- PORTRAIT_SIZE.y
		)


		portrait_box.size = (
			PORTRAIT_SIZE
		)

	else:

		portrait_box.visible = false


	# =====================================================
	# 하단 보조 버튼
	#
	# 첫 실제 선택 화면에는 "에피소드 재선택"
	# 그 다음부터는 기존 "이전" 버튼.
	# =====================================================

	if desktop_undo_button != null:

		desktop_undo_button.visible = (
			_can_show_undo_button()
		)


		# 초상화 바로 아래.
		# 버튼의 바닥 = 선택지 대화창의 바닥(DESKTOP_DIALOGUE_BOTTOM)
		desktop_undo_button.position = Vector2(
			PORTRAIT_POSITION.x,
			DESKTOP_DIALOGUE_BOTTOM
				- 38.0
		)


		desktop_undo_button.size = Vector2(
			PORTRAIT_SIZE.x,
			38
		)


	if episode_back_button != null:

		episode_back_button.visible = (
			_can_show_episode_reselect_button()
		)


		# "이전" 버튼과 완전히 같은 위치 / 크기
		episode_back_button.position = Vector2(
			PORTRAIT_POSITION.x,
			DESKTOP_DIALOGUE_BOTTOM
				- 38.0
		)


		episode_back_button.size = Vector2(
			PORTRAIT_SIZE.x,
			38
		)


	if desktop_discussion != null:

		if desktop_discussion.has_method(
			"apply_desktop_layout"
		):

			desktop_discussion.call(
				"apply_desktop_layout"
			)


		if desktop_discussion.has_method(
			"_refresh_feed"
		):

			desktop_discussion.call(
				"_refresh_feed"
			)


# =========================================================
# PC 선택지
# =========================================================

func _refresh_desktop_choice_buttons() -> void:

	var container = (
		dialogue_box.options_container
	)


	for idx in range(
		container.get_child_count()
	):

		var button = (
			container.get_child(idx)
		)


		if not button is Button:
			continue


		button.custom_minimum_size = Vector2(
			0,
			DESKTOP_OPTION_HEIGHT
		)


		button.size_flags_horizontal = (
			Control.SIZE_FILL
		)


		button.alignment = (
			HORIZONTAL_ALIGNMENT_LEFT
		)


		button.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART
		)


		# PC는 DialogueBox 내부 버튼이 직접 select_option()을 호출하므로
		# pressed보다 먼저 발생하는 button_down에서 선택 직전 상태를 잡는다.
		var snapshot_callable: Callable = (
			_on_desktop_option_button_down.bind(
				idx
			)
		)


		if not button.button_down.is_connected(
			snapshot_callable
		):

			button.button_down.connect(
				snapshot_callable
			)


# =========================================================
# PC 선택 직전 상태 저장
# =========================================================

func _on_desktop_option_button_down(
	_index: int
) -> void:

	if is_restoring_dialogue:
		return


	if is_undoing_dialogue:
		return


	if not RoomManager.has_room():
		return


	pending_choice_snapshot = (
		RoomManager.create_dialogue_undo_snapshot()
	)


# =========================================================
# 선택 기록
# =========================================================

func _on_dialogue_option_selected(
	idx: int
) -> void:

	if is_restoring_dialogue:
		return


	if is_undoing_dialogue:
		return


	if not RoomManager.has_room():
		return


	var option_text: String = ""


	if (
		idx >= 0
		and idx < current_options.size()
	):

		option_text = str(
			current_options[idx]
		)


	# 마우스/터치 직전에 저장한 스냅샷을 우선 사용.
	# 키보드 등으로 직접 선택된 경우에는 여기서 안전하게 하나 만든다.
	var snapshot: Dictionary = (
		pending_choice_snapshot.duplicate(true)
	)


	if snapshot.is_empty():

		snapshot = (
			RoomManager.create_dialogue_undo_snapshot()
		)


	RoomManager.record_dialogue_selection(
		idx,
		option_text,
		GameData.selected_name,
		snapshot
	)


	pending_choice_snapshot = {}


	_apply_current_layout()


# =========================================================
# 이전 선택으로 돌아가기
# =========================================================

func _on_undo_dialogue_pressed() -> void:

	if is_restoring_dialogue:
		return


	if is_undoing_dialogue:
		return


	if not RoomManager.has_room():
		return


	if not RoomManager.can_undo_dialogue_selection():
		return


	is_undoing_dialogue = true


	# 먼저 저장 기록을 실제 선택 직전으로 롤백
	var undo_success: bool = (
		RoomManager.undo_last_dialogue_selection()
	)


	if not undo_success:

		is_undoing_dialogue = false
		return


	pending_choice_snapshot = {}

	pending_insight_title = ""
	pending_insight_text = ""

	active_insight_title = ""
	active_insight_text = ""


	# 저장된 history를 다시 재생해
	# 방금 취소한 선택 직전 화면으로 복원
	await _replay_dialogue_to_current_history()


	is_undoing_dialogue = false


	_apply_current_layout()


# =========================================================
# 현재 저장 history 지점까지 빠른 재생
#
# transcript에는 다시 기록하지 않는다.
# =========================================================

func _replay_dialogue_to_current_history() -> void:

	var start_id: String = "START1"


	if RoomManager.has_room():

		start_id = str(
			RoomManager.get_dialogue_start_id()
		).strip_edges()


	if start_id.is_empty():

		start_id = "START1"


	var history: Array = (
		RoomManager.get_dialogue_history()
	)


	is_restoring_dialogue = true


	if dialogue_box.is_running():

		dialogue_box.stop()


	dialogue_box.start(
		start_id
	)


	await get_tree().process_frame


	for entry in history:

		if not dialogue_box.is_running():
			break


		var option_index: int = int(
			entry.get(
				"option_index",
				0
			)
		)


		dialogue_box.select_option(
			option_index
		)


		await get_tree().process_frame


	is_restoring_dialogue = false

	pending_choice_snapshot = {}


	# 최종 화면 기준으로 UI 다시 정리
	_apply_current_layout()


# =========================================================
# 시작 / 저장 복원
# =========================================================

func _start_or_restore_dialogue() -> void:

	await get_tree().process_frame


	var start_id: String = "START1"
	var history: Array = []


	if RoomManager.has_room():

		start_id = str(
			RoomManager.get_dialogue_start_id()
		).strip_edges()


		history = (
			RoomManager.get_dialogue_history()
		)


	if start_id.is_empty():

		start_id = "START1"


	# =====================================================
	# 새 게임
	# =====================================================

	if history.is_empty():

		is_restoring_dialogue = false
		_prepare_first_dialogue_wait()


		dialogue_box.start(
			start_id
		)


		return


	# =====================================================
	# 저장 복원
	# =====================================================

	is_restoring_dialogue = true


	dialogue_box.start(
		start_id
	)


	await get_tree().process_frame


	for entry in history:

		if not dialogue_box.is_running():
			break


		var option_index: int = int(
			entry.get(
				"option_index",
				0
			)
		)


		dialogue_box.select_option(
			option_index
		)


		await get_tree().process_frame


	is_restoring_dialogue = false

	pending_choice_snapshot = {}


	_apply_current_layout()

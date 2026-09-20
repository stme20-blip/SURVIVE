extends Control


var story_index := 0

var story_lines := [
	"처음에는 단순한 실종 사건이라고 생각했다.",

	"그러나 사람이 사라진 자리에서는\n어떤 흔적도 발견되지 않았다.",

	"그리고 얼마 지나지 않아\n존재해서는 안 되는 장소들이 나타나기 시작했다.",

	"끝나지 않는 복도.\n존재하지 않는 방.\n들어간 사람을 돌려보내지 않는 공간.",

	"왜 이런 장소가 생겨났는지는 아무도 모른다.",

	"한 가지 분명한 것은,\n그 안에서 살아남으려면 선택해야 한다는 것.",

	"그리고 어느 순간,\n당신도 그곳에 있었다."
]

var story_label: Label
var next_button: Button


func _ready() -> void:
	_create_ui()
	_show_story()


func _create_ui() -> void:
	# 배경
	var background := ColorRect.new()
	add_child(background)

	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	background.color = Color(
		0.015,
		0.018,
		0.022,
		1.0
	)


	# 텍스트 중앙 배치
	var center := CenterContainer.new()
	add_child(center)

	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)


	var box := VBoxContainer.new()
	center.add_child(box)

	box.custom_minimum_size = Vector2(
		760,
		260
	)

	box.add_theme_constant_override(
		"separation",
		35
	)


	# 프롤로그 글
	story_label = Label.new()
	box.add_child(story_label)

	story_label.custom_minimum_size = Vector2(
		760,
		150
	)

	story_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	story_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	story_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	story_label.add_theme_font_size_override(
		"font_size",
		22
	)


	# 다음
	next_button = Button.new()
	box.add_child(next_button)

	next_button.text = "계속"

	next_button.custom_minimum_size = Vector2(
		0,
		50
	)

	next_button.pressed.connect(
		_on_next_pressed
	)


func _show_story() -> void:
	story_label.text = story_lines[
		story_index
	]


func _on_next_pressed() -> void:
	story_index += 1

	if story_index >= story_lines.size():
		get_tree().change_scene_to_file(
			"res://character_select.tscn"
		)

		return

	_show_story()

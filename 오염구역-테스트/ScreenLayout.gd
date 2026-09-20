extends Node


signal layout_changed


# =========================================================
# PC
# =========================================================

const DESKTOP_SIZE := Vector2i(
	1536,
	648
)


# =========================================================
# 모바일
#
# 가상 폭을 720으로 두어
# 글씨 / 버튼이 모바일에서 크게 보이도록 함
# =========================================================

const MOBILE_WIDTH := 720
const MOBILE_MIN_HEIGHT := 1320


var mobile_portrait: bool = false

var _last_target_size := Vector2i.ZERO
var _last_mobile_state := false
var _applying := false


# =========================================================
# 시작
# =========================================================

func _ready() -> void:

	get_viewport().size_changed.connect(
		_on_viewport_size_changed
	)

	call_deferred(
		"_apply_layout"
	)


# =========================================================
# 모바일 여부
# =========================================================

func is_mobile_portrait() -> bool:

	return mobile_portrait


# =========================================================
# 화면 변경
# =========================================================

func _on_viewport_size_changed() -> void:

	if _applying:
		return

	call_deferred(
		"_apply_layout"
	)


# =========================================================
# 레이아웃 적용
# =========================================================

func _apply_layout() -> void:

	if _applying:
		return


	var physical_size := (
		DisplayServer.window_get_size()
	)


	if (
		physical_size.x <= 0
		or physical_size.y <= 0
	):
		return


	var new_mobile_state := (
		physical_size.y > physical_size.x
	)


	var target_size: Vector2i


	# =====================================================
	# 모바일 세로
	# =====================================================

	if new_mobile_state:

		var calculated_height := int(
			round(
				float(MOBILE_WIDTH)
				* float(physical_size.y)
				/ float(physical_size.x)
			)
		)


		target_size = Vector2i(
			MOBILE_WIDTH,
			max(
				calculated_height,
				MOBILE_MIN_HEIGHT
			)
		)


	# =====================================================
	# PC
	# =====================================================

	else:

		target_size = (
			DESKTOP_SIZE
		)


	if (
		target_size == _last_target_size
		and new_mobile_state == _last_mobile_state
	):
		return


	_applying = true


	var window := (
		get_tree().root as Window
	)


	window.content_scale_mode = (
		Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	)

	window.content_scale_aspect = (
		Window.CONTENT_SCALE_ASPECT_KEEP
	)

	window.content_scale_stretch = (
		Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	)

	window.content_scale_size = (
		target_size
	)


	mobile_portrait = (
		new_mobile_state
	)

	_last_target_size = (
		target_size
	)

	_last_mobile_state = (
		new_mobile_state
	)


	_applying = false


	layout_changed.emit()

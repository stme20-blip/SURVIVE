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
# Keep the logical canvas at the device's actual portrait aspect ratio.  A
# 1320px floor made normal phone viewports letterbox horizontally.
const MOBILE_MIN_HEIGHT := 900


var mobile_portrait: bool = false

var _last_target_size := Vector2i.ZERO
var _last_mobile_state := false
var _applying := false


# =========================================================
# 시작
# =========================================================

func _ready() -> void:
	if OS.has_feature("web"):
		_setup_browser_size()
		var timer := Timer.new()
		timer.wait_time = 0.2
		timer.timeout.connect(_apply_layout)
		add_child(timer)
		timer.start()

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
	if OS.has_feature("web"):
		var dimensions: Variant = JSON.parse_string(str(JavaScriptBridge.eval("window.surviveLayoutSize()", true)))
		if dimensions is Array and dimensions.size() == 2:
			physical_size = Vector2i(int(dimensions[0]), int(dimensions[1]))


	if (
		physical_size.x <= 0
		or physical_size.y <= 0
	):
		return


	var new_mobile_state := _is_portrait_display(physical_size)


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


func _is_portrait_display(physical_size: Vector2i) -> bool:
	return physical_size.y > physical_size.x


func _setup_browser_size() -> void:
	JavaScriptBridge.eval("""
		(() => {
			let previous = null;
			let keyboardSize = null;
			window.surviveLayoutSize = () => {
				const width = window.innerWidth;
				const height = window.innerHeight;
				const rotation = window.screen.orientation ? window.screen.orientation.angle : (window.orientation || 0);
				const active = document.activeElement;
				const editing = active && (active.tagName === 'TEXTAREA' || active.tagName === 'INPUT' || active.isContentEditable);
				const touch = navigator.maxTouchPoints > 0;
				const sameFrame = previous && previous.rotation === rotation && Math.abs(previous.width - width) < 2;
				// Freeze only a keyboard-related height reduction, never a real rotation or width change.
				if (touch && sameFrame && editing && height < previous.height - 100) keyboardSize = previous;
				if (keyboardSize && (!sameFrame || height >= keyboardSize.height - 100)) keyboardSize = null;
				if (keyboardSize) return JSON.stringify([width, keyboardSize.height]);
				previous = {width, height, rotation};
				return JSON.stringify([width, height]);
			};
		})();
	""", true)

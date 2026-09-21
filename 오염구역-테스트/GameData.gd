extends Node

signal character_settings_changed(personality_changed: bool)


# =========================================================
# 캐릭터 ID
# =========================================================

# 기본 캐릭터:
# 1 ~ 12
#
# 커스텀 캐릭터:
# 1000
# =========================================================

const CUSTOM_CHARACTER_ID := 1000


# =========================================================
# 현재 선택한 캐릭터 정보
# =========================================================

var selected_character_id: int = 0

var selected_name: String = ""

var selected_portrait_path: String = ""

# 내부 특성 KEY
#
# 예:
# CALM
# CAUTIOUS
# CURIOUS
# DIRECT
# TIMID
var selected_personality: String = ""

var selected_is_custom: bool = false


# =========================================================
# 캐릭터 외형 / 이름 선택
# =========================================================

func set_character_identity(
	character_id: int,
	character_name: String,
	portrait_path: String,
	is_custom: bool = false
) -> void:

	selected_character_id = character_id

	selected_name = character_name

	selected_portrait_path = portrait_path

	selected_is_custom = is_custom


	# 캐릭터를 새로 고르면
	# 특성은 다시 선택해야 함.
	selected_personality = ""


# =========================================================
# 특성 선택
# =========================================================

func set_personality(
	personality_key: String
) -> void:

	selected_personality = (
		personality_key.strip_edges()
	)


# =========================================================
# 선택 정보 초기화
# =========================================================

func clear_character_selection() -> void:

	selected_character_id = 0

	selected_name = ""

	selected_portrait_path = ""

	selected_personality = ""

	selected_is_custom = false


# =========================================================
# 캐릭터 선택 여부
# =========================================================

func has_selected_character() -> bool:

	return (
		selected_character_id != 0
		and not selected_name.strip_edges().is_empty()
	)


# =========================================================
# 초상화 Texture 불러오기
#
# 기본 캐릭터:
# res://...
#
# 커스텀 캐릭터:
# user://...
#
# 둘 다 처리
# =========================================================

func load_selected_portrait_texture() -> Texture2D:

	return load_portrait_texture(
		selected_portrait_path
	)


func load_portrait_texture(
	path: String
) -> Texture2D:

	var clean_path := (
		path.strip_edges()
	)


	if clean_path.is_empty():
		return null


	# =====================================================
	# 기본 캐릭터
	#
	# 프로젝트에 Import된 리소스
	# =====================================================

	if clean_path.begins_with(
		"res://"
	):

		if ResourceLoader.exists(
			clean_path
		):

			return load(
				clean_path
			) as Texture2D


		return null


	# =====================================================
	# 커스텀 캐릭터
	#
	# 실행 중 사용자가 선택한 이미지
	# =====================================================

	if clean_path.begins_with(
		"user://"
	):

		if not FileAccess.file_exists(
			clean_path
		):
			return null


		var image := Image.load_from_file(
			clean_path
		)


		if image == null:
			return null


		if image.is_empty():
			return null


		return ImageTexture.create_from_image(
			image
		)


	return null

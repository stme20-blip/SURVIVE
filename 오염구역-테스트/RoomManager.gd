extends Node


signal feed_changed
signal comment_added(comment_id: String)
signal comment_edited(comment_id: String)


# =========================================================
# 저장 설정
# =========================================================

const SAVE_DIR := "user://rooms/"
const EXPORT_DIR := "user://exports/"

const LOCAL_MEMBER_ID := "LOCAL_1"
const SCHEMA_VERSION := 4


var current_room: Dictionary = {}


# =========================================================
# 시작
# =========================================================

func _ready() -> void:

	_ensure_directory(
		SAVE_DIR
	)

	_ensure_directory(
		EXPORT_DIR
	)


# =========================================================
# 폴더
# =========================================================

func _ensure_directory(
	path: String
) -> void:

	var absolute_path: String = (
		ProjectSettings.globalize_path(
			path
		)
	)


	if DirAccess.dir_exists_absolute(
		absolute_path
	):
		return


	var error := (
		DirAccess.make_dir_recursive_absolute(
			absolute_path
		)
	)


	if error != OK:

		push_error(
			"폴더 생성 실패: "
			+ path
		)


# =========================================================
# 새 방
# =========================================================

func create_room(
	room_name: String,
	max_players: int
) -> Dictionary:

	max_players = clamp(
		max_players,
		1,
		3
	)


	if room_name.strip_edges().is_empty():

		room_name = "새 방"


	var room_id: String = (
		_generate_room_id()
	)


	var host_member := {

		"member_id": LOCAL_MEMBER_ID,

		"slot": 1,

		"is_host": true,

		"display_name": "Player 1",

		"character_id": 0,

		"character_name": "",

		"portrait_path": "",

		"personality": ""
	}


	current_room = {

		"schema_version": SCHEMA_VERSION,

		"room_id": room_id,

		"room_name": room_name,

		"max_players": max_players,

		"members": [
			host_member
		],

		"game_state": {

			"scene_file": "res://main.tscn",

			"scene_id": "school_hallway",

			"scene_title": "학교 복도",

			"checkpoint": "START1",

			"dialogue_start_id": "START1",

			"dialogue_file": "",

			"dialogue_history": [],

			"selected_character_id": 0,

			"story_flags": {},

			"inventory": []
		},

		"feed": [],

		"transcript": [],

		"created_at": _get_current_time(),

		"updated_at": _get_current_time()
	}


	save_current_room()


	return current_room


# =========================================================
# ID 생성
# =========================================================

func _generate_room_id() -> String:

	var unix_time := int(
		Time.get_unix_time_from_system()
	)


	var rng := RandomNumberGenerator.new()

	rng.randomize()


	return (
		"ROOM_"
		+ str(unix_time)
		+ "_"
		+ str(
			rng.randi_range(
				1000,
				9999
			)
		)
	)


func _generate_comment_id() -> String:

	var millis := int(
		Time.get_unix_time_from_system()
		* 1000.0
	)


	var rng := RandomNumberGenerator.new()

	rng.randomize()


	return (
		"COMMENT_"
		+ str(millis)
		+ "_"
		+ str(
			rng.randi_range(
				100000,
				999999
			)
		)
	)


# =========================================================
# 시간
# =========================================================

func _get_current_time() -> String:

	return (
		Time.get_datetime_string_from_system()
	)


# =========================================================
# 저장
# =========================================================

func save_current_room() -> bool:

	if current_room.is_empty():
		return false


	var room_id: String = str(
		current_room.get(
			"room_id",
			""
		)
	)


	if room_id.is_empty():
		return false


	current_room["updated_at"] = (
		_get_current_time()
	)


	var path := (
		SAVE_DIR
		+ room_id
		+ ".json"
	)


	var file := FileAccess.open(
		path,
		FileAccess.WRITE
	)


	if file == null:

		push_error(
			"방 저장 실패: "
			+ path
		)

		return false


	file.store_string(
		JSON.stringify(
			current_room,
			"\t"
		)
	)


	file.close()


	return true


# =========================================================
# 불러오기
# =========================================================

func load_room(
	room_id: String
) -> bool:

	var path := (
		SAVE_DIR
		+ room_id
		+ ".json"
	)


	if not FileAccess.file_exists(
		path
	):
		return false


	var file := FileAccess.open(
		path,
		FileAccess.READ
	)


	if file == null:
		return false


	var json_text: String = (
		file.get_as_text()
	)


	file.close()


	var parsed = JSON.parse_string(
		json_text
	)


	if not parsed is Dictionary:
		return false


	current_room = parsed


	_normalize_loaded_room()


	return true


# =========================================================
# 예전 저장 데이터 보정
# =========================================================

func _normalize_loaded_room() -> void:

	current_room["schema_version"] = (
		SCHEMA_VERSION
	)


	if not current_room.has(
		"members"
	):

		current_room["members"] = []


	if not current_room.has(
		"feed"
	):

		current_room["feed"] = []


	if not current_room.has(
		"transcript"
	):

		current_room["transcript"] = []


	if not current_room.has(
		"game_state"
	):

		current_room["game_state"] = {

			"scene_file": "res://main.tscn",

			"scene_id": "school_hallway",

			"scene_title": "학교 복도",

			"checkpoint": "START1",

			"dialogue_start_id": "START1",

			"dialogue_file": "",

			"dialogue_history": [],

			"selected_character_id": 0,

			"story_flags": {},

			"inventory": []
		}


	var state: Dictionary = (
		current_room.get(
			"game_state",
			{}
		)
	)


	if not state.has(
		"dialogue_start_id"
	):

		state["dialogue_start_id"] = (
			"START1"
		)


	if not state.has(
		"dialogue_history"
	):

		state["dialogue_history"] = []


	if not state.has(
		"dialogue_file"
	):

		state["dialogue_file"] = ""


	current_room["game_state"] = state


	# =====================================================
	# 기존 댓글에 comment_id / author_id 추가
	# =====================================================

	var feed: Array = (
		current_room.get(
			"feed",
			[]
		)
	)


	var comment_ids: Array[String] = []


	for index in range(
		feed.size()
	):

		var entry: Dictionary = (
			feed[index]
		)


		if str(
			entry.get(
				"type",
				"comment"
			)
		) != "comment":

			continue


		var comment_id: String = str(
			entry.get(
				"comment_id",
				""
			)
		)


		if comment_id.is_empty():

			comment_id = (
				_generate_comment_id()
			)


		entry["comment_id"] = (
			comment_id
		)


		if str(
			entry.get(
				"author_id",
				""
			)
		).is_empty():

			entry["author_id"] = (
				LOCAL_MEMBER_ID
			)


		if str(
			entry.get(
				"updated_at",
				""
			)
		).is_empty():

			entry["updated_at"] = str(
				entry.get(
					"created_at",
					_get_current_time()
				)
			)


		feed[index] = entry


		comment_ids.append(
			comment_id
		)


	current_room["feed"] = feed


	# =====================================================
	# transcript의 기존 댓글에도 같은 ID 부여
	# =====================================================

	var transcript: Array = (
		current_room.get(
			"transcript",
			[]
		)
	)


	var comment_number := 0


	for index in range(
		transcript.size()
	):

		var entry: Dictionary = (
			transcript[index]
		)


		if str(
			entry.get(
				"type",
				""
			)
		) != "comment":

			continue


		var comment_id := ""


		if comment_number < comment_ids.size():

			comment_id = (
				comment_ids[
					comment_number
				]
			)

		else:

			comment_id = (
				_generate_comment_id()
			)


		entry["comment_id"] = (
			comment_id
		)


		if str(
			entry.get(
				"author_id",
				""
			)
		).is_empty():

			entry["author_id"] = (
				LOCAL_MEMBER_ID
			)


		if str(
			entry.get(
				"updated_at",
				""
			)
		).is_empty():

			entry["updated_at"] = str(
				entry.get(
					"created_at",
					_get_current_time()
				)
			)


		transcript[index] = entry


		comment_number += 1


	current_room["transcript"] = (
		transcript
	)


	save_current_room()


# =========================================================
# 저장된 방
# =========================================================

func get_saved_rooms() -> Array:

	var rooms: Array = []


	var dir := DirAccess.open(
		SAVE_DIR
	)


	if dir == null:
		return rooms


	dir.list_dir_begin()


	while true:

		var file_name := (
			dir.get_next()
		)


		if file_name.is_empty():
			break


		if dir.current_is_dir():
			continue


		if not file_name.ends_with(
			".json"
		):
			continue


		var path := (
			SAVE_DIR
			+ file_name
		)


		var file := FileAccess.open(
			path,
			FileAccess.READ
		)


		if file == null:
			continue


		var parsed = JSON.parse_string(
			file.get_as_text()
		)


		file.close()


		if parsed is Dictionary:

			rooms.append(
				parsed
			)


	dir.list_dir_end()


	rooms.sort_custom(

		func(a, b):

			return str(
				a.get(
					"updated_at",
					""
				)
			) > str(
				b.get(
					"updated_at",
					""
				)
			)
	)


	return rooms


# =========================================================
# 방 삭제
# =========================================================

func delete_room(
	room_id: String
) -> bool:

	var path := (
		SAVE_DIR
		+ room_id
		+ ".json"
	)


	if not FileAccess.file_exists(
		path
	):
		return false


	var absolute_path := (
		ProjectSettings.globalize_path(
			path
		)
	)


	var error := (
		DirAccess.remove_absolute(
			absolute_path
		)
	)


	if error != OK:
		return false


	if str(
		current_room.get(
			"room_id",
			""
		)
	) == room_id:

		current_room = {}


	return true


# =========================================================
# 기본 방 정보
# =========================================================

func clear_current_room() -> void:

	current_room = {}


func has_room() -> bool:

	return not current_room.is_empty()


func get_current_room_id() -> String:

	return str(
		current_room.get(
			"room_id",
			""
		)
	)


func get_game_state() -> Dictionary:

	if current_room.is_empty():
		return {}


	return current_room.get(
		"game_state",
		{}
	)


# =========================================================
# 장면
# =========================================================

func set_scene(
	scene_id: String,
	scene_title: String,
	scene_file: String = ""
) -> void:

	if current_room.is_empty():
		return


	var state: Dictionary = (
		current_room["game_state"]
	)


	state["scene_id"] = scene_id
	state["scene_title"] = scene_title


	if not scene_file.is_empty():

		state["scene_file"] = (
			scene_file
		)


	current_room["game_state"] = state


	save_current_room()


# =========================================================
# 새 에피소드 시작
#
# 캐릭터/특성/토론 댓글은 유지한다.
# 기존 에피소드의 스토리 진행 기록만 초기화한다.
# =========================================================

func start_new_episode(
	scene_id: String,
	scene_title: String,
	scene_file: String,
	start_id: String,
	dialogue_file: String = ""
) -> void:

	if current_room.is_empty():
		return


	if start_id.strip_edges().is_empty():

		start_id = "START1"


	var state: Dictionary = (
		current_room.get(
			"game_state",
			{}
		)
	)


	state["scene_id"] = scene_id
	state["scene_title"] = scene_title
	state["scene_file"] = scene_file

	state["checkpoint"] = start_id
	state["dialogue_start_id"] = start_id
	state["dialogue_file"] = dialogue_file.strip_edges()

	state["dialogue_history"] = []
	state["story_flags"] = {}
	state["inventory"] = []


	current_room["game_state"] = state


	# =====================================================
	# transcript에서는 기존 스토리만 제거
	#
	# 토론 댓글(comment)은 방의 기록이므로 유지한다.
	# =====================================================

	var old_transcript: Array = (
		current_room.get(
			"transcript",
			[]
		)
	)


	var comments_only: Array = []


	for entry in old_transcript:

		if not entry is Dictionary:
			continue


		if str(
			entry.get(
				"type",
				""
			)
		) != "comment":

			continue


		comments_only.append(
			entry
		)


	current_room["transcript"] = (
		comments_only
	)


	save_current_room()


# =========================================================
# 체크포인트
# =========================================================

func set_checkpoint(
	checkpoint: String
) -> void:

	if current_room.is_empty():
		return


	var state: Dictionary = (
		current_room["game_state"]
	)


	state["checkpoint"] = checkpoint


	current_room["game_state"] = state


	save_current_room()


func get_checkpoint() -> String:

	if current_room.is_empty():
		return "START1"


	var state: Dictionary = (
		current_room.get(
			"game_state",
			{}
		)
	)


	return str(
		state.get(
			"checkpoint",
			"START1"
		)
	)


# =========================================================
# 캐릭터
# =========================================================

func set_selected_character(
	character_id: int,
	character_name: String,
	portrait_path: String,
	personality: String
) -> void:

	if current_room.is_empty():
		return


	var state: Dictionary = (
		current_room["game_state"]
	)


	state["selected_character_id"] = (
		character_id
	)


	current_room["game_state"] = state


	var members: Array = (
		current_room.get(
			"members",
			[]
		)
	)


	for idx in range(
		members.size()
	):

		var member: Dictionary = (
			members[idx]
		)


		if str(
			member.get(
				"member_id",
				""
			)
		) != LOCAL_MEMBER_ID:

			continue


		member["character_id"] = character_id

		member["character_name"] = (
			character_name
		)

		member["portrait_path"] = (
			portrait_path
		)

		member["personality"] = (
			personality
		)


		members[idx] = member


		break


	current_room["members"] = members


	save_current_room()


func get_local_member() -> Dictionary:

	if current_room.is_empty():
		return {}


	var members: Array = (
		current_room.get(
			"members",
			[]
		)
	)


	for member in members:

		if str(
			member.get(
				"member_id",
				""
			)
		) == LOCAL_MEMBER_ID:

			return member


	return {}


func get_local_member_id() -> String:

	return LOCAL_MEMBER_ID


# =========================================================
# 스토리 플래그
# =========================================================

func set_story_flag(
	flag_name: String,
	value
) -> void:

	if current_room.is_empty():
		return


	var state: Dictionary = (
		current_room["game_state"]
	)


	var flags: Dictionary = (
		state.get(
			"story_flags",
			{}
		)
	)


	flags[flag_name] = value

	state["story_flags"] = flags

	current_room["game_state"] = state


	save_current_room()


func get_story_flag(
	flag_name: String,
	default_value = false
):

	if current_room.is_empty():
		return default_value


	var state: Dictionary = (
		current_room.get(
			"game_state",
			{}
		)
	)


	var flags: Dictionary = (
		state.get(
			"story_flags",
			{}
		)
	)


	return flags.get(
		flag_name,
		default_value
	)


# =========================================================
# 인벤토리
# =========================================================

func add_item(
	item_id: String
) -> void:

	if current_room.is_empty():
		return


	var state: Dictionary = (
		current_room["game_state"]
	)


	var inventory: Array = (
		state.get(
			"inventory",
			[]
		)
	)


	if inventory.has(
		item_id
	):
		return


	inventory.append(
		item_id
	)


	state["inventory"] = inventory

	current_room["game_state"] = state


	save_current_room()


func remove_item(
	item_id: String
) -> void:

	if current_room.is_empty():
		return


	var state: Dictionary = (
		current_room["game_state"]
	)


	var inventory: Array = (
		state.get(
			"inventory",
			[]
		)
	)


	inventory.erase(
		item_id
	)


	state["inventory"] = inventory

	current_room["game_state"] = state


	save_current_room()


func has_item(
	item_id: String
) -> bool:

	if current_room.is_empty():
		return false


	var state: Dictionary = (
		current_room.get(
			"game_state",
			{}
		)
	)


	var inventory: Array = (
		state.get(
			"inventory",
			[]
		)
	)


	return inventory.has(
		item_id
	)


# =========================================================
# 장면 정보
# =========================================================

func _get_current_scene_id() -> String:

	var state: Dictionary = (
		get_game_state()
	)


	return str(
		state.get(
			"scene_id",
			""
		)
	)


func _get_current_scene_title() -> String:

	var state: Dictionary = (
		get_game_state()
	)


	return str(
		state.get(
			"scene_title",
			""
		)
	)


# =========================================================
# 댓글 추가
# =========================================================

func add_comment(
	character_name: String,
	message: String
) -> void:

	if current_room.is_empty():
		return


	message = message.strip_edges()


	if message.is_empty():
		return


	var now: String = (
		_get_current_time()
	)


	var comment_id: String = (
		_generate_comment_id()
	)


	var entry := {

		"type": "comment",

		"comment_id": comment_id,

		"author_id": LOCAL_MEMBER_ID,

		"scene_id": (
			_get_current_scene_id()
		),

		"scene_title": (
			_get_current_scene_title()
		),

		"speaker": character_name,

		"text": message,

		"created_at": now,

		"updated_at": now
	}


	var feed: Array = (
		current_room.get(
			"feed",
			[]
		)
	)


	feed.append(
		entry.duplicate(true)
	)


	current_room["feed"] = feed


	_append_transcript_entry(
		entry.duplicate(true),
		false
	)


	save_current_room()


	comment_added.emit(
		comment_id
	)


	feed_changed.emit()


# =========================================================
# 댓글 수정
# =========================================================

func edit_comment(
	comment_id: String,
	new_message: String,
	requester_member_id: String = LOCAL_MEMBER_ID
) -> bool:

	if current_room.is_empty():
		return false


	comment_id = (
		comment_id.strip_edges()
	)


	new_message = (
		new_message.strip_edges()
	)


	if (
		comment_id.is_empty()
		or new_message.is_empty()
	):

		return false


	var feed: Array = (
		current_room.get(
			"feed",
			[]
		)
	)


	var found := false

	var now: String = (
		_get_current_time()
	)


	# =====================================================
	# feed 수정
	# =====================================================

	for index in range(
		feed.size()
	):

		var entry: Dictionary = (
			feed[index]
		)


		if str(
			entry.get(
				"comment_id",
				""
			)
		) != comment_id:

			continue


		var author_id: String = str(
			entry.get(
				"author_id",
				""
			)
		)


		if author_id != requester_member_id:

			return false


		entry["text"] = new_message

		entry["updated_at"] = now


		feed[index] = entry


		found = true


		break


	if not found:
		return false


	current_room["feed"] = feed


	# =====================================================
	# transcript 수정
	# =====================================================

	var transcript: Array = (
		current_room.get(
			"transcript",
			[]
		)
	)


	for index in range(
		transcript.size()
	):

		var entry: Dictionary = (
			transcript[index]
		)


		if str(
			entry.get(
				"type",
				""
			)
		) != "comment":

			continue


		if str(
			entry.get(
				"comment_id",
				""
			)
		) != comment_id:

			continue


		entry["text"] = new_message

		entry["updated_at"] = now


		transcript[index] = entry


		break


	current_room["transcript"] = (
		transcript
	)


	save_current_room()


	comment_edited.emit(
		comment_id
	)


	feed_changed.emit()


	return true


# =========================================================
# 자기 댓글인지
# =========================================================

func can_edit_comment(
	entry: Dictionary
) -> bool:

	if entry.is_empty():
		return false


	return str(
		entry.get(
			"author_id",
			""
		)
	) == LOCAL_MEMBER_ID


# =========================================================
# 댓글 가져오기
# =========================================================

func get_feed() -> Array:

	if current_room.is_empty():
		return []


	return current_room.get(
		"feed",
		[]
	)


func get_current_scene_feed() -> Array:

	var result: Array = []


	if current_room.is_empty():
		return result


	var scene_id: String = (
		_get_current_scene_id()
	)


	for entry in get_feed():

		if str(
			entry.get(
				"scene_id",
				""
			)
		) == scene_id:

			result.append(
				entry
			)


	return result


# =========================================================
# Transcript
# =========================================================

func _append_transcript_entry(
	entry: Dictionary,
	save_after: bool = true
) -> void:

	if current_room.is_empty():
		return


	var transcript: Array = (
		current_room.get(
			"transcript",
			[]
		)
	)


	transcript.append(
		entry
	)


	current_room["transcript"] = (
		transcript
	)


	if save_after:

		save_current_room()


func record_chapter(
	title: String
) -> void:

	_append_transcript_entry({

		"type": "chapter",

		"scene_id": (
			_get_current_scene_id()
		),

		"scene_title": title,

		"speaker": "",

		"text": title,

		"created_at": (
			_get_current_time()
		)
	})


func record_situation(
	text: String
) -> void:

	_append_transcript_entry({

		"type": "situation",

		"scene_id": (
			_get_current_scene_id()
		),

		"scene_title": (
			_get_current_scene_title()
		),

		"speaker": "",

		"text": text,

		"created_at": (
			_get_current_time()
		)
	})


func record_dialogue(
	speaker: String,
	text: String
) -> void:

	_append_transcript_entry({

		"type": "dialogue",

		"scene_id": (
			_get_current_scene_id()
		),

		"scene_title": (
			_get_current_scene_title()
		),

		"speaker": speaker,

		"text": text,

		"created_at": (
			_get_current_time()
		)
	})


func record_insight(
	speaker: String,
	category: String,
	text: String
) -> void:

	_append_transcript_entry({

		"type": "insight",

		"scene_id": (
			_get_current_scene_id()
		),

		"scene_title": (
			_get_current_scene_title()
		),

		"speaker": speaker,

		"category": category,

		"text": text,

		"created_at": (
			_get_current_time()
		)
	})


func record_choice(
	speaker: String,
	text: String
) -> void:

	_append_transcript_entry({

		"type": "choice",

		"scene_id": (
			_get_current_scene_id()
		),

		"scene_title": (
			_get_current_scene_title()
		),

		"speaker": speaker,

		"text": text,

		"created_at": (
			_get_current_time()
		)
	})


func record_system(
	text: String
) -> void:

	_append_transcript_entry({

		"type": "system",

		"scene_id": (
			_get_current_scene_id()
		),

		"scene_title": (
			_get_current_scene_title()
		),

		"speaker": "",

		"text": text,

		"created_at": (
			_get_current_time()
		)
	})


func get_transcript() -> Array:

	if current_room.is_empty():
		return []


	return current_room.get(
		"transcript",
		[]
	)


# =========================================================
# TXT
# =========================================================

func build_transcript_text() -> String:

	if current_room.is_empty():
		return ""


	var result := ""


	result += (
		"========================================\n"
	)

	result += (
		"플레이 기록\n"
	)

	result += (
		"방 이름 : "
		+ str(
			current_room.get(
				"room_name",
				""
			)
		)
		+ "\n"
	)

	result += (
		"최대 인원 : "
		+ str(
			current_room.get(
				"max_players",
				1
			)
		)
		+ "명\n"
	)


	var participant_text := ""

	var members: Array = (
		current_room.get(
			"members",
			[]
		)
	)


	for member in members:

		var name: String = str(
			member.get(
				"character_name",
				""
			)
		)


		if name.is_empty():

			name = str(
				member.get(
					"display_name",
					"Player"
				)
			)


		if not participant_text.is_empty():

			participant_text += " / "


		participant_text += name


	result += (
		"참가자 : "
		+ participant_text
		+ "\n"
	)

	result += (
		"========================================\n\n"
	)


	for entry in get_transcript():

		var type: String = str(
			entry.get(
				"type",
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


		match type:

			"chapter":

				result += (
					"\n========================================\n"
				)

				result += (
					"["
					+ text
					+ "]\n"
				)

				result += (
					"========================================\n\n"
				)


			"situation":

				result += (
					text
					+ "\n\n"
				)


			"dialogue":

				if not speaker.is_empty():

					result += (
						speaker
						+ "\n"
					)


				result += (
					"\""
					+ text
					+ "\"\n\n"
				)


			"insight":

				var category: String = str(
					entry.get(
						"category",
						"정보"
					)
				)


				result += (
					"["
					+ speaker
					+ " - "
					+ category
					+ "]\n"
				)


				result += (
					text
					+ "\n\n"
				)


			"choice":

				result += (
					speaker
					+ " > "
					+ text
					+ "\n\n"
				)

			"comment":

				result += (
					"["
					+ speaker
					+ "]\n"
				)

				result += (
					"\""
					+ text
					+ "\"\n\n"
				)


			"system":

				result += (
					"[시스템]\n"
				)

				result += (
					text
					+ "\n\n"
				)


	return result


func export_transcript_txt() -> String:

	if current_room.is_empty():
		return ""


	_ensure_directory(
		EXPORT_DIR
	)


	var room_name: String = str(
		current_room.get(
			"room_name",
			"play"
		)
	)


	room_name = (
		_sanitize_file_name(
			room_name
		)
	)


	var room_id: String = str(
		current_room.get(
			"room_id",
			"ROOM"
		)
	)


	var file_name := (
		room_name
		+ "_"
		+ room_id
		+ ".txt"
	)


	var path := (
		EXPORT_DIR
		+ file_name
	)


	var file := FileAccess.open(
		path,
		FileAccess.WRITE
	)


	if file == null:

		push_error(
			"TXT 저장 실패: "
			+ path
		)

		return ""


	file.store_string(
		build_transcript_text()
	)


	file.close()


	return path


func _sanitize_file_name(
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


	return result.strip_edges()


# =========================================================
# Dialogue 선택 / 이전 기록
# =========================================================

# 현재 transcript에서 "스토리 기록"만 몇 개인지 센다.
# 토론 댓글(comment)은 이전 버튼으로 삭제하지 않는다.
func _count_story_transcript_entries(
	transcript: Array
) -> int:

	var count: int = 0


	for entry in transcript:

		if not entry is Dictionary:
			continue


		if str(
			entry.get(
				"type",
				""
			)
		) == "comment":

			continue


		count += 1


	return count


# =========================================================
# 선택 직전 상태 스냅샷
#
# main.gd에서 실제 선택지를 누르기 직전에 호출한다.
# =========================================================

func create_dialogue_undo_snapshot() -> Dictionary:

	if current_room.is_empty():
		return {}


	var state: Dictionary = (
		current_room.get(
			"game_state",
			{}
		)
	)


	var transcript: Array = (
		current_room.get(
			"transcript",
			[]
		)
	)


	var story_flags: Dictionary = (
		state.get(
			"story_flags",
			{}
		)
	)


	var inventory: Array = (
		state.get(
			"inventory",
			[]
		)
	)


	return {

		"story_entry_count_before": (
			_count_story_transcript_entries(
				transcript
			)
		),

		"story_flags_before": (
			story_flags.duplicate(true)
		),

		"inventory_before": (
			inventory.duplicate(true)
		),

		"checkpoint_before": str(
			state.get(
				"checkpoint",
				"START1"
			)
		)
	}


# =========================================================
# 선택 기록
# =========================================================

func record_dialogue_selection(
	option_index: int,
	option_text: String,
	speaker: String,
	undo_snapshot: Dictionary = {}
) -> void:

	if current_room.is_empty():
		return


	var state: Dictionary = (
		current_room.get(
			"game_state",
			{}
		)
	)


	var history: Array = (
		state.get(
			"dialogue_history",
			[]
		)
	)


	# 선택 직전 스냅샷이 전달되지 않은 경우를 위한 안전장치
	var snapshot: Dictionary = (
		undo_snapshot.duplicate(true)
	)


	if snapshot.is_empty():

		snapshot = (
			create_dialogue_undo_snapshot()
		)


	var snapshot_story_flags: Dictionary = (
		snapshot.get(
			"story_flags_before",
			{}
		)
	)


	var snapshot_inventory: Array = (
		snapshot.get(
			"inventory_before",
			[]
		)
	)


	history.append({

		"option_index": option_index,

		"option_text": option_text,

		"story_entry_count_before": int(
			snapshot.get(
				"story_entry_count_before",
				0
			)
		),

		"story_flags_before": (
			snapshot_story_flags.duplicate(true)
		),

		"inventory_before": (
			snapshot_inventory.duplicate(true)
		),

		"checkpoint_before": str(
			snapshot.get(
				"checkpoint_before",
				"START1"
			)
		),

		"created_at": (
			_get_current_time()
		)
	})


	state["dialogue_history"] = history

	current_room["game_state"] = state


	var clean_text: String = (
		option_text.strip_edges()
	)


	# 빈 선택지는 "계속" 진행용이므로
	# 복원 history에는 남기되 TXT에는 선택 문장으로 기록하지 않는다.
	if not clean_text.is_empty():

		var transcript: Array = (
			current_room.get(
				"transcript",
				[]
			)
		)


		transcript.append({

			"type": "choice",

			"scene_id": (
				_get_current_scene_id()
			),

			"scene_title": (
				_get_current_scene_title()
			),

			"speaker": speaker,

			"text": clean_text,

			"created_at": (
				_get_current_time()
			)
		})


		current_room["transcript"] = (
			transcript
		)


	save_current_room()


# =========================================================
# 예전 저장 데이터용
#
# story_entry_count_before가 없는 과거 history라면
# transcript에서 마지막 실제 choice 위치를 찾아 추정한다.
# =========================================================

func _infer_story_count_before_choice(
	option_text: String
) -> int:

	var transcript: Array = (
		current_room.get(
			"transcript",
			[]
		)
	)


	var story_count: int = 0
	var last_choice_story_count: int = -1

	var clean_option_text: String = (
		option_text.strip_edges()
	)


	for entry in transcript:

		if not entry is Dictionary:
			continue


		var entry_type: String = str(
			entry.get(
				"type",
				""
			)
		)


		if entry_type == "comment":
			continue


		if entry_type == "choice":

			var entry_text: String = str(
				entry.get(
					"text",
					""
				)
			).strip_edges()


			if (
				clean_option_text.is_empty()
				or entry_text == clean_option_text
			):

				last_choice_story_count = (
					story_count
				)


		story_count += 1


	if last_choice_story_count >= 0:

		return last_choice_story_count


	# 정확한 선택 문장을 못 찾았을 경우
	# 가장 마지막 choice 직전 위치를 다시 찾는다.
	story_count = 0
	last_choice_story_count = -1


	for entry in transcript:

		if not entry is Dictionary:
			continue


		var entry_type: String = str(
			entry.get(
				"type",
				""
			)
		)


		if entry_type == "comment":
			continue


		if entry_type == "choice":

			last_choice_story_count = (
				story_count
			)


		story_count += 1


	if last_choice_story_count >= 0:

		return last_choice_story_count


	return 0


# =========================================================
# 이전 가능한 실제 선택지가 있는지
#
# 빈 option_text는 "계속" 버튼이므로 제외한다.
# =========================================================

func can_undo_dialogue_selection() -> bool:

	if current_room.is_empty():
		return false


	var history: Array = (
		get_dialogue_history()
	)


	for index in range(
		history.size() - 1,
		-1,
		-1
	):

		var entry = history[index]


		if not entry is Dictionary:
			continue


		if not str(
			entry.get(
				"option_text",
				""
			)
		).strip_edges().is_empty():

			return true


	return false


# =========================================================
# 마지막 "실제 선택지"로 돌아가기
#
# - 마지막 실제 선택과 그 이후의 계속 진행 history 제거
# - 잘못 들어간 분기의 스토리 transcript 제거
# - comment는 그대로 보존
# - 당시 flags / inventory / checkpoint 복원
# =========================================================

func undo_last_dialogue_selection() -> bool:

	if current_room.is_empty():
		return false


	var state: Dictionary = (
		current_room.get(
			"game_state",
			{}
		)
	)


	var history: Array = (
		state.get(
			"dialogue_history",
			[]
		)
	)


	if history.is_empty():
		return false


	var target_index: int = -1


	# 마지막 "실제 선택지" 찾기
	for index in range(
		history.size() - 1,
		-1,
		-1
	):

		var candidate = history[index]


		if not candidate is Dictionary:
			continue


		var option_text: String = str(
			candidate.get(
				"option_text",
				""
			)
		).strip_edges()


		if not option_text.is_empty():

			target_index = index
			break


	if target_index < 0:
		return false


	var target_entry: Dictionary = (
		history[target_index]
	)


	# =====================================================
	# 선택 직전의 스토리 transcript 개수
	# =====================================================

	var story_entry_count_before: int = -1


	if target_entry.has(
		"story_entry_count_before"
	):

		story_entry_count_before = int(
			target_entry.get(
				"story_entry_count_before",
				0
			)
		)


	else:

		story_entry_count_before = (
			_infer_story_count_before_choice(
				str(
					target_entry.get(
						"option_text",
						""
					)
				)
			)
		)


	if story_entry_count_before < 0:

		story_entry_count_before = 0


	# =====================================================
	# target 선택부터 이후 history 전부 제거
	#
	# 잘못 선택한 뒤 "계속"을 여러 번 눌렀더라도
	# 한 번의 이전으로 실제 선택 화면까지 돌아간다.
	# =====================================================

	history.resize(
		target_index
	)


	state["dialogue_history"] = (
		history
	)


	# =====================================================
	# 선택 당시 게임 상태 복원
	# =====================================================

	if target_entry.has(
		"story_flags_before"
	):

		var restored_flags: Dictionary = (
			target_entry.get(
				"story_flags_before",
				{}
			)
		)


		state["story_flags"] = (
			restored_flags.duplicate(true)
		)


	if target_entry.has(
		"inventory_before"
	):

		var restored_inventory: Array = (
			target_entry.get(
				"inventory_before",
				[]
			)
		)


		state["inventory"] = (
			restored_inventory.duplicate(true)
		)


	if target_entry.has(
		"checkpoint_before"
	):

		state["checkpoint"] = str(
			target_entry.get(
				"checkpoint_before",
				"START1"
			)
		)


	current_room["game_state"] = state


	# =====================================================
	# transcript 롤백
	#
	# comment는 언제 작성했든 삭제하지 않는다.
	# 스토리 기록만 선택 직전 개수까지 남긴다.
	# =====================================================

	var transcript: Array = (
		current_room.get(
			"transcript",
			[]
		)
	)


	var rolled_back_transcript: Array = []

	var kept_story_entries: int = 0


	for entry in transcript:

		if not entry is Dictionary:
			continue


		var entry_type: String = str(
			entry.get(
				"type",
				""
			)
		)


		# 토론 댓글은 롤백 대상이 아님
		if entry_type == "comment":

			rolled_back_transcript.append(
				entry
			)

			continue


		# 선택 직전까지의 스토리만 유지
		if kept_story_entries < story_entry_count_before:

			rolled_back_transcript.append(
				entry
			)

			kept_story_entries += 1


	current_room["transcript"] = (
		rolled_back_transcript
	)


	save_current_room()


	return true


func get_dialogue_history() -> Array:

	if current_room.is_empty():
		return []


	var state: Dictionary = (
		current_room.get(
			"game_state",
			{}
		)
	)


	return state.get(
		"dialogue_history",
		[]
	)


# =========================================================
# Dialogue 파일
# =========================================================

func set_dialogue_file(
	dialogue_file: String
) -> void:

	if current_room.is_empty():
		return


	var state: Dictionary = (
		current_room.get(
			"game_state",
			{}
		)
	)


	state["dialogue_file"] = (
		dialogue_file.strip_edges()
	)


	current_room["game_state"] = state


	save_current_room()


func get_dialogue_file() -> String:

	if current_room.is_empty():
		return ""


	var state: Dictionary = (
		current_room.get(
			"game_state",
			{}
		)
	)


	return str(
		state.get(
			"dialogue_file",
			""
		)
	)


func set_dialogue_start_id(
	start_id: String
) -> void:

	if current_room.is_empty():
		return


	var state: Dictionary = (
		current_room.get(
			"game_state",
			{}
		)
	)


	state["dialogue_start_id"] = (
		start_id
	)


	current_room["game_state"] = state


	save_current_room()


func get_dialogue_start_id() -> String:

	if current_room.is_empty():
		return "START1"


	var state: Dictionary = (
		current_room.get(
			"game_state",
			{}
		)
	)


	return str(
		state.get(
			"dialogue_start_id",
			"START1"
		)
	)

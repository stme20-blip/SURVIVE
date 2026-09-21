extends Node

var _service: Node
var _write_service: Node
var _timer := 0.0
var _busy := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_service = preload("res://RoomService.gd").new()
	add_child(_service)
	_write_service = preload("res://RoomService.gd").new()
	add_child(_write_service)

func _process(delta: float) -> void:
	if not RoomManager.has_active_online_room(): return
	_timer += delta
	if _timer >= 2.0:
		_timer = 0.0
		refresh()

func refresh() -> void:
	if _busy or not RoomManager.has_active_online_room(): return
	_busy = true
	var online: Dictionary = RoomManager.current_room.get("online_room", {})
	var result: Dictionary = await _service.room_comments({"action":"list","room_id":str(online.get("room_id", ""))})
	_busy = false
	if result.has("error"):
		print("[comments] list failed: ", result.get("error", "unknown"))
		return
	if not result.data is Dictionary: return
	RoomManager.merge_online_comments(result.data.get("comments", []), AuthManager.user_id)

func submit(author: String, body: String) -> void:
	if not RoomManager.has_active_online_room():
		RoomManager.add_comment(author, body); return
	var state := RoomManager.get_game_state()
	var online: Dictionary = RoomManager.current_room.get("online_room", {})
	var result: Dictionary = await _write_service.room_comments({"action":"create","room_id":str(online.get("room_id", "")),"author_name":author,"body":body,"scene_id":str(state.get("scene_id", "")),"scene_title":str(state.get("scene_title", ""))})
	if result.has("error"):
		print("[comments] create failed: ", result.get("error", "unknown"))
		return
	refresh()

func edit(comment_id: String, body: String) -> void:
	if not RoomManager.has_active_online_room():
		RoomManager.edit_comment(comment_id, body); return
	var online: Dictionary = RoomManager.current_room.get("online_room", {})
	var result: Dictionary = await _write_service.room_comments({"action":"update","room_id":str(online.get("room_id", "")),"comment_id":comment_id,"body":body})
	if result.has("error"):
		print("[comments] update failed: ", result.get("error", "unknown"))
		return
	refresh()

func delete_comment(comment_id: String) -> void:
	if not RoomManager.has_active_online_room(): return
	var online: Dictionary = RoomManager.current_room.get("online_room", {})
	var result: Dictionary = await _write_service.room_comments({"action":"delete","room_id":str(online.get("room_id", "")),"comment_id":comment_id})
	if result.has("error"):
		print("[comments] delete failed: ", result.get("error", "unknown"))
		return
	refresh()

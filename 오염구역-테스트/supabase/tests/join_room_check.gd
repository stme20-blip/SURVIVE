extends SceneTree

const HOST := "11111111-1111-4111-8111-111111111111"
const USER := "22222222-2222-4222-8222-222222222222"
const ROOM := "33333333-3333-4333-8333-333333333333"

class MockService extends Node:
	var calls := 0
	var result: Dictionary
	var rows: Array
	func join_room(_code: String) -> Dictionary:
		calls += 1
		await get_tree().process_frame
		return result
	func get_members(_id: String) -> Dictionary:
		await get_tree().process_frame
		return {"data": rows}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(ProjectSettings.get_setting("application/config/custom_user_dir", "") == "CodexJoinRoomValidation")
	var auth = root.get_node("AuthManager")
	auth.user_id = USER
	var manager = root.get_node("RoomManager")
	var service = load("res://RoomService.gd").new()
	root.add_child(service)
	var data := {"room_id": ROOM, "invite_code": "K7M4XP", "host_user_id": HOST, "is_host": false, "max_players": 4, "status": "playing", "member_count": 2}
	assert(service._validate_join(data, "K7M4XP").has("data"))
	assert(service._validate_join({}, "K7M4XP").has("error"))
	var rows := [{"user_id": HOST, "role": "host", "display_name": null}, {"user_id": USER, "role": "member", "display_name": null}]
	assert(service._validate_members(rows).has("data"))
	assert(service._validate_members([rows[0]]).has("error"))
	assert(service._validate_members([rows[1], rows[1]]).has("error"))
	var invalid: Dictionary = await service.join_room("I7M4XP")
	assert(invalid.error == "INVALID_INVITE_CODE")
	var unauthorized: Dictionary = await service.join_room(" k7m4xp ")
	assert(unauthorized.error == "UNAUTHORIZED")
	manager.create_room("legacy", 4)
	var legacy: String = manager.current_room.room_id
	assert(manager.accept_joined_room(data, USER))
	var local_id: String = manager.current_room.room_id
	assert(not manager.get_local_member().is_host)
	manager.current_room.game_state["checkpoint"] = "KEEP_PROGRESS"
	manager.current_room.members[0]["personality_changes_used"] = 2
	assert(manager.save_current_room())
	assert(manager.accept_joined_room(data, USER))
	assert(manager.current_room.room_id == local_id)
	assert(manager.current_room.game_state.checkpoint == "KEEP_PROGRESS")
	assert(manager.get_local_member().personality_changes_used == 2)
	assert(manager.load_room(local_id))
	assert(manager.current_room.online_room.local_user_id == USER)
	assert(manager.load_room(legacy))
	assert(not manager.current_room.has("online_room"))
	# Host reentry reuses older create-room saves without local_user_id.
	var host_data := data.duplicate(true)
	host_data.is_host = true
	manager.create_room("host-original", 4, host_data)
	var host_local_id: String = manager.current_room.room_id
	assert(manager.accept_joined_room(host_data, HOST))
	assert(manager.current_room.room_id == host_local_id and manager.get_local_member().is_host)
	assert(manager.accept_joined_room(data, USER))
	assert(manager.current_room.room_id == local_id)
	set_meta("room_lobby_join", true)
	var lobby = load("res://room_lobby.tscn").instantiate()
	root.add_child(lobby)
	current_scene = lobby
	var mock := MockService.new()
	mock.result = {"error": "ROOM_FULL", "message": "이미 참가 인원이 가득 찬 서버입니다."}
	mock.rows = rows
	lobby.add_child(mock)
	lobby._service = mock
	lobby._code.text = " k7m4xp "
	lobby._normalize_input(lobby._code.text)
	assert(lobby._code.text == "K7M4XP")
	lobby._join_pressed()
	lobby._join_pressed()
	await process_frame
	await process_frame
	assert(mock.calls == 1 and not lobby._busy)
	assert(not lobby._joined and lobby._status.text.contains("가득"))
	assert(manager.current_room.room_id == local_id)
	mock.result = {"data": data}
	lobby._join_pressed()
	for i in range(5):
		await process_frame
	assert(lobby._joined and not lobby._busy)
	assert(lobby._members.get_child_count() == 2)
	assert(lobby._members.get_child(0).text == "방장")
	assert(lobby._members.get_child(1).text == "참가자 2 (나)")
	assert(not lobby._info.text.contains(USER))
	assert(manager.current_room.room_id == local_id)
	lobby._continue_pressed()
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == "res://episode_select.tscn")
	print("JOIN_ROOM_CHECK passed: validation, owner isolation, reentry preserves progress, roles, UI errors/duplicate guard, member labels and continuation")
	quit()

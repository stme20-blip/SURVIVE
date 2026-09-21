extends SceneTree

class MockService extends Node:
	var calls := 0
	func create_room() -> Dictionary:
		calls += 1
		await get_tree().process_frame
		return {"data": {"room_id": "345b7ad5-eb56-44cf-8c36-5573488a378a", "invite_code": "K7M4XP", "max_players": 4, "status": "lobby"}}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# Run only in an isolated project with a dedicated user directory.
	assert(ProjectSettings.get_setting("application/config/custom_user_dir", "") == "CodexCreateRoomValidation")
	var manager = root.get_node("RoomManager")
	var service = load("res://RoomService.gd").new()
	root.add_child(service)
	var no_session: Dictionary = await service.create_room()
	assert(no_session.error == "no_session")
	var data := {"room_id": "345b7ad5-eb56-44cf-8c36-5573488a378a", "invite_code": "K7M4XP", "max_players": 4, "status": "lobby"}
	var success: Dictionary = service._decode_response(0, 201, JSON.stringify(data).to_utf8_buffer())
	assert(success.data == data)
	assert(service._decode_response(0, 401, "{}".to_utf8_buffer()).error == "unauthorized")
	assert(service._decode_response(0, 500, '{"error":"room_creation_failed"}'.to_utf8_buffer()).error == "room_creation_failed")
	assert(service._decode_response(0, 200, '[]'.to_utf8_buffer()).error == "unexpected_response")
	assert(service._decode_response(0, 200, '{"room_id":"bad"}'.to_utf8_buffer()).error == "unexpected_response")
	assert(service._decode_response(HTTPRequest.RESULT_TIMEOUT, 0, PackedByteArray()).error == "network_failure")
	manager.create_room("legacy", 4)
	var old_id: String = manager.current_room.room_id
	assert(not manager.current_room.has("online_room"))
	data["is_host"] = true
	data["host_user_id"] = "test-host"
	manager.create_room("online", 4, data)
	var local_id: String = manager.current_room.room_id
	assert(local_id != data.room_id)
	assert(manager.load_room(local_id))
	for key in data:
		assert(manager.current_room.online_room[key] == data[key])
	assert(manager.current_room.members[0].member_id == "LOCAL_1")
	assert(manager.load_room(old_id))
	assert(not manager.current_room.has("online_room"))
	var menu = load("res://room_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await menu._on_create_room_pressed()
	assert(not menu._creating and not menu._created)
	assert(not menu._create_button.disabled and not menu._back_button.disabled)
	assert(manager.current_room.room_id == old_id)
	assert(menu.status_label.text.contains("인증 세션"))
	var mock := MockService.new()
	menu.add_child(mock)
	menu._room_service = mock
	menu._on_create_room_pressed()
	assert(menu._create_button.disabled and menu._back_button.disabled)
	menu._on_create_room_pressed()
	await process_frame
	await process_frame
	assert(mock.calls == 1 and menu._created)
	assert(menu.status_label.text.contains("K7M4XP"))
	assert(menu._continue_button.visible)
	assert(manager.current_room.online_room.is_host)
	current_scene = menu
	menu._on_continue_pressed()
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == "res://room_lobby.tscn")
	current_scene._continue_pressed()
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == "res://episode_select.tscn")
	print("CREATE_ROOM_CHECK passed: errors, local compatibility, metadata persistence, UI recovery, duplicate click guard, code display and episode selection transition")
	quit()

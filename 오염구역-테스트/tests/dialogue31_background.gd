extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("RoomManager").current_room = {"game_state": {"dialogue_file": "res://hospital_dialogue.tres"}}
	var controller = load("res://main.gd").new()
	var box = load("res://CoopDialogueBox.gd").new()
	box.data = load("res://hospital_dialogue.tres")
	box.data.nodes[&"1_31"] = {"dialogue": "dialogue 31 test", "speaker": "[접수 데스크]"}
	controller.dialogue_box = box
	controller.school_background = Sprite2D.new()
	controller.mobile_background = TextureRect.new()
	controller._update_hospital_dialogue_background("[접수 데스크]", "dialogue 31 test")
	assert(controller.school_background.texture == controller.HOSPITAL_DIALOGUE_31_BACKGROUND)
	assert(controller.mobile_background.texture == controller.HOSPITAL_DIALOGUE_31_BACKGROUND)
	print("PASS: dialogue 31 uses the new hospital background on desktop and mobile")
	quit()

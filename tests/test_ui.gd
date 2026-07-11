extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_checks")


func expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)


func run_checks() -> void:
	var progress = root.get_node_or_null("Progress")
	var created_progress := progress == null
	if created_progress:
		progress = load("res://src/progress.gd").new()
		progress.name = "Progress"
		root.add_child(progress)
	progress.data = progress.default_data()
	progress.data.coffee = 999999999
	progress.data.highest_zone = 99
	progress.data.upgrades = ["loadout_slot_2", "loadout_slot_3", "loadout_slot_4", "loadout_slot_5", "loadout_slot_6"]
	var app = load("res://src/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.selected_chapter = 9
	app.show_hub()
	await process_frame
	expect(app.screen.find_children("*", "Button", true, false).size() >= 10, "chapter hub must expose ten sectors and navigation")
	expect_controls_inside(app,"chapter hub")
	app.selected_chapter=0;app.change_chapter(1);expect(app.selected_chapter==1,"chapter navigation must advance exactly one chapter");app.change_chapter(-1);expect(app.selected_chapter==0,"chapter navigation must return exactly one chapter")
	capture_viewport("hub")
	app.show_upgrades("weapon", 0)
	await process_frame
	expect(app.screen.find_children("*", "Button", true, false).size() >= 28, "upgrade page must expose category tabs and 24 nodes")
	expect_controls_inside(app,"upgrade page")
	capture_viewport("upgrades")
	app.show_loadout()
	await process_frame
	expect(app.screen.find_children("*", "Button", true, false).size() >= 25, "loadout must expose all 24 weapon families")
	capture_viewport("loadout")
	app.show_facilities()
	await process_frame
	expect(app.screen.find_children("*", "Button", true, false).size() >= 11, "facilities must expose all ten producers")
	capture_viewport("facilities")
	var many_unlocks: Array[String] = []
	for index in range(180): many_unlocks.append("TASK: MISSION %03d (+%d)" % [index + 1, 32 + index * 4])
	app.show_results({"cleared":true,"zone":0,"coffee":594,"mined":129,"kills":51,"damage_taken":5,"elapsed":88.0}, many_unlocks)
	await process_frame
	var result_panel := app.screen.find_child("ResultPanel", true, false) as Control
	var result_scroll := app.screen.find_child("ResultUnlockScroll", true, false) as ScrollContainer
	var primary_action := app.screen.find_child("ResultPrimaryAction", true, false) as Button
	var secondary_action := app.screen.find_child("ResultSecondaryAction", true, false) as Button
	expect(result_panel != null and result_scroll != null, "long result summaries must use a bounded scroll panel")
	expect(primary_action != null and secondary_action != null, "result actions must remain available outside the scrolling content")
	if result_panel != null: expect(Rect2(Vector2.ZERO, Vector2(1280,720)).encloses(result_panel.get_global_rect()), "result panel must remain inside the viewport")
	if primary_action != null: expect(Rect2(Vector2.ZERO, Vector2(1280,720)).encloses(primary_action.get_global_rect()), "primary result action must remain visible")
	if secondary_action != null: expect(Rect2(Vector2.ZERO, Vector2(1280,720)).encloses(secondary_action.get_global_rect()), "secondary result action must remain visible")
	if result_panel != null:
		var original_screen_size: Vector2 = app.screen.size
		app.screen.size = Vector2(960, 540)
		await process_frame
		expect(Rect2(Vector2.ZERO, Vector2(960,540)).encloses(result_panel.get_rect()), "result panel must fit a reduced logical viewport")
		app.screen.size = original_screen_size
		await process_frame
	if result_scroll != null:
		expect(result_scroll.get_v_scroll_bar().max_value > result_scroll.get_v_scroll_bar().page, "long result summaries must have vertical scroll range")
		result_scroll.grab_focus()
		var down_key := InputEventKey.new()
		down_key.keycode = KEY_DOWN
		down_key.pressed = true
		Input.parse_input_event(down_key)
		await process_frame
		expect(result_scroll.scroll_vertical > 0, "result summary must accept keyboard scrolling")
		down_key.pressed = false
		Input.parse_input_event(down_key)
		result_scroll.scroll_vertical = 0
		var dpad_down := InputEventJoypadButton.new()
		dpad_down.button_index = JOY_BUTTON_DPAD_DOWN
		dpad_down.pressed = true
		Input.parse_input_event(dpad_down)
		await process_frame
		expect(result_scroll.scroll_vertical > 0, "result summary must accept gamepad D-pad scrolling")
		dpad_down.pressed = false
		Input.parse_input_event(dpad_down)
		result_scroll.scroll_vertical = int(result_scroll.get_v_scroll_bar().max_value - result_scroll.get_v_scroll_bar().page)
		await process_frame
		dpad_down.pressed = true
		Input.parse_input_event(dpad_down)
		await process_frame
		expect(root.get_viewport().gui_get_focus_owner() == primary_action, "D-pad down at the end of the result list must focus the primary action")
		dpad_down.pressed = false
		Input.parse_input_event(dpad_down)
	capture_viewport("results")
	var resize_connections_before_clear: int = app.screen.resized.get_connections().size()
	app.show_hub()
	await process_frame
	await process_frame
	expect(resize_connections_before_clear > 0 and app.screen.resized.get_connections().is_empty(), "closed responsive panels must disconnect their resize callback")
	progress.data.settings.locale = "en"
	TranslationServer.set_locale("en")
	app.show_hub()
	await process_frame
	expect(not app.is_ja() and app.tx("日本語", "English") == "English", "switching to English must refresh localized UI copy")
	app._start_zone(99)
	for frame in range(20): await process_frame
	expect(app.active_session != null and app.active_session.loadout.size() >= 1, "final-sector sortie must start with a valid weapon deck")
	expect(not app.hud_labels.is_empty(), "sortie HUD must be constructed")
	for index in range(10):app.active_session.spawn_enemy()
	for index in range(520):app.active_session.spawn_player_bullet(Vector2.from_angle(index*0.17),ContentCatalog.WEAPONS[index%24]);app.active_session.spawn_enemy_bullet(Vector2(640,390),index*0.23,180.0,Color.WHITE)
	app.active_session.shield=999999;app.active_session.invulnerable=999.0
	app.active_session.set_process(false)
	var frame_times:Array[int]=[]
	for frame in range(120):
		var frame_start:=Time.get_ticks_usec();app.active_session._process(0.016);RenderingServer.force_draw();frame_times.append(int(Time.get_ticks_usec()-frame_start))
	frame_times.sort();var p95_usec:int=frame_times[int(frame_times.size()*0.95)]
	var frame_budget_usec:=100000 if DisplayServer.get_name()=="headless" else 16667
	expect(p95_usec<=frame_budget_usec,"maximum-density p95 frame processing exceeded %dus budget: %dus"%[frame_budget_usec,p95_usec])
	app.active_session.paused = true
	await process_frame
	capture_viewport("combat")
	await create_timer(0.35).timeout
	app.music_player.stop();app.music_player.stream=null
	app.active_session.sfx_player.stop();app.active_session.sfx_player.stream=null;app.active_session.sfx_streams.clear()
	for audio_node in app.find_children("*", "AudioStreamPlayer", true, false):
		var audio := audio_node as AudioStreamPlayer
		if audio != null:
			audio.stop()
			audio.stream = null
	app.queue_free()
	await process_frame
	await process_frame
	await process_frame
	await create_timer(0.1).timeout
	if created_progress: progress.free()
	if failures.is_empty():
		print("PASS: UI navigation and sortie smoke checks")
		quit(0)
	else:
		for failure in failures: push_error("FAIL: " + failure)
		quit(1)


func capture_viewport(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	var texture := root.get_viewport().get_texture()
	if texture == null: return
	var image := texture.get_image()
	if image != null and not image.is_empty(): image.save_png("res://.local-agents/qa-%s.png" % name)


func expect_controls_inside(app:Control,screen_name:String)->void:
	var viewport_rect:=Rect2(Vector2.ZERO,Vector2(1280,720))
	for node in app.screen.find_children("*","Control",true,false):
		var control:=node as Control
		if control.visible and control.size.x>0 and control.size.y>0:
			var rect:=control.get_global_rect()
			expect(viewport_rect.encloses(rect),"%s control must remain inside 1280x720: %s %s"%[screen_name,control.name,rect])

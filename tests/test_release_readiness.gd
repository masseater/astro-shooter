extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	test_identity()
	test_input_actions()
	test_export_presets()
	test_required_notices()
	if failures.is_empty():
		print("PASS: release readiness checks")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	expect(file != null, "required file must be readable: " + path)
	return "" if file == null else file.get_as_text()


func test_identity() -> void:
	expect(ProjectSettings.get_setting("application/config/name") == "Riftweld: Signalbreak", "release title must use the original identity")
	var public_copy := read_text("res://README.md") + read_text("res://docs/business-requirements.md") + read_text("res://src/content_catalog.gd") + read_text("res://src/main.gd")
	for forbidden in ["AstroCoffee", "Cofferoid", "SpaceCorp", "ASTRO PROSPECTOR", "Web Rebellion"]:
		expect(forbidden not in public_copy, "release-facing copy must not contain legacy identity: " + forbidden)


func test_input_actions() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "boost", "pause", "retreat"]:
		expect(InputMap.has_action(action), "required input action must exist: " + action)
		var has_controller := false
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				has_controller = true
		expect(has_controller, "every gameplay action must support a controller: " + action)
	var main_script := read_text("res://src/main.gd")
	expect("gui_get_focus_owner" in main_script and "grab_focus" in main_script, "menu UI must establish controller focus")


func test_export_presets() -> void:
	var presets := read_text("res://export_presets.cfg")
	for preset in ["name=\"Web\"", "name=\"Windows Desktop\"", "name=\"Linux\"", "name=\"macOS\""]:
		expect(preset in presets, "required export preset is missing: " + preset)
	var preset_blocks: Array[String] = []
	for block in presets.split("[preset."):
		var header := block.get_slice("\n", 0)
		if ".options]" not in header and "name=\"" in block:
			preset_blocks.append(block)
	expect(preset_blocks.size() == 4, "all four export preset blocks must be readable")
	for block in preset_blocks:
		expect("assets/backgrounds/**" in block, "unused legacy concept art must be excluded from every release")
		expect("tests/**" in block, "tests must be excluded from every release preset")


func test_required_notices() -> void:
	expect(FileAccess.file_exists("res://THIRD_PARTY_NOTICES.md"), "third-party notices are required")
	expect(FileAccess.file_exists("res://assets/fonts/OFL.txt"), "font license is required")
	expect(FileAccess.file_exists("res://docs/steam-release-checklist.md"), "Steam release checklist is required")
	expect(FileAccess.file_exists("res://scripts/fetch_godot_copyright.sh"), "version-pinned Godot component notice fetcher is required")
	expect(FileAccess.file_exists("res://steam/app_build.vdf.example"), "SteamPipe app build template is required")
	expect(FileAccess.file_exists("res://steam/depot_windows.vdf.example"), "Windows depot template is required")
	expect(FileAccess.file_exists("res://steam/depot_linux.vdf.example"), "Linux depot template is required")
	expect(FileAccess.file_exists("res://steam/depot_macos.vdf.example"), "macOS depot template is required")
	var workflow := read_text("res://.github/workflows/ci.yml")
	expect("cp THIRD_PARTY_NOTICES.md GODOT_COPYRIGHT.txt assets/fonts/OFL.txt" in workflow, "desktop release artifacts must include license notices")
	expect("GODOT_COPYRIGHT.txt" in workflow, "desktop release artifacts must include Godot component notices")

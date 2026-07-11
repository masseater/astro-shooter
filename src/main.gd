extends Control

const BG := Color("100a16")
const PANEL := Color("211322")
const PANEL_LIGHT := Color("33202d")
const CREAM := Color("f2e8c9")
const MUTED := Color("bd9da5")
const SHARD := Color("58d9e8")
const TEAL := Color("66c7bd")
const PINK := Color("ec6f91")

var screen: Control
var background: Control
var background_dimmer: ColorRect
var music_player: AudioStreamPlayer
var active_session: GameSession
var hud_labels: Dictionary = {}
var last_zone := 0


func _ready() -> void:
	set_process_unhandled_input(true)
	build_theme()
	build_background()
	build_music()
	show_title()


func _process(_delta: float) -> void:
	if active_session != null or get_viewport().gui_get_focus_owner() != null:
		return
	for candidate in screen.find_children("*", "Control", true, false):
		var control := candidate as Control
		if control != null and control.visible and control.focus_mode == Control.FOCUS_ALL:
			if control is BaseButton and (control as BaseButton).disabled:
				continue
			control.grab_focus()
			return


func build_theme() -> void:
	var game_theme := Theme.new()
	game_theme.default_font = load("res://assets/fonts/NotoSansJP.ttf")
	game_theme.default_font_size = 20
	game_theme.set_color("font_color", "Label", CREAM)
	game_theme.set_color("font_color", "Button", CREAM)
	game_theme.set_color("font_hover_color", "Button", Color.WHITE)
	game_theme.set_color("font_pressed_color", "Button", Color.WHITE)
	game_theme.set_constant("outline_size", "Label", 5)
	game_theme.set_color("font_outline_color", "Label", Color("310f21"))
	game_theme.set_font_size("font_size", "Button", 18)
	game_theme.set_stylebox("normal", "Button", style_box(PANEL_LIGHT, SHARD, 2, 7))
	game_theme.set_stylebox("hover", "Button", style_box(Color("513042"), TEAL, 3, 7))
	game_theme.set_stylebox("pressed", "Button", style_box(Color("17101d"), PINK, 2, 7))
	game_theme.set_stylebox("disabled", "Button", style_box(Color("19131b"), Color("4d3d45"), 1, 7))
	game_theme.set_color("font_disabled_color", "Button", Color("6c5a61"))
	game_theme.set_stylebox("panel", "PanelContainer", style_box(Color(PANEL, 0.96), Color("7d4d55"), 2, 10))
	theme = game_theme


func style_box(color: Color, border_color: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func build_background() -> void:
	background = TitleBackground.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	background_dimmer = ColorRect.new()
	background_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_dimmer.color = Color(0.08, 0.03, 0.08, 0.36)
	background_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_dimmer)
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)


func build_music() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.stream = make_ambient_loop()
	music_player.volume_db = -15.0
	add_child(music_player)
	music_player.play()


func make_ambient_loop() -> AudioStreamWAV:
	var sample_rate := 16000
	var seconds := 4.0
	var count := int(sample_rate * seconds)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for index in range(count):
		var t := float(index) / sample_rate
		var envelope := 0.72 + 0.28 * sin(TAU * t / seconds)
		var value := sin(TAU * 55.0 * t) * 0.18
		value += sin(TAU * 82.5 * t + 0.4) * 0.10
		value += sin(TAU * 110.0 * t + sin(t * 0.7)) * 0.045
		value *= envelope
		bytes.encode_s16(index * 2, int(clampf(value, -1.0, 1.0) * 32760.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	stream.data = bytes
	return stream


func play_tone(frequency: float, duration := 0.09, volume := -12.0) -> void:
	var sample_rate := 16000
	var count := int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for index in range(count):
		var t := float(index) / sample_rate
		var envelope := pow(1.0 - float(index) / count, 2.0)
		var value := sin(TAU * frequency * t) * envelope * 0.42
		bytes.encode_s16(index * 2, int(value * 32760.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = bytes
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func clear_screen() -> void:
	for child in screen.get_children():
		child.queue_free()
	hud_labels.clear()
	active_session = null


func show_title() -> void:
	clear_screen()
	background.visible = true
	background_dimmer.visible = true
	background_dimmer.color = Color(0.08, 0.03, 0.08, 0.36)
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.position = Vector2(-310, -340)
	center.size = Vector2(620, 680)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 15)
	screen.add_child(center)
	var pretitle := make_label("CHASE THE SIGNAL BEYOND THE CHARTS", 18, SHARD, HORIZONTAL_ALIGNMENT_CENTER)
	center.add_child(pretitle)
	var title := make_label("RIFT\nWELD", 64, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", Color("341221"))
	center.add_child(title)
	center.add_child(make_label("SIGNALBREAK", 20, TEAL, HORIZONTAL_ALIGNMENT_CENTER))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 18
	center.add_child(spacer)
	var continue_button := make_button("続きから", _show_hub, Vector2(360, 55))
	continue_button.disabled = int(Progress.data.stats.runs) == 0 and Progress.data.upgrades.is_empty()
	center.add_child(continue_button)
	center.add_child(make_button("新しいゲーム", request_new_game, Vector2(360, 55)))
	center.add_child(make_button("設定", show_settings, Vector2(360, 48)))
	center.add_child(make_button("クレジット", show_credits, Vector2(360, 44)))
	if not OS.has_feature("web"):
		center.add_child(make_button("終了", quit_game, Vector2(360, 44)))
	if not Progress.persistence_available:
		center.add_child(make_label("WARNING: このブラウザでは進行を永続保存できません", 16, Color("ff9d87"), HORIZONTAL_ALIGNMENT_CENTER))
	if not Progress.save_warning.is_empty():
		center.add_child(make_label(Progress.save_warning, 16, Color("ffca7a"), HORIZONTAL_ALIGNMENT_CENTER))


func request_new_game() -> void:
	var has_progress: bool = int(Progress.data.stats.runs) > 0 or not Progress.data.upgrades.is_empty() or Progress.coffee() > 0
	if not has_progress:
		start_new_game()
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "新しいゲーム"
	dialog.dialog_text = "現在の進行を消去して最初から開始します。\nこの操作は元に戻せません。"
	dialog.ok_button_text = "最初から開始"
	dialog.cancel_button_text = "キャンセル"
	dialog.confirmed.connect(func(): dialog.queue_free(); start_new_game())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(520, 240))


func start_new_game() -> void:
	Progress.reset_game()
	play_tone(440.0, 0.16)
	show_story_intro()


func show_story_intro() -> void:
	clear_screen()
	background.visible = true
	background_dimmer.visible = true
	background_dimmer.color = Color(0.08, 0.03, 0.08, 0.36)
	var panel := centered_panel(Vector2(760, 440))
	var box := panel.get_child(0) as VBoxContainer
	box.add_child(make_label("TRANSMISSION // UNKNOWN ORIGIN", 18, PINK, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(make_label("FOLLOW THE VOID SIGNAL", 42, CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	var story := RichTextLabel.new()
	story.bbcode_enabled = true
	story.fit_content = true
	story.custom_minimum_size = Vector2(680, 190)
	story.add_theme_font_size_override("normal_font_size", 20)
	story.text = "[center]星図の外から届く信号が、失われた[b][color=#58d9e8]Aether Shard[/color][/b]の在処を示した。\n\n回収船ノマドで封鎖宙域へ入り、Aether Nodeを解体し、\n信号を隠すHelix Directorateの無人艦隊を突破せよ。\n\n[color=#66c7bd]回収。帰還。改修。そして信号源へ。[/color][/center]"
	box.add_child(story)
	box.add_child(make_button("航海を開始", _show_hub, Vector2(300, 56)))


func _show_hub() -> void:
	play_tone(310.0)
	show_hub()


func show_hub() -> void:
	clear_screen()
	background.visible = true
	background_dimmer.visible = true
	background_dimmer.color = Color(0.06, 0.025, 0.06, 0.68)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 28)
	screen.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	header.add_child(make_label("NOMAD DRYDOCK", 36, CREAM))
	header.add_spacer(false)
	header.add_child(make_label("SHARDS %d" % Progress.coffee(), 25, SHARD))
	header.add_child(make_button("強化ツリー", show_upgrades, Vector2(180, 48)))
	header.add_child(make_button("任務", show_tasks, Vector2(112, 48)))
	header.add_child(make_button("実績", show_achievements, Vector2(112, 48)))
	header.add_child(make_button("設定", show_settings, Vector2(112, 48)))
	layout.add_child(header)
	var intel := PanelContainer.new()
	var intel_text := make_label("短い出撃で資源を集め、恒久強化して再出撃。マウス/WASDで移動 • 左クリック/Spaceでブースト • 攻撃は自動", 17, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	intel.add_child(intel_text)
	layout.add_child(intel)
	var zones := GridContainer.new()
	zones.columns = 5
	zones.size_flags_vertical = Control.SIZE_EXPAND_FILL
	zones.add_theme_constant_override("h_separation", 12)
	layout.add_child(zones)
	for index in range(ContentCatalog.ZONES.size()):
		zones.add_child(make_zone_card(index))
	var footer := HBoxContainer.new()
	footer.add_child(make_label("クリア %d/5   •   強化 %d/%d   •   任務 %d/%d" % [Progress.data.cleared_zones.size(), Progress.data.upgrades.size(), ContentCatalog.upgrades().size(), Progress.data.tasks.size(), ContentCatalog.TASKS.size()], 17, MUTED))
	footer.add_spacer(false)
	footer.add_child(make_button("タイトルへ", show_title, Vector2(150, 46)))
	layout.add_child(footer)


func make_zone_card(index: int) -> PanelContainer:
	var zone := ContentCatalog.zone(index)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(228, 430)
	var card_style := style_box(Color("1b1120"), zone.color, 2, 8)
	card.add_theme_stylebox_override("panel", card_style)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	box.add_child(make_label("ZONE %d" % (index + 1), 17, zone.color, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(make_label(zone.name, 23, CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(make_label(zone.subtitle, 15, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var emblem := Control.new()
	emblem.custom_minimum_size = Vector2(180, 150)
	emblem.draw.connect(_draw_zone_emblem.bind(emblem, index, zone.color))
	box.add_child(emblem)
	box.add_child(make_label("敵機: %s\nボス: %s\n制圧目標: %d" % [zone.enemy, zone.boss, zone.quota], 16, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var unlocked := index <= Progress.highest_zone()
	var cleared: bool = str(index) in Progress.data.cleared_zones
	var status_text := "CLEARED" if cleared else ("READY" if unlocked else "LOCKED")
	var status_color := TEAL if cleared else (SHARD if unlocked else Color("67535c"))
	box.add_child(make_label(status_text, 18, status_color, HORIZONTAL_ALIGNMENT_CENTER))
	var launch := make_button("出撃", _start_zone.bind(index), Vector2(180, 52))
	launch.disabled = not unlocked
	box.add_child(launch)
	return card


func _draw_zone_emblem(control: Control, index: int, color: Color) -> void:
	var center := control.size / 2.0
	control.draw_circle(center, 57.0, Color(color, 0.13))
	control.draw_arc(center, 62.0, 0.0, TAU, 32, Color(color, 0.8), 3.0)
	for point_index in range(6 + index):
		var angle := TAU * point_index / (6.0 + index) + index * 0.2
		var outer := center + Vector2.from_angle(angle) * 48.0
		var inner := center + Vector2.from_angle(angle) * 23.0
		control.draw_line(inner, outer, color, 5.0)
	control.draw_circle(center, 22.0 + index * 2.0, Color("38202e"))
	control.draw_circle(center, 9.0, color)


func show_upgrades() -> void:
	clear_screen()
	background.visible = true
	background_dimmer.visible = true
	var margin := screen_margin()
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	header.add_child(make_label("SHIP MODIFICATION TREE", 34, CREAM))
	header.add_spacer(false)
	header.add_child(make_label("SHARDS %d" % Progress.coffee(), 25, SHARD))
	header.add_child(make_button("格納庫へ", show_hub, Vector2(150, 46)))
	layout.add_child(header)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	var tree := VBoxContainer.new()
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.add_theme_constant_override("separation", 10)
	scroll.add_child(tree)
	var all_upgrades := ContentCatalog.upgrades()
	for branch in ContentCatalog.BRANCHES:
		var row_panel := PanelContainer.new()
		row_panel.add_theme_stylebox_override("panel", style_box(Color("1b111e"), branch.color, 2, 8))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 9)
		row_panel.add_child(row)
		var branch_label := make_label(branch.name, 17, branch.color, HORIZONTAL_ALIGNMENT_CENTER)
		branch_label.custom_minimum_size.x = 95
		row.add_child(branch_label)
		for upgrade in all_upgrades:
			if upgrade.branch == branch.key:
				row.add_child(make_upgrade_button(upgrade))
		tree.add_child(row_panel)


func make_upgrade_button(upgrade: Dictionary) -> Button:
	var owned := Progress.has_upgrade(upgrade.id)
	var prerequisite_met := String(upgrade.requires).is_empty() or Progress.has_upgrade(upgrade.requires)
	var task_requirement := String(upgrade.get("task_requires", ""))
	var task_met: bool = task_requirement.is_empty() or task_requirement in Progress.data.tasks
	var label_text := "%s\n%s" % [upgrade.title, upgrade.description]
	if owned:
		label_text += "\nINSTALLED"
	else:
		label_text += "\nCOST %d" % upgrade.cost
		if not task_met:
			label_text += " • TASK LOCK"
	var button := make_button(label_text, _buy_upgrade.bind(upgrade.id), Vector2(205, 82))
	button.add_theme_font_size_override("font_size", 14)
	button.disabled = owned or not prerequisite_met or not task_met or Progress.coffee() < int(upgrade.cost)
	if owned:
		button.add_theme_stylebox_override("disabled", style_box(Color(upgrade.color, 0.20), upgrade.color, 2, 6))
		button.add_theme_color_override("font_disabled_color", CREAM)
	return button


func _buy_upgrade(id: String) -> void:
	if Progress.buy_upgrade(id):
		play_tone(660.0, 0.13)
		show_upgrades()


func show_tasks() -> void:
	clear_screen()
	background.visible = true
	background_dimmer.visible = true
	var margin := screen_margin()
	var layout := VBoxContainer.new()
	margin.add_child(layout)
	var header := HBoxContainer.new()
	header.add_child(make_label("REBEL TASK BOARD", 34, CREAM))
	header.add_spacer(false)
	header.add_child(make_button("格納庫へ", show_hub, Vector2(150, 46)))
	layout.add_child(header)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	layout.add_child(grid)
	for task in ContentCatalog.TASKS:
		var complete: bool = task.id in Progress.data.tasks
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(575, 95)
		panel.add_theme_stylebox_override("panel", style_box(Color("1c121e"), TEAL if complete else Color("664555"), 2, 7))
		var row := HBoxContainer.new()
		panel.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		text.add_child(make_label(task.title, 21, CREAM))
		text.add_child(make_label(task.text, 15, MUTED))
		row.add_child(make_label("COMPLETE" if complete else Progress.task_progress(task), 17, TEAL if complete else SHARD, HORIZONTAL_ALIGNMENT_RIGHT))
		grid.add_child(panel)


func show_achievements() -> void:
	clear_screen()
	background.visible = true
	background_dimmer.visible = true
	var margin := screen_margin()
	var layout := VBoxContainer.new()
	margin.add_child(layout)
	var header := HBoxContainer.new()
	header.add_child(make_label("LOCAL ACHIEVEMENTS", 34, CREAM))
	header.add_spacer(false)
	header.add_child(make_label("%d / %d" % [Progress.data.achievements.size(), ContentCatalog.ACHIEVEMENTS.size()], 22, SHARD))
	header.add_child(make_button("格納庫へ", show_hub, Vector2(150, 46)))
	layout.add_child(header)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	layout.add_child(grid)
	for achievement in ContentCatalog.ACHIEVEMENTS:
		var unlocked: bool = achievement.id in Progress.data.achievements
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(380, 125)
		panel.add_theme_stylebox_override("panel", style_box(Color("20131f") if unlocked else Color("151116"), SHARD if unlocked else Color("443840"), 2, 8))
		var box := VBoxContainer.new()
		panel.add_child(box)
		box.add_child(make_label(achievement.title if unlocked else "LOCKED", 21, SHARD if unlocked else Color("6e5c64"), HORIZONTAL_ALIGNMENT_CENTER))
		box.add_child(make_label(achievement.text if unlocked else "条件を達成して解除", 15, MUTED if unlocked else Color("55474d"), HORIZONTAL_ALIGNMENT_CENTER))
		grid.add_child(panel)


func show_settings() -> void:
	clear_screen()
	background.visible = true
	background_dimmer.visible = true
	var panel := centered_panel(Vector2(650, 510))
	var box := panel.get_child(0) as VBoxContainer
	box.add_child(make_label("SETTINGS", 36, CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(make_label("MASTER VOLUME", 17, MUTED))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(Progress.data.settings.master_volume)
	slider.custom_minimum_size = Vector2(520, 38)
	slider.value_changed.connect(Progress.set_volume)
	box.add_child(slider)
	var mouse_toggle := CheckButton.new()
	mouse_toggle.text = "マウス追従移動"
	mouse_toggle.button_pressed = bool(Progress.data.settings.mouse_move)
	mouse_toggle.toggled.connect(_set_mouse_move)
	box.add_child(mouse_toggle)
	var shake_toggle := CheckButton.new()
	shake_toggle.text = "画面シェイク"
	shake_toggle.button_pressed = bool(Progress.data.settings.screen_shake)
	shake_toggle.toggled.connect(_set_screen_shake)
	box.add_child(shake_toggle)
	box.add_child(make_button("全画面切替", toggle_fullscreen, Vector2(300, 50)))
	box.add_child(make_button("戻る", show_title, Vector2(300, 50)))
	var reset := make_button("進行をリセット", confirm_reset, Vector2(300, 45))
	reset.add_theme_color_override("font_color", Color("ff9d87"))
	box.add_child(reset)


func _set_mouse_move(enabled: bool) -> void:
	Progress.data.settings.mouse_move = enabled
	Progress.save_game()


func _set_screen_shake(enabled: bool) -> void:
	Progress.data.settings.screen_shake = enabled
	Progress.save_game()


func toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)


func show_credits() -> void:
	clear_screen()
	background.visible = true
	background_dimmer.visible = true
	var panel := centered_panel(Vector2(720, 560))
	var box := panel.get_child(0) as VBoxContainer
	box.add_child(make_label("CREDITS & LICENSES", 34, CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(make_label("RIFTWELD: SIGNALBREAK", 24, SHARD, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(make_label("Design, programming, procedural art and audio\nCreated for this original project\n\nEngine\nGodot Engine 4.7 — MIT License\n\nFont\nNoto Sans Japanese — SIL Open Font License 1.1\n\nNo third-party game code, characters, names, music or artwork are included.", 18, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(make_button("ライセンス全文", show_licenses, Vector2(300, 50)))
	box.add_child(make_button("タイトルへ", show_title, Vector2(300, 50)))


func show_licenses() -> void:
	clear_screen()
	background.visible = true
	background_dimmer.visible = true
	var panel := centered_panel(Vector2(880, 650))
	var box := panel.get_child(0) as VBoxContainer
	box.add_child(make_label("OPEN SOURCE LICENSES", 32, CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	var notices := RichTextLabel.new()
	notices.custom_minimum_size = Vector2(800, 500)
	notices.add_theme_font_size_override("normal_font_size", 16)
	var notice_file := FileAccess.open("res://THIRD_PARTY_NOTICES.md", FileAccess.READ)
	notices.text = "ライセンスファイルを読み込めませんでした。godotengine.org/license を参照してください。" if notice_file == null else notice_file.get_as_text()
	var godot_copyright := FileAccess.open("res://GODOT_COPYRIGHT.txt", FileAccess.READ)
	if godot_copyright != null:
		notices.text += "\n\n" + godot_copyright.get_as_text()
	box.add_child(notices)
	box.add_child(make_button("クレジットへ", show_credits, Vector2(300, 48)))


func quit_game() -> void:
	Progress.save_game()
	get_tree().quit()


func confirm_reset() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "進行をリセット"
	dialog.dialog_text = "資源、強化、ゾーン、任務、実績をすべて消去します。"
	dialog.ok_button_text = "リセット"
	dialog.cancel_button_text = "キャンセル"
	dialog.confirmed.connect(func(): Progress.reset_game(); dialog.queue_free(); show_title())
	add_child(dialog)
	dialog.popup_centered(Vector2i(520, 220))


func _start_zone(index: int) -> void:
	last_zone = index
	clear_screen()
	background.visible = false
	background_dimmer.visible = false
	active_session = GameSession.new()
	active_session.configure(index, Progress.combat_stats())
	screen.add_child(active_session)
	active_session.hud_changed.connect(update_hud)
	active_session.run_finished.connect(handle_run_finished)
	active_session.retreat_requested.connect(request_retreat)
	build_hud()
	play_tone(520.0, 0.18)


func build_hud() -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	screen.add_child(overlay)
	var top := HBoxContainer.new()
	top.position = Vector2(30, 18)
	top.size = Vector2(1220, 58)
	top.add_theme_constant_override("separation", 18)
	overlay.add_child(top)
	hud_labels.zone = make_label(ContentCatalog.zone(last_zone).name, 23, ContentCatalog.zone(last_zone).color)
	top.add_child(hud_labels.zone)
	top.add_spacer(false)
	hud_labels.shield = make_label("SHIELD", 19, TEAL)
	top.add_child(hud_labels.shield)
	hud_labels.coffee = make_label("SHARDS 0", 21, SHARD)
	top.add_child(hud_labels.coffee)
	var retreat := make_button("帰還 (R/B)", request_retreat, Vector2(132, 44))
	top.add_child(retreat)
	var bottom := HBoxContainer.new()
	bottom.position = Vector2(32, 670)
	bottom.size = Vector2(1216, 40)
	overlay.add_child(bottom)
	hud_labels.progress = make_label("PROGRESS", 16, MUTED)
	bottom.add_child(hud_labels.progress)
	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(460, 24)
	progress.show_percentage = false
	hud_labels.progress_bar = progress
	bottom.add_child(progress)
	hud_labels.boost = make_label("BOOST", 16, TEAL)
	bottom.add_child(hud_labels.boost)
	var boost_bar := ProgressBar.new()
	boost_bar.max_value = 1.0
	boost_bar.custom_minimum_size = Vector2(240, 24)
	boost_bar.show_percentage = false
	hud_labels.boost_bar = boost_bar
	bottom.add_child(boost_bar)
	bottom.add_spacer(false)
	hud_labels.timer = make_label("00:00", 18, MUTED)
	bottom.add_child(hud_labels.timer)
	var boss_bar := ProgressBar.new()
	boss_bar.position = Vector2(390, 105)
	boss_bar.size = Vector2(500, 24)
	boss_bar.max_value = 1.0
	boss_bar.show_percentage = false
	boss_bar.visible = false
	hud_labels.boss_bar = boss_bar
	overlay.add_child(boss_bar)
	hud_labels.boss_name = make_label(ContentCatalog.zone(last_zone).boss, 17, PINK, HORIZONTAL_ALIGNMENT_CENTER)
	hud_labels.boss_name.position = Vector2(390, 76)
	hud_labels.boss_name.size = Vector2(500, 28)
	hud_labels.boss_name.visible = false
	overlay.add_child(hud_labels.boss_name)
	hud_labels.pause = make_label("PAUSED\nP / ESC / START で再開\nR / B で帰還", 36, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	hud_labels.pause.position = Vector2(390, 290)
	hud_labels.pause.size = Vector2(500, 130)
	hud_labels.pause.visible = false
	overlay.add_child(hud_labels.pause)


func update_hud(values: Dictionary) -> void:
	if hud_labels.is_empty():
		return
	hud_labels.shield.text = "SHIELD %d/%d" % [values.shield, values.max_shield]
	hud_labels.coffee.text = "SHARDS %d   SALVAGED %d   DRONES %d" % [values.coffee, values.mined, values.kills]
	hud_labels.progress.text = "制圧 %d/%d" % [values.progress, values.quota]
	hud_labels.progress_bar.max_value = values.quota
	hud_labels.progress_bar.value = values.progress
	hud_labels.boost_bar.value = values.boost
	hud_labels.boss_bar.visible = values.boss
	hud_labels.boss_name.visible = values.boss
	hud_labels.boss_bar.value = values.boss_hp
	hud_labels.pause.visible = values.paused
	var seconds := int(values.elapsed)
	hud_labels.timer.text = "%02d:%02d" % [seconds / 60, seconds % 60]


func request_retreat() -> void:
	if active_session == null:
		return
	active_session.paused = true
	active_session.emit_hud()
	var dialog := ConfirmationDialog.new()
	dialog.title = "格納庫へ帰還"
	dialog.dialog_text = "現在のShardを保持して出撃を終了します。"
	dialog.ok_button_text = "帰還"
	dialog.cancel_button_text = "出撃を続ける"
	dialog.confirmed.connect(func(): dialog.queue_free(); if_active_retreat())
	dialog.canceled.connect(func(): dialog.queue_free(); if_active_resume())
	add_child(dialog)
	dialog.popup_centered(Vector2i(500, 220))


func if_active_retreat() -> void:
	if active_session:
		active_session.retreat()


func if_active_resume() -> void:
	if active_session:
		active_session.resume()


func handle_run_finished(result: Dictionary) -> void:
	var unlocks := Progress.apply_run(result)
	play_tone(760.0 if result.cleared else 180.0, 0.25)
	show_results(result, unlocks)


func show_results(result: Dictionary, unlocks: Array[String]) -> void:
	clear_screen()
	background.visible = true
	background_dimmer.visible = true
	var panel := centered_panel(Vector2(780, 660))
	var box := panel.get_child(0) as VBoxContainer
	var cleared := bool(result.cleared)
	var final_clear := cleared and int(result.zone) == ContentCatalog.ZONES.size() - 1
	var result_title := "SIGNAL SOURCE REACHED" if final_clear else ("SECTOR CLEARED" if cleared else "SORTIE ENDED")
	box.add_child(make_label(result_title, 38, TEAL if cleared else PINK, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(make_label(ContentCatalog.zone(int(result.zone)).name, 22, CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(make_label("%d Aether Shards   •   %d salvaged   •   %d drones\nDamage: %d   •   Time: %ds" % [result.coffee, result.mined, result.kills, result.damage_taken, int(result.elapsed)], 19, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	if cleared:
		box.add_child(make_label("SECTOR REWARD +%d" % ContentCatalog.zone(int(result.zone)).reward, 22, SHARD, HORIZONTAL_ALIGNMENT_CENTER))
	if final_clear:
		box.add_child(make_label("Helix Crownは沈黙し、未知の信号が初めて鮮明に届いた。", 17, TEAL, HORIZONTAL_ALIGNMENT_CENTER))
	if not unlocks.is_empty():
		var unlock_text := "\n".join(unlocks)
		box.add_child(make_label(unlock_text, 14, Color("f7c66b"), HORIZONTAL_ALIGNMENT_CENTER))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	if final_clear:
		buttons.add_child(make_button("エピローグ", show_epilogue, Vector2(260, 54)))
	else:
		buttons.add_child(make_button("格納庫へ", show_hub, Vector2(210, 54)))
		buttons.add_child(make_button("再出撃", _start_zone.bind(int(result.zone)), Vector2(210, 54)))
	box.add_child(buttons)


func show_epilogue() -> void:
	clear_screen()
	background.visible = true
	background_dimmer.visible = true
	background_dimmer.color = Color(0.04, 0.02, 0.05, 0.48)
	var panel := centered_panel(Vector2(820, 540))
	var box := panel.get_child(0) as VBoxContainer
	box.add_child(make_label("FINAL TRANSMISSION", 18, PINK, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(make_label("THE SIGNAL REMAINS", 40, CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	var story := RichTextLabel.new()
	story.bbcode_enabled = true
	story.fit_content = true
	story.custom_minimum_size = Vector2(730, 250)
	story.add_theme_font_size_override("normal_font_size", 20)
	story.text = "[center]First Directorの演算核は停止した。\n回収されたShardが星図を再構成し、信号源への航路を描き出す。\n\n[b][color=#66c7bd]ノマドは漂流船ではなく、未知へ進む先導船となった。[/color][/b]\n\n封鎖宙域の向こうには、記録から消された恒星系が待っている。\nSignalbreakは終わりではなく、最初の応答だ。[/center]"
	box.add_child(story)
	box.add_child(make_button("格納庫へ戻る", show_hub, Vector2(320, 56)))


func make_label(text: String, font_size := 20, color := CREAM, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


func make_button(text: String, callback: Callable, minimum := Vector2(160, 48)) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = minimum
	button.pressed.connect(callback)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override("focus", style_box(Color("263244"), TEAL, 3, 7))
	return button


func centered_panel(panel_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = -panel_size / 2.0
	panel.size = panel_size
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	screen.add_child(panel)
	return panel


func screen_margin() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 38)
	margin.add_theme_constant_override("margin_right", 38)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 30)
	screen.add_child(margin)
	return margin


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode == KEY_F9 and active_session != null:
		active_session.finish_run(true)
		get_viewport().set_input_as_handled()
		return
	if OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode == KEY_F10:
		Progress.data.coffee = 99999
		Progress.data.highest_zone = 4
		Progress.data.upgrades = []
		for upgrade in ContentCatalog.upgrades():
			Progress.data.upgrades.append(upgrade.id)
		Progress.save_game()
		if active_session == null:
			show_hub()

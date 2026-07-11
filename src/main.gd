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
var selected_chapter := 0
var upgrade_category := "ship"
var upgrade_page := 0
var task_page := 0
var achievement_page := 0


func _ready() -> void:
	set_process_unhandled_input(true)
	selected_chapter = Progress.current_chapter()
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
	var continue_button := make_button(tx("続きから", "CONTINUE"), _show_hub, Vector2(360, 55))
	continue_button.disabled = int(Progress.data.stats.runs) == 0 and Progress.data.upgrades.is_empty()
	center.add_child(continue_button)
	center.add_child(make_button(tx("新しいゲーム", "NEW GAME"), request_new_game, Vector2(360, 55)))
	center.add_child(make_button(tx("設定", "SETTINGS"), show_settings, Vector2(360, 48)))
	center.add_child(make_button(tx("クレジット", "CREDITS"), show_credits, Vector2(360, 44)))
	if not OS.has_feature("web"):
		center.add_child(make_button(tx("終了", "QUIT"), quit_game, Vector2(360, 44)))
	if not Progress.persistence_available:
		center.add_child(make_label(tx("警告: このブラウザでは進行を永続保存できません", "WARNING: This browser cannot persist progress"), 16, Color("ff9d87"), HORIZONTAL_ALIGNMENT_CENTER))
	if not Progress.save_warning.is_empty():
		center.add_child(make_label(localized_save_warning(), 16, Color("ffca7a"), HORIZONTAL_ALIGNMENT_CENTER))


func request_new_game() -> void:
	var has_progress: bool = int(Progress.data.stats.runs) > 0 or not Progress.data.upgrades.is_empty() or Progress.coffee() > 0
	if not has_progress:
		start_new_game()
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = tx("新しいゲーム", "NEW GAME")
	dialog.dialog_text = tx("現在の進行を消去して最初から開始します。\nこの操作は元に戻せません。", "Erase current progress and start over?\nThis cannot be undone.")
	dialog.ok_button_text = tx("最初から開始", "START OVER")
	dialog.cancel_button_text = tx("キャンセル", "CANCEL")
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
	story.text = tx("[center]星図の外から届く信号が、失われた[b][color=#58d9e8]Aether Shard[/color][/b]の在処を示した。\n\n回収船ノマドで封鎖宙域へ入り、Aether Nodeを解体し、\n信号を隠すHelix Directorateの無人艦隊を突破せよ。\n\n[color=#66c7bd]回収。帰還。改修。そして信号源へ。[/color][/center]", "[center]A signal from beyond the charts reveals the lost [b][color=#58d9e8]Aether Shards[/color][/b].\n\nEnter the blockade aboard the Nomad, dismantle Aether Nodes,\nand break through the Helix Directorate's drone fleet.\n\n[color=#66c7bd]Salvage. Return. Refit. Reach the source.[/color][/center]")
	box.add_child(story)
	box.add_child(make_button(tx("航海を開始", "BEGIN VOYAGE"), _show_hub, Vector2(300, 56)))


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
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	screen.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 5)
	margin.add_child(layout)
	selected_chapter = clampi(selected_chapter, 0, ContentCatalog.CHAPTER_COUNT - 1)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",6)
	header.add_child(make_label(tx("ノマド格納庫", "NOMAD DRYDOCK"), 28, CREAM))
	header.add_spacer(false)
	header.add_child(make_label(tx("SHARD %d", "SHARDS %d") % Progress.coffee(), 20, SHARD))
	header.add_child(make_button(tx("装備", "LOADOUT"), show_loadout, Vector2(90, 44)))
	header.add_child(make_button(tx("施設", "FACILITIES"), show_facilities, Vector2(90, 44)))
	header.add_child(make_button(tx("強化ツリー", "UPGRADES"), show_upgrades, Vector2(150, 44)))
	header.add_child(make_button(tx("任務", "MISSIONS"), show_tasks, Vector2(90, 44)))
	header.add_child(make_button(tx("実績", "RECORDS"), show_achievements, Vector2(90, 44)))
	header.add_child(make_button(tx("設定", "SETTINGS"), show_settings, Vector2(90, 44)))
	layout.add_child(header)
	var intel := PanelContainer.new()
	var intel_text := make_label(ContentCatalog.chapter_story(selected_chapter, is_ja()) + "\n" + tx("マウス/WASDで移動 • 左クリック/Spaceでブースト • 攻撃は自動", "Mouse/WASD move • Click/Space boost • Auto-fire"), 14, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	intel.add_child(intel_text)
	layout.add_child(intel)
	if int(Progress.pending_idle.get("amount", 0)) > 0:
		var idle_panel := PanelContainer.new()
		var idle_row := HBoxContainer.new()
		idle_panel.add_child(idle_row)
		idle_row.add_child(make_label(tx("帰還中の回収: %d Shards（%s）" % [Progress.pending_idle.amount, format_duration(int(Progress.pending_idle.seconds))], "OFFLINE SALVAGE: %d Shards (%s)" % [Progress.pending_idle.amount, format_duration(int(Progress.pending_idle.seconds))]), 18, TEAL))
		idle_row.add_spacer(false)
		idle_row.add_child(make_button(tx("受け取る", "CLAIM"), claim_idle_reward, Vector2(130, 42)))
		layout.add_child(idle_panel)
	var chapter_row := HBoxContainer.new()
	chapter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var previous := make_button("◀", change_chapter.bind(-1), Vector2(58, 42)); previous.disabled = selected_chapter == 0
	chapter_row.add_child(previous)
	chapter_row.add_child(make_label("CHAPTER %02d // %s" % [selected_chapter + 1, ContentCatalog.chapter_name(selected_chapter, is_ja())], 24, ContentCatalog.zone(selected_chapter * 10).color, HORIZONTAL_ALIGNMENT_CENTER))
	var next := make_button("▶", change_chapter.bind(1), Vector2(58, 42)); next.disabled = selected_chapter == ContentCatalog.CHAPTER_COUNT - 1
	chapter_row.add_child(next)
	layout.add_child(chapter_row)
	var zones := GridContainer.new()
	zones.columns = 5
	zones.size_flags_vertical = Control.SIZE_EXPAND_FILL
	zones.add_theme_constant_override("h_separation", 12)
	zones.add_theme_constant_override("v_separation", 8)
	layout.add_child(zones)
	for index in range(selected_chapter * 10, selected_chapter * 10 + 10):
		zones.add_child(make_zone_card(index))
	var footer := HBoxContainer.new()
	footer.add_child(make_label(tx("クリア %d/%d • 強化 %d/%d • 任務 %d/%d", "CLEARED %d/%d • UPGRADES %d/%d • MISSIONS %d/%d") % [Progress.data.cleared_zones.size(), ContentCatalog.ZONE_COUNT, Progress.data.upgrades.size(), ContentCatalog.UPGRADE_COUNT, Progress.data.tasks.size(), ContentCatalog.TASK_COUNT], 17, MUTED))
	footer.add_spacer(false)
	footer.add_child(make_button(tx("タイトルへ", "TITLE"), show_title, Vector2(150, 46)))
	layout.add_child(footer)


func make_zone_card(index: int) -> PanelContainer:
	var zone := ContentCatalog.zone(index)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(218, 174);card.clip_contents=true;card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var card_style := style_box(Color("1b1120"), zone.color, 2, 8)
	card.add_theme_stylebox_override("panel", card_style)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)
	box.add_child(make_label("SECTOR %d-%02d" % [int(zone.chapter) + 1, int(zone.sector) + 1], 15, zone.color, HORIZONTAL_ALIGNMENT_CENTER))
	var zone_name:=make_label(zone.name,17,CREAM,HORIZONTAL_ALIGNMENT_CENTER);zone_name.clip_text=true;zone_name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;box.add_child(zone_name)
	var emblem := Control.new()
	emblem.custom_minimum_size = Vector2(180, 46)
	emblem.draw.connect(_draw_zone_emblem.bind(emblem, index, zone.color))
	box.add_child(emblem)
	var detail:=make_label("%s • %s" % [localized_mechanic(String(zone.mechanic)),zone.boss],12,MUTED,HORIZONTAL_ALIGNMENT_CENTER);detail.clip_text=true;detail.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;detail.custom_minimum_size.x=0;detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_child(detail)
	var unlocked := index <= Progress.highest_zone()
	var cleared: bool = str(index) in Progress.data.cleared_zones
	var status_text := tx("クリア済", "CLEARED") if cleared else (tx("出撃可能", "READY") if unlocked else tx("未解放", "LOCKED"))
	var status_color := TEAL if cleared else (SHARD if unlocked else Color("67535c"))
	box.add_child(make_label(status_text, 14, status_color, HORIZONTAL_ALIGNMENT_CENTER))
	var launch := make_button(tx("出撃", "LAUNCH"), _start_zone.bind(index), Vector2(180, 32))
	launch.disabled = not unlocked
	box.add_child(launch)
	return card


func _draw_zone_emblem(control: Control, index: int, color: Color) -> void:
	var center := control.size / 2.0
	var spokes := 5 + index % 8
	control.draw_circle(center, 26.0, Color(color, 0.13))
	control.draw_arc(center, 29.0, 0.0, TAU, 32, Color(color, 0.8), 2.0)
	for point_index in range(spokes):
		var angle := TAU * point_index / spokes + index * 0.13
		control.draw_line(center + Vector2.from_angle(angle) * 9.0, center + Vector2.from_angle(angle) * 24.0, color, 3.0)
	control.draw_circle(center, 7.0, color)


func change_chapter(delta: int) -> void:
	selected_chapter = clampi(selected_chapter + delta, 0, ContentCatalog.CHAPTER_COUNT - 1)
	show_hub()


func claim_idle_reward() -> void:
	Progress.claim_idle(); play_tone(880.0, 0.16); show_hub()


func show_upgrades(category := "", page := -1) -> void:
	if not category.is_empty(): upgrade_category = category
	if page >= 0: upgrade_page = page
	clear_screen()
	background.visible = true
	background_dimmer.visible = true
	var margin := screen_margin()
	margin.add_theme_constant_override("margin_top",12);margin.add_theme_constant_override("margin_bottom",12)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	header.add_child(make_label(tx("船体改修ツリー", "SHIP MODIFICATION TREE"), 30, CREAM))
	header.add_spacer(false)
	header.add_child(make_label(tx("SHARD %d", "SHARDS %d") % Progress.coffee(), 22, SHARD))
	header.add_child(make_button(tx("格納庫へ", "HANGAR"), show_hub, Vector2(150, 46)))
	layout.add_child(header)
	var tabs := HBoxContainer.new(); tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	for item in [["weapon",tx("武器 960", "WEAPONS 960")],["ship",tx("機体 300", "SHIP 300")],["facility",tx("施設 200", "FACILITY 200")],["slot",tx("装備枠 5", "SLOTS 5")],["keystone",tx("基幹 35", "KEYSTONES 35")]]:
		var tab := make_button(item[1], show_upgrades.bind(item[0], 0), Vector2(180, 42)); tab.disabled = upgrade_category == item[0]; tabs.add_child(tab)
	layout.add_child(tabs)
	var filtered: Array[Dictionary] = []
	for upgrade in ContentCatalog.upgrades():
		if upgrade.category == upgrade_category: filtered.append(upgrade)
	var page_size := 24; var page_count := maxi(1, int(ceil(float(filtered.size()) / page_size)))
	upgrade_page = clampi(upgrade_page, 0, page_count - 1)
	var grid := GridContainer.new(); grid.columns = 4; grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 9); grid.add_theme_constant_override("v_separation", 5); layout.add_child(grid)
	for index in range(upgrade_page * page_size, mini(filtered.size(), (upgrade_page + 1) * page_size)):
		grid.add_child(make_upgrade_button(filtered[index]))
	var pager := HBoxContainer.new(); pager.alignment = BoxContainer.ALIGNMENT_CENTER
	var previous := make_button("◀", show_upgrades.bind(upgrade_category, upgrade_page - 1), Vector2(60, 42)); previous.disabled = upgrade_page == 0; pager.add_child(previous)
	pager.add_child(make_label("%d / %d" % [upgrade_page + 1, page_count], 18, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var next := make_button("▶", show_upgrades.bind(upgrade_category, upgrade_page + 1), Vector2(60, 42)); next.disabled = upgrade_page >= page_count - 1; pager.add_child(next)
	layout.add_child(pager)


func make_upgrade_button(upgrade: Dictionary) -> Button:
	var owned := Progress.has_upgrade(upgrade.id)
	var prerequisite_met := String(upgrade.requires).is_empty() or Progress.has_upgrade(upgrade.requires)
	var task_requirement := String(upgrade.get("task_requires", ""))
	var task_met: bool = task_requirement.is_empty() or task_requirement in Progress.data.tasks
	var label_text := "%s\n%s" % [localized_upgrade_title(upgrade), localized_stat(String(upgrade.stat)) + " +" + ContentCatalog.format_percent(float(upgrade.value), String(upgrade.stat))]
	if owned:
		label_text += " • " + tx("導入済", "INSTALLED")
	else:
		label_text += " • " + tx("費用 %d", "COST %d") % upgrade.cost
		if not task_met:
			label_text += " • TASK LOCK"
	var button := make_button(label_text, _buy_upgrade.bind(upgrade.id), Vector2(286, 66))
	button.add_theme_font_size_override("font_size", 13)
	button.disabled = owned or not prerequisite_met or not task_met or Progress.current_chapter() < int(upgrade.unlock_chapter) or Progress.coffee() < int(upgrade.cost)
	if owned:
		button.add_theme_stylebox_override("disabled", style_box(Color(upgrade.color, 0.20), upgrade.color, 2, 6))
		button.add_theme_color_override("font_disabled_color", CREAM)
	return button


func _buy_upgrade(id: String) -> void:
	if Progress.buy_upgrade(id):
		play_tone(660.0, 0.13)
		show_upgrades()


func show_tasks(page := -1) -> void:
	if page >= 0: task_page = page
	clear_screen()
	background.visible = true
	background_dimmer.visible = true
	var margin := screen_margin()
	var layout := VBoxContainer.new()
	margin.add_child(layout)
	var header := HBoxContainer.new()
	header.add_child(make_label(tx("反乱軍任務盤", "REBEL TASK BOARD"), 34, CREAM))
	header.add_spacer(false)
	header.add_child(make_button(tx("格納庫へ", "HANGAR"), show_hub, Vector2(150, 46)))
	layout.add_child(header)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	layout.add_child(grid)
	var tasks := ContentCatalog.tasks(); var page_count := int(ceil(float(tasks.size()) / 10.0)); task_page = clampi(task_page, 0, page_count - 1)
	for index in range(task_page * 10, mini(tasks.size(), (task_page + 1) * 10)):
		var task := tasks[index]
		var complete: bool = task.id in Progress.data.tasks
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(575, 95)
		panel.add_theme_stylebox_override("panel", style_box(Color("1c121e"), TEAL if complete else Color("664555"), 2, 7))
		var row := HBoxContainer.new()
		panel.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		text.add_child(make_label(tx("任務 %03d" % (index + 1), task.title), 21, CREAM))
		text.add_child(make_label(localized_milestone(String(task.kind), int(task.target)), 15, MUTED))
		row.add_child(make_label(tx("達成", "COMPLETE") if complete else Progress.task_progress(task), 17, TEAL if complete else SHARD, HORIZONTAL_ALIGNMENT_RIGHT))
		grid.add_child(panel)
	var pager := HBoxContainer.new(); pager.alignment = BoxContainer.ALIGNMENT_CENTER
	var previous := make_button("◀", show_tasks.bind(task_page - 1), Vector2(60, 42)); previous.disabled = task_page == 0; pager.add_child(previous)
	pager.add_child(make_label("%d / %d" % [task_page + 1, page_count], 18, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var next := make_button("▶", show_tasks.bind(task_page + 1), Vector2(60, 42)); next.disabled = task_page >= page_count - 1; pager.add_child(next)
	layout.add_child(pager)


func show_achievements(page := -1) -> void:
	if page >= 0: achievement_page = page
	clear_screen()
	background.visible = true
	background_dimmer.visible = true
	var margin := screen_margin()
	var layout := VBoxContainer.new()
	margin.add_child(layout)
	var header := HBoxContainer.new()
	header.add_child(make_label(tx("ローカル実績", "LOCAL ACHIEVEMENTS"), 34, CREAM))
	header.add_spacer(false)
	header.add_child(make_label("%d / %d" % [Progress.data.achievements.size(), ContentCatalog.ACHIEVEMENT_COUNT], 22, SHARD))
	header.add_child(make_button(tx("格納庫へ", "HANGAR"), show_hub, Vector2(150, 46)))
	layout.add_child(header)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	layout.add_child(grid)
	var achievements := ContentCatalog.achievements(); var page_count := int(ceil(float(achievements.size()) / 12.0)); achievement_page = clampi(achievement_page, 0, page_count - 1)
	for index in range(achievement_page * 12, mini(achievements.size(), (achievement_page + 1) * 12)):
		var achievement := achievements[index]
		var unlocked: bool = achievement.id in Progress.data.achievements
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(380, 125)
		panel.add_theme_stylebox_override("panel", style_box(Color("20131f") if unlocked else Color("151116"), SHARD if unlocked else Color("443840"), 2, 8))
		var box := VBoxContainer.new()
		panel.add_child(box)
		box.add_child(make_label(tx("記録 %03d" % (index + 1), achievement.title) if unlocked else tx("未解除", "LOCKED"), 21, SHARD if unlocked else Color("6e5c64"), HORIZONTAL_ALIGNMENT_CENTER))
		box.add_child(make_label(localized_milestone(String(achievement.kind), int(achievement.target)) if unlocked else tx("条件を達成して解除", "Complete the condition to unlock"), 15, MUTED if unlocked else Color("55474d"), HORIZONTAL_ALIGNMENT_CENTER))
		grid.add_child(panel)
	var pager := HBoxContainer.new(); pager.alignment = BoxContainer.ALIGNMENT_CENTER
	var previous := make_button("◀", show_achievements.bind(achievement_page - 1), Vector2(60, 42)); previous.disabled = achievement_page == 0; pager.add_child(previous)
	pager.add_child(make_label("%d / %d" % [achievement_page + 1, page_count], 18, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var next := make_button("▶", show_achievements.bind(achievement_page + 1), Vector2(60, 42)); next.disabled = achievement_page >= page_count - 1; pager.add_child(next)
	layout.add_child(pager)


func show_loadout() -> void:
	clear_screen(); background.visible = true; background_dimmer.visible = true
	var margin := screen_margin(); var layout := VBoxContainer.new(); layout.add_theme_constant_override("separation", 12); margin.add_child(layout)
	var header := HBoxContainer.new(); header.add_child(make_label(tx("兵装デッキ", "WEAPON DECK"), 34, CREAM)); header.add_spacer(false)
	header.add_child(make_label(tx("装備 %d/%d" % [Progress.data.loadout.size(), Progress.loadout_slots()], "EQUIPPED %d/%d" % [Progress.data.loadout.size(), Progress.loadout_slots()]), 21, SHARD)); header.add_child(make_button(tx("格納庫へ", "HANGAR"), show_hub, Vector2(150, 46))); layout.add_child(header)
	layout.add_child(make_label(tx("24系統から重複なしで選択。装備枠は強化ツリーで最大6まで拡張されます。", "Choose unique weapon families. Upgrade loadout capacity from 1 to 6."), 17, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var synergy_names: Array[String] = []
	for synergy in ContentCatalog.SYNERGIES:
		if synergy.ids[0] in Progress.data.loadout and synergy.ids[1] in Progress.data.loadout: synergy_names.append(synergy.name_ja if is_ja() else synergy.name)
	if not synergy_names.is_empty(): layout.add_child(make_label(tx("発動連携: ", "ACTIVE SYNERGIES: ") + ", ".join(synergy_names), 16, TEAL, HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new(); grid.columns = 4; grid.size_flags_vertical = Control.SIZE_EXPAND_FILL; grid.add_theme_constant_override("h_separation", 10); grid.add_theme_constant_override("v_separation", 8); layout.add_child(grid)
	var available := Progress.available_weapons()
	for weapon in ContentCatalog.WEAPONS:
		var equipped: bool = weapon.id in Progress.data.loadout
		var label := "%s\n%s • %s" % [weapon.name_ja if is_ja() else weapon.name, localized_family(String(weapon.family)), tx("装備中", "EQUIPPED") if equipped else tx("待機", "STANDBY")]
		var button := make_button(label, toggle_weapon.bind(String(weapon.id)), Vector2(286, 78)); button.disabled = weapon.id not in available; button.add_theme_font_size_override("font_size", 15)
		if equipped: button.add_theme_stylebox_override("normal", style_box(Color(weapon.color, 0.2), weapon.color, 3, 7))
		grid.add_child(button)


func toggle_weapon(id: String) -> void:
	var next: Array[String] = []
	for current in Progress.data.loadout: next.append(String(current))
	if id in next:
		if next.size() > 1: next.erase(id)
	elif next.size() < Progress.loadout_slots(): next.append(id)
	if Progress.set_loadout(next): play_tone(710.0, 0.08)
	show_loadout()


func show_facilities() -> void:
	clear_screen(); background.visible = true; background_dimmer.visible = true
	var margin := screen_margin(); var layout := VBoxContainer.new(); layout.add_theme_constant_override("separation", 10); margin.add_child(layout)
	var header := HBoxContainer.new(); header.add_child(make_label(tx("自律回収施設", "AUTONOMOUS FACILITIES"), 34, CREAM)); header.add_spacer(false)
	header.add_child(make_label("SHARDS %d • %.2f/s" % [Progress.coffee(), Progress.idle_rate()], 22, SHARD)); header.add_child(make_button(tx("格納庫へ", "HANGAR"), show_hub, Vector2(150, 46))); layout.add_child(header)
	layout.add_child(make_label(tx("不在中も最大8時間まで回収。出撃報酬と進行を制限しません。", "Salvage continues offline for up to 8 hours and never gates active progression."), 17, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new(); grid.columns = 2; grid.size_flags_vertical = Control.SIZE_EXPAND_FILL; grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 8); layout.add_child(grid)
	for index in range(ContentCatalog.FACILITIES.size()):
		var facility: Dictionary = ContentCatalog.FACILITIES[index]; var level := Progress.facility_level(facility.id); var cost := Progress.facility_cost(facility.id)
		var panel := PanelContainer.new(); panel.custom_minimum_size = Vector2(575, 92); panel.add_theme_stylebox_override("panel", style_box(Color("1c121e"), Color.from_hsv(0.12 + index * 0.07, 0.5, 0.95), 2, 7))
		var row := HBoxContainer.new(); panel.add_child(row); var info := VBoxContainer.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(info)
		info.add_child(make_label(facility.name_ja if is_ja() else facility.name, 20, CREAM)); info.add_child(make_label("LV %d • %.2f/s" % [level, float(facility.base_rate) * level], 15, MUTED))
		var buy := make_button(tx("購入 %d" % cost, "BUY %d" % cost), buy_facility.bind(String(facility.id)), Vector2(165, 52)); buy.disabled = Progress.current_chapter() < index or Progress.coffee() < cost; row.add_child(buy); grid.add_child(panel)


func buy_facility(id: String) -> void:
	if Progress.buy_facility(id): play_tone(530.0, 0.12)
	show_facilities()


func show_settings() -> void:
	clear_screen()
	background.visible = true
	background_dimmer.visible = true
	var panel := centered_panel(Vector2(650, 650))
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
	mouse_toggle.text = tx("マウス追従移動", "FOLLOW MOUSE")
	mouse_toggle.button_pressed = bool(Progress.data.settings.mouse_move)
	mouse_toggle.toggled.connect(_set_mouse_move)
	box.add_child(mouse_toggle)
	var shake_toggle := CheckButton.new()
	shake_toggle.text = tx("画面シェイク", "SCREEN SHAKE")
	shake_toggle.button_pressed = bool(Progress.data.settings.screen_shake)
	shake_toggle.toggled.connect(_set_screen_shake)
	box.add_child(shake_toggle)
	box.add_child(make_label(tx("難易度（報酬と進行は共通）", "DIFFICULTY (SAME REWARDS & PROGRESS)"), 17, MUTED))
	var difficulty_select := OptionButton.new()
	difficulty_select.custom_minimum_size = Vector2(520, 42)
	for item in [["explore",tx("探索", "EXPLORE")],["standard",tx("標準", "STANDARD")],["danger",tx("危険", "DANGER")]]:
		difficulty_select.add_item(item[1]); difficulty_select.set_item_metadata(difficulty_select.item_count - 1, item[0])
	for index in range(difficulty_select.item_count):
		if difficulty_select.get_item_metadata(index) == Progress.data.settings.difficulty: difficulty_select.select(index)
	difficulty_select.item_selected.connect(func(index: int): Progress.set_difficulty(String(difficulty_select.get_item_metadata(index))))
	box.add_child(difficulty_select)
	box.add_child(make_label(tx("言語", "LANGUAGE"), 17, MUTED))
	var locale_select := OptionButton.new()
	locale_select.custom_minimum_size = Vector2(520, 42); locale_select.add_item("日本語"); locale_select.set_item_metadata(0, "ja"); locale_select.add_item("English"); locale_select.set_item_metadata(1, "en"); locale_select.select(0 if is_ja() else 1)
	locale_select.item_selected.connect(func(index: int): Progress.set_locale(String(locale_select.get_item_metadata(index))); show_settings())
	box.add_child(locale_select)
	box.add_child(make_button(tx("全画面切替", "TOGGLE FULLSCREEN"), toggle_fullscreen, Vector2(300, 50)))
	box.add_child(make_button(tx("戻る", "BACK"), show_title, Vector2(300, 50)))
	var reset := make_button(tx("進行をリセット", "RESET PROGRESS"), confirm_reset, Vector2(300, 45))
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
	box.add_child(make_button(tx("ライセンス全文", "FULL LICENSES"), show_licenses, Vector2(300, 50)))
	box.add_child(make_button(tx("タイトルへ", "TITLE"), show_title, Vector2(300, 50)))


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
	notices.text = tx("ライセンスファイルを読み込めませんでした。godotengine.org/license を参照してください。", "License file could not be loaded. See godotengine.org/license.") if notice_file == null else notice_file.get_as_text()
	var godot_copyright := FileAccess.open("res://GODOT_COPYRIGHT.txt", FileAccess.READ)
	if godot_copyright != null:
		notices.text += "\n\n" + godot_copyright.get_as_text()
	box.add_child(notices)
	box.add_child(make_button(tx("クレジットへ", "CREDITS"), show_credits, Vector2(300, 48)))


func quit_game() -> void:
	Progress.save_game()
	get_tree().quit()


func confirm_reset() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = tx("進行をリセット", "RESET PROGRESS")
	dialog.dialog_text = tx("資源、強化、ゾーン、任務、実績をすべて消去します。", "Erase all resources, upgrades, sectors, missions, and records.")
	dialog.ok_button_text = tx("リセット", "RESET")
	dialog.cancel_button_text = tx("キャンセル", "CANCEL")
	dialog.confirmed.connect(func(): Progress.reset_game(); dialog.queue_free(); show_title())
	add_child(dialog)
	dialog.popup_centered(Vector2i(520, 220))


func _start_zone(index: int) -> void:
	last_zone = index
	clear_screen()
	background.visible = false
	background_dimmer.visible = false
	active_session = GameSession.new()
	active_session.configure(index, Progress.combat_stats(), Progress.data.loadout, Progress.difficulty_multipliers())
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
	hud_labels.shield = make_label(tx("シールド", "SHIELD"), 19, TEAL)
	top.add_child(hud_labels.shield)
	hud_labels.coffee = make_label(tx("SHARD 0", "SHARDS 0"), 21, SHARD)
	top.add_child(hud_labels.coffee)
	var retreat := make_button(tx("帰還 (R/B)", "RETURN (R/B)"), request_retreat, Vector2(132, 44))
	top.add_child(retreat)
	var bottom := HBoxContainer.new()
	bottom.position = Vector2(32, 670)
	bottom.size = Vector2(1216, 40)
	overlay.add_child(bottom)
	hud_labels.progress = make_label(tx("進行", "PROGRESS"), 16, MUTED)
	bottom.add_child(hud_labels.progress)
	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(460, 24)
	progress.show_percentage = false
	hud_labels.progress_bar = progress
	bottom.add_child(progress)
	hud_labels.boost = make_label(tx("加速", "BOOST"), 16, TEAL)
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
	hud_labels.mechanic = make_label(localized_mechanic(String(ContentCatalog.zone(last_zone).mechanic)) + " • " + ", ".join(Progress.data.loadout), 14, ContentCatalog.zone(last_zone).color, HORIZONTAL_ALIGNMENT_CENTER)
	hud_labels.mechanic.position = Vector2(32, 638)
	hud_labels.mechanic.size = Vector2(460, 24)
	overlay.add_child(hud_labels.mechanic)
	hud_labels.pause = make_label(tx("一時停止\nP / ESC / START で再開\nR / B で帰還", "PAUSED\nP / ESC / START TO RESUME\nR / B TO RETURN"), 36, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	hud_labels.pause.position = Vector2(390, 290)
	hud_labels.pause.size = Vector2(500, 130)
	hud_labels.pause.visible = false
	overlay.add_child(hud_labels.pause)


func update_hud(values: Dictionary) -> void:
	if hud_labels.is_empty():
		return
	hud_labels.shield.text = tx("シールド %d/%d", "SHIELD %d/%d") % [values.shield, values.max_shield]
	hud_labels.coffee.text = tx("SHARD %d  回収 %d  撃破 %d", "SHARDS %d  SALVAGED %d  DESTROYED %d") % [values.coffee, values.mined, values.kills]
	hud_labels.progress.text = tx("制圧 %d/%d", "CONTROL %d/%d") % [values.progress, values.quota]
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
	dialog.title = tx("格納庫へ帰還", "RETURN TO HANGAR")
	dialog.dialog_text = tx("現在のShardを保持して出撃を終了します。", "End the sortie and keep the Shards collected so far.")
	dialog.ok_button_text = tx("帰還", "RETURN")
	dialog.cancel_button_text = tx("出撃を続ける", "CONTINUE SORTIE")
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
	var final_clear: bool = cleared and int(result.zone) == ContentCatalog.ZONE_COUNT - 1
	var result_title := tx("信号源へ到達", "SIGNAL SOURCE REACHED") if final_clear else (tx("セクター制圧", "SECTOR CLEARED") if cleared else tx("出撃終了", "SORTIE ENDED"))
	box.add_child(make_label(result_title, 38, TEAL if cleared else PINK, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(make_label(ContentCatalog.zone(int(result.zone)).name, 22, CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(make_label(tx("%d Shards • 回収 %d • 撃破 %d\n被弾: %d • 時間: %d秒", "%d Aether Shards • %d salvaged • %d destroyed\nDamage: %d • Time: %ds") % [result.coffee, result.mined, result.kills, result.damage_taken, int(result.elapsed)], 19, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	if cleared:
		box.add_child(make_label(tx("セクター報酬 +%d", "SECTOR REWARD +%d") % ContentCatalog.zone(int(result.zone)).reward, 22, SHARD, HORIZONTAL_ALIGNMENT_CENTER))
	if final_clear:
		box.add_child(make_label(tx("Helix Crownは沈黙し、未知の信号が初めて鮮明に届いた。", "The Helix Crown falls silent. The unknown signal finally comes through."), 17, TEAL, HORIZONTAL_ALIGNMENT_CENTER))
	if not unlocks.is_empty():
		var unlock_text := "\n".join(unlocks)
		box.add_child(make_label(unlock_text, 14, Color("f7c66b"), HORIZONTAL_ALIGNMENT_CENTER))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	if final_clear:
		buttons.add_child(make_button(tx("エピローグ", "EPILOGUE"), show_epilogue, Vector2(260, 54)))
	else:
		buttons.add_child(make_button(tx("格納庫へ", "HANGAR"), show_hub, Vector2(210, 54)))
		buttons.add_child(make_button(tx("再出撃", "REDEPLOY"), _start_zone.bind(int(result.zone)), Vector2(210, 54)))
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
	story.text = tx("[center]First Directorの演算核は停止した。\n回収されたShardが星図を再構成し、信号源への航路を描き出す。\n\n[b][color=#66c7bd]ノマドは漂流船ではなく、未知へ進む先導船となった。[/color][/b]\n\n封鎖宙域の向こうには、記録から消された恒星系が待っている。\nSignalbreakは終わりではなく、最初の応答だ。[/center]", "[center]The First Director's core has stopped.\nRecovered Shards rebuild the star chart and reveal a path to the source.\n\n[b][color=#66c7bd]The Nomad is no longer a drifter, but a pathfinder into the unknown.[/color][/b]\n\nBeyond the blockade wait systems erased from every record.\nSignalbreak was not the end. It was the first reply.[/center]")
	box.add_child(story)
	box.add_child(make_button(tx("格納庫へ戻る", "RETURN TO HANGAR"), show_hub, Vector2(320, 56)))


func make_label(text: String, font_size := 20, color := CREAM, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


func is_ja() -> bool:
	return String(Progress.data.settings.get("locale", "ja")) == "ja"


func tx(ja: String, en: String) -> String:
	return ja if is_ja() else en


func format_duration(seconds: int) -> String:
	return "%dh %02dm" % [seconds / 3600, (seconds % 3600) / 60]


func localized_upgrade_title(upgrade: Dictionary) -> String:
	if not is_ja(): return String(upgrade.title)
	var parts := String(upgrade.id).split("_")
	var level := parts[parts.size() - 1]
	match String(upgrade.category):
		"weapon":
			return "%s %s" % [ContentCatalog.weapon_by_id(String(upgrade.branch)).name_ja, level]
		"ship":
			for branch in ContentCatalog.SHIP_BRANCHES:
				if branch.id == upgrade.branch: return "%s %s" % [branch.name_ja, level]
		"facility":
			return "%s %s" % [ContentCatalog.facility_by_id(String(upgrade.branch)).name_ja, level]
		"slot": return "装備枠 %s" % level
		"keystone": return "%s 基幹 %s" % [localized_stat(String(upgrade.stat)), level]
	return String(upgrade.title)


func localized_stat(stat: String) -> String:
	if not is_ja(): return stat.replace("_", " ").to_upper()
	return {"damage":"火力","fire_rate":"連射速度","yield":"回収量","speed":"機動力","shield":"シールド","dodge":"回避率","boost":"ブースト","magnet":"吸引範囲","crit":"会心率","armor":"装甲率","weapon_damage":"武器火力","weapon_rate":"武器連射","weapon_projectile":"投射数","weapon_utility":"特殊効果","facility_rate":"施設効率","loadout_slots":"装備枠"}.get(stat, stat)


func localized_milestone(kind: String, target: int) -> String:
	var names_ja := {"mined":"Aether Node回収","kills":"敵撃破","runs":"出撃","bosses":"ボス撃破","coffee_earned":"累計Shard","upgrade_count":"強化導入","zone":"到達セクター"}
	var names_en := {"mined":"Aether Nodes salvaged","kills":"Enemies destroyed","runs":"Sorties","bosses":"Bosses defeated","coffee_earned":"Total Shards","upgrade_count":"Upgrades installed","zone":"Sector reached"}
	return "%s: %d" % [(names_ja if is_ja() else names_en).get(kind, kind), target]


func localized_mechanic(id:String)->String:
	if not is_ja():return id.replace("_"," ").to_upper()
	return {"open_field":"開放宙域","gravity_well":"重力井戸","moving_wall":"移動障壁","ion_storm":"イオン嵐","darkness":"暗黒視界","shield_links":"連結防壁","capture_beacons":"標識制圧","convoy_guard":"船団護衛","rotating_arena":"回転戦場","time_pulse":"時間脈動","mirror_field":"鏡面領域","mine_lattice":"機雷格子","solar_flare":"恒星閃光","warp_gates":"転移門","hazard_tide":"危険潮流","healing_orbits":"治癒軌道","bullet_freeze":"弾幕凍結","polarity_shift":"極性反転","fracture_zones":"断裂領域","signal_jam":"信号妨害"}.get(id,id)


func localized_family(id:String)->String:
	if not is_ja():return id.to_upper()
	return {"direct":"直射","homing":"追尾","chain":"連鎖","area":"範囲","pierce":"貫通","spread":"拡散","orbit":"軌道","mine":"設置","beam":"光線","drone":"随伴","wave":"波動","counter":"反撃","burst":"斉射","vortex":"吸引","repeat":"反復","dot":"継続","slow":"減速","burn":"燃焼","ricochet":"反射","boomerang":"往復","pulse":"脈動","execute":"処刑","random":"乱射","hybrid":"複合"}.get(id,id)


func localized_save_warning() -> String:
	if is_ja(): return Progress.save_warning
	if "バックアップ" in Progress.save_warning: return "Save data was recovered from backup."
	return "Save data could not be loaded. The original files were preserved."


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
		Progress.data.coffee = 999999999
		Progress.data.highest_zone = 99
		Progress.data.weapons = Progress.available_weapons()
		Progress.data.upgrades = ["loadout_slot_2", "loadout_slot_3", "loadout_slot_4", "loadout_slot_5", "loadout_slot_6"]
		Progress.save_game()
		if active_session == null:
			show_hub()

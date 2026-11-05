extends Control
const ECHO_TITLES := ["I · A primeira marca", "II · O caminho de volta", "III · A última linha"]
const ECHO_TEXTS := [
	"Alguém riscou estas palavras na pedra: ‘Não confie no caminho. Confie no que você deixa nele.’ Abaixo, três marcas iguais às que sua mão parece lembrar. Você não sabe seu nome, mas sabe segurar a lâmina.",
	"‘Atravessei a porta para sair. Acordei onde havia começado. As árvores ainda tinham minhas marcas.’ A letra é sua. Você tem certeza disso. A floresta devolve seus passos, mas não consegue apagar tudo.",
	"‘A montanha não fica ao norte. Nem ao sul. Ela fica no fim de qualquer caminho.’ A última frase foi interrompida: ‘Se ainda houver uma linha, siga...’ Do outro lado da névoa, alguma coisa responde."
]
const CREAM := Color("e4dfcc")
const MUTED := Color("9cae9f")
const GREEN := Color("9bbaa3")
const PANEL := Color("142022")
var view: SubViewport
var picture: TextureRect
var forest: LineaForest
var player: LineaPlayer
var camera: Camera3D
var touch: LineaTouchControls
var hud: Control
var overlay: Control
var fade: ColorRect
var flash: ColorRect
var cinematic: Control
var caption: Label
var toast_label: Label
var toast_time := 0.0
var health_bar: ProgressBar
var xp_bar: ProgressBar
var health_label: Label
var level_label: Label
var goal_label: Label
var compass_label: Label
var context_label: Label
var guide_label: Label
var action_bar: ProgressBar
var interact_button: Button
var dodge_button: Button
var sprint_button: Button
var pause_button: Button
var fps_label: Label
var update_label: Label
var update_button: Button
var mode := "menu"
var return_mode := "menu"
var cam_yaw := 0.0
var cam_pitch := 0.52
var camera_target := Vector3.ZERO
var intro_clock := 0.0
var intro_serial := 0
var autosave_clock := 0.0
var interaction: Dictionary = {}
var booted := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	setup_input()
	build_view()
	build_hud()
	build_effects()
	State.changed.connect(refresh_hud)
	Updates.changed.connect(refresh_update)
	resized.connect(resize_view)
	booted = true
	refresh_hud()
	show_main_menu()
	if "--playtest" in OS.get_cmdline_user_args():
		State.new_game()
		start_game(false)
	elif "--capture-intro" in OS.get_cmdline_user_args():
		start_game(true)

func setup_input() -> void:
	# Physical keys preserve WASD on different keyboard layouts.
	for action in ["forward","back","left","right","interact","dodge","pause","sprint"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var keys := {"forward":[KEY_W,KEY_UP],"back":[KEY_S,KEY_DOWN],"left":[KEY_A,KEY_LEFT],
		"right":[KEY_D,KEY_RIGHT],"interact":[KEY_E],"dodge":[KEY_SPACE],"pause":[KEY_ESCAPE],"sprint":[KEY_SHIFT]}
	for action in keys:
		for key in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action,event)
	var pad := {"interact":JOY_BUTTON_A,"dodge":JOY_BUTTON_B,"pause":JOY_BUTTON_START}
	for action in pad:
		var event := InputEventJoypadButton.new()
		event.button_index = pad[action]
		InputMap.action_add_event(action,event)

func build_view() -> void:
	view = SubViewport.new()
	view.name = "PixelWorld"
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.audio_listener_enable_3d = true
	add_child(view)
	forest = LineaForest.new()
	view.add_child(forest)
	player = LineaPlayer.new()
	forest.add_child(player)
	player.stepped.connect(func(): Sound.play("step"))
	player.action_finished.connect(finish_interaction)
	camera = Camera3D.new()
	camera.fov = 58
	camera.near = 0.1
	camera.far = 180
	forest.add_child(camera)
	camera.current = true
	picture = TextureRect.new()
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.texture = view.get_texture()
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grade := ShaderMaterial.new()
	grade.shader = load("res://shaders/pixel_grade.gdshader")
	picture.material = grade
	add_child(picture)
	resize_view()
	camera.position = Vector3(8,5,10)
	camera.look_at(Vector3(0,0.8,0))

func resize_view() -> void:
	if not is_instance_valid(view):
		return
	var heights := [180,270,360]
	var h: int = heights[int(State.settings.quality)]
	var aspect := maxf(size.x, 1) / maxf(size.y, 1)
	view.size = Vector2i(roundi(h * aspect),h)
	if forest:
		forest.apply_quality()

func label(text_value: String, font_size: int = 20, color: Color = CREAM) -> Label:
	var node := Label.new()
	node.text = text_value
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func paragraph(text_value: String, font_size: int = 20, color: Color = CREAM) -> Label:
	var node := label(text_value,font_size,color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node

func style(color: Color, border: Color, radius: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

func button(text_value: String, action: Callable, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = text_value
	node.custom_minimum_size.y = 47
	node.add_theme_font_size_override("font_size",19)
	node.add_theme_color_override("font_color",PANEL if primary else CREAM)
	node.add_theme_color_override("font_hover_color",PANEL if primary else Color.WHITE)
	node.add_theme_color_override("font_focus_color",PANEL if primary else Color.WHITE)
	node.add_theme_stylebox_override("normal",style(GREEN if primary else Color("1b2a2c"),Color("52665b")))
	node.add_theme_stylebox_override("hover",style(Color("b7ccb4") if primary else Color("2a403d"),GREEN))
	node.add_theme_stylebox_override("pressed",style(Color("879f8d"),CREAM))
	node.add_theme_stylebox_override("focus",style(Color(0,0,0,0),CREAM))
	node.pressed.connect(func():
		Sound.play("ui")
		action.call())
	return node

func bar(color: Color, width: float, height: float) -> ProgressBar:
	var node := ProgressBar.new()
	node.custom_minimum_size = Vector2(width,height)
	node.show_percentage = false
	node.max_value = 100
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := style(Color("132024"),Color("4a5b51"),1)
	var fill := style(color,color,1)
	for s in [background,fill]:
		s.content_margin_left = 0
		s.content_margin_right = 0
		s.content_margin_top = 0
		s.content_margin_bottom = 0
	node.add_theme_stylebox_override("background",background)
	node.add_theme_stylebox_override("fill",fill)
	return node

func build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	var stats := VBoxContainer.new()
	stats.position = Vector2(30,23)
	stats.add_theme_constant_override("separation",5)
	hud.add_child(stats)
	level_label = label("VIAJANTE · NÍVEL 1",15,MUTED)
	stats.add_child(level_label)
	health_bar = bar(Color("b76659"),250,16)
	stats.add_child(health_bar)
	health_label = label("VIDA  100 / 100",13)
	stats.add_child(health_label)
	xp_bar = bar(Color("899f79"),250,6)
	stats.add_child(xp_bar)
	var goal := VBoxContainer.new()
	goal.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	goal.position = Vector2(-385,25)
	goal.size.x = 280
	hud.add_child(goal)
	goal.add_child(label("CAPÍTULO I · O DESPERTAR",13,MUTED))
	goal_label = paragraph("Encontre o limite da floresta.",19)
	goal.add_child(goal_label)
	compass_label = label("N",15,MUTED)
	compass_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	compass_label.position = Vector2(-130,32)
	compass_label.size.x = 260
	compass_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(compass_label)
	var pause := button("II",show_pause)
	pause_button = pause
	pause.focus_mode = Control.FOCUS_NONE
	pause.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause.position = Vector2(-82,24)
	pause.size = Vector2(54,48)
	hud.add_child(pause)
	touch = LineaTouchControls.new()
	hud.add_child(touch)
	touch.camera_dragged.connect(rotate_camera)
	context_label = label("",18)
	context_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	context_label.position = Vector2(-270,-128)
	context_label.size = Vector2(540,35)
	context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(context_label)
	action_bar = bar(GREEN,240,5)
	action_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	action_bar.position = Vector2(-120,-97)
	action_bar.size = Vector2(240,5)
	action_bar.visible = false
	hud.add_child(action_bar)
	interact_button = button("INTERAGIR · E",interact,true)
	interact_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	interact_button.position = Vector2(-120,-83)
	interact_button.size = Vector2(240,52)
	hud.add_child(interact_button)
	dodge_button = button("ESQUIVAR",dodge)
	dodge_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	dodge_button.position = Vector2(-190,-108)
	dodge_button.size = Vector2(155,66)
	hud.add_child(dodge_button)
	sprint_button = button("CORRER",func():
		pass)
	sprint_button.toggle_mode = true
	# Toggle manually so touch and keyboard can be combined without stuck actions.
	sprint_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	sprint_button.position = Vector2(-169,-174)
	sprint_button.size = Vector2(134,48)
	hud.add_child(sprint_button)
	for action_button in [interact_button,dodge_button,sprint_button]:
		action_button.focus_mode = Control.FOCUS_NONE
	var help := label("WASD  mover   ·   mouse direito  câmera   ·   E  interagir   ·   espaço  esquivar",13,MUTED)
	help.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	help.position = Vector2(-360,-21)
	help.size.x = 720
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.visible = not OS.has_feature("android")
	hud.add_child(help)
	fps_label = label("",13,MUTED)
	fps_label.position = Vector2(30,139)
	hud.add_child(fps_label)
	guide_label = paragraph("DEIXE UM SINAL\nChegue perto de uma árvore e toque em RISCAR ÁRVORE. Suas marcas vão ajudar na volta.",17,MUTED)
	guide_label.position = Vector2(30,172)
	guide_label.size = Vector2(270,100)
	guide_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	guide_label.add_theme_constant_override("shadow_offset_y",2)
	hud.add_child(guide_label)

func build_effects() -> void:
	toast_label = label("",21,CREAM)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_label.position = Vector2(-400,170)
	toast_label.size = Vector2(800,60)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	toast_label.add_theme_constant_override("shadow_offset_x",2)
	toast_label.add_theme_constant_override("shadow_offset_y",2)
	add_child(toast_label)
	cinematic = Control.new()
	cinematic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cinematic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cinematic)
	for bottom in [false,true]:
		var strip := ColorRect.new()
		strip.color = Color("080d0f")
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.anchor_right = 1
		if bottom:
			strip.anchor_top = 1
			strip.anchor_bottom = 1
			strip.offset_top = -68
		else:
			strip.offset_bottom = 68
		cinematic.add_child(strip)
	caption = label("",24,CREAM)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.anchor_left = 0.18
	caption.anchor_right = 0.82
	caption.anchor_top = 1
	caption.anchor_bottom = 1
	caption.offset_top = -160
	caption.offset_bottom = -75
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_shadow_color",Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_y",2)
	cinematic.add_child(caption)
	var skip := button("Pular abertura  ›",finish_intro)
	skip.anchor_left = 1
	skip.anchor_right = 1
	skip.position = Vector2(-245,17)
	skip.size = Vector2(215,40)
	cinematic.add_child(skip)
	flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(0.65,0.12,0.07,0)
	add_child(flash)
	for _i in 1:
		fade = ColorRect.new()
		fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fade.color = Color(0.02,0.03,0.04,0)
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fade)

func clear_overlay() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
		overlay = null
	update_label = null
	update_button = null

func shell(title: String, subtitle: String, width: float = 650, height: float = 580) -> VBoxContainer:
	clear_overlay()
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02,0.04,0.05,0.7)
	overlay.add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -width/2
	panel.offset_right = width/2
	panel.offset_top = -height/2
	panel.offset_bottom = height/2
	panel.add_theme_stylebox_override("panel",style(PANEL,Color("526459"),4))
	overlay.add_child(panel)
	var margins := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margins.add_theme_constant_override("margin_"+side,16)
	panel.add_child(margins)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	margins.add_child(box)
	box.add_child(label(title,34))
	if not subtitle.is_empty():
		box.add_child(paragraph(subtitle,17,MUTED))
	return box

func set_mode(value: String) -> void:
	if value in ["menu","intro","ending","transition","confirm"]:
		player.cancel_action()
		player.dodge_time = 0
		if value == "menu" and not player.asleep:
			player.stand_pose()
	mode = value
	player.enabled = value == "play"
	touch.active = value == "play"
	touch.reset()
	player.input_vector = Vector2.ZERO
	hud.visible = value == "play"
	cinematic.visible = value == "intro"
	forest.focus_marker.visible = false
	if value != "play":
		player.sprinting = false
		sprint_button.button_pressed = false

func show_main_menu() -> void:
	set_mode("menu")
	var box := shell("THE LAST\nLINEA", "CAPÍTULO I  /  A FLORESTA QUE DEVOLVE",540,586)
	box.get_child(0).add_theme_font_size_override("font_size",58)
	box.add_child(paragraph("Você acordou aqui.\nA floresta parece lembrar de você.",21))
	spacer(box)
	if State.has_save():
		box.add_child(button("Continuar a história",func(): start_game(false),true))
		box.add_child(button("Novo capítulo",confirm_new))
	else:
		box.add_child(button("Despertar na floresta",begin_new,true))
	box.add_child(button("Configurações e atualizações",func(): show_settings("menu")))
	box.add_child(button("Sobre o jogo",show_about))
	box.add_child(label("v%s  ·  B5 SOLUÇÕES  ·  FONES RECOMENDADOS" % ProjectSettings.get_setting("application/config/version"),12,MUTED))
	if not State.save_error.is_empty():
		box.add_child(paragraph(State.save_error,15,Color("d7ad86")))

func spacer(parent: Control, height: float = 6) -> void:
	var node := Control.new()
	node.custom_minimum_size.y = height
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(node)

func confirm_new() -> void:
	set_mode("confirm")
	var box := shell("Recomeçar o capítulo?","O progresso deste aparelho será substituído.",580,310)
	spacer(box)
	box.add_child(button("Recomeçar",begin_new,true))
	box.add_child(button("Manter meu progresso",show_main_menu))

func begin_new() -> void:
	State.new_game()
	# Rebuild removes old marks, disarmed traps and the ending gate.
	var old := forest
	var new_forest := LineaForest.new()
	old.remove_child(player)
	old.remove_child(camera)
	view.add_child(new_forest)
	new_forest.add_child(player)
	new_forest.add_child(camera)
	forest = new_forest
	old.queue_free()
	player.position = Vector3.ZERO
	player.sleep_pose()
	start_game(true)

func start_game(with_intro: bool) -> void:
	clear_overlay()
	cam_yaw = 0
	cam_pitch = 0.52
	player.position = State.last_position + Vector3(0,0.06,0)
	camera_target = player.position + Vector3(0,1,0)
	if with_intro:
		set_mode("intro")
		intro_clock = 0
		intro_serial += 1
		player.sleep_pose()
	else:
		player.stand_pose()
		set_mode("play")
		refresh_hud()
		toast("Marque as árvores. Nem todo caminho é uma saída.",5)

func finish_intro() -> void:
	if mode != "intro":
		return
	intro_serial += 1
	player.stand_pose()
	State.intro_seen = true
	State.save_game()
	set_mode("play")
	camera_target = player.position + Vector3.UP
	refresh_hud()
	toast("Eu preciso me orientar. Posso riscar as árvores próximas.",5)

func show_pause() -> void:
	if mode != "play":
		return
	snapshot()
	set_mode("pause")
	var box := shell("Um instante na névoa", "Seu progresso é salvo automaticamente neste aparelho.",570,485)
	spacer(box)
	box.add_child(button("Voltar à floresta",resume_game,true))
	box.add_child(button("Caderno de memórias",func(): show_journal("pause")))
	box.add_child(button("Configurações e atualizações",func(): show_settings("pause")))
	box.add_child(button("Salvar e voltar ao início",func(): snapshot(); show_main_menu()))

func resume_game() -> void:
	clear_overlay()
	set_mode("play")
	refresh_hud()

func show_about() -> void:
	set_mode("about")
	var box := shell("O que fica na floresta", "THE LAST LINEA · PRIMEIRA VERSÃO JOGÁVEL",650,580)
	box.add_child(paragraph("Um RPG de mistério em capítulos. Explore, faça suas próprias marcas e descubra o que insiste em trazer você de volta.",22))
	box.add_child(paragraph("Criação: Emanuel Bonfim / B5 Soluções\nEngine: Godot 4.6.3 (licença MIT)\nModelos, efeitos e sons originais gerados pelo código do jogo.",18,MUTED))
	box.add_child(paragraph("Celular: arraste à esquerda para andar; à direita para olhar. Toque para interagir, correr ou esquivar. Controle Bluetooth também é aceito.",18))
	spacer(box)
	box.add_child(button("Licenças da engine",show_licenses))
	box.add_child(button("Voltar",show_main_menu,true))

func show_licenses() -> void:
	set_mode("about")
	var box := shell("Licenças", "GODOT ENGINE E COMPONENTES DE TERCEIROS",760,620)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var text_value := Engine.get_license_text()+"\n\n"
	for component in Engine.get_copyright_info():
		text_value += str(component.get("name",""))+"\n"+JSON.stringify(component.get("parts",[]),"  ")+"\n\n"
	text_value += JSON.stringify(Engine.get_license_info(),"  ")
	scroll.add_child(paragraph(text_value,15,MUTED))
	box.add_child(button("Voltar",show_about,true))

func show_settings(origin: String) -> void:
	return_mode = origin
	set_mode("settings")
	var box := shell("Do seu jeito", "CONFIGURAÇÕES · SALVAS NESTE APARELHO",700,650)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",16)
	scroll.add_child(content)
	for item in [["Volume geral","master",0.0,1.0],["Ambiente e música","ambience",0.0,1.0],["Efeitos sonoros","effects",0.0,1.0],
		["Sensibilidade da câmera","sensitivity",0.3,2.5],["Tamanho do controle","touch_scale",0.8,1.3]]:
		setting_slider(content,item[0],item[1],item[2],item[3])
	var quality := OptionButton.new()
	for text_value in ["Econômico · 180p · sem sombras","Equilibrado · 270p","Detalhado · 360p"]:
		quality.add_item(text_value)
	quality.selected = int(State.settings.quality)
	quality.custom_minimum_size.y = 43
	quality.item_selected.connect(func(index: int): State.settings.quality = index; State.save_settings(); resize_view())
	content.add_child(label("Visual pixel art",18,MUTED))
	content.add_child(quality)
	var fps := OptionButton.new()
	fps.add_item("30 FPS · economizar bateria")
	fps.add_item("60 FPS · mais fluidez")
	fps.selected = 0 if int(State.settings.fps) == 30 else 1
	fps.custom_minimum_size.y = 43
	fps.item_selected.connect(func(index: int): State.settings.fps = 30 if index == 0 else 60; State.save_settings())
	content.add_child(fps)
	var check := CheckButton.new()
	check.text = "Mostrar contador de FPS"
	check.button_pressed = bool(State.settings.show_fps)
	check.toggled.connect(func(value: bool): State.settings.show_fps = value; State.save_settings())
	content.add_child(check)
	var hints := CheckButton.new()
	hints.text = "Dicas e destaque de interações"
	hints.button_pressed = bool(State.settings.hints)
	hints.toggled.connect(func(value: bool): State.settings.hints = value; State.save_settings(); refresh_hud())
	content.add_child(hints)
	content.add_child(label("ATUALIZAÇÕES PELO GITHUB",15,GREEN))
	content.add_child(paragraph("Versão instalada: %s. O download vem da release pública deste jogo. O Android pede sua autorização para instalar a atualização." % ProjectSettings.get_setting("application/config/version"),16,MUTED))
	update_label = paragraph(Updates.status_text,17)
	content.add_child(update_label)
	update_button = button("Buscar atualização",update_action,true)
	content.add_child(update_button)
	content.add_child(button("Ver releases no GitHub",func(): OS.shell_open(Updates.RELEASES_URL)))
	box.add_child(button("Concluído",settings_back))
	refresh_update()

func setting_slider(parent: VBoxContainer, title: String, key: String, minimum: float, maximum: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",24)
	var text_node := label(title,18,MUTED)
	text_node.custom_minimum_size.x = 275
	row.add_child(text_node)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.05
	slider.value = float(State.settings[key])
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(180,40)
	slider.value_changed.connect(func(value: float): State.settings[key] = value; State.save_settings(); touch.queue_redraw())
	row.add_child(slider)
	parent.add_child(row)

func settings_back() -> void:
	State.save_settings()
	if return_mode == "pause":
		set_mode("play")
		show_pause()
	else:
		show_main_menu()

func refresh_update() -> void:
	if is_instance_valid(update_label):
		update_label.text = Updates.status_text
	if is_instance_valid(update_button):
		update_button.disabled = Updates.busy
		update_button.text = "Instalar atualização" if Updates.ready_to_install else ("Baixar atualização" if Updates.available else "Buscar atualização")

func update_action() -> void:
	if Updates.ready_to_install:
		snapshot()
		Updates.install()
	elif Updates.available:
		Updates.download()
	else:
		Updates.check()

func show_journal(origin: String) -> void:
	return_mode = origin
	set_mode("journal")
	var box := shell("Caderno de memórias", "%d marcas nas árvores  ·  %d / 3 ecos encontrados" % [State.marks.size(),State.echoes.size()],720,620)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",18)
	scroll.add_child(content)
	for i in 3:
		content.add_child(label(ECHO_TITLES[i] if State.echoes.has(i) else "%s · Memória perdida" % [i+1],22,GREEN))
		content.add_child(paragraph(ECHO_TEXTS[i] if State.echoes.has(i) else "Procure pedras com inscrições esverdeadas entre as árvores.",19,MUTED))
	content.add_child(paragraph("As portas me devolvem à clareira. Minhas marcas e lembranças ficam. As placas de metal no chão escondem armadilhas; posso desarmá-las pela borda. A clareira me permite descansar.",18))
	box.add_child(button("Voltar",settings_back,true))

func show_note(title: String, text_value: String) -> void:
	set_mode("note")
	var box := shell(title,"UM ECO DA FLORESTA",690,420)
	box.add_child(paragraph(text_value,23))
	spacer(box)
	box.add_child(button("Guardar a lembrança",resume_game,true))

func refresh_hud() -> void:
	if not is_instance_valid(hud):
		return
	health_bar.value = State.health
	xp_bar.value = State.xp % 100
	health_label.text = "VIDA  %d / 100" % State.health
	level_label.text = "VIAJANTE · NÍVEL %d  /  XP %d / 100" % [State.level(),State.xp%100]
	goal_label.text = "Investigue a fenda na montanha." if State.mountain_found else "Encontre o limite da floresta."
	if State.completed:
		goal_label.text = "Capítulo concluído · continue explorando."
	guide_label.visible = bool(State.settings.hints) and State.marks.is_empty() and not State.mountain_found

func toast(text_value: String, duration: float = 3.5) -> void:
	toast_label.text = text_value
	toast_time = duration
	toast_label.modulate.a = 1

func grant_xp(amount: int) -> void:
	var previous := State.level()
	State.add_xp(amount)
	if State.level() > previous:
		State.health = mini(100,State.health+20)
		toast("Nível %d · você recuperou 20 de vida." % State.level())
		State.changed.emit()

func rotate_camera(delta: Vector2) -> void:
	if mode != "play":
		return
	cam_yaw -= delta.x * 0.005 * float(State.settings.sensitivity)
	cam_pitch = clampf(cam_pitch + delta.y * 0.003 * float(State.settings.sensitivity),0.2,0.95)

func _input(event: InputEvent) -> void:
	if mode != "play" or not booted:
		return
	# Ordinary GUI Buttons use mouse emulation, which only follows one finger.
	# Handle gameplay actions as real touch events so the joystick can stay held.
	if event is InputEventScreenTouch and event.pressed:
		for action_button in [interact_button,dodge_button,sprint_button,pause_button]:
			if action_button.visible and not action_button.disabled and action_button.get_global_rect().has_point(event.position):
				get_viewport().set_input_as_handled()
				if action_button.toggle_mode:
					action_button.button_pressed = not action_button.button_pressed
				action_button.pressed.emit()
				return
	elif (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == -1:
		# Avoid delivering a synthetic click after the same touch action.
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if mode == "play": show_pause()
		elif mode == "pause": resume_game()
		elif mode in ["settings","journal"]: settings_back()
		elif mode == "intro": finish_intro()
	elif mode == "play":
		if event.is_action_pressed("interact"): interact()
		elif event.is_action_pressed("dodge"): dodge()
	elif mode == "intro" and event.is_action_pressed("interact"):
		finish_intro()

func _process(delta: float) -> void:
	if not booted:
		return
	if toast_time > 0:
		toast_time -= delta
		toast_label.modulate.a = minf(1.0,toast_time)
	else:
		toast_label.modulate.a = 0
	fps_label.visible = bool(State.settings.show_fps)
	if fps_label.visible:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	match mode:
		"menu","about","confirm":
			var t := Time.get_ticks_msec() * 0.00004
			camera.position = Vector3(sin(t)*10,4.5,cos(t)*10)
			camera.look_at(Vector3(0,0.8,0))
		"intro": process_intro(delta)
		"play": process_game(delta)
		"pause","settings","journal","note":
			player.input_vector = Vector2.ZERO

func process_intro(delta: float) -> void:
	intro_clock += delta
	var t := intro_clock
	if t < 4.0:
		camera.position = Vector3(0,lerpf(10,5.8,t/4),lerpf(12,7,t/4))
		camera.look_at(Vector3(0,0.5,0))
		caption.text = "Não há vento. Mesmo assim, as árvores sussurram."
	elif t < 8.0:
		camera.position = Vector3(lerpf(0,1.4,(t-4)/4),2.5,lerpf(4.8,3.7,(t-4)/4))
		camera.look_at(Vector3(0,0.6,0))
		caption.text = "No chão frio, um homem respira.\nEle não se lembra de ter chegado."
	elif t < 11.0:
		var progress := smoothstep(8.0,11.0,t)
		player.model.rotation.z = lerpf(PI/2,0,progress)
		player.model.position = Vector3(lerpf(0.8,0,progress),lerpf(0.24,0,progress),0)
		camera.position = Vector3(lerpf(1.4,0,(t-8)/3),lerpf(2.5,4,(t-8)/3),lerpf(3.7,6,(t-8)/3))
		camera.look_at(Vector3(0,1,0))
		caption.text = "‘Onde eu estou?’"
	elif t < 14.5:
		player.stand_pose()
		camera.position = camera.position.lerp(Vector3(0,5.5,8),delta*1.5)
		camera.look_at(Vector3(0,1,0))
		caption.text = "A lâmina na sua cintura parece familiar.\nTalvez as marcas mostrem o caminho de volta."
	else:
		finish_intro()

func process_game(delta: float) -> void:
	var keyboard := Input.get_vector("left","right","forward","back")
	var pad := Vector2.ZERO
	if not Input.get_connected_joypads().is_empty():
		var id: int = Input.get_connected_joypads()[0]
		pad = Vector2(Input.get_joy_axis(id,JOY_AXIS_LEFT_X),Input.get_joy_axis(id,JOY_AXIS_LEFT_Y))
		if pad.length() < 0.18: pad = Vector2.ZERO
		rotate_camera(Vector2(Input.get_joy_axis(id,JOY_AXIS_RIGHT_X),Input.get_joy_axis(id,JOY_AXIS_RIGHT_Y))*delta*260)
	if Input.is_physical_key_pressed(KEY_Q): cam_yaw += delta*1.5
	if Input.is_physical_key_pressed(KEY_R): cam_yaw -= delta*1.5
	player.input_vector = (keyboard+touch.movement+pad).limit_length(1.0)
	player.camera_yaw = cam_yaw
	player.sprinting = Input.is_action_pressed("sprint") or sprint_button.button_pressed
	sprint_button.text = "ANDAR" if sprint_button.button_pressed else "CORRER"
	dodge_button.disabled = player.dodge_cooldown > 0 or player.busy()
	dodge_button.text = "%.1fs" % player.dodge_cooldown if player.dodge_cooldown > 0 else "ESQUIVAR"
	update_camera(delta)
	update_interaction()
	update_hazards(delta)
	if mode != "play":
		return
	var distance := Vector2(player.position.x,player.position.z).length()
	if distance >= LineaForest.MOUNTAIN_RADIUS and not State.mountain_found:
		discover_mountain()
	var heading := fposmod(cam_yaw,TAU)
	var cardinals := ["NORTE","OESTE","SUL","LESTE"]
	compass_label.text = "·  %s  ·" % cardinals[roundi(heading/(PI/2))%4]
	if State.mountain_found:
		compass_label.text += "   FENDA %dm" % roundi(player.position.distance_to(forest.exit_position))
	autosave_clock += delta
	if autosave_clock >= 8.0:
		autosave_clock = 0
		snapshot()

func update_camera(delta: float) -> void:
	var target := player.position + Vector3(0,1.15,0)
	camera_target = camera_target.lerp(target,1.0-exp(-delta*9))
	var offset := Vector3(sin(cam_yaw)*cos(cam_pitch),sin(cam_pitch),cos(cam_yaw)*cos(cam_pitch))*8.8
	var desired := camera_target + offset
	var query := PhysicsRayQueryParameters3D.create(camera_target,desired,3,[player.get_rid()])
	var hit := forest.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		desired = hit.position + (camera_target-hit.position).normalized()*0.35
	if desired.distance_to(camera_target) < 0.4:
		desired = camera_target + Vector3(0,1.5,0.3)
	var next_position := camera.position.lerp(desired,1.0-exp(-delta*12))
	# Clipping only the desired endpoint is insufficient while orbiting: the
	# smoothed camera can still pass through a trunk on its way there.
	var sweep := PhysicsRayQueryParameters3D.create(camera_target,next_position,3,[player.get_rid()])
	var obstruction := forest.get_world_3d().direct_space_state.intersect_ray(sweep)
	if not obstruction.is_empty():
		next_position = obstruction.position+(camera_target-obstruction.position).normalized()*0.35
	camera.position = next_position
	camera.look_at(camera_target)

func discover_mountain() -> void:
	State.mountain_found = true
	State.mountain_angle = atan2(player.position.x,player.position.z)
	forest.place_exit(State.mountain_angle)
	grant_xp(40)
	snapshot()
	refresh_hud()
	Sound.play("echo")
	toast("A montanha. Qualquer caminho terminava aqui.  +40 XP",6)

func update_interaction() -> void:
	action_bar.visible = player.busy()
	if player.busy():
		action_bar.value = player.action_progress()*100
		context_label.text = "Deixando uma marca na casca…" if player.action_kind == "tree" else "Soltando o mecanismo com cuidado…"
		interact_button.visible = true
		interact_button.disabled = true
		interact_button.text = ("RISCANDO" if player.action_kind == "tree" else "DESARMANDO")+"  %d%%" % roundi(player.action_progress()*100)
		return
	interaction = {}
	var pos := player.position
	if State.mountain_found and pos.distance_to(forest.exit_position) < 3.2:
		interaction = {"type":"exit","text":"Escutar a fenda na montanha"}
	elif pos.length() < 2.7 and State.health < 100:
		interaction = {"type":"rest","text":"Descansar na clareira · recuperar vida"}
	else:
		for i in forest.echo_positions.size():
			if pos.distance_to(forest.echo_positions[i]) < 2.8:
				interaction = {"type":"echo","id":i,"text":"Ler a inscrição na pedra"}
				break
	if interaction.is_empty():
		for trap in forest.traps:
			var distance := pos.distance_to(trap.position)
			if not trap.disarmed and distance < 3.0 and distance > 1.12:
				interaction = {"type":"trap","id":trap.id,"text":"Desarmar a placa de espinhos"}
				break
	if interaction.is_empty():
		var nearest := 2.5
		for tree in forest.trees:
			var distance := pos.distance_to(tree.position)
			if distance < nearest:
				nearest = distance
				interaction = {"type":"tree","id":tree.id,"text":"Esta árvore já tem a sua marca" if tree.marked else "Riscar esta árvore · deixar uma marca"}
	context_label.text = interaction.get("text","")
	interact_button.visible = not interaction.is_empty()
	if not interaction.is_empty():
		var texts := {"tree":"RISCAR ÁRVORE","echo":"LER MEMÓRIA","trap":"DESARMAR","rest":"DESCANSAR","exit":"INVESTIGAR"}
		interact_button.text = texts[interaction.type] + (" · E" if not OS.has_feature("android") else "")
		interact_button.disabled = interaction.type == "tree" and forest.trees[interaction.id].marked
	update_focus_marker()

func update_focus_marker() -> void:
	forest.focus_marker.visible = false
	if interaction.is_empty() or not bool(State.settings.hints):
		return
	var target := Vector3.ZERO
	var marked := false
	match interaction.type:
		"tree":
			target = forest.trees[interaction.id].position
			marked = forest.trees[interaction.id].marked
		"trap": target = forest.trap_positions[interaction.id]
		"echo": target = forest.echo_positions[interaction.id]
		"exit": target = forest.exit_position
	forest.focus_at(target,interaction.type,marked)

func interact() -> void:
	if mode != "play" or interaction.is_empty() or player.busy():
		return
	match interaction.type:
		"tree":
			var id: int = interaction.id
			if forest.trees[id].marked:
				return
			if player.begin_action("tree",id,forest.trees[id].position):
				Sound.play("scratch")
		"trap":
			var id: int = interaction.id
			if not State.disarmed.has(id) and player.begin_action("trap",id,forest.trap_positions[id]):
				Sound.play("scratch")
		"echo":
			var id: int = interaction.id
			if not State.echoes.has(id):
				State.echoes.append(id)
				grant_xp(30)
				Sound.play("echo")
			show_note(ECHO_TITLES[id],ECHO_TEXTS[id])
		"rest":
			State.health = 100
			State.changed.emit()
			Sound.play("echo")
			toast("A clareira lhe devolve o fôlego. Vida recuperada.")
		"exit":
			finish_chapter()
	snapshot()

func finish_interaction(kind: String, id: int) -> void:
	if mode != "play":
		return
	if kind == "tree" and id >= 0 and id < forest.trees.size():
		var tree: Dictionary = forest.trees[id]
		if State.marks.has(id) or player.position.distance_to(tree.position) > 1.8:
			toast("Chegue um pouco mais perto para alcançar a casca.")
			return
		State.marks.append(id)
		forest.mark_tree(id)
		var contact: Vector3 = (player.position-tree.position).normalized()*0.4+Vector3.UP*1.25
		forest.play_wood_chips(tree.position+contact)
		grant_xp(5)
		toast("Marca deixada. Ela continuará aqui.  +5 XP")
	elif kind == "trap" and id >= 0 and id < forest.traps.size():
		var distance := player.position.distance_to(forest.trap_positions[id])
		if State.disarmed.has(id) or distance > 3.2 or distance < 1.05:
			return
		State.disarmed.append(id)
		forest.disarm_trap(id)
		grant_xp(12)
		toast("Armadilha desarmada.  +12 XP")
	refresh_hud()
	snapshot()

func dodge() -> void:
	if mode == "play" and player.dodge():
		Sound.play("step")

func update_hazards(delta: float) -> void:
	for trap in forest.traps:
		trap.timer = maxf(0,trap.timer-delta)
		trap.spikes.position.y = minf(0.65,trap.timer*1.5)
		if not trap.disarmed and trap.timer <= 0 and player.position.distance_to(trap.position) < 1.05 and not player.invulnerable():
			trap.timer = 2.5
			damage(28)
			if mode != "play":
				return
	for door in forest.doors:
		var local := door.to_local(player.global_position)
		var last: float = door.get_meta("last_side",local.z)
		door.set_meta("last_side",local.z)
		if absf(local.x) < 0.95 and absf(local.z) < 1.0 and last*local.z < 0 and absf(last-local.z) < 1.5:
			return_to_clearing(false)
			return

func damage(amount: int) -> void:
	player.cancel_action()
	State.health = maxi(0,State.health-amount)
	State.changed.emit()
	Sound.play("trap")
	flash.color.a = 0.38
	create_tween().tween_property(flash,"color:a",0.0,0.65)
	toast("Espinhos!  −%d de vida. Observe as placas no chão." % amount)
	if State.health <= 0:
		return_to_clearing(true)
	else:
		snapshot()

func fade_to(alpha: float, duration: float) -> void:
	move_child(fade,get_child_count()-1)
	var tween := create_tween()
	tween.tween_property(fade,"color:a",alpha,duration)
	await tween.finished

func return_to_clearing(defeated: bool) -> void:
	if mode != "play":
		return
	set_mode("transition")
	Sound.play("door")
	await fade_to(1.0,0.45)
	player.position = Vector3(0,0.08,0)
	player.velocity = Vector3.ZERO
	if defeated:
		State.health = 100
	for door in forest.doors:
		door.set_meta("last_side",door.to_local(player.global_position).z)
	camera_target = player.position + Vector3.UP
	camera.position = player.position+Vector3(0,5.5,8)
	snapshot()
	refresh_hud()
	await fade_to(0.0,0.6)
	set_mode("play")
	toast("Você desperta outra vez. Suas marcas e memórias continuam aqui." if defeated else "A mesma clareira. As suas marcas ainda estão lá.",5)

func finish_chapter() -> void:
	set_mode("ending")
	if not State.completed:
		grant_xp(60)
	State.completed = true
	snapshot()
	Sound.play("door")
	await fade_to(1.0,1.1)
	var box := shell("A última linha", "FIM DO CAPÍTULO I",680,555)
	box.add_child(paragraph("Você encosta a mão na pedra.\nDo outro lado, uma voz diz seu nome.\n\nVocê não o reconhece.\nMas a sua mão risca uma última linha.",25))
	box.add_child(paragraph("A história continua no próximo capítulo. Novos capítulos chegarão pelas atualizações do jogo.",18,MUTED))
	box.add_child(label("%d memórias  ·  %d marcas  ·  %d XP" % [State.echoes.size(),State.marks.size(),State.xp],16,GREEN))
	spacer(box)
	box.add_child(button("Continuar explorando",resume_game,true))
	box.add_child(button("Voltar ao início",show_main_menu))
	await fade_to(0.0,0.7)

func snapshot() -> void:
	if not booted:
		return
	State.last_position = player.position
	if not State.save_game() and mode == "play":
		toast(State.save_error,5)

func _notification(what: int) -> void:
	if not booted:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		snapshot()
		if mode == "play":
			show_pause()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if mode == "play": show_pause()
		elif mode == "pause": resume_game()
		elif mode in ["settings","journal"]: settings_back()

# lobby.gd — HUB ENTRE RAIDS.
# ============================================================================
# Player anda no hub e entra num PORTAL (chegar perto e apertar C) pra iniciar
# a raid. Esc abre o menu de seleção rápida (estilo Mega Man).
# ============================================================================
extends Node2D

const PLAYER : PackedScene = preload("res://Player/player.tscn")

# Definição dos portais: id da raid + cor + posição + nome.
const PORTALS := [
	{"id": "silvanna",  "name": "RAID 1  ·  Silvanna",  "color": Color(0.70, 0.75, 0.92), "x": 110.0},
	{"id": "duelista",  "name": "RAID 2  ·  Kael",      "color": Color(0.62, 0.62, 0.82), "x": 180.0},
	{"id": "colosso",   "name": "RAID 3  ·  Gorm",      "color": Color(0.58, 0.52, 0.42), "x": 240.0},
	{"id": "tecela",    "name": "RAID 4  ·  Nyx",       "color": Color(0.62, 0.35, 0.82), "x": 310.0},
	{"id": "devorador", "name": "RAID 5  ·  Vorth",     "color": Color(0.82, 0.28, 0.32), "x": 380.0},
]

const FLOOR_Y := 240.0
const PORTAL_W := 28.0
const PORTAL_H := 56.0
const INTERACT_RANGE := 28.0

var _player : CharacterBody2D
var _hint   : Label
var _title  : Label
var _portal_nodes : Array = []   # [{rect:Rect2, raid:String, name:String}]


func _ready() -> void:
	_build_bg()
	_build_geometry()
	_build_portals()
	_build_player()
	_build_ui()
	# Música ambiente do lobby = mesma do menu (campo Menu Music do AudioManager).
	AudioManager.play_music(AudioManager.menu_music)


func _process(_dt: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var near = _portal_near_player()
	if near == null:
		_hint.text = ""
	else:
		_hint.text = "[ C ] entrar — " + near["name"]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Esc no lobby = menu de seleção (modo treino: 1 gate só).
		get_tree().change_scene_to_file("res://UI/menu.tscn")
		return
	if event.is_action_pressed("grab"):
		var near = _portal_near_player()
		if near:
			RaidManager.start_raid(near["raid"])


func _portal_near_player():
	var px : float = _player.global_position.x
	for p in _portal_nodes:
		var r : Rect2 = p["rect"]
		if absf(px - (r.position.x + r.size.x * 0.5)) <= INTERACT_RANGE:
			return p
	return null


# ── Construção do cenário ───────────────────────────────────────
func _build_bg() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.06, 0.10)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)
	add_child(layer)


func _build_geometry() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	add_child(body)
	# chão
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(520.0, 20.0)
	cs.shape = rect
	cs.position = Vector2(240.0, FLOOR_Y + 10.0)
	body.add_child(cs)
	# paredes
	for x in [-6.0, 486.0]:
		var w := CollisionShape2D.new()
		var ws := RectangleShape2D.new()
		ws.size = Vector2(12.0, 280.0)
		w.shape = ws
		w.position = Vector2(x, 135.0)
		body.add_child(w)
	# visuais
	var floorv := ColorRect.new()
	floorv.position = Vector2(0, FLOOR_Y)
	floorv.size = Vector2(480.0, 270.0 - FLOOR_Y)
	floorv.color = Color(0.10, 0.10, 0.16)
	add_child(floorv)


func _build_portals() -> void:
	for p in PORTALS:
		var x : float = p["x"]
		var rect_pos := Vector2(x - PORTAL_W * 0.5, FLOOR_Y - PORTAL_H)

		# Moldura
		var frame := ColorRect.new()
		frame.position = rect_pos + Vector2(-2, -2)
		frame.size = Vector2(PORTAL_W + 4, PORTAL_H + 4)
		frame.color = Color(0.18, 0.18, 0.24)
		add_child(frame)
		# Núcleo (cor do boss)
		var core := ColorRect.new()
		core.position = rect_pos
		core.size = Vector2(PORTAL_W, PORTAL_H)
		core.color = p["color"]
		add_child(core)
		# Nome curto embaixo
		var lbl := Label.new()
		lbl.text = p["id"].to_upper()
		lbl.position = Vector2(x - 40.0, FLOOR_Y + 2.0)
		lbl.size = Vector2(80.0, 12.0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(lbl)
		# Registra zona de interação
		_portal_nodes.append({
			"rect": Rect2(rect_pos, Vector2(PORTAL_W, PORTAL_H)),
			"raid": p["id"],
			"name": p["name"],
		})


func _build_player() -> void:
	_player = PLAYER.instantiate()
	_player.position = Vector2(60.0, FLOOR_Y - 20.0)
	add_child(_player)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)

	_title = Label.new()
	_title.text = "RAIDO — LOBBY"
	_title.position = Vector2(0.0, 6.0)
	_title.size = Vector2(480.0, 14.0)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(_title)

	var sub := Label.new()
	sub.text = "Andar (←→) · Pular (Espaço) · Entrar no portal (C) · Menu rápido (Esc)"
	sub.position = Vector2(0.0, 22.0)
	sub.size = Vector2(480.0, 12.0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(sub)

	_hint = Label.new()
	_hint.position = Vector2(0.0, 200.0)
	_hint.size = Vector2(480.0, 14.0)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(_hint)

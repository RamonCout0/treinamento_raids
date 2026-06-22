# arena.gd
# ============================================================================
# Controlador de arena (reutilizado pelas 5 arenas). Constrói o cenário-caixa
# (chão/paredes/teto na camada 2) por código a partir dos limites, pinta o fundo
# e cuida da tela de VITÓRIA / DERROTA (Enter volta ao menu; Esc sai a qualquer hora).
#
# Cada arena .tscn só instancia: Player + Boss + BossHUD + PlayerHUD e define o
# `arena_tint`. Toda a geometria nasce aqui (placeholder trocável por tilemap depois).
# ============================================================================
extends Node2D

@export var arena_tint  : Color  = Color(0.08, 0.08, 0.12)
@export var menu_scene  : String = "res://UI/menu.tscn"
@export var arena_music : AudioStream   ## música da luta (arraste no Inspetor)

@export_group("Limites (combine com os do boss)")
@export var arena_left  : float = 16.0
@export var arena_right : float = 464.0
@export var arena_top   : float = 16.0
@export var arena_floor : float = 252.0

## Plataformas sólidas (Rect2 em coords da arena). Úteis p/ fases aéreas.
@export var platforms : Array[Rect2] = []

var _result_label : Label
var _done := false
var _won  := false   ## evita derrota mandar pro próximo gate


func _ready() -> void:
	_build_background()
	_build_geometry()
	_build_camera()
	_build_result_ui()
	# HUD cinematográfico (intro do boss + cards de mecânica).
	add_child(preload("res://UI/cinematic_hud.tscn").instantiate())
	AudioManager.play_music(arena_music)
	EventBus.boss_died.connect(_on_win)
	EventBus.player_died.connect(_on_lose)


# Camera2D fixa centralizada (necessária pro shake do GameFeel).
func _build_camera() -> void:
	var cam := Camera2D.new()
	cam.position = Vector2(240.0, 135.0)   # centro da viewport 480x270
	add_child(cam)
	cam.make_current.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		RaidManager.return_to_lobby()
	elif _done and event.is_action_pressed("ui_accept"):
		# SÓ avança pra próximo gate em VITÓRIA. Derrota = volta ao lobby.
		if _won and RaidManager.current_raid != "":
			RaidManager.next_gate()
		else:
			RaidManager.return_to_lobby()


func _build_background() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = arena_tint
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)
	add_child(layer)


func _build_geometry() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 2   # arena
	body.collision_mask = 0
	add_child(body)

	var w := arena_right - arena_left
	var h := arena_floor - arena_top
	_add_collider(body, Vector2((arena_left + arena_right) * 0.5, arena_floor + 10.0), Vector2(w + 40.0, 20.0))   # chão
	_add_collider(body, Vector2(arena_left - 6.0, (arena_top + arena_floor) * 0.5), Vector2(12.0, h + 40.0))      # parede esq
	_add_collider(body, Vector2(arena_right + 6.0, (arena_top + arena_floor) * 0.5), Vector2(12.0, h + 40.0))     # parede dir
	_add_collider(body, Vector2((arena_left + arena_right) * 0.5, arena_top - 6.0), Vector2(w + 40.0, 12.0))      # teto

	# Visuais placeholder (chão + paredes).
	var floorv := _rect(Vector2(arena_left - 20.0, arena_floor), Vector2(w + 40.0, 270.0 - arena_floor + 20.0), arena_tint.lightened(0.10))
	add_child(floorv)
	add_child(_rect(Vector2(0, 0), Vector2(arena_left, 270.0), arena_tint.darkened(0.2)))
	add_child(_rect(Vector2(arena_right, 0), Vector2(480.0 - arena_right, 270.0), arena_tint.darkened(0.2)))

	# Plataformas sólidas (colisão + visual).
	for pf in platforms:
		_add_collider(body, pf.position + pf.size * 0.5, pf.size)
		add_child(_rect(pf.position, pf.size, arena_tint.lightened(0.18)))


func _add_collider(body: StaticBody2D, pos: Vector2, size: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	cs.position = pos
	body.add_child(cs)


func _rect(pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.color = color
	r.z_index = -5
	return r


func _build_result_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 8
	_result_label = Label.new()
	_result_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_label.text = ""
	layer.add_child(_result_label)
	add_child(layer)


func _on_win() -> void:
	if _done: return
	_done = true
	_won  = true
	var next := "próximo gate" if RaidManager.current_raid != "" else "lobby"
	_result_label.text = "VITÓRIA!\n\nEnter — %s" % next


func _on_lose() -> void:
	if _done: return
	_done = true
	_won  = false
	_result_label.text = "DERROTA\n\nEnter — lobby (recomeça a raid)"

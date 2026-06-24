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

# O viewport real do projeto continua 480x270 — a arena agora é 2x maior
# (em cada eixo) que isso, então a câmera passa a SEGUIR o player (em vez de
# ficar fixa centralizada) com limites pra nunca mostrar além do fundo pintado.
const WORLD_W := 960.0
const WORLD_H := 540.0

@export var arena_tint  : Color  = Color(0.08, 0.08, 0.12)
@export var arena_music : AudioStream   ## música da luta (arraste no Inspetor)
## Arte de fundo opcional (substitui o ColorRect do arena_tint). Desenhe em
## 960x540 (WORLD_W x WORLD_H) p/ cobrir a arena toda sem repetir/distorcer —
## a câmera dá pan por cima dela. Deixe vazio pra manter o placeholder de cor.
@export var background_texture : Texture2D

@export_group("Limites (combine com os do boss)")
@export var arena_left  : float = 32.0
@export var arena_right : float = 928.0
@export var arena_top   : float = 32.0
@export var arena_floor : float = 504.0

## Plataformas sólidas (Rect2 em coords da arena). Úteis p/ fases aéreas.
@export var platforms : Array[Rect2] = []

var _result_label : Label
var _bg_sprite : Sprite2D = null   ## referência viva p/ set_background() troca em tempo real
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


# Camera2D que segue o player (necessária pro shake do GameFeel). Zoom fica
# em 1.0 (não muda); os limites travam a câmera dentro do fundo pintado, então
# ela nunca mostra vazio além da arena.
func _build_camera() -> void:
	var cam := Camera2D.new()
	cam.limit_left   = 0
	cam.limit_top    = 0
	cam.limit_right  = WORLD_W
	cam.limit_bottom = WORLD_H
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.add_child(cam)
	else:
		add_child(cam)
		cam.position = Vector2(WORLD_W * 0.5, WORLD_H * 0.5)
	cam.make_current.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		RaidManager.return_to_lobby()
	elif _done and event.is_action_pressed("ui_accept"):
		if not _won:
			RaidManager.retry_gate()             # DERROTA → tenta o MESMO gate de novo
		elif RaidManager.current_raid != "":
			RaidManager.next_gate()              # VITÓRIA → próximo gate
		else:
			RaidManager.return_to_lobby()        # vitória avulsa → lobby


func _build_background() -> void:
	if background_texture:
		_bg_sprite = Sprite2D.new()
		_bg_sprite.centered = false
		_bg_sprite.z_index = -100   # atrás do chão/paredes (que usam z_index -5)
		add_child(_bg_sprite)
		set_background(background_texture)
		return

	# Placeholder: ColorRect full-rect (sem textura definida).
	var layer := CanvasLayer.new()
	layer.layer = -10
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = arena_tint
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)
	add_child(layer)


## Troca a arte de fundo em tempo real (ex.: mudança de cenário numa transição
## de fase). Bosses chamam isto via `get_parent().set_background(tex)` — o
## Boss é filho direto da Arena. Desenhe a textura em 960x540 (WORLD_W x
## WORLD_H) igual à arte inicial. Se a arena começou no placeholder de cor
## (sem `background_texture`), a primeira chamada já cria o Sprite2D.
func set_background(tex: Texture2D) -> void:
	if not tex:
		return
	if not is_instance_valid(_bg_sprite):
		_bg_sprite = Sprite2D.new()
		_bg_sprite.centered = false
		_bg_sprite.z_index = -100
		add_child(_bg_sprite)
	_bg_sprite.texture = tex
	var tex_size := tex.get_size()
	if tex_size.x > 0.0 and tex_size.y > 0.0:
		_bg_sprite.scale = Vector2(WORLD_W / tex_size.x, WORLD_H / tex_size.y)


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
	var floorv := _rect(Vector2(arena_left - 20.0, arena_floor), Vector2(w + 40.0, WORLD_H - arena_floor + 20.0), arena_tint.lightened(0.10))
	add_child(floorv)
	add_child(_rect(Vector2(0, 0), Vector2(arena_left, WORLD_H), arena_tint.darkened(0.2)))
	add_child(_rect(Vector2(arena_right, 0), Vector2(WORLD_W - arena_right, WORLD_H), arena_tint.darkened(0.2)))

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
	_result_label.text = "VITÓRIA!\n\nEnter — %s\nEsc — lobby" % next


func _on_lose() -> void:
	if _done: return
	_done = true
	_won  = false
	_result_label.text = "DERROTA\n\nEnter — tentar de novo (mesmo gate)\nEsc — lobby"

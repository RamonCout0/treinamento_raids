# hazard.gd
# ============================================================================
# Perigo genérico (PLACEHOLDER trocável). Node2D, detecção por AABB/raio manual.
# Fluxo: TELEGRAFO (aviso piscando) -> ATIVO (dá dano) -> some.
#
# FORMAS:
#   shape = 0 -> retângulo (size = largura x altura)
#   shape = 1 -> círculo   (raio = size.x * 0.5)   [telegrafo de raid]
#
# INVERSO (zona segura): inverse = true -> dá dano em quem está FORA da forma
#   (ex.: "fique dentro do círculo verde ou toma o golpe").
#
# VISUAL: cubo/círculo placeholder com brilho; ou uma `skin` (PackedScene)
# instanciada centralizada em (0,0).
# ============================================================================
extends Node2D

var _size        : Vector2 = Vector2(32, 32)
var _color       : Color   = Color(1, 0, 0)
var _damage      : float   = 500.0
var _telegraph   : float   = 0.6
var _active      : float   = 0.4
var _tick        : float   = 0.0
var _respect_dash: bool    = true
var _instakill   : bool    = false
var _skin        : PackedScene = null
var _shape       : int     = 0       # 0 = retângulo, 1 = círculo
var _inverse     : bool    = false   # true = dano FORA da forma (zona segura)

const PERIGO_SHADER := preload("res://Shaders_Efeitos/perigo.gdshader")

var _vis      : CanvasItem = null
var _is_rect  : bool  = true
var _is_draw  : bool  = false        # desenha círculo via _draw (placeholder)
var _phase    : int   = 0
var _timer    : float = 0.0
var _dmg_cd   : float = 0.0
var _hit_once : bool  = false
var _cur_alpha: float = 0.3
var _player   : Node2D = null

signal expired


func setup(size: Vector2, color: Color, damage: float, telegraph: float,
		active: float, tick: float = 0.0, respect_dash: bool = true,
		instakill: bool = false, skin: PackedScene = null,
		shape: int = 0, inverse: bool = false) -> void:
	_size = size; _color = color; _damage = damage
	_telegraph = telegraph; _active = active; _tick = tick
	_respect_dash = respect_dash; _instakill = instakill; _skin = skin
	_shape = shape; _inverse = inverse


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D

	if _skin:
		var inst := _skin.instantiate()
		add_child(inst)
		if inst is CanvasItem:
			_vis = inst
		_is_rect = false
	elif _shape == 1:
		_is_draw = true          # círculo placeholder via _draw
	else:
		var r := ColorRect.new()
		r.size = _size
		r.position = -_size * 0.5
		r.color = _color
		var mat := ShaderMaterial.new()
		mat.shader = PERIGO_SHADER
		r.material = mat
		add_child(r)
		_vis = r
		_is_rect = true

	_phase = 0
	_timer = _telegraph
	_apply_look(false)
	if _telegraph <= 0.0:
		_activate()


func _draw() -> void:
	if not _is_draw:
		return
	var rad := _size.x * 0.5
	var c := Color(_color.r, _color.g, _color.b, _cur_alpha)
	draw_circle(Vector2.ZERO, rad, c)
	# anel de borda pra leitura
	draw_arc(Vector2.ZERO, rad, 0.0, TAU, 48, Color(_color.r, _color.g, _color.b, min(1.0, _cur_alpha + 0.3)), 2.0)


func _activate() -> void:
	_phase = 1
	_timer = _active
	_apply_look(true)


func _apply_look(is_active: bool) -> void:
	_cur_alpha = 0.85 if is_active else 0.30
	if _is_draw:
		queue_redraw()
	elif _vis:
		if _is_rect:
			(_vis as ColorRect).color = Color(_color.r, _color.g, _color.b, _cur_alpha)
		else:
			_vis.modulate.a = 1.0 if is_active else 0.4


func _physics_process(delta: float) -> void:
	_dmg_cd -= delta

	if _phase == 0:
		# pisca o telegrafo
		_cur_alpha = 0.18 + 0.22 * (sin(_timer * 18.0) * 0.5 + 0.5)
		if _is_draw:
			queue_redraw()
		elif _is_rect and _vis:
			(_vis as ColorRect).color.a = _cur_alpha
		_timer -= delta
		if _timer <= 0.0:
			_activate()
		return

	_try_damage()

	if _active >= 0.0:
		_timer -= delta
		if _timer <= 0.0:
			expired.emit()
			queue_free()


func _try_damage() -> void:
	if not _player or not is_instance_valid(_player):
		return

	var inside := false
	var p := _player.global_position
	if _shape == 1:
		inside = global_position.distance_to(p) <= _size.x * 0.5
	else:
		var half := _size * 0.5
		inside = abs(p.x - global_position.x) <= half.x and abs(p.y - global_position.y) <= half.y

	var hit := inside if not _inverse else not inside
	if not hit:
		return

	if _respect_dash and _player.get("is_dashing"):
		return
	if _instakill:
		_player.take_damage(999999.0)
		return
	if _tick <= 0.0:
		if not _hit_once:
			_hit_once = true
			_player.take_damage(_damage)
	else:
		if _dmg_cd <= 0.0:
			_dmg_cd = _tick
			_player.take_damage(_damage)

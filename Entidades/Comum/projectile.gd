# projectile.gd
# ============================================================================
# Projétil genérico (PLACEHOLDER trocável). Area2D.
#
# 3 modos:
#   STRAIGHT — anda reto na direção dada.
#   HOMING   — persegue o player (vira suavemente). Bom p/ "mãos/almas".
#   BOUNCE   — ricocheteia nas paredes da arena N vezes.
#
# Opções:
#   counterable = true  -> o Parry (tecla Z) destrói o projétil se o player
#                          estiver perto (counter_range).
#
# Configure via setup() ANTES de add_child. Troque o visual por arte com `skin`.
# Camadas: layer 0, mask 1 (detecta o corpo do player, camada 1).
# ============================================================================
extends Area2D

enum Mode { STRAIGHT, HOMING, BOUNCE }

var _mode        : Mode    = Mode.STRAIGHT
var _dir         : Vector2 = Vector2.RIGHT
var _speed       : float   = 280.0
var _damage      : float   = 800.0
var _arena       : Rect2   = Rect2(0, 0, 480, 270)
var _counterable : bool    = false
var _counter_range : float = 80.0
var _max_bounces : int     = 3
var _lifetime    : float   = 6.0
var _size        : Vector2 = Vector2(12, 6)
var _color       : Color   = Color(0.95, 0.9, 0.5)
var _skin        : PackedScene = null
var _homing_turn : float   = 4.0   # rad/s de viragem no modo HOMING

var _velocity : Vector2
var _bounces  : int   = 0
var _time     : float = 0.0
var _player   : Node2D = null


func setup(mode: Mode, dir: Vector2, speed: float, damage: float, arena: Rect2,
		counterable: bool = false, skin: PackedScene = null,
		size: Vector2 = Vector2(12, 6), color: Color = Color(0.95, 0.9, 0.5)) -> void:
	_mode = mode; _dir = dir.normalized(); _speed = speed; _damage = damage
	_arena = arena; _counterable = counterable; _skin = skin
	_size = size; _color = color


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_velocity = _dir * _speed
	collision_layer = 0
	collision_mask  = 1   # corpo do player

	if _skin:
		add_child(_skin.instantiate())
	else:
		var vis := ColorRect.new()
		vis.size = _size
		vis.position = -_size * 0.5
		vis.color = _color
		add_child(vis)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = _size
	shape.shape = rect
	add_child(shape)

	body_entered.connect(_on_body)
	if _counterable and EventBus.has_signal("player_counter_pressed"):
		EventBus.player_counter_pressed.connect(_on_counter)


func _physics_process(delta: float) -> void:
	_time += delta
	if _time >= _lifetime:
		queue_free()
		return

	match _mode:
		Mode.HOMING:
			if _player and is_instance_valid(_player):
				var want := (_player.global_position - global_position).normalized()
				_velocity = _velocity.normalized().slerp(want, clampf(_homing_turn * delta, 0.0, 1.0)) * _speed
			global_position += _velocity * delta
		Mode.BOUNCE:
			var next := global_position + _velocity * delta
			var bounced := false
			if next.x <= _arena.position.x or next.x >= _arena.position.x + _arena.size.x:
				_velocity.x = -_velocity.x; bounced = true
			if next.y <= _arena.position.y or next.y >= _arena.position.y + _arena.size.y:
				_velocity.y = -_velocity.y; bounced = true
			if bounced:
				_bounces += 1
				if _bounces >= _max_bounces:
					queue_free(); return
			global_position += _velocity * delta
		_:
			global_position += _velocity * delta

	rotation = _velocity.angle()


func _on_body(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(_damage)
		if _mode != Mode.BOUNCE:   # ricochete atravessa, os outros somem
			queue_free()


func _on_counter() -> void:
	if _player and is_instance_valid(_player):
		if global_position.distance_to(_player.global_position) < _counter_range:
			queue_free()

extends CharacterBody2D
# ============================================================================
# RAI — protagonista melee (PLACEHOLDER: corpo é um ColorRect).
# ----------------------------------------------------------------------------
# Ferramentas (e o que cada uma stressa nas lutas):
#   • Combo de ataque (X)  — dano. 3 golpes; o 3º (finalizador) dá mais stagger.
#   • Heavy carregado (V)  — o golpe que MAIS gera stagger (abre janelas de DPS).
#   • Dash (Shift)         — i-frames (invencível) + reposiciona. Cooldown.
#   • Parry / Counter (Z)  — anula o dano de um golpe e dispara o sinal de counter
#                            (coração das mecânicas: Duelista, Tecelã, Devorador...).
#   • Pulo (Espaço) + wall-climb/slide (segura C na parede).
#
# Trocar placeholder por arte: substitua o nó "Visual" (ColorRect) por um
# AnimatedSprite2D. O código só liga/desliga hitbox e estados — não depende do visual.
# ============================================================================

# --- MOVIMENTO ---
const SPEED            := 250.0
const JUMP_VELOCITY    := -450.0
const WALL_CLIMB_SPEED := 160.0
const WALL_SLIDE_SPEED := 100.0
const DASH_SPEED       := 850.0
const DASH_TIME        := 0.18
const DASH_COOLDOWN    := 0.40

# --- ATAQUE / STAGGER (dano e stagger por golpe) ---
const COMBO_WINDOW := 0.8
const ATTACK_MOVE_FACTOR := 0.72   # quanto da velocidade você mantém atacando (não trava)
const BUFFER_TIME := 0.25         # janela de buffer p/ encadear o próximo golpe
# [dano, stagger] por passo de combo
# OBS: o combo é rápido (encadeia com buffer), então o dano por golpe é baixo
# de propósito — quem mata é a CONSISTÊNCIA + as janelas de stagger (dano 2x).
const COMBO_DMG     := [250.0, 350.0, 600.0]
const COMBO_STAGGER := [500.0, 650.0, 900.0]
# Heavy: lento e fraco em dano, mas é o MAIOR gerador de stagger (abre o DPS).
const HEAVY_DMG     := 700.0
const HEAVY_STAGGER := 2000.0

# --- PARRY ---
const PARRY_WINDOW := 0.22   # tempo em que o parry anula dano

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# --- VIDA ---
@export var max_health: float = 12000.0
var current_health: float = max_health

# --- ESTADOS ---
var is_attacking := false
var is_dashing   := false   # bosses leem isto como i-frame
var is_grabbing  := false
var can_dash     := true
var is_parrying  := false    # janela em que o parry anula dano
var _facing      := 1.0      # 1 = direita, -1 = esquerda

# --- COMBO ---
var combo_step  := 0
var combo_timer := 0.0
var _buffer     := ""    # "attack" / "heavy" — próximo golpe em fila
var _buffer_t   := 0.0

# Dano/stagger do golpe em andamento + alvos já atingidos no swing
var _cur_dmg     := 0.0
var _cur_stagger := 0.0
var _hit_targets := []

# --- ANIMAÇÃO ---
var _attack_anim    := "attack1"   # qual anim de ataque tocar (atualizada por golpe)
var _attack_started := false       # força reiniciar a anim no começo do golpe
var _hurt_t         := 0.0         # tempinho tocando "hurt" ao tomar dano

@onready var visual: CanvasItem = $Visual
@onready var attack_area: Area2D = $AttackHitbox
@onready var attack_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D


func _ready() -> void:
	add_to_group("player")
	# Camadas: 1=player, 2=arena, 3=boss, 4=hurtbox/hittable.
	collision_layer = 1            # player
	collision_mask  = 2            # colide só com a arena (não com o corpo do boss)
	attack_area.collision_layer = 0
	attack_area.collision_mask  = 8  # detecta a Hurtbox do boss (camada 4)
	attack_shape.disabled = true
	attack_area.body_entered.connect(_on_hit_body)
	attack_area.area_entered.connect(_on_hit_area)
	EventBus.player_max_health_set.emit.call_deferred(max_health)


func _physics_process(delta: float) -> void:
	combo_timer = max(0.0, combo_timer - delta)
	if combo_timer == 0.0:
		combo_step = 0
	_buffer_t = max(0.0, _buffer_t - delta)
	if _buffer_t == 0.0:
		_buffer = ""
	_hurt_t = max(0.0, _hurt_t - delta)

	if is_dashing:
		move_and_slide()
		_update_visual()
		return

	if not is_on_floor() and not is_grabbing:
		velocity.y += gravity * delta

	_handle_wall_grab()
	_handle_jump()
	_handle_dash()
	_handle_attacks()
	_handle_parry()
	_handle_movement()

	move_and_slide()
	_update_visual()


func _handle_movement() -> void:
	# O parry trava no lugar (postura). O ataque NÃO trava — você mantém parte
	# da mobilidade (steering) pra não sentir "preso".
	if is_parrying:
		velocity.x = move_toward(velocity.x, 0, SPEED * 2.0)
		return
	var dir := Input.get_axis("ui_left", "ui_right")
	var spd := SPEED * (ATTACK_MOVE_FACTOR if is_attacking else 1.0)
	if dir != 0.0:
		velocity.x = dir * spd
		if not is_attacking:   # não vira de lado no meio do golpe
			_facing = signf(dir)
			attack_area.scale.x = _facing
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)


func _handle_jump() -> void:
	if Input.is_action_just_pressed("ui_accept"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
		elif is_on_wall_only():
			velocity.y = JUMP_VELOCITY
			velocity.x = -Input.get_axis("ui_left", "ui_right") * SPEED * 1.5


func _handle_wall_grab() -> void:
	if is_on_wall_only() and Input.is_action_pressed("grab"):
		is_grabbing = true
		velocity.y = Input.get_axis("ui_up", "ui_down") * WALL_CLIMB_SPEED
	else:
		is_grabbing = false
		if is_on_wall_only() and velocity.y > 0:
			velocity.y = min(velocity.y, WALL_SLIDE_SPEED)


## True quando o player está com i-frames (atualmente: durante o dash).
## Os bosses/perigos checam isto pra saber se o golpe deve ser ignorado.
func is_invincible() -> bool:
	return is_dashing


func _handle_dash() -> void:
	if Input.is_action_just_pressed("dash") and can_dash and not is_dashing:
		_dash()


func _dash() -> void:
	is_dashing = true
	can_dash = false
	is_attacking = false
	attack_shape.disabled = true
	velocity = Vector2(_facing * DASH_SPEED, 0.0)
	await get_tree().create_timer(DASH_TIME).timeout
	is_dashing = false
	await get_tree().create_timer(DASH_COOLDOWN).timeout
	can_dash = true


func _handle_attacks() -> void:
	var want_heavy := Input.is_action_just_pressed("heavy")
	var want_attack := Input.is_action_just_pressed("attack")
	if is_attacking or is_dashing:
		# Pressionou no meio do golpe -> enfileira pro próximo (combo fluido).
		if want_heavy:   _buffer = "heavy";  _buffer_t = BUFFER_TIME
		elif want_attack: _buffer = "attack"; _buffer_t = BUFFER_TIME
		return
	if want_heavy:
		_do_heavy()
	elif want_attack:
		_do_combo()
	elif _buffer != "":   # consome o golpe enfileirado assim que o anterior acaba
		var b := _buffer
		_buffer = ""
		if b == "heavy": _do_heavy()
		else: _do_combo()


func _do_combo() -> void:
	is_attacking = true
	combo_timer = COMBO_WINDOW
	combo_step = (combo_step % 3) + 1
	var idx := combo_step - 1
	_cur_dmg     = COMBO_DMG[idx]
	_cur_stagger = COMBO_STAGGER[idx]
	_attack_anim = "attack" + str(combo_step)   # attack1 / attack2 / attack3
	_attack_started = true
	# Rápido e responsivo: quase sem windup, recuperação curta.
	await _swing(0.0, 0.11, 0.06, Color(0.7, 0.9, 1.0))


func _do_heavy() -> void:
	is_attacking = true
	combo_step = 0
	_cur_dmg     = HEAVY_DMG
	_cur_stagger = HEAVY_STAGGER
	_attack_anim = "heavy"
	_attack_started = true
	# Windup que telegrafa -> golpe forte de stagger (mais lento de propósito).
	_flash_visual(Color(1.0, 0.85, 0.3))
	await _swing(0.26, 0.14, 0.12, Color(1.0, 0.6, 0.1))


# windup -> ativo (hitbox ligada) -> recover
func _swing(windup: float, active: float, recover: float, _c: Color) -> void:
	_hit_targets.clear()
	await get_tree().create_timer(windup).timeout
	if not is_attacking: return   # cancelado por dash
	attack_shape.disabled = false
	await get_tree().create_timer(active).timeout
	attack_shape.disabled = true
	await get_tree().create_timer(recover).timeout
	is_attacking = false


func _handle_parry() -> void:
	if Input.is_action_just_pressed("counter") and not is_parrying and not is_attacking and not is_dashing:
		_do_parry()


func _do_parry() -> void:
	is_parrying = true
	EventBus.player_counter_pressed.emit()   # bosses checam isto na janela deles
	_flash_visual(Color(0.5, 0.85, 1.0))
	await get_tree().create_timer(PARRY_WINDOW).timeout
	is_parrying = false


# --- aplicação de dano nos bosses ---
func _apply_to_boss(target: Node) -> void:
	if target in _hit_targets:
		return
	_hit_targets.append(target)
	if target.has_method("take_damage"):
		target.take_damage(_cur_dmg)
	if target.has_method("add_stagger"):
		target.add_stagger(_cur_stagger)
	# Game feel: combos NÃO congelam o tempo (mantém o fluxo, sem travadinha a cada
	# golpe). Só o Heavy dá um hit-stop curtinho pra dar peso ao impacto.
	var is_heavy : bool = _cur_dmg >= HEAVY_DMG
	if is_heavy:
		GameFeel.hit_stop(0.05)
	GameFeel.shake_camera(5.0 if is_heavy else 2.5, 0.18)
	GameFeel.spawn_damage_number(target.global_position, _cur_dmg,
		Color(1.0, 0.85, 0.3) if is_heavy else Color(1.0, 0.95, 0.7))


func _on_hit_body(body: Node) -> void:
	if body.is_in_group("boss"):
		_apply_to_boss(body)


func _on_hit_area(area: Area2D) -> void:
	# Hurtbox dedicada do boss (Area2D chamada "Hurtbox").
	if area.name == "Hurtbox":
		var boss := area.get_parent()
		if boss and boss.is_in_group("boss"):
			_apply_to_boss(boss)


# --- dano recebido ---
func take_damage(amount: float) -> void:
	if is_dashing:
		return   # i-frame do dash
	if is_parrying:
		EventBus.player_parried.emit()
		_flash_visual(Color(0.6, 1.0, 1.0))
		# Game feel: PARRY = freeze maior + shake médio + texto "PARRY".
		GameFeel.hit_stop(0.14, 0.05)
		GameFeel.shake_camera(6.0, 0.25)
		GameFeel.spawn_damage_number(global_position, 0, Color(0.5, 0.9, 1.0), "PARRY!")
		return   # parry anula o golpe
	current_health = max(0.0, current_health - amount)
	EventBus.player_health_updated.emit(current_health)
	EventBus.player_hurt.emit()
	_hurt_t = 0.25
	_flash_visual(Color(1.0, 0.3, 0.3))
	GameFeel.shake_camera(3.5, 0.20)
	if current_health <= 0.0:
		_die()


func _die() -> void:
	EventBus.player_died.emit()
	set_physics_process(false)
	# Visual pode ser ColorRect (placeholder, usa .color) ou AnimatedSprite2D (.modulate).
	if visual is ColorRect:
		visual.color = Color(0.3, 0.3, 0.3)
	else:
		visual.modulate = Color(0.3, 0.3, 0.3)


# --- VISUAL ---
# Se "Visual" for um AnimatedSprite2D -> troca de animação automática por estado.
# Se for o ColorRect placeholder -> só muda a cor. Os dois funcionam.
func _update_visual() -> void:
	if visual is AnimatedSprite2D:
		_drive_sprite()
	elif visual is ColorRect:
		_tint_placeholder()


# Driver de animação: escolhe a anim por prioridade de estado e toca no sprite.
# Crie no SpriteFrames as animações: idle, walking, jump, fall, dash, grab,
# attack1, attack2, attack3, heavy, parry, hurt (faltou? ele só ignora).
func _drive_sprite() -> void:
	var spr := visual as AnimatedSprite2D
	spr.flip_h = _facing < 0.0
	var anim := _pick_anim()
	if spr.sprite_frames == null or not spr.sprite_frames.has_animation(anim):
		return
	if _attack_started and is_attacking:
		_attack_started = false
		spr.play(anim)            # reinicia a anim no início do golpe
	elif spr.animation != anim:
		spr.play(anim)


func _pick_anim() -> String:
	if _hurt_t > 0.0:    return "hurt"
	if is_dashing:       return "dash"
	if is_parrying:      return "parry"
	if is_attacking:     return _attack_anim
	if is_grabbing:      return "grab"
	if not is_on_floor():
		return "jump" if velocity.y < 0.0 else "fall"
	if absf(velocity.x) > 5.0:
		return "walking"
	return "idle"


func _tint_placeholder() -> void:
	if _hurt_t > 0.0:
		visual.color = Color(1.0, 0.3, 0.3)
	elif is_dashing:
		visual.color = Color(0.4, 0.9, 1.0)
	elif is_parrying:
		visual.color = Color(0.5, 0.85, 1.0)
	elif is_attacking:
		visual.color = Color(1.0, 0.95, 0.7)
	else:
		visual.color = Color(0.85, 0.9, 1.0)


func _flash_visual(c: Color) -> void:
	if visual is ColorRect:
		visual.color = c

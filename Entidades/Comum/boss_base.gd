# boss_base.gd
# ============================================================================
# BossBase — MOTOR reutilizável de boss (toda a "encanação" fica aqui).
# Cada boss herda esta classe e implementa SÓ a coreografia em fight().
#
# O que a base já entrega:
#   • Vida em barras + barra de stagger (sinais p/ a HUD via EventBus).
#   • Quebra de stagger -> atordoamento (janela de dano dobrado).
#   • Sistema de "formas" (placeholder cubo trocável por AnimatedSprite2D).
#   • Hurtbox automática (o player acerta aqui) e camadas de colisão prontas.
#   • Helpers de coreografia: _sleep, _move_to, _await_counter, _spawn_hazard,
#     _spawn_projectile, _make_cube, _banner, _flash, etc.
#   • Morte e "wipe" (mata o player).
#
# >>> COMO TROCAR PLACEHOLDERS: veja COMO_USAR.md na raiz.
# ============================================================================
class_name BossBase
extends CharacterBody2D

# --- IDENTIDADE ---
@export_group("Identidade")
@export var boss_name : String = "Boss"
@export var body_size : Vector2 = Vector2(44, 44)
## Frase de efeito mostrada na intro cinematográfica ("Sussurra os segredos do gelo...").
@export_multiline var epithet : String = ""
## Cor do retrato na intro (deixe Color.WHITE pra usar a cor do corpo).
@export var portrait_color : Color = Color.WHITE

# --- ARENA ---
@export_group("Arena")
@export var arena_left  : float = 16.0
@export var arena_right : float = 464.0
@export var arena_top   : float = 16.0
@export var arena_floor : float = 252.0
@export var hover_height : float = 40.0     ## altura em que o boss flutua
@export var move_speed   : float = 260.0

# --- VIDA / STAGGER ---
@export_group("Vida e Stagger")
@export var max_hp      : float = 40_000.0
@export var hp_per_bar  : float = 1_000.0
@export var max_stagger : float = 5_000.0
@export var stagger_decay : float = 250.0
@export var stagger_stun_time : float = 4.0
@export var stagger_stun_dmg_mult : float = 2.0
## Quebra de postura corta o ataque em andamento (responsivo, estilo Lost Ark).
## Desligue pra voltar ao comportamento antigo (só quebra entre ataques).
@export var stagger_interrupts_attacks : bool = true

@export_group("Ritmo Global (multiplicadores)")
@export var hp_mult : float = 5.0                  # escala a VIDA total (botão de duração da luta)
@export var telegraph_mult : float = 1.0          # escala o aviso (telegrafo)
@export var active_mult : float = 1.0             # escala o tempo de dano
@export var projectile_speed_mult : float = 1.0   # escala a velocidade dos projéteis
@export var recovery_mult : float = 1.25          # escala as pausas entre ataques (menos corrido)

# Janela de "preparação": durante mecânicas/troca de fase o boss recebe MENOS dano,
# pra o player ter tempo de ler e se posicionar (estilo Lost Ark). Disparada
# automaticamente por _announce / _phase_card / _gate_card / _wipe_card.
@export_group("Proteção em Mecânicas")
@export var mechanic_guard_mult : float = 0.5     # multiplicador de dano recebido enquanto a proteção está ativa
@export var mechanic_guard_time : float = 3.0     # duração (s) da proteção ao anunciar mecânica/fase

# --- ESTADO ---
enum State { INTRO, FIGHT, STAGGERED, DEAD }
var state : State = State.INTRO
var current_hp : float = 0.0
var stagger    : float = 0.0
var is_immune  : bool  = false

var _counter_flag := false
var _stun_pending := false
var _flashing     := false
var _guard_t      := 0.0     # tempo restante da proteção de mecânica/fase
var _stagger_immune := false # mecânica imune a stagger: barra não enche nem quebra

# --- FORMAS (placeholder cubo trocável por AnimatedSprite2D) ---
# Adicione filhos AnimatedSprite2D; eles são registrados pelo NOME do nó.
# _set_body("<nome>", cor) mostra a forma certa ou cai no cubo placeholder.
var _forms        : Dictionary = {}
var _cur_form     : Node = null
var _cur_form_key : String = ""
var _cur_cube_color : Color = Color.WHITE
var _body_cube : ColorRect = null
var _hurtbox   : Area2D = null
var _player    : CharacterBody2D = null

const HAZARD     := preload("res://Entidades/Comum/hazard.gd")
const PROJECTILE := preload("res://Entidades/Comum/projectile.gd")
const WIPE_DAMAGE := 1.0e9


# =============================================================================
# INIT
# =============================================================================
func _ready() -> void:
	max_hp *= hp_mult   # escala a vida total (duração da luta) antes de tudo usar max_hp
	add_to_group("boss")
	# Camadas: 1=player, 2=arena, 3=boss(4), 4=hurtbox(8).
	collision_layer = 4
	collision_mask  = 2

	# Registra formas (qualquer AnimatedSprite2D filho) e esconde todas.
	for c in get_children():
		if c is AnimatedSprite2D:
			_forms[c.name] = c
			c.visible = false

	# Cubo placeholder do corpo.
	_body_cube = ColorRect.new()
	_body_cube.size = body_size
	_body_cube.position = -body_size * 0.5
	add_child(_body_cube)
	_body_cube.visible = false

	# Hurtbox automática (o player acerta aqui).
	_hurtbox = Area2D.new()
	_hurtbox.name = "Hurtbox"
	_hurtbox.collision_layer = 8
	_hurtbox.collision_mask  = 0
	var hs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = body_size
	hs.shape = rect
	_hurtbox.add_child(hs)
	add_child(_hurtbox)

	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		push_warning("[%s] Player não encontrado no grupo 'player'!" % boss_name)

	current_hp = max_hp
	# Deferido: garante que as HUDs já conectaram aos sinais antes do valor chegar.
	EventBus.boss_intro.emit.call_deferred(boss_name)
	EventBus.boss_max_health_set.emit.call_deferred(max_hp, hp_per_bar)
	EventBus.boss_stagger_updated.emit.call_deferred(0.0, max_stagger)

	if EventBus.has_signal("player_counter_pressed"):
		EventBus.player_counter_pressed.connect(func(): _counter_flag = true)

	global_position = _idle_pos()
	_set_body(_cur_form_key, Color(0.6, 0.2, 0.2))

	_run()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if _guard_t > 0.0:
		_guard_t = max(0.0, _guard_t - delta)
	if state == State.FIGHT and not is_immune and stagger > 0.0:
		stagger = max(0.0, stagger - stagger_decay * delta)
		EventBus.boss_stagger_updated.emit(stagger, max_stagger)


func _run() -> void:
	# Intro cinematográfica: tela escurece + nome + epíteto.
	var col := portrait_color if portrait_color != Color.WHITE else _cur_cube_color
	EventBus.boss_intro_cine.emit(boss_name, epithet, col)
	await _sleep(2.6)   # tempo da cinemática (fade in + segura + fade out)
	state = State.FIGHT
	await fight()
	# fight() só retorna naturalmente se o boss ainda estiver vivo sem ter morrido
	# (a maioria chama _die internamente). Garantia:
	if _alive() and current_hp <= 0.0:
		_die()


## Sobrescreva em cada boss. É a coreografia completa da luta.
func fight() -> void:
	push_warning("[%s] fight() não implementado." % boss_name)


# =============================================================================
# DANO / STAGGER / MORTE
# =============================================================================
func take_damage(amount: float) -> void:
	if state == State.DEAD:
		return
	var amt := amount
	if state == State.STAGGERED:
		amt *= stagger_stun_dmg_mult   # janela de stagger continua sendo o burst de DPS
	elif _guard_t > 0.0:
		amt *= mechanic_guard_mult     # proteção durante mecânica/troca de fase
	if not is_immune:
		current_hp = max(0.0, current_hp - amt)
		EventBus.boss_health_updated.emit(current_hp)
		EventBus.boss_hit.emit()
		_flash(Color(1.0, 0.5, 0.5))
		if current_hp <= 0.0 and state != State.DEAD:
			_die()


func add_stagger(amount: float) -> void:
	if state == State.DEAD or state == State.STAGGERED:
		return
	if _stagger_immune:
		return   # mecânica imune: postura não acumula nem quebra
	stagger = min(max_stagger, stagger + amount)
	EventBus.boss_stagger_updated.emit(stagger, max_stagger)
	if stagger >= max_stagger and not is_immune and state == State.FIGHT:
		_stun_pending = true


func _reset_stagger() -> void:
	stagger = 0.0
	EventBus.boss_stagger_updated.emit(0.0, max_stagger)


# PORTÃO DE STAGGER (à la Silvanna): por `time` s o boss fica imune a HP; encha a
# barra de stagger pra PASSAR. Falhar = wipe (se fail_wipe). `on_tick` (opcional)
# roda todo frame com o delta — use pra cuspir perigos/sucção durante o portão.
func _stagger_gate(time: float, on_tick: Callable = Callable(), fail_wipe := true) -> bool:
	is_immune = true
	_reset_stagger()
	var dt := get_physics_process_delta_time()
	var t := 0.0
	var ok := false
	while _alive() and t < time:
		t += dt
		if on_tick.is_valid():
			on_tick.call(dt)
		if stagger >= max_stagger:
			ok = true
			break
		await get_tree().physics_frame
	_reset_stagger()
	is_immune = false
	if not ok and fail_wipe and _alive():
		_wipe()
	return ok


# Pausa entre ataques + checa quebra de stagger.
func _after_attack(t: float) -> void:
	_play_anim("idle")
	await _check_stun()
	await _sleep(t * recovery_mult)


func _check_stun() -> void:
	if _stun_pending and not _stagger_immune and _alive():
		await _do_stun()


func _do_stun() -> void:
	_stun_pending = false
	state = State.STAGGERED
	EventBus.boss_staggered.emit()
	# Game feel: quebra de postura = freeze grande + shake forte + texto.
	GameFeel.hit_stop(0.18, 0.03)
	GameFeel.shake_camera(9.0, 0.35)
	GameFeel.spawn_damage_number(global_position, 0, Color(1.0, 0.9, 0.3), "STAGGER!")
	_play_anim("staggered")
	_set_color(Color(1.0, 1.0, 0.2))   # amarelo = atordoado
	var dt := get_physics_process_delta_time()
	var t := 0.0
	while _alive() and state == State.STAGGERED and t < stagger_stun_time:
		t += dt
		await get_tree().physics_frame
	if state == State.STAGGERED:
		state = State.FIGHT
	_reset_stagger()
	_restore_body_color()
	_play_anim("idle")


func _die() -> void:
	state = State.DEAD
	current_hp = 0.0
	EventBus.boss_health_updated.emit(0.0)
	EventBus.boss_died.emit()
	# Game feel: morte = freeze longo + shake épico.
	GameFeel.hit_stop(0.30, 0.02)
	GameFeel.shake_camera(11.0, 0.6)
	_set_color(Color(0.2, 0.2, 0.2))
	await _sleep(1.0)
	queue_free()


func _wipe() -> void:
	if _player and is_instance_valid(_player):
		_player.take_damage(WIPE_DAMAGE)


func _parry_feedback() -> void:
	_flash(Color(0.5, 0.85, 1.0))


func _flash(c: Color) -> void:
	if _flashing:
		return
	_flashing = true
	_set_color(c)
	# Timer direto (não o _sleep interrompível): é só um flash visual de dano.
	await get_tree().create_timer(0.08).timeout
	_restore_body_color()
	_flashing = false


# =============================================================================
# HELPERS DE COREOGRAFIA
# =============================================================================
func _alive() -> bool:
	return state != State.DEAD and is_inside_tree()


func _sleep(t: float) -> void:
	# Fora da luta (intro/morte) ou com o recurso desligado: espera normal.
	if not stagger_interrupts_attacks or state != State.FIGHT:
		await get_tree().create_timer(t).timeout
		return
	# Na luta: a espera "acorda" cedo se a postura quebrar (corta o ataque atual),
	# exceto numa mecânica imune a stagger.
	var dt := get_physics_process_delta_time()
	var elapsed := 0.0
	while elapsed < t:
		if state != State.FIGHT:
			return
		if _stun_pending and not _stagger_immune and not is_immune:
			await _do_stun()
			return
		elapsed += dt
		await get_tree().physics_frame


# Liga/desliga a IMUNIDADE A STAGGER (mecânicas que não podem ser interrompidas).
# Enquanto ligada, a barra de postura não enche nem quebra. As janelas de parry
# (_await_counter) já ligam isso sozinhas; os portões usam `is_immune`.
func _set_stagger_immune(on: bool) -> void:
	_stagger_immune = on


func _move_to(target: Vector2, speed: float) -> void:
	var dt := get_physics_process_delta_time()
	while _alive() and global_position.distance_to(target) > 2.0:
		global_position = global_position.move_toward(target, speed * dt)
		await get_tree().physics_frame


# Espera o player apertar Parry dentro de `window`. `valid` (opcional) decide se
# o parry conta (ex.: player no lado certo). Retorna true se parry válido.
func _await_counter(window: float, valid: Callable = Callable()) -> bool:
	# Mecânica de parry/counter é IMUNE a stagger: não dá pra "pular" com a quebra.
	_set_stagger_immune(true)
	_counter_flag = false
	var dt := get_physics_process_delta_time()
	var t := 0.0
	var ok := false
	while _alive() and t < window:
		if _counter_flag:
			_counter_flag = false
			if not valid.is_valid() or valid.call():
				ok = true
				break
		t += dt
		await get_tree().physics_frame
	_set_stagger_immune(false)
	return ok


# Cria um perigo (telegrafo -> ativo -> some). `skin` opcional troca o cubo.
func _spawn_hazard(pos: Vector2, size: Vector2, color: Color, damage: float,
		telegraph: float, active: float, tick: float = 0.0,
		respect_dash: bool = true, instakill: bool = false, skin: PackedScene = null) -> Node:
	var h = HAZARD.new()
	h.setup(size, color, damage, telegraph * telegraph_mult, active * active_mult, tick, respect_dash, instakill, skin)
	get_parent().add_child(h)
	h.global_position = pos
	return h


# AoE CIRCULAR (telegrafo de raid). Avisa, depois dá dano em quem está DENTRO.
func _spawn_circle(pos: Vector2, radius: float, color: Color, damage: float,
		telegraph: float, active: float, respect_dash: bool = true,
		instakill: bool = false, skin: PackedScene = null) -> Node:
	var h = HAZARD.new()
	h.setup(Vector2(radius * 2.0, radius * 2.0), color, damage, telegraph * telegraph_mult, active * active_mult,
		0.0, respect_dash, instakill, skin, 1, false)
	get_parent().add_child(h)
	h.global_position = pos
	return h


# ZONA SEGURA: dá dano em quem está FORA do círculo (fique dentro!).
# respect_dash=false por padrão: não dá pra burlar uma mecânica de posição com dash.
func _spawn_safezone(center: Vector2, safe_radius: float, color: Color, damage: float,
		telegraph: float, active: float) -> Node:
	var h = HAZARD.new()
	h.setup(Vector2(safe_radius * 2.0, safe_radius * 2.0), color, damage, telegraph * telegraph_mult,
		active * active_mult, 0.0, false, false, null, 1, true)
	get_parent().add_child(h)
	h.global_position = center
	return h


# Cria um projétil. mode: PROJECTILE.Mode.STRAIGHT/HOMING/BOUNCE.
func _spawn_projectile(mode: int, pos: Vector2, dir: Vector2, speed: float,
		damage: float, counterable: bool = false, skin: PackedScene = null,
		size: Vector2 = Vector2(12, 6), color: Color = Color(0.95, 0.9, 0.5)) -> Node:
	var p = PROJECTILE.new()
	p.setup(mode, dir, speed * projectile_speed_mult, damage, _arena_rect(), counterable, skin, size, color)
	get_parent().add_child(p)
	p.global_position = pos
	return p


# Cubo visual avulso (clones, ícones, pistas, colunas). Some no queue_free.
# `skin` (PackedScene) opcional troca o cubo pela sua arte (centralizada em 0,0).
func _make_cube(pos: Vector2, size: Vector2, color: Color, skin: PackedScene = null) -> Node2D:
	var root := Node2D.new()
	if skin:
		root.add_child(skin.instantiate())
	else:
		var rect := ColorRect.new()
		rect.size = size
		rect.position = -size * 0.5
		rect.color = color
		root.add_child(rect)
	get_parent().add_child(root)
	root.global_position = pos
	return root


func _arena_center() -> Vector2:
	return Vector2((arena_left + arena_right) * 0.5, (arena_top + arena_floor) * 0.5)


func _arena_rect() -> Rect2:
	return Rect2(arena_left, arena_top, arena_right - arena_left, arena_floor - arena_top)


func _idle_pos() -> Vector2:
	return Vector2((arena_left + arena_right) * 0.5, arena_floor - hover_height)


func _player_x() -> float:
	if _player and is_instance_valid(_player):
		return clampf(_player.global_position.x, arena_left, arena_right)
	return _arena_center().x


func _player_alive() -> bool:
	return _player != null and is_instance_valid(_player)


func _player_invincible() -> bool:
	return _player_alive() and _player.is_invincible()


# --- formas / cor ---
func _set_body(form: String, color: Color) -> void:
	_cur_form_key = form
	_cur_cube_color = color
	for k in _forms:
		if _forms[k]:
			_forms[k].visible = false
	if _body_cube:
		_body_cube.visible = false

	_cur_form = _forms.get(form)
	if _cur_form:
		_cur_form.visible = true
		if _cur_form is CanvasItem:
			_cur_form.modulate = Color.WHITE
		_play_anim("idle")
	elif _body_cube:
		_body_cube.visible = true
		_body_cube.color = color


func _set_color(c: Color) -> void:
	if _cur_form and _cur_form.visible and _cur_form is CanvasItem:
		_cur_form.modulate = c
	elif _body_cube and _body_cube.visible:
		_body_cube.color = c


func _restore_body_color() -> void:
	if _cur_form and _cur_form.visible and _cur_form is CanvasItem:
		_cur_form.modulate = Color.WHITE
	elif _body_cube and _body_cube.visible:
		_body_cube.color = _cur_cube_color


func _play_anim(anim_name: String) -> void:
	if _cur_form is AnimatedSprite2D:
		var sf : SpriteFrames = _cur_form.sprite_frames
		if sf and sf.has_animation(anim_name):
			_cur_form.play(anim_name)


# Liga a "proteção de mecânica": por `t` s o boss recebe dano reduzido
# (mechanic_guard_mult). Use t<0 para a duração padrão (mechanic_guard_time).
func _begin_mechanic_guard(t: float = -1.0) -> void:
	var dur := t if t > 0.0 else mechanic_guard_time
	_guard_t = maxf(_guard_t, dur)


func _banner(text: String) -> void:
	print("[%s] >>> %s" % [boss_name, text])
	EventBus.boss_banner.emit(text)


# Card cinematográfico de MECÂNICA (branco/cor). Texto curto, ação clara.
func _announce(text: String, color: Color = Color(1, 1, 1)) -> void:
	print("[%s] >>> %s" % [boss_name, text])
	EventBus.mechanic_announce.emit(text, "mech", color)
	_begin_mechanic_guard()


# Card de MUDANÇA DE FASE (azul claro por padrão).
func _phase_card(text: String, color: Color = Color(0.55, 0.85, 1.0)) -> void:
	print("[%s] >>> %s" % [boss_name, text])
	EventBus.boss_banner.emit(text)
	EventBus.mechanic_announce.emit(text, "phase", color)
	_begin_mechanic_guard()


# Card de PORTÃO de stagger (dourado).
func _gate_card(text: String) -> void:
	print("[%s] >>> %s" % [boss_name, text])
	EventBus.boss_banner.emit(text)
	EventBus.mechanic_announce.emit(text, "gate", Color(1.0, 0.85, 0.3))
	_begin_mechanic_guard()


# Card de WIPE / parry obrigatório (vermelho).
func _wipe_card(text: String) -> void:
	print("[%s] >>> %s" % [boss_name, text])
	EventBus.boss_banner.emit(text)
	EventBus.mechanic_announce.emit(text, "wipe", Color(1.0, 0.3, 0.3))
	_begin_mechanic_guard()

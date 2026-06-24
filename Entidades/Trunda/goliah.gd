# goliah.gd  —  RAID 1 (Trunda), GATE 2: Goliah, o Guardião
# ============================================================================
# Golem de gelo gigante invocado por uma bruxa. Lento, pesado, com 3 ataques
# padrão e 3 mecânicas narrativas:
#   ATAQUES:
#     • Soco de Estilhaços — soca o chão e dispara 7 rajadas em leque pra frente.
#     • Arremesso de Rocha — animação longa com janela de COUNTER (cancela
#       a invocação); falhar = projétil ENORME no player. Cooldown alto.
#     • Hélice de Estilhaços — 2 machados gigantes saem dos braços girando e
#       voltando (boomerang à la Draven), atravessando a arena ida-e-volta.
#
#   MEC 1 — HIPOTERMIA: vai pro centro, escudo (stagger gate), está carregando
#       wipe. A cada X seg pisca e tenta soltar rajada radial; COUNTER cancela
#       e mantém a janela; falhar = empurra/atordoa o player (perdeu tempo).
#       Falha do gate = wipe.
#   MEC 2 — SOPRO CONGELANTE: pula pro "background" (visual encolhe + z-index),
#       estilhaços do teto caem em volta de UMA safezone (revela ela), depois
#       o sopro toma a tela: 17s de DoT em quem não estiver na safezone.
#   MEC 3 — MÃOS DE GELO (FASE DESESPERADA): boss quebra; spawnam 2 luvas
#       gigantes (esquerda/direita) que se aproximam pra esmagar. Uma luva
#       brilha periodicamente — COUNTER nela = trava + janela de stagger pra
#       quebrá-la e empurrar de volta. Alternam. Encontrar = wipe.
#
# Tudo exportado pelo Inspetor pra balancear.
# ============================================================================
extends BossBase

# --- LIMIARES DE FASE (% do HP máx) ---
@export_group("Goliah: Limiares (% HP)")
@export var th_hipotermia_pct : float = 0.70   ## dispara Mecânica 1
@export var th_sopro_pct      : float = 0.40   ## dispara Mecânica 2
@export var th_maos_pct       : float = 0.15   ## dispara Mecânica 3 (desespero)

@export_group("Goliah: Ritmo")
@export var pause            : float = 1.3   ## golem é pesado, pausas maiores
@export var pause_aggressive : float = 1.0


# --- ATAQUE 1: Soco de Estilhaços ---
@export_group("Goliah: Soco de Estilhaços")
@export var soco_shard_count    : int   = 7
@export var soco_shard_damage   : float = 1_200.0
@export var soco_shard_speed    : float = 280.0
@export var soco_spread_deg     : float = 70.0   ## abertura total do leque
@export var soco_telegraph      : float = 0.6
@export var soco_recover        : float = 0.7


# --- ATAQUE 2: Arremesso de Rocha (counter-or-die) ---
@export_group("Goliah: Arremesso de Rocha")
@export var rocha_cooldown        : float = 16.0
@export var rocha_invoke_time     : float = 1.6   ## animação longa (arranca)
@export var rocha_counter_window  : float = 0.55
@export var rocha_damage          : float = 4_200.0
@export var rocha_speed           : float = 220.0
@export var rocha_recover         : float = 1.0


# --- ATAQUE 3: Hélice de Estilhaços (Draven) ---
@export_group("Goliah: Hélice de Estilhaços")
@export var helice_damage      : float = 1_800.0
@export var helice_speed       : float = 240.0
@export var helice_out_time    : float = 1.3   ## quanto vai antes de voltar
@export var helice_recover     : float = 0.7


# --- MEC 1: Hipotermia ---
@export_group("Goliah: Hipotermia")
@export var hipo_max_stagger     : float = 12_000.0
@export var hipo_time_limit      : float = 30.0
@export var hipo_burst_interval_min : float = 3.0
@export var hipo_burst_interval_max : float = 4.5
@export var hipo_burst_telegraph : float = 0.55   ## tempo piscando antes da rajada
@export var hipo_burst_window    : float = 0.55   ## janela de counter
@export var hipo_burst_damage    : float = 2_200.0  ## se falhar o counter
@export var hipo_burst_radius    : float = 70.0
@export var hipo_burst_push      : float = 110.0   ## empurra o player longe
@export var hipo_stun_time       : float = 1.6     ## "estuna" o player (perde controle)


# --- MEC 2: Sopro Congelante ---
@export_group("Goliah: Sopro Congelante")
@export var sopro_setup_time     : float = 2.5   ## tempo dos estilhaços caindo / revelação
@export var sopro_shard_damage   : float = 1_000.0
@export var sopro_shard_interval : float = 0.18
@export var sopro_shard_telegraph : float = 0.5
@export var sopro_shard_active   : float = 0.3
@export var sopro_safezone_radius : float = 38.0
@export var sopro_duration       : float = 17.0
@export var sopro_dot_damage     : float = 900.0   ## dano POR TICK fora da safezone
@export var sopro_dot_interval   : float = 0.5    ## intervalo do tick


# --- MEC 3: Mãos de Gelo (desespero) ---
@export_group("Goliah: Mãos de Gelo")
@export var maos_hand_width       : float = 50.0
@export var maos_hand_height      : float = 90.0
@export var maos_close_speed      : float = 6.0   ## px/s — bem lento, pra dar tempo
@export var maos_min_distance     : float = 60.0  ## abaixo disso esmaga (wipe)
@export var maos_hand_max_hp      : float = 3_500.0   ## "vida" de cada luva pra empurrar
@export var maos_glow_interval_min : float = 3.0
@export var maos_glow_interval_max : float = 5.0
@export var maos_counter_window   : float = 0.65
@export var maos_stagger_window   : float = 4.0    ## tempo pra quebrar a luva
@export var maos_push_back        : float = 80.0   ## quanto empurra a luva pra trás
@export var maos_max_cycles       : int   = 4      ## quantas vezes alternar até vencer


# --- SKINS (opcional) ---
@export_group("Goliah: Skins (opcional)")
@export var skin_estilhaco : PackedScene
@export var skin_rocha     : PackedScene
@export var skin_helice    : PackedScene
@export var skin_safezone  : PackedScene
@export var skin_sopro     : PackedScene
@export var skin_mao       : PackedScene


# === ESTADO ============================================================
var _rocha_cd  : float = 0.0
var _hipo_pushing : bool = false   # trava sub-counter da Hipotermia
var _hand_left   : Node2D = null
var _hand_right  : Node2D = null


func fight() -> void:
	_set_body("Corpo", Color(0.55, 0.7, 0.85))

	# ── FASE 1: ataques normais até Hipotermia ─────────────────────
	_phase_card("FASE 1 — O Guardião Desperta")
	await _phase_normal(th_hipotermia_pct, pause)
	if not _alive(): return

	# ── MEC 1: Hipotermia ─────────────────────────────────────────
	await _mech_hipotermia()
	if not _alive(): return

	# ── Fase 1.5 ──────────────────────────────────────────────────
	_phase_card("FASE 2 — Tempestade Crescente")
	await _phase_normal(th_sopro_pct, pause_aggressive)
	if not _alive(): return

	# ── MEC 2: Sopro Congelante ───────────────────────────────────
	await _mech_sopro_congelante()
	if not _alive(): return

	# ── Fase 1.75 ─────────────────────────────────────────────────
	await _phase_normal(th_maos_pct, pause_aggressive)
	if not _alive(): return

	# ── MEC 3: Mãos de Gelo (desespero) ───────────────────────────
	await _mech_maos_de_gelo()
	if not _alive(): return

	_die()


# ============================================================================
# FASE NORMAL — rota de ataques padrão.
# ============================================================================
func _phase_normal(threshold_pct: float, p: float) -> void:
	var i := 0
	while _alive() and current_hp > max_hp * threshold_pct:
		if _rocha_cd <= 0.0 and randf() < 0.35:
			await _atk_arremesso_rocha()
		else:
			match i % 2:
				0: await _atk_soco_estilhacos()
				1: await _atk_helice_estilhacos()
		i += 1
		_rocha_cd = max(0.0, _rocha_cd - p - 0.5)
		await _after_attack(p)


# ============================================================================
# ATAQUE 1 — Soco de Estilhaços (7 rajadas em leque pra frente).
# ============================================================================
func _atk_soco_estilhacos() -> void:
	# Vira pra direção do player (define "frente").
	await _move_to(_idle_pos(), move_speed)
	if not _alive(): return
	_set_color(Color(0.85, 0.95, 1.0))
	await _sleep(soco_telegraph)
	if not _alive(): return
	_restore_body_color()
	_play_anim("slam")

	var origin := _muzzle_pos()
	var base := (_player.global_position - origin).angle() if _player_alive() else 0.0
	var spread_rad := deg_to_rad(soco_spread_deg)
	for k in soco_shard_count:
		var frac : float = float(k) / float(soco_shard_count - 1) - 0.5   # -0.5 .. +0.5
		var ang := base + spread_rad * frac
		_spawn_projectile(PROJECTILE.Mode.STRAIGHT, origin,
			Vector2.RIGHT.rotated(ang), soco_shard_speed, soco_shard_damage,
			false, skin_estilhaco, Vector2(14, 10), Color(0.7, 0.9, 1.0))
	await _sleep(soco_recover)


# ============================================================================
# ATAQUE 2 — Arremesso de Rocha (counter-or-die, cooldown alto).
# ============================================================================
func _atk_arremesso_rocha() -> void:
	_announce("ROCHA — defenda (Z) ou é fatal!", Color(0.7, 0.85, 1.0))
	_rocha_cd = rocha_cooldown
	await _move_to(_idle_pos(), move_speed)
	if not _alive(): return

	# Invocação longa (arranca a pedra do chão)
	_set_color(Color(0.6, 0.85, 1.0))
	_play_anim("cast")
	await _sleep(rocha_invoke_time * 0.7)
	if not _alive(): return

	# Janela de counter no ápice
	_set_color(Color(1.0, 1.0, 0.3))
	var ok : bool = await _await_counter(rocha_counter_window)
	_restore_body_color()
	if ok:
		_announce("Pedra estilhaçada!", Color(0.5, 1.0, 0.8))
		_parry_feedback()
		add_stagger(max_stagger * 0.35, true)
		await _sleep(0.7)
		return

	# Falhou: dispara a pedra ENORME na direção do player.
	if not _player_alive(): return
	var origin := _muzzle_pos()
	var dir := (_player.global_position - origin).normalized()
	_spawn_projectile(PROJECTILE.Mode.STRAIGHT, origin, dir, rocha_speed,
		rocha_damage, false, skin_rocha, Vector2(34, 34),
		Color(0.55, 0.75, 0.9))
	await _sleep(rocha_recover)


# ============================================================================
# ATAQUE 3 — Hélice de Estilhaços (machados ida-e-volta estilo Draven).
# ============================================================================
func _atk_helice_estilhacos() -> void:
	await _move_to(_idle_pos(), move_speed)
	if not _alive(): return
	_play_anim("attack")
	# Dois machados, em alturas levemente diferentes pra cobrir mais do espaço.
	var origin := _muzzle_pos()
	var dir_to_player : Vector2 = (_player.global_position - origin).normalized() \
		if _player_alive() else Vector2.RIGHT
	# Spawnar duas hélices com offset vertical.
	for s in [-1.0, 1.0]:
		var off := Vector2(0.0, s * 12.0)
		_spawn_boomerang_helice(origin + off, dir_to_player)
	await _sleep(helice_out_time * 2.0 + helice_recover)


# Cria uma hélice (Node2D customizado) que vai numa direção e volta.
func _spawn_boomerang_helice(from: Vector2, dir: Vector2) -> void:
	var h := IceAxe.new()
	h.setup(dir, helice_speed, helice_damage, helice_out_time, skin_helice)
	get_parent().add_child(h)
	h.global_position = from


# Sub-classe: machado boomerang. Vai → desacelera → volta na direção inversa
# até sair do alcance ou completar o ciclo.
class IceAxe extends Node2D:
	var _dir : Vector2 = Vector2.RIGHT
	var _speed : float = 240.0
	var _damage : float = 1_800.0
	var _out_time : float = 1.3
	var _t : float = 0.0
	var _state : int = 0   # 0 = indo, 1 = voltando
	var _player : Node2D = null
	var _hit_cd : float = 0.0

	func setup(p_dir: Vector2, p_speed: float, p_dmg: float, p_out: float, skin: PackedScene = null) -> void:
		_dir = p_dir.normalized()
		_speed = p_speed
		_damage = p_dmg
		_out_time = p_out
		if skin:
			add_child(skin.instantiate())
		else:
			var r := ColorRect.new()
			r.size = Vector2(20, 8)
			r.position = -Vector2(10, 4)
			r.color = Color(0.7, 0.9, 1.0)
			add_child(r)

	func _ready() -> void:
		_player = get_tree().get_first_node_in_group("player") as Node2D

	func _physics_process(delta: float) -> void:
		_hit_cd -= delta
		_t += delta
		# Rotaciona pra parecer girando
		rotation += TAU * 1.5 * delta
		# Trajetória: indo até _out_time, depois inverte (volta)
		if _state == 0 and _t >= _out_time:
			_state = 1
			_dir = -_dir
		global_position += _dir * _speed * delta
		# Dano ao tocar player
		if _player and is_instance_valid(_player) and _hit_cd <= 0.0:
			if global_position.distance_to(_player.global_position) < 18.0 \
					and not (_player.has_method("is_invincible") and _player.is_invincible()):
				_player.take_damage(_damage)
				_hit_cd = 0.6
		# Free depois de tempo dobrado (ida + volta)
		if _t > _out_time * 2.2:
			queue_free()


# ============================================================================
# MEC 1 — Hipotermia
# Gate de stagger custom: enquanto o player bate, o boss tenta soltar rajadas
# periódicas; counter cancela, falhar = empurra+atordoa o player.
# ============================================================================
func _mech_hipotermia() -> void:
	_gate_card("HIPOTERMIA — Quebre o escudo antes do wipe!")
	await _move_to(_arena_center(), move_speed)
	if not _alive(): return
	_set_body("Corpo", Color(0.5, 0.8, 1.0))

	# Boost temporário da barra
	var orig_max := max_stagger
	max_stagger = hipo_max_stagger
	EventBus.boss_stagger_updated.emit(0.0, max_stagger)

	var burst_cd : float = randf_range(hipo_burst_interval_min, hipo_burst_interval_max)
	_hipo_pushing = false
	var on_tick = func(dt: float) -> void:
		if _hipo_pushing:
			return
		burst_cd -= dt
		if burst_cd <= 0.0:
			burst_cd = randf_range(hipo_burst_interval_min, hipo_burst_interval_max)
			_hipo_pushing = true
			_run_hipo_burst()

	var ok : bool = await _stagger_gate(hipo_time_limit, on_tick, false)

	max_stagger = orig_max
	EventBus.boss_stagger_updated.emit(0.0, max_stagger)
	_restore_body_color()
	if not ok and _alive():
		_announce("Hipotermia — corpo cedeu.", Color(0.6, 0.7, 1.0))
		_wipe()


# Sub-rotina: piscada + counter window. Sucesso = nada acontece. Falha = rajada
# radial dá dano e empurra o player; também "estuna" temporariamente.
func _run_hipo_burst() -> void:
	# Telegrafo (piscada azul)
	_set_color(Color(0.4, 0.8, 1.0))
	await _sleep(hipo_burst_telegraph * 0.5)
	if not _alive() or not _stagger_mech_mode:
		_restore_body_color()
		_hipo_pushing = false
		return
	_set_color(Color(1.0, 1.0, 0.3))   # janela de counter
	var ok : bool = await _await_counter(hipo_burst_window)
	_restore_body_color()
	if not _alive() or not _stagger_mech_mode:
		_hipo_pushing = false
		return
	if ok:
		_parry_feedback()
		add_stagger(max_stagger * 0.05, true)   # pequena recompensa extra
	else:
		# Rajada radial: círculo grande de dano + empurra player + atordoa
		_spawn_circle(global_position, hipo_burst_radius, Color(0.55, 0.85, 1.0),
			hipo_burst_damage, 0.0, 0.25)
		if _player_alive() and not _player_invincible():
			var dir : Vector2 = (_player.global_position - global_position).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.RIGHT
			_player.global_position += dir * hipo_burst_push
			# Stun: trava i-frame off por um instante; sem hook próprio no player,
			# damos um "tick" de dano pra simular o atordoamento (perde tempo).
			_player.take_damage(hipo_burst_damage * 0.25)
			await _sleep(hipo_stun_time)
	_hipo_pushing = false


# ============================================================================
# MEC 2 — Sopro Congelante
# Boss "pula" pro background, estilhaços caem em volta de UMA safezone (que é
# revelada), e o sopro toma a tela: 17s de DoT fora da safezone.
# ============================================================================
func _mech_sopro_congelante() -> void:
	_announce("SOPRO CONGELANTE — encontre a safezone!", Color(0.6, 0.9, 1.0))
	is_immune = true
	# "Pula pro background": encolhe e empurra pra trás visualmente.
	await _move_to(Vector2(_arena_center().x, arena_top + 36.0), move_speed * 1.3)
	if not _alive(): return
	var orig_scale := scale
	var orig_z := z_index
	scale = orig_scale * 0.55
	z_index = -2
	modulate = Color(0.7, 0.85, 1.0, 0.6)

	# Sorteia a safezone
	var safe := Vector2(randf_range(arena_left + 70.0, arena_right - 70.0),
		randf_range(arena_floor - 80.0, arena_floor - 30.0))

	# Visual da safezone (cubo verde pulsante)
	var safe_marker := _make_cube(safe, Vector2(sopro_safezone_radius * 2.0, sopro_safezone_radius * 2.0),
		Color(0.3, 1.0, 0.45, 0.25), skin_safezone)

	# Estilhaços caindo em torno da safezone (visualmente "revelando" ela).
	var dt := get_physics_process_delta_time()
	var t := 0.0
	var shard_cd : float = 0.0
	while _alive() and t < sopro_setup_time:
		t += dt
		shard_cd -= dt
		if shard_cd <= 0.0:
			shard_cd = sopro_shard_interval
			# Spawna num X aleatório; pula se cair dentro da safezone
			var px := randf_range(arena_left + 16.0, arena_right - 16.0)
			var py := randf_range(arena_top + 30.0, arena_floor - 16.0)
			if Vector2(px, py).distance_to(safe) < sopro_safezone_radius + 8.0:
				continue
			_spawn_hazard(Vector2(px, py), Vector2(18, 18),
				Color(0.6, 0.85, 1.0), sopro_shard_damage,
				sopro_shard_telegraph, sopro_shard_active, 0.0,
				true, false, skin_estilhaco)
		await get_tree().physics_frame

	# SOPRO: 17s de DoT em quem está FORA da safezone.
	# `_spawn_safezone` não aceita tick — instanciamos HAZARD direto pra DoT.
	_announce("17s — fique na safezone!", Color(1.0, 0.9, 0.3))
	var sopro_haz : Node = HAZARD.new()
	sopro_haz.setup(Vector2(sopro_safezone_radius * 2.0, sopro_safezone_radius * 2.0),
		Color(0.6, 0.9, 1.0), sopro_dot_damage,
		0.3, sopro_duration, sopro_dot_interval,
		false, false, skin_sopro, 1, true)   # shape=1 círculo, inverse=true safezone
	get_parent().add_child(sopro_haz)
	sopro_haz.global_position = safe

	# Sopro visual full-screen (tela tinta de azul claro)
	var layer := CanvasLayer.new()
	layer.layer = 4
	var tint := ColorRect.new()
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.color = Color(0.6, 0.85, 1.0, 0.0)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(tint)
	get_parent().add_child(layer)

	t = 0.0
	while _alive() and t < sopro_duration:
		t += dt
		# Pulsa o tint pra leitura
		tint.color.a = 0.15 + 0.10 * (sin(t * 4.0) * 0.5 + 0.5)
		await get_tree().physics_frame

	if is_instance_valid(layer): layer.queue_free()
	if is_instance_valid(safe_marker): safe_marker.queue_free()
	if is_instance_valid(sopro_haz): sopro_haz.queue_free()

	# Volta o boss pro foreground
	scale = orig_scale
	z_index = orig_z
	modulate = Color.WHITE
	await _move_to(_idle_pos(), move_speed)
	is_immune = false


# ============================================================================
# MEC 3 — Mãos de Gelo (FASE DESESPERADA)
# Boss some; 2 luvas gigantes nas bordas avançam pro centro. Wipe se a distância
# fechar. Periodicamente uma brilha → COUNTER → janela de stagger naquela luva;
# stagger cheio empurra a luva pra trás. Alternar até `maos_max_cycles`.
# ============================================================================
func _mech_maos_de_gelo() -> void:
	_wipe_card("MÃOS DE GELO — Counter na luva que brilhar!")
	is_immune = true
	# Esconde o boss
	var orig_mod := modulate
	modulate = Color(1, 1, 1, 0)
	# Spawn das duas luvas
	_hand_left  = _spawn_hand(Vector2(arena_left + maos_hand_width * 0.5, _arena_center().y), true)
	_hand_right = _spawn_hand(Vector2(arena_right - maos_hand_width * 0.5, _arena_center().y), false)

	var orig_max := max_stagger
	max_stagger = maos_hand_max_hp
	var cycles := 0
	var won := false
	var dt := get_physics_process_delta_time()
	var glow_cd : float = randf_range(maos_glow_interval_min, maos_glow_interval_max)
	var which : bool = randf() > 0.5   # true = esquerda glow, false = direita

	# Baseline: bloqueia stagger fora da janela (player não enxerga o boss; o
	# `_await_counter` reseta a flag, então o caller restaura depois de cada sub).
	_set_stagger_immune(true)

	while _alive() and cycles < maos_max_cycles:
		# Aproxima as luvas (lentamente). Reatribuição completa do Vector2
		# pra garantir que o setter de global_position é chamado.
		if is_instance_valid(_hand_left):
			var lp : Vector2 = _hand_left.global_position
			lp.x += maos_close_speed * dt
			_hand_left.global_position = lp
		if is_instance_valid(_hand_right):
			var rp : Vector2 = _hand_right.global_position
			rp.x -= maos_close_speed * dt
			_hand_right.global_position = rp

		# Wipe se encontraram (esmagamento)
		if is_instance_valid(_hand_left) and is_instance_valid(_hand_right):
			var dist : float = _hand_right.global_position.x - _hand_left.global_position.x
			if dist <= maos_min_distance:
				_announce("ESMAGADO.", Color(1.0, 0.3, 0.3))
				_wipe()
				break

		# Glow + counter periódico
		glow_cd -= dt
		if glow_cd <= 0.0:
			glow_cd = randf_range(maos_glow_interval_min, maos_glow_interval_max)
			var target_hand : Node2D = _hand_left if which else _hand_right
			which = not which
			var pushed : bool = await _run_maos_counter(target_hand)
			_set_stagger_immune(true)   # restaura baseline (sub pode ter alterado)
			if pushed:
				cycles += 1
				if cycles >= maos_max_cycles:
					won = true
					break

		await get_tree().physics_frame

	# Cleanup
	if is_instance_valid(_hand_left):  _hand_left.queue_free()
	if is_instance_valid(_hand_right): _hand_right.queue_free()
	_hand_left = null
	_hand_right = null
	max_stagger = orig_max
	EventBus.boss_stagger_updated.emit(0.0, max_stagger)
	modulate = orig_mod
	is_immune = false
	_set_stagger_immune(false)   # desliga o bloqueio do mecânico

	if won:
		_announce("Luvas despedaçadas — Goliah cede!", Color(0.5, 1.0, 0.8))
		await _sleep(1.0)


# Sub-rotina: brilho na luva alvo → counter window → se sucesso, janela de
# stagger pra quebrar a luva e empurrá-la pra trás. Retorna true se empurrou.
func _run_maos_counter(target_hand: Node2D) -> bool:
	if not is_instance_valid(target_hand):
		return false
	# Telegrafo: brilha amarelo
	var orig_color : Color = Color.WHITE
	var rect : ColorRect = target_hand.get_node_or_null("Rect") as ColorRect
	if rect:
		orig_color = rect.color
		rect.color = Color(1.0, 1.0, 0.4)
	await _sleep(0.4)
	if not _alive():
		if rect: rect.color = orig_color
		return false

	# Janela de counter
	var ok : bool = await _await_counter(maos_counter_window)
	if not ok:
		if rect: rect.color = orig_color
		return false

	# Sucesso: trava a luva e abre janela de stagger nela.
	_parry_feedback()
	if rect: rect.color = Color(1.0, 0.6, 0.6)
	# Move o boss (invisível) pra posição da luva — a Hurtbox do boss segue, então
	# os ataques do player que mirarem o visual da luva registram aqui.
	global_position = target_hand.global_position
	max_stagger = maos_hand_max_hp
	EventBus.boss_stagger_updated.emit(0.0, max_stagger)
	_set_stagger_mech_mode(true)
	_set_stagger_immune(false)   # libera o stagger nesta janela
	_reset_stagger()
	_stagger_cd_t = 0.0          # zera o anti-spam pra janela ser justa

	var dt := get_physics_process_delta_time()
	var t := 0.0
	var broken := false
	while _alive() and t < maos_stagger_window:
		t += dt
		if stagger >= max_stagger:
			broken = true
			break
		await get_tree().physics_frame
	_set_stagger_mech_mode(false)
	_reset_stagger()

	if broken:
		# Empurra a luva pra trás (Vector2 inteiro pra garantir o setter)
		var is_left : bool = target_hand == _hand_left
		var push : float = -maos_push_back if is_left else maos_push_back
		var hp : Vector2 = target_hand.global_position
		hp.x += push
		target_hand.global_position = hp
		if rect: rect.color = orig_color
		return true

	# Não quebrou: restaura cor e continua
	if rect: rect.color = orig_color
	return false


func _spawn_hand(pos: Vector2, is_left: bool) -> Node2D:
	var root := Node2D.new()
	root.name = "HandLeft" if is_left else "HandRight"
	if skin_mao:
		root.add_child(skin_mao.instantiate())
	else:
		var r := ColorRect.new()
		r.name = "Rect"
		r.size = Vector2(maos_hand_width, maos_hand_height)
		r.position = -r.size * 0.5
		r.color = Color(0.55, 0.7, 0.9)
		root.add_child(r)
	get_parent().add_child(root)
	root.global_position = pos
	return root

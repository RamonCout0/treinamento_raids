# GameFeel.gd — autoload de "feel" do jogo.
# ============================================================================
#   • hit_stop(t)             — freeze frames (Engine.time_scale baixo) num
#                                instante de impacto. Adiciona PESO.
#   • shake_camera(int, t)    — sacode a Camera2D ativa (offset aleatório
#                                decaindo). Reage a hit, parry, stagger, morte.
#   • spawn_damage_number()   — número flutuante que sobe e some na posição
#                                do hit. Mostra DPS.
#
# Tudo opcional — funciona sem configurar nada. Apenas plugar no autoload.
# Para a câmera funcionar a arena precisa ter uma Camera2D ativa (criada
# automaticamente em arena.gd).
# ============================================================================
extends Node

const DAMAGE_NUMBER : PackedScene = preload("res://UI/damage_number.tscn")

# Estado do shake (acumula com novo trigger pra não interromper).
var _shake_intensity := 0.0
var _shake_time      := 0.0
var _shake_max_time  := 0.0

# Token do hit_stop mais recente: dois freezes sobrepostos não cortam um ao outro.
var _hitstop_token   := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # não pausa com time_scale


func _process(delta: float) -> void:
	if _shake_time > 0.0:
		_shake_time = max(0.0, _shake_time - delta)
		var cam := get_viewport().get_camera_2d()
		if cam:
			var falloff : float = _shake_time / _shake_max_time
			var amount := _shake_intensity * falloff
			cam.offset = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
			if _shake_time <= 0.0:
				cam.offset = Vector2.ZERO


# Freeze frames. Engine.time_scale despenca por `t` segundos reais.
# Pequeno (~0.05): hit normal. Maior (~0.12): parry/stagger.
func hit_stop(t: float = 0.06, scale: float = 0.02) -> void:
	_hitstop_token += 1
	var my_token := _hitstop_token
	Engine.time_scale = scale
	# Timer "real" — ignora time_scale.
	await get_tree().create_timer(t, true, false, true).timeout
	# Só restaura se nenhum hit_stop mais novo assumiu nesse meio tempo.
	if my_token == _hitstop_token:
		Engine.time_scale = 1.0


# Camera shake. Acumula com triggers anteriores (max).
func shake_camera(intensity: float = 4.0, duration: float = 0.18) -> void:
	if intensity > _shake_intensity:
		_shake_intensity = intensity
	if duration > _shake_time:
		_shake_time     = duration
		_shake_max_time = duration


# Número flutuante na posição do hit (coordenadas de mundo).
# Use text_override pra texto custom ("PARRY", "STAGGER", etc).
func spawn_damage_number(world_pos: Vector2, amount: float, color: Color = Color(1.0, 0.95, 0.4), text_override: String = "") -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var n := DAMAGE_NUMBER.instantiate()
	scene_root.add_child(n)
	n.global_position = world_pos + Vector2(randf_range(-6.0, 6.0), -8.0)
	if n.has_method("setup"):
		n.setup(int(round(amount)), color, text_override)

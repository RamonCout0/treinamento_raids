# RaidManager.gd — autoload que define as raids e sequencia os gates.
# ============================================================================
# Cada raid = uma sequência de cenas (gates). Vencer um gate carrega o próximo;
# após o boss final, volta ao lobby. A arena chama `next_gate()` no Enter da
# tela de vitória; o `return_to_lobby()` é chamado pela tela de derrota e Esc.
# ============================================================================
extends Node

const LOBBY_SCENE := "res://Lobby/lobby.tscn"

# raid_id -> array de cenas (gate 1, gate 2, boss final).
var raids : Dictionary = {
	"trunda": [
		"res://Arenas/arena_mortheus.tscn",
		"res://Arenas/arena_goliah.tscn",
		"res://Arenas/arena_silvanna.tscn",
	],
	"duelista": [
		"res://Arenas/arena_renji.tscn",
		"res://Arenas/arena_hana.tscn",
		"res://Arenas/arena_duelista.tscn",
	],
	"colosso": [
		"res://Arenas/arena_bruta.tscn",
		"res://Arenas/arena_mygur.tscn",
		"res://Arenas/arena_colosso.tscn",
	],
	"tecela": [
		"res://Arenas/arena_lira.tscn",
		"res://Arenas/arena_mirio.tscn",
		"res://Arenas/arena_tecela.tscn",
	],
	"devorador": [
		"res://Arenas/arena_asha.tscn",
		"res://Arenas/arena_karva.tscn",
		"res://Arenas/arena_devorador.tscn",
	],
}

var current_raid : String = ""
var current_gate : int = 0


func start_raid(raid_id: String) -> void:
	if not raids.has(raid_id):
		push_warning("[RaidManager] raid desconhecida: " + raid_id)
		return_to_lobby()
		return
	current_raid = raid_id
	current_gate = 0
	get_tree().change_scene_to_file(raids[raid_id][0])


# Próximo gate da raid atual; se acabou, volta pro lobby.
func next_gate() -> void:
	if current_raid == "" or not raids.has(current_raid):
		return_to_lobby()
		return
	current_gate += 1
	var list : Array = raids[current_raid]
	if current_gate >= list.size():
		return_to_lobby()
	else:
		get_tree().change_scene_to_file(list[current_gate])


func return_to_lobby() -> void:
	current_raid = ""
	current_gate = 0
	get_tree().change_scene_to_file(LOBBY_SCENE)


# Recarrega o GATE ATUAL (morreu = tenta de novo, sem perder o progresso da raid).
func retry_gate() -> void:
	if current_raid == "" or not raids.has(current_raid):
		get_tree().reload_current_scene()
		return
	var list : Array = raids[current_raid]
	current_gate = clampi(current_gate, 0, list.size() - 1)
	get_tree().change_scene_to_file(list[current_gate])


# Carrega uma arena solta sem entrar numa sequência (modo treino do menu).
func play_single(scene_path: String) -> void:
	current_raid = ""
	current_gate = 0
	get_tree().change_scene_to_file(scene_path)


# Texto pra HUD: "Raid Trunda — Gate 2/3" etc. Vazio fora de raid.
func progress_text() -> String:
	if current_raid == "" or not raids.has(current_raid):
		return ""
	var total : int = raids[current_raid].size()
	return "Raid %s — Gate %d/%d" % [current_raid.capitalize(), current_gate + 1, total]

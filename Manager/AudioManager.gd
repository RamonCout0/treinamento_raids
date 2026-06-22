# AudioManager.gd — gerência de áudio (autoload, placeholder).
# ============================================================================
# Música: cada Arena tem o campo `Arena Music`; o menu usa `Menu Music` daqui.
# SFX: tocam automaticamente em eventos do EventBus (hit/parry/stagger/morte).
#
# COMO PLUGAR: abra `Manager/AudioManager.tscn` e arraste seus arquivos de áudio
# (.ogg/.wav/.mp3) nos campos do Inspetor. Vazio = silêncio (nada quebra).
# Dica: pra MÚSICA em loop, marque "Loop" na importação do arquivo (aba Import).
# ============================================================================
extends Node

@export_group("Música")
@export var menu_music : AudioStream
@export var music_volume_db : float = -6.0

@export_group("SFX")
@export var sfx_volume_db    : float = -2.0
@export var sfx_hit          : AudioStream   ## acertou o boss
@export var sfx_parry        : AudioStream   ## parry bem-sucedido
@export var sfx_stagger      : AudioStream   ## quebrou a postura do boss
@export var sfx_boss_death   : AudioStream   ## boss morreu
@export var sfx_player_hurt  : AudioStream   ## player tomou dano
@export var sfx_player_death : AudioStream   ## player morreu

const POOL := 6

var _music : AudioStreamPlayer
var _sfx_pool : Array = []
var _sfx_i := 0


func _ready() -> void:
	_music = AudioStreamPlayer.new()
	_music.volume_db = music_volume_db
	add_child(_music)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.volume_db = sfx_volume_db
		add_child(p)
		_sfx_pool.append(p)

	EventBus.boss_hit.connect(func(): _play(sfx_hit))
	EventBus.player_parried.connect(func(): _play(sfx_parry))
	EventBus.boss_staggered.connect(func(): _play(sfx_stagger))
	EventBus.boss_died.connect(func(): _play(sfx_boss_death))
	EventBus.player_hurt.connect(func(): _play(sfx_player_hurt))
	EventBus.player_died.connect(func(): _play(sfx_player_death))


# Troca a faixa de música. null = silêncio. (Bosses podem chamar isto pra mudar
# de música por fase: AudioManager.play_music(minha_stream).)
func play_music(stream: AudioStream) -> void:
	if stream == null:
		_music.stop()
		return
	if _music.stream == stream and _music.playing:
		return
	_music.stream = stream
	_music.play()


func stop_music() -> void:
	_music.stop()


func _play(stream: AudioStream) -> void:
	if stream == null:
		return
	var p : AudioStreamPlayer = _sfx_pool[_sfx_i]
	_sfx_i = (_sfx_i + 1) % POOL
	p.stream = stream
	p.play()

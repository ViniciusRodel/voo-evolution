class_name CameraSeguidora
extends Camera3D
## Camera em terceira pessoa, atras e acima do aviao.
##
## Regra de ouro deste tipo de camera: ela NUNCA deve ser filha do aviao.
## Se fosse, herdaria a rolagem e a arfagem do modelo e o jogador enjoaria em
## 30 segundos. Ela segue a POSICAO do alvo e ignora a rotacao dele.

@export var alvo_caminho: NodePath
## Deslocamento em relacao ao alvo, no espaco do mundo.
@export var deslocamento: Vector3 = Vector3(0.0, 4.2, 9.0)
## Velocidade de perseguicao. Menor = camera mais "preguicosa" e cinematografica.
@export var suavizacao: float = 6.0
## Quanto a camera se desloca lateralmente em resposta ao aviao. Abaixo de 1.0
## a camera "fica para tras" na curva, o que aumenta a sensacao de velocidade.
@export var acompanhamento_lateral: float = 0.65
## FOV base e FOV no impulso. A variacao de FOV e o truque mais barato e mais
## eficaz para comunicar velocidade.
@export var fov_base: float = 68.0
@export var fov_impulso: float = 82.0

var _alvo: Node3D = null
var _tremor: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	fov = fov_base
	if alvo_caminho != NodePath():
		_alvo = get_node_or_null(alvo_caminho) as Node3D
	Eventos.solo_tocado.connect(_ao_colidir)


func definir_alvo(n: Node3D) -> void:
	_alvo = n


func _process(delta: float) -> void:
	if _alvo == null:
		return

	var destino := _alvo.global_position + deslocamento
	destino.x = _alvo.global_position.x * acompanhamento_lateral + deslocamento.x

	var s := clampf(suavizacao * delta, 0.0, 1.0)
	global_position = global_position.lerp(destino, s)

	if _tremor > 0.0:
		_tremor = maxf(0.0, _tremor - delta * 2.5)
		var amp := _tremor * 0.35
		global_position += Vector3(
			_rng.randf_range(-amp, amp),
			_rng.randf_range(-amp, amp),
			0.0
		)

	# Olha um pouco a frente do aviao, nao para ele. Da mais visibilidade dos
	# obstaculos que estao chegando.
	var foco := _alvo.global_position + Vector3(0.0, 0.6, -12.0)
	look_at(foco, Vector3.UP)

	var alvo_fov := fov_base
	if _alvo is Aviao and (_alvo as Aviao).impulso_ativo():
		alvo_fov = fov_impulso
	fov = lerpf(fov, alvo_fov, clampf(4.0 * delta, 0.0, 1.0))


func _ao_colidir(_pos: Vector3) -> void:
	_tremor = 1.0

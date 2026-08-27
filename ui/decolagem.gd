class_name Decolagem
extends Control
## QTE de decolagem: faixas coloridas com um marcador que varre a barra.
## O jogador toca para travar; a zona acertada define o bonus de velocidade
## inicial da partida.
##
## Este e o primeiro input que o jogador da em cada partida. Ele existe para
## (a) dar agencia logo no primeiro segundo e (b) criar uma razao para repetir
## a corrida mesmo sem progressao nova ("dessa vez eu pego o verde").
##
## As zonas sao simetricas: verde no centro, vermelho nas pontas. Simetria
## importa porque o marcador varre nos dois sentidos - assimetria tornaria a
## dificuldade diferente na ida e na volta.

signal concluida(multiplicador: float, nome_zona: String)

## Cada zona: metade da largura (fracao de 0..0.5 a partir do centro), cor,
## multiplicador e rotulo.
const ZONAS := [
	{"limite": 0.06, "cor": Color(0.16, 0.75, 0.32), "mult": 1.35, "nome": "PERFEITO"},
	{"limite": 0.17, "cor": Color(0.62, 0.80, 0.22), "mult": 1.15, "nome": "OTIMO"},
	{"limite": 0.32, "cor": Color(0.96, 0.80, 0.18), "mult": 0.95, "nome": "BOM"},
	{"limite": 0.50, "cor": Color(0.88, 0.24, 0.18), "mult": 0.70, "nome": "FRACO"},
]

## Velocidade de varredura, em ciclos por segundo. Sobe com a velocidade do
## veiculo: veiculo mais rapido, QTE mais dificil.
@export var ciclos_por_segundo: float = 0.85

var _posicao: float = 0.0     # 0.0 a 1.0 ao longo da barra
var _direcao: float = 1.0
var _rodando: bool = false
var _resultado_nome: String = ""
var _resultado_cor: Color = Color.WHITE
var _tempo_resultado: float = 0.0

@onready var _rotulo: Label = $Instrucao
@onready var _rotulo_resultado: Label = $Resultado


func _ready() -> void:
	set_process(false)
	visible = false


func iniciar(veiculo: Veiculo) -> void:
	visible = true
	_posicao = 0.0
	_direcao = 1.0
	_rodando = true
	_resultado_nome = ""
	_tempo_resultado = 0.0
	# Escala a dificuldade pela velocidade de cruzeiro, com teto para o caca
	# supersonico nao virar impossivel.
	ciclos_por_segundo = clampf(0.65 + veiculo.velocidade_cruzeiro / 260.0, 0.65, 2.1)
	if _rotulo:
		_rotulo.text = "TOQUE NO VERDE PARA DECOLAR"
		_rotulo.visible = true
	if _rotulo_resultado:
		_rotulo_resultado.visible = false
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if _rodando:
		_posicao += _direcao * ciclos_por_segundo * delta
		if _posicao >= 1.0:
			_posicao = 1.0
			_direcao = -1.0
		elif _posicao <= 0.0:
			_posicao = 0.0
			_direcao = 1.0
		queue_redraw()
	elif _tempo_resultado > 0.0:
		_tempo_resultado -= delta
		if _tempo_resultado <= 0.0:
			set_process(false)
			visible = false


func _gui_input(evento: InputEvent) -> void:
	if not _rodando:
		return
	var confirmou := false
	if evento is InputEventScreenTouch and (evento as InputEventScreenTouch).pressed:
		confirmou = true
	elif evento.is_action_pressed(&"impulso"):
		confirmou = true
	if confirmou:
		accept_event()
		_travar()


func _unhandled_input(evento: InputEvent) -> void:
	# Redundancia proposital: no desktop o toque emulado nem sempre cai dentro
	# do Control se o mouse estiver sobre outro no.
	if _rodando and evento.is_action_pressed(&"impulso"):
		_travar()


func _travar() -> void:
	if not _rodando:
		return
	_rodando = false

	var distancia_do_centro := absf(_posicao - 0.5)
	var mult := 0.70
	var nome := "FRACO"
	var cor := Color(0.88, 0.24, 0.18)
	for z in ZONAS:
		if distancia_do_centro <= float(z["limite"]):
			mult = float(z["mult"])
			nome = String(z["nome"])
			cor = z["cor"]
			break

	_resultado_nome = nome
	_resultado_cor = cor
	_tempo_resultado = 0.9

	if _rotulo:
		_rotulo.visible = false
	if _rotulo_resultado:
		_rotulo_resultado.visible = true
		_rotulo_resultado.text = nome
		_rotulo_resultado.add_theme_color_override(&"font_color", cor)

	queue_redraw()
	concluida.emit(mult, nome)


func _draw() -> void:
	var margem := 28.0
	var altura_barra := 46.0
	var y := size.y * 0.5 - altura_barra * 0.5
	var largura := size.x - margem * 2.0
	if largura <= 0.0:
		return

	# Faixas: desenhadas do centro para fora, simetricas.
	var anterior := 0.0
	for z in ZONAS:
		var limite := float(z["limite"])
		var cor: Color = z["cor"]
		# lado direito
		var x0 := margem + (0.5 + anterior) * largura
		var x1 := margem + (0.5 + limite) * largura
		draw_rect(Rect2(x0, y, x1 - x0, altura_barra), cor)
		# lado esquerdo (espelhado)
		var x2 := margem + (0.5 - limite) * largura
		var x3 := margem + (0.5 - anterior) * largura
		draw_rect(Rect2(x2, y, x3 - x2, altura_barra), cor)
		anterior = limite

	draw_rect(Rect2(margem, y, largura, altura_barra), Color(0, 0, 0, 0.55), false, 3.0)

	# Marcador.
	var mx := margem + _posicao * largura
	var cor_marcador := Color.WHITE if _rodando else _resultado_cor
	draw_rect(Rect2(mx - 3.0, y - 10.0, 6.0, altura_barra + 20.0), cor_marcador)
	draw_rect(Rect2(mx - 3.0, y - 10.0, 6.0, altura_barra + 20.0), Color(0, 0, 0, 0.7), false, 2.0)

class_name Estilingue
extends Control
## Medidor de forca do lancamento. Segurar carrega, soltar lanca.
##
## O medidor varre de 0 a 100% em Config.LANCAMENTO_CICLO segundos e volta. A
## posicao no momento da soltura e a qualidade `q`, que entra em:
##
##     v_inicial = v_cruzeiro * (0,90 + 0,35*q) * bonus_estilingue
##
## MEDIDO, NAO SUPOSTO: a diferenca entre o pior e o melhor lancamento vale
## +3,5% de distancia no nivel 1 e cai para +0,7% no nivel 10. O modelo de voo
## tem uma velocidade de equilibrio que funciona como atrator e come qualquer
## vantagem inicial em poucos segundos.
##
## Isso e proposital: este e um jogo de progressao, nao de habilidade. O
## estilingue existe para dar agencia no primeiro segundo e para tornar os
## upgrades visiveis (o elastico estica mais), nao para decidir a corrida.
##
## Alem da forca, o jogador mira arrastando o dedo para os lados enquanto o
## medidor esta correndo. Essa mira define a posicao lateral em que o aviao
## NASCE no corredor (Aviao.lancar) - efeito real, nao cosmetico: uma mira boa
## alinha com o primeiro padrao de orbes, uma mira ruim nasce fora da linha.

signal lancado(qualidade: float, lateral: float, rotulo: String)

const ZONAS := [
	{"minimo": 0.92, "cor": Color(0.16, 0.78, 0.34), "rotulo": "PERFEITO"},
	{"minimo": 0.78, "cor": Color(0.62, 0.82, 0.22), "rotulo": "OTIMO"},
	{"minimo": 0.50, "cor": Color(0.96, 0.80, 0.18), "rotulo": "BOM"},
	{"minimo": 0.00, "cor": Color(0.88, 0.28, 0.20), "rotulo": "FRACO"},
]

## Fracao de mira ganha por pixel arrastado na horizontal.
const SENSIBILIDADE_MIRA: float = 0.0032

var _posicao: float = 0.0
var _direcao: float = 1.0
var _rodando: bool = false
var _resultado_cor := Color.WHITE
var _tempo_saida: float = 0.0
var _lateral: float = 0.0    # -1 (esquerda) a 1 (direita)

@onready var _instrucao: Label = $Instrucao
@onready var _resultado: Label = $Resultado


func _ready() -> void:
	visible = false
	set_process(false)


func iniciar() -> void:
	visible = true
	_posicao = 0.0
	_direcao = 1.0
	_rodando = true
	_tempo_saida = 0.0
	_lateral = 0.0
	if _instrucao:
		_instrucao.visible = true
		_instrucao.text = "ARRASTE PARA MIRAR · SOLTE NO VERDE PARA LANCAR"
	if _resultado:
		_resultado.visible = false
	set_process(true)
	queue_redraw()


## Tensao atual do elastico (0 a 1). O mundo 3D usa para puxar o aviao para
## tras enquanto o medidor carrega.
func tensao() -> float:
	return _posicao if _rodando else 0.0


## Mira lateral atual (-1 esquerda a 1 direita). O mundo 3D usa para desviar o
## aviao para o lado durante o puxao, junto com tensao().
func mira() -> float:
	return _lateral


func _process(delta: float) -> void:
	if _rodando:
		var passo := delta / maxf(Config.LANCAMENTO_CICLO, 0.05)
		_posicao += _direcao * passo
		if _posicao >= 1.0:
			_posicao = 1.0
			_direcao = -1.0
		elif _posicao <= 0.0:
			_posicao = 0.0
			_direcao = 1.0
		queue_redraw()
	elif _tempo_saida > 0.0:
		_tempo_saida -= delta
		if _tempo_saida <= 0.0:
			visible = false
			set_process(false)


func _gui_input(evento: InputEvent) -> void:
	if not _rodando:
		return
	if evento is InputEventScreenDrag:
		_lateral = clampf(
			_lateral + (evento as InputEventScreenDrag).relative.x * SENSIBILIDADE_MIRA, -1.0, 1.0)
		accept_event()
		queue_redraw()
	elif evento is InputEventScreenTouch and not (evento as InputEventScreenTouch).pressed:
		accept_event()
		_lancar()
	elif evento.is_action_released(&"impulso"):
		accept_event()
		_lancar()


func _unhandled_input(evento: InputEvent) -> void:
	if _rodando and evento.is_action_released(&"impulso"):
		_lancar()


## Lanca com uma qualidade especifica, sem esperar o medidor. Usado pelo piloto
## automatico para que o teste seja determinista - um teste que depende de
## acertar o tempo do medidor mede o medidor, nao o modelo de voo. Mira
## centralizada por padrao: a mira e ortogonal a distancia (mexe na posicao
## lateral, nao na velocidade), entao nao precisa variar para o teste bater
## com o simulador.
func lancar_direto(qualidade: float, lateral: float = 0.0) -> void:
	if not _rodando:
		return
	_posicao = clampf(qualidade, 0.0, 1.0)
	_lateral = clampf(lateral, -1.0, 1.0)
	_lancar()


func _lancar() -> void:
	if not _rodando:
		return
	_rodando = false
	var q := _posicao
	var cor := Color(0.88, 0.28, 0.20)
	var rotulo := "FRACO"
	for z in ZONAS:
		if q >= float(z["minimo"]):
			cor = z["cor"]
			rotulo = String(z["rotulo"])
			break

	_resultado_cor = cor
	_tempo_saida = 0.8
	if _instrucao:
		_instrucao.visible = false
	if _resultado:
		_resultado.visible = true
		_resultado.text = rotulo
		_resultado.add_theme_color_override(&"font_color", cor)
	queue_redraw()
	lancado.emit(q, _lateral, rotulo)


func _draw() -> void:
	var margem := 30.0
	var altura := 42.0
	var largura := size.x - margem * 2.0
	if largura <= 0.0:
		return
	var y := size.y * 0.5 - altura * 0.5

	# Trilho da mira lateral fica abaixo do medidor de forca.
	var altura_mira := 20.0
	var y_mira := y + altura + 34.0

	draw_rect(Rect2(0.0, y - 120.0, size.x, y_mira + altura_mira + 30.0 - (y - 120.0)),
		Color(0, 0, 0, 0.32))

	# Zonas, do fim (verde) para o inicio (vermelho).
	var anterior := 1.0
	for z in ZONAS:
		var minimo := float(z["minimo"])
		var x0 := margem + minimo * largura
		var x1 := margem + anterior * largura
		draw_rect(Rect2(x0, y, x1 - x0, altura), z["cor"])
		anterior = minimo

	draw_rect(Rect2(margem, y, largura, altura), Color(0, 0, 0, 0.55), false, 3.0)

	var mx := margem + _posicao * largura
	var cor_marcador := Color.WHITE if _rodando else _resultado_cor
	draw_rect(Rect2(mx - 3.0, y - 12.0, 6.0, altura + 24.0), cor_marcador)
	draw_rect(Rect2(mx - 3.0, y - 12.0, 6.0, altura + 24.0), Color(0, 0, 0, 0.7), false, 2.0)

	# Mira lateral: trilho com marcador que segue o arraste horizontal.
	# Fica parado apos a soltura, mostrando onde o aviao vai nascer no corredor.
	draw_rect(Rect2(margem, y_mira, largura, altura_mira), Color(0.10, 0.10, 0.12, 0.85))
	draw_rect(Rect2(margem, y_mira, largura, altura_mira), Color(0, 0, 0, 0.55), false, 2.0)
	draw_line(Vector2(margem + largura * 0.5, y_mira), Vector2(margem + largura * 0.5, y_mira + altura_mira),
		Color(1, 1, 1, 0.35), 2.0)
	var mx_mira := margem + (0.5 + _lateral * 0.5) * largura
	var y_centro_mira := y_mira + altura_mira * 0.5
	draw_circle(Vector2(mx_mira, y_centro_mira), 11.0, Color(0.95, 0.95, 0.85))
	draw_circle(Vector2(mx_mira, y_centro_mira), 11.0, Color(0, 0, 0, 0.7), false, 2.0)

extends CanvasLayer
## HUD de voo.
##
## O jogo de referencia tem exatamente quatro informacoes na tela: velocimetro,
## barra de progresso, distancia e o botao de impulso.
##
## Tudo se alimenta do barramento de eventos, nunca de referencia direta ao
## aviao - da para testar o HUD inteiro sem existir aviao na cena.

@onready var _velocimetro: Velocimetro = $Raiz/Velocimetro
@onready var _distancia: Label = $Raiz/Distancia
@onready var _barra: BarraProgresso = $Raiz/Barra
@onready var _botao_impulso: Button = $Raiz/BotaoImpulso
@onready var _aviso: Label = $Raiz/Aviso

var _meta: float = 1.0
var _aviso_restante: float = 0.0


func _ready() -> void:
	Eventos.velocidade_alterada.connect(_ao_velocidade)
	Eventos.distancia_alterada.connect(_ao_distancia)
	Eventos.impulso_alterado.connect(_ao_impulso)
	Eventos.termica_entrou.connect(func(): _mostrar_aviso("CORRENTE DE AR", Color(0.35, 0.85, 0.95)))
	if _botao_impulso:
		_botao_impulso.pressed.connect(_ao_tocar_impulso)
	if _aviso:
		_aviso.visible = false
	set_process(true)


func configurar(meta: float) -> void:
	_meta = maxf(meta, 1.0)
	if _velocimetro:
		# A escala do velocimetro acompanha o aviao: sem isso, 50 km/h e
		# 1200 km/h usariam o mesmo mostrador e um dos dois ficaria ilegivel.
		_velocimetro.maximo = Config.velocidade_exibida(DadosJogo.v_cruzeiro() * 1.6)
		_velocimetro.valor = 0.0
	if _barra:
		_barra.progresso = 0.0
	if _distancia:
		_distancia.text = "0 M"


func _process(delta: float) -> void:
	if _aviso_restante > 0.0:
		_aviso_restante -= delta
		if _aviso_restante <= 0.0 and _aviso:
			_aviso.visible = false


func _ao_velocidade(v_ms: float) -> void:
	if _velocimetro:
		_velocimetro.valor = Config.velocidade_exibida(v_ms)


func _ao_distancia(metros: float) -> void:
	if _distancia:
		_distancia.text = "%s M" % CartaoAtributo._formatar(int(metros))
	if _barra:
		_barra.progresso = clampf(metros / _meta, 0.0, 1.0)


func _ao_impulso(ativo: bool, disponivel: bool, progresso: float) -> void:
	if _botao_impulso == null:
		return
	_botao_impulso.disabled = not disponivel
	if ativo:
		_botao_impulso.text = "IMPULSO!"
	elif disponivel:
		_botao_impulso.text = "IMPULSO"
	else:
		_botao_impulso.text = "%d%%" % int(progresso * 100.0)


func _ao_tocar_impulso() -> void:
	var avioes := get_tree().get_nodes_in_group(Aviao.GRUPO)
	if not avioes.is_empty():
		(avioes[0] as Aviao).acionar_impulso()


func _mostrar_aviso(texto: String, cor: Color) -> void:
	if _aviso == null:
		return
	_aviso.text = texto
	_aviso.add_theme_color_override(&"font_color", cor)
	_aviso.visible = true
	_aviso_restante = 0.5

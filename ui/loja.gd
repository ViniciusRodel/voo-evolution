extends Control
## Tela de upgrades. E aqui que a sensacao de progresso acontece: o jogador
## chega com moedas, compra, e a proxima corrida vai mais longe.
##
## Decisao de UX: o botao de voar fica sempre visivel e habilitado, mesmo sem
## moedas. Bloquear a saida da loja para forcar uma compra transforma a tela de
## recompensa em pedagio.

signal voar_solicitado()

@onready var _moedas: Label = $Topo/Moedas
@onready var _titulo: Label = $Topo/Titulo
@onready var _resumo: Label = $Topo/Resumo
@onready var _conteudo: VBoxContainer = $Lista/Conteudo
@onready var _botao_voar: Button = $Rodape/Voar
@onready var _topo: VBoxContainer = $Topo

var _cartoes: Array[CartaoAtributo] = []
## StringName (id da dificuldade) -> Button. Construido em codigo, mesmo
## raciocinio do resto da loja (ui/cartao_atributo.gd): poucos elementos,
## parametrizados por um catalogo (Config.DIFICULDADES) que pode crescer.
var _botoes_dificuldade: Dictionary = {}


func _ready() -> void:
	_botao_voar.pressed.connect(func():
		visible = false
		voar_solicitado.emit())
	Eventos.moedas_alteradas.connect(func(_t): _atualizar())
	_montar_dificuldade()


func _montar_dificuldade() -> void:
	var linha := HBoxContainer.new()
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_theme_constant_override(&"separation", 10)
	_topo.add_child(linha)

	for id in [&"facil", &"medio", &"dificil"]:
		var def := Config.dificuldade(id)
		var botao := Button.new()
		botao.text = String(def["nome"])
		botao.toggle_mode = true
		botao.custom_minimum_size = Vector2(150, 60)
		botao.add_theme_font_size_override(&"font_size", 22)
		botao.pressed.connect(func():
			DadosJogo.definir_dificuldade(id)
			_atualizar_dificuldade())
		linha.add_child(botao)
		_botoes_dificuldade[id] = botao

	_atualizar_dificuldade()


func _atualizar_dificuldade() -> void:
	for id in _botoes_dificuldade:
		(_botoes_dificuldade[id] as Button).button_pressed = (id == DadosJogo.dificuldade_atual)


func abrir() -> void:
	visible = true
	if _cartoes.is_empty():
		for id in Atributos.ORDEM:
			var c := CartaoAtributo.new()
			_conteudo.add_child(c)
			c.configurar(id)
			c.comprado.connect(_ao_comprar)
			_cartoes.append(c)
	_atualizar()


func _ao_comprar(id: StringName) -> void:
	if DadosJogo.comprar(id):
		_atualizar()


func _atualizar() -> void:
	_moedas.text = "%s MOEDAS" % CartaoAtributo._formatar(DadosJogo.moedas)
	_titulo.text = "FASE %d · %s  ·  META %s M" % [
		DadosJogo.fase_selecionada + 1, DadosJogo.aviao_atual().nome,
		CartaoAtributo._formatar(int(DadosJogo.meta_atual()))]
	_resumo.text = "NIVEL %d/20   ·   CRUZEIRO %d KM/H   ·   RECORDE DA FASE %s M" % [
		DadosJogo.nivel_visual(),
		int(round(Config.velocidade_exibida(DadosJogo.v_cruzeiro()))),
		CartaoAtributo._formatar(int(DadosJogo.recorde_atual()))]
	for c in _cartoes:
		c.atualizar()
	_botao_voar.text = "VOAR"

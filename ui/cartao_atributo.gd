class_name CartaoAtributo
extends PanelContainer
## Linha da loja: um atributo, seu nivel, o efeito e o botao de compra.
##
## Construido em codigo porque e instanciado dinamicamente e parametrizado por
## atributo - um .tscn aqui exigiria configurar tudo por script de qualquer
## forma e so acrescentaria um arquivo a manter.

signal comprado(id: StringName)

var id: StringName = &""

var _nome: Label = null
var _detalhe: Label = null
var _pontos: Control = null
var _botao: Button = null


func configurar(atributo: StringName) -> void:
	id = atributo
	custom_minimum_size = Vector2(0, 118)
	if get_child_count() == 0:
		_montar()
	atualizar()


func _montar() -> void:
	var d: Dictionary = Atributos.definicao(id)

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.16, 0.18, 0.24)
	estilo.set_corner_radius_all(16)
	estilo.content_margin_left = 18
	estilo.content_margin_right = 18
	estilo.content_margin_top = 12
	estilo.content_margin_bottom = 12
	estilo.border_color = (d["cor"] as Color)
	estilo.border_width_left = 6
	add_theme_stylebox_override(&"panel", estilo)

	var linha := HBoxContainer.new()
	linha.add_theme_constant_override(&"separation", 16)
	add_child(linha)

	var coluna := VBoxContainer.new()
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna.add_theme_constant_override(&"separation", 4)
	linha.add_child(coluna)

	_nome = Label.new()
	_nome.add_theme_font_size_override(&"font_size", 26)
	coluna.add_child(_nome)

	_detalhe = Label.new()
	_detalhe.add_theme_font_size_override(&"font_size", 17)
	_detalhe.add_theme_color_override(&"font_color", Color(0.76, 0.79, 0.86))
	coluna.add_child(_detalhe)

	_pontos = Control.new()
	_pontos.custom_minimum_size = Vector2(0, 14)
	_pontos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pontos.draw.connect(_desenhar_pontos)
	coluna.add_child(_pontos)

	_botao = Button.new()
	_botao.custom_minimum_size = Vector2(230, 84)
	_botao.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_botao.add_theme_font_size_override(&"font_size", 26)
	_botao.pressed.connect(func(): comprado.emit(id))
	linha.add_child(_botao)


func atualizar() -> void:
	var d: Dictionary = Atributos.definicao(id)
	var nivel := DadosJogo.nivel(id)
	var maximo := Atributos.nivel_maximo(id)

	_nome.text = "%s  ·  NV %d/%d" % [d["nome"], nivel, maximo]
	_detalhe.text = "%s  —  %s" % [d["efeito"], d["descricao"]]
	_pontos.queue_redraw()

	if DadosJogo.no_maximo(id):
		_botao.text = "MAXIMO"
		_botao.disabled = true
		return
	var custo := DadosJogo.custo_proximo(id)
	_botao.text = "%s" % _formatar(custo)
	_botao.disabled = DadosJogo.moedas < custo


## Trilha de pontinhos mostrando o nivel. E o feedback mais barato de
## progresso: o jogador ve a barra encher sem precisar ler numero.
func _desenhar_pontos() -> void:
	var d: Dictionary = Atributos.definicao(id)
	var nivel := DadosJogo.nivel(id)
	var maximo := Atributos.nivel_maximo(id)
	var largura := _pontos.size.x
	if largura <= 0.0:
		return
	var passo := minf(18.0, largura / float(maximo))
	for i in maximo:
		var cor: Color = d["cor"] if i < nivel else Color(1, 1, 1, 0.16)
		_pontos.draw_rect(Rect2(float(i) * passo, 4.0, passo - 4.0, 7.0), cor)


static func _formatar(n: int) -> String:
	var s := str(n)
	var saida := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		saida = s[i] + saida
		c += 1
		if c % 3 == 0 and i > 0:
			saida = "." + saida
	return saida

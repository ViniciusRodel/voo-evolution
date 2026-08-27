class_name AjusteMoedas
extends Control
## Overlay de debug para calibrar ao vivo quanto cada dificuldade paga em
## moedas. Tecla F2 no desktop.
##
## Escreve direto em Config.DIFICULDADES[id]["moedas_mult"] (ver o comentario
## em autoload/config_jogo.gd sobre por que esse dicionario e `static var` e
## nao `const`). So dura a sessao atual - fecha o jogo e volta pro padrao
## calibrado no codigo.

const PASSO := 0.5
const ORDEM: Array[StringName] = [&"facil", &"medio", &"dificil"]

var _rotulos: Dictionary = {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var painel := PanelContainer.new()
	painel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(painel)
	painel.anchor_left = 1.0
	painel.anchor_right = 1.0
	painel.offset_left = -420.0
	painel.offset_top = 200.0
	painel.offset_right = -24.0

	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override(&"separation", 6)
	painel.add_child(caixa)

	var titulo := Label.new()
	titulo.text = "MOEDAS POR DIFICULDADE (F2)"
	titulo.add_theme_font_size_override(&"font_size", 18)
	caixa.add_child(titulo)

	for id in ORDEM:
		caixa.add_child(_montar_linha(id))


func _montar_linha(id: StringName) -> Control:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override(&"separation", 10)

	var def := Config.dificuldade(id)
	var nome := Label.new()
	nome.text = String(def["nome"])
	nome.custom_minimum_size = Vector2(110, 0)
	nome.add_theme_font_size_override(&"font_size", 20)
	linha.add_child(nome)

	var menos := Button.new()
	menos.text = "-"
	menos.custom_minimum_size = Vector2(48, 48)
	menos.pressed.connect(_ajustar.bind(id, -PASSO))
	linha.add_child(menos)

	var valor := Label.new()
	valor.custom_minimum_size = Vector2(70, 0)
	valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	valor.add_theme_font_size_override(&"font_size", 20)
	linha.add_child(valor)
	_rotulos[id] = valor

	var mais := Button.new()
	mais.text = "+"
	mais.custom_minimum_size = Vector2(48, 48)
	mais.pressed.connect(_ajustar.bind(id, PASSO))
	linha.add_child(mais)

	_atualizar_linha(id)
	return linha


func _ajustar(id: StringName, delta: float) -> void:
	var def := Config.dificuldade(id)
	def["moedas_mult"] = maxf(0.0, float(def["moedas_mult"]) + delta)
	_atualizar_linha(id)


func _atualizar_linha(id: StringName) -> void:
	var def := Config.dificuldade(id)
	(_rotulos[id] as Label).text = "%.1fx" % float(def["moedas_mult"])


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed(&"alternar_ajuste_moedas"):
		visible = not visible

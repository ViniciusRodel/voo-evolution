extends Control
## Tela de fim de corrida.
##
## Alem do resumo, esta tela responde a pergunta que decide se o jogador
## continua: POR QUE a corrida acabou. Sem isso, acabar no solo parece
## injusto.

signal jogar_novamente()
signal voltar_ao_menu()

const MOTIVOS := {
	"meta": ["META ALCANCADA!", Color(0.35, 0.85, 0.45)],
	"solo": ["VOCE TOCOU O SOLO", Color(0.92, 0.55, 0.25)],
	"obstaculo": ["VOCE BATEU EM ALGO", Color(0.90, 0.30, 0.28)],
}

@onready var _titulo: Label = $Painel/Caixa/Titulo
@onready var _detalhes: Label = $Painel/Caixa/Detalhes
@onready var _destaque: Label = $Painel/Caixa/Destaque
@onready var _botao_novamente: Button = $Painel/Caixa/Botoes/Novamente
@onready var _botao_menu: Button = $Painel/Caixa/Botoes/Menu
@onready var _painel: PanelContainer = $Painel


func _ready() -> void:
	visible = false
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.09, 0.10, 0.14, 0.97)
	estilo.border_color = Color(1, 1, 1, 0.12)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(22)
	estilo.set_content_margin_all(30)
	_painel.add_theme_stylebox_override(&"panel", estilo)

	_botao_novamente.pressed.connect(func(): visible = false; jogar_novamente.emit())
	_botao_menu.pressed.connect(func(): visible = false; voltar_ao_menu.emit())
	_botao_menu.text = "MELHORAR"


func mostrar(d: Dictionary) -> void:
	visible = true
	var motivo := String(d.get("motivo", "solo"))
	var info: Array = MOTIVOS.get(motivo, MOTIVOS["solo"])
	_titulo.text = String(info[0])
	_titulo.add_theme_color_override(&"font_color", info[1])

	var meta := float(d.get("meta", 1.0))
	var dist := float(d.get("distancia", 0.0))
	var linhas: Array[String] = []
	linhas.append("DISTANCIA: %s M   (%d%% DA META)" % [
		CartaoAtributo._formatar(int(dist)), int(round(dist / maxf(meta, 1.0) * 100.0))])
	linhas.append("VELOCIDADE MAXIMA: %d KM/H" % int(round(
		Config.velocidade_exibida(float(d.get("v_pico", 0.0))))))
	linhas.append("MOEDAS GANHAS: %s" % CartaoAtributo._formatar(int(d.get("moedas_ganhas", 0))))
	if bool(d.get("voo_limpo", false)) and bool(d.get("atingiu_meta", false)):
		linhas.append("BONUS DE VOO LIMPO: +%d%%" % int(Config.BONUS_VOO_LIMPO * 100.0))
	if bool(d.get("novo_recorde", false)):
		linhas.append("NOVO RECORDE!")
	_detalhes.text = "\n".join(linhas)

	if bool(d.get("prestigiou", false)):
		# V9: "rolling over" (briefing_ajustes_v9.md P2) - terminar a ultima
		# fase de novo, em vez de "subir fase" (nao ha mais fase acima),
		# reinicia com bonus permanente.
		_destaque.visible = true
		var mult := 1.0 + Config.BONUS_PRESTIGIO_POR_NIVEL * float(d.get("prestigios", 0))
		_destaque.text = "PRESTIGIO! BONUS DE MOEDAS PERMANENTE: x%.2f" % mult
	elif bool(d.get("subiu_fase", false)):
		_destaque.visible = true
		_destaque.text = "FASE %d LIBERADA" % (int(d.get("fase", 0)) + 1)
	else:
		_destaque.visible = false

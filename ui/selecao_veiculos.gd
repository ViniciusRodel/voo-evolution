extends Control
## Tela de selecao de veiculos, organizada por universos.
##
## Espelha a referencia: navegacao entre universos no topo, lista vertical de
## veiculos, cada um com preview, nome, requisito de velocidade e cadeado
## quando bloqueado.
##
## Os cartoes sao reconstruidos a cada troca de universo. Isso e aceitavel
## porque acontece por acao do jogador (nunca durante o voo) e sao no maximo
## ~6 cartoes. Se um universo chegar a 30 veiculos, trocar por reciclagem de
## cartoes - mas otimizar isso agora seria otimizar sem medida.

signal jogar_solicitado(veiculo: Veiculo)

@onready var _titulo: Label = $Topo/Navegacao/Titulo
@onready var _botao_anterior: Button = $Topo/Navegacao/Anterior
@onready var _botao_proximo: Button = $Topo/Navegacao/Proximo
@onready var _moedas: Label = $Topo/Moedas
@onready var _conteudo: VBoxContainer = $Lista/Conteudo
@onready var _botao_jogar: Button = $Rodape/Jogar
@onready var _dica: Label = $Rodape/Dica

var _universo_atual: int = 1
var _cartoes: Array[CartaoVeiculo] = []


func _ready() -> void:
	_botao_anterior.pressed.connect(func(): _mudar_universo(-1))
	_botao_proximo.pressed.connect(func(): _mudar_universo(1))
	_botao_jogar.pressed.connect(_ao_jogar)
	Eventos.moedas_alteradas.connect(func(t): _moedas.text = "%d MOEDAS" % t)


func abrir() -> void:
	visible = true
	var atual := DadosJogo.veiculo_atual()
	if atual != null:
		_universo_atual = atual.universo
	_recarregar()


func _mudar_universo(passo: int) -> void:
	var universos := DadosJogo.todos_universos()
	if universos.is_empty():
		return
	var indices: Array[int] = []
	for u in universos:
		indices.append(u.indice)
	var pos := indices.find(_universo_atual)
	if pos == -1:
		pos = 0
	pos = clampi(pos + passo, 0, indices.size() - 1)
	_universo_atual = indices[pos]
	_recarregar()


func _recarregar() -> void:
	for c in _cartoes:
		c.queue_free()
	_cartoes.clear()

	var universos := DadosJogo.todos_universos()
	var nome := "UNIVERSO %d" % _universo_atual
	for u in universos:
		if u.indice == _universo_atual:
			nome = "UNIVERSO %d - %s" % [u.indice, u.nome]
	_titulo.text = nome

	var indices: Array[int] = []
	for u in universos:
		indices.append(u.indice)
	var pos := indices.find(_universo_atual)
	_botao_anterior.disabled = pos <= 0
	_botao_proximo.disabled = pos < 0 or pos >= indices.size() - 1

	_moedas.text = "%d MOEDAS" % DadosJogo.moedas

	var selecionado := DadosJogo.veiculo_selecionado
	for v in DadosJogo.veiculos_do_universo(_universo_atual):
		var cartao := CartaoVeiculo.new()
		_conteudo.add_child(cartao)
		cartao.configurar(v, DadosJogo.esta_desbloqueado(v), DadosJogo.nivel_de(v), v.id == selecionado)
		cartao.escolhido.connect(_ao_escolher)
		_cartoes.append(cartao)

	_atualizar_rodape()


func _ao_escolher(v: Veiculo) -> void:
	if not DadosJogo.esta_desbloqueado(v):
		# Feedback de bloqueio: reafirma o requisito em vez de so ignorar o
		# toque. Toque sem resposta e lido como bug pelo jogador.
		_dica.text = "BLOQUEADO - ATINJA %d KM/H PARA LIBERAR" % v.velocidade_necessaria
		return
	DadosJogo.selecionar(v)
	_recarregar()


func _atualizar_rodape() -> void:
	var atual := DadosJogo.veiculo_atual()
	if atual == null:
		_botao_jogar.disabled = true
		return
	_botao_jogar.disabled = false
	_botao_jogar.text = "JOGAR COM %s" % atual.nome
	_dica.text = "RECORDE DE VELOCIDADE: %d KM/H" % int(DadosJogo.velocidade_recorde)


func _ao_jogar() -> void:
	var v := DadosJogo.veiculo_atual()
	if v == null:
		return
	visible = false
	jogar_solicitado.emit(v)

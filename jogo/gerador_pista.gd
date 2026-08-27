class_name GeradorPista
extends Node3D
## Streaming do cenario e posicionamento dos obstaculos.
##
## Mantem uma janela de pedacos vivos ao redor do aviao. Quando o aviao
## ultrapassa a fronteira de um pedaco, o mais antigo e reciclado e um novo
## aparece a frente. Nada e instanciado durante o voo: pedacos e obstaculos vem
## de pools pre-alocados em `preparar()`.
##
## DUAS REGRAS QUE NAO PODEM SER QUEBRADAS:
##
## 1. Toda fileira de obstaculos e gerada COM uma abertura garantida. Nao
##    existe configuracao impossivel. Se o jogador bateu, foi reacao dele -
##    nunca geracao injusta.
##
## 2. O espacamento entre fileiras e medido em TEMPO, nao em metros. Um veiculo
##    tres vezes mais rapido recebe fileiras tres vezes mais distantes, para
##    que a janela de reacao seja a mesma. Sem isso, evoluir de veiculo
##    tornaria o jogo injogavel em vez de recompensador - foi exatamente o que
##    o teste automatizado da Fase 1 revelou na primeira execucao.

enum Fileira { LATERAL, HORIZONTAL, PILARES }

## Metros iniciais sem nenhum obstaculo, para o jogador se ambientar.
const DISTANCIA_LIVRE_INICIO := 120.0
## Meia-largura da abertura lateral, em metros. Cai com a dificuldade.
const ABERTURA_LATERAL_BASE := 3.4
const ABERTURA_LATERAL_MIN := 2.2
## Meia-altura da abertura horizontal, em metros.
const ABERTURA_HORIZONTAL := 2.8
## Extensao lateral das paredes, alem do corredor jogavel.
const PAREDE_EXTENSAO := 16.0
## A partir de quantos metros o cenario vira cidade.
const DISTANCIA_URBANIZACAO := 850.0

var _pool_pedacos: Pool = null
var _pool_obstaculos: Pool = null
var _ativos: Array[PedacoCenario] = []
var _obstaculos_por_indice: Dictionary = {}
var _proximo_indice: int = 0
var _alvo: Node3D = null
var _universo: Universo = null
var _rng := RandomNumberGenerator.new()
var _pronto: bool = false

## Derivados da velocidade do veiculo em uso, calculados em iniciar().
var _espacamento: float = Config.ESPACAMENTO_MINIMO
var _pedacos_janela: int = Config.PEDACOS_ATIVOS
## Cursor global da proxima fileira, em z do mundo (negativo).
var _proximo_z_fileira: float = 0.0


func preparar() -> void:
	# Pre-alocacao. Acontece uma vez, fora do voo, e e o motivo de nao existir
	# alocacao por frame depois. Os pools sao dimensionados para o PIOR caso
	# (veiculo mais rapido), nao para o caso medio.
	if _pool_pedacos == null:
		_pool_pedacos = Pool.new(self, func(): return PedacoCenario.new(),
			Config.PEDACOS_MAX + 2, "pedaco")
	if _pool_obstaculos == null:
		_pool_obstaculos = Pool.new(self, func(): return Obstaculo.new(),
			Config.POOL_OBSTACULOS, "obstaculo")


func iniciar(alvo: Node3D, universo: Universo, veiculo: Veiculo) -> void:
	preparar()
	_alvo = alvo
	_universo = universo

	# --- Adaptacao a velocidade do veiculo --------------------------------
	var vel_ms := veiculo.velocidade_cruzeiro * Config.KMH_PARA_MS
	_espacamento = maxf(Config.ESPACAMENTO_MINIMO, vel_ms * Config.TEMPO_MINIMO_ENTRE_FILEIRAS)
	var necessarios := int(ceil(vel_ms * Config.SEGUNDOS_DE_CENARIO / Config.PEDACO_COMPRIMENTO)) + 2
	_pedacos_janela = clampi(necessarios, Config.PEDACOS_ATIVOS, Config.PEDACOS_MAX)

	# --- Reset ------------------------------------------------------------
	for lista in _obstaculos_por_indice.values():
		for o in lista:
			_pool_obstaculos.devolver(o)
	_obstaculos_por_indice.clear()
	for p in _ativos:
		_pool_pedacos.devolver(p)
	_ativos.clear()

	_proximo_indice = 0
	_proximo_z_fileira = -DISTANCIA_LIVRE_INICIO
	for i in _pedacos_janela:
		_criar_proximo()
	_pronto = true


func _process(_delta: float) -> void:
	if not _pronto or _alvo == null:
		return
	var indice_aviao := int(floor(-_alvo.global_position.z / Config.PEDACO_COMPRIMENTO))
	while not _ativos.is_empty() and _ativos[0].indice < indice_aviao - Config.PEDACOS_ATRAS:
		_reciclar_primeiro()
		_criar_proximo()


func _criar_proximo() -> void:
	var p := _pool_pedacos.pegar() as PedacoCenario
	if p == null:
		return
	p.configurar(_proximo_indice, _universo, DISTANCIA_URBANIZACAO)
	_ativos.append(p)
	_povoar_obstaculos(_proximo_indice)
	_proximo_indice += 1


func _reciclar_primeiro() -> void:
	var p: PedacoCenario = _ativos.pop_front()
	var idx := p.indice
	if _obstaculos_por_indice.has(idx):
		for o in _obstaculos_por_indice[idx]:
			_pool_obstaculos.devolver(o)
		_obstaculos_por_indice.erase(idx)
	_pool_pedacos.devolver(p)


## Coloca todas as fileiras cujo z cai dentro deste pedaco. O cursor
## `_proximo_z_fileira` e global, entao o espacamento e respeitado mesmo quando
## ele e maior que um pedaco inteiro (caso dos veiculos supersonicos).
func _povoar_obstaculos(indice: int) -> void:
	var z_inicio := -float(indice) * Config.PEDACO_COMPRIMENTO
	var z_fim := z_inicio - Config.PEDACO_COMPRIMENTO
	var lista: Array[Obstaculo] = []

	while _proximo_z_fileira > z_fim:
		if _proximo_z_fileira <= z_inicio:
			var distancia := -_proximo_z_fileira
			var dificuldade := clampf((distancia - DISTANCIA_LIVRE_INICIO) / 1400.0, 0.0, 1.0)
			# Semente derivada da posicao: a fileira em z = -740 e SEMPRE a
			# mesma. Sem isso, reproduzir um bug de level design vira sorte.
			_rng.seed = hash(int(_proximo_z_fileira * 10.0)) & 0x7FFFFFFF
			_gerar_fileira(_proximo_z_fileira, dificuldade, lista)
		_proximo_z_fileira -= _espacamento

	if not lista.is_empty():
		_obstaculos_por_indice[indice] = lista


func _gerar_fileira(z: float, dificuldade: float, lista: Array[Obstaculo]) -> void:
	match _sortear_tipo(dificuldade):
		Fileira.LATERAL:
			_fileira_lateral(z, dificuldade, lista)
		Fileira.HORIZONTAL:
			_fileira_horizontal(z, lista)
		Fileira.PILARES:
			_fileira_pilares(z, dificuldade, lista)


func _sortear_tipo(dificuldade: float) -> Fileira:
	# No inicio so aparece esquiva lateral. Esquiva vertical e pilares entram
	# depois, quando o jogador ja dominou o controle basico.
	if dificuldade < 0.15:
		return Fileira.LATERAL
	var r := _rng.randf()
	if r < 0.5:
		return Fileira.LATERAL
	if r < 0.8:
		return Fileira.HORIZONTAL
	return Fileira.PILARES


## Duas paredes com uma abertura lateral garantida.
func _fileira_lateral(z: float, dificuldade: float, lista: Array[Obstaculo]) -> void:
	var abertura := lerpf(ABERTURA_LATERAL_BASE, ABERTURA_LATERAL_MIN, dificuldade)
	var limite := Config.CORREDOR_LARGURA - abertura
	var centro := _rng.randf_range(-limite, limite)
	var altura := 26.0
	var espessura := 2.2
	var cor := Color(0.72, 0.28, 0.24)

	var esq_dir := centro - abertura
	var esq_esq := -Config.CORREDOR_LARGURA - PAREDE_EXTENSAO
	if esq_dir > esq_esq:
		_colocar(Obstaculo.Tipo.PAREDE,
			Vector3(esq_dir - esq_esq, altura, espessura),
			Vector3((esq_dir + esq_esq) * 0.5, altura * 0.5 - 1.0, z), cor, lista)

	var dir_esq := centro + abertura
	var dir_dir := Config.CORREDOR_LARGURA + PAREDE_EXTENSAO
	if dir_dir > dir_esq:
		_colocar(Obstaculo.Tipo.PAREDE,
			Vector3(dir_dir - dir_esq, altura, espessura),
			Vector3((dir_dir + dir_esq) * 0.5, altura * 0.5 - 1.0, z), cor, lista)


## Duas lajes com uma faixa horizontal livre: obriga esquiva vertical.
func _fileira_horizontal(z: float, lista: Array[Obstaculo]) -> void:
	var centro := _rng.randf_range(
		Config.CORREDOR_ALTURA_MIN + ABERTURA_HORIZONTAL,
		Config.CORREDOR_ALTURA_MAX - ABERTURA_HORIZONTAL)
	var largura := (Config.CORREDOR_LARGURA + PAREDE_EXTENSAO) * 2.0
	var espessura := 2.0
	var cor := Color(0.85, 0.62, 0.22)

	var topo_base := centro + ABERTURA_HORIZONTAL
	var topo_altura := 30.0
	_colocar(Obstaculo.Tipo.PAREDE, Vector3(largura, topo_altura, espessura),
		Vector3(0.0, topo_base + topo_altura * 0.5, z), cor, lista)

	var baixo_topo := centro - ABERTURA_HORIZONTAL
	if baixo_topo > Config.CORREDOR_ALTURA_MIN - 1.0:
		var h := baixo_topo + 2.0
		_colocar(Obstaculo.Tipo.PAREDE, Vector3(largura, h, espessura),
			Vector3(0.0, baixo_topo - h * 0.5, z), cor, lista)


## Pilares esparsos. Cada um fica em uma faixa distinta, entao nunca se
## agrupam e fecham o corredor.
func _fileira_pilares(z: float, dificuldade: float, lista: Array[Obstaculo]) -> void:
	var quantidade := 2 + int(dificuldade * 2.0)
	var cor := Color(0.35, 0.38, 0.44)
	var faixa := Config.CORREDOR_LARGURA * 2.0 / float(quantidade + 1)
	for i in quantidade:
		var base := -Config.CORREDOR_LARGURA + faixa * float(i + 1)
		var x := base + _rng.randf_range(-faixa * 0.22, faixa * 0.22)
		var largura := _rng.randf_range(1.1, 1.9)
		_colocar(Obstaculo.Tipo.PILAR, Vector3(largura, 34.0, largura),
			Vector3(x, 12.0, z + _rng.randf_range(-3.0, 3.0)), cor, lista)


func _colocar(tipo: Obstaculo.Tipo, tam: Vector3, pos: Vector3, cor: Color, lista: Array[Obstaculo]) -> void:
	var o := _pool_obstaculos.pegar() as Obstaculo
	if o == null:
		return
	o.configurar(tipo, tam, cor, pos)
	lista.append(o)


func encerrar() -> void:
	_pronto = false


# --- Telemetria para o monitor de desempenho ------------------------------

func obstaculos_ativos() -> int:
	return _pool_obstaculos.total_ativos() if _pool_obstaculos != null else 0


func pedacos_ativos() -> int:
	return _ativos.size()


func pedacos_alvo() -> int:
	return _pedacos_janela


func espacamento_fileiras() -> float:
	return _espacamento

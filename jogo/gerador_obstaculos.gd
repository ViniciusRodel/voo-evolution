class_name GeradorObstaculos
extends Node3D
## Geracao e streaming de obstaculos de esquiva ao longo do corredor de voo.
##
## V8 (P2 do roadmap - briefing_ajustes_v8.md): reativa a logica de
## jogo/gerador_pista.gd (existia pronta, nunca foi instanciada por
## cenas/principal.gd), adaptada para o Aviao/DadosJogo atuais:
##  - velocidade de referencia vem de DadosJogo.v_cruzeiro() (m/s direto, ja
##    inclui a trilha AVIAO), nao mais de Veiculo.velocidade_cruzeiro * um
##    fator km/h->m/s que so fazia sentido quando o campo era km/h;
##  - a altura de cada fileira e relativa a Terreno.altura() no z da fileira,
##    porque o terreno ondula de verdade desde o v3 - gerador_pista.gd
##    assumia chao plano (universo/pedaco de cenario proprios, com um bloco
##    de chao fixo, que NAO sao reaproveitados aqui de proposito: rodar os
##    dois sistemas de chao juntos duplicaria a superficie de colisao contra
##    Terreno.altura());
##  - a rampa de dificuldade e proporcional a meta da FASE atual, nao um
##    valor absoluto fixo (as metas variam de ~1.250 m a ~15.000 m entre
##    fases, um numero fixo deixaria fases curtas dificeis demais cedo ou
##    fases longas faceis demais por perto demais do tempo todo).
##
## Roda em paralelo com GeradorMundo (chao + decoracao + termicas) - os dois
## streamam de forma independente sobre a mesma posicao do Aviao.
##
## DUAS REGRAS QUE NAO PODEM SER QUEBRADAS (herdadas de gerador_pista.gd):
## 1. Toda fileira tem uma abertura garantida - nunca existe configuracao
##    impossivel. Se o jogador bateu, foi reacao dele.
## 2. O espacamento entre fileiras e medido em TEMPO, nao em metros - um
##    aviao mais rapido recebe fileiras mais distantes, pra manter a mesma
##    janela de reacao em qualquer fase.

enum Fileira { LATERAL, HORIZONTAL, PILARES }

## Metros iniciais sem nenhum obstaculo, para o jogador se ambientar.
const DISTANCIA_LIVRE_INICIO := 140.0
## Segundos de reacao minimos entre fileiras, na velocidade de cruzeiro atual.
const TEMPO_MINIMO_ENTRE_FILEIRAS := 1.8
const ESPACAMENTO_MINIMO := 90.0
const ABERTURA_LATERAL_BASE := 3.6
const ABERTURA_LATERAL_MIN := 2.3
const ABERTURA_VERTICAL := 3.0
const PAREDE_EXTENSAO := 16.0
const ALTURA_MIN_FILEIRA := 6.0
const ALTURA_MAX_FILEIRA := 46.0
## Quantos pedacos de PEDACO_COMPRIMENTO manter povoados a frente - mesmo
## alcance de streaming do terreno (Config.PEDACOS_MAX), pra nunca gerar
## fileira mais perto do aviao do que o terreno ja visivel.
const JANELA_PEDACOS := Config.PEDACOS_MAX

## Metadados das fileiras ativas (nao so os nos Obstaculo) - usado pelo
## piloto automatico para esquivar de verdade (ver testes/piloto_automatico.gd),
## ja que sem isso a mira lateral do piloto ficava sempre no centro (x=0) e
## batia na maioria das fileiras LATERAL, que abrem em um x aleatorio.
class Fileira_Info:
	var tipo: Fileira
	var z: float
	var centro_abertura: float
	func _init(t: Fileira, zz: float, c: float) -> void:
		tipo = t; z = zz; centro_abertura = c

var _fileiras: Array[Fileira_Info] = []
var _pool: Pool = null
var _obstaculos_por_indice: Dictionary = {}
var _aviao: Aviao = null
var _rng := RandomNumberGenerator.new()
var _pronto := false

var _espacamento: float = ESPACAMENTO_MINIMO
var _distancia_rampa: float = 1400.0
var _proximo_z_fileira: float = 0.0


func preparar() -> void:
	if _pool == null:
		_pool = Pool.new(self, func(): return Obstaculo.new(), Config.POOL_OBSTACULOS, "obstaculo")


func iniciar(aviao: Aviao) -> void:
	preparar()
	_aviao = aviao

	for lista in _obstaculos_por_indice.values():
		for o in lista:
			_pool.devolver(o)
	_obstaculos_por_indice.clear()
	_fileiras.clear()

	var v := DadosJogo.v_cruzeiro()
	_espacamento = maxf(ESPACAMENTO_MINIMO, v * TEMPO_MINIMO_ENTRE_FILEIRAS)
	_distancia_rampa = maxf(300.0, Config.meta_da_fase(DadosJogo.fase_selecionada) * 0.4)

	# Semente fixa: a fileira em z = -740 e SEMPRE a mesma. Sem isso,
	# reproduzir um bug de level design vira sorte.
	_rng.seed = 42

	# V9/P5: fases com vinheta desenhada a mao (briefing_ajustes_v9.md P5,
	# jogo/cenario_fixo.gd) povoam o trecho fixo primeiro; a geracao
	# procedural normal so comeca DEPOIS do fim da vinheta ("o aviao sai
	# novamente para o exterior"). Fases sem vinheta continuam 100%
	# proceduais desde o metro 0, como sempre.
	var vinheta: Array = CenarioFixo.vinhetas().get(DadosJogo.fase_selecionada, [])
	if not vinheta.is_empty():
		_povoar_vinheta(vinheta)
		_proximo_z_fileira = -CenarioFixo.fim_da_vinheta(DadosJogo.fase_selecionada)
	else:
		_proximo_z_fileira = -DISTANCIA_LIVRE_INICIO

	_povoar_ate(-Config.PEDACO_COMPRIMENTO * float(JANELA_PEDACOS))
	_pronto = true


## `pos.y` de cada definicao em CenarioFixo e ALTURA ACIMA DO TERRENO local,
## nao y absoluto - mesma convencao das fileiras proceduais (_fileira_*
## abaixo), pra um obstaculo fixo nunca flutuar ou afundar se o relevo
## naquele trecho nao for perfeitamente plano.
func _povoar_vinheta(vinheta: Array) -> void:
	for def in vinheta:
		var d: Dictionary = def
		var pos: Vector3 = (d["pos"] as Vector3)
		pos.y += Terreno.altura(pos.x, pos.z)
		var indice := int(floor(-pos.z / Config.PEDACO_COMPRIMENTO))
		var lista: Array = _obstaculos_por_indice.get(indice, [])
		_colocar(d["tipo"], d["tamanho"], pos, d["cor"], lista)
		_obstaculos_por_indice[indice] = lista


func _process(_delta: float) -> void:
	if not _pronto or _aviao == null:
		return
	var z := _aviao.position.z
	_povoar_ate(z - Config.PEDACO_COMPRIMENTO * float(JANELA_PEDACOS))
	_reciclar_atras(z)


func _povoar_ate(z_limite: float) -> void:
	while _proximo_z_fileira > z_limite:
		var distancia := -_proximo_z_fileira
		var dificuldade := clampf(
			(distancia - DISTANCIA_LIVRE_INICIO) / _distancia_rampa, 0.0, 1.0)
		_rng.seed = hash(int(_proximo_z_fileira * 10.0)) & 0x7FFFFFFF
		var indice := int(floor(distancia / Config.PEDACO_COMPRIMENTO))
		var lista: Array = _obstaculos_por_indice.get(indice, [])
		_gerar_fileira(_proximo_z_fileira, dificuldade, lista)
		_obstaculos_por_indice[indice] = lista
		_proximo_z_fileira -= _espacamento


func _reciclar_atras(z_aviao: float) -> void:
	var limite := int(floor(-z_aviao / Config.PEDACO_COMPRIMENTO)) - JANELA_PEDACOS
	var indices_para_remover: Array = []
	for indice in _obstaculos_por_indice:
		if indice < limite:
			indices_para_remover.append(indice)
	for indice in indices_para_remover:
		for o in _obstaculos_por_indice[indice]:
			_pool.devolver(o)
		_obstaculos_por_indice.erase(indice)
	# _fileiras e adicionada sempre em z decrescente (cada nova fileira mais a
	# frente que a anterior), entao o mais antigo (indice 0) e sempre o
	# primeiro a ficar pra tras do aviao.
	while not _fileiras.is_empty() and _fileiras[0].z > z_aviao + 50.0:
		_fileiras.pop_front()


func _gerar_fileira(z: float, dificuldade: float, lista: Array) -> void:
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
func _fileira_lateral(z: float, dificuldade: float, lista: Array) -> void:
	var abertura := lerpf(ABERTURA_LATERAL_BASE, ABERTURA_LATERAL_MIN, dificuldade)
	var limite := Config.CORREDOR_LARGURA - abertura
	var centro := _rng.randf_range(-limite, limite)
	var base_y := Terreno.altura(0.0, z)
	var altura := 30.0
	var espessura := 2.2
	var cor := Color(0.72, 0.28, 0.24)

	var esq_dir := centro - abertura
	var esq_esq := -Config.CORREDOR_LARGURA - PAREDE_EXTENSAO
	if esq_dir > esq_esq:
		_colocar(Obstaculo.Tipo.PAREDE,
			Vector3(esq_dir - esq_esq, altura, espessura),
			Vector3((esq_dir + esq_esq) * 0.5, base_y + altura * 0.5 - 1.0, z), cor, lista)

	var dir_esq := centro + abertura
	var dir_dir := Config.CORREDOR_LARGURA + PAREDE_EXTENSAO
	if dir_dir > dir_esq:
		_colocar(Obstaculo.Tipo.PAREDE,
			Vector3(dir_dir - dir_esq, altura, espessura),
			Vector3((dir_dir + dir_esq) * 0.5, base_y + altura * 0.5 - 1.0, z), cor, lista)

	_fileiras.append(Fileira_Info.new(Fileira.LATERAL, z, centro))


## Duas lajes com uma faixa horizontal livre: obriga esquiva vertical.
func _fileira_horizontal(z: float, lista: Array) -> void:
	var base_y := Terreno.altura(0.0, z)
	var centro := _rng.randf_range(
		ALTURA_MIN_FILEIRA + ABERTURA_VERTICAL, ALTURA_MAX_FILEIRA - ABERTURA_VERTICAL)
	var largura := (Config.CORREDOR_LARGURA + PAREDE_EXTENSAO) * 2.0
	var espessura := 2.0
	var cor := Color(0.85, 0.62, 0.22)

	var topo_base := centro + ABERTURA_VERTICAL
	var topo_altura := 34.0
	_colocar(Obstaculo.Tipo.PAREDE, Vector3(largura, topo_altura, espessura),
		Vector3(0.0, base_y + topo_base + topo_altura * 0.5, z), cor, lista)

	var baixo_topo := centro - ABERTURA_VERTICAL
	if baixo_topo > ALTURA_MIN_FILEIRA - 2.0:
		var h := baixo_topo + 2.0
		_colocar(Obstaculo.Tipo.PAREDE, Vector3(largura, h, espessura),
			Vector3(0.0, base_y + baixo_topo - h * 0.5, z), cor, lista)

	# Sem alvo lateral - a esquiva aqui e vertical, o piloto so precisa se
	# manter na faixa de altura livre (ver testes/piloto_automatico.gd).
	_fileiras.append(Fileira_Info.new(Fileira.HORIZONTAL, z, 0.0))


## Pilares esparsos. Cada um fica em uma faixa distinta, entao nunca se
## agrupam e fecham o corredor.
func _fileira_pilares(z: float, dificuldade: float, lista: Array) -> void:
	var base_y := Terreno.altura(0.0, z)
	var quantidade := 2 + int(dificuldade * 2.0)
	var cor := Color(0.35, 0.38, 0.44)
	var faixa := Config.CORREDOR_LARGURA * 2.0 / float(quantidade + 1)
	for i in quantidade:
		var base := -Config.CORREDOR_LARGURA + faixa * float(i + 1)
		var x := base + _rng.randf_range(-faixa * 0.22, faixa * 0.22)
		var largura := _rng.randf_range(1.1, 1.9)
		_colocar(Obstaculo.Tipo.PILAR, Vector3(largura, 40.0, largura),
			Vector3(x, base_y + 14.0, z + _rng.randf_range(-3.0, 3.0)), cor, lista)

	_fileiras.append(Fileira_Info.new(Fileira.PILARES, z, 0.0))


func _colocar(tipo: Obstaculo.Tipo, tam: Vector3, pos: Vector3, cor: Color, lista: Array) -> void:
	var o := _pool.pegar() as Obstaculo
	if o == null:
		return
	o.configurar(tipo, tam, cor, pos)
	lista.append(o)


func encerrar() -> void:
	_pronto = false


## Fileira LATERAL mais proxima a frente de `z_aviao`, dentro de `alcance`
## metros - usado pelo piloto automatico para esquivar de verdade. Devolve
## null se nenhuma fileira lateral estiver na janela.
func fileira_lateral_mais_proxima(z_aviao: float, alcance: float) -> Variant:
	var melhor: Fileira_Info = null
	var melhor_dist := INF
	for f in _fileiras:
		if f.tipo != Fileira.LATERAL:
			continue
		var a_frente := z_aviao - f.z
		if a_frente < 0.0 or a_frente > alcance:
			continue
		if a_frente < melhor_dist:
			melhor_dist = a_frente
			melhor = f
	return melhor


func obstaculos_ativos() -> int:
	return _pool.total_ativos() if _pool != null else 0


## Obstaculo ativo mais proximo a frente de z_aviao, dentro de `alcance` -
## QUALQUER tipo, nao so fileiras LATERAL puras. Usado pelo piloto
## automatico como fallback generico pra pelo menos tentar desviar de
## vinhetas fixas (CenarioFixo) - cadeiras/banheira nao tem um "centro de
## abertura" como as fileiras proceduais. Devolve null se nada na janela.
func obstaculo_mais_proximo(z_aviao: float, alcance: float) -> Obstaculo:
	var melhor: Obstaculo = null
	var melhor_dist := INF
	for lista in _obstaculos_por_indice.values():
		for o in lista:
			var obstaculo := o as Obstaculo
			var a_frente := z_aviao - obstaculo.position.z
			if a_frente < 0.0 or a_frente > alcance:
				continue
			if a_frente < melhor_dist:
				melhor_dist = a_frente
				melhor = obstaculo
	return melhor

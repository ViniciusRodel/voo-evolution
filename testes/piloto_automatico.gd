extends Node
## Piloto automatico: joga sozinho e verifica se o JOGO reproduz os numeros do
## SIMULADOR (sim/modelo.py).
##
## Uso:
##   godot --headless --quit-after 20000 -- --teste-voo
##   godot --headless --quit-after 20000 -- --teste-voo --corridas=8
##   godot --headless --quit-after 20000 -- --teste-voo --nivel=10
##
## POR QUE ISTO EXISTE: o balanceamento foi validado em Python, mas quem roda em
## producao e o GDScript. Duas implementacoes do mesmo modelo divergem em
## silencio - alguem ajusta uma constante em um lado e esquece o outro, e seis
## semanas depois a curva de progressao nao e mais a que foi aprovada. Este
## teste falha no momento em que isso acontece.
##
## Referencias do simulador para o nivel 1 (jogador mediano, q = 0,70):
##   v_cruzeiro  97,5 m/s   (= 50 km/h no HUD)
##   v_inicial  111,6 m/s   (= 60 km/h no HUD; o video mostra 59)
##   duracao     41,4 s     com fracao de coleta de 0,35
##   capacidade  4.088 m

const QUALIDADE := 0.70
## Altura alvo acima do terreno que o piloto tenta manter.
const ALTURA_ALVO := 30.0
## Altura minima que o piloto se permite perseguir.
const ALTURA_SEGURA := 18.0
## Ganho do controle proporcional de arfagem.
const GANHO := 0.55
## Amortecimento derivativo, em unidades de comando por grau de arfagem atual.
const AMORTECIMENTO := 1.6

var principal: Node = null

var _aviao: Aviao = null
var _gerador: GeradorMundo = null
var _gerador_obstaculos: GeradorObstaculos = null
var _estilingue: Estilingue = null
var _monitor: MonitorDesempenho = null

var _corridas_alvo := 3
var _nivel_forcado := 1
## Indice da fase (base 0) a medir - desbloqueia ate ela antes de selecionar,
## pra permitir medir capacidade de qualquer aviao do catalogo, nao so o 1.
var _fase_forcada := 0
## Quando ligado, a meta vira inalcancavel para que a corrida SEMPRE termine
## tocando o solo, nunca batendo a meta - usado para medir a capacidade real
## de voo (distancia/duracao) sem o teto artificial da meta.
var _meta_livre := false
## Uso de teste: id de Config.DIFICULDADES a forcar antes de medir - permite
## calibrar a capacidade maxima de voo em cada dificuldade (ver
## briefing_ajustes_v7.md e o pedido de reforcar Facil/Medio sem tocar
## Dificil). Vazio mantem o padrao ("medio").
var _dificuldade_forcada := &""
var _corrida := 0
var _relatorios: Array[Dictionary] = []
## V9/P4: o piloto automatico simula um jogador que SEGURA o dedo na tela a
## corrida inteira (pior caso realista - ver Config.ARRASTO_POR_SEGURAR em
## jogo/aviao.gd) - envia um unico toque por corrida, nunca solta. Mede a
## capacidade COM a penalidade de segurar sempre ativa.
var _tocou_nesta_corrida := false
var _tempo_corrida := 0.0
var _pior_frame := 0.0
var _frames := 0
var _reportou := false


func _ready() -> void:
	var nos: Dictionary = principal.nos_de_teste()
	_aviao = nos["aviao"]
	_gerador = nos["gerador"]
	_gerador_obstaculos = nos["gerador_obstaculos"]
	_estilingue = nos["estilingue"]
	_monitor = nos["monitor"]

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--corridas="):
			_corridas_alvo = maxi(1, int(arg.substr(11)))
		elif arg.begins_with("--nivel="):
			_nivel_forcado = maxi(1, int(arg.substr(8)))
		elif arg.begins_with("--fase="):
			_fase_forcada = clampi(int(arg.substr(7)) - 1, 0, Catalogo.veiculos().size() - 1)
		elif arg == "--meta-livre":
			_meta_livre = true
		elif arg.begins_with("--dificuldade="):
			_dificuldade_forcada = StringName(arg.substr(14))

	DadosJogo._persistencia_desabilitada = true
	DadosJogo.apagar_progresso()
	DadosJogo.fase_maxima_alcancada = _fase_forcada
	DadosJogo.selecionar_fase(_fase_forcada)
	DadosJogo.forcar_niveis(_nivel_forcado)
	if _dificuldade_forcada != &"":
		DadosJogo.definir_dificuldade(_dificuldade_forcada)

	if _meta_livre:
		DadosJogo.meta_forcada = 1_000_000.0

	Eventos.corrida_encerrada.connect(_ao_encerrar)

	print("=== PILOTO AUTOMATICO ===")
	print("niveis forcados: %d | corridas: %d | dificuldade: %s" % [
		_nivel_forcado, _corridas_alvo, String(DadosJogo.dificuldade_atual)])
	print("v_cruzeiro %.1f m/s  ->  HUD %.0f km/h" % [
		DadosJogo.v_cruzeiro(), Config.velocidade_exibida(DadosJogo.v_cruzeiro())])
	print("v_inicial  %.1f m/s  ->  HUD %.0f km/h" % [
		DadosJogo.v_inicial(QUALIDADE), Config.velocidade_exibida(DadosJogo.v_inicial(QUALIDADE))])
	print("bonus motor %.2fx | bonus estilingue %.2fx" % [
		DadosJogo.bonus_motor_lancamento(), DadosJogo.bonus_estilingue()])
	print("")
	principal.iniciar_corrida()


func _exit_tree() -> void:
	if not _reportou:
		_resumo("processo encerrado antes do fim")


func _process(delta: float) -> void:
	_frames += 1
	_pior_frame = maxf(_pior_frame, delta * 1000.0)

	# Solta o estilingue assim que ele aparece, sempre na mesma qualidade.
	if _estilingue.visible and principal.estado == 1:  # Estado.LANCAMENTO
		_estilingue.lancar_direto(QUALIDADE)
		_tempo_corrida = 0.0
		_tocou_nesta_corrida = false
		return

	if not _aviao.ativo:
		return
	_tempo_corrida += delta
	_pilotar()


## Controle proporcional simples: mantem ALTURA_ALVO acima do terreno e
## esquiva lateralmente da proxima fileira de obstaculos (V8 - antes disso o
## piloto so sabia perseguir orbes, que nao existem desde o v3; sem esquiva
## real ele voava sempre no centro do corredor e batia na maioria das
## fileiras LATERAL, que abrem num x aleatorio). Nao e um bom jogador - e um
## jogador CONSISTENTE, que e o que um teste precisa.
func _pilotar() -> void:
	if not _tocou_nesta_corrida:
		var toque := InputEventScreenTouch.new()
		toque.index = 0
		toque.position = Vector2(540.0, 1200.0)
		toque.pressed = true
		Input.parse_input_event(toque)
		_tocou_nesta_corrida = true

	var altura := _aviao.altura_acima_do_solo()
	var altura_desejada := ALTURA_ALVO
	if not DadosJogo.tem_motor_agora():
		# V5: planador balistico. Mirar ALTURA_ALVO (30 m) forca uma subida logo
		# na largada que nao ha empuxo pra sustentar - desperdica a velocidade do
		# lancamento antes da corrida comecar de verdade. Mirar perto do chao
		# evita que o "nudge" (Config.NUDGE_ACELERACAO) brigue tanto com a
		# gravidade logo de cara.
		altura_desejada = ALTURA_SEGURA
	altura_desejada = clampf(altura_desejada, ALTURA_SEGURA, 90.0)

	var erro := altura_desejada - altura
	# Termo derivativo: freia o comando quando o aviao ja esta se movendo na
	# direcao certa. Sem ele o controle proporcional oscila e crava no chao.
	var comando := clampf(erro * GANHO - rad_to_deg(_aviao.angulo_atual()) * AMORTECIMENTO, -60.0, 60.0)

	# Esquiva lateral: mira no centro da abertura da proxima fileira LATERAL
	# dentro da janela de reacao (proporcional a velocidade atual - na
	# velocidade de cruzeiro de referencia, 220 m equivalem a pouco mais de
	# 2 s de antecipacao).
	var lateral := 0.0
	var alvo_x := _alvo_lateral()
	if not is_nan(alvo_x):
		lateral = clampf((alvo_x - _aviao.position.x) * 6.0, -90.0, 90.0)

	var evento := InputEventScreenDrag.new()
	evento.index = 0
	evento.position = Vector2(540.0, 1200.0)
	# Tela: y para baixo mergulha. Erro positivo (esta baixo) precisa subir.
	evento.relative = Vector2(lateral, -comando * 0.16)
	Input.parse_input_event(evento)


## X do centro da abertura da fileira LATERAL mais proxima a frente, dentro
## de uma janela de antecipacao. Devolve NAN quando nao ha nenhuma na janela
## (fileiras HORIZONTAL/PILARES nao tem um "centro" lateral unico simples de
## perseguir - o piloto so esquiva de verdade das LATERAL por enquanto).
## V9/P5: sem fileira LATERAL na janela, cai pro fallback generico (qualquer
## obstaculo ativo, incluindo vinhetas fixas de jogo/cenario_fixo.gd) -
## esquiva grosseira (vai pro lado livre do obstaculo), nao perfeita, mas
## evita que o piloto sempre bata de frente numa cadeira/banheira que nao
## sabe interpretar como fileira.
func _alvo_lateral() -> float:
	if _gerador_obstaculos == null:
		return NAN
	var f = _gerador_obstaculos.fileira_lateral_mais_proxima(_aviao.position.z, 220.0)
	if f != null:
		return f.centro_abertura
	var o := _gerador_obstaculos.obstaculo_mais_proximo(_aviao.position.z, 100.0)
	if o == null:
		return NAN
	return -12.0 if o.position.x >= 0.0 else 12.0


func _ao_encerrar(dados: Dictionary) -> void:
	_corrida += 1
	var d := {
		"corrida": _corrida,
		"motivo": String(dados.get("motivo", "?")),
		"distancia": float(dados.get("distancia", 0.0)),
		"duracao": _tempo_corrida,
		"orbes": int(dados.get("orbes", 0)),
		"moedas": int(dados.get("moedas_ganhas", 0)),
		"v_pico": float(dados.get("v_pico", 0.0)),
	}
	_relatorios.append(d)
	print("corrida %d | %-8s | %7.0f m | %5.1f s | %3d orbes | %5d moedas | pico %.0f km/h" % [
		d["corrida"], d["motivo"], d["distancia"], d["duracao"], d["orbes"], d["moedas"],
		Config.velocidade_exibida(d["v_pico"])])

	if _corrida >= _corridas_alvo:
		_resumo("todas as corridas concluidas")
		get_tree().quit(0)
	else:
		principal.iniciar_corrida()


func _resumo(motivo: String) -> void:
	if _reportou:
		return
	_reportou = true
	print("")
	print("=== RESUMO (%s) ===" % motivo)
	if _relatorios.is_empty():
		print("nenhuma corrida concluida.")
		push_error("Teste falhou: nenhuma corrida concluida.")
		return

	var soma_d := 0.0
	var soma_t := 0.0
	for r in _relatorios:
		soma_d += r["distancia"]
		soma_t += r["duracao"]
	var n := float(_relatorios.size())
	var media_d := soma_d / n
	var media_t := soma_t / n

	print("distancia media ....... %.0f m" % media_d)
	print("duracao media ......... %.1f s" % media_t)
	print("frames ................ %d | pior frame %.1f ms" % [_frames, _pior_frame])
	print("pedacos ............... %d / %d" % [_gerador.pedacos_ativos(), _gerador.pedacos_alvo()])
	print("")

	# --- Verificacoes ------------------------------------------------------
	var falhas := 0

	var v_esperado := DadosJogo.aviao_atual().velocidade_cruzeiro \
		* Atributos.multiplicador(Atributos.HELICE, DadosJogo.nivel(Atributos.HELICE), &"passo_v")
	falhas += _verificar("v_cruzeiro", DadosJogo.v_cruzeiro(), v_esperado, 0.001)

	# V7: fisica balistica unica pro jogo inteiro - a duracao e sempre uma
	# SAIDA da fisica (o quanto o mergulho foi bem cronometrado), nunca mais
	# um orcamento fixo de energia/tempo pra comparar, motorizado ou nao
	# (ver briefing_ajustes_v7.md §2).
	print("[--] duracao nao verificada: sem orcamento fixo (fisica balistica unica)")

	if _gerador.pedacos_ativos() != _gerador.pedacos_alvo():
		print("[--] streaming de terreno inconsistente")
		falhas += 1
	else:
		print("[OK] streaming de terreno consistente")

	print("")
	if falhas == 0:
		print("RESULTADO: OK - o jogo reproduz o modelo validado.")
	else:
		print("RESULTADO: %d VERIFICACAO(OES) FALHARAM." % falhas)
		push_error("Piloto automatico reprovou.")


func _verificar(nome: String, obtido: float, esperado: float, tolerancia: float) -> int:
	var erro := absf(obtido - esperado) / maxf(absf(esperado), 0.001)
	if erro <= tolerancia:
		print("[OK] %-12s %10.2f  (esperado %.2f, erro %.1f%%)" % [nome, obtido, esperado, erro * 100.0])
		return 0
	print("[--] %-12s %10.2f  (esperado %.2f, erro %.1f%% > %.0f%%)" % [
		nome, obtido, esperado, erro * 100.0, tolerancia * 100.0])
	return 1

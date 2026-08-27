class_name Aviao
extends Node3D
## O aviao do jogador. UM modelo de voo so (v7) - projetil balistico
## (Worms/Gunbound): o estado real e um vetor de velocidade (vx, vy), a
## gravidade sempre reduz vy, o arrasto sempre freia, e o angulo do modelo
## (`atan2(vy, vx)`) e CONSEQUENCIA da velocidade, nunca comando do jogador.
## Isso produz a curva em U invertido (sobe, atinge o pico, cai), e o nariz
## sempre aponta pra onde o aviao esta realmente indo - inclinando pra baixo
## conforme perde sustentacao, em QUALQUER nivel de evolucao, do Aviao de
## Papel ate o mais avancado.
##
## V7: o motor NAO sustenta voo mais - virou um bonus no LANCAMENTO
## (`DadosJogo.v_inicial()`, via `bonus_motor_lancamento()`), do mesmo jeito
## que o Estilingue ja e. Nao existe um segundo modelo de fisica "motorizado"
## pra substituir este quando o aviao termina de ser construido - mergulhar
## pra ganhar velocidade continua sendo a decisao central do jogo sempre.
## `energia`/tanque tambem saiu: sem empuxo sustentado em voo, nao ha mais o
## que consumir - a corrida so termina tocando o solo ou batendo a meta.
## Ver briefing_ajustes_v5.md, v6.md e v7.md.
##
## A colisao com o solo e um teste analitico contra Terreno.altura(). Custo de
## fisica por frame: zero. A colisao com OBSTACULOS (V8, ver
## jogo/gerador_obstaculos.gd) e a unica coisa aqui que usa fisica de
## verdade - um Area3D pequeno, so pra deteccao (nao ha resposta fisica,
## nunca ha empurrao/quique), monitorando a camada 2 (Obstaculo.collision_layer).
## Escolhido por ser barato (um teste de overlap, nao um RigidBody simulado) e
## por reusar exatamente o layer que jogo/obstaculo.gd ja expunha havia tempo,
## sem uso.

signal encerrou(motivo: String)

const GRUPO := &"aviao"
## Camada de colisao dos obstaculos (jogo/obstaculo.gd) - o detector do aviao
## usa isto como collision_mask.
const CAMADA_OBSTACULOS := 2

var ativo: bool = false

# --- estado --------------------------------------------------------------
var vx: float = 0.0                # m/s, componente horizontal (para frente)
var vy: float = 0.0                # m/s, componente vertical
var distancia: float = 0.0
var v_pico: float = 0.0
## V8: nome historico ("tocou o solo"), mas agora tambem marca colisao com
## obstaculo - o unico uso deste campo e "a corrida terminou suja" (nao
## conta pro bonus de voo limpo em DadosJogo.registrar_corrida()).
var tocou_solo: bool = false

var _angulo_alvo: float = 0.0
var _lateral_alvo: float = 0.0
var _arraste := Vector2.ZERO
## V9/P4: dedo na tela AGORA (independente de estar arrastando ou nao) - ver
## briefing_ajustes_v9.md P4. Enquanto pressionado, `_integrar()` cobra um
## arrasto extra (Config.ARRASTO_POR_SEGURAR): segurar custa velocidade, so
## toques/arrastes curtos sao "de graca".
var _dedo_pressionado: bool = false
var _impulso_ativo := false
var _impulso_restante := 0.0
var _recarga_restante := 0.0
## Usos restantes de impulso nesta corrida (ver Config.IMPULSO_USOS_POR_CORRIDA).
## Sem tanque de energia, o impulso e sempre por usos fixos, nunca recarga
## contra um recurso que nao existe mais.
var _usos_impulso_restantes := 0
var _dentro_termica := false
var _meta: float = 0.0
var _modelo: Node3D = null
var _detector: Area3D = null


func _ready() -> void:
	add_to_group(GRUPO)
	set_process_unhandled_input(true)
	_criar_detector()


func _criar_detector() -> void:
	_detector = Area3D.new()
	_detector.collision_layer = 0
	_detector.collision_mask = CAMADA_OBSTACULOS
	_detector.monitoring = true
	_detector.monitorable = false
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	# Caixa aproximada do aviao (nunca exata - o modelo procedural muda por
	# nivel/aviao, e colisao pixel-perfect custaria mais do que vale aqui).
	caixa.size = Vector3(3.2, 1.4, 4.6)
	forma.shape = caixa
	_detector.add_child(forma)
	add_child(_detector)
	_detector.area_entered.connect(_ao_colidir_obstaculo)


func _ao_colidir_obstaculo(_area: Area3D) -> void:
	if not ativo:
		return
	ativo = false
	tocou_solo = true
	Eventos.solo_tocado.emit(global_position)
	encerrou.emit("obstaculo")


func preparar(meta: float) -> void:
	_meta = meta
	if _modelo != null:
		_modelo.queue_free()
	_modelo = FabricaModelos.criar(DadosJogo.aviao_atual(), DadosJogo.nivel_visual(),
		false, DadosJogo.pecas_visuais())
	add_child(_modelo)

	vx = 0.0
	vy = 0.0
	distancia = 0.0
	v_pico = 0.0
	_angulo_alvo = 0.0
	_lateral_alvo = 0.0
	_arraste = Vector2.ZERO
	_dedo_pressionado = false
	_impulso_ativo = false
	_impulso_restante = 0.0
	_recarga_restante = 0.0
	_usos_impulso_restantes = Config.IMPULSO_USOS_POR_CORRIDA
	tocou_solo = false
	ativo = false

	position = Vector3(0.0, Terreno.altura(0.0, 0.0) + 14.0, 0.0)
	rotation = Vector3.ZERO


## Puxao visual do estilingue enquanto o medidor carrega. So move o modelo
## (filho de Aviao), nunca `position`/velocidade reais - o aviao so existe de
## verdade a partir de lancar(). Devolve a posicao mundial da cauda, para o
## elastico em jogo/estilingue_visual.gd saber ate onde esticar.
func ajustar_preparacao(tensao: float, mira: float) -> Vector3:
	if _modelo == null:
		return global_position
	var t := clampf(tensao, 0.0, 1.0)
	var m := clampf(mira, -1.0, 1.0)
	_modelo.position = Vector3(
		m * Config.PUXAO_LATERAL_MAXIMO, 0.0, t * Config.PUXAO_TRAS_MAXIMO)
	_modelo.rotation.x = deg_to_rad(Config.PUXAO_INCLINACAO_MAXIMA) * t
	return _modelo.global_position


## `lateral` vem da mira do estilingue (-1 esquerda a 1 direita) e define onde
## no corredor o aviao nasce - efeito real sobre a rota, nao cosmetico. E
## ortogonal ao modelo de distancia (so desloca `x`, nunca a velocidade), entao
## nao precisa ser recalibrado no simulador em sim/modelo.py.
func lancar(qualidade: float, lateral: float = 0.0) -> void:
	var v_inicial := DadosJogo.v_inicial(qualidade)
	# Angulo de saida de verdade, pra formar o arco em U invertido - a 6 graus
	# (angulo raso do modelo antigo) o pico chega em fracao de segundo e o
	# "voo" mal existe. 35 graus da tempo pra gravidade agir
	# (Config.GRAVIDADE_BALISTICA) antes do pico.
	var angulo_lancamento := deg_to_rad(35.0)
	vx = v_inicial * cos(angulo_lancamento)
	vy = v_inicial * sin(angulo_lancamento)
	_angulo_alvo = 0.0
	_lateral_alvo = clampf(lateral, -1.0, 1.0) * Config.CORREDOR_LARGURA
	if _modelo != null:
		_modelo.position = Vector3.ZERO
		_modelo.rotation = Vector3.ZERO
	ativo = true
	Eventos.voo_iniciado.emit()


func _unhandled_input(evento: InputEvent) -> void:
	if not ativo:
		return
	if evento is InputEventScreenDrag:
		_arraste += (evento as InputEventScreenDrag).relative
	elif evento is InputEventScreenTouch:
		_dedo_pressionado = (evento as InputEventScreenTouch).pressed
	elif evento.is_action_pressed(&"impulso"):
		acionar_impulso()


func _process(delta: float) -> void:
	if not ativo:
		return

	_aplicar_arraste(delta)
	_atualizar_impulso(delta)
	_integrar(delta)
	position.x = lerpf(position.x, _lateral_alvo,
		clampf(Config.SUAVIZACAO_LATERAL * delta, 0.0, 1.0))
	_limitar_teto()
	_orientar(delta)
	_verificar_fim()

	Eventos.velocidade_alterada.emit(velocidade_atual())
	Eventos.distancia_alterada.emit(distancia)


func velocidade_atual() -> float:
	return Vector2(vx, vy).length()


## Angulo (rad) usado pra orientar o modelo visualmente - a direcao real do
## vetor de velocidade, CONSEQUENCIA do movimento, nunca comando direto do
## jogador (ver cabecalho da classe).
func angulo_atual() -> float:
	return atan2(vy, vx)


func _aplicar_arraste(delta: float) -> void:
	if _arraste == Vector2.ZERO:
		# V9/P4: sem arraste novo neste frame, o "nudge" decai de volta a
		# zero - um toque vira um AJUSTE PONTUAL que se apaga sozinho, nao um
		# comando permanente que so muda com outro toque na direcao oposta.
		# Ver briefing_ajustes_v9.md P4 (pesquisa_epic_plane_evolution.md §3:
		# "swipe rapido, nao segurar").
		_angulo_alvo = move_toward(_angulo_alvo, 0.0, deg_to_rad(Config.DECAIMENTO_ANGULO_GRAUS) * delta)
		return
	# Tela: y cresce para baixo. Arrastar para baixo deve mergulhar.
	_angulo_alvo -= deg_to_rad(_arraste.y * Config.SENSIBILIDADE_ARRASTE)
	_lateral_alvo += _arraste.x * Config.SENSIBILIDADE_LATERAL
	_arraste = Vector2.ZERO
	var lim := deg_to_rad(Config.ANGULO_MAXIMO_GRAUS)
	_angulo_alvo = clampf(_angulo_alvo, -lim, lim)
	_lateral_alvo = clampf(_lateral_alvo, -Config.CORREDOR_LARGURA, Config.CORREDOR_LARGURA)


func _atualizar_impulso(delta: float) -> void:
	var mudou := false
	if _impulso_ativo:
		_impulso_restante -= delta
		if _impulso_restante <= 0.0:
			_impulso_ativo = false
			_recarga_restante = Config.IMPULSO_RECARGA / DadosJogo.bonus_impulso()
			mudou = true
	elif _recarga_restante > 0.0:
		_recarga_restante = maxf(0.0, _recarga_restante - delta)
		if is_zero_approx(_recarga_restante):
			mudou = true
	if mudou:
		_emitir_impulso()


func acionar_impulso() -> void:
	if not ativo or _impulso_ativo or _recarga_restante > 0.0 or _usos_impulso_restantes <= 0:
		return
	_usos_impulso_restantes -= 1
	_impulso_ativo = true
	_impulso_restante = Config.IMPULSO_DURACAO
	_emitir_impulso()


func _emitir_impulso() -> void:
	var progresso := 1.0
	if _recarga_restante > 0.0:
		progresso = 1.0 - _recarga_restante / (Config.IMPULSO_RECARGA / DadosJogo.bonus_impulso())
	var disponivel := not _impulso_ativo and _recarga_restante <= 0.0 and _usos_impulso_restantes > 0
	Eventos.impulso_alterado.emit(_impulso_ativo, disponivel, progresso)


## Projetil balistico (Worms/Gunbound) - unico modelo de voo do jogo (v7).
## O estado real e o vetor (vx, vy); `angulo_atual()` o deriva pra quem
## precisa (visual, camera).
func _integrar(delta: float) -> void:
	var dif := DadosJogo.dificuldade_multiplicadores()
	var asas := DadosJogo.asas_atual()
	var arrasto_mult := DadosJogo.arrasto_mult_atual()

	var vel := Vector2(vx, vy)
	var rapidez := vel.length()
	var dir := vel.normalized() if rapidez > 0.001 else Vector2(1.0, 0.0)

	var aceleracao := Vector2.ZERO
	# Gravidade: sempre pra baixo, constante - e o que cria a curva em U
	# invertido (sobe, atinge o pico, cai) em vez do aviao manter altitude por
	# conta propria.
	aceleracao.y -= Config.GRAVIDADE_BALISTICA * float(dif["queda_mult"])
	# Arrasto sempre oposto ao movimento, proporcional ao quadrado da
	# velocidade. A penalidade de asa faltando entra aqui como arrasto extra,
	# nao como estol - este modelo nao tem estol, so a parabola.
	aceleracao -= dir * (Config.K_ARRASTO * arrasto_mult * rapidez * rapidez \
		+ Config.ARRASTO_EXTRA_SEM_ASA[asas])
	# Nudge do jogador: empurrao na direcao que o dedo pede, mais fraco que a
	# gravidade - inclina a parabola, nao reescreve. Mergulhar de proposito
	# (mirar pra baixo) soma a queda e ganha velocidade real; puxar pra cima
	# resiste, sem inverter a gravidade sozinho.
	aceleracao += Vector2(cos(_angulo_alvo), sin(_angulo_alvo)) * Config.NUDGE_ACELERACAO
	# V9/P4: segurar o dedo na tela custa velocidade (arrasto extra, ainda que
	# nao esteja arrastando de fato) - incentiva toques/arrastes curtos em vez
	# de manter o dedo parado, batendo com a pesquisa sobre o jogo de
	# referencia. Ver briefing_ajustes_v9.md P4.
	if _dedo_pressionado:
		aceleracao -= dir * Config.ARRASTO_POR_SEGURAR
	if _impulso_ativo:
		aceleracao += dir * Config.IMPULSO_ACELERACAO * DadosJogo.bonus_impulso()
	if _dentro_termica:
		aceleracao.y += Config.TERMICA_ACELERACAO

	aceleracao *= float(dif["velocidade_mult"])

	vel += aceleracao * delta
	vx = vel.x
	vy = vel.y
	v_pico = maxf(v_pico, vel.length())

	var avanco := vx * delta
	position.z -= avanco
	position.y += vy * delta
	distancia += maxf(avanco, 0.0)


func _limitar_teto() -> void:
	var chao := Terreno.altura(position.x, position.z)
	var teto := chao + Config.ALTURA_MAXIMA
	if position.y > teto:
		position.y = teto
		vy = minf(vy, 0.0)


func _orientar(delta: float) -> void:
	# Rolagem cosmetica derivada do deslocamento lateral. Com menos de 2 asas o
	# modelo fica ASSIMETRICO (so a asa direita, ou nenhuma - ver
	# FabricaModelos) - rolar/guinar na mesma amplitude de um modelo simetrico
	# lia como o aviao "girando" descontrolado no ar, em vez de so instavel.
	var asas := DadosJogo.asas_atual()
	var alvo_rolagem := clampf((position.x - _lateral_alvo) * 0.06, -0.6, 0.6) \
		* Config.ROLAGEM_MULT_SEM_ASA[asas]
	rotation.x = lerpf(rotation.x, angulo_atual(), clampf(8.0 * delta, 0.0, 1.0))
	rotation.z = lerpf(rotation.z, alvo_rolagem, clampf(6.0 * delta, 0.0, 1.0))
	rotation.y = lerpf(rotation.y, -alvo_rolagem * 0.3, clampf(6.0 * delta, 0.0, 1.0))


func _verificar_fim() -> void:
	if distancia >= _meta:
		ativo = false
		Eventos.meta_atingida.emit(distancia)
		encerrou.emit("meta")
		return

	var chao := Terreno.altura(position.x, position.z)
	if position.y - chao <= Config.ALTURA_MINIMA:
		position.y = chao + Config.ALTURA_MINIMA
		tocou_solo = true
		ativo = false
		Eventos.solo_tocado.emit(global_position)
		encerrou.emit("solo")


func altura_acima_do_solo() -> float:
	return position.y - Terreno.altura(position.x, position.z)


func definir_termica(dentro: bool) -> void:
	if dentro == _dentro_termica:
		return
	_dentro_termica = dentro
	if dentro:
		Eventos.termica_entrou.emit()
	else:
		Eventos.termica_saiu.emit()


func impulso_ativo() -> bool:
	return _impulso_ativo

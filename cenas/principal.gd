extends Node
## Maquina de estados da sessao e montagem do mundo 3D.
##
## LOJA -> LANCAMENTO -> VOO -> RESULTADO -> LOJA
##
## O ciclo e curto de proposito: o jogador precisa passar pela loja depois de
## cada corrida, porque e la que o progresso fica visivel. Um jogo deste genero
## que deixa o jogador voar dez vezes seguidas sem comprar nada perde o unico
## motivo que ele tem para voar de novo.

enum Estado { LOJA, LANCAMENTO, VOO, RESULTADO }

var estado: Estado = Estado.LOJA

@onready var _mundo: Node3D = $Mundo
@onready var _hud: CanvasLayer = $HUD
@onready var _loja: Control = $Interface/Loja
@onready var _estilingue: Estilingue = $Interface/Estilingue
@onready var _resultado: Control = $Interface/Resultado
@onready var _monitor: MonitorDesempenho = $Monitor/MonitorDesempenho

var _aviao: Aviao = null
var _camera: CameraSeguidora = null
var _gerador: GeradorMundo = null
var _gerador_obstaculos: GeradorObstaculos = null
var _ambiente: WorldEnvironment = null
var _luz: DirectionalLight3D = null
var _estilingue_visual: EstilingueVisual = null
var _meta: float = 0.0


func _ready() -> void:
	_montar_mundo()

	_loja.voar_solicitado.connect(iniciar_corrida)
	_estilingue.lancado.connect(_ao_lancar)
	_aviao.encerrou.connect(_ao_encerrar)
	_resultado.jogar_novamente.connect(iniciar_corrida)
	_resultado.voltar_ao_menu.connect(abrir_loja)

	_monitor.gerador = _gerador
	_monitor.gerador_obstaculos = _gerador_obstaculos
	abrir_loja()

	var args := OS.get_cmdline_user_args()
	if args.has("--teste-voo"):
		_anexar("res://testes/piloto_automatico.gd", "PilotoAutomatico")
	elif args.has("--capturar"):
		_anexar("res://testes/capturar_telas.gd", "CapturarTelas")


func _anexar(caminho: String, nome: String) -> void:
	var script: GDScript = load(caminho)
	var no: Node = script.new()
	no.name = nome
	no.principal = self
	add_child(no)


func nos_de_teste() -> Dictionary:
	return {"aviao": _aviao, "gerador": _gerador, "gerador_obstaculos": _gerador_obstaculos,
			"estilingue": _estilingue, "monitor": _monitor, "loja": _loja}


# --- Mundo -----------------------------------------------------------------

func _montar_mundo() -> void:
	_ambiente = WorldEnvironment.new()
	_ambiente.environment = _criar_ambiente(
		Terreno.cor_ceu(Terreno.offset_bioma(DadosJogo.fase_selecionada)), 400.0)
	_mundo.add_child(_ambiente)

	_luz = DirectionalLight3D.new()
	_luz.rotation_degrees = Vector3(-62.0, -28.0, 0.0)
	_luz.light_energy = 1.05
	_luz.shadow_enabled = true
	_luz.directional_shadow_max_distance = 120.0
	_mundo.add_child(_luz)

	_gerador = GeradorMundo.new()
	_gerador.name = "GeradorMundo"
	_mundo.add_child(_gerador)
	_gerador.preparar()

	# V9: obstaculos removidos do jogo ("tirar os objetos", pedido explicito)
	# - GeradorObstaculos/CenarioFixo (v8/v9 P2/P5) continuam no projeto,
	# so nao sao mais instanciados. _gerador_obstaculos fica null de
	# proposito; todo chamador (monitor, piloto automatico) ja trata null
	# como "sem obstaculos".
	_aviao = Aviao.new()
	_aviao.name = "Aviao"
	_mundo.add_child(_aviao)

	_estilingue_visual = EstilingueVisual.new()
	_estilingue_visual.name = "EstilingueVisual"
	_mundo.add_child(_estilingue_visual)

	_camera = CameraSeguidora.new()
	_camera.name = "Camera"
	_mundo.add_child(_camera)
	_camera.definir_alvo(_aviao)
	_camera.current = true


func _criar_ambiente(cor_ceu: Color, alcance: float) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = cor_ceu
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = cor_ceu.lerp(Color.WHITE, 0.18)
	env.ambient_light_energy = 0.42
	env.fog_enabled = true
	env.fog_light_color = cor_ceu
	# A constante 1,8 chega a ~83% de opacidade no fim do alcance: esconde o
	# surgimento dos pedacos sem lavar as cores do cenario proximo.
	env.fog_density = 1.8 / maxf(alcance, 1.0)
	env.fog_sky_affect = 0.0
	return env


# --- Ciclo -----------------------------------------------------------------

func abrir_loja() -> void:
	estado = Estado.LOJA
	_aviao.ativo = false
	_aviao.visible = false
	_gerador.encerrar()
	_hud.visible = false
	_estilingue.visible = false
	_estilingue_visual.encerrar()
	_resultado.visible = false
	_loja.call(&"abrir")


func iniciar_corrida() -> void:
	estado = Estado.LANCAMENTO
	_meta = DadosJogo.meta_atual()

	_aviao.visible = true
	_aviao.preparar(_meta)
	_gerador.iniciar(_aviao)

	# A nevoa precisa alcancar mais longe quanto mais rapido o aviao voa: se o
	# alcance visual for menor que a distancia percorrida no tempo de reacao, o
	# jogador ve o relevo depois que ja era tarde.
	var alcance := maxf(400.0, DadosJogo.v_cruzeiro() * 3.2)
	_ambiente.environment = _criar_ambiente(
		Terreno.cor_ceu(Terreno.offset_bioma(DadosJogo.fase_selecionada)), alcance)

	_camera.global_position = _aviao.global_position + _camera.deslocamento

	_loja.visible = false
	_resultado.visible = false
	_hud.visible = true
	_hud.call(&"configurar", _meta)
	_estilingue.iniciar()
	_estilingue_visual.preparar(_aviao.global_position)


func _ao_lancar(qualidade: float, lateral: float, _rotulo: String) -> void:
	estado = Estado.VOO
	_aviao.lancar(qualidade, lateral)
	_estilingue_visual.encerrar()
	_monitor.reiniciar()


func _process(_delta: float) -> void:
	if estado == Estado.LANCAMENTO:
		var ponta := _aviao.ajustar_preparacao(_estilingue.tensao(), _estilingue.mira())
		_estilingue_visual.atualizar(ponta)
		return
	if estado != Estado.VOO:
		return
	# O ceu acompanha o bioma, que e funcao da distancia (+ offset da fase -
	# ver Terreno.offset_bioma()).
	var cor := Terreno.cor_ceu(_aviao.distancia + Terreno.offset_bioma(DadosJogo.fase_selecionada))
	var env := _ambiente.environment
	env.background_color = env.background_color.lerp(cor, 0.02)
	env.fog_light_color = env.background_color


func _ao_encerrar(motivo: String) -> void:
	if estado != Estado.VOO:
		return
	estado = Estado.RESULTADO
	_gerador.encerrar()

	var atingiu := motivo == "meta"
	var registro := DadosJogo.registrar_corrida(_aviao.distancia, atingiu, not _aviao.tocou_solo)
	registro["motivo"] = motivo
	registro["v_pico"] = _aviao.v_pico
	registro["meta"] = _meta

	_hud.visible = false
	_resultado.call(&"mostrar", registro)
	Eventos.corrida_encerrada.emit(registro)

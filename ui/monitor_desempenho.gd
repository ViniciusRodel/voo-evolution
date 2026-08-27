class_name MonitorDesempenho
extends Control
## Overlay de telemetria. Tecla F1 no desktop, ou toque com 3 dedos no celular.
##
## ESTE NO EXISTE PARA A FASE 1 DO ROADMAP TER UM VEREDITO OBJETIVO.
##
## Os criterios de aprovacao eram: >= 60 FPS por 3 minutos continuos, frame
## time p99 abaixo de 20 ms e zero alocacao por frame no loop de voo. Sem
## instrumentacao, "parece fluido" vira o criterio - e "parece fluido" no
## aparelho do desenvolvedor nao diz nada sobre o aparelho do jogador.
##
## O p99 e reportado porque a media mente: um jogo com 60 FPS de media e um
## engasgo de 45 ms a cada 4 segundos tem media excelente e sensacao pessima.

## Tamanho da janela de amostragem (10 segundos a 60 FPS).
const AMOSTRAS := 600
## Intervalo de recalculo das estatisticas caras, em segundos.
const INTERVALO_RECALCULO := 0.5

var _tempos: PackedFloat32Array = PackedFloat32Array()
var _cursor: int = 0
var _preenchido: int = 0
var _acumulado: float = 0.0

var _fps: float = 0.0
var _p99: float = 0.0
var _medio: float = 0.0
var _pior: float = 0.0
var _tempo_acima_do_alvo: float = 0.0
var _tempo_total: float = 0.0

var gerador: GeradorMundo = null
var gerador_obstaculos: GeradorObstaculos = null

@onready var _texto: Label = $Painel/Texto


func _ready() -> void:
	_tempos.resize(AMOSTRAS)
	visible = false
	set_process(true)
	# Nunca bloqueia o input do jogo.
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed(&"alternar_monitor"):
		visible = not visible
	elif evento is InputEventScreenTouch and (evento as InputEventScreenTouch).pressed:
		# Toque com 3 dedos alterna no celular, onde nao ha teclado.
		if (evento as InputEventScreenTouch).index == 2:
			visible = not visible


func _process(delta: float) -> void:
	var ms := delta * 1000.0
	_tempos[_cursor] = ms
	_cursor = (_cursor + 1) % AMOSTRAS
	_preenchido = mini(_preenchido + 1, AMOSTRAS)

	_tempo_total += delta
	if Engine.get_frames_per_second() >= float(Config.ALVO_FPS) - 1.0:
		_tempo_acima_do_alvo += delta

	_acumulado += delta
	if _acumulado < INTERVALO_RECALCULO:
		return
	_acumulado = 0.0
	_recalcular()
	if visible:
		_atualizar_texto()


func _recalcular() -> void:
	_fps = Engine.get_frames_per_second()
	if _preenchido == 0:
		return
	var copia := PackedFloat32Array()
	copia.resize(_preenchido)
	for i in _preenchido:
		copia[i] = _tempos[i]
	var soma := 0.0
	for v in copia:
		soma += v
	_medio = soma / float(_preenchido)

	var ordenado := Array(copia)
	ordenado.sort()
	var idx: int = clampi(int(float(_preenchido) * 0.99), 0, _preenchido - 1)
	_p99 = ordenado[idx]
	_pior = ordenado[_preenchido - 1]


func _atualizar_texto() -> void:
	if _texto == null:
		return
	var aprovado_fps := _fps >= float(Config.ALVO_FPS) - 1.0
	var aprovado_p99 := _p99 <= Config.ALVO_FRAME_TIME_P99_MS

	var draw_calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var objetos := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	var memoria := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var nos := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))

	var linhas: Array[String] = []
	linhas.append("=== FASE 1 / CRITERIOS DE APROVACAO ===")
	linhas.append("%s FPS ...... %5.1f  (alvo >= %d)" % [_marca(aprovado_fps), _fps, Config.ALVO_FPS])
	linhas.append("%s p99 ...... %5.2f ms (alvo <= %.0f)" % [_marca(aprovado_p99), _p99, Config.ALVO_FRAME_TIME_P99_MS])
	linhas.append("   medio ... %5.2f ms" % _medio)
	linhas.append("   pior .... %5.2f ms" % _pior)
	var pct := 0.0
	if _tempo_total > 0.0:
		pct = _tempo_acima_do_alvo / _tempo_total * 100.0
	linhas.append("   no alvo . %5.1f%% do tempo" % pct)
	linhas.append("   teste ... %5.1f s / %.0f s" % [_tempo_total, Config.ALVO_DURACAO_TESTE_S])
	linhas.append("")
	linhas.append("=== RENDERIZACAO ===")
	linhas.append("   draw calls .. %d" % draw_calls)
	linhas.append("   objetos ..... %d" % objetos)
	linhas.append("   nos ......... %d" % nos)
	linhas.append("   memoria ..... %.1f MB" % memoria)
	if gerador != null:
		linhas.append("")
		linhas.append("=== CENARIO ===")
		linhas.append("   pedacos ..... %d / %d" % [gerador.pedacos_ativos(), gerador.pedacos_alvo()])
	if gerador_obstaculos != null:
		linhas.append("   obstaculos .. %d" % gerador_obstaculos.obstaculos_ativos())

	_texto.text = "\n".join(linhas)


func _marca(ok: bool) -> String:
	return "[OK]" if ok else "[--]"


## Zera as estatisticas. Chamado no inicio de cada partida para que o teste de
## 3 minutos meca apenas o voo, sem contaminar com o tempo de menu.
func reiniciar() -> void:
	_cursor = 0
	_preenchido = 0
	_acumulado = 0.0
	_tempo_total = 0.0
	_tempo_acima_do_alvo = 0.0
	_p99 = 0.0
	_medio = 0.0
	_pior = 0.0

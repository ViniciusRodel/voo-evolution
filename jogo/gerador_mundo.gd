class_name GeradorMundo
extends Node3D
## Streaming do terreno e correntes de ar.
##
## V3: orbes removidos do jogo ("remova as bolas do cenario") - ver
## `briefing_ajustes_v4.md` para a proposta de fisica planadora que motivou a
## remocao. O streaming de terreno e as termicas continuam identicos.

var _pool_pedacos: Pool = null
var _pedacos_ativos: Array[PedacoTerreno] = []
var _proximo_indice: int = 0
var _pedacos_janela: int = Config.PEDACOS_MIN

var _termicas: Array[Vector3] = []   # x, y, z do centro
var _cursor_termica: float = 0.0

var _aviao: Aviao = null
var _rng := RandomNumberGenerator.new()
var _pronto: bool = false
## V8: offset de bioma da fase selecionada (ver Terreno.offset_bioma()),
## calculado uma vez por corrida em iniciar() e repassado a cada pedaco.
var _offset_bioma: float = 0.0


func preparar() -> void:
	if _pool_pedacos == null:
		_pool_pedacos = Pool.new(self, func(): return PedacoTerreno.new(),
			Config.PEDACOS_MAX + 2, "terreno")


func iniciar(aviao: Aviao) -> void:
	preparar()
	_aviao = aviao
	_offset_bioma = Terreno.offset_bioma(DadosJogo.fase_selecionada)

	for p in _pedacos_ativos:
		_pool_pedacos.devolver(p)
	_pedacos_ativos.clear()
	_termicas.clear()

	var v := DadosJogo.v_cruzeiro()
	var necessarios := int(ceil(v * Config.SEGUNDOS_DE_CENARIO / Config.PEDACO_COMPRIMENTO)) + 2
	_pedacos_janela = clampi(necessarios, Config.PEDACOS_MIN, Config.PEDACOS_MAX)

	_proximo_indice = -1
	_cursor_termica = -Config.TERMICA_A_CADA
	_rng.seed = 90210

	for i in _pedacos_janela + 1:
		_criar_proximo_pedaco()
	_pronto = true


func _process(_delta: float) -> void:
	if not _pronto or _aviao == null:
		return
	var z := _aviao.position.z
	var indice_aviao := int(floor(-z / Config.PEDACO_COMPRIMENTO))
	while not _pedacos_ativos.is_empty() and _pedacos_ativos[0].indice < indice_aviao - 1:
		var p: PedacoTerreno = _pedacos_ativos.pop_front()
		_pool_pedacos.devolver(p)
		_criar_proximo_pedaco()

	_repor_termicas(z)
	_atualizar_termica()


func _criar_proximo_pedaco() -> void:
	var p := _pool_pedacos.pegar() as PedacoTerreno
	if p == null:
		return
	p.configurar(_proximo_indice, _offset_bioma)
	_pedacos_ativos.append(p)
	_proximo_indice += 1


# --- Correntes de ar -------------------------------------------------------

func _repor_termicas(z_aviao: float) -> void:
	var limite := z_aviao - Config.PEDACO_COMPRIMENTO * float(_pedacos_janela - 1)
	while _cursor_termica > limite:
		var x := _rng.randf_range(-Config.CORREDOR_LARGURA * 0.6, Config.CORREDOR_LARGURA * 0.6)
		var y := Terreno.altura(x, _cursor_termica) + _rng.randf_range(14.0, 55.0)
		_termicas.append(Vector3(x, y, _cursor_termica))
		_cursor_termica -= Config.TERMICA_A_CADA
	# Descarta as que ficaram para tras.
	while not _termicas.is_empty() and _termicas[0].z > z_aviao + 100.0:
		_termicas.pop_front()


func _atualizar_termica() -> void:
	if _aviao == null:
		return
	var p := _aviao.position
	var dentro := false
	for t in _termicas:
		if absf(p.z - t.z) > Config.TERMICA_COMPRIMENTO * 0.5:
			continue
		var d := Vector2(p.x - t.x, p.y - t.y).length()
		if d <= Config.TERMICA_RAIO:
			dentro = true
			break
	_aviao.definir_termica(dentro)


func encerrar() -> void:
	_pronto = false


# --- Telemetria ------------------------------------------------------------

func pedacos_ativos() -> int:
	return _pedacos_ativos.size()


func pedacos_alvo() -> int:
	return _pedacos_janela + 1

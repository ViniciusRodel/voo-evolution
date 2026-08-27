class_name CartaoVeiculo
extends PanelContainer
## Item da lista de selecao: preview 3D do veiculo, nome, cadeado e requisito
## de velocidade.
##
## Construido em codigo, e nao em .tscn, porque e instanciado dinamicamente e
## parametrizado por veiculo. Um .tscn aqui exigiria configurar tudo por script
## de qualquer forma - o .tscn so acrescentaria um arquivo a manter.
##
## PREVIEW 3D: cada cartao tem um SubViewport com mundo proprio, mostrando o
## modelo real do veiculo no nivel de evolucao atual do jogador. Veiculos
## bloqueados aparecem como silhueta preta, como na referencia.
##
## CUSTO: o SubViewport usa render_target_update_mode = UPDATE_ONCE. Ele
## renderiza um unico frame e congela. Sem isso, 6 cartoes na tela seriam 6
## viewports 3D renderizando a 60 FPS por cima da tela de menu - o caminho
## mais rapido para reprovar o criterio de FPS em uma tela que nem e gameplay.

signal escolhido(veiculo: Veiculo)

const ALTURA := 104
const TAM_PREVIEW := Vector2i(190, 104)

var veiculo: Veiculo = null
var desbloqueado: bool = false

var _viewport: SubViewport = null
var _rotulo_nome: Label = null
var _rotulo_requisito: Label = null
var _velocimetro: Velocimetro = null
var _cadeado: Label = null


func configurar(v: Veiculo, esta_desbloqueado: bool, nivel: int, selecionado: bool) -> void:
	veiculo = v
	desbloqueado = esta_desbloqueado

	custom_minimum_size = Vector2(0, ALTURA)
	mouse_filter = Control.MOUSE_FILTER_STOP

	if get_child_count() == 0:
		_montar()

	_rotulo_nome.text = v.nome
	_rotulo_nome.add_theme_color_override(&"font_color",
		Color(1, 1, 1) if esta_desbloqueado else Color(0.72, 0.74, 0.78))

	_velocimetro.maximo = maxf(v.velocidade_cruzeiro, 1.0)
	_velocimetro.valor = v.velocidade_cruzeiro

	if esta_desbloqueado:
		_cadeado.visible = false
		_rotulo_requisito.text = "NIVEL %d / %d" % [nivel, v.total_niveis]
	else:
		_cadeado.visible = true
		_rotulo_requisito.text = "ATINJA %d KM/H" % v.velocidade_necessaria

	_aplicar_estilo(esta_desbloqueado, selecionado)
	_montar_preview(v, nivel, not esta_desbloqueado)


func _montar() -> void:
	var caixa := HBoxContainer.new()
	caixa.add_theme_constant_override(&"separation", 10)
	add_child(caixa)

	# --- Preview 3D --------------------------------------------------------
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(TAM_PREVIEW)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.add_child(container)

	_viewport = SubViewport.new()
	_viewport.size = TAM_PREVIEW
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(_viewport)

	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.position = Vector3(3.6, 2.0, 4.4)
	cam.look_at_from_position(Vector3(3.6, 2.0, 4.4), Vector3.ZERO, Vector3.UP)
	cam.fov = 42.0
	_viewport.add_child(cam)

	var luz := DirectionalLight3D.new()
	luz.name = "Luz"
	luz.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
	luz.light_energy = 1.15
	_viewport.add_child(luz)

	# --- Textos ------------------------------------------------------------
	var coluna := VBoxContainer.new()
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna.alignment = BoxContainer.ALIGNMENT_CENTER
	coluna.add_theme_constant_override(&"separation", 2)
	caixa.add_child(coluna)

	_rotulo_nome = Label.new()
	_rotulo_nome.add_theme_font_size_override(&"font_size", 21)
	_rotulo_nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(_rotulo_nome)

	_rotulo_requisito = Label.new()
	_rotulo_requisito.add_theme_font_size_override(&"font_size", 13)
	_rotulo_requisito.add_theme_color_override(&"font_color", Color(0.85, 0.86, 0.90))
	coluna.add_child(_rotulo_requisito)

	# --- Cadeado -----------------------------------------------------------
	_cadeado = Label.new()
	_cadeado.text = "[X]"
	_cadeado.add_theme_font_size_override(&"font_size", 30)
	_cadeado.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caixa.add_child(_cadeado)

	# --- Velocimetro -------------------------------------------------------
	_velocimetro = Velocimetro.new()
	_velocimetro.custom_minimum_size = Vector2(78, 78)
	_velocimetro.espessura = 8.0
	_velocimetro.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_velocimetro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.add_child(_velocimetro)


func _montar_preview(v: Veiculo, nivel: int, silhueta: bool) -> void:
	if _viewport == null:
		return
	for filho in _viewport.get_children():
		if filho.name == "Modelo":
			filho.queue_free()

	var modelo := FabricaModelos.criar(v, nivel, silhueta)
	modelo.name = "Modelo"
	modelo.rotation_degrees = Vector3(0.0, 34.0, 0.0)
	_viewport.add_child(modelo)

	# Renderiza um unico frame e congela. Precisa ser reagendado toda vez que o
	# conteudo muda (troca de nivel, desbloqueio).
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _aplicar_estilo(esta_desbloqueado: bool, selecionado: bool) -> void:
	var estilo := StyleBoxFlat.new()
	if not esta_desbloqueado:
		estilo.bg_color = Color(0.55, 0.57, 0.60)
	else:
		estilo.bg_color = veiculo.cor_primaria.lerp(Color(0.20, 0.20, 0.24), 0.30)
	estilo.corner_radius_top_left = 14
	estilo.corner_radius_top_right = 14
	estilo.corner_radius_bottom_left = 14
	estilo.corner_radius_bottom_right = 14
	estilo.content_margin_left = 8
	estilo.content_margin_right = 12
	estilo.content_margin_top = 6
	estilo.content_margin_bottom = 6
	if selecionado:
		estilo.border_color = Color(1, 1, 1, 0.95)
		estilo.set_border_width_all(3)
	add_theme_stylebox_override(&"panel", estilo)


func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventScreenTouch and (evento as InputEventScreenTouch).pressed:
		accept_event()
		escolhido.emit(veiculo)

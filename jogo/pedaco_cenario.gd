class_name PedacoCenario
extends Node3D
## Um segmento de cenario de Config.PEDACO_COMPRIMENTO metros.
##
## DECISAO DE DESEMPENHO CENTRAL DESTE ARQUIVO: toda a decoracao (arvores,
## casas, predios) e desenhada com MultiMeshInstance3D, nao com nos individuais.
## Sao ~250 objetos visiveis por pedaco em 2 draw calls, em vez de 250 draw
## calls. Este e o mesmo principio do GPU Instancing citado na tabela de riscos
## da analise de arquitetura, e e o que torna o alvo de 60 FPS em aparelho de
## gama media alcancavel com folga.
##
## Os buffers do MultiMesh sao alocados UMA VEZ no _ready(). Ao reciclar o
## pedaco, so mexemos em `visible_instance_count` e nas transformadas - nunca
## em `instance_count`, que realocaria memoria e causaria hitch.

const MAX_ARVORES := 46
const MAX_CASAS := 18

var indice: int = -1

var _chao: MeshInstance3D = null
var _faixa: MeshInstance3D = null
var _rio: MeshInstance3D = null
var _mm_arvores: MultiMeshInstance3D = null
var _mm_casas: MultiMeshInstance3D = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_chao = _criar_bloco(Vector3(160.0, 1.0, Config.PEDACO_COMPRIMENTO),
		Vector3(0.0, -0.5, -Config.PEDACO_COMPRIMENTO * 0.5), Color(0.42, 0.70, 0.30))
	_faixa = _criar_bloco(Vector3(7.0, 0.15, Config.PEDACO_COMPRIMENTO),
		Vector3(0.0, 0.05, -Config.PEDACO_COMPRIMENTO * 0.5), Color(0.62, 0.62, 0.64))
	_rio = _criar_bloco(Vector3(11.0, 0.1, Config.PEDACO_COMPRIMENTO),
		Vector3(34.0, 0.02, -Config.PEDACO_COMPRIMENTO * 0.5), Color(0.28, 0.52, 0.82))

	_mm_arvores = _criar_multimesh(MAX_ARVORES)
	_mm_casas = _criar_multimesh(MAX_CASAS)


func _criar_bloco(tam: Vector3, pos: Vector3, cor: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = FabricaModelos.malha_cubo()
	mi.material_override = FabricaModelos.material_para(cor)
	mi.scale = tam
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _criar_multimesh(maximo: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = FabricaModelos.malha_cubo()
	mm.instance_count = maximo      # alocado uma unica vez
	mm.visible_instance_count = 0

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## Reposiciona e repovoa este pedaco para representar o segmento `novo_indice`.
## A semente do RNG deriva do indice, entao o pedaco 7 tem SEMPRE o mesmo
## layout - essencial para reproduzir um bug de level design.
func configurar(novo_indice: int, universo: Universo, distancia_urbanizacao: float) -> void:
	indice = novo_indice
	position = Vector3(0.0, 0.0, -float(novo_indice) * Config.PEDACO_COMPRIMENTO)
	_rng.seed = hash(novo_indice) & 0x7FFFFFFF

	if universo != null:
		_chao.material_override = FabricaModelos.material_para(universo.cor_terreno)

	# Passada certa distancia o cenario vira cidade: as "casas" ficam altas e
	# cinzas. E a transicao vila -> cidade da referencia, feita so com
	# parametros, sem trocar nenhum asset. O criterio e DISTANCIA, nao indice
	# de pedaco, para a transicao acontecer no mesmo ponto do mundo
	# independentemente da velocidade do veiculo.
	var distancia := float(novo_indice) * Config.PEDACO_COMPRIMENTO
	var urbano: float = clampf((distancia - distancia_urbanizacao) / 700.0, 0.0, 1.0)

	_povoar_arvores(urbano)
	_povoar_casas(urbano)


func _povoar_arvores(urbano: float) -> void:
	var mm := _mm_arvores.multimesh
	var n := int(lerpf(float(MAX_ARVORES), 10.0, urbano))
	mm.visible_instance_count = n
	for i in n:
		var lado := 1.0 if _rng.randf() > 0.5 else -1.0
		var x := lado * _rng.randf_range(14.0, 70.0)
		var z := -_rng.randf_range(0.0, Config.PEDACO_COMPRIMENTO)
		var altura := _rng.randf_range(2.5, 6.5)
		var largura := _rng.randf_range(1.2, 2.4)

		var t := Transform3D.IDENTITY
		t.basis = t.basis.scaled(Vector3(largura, altura, largura))
		t.origin = Vector3(x, altura * 0.5, z)
		mm.set_instance_transform(i, t)

		var verde := Color(
			_rng.randf_range(0.15, 0.30),
			_rng.randf_range(0.42, 0.62),
			_rng.randf_range(0.16, 0.28)
		)
		mm.set_instance_color(i, verde)


func _povoar_casas(urbano: float) -> void:
	var mm := _mm_casas.multimesh
	mm.visible_instance_count = MAX_CASAS
	for i in MAX_CASAS:
		var lado := 1.0 if (i % 2 == 0) else -1.0
		var x := lado * _rng.randf_range(16.0, 58.0)
		var z := -_rng.randf_range(0.0, Config.PEDACO_COMPRIMENTO)
		var altura := lerpf(_rng.randf_range(3.0, 5.5), _rng.randf_range(10.0, 34.0), urbano)
		var largura := lerpf(_rng.randf_range(4.0, 7.0), _rng.randf_range(6.0, 11.0), urbano)

		var t := Transform3D.IDENTITY
		t.basis = t.basis.scaled(Vector3(largura, altura, largura))
		t.origin = Vector3(x, altura * 0.5, z)
		mm.set_instance_transform(i, t)

		var rural := Color(_rng.randf_range(0.72, 0.88), _rng.randf_range(0.62, 0.74), _rng.randf_range(0.48, 0.58))
		var predio := Color(_rng.randf_range(0.38, 0.55), _rng.randf_range(0.42, 0.58), _rng.randf_range(0.50, 0.66))
		mm.set_instance_color(i, rural.lerp(predio, urbano))


func ativar() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT


func desativar() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	indice = -1

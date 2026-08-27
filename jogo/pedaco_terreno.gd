class_name PedacoTerreno
extends Node3D
## Um segmento de terreno de Config.PEDACO_COMPRIMENTO metros, com malha gerada
## a partir de Terreno.altura().
##
## DESEMPENHO: os PackedArrays sao alocados UMA vez no _ready e apenas
## reescritos a cada reciclagem. Sem isso, cada reciclagem alocaria ~7 mil
## vetores e o coletor de lixo apareceria como stutter no p99 - o criterio que
## mais importa.
##
## A malha usa vertices NAO compartilhados (cada quad tem os seus). Custa 4x
## mais vertices e entrega o sombreamento facetado do visual low-poly sem
## precisar de shader nenhum.

const COLUNAS := 20
const LINHAS := 15
const LARGURA := 280.0

var indice: int = -1
## V8: offset de bioma da fase atual (ver Terreno.offset_bioma()) - so afeta
## a COR consultada em Terreno.cor_terreno(), nunca Terreno.altura()/amplitude
## (relevo/colisao continuam funcao pura da distancia da corrida).
var _offset_bioma: float = 0.0

var _malha: ArrayMesh = null
var _instancia: MeshInstance3D = null
var _mm_decoracao: MultiMeshInstance3D = null
var _vertices := PackedVector3Array()
var _normais := PackedVector3Array()
var _cores := PackedColorArray()
var _rng := RandomNumberGenerator.new()

const MAX_DECORACOES := 60


func _ready() -> void:
	var total := COLUNAS * LINHAS * 6
	_vertices.resize(total)
	_normais.resize(total)
	_cores.resize(total)

	_malha = ArrayMesh.new()
	_instancia = MeshInstance3D.new()
	_instancia.mesh = _malha
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_instancia.material_override = mat
	_instancia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_instancia)

	_mm_decoracao = _criar_decoracao()


func _criar_decoracao() -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = FabricaModelos.malha_cubo()
	mm.instance_count = MAX_DECORACOES
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


func configurar(novo_indice: int, offset_bioma: float = 0.0) -> void:
	indice = novo_indice
	_offset_bioma = offset_bioma
	var z0 := -float(novo_indice) * Config.PEDACO_COMPRIMENTO
	position = Vector3.ZERO   # a malha e construida em coordenadas de mundo
	_rng.seed = hash(novo_indice * 7919) & 0x7FFFFFFF
	_gerar_malha(z0)
	_gerar_decoracao(z0)


func _gerar_malha(z0: float) -> void:
	var passo_x := LARGURA / float(COLUNAS)
	var passo_z := Config.PEDACO_COMPRIMENTO / float(LINHAS)
	var x0 := -LARGURA * 0.5
	var i := 0

	for cx in COLUNAS:
		for cz in LINHAS:
			var xa := x0 + float(cx) * passo_x
			var xb := xa + passo_x
			var za := z0 - float(cz) * passo_z
			var zb := za - passo_z

			var a := Vector3(xa, Terreno.altura(xa, za), za)
			var b := Vector3(xb, Terreno.altura(xb, za), za)
			var c := Vector3(xb, Terreno.altura(xb, zb), zb)
			var d := Vector3(xa, Terreno.altura(xa, zb), zb)

			var cor := Terreno.cor_terreno(-((za + zb) * 0.5) + _offset_bioma)
			# Variacao por face: quebra a leitura de grade sem custo de textura.
			var v := _rng.randf_range(-0.035, 0.035)
			cor = Color(clampf(cor.r + v, 0, 1), clampf(cor.g + v, 0, 1), clampf(cor.b + v, 0, 1))

			i = _quad(i, a, b, c, d, cor)

	_malha.clear_surfaces()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = _normais
	arrays[Mesh.ARRAY_COLOR] = _cores
	_malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _quad(i: int, a: Vector3, b: Vector3, c: Vector3, d: Vector3, cor: Color) -> int:
	var n1 := (b - a).cross(c - a).normalized()
	var n2 := (c - a).cross(d - a).normalized()
	_vertices[i] = a; _normais[i] = n1; _cores[i] = cor; i += 1
	_vertices[i] = b; _normais[i] = n1; _cores[i] = cor; i += 1
	_vertices[i] = c; _normais[i] = n1; _cores[i] = cor; i += 1
	_vertices[i] = a; _normais[i] = n2; _cores[i] = cor; i += 1
	_vertices[i] = c; _normais[i] = n2; _cores[i] = cor; i += 1
	_vertices[i] = d; _normais[i] = n2; _cores[i] = cor; i += 1
	return i


func _gerar_decoracao(z0: float) -> void:
	var mm := _mm_decoracao.multimesh
	var distancia := -z0
	var amp := Terreno.amplitude(distancia)
	var n := MAX_DECORACOES
	mm.visible_instance_count = n

	for k in n:
		# Decoracao fica FORA do corredor jogavel: nunca deve estar no caminho.
		var lado := 1.0 if _rng.randf() > 0.5 else -1.0
		var x := lado * _rng.randf_range(Config.CORREDOR_LARGURA + 8.0, LARGURA * 0.48)
		var z := z0 - _rng.randf_range(0.0, Config.PEDACO_COMPRIMENTO)
		var altura_base := Terreno.altura(x, z)
		var h := _rng.randf_range(3.0, 9.0) * (0.7 + amp * 0.5)
		var l := _rng.randf_range(1.6, 4.2)

		var t := Transform3D.IDENTITY
		t.basis = t.basis.scaled(Vector3(l, h, l))
		t.origin = Vector3(x, altura_base + h * 0.5 - 0.5, z)
		mm.set_instance_transform(k, t)

		var cor := Terreno.cor_terreno(-z + _offset_bioma).darkened(_rng.randf_range(0.15, 0.45))
		mm.set_instance_color(k, cor)


func ativar() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT


func desativar() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	indice = -1

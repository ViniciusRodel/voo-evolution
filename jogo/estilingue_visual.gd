class_name EstilingueVisual
extends Node3D
## Elastico do estilingue, visivel no mundo 3D durante a carga do lancamento.
##
## Puramente cosmetico: dois postes fixos plantados perto do ponto de partida
## e duas bandas que esticam ate a cauda do aviao, que Aviao.ajustar_preparacao()
## move enquanto o medidor de forca (ui/estilingue.gd) carrega. Fecha a
## pendencia do README - antes so existia o medidor 2D, sem elastico no mundo.

const ESPESSURA_POSTE: float = 0.18
const ALTURA_POSTE: float = 2.4
const ESPESSURA_BANDA: float = 0.10
const AFASTAMENTO_POSTES: float = 1.7
const RECUO_POSTES: float = 1.1   # postes ficam um pouco a frente do ponto de partida

var _poste_esquerdo: MeshInstance3D
var _poste_direito: MeshInstance3D
var _banda_esquerda: MeshInstance3D
var _banda_direita: MeshInstance3D
var _ancora_esquerda: Vector3 = Vector3.ZERO
var _ancora_direita: Vector3 = Vector3.ZERO


func _ready() -> void:
	visible = false
	var mat_poste := FabricaModelos.material_para(Color(0.42, 0.30, 0.20))
	var mat_banda := FabricaModelos.material_para(Color(0.12, 0.12, 0.13))

	_poste_esquerdo = _criar_bloco(mat_poste)
	_poste_direito = _criar_bloco(mat_poste)
	_banda_esquerda = _criar_bloco(mat_banda)
	_banda_direita = _criar_bloco(mat_banda)


func _criar_bloco(material: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = FabricaModelos.malha_cubo()
	mi.material_override = material
	# Postes e bandas sao finos e nao precisam sombra propria - mesmo raciocinio
	# de custo que ja se aplica aos blocos pequenos da FabricaModelos.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## Planta os dois postes ao redor do ponto onde o aviao vai nascer.
func preparar(base_mundial: Vector3) -> void:
	var centro_esq := base_mundial + Vector3(-AFASTAMENTO_POSTES, ALTURA_POSTE * 0.5, -RECUO_POSTES)
	var centro_dir := base_mundial + Vector3(AFASTAMENTO_POSTES, ALTURA_POSTE * 0.5, -RECUO_POSTES)

	_poste_esquerdo.global_position = centro_esq
	_poste_esquerdo.scale = Vector3(ESPESSURA_POSTE, ALTURA_POSTE, ESPESSURA_POSTE)
	_poste_direito.global_position = centro_dir
	_poste_direito.scale = Vector3(ESPESSURA_POSTE, ALTURA_POSTE, ESPESSURA_POSTE)

	_ancora_esquerda = centro_esq + Vector3(0.0, ALTURA_POSTE * 0.5, 0.0)
	_ancora_direita = centro_dir + Vector3(0.0, ALTURA_POSTE * 0.5, 0.0)

	visible = true
	atualizar(base_mundial)


## Reposiciona as bandas para a posicao atual da cauda do aviao (mundo).
func atualizar(ponta_aviao: Vector3) -> void:
	_esticar(_banda_esquerda, _ancora_esquerda, ponta_aviao)
	_esticar(_banda_direita, _ancora_direita, ponta_aviao)


func encerrar() -> void:
	visible = false


func _esticar(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var direcao := b - a
	var comprimento := direcao.length()
	if comprimento < 0.01:
		mi.visible = false
		return
	mi.visible = true
	mi.global_transform = Transform3D(Basis.looking_at(direcao.normalized(), Vector3.UP), (a + b) * 0.5)
	mi.scale = Vector3(ESPESSURA_BANDA, ESPESSURA_BANDA, comprimento)

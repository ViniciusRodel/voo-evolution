class_name Obstaculo
extends Area3D
## Obstaculo de esquiva. SEMPRE vem de um pool - nunca instanciar diretamente.
##
## Por que pool: instanciar e liberar nos durante o voo gera alocacao e,
## eventualmente, uma pausa do coletor de lixo. Uma pausa de 30 ms no meio de
## uma esquiva e exatamente o tipo de stutter que reprova o criterio de
## frame time p99 da Fase 1.

enum Tipo { PAREDE, PILAR, FLUTUANTE }

var tipo: Tipo = Tipo.PAREDE

var _malha: MeshInstance3D = null
var _forma: CollisionShape3D = null
var _caixa: BoxShape3D = null


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	# Obstaculo nao precisa detectar nada: quem detecta e o aviao. Desligar o
	# monitoring aqui elimina metade dos testes de sobreposicao do broad phase.
	monitoring = false
	monitorable = true


func _preparar_nos() -> void:
	if _malha == null:
		_malha = MeshInstance3D.new()
		_malha.mesh = FabricaModelos.malha_cubo()
		add_child(_malha)
	if _forma == null:
		_caixa = BoxShape3D.new()
		_forma = CollisionShape3D.new()
		_forma.shape = _caixa
		add_child(_forma)


## Reconfigura o obstaculo para um novo uso. Nao aloca nada alem do material
## (que vem do cache compartilhado da FabricaModelos).
func configurar(novo_tipo: Tipo, tamanho: Vector3, cor: Color, pos: Vector3) -> void:
	_preparar_nos()
	tipo = novo_tipo
	position = pos
	_malha.scale = tamanho
	_malha.material_override = FabricaModelos.material_para(cor)
	_caixa.size = tamanho
	rotation = Vector3.ZERO


func ativar() -> void:
	visible = true
	# V8: set_deferred, nao atribuicao direta - reciclar um obstaculo pode
	# acontecer DENTRO do callback de area_entered de outro obstaculo (ver
	# Aviao._ao_colidir_obstaculo -> fim de corrida -> proxima corrida ->
	# _povoar_ate), e o motor de fisica bloqueia mudar `monitorable` em
	# pleno despacho de sinal de area (erro "Function blocked during in/out
	# signal").
	set_deferred(&"monitorable", true)
	process_mode = Node.PROCESS_MODE_INHERIT


func desativar() -> void:
	visible = false
	set_deferred(&"monitorable", false)
	process_mode = Node.PROCESS_MODE_DISABLED
	# Tira do caminho para o caso de algum teste de fisica ainda pegar o no
	# antes do monitorable propagar.
	position = Vector3(0.0, -500.0, 0.0)

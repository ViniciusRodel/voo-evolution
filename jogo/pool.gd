class_name Pool
extends RefCounted
## Pool de nos generico e pre-alocado.
##
## Contrato: todos os objetos sao criados UMA VEZ, no inicio da partida.
## Durante o voo, `pegar()` e `devolver()` nunca alocam. Se `pegar()` for
## chamado com o pool vazio, ele devolve null e registra um aviso - isso e
## proposital: e melhor um obstaculo faltar do que um frame drop. Se aparecer
## nos logs, o tamanho do pool esta subdimensionado e deve ser corrigido em
## Config, nao contornado aqui.

var _livres: Array[Node] = []
var _ativos: Array[Node] = []
var _pai: Node = null
var _rotulo: String = ""
var _avisou_vazio: bool = false


func _init(pai: Node, fabrica: Callable, quantidade: int, rotulo: String = "pool") -> void:
	_pai = pai
	_rotulo = rotulo
	for i in quantidade:
		var n: Node = fabrica.call()
		n.name = "%s_%03d" % [rotulo, i]
		_pai.add_child(n)
		if n.has_method("desativar"):
			n.call("desativar")
		_livres.append(n)


func pegar() -> Node:
	if _livres.is_empty():
		if not _avisou_vazio:
			push_warning("Pool '%s' esgotado (%d ativos). Aumente o tamanho em Config." % [_rotulo, _ativos.size()])
			_avisou_vazio = true
		return null
	var n: Node = _livres.pop_back()
	_ativos.append(n)
	if n.has_method("ativar"):
		n.call("ativar")
	return n


func devolver(n: Node) -> void:
	if n == null:
		return
	var i := _ativos.find(n)
	if i == -1:
		return
	_ativos.remove_at(i)
	if n.has_method("desativar"):
		n.call("desativar")
	_livres.append(n)


func devolver_todos() -> void:
	for n in _ativos.duplicate():
		devolver(n)


func total_ativos() -> int:
	return _ativos.size()


func total() -> int:
	return _ativos.size() + _livres.size()

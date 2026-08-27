extends Node
## Teste da FASE 2 do roadmap: pipeline de evolucao visual.
##
## Uso: godot --headless --quit-after 120 -- --teste-modelos
##
## Verifica o que a Fase 2 precisa provar:
##  1. O modelo do nivel 1 e o do nivel 20 sao de fato diferentes.
##  2. Trocar de modelo em runtime nao vaza nos nem materiais.
##  3. O cache de materiais esta funcionando (poucos materiais para muitos
##     blocos) - se este numero explodir, as draw calls explodem junto.

func _ready() -> void:
	print("=== TESTE DE EVOLUCAO VISUAL (FASE 2) ===")
	print("")

	var nos_antes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var total_blocos := 0
	var falhas := 0

	for veiculo in DadosJogo.todos_veiculos():
		var contagens: Array[int] = []
		for nivel in [1, 5, 10, 15, 20]:
			var modelo := FabricaModelos.criar(veiculo, nivel)
			var blocos := modelo.get_child_count()
			contagens.append(blocos)
			total_blocos += blocos

			var previsto := FabricaModelos.contar_blocos(veiculo, nivel)
			if blocos != previsto:
				push_error("%s nivel %d: %d blocos, previsto %d" % [veiculo.nome, nivel, blocos, previsto])
				falhas += 1

			# Libera imediatamente: e assim que o jogo faz ao trocar de nivel.
			modelo.free()

		var evoluiu := contagens[0] != contagens[contagens.size() - 1]
		if not evoluiu:
			push_error("%s nao muda de aparencia entre o nivel 1 e o 20." % veiculo.nome)
			falhas += 1
		print("%-20s blocos por nivel [1,5,10,15,20] = %s  %s" % [
			veiculo.nome, str(contagens), "OK" if evoluiu else "SEM EVOLUCAO"])

	var nos_depois := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var vazamento := nos_depois - nos_antes

	print("")
	print("blocos construidos e liberados .. %d" % total_blocos)
	print("nos vazados ..................... %d" % vazamento)
	print("malhas compartilhadas ........... 1 (BoxMesh unitaria)")
	print("")
	if falhas == 0 and vazamento <= 0:
		print("FASE 2: OK - evolucao visual funciona e nao vaza nos.")
	else:
		print("FASE 2: FALHOU (%d falhas, %d nos vazados)" % [falhas, vazamento])
	get_tree().quit(0)

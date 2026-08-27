class_name CenarioFixo
extends RefCounted
## Catalogo de VINHETAS desenhadas a mao - sequencias de obstaculo fixas e
## nomeaveis, no lugar da geracao procedural aleatoria de
## jogo/gerador_obstaculos.gd, pra bater com o achado da pesquisa (P5,
## briefing_ajustes_v9.md): o jogo de referencia tem fases com identidade
## propria (dentro de uma casa, um escritorio, uma igreja), nao distancia
## continua com fileiras sorteadas.
##
## ESCOPO DESTA RODADA: so a Fase 2 tem vinheta propria (a mais documentada
## na pesquisa - `pesquisa_epic_plane_evolution.md` §2). As outras 12 fases
## continuam 100% proceduais (GeradorObstaculos) - nao e tudo ou nada, ver
## briefing_ajustes_v9.md P5 item 4. Cada vinheta cobre so o TRECHO INICIAL
## do voo (a "casa"); depois dela, GeradorObstaculos assume a geracao
## procedural normal pro resto da fase, exatamente como a referencia ("o
## aviao sai novamente para o exterior").
##
## Formato de cada obstaculo: {tipo, tamanho: Vector3, pos: Vector3, cor}.
## `pos.z` e negativo (a frente), no mesmo referencial de GeradorObstaculos.

## indice da fase (base 0) -> Array de definicoes de obstaculo.
static func vinhetas() -> Dictionary:
	return {
		1: _fase_2_casa(),
	}


## Distancia (metros, positiva) onde a vinheta termina e a geracao
## procedural normal comeca a povoar - a "janela" de saida marca o fim.
static func fim_da_vinheta(indice_fase: int) -> float:
	match indice_fase:
		1:
			return 340.0
		_:
			return 0.0


## Fase 2 - "dentro de uma casa" (pesquisa_epic_plane_evolution.md §2):
## duas cadeiras, uma banheira, sai pela janela.
##
## NOTA DE ESCALA: uma cadeira/banheira de verdade seria baixa (poucos
## metros), mas o aviao cruza a uma altitude que varia MUITO com o nivel de
## evolucao e a fase (dezenas de metros) - um obstaculo baixo de verdade
## seria sobrevoado sem querer na maioria das evolucoes, nunca testando a
## esquiva pretendida. Por isso os "moveis" aqui usam a MESMA altura das
## colunas/paredes proceduais ja calibradas (jogo/gerador_obstaculos.gd -
## PILAR ~34-40, PAREDE ~30) - a identidade vem da POSICAO e do NOME, nao da
## escala realista da mobilia.
static func _fase_2_casa() -> Array[Dictionary]:
	var marrom := Color(0.45, 0.30, 0.18)
	var branco := Color(0.88, 0.88, 0.90)
	var parede := Color(0.72, 0.68, 0.60)
	var lista: Array[Dictionary] = []

	# Cadeira 1 - esquerda.
	lista.append({"tipo": Obstaculo.Tipo.PILAR, "tamanho": Vector3(2.4, 34.0, 2.4),
		"pos": Vector3(-6.0, 17.0, -160.0), "cor": marrom})
	# Cadeira 2 - direita, um pouco mais a frente.
	lista.append({"tipo": Obstaculo.Tipo.PILAR, "tamanho": Vector3(2.4, 34.0, 2.4),
		"pos": Vector3(6.5, 17.0, -210.0), "cor": marrom})

	# Banheira - larga, bem no meio, obriga desviar pra um dos lados.
	lista.append({"tipo": Obstaculo.Tipo.PILAR, "tamanho": Vector3(9.0, 32.0, 4.5),
		"pos": Vector3(0.0, 16.0, -270.0), "cor": branco})

	# Janela de saida - parede com abertura LATERAL de ~7m no meio (mesma
	# escala de jogo/gerador_obstaculos.gd::_fileira_lateral), marca o fim
	# da "casa" - depois dela e "exterior" (GeradorObstaculos assume).
	lista.append({"tipo": Obstaculo.Tipo.PAREDE, "tamanho": Vector3(20.0, 30.0, 2.2),
		"pos": Vector3(-13.5, 14.0, -335.0), "cor": parede})
	lista.append({"tipo": Obstaculo.Tipo.PAREDE, "tamanho": Vector3(20.0, 30.0, 2.2),
		"pos": Vector3(13.5, 14.0, -335.0), "cor": parede})

	return lista

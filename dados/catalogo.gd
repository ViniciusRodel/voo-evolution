class_name Catalogo
extends RefCounted
## Catalogo de conteudo do jogo (universos e veiculos).
##
## V3: um aviao por fase (13 no total), cada um com uma velocidade BASE maior
## que o anterior - ESPELHO da tabela simulada em `sim/modelo.py`
## (`aviao_base()`). A curva cresce ~24,5% por fase (fator R=1,245), calibrada
## para produzir metas de fase pequenas o bastante para "poucas corridas por
## fase" (ver `briefing_ajustes_v3.md` §1-2) sem repetir o mesmo tipo de salto
## que a trilha de upgrade dentro da fase ja cobre.
##
## FASE 1: definido em codigo, mesmo raciocinio do comentario original desta
## classe - balanceamento muda toda hora durante o spike, editar um dicionario
## e mais rapido que editar 13 arquivos .tres. Producao troca por .tres.
##
## V5: nenhum aviao tem motor "de fabrica" mais - TODOS os 13 nascem
## planadores no proprio nivel 1 e ganham motor conforme sao construidos
## dentro da fase (asa, asa, cauda, so entao motor). `tem_motor`/
## `arrasto_mult` viraram funcoes de `DadosJogo.tem_motor_agora()`/
## `arrasto_mult_atual()`, nao mais campos fixos aqui. Ver
## briefing_ajustes_v5.md §1.


static func universos() -> Array[Universo]:
	var lista: Array[Universo] = []

	var u1 := Universo.new()
	u1.indice = 1
	u1.nome = "AMADOR"
	u1.cor_ceu = Color(0.68, 0.85, 0.96)
	u1.cor_terreno = Color(0.45, 0.72, 0.32)
	lista.append(u1)

	var u2 := Universo.new()
	u2.indice = 2
	u2.nome = "MOTORIZADO"
	u2.cor_ceu = Color(0.53, 0.78, 0.95)
	u2.cor_terreno = Color(0.60, 0.48, 0.36)
	lista.append(u2)

	var u3 := Universo.new()
	u3.indice = 3
	u3.nome = "MILITAR E EXPERIMENTAL"
	u3.cor_ceu = Color(0.40, 0.55, 0.85)
	u3.cor_terreno = Color(0.42, 0.40, 0.46)
	lista.append(u3)

	return lista


## Velocidade de cruzeiro BASE (m/s) de cada aviao, indice 0 = fase 1.
## Derivada por simulacao (fator R=1,245/fase a partir de 97,5 m/s) - ver
## sim/modelo.py::aviao_base(). Rodar de novo se a curva mudar.
const V_EQ_BASE: Array[float] = [
	97.5, 121.3, 151.1, 188.1, 234.2, 291.5, 363.0,
	451.9, 562.6, 700.5, 872.1, 1085.7, 1351.7,
]


static func veiculos() -> Array[Veiculo]:
	var lista: Array[Veiculo] = []

	var dados := [
		{"id": &"aviao_papel", "nome": "AVIAO DE PAPEL", "universo": 1,
			"primaria": Color(0.94, 0.92, 0.84), "secundaria": Color(0.80, 0.77, 0.68)},
		{"id": &"aviao_brinquedo", "nome": "AVIAO DE BRINQUEDO", "universo": 1,
			"primaria": Color(0.86, 0.22, 0.20), "secundaria": Color(0.16, 0.16, 0.19)},
		{"id": &"hidroaviao", "nome": "HIDROAVIAO", "universo": 1,
			"primaria": Color(0.25, 0.55, 0.85), "secundaria": Color(0.92, 0.92, 0.95)},
		{"id": &"planador", "nome": "PLANADOR", "universo": 1,
			"primaria": Color(0.93, 0.85, 0.35), "secundaria": Color(0.25, 0.25, 0.28)},
		{"id": &"biplano", "nome": "BIPLANO", "universo": 2,
			"primaria": Color(0.30, 0.62, 0.35), "secundaria": Color(0.35, 0.24, 0.14)},
		{"id": &"monomotor", "nome": "MONOMOTOR", "universo": 2,
			"primaria": Color(0.90, 0.55, 0.20), "secundaria": Color(0.30, 0.24, 0.18)},
		{"id": &"turboelice", "nome": "TURBOELICE", "universo": 2,
			"primaria": Color(0.24, 0.45, 0.82), "secundaria": Color(0.88, 0.88, 0.90)},
		{"id": &"jato_executivo", "nome": "JATO EXECUTIVO", "universo": 2,
			"primaria": Color(0.92, 0.92, 0.94), "secundaria": Color(0.35, 0.38, 0.45)},
		{"id": &"caca_a_jato", "nome": "CACA A JATO", "universo": 3,
			"primaria": Color(0.45, 0.48, 0.52), "secundaria": Color(0.20, 0.20, 0.22)},
		{"id": &"caca_supersonico", "nome": "CACA SUPERSONICO", "universo": 3,
			"primaria": Color(0.22, 0.24, 0.28), "secundaria": Color(0.85, 0.30, 0.18)},
		{"id": &"interceptador", "nome": "INTERCEPTADOR", "universo": 3,
			"primaria": Color(0.14, 0.14, 0.16), "secundaria": Color(0.95, 0.55, 0.15)},
		{"id": &"foguete_experimental", "nome": "FOGUETE EXPERIMENTAL", "universo": 3,
			"primaria": Color(0.95, 0.95, 0.92), "secundaria": Color(0.85, 0.20, 0.18)},
		{"id": &"nave_espacial", "nome": "NAVE ESPACIAL", "universo": 3,
			"primaria": Color(0.75, 0.78, 0.85), "secundaria": Color(0.25, 0.85, 0.90)},
	]

	for i in dados.size():
		var d: Dictionary = dados[i]
		var v := Veiculo.new()
		v.id = d["id"]
		v.nome = d["nome"]
		v.universo = d["universo"]
		v.velocidade_necessaria = 0  # deprecated, ver dados/veiculo.gd
		v.velocidade_cruzeiro = V_EQ_BASE[i]
		v.velocidade_maxima = V_EQ_BASE[i] * 1.4
		v.agilidade = lerpf(1.35, 0.65, float(i) / float(dados.size() - 1))
		v.cor_primaria = d["primaria"]
		v.cor_secundaria = d["secundaria"]
		v.escala_modelo = lerpf(0.85, 1.35, float(i) / float(dados.size() - 1))
		v.total_niveis = 20
		lista.append(v)

	return lista

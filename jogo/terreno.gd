class_name Terreno
extends RefCounted
## Funcao de altura do terreno e definicao dos biomas.
##
## DECISAO ARQUITETURAL: esta funcao e a UNICA fonte da verdade do relevo.
## A malha visual e gerada a partir dela e a colisao do aviao e um teste
## analitico contra ela - nao ha PhysicsBody, nao ha raycast, nao ha
## CollisionShape para o terreno.
##
## Consequencias:
##  - custo de colisao com o solo: uma chamada de funcao por frame, contra
##    dezenas de testes de broad phase que um terreno com colisor exigiria;
##  - impossivel a malha e a colisao divergirem, que e a fonte classica de
##    "o aviao bateu no nada" em jogos com terreno gerado.

## Amplitude do relevo cresce com a distancia: as primeiras fases sao planas e
## perdoam, as ultimas sao canions.
## V8: reescalado de 45000 para ~8000 - Config.METAS_FASE encolheu ~12x na
## recalibracao do v7 (motor deixou de sustentar voo, metas viraram
## "medidas, nao estimadas" - ver briefing_ajustes_v7.md §3). Com a
## constante antiga o relevo mal saia do patamar inicial em QUALQUER fase
## (a fase 13, a mais longa, so alcanca ~17% do caminho ate a amplitude
## maxima). Ver briefing_ajustes_v8.md §1.
const AMPLITUDE_INICIAL := 0.30
const AMPLITUDE_FINAL := 1.70
const DISTANCIA_AMPLITUDE_MAXIMA := 8000.0


## Altura do terreno em um ponto do mundo. z e negativo a frente.
static func altura(x: float, z: float) -> float:
	var distancia := -z
	var amp := amplitude(distancia)
	var h := 0.0
	h += sin(z * 0.0071 - 0.6) * 11.0     # ondulacao longa (colinas)
	h += sin(z * 0.0130) * 6.0            # media
	h += sin(z * 0.0310 + 1.7) * 2.6      # curta (textura)
	h += sin(x * 0.0180 + z * 0.0043) * 3.4  # variacao lateral
	h += sin(x * 0.0067 - 1.1) * 2.0
	return h * amp


## Normal aproximada do terreno, por diferencas finitas. Usada para orientar
## decoracao e para o efeito de proximidade do solo.
static func inclinacao(x: float, z: float) -> float:
	const D := 4.0
	return (altura(x, z - D) - altura(x, z + D)) / (2.0 * D)


static func amplitude(distancia: float) -> float:
	var t := clampf(distancia / DISTANCIA_AMPLITUDE_MAXIMA, 0.0, 1.0)
	return lerpf(AMPLITUDE_INICIAL, AMPLITUDE_FINAL, t)


# --- Biomas ----------------------------------------------------------------
# Progressao DENTRO de uma corrida. A fase apenas desloca o ponto de partida:
# na fase 8 o jogador ja comeca no canion.

## V8: thresholds reescalados pelo mesmo fator ~0,0775 da recalibracao de
## METAS_FASE no v7 (nova meta da fase 13 / meta antiga da fase 13 =
## 7639/98524) - preserva a MESMA proporcao de design (ex.: "fase 8 ja
## comeca no canion", ver offset_bioma() abaixo), so que na escala de
## distancia atual. Sem isso, uma corrida inteira mal saia de DUNA/DESERTO.
const BIOMAS := [
	{"inicio": 0.0,     "nome": "DUNA",        "terreno": Color(0.82, 0.70, 0.48), "ceu": Color(0.55, 0.78, 0.95)},
	{"inicio": 70.0,    "nome": "DESERTO",     "terreno": Color(0.86, 0.72, 0.45), "ceu": Color(0.58, 0.80, 0.96)},
	{"inicio": 200.0,   "nome": "RACHADURAS",  "terreno": Color(0.74, 0.55, 0.38), "ceu": Color(0.62, 0.79, 0.94)},
	{"inicio": 400.0,   "nome": "VILAREJO",    "terreno": Color(0.70, 0.62, 0.40), "ceu": Color(0.60, 0.80, 0.95)},
	{"inicio": 700.0,   "nome": "VELHO OESTE", "terreno": Color(0.78, 0.60, 0.42), "ceu": Color(0.66, 0.80, 0.93)},
	{"inicio": 1085.0,  "nome": "ESTACAO",     "terreno": Color(0.68, 0.52, 0.36), "ceu": Color(0.70, 0.78, 0.90)},
	{"inicio": 1630.0,  "nome": "MESAS",       "terreno": Color(0.62, 0.40, 0.30), "ceu": Color(0.62, 0.76, 0.92)},
	{"inicio": 2325.0,  "nome": "CANION",      "terreno": Color(0.54, 0.34, 0.26), "ceu": Color(0.52, 0.72, 0.93)},
	{"inicio": 3255.0,  "nome": "PLANALTO",    "terreno": Color(0.60, 0.48, 0.40), "ceu": Color(0.48, 0.68, 0.94)},
	{"inicio": 4340.0,  "nome": "SALINAS",     "terreno": Color(0.88, 0.87, 0.83), "ceu": Color(0.60, 0.75, 0.95)},
	{"inicio": 5425.0,  "nome": "COSTA",       "terreno": Color(0.72, 0.74, 0.58), "ceu": Color(0.46, 0.72, 0.96)},
]
## Distancia (na escala acima) onde o offset de fase (ver offset_bioma())
## satura - a ultima fase NASCE em SALINAS, deixando COSTA para ser
## alcancada durante o proprio voo, nao logo de saida.
const OFFSET_BIOMA_MAXIMO := 4340.0


## V8: quanto somar a distancia da corrida ANTES de consultar bioma/ceu, para
## que fases mais avancadas do catalogo (dados/catalogo.gd) nasçam num cenario
## visualmente mais avancado - a intencao original era "a fase apenas desloca
## o ponto de partida" (ver comentario no topo do arquivo), mas nunca tinha
## sido conectada a nenhum chamador. So afeta COR (bioma/ceu) - a amplitude do
## RELEVO (amplitude()) continua funcao so da distancia percorrida NESTA
## corrida, para nao mudar a fisica/colisao ja calibrada por fase.
## Linear de 0 (fase 1) ate OFFSET_BIOMA_MAXIMO (ultima fase).
static func offset_bioma(indice_fase: int) -> float:
	if Config.TOTAL_FASES <= 1:
		return 0.0
	var t := float(clampi(indice_fase, 0, Config.TOTAL_FASES - 1)) / float(Config.TOTAL_FASES - 1)
	return t * OFFSET_BIOMA_MAXIMO


static func indice_bioma(distancia: float) -> int:
	var i := 0
	for j in BIOMAS.size():
		if distancia >= float(BIOMAS[j]["inicio"]):
			i = j
	return i


static func nome_bioma(distancia: float) -> String:
	return String(BIOMAS[indice_bioma(distancia)]["nome"])


## Cor do terreno com transicao suave entre biomas, para a troca nao aparecer
## como uma linha reta atravessando o chao.
static func cor_terreno(distancia: float) -> Color:
	return _cor_interpolada(distancia, "terreno")


static func cor_ceu(distancia: float) -> Color:
	return _cor_interpolada(distancia, "ceu")


static func _cor_interpolada(distancia: float, chave: String) -> Color:
	var i := indice_bioma(distancia)
	if i >= BIOMAS.size() - 1:
		return BIOMAS[i][chave]
	var ini := float(BIOMAS[i]["inicio"])
	var fim := float(BIOMAS[i + 1]["inicio"])
	# A transicao ocupa os ultimos 35% do bioma.
	var inicio_transicao := lerpf(ini, fim, 0.65)
	if distancia < inicio_transicao:
		return BIOMAS[i][chave]
	var t := (distancia - inicio_transicao) / maxf(fim - inicio_transicao, 1.0)
	return (BIOMAS[i][chave] as Color).lerp(BIOMAS[i + 1][chave], clampf(t, 0.0, 1.0))

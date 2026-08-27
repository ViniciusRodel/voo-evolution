class_name Atributos
extends RefCounted
## Catalogo das trilhas compraveis.
##
## ESPELHO EXATO de ATRIBUTOS em sim/modelo.py. Qualquer alteracao aqui precisa
## ser refeita la, ou o balanceamento validado deixa de valer.
## [PENDENTE v9/P3: sim/modelo.py ainda reflete o AVIAO antigo (1 trilha) -
## nao foi sincronizado nesta rodada, ver nota no fim do arquivo.]
##
## V3 - UMA TRILHA POR AVIAO, NAO MAIS PARA O JOGO INTEIRO. Cada fase tem seu
## proprio aviao (ver dados/catalogo.gd) com sua propria velocidade BASE; estas
## trilhas so cobrem o ganho DENTRO daquela fase e resetam para o nivel 1
## quando o jogador troca de aviao (`autoload/dados_jogo.gd::niveis_por_aviao`).
##
## V9/P3 (briefing_ajustes_v9.md): a trilha AVIAO (um numero unico movendo
## velocidade+aerodinamica+impulso ao mesmo tempo) foi separada em 4 PECAS
## NOMEADAS - ASA_ESQUERDA, ASA_DIREITA, CAUDA, HELICE - cada uma rasa (8
## niveis, contra os 30 fundidos de antes) e com efeito visual proprio em
## jogo/fabrica_modelos.gd, batendo com a pesquisa sobre o jogo de referencia
## real (pesquisa_epic_plane_evolution.md §4: "4 pecas por aviao, poucos
## niveis cada, sem efeito visual depois de completas"). MOEDAS e o antigo
## Ima. ESTILINGUE (v9/P1) e progressao GLOBAL, nao mais por aviao.

const ASA_ESQUERDA := &"asa_esquerda"
const ASA_DIREITA := &"asa_direita"
const CAUDA := &"cauda"
const HELICE := &"helice"
const MOEDAS := &"moedas"
const ESTILINGUE := &"estilingue"

## Ordem de exibicao na loja.
const ORDEM: Array[StringName] = [ASA_ESQUERDA, ASA_DIREITA, CAUDA, HELICE, MOEDAS, ESTILINGUE]

## V9: trilhas que pertencem a UM AVIAO especifico e resetam ao trocar de
## aviao (DadosJogo.niveis_por_aviao) - ESTILINGUE fica de fora (e global,
## ver DadosJogo.nivel_estilingue).
const ORDEM_POR_AVIAO: Array[StringName] = [ASA_ESQUERDA, ASA_DIREITA, CAUDA, HELICE, MOEDAS]

## V9/P3: so as 4 pecas do AVIAO (nao MOEDAS) - usada para derivar a
## construcao VISUAL do aviao atual (DadosJogo._progresso_trilhas()). Comprar
## upgrade de renda nao devia fazer o aviao parecer mais construido.
const ORDEM_PECAS_AVIAO: Array[StringName] = [ASA_ESQUERDA, ASA_DIREITA, CAUDA, HELICE]

const DEFINICOES := {
	ASA_ESQUERDA: {
		"nome": "ASA ESQUERDA",
		"descricao": "Sustentacao e aerodinamica. Aparece com o 1o nivel.",
		# [A RECALIBRAR: primeiro palpite, mesmo metodo do AVIAO antigo -
		# medir com --teste-voo e ajustar Config.METAS_FASE depois, nao os
		# passos aqui. Ver briefing_ajustes_v9.md P3.]
		"max": 8, "passo": 1.09, "custo_base": 110.0, "razao": 1.32,
		"efeito": "+9% de aerodinamica",
		"cor": Color(0.90, 0.35, 0.25),
	},
	ASA_DIREITA: {
		"nome": "ASA DIREITA",
		"descricao": "Sustentacao e aerodinamica. Aparece com o 1o nivel.",
		"max": 8, "passo": 1.09, "custo_base": 110.0, "razao": 1.32,
		"efeito": "+9% de aerodinamica",
		"cor": Color(0.85, 0.40, 0.22),
	},
	CAUDA: {
		"nome": "CAUDA",
		"descricao": "Estabilidade - reduz um pouco o arrasto extra.",
		"max": 8, "passo": 1.05, "custo_base": 90.0, "razao": 1.32,
		"efeito": "+5% de aerodinamica",
		"cor": Color(0.70, 0.55, 0.30),
	},
	HELICE: {
		"nome": "HELICE",
		"descricao": "Motor - velocidade e impulso deste aviao.",
		"max": 8, "passo_v": 1.13, "passo_i": 1.045, "custo_base": 150.0, "razao": 1.32,
		"efeito": "+13% de velocidade, +4,5% de impulso",
		"cor": Color(0.55, 0.55, 0.60),
	},
	MOEDAS: {
		"nome": "MOEDAS",
		"descricao": "Raio de coleta maior. Mais orbes e mais moedas por metro voado.",
		"max": 30, "passo": 1.015, "custo_base": 250.0, "razao": 1.220,
		"efeito": "+8% de moedas",
		"cor": Color(0.85, 0.70, 0.25),
	},
	ESTILINGUE: {
		"nome": "ESTILINGUE",
		"descricao": "Lancamento mais forte. Nao reseta ao trocar de aviao.",
		"max": 40, "passo": 1.0197, "custo_base": 120.0, "razao": 1.220,
		"efeito": "+2% no lancamento",
		"cor": Color(0.55, 0.58, 0.65),
	},
}


static func definicao(id: StringName) -> Dictionary:
	return DEFINICOES.get(id, {})


static func nivel_maximo(id: StringName) -> int:
	return int(DEFINICOES[id]["max"])


## Custo do proximo nivel. custo(n) = base * razao^(n-1)
static func custo(id: StringName, nivel_atual: int) -> int:
	var d: Dictionary = DEFINICOES[id]
	return int(round(float(d["custo_base"]) * pow(float(d["razao"]), float(nivel_atual - 1))))


## Multiplicador acumulado do atributo em um dado nivel. `chave` seleciona qual
## multiplicador ler quando o atributo tem mais de um simultaneo - caso de
## HELICE, que sobe velocidade ("passo_v") e impulso ("passo_i") no mesmo
## nivel. Os demais atributos usam a chave padrao "passo".
static func multiplicador(id: StringName, nivel: int, chave: StringName = &"passo") -> float:
	var d: Dictionary = DEFINICOES[id]
	return pow(float(d[chave]), float(nivel - 1))


## Soma minima e maxima dos niveis das PECAS DO AVIAO (ver ORDEM_PECAS_AVIAO),
## usada para derivar o nivel visual do aviao atual.
static func soma_minima() -> int:
	return ORDEM_PECAS_AVIAO.size()


static func soma_maxima() -> int:
	var s := 0
	for id in ORDEM_PECAS_AVIAO:
		s += nivel_maximo(id)
	return s

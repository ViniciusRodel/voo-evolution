class_name Veiculo
extends Resource
## Definicao de um veiculo jogavel.
##
## Na Fase 1 os veiculos sao criados em codigo (ver dados/catalogo.gd) para
## evitar 20 arquivos .tres escritos a mao antes de sabermos se o balanceamento
## presta. Na fase de producao isto vira um .tres por veiculo, editavel no
## inspector pelo game designer.

## Identificador estavel. Usado como chave no save. NUNCA renomear depois
## de publicado, ou o progresso dos jogadores quebra.
@export var id: StringName = &""

## Nome exibido na interface.
@export var nome: String = ""

## Indice do universo ao qual pertence (1, 2, 3...).
@export var universo: int = 1

## DEPRECATED (v3): o desbloqueio agora e por fase completada
## (`DadosJogo.fase_maxima_alcancada`), nao por velocidade recorde. Campo
## mantido no Resource so para nao quebrar o shape; ver `briefing_ajustes_v3.md`
## "Achado que muda o escopo deste pedido".
@export var velocidade_necessaria: int = 0

## Velocidade de cruzeiro EM M/S (nao km/h, apesar do nome historico) no nivel
## 1 da trilha Aviao deste veiculo especifico - a base de `v_eq` que
## `DadosJogo.v_cruzeiro()` multiplica pela trilha comprada dentro da fase.
## E este numero que sobe de aviao para aviao (ver dados/catalogo.gd) e produz
## o "aviao melhor com velocidade maxima maior" a cada fase completada.
@export var velocidade_cruzeiro: float = 97.5

## Informativo/preview (usado pelo velocimetro do cartao na tela de selecao,
## ver `briefing_ajustes_v3.md` §5) - nao alimenta o modelo de voo.
@export var velocidade_maxima: float = 140.0

## Multiplicador de resposta lateral. 1.0 = padrao.
## Veiculos rapidos costumam ser menos ageis; e o trade-off do balanceamento.
@export var agilidade: float = 1.0

## Quantos niveis de evolucao visual este veiculo possui.
@export var total_niveis: int = 20

@export var cor_primaria: Color = Color(0.85, 0.2, 0.2)
@export var cor_secundaria: Color = Color(0.15, 0.15, 0.18)

## Escala geral do modelo montado. Ajusta a leitura visual na tela.
@export var escala_modelo: float = 1.0


## Retorna o multiplicador de tamanho/detalhe para um dado nivel (0.0 a 1.0).
## E este numero que a fabrica de modelos usa para decidir o que desenhar.
func progresso_do_nivel(nivel: int) -> float:
	if total_niveis <= 1:
		return 1.0
	return clampf(float(nivel - 1) / float(total_niveis - 1), 0.0, 1.0)

class_name Universo
extends Resource
## Agrupamento de veiculos, equivalente as abas "UNIVERSE 1 / 2 / 3" da tela
## de selecao.

@export var indice: int = 1
@export var nome: String = ""
## Cor de fundo do ceu quando se joga com um veiculo deste universo.
@export var cor_ceu: Color = Color(0.65, 0.82, 0.95)
## Cor do terreno base.
@export var cor_terreno: Color = Color(0.42, 0.70, 0.30)

extends Node
## Barramento de eventos global.
##
## Regra: sinais aqui sao para comunicacao entre SISTEMAS distintos. Comunicacao
## entre um no e seu proprio filho usa sinal local, nao isto.

# --- Ciclo da corrida ------------------------------------------------------

signal lancamento_concluido(qualidade: float, rotulo: String)
signal voo_iniciado()
signal corrida_encerrada(resultado: Dictionary)

# --- Telemetria de voo -----------------------------------------------------

signal velocidade_alterada(v_ms: float)
signal distancia_alterada(metros: float)
signal termica_entrou()
signal termica_saiu()
signal impulso_alterado(ativo: bool, disponivel: bool, progresso: float)
signal solo_tocado(posicao: Vector3)
signal meta_atingida(distancia: float)

# --- Progressao ------------------------------------------------------------

signal moedas_alteradas(total: int)
signal atributo_melhorado(id: StringName, novo_nivel: int)

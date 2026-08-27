extends Node
## Estado persistente: qual aviao/fase o jogador esta jogando, niveis de
## upgrade de CADA aviao, moedas, recordes por fase e dificuldade escolhida.
##
## Este autoload e a fonte da verdade dos derivados do aviao (velocidade de
## cruzeiro, bonus de lancamento, arrasto...). O no do aviao le daqui em vez de
## guardar copia propria, para nao existir a possibilidade de os dois
## divergirem depois de uma compra.
##
## V3: um aviao por fase (`dados/catalogo.gd`), cada um com sua propria trilha
## de upgrade que RESETA ao trocar de aviao - ver `briefing_ajustes_v3.md` §6.
## Fases ja completadas continuam selecionaveis livremente ("jogar so para se
## divertir"), com recompensa normal.

const CAMINHO_SAVE := "user://progresso.json"
## v5: o balanceamento mudou tanto (asa progressiva, penalidade de voar sem
## asa, meta com folga bem mais apertada, dificuldade mais dura) que um save
## v4 com niveis ja comprados sob a curva antiga fica incoerente com a nova -
## por exemplo, pula direto pras duas asas sem o jogador nunca ver o estado
## inicial sem asa nenhuma. Mesmo raciocinio das bumps anteriores: descartar e
## comecar limpo.
## v7: motor deixou de sustentar voo (virou bonus de lancamento) e
## Config.METAS_FASE foi recalibrada do zero em cima disso - um save antigo
## teria fases ja desbloqueadas com metas de outra ordem de grandeza,
## incoerente com o progresso salvo.
## v7.1: primeira recalibracao de METAS_FASE mediu nivel=10 por engano
## (dados/atributos.gd V8-V10 ja tinha subido o maximo das trilhas para 30) -
## corrigido medindo nivel=30 em Dificil, valores de METAS_FASE mudaram nas
## 13 fases.
## v9: Estilingue saiu de niveis_por_aviao e virou campo global proprio
## (nivel_estilingue); novo campo de prestigio (prestigios). Estrutura do
## save mudou o bastante pra nao valer migrar (briefing_ajustes_v9.md).
## v9/P3: a trilha AVIAO (uma so) virou 4 pecas (asa_esquerda/asa_direita/
## cauda/helice) - as chaves salvas em niveis_por_aviao mudaram de nome,
## save antigo incompativel.
## v9/P4: METAS_FASE remedida de novo (arrasto por segurar o dedo).
const VERSAO_SAVE := 10

var moedas: int = 0
## Fase mais avancada que o jogador ja desbloqueou (indice base 0) - define o
## que aparece liberado no mapa (briefing_ajustes_v3.md §5).
var fase_maxima_alcancada: int = 0
## Fase que o jogador esta jogando/comprando upgrade AGORA. Pode ser menor que
## fase_maxima_alcancada quando o jogador volta pra uma fase antiga.
var fase_selecionada: int = 0
## StringName (id do aviao) -> Dictionary(StringName atributo -> int nivel).
## Criado sob demanda em _niveis_atuais() na primeira vez que um aviao e
## selecionado - todo aviao comeca do nivel 1 em tudo.
var niveis_por_aviao: Dictionary = {}
## V9: nivel do Estilingue - GLOBAL, nao mais dentro de niveis_por_aviao.
## Nunca reseta ao trocar de aviao nem ao prestigiar (ver
## briefing_ajustes_v9.md P1/P2) - e o que da sentido a repetir o jogo.
var nivel_estilingue: int = 1
## V9: quantas vezes o jogador completou a ultima fase e "prestigiou"
## (briefing_ajustes_v9.md P2) - volta pra fase 1 com bonus_prestigio()
## permanente em troca de resetar niveis_por_aviao. Nunca reseta sozinho.
var prestigios: int = 0
## int (indice da fase) -> float (melhor distancia ja alcancada nela). Usado
## pelo marcador de recorde no mapa e em voo (briefing_ajustes_v3.md §7).
var recordes_por_fase: Dictionary = {}
## Uma chave de Config.DIFICULDADES, lido por Aviao._integrar().
var dificuldade_atual: StringName = &"medio"
var total_corridas: int = 0
## Uso de teste: quando > 0, sobrescreve meta_atual(). O piloto automatico usa
## isto com --meta-livre para garantir que a corrida termine tocando o solo,
## nao por bater a meta - nunca e setado pelo jogo real.
var meta_forcada: float = -1.0
## Uso de teste: quando true, salvar() vira no-op. testes/piloto_automatico.gd
## e testes/capturar_telas.gd ligam isto no _ready() deles - os dois rodam
## corridas de verdade (registrar_corrida chama salvar()) contra o MESMO
## progresso.json do jogo real (mesmo user:// da instancia headless e da
## janela jogavel, indexado pelo nome do projeto). Sem este flag, uma sessao
## de calibracao (--nivel=10 --fase=13 ...) sobrescreve o save de quem esta
## jogando de verdade - foi exatamente o que aconteceu forcando as 13 fases em
## Dificil para calibrar dados/atributos.gd (V8): o save real virou "fase 13,
## tudo no maximo, dificil" sem nenhuma corrida jogada de verdade.
var _persistencia_desabilitada: bool = false


func _ready() -> void:
	carregar()


# --- Aviao atual -------------------------------------------------------------

func aviao_atual() -> Veiculo:
	var lista := Catalogo.veiculos()
	var indice := clampi(fase_selecionada, 0, lista.size() - 1)
	return lista[indice]


## Muda qual fase/aviao esta selecionado para jogar/comprar. Fases alem da
## maxima alcancada nao sao permitidas - a UI de mapa e responsavel por nunca
## oferecer essa opcao, isto aqui e a garantia de fundo.
func selecionar_fase(indice: int) -> void:
	fase_selecionada = clampi(indice, 0, fase_maxima_alcancada)


func _niveis_atuais() -> Dictionary:
	var id := aviao_atual().id
	if not niveis_por_aviao.has(id):
		var d := {}
		for atributo in Atributos.ORDEM_POR_AVIAO:
			d[atributo] = 1
		niveis_por_aviao[id] = d
	return niveis_por_aviao[id]


# --- Upgrades ----------------------------------------------------------------

## V9: ESTILINGUE despacha pro campo global (nivel_estilingue) - as outras
## trilhas continuam por aviao (niveis_por_aviao). Ver Atributos.ORDEM_POR_AVIAO.
func nivel(id: StringName) -> int:
	if id == Atributos.ESTILINGUE:
		return nivel_estilingue
	return int(_niveis_atuais().get(id, 1))


func no_maximo(id: StringName) -> bool:
	return nivel(id) >= Atributos.nivel_maximo(id)


func custo_proximo(id: StringName) -> int:
	return Atributos.custo(id, nivel(id))


func pode_comprar(id: StringName) -> bool:
	return not no_maximo(id) and moedas >= custo_proximo(id)


func comprar(id: StringName) -> bool:
	if not pode_comprar(id):
		return false
	moedas -= custo_proximo(id)
	if id == Atributos.ESTILINGUE:
		nivel_estilingue += 1
	else:
		_niveis_atuais()[id] = nivel(id) + 1
	Eventos.moedas_alteradas.emit(moedas)
	Eventos.atributo_melhorado.emit(id, nivel(id))
	salvar()
	return true


# --- Derivados do aviao ----------------------------------------------------

## V9/P3: velocidade vem so da HELICE (motor) - as asas nao afetam mais
## velocidade diretamente, so arrasto (ver arrasto_mult_atual()).
func v_cruzeiro() -> float:
	var base := aviao_atual().velocidade_cruzeiro
	return base * Atributos.multiplicador(Atributos.HELICE, nivel(Atributos.HELICE), &"passo_v")


func raio_coleta() -> float:
	return Config.RAIO_COLETA_BASE * Atributos.multiplicador(Atributos.MOEDAS, nivel(Atributos.MOEDAS)) \
		* (1.0 + 0.22 * float(nivel(Atributos.MOEDAS) - 1))


func bonus_moedas() -> float:
	return 1.0 + 0.08 * float(nivel(Atributos.MOEDAS) - 1)


func bonus_impulso() -> float:
	return Atributos.multiplicador(Atributos.HELICE, nivel(Atributos.HELICE), &"passo_i")


func bonus_estilingue() -> float:
	return Atributos.multiplicador(Atributos.ESTILINGUE, nivel(Atributos.ESTILINGUE))


## V9: multiplicador de moedas por prestigio acumulado - ver
## briefing_ajustes_v9.md P2. [A CALIBRAR: +50% por volta e primeiro
## palpite, nao medido contra quantas voltas um jogador real da.]
func bonus_prestigio() -> float:
	return 1.0 + Config.BONUS_PRESTIGIO_POR_NIVEL * float(prestigios)


func dificuldade_multiplicadores() -> Dictionary:
	return Config.dificuldade(dificuldade_atual)


func definir_dificuldade(id: StringName) -> void:
	if Config.DIFICULDADES.has(id):
		dificuldade_atual = id
		salvar()


## V7: o motor deixou de sustentar voo - agora e um bonus de LANCAMENTO, do
## mesmo jeito que o Estilingue ja e. Quanto mais construido (helices -> motor
## direito -> motor esquerdo), mais forte o lancamento sai. Ver
## briefing_ajustes_v7.md §2.
func v_inicial(qualidade: float) -> float:
	return v_cruzeiro() \
		* (Config.LANCAMENTO_BASE + Config.LANCAMENTO_AMPLITUDE * clampf(qualidade, 0.0, 1.0)) \
		* bonus_estilingue() \
		* bonus_motor_lancamento()


func bonus_motor_lancamento() -> float:
	return 1.0 + Config.BONUS_MOTOR_LANCAMENTO_MAXIMO * potencia_motor_atual()


## V9/P3: so as 4 PECAS do aviao (Atributos.ORDEM_PECAS_AVIAO) - MOEDAS saiu
## daqui (comprar upgrade de renda nao devia mudar a aparencia do aviao).
func _progresso_trilhas() -> float:
	var soma := 0
	for id in Atributos.ORDEM_PECAS_AVIAO:
		soma += nivel(id)
	var minimo := Atributos.soma_minima()
	var maximo := Atributos.soma_maxima()
	return float(soma - minimo) / float(maximo - minimo)


## Nivel visual GERAL do aviao ATUAL (1 a 20), derivado da soma das 4 pecas.
## Ainda usado como "nivel" simples pra UI (loja) e pros chamadores que nao
## precisam de detalhe por peca (testes/teste_modelos.gd, cartoes de
## selecao). Quem precisa do progresso de CADA peca (o jogo real, ao montar
## o aviao em voo) usa pecas_visuais() abaixo.
func nivel_visual() -> int:
	return 1 + int(round(_progresso_trilhas() * 19.0))


## V9/P3: progresso (0 a 1) de cada peca do aviao, mais um "geral" (media das
## 4) - e o que jogo/fabrica_modelos.gd consome pra desenhar cada asa/cauda/
## helice de forma independente, em vez de uma fracao "t" unica e
## compartilhada. Ver briefing_ajustes_v9.md P3.
func pecas_visuais() -> Dictionary:
	var d := {}
	for id in Atributos.ORDEM_PECAS_AVIAO:
		var maximo := Atributos.nivel_maximo(id)
		d[id] = 0.0 if maximo <= 1 else float(nivel(id) - 1) / float(maximo - 1)
	d["geral"] = _progresso_trilhas()
	return d


## Quantas asas o aviao atual tem (0, 1 ou 2). V9/P3: cada asa e uma PECA
## PROPRIA agora (Atributos.ASA_ESQUERDA/ASA_DIREITA) - uma asa "existe" a
## partir do primeiro nivel comprado (nivel > 1), nao mais uma fracao "t"
## compartilhada com as outras trilhas. jogo/fabrica_modelos.gd usa o mesmo
## criterio pra desenhar (ou nao) cada meia-asa.
func asas_atual() -> int:
	var conta := 0
	if nivel(Atributos.ASA_DIREITA) > 1:
		conta += 1
	if nivel(Atributos.ASA_ESQUERDA) > 1:
		conta += 1
	return conta


## Fracao de progresso da peca HELICE (0 a 1) - 0 no nivel 1 (so cosmetico,
## sem motor nenhum), 1,0 no nivel maximo. V9/P3: antes era uma fracao da
## soma de TODAS as trilhas (Config.LIMIAR_HELICES/MOTOR_DIREITO/ESQUERDO);
## agora e so o progresso da propria peca HELICE, que passou a ser a unica
## responsavel por velocidade/impulso/motor. Ver briefing_ajustes_v9.md P3.
func potencia_motor_atual() -> float:
	var maximo := Atributos.nivel_maximo(Atributos.HELICE)
	if maximo <= 1:
		return 1.0
	return clampf(float(nivel(Atributos.HELICE) - 1) / float(maximo - 1), 0.0, 1.0)


## Se o aviao atual tem o motor construido na potencia total (os dois motores
## prontos). Informativo (loja/UI) - nao muda mais o modelo de voo (v7).
func tem_motor_agora() -> bool:
	return potencia_motor_atual() >= 1.0


## Multiplicador de arrasto (Aviao._integrar) - propriedade do TIER do aviao,
## nao de quanto ele foi construido (v7: nao ha mais "modelo motorizado" pra
## devolver o arrasto puro depois que o motor fica pronto, o balistico e o
## unico modelo o jogo inteiro). Quanto mais rapido o aviao base (fases
## avancadas), mais arrasto extra ele precisa pra nao virar impossivel de
## sustentar (arrasto cresce com o QUADRADO da velocidade, a margem acima do
## estol so cresce linear - medido no v4).
## V9/P3: a reducao de arrasto agora vem de 3 pecas combinadas (as 2 asas +
## a cauda), multiplicadas entre si - refinamento aerodinamico distribuido
## entre elas em vez de um "passo_e" unico da antiga trilha AVIAO. Empurra a
## distancia alcancavel pra cima a cada compra em qualquer uma das 3 (ver
## briefing_ajustes_v7.md §3 "estender a distancia" e v9.md P3).
## [A RECALIBRAR: formula por proporcao inversa ao quadrado da velocidade
## base, nao validada por medicao alem do Aviao de Papel - ver
## briefing_ajustes_v5.md §1]
func arrasto_mult_atual() -> float:
	var atual := aviao_atual()
	var referencia := Catalogo.veiculos()[0].velocidade_cruzeiro
	var base := pow(referencia / maxf(atual.velocidade_cruzeiro, 1.0), 2.0)
	var reducao := Atributos.multiplicador(Atributos.ASA_ESQUERDA, nivel(Atributos.ASA_ESQUERDA)) \
		* Atributos.multiplicador(Atributos.ASA_DIREITA, nivel(Atributos.ASA_DIREITA)) \
		* Atributos.multiplicador(Atributos.CAUDA, nivel(Atributos.CAUDA))
	return base / reducao


func meta_atual() -> float:
	if meta_forcada > 0.0:
		return meta_forcada
	return Config.meta_da_fase(fase_selecionada)


## Uso de teste: forca todas as trilhas do aviao ATUAL para um nivel de uma
## vez - o piloto automatico usa isto para reproduzir os cenarios do
## simulador. Nunca chamado pelo jogo real, onde o jogador compra nivel a
## nivel.
func forcar_niveis(nivel: int) -> void:
	var d := _niveis_atuais()
	for atributo in Atributos.ORDEM_POR_AVIAO:
		d[atributo] = clampi(nivel, 1, Atributos.nivel_maximo(atributo))
	nivel_estilingue = clampi(nivel, 1, Atributos.nivel_maximo(Atributos.ESTILINGUE))


## Recorde de distancia da fase selecionada agora - usado pela loja e pelo
## marcador em voo/mapa (briefing_ajustes_v3.md §7).
func recorde_atual() -> float:
	return float(recordes_por_fase.get(fase_selecionada, 0.0))


func progresso_geral() -> float:
	return clampf(float(fase_maxima_alcancada) / float(Config.TOTAL_FASES), 0.0, 1.0)


# --- Fim de corrida --------------------------------------------------------

## Registra o resultado e devolve o que mudou, para a tela de resultado.
func registrar_corrida(distancia: float, atingiu_meta: bool, voo_limpo: bool) -> Dictionary:
	total_corridas += 1

	# V3: moeda e so por metro percorrido - orbe nao rende moeda direto mais,
	# so energia (ver briefing_ajustes_v3.md §3). O bonus de conclusao e
	# separado do de voo limpo: um premia terminar, o outro premia terminar
	# limpo, e se somam quando os dois acontecem juntos.
	var ganho := distancia * Config.MOEDAS_POR_METRO
	ganho *= bonus_moedas()
	if atingiu_meta:
		ganho *= (1.0 + Config.BONUS_CONCLUSAO_FASE)
	if atingiu_meta and voo_limpo:
		ganho *= (1.0 + Config.BONUS_VOO_LIMPO)
	# V4: dificuldade maior paga mais moeda (5x/10x/15x) - recompensa quem joga
	# no nivel mais dificil em vez de so punir.
	ganho *= float(dificuldade_multiplicadores().get("moedas_mult", 1.0))
	# V9: bonus permanente de prestigio - ver bonus_prestigio().
	ganho *= bonus_prestigio()
	var moedas_ganhas := int(round(ganho))
	moedas += moedas_ganhas

	var novo_recorde := distancia > recorde_atual()
	if novo_recorde:
		recordes_por_fase[fase_selecionada] = distancia

	var subiu_fase := false
	var prestigiou := false
	var na_ultima_fase := fase_selecionada >= Config.TOTAL_FASES - 1
	if atingiu_meta and fase_selecionada >= fase_maxima_alcancada and not na_ultima_fase:
		fase_maxima_alcancada += 1
		fase_selecionada = fase_maxima_alcancada
		subiu_fase = true
	elif atingiu_meta and na_ultima_fase:
		# V9: "rolling over" (briefing_ajustes_v9.md P2) - terminar a ultima
		# fase de novo prestigia em vez de nao fazer nada. Reseta as trilhas
		# POR AVIAO (a economia de cada fase so foi calibrada pra ser
		# vencivel a partir do nivel 1 daquele aviao - manter tudo no maximo
		# tornaria a fase 1 trivial de novo). Estilingue e prestigios
		# acumulados NAO resetam - sao o que da sentido a repetir.
		prestigios += 1
		niveis_por_aviao.clear()
		fase_maxima_alcancada = 0
		fase_selecionada = 0
		prestigiou = true

	Eventos.moedas_alteradas.emit(moedas)
	salvar()

	return {
		"distancia": distancia,
		"moedas_ganhas": moedas_ganhas,
		"novo_recorde": novo_recorde,
		"atingiu_meta": atingiu_meta,
		"voo_limpo": voo_limpo,
		"subiu_fase": subiu_fase,
		"prestigiou": prestigiou,
		"prestigios": prestigios,
		"fase": fase_maxima_alcancada,
	}


# --- Persistencia ----------------------------------------------------------

func salvar() -> void:
	if _persistencia_desabilitada:
		return
	var niveis_json := {}
	for id in niveis_por_aviao:
		var por_atributo := {}
		for atributo in (niveis_por_aviao[id] as Dictionary):
			por_atributo[str(atributo)] = (niveis_por_aviao[id] as Dictionary)[atributo]
		niveis_json[str(id)] = por_atributo

	var recordes_json := {}
	for fase in recordes_por_fase:
		recordes_json[str(fase)] = recordes_por_fase[fase]

	var dados := {
		"versao": VERSAO_SAVE,
		"moedas": moedas,
		"fase_maxima_alcancada": fase_maxima_alcancada,
		"fase_selecionada": fase_selecionada,
		"niveis_por_aviao": niveis_json,
		"nivel_estilingue": nivel_estilingue,
		"prestigios": prestigios,
		"recordes_por_fase": recordes_json,
		"dificuldade_atual": str(dificuldade_atual),
		"total_corridas": total_corridas,
	}
	var arquivo := FileAccess.open(CAMINHO_SAVE, FileAccess.WRITE)
	if arquivo == null:
		push_warning("Nao foi possivel gravar o save.")
		return
	arquivo.store_string(JSON.stringify(dados, "\t"))
	arquivo.close()


func carregar() -> void:
	if not FileAccess.file_exists(CAMINHO_SAVE):
		return
	var arquivo := FileAccess.open(CAMINHO_SAVE, FileAccess.READ)
	if arquivo == null:
		return
	var lido: Variant = JSON.parse_string(arquivo.get_as_text())
	arquivo.close()
	if typeof(lido) != TYPE_DICTIONARY:
		push_warning("Save corrompido - ignorando.")
		return
	var d: Dictionary = lido

	# Save de versao anterior tem estrutura incompativel (ver comentario em
	# VERSAO_SAVE). Descartar e comecar limpo e melhor que migrar dados sem
	# equivalente no design novo.
	if int(d.get("versao", 1)) < VERSAO_SAVE:
		push_warning("Save de versao anterior descartado (design mudou).")
		return

	moedas = int(d.get("moedas", 0))
	var total_fases := Catalogo.veiculos().size()
	fase_maxima_alcancada = clampi(int(d.get("fase_maxima_alcancada", 0)), 0, total_fases - 1)
	fase_selecionada = clampi(int(d.get("fase_selecionada", 0)), 0, fase_maxima_alcancada)
	dificuldade_atual = StringName(str(d.get("dificuldade_atual", "medio")))
	total_corridas = int(d.get("total_corridas", 0))
	nivel_estilingue = clampi(int(d.get("nivel_estilingue", 1)), 1, Atributos.nivel_maximo(Atributos.ESTILINGUE))
	prestigios = maxi(0, int(d.get("prestigios", 0)))

	niveis_por_aviao.clear()
	var niveis_json: Variant = d.get("niveis_por_aviao", {})
	if typeof(niveis_json) == TYPE_DICTIONARY:
		for id_str in (niveis_json as Dictionary):
			var por_atributo: Variant = (niveis_json as Dictionary)[id_str]
			if typeof(por_atributo) != TYPE_DICTIONARY:
				continue
			var d2 := {}
			for atributo in Atributos.ORDEM_POR_AVIAO:
				var bruto: Variant = (por_atributo as Dictionary).get(String(atributo), 1)
				d2[atributo] = clampi(int(bruto), 1, Atributos.nivel_maximo(atributo))
			niveis_por_aviao[StringName(id_str)] = d2

	recordes_por_fase.clear()
	var recordes_json: Variant = d.get("recordes_por_fase", {})
	if typeof(recordes_json) == TYPE_DICTIONARY:
		for fase_str in (recordes_json as Dictionary):
			recordes_por_fase[int(fase_str)] = float((recordes_json as Dictionary)[fase_str])


func apagar_progresso() -> void:
	moedas = 0
	fase_maxima_alcancada = 0
	fase_selecionada = 0
	niveis_por_aviao.clear()
	nivel_estilingue = 1
	prestigios = 0
	recordes_por_fase.clear()
	dificuldade_atual = &"medio"
	total_corridas = 0
	salvar()

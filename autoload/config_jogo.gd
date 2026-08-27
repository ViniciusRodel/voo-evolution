extends Node
## Constantes do modelo de voo e da economia.
##
## ESTE ARQUIVO E O ESPELHO DE sim/modelo.py. Os valores foram derivados por
## simulacao, nao escolhidos: a primeira versao produzia ganho de 1,8% de
## distancia por compra (upgrade imperceptivel) e foi reprovada pelo proprio
## simulador. Se algum numero daqui mudar, o simulador precisa mudar junto -
## caso contrario o balanceamento validado deixa de valer.
##
## O teste em testes/piloto_automatico.gd compara a saida do jogo com os
## numeros da simulacao e falha se divergirem.

# --- Voo: constantes do nivel 1 -------------------------------------------

## Arrasto. Compartilhado por todos os avioes - DadosJogo.arrasto_mult_atual()
## e quem varia por aviao/tier.
const K_ARRASTO: float = 0.0012

## V5: gravidade do unico modelo de voo do jogo (v7:
## `Aviao._integrar()`) - age em cheio todo frame sobre `vy`, sem ser escalada
## por nenhum angulo comandado. Perto da gravidade real de proposito: um arco
## de Worms/Gunbound precisa de segundos pra se formar, nao fracoes de
## segundo.
const GRAVIDADE_BALISTICA: float = 13.0

## Angulo maximo de subida/descida comandado pelo jogador, em graus - usado so
## pra limitar `_angulo_alvo` (a direcao do "nudge", ver NUDGE_ACELERACAO), ja
## que o angulo VISUAL do aviao (Aviao.angulo_atual()) e sempre consequencia
## da velocidade real, nunca comandado direto.
const ANGULO_MAXIMO_GRAUS: float = 28.0
## Sensibilidade do arraste vertical: graus de comando por pixel arrastado.
const SENSIBILIDADE_ARRASTE: float = 0.22
## V9/P4: velocidade de decaimento do "nudge" (Aviao._angulo_alvo) de volta a
## zero quando o jogador NAO esta arrastando neste frame - graus por segundo.
## Um toque vira um ajuste pontual que se apaga sozinho em ~0,7s (28 graus /
## 40), nao um comando permanente. Ver briefing_ajustes_v9.md P4.
const DECAIMENTO_ANGULO_GRAUS: float = 40.0
## V9/P4: arrasto extra (m/s^2) enquanto o dedo esta pressionado na tela,
## arrastando ou nao - "segurar custa velocidade" (ver
## pesquisa_epic_plane_evolution.md §3). [A RECALIBRAR: primeiro palpite,
## mesma ordem de grandeza de ARRASTO_EXTRA_SEM_ASA, nao medido a fundo.]
const ARRASTO_POR_SEGURAR: float = 3.0
## Deslocamento lateral maximo, em metros (o corredor jogavel).
const CORREDOR_LARGURA: float = 22.0
const SENSIBILIDADE_LATERAL: float = 0.045
const SUAVIZACAO_LATERAL: float = 9.0

## Altura minima de voo acima do terreno. Abaixo disso, a corrida acaba.
const ALTURA_MINIMA: float = 1.4
## Teto de voo acima do terreno.
const ALTURA_MAXIMA: float = 190.0

## V9/P3: os limiares visuais do motor (helice/motor direito/motor esquerdo)
## viraram fracoes da PROPRIA peca HELICE (Atributos.HELICE), nao mais
## constantes globais - ver jogo/fabrica_modelos.gd e
## DadosJogo.potencia_motor_atual(). Saiu daqui porque agora e uma
## propriedade de UMA peca, nao do progresso do aviao inteiro.

## V7: quanto o motor NA POTENCIA MAXIMA multiplica o lancamento
## (DadosJogo.v_inicial(), via bonus_motor_lancamento()) - o motor deixou de
## sustentar voo e virou um bonus de lancamento, do mesmo jeito que o
## Estilingue ja e. [A CALIBRAR: primeiro palpite, no ambiente do maximo que
## bonus_estilingue() ja entrega no proprio maximo, pra nenhum dos dois
## dominar o outro - nao validado por medicao, ver briefing_ajustes_v7.md
## pergunta 2]
const BONUS_MOTOR_LANCAMENTO_MAXIMO: float = 0.20

## V5: aceleracao do "nudge" do jogador durante o voo balistico (planador) -
## mais fraca que a gravidade de proposito, pra inclinar a parabola sem
## reescreve-la. Mergulhar de proposito (mirar pra baixo) soma a essa
## aceleracao na queda e ganha velocidade real; puxar pra cima resiste, sem
## inverter a gravidade sozinho. Ver briefing_ajustes_v5.md §2.
const NUDGE_ACELERACAO: float = 14.0

## Penalidade real (nao so visual) de voar com menos de 2 asas - indice pelo
## numero de asas atuais (0, 1, 2), ver DadosJogo.asas_atual() e os mesmos
## limiares em jogo/fabrica_modelos.gd. Sem asa nenhuma o aviao mal sustenta
## voo: arrasto extra direto na soma de forcas (Aviao._integrar). Com as 2
## asas (a partir da segunda melhoria) a penalidade some por completo.
## V3: reforcada numa segunda rodada (2,6->3,6 / 1,85->2,2) - ainda estava
## facil demais sem asa.
const ARRASTO_EXTRA_SEM_ASA: Array[float] = [3.6, 1.4, 0.0]   # m/s^2

## Amortecimento da rolagem/guinada cosmetica (Aviao._orientar) por numero de
## asas - o modelo fica assimetrico com menos de 2 (so a asa direita, ou
## nenhuma), e rolar na amplitude normal lia como o aviao girando fora de
## controle em vez de so instavel. So visual - nao muda a dificuldade real.
const ROLAGEM_MULT_SEM_ASA: Array[float] = [0.30, 0.55, 1.0]

# --- Coleta (orfao pos-remocao dos orbes) -----------------------------------
##
## V4: os orbes foram removidos do cenario ("remova as bolas"). RAIO_COLETA_BASE
## fica so porque `DadosJogo.raio_coleta()` e o texto da trilha MOEDAS em
## `dados/atributos.gd` ainda apontam pra ele - a trilha promete "raio de
## coleta maior" mas nao ha mais nada pra coletar. Ver `briefing_ajustes_v4.md`
## para a proposta de repensar essa trilha junto do resto do modelo de voo.
const RAIO_COLETA_BASE: float = 5.5

# --- Correntes de ar --------------------------------------------------------

const TERMICA_A_CADA: float = 600.0     # metros
## V3: reduzido de 6,0 para 3,2 - o "vento" das correntes de ar estava forte
## demais (quase metade do empuxo base do Aviao de Papel, 11,4 m/s2).
const TERMICA_ACELERACAO: float = 3.2   # m/s2 enquanto dentro
const TERMICA_RAIO: float = 9.0
const TERMICA_COMPRIMENTO: float = 70.0

# --- Dificuldade -------------------------------------------------------------
##
## Multiplicadores aplicados em Aviao._integrar(): queda_mult escala a
## gravidade (GRAVIDADE_BALISTICA), velocidade_mult escala a soma de forcas
## inteira (mantendo o equilibrio entre elas, so mudando a intensidade geral).
## "Medio" ja e mais duro que a base historica do jogo (1,0) - o pedido era
## que a regua toda subisse, nao so o Dificil.
## V3: terceira rodada de reforco - Dificil 1,55/1,25 -> 2,00/1,35 -> 2,60/1,55,
## Medio 1,15/1,10 -> 1,30/1,15.
## V5: quarta rodada - so Facil e Medio subiram (Dificil ficou intocado por
## pedido explicito): Facil 0,80/0,90 -> 0,95/1,00 (deixa de ser mais facil
## que a base historica), Medio 1,30/1,15 -> 1,70/1,30.
##
## V4: "moedas_mult" - dificuldade maior paga mais moeda por corrida (1x/2x/3x),
## recompensando quem joga no nivel mais dificil em vez de so punir. Aplicado
## em DadosJogo.registrar_corrida().
## V5: dobrado em todos os niveis (1x/2x/3x -> 2x/3x/6x) - pedido explicito de
## aumentar a recompensa em moedas.
## V10: novo reforco (2x/3x/6x -> 5x/10x/15x), pedido explicito.
##
## V5: `var` em vez de `const` de proposito - ui/ajuste_moedas.gd (overlay de
## debug, tecla F2) escreve direto em DIFICULDADES[id]["moedas_mult"] em
## tempo real, pra testar valores sem recompilar. Reseta pro padrao acima a
## cada reinicio do jogo (nao persiste em disco).
static var DIFICULDADES := {
	&"facil": {"nome": "FACIL", "queda_mult": 0.95, "velocidade_mult": 1.00, "moedas_mult": 5.0},
	&"medio": {"nome": "MEDIO", "queda_mult": 1.70, "velocidade_mult": 1.30, "moedas_mult": 10.0},
	&"dificil": {"nome": "DIFICIL", "queda_mult": 2.60, "velocidade_mult": 1.55, "moedas_mult": 15.0},
}

# --- Impulso ---------------------------------------------------------------

const IMPULSO_ACELERACAO: float = 22.0
const IMPULSO_DURACAO: float = 2.2
const IMPULSO_RECARGA: float = 9.0
## V7: nenhum aviao tem mais tanque pra recarregar o impulso contra (energia
## saiu do jogo por completo) - todo mundo ganha um numero fixo de usos por
## corrida, motorizado ou nao.
const IMPULSO_USOS_POR_CORRIDA: int = 2

# --- Lancamento ------------------------------------------------------------

## v_inicial = v_cruzeiro * (BASE + AMPLITUDE * qualidade) * bonus_estilingue
## V4: 0,90/0,35 -> 0,70/0,25 - um lancamento verde (q=1) estava dando forca
## de sobra pra sozinho levar o planador ate a meta, mesmo com so 1 asa.
## Agora nem um lancamento perfeito passa da velocidade de cruzeiro de
## referencia (BASE+AMPLITUDE = 0,95 < 1,0); um lancamento ruim (q=0) sai bem
## abaixo dela.
const LANCAMENTO_BASE: float = 0.70
const LANCAMENTO_AMPLITUDE: float = 0.25
## Duracao de uma varredura do medidor, em segundos.
const LANCAMENTO_CICLO: float = 1.2

## Puxao visual do estilingue em 3D (cosmetico - so move o modelo, nunca a
## posicao real do aviao, que so passa a existir com lancar()).
const PUXAO_TRAS_MAXIMO: float = 4.5     # metros, com tensao = 1
const PUXAO_LATERAL_MAXIMO: float = 2.6  # metros, com mira = +-1
const PUXAO_INCLINACAO_MAXIMA: float = 14.0  # graus, nariz sobe com a tensao

# --- Economia --------------------------------------------------------------

## V3: subiu de 0,05 para compensar a remocao da moeda por orbe (agora e so
## por metro, ver briefing_ajustes_v3.md §3) e para dar a "recompensa maior"
## pedida.
const MOEDAS_POR_METRO: float = 0.08
## Bonus por chegar a meta sem tocar o solo. Recompensar o voo limpo funciona
## melhor que punir o sujo, porque a recompensa e visivel e a punicao so e
## sentida.
const BONUS_VOO_LIMPO: float = 0.15
## V3: bonus por COMPLETAR a fase (bater a meta), separado do bonus de voo
## limpo acima - um premia terminar limpo, o outro premia terminar. Os dois
## se somam quando os dois acontecem na mesma corrida.
const BONUS_CONCLUSAO_FASE: float = 0.35
## V9: bonus PERMANENTE de moedas por "prestigio" (DadosJogo.prestigios) -
## ver briefing_ajustes_v9.md P2 ("rolling over"). +50% por volta completa
## no jogo inteiro. [A CALIBRAR: primeiro palpite, nao medido contra quantas
## voltas um jogador real da em quanto tempo.]
const BONUS_PRESTIGIO_POR_NIVEL: float = 0.50

# --- Fases -----------------------------------------------------------------

## V3: meta de cada fase, uma por aviao (ver dados/catalogo.gd). Deixou de ser
## uma progressao geometrica fechada porque a velocidade BASE agora pula de
## aviao pra aviao.
##
## V7: recalibrada por completo (ver briefing_ajustes_v7.md §3) apos o motor
## deixar de sustentar voo (§2) - as metas antigas assumiam o velho modelo
## motorizado-atrator e ficaram MUITO acima do que o modelo balistico unico
## consegue. A logica virou o OPOSTO da calibracao do nivel 1 (que busca
## folga por BAIXO): aqui a meta fica um pouco ACIMA da capacidade no nivel
## maximo, pra que "tudo evoluido" sozinho ainda nao seja suficiente -
## precisa somar evolucao maxima com mergulhos bem pilotados.
##
## V8 (dados/atributos.gd): trilhas expandidas para ate 30 niveis. Metodo de
## calibracao estabelecido la e reaplicado aqui: `--teste-voo --nivel=<max>
## --fase=<N> --dificuldade=dificil --meta-livre --corridas=5`. Meta =
## capacidade media medida * 1,18 (18% de margem, mesma razao meta/capacidade
## que dados/atributos.gd V8 ja usa).
## V9/P3 (briefing_ajustes_v9.md): AVIAO virou 4 pecas (Asa Esquerda/Direita/
## Cauda/Helice, max 8 cada) - curva de poder no nivel maximo mudou de novo,
## remedido com `--nivel=40` (40 e o maior max entre as pecas/trilhas atuais;
## forcar_niveis() clampa cada uma no seu proprio teto).
## V9/P4: novo arrasto por segurar o dedo (Config.ARRASTO_POR_SEGURAR) muda a
## capacidade de novo, ainda que pouco (o piloto automatico agora simula
## segurar a corrida inteira - ver testes/piloto_automatico.gd) - remedido
## mais uma vez com o mesmo metodo.
## [A RECALIBRAR: piloto usado na medicao mantem altitude fixa em vez de
## mergulhar estrategicamente, pode ficar mais folgado do que um humano
## habilidoso conseguiria fechar - ver briefing_ajustes_v7.md pergunta 3, sem
## resposta do usuario ainda.]
const METAS_FASE: Array[float] = [
	1372.0, 1626.0, 1685.0, 2519.0, 3094.0, 3738.0, 4692.0,
	5791.0, 7143.0, 8838.0, 10048.0, 13084.0, 15467.0,
]
const TOTAL_FASES: int = 13

# --- Mundo -----------------------------------------------------------------

const PEDACO_COMPRIMENTO: float = 120.0
const PEDACOS_MIN: int = 8
const PEDACOS_MAX: int = 22
const SEGUNDOS_DE_CENARIO: float = 4.5

# --- Obstaculos --------------------------------------------------------------
##
## V8 (P2 do roadmap - briefing_ajustes_v8.md): reativa jogo/gerador_pista.gd/
## jogo/obstaculo.gd, que existiam prontos mas nunca chegaram a ser
## instanciados por cenas/principal.gd. Tunáveis de geracao de fileira ficam
## em jogo/gerador_obstaculos.gd (auto-contido, como o gerador_pista.gd
## original) - aqui so o tamanho do pool, que e uma decisao de orcamento de
## desempenho, nao de design de fase.
const POOL_OBSTACULOS: int = 64

# --- Alvos de desempenho ---------------------------------------------------

const ALVO_FPS: int = 60
const ALVO_FRAME_TIME_P99_MS: float = 20.0
const ALVO_DURACAO_TESTE_S: float = 180.0


## km/h exibidos no HUD. FUNCAO DE VIEW PURA: nenhuma regra de jogo pode ler
## isto. A distancia e honesta; o velocimetro e o unico numero cosmetico,
## porque e o unico que nao alimenta nenhuma formula.
##
## Calibrada em dois pontos reais: 97,5 m/s -> 50 km/h (medido no video de
## referencia) e ~1000 m/s -> ~1200 km/h (topo do catalogo do jogo original).
static func velocidade_exibida(v_ms: float) -> float:
	if v_ms <= 0.0:
		return 0.0
	return 0.0964 * pow(v_ms, 1.365)


## Meta de distancia de uma fase (indice base 0).
static func meta_da_fase(indice: int) -> float:
	return METAS_FASE[clampi(indice, 0, METAS_FASE.size() - 1)]


## Multiplicadores da dificuldade escolhida. Cai em "medio" se o id nao existe
## (save antigo com um valor que nao existe mais, por exemplo).
static func dificuldade(id: StringName) -> Dictionary:
	return DIFICULDADES.get(id, DIFICULDADES[&"medio"])

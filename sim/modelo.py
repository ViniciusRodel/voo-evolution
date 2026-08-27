"""
Simulador do modelo de voo e da economia do Voo Evolution.

Existe para que as tabelas do documento de design sejam DERIVADAS, nao
inventadas: todo numero publicado sai de uma execucao deste arquivo. A primeira
versao destas constantes foi REPROVADA aqui mesmo - produzia ganho medio de
1,8% de distancia por corrida, que e o fracasso classico do "upgrade
imperceptivel". Os valores atuais sao o resultado do rebalanceamento.

MODELO DE VOO (voo sustentado com orcamento de energia)

    dv/dt  = a_motor - k_arrasto * v^2 - g_ef * sin(theta)
    v_eq   = sqrt(a_motor / k_arrasto)            # velocidade de cruzeiro
    t_voo  = E_max / (c - R * f * e_orbe)         # duracao ate a energia acabar
    d_cap  = integral(v dt) * (1 + bonus)         # capacidade de distancia
    d_real = min(d_cap, meta_da_fase)             # a corrida para na meta

DECISAO 1 - consumo por SEGUNDO, nao por metro.
Torna a duracao da corrida uma constante projetavel e faz a distancia ser o
produto direto das melhorias de velocidade. Troca realismo por controlabilidade,
de proposito.

DECISAO 2 - orbes em cadencia de TEMPO, nao de distancia.
Se fossem a cada X metros, a renda de energia cresceria junto com a velocidade,
o denominador (c - R*f*e) tenderia a zero e o voo viraria infinito. Em cadencia
de tempo, a renda e constante e o sistema nao diverge.

DECISAO 3 - poucos niveis, degraus grandes.
Com 6 atributos de 30 niveis cada seriam 174 compras para um crescimento total
de ~17x, ou seja 1,7% por compra: invisivel. Com 44 compras, cada uma vale ~6,5%
- acima do limiar de percepcao. O numero de niveis e uma consequencia
matematica do ganho por compra desejado, nao uma escolha estetica.

V2 - TRES TRILHAS EM VEZ DE SEIS ATRIBUTOS.
Motor, Aerodinamica, Tanque e Impulso viraram uma unica trilha "Aviao": cada
nivel sobe velocidade de cruzeiro, energia maxima e bonus de impulso ao mesmo
tempo (tres multiplicadores diferentes por nivel, nao um so), e o numero de
niveis foi calibrado para reproduzir o MESMO crescimento total de distancia
(~14x so dessas quatro fontes) que o modelo de 6 atributos ja tinha validado -
nao e um numero novo, e o mesmo teto redistribuido em uma trilha visivel em vez
de quatro. Ima virou "Moedas" e Estilingue nao mudou; so trocaram de nome.
"""

import math

# ------------------------------------------------------------- voo (nivel 1)

K_ARRASTO_0 = 0.0012      # 1/m
A_MOTOR_0 = 11.4          # m/s^2  -> v_eq = 97.5 m/s = 50 km/h no HUD
E_MAX_0 = 68.0            # unidades de energia no tanque
CONSUMO = 2.3             # unidades/s (constante - ver DECISAO 1). V3: 2,0->2,3
ORBES_POR_SEGUNDO = 0.85  # cadencia de orbes (ver DECISAO 2)
ENERGIA_POR_ORBE = 1.2
COLETA_0 = 0.35           # fracao dos orbes efetivamente coletada

G_EFETIVO = 25.0          # m/s^2 - gravidade amplificada para o relevo pesar
                          # no gameplay. Real (9,81) torna descidas irrelevantes.

# ------------------------------------------------------------------ economia
#
# V3: moeda e so por metro percorrido - orbe nao rende moeda direto mais, so
# energia. MOEDAS_POR_METRO subiu para compensar e para dar a "recompensa
# maior por fase" pedida. Ver briefing_ajustes_v3.md §3.

MOEDAS_POR_METRO = 0.08
BONUS_CONCLUSAO_FASE = 0.35
QUALIDADE_LANCAMENTO_MEDIA = 0.70

# --------------------------------------------------------- aviao por fase
#
# V3: um aviao por fase, cada um com uma velocidade BASE maior que o anterior
# - ESPELHO de dados/catalogo.gd::V_EQ_BASE. Fator R=1,245/fase a partir de
# 97,5 m/s (o Aviao de Papel, fase 1 - mesmo numero do modelo v1/v2, para o
# HUD de 50 km/h continuar batendo com o video de referencia).

R_FASE = 1.245
TOTAL_FASES = 13


def aviao_base(indice_fase: int) -> float:
    """v_eq (m/s) do aviao daquela fase no nivel 1 da trilha propria."""
    return math.sqrt(A_MOTOR_0 / K_ARRASTO_0) * (R_FASE ** indice_fase)


def metas_fase(headroom=0.90):
    """Meta de cada fase: capacidade do aviao daquela fase, nivel 1 em tudo,
    dividida pela folga. headroom=0,90 significa que o aviao novo chega
    sozinho a 90% da meta - poucas corridas/compras fecham o resto (ver
    briefing_ajustes_v3.md §2)."""
    metas = []
    for i in range(TOTAL_FASES):
        av = Aviao(indice_fase=i)
        metas.append(capacidade(av) / headroom)
    return metas

# --------------------------------------------------------------- atributos
#
# V3: as trilhas encolheram de "para o jogo inteiro" (v2: 37/6/4) para "para
# uma fase so" (poucas corridas, reseta ao trocar de aviao - ver
# briefing_ajustes_v3.md §6). "aviao" e a fusao de Motor+Aerodinamica+Tanque+
# Impulso: um nivel move tres multiplicadores ao mesmo tempo (passo_v,
# passo_e, passo_i). "moedas" e o antigo Ima. "estilingue" nao mudou de forma.

ATRIBUTOS = {
    # V6: 6->10 niveis, pra abrir espaco de "t" pros 3 estagios novos do
    # motor (helices/motor direito/motor esquerdo). Passo por nivel caiu
    # junto pra manter o efeito total no nivel maximo parecido com o de antes.
    # V8: passo_v 1,025->1,060 e passo_e 1,011->1,085 - no maximo, Dificil
    # (queda/velocidade 2,60/1,55) nao dava pra completar nem a Fase 1
    # (312 m medidos contra meta de 765 m). Ver dados/atributos.gd (espelho).
    # V9: 10->14 niveis, passo_v 1,060->1,075, passo_e 1,085->1,100,
    # passo_i 1,0165->1,020 - mais profundidade de progressao, pedido
    # explicito. So estica a folga ja calibrada em V8, nunca reduz.
    # V10: 14->30 niveis - passo recalculado pra manter o MESMO efeito total
    # do maximo de V9, so espalhado por mais compras. Ver dados/atributos.gd.
    "aviao": {
        "max": 30,
        "passo_v": 1.0330,   # velocidade de cruzeiro por nivel
        "passo_e": 1.0437,   # energia maxima (duracao do tanque) por nivel
        "passo_i": 1.0089,   # bonus de impulso por nivel
        "c0": 150.0, "r": 1.220,
    },
    # V10: 4->30 niveis, r 1,900->1,220 (com 1,900 o nivel 30 custava ~30
    # bilhoes de moedas - inalcancavel). Ver dados/atributos.gd.
    "moedas":     {"max": 30, "passo": 1.015, "c0": 250.0, "r": 1.220},
    # V4: 3->6 niveis, passo 1,020->1,025 - LANCAMENTO_BASE/AMPLITUDE cairam
    # (ver config_jogo.gd), entao o lancamento base ficou mais fraco e essa
    # trilha precisa de mais alcance pra compensar via progressao.
    # V8: 6->8 niveis, passo 1,025->1,055 - mesmo motivo do "aviao" acima.
    # V9: 8->10 niveis, passo 1,055->1,065 - mais profundidade de progressao.
    # V10: 10->30 niveis, passo recalculado (mesmo efeito total de V9), r
    # 1,600->1,220 (mesmo motivo do "moedas" acima).
    "estilingue": {"max": 30, "passo": 1.0197, "c0": 120.0, "r": 1.220},
}

ROTULOS = {
    "aviao": "Avião", "moedas": "Moedas", "estilingue": "Estilingue",
}


class Aviao:
    def __init__(self, indice_fase=0):
        self.niveis = {k: 1 for k in ATRIBUTOS}
        self.v_eq_base = aviao_base(indice_fase)

    # --- derivados ---------------------------------------------------------

    def v_cruzeiro(self):
        m = ATRIBUTOS["aviao"]["passo_v"] ** (self.niveis["aviao"] - 1)
        return self.v_eq_base * m

    def a_motor(self):
        # Reconstruido a partir de v_eq para o transiente do lancamento ficar
        # coerente com o equilibrio.
        return K_ARRASTO_0 * self.v_cruzeiro() ** 2

    def e_max(self):
        return E_MAX_0 * ATRIBUTOS["aviao"]["passo_e"] ** (self.niveis["aviao"] - 1)

    def taxa_coleta(self):
        return min(0.95, COLETA_0 * ATRIBUTOS["moedas"]["passo"] ** (self.niveis["moedas"] - 1))

    def bonus_moedas(self):
        """Moedas (ex-Ima) tambem aumenta a renda: cada nivel coleta mais orbes."""
        return 1.0 + 0.08 * (self.niveis["moedas"] - 1)

    def bonus_impulso(self):
        return ATRIBUTOS["aviao"]["passo_i"] ** (self.niveis["aviao"] - 1)

    def bonus_estilingue(self):
        return ATRIBUTOS["estilingue"]["passo"] ** (self.niveis["estilingue"] - 1)

    def v_inicial(self, qualidade=QUALIDADE_LANCAMENTO_MEDIA):
        # V4: 0,90/0,35 -> 0,70/0,25 (ver config_jogo.gd LANCAMENTO_BASE/AMPLITUDE)
        return self.v_cruzeiro() * (0.70 + 0.25 * qualidade) * self.bonus_estilingue()

    def custo(self, atributo):
        cfg = ATRIBUTOS[atributo]
        return cfg["c0"] * cfg["r"] ** (self.niveis[atributo] - 1)

    def no_maximo(self, atributo):
        return self.niveis[atributo] >= ATRIBUTOS[atributo]["max"]

    def nivel_visual(self):
        """Nivel exibido do aviao (1 a 20), derivado da soma dos atributos.
        E ele que a fabrica de modelos ja implementada consome."""
        soma = sum(self.niveis.values())
        soma_min = len(ATRIBUTOS)
        soma_max = sum(c["max"] for c in ATRIBUTOS.values())
        t = (soma - soma_min) / (soma_max - soma_min)
        return 1 + int(round(t * 19))


def duracao(av: Aviao):
    renda = ORBES_POR_SEGUNDO * av.taxa_coleta() * ENERGIA_POR_ORBE
    liquido = CONSUMO - renda
    if liquido <= 0.05:
        raise ValueError("Economia de orbes divergiu: voo infinito.")
    return av.e_max() / liquido


def capacidade(av: Aviao, qualidade=QUALIDADE_LANCAMENTO_MEDIA):
    """Distancia que o aviao consegue voar se nada o interromper."""
    t = duracao(av)
    dt = 0.05
    v = av.v_inicial(qualidade)
    a = av.a_motor()
    d = 0.0
    for _ in range(int(t / dt)):
        v += (a - K_ARRASTO_0 * v * v) * dt
        d += v * dt
    return d * av.bonus_impulso()


def simular_corrida(av: Aviao, meta=None, qualidade=QUALIDADE_LANCAMENTO_MEDIA):
    cap = capacidade(av, qualidade)
    t_total = duracao(av)
    atingiu = meta is not None and cap >= meta
    d = min(cap, meta) if meta is not None else cap
    t = t_total * (d / cap) if cap > 0 else t_total
    orbes = ORBES_POR_SEGUNDO * av.taxa_coleta() * t
    moedas = d * MOEDAS_POR_METRO * av.bonus_moedas()
    if atingiu:
        moedas *= (1.0 + BONUS_CONCLUSAO_FASE)
    return {
        "distancia": d, "capacidade": cap, "duracao": t, "duracao_total": t_total,
        "moedas": moedas, "orbes": orbes, "atingiu_meta": atingiu,
        "v_cruzeiro": av.v_cruzeiro(),
    }


def velocidade_exibida(v_ms):
    """km/h no HUD. Funcao de VIEW pura: nenhuma regra de jogo pode ler isto.

    Calibrada em dois pontos: 97,5 m/s -> 50 km/h (medido no video de
    referencia) e ~1000 m/s -> ~1200 km/h (topo do catalogo, das capturas da
    loja do jogo original).
    """
    return 0.0964 * (v_ms ** 1.365)


def melhor_compra(av: Aviao, saldo):
    """Politica gulosa por ganho de capacidade por moeda. Serve para DESCOBRIR
    qual atributo e o mais atraente em cada momento, em vez de supor."""
    base = capacidade(av)
    melhor, melhor_valor = None, 0.0
    for atributo in ATRIBUTOS:
        if av.no_maximo(atributo):
            continue
        custo = av.custo(atributo)
        if custo > saldo:
            continue
        av.niveis[atributo] += 1
        try:
            ganho = capacidade(av) - base
        except ValueError:
            ganho = -1.0
        av.niveis[atributo] -= 1
        valor = ganho / custo
        if valor > melhor_valor:
            melhor, melhor_valor = atributo, valor
    return melhor

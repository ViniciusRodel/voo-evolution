"""Simula a progressao completa: fases, compras e economia. Emite as tabelas do
documento de design e um diagnostico de balanceamento."""

from modelo import (Aviao, ATRIBUTOS, ROTULOS, capacidade, duracao,
                    simular_corrida, velocidade_exibida, melhor_compra)

# Metas por fase. Geometrica: cada fase exige ~28% mais que a anterior, o que
# corresponde a cerca de 4 compras (4 x 6,5%).
META_INICIAL = 3900.0
RAZAO_META = 1.28
N_FASES = 14


def metas():
    return [META_INICIAL * RAZAO_META ** i for i in range(N_FASES)]


def simular(n_corridas=40, verbose=False):
    av = Aviao()
    saldo = 0.0
    fase = 0
    ms = metas()
    hist = []

    for i in range(1, n_corridas + 1):
        fase_jogada = min(fase, len(ms) - 1)
        meta = ms[fase_jogada]
        r = simular_corrida(av, meta)
        saldo += r["moedas"]
        if r["atingiu_meta"]:
            fase += 1

        compras = []
        while True:
            alvo = melhor_compra(av, saldo)
            if alvo is None:
                break
            saldo -= av.custo(alvo)
            av.niveis[alvo] += 1
            compras.append(ROTULOS[alvo])

        hist.append({
            "corrida": i, "fase": fase, "fase_jogada": fase_jogada, "meta": meta,
            "distancia": r["distancia"], "capacidade": r["capacidade"],
            "duracao": r["duracao"], "duracao_total": r["duracao_total"],
            "moedas": r["moedas"], "saldo": saldo,
            "vhud": velocidade_exibida(r["v_cruzeiro"]),
            "atingiu": r["atingiu_meta"], "compras": compras,
            "nivel_visual": av.nivel_visual(), "niveis": dict(av.niveis),
        })
    return hist, av


def fmt(n):
    return f"{n:,.0f}".replace(",", ".")


def diagnostico(hist):
    caps = [h["capacidade"] for h in hist]
    ganhos = [(caps[i] / caps[i - 1] - 1) * 100 for i in range(1, len(caps))
              if caps[i] > caps[i - 1] * 1.0001]
    compras_total = sum(len(h["compras"]) for h in hist)
    corridas_sem_compra = sum(1 for h in hist if not h["compras"])
    print("--- DIAGNOSTICO ---")
    print("corridas simuladas ............ %d" % len(hist))
    print("upgrades comprados ............ %d" % compras_total)
    print("corridas sem nenhuma compra ... %d" % corridas_sem_compra)
    if ganhos:
        print("ganho de capacidade por compra: medio %.1f%% | min %.1f%% | max %.1f%%"
              % (sum(ganhos) / len(ganhos), min(ganhos), max(ganhos)))
    print("capacidade corrida 1 .......... %s m" % fmt(caps[0]))
    print("capacidade corrida %d ......... %s m (x%.1f)"
          % (len(hist), fmt(caps[-1]), caps[-1] / caps[0]))
    print("duracao total corrida 1 ....... %.1f s" % hist[0]["duracao_total"])
    print("duracao total corrida %d ...... %.1f s" % (len(hist), hist[-1]["duracao_total"]))
    print("fase alcancada ................ %d de %d" % (hist[-1]["fase"] + 1, N_FASES))
    print("nivel visual do aviao ......... %d de 20" % hist[-1]["nivel_visual"])
    print("niveis finais ................. %s" % hist[-1]["niveis"])
    metas_batidas = sum(1 for h in hist if h["atingiu"])
    print("corridas que bateram a meta ... %d" % metas_batidas)


def tabela_corridas(hist, n=30):
    out = ["| # | Fase | Meta | Distância | Duração | HUD | Moedas | Saldo | Comprou |",
           "|---|---|---|---|---|---|---|---|---|"]
    for h in hist[:n]:
        marca = " ✅" if h["atingiu"] else ""
        out.append("| %d | %d | %s m | %s m%s | %.0f s | %.0f km/h | %s | %s | %s |" % (
            h["corrida"], h["fase_jogada"] + 1, fmt(h["meta"]), fmt(h["distancia"]), marca,
            h["duracao"], h["vhud"], fmt(h["moedas"]), fmt(h["saldo"]),
            ", ".join(h["compras"]) if h["compras"] else "—"))
    return "\n".join(out)


def tabela_atributos():
    out = ["| Atributo | Níveis | Efeito por nível | Custo do nível n | Custo nv.2 | Custo máx. |",
           "|---|---|---|---|---|---|"]
    efeitos = {
        "aviao": "v_cruzeiro ×1,0627, E_max ×1,0086, impulso ×1,0046",
        "moedas": "coleta × 1,015 e +8% de moedas",
        "estilingue": "v_inicial × 1,020 (+2,0%)",
    }
    for a, cfg in ATRIBUTOS.items():
        c2 = cfg["c0"] * cfg["r"]
        cmax = cfg["c0"] * cfg["r"] ** (cfg["max"] - 1)
        out.append("| %s | %d | %s | %s × %.3f^(n−1) | %s | %s |" % (
            ROTULOS[a], cfg["max"], efeitos[a], fmt(cfg["c0"]), cfg["r"],
            fmt(c2), fmt(cmax)))
    return "\n".join(out)


def tabela_fases():
    biomas = ["Duna inicial", "Deserto aberto", "Terreno rachado", "Vilarejo e igreja",
              "Cidade do velho oeste", "Estação e locomotiva", "Mesas rochosas",
              "Cânion profundo", "Ponte ferroviária", "Planalto alto",
              "Tempestade de areia", "Salinas", "Costa e falésias", "Arquipélago",
              "Floresta tropical", "Cordilheira", "Geleira", "Aurora polar",
              "Vulcões", "Deserto de sal", "Alta atmosfera", "Estratosfera",
              "Mesosfera", "Órbita baixa"]
    out = ["| Fase | Meta | Nível visual | HUD | Duração | Bioma |",
           "|---|---|---|---|---|---|"]
    hist, _ = simular(120)
    vistas = {}
    for h in hist:
        vistas.setdefault(h["fase_jogada"], h)
    for i, meta in enumerate(metas()):
        h = vistas.get(i)
        if h is None:
            continue
        out.append("| %d | %s m | %d | %.0f km/h | %.0f s | %s |" % (
            i + 1, fmt(meta), h["nivel_visual"], h["vhud"], h["duracao_total"],
            biomas[i % len(biomas)]))
    return "\n".join(out)


if __name__ == "__main__":
    hist, av = simular(40)
    diagnostico(hist)
    print()
    print("### Atributos\n")
    print(tabela_atributos())
    print("\n### 30 primeiras corridas\n")
    print(tabela_corridas(hist, 30))
    print("\n### Fases\n")
    print(tabela_fases())

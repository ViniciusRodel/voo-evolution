# Roadmap de implementação — v3 (avião por fase, mapa, dificuldade, economia)

Executa `briefing_ajustes_v3.md` em etapas. Cada etapa é testável sozinha
(importa no Godot sem erro, roda `--teste-voo`) antes de passar pra próxima —
mesmo método usado no `briefing_ajustes_v2.md`, que já foi validado em jogo.

Onde uma decisão do briefing ficou em aberto (curva de velocidade dos 13
aviões, níveis por fase, valores de dificuldade), uso a opção recomendada já
escrita no próprio briefing como ponto de partida, calibrada por simulação —
não chuto número. Fica marcado **[a recalibrar]** onde o valor é um primeiro
palpite plausível, não uma calibração final por playtest real.

| Etapa | Conteúdo | Depende de | Status |
|---|---|---|---|
| 0+1 | Estado por avião + catálogo de 13 aviões + física por avião | — | 🔧 em andamento |
| 2 | Fases menores + moedas só-distância + bônus de conclusão | 0+1 | ⬜ |
| 3 | Seletor de dificuldade (Fácil/Normal/Difícil) | — | ⬜ |
| 4 | Mapa de navegação (revive `selecao_veiculos.gd`) + indicador de recorde por estágio | 0+1 | ⬜ |
| 5 | Marcador de recorde em voo | 0+1, 4 | ⬜ |
| 6 | Sugestões de jogabilidade baratas (tutorial diegético, "quase lá", rastro de velocidade) | 2 | ⬜ |
| 7 | Física fina — pendente de feedback específico (`briefing_ajustes_v3.md` pergunta 5) | — | ⬜ bloqueado |

Etapas 0+1 e 2 saem nesta rodada. As demais continuam em rodadas seguintes,
cada uma testada antes de eu seguir pra próxima.

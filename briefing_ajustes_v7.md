# Voo Evolution — Briefing de ajustes v7 (motor vira lançamento, não sustentação)

Continuação de `briefing_ajustes_v5.md`/`v6.md` (trajetória balística, motor
gradual em 3 partes - ambos implementados). Feedback depois de jogar: *"o
motor no jogo ainda tá muito roubado"* - mesmo com o motor entrando aos
poucos (v6), o resultado final ainda entrega voo fácil demais. Este
documento propõe uma mudança de raiz maior que a do v6: o motor **deixa de
sustentar voo** e vira parte do lançamento.

**Status: nada abaixo foi implementado ainda.** É a especificação para o
próximo trabalho, como pedido.

---

## Resumo do pedido

1. O foco do jogo deveria ser **mergulhar o avião** - inclusive
   visualmente, com o nariz se inclinando pra baixo conforme perde
   sustentação - o tempo todo, do início ao fim da evolução.
2. O motor devia ser **um PLUS pro lançamento**, não uma forma de sustentar
   voo. Hoje, ao evoluir e ganhar o motor, a fase fica fácil demais.
3. A distância de cada fase precisa **esticar um pouco mais**.
4. Com o avião **totalmente evoluído** (tudo no máximo), completar a fase
   devia ficar **no limite** - justo, não folgado.

---

## 1. Diagnóstico: por que o motor ainda "rouba" mesmo depois do v6

O v6 já tentou suavizar a chegada do motor (3 estágios, potência fracionária
- ver `DadosJogo.potencia_motor_atual()`), mas manteve a mesma
**arquitetura de fundo**: quando a potência bate 100%,
`Aviao._integrar_motorizado()` assume por completo, e esse método é o
modelo antigo inteiro - `v_eq` como ATRATOR, ângulo como variável de
CONTROLE. É exatamente esse atrator que faz o jogo "carregar" o jogador -
uma vez que o avião está totalmente evoluído, a fase 100% motorizada volta
a ser o "piloto automático" que o v5 tinha acabado de eliminar do trecho
planador. O v6 amenizou a TRANSIÇÃO, mas não mudou o que existe do outro
lado dela.

**A causa raiz: o jogo tem dois modelos de física, e um deles (o
motorizado) é fundamentalmente mais fácil que o outro (o balístico) porque
foi desenhado pra manter altitude sozinho.** Suavizar a chegada não resolve
isso - só adia. O pedido agora é remover essa segunda física por completo.

---

## 2. Proposta: um modelo de voo só, pro jogo inteiro

**Ideia central:** `Aviao._integrar_balistico()` (gravidade real, arrasto,
nudge do jogador, sem atrator) vira o **único** modelo de física, do Avião
de Papel até o avião mais evoluído da última fase. `Aviao._integrar_motorizado()`
e tudo que ele carrega (`v_eq` como atrator, `FRACAO_ESTOL`, ângulo
comandado) deixam de existir. Consequência direta: o nariz do avião **sempre**
aponta pra onde ele está realmente indo (`atan2(vy, vx)`) - inclusive se
inclinando pra baixo conforme a velocidade vertical fica negativa, que é
exatamente o efeito visual pedido no item 1. Isso não precisa ser construído
- já é o comportamento do modelo balístico; só precisa parar de ser
substituído pelo motorizado no fim da evolução.

### Onde entra o motor, então

O motor deixa de ser "uma força que empurra o avião pra frente durante o
voo" e vira **um bônus no momento do lançamento** - do mesmo jeito que o
Estilingue (`Atributos.ESTILINGUE`) já é. Proposta:

```gdscript
## DadosJogo.v_inicial() ja multiplica por bonus_estilingue(). V7: soma um
## segundo multiplicador, do motor - quanto mais construido (helices, motor
## direito, motor esquerdo - potencia_motor_atual()), maior o lancamento.
func v_inicial(qualidade: float) -> float:
    return v_cruzeiro() \
        * (Config.LANCAMENTO_BASE + Config.LANCAMENTO_AMPLITUDE * clampf(qualidade, 0.0, 1.0)) \
        * bonus_estilingue() \
        * bonus_motor_lancamento()  # NOVO


func bonus_motor_lancamento() -> float:
    return 1.0 + Config.BONUS_MOTOR_LANCAMENTO_MAXIMO * potencia_motor_atual()
```

Isso muda o que "evoluir o avião até o motor" significa: em vez de trocar a
FÍSICA (o que hoje faz a fase virar fácil), o motor melhora o PONTO DE
PARTIDA de cada voo - lançamento mais forte, ápice mais alto, mais distância
disponível antes da queda -, mas o jogador continua tendo que administrar a
queda com mergulho o tempo todo, em qualquer nível de evolução. É a leitura
mais literal do pedido: *"o motor ser mais um PLUS e melhoria para o
lançamento"*.

### O que isso simplifica (e o que fica pendente de decisão)

- `_integrar_motorizado()`, `FRACAO_ESTOL`/`MULT_ESTOL_SEM_ASA`, e a
  ramificação `if DadosJogo.tem_motor_agora(): ... else: ...` em
  `Aviao._process()` são removidos - o jogo passa a ter uma física só,
  mais simples de manter.
- `tem_motor_agora()` (booleano "motor em potência total") deixa de ter uso
  físico - pode continuar existindo só pra UI/visual (ex.: mostrar "MOTOR
  COMPLETO" na loja), sem afetar `Aviao._integrar()`.
- **Pergunta em aberto:** o motor dá ALGUM empuxo contínuo durante o voo
  (bem mais fraco que hoje, um "PLUS" de verdade), ou é 100% só lançamento,
  zero efeito depois que o avião já está no ar? O pedido soa mais pra
  segunda opção, mas vale confirmar - ver perguntas no fim.

---

## 3. Distância maior, e "no limite" com tudo no máximo

### O pedido, em números

Hoje `Config.METAS_FASE` foi calibrado (v4/v5, parcialmente) pra que o
avião recém-desbloqueado (nível 1 da trilha própria) fique bem abaixo da
meta, e suba conforme compra upgrades. O pedido agora é sobre a **outra
ponta**: com a trilha Avião/Moedas/Estilingue **totalmente maximizada**
(10/4/6, v6), bater a meta deve ficar apertado - não uma formalidade.

### Por que isso precisa de medição nova, não só aumentar um número

Duas mudanças acontecem ao mesmo tempo:
1. O modelo de física muda por completo (§2) - a "capacidade" de um avião
   no nível máximo agora depende de física balística com bônus de
   lançamento, não mais do antigo atrator com tanque de energia.
2. A meta precisa subir o bastante pra que essa capacidade no MÁXIMO fique
   perto do limite, não só a do nível 1.

Isso significa que **toda a tabela `METAS_FASE` precisa ser remedida depois
que §2 estiver implementado**, não ajustada por estimativa. Recomendo o
mesmo método já usado nas rodadas anteriores: rodar `--teste-voo
--nivel=<max> --meta-livre` pra medir a capacidade real do avião totalmente
evoluído em cada fase, e fixar a meta um pouco ACIMA dessa medição (não
abaixo) - o oposto do que foi feito pro nível 1 até aqui. Se a meta ficar um
pouco acima do que o avião no máximo consegue com folga, "no limite" vira
literal: ele só bate combinando evolução máxima com pilotagem boa (mergulhos
bem cronometrados), não com uma das duas sozinha.

---

## Ordem de implementação sugerida

| Ordem | Item | Por quê |
|---|---|---|
| 1 | Motor vira bônus de lançamento (§2) | Mudança de arquitetura - o resto depende dela pra fazer sentido |
| 2 | Remover `_integrar_motorizado()` e a ramificação em `_process()` (§2) | Mesma mudança, não faz sentido meio-implementada |
| 3 | Medir capacidade real no nível máximo, por fase (§3) | Só é possível depois de 1-2 estarem prontos |
| 4 | Recalibrar `METAS_FASE` pra "no limite" no máximo (§3) | Depende da medição do item 3 |

## Perguntas em aberto para o dev sênior alinhar

1. **O motor dá empuxo contínuo em voo, mesmo que pequeno, ou é 100% só
   lançamento?** Decide se sobra algum resquício de `a_motor` dentro de
   `_integrar_balistico()` (que o v6 já somava parcialmente) ou se ele
   desaparece de vez da integração por frame.
2. **`Config.BONUS_MOTOR_LANCAMENTO_MAXIMO`** (quanto o motor no máximo
   multiplica o lançamento) - proponho começar por um valor parecido com o
   que `bonus_estilingue()` já entrega no seu próprio máximo, pra não um dos
   dois bônus dominar o outro, mas isso é palpite inicial, não medição.
3. **"No limite" para quem?** A meta recalibrada deve ficar apertada pro
   piloto automático (o "rastreador perfeito" que os testes já usam) ou
   para uma habilidade mais parecida com jogador humano mediano? O piloto
   automático historicamente supera qualquer humano real (ver
   `design_core_loop.md`), então calibrar "no limite" pra ele pode deixar a
   fase impossível pra a maioria dos jogadores.

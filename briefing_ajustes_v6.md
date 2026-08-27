# Voo Evolution — Briefing de ajustes v6 (motor em 3 partes, menos constante, mais níveis)

Continuação de `briefing_ajustes_v5.md` (motor por construção, trajetória
balística — implementado e testado, feedback positivo: *"ficou bem melhor a
mecânica dos níveis anteriores a obter o motor"*). Este documento parte
justamente desse elogio: em vez de tratar "ganhar o motor" como o fim da
parte boa, propõe esticar o mesmo caráter (potência que se conquista aos
poucos, nunca totalmente "constante") pra dentro da fase motorizada também.

**Status:** implementado e testado em jogo, usando as opções recomendadas
deste documento (§3 pergunta 2: hélices cosméticas; §3 pergunta 3: fusão
simples, empuxo somado ao modelo balístico; §4: trilha Avião com 10 níveis).
Testado nos 3 estágios (sem motor, motor parcial, motor total) sem erro. Os
4 motores extra em `t > 0,90` (pergunta 4) continuam como degrau único, fora
do escopo desta rodada.

---

## Resumo do pedido

1. Mesmo depois de ganhar o motor, ele deve ser mais fraco e **menos
   constante** do que o modelo motorizado atual — manter um pouco do
   caráter do planador em vez de trocar de comportamento de uma vez.
2. Mais níveis na trilha Avião, pra abrir espaço pro pedido 3.
3. Dividir o que hoje é "o motor aparece" (um interruptor só) em **3 partes
   progressivas**: hélices, motor/hélice na asa direita, motor/hélice na asa
   esquerda — espelhando como as asas já funcionam (uma de cada vez, não as
   duas juntas).

---

## 1. Por que isto importa: o que "ficou melhor" precisa sobreviver ao motor

O v5 criou dois modelos de voo que **trocam de uma vez** em
`Config.LIMIAR_T_MOTOR` (`t > 0,55`): antes disso, `Aviao._integrar_balistico()`
(vetor de velocidade, gravidade real, sem atrator); depois,
`Aviao._integrar_motorizado()` (o modelo antigo inteiro, com `v_eq` como
atrator constante). O feedback confirma que o trecho balístico está bom — e
também sinaliza que a troca abrupta pro modelo antigo desfaz esse ganho: ao
cruzar o limiar, o avião troca de "eu preciso pilotar isto" pra "isto se
mantém sozinho", de um frame pro outro.

**O pedido não é remover o motor** (a fantasia de "meu avião finalmente tem
motor" continua valendo) — é fazer o motor **não devolver de golpe** a
sensação de piloto automático que o planador tinha acabado de tirar.

---

## 2. Motor em 3 partes, não um interruptor só

### Como o motor aparece hoje (só visual, um degrau só)

`jogo/fabrica_modelos.gd::criar()`:
```gdscript
if t > Config.LIMIAR_T_MOTOR:   # 0,55
    _motor(raiz, Vector3(dx, ...), ...)     # motor direito
    _motor(raiz, Vector3(-dx, ...), ...)    # motor esquerdo, no MESMO instante
```

Os dois motores nascem juntos, no mesmo limiar de `t`. Fisicamente,
`DadosJogo.tem_motor_agora()` é um booleano só - motor existe ou não, sem
meio-termo.

### O que muda: 3 limiares em vez de 1, espelhando as asas

As asas já fazem exatamente o padrão pedido - uma de cada vez:
```gdscript
if t > 0,05: asa direita
if t > 0,15: asa esquerda
```
Proposta: aplicar o mesmo formato ao motor, com um terceiro estágio
preliminar (hélices) antes do primeiro motor de verdade:

| Estágio | O que aparece | Efeito físico proposto |
|---|---|---|
| 1 — Hélices | Hélice(s) aparecem no modelo, ainda sem motor associado | Nenhum empuxo ainda - cosmético, prepara o próximo estágio |
| 2 — Motor/hélice direita | Motor direito liga | Empuxo PARCIAL (ver §3) |
| 3 — Motor/hélice esquerda | Motor esquerdo liga | Empuxo TOTAL - só agora `tem_motor_agora()` bate 100% com o modelo antigo |

Isso substitui o bloco único de `_motor()` em `t > 0,55` por três blocos
menores, cada um plantando UM motor/hélice (reaproveitando a mesma função
`_motor()` que já existe, só chamada em momentos separados em vez de em
par). Os 4 motores extra que já existem em `t > 0,85` (para os aviões mais
avançados) não fazem parte deste pedido - continuam como estão, ou entram
como uma pergunta em aberto (ver final do documento).

---

## 3. Potência gradual e "menos constante" - como isso se traduz em física

Hoje `tem_motor_agora()` é um booleano (`t > 0,55`) que decide qual dos dois
métodos de integração rodar por inteiro. Para os 3 estágios acima terem
efeito real, a transição precisa deixar de ser um interruptor.

### Proposta: uma fração de potência, não um booleano

```gdscript
## Fracao de potencia do motor (0 a 1), NAO mais booleano. 0 ate o estagio 2
## (so helices, sem empuxo). Sobe pra ~0,5 no estagio 2 (motor direito) e 1,0
## so no estagio 3 (motor esquerdo tambem) - so ai o aviao bate 100% com o
## modelo motorizado classico.
func potencia_motor_atual() -> float:
    var t := _progresso_trilhas()
    if t <= LIMIAR_HELICES:
        return 0.0
    if t <= LIMIAR_MOTOR_DIREITO:
        return lerpf(0.0, 0.5, remap_local(t, LIMIAR_HELICES, LIMIAR_MOTOR_DIREITO))
    if t <= LIMIAR_MOTOR_ESQUERDO:
        return lerpf(0.5, 1.0, remap_local(t, LIMIAR_MOTOR_DIREITO, LIMIAR_MOTOR_ESQUERDO))
    return 1.0
```

Isso resolve os dois pedidos de uma vez:
- **"Diminuindo a potência"**: `a_motor` de fato passa a ser
  `DadosJogo.a_motor() * potencia_motor_atual()` em vez de tudo-ou-nada -
  logo depois do primeiro motor ligar, o empuxo é só metade do que seria no
  modelo cheio.
- **"Diminuindo a constância"**: em vez de `_integrar_motorizado()` assumir o
  controle inteiro no instante em que `t` cruza 0,55, os dois modelos
  **misturam** enquanto `potencia_motor_atual()` está entre 0 e 1 - por
  exemplo, rodando as duas integrações (balística e motorizada) e
  interpolando o resultado pela fração de potência, ou (mais simples de
  implementar) manter o modelo balístico como base o tempo todo e SOMAR o
  empuxo do motor a ele proporcionalmente à fração, só trocando pro modelo
  motorizado puro (com atrator) quando a fração chega a 1,0. A segunda opção
  é mais barata e esse resultado provavelmente já entrega o "menos
  constante" pedido, porque o atrator (que é o que faz o voo parecer
  "sozinho") só existe no modelo motorizado puro - enquanto a fração for
  menor que 1, o avião continua sendo empurrado pela física balística, só
  que com um empurrão extra de motor.

### Isso muda o papel de `_integrar_balistico`/`_integrar_motorizado`

Hoje são dois métodos mutuamente exclusivos (`if/else` em `_process()`).
Com potência fracionária, viram mais parecidos com "duas fontes de força que
se somam", não "dois modelos que se substituem". Recomendo (mas é uma
decisão de arquitetura pro dev validar): manter o modelo BALÍSTICO
(`_integrar_balistico`) como a integração de base sempre que `potencia_motor
< 1,0`, e somar `a_motor * potencia_motor` como mais uma força na soma de
`aceleracao` (do mesmo jeito que hoje já soma impulso e térmica) - só trocar
de fato para `_integrar_motorizado()` (com atrator e estol) quando a fração
bate 1,0 (equivalente ao `LIMIAR_T_MOTOR` de hoje, só que agora é o TERCEIRO
estágio, não o único).

---

## 4. Mais níveis na trilha Avião

### Por quê

Hoje a trilha AVIAO (`dados/atributos.gd`) tem só 6 níveis. Os limiares de
`t` (`_progresso_trilhas()`) dependem da SOMA dos níveis das 3 trilhas
(Avião + Moedas + Estilingue), então mais estágios (hélices, motor direito,
motor esquerdo, cauda, cabine, trem...) espremidos no mesmo intervalo de `t`
ficam cada vez mais próximos uns dos outros. Aumentar o teto da trilha Avião
dá mais "distância" entre cada compra e cada estágio visual/físico -
inclusive os 3 novos estágios de motor deste documento.

### Números de referência (a validar, não travados)

| | Hoje | Proposta |
|---|---|---|
| Níveis da trilha Avião | 6 | 10-12 |
| Custo base / razão | 150 / 1,350 | precisa recalibrar - mais níveis com o mesmo teto de efeito final significa passo por nível menor |

**Atenção**: aumentar só o número de níveis SEM reduzir o `passo_v/passo_e/
passo_i` por nível faz o efeito total da trilha (velocidade/duração/impulso
no nível máximo) crescer proporcionalmente mais forte - se a intenção é só
"mais degraus pro mesmo teto final", os passos por nível precisam cair
também. Isso é recalibração de balanceamento, não só trocar o número `6`.

---

## Ordem de implementação sugerida

| Ordem | Item | Por quê |
|---|---|---|
| 1 | Mais níveis na trilha Avião (§4) | Abre espaço de `t` pros novos estágios - fazer antes evita ter que reajustar limiares duas vezes |
| 2 | 3 estágios visuais do motor em `FabricaModelos` (§2) | Puramente visual, pode ser testado sozinho antes de mexer em física |
| 3 | `potencia_motor_atual()` fracionária + fusão dos dois modelos (§3) | Depende de 2 pra saber em que `t` cada estágio deve valer |

## Perguntas em aberto para o dev sênior alinhar

1. **Confirmar os limiares dos 3 estágios** (hélices / motor direito / motor
   esquerdo) depois que o número de níveis da trilha Avião (§4) for
   decidido - eles precisam ser recalculados juntos, não em separado.
2. **Estágio 1 (hélices) tem algum efeito físico, ou é só cosmético** (a
   "promessa" visual de que o motor está chegando, sem empuxo nenhum
   ainda)? A proposta em §3 assume que sim, cosmético puro - mas vale
   confirmar.
3. **A fusão dos dois modelos (§3) usa a abordagem mais simples** (base
   balística + empuxo do motor somado, proporcional à fração) **ou algo mais
   sofisticado** (interpolar as duas integrações completas)? Recomendo a
   mais simples, é bem mais barata de implementar e testar.
4. **Os 4 motores extra em `t > 0,85`** (para os aviões mais avançados)
   também entram nesse esquema gradual, ou continuam como um degrau único
   como hoje? Fora do escopo original do pedido, mas fica inconsistente se
   só o primeiro par de motores for gradual e o segundo não.

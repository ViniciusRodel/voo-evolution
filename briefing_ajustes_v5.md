# Voo Evolution — Briefing de ajustes v5 (motor por construção, trajetória balística)

Continuação de `briefing_ajustes_v4.md` (avião planador, sem velocidade
constante — implementado e testado). Este documento tem duas correções sobre
o que já foi construído, e uma delas é maior que tudo que veio antes.

**Status:** implementado e testado em jogo. §1 (motor por construção,
`DadosJogo.tem_motor_agora()` em `t > Config.LIMIAR_T_MOTOR = 0,55`, mesmo
limiar do motor aparecer no modelo) e §2 (trajetória balística, vetor `vx`/
`vy` em `Aviao._integrar_balistico()`) prontos. `arrasto_mult` virou
`DadosJogo.arrasto_mult_atual()`, função de `t` por fórmula (proporção
inversa ao quadrado da velocidade base), não mais valores fixos por avião.

**Achado durante a implementação:** a gravidade calibrada pro modelo
motorizado (`G_EFETIVO=36`) fazia o arco balístico subir e cair em menos de
1 segundo — lá ela só age escalada por `sin(ângulo)` com teto de 28°, aqui
age em cheio todo frame. Precisou de uma gravidade própria pro balístico
(`Config.GRAVIDADE_BALISTICA=13`, perto da real) e um ângulo de lançamento
mais alto (35° em vez de 6°) só pro caso sem motor, pra dar tempo do arco se
formar.

**Pendências reais que ficaram de fora desta rodada:** a meta de cada fase
(`Config.METAS_FASE`) ainda assume o modelo antigo — como agora TODO avião
(não só os 4 primeiros) tem um trecho planador antes do motor, as fases 5-13
também precisam de recalibração, e não deu tempo de fazer isso com rigor.
Também não construí o "simulador novo de projétil" mencionado na ordem de
implementação (item 4) - a calibração de metas por enquanto é só medição
pontual em jogo, não simulação.

---

## 1. Correção: motor não é "por avião", é por quanto o avião foi construído

### O que o v4 implementou (e por que está errado)

`Veiculo.tem_motor: bool` é um campo **fixo por avião**: as fases 1-4 (Papel,
Brinquedo, Hidroavião, Planador) nunca têm motor; a fase 5 em diante
(Biplano...) sempre tem. `Aviao._integrar()` lê esse campo direto.

**O pedido corrige isso:** todo avião — os 13, não só os 4 primeiros — nasce
**sem motor no nível 1 da própria trilha**, e só ganha motor conforme é
construído dentro daquela fase: primeiro uma asa, depois a outra, depois as
asas traseiras, e só então o motor. Isso vale pro Avião de Papel e também pro
Caça Supersônico — cada avião novo que você desbloqueia começa cru e você o
constrói peça por peça com as compras daquela fase.

### A boa notícia: essa escada já existe, só não está ligada à física

`jogo/fabrica_modelos.gd::criar()` já monta o avião nessa exata ordem, com
`t = veiculo.progresso_do_nivel(nivel_visual())` indo de 0 a 1 conforme o
jogador compra dentro da fase:

| Limiar de `t` | O que aparece |
|---|---|
| `t > 0,05` | Asa direita |
| `t > 0,15` | Asa esquerda |
| `t > 0,25` | Estabilizador horizontal (asas traseiras) |
| `t > 0,40` | Cabine |
| **`t > 0,55`** | **Motores (2)** |
| `t > 0,70` | Trem de pouso |
| `t > 0,85` | Mais 2 motores (4 no total) |

O motor já aparece VISUALMENTE em `t > 0,55` — só que isso é cosmético hoje;
`tem_motor` não olha pra esse número, olha pro `Veiculo` fixo. A correção é
literalmente ligar os dois: **`tem_motor` deixa de ser uma propriedade do
avião e vira uma função do nível de construção atual, usando o mesmo
limiar que já faz o motor aparecer no modelo.**

### O que muda no código

- `dados/veiculo.gd::tem_motor` (campo fixo) é removido.
- `dados/catalogo.gd` não marca mais `"tem_motor": false` nas 4 primeiras
  entradas — nenhum avião tem motor "de fábrica" mais.
- Um método novo, recomendo em `autoload/dados_jogo.gd` (mesmo lugar que já
  tem `asas_atual()`, raciocínio idêntico):

  ```gdscript
  func tem_motor_agora() -> bool:
      var t := aviao_atual().progresso_do_nivel(nivel_visual())
      return t > 0.55  # mesmo limiar de jogo/fabrica_modelos.gd
  ```

- Todo lugar em `jogo/aviao.gd` que hoje lê `DadosJogo.aviao_atual().tem_motor`
  (`_integrar()`, `_atualizar_energia()`, `acionar_impulso()`,
  `_emitir_impulso()`) passa a chamar `DadosJogo.tem_motor_agora()`.

### Não precisa resolver "motor liga no meio do voo" — mas vale avisar o jogador

`nivel_visual()` só muda quando o jogador compra um upgrade, e compra só
acontece na loja, nunca durante o voo. Então `tem_motor_agora()` também só
muda **entre corridas**, nunca no meio de uma — não existe o caso de "o motor
liga com o avião no ar". O que existe é uma transição abrupta de uma corrida
pra outra (a corrida N ainda era planador; depois de comprar o suficiente, a
corrida N+1 já tem motor e tanque cheio do nada). Recomendo um aviso claro na
loja quando a próxima compra vai cruzar esse limiar ("PRÓXIMA MELHORIA:
MOTOR!"), pra o momento ser sentido como conquista, não como uma mudança de
regra sem explicação.

### Efeito colateral real: `arrasto_mult` (v4) precisa virar função de `t` também

O v4 deu a cada um dos 4 primeiros aviões um `arrasto_mult` cada vez menor
(mais aerodinâmico) porque cada avião tem velocidade base maior que o
anterior, e sem compensar isso o avião "melhor" planava PIOR (arrasto cresce
com o quadrado da velocidade, a margem acima do estol só cresce linear — ver
`briefing_ajustes_v4.md` §5, achado no meio da implementação).

Com motor virando algo que se conquista DENTRO de cada avião (não uma propriedade do avião inteiro),
isso precisa ser revisto: os aviões de fases avançadas (Caça Supersônico, por
exemplo) também vão passar por um trecho planador **dentro da própria fase**,
só que com uma velocidade base calibrada pra voo motorizado (muito mais alta
que a do Avião de Papel). Sem um `arrasto_mult` alto o bastante nesse trecho,
o início de vida desses aviões avançados pode ser impraticável — rápido
demais pra sustentar sem motor. Recomendo `arrasto_mult` também virar função
de `t`: alto (mais arrasto, mais resistência ao excesso de velocidade)
enquanto `t < 0,55` (sem motor), caindo pro valor calibrado do avião conforme
o motor se aproxima.

---

## 2. Trajetória de lançamento balística — estilo Worms/Gunbound

### O pedido

O lançamento deve se comportar como um projétil de jogo de artilharia (Worms,
Gunbound): sobe, atinge um pico de altura, e cai — uma curva em U invertido
(parábola), que é consequência da física (velocidade inicial + gravidade
constante), não de um controle de ângulo que o jogador segura o tempo todo.

### Por que o modelo atual não produz essa curva

Hoje `angulo` é uma variável de **controle**, não uma consequência de
velocidade: o jogador arrasta o dedo, isso define `_angulo_alvo`, e o avião
gira pra essa direção; a posição vertical vem de `v * sin(angulo) * delta` a
cada frame. Ou seja, o jogo pergunta "que ângulo o jogador quer agora" e move
o avião nessa direção — sempre na MESMA velocidade escalar (que sobe ou desce
por arrasto/mergulho, mas nunca tem uma direção própria independente do
comando). É o oposto de um projétil: uma bala de canhão em Worms não é
"comandada" em ângulo durante o voo, a trajetória inteira é resultado da
velocidade de saída e da gravidade puxando pra baixo o tempo todo.

### O que precisa mudar — vetor de velocidade real, não escalar + ângulo comandado

Hoje: `v` (escalar, m/s) + `angulo` (direção, comandada pelo jogador).
Trocar para: um vetor de velocidade — `vx` (horizontal) e `vy` (vertical) —
onde o ângulo do avião passa a ser **consequência**, não causa:

```
vy -= gravidade * delta        # gravidade sempre puxa pra baixo, sem exceção
vx -= arrasto(vx) * delta      # arrasto sempre freia a velocidade horizontal
angulo_visual = atan2(vy, vx)  # o modelo aponta pra onde esta indo, nao pra onde o jogador manda
```

No lançamento (`Aviao.lancar()`), a força/mira do estilingue decompõe em
`vx_inicial = v_inicial * cos(ângulo_de_lançamento)` e
`vy_inicial = v_inicial * sin(ângulo_de_lançamento)`. A partir daí, sem
nenhum input:

1. **Sobe** enquanto `vy > 0` — a subida "morre" sozinha porque `gravidade`
   reduz `vy` a cada frame.
2. **Atinge o pico** quando `vy` cruza 0 — exatamente a curva em U invertido
   pedida.
3. **Cai acelerando** — `vy` fica cada vez mais negativo.

### Isso substitui boa parte do que o v4 acabou de calibrar

Num modelo balístico de verdade **não existe estol** — existe só a parábola.
`FRACAO_ESTOL`, `MULT_ESTOL_SEM_ASA`, e o "estol severo"
(`FRACAO_ESTOL_SEVERO`/`MERGULHO_MULT_ESTOL_SEVERO`/`QUEDA_LIVRE_MAXIMA`) que
acabamos de adicionar nesta mesma sessão ficam **em boa parte obsoletos** —
foram a forma de simular "perder sustentação e cair" dentro do modelo antigo
de ângulo comandado; num modelo de vetor de velocidade, cair é só o que
acontece quando `vy` fica negativo, não precisa de uma regra separada pra
isso.

O papel do jogador muda de "manter altitude" pra "escolher mira e força no
lançamento, e talvez ajustar pontualmente durante a queda" (por exemplo,
mergulhar cedo pra converter altura em velocidade antes da queda natural —
ver pergunta 1 abaixo).

### Por que isto é MAIOR que o v4, não um ajuste dele

Trocar "velocidade escalar + ângulo comandado" por "vetor de velocidade real"
toca:

| Sistema | Como muda |
|---|---|
| `Aviao._integrar()` | Reescrita do núcleo, não ajuste de constante |
| Arraste do jogador (`_angulo_alvo`) | Vira um input secundário (nudge pontual), não a variável que decide a trajetória inteira |
| `FRACAO_ESTOL` e toda a familia de constantes de estol (v4) | Grande parte fica obsoleta - não existe mais "estolar" |
| `sim/modelo.py` | Precisa de um modelo de projétil novo (trajetória parabólica) pra calibrar metas - o `capacidade()` atual não serve |
| HUD/velocímetro | Sem mudança - velocidade exibida continua sendo a magnitude do vetor |
| Impulso (`Config.IMPULSO_ACELERACAO`) | Precisa decidir se empurra na direção do vetor atual ou numa direção fixa (ver pergunta 2) |

---

## Ordem de implementação sugerida

| Ordem | Item | Por quê |
|---|---|---|
| 1 | Motor por construção (§1) | Menor, mais contido, não depende do resto |
| 2 | `arrasto_mult` como função de `t` (§1) | Precisa entrar junto com o item 1, ou os aviões avançados nascem impossíveis de voar |
| 3 | Vetor de velocidade / trajetória balística (§2) | Reescrita do núcleo físico - reservar tempo dedicado, é o item que mais recalibra o que já existe |
| 4 | Simulador novo de projétil (§2) | Depende de 3 estar decidido, pra ter o que simular |

## Perguntas em aberto para o dev sênior alinhar

1. **Depois do ápice, o jogador ainda controla alguma coisa?** Recomendo que
   sim (mergulhar cedo, correção lateral), só que como *nudge* sobre a
   parábola, não como o controle principal — do contrário o voo vira 100%
   decidido no momento do lançamento (mais fiel a Worms, mas tira a
   habilidade de pilotagem em voo que o resto do jogo já construiu).
2. **Impulso empurra na direção atual do vetor de velocidade, ou numa direção
   fixa (ex.: sempre pra frente/reto)?** Muda a sensação de "acelerar
   reto" vs. "ganhar mais arco".
3. **Avião COM motor (depois de construído) volta a ser o modelo atual
   (velocidade escalar com atrator), ou também passa a usar vetor de
   velocidade, só que com empuxo constante somado ao `vx`?** Definir isso
   antes de mexer em `Aviao._integrar()`, porque muda se o código fica com
   um modelo só (unificado) ou dois modelos (planador balístico + motorizado
   escalar) convivendo.
4. **Confirmar o encaminhamento do §1** (`tem_motor_agora()` em
   `DadosJogo`, limiar `t > 0,55` compartilhado com `FabricaModelos`, e
   `arrasto_mult` como função de `t`) antes de qualquer código - é uma
   correção pequena, mas muda a leitura de "quais aviões são planadores" em
   todo o resto dos documentos anteriores.

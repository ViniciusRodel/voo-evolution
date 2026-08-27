# Voo Evolution — Briefing de ajustes v4 (avião planador: sem motor, sem velocidade constante)

Continuação de `briefing_ajustes_v2.md` (estilingue direcional, loja de 3
trilhas) e `briefing_ajustes_v3.md` (avião por fase, mapa, dificuldade,
economia) — ambos já implementados e testados em jogo. Este é o pedido mais
profundo até aqui: não ajusta um número, questiona a **equação central** do
modelo de voo.

**Status:** implementado e testado em jogo. §1 (orbes), §2-4 (motor só a
partir da fase 5, `Veiculo.tem_motor`), §6 opção 1 (sem tanque de energia
pros planadores, corrida termina só tocando o solo), §7 (impulso com usos
fixos) e §5/§4-difícil (dificuldade já funciona sem mudança extra, é só um
multiplicador na força total) — todos prontos. Achado durante a implementação
que não estava previsto: aumentar só a velocidade base de fase em fase piora
a planagem, não melhora (arrasto cresce com o quadrado da velocidade) -
corrigido com `Veiculo.arrasto_mult`, mas a calibração fina entre as 4 fases
planadoras **ainda não está boa** e precisa de playtest humano, não só
piloto automático. Ver nota em `Config.METAS_FASE`.

---

## 1. Orbes removidos — feito

`jogo/gerador_mundo.gd` não gera mais os orbes coletáveis (nem os padrões
arco/escada/mergulho, nem o pool de esferas). O streaming de terreno e as
térmicas (correntes de ar) continuam intactos. Removidos junto, por estarem
amarrados só a orbes: `Aviao.coletar_orbe()`/`orbes_coletados`, o sinal
`Eventos.orbe_coletado`, a linha "ORBES COLETADOS" da tela de resultado, e as
constantes `Config.ORBES_POR_SEGUNDO/ENERGIA_POR_ORBE/POOL_ORBES/COLETA_BASE`.

**Consequência em aberto:** a trilha **Moedas** (`dados/atributos.gd`) ainda
promete *"Raio de coleta maior. Mais orbes e mais moedas por metro voado"* —
`DadosJogo.raio_coleta()` continua existindo (não removi, para não quebrar a
trilha), mas não tem mais nada pra coletar. Essa trilha precisa de um novo
propósito. Ver §6.

---

## 2. O pedido: tirar o motor constante do modelo

### A equação de hoje

`jogo/aviao.gd::_integrar()`:

```
dv/dt = a_motor − k_arrasto·v² − g_efetivo·sin(ângulo) [+ impulso] [+ térmica]
```

`a_motor` é **empuxo constante**, presente sempre que há energia no tanque,
não importa a altitude ou a manobra. Ele define um ponto de equilíbrio:

```
v_eq = √(a_motor / k_arrasto)
```

`design_core_loop.md` §2 é explícito sobre o que isso causa: *"v_eq é um
ATRATOR: em voo nivelado a velocidade sempre converge para ela"*. É
exatamente esse atrator que o pedido quer remover — hoje, não importa o que o
jogador faça, o avião "quer" voltar pra `v_eq` sozinho, porque há um motor
ligado o tempo todo. Isso é literalmente um motor no código, mesmo em fases
cujo avião (Avião de Papel, de Brinquedo) não tem motor nenhum na
concepção do jogo.

### A equação pedida

Para aviões **sem motor**:

```
dv/dt = − k_arrasto·v² − g_efetivo·sin(ângulo)
```

Só isso. Sem o termo `a_motor`, a velocidade **decai por arrasto o tempo
todo**, e a única forma de recuperar velocidade é **trocar altitude por
velocidade** — mergulhar (`ângulo < 0`) soma um termo positivo (exatamente
como já funciona hoje), subir (`ângulo > 0`) subtrai. A física de troca já
existe no código, ela só fica **mascarada** hoje porque o empuxo constante
disfarça o efeito. Tirar `a_motor` não é adicionar mecânica nova — é parar de
esconder a que já está lá.

**Consequência direta, e é o ponto central do pedido:** sem atrator, não
existe mais "velocidade de cruzeiro" estável. O avião acelera mergulhando,
desacelera subindo ou por arrasto puro, e a habilidade do jogador em
administrar essa troca — não um número de tanque — decide a distância. É
isso que a mensagem descreve como *"a dificuldade fica no controle do avião
no ar"*.

---

## 3. O estilingue muda de papel, sem mudar de código

`Aviao.lancar(qualidade, lateral)` já faz exatamente *"um empurrão"*: define
`v = DadosJogo.v_inicial(qualidade)` uma vez, no instante do lançamento, e
nunca mais mexe nisso diretamente — o resto é a integração de `_integrar()`
cuidando da velocidade. Estruturalmente **nada muda aqui**.

O que muda é o que acontece **depois** do empurrão:

- **Hoje:** o atrator "come" a vantagem do lançamento em poucos segundos —
  `design_core_loop.md` §4.2 mediu isso e chegou a 0,7%–3,5% de efeito na
  distância final, decaindo com o nível. Por isso o design recomendava
  explicitamente **não** apostar no lançamento como fator de habilidade.
- **Sem atrator:** essa conclusão **se inverte por completo**. O empurrão
  inicial não converge pra lugar nenhum — ele decai, e quanto mais forte
  (melhor qualidade no estilingue) e melhor administrado (mergulhos bem
  cronometrados), mais longe o avião vai. O lançamento deixa de ser
  cosmético e vira a base de tudo. **§4.2 do design doc inteiro fica
  obsoleto** para aviões sem motor — precisa ser remedido, não reaproveitado.

---

## 4. Nem todo avião perde o motor — é uma diferenciação por fase

O catálogo de 13 aviões (`dados/catalogo.gd`, `briefing_ajustes_v3.md` §1) já
dá o lugar natural pra essa mudança não ser tudo-ou-nada. Proposta:

| Fase | Avião | Tem motor? |
|---|---|---|
| 1 | Avião de Papel | Não |
| 2 | Avião de Brinquedo | Não |
| 3 | Hidroavião | Não (planador com flutuadores) |
| 4 | Planador | Não (o próprio nome já diz) |
| 5 | Biplano | **Sim** — primeiro motor a hélice |
| 6+ | Monomotor, Turboélice, ... | Sim |

Isso cria um arco de progressão real: as **quatro primeiras fases são puro
jogo de habilidade** (mergulhar, nivelar, administrar altitude — sem tanque,
sem atrator), e a partir da fase 5 o jogo **se transforma** num jogo de
gerenciamento de recurso (o modelo atual, com energia e velocidade de
cruzeiro). Isso não é só coerente com o pedido — dá ao jogo uma identidade
que os concorrentes de referência não têm: a primeira metade da experiência
ensina a pilotar, a segunda ensina a otimizar.

**Implementação sugerida:** `dados/veiculo.gd` ganha `@export var tem_motor:
bool = true`, setado a `false` nas 4 primeiras entradas de
`dados/catalogo.gd`. `Aviao._integrar()` lê
`DadosJogo.aviao_atual().tem_motor` e zera `a_motor` quando falso.

---

## 5. O que isso quebra e precisa ser refeito (não é cosmético)

Tirar `a_motor` de um avião não é trocar uma constante — é remover a premissa
que **todo o resto do balanceamento assume**. Lista do que depende dela:

| Sistema | Como depende de `a_motor`/`v_eq` | O que precisa acontecer |
|---|---|---|
| `sim/modelo.py::capacidade()` | Integra em torno de um `v_eq` fixo | Precisa de uma função de planeio nova: distância como função de altitude inicial, arrasto e decisões de mergulho/nivelamento do piloto simulado |
| `Config.METAS_FASE` | Calibrada a partir de `capacidade()` acima | Recalcular do zero para as fases 1–4 (planadoras); fases 5+ continuam com o método atual |
| `FRACAO_ESTOL` / `v_estol` | É uma fração de `v_cruzeiro()`, que sem atrator não é mais um "nível de repouso" | Repensar o que significa estolar quando não há velocidade de equilíbrio |
| `energia`/`ENERGIA_BASE`/`CONSUMO` | Hoje é o que encerra a corrida (tanque zera) | Para aviões sem motor, **provavelmente não faz sentido nenhum** — ver §6 |
| Velocímetro (`Config.velocidade_exibida`) | Calibrado nos dois pontos 97,5 m/s→50 km/h e ~1000 m/s→~1200 km/h, assumindo velocidades de cruzeiro | Continua funcionando como função de exibição, mas os valores que vai mostrar mudam de caráter (picos e vales em vez de platô) |
| `DIFICULDADES` (queda_mult/velocidade_mult) | `velocidade_mult` hoje escala a força de `a_motor` | Sem motor, esse multiplicador não tem mais o que escalar — a dificuldade dos aviões planadores provavelmente precisa ser outro eixo (ex.: `k_arrasto` ou o próprio `g_efetivo`) |

**Isto não é uma lista de bugs a corrigir — é o escopo real do pedido.**
Trocar a equação central de 4 dos 13 aviões exige um simulador novo pra essa
classe de avião, não um ajuste do `sim/modelo.py` atual.

---

## 6. O que substitui "energia" nos aviões sem motor?

Pergunta em aberto mais importante do documento. Hoje a corrida termina
quando: bate a meta, toca o solo, ou a energia esgota e o avião pousa. Para
um planador puro, **energia esgotar não significa nada** — não existe
combustível pra um avião sem motor. As saídas naturais:

1. **A corrida acaba só quando o avião perde altitude/velocidade demais e
   cai** — puramente físico, sem tanque. É a leitura mais literal do pedido
   ("a dificuldade fica no controle do avião no ar"). A meta de distância
   dessas fases precisa ser calibrada sabendo que não há mais um "orçamento
   de tempo" fixo (`design_core_loop.md` Decisão A deixa de valer pra essas
   4 fases) — a duração vira uma saída da simulação, não uma entrada.
2. Manter um recurso, mas redefinido — por exemplo, altitude inicial do
   lançamento como o "tanque": você começa com X metros de altitude
   utilizável, e cada mergulho/subida gasta ou recupera altitude, não
   energia abstrata.

Recomendo a opção 1 — é mais simples de implementar (menos um sistema, não
mais um) e é a leitura mais direta do que foi pedido. Mas isso precisa ser
confirmado antes de qualquer código, porque decide se `energia`/`ENERGIA_BASE`
continuam existindo em algum formato pros aviões sem motor.

**Efeito colateral que resolve o item aberto do §1:** se a corrida para de
depender de energia/orbe pra esses aviões, a trilha **Moedas** também precisa
de um novo propósito ali (já não tinha desde a remoção dos orbes). Proponho
tratar as duas questões juntas: Moedas vira "+X% de moedas por metro" puro
(sem menção a raio de coleta), igual em todos os aviões, motorizados ou não.

---

## 7. Impulso: existe para avião sem motor?

`Config.IMPULSO_ACELERACAO`/`acionar_impulso()` hoje dá aceleração extra
descontando de `energia`. Se energia deixa de existir pros aviões sem
motor (§6, opção 1), o impulso também precisa de uma nova regra — por
exemplo, um número fixo de usos por corrida (1–2), sem recarga, já que não há
mais tanque pra recarregar contra.

---

## Ordem de implementação sugerida

| Ordem | Item | Por quê |
|---|---|---|
| 1 | Decidir §6 (o que substitui energia) e §7 (impulso) com o time | Bloqueia tudo o resto — é a decisão de design que todo o resto depende |
| 2 | `tem_motor` no catálogo (§4) + zerar `a_motor` em `_integrar()` (§2) | Menor mudança de código, mas só faz sentido depois de 1 decidido |
| 3 | Simulador novo de planeio (§5) para as 4 fases sem motor | Precisa de 2 pronto pra ter o que simular |
| 4 | Recalibrar `METAS_FASE` das fases 1–4 com o simulador novo | Depende de 3 |
| 5 | Redefinir a trilha Moedas (§1, §6) | Pode entrar em paralelo, é independente do resto |
| 6 | Revisitar `DIFICULDADES` para os aviões sem motor (§5) | Por último — só faz sentido calibrar dificuldade depois que a física base estiver fechada |

## Perguntas em aberto para o dev sênior alinhar

1. **Confirmar quais aviões ficam sem motor** — proposta no §4 é papel,
   brinquedo, hidroavião e planador (fases 1–4); a partir do biplano (fase 5)
   o motor volta. Pode ser diferente.
2. **O que substitui energia nos aviões sem motor** (§6) — recomendo "nada,
   a corrida acaba quando o avião cai", mas é uma decisão de design, não
   técnica.
3. **Impulso pra avião sem motor** (§7) — usos fixos por corrida, ou remover
   completamente pras 4 primeiras fases?
4. **Dificuldade pros aviões sem motor** (§5, última linha da tabela) — qual
   eixo físico o seletor Fácil/Médio/Difícil deveria escalar quando não há
   `a_motor` pra escalar?

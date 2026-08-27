# Voo Evolution — Core Loop, Modelo de Voo e Economia

**Todos os números deste documento foram derivados por simulação, não estimados.**
O modelo está em `sim/modelo.py` e a progressão em `sim/progressao.py`. Cada
tabela é a saída de uma execução. Rode `python3 progressao.py` para reproduzir.

Isso importa porque o primeiro conjunto de constantes que escrevi foi
**reprovado pela própria simulação**: produzia ganho médio de 1,8% de distância
por compra, que é o fracasso clássico do upgrade imperceptível. Os valores
abaixo são o resultado do rebalanceamento.

---

## 1. Resumo do core loop

O avião é lançado por um estilingue e voa até a energia acabar. A distância
percorrida é o placar. Cada corrida rende moedas — por metro voado e por orbes
coletados no trajeto. As moedas compram melhorias permanentes em seis atributos,
que aumentam principalmente a **velocidade** do avião. Como a duração do voo é
quase constante (o tanque é um orçamento de tempo, não de distância), mais
velocidade significa diretamente mais distância. Cada fase tem uma meta; cruzá-la
paga um bônus, libera o próximo bioma e sobe a meta seguinte em 28%. O avião
muda de aparência conforme a soma dos seus atributos, do Nível 1 ao 20. O ciclo
completo é: **lançar → voar → ganhar → melhorar → ir mais longe.**

---

## 2. Modelo de voo

### 2.1 Variáveis de estado

| Variável | Unidade | Papel |
|---|---|---|
| `v` | m/s | Velocidade real no mundo. **Fonte da verdade.** |
| `y` | m | Altitude acima do terreno |
| `θ` | rad | Ângulo da trajetória (positivo = subindo) |
| `E` | unidades | Energia restante no tanque |
| `d` | m | Distância percorrida (integral de `v`) |

### 2.2 Equações

```
dv/dt = a_motor − k_arrasto · v²  − g_ef · sin(θ)  + a_impulso + a_térmica
dy/dt = v · sin(θ)
dE/dt = −c + (orbes coletados no instante) · e_orbe
d     = ∫ v dt
```

**Velocidade de equilíbrio** (o atrator do sistema — o avião sempre converge
para ela em voo nivelado):

```
v_eq = √(a_motor / k_arrasto)
```

**Duração do voo** — resolvendo `dE/dt = 0` com a renda de orbes:

```
t_voo = E_max / (c − R · f · e_orbe)
```

onde `R` = orbes por segundo no trajeto, `f` = fração coletada (ímã),
`e_orbe` = energia por orbe.

**Distância da corrida:**

```
d_capacidade = ∫₀^t_voo v dt · (1 + bônus_impulso)
d_real       = min(d_capacidade, meta_da_fase)
```

### 2.3 Constantes iniciais (nível 1 em tudo)

| Constante | Valor | Origem |
|---|---|---|
| `k_arrasto` | 0,0012 1/m | Calibrado para `v_eq` = 97,5 m/s |
| `a_motor` | 11,4 m/s² | Idem |
| `v_eq` resultante | **97,5 m/s** | = 50 km/h no HUD — bate com o vídeo |
| `E_max` | 68 unidades | Calibrado para `t_voo` = 41,4 s |
| `c` (consumo) | 2,0 un/s | **Constante, independente da velocidade** |
| `R` (orbes/s) | 0,85 | Um orbe a cada ~1,2 s de voo |
| `e_orbe` | 1,2 unidades | Devolve ~0,6 s de voo por orbe |
| `f` (coleta) | 0,35 | Fração dos orbes efetivamente pega |
| `g_ef` | 25 m/s² | Gravidade **amplificada** — ver nota abaixo |
| `v_inicial` | 111,6 m/s | = 60 km/h no HUD — o vídeo mostra 59 |

**Sobre `g_ef` = 25 e não 9,81.** Com gravidade real, uma descida de 10° dá
−1,7 m/s² contra um empuxo de 11,4 — o relevo vira irrelevante e o jogador não
tem motivo para olhar o terreno. Com 25, a mesma descida dá −4,3 m/s², e mergulhar
numa encosta passa a ser uma decisão. É realismo trocado por gameplay,
conscientemente.

### 2.4 Duas decisões estruturais que sustentam tudo

**Decisão A — o consumo é por SEGUNDO, não por metro.**

Consequência: `t_voo` não depende da velocidade. Se a velocidade dobra, a
distância dobra e a duração não muda. Isso transforma a restrição de 40–60 s de
um problema de balanceamento contínuo em uma **propriedade estrutural do
modelo**. Fisicamente é estranho (um avião mais rápido gastaria mais
combustível); em termos de design é o que torna a curva projetável.

**Decisão B — os orbes aparecem em cadência de TEMPO, não de distância.**

Se fossem colocados a cada X metros, a renda de energia seria `v · ρ · f · e`,
que cresce com a velocidade. O denominador `c − v·ρ·f·e` tenderia a zero e o
voo se tornaria **infinito**. Verifiquei na simulação: com densidade por metro,
no nível 30 a renda ultrapassa o consumo e o modelo diverge. Em cadência de
tempo, a renda é constante e o sistema é estável em qualquer velocidade.

Na prática o gerador posiciona orbes a cada `v / R` metros — o espaçamento no
mundo cresce junto com a velocidade, e o jogador recebe uma oportunidade de
coleta a cada ~1,2 s independentemente do nível.

---

## 3. Velocidade real vs. velocidade exibida

Medimos no vídeo: ~100 m/s de deslocamento real contra 50 km/h no velocímetro —
fator ~7×, deliberado.

**Regra: a distância é honesta; o velocímetro é o único número cosmético.**

Justificativa: a distância alimenta a economia (moedas por metro), a barra de
progresso e a meta da fase. Se ela carregasse um fator de escala, toda fórmula
de economia carregaria o fator junto e qualquer ajuste futuro exigiria mexer em
todas. O velocímetro, ao contrário, **não é lido por nenhuma regra do jogo** —
só pelos olhos do jogador. É o lugar certo para pôr a mentira.

**Fórmula (função de view pura):**

```
velocidade_exibida_kmh = 0,0964 · v^1,365          [v em m/s]
```

Calibrada em dois pontos reais: 97,5 m/s → 50 km/h (medido no vídeo) e
~1.000 m/s → ~1.200 km/h (topo do catálogo, das capturas da loja do original).

O expoente 1,365 faz o número exibido crescer **mais rápido** que a velocidade
real: 10× de velocidade real vira 24× no mostrador. É isso que permite a fantasia
de progressão de 50 até 1.200 km/h sem que o avião precise realmente voar a
2.400 m/s — o que quebraria o streaming de cenário e a precisão de float.

**Armadilhas que isso cria — e como evitá-las:**

| Armadilha | Prevenção |
|---|---|
| Alguém usar `velocidade_exibida` numa regra de jogo | A função vive na camada de UI, não no modelo. Nunca exportar do nó do avião |
| Jogador comparar km/h com metros e achar inconsistente | Nunca exibir tempo de voo em segundos junto do velocímetro. Sem os dois na tela, ninguém faz a conta |
| Ajustar a curva mexendo no expoente | O expoente é cosmético. Ajustes de balanceamento se fazem em `a_motor` e `k_arrasto`, nunca aqui |

---

## 4. Fase de lançamento (estilingue)

### 4.1 Mecânica recomendada: segurar e soltar

Um medidor varre de 0 a 100% em 1,2 s e volta. O jogador solta o dedo; a posição
no momento da soltura é a qualidade `q ∈ [0,1]`. Zona verde no topo.

```
v_inicial = v_cruzeiro · (0,90 + 0,35·q) · bônus_estilingue
```

Com `q = 0,7` (jogador mediano) e estilingue nível 1: `v_inicial = 1,145 · v_eq`.
Isso reproduz o vídeo, onde o lançamento (59 km/h) fica ~18% acima do cruzeiro
(50 km/h).

### 4.2 O peso do lançamento — medido, não estimado

A pergunta era se o lançamento vale 10% ou 60% da distância. **Simulei os dois
extremos** (lançamento péssimo, `q=0`, contra perfeito, `q=1`):

| Avião no nível | Lançamento péssimo | Lançamento perfeito | Diferença |
|---|---|---|---|
| 1 | 3.988 m | 4.127 m | **+3,5%** |
| 10 | 7.805 m | 7.949 m | **+1,8%** |
| 20 | 16.401 m | 16.549 m | **+0,9%** |

*(Refeito com a trilha Avião no lugar de Motor isolado — mesma conclusão, os
números mudam pouco porque o atrator `v_eq` é quem domina, não qual atributo
o alimenta.)*

**O lançamento não pode importar muito, e a razão é estrutural.** O modelo tem
uma velocidade de equilíbrio que funciona como atrator: qualquer velocidade
inicial converge para `v_eq` em poucos segundos. O lançamento só influencia o
transiente, que é uma fração cada vez menor de uma corrida cada vez mais longa.

Isso responde a pergunta com um número: **o lançamento vale entre 0,7% e 3,5% da
distância, decaindo conforme o jogador progride.** Ou seja, este é um jogo de
progressão, não de habilidade — e a matemática do modelo já garante isso sozinha.

**Se vocês quiserem que o lançamento importe mais**, não adianta aumentar a
velocidade inicial: o atrator vai comê-la. É preciso dar ao lançamento um efeito
**persistente** — por exemplo, um lançamento perfeito conceder +8% de energia
inicial no tanque, o que se propaga por toda a corrida. Recomendo isso como
ajuste opcional, com valor inicial de +8% a calibrar por teste com jogadores.

---

## 5. Atributos de upgrade

**Atualizado — v2: três trilhas em vez de seis.** Motor, Aerodinâmica, Tanque
e Impulso viraram uma trilha única, **Avião**: cada nível sobe velocidade,
duração e impulso ao mesmo tempo (três multiplicadores diferentes num só
nível de compra), e o número de níveis foi recalibrado em `sim/progressao.py`
para reproduzir o **mesmo** crescimento total que os quatro atributos
separados já tinham validado — não é um teto novo, é o mesmo teto
redistribuído numa trilha visível em vez de quatro. Ímã virou **Moedas**;
Estilingue não mudou. Ver `briefing_ajustes_v2.md` §1 para o pedido original
e o raciocínio da fusão.

### 5.1 Por que poucos níveis com degraus grandes

O número de níveis **não é escolha estética, é consequência matemática.** Se o
crescimento total de distância é ~17× e o jogador faz `N` compras, o ganho médio
por compra é `17^(1/N)`:

| Compras totais | Ganho por compra |
|---|---|
| 174 (6 atributos × 30 níveis, versão antiga) | **+1,7%** — invisível |
| 100 | +2,9% — quase invisível |
| **44** | **+6,5%** — perceptível |
| 20 | +15,3% — conteúdo acaba rápido demais |

Isso vale independente de quantas trilhas visíveis existem — 44 compras a
~6,5% cada é o alvo, seja distribuído em 6 atributos ou em 3. Por isso a
trilha Avião tem 37 níveis (ela sozinha carrega o que antes eram quatro
trilhas somando 36 compras).

### 5.2 Tabela de atributos

| Atributo | Níveis | Efeito por nível | Custo do nível n | Custo nv. 2 | Custo máx. |
|---|---|---|---|---|---|
| **Avião** | 37 | `v_cruzeiro ×1,0627`, `E_max ×1,0086`, `impulso ×1,0046` (todos no mesmo nível) | 220 × 1,118^(n−1) | 246 | 12.199 |
| **Moedas** | 6 | `coleta × 1,015` e **+8% de moedas** | 400 × 2,150^(n−1) | 860 | 18.376 |
| **Estilingue** | 4 | `v_inicial × 1,020` (+2,0%) | 180 × 2,400^(n−1) | 432 | 2.488 |

No máximo de tudo, `v_cruzeiro` chega a **870 m/s (≈992 km/h)**, `E_max` a
92,5 (era 92,65) e o bônus de impulso a 1,180 — dentro do arredondamento, os
mesmos tetos que o modelo de 6 atributos já tinha (motor+aerodinâmica maxados
davam 869,8 m/s; tanque maxado dava `E_max` 92,65; impulso maxado dava 1,18).
A fusão preserva o teto, só muda quantas trilhas o jogador vê.

### 5.3 Qual atributo deve ser o mais atraente no começo

A simulação usa um comprador guloso que sempre escolhe o melhor ganho de
distância por moeda. Com três trilhas em vez de seis, **Avião domina quase
toda compra no início** — é o único caminho para velocidade agora, então não
há mais a alternância Motor↔Aerodinâmica da versão anterior (quando um ficava
caro, o outro assumia). Isso é uma perda de nuance deliberada: a versão de 6
atributos dava ao jogador "duas avenidas" de velocidade; a de 3 dá uma só,
mais fácil de entender à custa de menos variedade de decisão. **Moedas** e
**Estilingue** entram quando o saldo sobra ou quando Avião momentaneamente
fica caro demais para o próximo nível — o comportamento observado na
simulação (ver §6.1) é Avião na esmagadora maioria das compras, com Moedas e
Estilingue intercalados a cada 4-6 corridas.

### 5.4 Nível visual do avião

O Nível 1→20 exibido na loja é derivado, não comprado:

```
nível_visual = 1 + round(19 · (Σ níveis − 3) / (47 − 3))
```

(Era `Σ níveis − 6) / (50 − 6)` com 6 atributos; a fórmula em si não mudou —
`Atributos.soma_minima()`/`soma_maxima()` recalculam os limites automaticamente
para o número de trilhas atual.) Isso conecta direto na `FabricaModelos` que já
existe no spike — ela já monta o avião a partir de um número de 1 a 20, sem
precisar mudar nada quando o número de trilhas muda.

---

## 6. Economia

| Fonte | Valor |
|---|---|
| Moedas por metro | 0,05 |
| Moedas por orbe | 5,0 |
| Multiplicador de Moedas | +8% por nível |
| Renda da corrida 1 | ~254 moedas |
| Custo do 1º upgrade | 246 (Avião nv. 2) |

**O primeiro upgrade é comprável logo após a primeira corrida.** Isso é
deliberado: o jogador precisa completar o ciclo inteiro — voar, ganhar, comprar,
ver a diferença — antes de decidir se o jogo merece a segunda sessão.

### 6.1 As 30 primeiras corridas (saída da simulação, v2 — 3 trilhas)

| # | Fase | Meta | Distância | Duração | HUD | Moedas | Saldo | Comprou |
|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 3.900 m | 3.900 m ✅ | 39 s | 50 km/h | 254 | 34 | Avião |
| 2 | 2 | 4.992 m | 4.397 m | 42 s | 54 km/h | 282 | 70 | Avião |
| 3 | 2 | 4.992 m | 4.735 m | 42 s | 59 km/h | 299 | 94 | Avião |
| 4 | 2 | 4.992 m | 4.992 m ✅ | 42 s | 64 km/h | 312 | 98 | Avião |
| 5 | 3 | 6.390 m | 5.477 m | 43 s | 70 km/h | 338 | 92 | Avião |
| 6 | 3 | 6.390 m | 5.891 m | 43 s | 76 km/h | 359 | 67 | Avião |
| 7 | 3 | 6.390 m | 6.343 m | 44 s | 82 km/h | 382 | 19 | Avião |
| 8 | 3 | 6.390 m | 6.390 m ✅ | 41 s | 89 km/h | 381 | 220 | Estilingue |
| 9 | 4 | 8.179 m | 6.831 m | 44 s | 89 km/h | 407 | 146 | Avião |
| 10 | 4 | 8.179 m | 7.354 m | 44 s | 97 km/h | 434 | 43 | Avião |
| 11 | 4 | 8.179 m | 7.917 m | 45 s | 106 km/h | 462 | 105 | Moedas |
| 12 | 4 | 8.179 m | 7.935 m | 45 s | 106 km/h | 502 | 7 | Avião |
| 13 | 4 | 8.179 m | 8.179 m ✅ | 43 s | 115 km/h | 512 | 87 | Estilingue |
| 14 | 5 | 10.469 m | 8.551 m | 45 s | 115 km/h | 536 | 622 | — |
| 15 | 5 | 10.469 m | 8.551 m | 45 s | 115 km/h | 536 | 487 | Avião |
| 16 | 5 | 10.469 m | 9.204 m | 46 s | 125 km/h | 571 | 308 | Avião |
| 17 | 5 | 10.469 m | 9.906 m | 46 s | 135 km/h | 610 | 79 | Avião |
| 18 | 5 | 10.469 m | 10.469 m ✅ | 46 s | 147 km/h | 640 | 718 | — |
| 19 | 6 | 13.400 m | 10.662 m | 46 s | 147 km/h | 651 | 432 | Avião |
| 20 | 6 | 13.400 m | 11.475 m | 47 s | 160 km/h | 696 | 79 | Avião |
| 21 | 6 | 13.400 m | 12.349 m | 47 s | 174 km/h | 744 | 823 | — |
| 22 | 6 | 13.400 m | 12.349 m | 47 s | 174 km/h | 744 | 395 | Avião |
| 23 | 6 | 13.400 m | 13.290 m | 48 s | 189 km/h | 795 | 330 | Moedas |
| 24 | 6 | 13.400 m | 13.332 m | 48 s | 189 km/h | 858 | 151 | Estilingue |
| 25 | 6 | 13.400 m | 13.341 m | 48 s | 189 km/h | 859 | 1.010 | — |
| 26 | 6 | 13.400 m | 13.341 m | 48 s | 189 km/h | 859 | 558 | Avião |
| 27 | 6 | 13.400 m | 13.400 m ✅ | 45 s | 205 km/h | 857 | 1.415 | — |
| 28 | 7 | 17.152 m | 14.355 m | 48 s | 205 km/h | 918 | 868 | Avião |
| 29 | 7 | 17.152 m | 15.462 m | 49 s | 223 km/h | 983 | 213 | Avião |
| 30 | 7 | 17.152 m | 16.637 m | 49 s | 242 km/h | 1.052 | 1.265 | — |

**Diagnóstico da simulação (40 corridas):** 30 upgrades comprados; 10 corridas
sem compra (o jogador está juntando); ganho médio de **6,1%** de capacidade por
compra; distância de 4.088 m para 22.419 m (×5,5); duração de 41,4 s para
50,9 s. **Idêntico, dentro do arredondamento, ao resultado do modelo de 6
atributos** — a fusão em 3 trilhas não mudou o ritmo da progressão, só a
apresentação. Em 90 corridas o jogador compra **44 upgrades no total** (mesmo
número da versão anterior) e maxa as três trilhas, chegando a ~58,9 km de
capacidade — o mesmo teto de ~59 km já documentado.

---

## 7. Fases e biomas

A meta de cada fase é 28% maior que a anterior — o equivalente a ~4 compras.
Isso mantém o ritmo de uma fase nova a cada 4–6 corridas.

| Fase | Meta | Nível visual | HUD | Duração | Bioma |
|---|---|---|---|---|---|
| 1 | 3.900 m | 1 | 50 km/h | 41 s | Duna inicial |
| 2 | 4.992 m | 2 | 54 km/h | 42 s | Deserto aberto |
| 3 | 6.390 m | 3 | 70 km/h | 43 s | Terreno rachado |
| 4 | 8.179 m | 5 | 89 km/h | 44 s | Vilarejo e igreja |
| 5 | 10.469 m | 7 | 115 km/h | 45 s | Cidade do velho oeste |
| 6 | 13.400 m | 8 | 147 km/h | 46 s | Estação e locomotiva |
| 7 | 17.152 m | 11 | 205 km/h | 48 s | Mesas rochosas |
| 8 | 21.955 m | 12 | 263 km/h | 49 s | Cânion profundo |
| 9 | 28.102 m | 14 | 337 km/h | 51 s | Ponte ferroviária |
| 10 | 35.971 m | 15 | 470 km/h | 53 s | Planalto alto |
| 11 | 46.043 m | 17 | 603 km/h | 54 s | Tempestade de areia |
| 12 | 58.935 m | 18 | 774 km/h | 56 s | Salinas |
| 13 | 75.437 m | ~20 | ~980 km/h | ~57 s | Costa e falésias |

*(Tabela v2, saída de `sim/progressao.py` com o modelo de 3 trilhas — fase 13
extrapolada, a simulação de referência parou na 12 em 40 corridas.)*

**Duração: 41 s na fase 1, ~57 s na fase 13.** A restrição de 40–60 s se
cumpre ao longo de toda a progressão — não por ajuste manual, mas porque o
consumo é por segundo (Decisão A). Números praticamente idênticos aos da
versão de 6 atributos: a fusão em 3 trilhas preservou o ritmo de fases, não só
o ritmo de compras.

**O número de fases é derivado, não escolhido.** Com 44 upgrades disponíveis, o
teto de capacidade é ~59 km, o que sustenta exatamente 13 fases. Minha primeira
versão tinha 24 fases desenhadas e o jogador travava na 13 sem ter mais nada
para comprar — as 11 restantes eram conteúdo inalcançável. **Regra: sempre que
adicionarem fases, adicionem níveis de upgrade na mesma proporção. Nunca uma
sem a outra.**

### Os biomas na fase 1

Dentro de uma única corrida o cenário também evolui (duna → deserto → terreno
rachado → vilarejo → cidade → estação → mesas → cânion, como no vídeo). Ou seja,
há **duas escalas de progressão visual**: dentro da corrida e entre fases. A
segunda desloca o ponto de partida da primeira — na fase 8 o jogador já começa
no cânion.

### Quando o jogador passa de todos os biomas

Aos 75 km ele viu tudo. Três saídas, em ordem de custo:
1. **Modo infinito** — sem meta, os biomas ciclam com variação de paleta, e o
   placar vira o recorde pessoal. Custo quase zero, é o que recomendo primeiro.
2. **Prestígio** — reinicia os upgrades em troca de um multiplicador permanente.
   Padrão do gênero, barato de implementar, e estende a curva indefinidamente.
3. **Novos biomas** — o único que custa arte de verdade.

---

## 8. Coletáveis e correntes de ar

### Orbes

- **Cadência:** 0,85 por segundo de voo → espaçamento no mundo de `v/0,85`
  metros, que cresce com a velocidade (ver Decisão B).
- **Valor:** 1,2 unidades de energia (≈ 0,6 s de voo) + 5 moedas.
- **Posicionamento:** procedural, mas em **padrões desenhados à mão** de 3 a 7
  orbes — arco, escada subindo, linha em mergulho. Orbes isolados e aleatórios
  não criam decisão; um arco que sobe cria a decisão de trocar velocidade por
  altura.
- **A decisão que criam:** desviar da trajetória ótima de energia custa
  velocidade. Pegar o padrão inteiro devolve mais do que custou; pegar metade
  fica no prejuízo. Isso transforma cada padrão numa aposta pequena.

### Correntes de ar

- **Densidade:** 1 a cada ~600 m, mais frequentes nos biomas de cânion.
- **Efeito:** `a_térmica = +6 m/s²` enquanto o avião estiver dentro do volume.
- **Formato:** tubos visíveis em ciano, geralmente atravessando o cânion na
  diagonal — obrigam a subir ou descer para entrar.
- **Papel:** são o oposto dos orbes. O orbe é um desvio pequeno e frequente; a
  térmica é um compromisso longo que muda a altitude por vários segundos.

---

## 9. Fim de corrida

**A corrida termina quando:** a meta é atingida (✅ vitória), a energia acaba
(o avião plana e pousa), ou o avião toca o solo.

**Recomendação sobre o toque no solo: encerra, mas não pune.** O jogador mantém
todas as moedas do trecho já voado e o recorde de distância vale.

Justificativa em termos de frustração vs. tensão: a tensão vem de *"consigo
chegar na meta?"*, e essa pergunta já é suficiente porque a energia é finita.
Adicionar perda de moedas ao tocar o solo cria uma segunda ameaça que ataca
justamente a coisa que sustenta a sessão — o progresso. Em jogo de progressão,
punição que apaga progresso não gera tensão, gera desinstalação. O toque no solo
já é punição bastante: encerra a corrida antes da meta.

**Uma exceção que vale testar:** conceder um bônus de 15% em moedas para quem
chega à meta *sem* tocar o solo. Recompensar o voo limpo é mais eficaz que punir
o sujo, porque a recompensa é visível e a punição só é sentida.

---

## 10. Riscos de balanceamento

| Sintoma observável | Causa provável | O que ajustar |
|---|---|---|
| Jogador para de comprar e só repete corridas | Custos crescem mais rápido que a renda | Baixar as razões `r` dos custos, ou subir `MOEDAS_POR_METRO` |
| "Comprei e não mudou nada" | Ganho por compra abaixo de ~5% | Menos níveis com degraus maiores. Nunca adicionar níveis para "dar mais conteúdo" |
| Corridas passam de 60 s e ficam arrastadas | `passo_e` do Avião ou Moedas subindo demais | Cortar `passo_e` em `dados/atributos.gd`/`sim/modelo.py`. **A duração é o teto que limita esses dois** |
| Voo nunca acaba | Orbes por distância em vez de por tempo, ou `R·f·e ≥ c` | Cadência em tempo. Manter `R·f·e < 0,7·c` |
| Jogador trava numa fase sem nada para comprar | Fases desenhadas além do teto de upgrades | Fases e níveis crescem juntos. Ver seção 7 |
| Progressão explode e o conteúdo acaba em 2 dias | Ganho por compra acima de ~12% | Aumentar a contagem de níveis e reduzir o passo |
| Todos compram o mesmo atributo sempre | Um atributo domina em ganho por moeda | Subir o custo dele ou o efeito dos concorrentes até a curva gulosa alternar |

### O risco de escopo, que é o maior de todos

Com 44 upgrades e 13 fases, **o conteúdo acaba em ~71 corridas, ou 1,3 hora de
jogo.** É suficiente para validar o loop, não para lançar. Um produto de loja
precisa de 15 a 30 horas, o que significa multiplicar por 3 a 5 tanto os níveis
quanto as fases — e isso muda o balanceamento, porque mais níveis com o mesmo
crescimento total reduz o ganho por compra. Planejem a expansão junto com a
curva, não depois.

---

## 11. Ordem de implementação

### O primeiro protótipo que decide tudo

**Antes de qualquer arte, bioma ou upgrade**, construa isto:

> Um avião, um terreno plano, o modelo de voo da seção 2, o velocímetro e o
> contador de distância. Controle de pitch por arraste. Nada mais.
> Sem lançamento, sem orbes, sem moedas, sem loja.

**A pergunta que ele responde:** *segurar o avião no ar e gerenciar velocidade
por 45 segundos é divertido sozinho?*

Se a resposta for não, nenhum sistema de upgrade salva — o jogador vai passar
95% do tempo dentro desse loop. Se for sim, todo o resto é amplificação. Este é
o teste mais barato e mais decisivo do projeto, e ele cabe em uma semana em cima
do que o spike já tem.

### Sequência

| Etapa | Entrega | Depende de |
|---|---|---|
| **1** | Modelo de voo + terreno com relevo + controle de pitch | Streaming de chunks (já existe) |
| **2** | Energia, consumo e fim de corrida por esgotamento | 1 |
| **3** | Orbes em padrões desenhados + coleta | 2 (a energia precisa existir para o orbe ter valor) |
| **4** | Meta de fase, barra de progresso, tela de resultado | 2 |
| **5** | Moedas e loja de upgrades com os 6 atributos | 4 |
| **6** | Estilingue com medidor de força | 5 (o upgrade precisa existir para o estilingue significar algo) |
| **7** | Biomas por distância e transição | 4 |
| **8** | Correntes de ar | 3 |
| **9** | Recompensa física (dinheiro caindo) e confete | 4 |

**O que já está pronto e entra direto:** streaming de cenário com pooling,
câmera em terceira pessoa, `FabricaModelos` (consome o nível visual da seção
5.4), velocímetro e barra de progresso desenhados em código, save, monitor de
desempenho, piloto automático de teste e a exportação.

**O piloto automático merece uma adaptação prioritária.** Ele já sabe jogar
sozinho e emitir relatório; ensiná-lo a gerenciar energia transforma esta
simulação em Python num teste rodando dentro do jogo real — e aí o balanceamento
passa a ser verificado contra o código de produção, não contra um modelo
paralelo que pode divergir dele.

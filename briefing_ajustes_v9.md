# Voo Evolution — Roadmap v9: fechando o gap com o jogo de referência real

Continuação de `briefing_ajustes_v8.md`, agora em cima de
`pesquisa_epic_plane_evolution.md` (pesquisa real sobre o Epic Plane
Evolution - loja oficial, changelog, guias de comunidade), depois do
feedback "está MUITO diferente do jogo de referência". Os 5 gaps
estruturais identificados na pesquisa viram 5 fases aqui, ordenadas por
risco/esforço - as duas primeiras são seguras e não tocam fisica de voo
calibrada; as duas do meio reescrevem sistemas centrais e citação exigem
recalibração completa; a última é a maior (conteúdo, não código).

**Status: P1-P5 implementados e testados.**

---

## P1 — Estilingue vira progressão global (IMPLEMENTADO)

**Gap (pesquisa §4):** a fonte mais recente (clashiverse.com, versão atual
do app) descreve o Estilingue como upgrade que PERSISTE entre fases, sem
teto - diferente da trilha AVIÃO, que reseta a cada troca de avião. Hoje
nossas 3 trilhas (AVIÃO/MOEDAS/ESTILINGUE) resetam igualmente.

**O que foi feito:**
- `dados/atributos.gd`: nova constante `Atributos.ORDEM_POR_AVIAO := [AVIAO, MOEDAS]`
  (a antiga `ORDEM` continua existindo, agora só para ordem de exibição na
  loja). `soma_minima()`/`soma_maxima()` passaram a usar
  `ORDEM_POR_AVIAO` - a progressão visual do avião (`nivel_visual()`,
  `asas_atual()`, `potencia_motor_atual()`) não é mais afetada pelo
  Estilingue, que deixou de "pertencer" a um avião especifico.
- `Atributos.ESTILINGUE.max`: 6 -> 40 (bem mais fundo que antes, sem ser
  literalmente infinito - ver nota de escopo abaixo).
- `autoload/dados_jogo.gd`: novo campo persistente `nivel_estilingue: int`,
  salvo/carregado como `moedas` (nao mais dentro de `niveis_por_aviao`).
  `nivel()`/`comprar()` agora despacham pelo id: ESTILINGUE le/escreve
  `nivel_estilingue`; AVIAO/MOEDAS continuam por avião como antes.
- `VERSAO_SAVE` subiu (save antigo com Estilingue por avião nao é
  compatível com a nova coluna global).

**Nota de escopo:** a pesquisa aponta o Estilingue como "sem teto" na
referência, mas isso provavelmente reflete jogadores com centenas de
corridas acumuladas, não algo pra replicar literalmente como infinito (a
UI de pontinhos da loja - `ui/cartao_atributo.gd` - desenha um ponto por
nível, o que não escala pra "infinito"). Fixei um teto alto (40) em vez de
remover o conceito de teto - se depois de jogar isso ainda parecer raso
demais, é so subir o número de novo, não precisa de mudança estrutural.

---

## P2 — Loop de prestígio ("rolling over") (IMPLEMENTADO)

**Gap (pesquisa §1):** ao terminar a última fase, o jogo de referência deixa
o jogador voltar pra fase 1 com a renda multiplicada, e repetir - "rolling
over". Hoje `DadosJogo.registrar_corrida()` só avança
`fase_maxima_alcancada` até `Config.TOTAL_FASES - 1` e para: não existe
"fim de jogo" nem replay com bônus.

**O que foi feito:**
- `autoload/dados_jogo.gd`: novo campo persistente `prestigios: int`. Nova
  função `bonus_prestigio() -> float` (multiplicador de moedas, +50% por
  prestígio - `Config.BONUS_PRESTIGIO_POR_NIVEL`, [A CALIBRAR]). Entra na
  cadeia de `ganho *=` de `registrar_corrida()`, junto de `bonus_moedas()`
  e do multiplicador de dificuldade.
- `registrar_corrida()`: quando o jogador bate a meta E já está na última
  fase (`fase_selecionada == TOTAL_FASES - 1`), em vez de só marcar
  "concluído" sem efeito (como hoje), incrementa `prestigios`, reseta
  `fase_maxima_alcancada`/`fase_selecionada` para 0 e `niveis_por_aviao`
  (progresso de AVIAO/MOEDAS de cada avião - faz sentido resetar porque a
  economia de cada fase foi calibrada pra ser vencível a partir do nível 1
  daquele avião; manter os niveis antigos tornaria a fase 1 trivial demais
  de novo, o problema que o v3-v7 gastou varias rodadas evitando). O
  Estilingue (P1, agora global) e os prestígios acumulados NÃO resetam -
  são o que dá sentido a repetir.
  Devolve um novo campo no registro, `"prestigiou": true`, para a UI.
- `ui/resultado.gd`: novo texto de destaque quando `prestigiou` vem
  `true` - "PRESTIGIO! Bonus de moedas permanente: xN,NN".

**Por que reseta AVIAO/MOEDAS mas não o resto:** a alternativa (manter
tudo no máximo e só repetir) tornaria toda repetição imediatamente
trivial - sem escolha nenhuma de upgrade, só "voar e coletar", o oposto do
loop viciante que a pesquisa descreve. Resetar as trilhas por avião e
manter só o multiplicador global é o que faz "a próxima volta" valer a
pena econômicamente sem ficar fácil de novo.

---

## P3 — Evolução em 4 peças discretas por avião (IMPLEMENTADO)

**Gap (pesquisa §4):** a trilha AVIÃO hoje é um número único (1 a 30) que
move velocidade+aerodinâmica+impulso ao mesmo tempo. A referência separa
isso em ATÉ 4 peças nomeadas (Asa Esquerda, Asa Direita, Cauda,
Hélice/Motores), cada uma com poucos níveis (~5), cada uma com seu próprio
botão de compra na loja.

**O que foi feito:** `dados/atributos.gd` trocou a trilha AVIAO (um numero
so) por 4 pecas nomeadas - ASA_ESQUERDA, ASA_DIREITA, CAUDA, HELICE - cada
uma com 8 niveis (contra os 30 fundidos de antes), dentro de
`niveis_por_aviao` (continuam resetando ao trocar de aviao). Fisica
remapeada em `autoload/dados_jogo.gd`: `v_cruzeiro()`/`bonus_impulso()`
agora leem so de HELICE; `arrasto_mult_atual()` combina ASA_ESQUERDA *
ASA_DIREITA * CAUDA; `asas_atual()` virou binario por peca (nivel > 1 =
"comprou aquela asa") em vez de uma fracao "t" compartilhada;
`potencia_motor_atual()` e so o progresso da propria peca HELICE.
`jogo/fabrica_modelos.gd::criar()` ganhou um parametro `pecas` (opcional,
mantem compatibilidade com chamadores antigos como
`testes/teste_modelos.gd`/`ui/cartao_veiculo.gd`) - cada asa/cauda/helice
agora aparece e cresce com o progresso da SUA PROPRIA peca, permitindo
inclusive um aviao assimetrico (uma asa mais evoluida que a outra).
`Config.METAS_FASE` remedida do zero com o novo `--nivel=40` (o maior teto
entre as pecas/trilhas atuais).

---

## P4 — Controle por toque/swipe em vez de arraste contínuo (IMPLEMENTADO)

**Gap (pesquisa §3):** guias de comunidade descrevem controle por
toques/swipes rápidos, com penalidade por segurar o dedo pressionado -
"segurar custa velocidade". Hoje `Aviao._aplicar_arraste()` usa
`InputEventScreenDrag` contínuo: enquanto o dedo arrasta, o `_angulo_alvo`
muda proporcionalmente, sem custo por manter arrastando.

**Escopo escolhido (mais conservador que uma reescrita total):** em vez de
substituir o modelo de nudge contínuo por impulsos discretos (que exigiria
recalibrar a física do zero, o maior risco identificado originalmente),
mantive `Aviao._aplicar_arraste()` como está e ACRESCENTEI dois
comportamentos novos, aditivos:
1. **Decaimento do nudge**: sem arraste novo no frame, `_angulo_alvo` decai
   de volta a zero (`Config.DECAIMENTO_ANGULO_GRAUS`) - um toque vira um
   ajuste pontual que se apaga sozinho, não um comando permanente.
2. **Penalidade por segurar**: `Aviao` agora escuta `InputEventScreenTouch`
   e rastreia `_dedo_pressionado`; enquanto o dedo está na tela (arrastando
   ou não), `_integrar()` cobra um arrasto extra
   (`Config.ARRASTO_POR_SEGURAR`) - "segurar custa velocidade", batendo com
   a pesquisa, sem precisar reescrever o modelo de voo inteiro.

`testes/piloto_automatico.gd` foi atualizado pra simular um jogador que
segura o dedo a corrida inteira (pior caso realista), e `Config.METAS_FASE`
foi remedida mais uma vez com esse novo arrasto ativo.

---

## P5 — Fases desenhadas à mão em vez de proceduais (IMPLEMENTADO O PILOTO)

**Gap (pesquisa §2, o maior identificado):** cada fase da referência tem
identidade própria - dentro de uma casa (cadeiras, banheira, janela),
escritório (mesas de reunião), planador solar (mecânica própria de luz),
mundo estilo Minecraft, até um barco viking. Hoje nosso cenário é 100%
procedural: `Terreno.BIOMAS` muda cor por distância, `GeradorObstaculos`
(v8) sorteia fileiras de parede/pilar com semente fixa - visualmente
contínuo, sem nenhuma fase ter uma identidade única reconhecível.

**O que foi feito (o piloto proposto no item 3 abaixo, não as 13 fases):**
novo `jogo/cenario_fixo.gd` - um catálogo de VINHETAS (sequências de
obstáculo fixas e nomeáveis, usando a mesma classe `Obstaculo`/`Pool` já
existente) por índice de fase. `jogo/gerador_obstaculos.gd::iniciar()`
consulta esse catálogo: se a fase atual tem vinheta, povoa ela primeiro e
só deixa a geração procedural aleatória assumir DEPOIS do fim da vinheta -
"o avião sai novamente para o exterior", exatamente como a pesquisa
descreve. Fases sem vinheta continuam 100% proceduais, sem mudança - não é
tudo ou nada (item 4 da proposta original).

A Fase 2 (a mais documentada na pesquisa) ganhou a primeira vinheta: "dentro
de uma casa" - duas cadeiras, uma banheira, saída por uma janela (abertura
lateral na parede). Nota de escala: os "móveis" usam a MESMA altura das
colunas/paredes já calibradas no sistema procedural (~30-40m), não a altura
real de uma cadeira - um obstáculo baixo de verdade seria sobrevoado sem
querer, já que a altitude de cruzeiro varia muito com o nível de evolução.

`testes/piloto_automatico.gd` ganhou um desvio genérico de obstáculo
(`GeradorObstaculos.obstaculo_mais_proximo()`) como último recurso quando
não há uma fileira LATERAL para mirar - sem isso o piloto bateria de frente
nos móveis, que não são fileiras proceduais. Medido: a Fase 2 no nível
máximo mantém praticamente a mesma capacidade de antes da vinheta (1380 m
vs 1378 m sem ela) - não precisou recalibrar `Config.METAS_FASE`.

**Por que só uma fase agora, não as 13:** cada vinheta é level design de
verdade (posições, temas, geometria escolhidos à mão), não uma mudança de
fórmula - é o item de maior esforço por unidade do roadmap inteiro. A
arquitetura (catálogo de vinhetas + transição pra procedural) já suporta
adicionar as outras 12 (escritório, planador solar, igreja, mundo estilo
Minecraft, barco viking...) uma de cada vez, no mesmo padrão da Fase 2,
sempre que fizer sentido priorizar.

---

## Ordem de implementação sugerida

| Ordem | Fase | Status | Por que essa ordem |
|---|---|---|---|
| 1 | P1 - Estilingue global | Feito | Isolado, baixo risco, nao toca fisica |
| 2 | P2 - Prestigio | Feito | Isolado, baixo risco, nao toca fisica |
| 3 | P3 - 4 pecas por aviao | Especificado | Reescreve economia calibrada - precisa de rodada propria |
| 4 | P4 - Controle por toque | Especificado | Reescreve fisica calibrada - precisa de rodada propria |
| 5 | P5 - Fases a mao | Especificado | Maior esforco (conteudo, nao formula) - comecar por 1-2 fases piloto |

## Perguntas em aberto

1. **P2 - o multiplicador de prestígio (+50% por volta) é um primeiro
   palpite, não medido.** Vale calibrar depois de ver quantas voltas um
   jogador real dá em quanto tempo.
2. **P3/P4 - qual entra primeiro?** Os dois são reescritas de sistema
   central; sugiro P3 primeiro (é só economia/UI, mais fácil de testar
   isoladamente) e P4 depois (mexe em física, mais difícil de isolar).
3. **P5 - vale pilotar com qual fase primeiro?** A fase 2 (casa) é a mais
   descrita em detalhe pelas fontes e tem uma identidade forte e simples
   (poucos móveis, uma janela de saída) - candidata natural pro piloto.

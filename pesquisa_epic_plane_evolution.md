# Pesquisa: Epic Plane Evolution (Voodoo) — referência real, não teórica

Documento de pesquisa (não é um briefing de implementação) feito para responder
"está muito diferente do jogo de referência" com fatos verificados, não só a
análise teórica que já tínhamos. Fontes: loja oficial (Google Play/App Store),
changelog de versão da Apple, e três guias/wikis de jogadores independentes
(wesl.ee, clashiverse.com, tap-guides.com) que documentam a mecânica em
detalhe. Marco cada afirmação com a confiança que tenho nela - loja oficial e
changelog são fatos; guias de comunidade são relato de jogador, majoritário
mas não 100% verificado; e sinalizo explicitamente onde as fontes DIVERGEM
entre si (o jogo mudou de versão pra versão, e existe uma versão "demo"
simplificada no YouTube Playables, diferente do app completo).

---

## Resumo executivo: as maiores diferenças estruturais

Por ordem de impacto - isto é o que eu acho que explica a sensação de "muito
diferente":

1. **O jogo de referência tem fases DESENHADAS À MÃO, curtas e tematicas
   (a "casa", o "escritório", a "igreja", um mundo estilo Minecraft, um
   barco viking) - não distância procedural aleatória.** Nosso jogo é 100%
   procedural (bioma por distância, obstáculo por sorteio). Isto é
   provavelmente a maior fonte da sensação de "diferente".
2. **O jogo de referência tem um loop de PRESTÍGIO ("rolling over"): ao
   terminar todas as fases, você volta pra fase 1 com um multiplicador de
   renda muito maior, e repete.** Nosso jogo é uma progressão linear de 13
   fases sem loop de volta. Isto muda a MOLDURA inteira do jogo (infinito
   e repetitivo vs. campanha finita).
3. **A evolução do avião é 4 peças DISCRETAS e nomeadas por avião (Asa
   Esquerda / Asa Direita / Cauda / Hélice ou Motores), cada uma parando de
   ter efeito visual depois de completa.** Nosso trilha "AVIÃO" é um número
   único (até nível 30) que mexe em 3 multiplicadores ao mesmo tempo
   (velocidade/aerodinâmica/impulso) - mais abstrato, menos "eu construí
   essa peça".
4. **O Estilingue, na versão atual do app completo, parece ser GLOBAL e sem
   teto (persiste entre todas as fases)** - diferente da nossa trilha
   ESTILINGUE, que reseta a cada troca de avião igual à trilha AVIÃO.
5. **O controle é por TOQUES/SWIPES rápidos, não arrastar contínuo** -
   segurar o dedo pressionado custa velocidade. Nosso controle é arraste
   contínuo (`InputEventScreenDrag`) que define um ângulo-alvo constante.

O resto do documento detalha cada sistema com as fontes.

---

## 1. Loop geral e estrutura de progressão

**Confirmado pela loja oficial:** "Launch, Upgrade, and Conquer the Skies" -
lançar por estilingue, coletar moedas durante o voo, evoluir componentes,
repetir. Isso já bate com nosso jogo.

**Confirmado por guias de comunidade (clashiverse.com), não pela loja:**
existe um sistema de "rolling over" - depois de completar todas as fases
disponíveis, o jogador pode voltar pra fase 1 com a renda MULTIPLICADA
("cada vez que você faz isso, sua renda multiplica massivamente"). O
objetivo declarado é "farmar moedas mais rápido nas fases iniciais e
acelerar o replay". Isso e o sistema de multiplicador de renda persistente
(que segundo um relato de jogador pode chegar a "2,14 bilhões" depois de
uso extensivo) sugerem que o jogo INTEIRO é desenhado pra ser jogado várias
vezes em loop, não terminado uma vez.

**Isso e diferente do que temos:** nosso `DadosJogo.registrar_corrida()` só
avança `fase_maxima_alcancada` até `Config.TOTAL_FASES - 1` e para. Não há
conceito de "terminar tudo e recomeçar com bônus".

## 2. Cenário e estrutura de fases (a maior divergência)

**Confirmado por wesl.ee (versão YouTube Playables, 7 fases) - o mais
detalhado que encontrei:**

| Fase | Avião | Ambiente | Obstáculos específicos | Observação |
|---|---|---|---|---|
| 1 | Monoplano (parecido com um Corsair) | Lagoa → deserto | Árvores no início, depois deserto aberto | "Fácil depois de decolar" |
| 2 | Biplano | **Dentro de uma casa** | Duas cadeiras, uma banheira, sai pela janela | Calçada termina o nível |
| 3 | Jato | Urbano | Prédios (voo rente, "perigosamente perto") | "Uma das fases mais difíceis" |
| 4 | Avião de papel (nomes de upgrade não convencionais: "Great/Super/Hyper/Mega Paper Airplane") | Escritório | Mesas de sala de reunião | "A maioria considera a fase mais difícil" |
| 5 | Biplano (de novo) | Rural | Árvores, silos de grão, catavento de bombeamento | Navegação moderada |
| 6 | **Planador solar** | Área ensolarada | Sem obstáculo fixo - o desafio é o próprio sistema de luz | Asas brilham dourado no sol = ganho de velocidade grande; na sombra fica "lento como melaço" |
| 7 | Não especificado | Campo → igreja | Controles "sensíveis" no início; navegação de campo crítica antes da abertura na igreja | "A fase mais desafiadora" pro autor |

**Confirmado por clashiverse.com (guia separado, versão app completo,
fases mais avançadas):** existe também uma fase **"Block Plane"** com
visual estilo Minecraft ("colinas mais agudas, objetos mais apertados"),
com uma casa como obstáculo no início e um vale em V apertado entre duas
colinas no final - e o guia confirma que fases posteriores incluem
**Planador, "Viking Boat" (um barco viking!) e Fighter Jet** como o avião
mais avançado/última fase.

**Conclusão pra nós:** cada fase do jogo de referência é um MICRO-NÍVEL
COM IDENTIDADE PRÓPRIA - um obstáculo específico e nomeável (a casa, a
mesa de reunião, o vale), não uma sequência aleatória de paredes/pilares
geradas por fórmula. O bioma muda o SIGNIFICADO da fase (você literalmente
está dentro de uma casa, depois num escritório, depois vira um barco
viking), não só a cor do chão. Nosso `Terreno.BIOMAS` (11 biomas por cor,
transição suave por distância) e `GeradorObstaculos` (fileiras aleatórias
com semente fixa) são o oposto disso: contínuos, proceduais, sem
identidade própria por fase. Isso é provavelmente a causa #1 da sensação
"muito diferente".

## 3. Física e controles

**Confirmado pela loja oficial:** lançamento por estilingue determina
velocidade/ângulo inicial; em voo, "ajuste o pitch e o ângulo do avião pra
manter momentum e evitar obstáculos".

**Confirmado por MÚLTIPLOS guias de comunidade, de forma consistente
(clashiverse, tap-guides, gamefaqs) - este é provavelmente o achado mais
acionável da pesquisa:**
- O controle é por **toques/swipes RÁPIDOS** (cima/baixo/esquerda/direita),
  não por segurar o dedo pressionado. Guias avisam explicitamente: **"segurar
  o dedo pressionado custa velocidade"** / "swipe pra guiar - não segure o
  dedo".
- O objetivo declarado do jogador é manter a velocidade **constante ou
  crescente**, monitorada por um velocímetro na tela ("speedometer" - a
  Apple confirma isso como "Flight HUD Upgrade" na v1.13.0). Mergulhar de
  leve ganha velocidade; subir só quando necessário pra evitar obstáculo.
- **Técnica avançada citada:** subir bastante no início pra depois usar a
  gravidade na descida e ganhar velocidade suficiente pra "pular" trechos
  inteiros ou alcançar zonas novas - ou seja, o pico da parábola de
  lançamento É uma decisão estratégica do jogador (quanto subir antes de
  mergulhar), não só uma consequência passiva da física.
- Existe um sistema de **boost/impulso com timing** ("use o primeiro boost
  no pico do arco de lançamento, guarde o segundo pra quando a descida
  começar, pra contrariar a gravidade") - mais orientado a TIMING dentro
  do arco do que o nosso impulso (usos fixos, botão a qualquer momento).

**Isso é diferente do que temos:** nosso `Aviao._aplicar_arraste()` usa
`InputEventScreenDrag` contínuo, que define um `_angulo_alvo` que o nudge
persegue enquanto o dedo estiver arrastando - mais parecido com "segurar
uma direção" do que "toques rápidos". Não há penalidade por manter o dedo
parado/arrastando, nem um conceito de "toque discreto = ajuste, soltar =
sem input". Vale considerar mudar a interação de arraste contínuo para
"swipe = impulso pontual" para bater com a referência.

## 4. Evolução da aeronave (economia de upgrade)

**Confirmado por clashiverse.com, de forma bem específica:**
- **Trilha AVIÃO (por fase):** exatamente **4 peças**, nomeadas -
  tipicamente Asa Esquerda, Asa Direita, Cauda, Hélice (ou "Motores" em
  fases com jato). Cada peça tem upgrades PRÓPRIOS (o guia do Block Plane
  fala em "20 total" pras 4 categorias, sugerindo ~5 níveis por peça, não
  30). Depois de completar as 4, "nenhuma mudança visível ocorre" além
  daquele nível - ou seja, o teto é bem mais raso que o nosso (nosso
  `Atributos.AVIAO` tem 30 níveis fundidos).
- **Trilha ESTILINGUE:** aqui as fontes DIVERGEM entre si (marco a
  divergência porque é importante). wesl.ee (versão Playables, mais
  antiga/simples) diz que upgrades de estilingue "não persistem entre
  fases, embora a estética persista". clashiverse.com (guia mais recente,
  do app completo) diz o oposto: **"upgrades de estilingue persistem
  ENTRE fases... sem teto"**. Minha leitura: o design mudou ao longo das
  atualizações (a Apple confirma "Economy rebalance" em v1.11.0 e outros
  rebalanceamentos em quase toda versão) - o app atual parece ter o
  Estilingue como progressão GLOBAL, não por avião.
- **Trilha RENDA/INCOME:** multiplica moedas, e "empilha multiplicativamente
  com os bônus de conclusão de fase" - igual ao espírito do nosso
  `BONUS_CONCLUSAO_FASE`.
- Existe também um **Rocket Booster** cosmético/funcional (desbloqueado por
  anúncio ou moeda premium "Skip'its") cujos primeiros 10 níveis só mudam a
  aparência, e só depois passam a estender a duração do boost - reforça a
  regra "evolução precisa ser visual antes de virar poder".

**Isso é diferente do que temos:** nossa trilha AVIÃO funde 3 efeitos
(velocidade/aerodinâmica/impulso) num único número de 1 a 30, sem
corresponder a peças nomeadas e clicáveis separadamente. A referência
separa CADA peça visível em um upgrade PRÓPRIO, mais raso (poucos níveis),
o que é mais legível ("comprei a asa direita" vs "subi pro nível 14 de
AVIÃO"). Nossa trilha ESTILINGUE reseta por avião como a AVIÃO - a
referência (pelo menos na leitura mais recente) não reseta o estilingue.

## 5. Gráficos e câmera

**Confirmado pela loja oficial + changelog:** modelos 3D descritos como
"vibrantes, alta qualidade", "coloridos e satisfatórios". Atualizações
recentes mencionam especificamente: "VFX boost: mais brilho, mais
explosão", "grama da fase 1 recebeu upgrade visual", "Flight HUD Upgrade"
com efeito de velocímetro. Isso sugere um estilo 3D estilizado/cartoon
saturado, não realista nem estritamente low-poly geométrico - mais perto
de "toy-like" (o próprio nome dos aviões iniciais é "avião de brinquedo",
"avião de papel").

**Não consegui confirmar de forma direta e específica** o ângulo exato de
câmera (se é estritamente lateral/2.5D ou uma perspectiva 3D com leve
rotação) - nenhuma fonte descreveu isso em detalhe técnico. A análise
teórica original (baseada em vídeos) descreve uma câmera lateral com o
avião em primeiro plano, o que é consistente com o gênero mas não pude
confirmar com uma fonte textual direta - marco como INFERIDO, não
confirmado.

**Confiança baixa/possível confusão com outro jogo:** uma fonte
(taggame.io) mencionou "mais de 50 aeronaves para desbloquear" e
"progressão através da fusão de aviões idênticos" (mecânica de merge) -
isso NÃO aparece em nenhuma outra fonte e contradiz a estrutura de "uma
fase = um avião" que as outras 3 fontes (wesl.ee, clashiverse, gamefaqs)
descrevem de forma consistente. Provavelmente essa fonte confundiu Epic
Plane Evolution com outro clone de avião da Voodoo (existem vários
títulos parecidos no catálogo deles). Não usaria esse dado sem confirmar.

## 6. O que evitar (já confirmado por reviews negativas)

- **Sistema de "Plane Tickets"** (bilhetes de voo): cada bilhete = 1 voo de
  10-15 segundos; regenera 1 a cada 20 minutos; pago com dinheiro real pra
  pular a espera. Reviews descrevem isso como "fundamentalmente
  incompatível com um jogo baseado em tentativa e erro", tornando o jogo
  "quase injogável sem gastar $1,99-$9,99 regularmente" a partir da
  fase 2-3. **Já era nosso plano evitar isso, e a pesquisa confirma que é
  a reclamação #1 dos jogadores reais.**
- **Anúncios interrompendo o voo** - reclamação recorrente.
- **Bug de multiplicador zerado** - um glitch relatado zera o bônus de
  moedas de uma corrida inteira.
- **Física inconsistente** - vários reviews relatam distâncias diferentes
  com o mesmo input, o que mina a sensação de "eu controlo isso" que
  passamos 7+ rodadas calibrando pro nosso jogo. Vale o nosso rigor de
  medição continuar sendo um diferencial, não algo a abandonar.

## 7. Confirmações do que JÁ estamos fazendo certo

Vale registrar, porque nem tudo diverge:
- 3 categorias de upgrade (Avião/Renda/Estilingue) batem com a estrutura
  real (Plane/Income/Slingshot).
- Fase = avião próprio, com trilha que reseta ao trocar (pelo menos pra
  AVIÃO - ver divergência do Estilingue acima) - já é como
  `niveis_por_aviao` funciona.
- Moeda ganha por distância + bônus de conclusão - bate com "Income
  upgrades... stack with stage completion bonuses".
- Recompensa/punição leve ao "morrer" (nossa tela de resultado sem
  penalidade de progresso) - bate com a filosofia de game-over leve que a
  análise teórica original já tinha identificado.

---

## Fontes

- [Epic Plane Evolution - Google Play](https://play.google.com/store/apps/details?id=com.WalkTalk.FlightMaster&hl=en_US) - descrição oficial, 4.2★, 116K avaliações, 10M+ downloads
- [Epic Plane Evolution - App Store](https://apps.apple.com/us/app/epic-plane-evolution/id6504122823) - descrição oficial + histórico de versões (1.7.0 a 1.13.2)
- [Epic Plane Evolution (YouTube Playables) - wesl.ee](https://wesl.ee/Epic_Plane_Evolution_YouTube_Playables/) - guia detalhado das 7 fases da versão demo/browser
- [Epic Plane Evolution Beginner Guide Wiki - Upgrade Systems - clashiverse.com](https://clashiverse.com/epic-plane-evolution-beginner-guide-wiki-upgrade-systems/) - sistema de upgrade do app completo, "rolling over"
- [Epic Plane Evolution Block Plane Level Guide - clashiverse.com](https://clashiverse.com/epic-plane-evolution-block-plane-level-guide/) - fase tema Minecraft, controle por swipe
- [Epic Plane Evolution - Game Solver](https://game-solver.com/epic-plane-evolution/) - reviews e mecânica geral
- [taggame.io - Epic Plane Evolution](https://taggame.io/epic-plane-evolution) - descrição geral (contém o dado não confirmado de "50 aeronaves"/merge, tratado com ressalva acima)
- [GameFAQs - Tips, Cheats and Strategy Guide](https://gamefaqs.gamespot.com/news?id=157499)
- [iofreeonline.com - Info, Tip, Walkthrough, Glitch](https://www.iofreeonline.com/IOS/game/Epic-Plane-Evolution.html) - glitches conhecidos, sistema de bilhetes

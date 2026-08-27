# Voo Evolution — Briefing de ajustes v2 (estilingue direcional, 3 skills, visual)

**Status:**
- Item 1 (mira lateral afetando a trajetória de verdade) — feito, em
  `ui/estilingue.gd`, `jogo/aviao.gd` e `cenas/principal.gd`.
- Item 2 (elástico/puxão visível em 3D) — feito, em `jogo/estilingue_visual.gd`
  (novo) e conectado em `cenas/principal.gd`.
- Item 1 loja (3 trilhas Avião/Moedas/Estilingue) — feito e recalibrado em
  `sim/modelo.py`/`sim/progressao.py`, portado para `dados/atributos.gd` e
  `autoload/dados_jogo.gd`. Reproduz o mesmo teto e o mesmo ritmo (44 compras,
  ~59 km, 40-60 s) que o modelo de 6 atributos já tinha validado — ver
  `design_core_loop.md` §5-7, atualizado com os números novos.
- Item 3 (motor perdendo potência) — não mexido; recomendação do documento
  (testar a build atual antes de pedir a versão gradual) continua de pé.
- Item 4 (visual de cenário/avião/HUD) — não iniciado.
- `--teste-voo` não pôde ser rodado neste ambiente (sem Godot instalado) -
  rodar antes de considerar os itens acima fechados.

Este documento é o pedido de trabalho para a próxima iteração. Pressupõe que
você já leu `README.md` (como rodar, arquitetura) e `design_core_loop.md`
(modelo de voo, economia, balanceamento validado por simulação). Não repito o
que já está lá — só o que muda a partir daqui.

**Estado do projeto:** protótipo jogável em Godot 4.6/GDScript, com o core
loop (estilingue → voo → energia → moedas → loja → repete) validado contra um
simulador em Python (`sim/`). As três mudanças abaixo tocam justamente nas
partes que esse simulador calibrou, então cada seção diz explicitamente o que
precisa ser recalibrado e o que não precisa.

---

## Resumo do pedido

1. **Loja:** trocar os 6 atributos atuais por **3 trilhas de upgrade reais**:
   Estilingue, Avião (asa → outra asa → motor, progressivo) e Moedas.
2. **Estilingue:** além da barra de força (já existe), adicionar **mira
   lateral que realmente altera a trajetória** — não é só efeito visual.
3. **Voo:** confirmar/ajustar a sensação de motor perdendo potência aos
   poucos, com o mergulho como forma de recuperar velocidade.
4. **Visual:** cenário, avião e HUD no estilo das referências anexadas
   (low-poly estilizado, cores saturadas).

---

## 1. Loja: de 6 atributos para 3 trilhas

### Estado atual

`dados/atributos.gd` define 6 atributos independentes, cada um com sua
própria curva de custo/efeito, exibidos como lista única em `ui/loja.gd`:

| Atributo | Efeito | Níveis |
|---|---|---|
| Motor | velocidade de cruzeiro | 15 |
| Aerodinâmica | velocidade de cruzeiro | 12 |
| Tanque | duração do voo | 8 |
| Ímã | raio de coleta + moedas | 6 |
| Impulso | força do boost | 5 |
| Estilingue | força do lançamento | 4 |

`autoload/dados_jogo.gd` deriva tudo do jogo a partir desses 6 IDs
(`v_cruzeiro()` lê Motor+Aerodinâmica, `energia_maxima()` lê Tanque, etc.), e
o **nível visual do avião** (1 a 20, consumido por `jogo/fabrica_modelos.gd`)
é a soma dos 6 níveis normalizada.

Essa granularidade não é estética — foi calibrada em `sim/progressao.py` para
dar **44 compras totais a ~6,5% de ganho cada** (ver `design_core_loop.md`
§5.1). Menos compras com passos maiores é o "conteúdo acaba rápido"; mais
compras com passos menores é o "upgrade invisível". Os dois lados estão
documentados na tabela de riscos, §10 do design doc.

### Pedido

Três trilhas visíveis no menu:

- **Estilingue** — força do lançamento (mantém como está hoje).
- **Avião** — fusão de Motor + Aerodinâmica + Tanque + Impulso num único
  medidor. Cada nível sobe velocidade/duração/impulso *juntos*, e o modelo 3D
  ganha uma parte nova (asa → outra asa → motor) a cada faixa de progresso.
- **Moedas** — o atual Ímã, isolado como trilha própria.

### O que isso muda no código

- **`dados/atributos.gd`** — reescrever o catálogo para 3 entradas. A trilha
  "Avião" passa a ter um único par custo/efeito por nível (não é a soma
  separada de 4 curvas antigas — isso teria que virar uma única curva nova,
  balanceada do zero).
- **`autoload/dados_jogo.gd`** — `v_cruzeiro()`, `energia_maxima()` e
  `bonus_impulso()` hoje leem 3 IDs diferentes; passam a ler 1 (`aviao`).
  `nivel_visual()` recalcula soma mínima/máxima para 3 trilhas em vez de 6.
- **`jogo/fabrica_modelos.gd`** — os limiares que já existem (`t > 0.15`
  estabilizador, `t > 0.30` cabine, `t > 0.45`/`t > 0.80` motores, `t > 0.60`
  trem de pouso) continuam funcionando sem mudança, porque `t` já é derivado
  do nível visual — só a fórmula que produz o nível visual muda. Isso é
  conveniente: a progressão "asa, outra asa, motor" que vocês pediram **já
  existe** nesse arquivo, só precisa ser realimentada pela nova trilha.
- **`sim/modelo.py` e `sim/progressao.py`** — precisam de uma calibração
  nova do zero. Não dá para simplesmente somar os efeitos das 4 curvas
  antigas em 1: isso produziria uma curva de custo com degraus enormes (cada
  atributo tinha *seu próprio* ritmo de custo). Recomendo manter algo entre
  12 e 15 níveis por trilha (≈ 36 a 45 compras no total, perto do número já
  validado) em vez de reduzir para poucos níveis grandes — o risco de "ganho
  por compra acima de 12%" já está documentado como falha no design doc.

### Pergunta em aberto para alinhar com o dev

A trilha "Avião" deve ter **um multiplicador combinado por nível** (mais
simples de exibir e balancear, recomendado) ou manter sub-efeitos internos
diferentes por nível (ex.: nível 3 sobe mais aerodinâmica que motor) para dar
nuance a quem olhar o código? Recomendo a primeira opção — é o que "3 skills"
implica visualmente, e simplifica o simulador.

---

## 2. Estilingue: mira lateral que afeta a trajetória de verdade

### Estado atual

`ui/estilingue.gd` é só um medidor de força (0→100%→0, solta no verde). Não
existe nenhum input lateral nessa fase — e o `README.md` já lista como
pendência: *"Sequência visual do estilingue no mundo 3D (o medidor existe; o
elástico não)"*. Ou seja, hoje não há puxar-para-trás visível em 3D nem mira
esquerda/direita — só a barra 2D de UI.

Existe sim um controle lateral em `jogo/aviao.gd` (`_arraste`, `_lateral_alvo`,
`Config.CORREDOR_LARGURA` = 22 m), mas ele só age **depois** do avião lançado,
arrastando o dedo em voo — não durante a carga do estilingue.

### Pedido

Durante a carga (segurar/puxar para trás), o jogador também arrasta
esquerda/direita para mirar, e essa mira **entra de verdade na física do
lançamento** — não é só o elástico esticando na tela.

### Ressalva importante para o dev sênior

`design_core_loop.md` §4.2 mediu que a *força* do lançamento vale entre
0,7% e 3,5% da distância final, porque `v_eq` funciona como atrator e "come"
qualquer vantagem inicial de velocidade em poucos segundos — por isso o
documento recomenda **não** apostar em aumentar a força inicial como fator de
habilidade. A mira lateral é um tipo de efeito diferente (posição/rota, não
velocidade), então **não contradiz** essa conclusão — mas para valer a pena
ela precisa de uma consequência clara, ou vira um gesto sem significado.

Duas formas de implementar, em ordem de recomendação:

1. **(Recomendado) A mira define a posição lateral inicial do avião** dentro
   do corredor (`Config.CORREDOR_LARGURA`, hoje ±22 m). Reaproveita
   exatamente o sistema que já existe para o controle lateral em voo — é só
   inicializar `_lateral_alvo` com o valor travado no estilingue em vez de
   0. Consequência legível: uma mira boa alinha o avião com o primeiro
   padrão de orbes; uma mira ruim nasce deslocado da linha. Risco de
   implementação baixo, não exige tocar no simulador de distância (é
   ortogonal ao `t_voo`/`v_eq`).
2. Mira define um ângulo de guinada inicial que decai para frente ao longo de
   alguns segundos, criando uma curva em "S" logo após o lançamento. Mais
   vistoso, mas arriscado: a geração de mundo (`jogo/gerador_mundo.gd`)
   assume um corredor reto, e teria que ser testado contra os padrões de
   orbe para não deixar o início de toda corrida injogável.

Enquanto isso, faz sentido também fechar a pendência já anotada no README: o
elástico/puxão visível em 3D (hoje só existe o medidor 2D). É a mesma feature
pedida pelo usuário, e o gancho de UI (`ui/estilingue.gd`, sinal `lancado`) já
existe.

---

## 3. Motor perdendo potência aos poucos + mergulho

### O que já existe (e já bate com o pedido)

Isso, na prática, **já está implementado**:

- **Consumo de energia:** `Config.CONSUMO` (2,0 un/s) drena o tanque
  constantemente em `Aviao._atualizar_energia()`. Enquanto há energia, o
  empuxo (`a_motor`) é constante e o arrasto puxa a velocidade para o
  equilíbrio `v_eq`. Quando a energia chega a zero, o empuxo cai para zero e
  o avião vira planador (só arrasto e gravidade agem) — ver
  `Aviao._integrar()`.
- **Mergulhar ganha velocidade:** apontar o nariz para baixo
  (`_angulo_alvo` negativo) soma `-G_EFETIVO·sin(ângulo)` à aceleração, que é
  positivo quando o ângulo é negativo. Está calibrado propositalmente
  (`Config.G_EFETIVO = 25`, não a gravidade real) para que um mergulho de 10°
  dê -4,3 m/s² — "mergulhar numa encosta passa a ser uma decisão", como diz o
  comentário do arquivo.

### O ponto a confirmar com o dev antes de ele mexer

A frase "perdendo potência aos poucos" pode significar duas coisas
diferentes, e o modelo atual só implementa uma delas:

| Interpretação | Estado atual | Custo de mudar |
|---|---|---|
| **A.** Empuxo constante enquanto há tanque; acaba de vez quando a energia zera (modelo hoje) | ✅ já existe | — |
| **B.** Empuxo cai gradualmente conforme o tanque esvazia (motor "engasgando") | ❌ não existe | Alto — quebra a fórmula fechada `t_voo = E_max/(c − R·f·e_orbe)` do design doc §2.2, e exige recalibrar o simulador inteiro |

**Recomendação:** joguem a build atual antes de pedir a versão B. A queda de
velocidade por arrasto já dá uma sensação de "perdendo força" mesmo com
empuxo constante, e a versão B tem custo de balanceamento desproporcional ao
ganho de sensação — mas só quem jogou pode confirmar se falta alguma coisa.

---

## 4. Visual: cenário, avião e HUD

### Estado atual

Tudo é geometria procedural feita de caixas, deliberadamente (ver comentário
em `jogo/fabrica_modelos.gd`: *"MIGRAÇÃO PARA PRODUÇÃO: trocar o corpo de
`criar()` por um carregamento de .glb... Nenhum outro arquivo do projeto
precisa mudar"* — o isolamento para essa troca já foi construído de
propósito).

- **Avião:** um `BoxMesh` único reaproveitado e escalado para cada parte
  (fuselagem, nariz, asas, pontas, cauda, cabine, motores, trem de pouso —
  tudo cubos). Material sem textura, `roughness 0.85`, sem shading toon.
- **Cenário:** `jogo/terreno.gd` é só uma função de altura (soma de senos) e
  uma cor sólida por bioma, interpolada na transição. Sem árvores, pedras,
  água ou vegetação — o `README.md` já lista isso como pendência: *"Prédios
  e objetos de cenário por bioma — hoje só relevo e decoração genérica"*.
- **HUD:** `ui/hud.gd` já tem os elementos certos (velocímetro, distância,
  barra de progresso, energia, botão de impulso) mas com estilo de protótipo
  — a barra de energia é um `ProgressBar` padrão do Godot, sem o visual de
  barra vertical com ícone de avião das referências.

### Alvo (baseado nas imagens anexadas)

- **Terreno:** low-poly arredondado — copas de árvore em blob, pedras
  arredondadas, grama com variação de cor, água visível com margem definida
  e respingo/espuma no impacto (as imagens mostram justamente uma queda na
  água, com splash).
- **Avião:** fuselagem e hélice arredondadas, madeira aparente (a cor já
  configurada em `jogo/aviao.gd::_veiculo_ficticio()` — `Color(0.86, 0.55,
  0.28)` — já é um tom de madeira; falta a forma acompanhar).
- **Iluminação:** tom quente, saturado, com leitura de "toon" (rim light ou
  rampa de 2 tons), não o PBR neutro atual.
- **HUD:** velocímetro circular com ponteiro e marcações (confirmar se
  `ui/velocimetro.gd` já é desenhado assim — se não, restilizar); barra
  vertical de energia/combustível na lateral com um ícone de avião marcando a
  posição atual (hoje é uma barra genérica); contador de distância central
  grande (já existe, só restilizar); barra superior com pausa/mudo/config.

### Para o dev

Isso é essencialmente troca de assets + shader, não lógica nova:

1. Modelar avião e cenário em baixo-poli (glb) e plugar via
   `FabricaModelos.criar()` — a assinatura já está pronta para receber isso
   sem tocar em mais nenhum arquivo.
2. Popular `jogo/gerador_mundo.gd`/`jogo/pedaco_cenario.gd` com objetos de
   decoração por bioma (árvores, pedras, água) — hoje só existe relevo.
3. Shader toon simples sobre os materiais atuais (ou substituir
   `StandardMaterial3D` por um `ShaderMaterial` compartilhado).
4. Restilizar os controles de `ui/hud.gd` e `ui/velocimetro.gd` — troca de
   estilo visual, sem mudar a lógica de eventos que já existe.

---

## Ordem de implementação sugerida

| Ordem | Item | Por quê primeiro/depois |
|---|---|---|
| 1 | Mira lateral no estilingue (opção 1, posição inicial) | Menor risco, reaproveita sistema existente, testável isolado |
| 2 | Elástico/puxão visível em 3D | Mesmo pacote de trabalho do item 1, mesmo arquivo de UI |
| 3 | Loja: 3 trilhas + rebalanceamento no simulador | Bloqueia o visual do avião (nível visual depende da nova fórmula) |
| 4 | Visual do avião e cenário | Depende do item 3 estar estável (nível visual não pode mudar de fórmula depois de a arte ser feita) |
| 5 | Restilo de HUD | Independente do resto, pode entrar em paralelo a qualquer momento |
| — | Motor "engasgando" (interpretação B da seção 3) | Só entra se, depois de jogar a build atual, ainda parecer necessário |

---

## Perguntas em aberto para o dev sênior confirmar com a gente

1. Trilha "Avião": multiplicador único por nível, ou sub-efeitos internos
   diferentes por nível? (Seção 1)
2. Mira lateral: posição inicial no corredor (recomendado) ou ângulo de
   guinada com decaimento? (Seção 2)
3. Motor perdendo potência: o modelo atual (corte abrupto ao esvaziar o
   tanque) já é suficiente, ou querem queda gradual de verdade? Pedimos para
   jogar a build atual antes de decidir, porque a opção B tem custo alto de
   rebalanceamento. (Seção 3)

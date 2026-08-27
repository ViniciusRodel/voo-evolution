# Voo Evolution — Briefing de ajustes v3 (avião por fase, mapa, dificuldade, economia)

Continuação de `briefing_ajustes_v2.md` (mira lateral, elástico 3D e loja de 3
trilhas — já implementados e testados em jogo, ver status naquele documento).
Este pedido é maior: muda o objeto central da progressão de "um avião que vai
ficando mais forte" para "uma sequência de aviões diferentes, um por fase,
com um mapa para navegar entre eles."

---

## Achado que muda o escopo deste pedido

Antes de desenhar isso do zero: o projeto **já tem um catálogo de múltiplos
aviões construído e funcionando**, sobrado do protótipo anterior ao core loop
atual (ver `README.md`: *"Esta versão substituiu o núcleo de gameplay do
protótipo anterior... pelo modelo especificado em design_core_loop.md"*). Ele
está desconectado da cena principal hoje (não aparece em `cenas/principal.gd`),
mas é exatamente a peça que este pedido precisa:

| Arquivo | O que já faz | Reaproveitável direto |
|---|---|---|
| `dados/veiculo.gd` | Resource de um avião: nome, cores, `velocidade_cruzeiro`, `velocidade_maxima`, requisito de desbloqueio, `total_niveis` (1-20, consumido pela `FabricaModelos`) | Sim, sem mudança |
| `dados/catalogo.gd` | Lista estática de 6 aviões — Avião de Papel, Plano de Bloco, Planador, Biplano, Turboélice, Caça Supersônico — agrupados em 2 "universos" | A lista de nomes/exemplos, sim. A estrutura de desbloqueio, não (ver §2) |
| `dados/universo.gd` | Agrupamento temático (cor de céu/terreno por universo) | Sim, útil para dar identidade visual a blocos de fases |
| `ui/selecao_veiculos.gd` | Tela de seleção com navegação por universo, lista de cartões, botão "jogar com X" | A base de layout, sim. A lógica de navegação por universo vira navegação por fase (ver §5) |
| `ui/cartao_veiculo.gd` | Cartão com **preview 3D real do avião** (SubViewport de 1 frame só, sem custo de FPS), nome, cadeado, requisito, nível | Praticamente pronto — é a peça mais cara de construir do zero e já existe |

`jogo/aviao.gd::_veiculo_ficticio()` já comenta isso: *"A FabricaModelos foi
escrita para o design anterior e recebe um Veiculo... montamos o Resource que
ela espera a partir dos atributos atuais"* — ou seja, hoje o jogo FINGE que
existe um `Veiculo` para reaproveitar a `FabricaModelos`. Com este pedido, o
`Veiculo` volta a ser real.

**O que precisa mudar nessas peças** (não é copiar e colar):
1. Desbloqueio hoje é por `velocidade_necessaria` (recorde de km/h). Passa a
   ser por **fase completada** — mais simples, já existe `DadosJogo.fase`.
2. Cada avião precisa da sua **própria trilha de upgrade** (Avião/Moedas/
   Estilingue do `briefing_ajustes_v2.md`), não só do nível visual 1-20. Isso
   é estado novo (ver §6).
3. As constantes de física por avião (`velocidade_cruzeiro`/`velocidade_maxima`
   do catálogo antigo, em km/h "de mentirinha") precisam virar `a_motor`/
   `k_arrasto` reais no sistema de unidades atual (m/s, ver `config_jogo.gd`).

---

## 1. Treze aviões, um por fase, cada um mais rápido que o anterior

**Decisão confirmada:** um avião novo a cada fase (não a cada bloco de fases).
Com 13 fases hoje, são até 13 aviões distintos — o exemplo dado (papel →
brinquedo → hidroavião → ...) vira literal, fase a fase.

### Consequência no `dados/catalogo.gd`

A lista de 6 precisa crescer para 13 entradas, cada uma com:
- `nome`, cores, `escala_modelo` (a `FabricaModelos` já monta qualquer coisa
  a partir de blocos, então isso é iteração rápida de valores, não arte nova
  — a arte de verdade entra no item 4 do `briefing_ajustes_v2.md`, quando os
  blocos virarem modelos `.glb`)
- `velocidade_cruzeiro`/`velocidade_maxima` **crescente a cada fase** — este é
  o número que precisa de simulação, não estimativa: a curva de 13 degraus de
  velocidade tem que produzir uma progressão de HUD (km/h exibido) que sinta
  crescimento real sem repetir o mesmo salto do sistema de upgrades contínuo
  que o `briefing_ajustes_v2.md` já calibrou. Recomendo tratar isso como uma
  curva separada: velocidade BASE do avião (fixa, define a fase) × multipli-
  cador do Avião/Moedas/Estilingue **daquele avião especificamente** (o
  upgrade comprado dentro da fase, que reseta ao trocar de avião — ver §6).

### Consequência no motor de física

Hoje `A_MOTOR_BASE`/`K_ARRASTO` em `config_jogo.gd` são globais, um só valor
pra todo o jogo, e a trilha "Avião" multiplica em cima disso (`autoload/
dados_jogo.gd::v_cruzeiro()`). Com 13 aviões, cada um precisa da sua própria
base — ou seja, `v_cruzeiro()` passa a ler a base do **avião atualmente
selecionado** (`Catalogo`/`Veiculo`), não mais de uma constante global fixa.
Isso é uma mudança estrutural em `autoload/dados_jogo.gd` e em
`sim/modelo.py`, não um ajuste de número.

---

## 2. Fases menores (meta de distância reduzida)

**Por que isso importa, em uma frase:** fase mais curta → jogador termina mais
rápido → avião evolui mais rápido → sensação de progresso maior. É a mesma
lógica por trás do `design_core_loop.md` §5.1 (por que os upgrades têm poucos
níveis com degraus grandes em vez de muitos níveis pequenos) aplicada agora à
escala da fase inteira, não só da compra individual: ciclos curtos e visíveis
batem mais forte que ciclos longos e graduais, mesmo quando a soma é a mesma
progressão. O trade-off, para o dev ter em mente: encurtar demais esvazia o
"conteúdo acaba rápido demais" já mapeado na tabela de riscos do design doc
(§10) — o alvo é curto o bastante pra sensação de progresso, não curto a
ponto de a fase virar um piscar de olhos sem tempo de o jogador aprender o
avião novo.

**Por que hoje parecem grandes:** a meta atual (`Config.META_INICIAL=3900`,
`RAZAO_META=1.28`, ver `design_core_loop.md` §7) foi calibrada para uma
progressão **contínua** de 44 compras num avião só, levando ~70 corridas para
zerar o conteúdo. Com um avião novo por fase e a evolução resetando a cada
troca (§6), a lógica muda: cada fase agora é uma "sessão curta" com o avião
daquela fase, não um trecho de uma escalada longa.

**Recomendação:** a meta de cada fase deve ser alcançável em poucas corridas
(o suficiente para o jogador sentir o avião novo, comprar 1-2 upgrades dele, e
passar para o próximo) — não os ~5-7 corridas por fase de hoje. Isso não dá
para cravar sem simular: depende de quantos níveis a trilha Avião/Moedas/
Estilingue vai ter **dentro de cada fase** (ver §6 — provavelmente bem menos
que os 37/6/4 atuais, já que agora são 13 progressões curtas em vez de uma
longa). Recomendo ao dev rodar uma calibração nova em `sim/progressao.py`
assim que o número de níveis por avião for decidido, do mesmo jeito que foi
feito para a fusão em 3 trilhas.

---

## 3. Moedas só por distância percorrida

### Estado atual

`autoload/dados_jogo.gd::registrar_corrida()`:
```
ganho = distancia * Config.MOEDAS_POR_METRO + orbes * Config.MOEDAS_POR_ORBE
```
Moedas vêm de dois lugares: metro percorrido (0,05/m) e orbe coletado (5,0
cada). O pedido é remover o segundo termo.

### Mudança

Zerar `MOEDAS_POR_ORBE` (ou remover o termo da fórmula). Os orbes **continuam
existindo e continuam valendo energia** (`ENERGIA_POR_ORBE`) — eles seguem
sendo o motivo de seguir a linha de coleta e de durar mais no ar, só param de
dar moeda direta.

### Isso quebra o propósito da trilha "Moedas"

A trilha Moedas (`dados/atributos.gd`, ex-Ímã) hoje faz duas coisas:
`raio_coleta` (pega orbe de mais longe) e `bonus_moedas` (+8%/nível sobre o
total ganho). Se moeda só vem de distância, o `raio_coleta` continua tendo
sentido (mais energia, voos mais longos, mais distância) mas o `bonus_moedas`
precisa ser reancorado explicitamente em **moedas por metro**, não em orbe.
Não é preciso mudar o código de `bonus_moedas()` — ele já multiplica o ganho
total, que agora é só distância — só o texto da loja (`"efeito"` em
`dados/atributos.gd`) precisa parar de dizer "moedas e orbes" e passar a dizer
"moedas por metro".

### Recompensa maior por completar a fase

**Pedido separado, mas relacionado:** além de reancorar o Moedas, o valor em
si deve subir. Recomendo não só aumentar `MOEDAS_POR_METRO`, mas somar um
**bônus fixo por completar a fase** (pago uma vez, ao bater a meta, em cima do
que já foi ganho por metro) — hoje só existe o `BONUS_VOO_LIMPO` (+15% por não
tocar o solo). Um bônus de conclusão de fase separa duas recompensas que hoje
estão misturadas (terminar a corrida vs. bater a meta), e é o gancho natural
para a "recompensa maior" pedida.

---

## 4. Mais dificuldade — queda e velocidade maiores, com seletor pro jogador

### Estado atual

`autoload/config_jogo.gd`: `G_EFETIVO = 25.0` (gravidade amplificada — o
comentário já explica que é deliberadamente mais forte que a real para o
mergulho importar) e `K_ARRASTO = 0.0012` (define o teto de velocidade via
`v_eq = sqrt(a_motor/k_arrasto)`). Hoje são constantes fixas, um valor só para
todo o jogo.

### Pedido

(a) a sensação básica do jogo fica mais dura — cair custa mais, correr mais
rápido é mais fácil de atingir; (b) um seletor Fácil/Normal/Difícil visível
pro jogador, que ajusta isso.

### Desenho recomendado

Um dicionário de perfis, análogo ao `Atributos.DEFINICOES`:

```gdscript
const DIFICULDADES := {
    "facil":   {"queda_mult": 0.75, "velocidade_mult": 0.90},
    "normal":  {"queda_mult": 1.15, "velocidade_mult": 1.10},  # nova base, mais dura que a atual
    "dificil": {"queda_mult": 1.55, "velocidade_mult": 1.25},
}
```

`jogo/aviao.gd::_integrar()` passa a ler `Config.G_EFETIVO * queda_mult` e
`Config.K_ARRASTO` ajustado por `velocidade_mult` (via `a_motor`, não direto
no arrasto, para não alterar o `v_eq` de forma que quebre a curva de fases)
em vez das constantes cruas. **Importante:** "normal" já deve ser mais difícil
que o jogo de hoje — o pedido não é só que "difícil" seja mais difícil, é que
a régua toda suba. Valores acima são ponto de partida, não calibrados; isso
entra no `sim/modelo.py` como mais um eixo a simular antes de fixar.

### Onde mora a escolha

Precisa de uma tela nova (ou um controle na tela de mapa do §5) — não existe
hoje nenhum menu de configurações. `DadosJogo` guarda a escolha (persistida no
save) e todo lugar que hoje lê `Config.G_EFETIVO`/`Config.K_ARRASTO` direto
passa a ler through `DadosJogo.dificuldade_atual()`.

---

## 5. O mapa — reaproveitando e redesenhando `selecao_veiculos.gd`

Isto é o pedido de "melhore o mapa considerando UX/design sênior". Na leitura
mais provável dado o resto do pedido (aviões que se desbloqueiam por fase, e
poder voltar a fases antigas "só para se divertir"), o que falta não é o
terreno de voo — é uma **tela de navegação entre fases/aviões**, que hoje não
existe (o jogo só tem loja → lançamento → voo → resultado → loja, com a fase
avançando sozinha). Se a intenção era o terreno/relevo em si, isso já está
coberto pelo item 4 do `briefing_ajustes_v2.md` (visual de cenário) — vale
confirmar com quem pediu qual dos dois, ou os dois.

### Proposta (adaptando `ui/selecao_veiculos.gd` + `ui/cartao_veiculo.gd`)

Trocar a navegação por "universo" (abas Anterior/Próximo) por um **caminho
linear de 13 estágios**, um por fase/avião, no espírito de mapa de mundo de
jogo casual (Angry Birds, Candy Crush) — que também é o que as imagens de
referência do `briefing_ajustes_v2.md` evocam. Princípios de design a seguir:

- **Um caminho só, sem ramificação.** O jogador nunca precisa decidir "que
  caminho seguir" — só "até onde eu já cheguei". Ambiguidade de navegação é
  o erro mais comum nesse tipo de tela.
- **"Você está aqui" é sempre óbvio.** Marcador visual diferente (maior, com
  animação sutil) no estágio atual — o `cartao_veiculo.gd` atual já marca
  selecionado com borda branca; dá pra evoluir isso pro nó do mapa.
- **Bloqueado mostra o que falta, nunca só ignora o toque.** O
  `cartao_veiculo.gd` já faz isso certo (silhueta preta + requisito) — mesma
  lógica, trocando "atinja X km/h" por "complete a fase anterior".
- **Fases já completadas continuam claramente acessíveis**, visualmente
  diferentes de "bloqueada" e de "atual" (ex.: com uma estrela/check, cor mais
  viva) — é o que sustenta o "voltar só para se divertir" sem o jogador achar
  que está reiniciando ou perdendo progresso.
- **O preview 3D real por estágio já existe** (`CartaoVeiculo._montar_preview`,
  SubViewport de frame único) — é a parte mais cara de uma tela dessas e já
  está pronta, só precisa de um layout de trilha em vez de lista vertical.
- **Aproveitar os biomas já existentes para dar identidade a cada estágio do
  mapa.** `jogo/terreno.gd::BIOMAS` já tem 11 biomas nomeados (Duna, Deserto,
  Vilarejo, Cânion...) — perto o suficiente das 13 fases para servir de pano
  de fundo/cor de cada nó do mapa sem inventar identidade visual nova.

---

## 6. Progressão zera por avião, mas fases antigas ficam jogáveis com recompensa normal

**Confirmado:** trocar de avião reseta Avião/Moedas/Estilingue para nível 1
(o avião novo começa do zero); fases já completadas continuam voáveis a
qualquer momento, e rendem moedas normalmente (sem penalidade) — decisão
consciente de não punir replay, com o trade-off de que farmar a fase 1 vira
uma opção válida em vez de proibida. Se isso virar problema on farming depois
de jogado, é ajuste de valor (baixar a meta_atual/recompensa de fases muito
antigas), não de regra.

### Mudança de estado necessária

`autoload/dados_jogo.gd` precisa parar de guardar **um** dicionário de níveis
e passar a guardar **um por avião**:

```gdscript
var niveis_por_aviao: Dictionary = {}   # StringName (id do aviao) -> {StringName -> int}
var fase_maxima_alcancada: int = 0      # define o que esta desbloqueado
var fase_selecionada: int = 0           # fase que o jogador esta jogando agora (pode ser < maxima)
```

`nivel()`/`comprar()`/`custo_proximo()` passam a operar sobre
`niveis_por_aviao[id_do_aviao_atual]`, criando a entrada com tudo em 1 na
primeira vez que aquele avião é selecionado. Como no `briefing_ajustes_v2.md`
§1, isso é troca de estrutura de dados, não de fórmula — os métodos
`v_cruzeiro()`/`energia_maxima()`/etc. continuam iguais, só trocam de onde
leem o nível.

**Bump de `VERSAO_SAVE`** (hoje em 3, ver `autoload/dados_jogo.gd`) —
consistente com como as duas mudanças de save anteriores foram tratadas:
descartar limpo em vez de tentar migrar uma estrutura sem equivalente.

---

## 7. Marcar no mapa o recorde de distância da fase

### O que existe hoje

`DadosJogo.recorde_distancia` é **um float global só**, a melhor distância de
toda a vida do save, comparado e atualizado em `registrar_corrida()` e exibido
como texto no resumo da loja. Não existe nenhuma marcação visual dele em lugar
nenhum — só o número.

### O que muda

Com uma fase por avião (§1) e metas pequenas (§2), "recorde global" deixa de
fazer sentido — o que importa agora é o recorde **daquela fase específica**
(a melhor distância já alcançada com aquele avião, naquela meta). Isso vira:

```gdscript
var recordes_por_fase: Dictionary = {}   # int (indice da fase) -> float (melhor distancia)
```

atualizado no mesmo lugar que hoje atualiza `recorde_distancia`, só que
indexado pela fase da corrida.

### "Delinear no mapa a distância máxima" — duas leituras, recomendo as duas

1. **Dentro do voo (a leitura mais literal de "percurso"):** plantar um
   marcador visível no terreno — uma bandeira/poste, por exemplo — na posição
   de mundo correspondente ao recorde daquela fase. Como `distancia` cresce e
   `position.z` decresce (`position.z -= avanco` em `jogo/aviao.gd::_integrar`),
   o marcador fica em `z = -recordes_por_fase[fase]`, gerado pelo
   `jogo/gerador_mundo.gd` do mesmo jeito que hoje gera orbes e térmicas (objeto
   posicionado em função da distância, dentro da janela de streaming). O
   jogador vê o próprio recorde se aproximando durante a corrida — é o gancho
   de tensão mais barato de construir aqui, porque reaproveita o streaming que
   já existe.
2. **Na tela de mapa (§5), por estágio:** um preenchimento parcial no nó da
   fase em andamento, proporcional a `recordes_por_fase[fase] / meta_da_fase`
   — mostra de relance "cheguei a 70% desta fase" sem precisar abrir a corrida.
   Mais barato que o item 1 (é só desenho 2D), e complementa em vez de
   substituir.

Recomendo os dois: o marcador em voo dá a tensão momento-a-momento, o
indicador no mapa dá a visão geral. Se só um puder entrar primeiro, o do mapa
é mais barato e já comunica a ideia.

**Cuidado de leitura visual:** o marcador de recorde não pode ser confundido
com o de meta/objetivo (que hoje também não existe visualmente no mundo 3D, só
na barra de progresso da HUD) — se os dois forem implementados, precisam ter
identidade visual clara e diferente (cor, formato).

---

## 8. Melhoria de física

Pedido aberto, sem sintoma específico anexado — diferente dos outros itens
deste documento, aqui não dá pra propor um número sem saber o que exatamente
incomodou no playtest. O que segue é o estado atual do modelo (todo em
`jogo/aviao.gd` e `autoload/config_jogo.gd`) para servir de referência do que
mexer, e uma lista dos lugares mais prováveis de "sensação ruim" nesse tipo de
jogo:

| Eixo | Constante hoje | Sintoma se estiver errado |
|---|---|---|
| Resposta do comando de arfagem | `SUAVIZACAO_ANGULO = 3.2` (1/s), `SENSIBILIDADE_ARRASTE = 0.22°/px` | Nervoso demais (ganho alto) ou lento/borrachudo (ganho baixo) |
| Resposta do comando lateral | `SUAVIZACAO_LATERAL = 9.0` (1/s) | "Gruda" na posição em vez de deslizar |
| Estol | `FRACAO_ESTOL = 0.42` — abaixo disso o nariz cai sozinho, mesmo puxando pra cima | Se não houver aviso visual antes de acontecer, o jogador lê como "física quebrada", não como regra |
| Mergulho/subida | `G_EFETIVO = 25` (ver §4 — já entra em discussão por causa da dificuldade) | Mergulho fraco demais = relevo irrelevante; forte demais = perde-se controle fácil |
| Colisão com o solo | Puramente analítica (`Terreno.altura()`), sem corpo físico, sem quique nem deslizamento | Impacto pode parecer abrupto/sem peso, mesmo sendo barato em performance |
| Câmera | `CameraSeguidora`: `suavizacao = 6.0`, FOV sobe de 68° a 82° no impulso | Atraso de câmera contribui pra sensação de física ruim mesmo com o modelo correto |

**Recomendação:** antes do dev mexer aqui, pedir para quem jogou (você, ou
quem testou) apontar especificamente o que incomodou — "vira rápido demais",
"o mergulho não muda nada", "bater no chão parece sem peso" são pedidos
acionáveis; "melhorar a física" sozinho não é. Ver pergunta em aberto no fim.

---

## 9. Persistência de progresso — requisito explícito, não detalhe

**Isto já existe e já funciona:** `autoload/dados_jogo.gd::salvar()/carregar()`
grava em `user://progresso.json` a cada compra (`comprar()`) e ao fim de cada
corrida (`registrar_corrida()`), e recarrega em `_ready()`. Validei isso na
sessão de teste anterior — o aviso *"Save de versao anterior descartado"* que
apareceu era o mecanismo de `VERSAO_SAVE` funcionando como projetado (descarta
save incompatível de forma limpa), não uma falha de persistência.

**O que muda com este pedido:** a lista de campos persistidos precisa crescer
junto com o estado novo — hoje `salvar()` só grava `moedas`, `fase`, `niveis`
(um dicionário só), `recorde_distancia` (global) e `total_corridas`. Com os
itens deste documento, o "contrato de save" passa a exigir:

- `niveis_por_aviao` (§6) — nível de Avião/Moedas/Estilingue **por avião**
- `fase_maxima_alcancada` (§6) — o que está desbloqueado no mapa
- `recordes_por_fase` (§7) — os recordes marcados no mapa
- `dificuldade_atual` (§4) — a escolha do jogador não pode resetar sozinha

**Regra pro dev:** qualquer campo novo adicionado ao `DadosJogo` como
progresso visível ao jogador entra em `salvar()`/`carregar()` no mesmo commit
que o introduz — não depois. É exatamente esse tipo de esquecimento que
produz o sintoma "abri de novo e perdi tudo" que este pedido quer evitar. O
bump de `VERSAO_SAVE` já previsto no §6 é esperado **durante esta transição**
(a estrutura antiga não tem equivalente na nova); depois de publicado, saves
passam a ser tratados como intocáveis — sem mais bumps casuais.

---

## Ordem de implementação sugerida

| Ordem | Item | Por quê |
|---|---|---|
| 1 | Estado por avião no `DadosJogo`, incluindo `recordes_por_fase` e `dificuldade_atual` (§6, §7, §4) + extensão de `salvar()`/`carregar()` (§9) | Todo o resto depende de "qual avião, qual fase" existir como conceito, e nasce já persistido |
| 2 | Catálogo de 13 aviões + física por avião (§1) | Depende de 1; bloqueia a calibração de fases |
| 3 | Metas de fase recalibradas (§2) e economia só-distância (§3) | Depende de 2 para saber a velocidade de cada fase |
| 4 | Mapa de navegação com indicador de recorde por estágio (§5, §7.2) | Precisa do catálogo (2) e do estado de fase máxima/recorde (1) prontos pra ter o que mostrar |
| 5 | Marcador de recorde em voo (§7.1) | Cosmético, entra depois do mapa por reaproveitar o mesmo dado |
| 6 | Seletor de dificuldade (§4) | Independente do resto, pode entrar em paralelo |
| 7 | Ajustes de física (§8) | Depende de feedback específico de playtest — ver pergunta 5 abaixo |

## Perguntas em aberto para o dev sênior alinhar

1. **Curva de velocidade dos 13 aviões** — precisa de simulação própria (como
   a da loja em `briefing_ajustes_v2.md` §1), não dá para estimar sem rodar.
2. **Quantos níveis a trilha Avião/Moedas/Estilingue tem dentro de cada
   fase** — decide o ritmo de "poucas corridas por fase" pedido em §2.
3. **"Melhore o mapa" é a tela de navegação (§5), o terreno de voo (já coberto
   no `briefing_ajustes_v2.md` item 4), ou os dois?** Confirmar antes de
   escrever o código, para não construir a coisa errada.
4. **Valores de `queda_mult`/`velocidade_mult` por dificuldade** — os do §4
   são ponto de partida, não calibrados; precisam de playtest.
5. **O que especificamente incomoda na física hoje?** (§8) — sem isso o dev
   vai estar ajustando às cegas. Precisa de 1-2 frases concretas: vira rápido
   demais/de menos, mergulho fraco, colisão sem peso, câmera atrasada, etc.
6. **O marcador de recorde em voo (§7.1) precisa ser visível também para quem
   nunca bateu recorde nessa fase (primeira tentativa)?** Se sim, ele nasce
   ausente até a primeira corrida completa — confirmar que não é regressão,
   é o comportamento esperado no dia 1.

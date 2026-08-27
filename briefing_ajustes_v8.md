# Voo Evolution — Roadmap v8: sistemas do Epic Plane Evolution

Documento guarda-chuva para a analise de 60 pontos do Epic Plane Evolution
que o usuario trouxe, decompondo-a em fases concretas de trabalho sobre o
projeto ATUAL (nao um recomeco do zero - ver decisao registrada abaixo em
"Por que estender, nao recomecar"). Cada fase (P1, P2, ...) e independente,
tem status proprio, e sera implementada e testada separadamente, no mesmo
ritmo dos briefings anteriores (spec -> implementacao -> `--teste-voo` ->
playtest -> proximo).

**Status geral: P1 e P2 implementados e testados. P3-P6 especificados,
aguardando implementacao.**

---

## Por que estender, nao recomecar

O projeto ja cobre a maior parte do que a analise descreve como nucleo do
genero (lancamento por estilingue -> voo -> coleta -> upgrade -> repetir),
com fisica calibrada em 7+ rodadas de ajuste (`briefing_ajustes_v2.md` a
`v7.md`, mais tres rodadas de tuning de dificuldade/economia direto no
codigo - ver `V8`/`V9`/`V10` em `dados/atributos.gd` e `autoload/config_jogo.gd`).
Reescrever do zero jogaria fora essa calibracao para reconstruir a mesma
arquitetura de base. O que a analise traz de genuinamente novo (peso/
sustentacao real por componente, cenario variado por bioma, clima, missoes,
estrelas) entra como sistemas adicionais.

## Achado que mudou o escopo deste documento

Ao investigar o codigo para aterrissar o roadmap em arquivos reais, apareceu
um achado grande: **o jogo ja tem um sistema COMPLETO de obstaculos de
esquiva construido** (`jogo/gerador_pista.gd`, `jogo/obstaculo.gd`,
`jogo/pedaco_cenario.gd`, `dados/universo.gd`) - pool de obstaculos,
geracao com abertura garantida, dificuldade escalando com a distancia,
"urbanizacao" a partir de 850 m, tres tipos de fileira (lateral/horizontal/
pilares). Ele **nunca chegou a ser instanciado por `cenas/principal.gd`** -
o gerador ativo hoje (`jogo/gerador_mundo.gd`) so cuida de chao e correntes
de ar, sem nenhum obstaculo real. Isso muda a prioridade do roadmap: o maior
gap da analise frente ao jogo atual (ausencia total de obstaculos - o item
11 da analise, "transformar um voo automatico em atividade de habilidade")
nao precisa ser construido do zero, precisa ser **reativado e reconciliado**
com o `Config`/`DadosJogo`/`Aviao` atuais (o codigo dormente referencia
constantes e formatos de velocidade de uma versao anterior do jogo). Por
isso isso vira P2, logo depois da correcao de escala que P1 já fazia.

---

## P1 — Cenario sente-se vivo dentro de UMA corrida (IMPLEMENTADO)

**Problema medido:** `jogo/terreno.gd` ja tinha 11 biomas com transicao de
cor suave e relevo que cresce com a distancia - mas os limiares (900 m a
70.000 m) foram calibrados pro `Config.METAS_FASE` ANTIGO (ate 98.524 m). A
recalibracao do v7 (motor virou bonus de lancamento, nao sustentacao)
encolheu as metas ~12x (fase 13 agora e ~15.069 m no maximo - ver correcao
abaixo). Na pratica, toda corrida ficava presa em DUNA/DESERTO, e o relevo
mal saia do patamar inicial (`Terreno.amplitude()` so alcancava ~17% do
maximo mesmo na fase 13). O comentario original do arquivo ja dizia a
intencao ("a fase 8 ja comeca no canion"), mas nenhum chamador jamais
implementou esse deslocamento.

**O que foi feito:**
- `jogo/terreno.gd`: `BIOMAS` reescalado pelo mesmo fator da recalibracao
  de metas; `DISTANCIA_AMPLITUDE_MAXIMA` 45000 -> 8000; nova funcao
  `offset_bioma(indice_fase)` (linear de 0 na fase 1 ate `OFFSET_BIOMA_MAXIMO`
  na fase 13) - so afeta COR (bioma/ceu), nunca `altura()`/`amplitude()`
  (relevo e colisao continuam funcao pura da distancia voada NESTA corrida,
  para nao mexer em fisica ja calibrada).
- `jogo/gerador_mundo.gd`/`jogo/pedaco_terreno.gd`: offset calculado uma vez
  por corrida e repassado a cada pedaco de terreno.
- `cenas/principal.gd`: cor do ceu (inicial e ao vivo) usa o offset da fase
  selecionada.

**Bug encontrado e corrigido durante a implementacao:** a primeira
recalibracao de `Config.METAS_FASE` (v7) mediu a capacidade maxima usando
`--nivel=10`, mas `dados/atributos.gd` (rodadas V8-V10, ja feitas antes
deste documento) tinha expandido o nivel maximo das 3 trilhas para **30**.
As metas ficaram calibradas contra um "maximo" que nao era o maximo de
verdade (folgadas demais). Corrigido remedindo com `--nivel=30
--dificuldade=dificil --meta-livre` (mesmo metodo e razao 1,18 que
`dados/atributos.gd` V8 ja usa) - `Config.METAS_FASE` atualizado, `VERSAO_SAVE`
subiu para 7. Confirmado por `--teste-voo`: nivel 1/medio fica em 18-21% da
meta em todas as fases testadas; nivel 30/dificil fica em ~85% (no limite,
como pedido no v7).

---

## P2 — Obstaculos reais (o maior gap da analise, ja ~90% construido) (IMPLEMENTADO)

**Objetivo:** reativar `GeradorPista`/`Obstaculo`/`PedacoCenario`/`Universo`
para que o jogador precise desviar de verdade, nao so administrar altitude
e mergulho.

**Trabalho necessario (o codigo dormente precede o v3-v7 e fica
desatualizado em alguns pontos):**
1. `Config` precisa de constantes que `gerador_pista.gd` ja referencia mas
   nao existem hoje: `ESPACAMENTO_MINIMO`, `TEMPO_MINIMO_ENTRE_FILEIRAS`,
   `POOL_OBSTACULOS`, `KMH_PARA_MS`, `CORREDOR_ALTURA_MIN`/`MAX`,
   `PEDACOS_ATIVOS`, `PEDACOS_ATRAS` (hoje `GeradorMundo` usa nomes
   diferentes: `PEDACOS_MIN`/`PEDACOS_MAX`/`SEGUNDOS_DE_CENARIO`).
2. `GeradorPista.iniciar(alvo, universo, veiculo)` calcula velocidade via
   `veiculo.velocidade_cruzeiro * Config.KMH_PARA_MS` - resquicio de uma
   epoca em que `velocidade_cruzeiro` era km/h. Hoje e m/s direto
   (`dados/veiculo.gd` documenta isso) e a velocidade de voo real vem de
   `DadosJogo.v_cruzeiro()` (que ja aplica a trilha AVIAO), nao do
   `Veiculo` base sozinho. Precisa adaptar a assinatura.
2. Decidir arquitetura: `GeradorMundo` (chao + decoracao + termicas) e
   `GeradorPista` (obstaculos) rodam em paralelo sobre o mesmo `_aviao`, ou
   fundem num gerador so? Recomendo paralelo no inicio (risco menor,
   nenhum dos dois muda), com fusao futura se performance pedir.
3. `Aviao._verificar_fim()` so conhece "meta"/"solo" hoje - precisa de um
   terceiro motivo ("obstaculo"), disparado por deteccao de overlap contra
   o grupo de obstaculos (Area3D, ver `jogo/obstaculo.gd` - ja diz que quem
   detecta e o aviao, nao o obstaculo).
4. `Config.CORREDOR_LARGURA` (22 m) e usado tanto pelo obstaculo quanto pelo
   controle lateral do aviao - conferir que a abertura garantida das
   fileiras nunca fica menor que o que o jogador consegue reagir na
   velocidade atual (a regra 2 do cabecalho de `gerador_pista.gd` ja cobre
   isso via espacamento em TEMPO, so precisa ser revalidada com as
   velocidades atuais, bem mais altas que quando foi escrita).
5. Recalibrar `Config.METAS_FASE` de novo depois (obstaculos reduzem a
   distancia media alcancavel, entao a folga de P1 pode ficar generosa
   demais uma vez que colidir vira uma causa real de corrida curta).

**Risco:** medio. Nao mexe na fisica de voo (`Aviao._integrar()`), so
adiciona uma nova causa de fim de corrida e objetos no caminho.

**O que foi feito (nao reaproveitou `PedacoCenario`/`GeradorPista` diretos -
motivo abaixo):**
- Novo `jogo/gerador_obstaculos.gd`, adaptando a logica de geracao de
  fileira de `gerador_pista.gd` (aberturas garantidas, 3 tipos de fileira,
  espacamento em tempo) para os sistemas atuais: velocidade vem de
  `DadosJogo.v_cruzeiro()` (nao mais `Veiculo.velocidade_cruzeiro * km/h`),
  altura de cada fileira e relativa a `Terreno.altura()` (o terreno ondula
  de verdade), rampa de dificuldade proporcional a meta da fase atual (nao
  um valor absoluto fixo). Roda em PARALELO ao `GeradorMundo` (chao +
  decoracao + termicas) - `PedacoCenario`/`Universo` NAO foram reaproveitados
  porque desenham seu proprio chao plano, que colidiria visualmente com o
  relevo real de `Terreno.altura()` que ja existe.
- `jogo/aviao.gd`: novo detector `Area3D` (so deteccao, sem resposta fisica)
  monitorando a camada 2 (`Obstaculo.collision_layer`); nova terceira causa
  de fim de corrida, `"obstaculo"` (`_ao_colidir_obstaculo`), que tambem
  marca `tocou_solo = true` (reutilizado como flag geral de "corrida suja",
  nao literal "tocou o solo").
- `cenas/principal.gd`/`ui/monitor_desempenho.gd`/`ui/resultado.gd`: ciclo
  de vida do novo gerador e label de resultado para o motivo novo.
- `testes/piloto_automatico.gd`: o piloto so sabia perseguir orbes (mortos
  desde o v3) - sem esquiva nenhuma ele voava sempre no centro do corredor e
  batia na maioria das fileiras LATERAL (que abrem num x aleatorio). Trocado
  por esquiva real: mira no centro da abertura da fileira LATERAL mais
  proxima (`GeradorObstaculos.fileira_lateral_mais_proxima()`). Esquiva de
  fileiras HORIZONTAL/PILARES ainda nao foi implementada no piloto (nao tem
  um "centro" lateral simples) - fica como limitacao conhecida.
- **Bug real encontrado e corrigido durante o teste:** reciclar um obstaculo
  (`Obstaculo.ativar()`/`desativar()`) mexia em `monitorable` por atribuicao
  direta; quando isso acontecia DENTRO do proprio callback de colisao
  (corrida terminou por obstaculo -> proxima corrida comeca -> gera fileira
  nova -> reaproveita um obstaculo do pool), o motor de fisica bloqueava com
  "Function blocked during in/out signal". Corrigido trocando por
  `set_deferred(&"monitorable", ...)`. So se manifestava com o piloto
  automatico (que reinicia a corrida na hora); no jogo real ha a tela de
  resultado no meio, entao nunca teria acontecido - mas o bug era real e foi
  corrigido na fonte.
- Confirmado por `--teste-voo` (varias fases/niveis/dificuldades): sem
  erros, sem esgotamento do pool (`Config.POOL_OBSTACULOS = 40`), colisao
  com obstaculo dispara corretamente (verificado forcando o piloto a nao
  esquivar).

**Ainda nao feito, proximo passo natural:** `Config.METAS_FASE` foi
calibrada em P1 SEM obstaculos no caminho; agora que eles existem, a
capacidade medida pode cair (o piloto ainda esquiva bem de fileiras
LATERAL, mas nao de HORIZONTAL/PILARES) - vale remedir e comparar com as
metas atuais antes de considerar a calibracao de distancia fechada.

---

## P3 — Engenharia emergente: peso/sustentacao/arrasto por componente

**Objetivo (analise §45-47):** substituir os multiplicadores flat da
trilha AVIAO por atributos fisicos reais por componente (peso, area de asa,
potencia), com sustentacao/arrasto calculados (`Lift = Cl*v^2*area`,
`Drag = Cd*v^2*area`) em vez de um numero unico "velocidade de cruzeiro".

**Por que fica por ultimo entre as mudancas de fisica:** e a unica fase
deste roadmap que mexe direto na formula ja calibrada em 7+ rodadas
(`Aviao._integrar()`, `DadosJogo.v_cruzeiro()`/`arrasto_mult_atual()`).
Precisa de recalibracao completa via `--teste-voo` para as 13 fases de
novo, igual ao que aconteceu no v7. Vale fazer DEPOIS de P1/P2 estarem
estaveis, para nao empilhar duas fontes de instabilidade ao mesmo tempo.

**Risco:** alto. Requer nova rodada de medicao ponta a ponta.

---

## P4 — Clima e vento

**Objetivo (analise §33-34):** vento como vetor lateral (por bioma/fase),
chuva reduzindo resposta de controle, neve aumentando arrasto. Aditivo
sobre `Aviao._integrar()` - soma uma forca a mais, no mesmo padrao que
`Config.TERMICA_ACELERACAO` ja usa para as correntes de ar.

**Risco:** baixo-medio. Reusa o padrao ja existente das termicas
(`jogo/gerador_mundo.gd::_atualizar_termica`), so generaliza pra vento
constante por bioma em vez de bolsões pontuais.

---

## P5 — Metagame: missoes e estrelas

**Objetivo (analise §38-39):** missoes diarias simples (percorrer X metros,
nao colidir, etc.) e avaliacao por estrelas na tela de resultado
(`ui/resultado.gd`). Nao toca fisica nem economia central - puramente
aditivo, novo autoload `MissaoManager` + UI nova.

**Risco:** baixo. Isolado do resto do jogo.

---

## P6 — Polish de feedback

Sons de lancamento/moeda/upgrade/colisao, popups de moeda coletada, texto
de bioma na tela (ja calculavel via `Terreno.nome_bioma()`, so falta
exibir). Itens 26-27 da analise. Sem dependencia dos anteriores, pode
intercalar a qualquer momento.

---

## Ordem de implementacao sugerida

| Ordem | Fase | Por que |
|---|---|---|
| 1 | P1 | Feito - base de distancia/bioma que as fases seguintes assumem correta |
| 2 | P2 | Maior gap da analise, e a maior parte ja existe no codigo |
| 3 | P4 | Aditivo, baixo risco, reusa padrao das termicas |
| 4 | P5 | Aditivo, isolado, nao depende de P2/P3 |
| 5 | P3 | Unica que mexe na fisica calibrada - por ultimo de proposito |
| - | P6 | Sem dependencia - encaixa a qualquer momento |

## Perguntas em aberto

1. **P2 - fundir ou paralelizar geradores?** Recomendo paralelo primeiro
   (menor risco), decisão final depende de como o desempenho se comporta
   com os dois rodando juntos.
2. **P3 - vale a pena?** E a fase mais arriscada e a que menos aparece nos
   pedidos explicitos do usuario ate agora (a analise trouxe a ideia, mas
   ninguem pediu peso/sustentacao real ainda). Pode ficar como "nice to
   have" adiado indefinidamente sem prejuizo pro resto do roadmap.
3. **Calibracao "no limite" (v7 pergunta 3, ainda sem resposta):** este
   documento manteve a convencao ja estabelecida em `dados/atributos.gd` V8
   (calibrar contra Dificil, piloto automatico, razao 1,18). Vale confirmar
   com o usuario se e isso mesmo que "no limite" deveria significar.

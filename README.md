# Voo Evolution

Jogo de lançamento e distância em 3D, feito em **Godot 4.7 / GDScript**.
Você lança um avião de um estilingue, guia o voo mergulhando para ganhar
velocidade, e usa as moedas ganhas por distância para evoluir o avião peça
por peça — asas, cauda, hélice — até o próximo lançamento ir mais longe.

Inspirado na fórmula de jogos como *Epic Plane Evolution* (Voodoo), mas
com um modelo de voo próprio: física balística de verdade (o avião sobe,
atinge o pico e cai — não há "piloto automático" motorizado carregando o
jogador), 13 fases com um avião distinto cada, e um loop de prestígio que
deixa o jogo recomeçar com bônus permanente depois da última fase.

---

## Como jogar

1. **Lance** — puxe o estilingue: a tensão define a força, o arraste
   lateral mira em que ponto do corredor o avião nasce.
2. **Pilote** — arraste vertical inclina o avião (mergulhar ganha
   velocidade real; subir freia). Segurar o dedo parado custa um pouco de
   velocidade — toques/ajustes curtos rendem mais que segurar.
3. **Chegue o mais longe possível** — a corrida acaba ao bater a meta da
   fase ou ao tocar o solo.
4. **Evolua** — moedas ganhas por distância (mais bônus por bater a meta e
   por terminar sem tocar o chão) compram upgrades na loja: cada asa, a
   cauda e a hélice são peças **separadas**, cada uma com efeito visual
   próprio no modelo do avião.
5. **Avance de fase** — cada uma das 13 fases é um avião diferente, do
   Avião de Papel até a Nave Espacial, com meta e dificuldade próprias.
   Ao completar a última fase, o jogo **prestigia**: volta para a fase 1
   com um multiplicador de moedas permanente, e você recomeça mais forte.

### Controles

| Ação | Como |
|---|---|
| Lançar | Puxar e soltar o estilingue na tela |
| Mirar o lançamento | Arrastar horizontal enquanto o estilingue carrega |
| Subir / mergulhar | Arrastar vertical durante o voo |
| Corrigir lateralmente | Arrastar horizontal durante o voo |
| Impulso | Botão na tela (usos limitados por corrida) |
| Monitor de desempenho | `F1` (ou toque com 3 dedos no celular) |
| Ajuste de moedas por dificuldade (debug) | `F2` |

---

## Instalação e como rodar

### Pré-requisito

- **[Godot Engine 4.7](https://godotengine.org/download)** ou mais recente
  (o projeto usa `config/features = "4.7"`; versões 4.6 podem funcionar mas
  não são testadas).

### Rodar o jogo

```bash
git clone https://github.com/<seu-usuario>/voo-evolution.git
cd voo-evolution
godot --path .              # abre e roda o jogo
godot --path . -e           # abre no editor do Godot
```

Ou, sem linha de comando: abra o **Godot Engine**, clique em **Importar**,
selecione a pasta do projeto (o arquivo `project.godot`) e depois em
**Rodar** (▶).

### Exportar um executável

Dentro do editor: `Projeto → Exportar`. O projeto já vem com
`export_presets.cfg` configurado; é preciso instalar os **templates de
exportação** da mesma versão do Godot (`Editor → Gerenciar templates de
exportação`) antes de exportar para Windows/Android/etc.

### Rodar os testes automatizados (headless, sem janela)

O balanceamento do jogo é validado por um piloto automático que joga
sozinho e verifica se a física/economia do jogo bate com o que foi
calibrado:

```bash
# Uma corrida no nível 1, dificuldade padrão
godot --headless --quit-after 20000 -- --teste-voo

# Mede a capacidade máxima de uma fase (todas as trilhas no nível mais alto,
# meta desativada para a corrida terminar caindo, não batendo a meta)
godot --headless --quit-after 20000 -- --teste-voo --nivel=40 --fase=13 --dificuldade=dificil --meta-livre --corridas=5

# Testa a evolução visual do modelo 3D do avião
godot --headless --quit-after 120 -- --teste-modelos
```

Flags aceitas por `--teste-voo`: `--corridas=N`, `--nivel=N` (força todas
as trilhas do avião atual nesse nível), `--fase=N` (1 a 13), `--dificuldade=facil|medio|dificil`,
`--meta-livre` (meta inatingível, a corrida sempre termina caindo).

---

## O que existe hoje

- **Física balística única** — um só modelo de voo do começo ao fim do
  jogo: gravidade real, arrasto, e um "empurrão" do jogador que inclina a
  trajetória sem reescrevê-la. O motor, quando totalmente evoluído, é um
  bônus no **lançamento** (mais força inicial), não uma forma de sustentar
  voo para sempre.
- **13 fases, 13 aviões** — do Avião de Papel ao Planador, Biplano,
  Monomotor, Turboélice, Jato Executivo, Caça a Jato, Caça Supersônico,
  Interceptador, Foguete Experimental e Nave Espacial. Cada fase tem sua
  própria meta de distância e sua própria trilha de upgrade, que reseta ao
  trocar de avião.
- **Evolução em 4 peças por avião** — Asa Esquerda, Asa Direita, Cauda e
  Hélice, cada uma com efeito visual e físico independente (dá para
  evoluir uma asa mais que a outra e voar assimétrico de propósito).
  Estilingue e bônus de renda são progressões **globais**, que acompanham
  o jogador entre fases.
- **Loop de prestígio** — completar a última fase reinicia o progresso das
  13 fases com um multiplicador de moedas permanente, para jogar de novo
  mais rápido.
- **Cenário procedural com biomas** — o terreno muda de cor e relevo ao
  longo de cada voo (duna → deserto → rachaduras → vilarejo → velho oeste
  → estação → mesas → cânion → planalto → salinas → costa), e fases mais
  avançadas já começam num cenário mais adiantado dessa progressão.
- **Uma fase desenhada à mão** — a Fase 2 (Avião de Brinquedo) tem uma
  vinheta própria: o avião atravessa **dentro de uma casa**, desviando de
  cadeiras e uma banheira antes de sair por uma janela — só depois disso
  a geração procedural normal assume o resto do voo.
- **3 dificuldades** (Fácil/Médio/Difícil), cada uma com sua própria queda,
  velocidade e recompensa em moedas.
- **Monitor de desempenho embutido** (`F1`) com FPS, frame time p99, draw
  calls e contagem de nós — critério objetivo de que o jogo roda liso em
  aparelho de gama média, não só "parece fluido".

## O que ainda não existe

- Áudio, partículas de impacto, vibração.
- Vinhetas desenhadas à mão nas outras 12 fases (a arquitetura já suporta,
  só falta desenhar cada uma).
- Controle por toques/impulsos discretos "de verdade" (hoje é arraste
  contínuo com penalidade por segurar o dedo, uma aproximação mais simples
  do mesmo efeito).
- Clima/vento variando por bioma.
- Missões diárias e avaliação por estrelas ao fim da fase.

---

## Arquitetura

```
autoload/
  config_jogo.gd     Constantes do modelo de voo e da economia
  eventos.gd         Barramento de sinais entre sistemas
  dados_jogo.gd       Progresso do jogador (moedas, niveis, fase, prestigio, save)
dados/
  atributos.gd       Catalogo das trilhas compraveis (4 pecas do aviao + moedas + estilingue)
  catalogo.gd        Os 13 avioes e suas velocidades base
  veiculo.gd, universo.gd  Resources consumidos pela FabricaModelos
jogo/
  aviao.gd           Fisica de voo (unico modelo balistico) e deteccao de colisao
  terreno.gd         Funcao de altura do relevo + biomas <- fonte unica da verdade
  pedaco_terreno.gd  Malha de terreno gerada a partir dela, com streaming
  gerador_mundo.gd   Streaming de terreno e correntes de ar
  gerador_obstaculos.gd, obstaculo.gd, cenario_fixo.gd  Sistema de obstaculos (atualmente nao instanciado - ver "O que ainda não existe")
  fabrica_modelos.gd Monta o modelo 3D do aviao por peca evoluida
  estilingue_visual.gd, camera_seguidora.gd, pool.gd
ui/
  estilingue.gd      Medidor de lancamento + mira lateral
  loja.gd, cartao_atributo.gd  Compra de upgrades
  hud.gd, velocimetro.gd, barra_progresso.gd, resultado.gd
  monitor_desempenho.gd, ajuste_moedas.gd (debug)
cenas/
  principal.tscn/gd  Cena unica; maquina de estados LOJA -> LANCAMENTO -> VOO -> RESULTADO
testes/
  piloto_automatico.gd  Joga sozinho e verifica o balanceamento (--teste-voo)
  teste_modelos.gd       Verifica a evolucao visual do modelo (--teste-modelos)
sim/
  modelo.py, progressao.py  Simulador de referencia em Python (parcialmente desatualizado - ver historico dos briefings)
csharp_opcional/
  Modulo C# opcional, desligado por padrao (ver csharp_opcional/README.md)
```

### Decisões que sustentam o resto

**O terreno tem uma única fonte da verdade.** `Terreno.altura(x, z)` gera
a malha visual *e* resolve a colisão do avião com o chão. Não existe
PhysicsBody, CollisionShape nem raycast para o solo — impossível a malha e
a colisão divergirem.

**O ângulo visual do avião é sempre consequência, nunca comando.** O
estado real do voo é um vetor de velocidade `(vx, vy)`; o nariz do modelo
aponta para `atan2(vy, vx)` — para onde o avião está *realmente* indo.
Isso é o que produz a curva em U invertida (sobe, atinge o pico, cai) e o
nariz inclinando para baixo conforme perde sustentação, em qualquer nível
de evolução.

**Cada avião tem sua própria trilha de upgrade, que reseta ao trocar.**
O salto grande de capacidade entre fases vem da troca de avião em si
(velocidade base maior), não do acúmulo de upgrade — por isso a curva de
custo de cada trilha é rasa (poucos níveis, poucas compras por fase).

---

## Documentação de design

O histórico completo de decisões de design está nos arquivos
`briefing_ajustes_v2.md` a `briefing_ajustes_v9.md` (nessa ordem
cronológica) e em `pesquisa_epic_plane_evolution.md` (pesquisa sobre o
jogo que inspirou o projeto, usada para orientar as últimas rodadas de
ajuste). `design_core_loop.md` é a especificação original do core loop e
está parcialmente desatualizada em relação ao jogo atual.

---

## Licença

Sem licença definida ainda — todos os direitos reservados por padrão até
que uma seja escolhida.

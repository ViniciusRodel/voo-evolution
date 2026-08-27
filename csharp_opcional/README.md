# Módulo C# opcional

> **Status: NÃO COMPILADO NESTE PROJETO.** Os arquivos desta pasta estão fora da
> compilação por padrão. O projeto que você recebeu roda 100% em GDScript, na
> build padrão do Godot 4.6, sem nenhuma dependência de .NET.

## Por que ele está desligado

Você escolheu a abordagem híbrida — GDScript para gameplay e UI, C# nos
gargalos. Este módulo existe para tornar a segunda metade dessa frase possível.
Mas ele começa desligado por um motivo:

**Na Fase 1 ainda não existe gargalo medido.** O laço de voo é dominado por
renderização (draw calls, shadow pass, fill rate), não por CPU em GDScript. O
trabalho de CPU por frame é da ordem de dezenas de operações: mover o avião,
interpolar a câmera, checar a fronteira do chunk. Portar isso para C# não
mudaria o FPS e custaria a toolchain .NET no pipeline de build mobile — que é,
por sinal, a parte historicamente mais delicada do C# no Godot.

Ligar C# antes de o profiler apontar é otimização sem medida. A ordem correta é:
rodar o spike → abrir o profiler no dispositivo alvo → **se** aparecer uma
função GDScript no topo do perfil de CPU, então portar aquela função.

## O que tem aqui

| Arquivo | Função |
|---|---|
| `LayoutFileiras.cs` | Porte em C# da geração de layout de fileiras de obstáculos — o candidato mais plausível a gargalo de CPU, por ser puro cálculo em lote |
| `Benchmark.cs` | Mede GDScript vs. C# no mesmo workload, para a decisão ser por dado e não por intuição |

## Por que a geração de layout é o candidato certo

É o único trecho do projeto que faz cálculo em lote e escala com a dificuldade.
Hoje ele gera 1–3 fileiras por chunk e o custo é irrelevante. Ele passa a
importar se vocês evoluírem para geração mais elaborada — validação de
jogabilidade por busca (verificar que existe uma trajetória viável entre
fileiras consecutivas), padrões compostos, ou pré-geração de centenas de metros
de pista de uma vez. Nesse cenário o custo sai de microssegundos e vira hitch
visível, e aí o porte se paga.

## Como ligar, quando chegar a hora

1. Instale a **build .NET do Godot 4.6** (o executável padrão não roda C#).
2. No editor: `Projeto → Ferramentas → C# → Criar solução C#`.
3. Mova os `.cs` desta pasta para a raiz do projeto (ou inclua a pasta no
   `.csproj`, que por padrão só varre a raiz).
4. Em `jogo/gerador_pista.gd`, troque as chamadas de `_fileira_*` pelas do
   objeto C#:

   ```gdscript
   # No topo do arquivo:
   const LayoutCS := preload("res://LayoutFileiras.cs")
   var _layout = LayoutCS.new()

   # Em _gerar_fileira, no lugar de _fileira_lateral(...):
   for b in _layout.GerarLateral(z, dificuldade, Config.CORREDOR_LARGURA):
       _colocar(Obstaculo.Tipo.PAREDE, b["tamanho"], b["posicao"], b["cor"], lista)
   ```

5. **Meça antes e depois.** Se o ganho não aparecer no monitor de desempenho
   (F1), reverta — você acabou de adicionar uma toolchain ao build mobile em
   troca de nada.

## Riscos conhecidos do C# no Godot para mobile

Levante estes pontos no spike, **antes** de o projeto depender deles:

- **Exportação Android/iOS** com C# tem historicamente mais arestas que
  GDScript. Valide a exportação assinada logo na Fase 3 do roadmap, não perto
  do lançamento.
- **Tamanho do binário** cresce com o runtime .NET incluído.
- **Tempo de iteração** piora: toda alteração em C# exige rebuild, enquanto
  GDScript recarrega na hora. Em código de balanceamento — que muda dezenas de
  vezes por dia — isso é um custo diário real.
- **Marshalling** entre GDScript e C# tem custo por chamada. Chamar C# uma vez
  por frame com um lote grande compensa; chamar 500 vezes por frame com
  argumentos pequenos pode sair mais caro que o GDScript que você substituiu.

## Nota de honestidade sobre esta entrega

Estes arquivos `.cs` **não foram compilados nem executados**. O ambiente onde o
projeto foi montado tinha a build padrão do Godot 4.6 (validada e usada para
rodar todos os testes de GDScript), mas não tinha o SDK .NET disponível.
Trate-os como ponto de partida revisável, não como código testado — ao
contrário de todo o resto do projeto, que roda e passa nos testes automatizados.

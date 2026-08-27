using Godot;
using System.Diagnostics;

// Micro-benchmark para decidir COM DADO se vale portar a geracao de layout
// para C#. NAO COMPILADO POR PADRAO. Ver csharp_opcional/README.md.
//
// Uso a partir do GDScript, depois de habilitar o modulo:
//
//   const BenchCS := preload("res://Benchmark.cs")
//   var b = BenchCS.new()
//   print(b.MedirCSharp(200000))
//
// e comparar com o equivalente em GDScript (metodo `medir_gdscript` sugerido
// no README). Regra de decisao: so porte se o ganho for grande o suficiente
// para aparecer no frame time real do dispositivo alvo - um ganho de 0,2 ms
// por frame em um orcamento de 16,6 ms nao justifica adicionar a toolchain
// .NET ao build mobile.

[GlobalClass]
public partial class Benchmark : RefCounted
{
    /// Roda `iteracoes` geracoes de fileira e devolve o tempo total em
    /// milissegundos. Descarta o resultado de proposito: o que interessa aqui
    /// e o custo de calculo, nao o layout.
    public double MedirCSharp(int iteracoes)
    {
        var layout = new LayoutFileiras();
        var relogio = Stopwatch.StartNew();

        for (int i = 0; i < iteracoes; i++)
        {
            float z = -(i * 30.0f);
            float dificuldade = (i % 100) / 100.0f;
            switch (i % 3)
            {
                case 0: layout.GerarLateral(z, dificuldade, 9.0f); break;
                case 1: layout.GerarHorizontal(z, 9.0f); break;
                default: layout.GerarPilares(z, dificuldade, 9.0f); break;
            }
        }

        relogio.Stop();
        return relogio.Elapsed.TotalMilliseconds;
    }

    /// Versao sem alocar Dictionary/Array, para separar o custo do calculo do
    /// custo de marshalling entre C# e o Godot. A diferenca entre este numero
    /// e o de MedirCSharp E o custo da ponte - e e frequentemente ele, e nao o
    /// calculo, que domina. Se for esse o caso, portar para C# nao resolve:
    /// o certo e reduzir a quantidade de chamadas atraves da fronteira.
    public double MedirCalculoPuro(int iteracoes)
    {
        var rng = new RandomNumberGenerator();
        var relogio = Stopwatch.StartNew();
        float soma = 0.0f;

        for (int i = 0; i < iteracoes; i++)
        {
            rng.Seed = (ulong)i;
            float abertura = Mathf.Lerp(3.4f, 2.2f, (i % 100) / 100.0f);
            float limite = 9.0f - abertura;
            soma += rng.RandfRange(-limite, limite);
        }

        relogio.Stop();
        GD.Print($"(soma ignorada: {soma})");
        return relogio.Elapsed.TotalMilliseconds;
    }
}

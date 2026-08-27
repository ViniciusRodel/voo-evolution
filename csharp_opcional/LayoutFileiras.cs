using Godot;
using Godot.Collections;

// Porte em C# da geracao de layout de fileiras de obstaculos.
//
// NAO COMPILADO POR PADRAO. Ver csharp_opcional/README.md antes de ligar.
//
// Contrato identico ao do GDScript em jogo/gerador_pista.gd: cada fileira SEMPRE
// tem uma abertura garantida. Se este arquivo divergir daquele nessa regra, o
// jogo fica injusto de um jeito dificil de rastrear - qualquer alteracao aqui
// precisa ser espelhada la, e vice-versa. Enquanto os dois coexistirem, o
// GDScript e a fonte da verdade.
//
// Devolve Array de Dictionary para o GDScript consumir sem conversao manual.
// Chaves: "tamanho" (Vector3), "posicao" (Vector3), "cor" (Color).

[GlobalClass]
public partial class LayoutFileiras : RefCounted
{
    public const float AberturaLateralBase = 3.4f;
    public const float AberturaLateralMin = 2.2f;
    public const float AberturaHorizontal = 2.8f;
    public const float ParedeExtensao = 16.0f;
    public const float AlturaMin = 2.0f;
    public const float AlturaMax = 16.0f;

    private readonly RandomNumberGenerator _rng = new RandomNumberGenerator();

    /// Semente derivada da posicao, para a fileira em um dado z ser sempre a
    /// mesma. Mesma logica do GDScript.
    public void Semear(float z)
    {
        _rng.Seed = (ulong)((int)(z * 10.0f)).GetHashCode();
    }

    public Array<Dictionary> GerarLateral(float z, float dificuldade, float corredorLargura)
    {
        Semear(z);
        var blocos = new Array<Dictionary>();

        float abertura = Mathf.Lerp(AberturaLateralBase, AberturaLateralMin, dificuldade);
        float limite = corredorLargura - abertura;
        float centro = _rng.RandfRange(-limite, limite);
        const float altura = 26.0f;
        const float espessura = 2.2f;
        var cor = new Color(0.72f, 0.28f, 0.24f);

        float esqDir = centro - abertura;
        float esqEsq = -corredorLargura - ParedeExtensao;
        if (esqDir > esqEsq)
        {
            blocos.Add(Bloco(
                new Vector3(esqDir - esqEsq, altura, espessura),
                new Vector3((esqDir + esqEsq) * 0.5f, altura * 0.5f - 1.0f, z),
                cor));
        }

        float dirEsq = centro + abertura;
        float dirDir = corredorLargura + ParedeExtensao;
        if (dirDir > dirEsq)
        {
            blocos.Add(Bloco(
                new Vector3(dirDir - dirEsq, altura, espessura),
                new Vector3((dirDir + dirEsq) * 0.5f, altura * 0.5f - 1.0f, z),
                cor));
        }

        return blocos;
    }

    public Array<Dictionary> GerarHorizontal(float z, float corredorLargura)
    {
        Semear(z);
        var blocos = new Array<Dictionary>();

        float centro = _rng.RandfRange(
            AlturaMin + AberturaHorizontal,
            AlturaMax - AberturaHorizontal);
        float largura = (corredorLargura + ParedeExtensao) * 2.0f;
        const float espessura = 2.0f;
        var cor = new Color(0.85f, 0.62f, 0.22f);

        float topoBase = centro + AberturaHorizontal;
        const float topoAltura = 30.0f;
        blocos.Add(Bloco(
            new Vector3(largura, topoAltura, espessura),
            new Vector3(0.0f, topoBase + topoAltura * 0.5f, z),
            cor));

        float baixoTopo = centro - AberturaHorizontal;
        if (baixoTopo > AlturaMin - 1.0f)
        {
            float h = baixoTopo + 2.0f;
            blocos.Add(Bloco(
                new Vector3(largura, h, espessura),
                new Vector3(0.0f, baixoTopo - h * 0.5f, z),
                cor));
        }

        return blocos;
    }

    public Array<Dictionary> GerarPilares(float z, float dificuldade, float corredorLargura)
    {
        Semear(z);
        var blocos = new Array<Dictionary>();

        int quantidade = 2 + (int)(dificuldade * 2.0f);
        var cor = new Color(0.35f, 0.38f, 0.44f);
        float faixa = corredorLargura * 2.0f / (quantidade + 1);

        for (int i = 0; i < quantidade; i++)
        {
            float b = -corredorLargura + faixa * (i + 1);
            float x = b + _rng.RandfRange(-faixa * 0.22f, faixa * 0.22f);
            float largura = _rng.RandfRange(1.1f, 1.9f);
            blocos.Add(Bloco(
                new Vector3(largura, 34.0f, largura),
                new Vector3(x, 12.0f, z + _rng.RandfRange(-3.0f, 3.0f)),
                cor));
        }

        return blocos;
    }

    private static Dictionary Bloco(Vector3 tamanho, Vector3 posicao, Color cor)
    {
        return new Dictionary
        {
            { "tamanho", tamanho },
            { "posicao", posicao },
            { "cor", cor },
        };
    }
}

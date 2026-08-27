@tool
class_name Velocimetro
extends Control
## Medidor circular de velocidade, desenhado inteiramente com _draw().
##
## Por que desenhado e nao montado com texturas: um gauge feito de sprites
## exigiria arte para cada estado e nao escalaria para os 6 veiculos (que tem
## escalas de velocidade de 10 a 1750 km/h). Desenhado, ele se adapta sozinho e
## nao consome nenhum slot de textura. O custo de _draw() e desprezivel porque
## so redesenha quando `valor` muda (queue_redraw).
##
## @tool para o desenho aparecer no editor durante o ajuste visual.

@export var valor: float = 0.0: set = definir_valor
@export var maximo: float = 100.0: set = definir_maximo
## Quando >= 0, e este numero que aparece no centro, em vez de `valor`.
## Existe para o cartao de veiculo poder posicionar o ponteiro em escala
## logaritmica (unica forma de 10 km/h e 1200 km/h coexistirem legivelmente no
## mesmo mostrador) e ainda assim exibir o km/h real.
@export var valor_exibido: float = -1.0: set = definir_valor_exibido
@export var espessura: float = 11.0
@export var mostrar_texto: bool = true
@export var cor_fundo: Color = Color(0.12, 0.14, 0.18, 0.55)
@export var cor_trilha: Color = Color(1, 1, 1, 0.18)

## Angulo inicial e final do arco, em graus. 135 -> 405 desenha um "C" aberto
## para baixo, como um velocimetro de painel.
const ANGULO_INICIO := 135.0
const ANGULO_VARRE := 270.0

## Paleta do gradiente, do lento ao rapido. Mesma logica das faixas coloridas
## da decolagem, para o jogador ler as duas telas com o mesmo vocabulario.
const CORES: Array[Color] = [
	Color(0.20, 0.72, 0.35),
	Color(0.62, 0.78, 0.22),
	Color(0.95, 0.78, 0.18),
	Color(0.94, 0.52, 0.15),
	Color(0.88, 0.22, 0.18),
]


func definir_valor(v: float) -> void:
	if is_equal_approx(valor, v):
		return
	valor = v
	queue_redraw()


func definir_maximo(v: float) -> void:
	maximo = maxf(0.0001, v)
	queue_redraw()


func definir_valor_exibido(v: float) -> void:
	valor_exibido = v
	queue_redraw()


func _draw() -> void:
	var centro := size * 0.5
	var raio := minf(size.x, size.y) * 0.5 - espessura * 0.5 - 2.0
	if raio <= 0.0:
		return

	draw_circle(centro, raio + espessura * 0.5, cor_fundo)

	var ini := deg_to_rad(ANGULO_INICIO)
	var fim := deg_to_rad(ANGULO_INICIO + ANGULO_VARRE)
	draw_arc(centro, raio, ini, fim, 64, cor_trilha, espessura, true)

	var proporcao := clampf(valor / maximo, 0.0, 1.0)
	if proporcao > 0.001:
		# O arco preenchido e desenhado em segmentos para permitir o gradiente
		# de cor ao longo dele.
		var segmentos := maxi(2, int(proporcao * 48.0))
		for i in segmentos:
			var t0 := float(i) / float(segmentos)
			var t1 := float(i + 1) / float(segmentos)
			var a0 := ini + (fim - ini) * proporcao * t0
			var a1 := ini + (fim - ini) * proporcao * t1
			draw_arc(centro, raio, a0, a1 + 0.02, 4, _cor_em(proporcao * t1), espessura, true)

	# Ponteiro.
	var ang := ini + (fim - ini) * proporcao
	var ponta := centro + Vector2(cos(ang), sin(ang)) * (raio - espessura * 0.35)
	draw_line(centro, ponta, Color(0.10, 0.11, 0.14), 4.0, true)
	draw_circle(centro, 5.0, Color(0.10, 0.11, 0.14))

	if mostrar_texto:
		var fonte := ThemeDB.fallback_font
		var tam_fonte := int(clampf(raio * 0.42, 12.0, 40.0))
		var texto := "%d" % int(round(valor_exibido if valor_exibido >= 0.0 else valor))
		var largura := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_CENTER, -1, tam_fonte).x
		draw_string(fonte, centro + Vector2(-largura * 0.5, raio * 0.24),
			texto, HORIZONTAL_ALIGNMENT_CENTER, -1, tam_fonte, Color.WHITE)
		var rotulo := "KM/H"
		var tam_rot := maxi(9, int(tam_fonte * 0.4))
		var larg_rot := fonte.get_string_size(rotulo, HORIZONTAL_ALIGNMENT_CENTER, -1, tam_rot).x
		draw_string(fonte, centro + Vector2(-larg_rot * 0.5, raio * 0.24 + float(tam_fonte) * 0.85),
			rotulo, HORIZONTAL_ALIGNMENT_CENTER, -1, tam_rot, Color(1, 1, 1, 0.75))


func _cor_em(t: float) -> Color:
	var escala := clampf(t, 0.0, 1.0) * float(CORES.size() - 1)
	var i := int(floor(escala))
	var j: int = mini(i + 1, CORES.size() - 1)
	return CORES[i].lerp(CORES[j], escala - float(i))

@tool
class_name BarraProgresso
extends Control
## Barra vertical de progresso ate o checkpoint, com marcador em forma de
## aviao e porcentagem - equivalente a barra da lateral direita da referencia.
##
## Desenhada com _draw() pelo mesmo motivo do velocimetro: se adapta a qualquer
## altura de tela sem precisar de 9-patch nem arte por resolucao.

@export_range(0.0, 1.0) var progresso: float = 0.0: set = definir_progresso
@export var cor_trilha: Color = Color(0.10, 0.11, 0.14, 0.55)
@export var cor_preenchida: Color = Color(0.30, 0.62, 0.95)
@export var largura_trilha: float = 12.0


func definir_progresso(v: float) -> void:
	var novo := clampf(v, 0.0, 1.0)
	if is_equal_approx(progresso, novo):
		return
	progresso = novo
	queue_redraw()


func _draw() -> void:
	var x := size.x * 0.5
	var topo := 26.0
	var base := size.y - 10.0
	var altura := base - topo
	if altura <= 0.0:
		return

	# Trilha.
	draw_rect(Rect2(x - largura_trilha * 0.5, topo, largura_trilha, altura), cor_trilha)

	# Preenchimento cresce de baixo para cima.
	var h := altura * progresso
	draw_rect(Rect2(x - largura_trilha * 0.5, base - h, largura_trilha, h), cor_preenchida)

	# Bandeira quadriculada no topo, marcando o checkpoint.
	var lado := 5.0
	for i in 4:
		for j in 2:
			var c := Color.WHITE if (i + j) % 2 == 0 else Color(0.12, 0.12, 0.14)
			draw_rect(Rect2(x - lado + float(j) * lado, topo - 16.0 + float(i) * (lado * 0.8),
				lado, lado * 0.8), c)

	# Marcador do aviao: triangulo simples apontando para cima.
	var my := base - h
	var pontos := PackedVector2Array([
		Vector2(x, my - 9.0),
		Vector2(x - 7.0, my + 5.0),
		Vector2(x + 7.0, my + 5.0),
	])
	draw_colored_polygon(pontos, Color.WHITE)

	var fonte := ThemeDB.fallback_font
	var texto := "%d%%" % int(round(progresso * 100.0))
	var larg := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_CENTER, -1, 14).x
	draw_string(fonte, Vector2(x - larg * 0.5, my + 22.0), texto,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.WHITE)

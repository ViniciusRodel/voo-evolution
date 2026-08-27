extends Node
## Captura telas do jogo em pontos definidos do fluxo, para revisao visual sem
## precisar de alguem segurando o aparelho.
##
## Uso (Linux com display virtual):
##   xvfb-run -a -s "-screen 0 1080x1920x24" \
##     godot --rendering-driver opengl3 --quit-after 3000 -- --capturar
##
## Util para: revisao de UI em pull request, comparacao antes/depois de uma
## mudanca de balanceamento, e prova de que a build renderiza de fato.

const PASTA := "user://capturas"
## Mesma qualidade fixa usada pelo piloto automatico (testes/piloto_automatico.gd)
## - lancamento deterministico, ver Estilingue.lancar_direto().
const QUALIDADE := 0.70

var principal: Node = null

var _aviao: Aviao = null
var _estilingue: Estilingue = null
var _etapa: int = 0
var _tempo: float = 0.0


func _ready() -> void:
	# Ver DadosJogo._persistencia_desabilitada: sem isto, a corrida forcada em
	# _capturar_resultado() grava por cima do progresso.json real (mesmo
	# save da janela jogavel).
	DadosJogo._persistencia_desabilitada = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	var nos: Dictionary = principal.nos_de_teste()
	_aviao = nos["aviao"]
	_estilingue = nos["estilingue"]
	print("Capturando em: ", ProjectSettings.globalize_path(PASTA))


func _process(delta: float) -> void:
	_tempo += delta
	match _etapa:
		0:
			if _tempo > 0.6:
				await _capturar("01_selecao_veiculos.png")
				_avancar()
		1:
			principal.iniciar_corrida()
			_avancar()
		2:
			# Estilingue.iniciar() ja deixa visible=true no frame de
			# iniciar_corrida() - so espera um instante pro elastico assentar.
			if _tempo > 0.5:
				await _capturar("02_estilingue.png")
				_avancar()
		3:
			_estilingue.lancar_direto(QUALIDADE)
			_avancar()
		4:
			if _tempo > 3.0:
				await _capturar("03_voo.png")
				_avancar()
		5:
			if _tempo > 4.0:
				await _capturar("04_voo_distante.png")
				_avancar()
		6:
			# Forca o fim da partida (bate a meta) para capturar a tela de
			# resultado sem esperar o voo real terminar.
			_aviao.distancia = 1_000_000.0
			_avancar()
		7:
			if _tempo > 0.8:
				await _capturar("05_resultado.png")
				_avancar()
		8:
			print("capturas concluidas.")
			get_tree().quit(0)


func _avancar() -> void:
	_etapa += 1
	_tempo = 0.0


func _capturar(nome: String) -> void:
	# Espera o frame ser efetivamente desenhado antes de ler o framebuffer.
	await RenderingServer.frame_post_draw
	var imagem := get_viewport().get_texture().get_image()
	var caminho := "%s/%s" % [PASTA, nome]
	var erro := imagem.save_png(caminho)
	if erro != OK:
		push_error("Falha ao salvar %s (erro %d)" % [caminho, erro])
	else:
		print("  -> %s (%dx%d)" % [nome, imagem.get_width(), imagem.get_height()])

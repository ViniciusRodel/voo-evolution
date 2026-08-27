class_name FabricaModelos
extends RefCounted
## Monta o modelo 3D de um veiculo a partir de blocos, em funcao do seu nivel
## de evolucao.
##
## ESTE ARQUIVO E O CORACAO DA VALIDACAO DA FASE 2 DO ROADMAP.
##
## A mecanica de "Level 1 -> Level 20 troca o modelo" e o que precisa ser
## provado. Aqui ela e provada com geometria procedural (zero assets de arte),
## o que permite testar a troca em runtime, o custo de instanciacao e o
## comportamento de memoria antes de existir um unico modelo feito por artista.
##
## MIGRACAO PARA PRODUCAO: trocar o corpo de `criar()` por um carregamento de
## .glb (`load("res://modelos/%s_n%02d.glb")`), mantendo a MESMA assinatura.
## Nenhum outro arquivo do projeto precisa mudar - e exatamente esse isolamento
## que estamos validando.

## Cache de materiais por cor. Sem isto, cada bloco criaria um
## StandardMaterial3D novo e a contagem de draw calls explodiria.
static var _cache_materiais: Dictionary = {}

## Malha unitaria compartilhada por TODOS os blocos do jogo. Cada bloco ajusta
## sua propria escala. Uma malha so = a GPU nao troca de buffer entre blocos.
static var _malha_cubo: BoxMesh = null


static func malha_cubo() -> BoxMesh:
	if _malha_cubo == null:
		_malha_cubo = BoxMesh.new()
		_malha_cubo.size = Vector3.ONE
	return _malha_cubo


static func material_para(cor: Color, silhueta: bool = false) -> StandardMaterial3D:
	var chave := "%s|%s" % [cor.to_html(false), silhueta]
	if _cache_materiais.has(chave):
		return _cache_materiais[chave]

	var m := StandardMaterial3D.new()
	if silhueta:
		# Cartoes de veiculo bloqueado mostram so a silhueta preta.
		m.albedo_color = Color(0.10, 0.10, 0.12)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		m.albedo_color = cor
		m.roughness = 0.85
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_cache_materiais[chave] = m
	return m


## Monta o modelo do veiculo no nivel informado e devolve a raiz.
## O chamador e responsavel por adicionar o no na arvore e liberar o anterior.
##
## V9/P3: `pecas` e opcional e traz o progresso (0 a 1) de CADA peca
## (Atributos.ASA_ESQUERDA/ASA_DIREITA/CAUDA/HELICE, ver
## DadosJogo.pecas_visuais()) - cada asa aparece e cresce com o progresso da
## SUA PROPRIA peca, nao mais uma fracao "t" compartilhada entre trilhas
## diferentes (ver briefing_ajustes_v9.md P3). Quando `pecas` vem vazio
## (chamadores antigos/de teste que so tem um "nivel" geral - ver
## testes/teste_modelos.gd, ui/cartao_veiculo.gd), toda peca usa o mesmo "t"
## geral de `nivel`, reproduzindo o comportamento de antes.
static func criar(veiculo: Veiculo, nivel: int, silhueta: bool = false, pecas: Dictionary = {}) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Modelo"

	if veiculo == null:
		return raiz

	var t := veiculo.progresso_do_nivel(nivel)
	var t_geral: float = pecas.get("geral", t)
	var t_asa_d: float = pecas.get(Atributos.ASA_DIREITA, t)
	var t_asa_e: float = pecas.get(Atributos.ASA_ESQUERDA, t)
	var t_cauda: float = pecas.get(Atributos.CAUDA, t)
	var t_helice: float = pecas.get(Atributos.HELICE, t)
	var cor_a := veiculo.cor_primaria
	var cor_b := veiculo.cor_secundaria

	# --- Fuselagem -----------------------------------------------------------
	# Cresce com o progresso GERAL (media das 4 pecas) - nao e propriedade de
	# nenhuma peca especifica, e o corpo que todas elas se prendem.
	var comprimento := lerpf(1.8, 3.8, t_geral)
	var largura := lerpf(0.30, 0.52, t_geral)
	_bloco(raiz, Vector3(0, 0, 0), Vector3(largura, largura * 0.9, comprimento), cor_a, silhueta)

	# Nariz: um bloco menor a frente, para dar direcao clara ao modelo.
	_bloco(raiz, Vector3(0, 0, -comprimento * 0.5 - 0.25),
		Vector3(largura * 0.7, largura * 0.7, 0.5), cor_b, silhueta)

	# --- Asas ------------------------------------------------------------------
	# V9/P3: cada asa e independente - existe assim que a PECA respectiva tem
	# pelo menos 1 nivel comprado (t > 0), e cresce com o progresso DAQUELA
	# peca, nao mais uma fracao "t" somada com as outras trilhas. Um jogador
	# pode comprar so a asa direita e voar assimetrico de proposito.
	var corda := lerpf(0.55, 0.95, t_geral)
	var espessura := lerpf(0.09, 0.16, t_geral)

	if t_asa_d > 0.0:
		var envergadura_d := lerpf(2.2, 5.2, t_asa_d)
		var ponta_d := envergadura_d * 0.5 - 0.22
		_bloco(raiz, Vector3(envergadura_d * 0.25, 0, -comprimento * 0.05),
			Vector3(envergadura_d * 0.5, espessura, corda), cor_a, silhueta)
		_bloco(raiz, Vector3(ponta_d, 0, -comprimento * 0.05),
			Vector3(0.44, espessura * 1.05, corda * 0.95), cor_b, silhueta)
	if t_asa_e > 0.0:
		var envergadura_e := lerpf(2.2, 5.2, t_asa_e)
		var ponta_e := envergadura_e * 0.5 - 0.22
		_bloco(raiz, Vector3(-envergadura_e * 0.25, 0, -comprimento * 0.05),
			Vector3(envergadura_e * 0.5, espessura, corda), cor_a, silhueta)
		_bloco(raiz, Vector3(-ponta_e, 0, -comprimento * 0.05),
			Vector3(0.44, espessura * 1.05, corda * 0.95), cor_b, silhueta)

	# --- Cauda -----------------------------------------------------------------
	# V9/P3: a peca CAUDA controla a deriva vertical (sempre presente, mesmo
	# no nivel 1 - ate sem nenhuma compra o aviao precisa de uma silhueta
	# reconhecivel) e o estabilizador horizontal (a partir do 2o nivel).
	var envergadura_geral := lerpf(2.2, 5.2, t_geral)
	var z_cauda := comprimento * 0.5 - 0.15
	_bloco(raiz, Vector3(0, lerpf(0.25, 0.48, t_cauda), z_cauda),
		Vector3(espessura, lerpf(0.5, 0.95, t_cauda), corda * 0.75), cor_b, silhueta)
	if t_cauda > 0.15:
		_bloco(raiz, Vector3(0, 0.05, z_cauda),
			Vector3(envergadura_geral * 0.38, espessura * 0.9, corda * 0.6), cor_a, silhueta)

	# --- Cabine ------------------------------------------------------------
	if t_geral > 0.40:
		_bloco(raiz, Vector3(0, largura * 0.62, -comprimento * 0.12),
			Vector3(largura * 0.75, largura * 0.55, corda * 1.1), cor_b, silhueta)

	# --- Motor em 3 estagios (peca HELICE) -------------------------------------
	# V9/P3: os 3 limiares agora sao fracoes da PROPRIA peca HELICE (0 a 1),
	# nao mais uma fracao da soma de todas as trilhas - a helice cosmetica
	# aparece cedo dentro da peca, os 2 motores um de cada vez depois.
	if t_helice > 0.0:
		var r_helice := lerpf(0.30, 0.50, t_helice)
		var z_helice := -comprimento * 0.5 - 0.55
		_bloco(raiz, Vector3(0, 0, z_helice), Vector3(r_helice, 0.05, 0.05), cor_b, silhueta)
		_bloco(raiz, Vector3(0, 0, z_helice), Vector3(0.05, r_helice, 0.05), cor_b, silhueta)

	var dx := envergadura_geral * 0.26
	var dz := -comprimento * 0.05 - corda * 0.35
	# Motor direito primeiro - potencia_motor_atual() bate ~0,5 por aqui.
	if t_helice > 0.40:
		_motor(raiz, Vector3(dx, -espessura * 1.4, dz), t_helice, cor_b, silhueta)
	# Motor esquerdo - so com os dois potencia_motor_atual() bate 1,0 e
	# bonus_motor_lancamento() (DadosJogo) chega ao maximo.
	if t_helice > 0.70:
		_motor(raiz, Vector3(-dx, -espessura * 1.4, dz), t_helice, cor_b, silhueta)
	if t_helice >= 1.0:
		var dx2 := envergadura_geral * 0.40
		var dz2 := -comprimento * 0.05 - corda * 0.30
		_motor(raiz, Vector3(dx2, -espessura * 1.4, dz2), t_helice, cor_b, silhueta)
		_motor(raiz, Vector3(-dx2, -espessura * 1.4, dz2), t_helice, cor_b, silhueta)

	# --- Trem de pouso -----------------------------------------------------
	if t_geral > 0.78:
		var dyg := -largura * 0.75
		_bloco(raiz, Vector3(0.45, dyg, -comprimento * 0.10), Vector3(0.14, 0.30, 0.14), cor_b, silhueta)
		_bloco(raiz, Vector3(-0.45, dyg, -comprimento * 0.10), Vector3(0.14, 0.30, 0.14), cor_b, silhueta)

	raiz.scale = Vector3.ONE * veiculo.escala_modelo
	return raiz


static func _motor(pai: Node3D, pos: Vector3, t_helice: float, cor: Color, silhueta: bool) -> void:
	var c := lerpf(0.45, 0.75, t_helice)
	_bloco(pai, pos, Vector3(0.26, 0.26, c), cor, silhueta)


static func _bloco(pai: Node3D, pos: Vector3, tam: Vector3, cor: Color, silhueta: bool) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = malha_cubo()
	mi.material_override = material_para(cor, silhueta)
	mi.position = pos
	mi.scale = tam
	# Blocos pequenos nao precisam projetar sombra individual: em mobile isso
	# reduz bastante o custo do shadow pass sem perda visual perceptivel.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pai.add_child(mi)


## Numero de blocos que o modelo teria neste nivel, sem construi-lo.
## Usado pelo monitor de desempenho para reportar custo por nivel. Mesmo
## fallback de criar(): sem `pecas`, todas usam o "t" geral de `nivel`.
static func contar_blocos(veiculo: Veiculo, nivel: int, pecas: Dictionary = {}) -> int:
	if veiculo == null:
		return 0
	var t := veiculo.progresso_do_nivel(nivel)
	var t_geral: float = pecas.get("geral", t)
	var t_asa_d: float = pecas.get(Atributos.ASA_DIREITA, t)
	var t_asa_e: float = pecas.get(Atributos.ASA_ESQUERDA, t)
	var t_cauda: float = pecas.get(Atributos.CAUDA, t)
	var t_helice: float = pecas.get(Atributos.HELICE, t)
	var n := 2  # fuselagem, nariz
	n += 1      # deriva vertical (Cauda) - sempre presente
	if t_asa_d > 0.0: n += 2   # meia-asa direita + ponta
	if t_asa_e > 0.0: n += 2   # meia-asa esquerda + ponta
	if t_cauda > 0.15: n += 1  # estabilizador horizontal
	if t_geral > 0.40: n += 1  # cabine
	if t_helice > 0.0: n += 2      # helice cosmetica
	if t_helice > 0.40: n += 1     # motor direito
	if t_helice > 0.70: n += 1     # motor esquerdo
	if t_geral > 0.78: n += 2      # trem de pouso
	if t_helice >= 1.0: n += 2     # motores extra
	return n

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config.dart';
import '../extractors/portal.dart';
import '../session/regras_sessao.dart';
import '../session/sessao.dart';
import 'academico.dart';
import 'banco.dart';

enum ResultadoPortal { atualizado, sessaoExpirada, falhou }

/// Identificação e horários. A sessão do portal é curta, então o app vive do que está salvo
/// e só lê de novo depois de um login ou quando a pessoa puxa para atualizar.
class RepositorioPortal extends ChangeNotifier {
  RepositorioPortal._();
  static final instancia = RepositorioPortal._();

  static const _cofre = FlutterSecureStorage();
  static const _chaveMatricula = 'matricula';
  static const _chaveId = 'identificacao';
  static const _chaveAulas = 'aulas';
  static const _chaveIdInterno = 'id_interno';
  // v2: quadro completo (avaliações, pesos, exame). O formato antigo é ignorado.
  static const _chaveNotas = 'notas_v2';

  String? _idInterno;

  Identificacao? identificacao;
  String? matricula;
  List<Aula>? aulas;
  List<NotasDisciplina>? notas;
  String? semestreDasNotas;
  DateTime? notasLidasEm;
  bool carregando = false;

  Future<void> carregarSalvos() async {
    matricula = await _cofre.read(key: _chaveMatricula);
    final id = await Banco.ler(_chaveId);
    if (id != null) identificacao = Identificacao.deMapa(jsonDecode(id) as Map<String, dynamic>);
    final salvas = await Banco.ler(_chaveAulas);
    if (salvas != null) {
      aulas = (jsonDecode(salvas) as List).map((a) => Aula.deMapa(a as Map<String, dynamic>)).toList();
    }
    final salvasNotas = await Banco.ler(_chaveNotas);
    if (salvasNotas != null) {
      final m = jsonDecode(salvasNotas) as Map<String, dynamic>;
      semestreDasNotas = m['semestre'] as String;
      notasLidasEm = DateTime.parse(m['lidasEm'] as String);
      notas = (m['disciplinas'] as List).map((n) => NotasDisciplina.deMapa(n as Map<String, dynamic>)).toList();
    }
    notifyListeners();
  }

  /// Logo depois do primeiro login a sessão está nova: é a hora de ler.
  Future<void> aoAbrirApp() async {
    // Quem pulou o Portal no login não tem o que ler: a Início mostra o botão "Entrar no Portal".
    if (identificacao == null && Sessao.instancia.conectado(Sistema.portal)) await atualizar();
  }

  Future<ResultadoPortal> atualizar() async {
    if (carregando) return ResultadoPortal.falhou;
    carregando = true;
    notifyListeners();
    final resultado = await _ler();
    carregando = false;
    notifyListeners();
    return resultado;
  }

  Future<ResultadoPortal> _ler() async {
    final sessao = Sessao.instancia;
    final inicio = await sessao.lerEMarcar(Sistema.portal);
    if (inicio.resultado == ResultadoVerificacao.expirada) return ResultadoPortal.sessaoExpirada;
    final id = inicio.html == null ? null : lerIdInterno(inicio.html!);
    if (id == null) return ResultadoPortal.falhou;
    await _guardarId(id);

    final relatorios = await sessao.lerEMarcar(Sistema.portal, url: urlRelatorios(id));
    final dados = relatorios.html == null ? null : lerIdentificacao(relatorios.html!);
    if (dados == null) return ResultadoPortal.falhou;
    identificacao = dados.identificacao;
    matricula = dados.matricula;
    await _cofre.write(key: _chaveMatricula, value: dados.matricula);
    await Banco.gravar(_chaveId, jsonEncode(dados.identificacao.paraMapa()));
    notifyListeners();

    final quadro = await sessao.lerEMarcar(Sistema.portal, url: urlHorarios(id));
    final lidas = quadro.html == null ? null : lerHorarios(quadro.html!);
    if (lidas == null) return ResultadoPortal.falhou;
    aulas = lidas;
    await Banco.gravar(_chaveAulas, jsonEncode(lidas.map((a) => a.paraMapa()).toList()));
    notifyListeners();
    return _lerNotas(id);
  }

  Future<ResultadoPortal> _lerNotas(String id) async {
    final sessao = Sessao.instancia;
    final pagina = await sessao.lerEMarcar(Sistema.portal, url: urlNotas(id));
    final lista = pagina.html == null ? null : lerListaDeNotas(pagina.html!);
    if (lista == null) return ResultadoPortal.falhou;
    final lidas = <NotasDisciplina>[];
    for (final d in lista.disciplinas) {
      final url = d.urlNotas;
      final quadro = url == null ? null : await sessao.lerEMarcar(Sistema.portal, url: url);
      if (url != null && quadro?.resultado != ResultadoVerificacao.ativa) return ResultadoPortal.falhou;
      lidas.add(lerNotasDaDisciplina(quadro?.html ?? '', d));
    }
    notas = lidas;
    semestreDasNotas = lista.semestre;
    notasLidasEm = DateTime.now();
    await Banco.gravar(
      _chaveNotas,
      jsonEncode({
        'semestre': lista.semestre,
        'lidasEm': notasLidasEm!.toIso8601String(),
        'disciplinas': lidas.map((n) => n.paraMapa()).toList(),
      }),
    );
    return ResultadoPortal.atualizado;
  }

  Future<void> _guardarId(String id) async {
    _idInterno = id;
    await _cofre.write(key: _chaveIdInterno, value: id);
  }

  /// O número interno dos endereços do portal. Null se a sessão caiu e ele ainda não é conhecido.
  Future<String?> garantirIdInterno() async {
    final salvo = _idInterno ?? await _cofre.read(key: _chaveIdInterno);
    if (salvo != null) return _idInterno = salvo;
    final inicio = await Sessao.instancia.lerEMarcar(Sistema.portal);
    final id = inicio.html == null ? null : lerIdInterno(inicio.html!);
    if (id != null) await _guardarId(id);
    return id;
  }

  /// Null se a sessão caiu: a página oficial pede o login por conta própria.
  Future<String?> lerEnderecoComunicacoesDoPortal() async {
    final inicio = await Sessao.instancia.lerEMarcar(Sistema.portal);
    return inicio.html == null ? null : lerEnderecoComunicacoes(inicio.html!);
  }

  /// O endereço de "Mais relatórios" vem da página. Null se a sessão caiu.
  Future<String?> lerEnderecoMaisRelatorios() async {
    final id = await garantirIdInterno();
    if (id == null) return null;
    final pagina = await Sessao.instancia.lerEMarcar(Sistema.portal, url: urlRelatorios(id));
    return pagina.html == null ? null : lerEnderecoMaisRelatoriosDe(pagina.html!);
  }

  /// "Limpar dados salvos": o banco é apagado pelo repositório do RU; aqui só a memória.
  void limparCache() {
    identificacao = null;
    aulas = null;
    notas = null;
    semestreDasNotas = null;
    notasLidasEm = null;
    notifyListeners();
  }

  void limpar() {
    _idInterno = null;
    identificacao = null;
    matricula = null;
    aulas = null;
    notas = null;
    semestreDasNotas = null;
    notasLidasEm = null;
    notifyListeners();
  }
}

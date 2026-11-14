import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config.dart';
import '../extractors/biblioteca.dart';
import '../session/regras_sessao.dart';
import '../session/sessao.dart';
import 'banco.dart';
import 'biblioteca.dart';
import 'repositorio_portal.dart';

enum ResultadoBiblioteca { ok, sessaoExpirada, falhou }

/// Biblioteca: busca no acervo (sob demanda, nunca em segundo plano) e histórico de
/// empréstimos (salvo no celular, lido de novo ao abrir a aba ou puxar para atualizar).
class RepositorioBiblioteca extends ChangeNotifier {
  RepositorioBiblioteca._();
  static final instancia = RepositorioBiblioteca._();

  static const _chaveHistorico = 'biblioteca_historico_v1';

  List<EmprestimoHistorico>? historico;
  DateTime? historicoLidoEm;
  bool carregandoHistorico = false;

  /// A Biblioteca só reconhece a pessoa depois de entrar pelo link com o número interno.
  bool _entrou = false;

  Future<void> carregarSalvos() async {
    final texto = await Banco.ler(_chaveHistorico);
    if (texto == null) return;
    try {
      final m = jsonDecode(texto) as Map<String, dynamic>;
      historicoLidoEm = DateTime.parse(m['lidoEm'] as String);
      historico = [for (final e in m['lista'] as List) EmprestimoHistorico.deMapa(e as Map<String, dynamic>)];
      notifyListeners();
    } catch (_) {
      // Formato antigo: lê de novo.
    }
  }

  /// Antes de abrir Renovação ou Reservas na página oficial: garante que a Biblioteca já reconhece a pessoa.
  Future<ResultadoBiblioteca> prepararPaginaOficial() => _entrar();

  Future<ResultadoBiblioteca> _entrar() async {
    if (_entrou) return ResultadoBiblioteca.ok;
    final id = await RepositorioPortal.instancia.garantirIdInterno();
    if (id == null) return ResultadoBiblioteca.sessaoExpirada;
    final pagina = await Sessao.instancia.lerEMarcar(Sistema.biblioteca, url: urlBiblioteca(id));
    if (pagina.resultado == ResultadoVerificacao.expirada) return ResultadoBiblioteca.sessaoExpirada;
    if (pagina.resultado != ResultadoVerificacao.ativa) return ResultadoBiblioteca.falhou;
    _entrou = true;
    return ResultadoBiblioteca.ok;
  }

  /// Lê uma página da Biblioteca; se a sessão tiver caído no meio, entra de novo uma vez.
  Future<(ResultadoBiblioteca, String?)> _ler(String url) async {
    var r = await _entrar();
    if (r != ResultadoBiblioteca.ok) return (r, null);
    var pagina = await Sessao.instancia.lerEMarcar(Sistema.biblioteca, url: url);
    if (pagina.resultado == ResultadoVerificacao.expirada) {
      _entrou = false;
      r = await _entrar();
      if (r != ResultadoBiblioteca.ok) return (r, null);
      pagina = await Sessao.instancia.lerEMarcar(Sistema.biblioteca, url: url);
    }
    return switch (pagina.resultado) {
      ResultadoVerificacao.ativa => (ResultadoBiblioteca.ok, pagina.html),
      ResultadoVerificacao.expirada => (ResultadoBiblioteca.sessaoExpirada, null),
      ResultadoVerificacao.semResposta => (ResultadoBiblioteca.falhou, null),
    };
  }

  Future<ResultadoBiblioteca> atualizarHistorico() async {
    if (carregandoHistorico) return ResultadoBiblioteca.falhou;
    carregandoHistorico = true;
    notifyListeners();
    final (r, html) = await _ler(urlBibliotecaHistorico);
    final lista = html == null ? null : lerHistoricoBiblioteca(html);
    if (lista != null) {
      historico = lista;
      historicoLidoEm = DateTime.now();
      await Banco.gravar(
        _chaveHistorico,
        jsonEncode({
          'lidoEm': historicoLidoEm!.toIso8601String(),
          'lista': [for (final e in lista) e.paraMapa()],
        }),
      );
    }
    carregandoHistorico = false;
    notifyListeners();
    if (r != ResultadoBiblioteca.ok) return r;
    return lista == null ? ResultadoBiblioteca.falhou : ResultadoBiblioteca.ok;
  }

  /// Ao abrir a aba: lê se nunca leu ou se a leitura tem mais de 6 horas.
  Future<void> aoAbrirAba() async {
    if (!Sessao.instancia.conectado(Sistema.portal)) return;
    final lido = historicoLidoEm;
    if (lido == null || DateTime.now().difference(lido) > const Duration(hours: 6)) await atualizarHistorico();
  }

  Future<(ResultadoBiblioteca, List<TituloAcervo>?)> pesquisar(String termo) async {
    final (r, html) = await _ler(urlAcervoPesquisa(termo.trim()));
    if (r != ResultadoBiblioteca.ok) return (r, null);
    final lista = lerResultadoAcervo(html!);
    return (lista == null ? ResultadoBiblioteca.falhou : ResultadoBiblioteca.ok, lista);
  }

  Future<(ResultadoBiblioteca, List<Exemplar>?)> exemplares(TituloAcervo titulo) async {
    final (r, html) = await _ler(
      urlAcervoExemplares(titulo.idRegistro, titulo: titulo.titulo, autor: titulo.autor ?? ''),
    );
    if (r != ResultadoBiblioteca.ok) return (r, null);
    final lista = lerExemplares(html!);
    return (lista == null ? ResultadoBiblioteca.falhou : ResultadoBiblioteca.ok, lista);
  }

  void limparCache() {
    historico = null;
    historicoLidoEm = null;
    _entrou = false;
    notifyListeners();
  }
}
